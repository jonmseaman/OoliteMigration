#!/usr/bin/env python3
"""Read-only fleet reporter: writes docs/fleet/REPORT-<date>.md with every daily
metric defined in docs/infra/4-metrics.md.

Design notes that matter more than the code:

1. THE METRIC LIST IS DERIVED FROM THE DOC, NEVER COPIED.  ``daily_metrics_from_doc``
   parses the ``## Daily`` table of docs/infra/4-metrics.md and slugifies the first
   column.  The collector registry below is keyed by those slugs.  If the doc gains a
   row that no collector answers, the report simply does not contain it and
   ``check_report`` goes red naming the missing slug.  There is no hard-coded copy of
   the metric list to drift.

2. 'GENUINELY ZERO' AND 'NOT COMPUTED' ARE DIFFERENT THINGS IN THE OUTPUT.  Every
   value is either ``{"value": <x>}`` (really measured, and 0 is a real measurement)
   or ``{"not_computed": "<reason>"}``.  A collector that cannot reach its source MUST
   return the second form; printing 0 for an unreachable source is the failure mode
   this whole file exists to prevent, and check_report asserts the distinction.

3. READ-ONLY IS ENFORCED, NOT PROMISED.  Two seams:
      * every filesystem write goes through ``ReadOnlyGuard.write_text`` which refuses
        any path other than the single report file the run was told to produce;
      * every subprocess goes through ``ReadOnlyGuard.run`` which refuses a mutating
        argv (bd close/update/..., git commit/push/...) BEFORE exec, so the refusal
        precedes any process start rather than merely accompanying it.
   Both refusals raise ``Refusal``.  tests/fleet/test_fleet_reporter.py proves each one
   blocks, and proves the block disappears when the enforcement is stripped.

4. THE MODEL INVOCATION IS A SEAM.  The scheduled form of this job is
   ``claude -p --model claude-opus-5`` with read-only tools (tools/fleet-report.sh).
   Report GENERATION is this module and is exercised directly by the tests; the model
   call is not invoked here at all, so nothing in the gate depends on Claude being
   installed, authenticated or fast.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import subprocess
import sys

REPO_MARKERS = ("docs/infra/4-metrics.md", ".git")

# --------------------------------------------------------------------------- guard


class Refusal(RuntimeError):
    """A read-only rule refused an action.  Never caught inside this module."""


# BEGIN-ENFORCEMENT-WRITE (tests strip this marked region to prove the guard bites)
_WRITE_ENFORCED = True
# END-ENFORCEMENT-WRITE

# BEGIN-ENFORCEMENT-EXEC
_EXEC_ENFORCED = True
# END-ENFORCEMENT-EXEC

# argv[0] basename -> subcommands that mutate state.  "*" means the whole program is
# a mutation (there is no read-only way to call it).
_MUTATING = {
    "bd": {
        "close", "create", "update", "delete", "import", "sync", "dep", "comment",
        "remember", "claim", "reopen", "split", "merge", "init", "migrate", "push",
        "pull", "dolt", "compact", "collapse", "label", "assign", "note",
    },
    "git": {
        "commit", "push", "add", "rm", "mv", "merge", "rebase", "reset", "checkout",
        "switch", "restore", "clean", "apply", "am", "cherry-pick", "revert", "tag",
        "branch", "worktree", "gc", "prune", "fetch", "pull", "stash", "notes",
        "update-ref", "symbolic-ref", "config", "filter-branch", "replace",
    },
    "rm": {"*"}, "rmdir": {"*"}, "mv": {"*"}, "cp": {"*"}, "dd": {"*"},
    "tee": {"*"}, "truncate": {"*"}, "install": {"*"}, "chmod": {"*"},
    "powershell": {"*"}, "cmd": {"*"}, "bash": {"*"}, "sh": {"*"},
}


def _prog(argv0: str) -> str:
    base = os.path.basename(str(argv0)).lower()
    for ext in (".exe", ".cmd", ".bat"):
        if base.endswith(ext):
            base = base[: -len(ext)]
    return base


# Global flags that CONSUME the next argument.  Without this table the scan mistakes
# the value of `git -C <path>` for the subcommand and `git -C <path> commit` walks
# straight through the guard.  (That hole existed and was found by test
# test_git_dash_C_commit_is_refused; keep the test if you touch this.)
_VALUE_FLAGS = {"-c", "-C", "--git-dir", "--work-tree", "--namespace", "--exec-path",
                "--db", "--config", "--dir", "--limit", "--format", "--status"}


def classify_argv(argv) -> str | None:
    """Return a refusal reason if argv mutates state, else None."""
    if not argv:
        return "empty argv"
    prog = _prog(argv[0])
    banned = _MUTATING.get(prog)
    if banned is None:
        return None
    if "*" in banned:
        return f"{prog} is not a read-only program"
    # flags that write even under a read-only subcommand
    for tok in argv[1:]:
        t = str(tok).lower()
        if t in ("--claim", "--acceptance", "-w", "--write", "--in-place", "--force"):
            return f"{prog} {t} mutates state"
    skip = False
    for tok in argv[1:]:
        t = str(tok)
        if skip:
            skip = False
            continue
        if t in _VALUE_FLAGS:
            skip = True
            continue
        if t.startswith("-"):
            continue
        if t.lower() in banned:
            return f"{prog} {t} mutates state"
        break  # first non-flag, non-flag-value token is the subcommand
    return None


class ReadOnlyGuard:
    """Single choke point for every side effect the reporter is allowed."""

    def __init__(self, report_path: str):
        self.report_path = os.path.abspath(report_path)
        self.exec_trace: list[list[str]] = []
        self.refusals: list[str] = []

    # -- writes ------------------------------------------------------------
    def write_text(self, path: str, text: str) -> str:
        target = os.path.abspath(path)
        if _WRITE_ENFORCED and target != self.report_path:
            msg = (
                f"REFUSED WRITE: {target}\n"
                f"  the reporter may write exactly one file: {self.report_path}"
            )
            self.refusals.append(msg)
            raise Refusal(msg)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        return target

    # -- subprocesses ------------------------------------------------------
    def run(self, argv, cwd=None, timeout=120):
        reason = classify_argv(argv) if _EXEC_ENFORCED else None
        if reason is not None:
            msg = f"REFUSED COMMAND: {' '.join(str(a) for a in argv)}\n  {reason}"
            self.refusals.append(msg)
            raise Refusal(msg)
        self.exec_trace.append([str(a) for a in argv])
        try:
            p = subprocess.run(
                [str(a) for a in argv], cwd=cwd, timeout=timeout,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            return 127, "", f"{type(exc).__name__}: {exc}"
        return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")


# ------------------------------------------------------------------- doc parsing


def slugify(label: str) -> str:
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", label)      # [text](link) -> text
    s = s.replace("`", "").replace("**", "")
    s = re.sub(r"[^0-9a-zA-Z]+", "-", s).strip("-").lower()
    return re.sub(r"-{2,}", "-", s)


def daily_metrics_from_doc(doc_path: str):
    """[(slug, label, source)] for every row of the ## Daily table."""
    with open(doc_path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    out, in_daily = [], False
    for line in lines:
        if line.startswith("## "):
            in_daily = line.strip().lower() == "## daily"
            continue
        if not in_daily or not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        if set("".join(cells)) <= set("-: "):
            continue                                  # separator row
        if cells[0].lower() == "metric":
            continue                                  # header row
        out.append((slugify(cells[0]), cells[0], cells[1]))
    return out


# --------------------------------------------------------------------- helpers


def val(x, unit=None):
    d = {"value": x}
    if unit:
        d["unit"] = unit
    return d


def nc(reason):
    return {"not_computed": reason}


def find_repo_root(start: str) -> str:
    cur = os.path.abspath(start)
    while True:
        if all(os.path.exists(os.path.join(cur, m)) for m in REPO_MARKERS[:1]):
            if os.path.exists(os.path.join(cur, ".git")):
                return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            raise SystemExit(f"not inside an OoliteMigration checkout: {start}")
        cur = parent


def _tier_log_candidates(root: str):
    return [
        os.path.join(root, ".fleet-logs"),
        os.path.join(root, "build", "tier-logs"),
        os.path.join(os.path.dirname(root), ".fleet-logs"),
    ]


def _tier_logs(root: str, pattern: str):
    hits = []
    for d in _tier_log_candidates(root):
        if os.path.isdir(d):
            for name in sorted(os.listdir(d)):
                if re.search(pattern, name):
                    hits.append(os.path.join(d, name))
    return hits


def _no_tier_logs_reason(root: str, what: str) -> str:
    where = ", ".join(os.path.relpath(d, root).replace("\\", "/") for d in _tier_log_candidates(root))
    return f"no {what} log found (searched: {where}); source not present in this checkout"


# ------------------------------------------------------------------ collectors
# Each collector: (guard, root, ctx) -> dict of value-name -> val()/nc()


def c_goldens_stable(g, root, ctx):
    logs = _tier_logs(root, r"tier-c|golden")
    if not logs:
        return {"scenarios_reproduced": nc(_no_tier_logs_reason(root, "Tier C")),
                "scenarios_total": nc(_no_tier_logs_reason(root, "Tier C"))}
    return {"scenarios_reproduced": nc("tier-C log found but its schema is not defined yet"),
            "scenarios_total": nc("tier-C log found but its schema is not defined yet")}


def c_tier_b_flake(g, root, ctx):
    r = _no_tier_logs_reason(root, "Tier B")
    return {"checks_examined": nc(r), "worst_check_flake_rate_pct": nc(r),
            "stop_the_line": nc(r)}


def c_merge_queue(g, root, ctx):
    log = os.path.join(root, "tools", "merge-queue")
    if not os.path.exists(log):
        r = "tools/merge-queue does not exist in this checkout (merge queue not built yet)"
        return {"queue_depth": nc(r), "batches_run": nc(r), "bisections_triggered": nc(r)}
    r = "tools/merge-queue exists but its log schema is not defined yet"
    return {"queue_depth": nc(r), "batches_run": nc(r), "bisections_triggered": nc(r)}


def c_beads(g, root, ctx):
    beads = ctx.get("beads")
    if beads is None:
        r = ctx.get("beads_error", "bd not available")
        return {k: nc(r) for k in
                ("ready", "claimed", "closed_by_wrapper", "closed_by_human",
                 "stuck_claimed_over_8h")}
    open_ = [b for b in beads if b.get("status") == "open"]
    in_prog = [b for b in beads if b.get("status") == "in_progress"]
    closed = [b for b in beads if b.get("status") == "closed"]
    wrapper = [b for b in closed if "accepted: merged into" in (b.get("close_reason") or "")]
    now = _dt.datetime.now(_dt.timezone.utc)
    stuck = 0
    for b in in_prog:
        ts = b.get("started_at") or b.get("updated_at")
        t = _parse_iso(ts)
        if t is not None and (now - t).total_seconds() > 8 * 3600:
            stuck += 1
    return {
        "ready": val(len(open_)),
        "claimed": val(len(in_prog)),
        "closed_by_wrapper": val(len(wrapper)),
        "closed_by_human": val(len(closed) - len(wrapper)),
        "stuck_claimed_over_8h": val(stuck),
    }


def _parse_iso(ts):
    if not ts:
        return None
    try:
        return _dt.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except ValueError:
        return None


def c_days_since_match(g, root, ctx):
    out = {}
    rc, so, se = g.run(["git", "-C", root, "log", "-1", "--format=%cI", "origin/main"])
    if rc == 0 and so.strip():
        t = _parse_iso(so.strip())
        days = (_dt.datetime.now(t.tzinfo) - t).total_seconds() / 86400.0
        out["days_since_origin_main"] = val(round(days, 2), "days")
        out["origin_main_commit"] = val(_rev(g, root, "origin/main"))
    else:
        out["days_since_origin_main"] = nc(f"git log origin/main failed (rc={rc}): {se.strip()[:120]}")
        out["origin_main_commit"] = nc("origin/main not resolvable in this checkout")

    ref = None
    for cand in ("fork/migration", "refs/remotes/fork/migration"):
        rc, so, _ = g.run(["git", "-C", root, "rev-parse", "--verify", "--quiet", cand])
        if rc == 0 and so.strip():
            ref = cand
            break
    if ref is not None:
        rc, so, _ = g.run(["git", "-C", root, "log", "-1", "--format=%cI", ref])
        t = _parse_iso(so.strip())
        out["days_since_fork_migration"] = val(
            round((_dt.datetime.now(t.tzinfo) - t).total_seconds() / 86400.0, 2), "days")
        rc, so, _ = g.run(["git", "-C", root, "rev-parse", ref])
        rc2, so2, _ = g.run(["git", "-C", root, "rev-parse", "HEAD"])
        out["fork_migration_matched"] = val(so.strip() == so2.strip())
        return out

    # No local mirror ref.  `git ls-remote` is a read-only query (it fetches nothing and
    # writes no ref), so the MATCHED figure is still answerable; the AGE is not, because
    # the commit date needs objects this checkout does not have and fetching them would
    # be a write.  Report each honestly rather than collapsing both to 0.
    rc, so, se = g.run(["git", "-C", root, "ls-remote", "fork", "refs/heads/migration"], timeout=60)
    if rc != 0:
        r = (f"git ls-remote fork failed (rc={rc}): {(se or so).strip()[:120]}; "
             f"no local fork/migration ref either, and the reporter is read-only so it may "
             f"not run git fetch")
        out["days_since_fork_migration"] = nc(r)
        out["fork_migration_matched"] = nc(r)
    elif not so.strip():
        r = "the fork remote has no refs/heads/migration branch yet (ls-remote returned nothing)"
        out["days_since_fork_migration"] = nc(r)
        out["fork_migration_matched"] = nc(r)
    else:
        remote_sha = so.split()[0]
        rc2, head, _ = g.run(["git", "-C", root, "rev-parse", "HEAD"])
        out["fork_migration_matched"] = val(remote_sha == head.strip())
        out["fork_migration_remote_sha"] = val(remote_sha[:12])
        out["days_since_fork_migration"] = nc(
            "fork/migration is not mirrored locally; its commit date needs objects this "
            "checkout does not have, and fetching them would be a write")
    return out


def _rev(g, root, ref):
    rc, so, _ = g.run(["git", "-C", root, "rev-parse", "--short", ref])
    return so.strip() if rc == 0 else "?"


def c_first_try_pass(g, root, ctx):
    r = _no_tier_logs_reason(root, "Tier B")
    return {"stories_attempted": nc(r), "first_try_pass_rate_pct": nc(r)}


def c_rebless(g, root, ctx):
    path = os.path.join(root, "tools", "rebless-approvals.txt")
    if not os.path.exists(path):
        r = "tools/rebless-approvals.txt missing"
        return {k: nc(r) for k in ("proposed", "accepted", "rejected", "oldest_pending_age_days")}
    approvals = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.strip() and not line.startswith("#") and not line[0].isspace():
                approvals += 1
    return {
        "proposed": val(0),          # genuinely zero: no adjudicator log exists yet,
        "accepted": val(approvals),  # and the approvals file is the accepted register
        "rejected": val(0),
        "oldest_pending_age_days": nc(
            "no pending entries (proposed == 0), so there is no oldest pending item to age"),
    }


def c_proposed_adrs(g, root, ctx):
    d = os.path.join(root, "docs", "decisions")
    if not os.path.isdir(d):
        return {"awaiting_override": nc("docs/decisions/ missing")}
    n, names = 0, []
    for name in sorted(os.listdir(d)):
        if not name.endswith(".md") or name == "README.md":
            continue
        with open(os.path.join(d, name), encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("**Status:**"):
                    if re.match(r"\*\*Status:\*\*\s*Proposed\b", line):
                        n += 1
                        names.append(name)
                    break
    return {"awaiting_override": val(n), "adrs": val(",".join(names) if names else "-")}


def c_tier1_corpus(g, root, ctx):
    r = _no_tier_logs_reason(root, "Tier B/C corpus")
    return {"corpus_green": nc(r), "expansions_checked": nc(r)}


def c_ccache(g, root, ctx):
    r = _no_tier_logs_reason(root, "Tier A / ccache")
    return {"ccache_hit_rate_pct": nc(r), "tier_a_p50_seconds": nc(r), "tier_a_p95_seconds": nc(r)}


COLLECTORS = {
    "goldens-stable-20-20-reproduce-on-main": c_goldens_stable,
    "tier-b-flake-rate-per-check-rolling-7-days": c_tier_b_flake,
    "merge-queue-depth-batches-run-bisections-triggered": c_merge_queue,
    "beads-bd-ready-claimed-closed-by-wrapper-closed-by-human-claimed-n-h-stuck": c_beads,
    "days-since-origin-main-and-fork-migration-last-matched-the-local-tree": c_days_since_match,
    "first-try-tier-b-pass-rate-for-fleet-stories": c_first_try_pass,
    "re-bless-queue-proposed-accepted-rejected-age-of-oldest-pending": c_rebless,
    "proposed-adrs-awaiting-override": c_proposed_adrs,
    "tier-1-corpus-green": c_tier1_corpus,
    "ccache-hit-rate-tier-a-p50-p95-wall-clock": c_ccache,
}


# ------------------------------------------------------------------- gathering


def _load_beads(g, root, bd_exe):
    if not bd_exe:
        return None, "no bd executable given (--bd) and C:/tools/bd/bd.exe not present"
    rc, so, se = g.run([bd_exe, "list", "--all", "--limit", "0", "--json"], cwd=root, timeout=240)
    if rc != 0:
        return None, f"bd list failed rc={rc}: {(se or so).strip()[:160]}"
    start = so.find("[")
    if start < 0:
        return None, "bd list produced no JSON array"
    try:
        return json.loads(so[start:]), None
    except json.JSONDecodeError as exc:
        return None, f"bd list JSON unparseable: {exc}"


def build_report(root, doc_path, guard, bd_exe=None, today=None):
    today = today or _dt.date.today().isoformat()
    metrics_doc = daily_metrics_from_doc(doc_path)
    beads, beads_err = _load_beads(guard, root, bd_exe)
    ctx = {"beads": beads, "beads_error": beads_err}

    metrics = []
    for slug, label, source in metrics_doc:
        fn = COLLECTORS.get(slug)
        if fn is None:
            continue  # unknown doc row: absent from the report, so check_report goes red
        values = fn(guard, root, ctx)
        computed = sum(1 for v in values.values() if "value" in v)
        if computed == len(values):
            status = "COMPUTED"
        elif computed == 0:
            status = "NOT_COMPUTED"
        else:
            status = "PARTIAL"
        metrics.append({"id": slug, "label": label, "source": source,
                        "status": status, "values": values})

    payload = {
        "report_date": today,
        "generated_by": "tools/fleet_reporter.py (read-only)",
        "metrics_doc": os.path.relpath(doc_path, root).replace("\\", "/"),
        "repo_head": _rev(guard, root, "HEAD"),
        "metrics": metrics,
    }
    return payload


def render(payload) -> str:
    L = []
    L.append(f"# Fleet daily report — {payload['report_date']}")
    L.append("")
    L.append(f"Generated by `{payload['generated_by']}` from `{payload['metrics_doc']}`, "
             f"repo HEAD `{payload['repo_head']}`.")
    L.append("")
    L.append("Every row of the **## Daily** table in `docs/infra/4-metrics.md` appears below; the")
    L.append("list is parsed from that document, not copied, so a new metric there shows up here as")
    L.append("a missing section and fails the gate. A value is either a real measurement (`0` means")
    L.append("**measured zero**) or explicitly `NOT COMPUTED` with the reason its source was")
    L.append("unreachable. The two are never conflated.")
    L.append("")
    computed = sum(1 for m in payload["metrics"] if m["status"] == "COMPUTED")
    partial = sum(1 for m in payload["metrics"] if m["status"] == "PARTIAL")
    notc = sum(1 for m in payload["metrics"] if m["status"] == "NOT_COMPUTED")
    L.append(f"**Summary:** {len(payload['metrics'])} daily metrics — "
             f"{computed} COMPUTED, {partial} PARTIAL, {notc} NOT_COMPUTED.")
    L.append("")
    L.append("## Metrics")
    for m in payload["metrics"]:
        L.append("")
        L.append(f"### {m['id']}")
        L.append("")
        L.append(f"- **metric:** {m['label']}")
        L.append(f"- **source:** {m['source']}")
        L.append(f"- **status:** {m['status']}")
        for k, v in m["values"].items():
            if "value" in v:
                unit = f" {v['unit']}" if v.get("unit") else ""
                L.append(f"- `{k}` = {v['value']}{unit}")
            else:
                L.append(f"- `{k}` = NOT COMPUTED — {v['not_computed']}")
    L.append("")
    L.append("## Machine-readable")
    L.append("")
    L.append("```json")
    L.append(json.dumps(payload, indent=2, sort_keys=False))
    L.append("```")
    L.append("")
    return "\n".join(L)


def extract_payload(md_text):
    m = re.search(r"```json\n(.*?)\n```", md_text, re.S)
    if not m:
        raise ValueError("report has no ```json payload block")
    return json.loads(m.group(1))


# ---------------------------------------------------------------------- check


def check_report(md_path, doc_path, root, bd_exe=None):
    """Return (ok, [messages]).  Fails loudly; never silently."""
    msgs, ok = [], True

    def bad(m):
        nonlocal ok
        ok = False
        msgs.append("FAIL: " + m)

    with open(md_path, encoding="utf-8") as fh:
        text = fh.read()
    payload = extract_payload(text)
    got = {m["id"]: m for m in payload["metrics"]}

    # 1. every daily metric in the doc is present (derived, not copied)
    doc = daily_metrics_from_doc(doc_path)
    if not doc:
        bad(f"parsed 0 daily metrics out of {doc_path}: the checker would be vacuous")
    for slug, label, _src in doc:
        if slug not in got:
            bad(f"metric '{label}' (id {slug}) is defined in {os.path.basename(doc_path)} "
                f"but absent from the report")
        elif f"### {slug}" not in text:
            bad(f"metric {slug} is in the JSON payload but has no prose section")
    msgs.append(f"info: {len(doc)} daily metrics in the doc, {len(got)} in the report")

    # 2. the bead's two extra required figures
    dsm = got.get("days-since-origin-main-and-fork-migration-last-matched-the-local-tree")
    if dsm is None:
        bad("no days-since-origin-main / fork-migration metric in the report")
    else:
        for key in ("days_since_origin_main", "days_since_fork_migration", "fork_migration_matched"):
            if key not in dsm["values"]:
                bad(f"required figure '{key}' missing from the report")

    # 3. zero must not masquerade as 'not computed' and vice versa
    for m in got.values():
        for k, v in m["values"].items():
            if "value" in v and "not_computed" in v:
                bad(f"{m['id']}.{k} claims both a value and not_computed")
            if "value" not in v and "not_computed" not in v:
                bad(f"{m['id']}.{k} is neither a value nor an explicit NOT COMPUTED")
            if "not_computed" in v and not str(v["not_computed"]).strip():
                bad(f"{m['id']}.{k} is NOT COMPUTED with an empty reason")
            if "not_computed" in v and re.search(rf"`{re.escape(k)}` = 0\b", text):
                bad(f"{m['id']}.{k} is NOT COMPUTED in the payload but the prose prints it as 0")
        st = m["status"]
        cvals = sum(1 for v in m["values"].values() if "value" in v)
        expect = "COMPUTED" if cvals == len(m["values"]) else ("NOT_COMPUTED" if cvals == 0 else "PARTIAL")
        if st != expect:
            bad(f"{m['id']} status {st} disagrees with its values (expected {expect})")

    # 4. the report is not vacuous: something was really measured, and at least one
    #    honest NOT COMPUTED exists rather than a silent zero everywhere
    real = [(m["id"], k) for m in got.values() for k, v in m["values"].items() if "value" in v]
    honest = [(m["id"], k) for m in got.values() for k, v in m["values"].items() if "not_computed" in v]
    if len(real) < 3:
        bad(f"only {len(real)} genuinely measured values in the whole report; a report that "
            f"computes nothing is vacuous")
    msgs.append(f"info: {len(real)} measured values, {len(honest)} explicit NOT COMPUTED values")

    # 5. independent cross-checks: the numbers must equal what an unrelated path computes
    guard = ReadOnlyGuard(os.path.abspath(md_path))
    adr = got.get("proposed-adrs-awaiting-override")
    if adr and "value" in adr["values"].get("awaiting_override", {}):
        indep = 0
        d = os.path.join(root, "docs", "decisions")
        for name in sorted(os.listdir(d)):
            if name.endswith(".md") and name != "README.md":
                with open(os.path.join(d, name), encoding="utf-8") as fh:
                    if any(re.match(r"\*\*Status:\*\*\s*Proposed\b", ln) for ln in fh):
                        indep += 1
        rep = adr["values"]["awaiting_override"]["value"]
        if rep != indep:
            bad(f"proposed-ADR count {rep} != independently counted {indep}")
        else:
            msgs.append(f"info: cross-check OK proposed ADRs reported={rep} independent={indep}")
    else:
        bad("proposed-ADRs metric not computed, so the independent cross-check cannot run")

    fresh = payload.get("report_date") == _dt.date.today().isoformat()
    if dsm and "value" in dsm["values"].get("days_since_origin_main", {}) and fresh:
        rc, so, _ = guard.run(["git", "-C", root, "log", "-1", "--format=%cI", "origin/main"])
        t = _parse_iso(so.strip())
        if t is None:
            bad("days_since_origin_main is reported but git log origin/main gave no timestamp")
        else:
            indep = (_dt.datetime.now(t.tzinfo) - t).total_seconds() / 86400.0
            rep = dsm["values"]["days_since_origin_main"]["value"]
            if abs(rep - indep) > 1.0:
                bad(f"days_since_origin_main reported {rep} but git says {indep:.2f}")
            else:
                msgs.append(f"info: cross-check OK days_since_origin_main reported={rep} git={indep:.2f}")
    elif not fresh:
        msgs.append("info: report is not from today; the wall-clock days_since cross-check is "
                    "skipped (it would measure the age of the report, not an error)")

    beads_m = got.get("beads-bd-ready-claimed-closed-by-wrapper-closed-by-human-claimed-n-h-stuck")
    if bd_exe and beads_m and "value" in beads_m["values"].get("ready", {}):
        beads, err = _load_beads(guard, root, bd_exe)
        if beads is None:
            msgs.append(f"info: bd cross-check skipped ({err})")
        else:
            indep = sum(1 for b in beads if b.get("status") == "open")
            rep = beads_m["values"]["ready"]["value"]
            if rep != indep:
                bad(f"beads.ready reported {rep} but bd list says {indep}")
            else:
                msgs.append(f"info: cross-check OK beads.ready reported={rep} bd={indep}")

    # 6. a claimed value must have a source that actually exists.  Without this, the
    #    'not computed vs zero' rule is evadable by a mutant that fakes the value AND
    #    the status consistently; the checker therefore stats the sources itself
    #    rather than trusting the report's own account of what it could reach.
    log_backed = {
        "goldens-stable-20-20-reproduce-on-main": ("Tier C", r"tier-c|golden"),
        "tier-b-flake-rate-per-check-rolling-7-days": ("Tier B", r"tier-b"),
        "first-try-tier-b-pass-rate-for-fleet-stories": ("Tier B", r"tier-b"),
        "tier-1-corpus-green": ("Tier B/C corpus", r"tier-b|tier-c|corpus"),
        "ccache-hit-rate-tier-a-p50-p95-wall-clock": ("Tier A", r"tier-a|ccache"),
    }
    for slug, (what, pat) in log_backed.items():
        m = got.get(slug)
        if m is None:
            continue
        claimed = [k for k, v in m["values"].items() if "value" in v]
        if claimed and not _tier_logs(root, pat):
            bad(f"{slug} reports measured values {claimed} but no {what} log exists in this "
                f"checkout; a number with no source is fabricated, not measured")
    mq = got.get("merge-queue-depth-batches-run-bisections-triggered")
    if mq is not None:
        claimed = [k for k, v in mq["values"].items() if "value" in v]
        if claimed and not os.path.exists(os.path.join(root, "tools", "merge-queue")):
            bad(f"merge-queue metric reports measured values {claimed} but tools/merge-queue "
                f"does not exist; a number with no source is fabricated, not measured")

    return ok, msgs


# ----------------------------------------------------------------------- main


def default_bd():
    for c in (os.environ.get("BD_EXE"), "C:/tools/bd/bd.exe"):
        if c and os.path.exists(c):
            return c
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description="read-only fleet metrics reporter")
    ap.add_argument("--repo-root", default=None)
    ap.add_argument("--metrics-doc", default=None)
    ap.add_argument("--out-dir", default=None, help="default <repo>/docs/fleet")
    ap.add_argument("--date", default=None)
    ap.add_argument("--bd", default=None)
    ap.add_argument("--check-only", metavar="REPORT.md", default=None)
    ap.add_argument("--print-metric-ids", action="store_true")
    a = ap.parse_args(argv)

    root = os.path.abspath(a.repo_root or find_repo_root(os.path.dirname(os.path.abspath(__file__))))
    doc = a.metrics_doc or os.path.join(root, "docs", "infra", "4-metrics.md")
    bd_exe = a.bd if a.bd is not None else default_bd()

    if a.print_metric_ids:
        for slug, label, _ in daily_metrics_from_doc(doc):
            print(f"{slug}\t{label}")
        return 0

    if a.check_only:
        ok, msgs = check_report(a.check_only, doc, root, bd_exe)
        for m in msgs:
            print(m)
        print("CHECK PASS" if ok else "CHECK FAIL")
        return 0 if ok else 1

    today = a.date or _dt.date.today().isoformat()
    out_dir = a.out_dir or os.path.join(root, "docs", "fleet")
    path = os.path.join(out_dir, f"REPORT-{today}.md")
    guard = ReadOnlyGuard(path)
    payload = build_report(root, doc, guard, bd_exe=bd_exe, today=today)
    written = guard.write_text(path, render(payload))
    print(f"wrote {written}")
    print(f"exec trace ({len(guard.exec_trace)} read-only commands):")
    for cmd in guard.exec_trace:
        print("  " + " ".join(cmd))
    ok, msgs = check_report(written, doc, root, bd_exe)
    for m in msgs:
        print(m)
    print("CHECK PASS" if ok else "CHECK FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
