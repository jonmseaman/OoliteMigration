"""Replaying the series/ steps onto the seriesb parents (research R3, R4).

Step k's tree is a 3-way merge: base = the old step's parent tree, ours = the new parent's tree (the
previous seriesb step's, or the last parent's), theirs = the old step's tree. Conflicts are resolved
by stored whole-file resolutions (trees.target_tree), by a step's `rules` (every conflict under the
rule's globs takes the old step's side, recorded as theirs-rule with the rule's reason), or by hand
with `tree --record`. Each step starts as one commit on its parent; after a `git town sync` it also
carries the sync's merges, and `build` will not reset it without `reset=True`.
"""
import contextlib
import fnmatch
import json
import os
import subprocess

from tools.series import profile, seriesb, stack, trees

EMPTY_BLOB = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
ERA_MAP = {"objc-spidermonkey": "objc-quickjs"}  # no seriesb step has SpiderMonkey (research R7)
STATE_FIELDS = ("resolutions", "rules", "reasons", "differs_from_old", "build_commit", "target_tree", "merge_tree",
                "verification", "size", "state")


def _git(repo, *args, ok=(0,), inp=None):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8",
                       errors="surrogateescape", input=inp)
    if r.returncode not in ok:
        raise SystemExit(f"git {' '.join(args)}: {(r.stderr or r.stdout).strip()[-600:]}")
    return r.stdout.strip()


def _sha(repo, ref):
    r = subprocess.run(["git", "-C", repo, "rev-parse", "-q", "--verify", ref], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


@contextlib.contextmanager
def active(m):
    """The seriesb profile for the duration (stack.make_step and renumber read it)."""
    before = profile.current()
    profile.activate("seriesb", m)
    try:
        yield
    finally:
        profile.activate(before)


def slug_of(branch):
    return branch.split("/", 1)[1].split("-", 1)[1]


def res_dir(series_dir, step):
    return os.path.join(series_dir, "resolutions", f"{step['n']:03d}")


# --- planning ------------------------------------------------------------------------------------

def cut(repo, m, old_m):
    """One planned replay step per old step not in `dropped`, in order; keeps the state of steps
    already planned (matched by old step)."""
    have = {s["source"]["old_step"]: s for s in m.get("steps", [])}
    dropped = {d["old_step"] for d in m.get("dropped", [])}
    steps = []
    for o in old_m["steps"]:
        if o["n"] in dropped:
            continue
        n = len(steps) + 1
        slug = slug_of(o["branch"])
        prev = have.get(o["n"], {})
        s = {"n": n, "branch": f"seriesb/{n:03d}-{slug}", "kind": o["kind"],
             "title": prev.get("title") or o["title"], "mechanical_command": o.get("mechanical_command"),
             "chapter": o.get("chapter"), "era": ERA_MAP.get(o.get("era"), o.get("era")),
             "description": f"series/pr/{n:03d}-{slug}.md",
             "source": {"type": "replay", "old_step": o["n"], "old_branch": o["branch"],
                        "old_commit": _git(repo, "rev-parse", f"refs/heads/{o['branch']}")}}
        keep = prev.get("branch") == s["branch"] and prev.get("source", {}).get("old_commit") == s["source"]["old_commit"]
        for k in STATE_FIELDS:
            s[k] = prev.get(k) if keep and k in prev else ([] if k in ("resolutions", "rules", "differs_from_old")
                                                          else {} if k == "reasons" else None)
        s["state"] = s["state"] or "planned"
        steps.append(s)
    root = seriesb.root(m)
    for i, s in enumerate(steps):
        s["parent"] = root if i == 0 else steps[i - 1]["branch"]
    m["steps"] = steps
    return m


# --- trees ---------------------------------------------------------------------------------------

def parent_tree(repo, m, step):
    i = step["n"] - 1
    if i == 0:
        return _git(repo, "rev-parse", f"refs/heads/{seriesb.root(m)}^{{tree}}")
    prev = m["steps"][i - 1]
    if not prev.get("merge_tree"):
        raise SystemExit(f"step {step['n']}: step {prev['n']} has no tree yet; run `tree {prev['n']}` first")
    return prev["merge_tree"]


def inputs(repo, m, step):
    """(base, ours, theirs) trees of the step's replay merge."""
    old = step["source"]["old_commit"]
    return (_git(repo, "rev-parse", f"{old}~1^{{tree}}"), parent_tree(repo, m, step),
            _git(repo, "rev-parse", f"{old}^{{tree}}"))


def _matches(path, globs):
    return any(fnmatch.fnmatchcase(path, g) for g in globs)


def rule_globs(step):
    return [g for r in step.get("rules", []) for g in r["paths"]]


def add_rule(step, globs, reason, side="theirs"):
    if side != "theirs":
        raise ValueError("only the old step's side (theirs) can be a rule")
    if not str(reason or "").strip():
        raise SystemExit("a rule needs a reason")
    step.setdefault("rules", [])
    for r in step["rules"]:
        if r["paths"] == list(globs):
            r["reason"] = reason
            return
    step["rules"].append({"paths": list(globs), "side": side, "reason": reason})


def _apply_rules(repo, step, base, ours, theirs, rdir):
    """Store, as whole-file resolutions, the old step's side of every conflict under a rule's globs."""
    globs = rule_globs(step)
    if not globs:
        return
    _, conflicts = trees.merge(repo, base, ours, theirs)
    index = trees._load_index(rdir)
    changed = False
    for path, key in conflicts.items():
        if not _matches(path, globs):
            continue
        rec = index.get(path)
        if rec and not rec.get("extra") and all(rec.get(k) == v for k, v in key.items()):
            continue
        index[path] = dict(key, deleted=key["theirs"] is None)
        if key["theirs"] is not None:
            target = os.path.join(rdir, "files", path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            data = subprocess.run(["git", "-C", repo, "cat-file", "blob", key["theirs"]], capture_output=True,
                                  check=True).stdout
            with open(target, "wb") as f:
                f.write(data)
        changed = True
    if changed:
        os.makedirs(rdir, exist_ok=True)
        with open(os.path.join(rdir, "index.json"), "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(index, indent=1, sort_keys=True) + "\n")


def rule_reason(step, path):
    for r in step.get("rules", []):
        if _matches(path, r["paths"]):
            return r["reason"]
    return None


def compute(repo, m, step, series_dir):
    """(tree or None, unresolved paths, [(path, how)]). Records the tree and resolutions in the step;
    a changed tree invalidates later steps' trees."""
    rdir = res_dir(series_dir, step)
    base, ours, theirs = inputs(repo, m, step)
    _apply_rules(repo, step, base, ours, theirs, rdir)
    report = []
    tree, conflicts = trees.target_tree(repo, base, ours, theirs, rdir, report=report)
    globs = rule_globs(step)
    report = [(p, "theirs-rule" if how == "stored" and _matches(p, globs) else how) for p, how in report]
    if tree is None:
        return None, conflicts, report
    reasons = step.get("reasons") or {}
    resolved = []
    for p, how in sorted(report):
        why = rule_reason(step, p) if how == "theirs-rule" else reasons.get(p) or (
            None if how == "stored" else f"merged automatically ({how})")
        resolved.append({"path": p, "how": how, "reason": why})
    if step.get("target_tree") != tree:
        for later in m["steps"][step["n"]:]:
            later["target_tree"] = later["merge_tree"] = None
    step["target_tree"] = step["merge_tree"] = tree
    step["resolutions"] = resolved
    if step.get("state") in (None, "planned"):
        step["state"] = "computed"
    return tree, [], report


def _changes(repo, a, b):
    """{path: (before blob, after blob)} for paths that differ between trees a and b."""
    out = {}
    raw = subprocess.run(["git", "-C", repo, "diff", "--raw", "--no-renames", "-z", "--abbrev=40", a, b],
                         capture_output=True, check=True).stdout.decode("utf-8", "surrogateescape").split("\0")
    i = 0
    while i < len(raw) - 1:
        meta, path = raw[i], raw[i + 1]
        i += 2
        _m1, _m2, before, after, _status = meta.lstrip(":").split()
        z = "0" * 40
        out[path] = (None if before == z else before, None if after == z else after)
    return out


def _hunks(repo, before, after):
    """The +/- lines of the change from blob `before` to blob `after` (None = absent): a change's
    content without its line numbers or context."""
    r = subprocess.run(["git", "-C", repo, "diff", "-U0", "--no-color", before or EMPTY_BLOB, after or EMPTY_BLOB],
                       capture_output=True)
    lines = r.stdout.decode("utf-8", "surrogateescape").splitlines()
    keep = [l for l in lines if l[:1] in "+-" and not l.startswith(("+++", "---"))]
    if not keep and r.stdout:  # binary: the blobs are the change
        keep = [f"binary {before} {after}"]
    return keep


def differs(repo, m, step):
    """[{path, reason}] where this step's change differs from its old step's change (SC-006).
    A reason is None when nothing explains the difference."""
    old = step["source"]["old_commit"]
    old_parent, old_tree = _git(repo, "rev-parse", f"{old}~1^{{tree}}"), _git(repo, "rev-parse", f"{old}^{{tree}}")
    new_parent, new_tree = parent_tree(repo, m, step), step["target_tree"]
    a, b = _changes(repo, old_parent, old_tree), _changes(repo, new_parent, new_tree)
    res = {r["path"]: r for r in step.get("resolutions", [])}
    adds = [(e["path_glob"], e) for e in m.get("additions", []) if e.get("path_glob")]
    blob = lambda t, p: _sha(repo, f"{t}:{p}")
    out = []
    for p in sorted(set(a) | set(b)):
        ca, cb = a.get(p), b.get(p)
        if ca == cb:
            continue
        if ca and cb and _hunks(repo, *ca) == _hunks(repo, *cb):
            continue
        if p in res:
            r = res[p]
            why = f"conflict resolved ({r['how']})" + (f": {r['reason']}" if r.get("reason") else "")
        elif any(fnmatch.fnmatchcase(p, g) for g, _ in adds):
            e = next(e for g, e in adds if fnmatch.fnmatchcase(p, g))
            why = f"addition kept from #{e.get('from_pr')}: {e.get('reason')}"
        elif blob(old_parent, p) != blob(new_parent, p):
            why = ("the parent's text differs here (#767/#768, or an earlier step's resolution); "
                   "the step's own edit merged cleanly")
        else:
            why = None
        out.append({"path": p, "reason": why})
    return out


# --- branches ------------------------------------------------------------------------------------

def message(step):
    """The step commit's message: the title, what it covers, and the old step it replays. No bead ids
    and no text from the old commit's message (spec FR-013)."""
    ch = step.get("chapter")
    if ch:
        body = f"Migration phase {ch['phase'].lstrip('P')}: " + "; ".join(ch["work_items"]) + "."
    elif step.get("kind") == "mechanical":
        body = "A mechanical change: " + str(step.get("mechanical_command")) + "."
    else:
        body = "Changes made on the fork after the migration."
    return f"{step['title']}\n\n{body}\n\nThe same change as {step['source']['old_branch']}, on upstream's QuickJS-ng PRs.\n"


def build(repo, m, step, series_dir, worktree, reset=False):
    """Create or reset the step's branch (one commit on its parent); 'built' or 'unchanged'."""
    blocked = [p["branch"] for p in seriesb.live_parents(m) if p.get("gate") not in seriesb.GATE_OK]
    if blocked:
        raise SystemExit(f"build: parent gate not passed for {', '.join(blocked)} (gate G1, spec FR-003a)")
    if not step.get("target_tree"):
        tree, conflicts, _ = compute(repo, m, step, series_dir)
        if conflicts:
            raise SystemExit(f"build {step['n']}: {len(conflicts)} unresolved conflicts; run `tree {step['n']}`")
    tree, msg = step["target_tree"], message(step)
    parent_tip = _git(repo, "rev-parse", f"refs/heads/{step['parent']}")
    tip = _sha(repo, f"refs/heads/{step['branch']}")
    if tip:
        if step.get("build_commit") and tip != step["build_commit"] and not reset:
            raise SystemExit(f"build {step['n']}: {step['branch']} has commits after its build (a sync); "
                             "it is not reset without --reset")
        same = (_git(repo, "rev-parse", f"{tip}^{{tree}}") == tree and _git(repo, "rev-parse", f"{tip}^") == parent_tip
                and _git(repo, "log", "-1", "--format=%B", tip).strip() == msg.strip()
                and stack.lineage(repo, step["branch"]) == step["parent"])
        if same:
            return "unchanged"
    with active(m):
        step["build_commit"] = stack.make_step(repo, worktree, step["branch"], step["parent"], tree, msg)
    step["state"] = "built"
    step["verification"] = None
    return "built"


def drop(repo, m, n, covered_by, reason, series_dir):
    """Move step n to `dropped` when its replayed tree equals its parent's (spec FR-005), and renumber."""
    step = m["steps"][n - 1]
    if not step.get("target_tree"):
        raise SystemExit(f"drop {n}: compute its tree first (`tree {n}`)")
    if step["target_tree"] != parent_tree(repo, m, step):
        raise SystemExit(f"drop {n}: the replayed tree differs from its parent's; it is not covered")
    if _sha(repo, f"refs/heads/{step['branch']}"):
        raise SystemExit(f"drop {n}: {step['branch']} is built; a built step is not dropped")
    if not str(reason or "").strip():
        raise SystemExit("drop: give a reason")
    m.setdefault("dropped", []).append({"old_step": step["source"]["old_step"], "old_branch": step["source"]["old_branch"],
                                        "title": step["title"], "covered_by": int(covered_by), "reason": reason})
    m["steps"].pop(n - 1)
    for i, s in enumerate(m["steps"], 1):
        s["n"] = i
    from tools.series import renumber
    with active(m):
        renumber.apply(repo, series_dir, m, seriesb.root(m))
    return m
