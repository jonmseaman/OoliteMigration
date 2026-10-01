#!/usr/bin/env python3
"""Render tools/tier-c-diff.sh's divergence report in ONE process (bead oo-3rb.349).

tools/tier-c-diff.sh runs both backends and then compares what each left behind. The comparison
used to be done in bash: a `cygpath`, `grep`, `sed`, `wc` or `python` process for nearly every
line -- about sixty process spawns for a two-scenario fixture. Under MSYS a spawn costs 1-2 s when
the machine is loaded (tier-b runs 8 golden + 6 tools pytest shards at once), so a report that
takes 1 s on an idle machine took over 60 s under load (bead oo-3rb.349: tools/test_tier_c_diff.py
timed out twice in the Phase 2 exit gate). This script is the same comparison, line for line, in a
single interpreter: golden_diff.py is imported and its main() called in-process per scenario, so
the cost no longer scales with process spawns.

It is an implementation detail of tools/tier-c-diff.sh, which calls it as
`"$PY" tools/tier_c_diff_report.py ...`; the output contract (report text, stdout/stderr lines,
exit codes 0 green / 1 divergence or failed backend / 2 refusal) is tier-c-diff.sh's and is pinned
by tools/test_tier_c_diff.py.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tests" / "golden"))
import golden_diff  # tests/golden is not a package; its path is put on sys.path just above


class Refuse(Exception):
    """tier-c-diff.sh's die(): message to stderr, exit 2."""


def native(p: str) -> str:
    """A path this (native) interpreter can open. tier-c.sh prints its run root already native
    (cygpath -m), but corpus.sh's "results: <path>" line is whatever form its shell had, which
    under MSYS can be /c/... or /tmp/.... The bash version tested those with [ -f ], which
    understands MSYS paths; do the same here."""
    if not p or os.path.exists(p):
        return p
    m = re.match(r"^/([a-zA-Z])(/.*)?$", p)
    if m:
        cand = "%s:%s" % (m.group(1).upper(), m.group(2) or "/")
        if os.path.exists(cand):
            return cand
    if p.startswith("/") and shutil.which("cygpath"):
        try:
            out = subprocess.run(["cygpath", "-m", p], capture_output=True, text=True,
                                 timeout=30).stdout.strip()
            if out:
                return out
        except (OSError, subprocess.SubprocessError):
            pass
    return p


def first_line(path: str, pattern: str) -> str:
    """grep -m1 <pattern> <path>, '' if none."""
    rx = re.compile(pattern)
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if rx.search(line):
                    return line
    except OSError:
        pass
    return ""


def tail(path: str, n: int = 5) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return "\n".join(fh.read().splitlines()[-n:])
    except OSError:
        return ""


def run_root_of(log: str) -> str:
    line = first_line(log, r"logs kept at")
    m = re.match(r"^.*logs kept at ([^ ]+).*$", line)
    return m.group(1) if m else ""


def golden_names(root: str) -> list[str]:
    try:
        entries = os.listdir(root)
    except OSError:
        return []
    names = [e[:-len(".json")] for e in entries
             if e.endswith(".json") and not e.startswith(".")
             and os.path.isfile(os.path.join(root, e))]
    return sorted(n for n in names if not re.match(r"^(diff-|ev-)", n))


def golden_diff_into(log: str, left: str, right: str, name: str) -> int:
    """Run golden_diff.py's main() in-process with its stdout+stderr captured to `log`, exactly
    as `golden_diff.py ... > log 2>&1` did."""
    with open(log, "w", encoding="utf-8") as fh, \
            contextlib.redirect_stdout(fh), contextlib.redirect_stderr(fh):
        try:
            rc = golden_diff.main([left, right, "--label-left", "sm/" + name,
                                   "--label-right", "quickjs/" + name])
        except SystemExit as exc:
            rc = exc.code if isinstance(exc.code, int) else 2
        except Exception as exc:  # a crash is a refusal, as a nonzero/non-1 exit was
            sys.stderr.write("REFUSED: golden_diff crashed: %r\n" % (exc,))
            rc = 2
    return int(rc or 0)


def load_results(path: str) -> list:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def render(out: str, sm_rc: int, qjs_rc: int, golden_floor: int, corpus_floor: int) -> int:
    sm_log = os.path.join(out, "tier-c-sm.log")
    qjs_log = os.path.join(out, "tier-c-quickjs.log")
    sm_root = native(run_root_of(sm_log))
    qjs_root = native(run_root_of(qjs_log))
    if not (sm_root and os.path.isdir(sm_root)):
        raise Refuse("could not find the SpiderMonkey run's kept root from %s; the run may have "
                     "failed before reaching goldens/corpus. Tail: %s" % (sm_log, tail(sm_log)))
    if not (qjs_root and os.path.isdir(qjs_root)):
        raise Refuse("could not find the QuickJS-ng run's kept root from %s; the run may have "
                     "failed before reaching goldens/corpus. Tail: %s" % (qjs_log, tail(qjs_log)))

    print("tier-c-diff: sm run root      %s" % sm_root)
    print("tier-c-diff: quickjs run root %s" % qjs_root)

    # 2. GOLDEN DUMPS, each pair through golden_diff.py (the tool the goldens stage trusts).
    report_path = os.path.join(out, "divergence-report.md")
    diff_log_dir = os.path.join(out, "golden-diffs")
    os.makedirs(diff_log_dir, exist_ok=True)

    sm_names = golden_names(sm_root)
    qjs_names = golden_names(qjs_root)
    all_names = sorted(set(sm_names) | set(qjs_names))

    # ANTI-VACUITY: a differential over a golden set that never ran is two empty sets compared.
    if len(sm_names) < golden_floor:
        raise Refuse("the SpiderMonkey run produced only %d golden dump(s), fewer than the floor "
                     "of %d; a differential over an empty set is vacuous"
                     % (len(sm_names), golden_floor))
    if len(qjs_names) < golden_floor:
        raise Refuse("the QuickJS-ng run produced only %d golden dump(s), fewer than the floor "
                     "of %d; a differential over an empty set is vacuous"
                     % (len(qjs_names), golden_floor))

    golden_rows = []
    for name in all_names:
        left = os.path.join(sm_root, name + ".json")
        right = os.path.join(qjs_root, name + ".json")
        if not os.path.isfile(left):
            golden_rows.append("%s | MISSING on sm | present on quickjs" % name)
            continue
        if not os.path.isfile(right):
            golden_rows.append("%s | present on sm | MISSING on quickjs" % name)
            continue
        dlog = os.path.join(diff_log_dir, name + ".log")
        drc = golden_diff_into(dlog, left, right, name)
        if drc == 0:
            continue
        if drc == 1:
            first = first_line(dlog, r"^  ")
            golden_rows.append("%s | DIFFERS | first: %s" % (name, first or "<no line captured>"))
        else:
            reason = first_line(dlog, r"^REFUSED") or "refused (rc=%d)" % drc
            golden_rows.append("%s | REFUSED | %s" % (name, reason))

    # 3. CORPUS: results.json named by each run's corpus.log, compared by group name + verdict.
    sm_corpus_log = os.path.join(sm_root, "corpus.log")
    qjs_corpus_log = os.path.join(qjs_root, "corpus.log")
    if not os.path.isfile(sm_corpus_log):
        raise Refuse("no corpus.log under %s; the sm run's corpus stage did not leave the "
                     "evidence this script depends on" % sm_root)
    if not os.path.isfile(qjs_corpus_log):
        raise Refuse("no corpus.log under %s; the quickjs run's corpus stage did not leave the "
                     "evidence this script depends on" % qjs_root)

    def results_of(corpus_log: str) -> str:
        line = first_line(corpus_log, r"^results: ")
        return line[len("results: "):] if line else ""

    sm_results_raw = results_of(sm_corpus_log)
    qjs_results_raw = results_of(qjs_corpus_log)
    sm_results = native(sm_results_raw)
    qjs_results = native(qjs_results_raw)
    if not (sm_results and os.path.isfile(sm_results)):
        raise Refuse("could not find the sm corpus run's results.json (parsed '%s' from %s)"
                     % (sm_results_raw, sm_corpus_log))
    if not (qjs_results and os.path.isfile(qjs_results)):
        raise Refuse("could not find the quickjs corpus run's results.json (parsed '%s' from %s)"
                     % (qjs_results_raw, qjs_corpus_log))

    sm = load_results(sm_results)
    qjs = load_results(qjs_results)
    # ANTI-VACUITY: a corpus run that checked fewer groups than the floor (bead oo-het's "35 of
    # 36 never copied") is not a real differential.
    if len(sm) < corpus_floor:
        sys.stderr.write("tier-c-diff: the sm corpus run checked only %d group(s), fewer than the "
                         "floor of %d; a differential over a run that short is vacuous\n"
                         % (len(sm), corpus_floor))
        raise Refuse("the corpus comparison refused (rc=2); see the message above")
    if len(qjs) < corpus_floor:
        sys.stderr.write("tier-c-diff: the quickjs corpus run checked only %d group(s), fewer "
                         "than the floor of %d; a differential over a run that short is vacuous\n"
                         % (len(qjs), corpus_floor))
        raise Refuse("the corpus comparison refused (rc=2); see the message above")

    sm_by_name = {r["name"]: r for r in sm}
    qjs_by_name = {r["name"]: r for r in qjs}
    corpus_names = sorted(set(sm_by_name) | set(qjs_by_name))
    corpus_rows = []
    for name in corpus_names:
        sr, qr = sm_by_name.get(name), qjs_by_name.get(name)
        if sr is None:
            corpus_rows.append((name, "MISSING", qr.get("verdict", "?"), ""))
            continue
        if qr is None:
            corpus_rows.append((name, sr.get("verdict", "?"), "MISSING", ""))
            continue
        sv, qv = sr.get("verdict"), qr.get("verdict")
        if sv != qv:
            first_err = ""
            for src in (sr, qr):
                errs = src.get("errors") or []
                if errs:
                    first_err = errs[0]
                    break
            corpus_rows.append((name, sv, qv, first_err))

    with open(os.path.join(out, "corpus-rows.tsv"), "w", encoding="utf-8") as fh:
        for name, sv, qv, first_err in corpus_rows:
            fh.write("%s\t%s\t%s\t%s\n" % (name, sv, qv, first_err))
    print("corpus: %d group(s) compared (sm %d checked, quickjs %d checked), %d divergent"
          % (len(corpus_names), len(sm), len(qjs), len(corpus_rows)))

    # 4. THE REPORT.
    golden_divergent = len(golden_rows)
    corpus_divergent = len(corpus_rows)
    lines = ["# Tier C differential report: SpiderMonkey vs QuickJS-ng\n\n",
             "- sm run:      %s (%s)\n" % (sm_root, sm_log),
             "- quickjs run: %s (%s)\n\n" % (qjs_root, qjs_log),
             "## Goldens (%d compared, floor %d each side; sm=%d, quickjs=%d dumped)\n\n"
             % (len(all_names), golden_floor, len(sm_names), len(qjs_names))]
    if golden_divergent == 0:
        lines.append("NO golden divergences: every scenario byte-for-byte identical between "
                     "backends.\n\n")
    else:
        lines.append("| scenario | status | first differing line |\n|---|---|---|\n")
        lines += ["| %s |\n" % row for row in golden_rows]
        lines.append("\n")
    lines.append("## Corpus (%d group(s) compared, floor %d each side; sm=%d, quickjs=%d "
                 "checked)\n\n" % (len(corpus_names), corpus_floor, len(sm), len(qjs)))
    if corpus_divergent == 0:
        lines.append("NO corpus divergences: every group verdict identical between backends.\n\n")
    else:
        lines.append("| group | sm verdict | quickjs verdict | first differing line |\n"
                     "|---|---|---|---|\n")
        lines += ["| %s | %s | %s | %s |\n" % (n, sv, qv, fe or "-")
                  for n, sv, qv, fe in corpus_rows]
        lines.append("\n")
    total = golden_divergent + corpus_divergent
    lines.append("## Summary\n\n%d total divergence(s): %d golden, %d corpus.\n"
                 % (total, golden_divergent, corpus_divergent))
    report = "".join(lines)
    with open(report_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(report)

    sys.stdout.write(report)
    print("\ntier-c-diff: report written to %s" % report_path)
    sys.stdout.flush()

    if sm_rc != 0 or qjs_rc != 0:
        sys.stderr.write("tier-c-diff: at least one backend run FAILED (sm rc=%d, quickjs rc=%d) "
                         "-- the report above reflects only what each run actually produced "
                         "before failing.\n" % (sm_rc, qjs_rc))
        return 1
    if total > 0:
        sys.stderr.write("tier-c-diff: %d divergence(s) found between backends; see %s\n"
                         % (total, report_path))
        return 1
    print("tier-c-diff: GREEN -- no divergence between sm and quickjs across %d golden "
          "scenario(s) and %d corpus group(s)" % (len(all_names), len(corpus_names)))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True, help="tier-c-diff.sh's --out, as a native path")
    ap.add_argument("--sm-rc", type=int, default=0)
    ap.add_argument("--quickjs-rc", type=int, default=0)
    ap.add_argument("--golden-floor", type=int, required=True)
    ap.add_argument("--corpus-floor", type=int, required=True)
    args = ap.parse_args(argv)
    try:
        return render(args.out, args.sm_rc, args.quickjs_rc, args.golden_floor,
                      args.corpus_floor)
    except Refuse as exc:
        sys.stdout.flush()
        sys.stderr.write("tier-c-diff: %s\n" % exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())
