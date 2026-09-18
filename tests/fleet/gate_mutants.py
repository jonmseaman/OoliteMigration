#!/usr/bin/env python3
"""Mutation harness for the oo-l7r0 gate: every property the gate protects is broken on a
COPY and the checker must go RED with a message naming the failure.

A gate nobody has watched fail is decoration.  This file is what makes the acceptance block
falsifiable without editing any committed artefact: each mutant is applied to a temp copy of
the report, of docs/infra/4-metrics.md, or of tools/fleet_reporter.py itself.

Run:
    python3 tests/fleet/gate_mutants.py --all        # report/doc mutants
    python3 tests/fleet/gate_mutants.py --guards     # read-only refusals + their red twins

Exit 0 only if EVERY mutant went red (and every control stayed green).  Output is verbatim:
the actual refusal / failure text is printed, not a summary of it.
"""

from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import fleet_reporter as fr  # noqa: E402

DOC = os.path.join(ROOT, "docs", "infra", "4-metrics.md")
RESULTS: list[tuple[str, bool, str]] = []


def record(name, ok, detail, kind="mutant"):
    RESULTS.append((name, ok, detail))
    print(f"\n--- {kind}: {name}")
    print(detail.rstrip())
    if kind == "control":
        print(f"--- verdict: {'GOOD (stayed green as required)' if ok else 'BAD (control failed)'}")
    else:
        print(f"--- verdict: {'GOOD (went red as required)' if ok else 'BAD (did not go red)'}")


def latest_report():
    d = os.path.join(ROOT, "docs", "fleet")
    rs = sorted(f for f in os.listdir(d) if re.fullmatch(r"REPORT-\d{4}-\d{2}-\d{2}\.md", f))
    if not rs:
        sys.exit("FAIL: no docs/fleet/REPORT-<date>.md to mutate")
    return os.path.join(d, rs[-1])


def rewrite_payload(text, payload):
    return re.sub(r"```json\n.*?\n```", "```json\n" + json.dumps(payload, indent=2) + "\n```",
                  text, flags=re.S)


def run_check(path, doc=DOC):
    ok, msgs = fr.check_report(path, doc, ROOT, fr.default_bd())
    return ok, "\n".join(msgs)


# ------------------------------------------------------------------ mutants


def mut_control(tmp, rep_text):
    """CONTROL: the unmutated report must be GREEN, or every red below is meaningless."""
    p = os.path.join(tmp, os.path.basename(latest_report()))
    open(p, "w", encoding="utf-8").write(rep_text)
    ok, msgs = run_check(p)
    record("control (unmutated report must PASS)", ok,
           msgs + f"\ncheck said: {'CHECK PASS' if ok else 'CHECK FAIL'}", kind="control")


def mut_sourceless_number(tmp, rep_text):
    """The subtlest cheat: fake a value AND repair the status so the report is internally
    consistent.  Only a checker that stats the SOURCE catches this."""
    payload = fr.extract_payload(rep_text)
    m = next(x for x in payload["metrics"] if x["id"] == "tier-b-flake-rate-per-check-rolling-7-days")
    m["values"] = {"checks_examined": {"value": 42},
                   "worst_check_flake_rate_pct": {"value": 0.0},
                   "stop_the_line": {"value": False}}
    m["status"] = "COMPUTED"
    text = rewrite_payload(rep_text, payload)
    text = re.sub(r"(### tier-b-flake-rate-per-check-rolling-7-days\n.*?)(?=\n### )",
                  "### tier-b-flake-rate-per-check-rolling-7-days\n\n"
                  "- **status:** COMPUTED\n- `checks_examined` = 42\n"
                  "- `worst_check_flake_rate_pct` = 0.0\n- `stop_the_line` = False\n",
                  text, flags=re.S)
    p = os.path.join(tmp, "REPORT-sourceless.md")
    open(p, "w", encoding="utf-8").write(text)
    ok, msgs = run_check(p)
    record("fabricate a Tier-B number AND repair its status (no Tier-B log exists)",
           (not ok) and "fabricated, not measured" in msgs, msgs)


def mut_drop_metric(tmp, rep_text):
    """Drop a metric the doc defines: the gate must name it."""
    payload = fr.extract_payload(rep_text)
    victim = payload["metrics"].pop(3)
    text = rewrite_payload(rep_text, payload)
    text = re.sub(rf"### {re.escape(victim['id'])}\n.*?(?=\n### |\n## )", "", text, flags=re.S)
    p = os.path.join(tmp, "REPORT-dropped.md")
    open(p, "w", encoding="utf-8").write(text)
    ok, msgs = run_check(p)
    named = victim["label"] in msgs or victim["id"] in msgs
    record(f"drop metric '{victim['id']}' from the report", (not ok) and named, msgs)


def mut_zero_for_uncomputed(tmp, rep_text):
    """Print 0 for a metric that could not be computed: the gate must refuse the silent zero."""
    payload = fr.extract_payload(rep_text)
    target = None
    for m in payload["metrics"]:
        for k, v in m["values"].items():
            if "not_computed" in v:
                target = (m, k)
                break
        if target:
            break
    if target is None:
        record("zero-for-uncomputed", False, "no NOT COMPUTED value exists to mutate")
        return
    m, k = target
    m["values"][k] = {"value": 0}
    text = rewrite_payload(rep_text, payload)
    text = re.sub(rf"`{re.escape(k)}` = NOT COMPUTED[^\n]*", f"`{k}` = 0", text)
    p = os.path.join(tmp, "REPORT-silentzero.md")
    open(p, "w", encoding="utf-8").write(text)
    ok, msgs = run_check(p)
    record(f"print 0 for uncomputable '{m['id']}.{k}'", (not ok) and m["id"] in msgs, msgs)


def mut_fake_number(tmp, rep_text):
    """Fake a count the gate recomputes independently."""
    payload = fr.extract_payload(rep_text)
    adr = next(m for m in payload["metrics"] if m["id"] == "proposed-adrs-awaiting-override")
    adr["values"]["awaiting_override"]["value"] += 7
    p = os.path.join(tmp, "REPORT-faked.md")
    open(p, "w", encoding="utf-8").write(rewrite_payload(rep_text, payload))
    ok, msgs = run_check(p)
    record("inflate proposed-ADR count by 7", (not ok) and "independently counted" in msgs, msgs)


def mut_doc_gains_metric(tmp, rep_text):
    """The metric list is parsed from the doc: a new row must make the gate red."""
    doc2 = os.path.join(tmp, "4-metrics-plus.md")
    src = open(DOC, encoding="utf-8").read()
    src = src.replace("| Tier-1 corpus green |",
                      "| Invented metric for the derivation test | nowhere | proves parsing |\n"
                      "| Tier-1 corpus green |")
    open(doc2, "w", encoding="utf-8").write(src)
    n_before, n_after = len(fr.daily_metrics_from_doc(DOC)), len(fr.daily_metrics_from_doc(doc2))
    p = os.path.join(tmp, "REPORT-docgain.md")
    open(p, "w", encoding="utf-8").write(rep_text)
    ok, msgs = run_check(p, doc2)
    named = "Invented metric for the derivation test" in msgs
    record(f"doc gains a metric ({n_before} -> {n_after} rows)", (not ok) and named, msgs)


def mut_drop_fork_figure(tmp, rep_text):
    """The bead's extra required figure disappears."""
    payload = fr.extract_payload(rep_text)
    m = next(x for x in payload["metrics"] if x["id"].startswith("days-since-origin-main"))
    m["values"].pop("fork_migration_matched")
    p = os.path.join(tmp, "REPORT-nofork.md")
    open(p, "w", encoding="utf-8").write(rewrite_payload(rep_text, payload))
    ok, msgs = run_check(p)
    record("remove the fork/migration matched figure",
           (not ok) and "fork_migration_matched" in msgs, msgs)


# ------------------------------------------------------------------- guards


def load_stripped(tmp, marker):
    src = open(os.path.join(ROOT, "tools", "fleet_reporter.py"), encoding="utf-8").read()
    out, n = re.subn(rf"# BEGIN-ENFORCEMENT-{marker}.*?# END-ENFORCEMENT-{marker}",
                     f"_{marker}_ENFORCED = False", src, flags=re.S)
    assert n == 1, f"expected one ENFORCEMENT-{marker} region, found {n}"
    p = os.path.join(tmp, f"fr_no{marker.lower()}.py")
    open(p, "w", encoding="utf-8").write(out)
    spec = importlib.util.spec_from_file_location(f"fr_no{marker}", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def guards(tmp):
    g = fr.ReadOnlyGuard(os.path.join(tmp, "REPORT-x.md"))

    # 1. write outside the single permitted file
    victim = os.path.join(tmp, "victim.txt")
    open(victim, "w", encoding="utf-8").write("original")
    try:
        g.write_text(victim, "clobbered")
        record("write outside the report file", False, "NO REFUSAL: the write succeeded")
    except fr.Refusal as e:
        intact = open(victim, encoding="utf-8").read() == "original"
        record("write outside the report file", intact,
               f"{e}\nvictim file after the refusal: "
               f"{open(victim, encoding='utf-8').read()!r} (intact={intact})")

    # 2. mutating commands, refused BEFORE exec
    for argv in (["C:/tools/bd/bd.exe", "close", "oo-l7r0"],
                 ["bd", "update", "oo-l7r0", "--status", "closed"],
                 ["bd", "update", "oo-l7r0", "--claim"],
                 ["git", "commit", "-m", "x"],
                 ["git", "-C", ROOT, "commit", "-m", "x"],
                 ["git", "push", "origin", "main"],
                 ["git", "-C", ROOT, "push"],
                 ["git", "add", "-A"],
                 ["rm", "-rf", ROOT]):
        before = len(g.exec_trace)
        try:
            g.run(argv)
            record(" ".join(argv), False, "NO REFUSAL: the command was executed")
        except fr.Refusal as e:
            never_ran = len(g.exec_trace) == before
            record(" ".join(argv), never_ran,
                   f"{e}\nexec trace unchanged (refused before exec): {never_ran}")

    # 3. control: read-only commands must still work, or the guard is just 'refuse everything'
    rc, so, _ = g.run(["git", "-C", ROOT, "rev-parse", "HEAD"])
    ok = rc == 0 and len(so.strip()) == 40
    record("git rev-parse HEAD must be ALLOWED", ok,
           f"rc={rc} stdout={so.strip()!r}\n(a guard that refuses everything would pass the "
           f"refusal tests and be useless)", kind="control")

    # 4. RED TWINS: strip the enforcement and watch the same actions succeed
    nw = load_stripped(tmp, "WRITE")
    g2 = nw.ReadOnlyGuard(os.path.join(tmp, "REPORT-x.md"))
    v2 = os.path.join(tmp, "victim2.txt")
    open(v2, "w", encoding="utf-8").write("original")
    try:
        g2.write_text(v2, "clobbered")
        clob = open(v2, encoding="utf-8").read() == "clobbered"
        record("RED TWIN: enforcement stripped -> write outside report SUCCEEDS", clob,
               f"victim2 after the stripped-guard write: "
               f"{open(v2, encoding='utf-8').read()!r}\n"
               f"=> the refusal above is caused by the enforcement, not by something else")
    except Exception as e:  # noqa: BLE001
        record("RED TWIN: enforcement stripped -> write SUCCEEDS", False,
               f"stripped mutant still failed: {e!r}")

    ne = load_stripped(tmp, "EXEC")
    g3 = ne.ReadOnlyGuard(os.path.join(tmp, "REPORT-x.md"))
    try:
        rc, so, _ = g3.run([sys.executable, "-c", "print('a mutating command would run here')"])
        ran = bool(g3.exec_trace)
        record("RED TWIN: enforcement stripped -> guard no longer refuses", ran,
               f"stripped guard executed: {g3.exec_trace}\nstdout={so.strip()!r}")
    except Exception as e:  # noqa: BLE001
        record("RED TWIN: enforcement stripped -> guard no longer refuses", False, repr(e))


# --------------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--guards", action="store_true")
    a = ap.parse_args()
    if not (a.all or a.guards):
        a.all = a.guards = True

    tmp = tempfile.mkdtemp(prefix="oo-l7r0-mutants-")
    try:
        if a.all:
            rep_text = open(latest_report(), encoding="utf-8").read()
            mut_control(tmp, rep_text)
            mut_sourceless_number(tmp, rep_text)
            mut_drop_metric(tmp, rep_text)
            mut_zero_for_uncomputed(tmp, rep_text)
            mut_fake_number(tmp, rep_text)
            mut_doc_gains_metric(tmp, rep_text)
            mut_drop_fork_figure(tmp, rep_text)
        if a.guards:
            guards(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    bad = [n for n, ok, _ in RESULTS if not ok]
    print(f"\n==== {len(RESULTS)} mutants/controls, {len(RESULTS) - len(bad)} behaved as required")
    if bad:
        print("FAILED TO GO RED (or control failed): " + "; ".join(bad))
        return 1
    print("ALL MUTANTS WENT RED; ALL CONTROLS GREEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
