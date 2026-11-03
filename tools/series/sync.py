"""Recording a `git town sync --stack` of the seriesb stack (research R2, R9; docs/series-sync.md).

The sync itself is Jon's command, or an agent's with `--detached --no-push`; this module only
records what it did: the parents' heads before and after, the conflicts resolved by hand (step,
path, reason), and that every step must be verified again (spec FR-011).
"""
import datetime

from tools.series import seriesb


def _heads(repo, m):
    from tools.series.parents import _sha
    return {p["branch"]: _sha(repo, f"refs/heads/{p['branch']}") for p in seriesb.live_parents(m)}


def record(repo, m, command, conflicts):
    """Append a sync record; conflicts are (step, path, reason). Marks every step stale."""
    after = _heads(repo, m)
    pending = m.pop("pending_sync", None) or {}
    before = pending.get("before") or (m["syncs"][-1]["parent_heads_after"] if m.get("syncs") else after)
    root = seriesb.root(m)
    changed = []
    if before.get(root) and after.get(root) and before[root] != after[root]:
        from tools.series.parents import _out
        changed = _out(repo, "diff", "--name-only", "--no-renames", before[root], after[root]).splitlines()
    entry = {"date": datetime.date.today().isoformat(), "command": command,
             "parent_heads_before": before, "parent_heads_after": after,
             "upstream_paths": changed,
             "conflicts": [{"step": int(s), "path": p, "reason": r} for s, p, r in conflicts]}
    for s, p, r in conflicts:
        if not str(r or "").strip():
            raise SystemExit(f"sync-record: the conflict at step {s} {p} has no reason")
    m.setdefault("syncs", []).append(entry)
    for s in m.get("steps", []):
        s["state"] = "stale"
    for p in seriesb.live_parents(m):
        if p.get("kind") == "upstream":
            p["head"] = after.get(p["branch"], p.get("head"))
    return entry


def parse_conflict(text):
    """STEP:PATH:REASON (the path may not contain a colon; the reason may)."""
    step, _, rest = text.partition(":")
    path, _, reason = rest.partition(":")
    if not step.isdigit() or not path or not reason.strip():
        raise SystemExit(f"sync-record: --conflict wants STEP:PATH:REASON, got {text!r}")
    return int(step), path, reason.strip()
