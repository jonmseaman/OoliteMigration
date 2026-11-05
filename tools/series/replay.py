"""Replaying the series/ steps onto the seriesb parents (research R3, R4).

Step k's tree is a 3-way merge: base = the old step's parent tree, ours = the new parent's tree (the
previous seriesb step's, or the last parent's), theirs = the old step's tree. Conflicts are resolved
by stored whole-file resolutions (trees.target_tree), by a step's `rules` (every conflict under the
rule's globs takes the old step's side, recorded as theirs-rule with the rule's reason), or by hand
with `tree --record`. Each step starts as one commit on its parent; after a `git town sync` it also
carries the sync's merges, and `build` will not reset it without `reset=True`.

The last step may be the switch (source type "target", set by `set_target`): its tree is a target
branch's tree, with the exclusions' reverts applied and every exclusion and addition path as the
parent has it. It replays no old step; its test changes are listed in its test ledger (FR-015).
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


def is_target(step):
    return (step.get("source") or {}).get("type") == "target"


def _reset_state(s):
    for k in STATE_FIELDS:
        s[k] = [] if k in ("resolutions", "rules", "differs_from_old") else {} if k == "reasons" else None
    s["state"] = "planned"


def slug_of(branch):
    return branch.split("/", 1)[1].split("-", 1)[1]


def res_dir(series_dir, step):
    return os.path.join(series_dir, "resolutions", f"{seriesb.branch_number(step):03d}")


# --- planning ------------------------------------------------------------------------------------

def cut(repo, m, old_m):
    """One planned replay step per old step not in `dropped`, in order; keeps the state of steps
    already planned (matched by old step)."""
    have = {s["source"]["old_step"]: s for s in m.get("steps", []) if not is_target(s)}
    targets = [s for s in m.get("steps", []) if is_target(s)]
    dropped = {d["old_step"] for d in m.get("dropped", [])}
    folded = {n for f in m.get("folded", []) for n in f["old_steps"]}
    into = {f["into_old_step"]: f for f in m.get("folded", [])}
    by_n = {o["n"]: o for o in old_m["steps"]}
    steps = []
    for o in old_m["steps"]:
        if o["n"] in dropped or o["n"] in folded:
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
        f = into.get(o["n"])
        if f:
            first = by_n[min(f["old_steps"])]
            s["source"]["old_steps"] = sorted(f["old_steps"]) + [o["n"]]
            s["source"]["old_from_commit"] = _git(repo, "rev-parse", f"refs/heads/{first['branch']}")
            if f.get("title"):
                s["title"] = prev.get("title") if prev.get("title") and prev.get("title") != o["title"] else f["title"]
        keep = (prev.get("branch") == s["branch"] and prev.get("source", {}).get("old_commit") == s["source"]["old_commit"]
                and prev.get("source", {}).get("old_steps") == s["source"].get("old_steps"))
        for k in STATE_FIELDS:
            s[k] = prev.get(k) if keep and k in prev else ([] if k in ("resolutions", "rules", "differs_from_old")
                                                          else {} if k == "reasons" else None)
        s["state"] = s["state"] or "planned"
        if keep and prev.get("take_old"):  # a recorded resolution, like the rules
            s["take_old"] = prev["take_old"]
        steps.append(s)
    for t in targets:  # the switch stays last
        n = len(steps) + 1
        slug = slug_of(t["branch"])
        branch = f"seriesb/{n:03d}-{slug}"
        if t["branch"] != branch:
            _reset_state(t)
        t.update(n=n, branch=branch, description=f"series/pr/{n:03d}-{slug}.md")
        steps.append(t)
    root = seriesb.root(m)
    for i, s in enumerate(steps):
        s["parent"] = root if i == 0 else steps[i - 1]["branch"]
    m["steps"] = steps
    return m


def set_target(repo, m, ref, title, slug, test_ledger):
    """Add the switch step last, or update it: its tree is `ref`'s (see the module docstring)."""
    if not str(title or "").strip() or not str(slug or "").strip():
        raise SystemExit("target: give a title and a slug")
    commit = _git(repo, "rev-parse", f"{ref}^{{commit}}")
    steps = m.setdefault("steps", [])
    s = next((x for x in steps if is_target(x)), None)
    if s is None:
        n = len(steps) + 1
        s = {"n": n, "branch": f"seriesb/{n:03d}-{slug}", "kind": "hand-written", "title": title,
             "mechanical_command": None, "chapter": None, "era": steps[-1].get("era") if steps else None,
             "description": f"series/pr/{n:03d}-{slug}.md",
             "parent": steps[-1]["branch"] if steps else seriesb.root(m)}
        _reset_state(s)
        steps.append(s)
    elif (s["source"].get("commit"), slug_of(s["branch"])) != (commit, slug):
        _reset_state(s)
        s["branch"] = f"seriesb/{s['n']:03d}-{slug}"
        s["description"] = f"series/pr/{s['n']:03d}-{slug}.md"
    s["title"] = title
    s["source"] = {"type": "target", "ref": ref, "commit": commit, "test_ledger": test_ledger}
    return s


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
    if is_target(step):
        raise SystemExit(f"step {step['n']} is the switch to {step['source']['ref']}: it has no replay merge")
    old = step["source"]["old_commit"]
    first = step["source"].get("old_from_commit") or old
    return (_git(repo, "rev-parse", f"{first}~1^{{tree}}"), parent_tree(repo, m, step),
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


def fold(repo, m, old_m, first_old, into_old, title, reason):
    """Fold old steps first_old..into_old-1 into the step for into_old: one seriesb step whose change
    is the whole range's. Re-cuts the plan."""
    if not (0 < first_old < into_old):
        raise SystemExit("fold: the range must name at least two old steps")
    if not str(reason or "").strip():
        raise SystemExit("fold: give a reason")
    m.setdefault("folded", [])
    m["folded"] = [f for f in m["folded"] if f["into_old_step"] != into_old]
    m["folded"].append({"old_steps": list(range(first_old, into_old)), "into_old_step": into_old, "reason": reason})
    for s in m.get("steps", []):
        if s["source"]["old_step"] == into_old:
            s["title"] = title
    cut(repo, m, old_m)
    for s in m["steps"]:
        if s["source"]["old_step"] == into_old:
            s["title"] = title
    return m


def take_old(step, keep, reason):
    """The step's tree is its old step's tree whole, with the `keep` globs as the parent has them."""
    if not str(reason or "").strip():
        raise SystemExit("take-old: give a reason")
    step["take_old"] = {"keep": list(keep), "reason": reason}


def rule_reason(step, path):
    for r in step.get("rules", []):
        if _matches(path, r["paths"]):
            return r["reason"]
    return None


def compute(repo, m, step, series_dir):
    """(tree or None, unresolved paths, [(path, how)]). Records the tree and resolutions in the step;
    a changed tree invalidates later steps' trees."""
    if is_target(step):
        return _compute_target(repo, m, step)
    rdir = res_dir(series_dir, step)
    base, ours, theirs = inputs(repo, m, step)
    report = []
    if step.get("take_old"):
        # the old step's tree whole, with the kept paths as the parent has them (research R4)
        tree, conflicts = trees.take_paths(repo, theirs, ours, step["take_old"]["keep"]), []
    else:
        _apply_rules(repo, step, base, ours, theirs, rdir)
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


def _set_tree(m, step, tree):
    if step.get("target_tree") != tree:
        for later in m["steps"][step["n"]:]:
            later["target_tree"] = later["merge_tree"] = None
    step["target_tree"] = step["merge_tree"] = tree
    if step.get("state") in (None, "planned"):
        step["state"] = "computed"


def target_tree(repo, m, step):
    """The switch step's tree: the target's, with the exclusions' reverts applied and every exclusion
    and addition path as the parent has it (the final-tree rule, read backwards)."""
    tree = _git(repo, "rev-parse", f"{step['source']['commit']}^{{tree}}")
    for e in m.get("exclusions", []):
        if e.get("revert_commit"):
            tree = trees.revert(repo, tree, e["revert_commit"])
    globs = [e["path_glob"] for e in m.get("exclusions", []) + m.get("additions", []) if e.get("path_glob")]
    return trees.take_paths(repo, tree, parent_tree(repo, m, step), globs)


def _compute_target(repo, m, step):
    tree = target_tree(repo, m, step)
    _set_tree(m, step, tree)
    step["resolutions"] = []
    return tree, [], []


def ledger_paths(step, section=None):
    """The paths the step's test ledger lists (any `path` in a table row's first cell). With
    `section` (a replayed step, spec FR-017), only the rows under the heading `## <section>`, up to
    the next `## ` heading."""
    import re
    path = step["source"].get("test_ledger") or ""
    if not os.path.isabs(path):
        path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), path)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if section is not None:
        inside, kept = False, []
        for line in lines:
            if line.startswith("## "):
                inside = line[3:].strip().startswith(section)
            elif inside:
                kept.append(line)
        lines = kept
    return {p.strip("`") for row in lines if row.startswith("|")
            for p in re.split(r",\s*", row.split("|")[1].strip())}


def ledger_section(step):
    """The ledger heading a replayed step's rows sit under."""
    return f"Step {seriesb.branch_number(step):03d}"


def unlisted_tests(repo, step, parent, tree):
    """Existing tests the switch step modifies or deletes that its ledger does not list (FR-015).
    A ledger row may name a file by its path, or by its name alone."""
    listed = ledger_paths(step)
    if listed is None:
        return ["(no test ledger at " + str(step["source"].get("test_ledger")) + ")"]
    out = []
    for line in _git(repo, "diff", "--name-status", "--no-renames", parent, tree, "--", "tests/").splitlines():
        status, p = line.split("\t", 1)
        if status != "A" and p not in listed and os.path.basename(p) not in listed:
            out.append(p)
    return out


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
    A reason is None when nothing explains the difference. The switch replays nothing: []."""
    if is_target(step):
        return []
    old = step["source"]["old_commit"]
    first = step["source"].get("old_from_commit") or old
    old_parent, old_tree = _git(repo, "rev-parse", f"{first}~1^{{tree}}"), _git(repo, "rev-parse", f"{old}^{{tree}}")
    took = step.get("take_old")
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
        if took and not _matches(p, took["keep"]):
            why = f"the step takes the old step's tree whole: {took['reason']}"
        elif p in res:
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


# --- verification --------------------------------------------------------------------------------

def resolution_paths(series_dir, step):
    index = os.path.join(res_dir(series_dir, step), "index.json")
    if not os.path.exists(index):
        return []
    with open(index, encoding="utf-8") as f:
        return sorted(json.load(f))


def integrity(repo, m, step, series_dir):
    """Research R11's construction checks for a replayed step: its tests are the old step's, the
    parent's, or their clean merge; no new warning suppression the old step lacks; no new
    SpiderMonkey or gnustep-base dependency; src/ is clang-format clean (but for the reformat)."""
    from tools.series import normalise, verify
    tree = _git(repo, "rev-parse", f"refs/heads/{step['branch']}^{{tree}}")
    parent = _git(repo, "rev-parse", f"refs/heads/{step['parent']}^{{tree}}")
    if is_target(step):
        bad = unlisted_tests(repo, step, parent, tree)
        out = {
            "tests_untouched": ("pass: every changed test is in the test ledger (FR-015)" if not bad
                                else "fail: not in the test ledger: " + ", ".join(bad[:8])),
            # the parent is the only source: the switch may bring no suppression at all
            "no_new_suppressions": verify.check_no_new_suppressions(repo, parent, tree, parent),
            "no_new_spidermonkey_or_gnustep": verify.check_no_new_legacy(repo, parent, tree),
            "clang_format": verify.check_clang_format(repo, tree, normalise.normalise_tree(repo, tree, tree)),
            "no_facade": verify.check_no_facade(repo, tree),
        }
        return out
    base, ours, theirs = inputs(repo, m, step)
    allowed = ()
    if step["source"].get("test_ledger"):
        allowed = ledger_paths(step, ledger_section(step)) or ()
    out = {
        "tests_untouched": verify.check_tests_untouched(repo, tree, theirs, ours, resolution_paths(series_dir, step),
                                                        base, allowed=allowed),
        "no_new_suppressions": verify.check_no_new_suppressions(repo, parent, tree, theirs),
        "no_new_spidermonkey_or_gnustep": verify.check_no_new_legacy(repo, parent, tree),
        "no_facade": verify.check_no_facade(repo, tree),
    }
    if step.get("kind") == "mechanical":
        out["clang_format"] = "n/a: the reformat step changes the style; upstream's check follows it"
    else:
        out["clang_format"] = verify.check_clang_format(repo, tree, normalise.normalise_tree(repo, tree, tree))
    return out


def parent_record(m, step):
    """The verification record of the step's parent: the previous step's, or the root parent's gate."""
    if step["n"] > 1:
        return m["steps"][step["n"] - 2].get("verification")
    root = seriesb.root(m)
    return next((p.get("verification") for p in m.get("parents", []) if p["branch"] == root), None)


# --- branches ------------------------------------------------------------------------------------

def message(step):
    """The step commit's message: the title, what it covers, and the old step it replays. No bead ids
    and no text from the old commit's message (spec FR-013)."""
    if is_target(step):
        src = step["source"]
        return (f"{step['title']}\n\nThe scripting layer moves to upstream's QuickJS-ng binding: the tree of "
                f"{src['ref']} ({src['commit'][:10]}), with the series' exclusions and additions. The tests that "
                f"change with it are listed in {os.path.basename(src.get('test_ledger') or 'the test ledger')}.\n")
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
