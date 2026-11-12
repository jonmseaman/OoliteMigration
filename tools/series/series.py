#!/usr/bin/env python3
"""Command line for the PR series: see specs/001-split-migration-prs/contracts/series-cli.md.

Exit codes: 0 success, 1 a check or verification failed, 2 usage or environment error.
Never pushes, never runs `git town sync` or `propose`, never touches develop, master or main.
"""
import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

COMMANDS = ("inventory", "cut", "hoist", "tree", "build", "verify", "describe", "check", "renumber", "parents", "gate", "drop", "fold", "sync-record")


def parser():
    p = argparse.ArgumentParser(prog="series.py", description="Build and check the migration PR series.")
    p.add_argument("--series", choices=("series", "seriesb"), default="series",
                   help="which series: feature 001's series/ (default) or feature 002's seriesb/")
    sub = p.add_subparsers(dest="command", required=True, metavar="{" + ",".join(COMMANDS) + "}")
    sub.add_parser("inventory", help="list the history's first-parent merges into series/inventory.tsv")
    c = sub.add_parser("cut", help="write the planned steps into the manifest")
    cg = c.add_mutually_exclusive_group(required=True)
    cg.add_argument("--chapters", action="store_true", help="use research R14's chapters (series)")
    cg.add_argument("--replay", action="store_true", help="one replay step per old series/ step (seriesb)")
    c.add_argument("--target", metavar="REF", help="with --replay: add or update the last step, the switch to REF's tree")
    c.add_argument("--title", help="with --target: the switch step's title")
    c.add_argument("--slug", help="with --target: the switch step's branch slug")
    c.add_argument("--test-ledger", metavar="PATH", help="with --target: the FR-015 ledger of the tests it changes")
    h = sub.add_parser("hoist", help="turn history commits into an independent step at the front")
    h.add_argument("commits", nargs="+")
    h.add_argument("--slug", required=True)
    h.add_argument("--title", help="the PR title (default: the last commit's subject)")
    t = sub.add_parser("tree", help="compute a step's target tree")
    t.add_argument("n", type=int)
    t.add_argument("--show", metavar="PATH", help="write the conflicted file and its inputs to .agent-tmp/series-resolve")
    t.add_argument("--record", metavar="PATH", help="store the edited file from .agent-tmp/series-resolve as the resolution")
    t.add_argument("--commit", metavar="LABEL", help="for a tail step: the replayed commit the conflict is in")
    t.add_argument("--reason", help="seriesb: why the recorded resolution (or rule) is right")
    t.add_argument("--rule", choices=("theirs",), help="seriesb: resolve conflicts under --paths to the old step's side")
    t.add_argument("--paths", nargs="+", metavar="GLOB", help="seriesb: the globs a --rule covers")
    t.add_argument("--take-old", action="store_true", help="seriesb: the old step's tree whole, but --keep")
    t.add_argument("--keep", nargs="+", metavar="GLOB", default=[], help="seriesb: with --take-old, paths kept as the parent has them")
    b = sub.add_parser("build", help="create or reset step branches")
    b.add_argument("steps", nargs="*", type=int)
    b.add_argument("--from", dest="from_", type=int)
    b.add_argument("--to", type=int)
    b.add_argument("--reset", action="store_true", help="seriesb: rebuild a step even after a sync added merges")
    v = sub.add_parser("verify", help="run a step's verification matrix")
    v.add_argument("n", nargs="?", type=int)
    v.add_argument("--from", dest="from_", type=int)
    v.add_argument("--to", type=int, help="seriesb: the last step to verify with --from")
    v.add_argument("--clean", action="store_true")
    v.add_argument("--integrity-only", action="store_true", help="run only the construction checks (no build)")
    d = sub.add_parser("describe", help="write a step's PR description, or the handover")
    d.add_argument("n", nargs="?", type=int)
    d.add_argument("--handover", action="store_true")
    k = sub.add_parser("check", help="validate manifest, branches, lineage and trees")
    k.add_argument("--verified", action="store_true")
    k.add_argument("--only")
    k.add_argument("--steps")
    sub.add_parser("renumber", help="renumber branches and files after inserting or removing a step")
    fo = sub.add_parser("fold", help="seriesb: fold a range of old steps into one step (research R4)")
    fo.add_argument("first_old", type=int, help="the first old step folded in")
    fo.add_argument("into_old", type=int, help="the old step the range folds into (its last)")
    fo.add_argument("--title", required=True)
    fo.add_argument("--reason", required=True)
    dr = sub.add_parser("drop", help="seriesb: drop a step whose replayed tree is its parent's (FR-005)")
    dr.add_argument("n", type=int)
    dr.add_argument("--covered-by", type=int, required=True, help="the upstream PR that covers it")
    dr.add_argument("--reason", required=True)
    pa = sub.add_parser("parents", help="seriesb: set up, refresh or report the upstream-PR parents")
    pa.add_argument("--setup", action="store_true", help="add the remote, mirror the PR heads, set lineage")
    pa.add_argument("--refresh", action="store_true", help="fetch and reset each parent to its PR head")
    pa.add_argument("--retire", action="store_true", help="once the PRs are in upstream master: step 1 onto it")
    sr = sub.add_parser("sync-record", help="seriesb: record a git town sync and its hand-resolved conflicts")
    sr.add_argument("--conflict", action="append", default=[], metavar="STEP:PATH:REASON")
    sr.add_argument("--command", dest="sync_command", default="git town sync --stack --detached --no-push")
    g = sub.add_parser("gate", help="seriesb: build and test a parent with its own CI commands (gate G1)")
    g.add_argument("parent", help="the parent branch, or its 000x stem")
    return p


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "oolite-dev")
SERIES_DIR = os.path.join(ROOT, "specs", "001-split-migration-prs", "series")
MANIFEST = os.path.join(SERIES_DIR, "manifest.json")
INVENTORY = os.path.join(SERIES_DIR, "inventory.tsv")
HISTORY_REF = "refs/series/history"
HISTORY_PREFIX = "upstream/oolite"
HISTORY_START = "4f089047c"  # the subtree add at upstream dc55e3e05
HISTORY_END = HISTORY_REF + "^"  # 338463308 itself removes the subtree
INVENTORY_COLUMNS = ("idx", "commit", "date", "bead", "phase", "subject", "upstream_under")


def read_inventory(path=INVENTORY):
    with open(path, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        return [dict(zip(header, line.rstrip("\n").split("\t"))) for line in f if line.strip()]


def cmd_inventory(args):
    from tools.series import history
    rows = history.first_parent(GAME, HISTORY_PREFIX, HISTORY_START, HISTORY_END,
                                labelled=history.load_bead_phases(ROOT))
    pull, pulled = history.HISTORY_PULLS[0]
    after = set(history.git(GAME, "rev-list", HISTORY_END, f"^{pull}^").split())
    os.makedirs(SERIES_DIR, exist_ok=True)
    with open(INVENTORY, "w", encoding="utf-8", newline="\n") as f:
        f.write("\t".join(INVENTORY_COLUMNS) + "\n")
        for i, r in enumerate(rows):
            # commits that contain the pull sit on the pulled upstream; the rest on the history's base
            contains_pull = r["commit"] in after and history.git(
                GAME, "merge-base", "--is-ancestor", pull, r["commit"], check=False).returncode == 0
            under = pulled if contains_pull else history.HISTORY_BASE_UPSTREAM
            subject = r["subject"].replace("\t", " ")
            f.write("\t".join([str(i), r["commit"], r["date"], r["bead"] or "", r["phase"], subject, under]) + "\n")
    print(f"inventory: {len(rows)} first-parent commits -> {os.path.relpath(INVENTORY, ROOT)}")
    return 0


STATE_FIELDS = ("target_tree", "merge_tree", "verification", "boundary_moved", "resolutions", "temporaries", "size", "era")


def load_manifest():
    from tools.series import manifest
    return manifest.load(MANIFEST) if os.path.exists(MANIFEST) else {}


def cmd_cut(args):
    from tools.series import profile
    if profile.current() == "seriesb" or args.replay:
        return cmd_cut_replay(args)
    from tools.series import chapters, history, manifest
    inv = read_inventory()
    idx = {r["commit"]: int(r["idx"]) for r in inv}
    full = lambda c: history.git(GAME, "rev-parse", "--verify", f"{c}^{{commit}}")
    old = {s["branch"]: s for s in load_manifest().get("steps", [])}
    steps, errors, expect = [], [], 0
    for slug, phase, title, items, first, last in chapters.HISTORY:
        f, l = full(first), full(last)
        fi, li = idx.get(f), idx.get(l)
        if fi is None or li is None:
            errors.append(f"{slug}: boundary not in the inventory")
            continue
        if fi != expect:
            errors.append(f"{slug}: starts at row {fi}, expected {expect}")
        expect = li + 1
        steps.append({"kind": "hand-written", "title": title, "slug": slug,
                      "source": {"type": "history", "from": f, "to": l},
                      "chapter": {"phase": phase, "work_items": items, "first": f, "last": l, "merges": li - fi + 1}})
    if expect != len(inv):
        errors.append(f"chapters end at row {expect - 1}, the inventory has {len(inv)} rows")
    covered = set()
    for slug, kind, title, commits, command in chapters.TAIL:
        fulls = [full(c) for c in commits]
        covered.update(fulls)
        steps.append({"kind": kind, "title": title, "slug": slug, "source": {"type": "develop", "commits": fulls},
                      "chapter": None, "mechanical_command": command})
    # every develop commit after the squash's merge must be in a tail group, or excluded
    excluded = {full(e["revert_commit"]) for e in chapters.EXCLUSIONS if "revert_commit" in e}
    squash_merge = full("0e1cc17a4")
    for c in history.git(GAME, "rev-list", "--first-parent", f"{squash_merge}..{chapters.ANCHORS['develop_target']}").split():
        if c not in covered and c not in excluded:
            errors.append(f"develop commit {c[:10]} is in no tail group")
    if errors:
        print("cut: " + "\n     ".join(errors), file=sys.stderr)
        return 1
    # hoisted steps are not in the chapters; they keep their place in front (and their state)
    hoisted = [dict(s, slug=s["branch"].split("-", 1)[1]) for s in old.values() if s.get("kind") == "independent"]
    steps = sorted(hoisted, key=lambda s: s["n"]) + steps
    for n, s in enumerate(steps, 1):
        slug = s.pop("slug")
        s["n"] = n
        s["branch"] = f"series/{n:03d}-{slug}"
        s["parent"] = manifest.ROOT_BRANCH if n == 1 else steps[n - 2]["branch"]
        s["description"] = f"series/pr/{n:03d}-{slug}.md"
        s.setdefault("mechanical_command", None)
        prev = old.get(s["branch"], {})
        for k in STATE_FIELDS:
            s[k] = prev.get(k, [] if k in ("resolutions", "temporaries") else None)
    m = load_manifest()
    m.update({"anchors": chapters.ANCHORS, "steps": steps, "exclusions": chapters.EXCLUSIONS})
    m.setdefault("ledger", [])
    problems = manifest.validate(m, order={r["commit"]: int(r["idx"]) for r in inv})
    if problems:
        print("cut: manifest invalid:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1
    manifest.save(MANIFEST, m)
    print(f"cut: {len(steps)} steps ({len(chapters.HISTORY)} history chapters, {len(chapters.TAIL)} tail)")
    return 0


def resolutions_dir(step):
    return os.path.join(SERIES_DIR, "resolutions", f"{step['n']:03d}")


def history_snap(m):
    """history commit -> the game's tree there, normalised to upstream's paths and style (N)."""
    from tools.series import history, normalise, selectors
    a = m["anchors"]
    return lambda c: normalise.normalise_tree(GAME, history.snapshot(GAME, c, a["history_prefix"]),
                                              a["format"]["style_file_from"],
                                              transform=selectors.upstream_renames,
                                              transform_id=selectors.TRANSFORM_VERSION)


def cmd_hoist(args):
    """Insert an independent step made of history commits, if they apply to the series base and to
    upstream_base alone (FR-008). Building it is `verify`'s job; `renumber` then renames the branches."""
    from tools.series import history, hoist, manifest
    m = load_manifest()
    full = lambda c: history.git(GAME, "rev-parse", "--verify", f"{c}^{{commit}}")
    commits = [full(c) for c in args.commits]
    snap = history_snap(m)
    upstream = history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{tree}}")
    try:
        hoist.hoisted_tree(GAME, upstream, commits, snap)  # alone on upstream
        tree = hoist.hoisted_tree(GAME, hoist.series_base(m, upstream), commits, snap)
    except hoist.DoesNotApply as e:
        print(f"hoist: {e}; it stays in its chapter", file=sys.stderr)
        return 1
    if any(c in (s.get("source") or {}).get("commits", []) for s in m.get("steps", []) for c in commits):
        print("hoist: already hoisted", file=sys.stderr)
        return 1
    title = args.title or history.git(GAME, "log", "-1", "--format=%s", commits[-1])
    step = hoist.insert(m, commits, args.slug, title, tree, manifest.ROOT_BRANCH, "objc-spidermonkey")
    manifest.save(MANIFEST, m)
    print(f"hoist: step {step['n']} {step['branch']} planned; run `renumber`, then `build --from {step['n']}`")
    return 0


def cmd_renumber(args):
    from tools.series import manifest, renumber
    m = load_manifest()
    moved = renumber.apply(GAME, SERIES_DIR, m, manifest.ROOT_BRANCH)
    manifest.save(MANIFEST, m)
    for old, new in moved:
        print(f"renumber: {old:03d} -> {new}")
    print(f"renumber: {len(moved)} step(s) moved")
    return 0


def merge_inputs(m, step):
    """(base, ours, theirs) trees for a history step: an incremental, rebase-style merge (research R15).

    base   = N(history at the previous chapter's boundary), or N(the history's start) for the first
    ours   = the previous step's resolved tree, or the series base for the first
    theirs = N(history at this chapter's boundary)
    """
    from tools.series import history, hoist
    a = m["anchors"]
    snap = history_snap(m)
    prev = step_by_n(m, step["n"] - 1) if step["n"] > 1 else None
    if prev is None or prev.get("kind") == "independent":
        # the series base: upstream, with the hoisted fixes in front of the first chapter
        base = snap(a["history_start"])
        ours = hoist.series_base(m, history.git(GAME, "rev-parse", f"{a['upstream_base']}^{{tree}}"))
    else:
        if prev["source"]["type"] != "history":
            raise SystemExit(f"step {step['n']}: previous step is not a history step")
        ours = prev.get("merge_tree") or prev.get("target_tree")
        if not ours:
            raise SystemExit(f"step {step['n']}: step {prev['n']} has no resolved tree yet; run `tree {prev['n']}` first")
        base = snap(prev["source"]["to"])
    theirs = snap(step["source"]["to"])
    return base, ours, theirs


def step_by_n(m, n):
    for s in m.get("steps", []):
        if s["n"] == n:
            return s
    raise SystemExit(f"no step {n}")


SQUASH = "935aedb20"  # the fork's squash of the history (the second parent of develop's 0e1cc17a4)


def tail_space(m, tree):
    """`tree` in the fork's final style (develop_target's .clang-format) and upstream's names, its
    sources and tests alike: the space the tail is replayed in. develop reformatted everything in
    Google style early (13eb19ee7, one of step 025's commits), rewrapping comments at 80 columns;
    formatting back cannot undo that, but formatting the series' own files this way gives develop's
    text, so the commits after it merge here (plan.md Notes, 2026-11-02)."""
    from tools.series import normalise, selectors
    return normalise.normalise_tree(GAME, tree, m["anchors"]["develop_target"], transform=selectors.upstream_renames,
                                    transform_id=selectors.TRANSFORM_VERSION,
                                    select=lambda p: normalise.is_source(p) or normalise.is_test_source(p),
                                    rename_only=lambda p: False)


def develop_order(m):
    """develop's commits after the squash, oldest first: the squash, then the first-parent line."""
    from tools.series import history
    full = lambda c: history.git(GAME, "rev-parse", "--verify", f"{c}^{{commit}}")
    squash = full(SQUASH)
    line = history.git(GAME, "rev-list", "--first-parent", "--reverse",
                       f"{squash}^..{m['anchors']['develop_target']}").split()
    return [squash] + [c for c in line if c != squash and c != full(f"{squash}^")]


def develop_inputs(m, step, space=None):
    """[(label, before, after)] for a tail step: its commits in develop's order, in the tail's space
    (or `space(m, tree)`). The squash's `before` is the history's last snapshot, so its pair is the
    squash gap (research R14). A merge commit counts as its change against its first parent."""
    from tools.series import history
    space = space or tail_space
    order = develop_order(m)
    commits = sorted(step["source"]["commits"], key=order.index)
    base_commit = history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{commit}}")
    out = []
    for c in commits:
        if c == order[0]:  # the squash
            last = step_by_n(m, HISTORY_STEPS_LAST(m))["source"]["to"]
            before = history.snapshot(GAME, last, m["anchors"]["history_prefix"])
        else:
            before = history.git(GAME, "rev-parse", f"{c}^1^{{tree}}")
        after = space(m, history.git(GAME, "rev-parse", f"{c}^{{tree}}"))
        out.append((c[:10], space(m, before), after))
        if history.git(GAME, "rev-parse", "-q", "--verify", f"{c}^2", check=False).stdout.strip() == base_commit:
            # develop's merge of the series' own base: the series already has upstream's side, so
            # the merge's resolution is its change against that side. Where the series and the
            # resolution differ on the same lines, the resolution is the fork's decision.
            # It also holds what develop did before it in commits of later steps (13eb19ee7's
            # .clang-format): those paths are left as they are.
            res_base = space(m, f"{base_commit}^{{tree}}")
            later = [x for x in order[:order.index(c)] if step_of_commit(m, x) > step["n"]]
            # (non-source files only: a later reformat's sources differ here only where clang-format
            # is not idempotent, and those are develop's resolution too)
            from tools.series import normalise
            paths = set()
            for x in later:
                paths |= {p for p in history.git(GAME, "diff", "--name-only", "--no-renames",
                                                 space(m, f"{x}^1^{{tree}}"), space(m, f"{x}^{{tree}}")).splitlines()
                          if not (normalise.is_source(p) or normalise.is_test_source(p))}
            from tools.series import trees
            res_after = trees.take_paths(GAME, after, res_base, [glob_escape(p) for p in sorted(paths)])
            out.append((c[:10] + "-resolution", res_base, res_after, "theirs"))
    return out


def step_of_commit(m, commit):
    for s in m["steps"]:
        if s["source"]["type"] == "develop" and commit in s["source"]["commits"]:
            return s["n"]
    return 0  # the squash's first parent and other commits in no step


def exclusion_globs(m):
    return [e["path_glob"] for e in m.get("exclusions", []) if "path_glob" in e]


def compute_merge_tree(m, step, report=None):
    """(merge tree, conflicts) for a step; `report` receives (path, "stored" | "auto") per resolved conflict."""
    from tools.series import history, trees
    if step["source"]["type"] == "history":
        base, ours, theirs = merge_inputs(m, step)
        return trees.target_tree(GAME, base, ours, theirs, resolutions_dir(step), report=report)
    if step["source"]["type"] == "hoisted":
        from tools.series import hoist
        upstream = history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{tree}}")
        earlier = {"steps": [s for s in m["steps"] if s["n"] < step["n"]]}
        try:
            return hoist.hoisted_tree(GAME, hoist.series_base(earlier, upstream), step["source"]["commits"],
                                      history_snap(m)), []
        except hoist.DoesNotApply as e:
            raise SystemExit(f"step {step['n']}: {e}")
    if step["source"]["type"] != "develop":
        raise SystemExit(f"tree: unknown source type {step['source']['type']!r}")
    base_tree = history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{tree}}")
    if step["kind"] == "mechanical":
        # the last step is the fork itself, outside the exclusions (FR-002)
        tree = history.git(GAME, "rev-parse", f"{m['anchors']['develop_target']}^{{tree}}")
        for e in m.get("exclusions", []):
            if "revert_commit" in e:
                tree = trees.revert(GAME, tree, e["revert_commit"])
        return trees.take_paths(GAME, tree, base_tree, exclusion_globs(m)), []
    prev = step_by_n(m, step["n"] - 1)
    ours = prev.get("merge_tree")
    if not ours:
        raise SystemExit(f"step {step['n']}: step {prev['n']} has no resolved tree yet; run `tree {prev['n']}` first")
    # replayed in the tail's space; a file the step does not change keeps the series' bytes (a test
    # is never reformatted by a step that does not change it), and the format pass puts changed
    # sources back in upstream's style
    ours_t = tail_space(m, ours)
    tree, conflicts = trees.replay(GAME, ours_t, develop_inputs(m, step), resolutions_dir(step), report=report)
    if conflicts:
        return None, conflicts
    # what both sides added to a header (a #pragma once, a self-contained include run) is kept once
    changed = history.git(GAME, "diff", "--name-only", "--no-renames", ours_t, tree).splitlines()
    tree = trees.dedupe_tree(GAME, tree, changed)
    nxt = step_by_n(m, step["n"] + 1) if step["n"] < len(m["steps"]) else None
    if nxt is not None and nxt["kind"] == "mechanical":
        tree = converge(m, nxt, tree, report)
    tree = trees.keep_unchanged(GAME, tree, ours_t, ours)
    tree = upstream_layout(m, step, ours, tree)
    return trees.take_paths(GAME, tree, base_tree, exclusion_globs(m)), []


def upstream_space(m, tree):
    """N_upstream(tree): upstream's style and names, as for the history's snapshots."""
    from tools.series import normalise, selectors
    return normalise.normalise_tree(GAME, tree, m["anchors"]["format"]["style_file_from"],
                                    transform=selectors.upstream_renames, transform_id=selectors.TRANSFORM_VERSION)


def upstream_layout(m, step, ours, tree):
    """`tree` (the replay in the tail's space) with each file the step changes in upstream's layout
    where that is the same content: the step's commits replayed in upstream's style, with no rules,
    merge that file cleanly and give `tree`'s text once put in the tail's style. Otherwise the file
    keeps the tail's layout (Google style's 80-column breaks, which upstream's style keeps)."""
    from tools.series import history, trees
    import tempfile
    cur, dirty = ours, set()
    with tempfile.TemporaryDirectory() as no_resolutions:
        for _label, before, after, *_ in develop_inputs(m, step, space=upstream_space):
            rep = []
            cur, left = trees.target_tree(GAME, before, cur, after, no_resolutions, report=rep, partial=True)
            # a test takes only clean merges here, never a rule's resolution (rule 1)
            dirty |= set(left) | {p for p, _how in rep if p.startswith("tests/")}
    changed = set(history.git(GAME, "diff", "--name-only", "--no-renames", ours, tree).splitlines())
    cur = trees.dedupe_tree(GAME, cur, sorted(changed))
    cur_t = tail_space(m, cur)
    blob = lambda t, p: trees._blob_at(GAME, t, p)
    take = [p for p in sorted(changed) if p not in dirty and blob(cur_t, p) == blob(tree, p)]
    return trees.take_paths(GAME, tree, cur, [glob_escape(p) for p in take])


def converge(m, mechanical, tree, report=None):
    """The last content step ends where develop does, in the tail's space: a file that still differs
    from develop (outside the exclusions, and apart from what the mechanical step's own commits
    change besides formatting) takes develop's text. What remains are merge artefacts of the
    replay; this makes the mechanical step exactly the reformat (research R14)."""
    import fnmatch
    from tools.series import history, normalise, trees
    target, _ = compute_merge_tree(m, mechanical)
    target_t = tail_space(m, target)
    # the mechanical step's own files (.clang-format, the format script); a source that still differs
    # in the tail's space differs in more than its formatting, so it converges here
    own = set()
    for _label, before, after, *_ in develop_inputs(m, mechanical):
        own |= {p for p in history.git(GAME, "diff", "--name-only", "--no-renames", before, after).splitlines()
                if not (normalise.is_source(p) or normalise.is_test_source(p))}
    excluded = lambda p: any(fnmatch.fnmatchcase(p, g) for g in exclusion_globs(m))
    left = [p for p in history.git(GAME, "diff", "--name-only", "--no-renames", tree, target_t).splitlines()
            if p not in own and not excluded(p)]
    if report is not None:
        report.extend((p, "converge") for p in left)
    return trees.take_paths(GAME, tree, target_t, [glob_escape(p) for p in left])


def glob_escape(path):
    import glob
    return glob.escape(path)


def develop_merge_at(m, step, label):
    """(base, ours, theirs, res_dir) of the replay's merge for the commit `label` of a tail step."""
    from tools.series import trees
    prev = step_by_n(m, step["n"] - 1)
    ours = tail_space(m, prev["merge_tree"])
    for lab, before, after, *policy in develop_inputs(m, step):
        res = os.path.join(resolutions_dir(step), lab)
        if lab == label or lab == label[:10]:
            return before, ours, after, res
        ours, conflicts = trees.target_tree(GAME, before, ours, after, res, prefer=policy[0] if policy else None)
        if conflicts:
            raise SystemExit(f"step {step['n']}: {lab} has unresolved conflicts first")
    raise SystemExit(f"step {step['n']}: no commit {label}")


def format_pass(m, tree):
    """The published tree: `tree` with the files upstream's CI format check covers (C and C++ under
    src/) run through clang-format. Merging two formatted sides can give an unformatted result (e.g.
    an include block that is no longer sorted); this fixes only that. Tests are never touched."""
    from tools.series import normalise, verify
    style = m["anchors"]["format"]["style_file_from"]
    return normalise.normalise_tree(GAME, tree, style, select=lambda p: p.startswith("src/")
                                    and bool(verify.FORMAT_INCLUDE_RE.match(p)))


def compute_tree(m, step, report=None):
    """(published tree, merge tree, conflicts). The next step merges onto the merge tree, so stored
    resolutions (keyed by the merge's input blobs) stay valid; the branch carries the published tree."""
    merged, conflicts = compute_merge_tree(m, step, report)
    if conflicts:
        return None, merged, conflicts
    if step["kind"] == "mechanical":
        return merged, merged, conflicts  # the fork's own tree, in its own style
    return format_pass(m, merged), merged, conflicts


RESOLVE_SCRATCH = os.path.join(ROOT, ".agent-tmp", "series-resolve")


def cmd_tree(args):
    from tools.series import profile
    if profile.current() == "seriesb":
        return cmd_tree_replay(args)
    from tools.series import history, trees
    m = load_manifest()
    step = step_by_n(m, args.n)
    scratch = os.path.join(RESOLVE_SCRATCH, f"{step['n']:03d}")
    if args.show or args.record:
        res_dir = resolutions_dir(step)
        if step["source"]["type"] == "history":
            base, ours, theirs = merge_inputs(m, step)
        elif not args.commit:
            raise SystemExit("tree --show/--record: a tail step needs --commit (the label `tree` printed)")
        else:
            base, ours, theirs, res_dir = develop_merge_at(m, step, args.commit)
            scratch = os.path.join(scratch, args.commit[:10])
        path = args.show or args.record
        if path.startswith("tests/"):
            print(f"tree {args.n}: {path} is a test file; tests are never resolved by hand (rule 1)", file=sys.stderr)
            return 1
        if args.show:
            merged, conflicts = trees.merge(GAME, base, ours, theirs)
            os.makedirs(os.path.dirname(os.path.join(scratch, path)), exist_ok=True)
            key = conflicts.get(path, {})
            if all(key.get(k) for k in ("base", "ours", "theirs")):
                # the file with only the hunks the automatic rules could not resolve still marked
                lines = trees.merge_file_by_hunks(GAME, key["base"], key["ours"], key["theirs"], ours, path)[0]
                content = "".join(lines).encode("utf-8", "surrogateescape")
            else:
                content = trees._git(GAME, "cat-file", "-p", f"{merged}:{path}", ok=(0, 128)).stdout
            blobs = {"": content}
            for side, suffix in (("ours", ".upstream"), ("theirs", ".history"), ("base", ".base")):
                blobs[suffix] = trees._git(GAME, "cat-file", "blob", key[side]).stdout if key.get(side) else b""
            for suffix, data in blobs.items():  # raw bytes: the resolution must be byte-exact
                with open(os.path.join(scratch, path + suffix), "wb") as f:
                    f.write(data)
            print(os.path.join(scratch, path))
            return 0
        src = os.path.join(scratch, path)
        if not os.path.exists(src):
            trees.record_resolution(GAME, base, ours, theirs, res_dir, path, None)
            print(f"recorded: {path} deleted")
            return 0
        with open(src, "rb") as f:
            content = f.read()
        if b"<<<<<<<" in content or b">>>>>>>" in content:
            print(f"tree {args.n}: {src} still has conflict markers", file=sys.stderr)
            return 1
        trees.record_resolution(GAME, base, ours, theirs, res_dir, path, content)
        print(f"recorded: {path}")
        return 0
    report = []
    tree, merged, conflicts = compute_tree(m, step, report)
    if conflicts:
        print(f"tree {args.n}: {len(conflicts)} conflicts")
        for p in conflicts:
            print(f"  {p}")
        return 1
    resolved = [{"path": p, "how": how} for p, how in sorted(report)]
    if report:
        import collections
        kinds = collections.Counter(how for _, how in report)
        print(f"tree {args.n}: {len(report)} conflicts resolved ("
              + ", ".join(f"{v} {k}" for k, v in sorted(kinds.items())) + ")", file=sys.stderr)
    if step.get("target_tree") != tree or step.get("merge_tree") != merged or step.get("resolutions") != resolved:
        from tools.series import manifest
        step["resolutions"] = resolved
        step["target_tree"] = tree
        step["merge_tree"] = merged
        for later in m["steps"][step["n"]:]:  # later trees were computed on the old one
            later["target_tree"] = later["merge_tree"] = None
        manifest.save(MANIFEST, m)
    print(tree)
    return 0


STACK_WORKTREE = os.path.join(ROOT, ".agent-tmp", "series-stack")


def commit_message(step):
    """The step commit's message: the title, then what it covers (no bead ids, no history paths)."""
    ch = step.get("chapter")
    if ch:
        body = f"Migration phase {ch['phase'].lstrip('P')}: " + "; ".join(ch["work_items"]) + "."
    elif step["source"]["type"] == "hoisted":
        body = "An independent fix from the migration's first phase, ahead of the migration."
    else:
        body = "Changes made on the fork after the migration: " + ", ".join(c[:10] for c in step["source"]["commits"]) + "."
    return f"{step['title']}\n\n{body}\n"


def build_one(m, step):
    """Create or reset the step's branch; returns 'built' or 'unchanged'."""
    from tools.series import manifest, stack
    tree, merged, conflicts = compute_tree(m, step)
    if conflicts:
        raise SystemExit(f"build {step['n']}: {len(conflicts)} unresolved conflicts; run `tree {step['n']}`")
    if step.get("target_tree") != tree or step.get("merge_tree") != merged:
        step["target_tree"], step["merge_tree"] = tree, merged
        manifest.save(MANIFEST, m)
    msg = commit_message(step)
    parent_tip = stack.git(GAME, "rev-parse", f"refs/heads/{step['parent']}")
    if stack.exists(GAME, step["branch"]) and stack.lineage(GAME, step["branch"]) == step["parent"]:
        tip = step["branch"]
        same = (stack.git(GAME, "rev-parse", f"{tip}^{{tree}}") == tree
                and stack.git(GAME, "rev-parse", f"{tip}^") == parent_tip
                and stack.git(GAME, "log", "-1", "--format=%B", tip).strip() == msg.strip())
        if same:
            return "unchanged"
    stack.make_step(GAME, STACK_WORKTREE, step["branch"], step["parent"], tree, msg)
    return "built"


def cmd_build(args):
    from tools.series import profile
    if profile.current() == "seriesb":
        return cmd_build_replay(args)
    m = load_manifest()
    if args.steps:
        ns = sorted(args.steps)
    else:
        start = args.from_ or 1
        end = args.to or len(m["steps"])
        ns = list(range(start, end + 1))
    for n in ns:
        step = step_by_n(m, n)
        print(f"build {n}: {step['branch']} {build_one(m, step)}", flush=True)
    return 0


def resolution_paths(step):
    import json
    index = os.path.join(resolutions_dir(step), "index.json")
    if not os.path.exists(index):
        return []
    with open(index, encoding="utf-8") as f:
        data = json.load(f)
    return sorted(data)  # {path: {base, ours, theirs, deleted}}


def integrity(m, step):
    """The construction-integrity checks (research R11) for a built step."""
    from tools.series import normalise, verify
    tree = stack_tree(step)
    parent = parent_tree_of(m, step)
    if step["source"]["type"] == "develop":
        return integrity_tail(m, step, tree, parent)
    if step["source"]["type"] == "hoisted":
        from tools.series import history, hoist
        commits = step["source"]["commits"]
        snap = history_snap(m)
        upstream = history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{tree}}")
        ours = hoist.series_base({"steps": [s for s in m["steps"] if s["n"] < step["n"]]}, upstream)
        base, source = snap(hoist.first_parent(GAME, commits[0])), snap(commits[-1])
    else:
        base, ours, source = merge_inputs(m, step)
    out = {
        "tests_untouched": verify.check_tests_untouched(GAME, tree, source, ours, resolution_paths(step), base),
        "no_new_suppressions": verify.check_no_new_suppressions(GAME, parent, tree, source),
        "no_new_spidermonkey_or_gnustep": verify.check_no_new_legacy(GAME, parent, tree),
    }
    if step["kind"] != "mechanical":
        out["clang_format"] = verify.check_clang_format(GAME, tree, normalise.normalise_tree(GAME, tree, tree))
    else:
        out["clang_format"] = "n/a: the reformat step changes the style; upstream's check follows it"
    return out


def integrity_tail(m, step, tree, parent):
    """Research R11's checks for a tail step. Its sources are develop's commits: a test it changes
    is develop's text of that test (in the tail's style, or exactly develop's in the mechanical
    step), no stored resolution is a test, and a suppression it adds is one develop has."""
    import fnmatch
    from tools.series import history, normalise, verify
    commits = [c for c in develop_order(m) if c in step["source"]["commits"]]
    latest = history.git(GAME, "rev-parse", f"{commits[-1]}^{{tree}}")
    out = {}
    bad = [p for p in tail_resolution_paths(step) if p.startswith("tests/")]
    changed = history.git(GAME, "diff", "--name-only", "--no-renames", parent, tree, "--", "tests/").splitlines()
    if step["kind"] == "mechanical":
        target = history.git(GAME, "rev-parse", f"{m['anchors']['develop_target']}^{{tree}}")
        bad += [p for p in changed if verify._blob(GAME, tree, p) != verify._blob(GAME, target, p)]
    else:
        # the text of each changed test in some commit of the step, or develop's in the converging step
        sources = [after for _l, _b, after, *_ in develop_inputs(m, step)]
        sources += [after for _l, _b, after, *_ in develop_inputs(m, step, space=upstream_space)]
        nxt = step_by_n(m, step["n"] + 1) if step["n"] < len(m["steps"]) else None
        if nxt is not None and nxt["kind"] == "mechanical":
            sources.append(tail_space(m, compute_merge_tree(m, nxt)[0]))
        # or the step's commits merged cleanly, in turn, into the parent's text of it: in the tail's
        # style, or in upstream's (where a test keeps its own layout)
        spaces = [(develop_inputs(m, step), tail_space(m, parent)),
                  (develop_inputs(m, step, space=upstream_space), parent)]
        for p in changed:
            blob = verify._blob(GAME, tree, p)
            if any(verify._blob(GAME, s, p) == blob for s in sources):
                continue
            got = trees_text(tree, p)
            ok = False
            for pairs, start in spaces:
                text = trees_text(start, p)
                for _l, before, after, *_ in pairs:
                    if text is None or verify._blob(GAME, before, p) == verify._blob(GAME, after, p):
                        continue
                    text = merge_text(trees_text(before, p), text, trees_text(after, p))
                ok = ok or (text is not None and got is not None and text == got)
            if not ok:
                bad.append(p)
    out["tests_untouched"] = "pass" if not bad else "fail: " + ", ".join(sorted(set(bad))[:8])
    out["no_new_suppressions"] = verify.check_no_new_suppressions(GAME, parent, tree, latest)
    out["no_new_spidermonkey_or_gnustep"] = verify.check_no_new_legacy(GAME, parent, tree)
    if step["kind"] == "mechanical":
        out["clang_format"] = "n/a: the reformat step changes the style; upstream's check follows it"
        out["mechanical"] = check_mechanical(m, step, tree, parent)
    else:
        out["clang_format"] = verify.check_clang_format(GAME, tree, normalise.normalise_tree(GAME, tree, tree))
    return out


def trees_text(tree, path):
    """The bytes of `path` in `tree`, or None if it has none."""
    r = subprocess.run(["git", "-C", GAME, "cat-file", "-p", f"{tree}:{path}"], capture_output=True)
    return r.stdout if r.returncode == 0 else None


def merge_text(base, ours, theirs):
    """A conflict-free `git merge-file` of three texts (None meaning absent), or None."""
    import tempfile
    if ours == theirs:
        return ours
    if base is None or ours is None or theirs is None:
        return theirs if ours == base else (ours if theirs == base else None)
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for name, data in (("ours", ours), ("base", base), ("theirs", theirs)):
            f = os.path.join(tmp, name)
            with open(f, "wb") as out:
                out.write(data)
            files.append(f)
        r = subprocess.run(["git", "merge-file", "-p", *files], capture_output=True)
        return r.stdout if r.returncode == 0 else None


def check_mechanical(m, step, tree, parent):
    """The mechanical step is its command: the parent with the step's own non-source files, its
    sources and tests run through clang-format 22 in the new style, gives the step's tree."""
    from tools.series import history, normalise, trees
    own = set()
    for _label, before, after, *_ in develop_inputs(m, step):
        own |= {p for p in history.git(GAME, "diff", "--name-only", "--no-renames", before, after).splitlines()
                if not (normalise.is_source(p) or normalise.is_test_source(p))}
    start = trees.take_paths(GAME, parent, tree, [glob_escape(p) for p in sorted(own)])
    made = normalise.normalise_tree(GAME, start, m["anchors"]["develop_target"],
                                    select=lambda p: normalise.is_source(p) or normalise.is_test_source(p),
                                    rename_only=lambda p: False)
    diff = history.git(GAME, "diff", "--name-only", "--no-renames", made, tree).splitlines()
    # develop's text came from earlier layouts (and its tests from an earlier clang-format), and
    # clang-format's output depends on its input's layout: such files may differ, but in layout only
    lines = lambda t, p: (trees_text(t, p) or b"").decode("utf-8", "surrogateescape").splitlines(keepends=True)
    def shape(t, p):  # the text without its layout, and its includes in any order
        ls = lines(t, p)
        return (trees._layout([l for l in ls if not l.startswith("#include")]),
                sorted(l.strip() for l in ls if l.startswith("#include")))
    real = [p for p in diff if shape(made, p) != shape(tree, p)]
    own_text = f"{len(own)} file(s) of its own ({', '.join(sorted(own))})"
    if real:
        return f"fail: {len(real)} file(s) differ from the command's output in more than layout: " + ", ".join(real[:8])
    if diff:
        return f"pass: the reformat and {own_text}; {len(diff)} file(s) keep develop's layout or include order (clang-format's output depends on its input's layout, and develop's tests were sorted by an earlier version)"
    return f"pass: the reformat and {own_text}"


def tail_resolution_paths(step):
    """The paths of a tail step's stored resolutions (one directory per replayed commit)."""
    import json
    out = set()
    root = resolutions_dir(step)
    if os.path.isdir(root):
        for d in os.listdir(root):
            index = os.path.join(root, d, "index.json")
            if os.path.exists(index):
                with open(index, encoding="utf-8") as f:
                    out |= set(json.load(f))
    return sorted(out)


def stack_tree(step):
    from tools.series import stack
    return stack.git(GAME, "rev-parse", f"refs/heads/{step['branch']}^{{tree}}")


def cmd_verify_replay(args):
    """Verify seriesb steps in order (spec FR-008); stops at the first failure."""
    from tools.series import manifest, replay, stack, verify
    m = load_manifest()
    steps = m["steps"]
    if args.n:
        ns = [args.n]
    elif args.from_:
        ns = list(range(args.from_, (args.to or len(steps)) + 1))
    else:
        print("verify: give a step or --from", file=sys.stderr)
        return 2
    old_listed = os.path.join(ROOT, "specs", "001-split-migration-prs", "series", "test-warnings.md")
    for n in ns:
        step = _replay_step(m, n)
        if not stack.exists(GAME, step["branch"]):
            print(f"verify {n}: {step['branch']} is not built; stopping", file=sys.stderr)
            return 1
        checks = replay.integrity(GAME, m, step, SERIES_DIR)
        if args.integrity_only:
            print(f"verify {n}: " + "; ".join(f"{k}={v}" for k, v in checks.items()), flush=True)
            continue
        prec = replay.parent_record(m, step) or {}
        tree = stack.git(GAME, "rev-parse", f"refs/heads/{step['branch']}^{{tree}}")
        clean = args.clean or n == 1 or verify.era(GAME, tree) != prec.get("era")
        saved = verify.TEST_WARNINGS
        verify.TEST_WARNINGS = old_listed  # the history's test warnings, keyed by old step
        try:
            record = verify.verify_step(GAME, step, replay.parent_tree(GAME, m, step), prec, clean=clean,
                                        integrity=checks, inherited=prec.get("warning_keys", []),
                                        listed_n=step["source"].get("old_step", 0), component_attempts=3,
                                        poc=True, gcc=False)
        finally:
            verify.TEST_WARNINGS = saved
        record["after_sync"] = len(m.get("syncs", []))
        step["verification"] = record
        step["era"] = record["era"]
        ok = verify.record_passes(record)
        step["state"] = "verified" if ok else "failed"
        manifest.save(MANIFEST, m)
        print(f"verify {n}: {'pass' if ok else 'FAIL'} " + "; ".join(f"{k}={v}" for k, v in record["checks"].items()),
              flush=True)
        if not ok:
            return 1
    return 0


def cmd_verify(args):
    from tools.series import manifest, profile, verify
    if profile.current() == "seriesb":
        return cmd_verify_replay(args)
    m = load_manifest()
    steps = m["steps"]
    if args.n:
        ns = [args.n]
    elif args.from_:
        ns = list(range(args.from_, len(steps) + 1))
    else:
        print("verify: give a step or --from", file=sys.stderr)
        return 2
    failed = False
    from tools.series import stack
    for n in ns:
        step = step_by_n(m, n)
        if not stack.exists(GAME, step["branch"]):
            print(f"verify {n}: {step['branch']} is not built; stopping", file=sys.stderr)
            return 1 if args.n else (1 if failed else 0)
        checks = integrity(m, step)
        if args.integrity_only:
            print(f"verify {n}: " + "; ".join(f"{k}={v}" for k, v in checks.items()), flush=True)
            failed |= not all(v.startswith(("pass", "n/a")) for v in checks.values())
            continue
        prev = step_by_n(m, n - 1) if n > 1 else None
        parent_record = (prev or {}).get("verification")
        parent_era = (parent_record or {}).get("era")
        tree = stack_tree(step)
        clean = args.clean or n == 1 or verify.era(GAME, tree) != parent_era or n == HISTORY_STEPS_LAST(m)
        record = verify.verify_step(GAME, step, parent_tree_of(m, step), parent_record, clean=clean, integrity=checks)
        step["verification"] = record
        step["era"] = record["era"]
        manifest.save(MANIFEST, m)
        cmd_describe(argparse.Namespace(n=n, handover=False))
        ok = verify.record_passes(record)
        print(f"verify {n}: {'pass' if ok else 'FAIL'} " + "; ".join(f"{k}={v}" for k, v in record["checks"].items()),
              flush=True)
        if not ok:
            return 1  # later steps build on this one: stop at the first failure
    return 1 if failed else 0


def HISTORY_STEPS_LAST(m):
    return max(s["n"] for s in m["steps"] if s["source"]["type"] == "history")


CHECK_GROUPS = ("manifest", "branches", "lineage", "trees", "descriptions", "final-tree", "ledger", "verified")


def parse_range(text, total):
    if not text:
        return set(range(1, total + 1))
    a, _, b = text.partition("-")
    return set(range(int(a), int(b or a) + 1))


def check_descriptions(m, step):
    """Rule 8 and rule 9 (descriptions): required sections, written, no bookkeeping ids."""
    from tools.series import manifest
    out = []
    path = os.path.join(SERIES_DIR, "pr", os.path.basename(step["description"]))
    if not os.path.exists(path):
        return [f"rule 8: step {step['n']} has no description {os.path.relpath(path, ROOT)}"]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.startswith(f"# {step['title']}\n"):
        out.append(f"rule 8: step {step['n']} description does not start with its title")
    sections = parse_sections(text)
    for h in HAND_SECTIONS + ("Verified",):
        if h not in sections:
            out.append(f"rule 8: step {step['n']} description lacks '## {h}'")
        elif h in HAND_SECTIONS and (not sections[h] or sections[h] == TODO):
            out.append(f"rule 8: step {step['n']} section '{h}' is not written")
    hit = manifest.BOOKKEEPING_RE.search(text)
    if hit:
        out.append(f"rule 9: step {step['n']} description carries {hit.group(0)!r}")
    return out


def check_final_tree(m, step):
    """Rule 7: the last step's tree equals develop_target outside the exclusions (path globs left out,
    reverted commits undone), and every exclusion gives its reason."""
    import fnmatch
    from tools.series import history, trees
    out = [f"rule 7: exclusion {e.get('path_glob') or e.get('revert_commit')!r} has no reason"
           for e in m.get("exclusions", []) if not str(e.get("reason") or "").strip()]
    target = history.git(GAME, "rev-parse", f"{m['anchors']['develop_target']}^{{tree}}")
    for e in m.get("exclusions", []):
        if "revert_commit" in e:
            target = trees.revert(GAME, target, e["revert_commit"])
    tip = history.git(GAME, "rev-parse", f"refs/heads/{step['branch']}^{{tree}}")
    globs = exclusion_globs(m)
    diff = [p for p in history.git(GAME, "diff", "--name-only", "--no-renames", tip, target).splitlines()
            if not any(fnmatch.fnmatch(p, g) for g in globs)]
    return out + [f"rule 7: last step differs from develop_target at {p}" for p in diff[:20]] + (
        [f"rule 7: ... and {len(diff) - 20} more paths"] if len(diff) > 20 else [])


def cmd_check_seriesb(args):
    """`check` for the seriesb profile: data-model.md's rules 1-7 (tools/series/seriesb.py)."""
    import json
    from tools.series import seriesb
    m = load_manifest()
    groups = set(args.only.split(",")) if args.only else (set(seriesb.GROUPS) | {"descriptions", "handover"}) - {"verified"}
    if args.verified:
        groups.add("verified")
    known = set(seriesb.GROUPS) | {"descriptions", "handover"}
    unknown = groups - known
    if unknown:
        print(f"check: unknown group(s) {', '.join(sorted(unknown))}; groups are {', '.join(sorted(known))}", file=sys.stderr)
        return 2
    if not m:
        print(f"check: no manifest at {os.path.relpath(MANIFEST, ROOT)}", file=sys.stderr)
        return 1
    baseline_path = os.path.join(SERIES_DIR, "baseline.json")
    baseline = None
    if os.path.exists(baseline_path):
        with open(baseline_path, encoding="utf-8") as f:
            baseline = json.load(f)
    elif "baseline" in groups:
        print(f"check: no {os.path.relpath(baseline_path, ROOT)}", file=sys.stderr)
        return 1
    steps = m.get("steps", [])
    wanted = parse_range(args.steps, len(steps))
    problems = seriesb.check(GAME, m, groups, baseline, wanted)
    if "descriptions" in groups:
        for step in steps:
            if step["n"] in wanted:
                problems += check_descriptions(m, step)
    if "handover" in groups:
        problems += check_handover_replay(m)
    for p in problems:
        print(p)
    print(f"check: {len(problems)} problem(s) in {', '.join(sorted(groups))} for steps "
          f"{args.steps or f'1-{len(steps)}'}", file=sys.stderr)
    return 1 if problems else 0


def cmd_check(args):
    from tools.series import manifest, profile, stack
    if profile.current() == "seriesb":
        return cmd_check_seriesb(args)
    m = load_manifest()
    groups = set(args.only.split(",")) if args.only else set(CHECK_GROUPS) - {"verified"}
    if args.verified:
        groups.add("verified")
    unknown = groups - set(CHECK_GROUPS)
    if unknown:
        print(f"check: unknown group(s) {', '.join(sorted(unknown))}; groups are {', '.join(CHECK_GROUPS)}", file=sys.stderr)
        return 2
    steps = m.get("steps", [])
    wanted = parse_range(args.steps, len(steps))
    problems = []
    if groups & {"manifest", "ledger"}:
        inv = {r["commit"]: int(r["idx"]) for r in read_inventory()}
        for p in manifest.validate(m, order=inv):
            is_ledger = p.startswith("rule 6:")
            if ("ledger" in groups and is_ledger) or ("manifest" in groups and not is_ledger):
                problems.append(p)
    for step in steps:
        if step["n"] not in wanted:
            continue
        n, branch = step["n"], step["branch"]
        built = stack.exists(GAME, branch)
        if groups & {"branches", "lineage", "trees", "final-tree"} and not built:
            problems.append(f"rule 2: step {n} branch {branch} does not exist")
        if built and "branches" in groups:
            parents = stack.git(GAME, "rev-list", "--parents", "-n", "1", branch).split()[1:]
            parent_tip = stack.git(GAME, "rev-parse", f"refs/heads/{step['parent']}") if stack.exists(GAME, step["parent"]) else None
            if parents != [parent_tip]:
                problems.append(f"rule 2: step {n} commit is not a single commit on {step['parent']}'s tip")
            msg = stack.git(GAME, "log", "-1", "--format=%B", branch)
            hit = manifest.BOOKKEEPING_RE.search(msg)
            if hit:
                problems.append(f"rule 9: step {n} commit message carries {hit.group(0)!r}")
        if built and "lineage" in groups and stack.lineage(GAME, branch) != step["parent"]:
            problems.append(f"rule 2: step {n} Git Town parent is {stack.lineage(GAME, branch)!r}, expected {step['parent']!r}")
        if built and "trees" in groups:
            tree = stack.git(GAME, "rev-parse", f"{branch}^{{tree}}")
            if not step.get("target_tree"):
                problems.append(f"rule 3: step {n} has no target_tree")
            elif tree != step["target_tree"]:
                problems.append(f"rule 3: step {n} tree {tree[:10]} is not its target_tree {step['target_tree'][:10]}")
        if "descriptions" in groups:
            problems += check_descriptions(m, step)
        if built and "final-tree" in groups and n == len(steps):
            problems += check_final_tree(m, step)
        if "verified" in groups:
            v = step.get("verification") or {}
            bad = [k for k, r in (v.get("checks") or {}).items() if not str(r).startswith(("pass", "n/a"))]
            if not v or bad:
                problems.append(f"rule 10: step {n} is not verified" + (f" ({', '.join(bad)})" if bad else ""))
            else:
                stale = record_stale(m, step)
                if stale:
                    problems.append(f"rule 10: step {n}'s verification is stale: {stale}")
    for p in problems:
        print(p)
    print(f"check: {len(problems)} problem(s) in {', '.join(sorted(groups))} for steps "
          f"{args.steps or f'1-{len(steps)}'}", file=sys.stderr)
    return 1 if problems else 0


def record_stale(m, step):
    """Why the step's verification record no longer describes its branch, or None.

    A record is for the tip commit it names. After a rebuild that changes no tree (say, a step
    inserted earlier whose tree the next step already contained), it still holds when the step's tree
    is the record's and the parent's tree is the one the parent's own record was made for: every
    check reads only those two trees and the parent's record."""
    from tools.series import stack
    v = step["verification"]
    tip = stack.git(GAME, "rev-parse", f"refs/heads/{step['branch']}")
    if v.get("commit") == tip:
        return None
    if v.get("tree") != stack.git(GAME, "rev-parse", f"{tip}^{{tree}}"):
        return f"made for tree {str(v.get('tree'))[:10]}, the branch has another"
    if step["n"] == 1:
        return "made for another commit, and the first step has no parent record"
    pv = step_by_n(m, step["n"] - 1).get("verification") or {}
    parent_tree = stack.git(GAME, "rev-parse", f"{tip}^^{{tree}}")
    if pv.get("tree") != parent_tree:
        return "made on another parent"
    if pv.get("commit") != stack.git(GAME, "rev-parse", f"{tip}^") and record_stale(m, step_by_n(m, step["n"] - 1)):
        return "the parent's record is stale"
    return None


HAND_SECTIONS = ("What this changes", "Why", "Behaviour changes", "How to review")
TODO = "_To write._"
NOT_VERIFIED_PLATFORMS = "macOS (its platform code is not converted yet) and Linux are not verified by this series."


def parse_sections(text):
    """{heading: body} for '## ' sections of a description."""
    out, cur, buf = {}, None, []
    for line in text.splitlines():
        if line.startswith("## "):
            if cur:
                out[cur] = "\n".join(buf).strip()
            cur, buf = line[3:].replace(" **(gen)**", "").strip(), []
        elif cur:
            buf.append(line)
    if cur:
        out[cur] = "\n".join(buf).strip()
    return out


def step_size(step, parent_tree):
    """{src, tests, other, deleted_files} changed lines between parent_tree and the step's target tree."""
    if not step.get("target_tree") or not parent_tree:
        return None
    return tree_size(parent_tree, step["target_tree"])


def tree_size(parent_tree, tree):
    """{src, tests, other, deleted_files} changed lines between two trees."""
    from tools.series import history
    num = history.git(GAME, "diff", "--numstat", "-M", parent_tree, tree)
    status = history.git(GAME, "diff", "--name-status", "-M", parent_tree, tree)
    deleted = {l.split("\t")[-1] for l in status.splitlines() if l.startswith("D")}
    size = {"src": 0, "tests": 0, "other": 0, "deleted_files": 0}
    for line in num.splitlines():
        a, d, path = line.split("\t", 2)
        if a == "-":
            continue
        path = path.split(" => ")[-1].strip("{}")
        if path in deleted:
            size["deleted_files"] += int(d)
            continue
        key = "tests" if path.startswith("tests/") else "src" if path.startswith("src/") else "other"
        size[key] += int(a) + int(d)
    return size


def fmt_k(n):
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n)


def parent_tree_of(m, step):
    from tools.series import history
    if step["n"] == 1:
        return history.git(GAME, "rev-parse", f"{m['anchors']['upstream_base']}^{{tree}}")
    return step_by_n(m, step["n"] - 1).get("target_tree")


def render_description(m, step, kept):
    steps = m["steps"]
    nxt = step_by_n(m, step["n"] + 1)["branch"] if step["n"] < len(steps) else "—"
    lines = [f"# {step['title']}", "",
             f"**Series:** step {step['n']} of {len(steps)} · base `{step['parent']}` · next `{nxt}` **(gen)**", ""]
    ch = step.get("chapter")
    size = step.get("size")
    size_txt = (f"{fmt_k(size['src'])} src, {fmt_k(size['tests'])} tests, {fmt_k(size['other'])} other changed lines; "
                f"{fmt_k(size['deleted_files'])} lines in deleted files") if size else "not built yet"
    if ch:
        lines += [f"**Chapter:** {ch['phase']} · {', '.join(ch['work_items'])} · history "
                  f"`{ch['first'][:10]}`..`{ch['last'][:10]}` ({ch['merges']} merges) · {size_txt} **(gen)**", ""]
    else:
        src = step["source"]
        where = "the migration's history (an independent fix, ahead of it)" if src["type"] == "hoisted" else "`develop`"
        lines += [f"**From:** {where} commits {', '.join(f'`{c[:9]}`' for c in src.get('commits', []))} · "
                  f"{size_txt} **(gen)**", ""]
    for h in HAND_SECTIONS:
        lines += [f"## {h}", "", kept.get(h) or TODO, ""]
    lines += ["## Verified **(gen)**", ""]
    v = step.get("verification")
    if v:
        lines += [f"Windows x64, `{v.get('commit', '')[:10]}`, {v.get('date', '')}.", "",
                  "| Check | Result |", "|---|---|"]
        for k, r in sorted(v.get("checks", {}).items()):
            lines.append(f"| {k} | {r} |")
        lines.append("")
    else:
        lines += ["Not verified yet.", ""]
    lines += [NOT_VERIFIED_PLATFORMS, ""]
    temps = [t for t in m.get("ledger", []) if step["n"] in (t.get("added_in"), t.get("removed_in"))]
    if temps:
        lines += ["## Temporary code **(gen)**", ""]
        for t in temps:
            if t.get("added_in") == step["n"]:
                lines.append(f"- Adds {t['description']}; removed in step {t.get('removed_in')}.")
            else:
                lines.append(f"- Removes {t['description']}, added in step {t.get('added_in')}.")
        lines.append("")
    return "\n".join(lines)


def cmd_describe(args):
    from tools.series import manifest, profile
    if profile.current() == "seriesb":
        return cmd_describe_replay(args)
    m = load_manifest()
    if args.handover:
        return cmd_handover(m)
    targets = [step_by_n(m, args.n)] if args.n else m["steps"]
    for step in targets:
        step["size"] = step_size(step, parent_tree_of(m, step)) or step.get("size")
        path = os.path.join(SERIES_DIR, "pr", os.path.basename(step["description"]))
        kept = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                kept = {k: v for k, v in parse_sections(f.read()).items() if k in HAND_SECTIONS and v != TODO}
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(render_description(m, step, kept))
        print(os.path.relpath(path, ROOT))
    manifest.save(MANIFEST, m)
    return 0


# --- seriesb: descriptions and the handover (contracts/series-cli-seriesb.md) ----------------------

def _old_range(step):
    if step["source"].get("type") == "target":
        return "the switch"
    olds = step["source"].get("old_steps") or [step["source"]["old_step"]]
    return "old " + ", ".join(str(n) for n in olds)


def _root_pr(m):
    from tools.series import seriesb
    root = seriesb.root(m)
    p = next((p for p in m.get("parents", []) if p["branch"] == root), {})
    if p.get("kind") == "upstream":
        return f"upstream #{p['upstream_pr']}'s branch"
    if p.get("kind") == "upstream-master":
        return "upstream `master`"
    return f"`{root}` (a fix on top of upstream's PRs)"


PLATFORMS_NOT_VERIFIED = "macOS and Linux are not verified."
TESTS_LISTED = 20  # a switch step's changed tests listed by name; the rest by a command
GENERATED_NOTE = ("<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four "
                  "hand-written sections and rewrites the rest. -->")


def _on_open_prs(m):
    """Whether the stack still hangs from upstream's unmerged QuickJS-ng PRs (or a fix on top of them):
    false once the parents are retired onto upstream `master`."""
    from tools.series import seriesb
    root = seriesb.root(m)
    return next((p for p in m.get("parents", []) if p["branch"] == root), {}).get("kind") != "upstream-master"


def _header_replay(m, step):
    """The one line under the title: the step's place in the stack, what it needs first, and where it
    comes from. GitHub shows the base branch and the diff's size, so the line does not."""
    src = step["source"]
    line = f"Step {step['n']} of {len(m['steps'])}"
    if _on_open_prs(m):
        line += f", stacked on {_root_pr(m)}, so not independent of #767 and #768"
    line += "."
    if src.get("type") != "target":
        folded = f" ({_old_range(step)})" if src.get("old_steps") else ""
        line += f" Replays `{src['old_branch']}`{folded}."
    elif src["ref"] != step["branch"]:
        line += f" Takes the tree of `{src['ref']}` (`{src['commit'][:10]}`), with the series' exclusions and additions."
    return line


def render_description_replay(m, step, kept, tip=None, tests_changed=None):
    """The step's description. `tip`: the branch's tip commit, when it exists (a verification record
    made for another commit is then reported as not current). `tests_changed`: the existing test files
    the step modifies or deletes, for the last step's Test changes section."""
    src = step["source"]
    switch = src.get("type") == "target"
    lines = [f"# {step['title']}", "", GENERATED_NOTE, "", _header_replay(m, step), ""]
    for h in HAND_SECTIONS:
        lines += [f"## {h}", "", kept.get(h) or TODO, ""]
    differs = step.get("differs_from_old") or []
    ledger = os.path.basename(src.get("test_ledger") or "") or "the test ledger"
    if switch:
        lines += ["## Test changes", ""]
        if tests_changed:
            lines.append(f"Existing test files this step changes (test ledger: `{ledger}`):")
            lines.append("")
            lines += [f"- `{p}`" for p in tests_changed[:TESTS_LISTED]]
            if len(tests_changed) > TESTS_LISTED:
                lines.append(f"- ... and {len(tests_changed) - TESTS_LISTED} more: `git diff --name-only "
                             f"--diff-filter=MD {step['parent']} {step['branch']} -- tests/`")
        else:
            lines.append(f"No existing test file changes (the test ledger is `{ledger}`).")
        lines.append("")
    elif differs:
        lines += ["## Differences from the old step", "",
                  f"Where this step's change differs from `{src['old_branch']}`'s, and why:", ""]
        for d in differs[:40]:
            lines.append(f"- `{d['path']}`: {d['reason']}")
        if len(differs) > 40:
            lines.append(f"- ... and {len(differs) - 40} more (the manifest lists them all)")
        lines.append("")
    lines += ["## Verified **(gen)**", ""]
    v = step.get("verification")
    if v and tip and v.get("commit") != tip:
        lines += [f"Not verified at this branch's tip (`{tip[:10]}`) yet; the last record "
                  f"({v.get('date', '')}) is for an earlier build.", ""]
    elif v:
        checks = sorted((v.get("checks") or {}).items())
        ran = [(k, r) for k, r in checks if not str(r).startswith("n/a")]
        na = [k for k, r in checks if str(r).startswith("n/a")]
        lines += [f"Windows x64, `{v.get('commit', '')[:10]}`, {v.get('date', '')}. {PLATFORMS_NOT_VERIFIED}", ""]
        if ran:
            lines += ["| Check | Result |", "|---|---|"] + [f"| {k} | {r} |" for k, r in ran] + [""]
        if na:
            lines += [f"Not applicable here: {', '.join(na)}.", ""]
    else:
        lines += ["Not verified yet.", ""]
    return "\n".join(lines)


def _old_description(m, step):
    """The hand-written sections of the old step's description, as a starting point (FR-006)."""
    old = _old_manifest(m)
    o = next((x for x in old["steps"] if x["branch"] == step["source"].get("old_branch")), None)
    if not o:
        return {}
    path = os.path.join(ROOT, os.path.dirname(m["anchors"]["old_manifest"]), "pr", os.path.basename(o["description"]))
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return {k: v for k, v in parse_sections(f.read()).items() if k in HAND_SECTIONS and v != TODO}


def _branch_tip(branch):
    from tools.series import stack
    return stack.git(GAME, "rev-parse", f"refs/heads/{branch}") if stack.exists(GAME, branch) else None


def history_lines(*args):
    from tools.series import history
    return [l for l in history.git(GAME, *args).splitlines() if l]


def cmd_describe_replay(args):
    from tools.series import manifest, replay
    m = load_manifest()
    if args.handover:
        with open(HANDOVER, "w", encoding="utf-8", newline="\n") as f:
            f.write(render_handover_replay(m, origin_branches()))
        print(os.path.relpath(HANDOVER, ROOT))
        return 0
    targets = [_replay_step(m, args.n)] if args.n else m["steps"]
    for step in targets:
        tip, tests_changed = _branch_tip(step["branch"]), None
        parent_tip = _branch_tip(step["parent"])
        if tip and parent_tip:
            # the branches as they are: a step may hold commits after its build (follow-ups, sync merges)
            step["size"] = tree_size(f"{parent_tip}^{{tree}}", f"{tip}^{{tree}}")
            if replay.is_target(step):
                tests_changed = [p for p in history_lines("diff", "--name-only", "--no-renames", "--diff-filter=MD",
                                                          parent_tip, tip, "--", "tests/")]
        elif step.get("target_tree"):
            step["size"] = step_size(step, replay.parent_tree(GAME, m, step)) or step.get("size")
        path = os.path.join(SERIES_DIR, "pr", os.path.basename(step["description"]))
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                kept = {k: v for k, v in parse_sections(f.read()).items() if k in HAND_SECTIONS and v != TODO}
        else:
            kept = _old_description(m, step) if not step["source"].get("old_steps") else {}
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(render_description_replay(m, step, kept, tip, tests_changed))
        print(os.path.relpath(path, ROOT))
    manifest.save(MANIFEST, m)
    return 0


def origin_branches():
    """{branch: commit} for `origin`'s seriesb branches, as this repository last fetched them."""
    from tools.series import stack
    out = stack.git(GAME, "for-each-ref", "--format=%(refname:lstrip=3) %(objectname)", "refs/remotes/origin/seriesb/")
    return dict(line.split(" ", 1) for line in out.splitlines() if line)


def render_handover_replay(m, remote=None):
    """The handover. `remote`: {branch: commit} on `origin` (origin_branches); each push is leased on
    it, and its seriesb branches that are neither a step nor a parent are deleted."""
    from tools.series import seriesb
    remote = remote or {}
    a, steps = m["anchors"], m["steps"]
    spec_dir = os.path.relpath(os.path.dirname(SERIES_DIR), ROOT).replace(os.sep, "/")
    body = lambda s: f"{spec_dir}/{s['description']}"
    live = seriesb.live_parents(m)
    root = seriesb.root(m)
    out = ["# Handover: the PR series on upstream's QuickJS-ng PRs (seriesb)", "",
           "Generated by `python -I tools/series/series.py --series seriesb describe --handover` from the manifest. "
           f"{len(steps)} steps, replaying the master-based `series/*` steps on upstream #767 and #768. Run "
           "`python -I tools/series/series.py --series seriesb check --verified` first: it exits 0 only if every "
           "step's verification below is current.", "",
           "## Parents", "",
           "| Parent | Mirrors | Head | Gate |", "|---|---|---|---|"]
    for p in m.get("parents", []):
        what = (f"upstream #{p['upstream_pr']}" if p.get("kind") == "upstream" else
                "upstream `master`" if p.get("kind") == "upstream-master" else "a fix on top of the PRs")
        state = " (retired)" if p.get("state") == "retired" else ""
        out.append(f"| `{p['branch']}`{state} | {what} | `{str(p.get('head'))[:10]}` | {p.get('gate')} |")
    out += ["", f"- End: the fork's `develop` at `{a['develop_target'][:10]}`, outside the exclusions and "
            "additions below (and paths upstream changed in a recorded sync).", "",
            "## Folded and dropped old steps", ""]
    for f in m.get("folded", []):
        olds = ", ".join(str(n) for n in f["old_steps"] + [f["into_old_step"]])
        out.append(f"- old {olds} are one step: {f['reason']}.")
    for d in m.get("dropped", []):
        covered = f"#{d['covered_by']}" if str(d["covered_by"]).isdigit() else d["covered_by"]
        out.append(f"- `{d['old_branch']}` is dropped: covered by {covered}; {d['reason']}.")
    if not m.get("folded") and not m.get("dropped"):
        out.append("None.")
    out += ["", "## Exclusions and additions", "", "What `develop` has and the series does not carry:", ""]
    for e in m.get("exclusions", []):
        what = f"`{e['path_glob']}`" if e.get("path_glob") else f"commit `{e['revert_commit']}` (reverted)"
        out.append(f"- {what}: {e['reason']}.")
    out += ["", "What the series keeps from upstream's PRs and `develop` does not have:", ""]
    for e in m.get("additions", []):
        out.append(f"- `{e['path_glob']}` (#{e.get('from_pr')}): {e['reason']}.")
    out += ["", "## Steps", "", "| Step | Branch | Replays | Base | Title | Size (src / tests / other) | Verification |",
            "|---|---|---|---|---|---|---|"]
    for s in steps:
        z = s.get("size") or {}
        size = f"{fmt_k(z.get('src', 0))} / {fmt_k(z.get('tests', 0))} / {fmt_k(z.get('other', 0))}" if z else "—"
        title = s["title"].replace("|", "\\|")
        src = s["source"]
        what = ("written on its own branch" if src.get("type") == "target" and src.get("ref") == s["branch"]
                else f"`{src['ref']}` (the switch)" if src.get("type") == "target"
                else f"`{src['old_branch']}` ({_old_range(s)})")
        out.append(f"| {s['n']} | `{s['branch']}` | {what} | `{s['parent']}` "
                   f"| {title} | {size} | {verification_summary(s)} |")
    git = f"GIT_TERMINAL_PROMPT=0 {PUSH_GIT} -C oolite-dev push"
    lease = lambda b: f"--force-with-lease=refs/heads/{b}:{remote.get(b, '')}"
    kept = {s["branch"] for s in steps} | {p["branch"] for p in m.get("parents", [])} | {seriesb.root_parent(m)}
    obsolete = sorted(b for b in remote if b not in kept)
    out += ["", "## Keeping it current", "",
            "When upstream's PRs move: `parents --refresh`, then `git town sync --stack --detached --no-push`, then "
            "`sync-record` and `verify --from 1`. See `docs/series-sync.md`.", "",
            "## Push (Jon)", "",
            "With Git for Windows' git (MSYS2's has no credentials and waits for a username forever). Each push "
            "is leased: it goes through only if `origin`'s branch is still at the commit this handover was "
            "generated against, or, for a name `origin` does not have, still absent. A step whose branch "
            "`origin` already has at the same commit pushes nothing. `--set-upstream` points each branch's "
            "tracking at its own name (a renamed branch still tracks its old one).", "", "```bash"]
    for s in steps:
        b = s["branch"]
        out.append(f"{git} --set-upstream {lease(b)} origin {b}:refs/heads/{b}")
    if any(p["branch"] == root for p in live if p.get("kind") == "upstream"):
        out += ["```", "", f"`{root}` goes to the fork too, as the base of step 1's dry-run PR; the explicit "
                "refspec is needed because its tracking remote is the PR author's:", "", "```bash",
                f"{git} {lease(root)} origin {root}:refs/heads/{root}"]
    top = seriesb.root_parent(m)
    if top != "develop":
        out += ["```", "", f"`{top}` is upstream's `master` as a Git Town perennial branch, the parent of "
                f"`{live[0]['branch'] if live else root}`: PRs inside the fork target it. It goes to the fork as it is:",
                "", "```bash", f"{git} {lease(top)} origin {top}:refs/heads/{top}"]
    out += ["```", "", "## Delete obsolete names on origin (Jon)", ""]
    if obsolete:
        out += ["After the pushes: `origin`'s seriesb branches that are no longer a step or a parent (renamed or "
                "dropped steps), each leased on the commit it had when this handover was generated:", "", "```bash"]
        out += [f"{git} {lease(b)} origin :refs/heads/{b}" for b in obsolete]
        out += [f"GIT_TERMINAL_PROMPT=0 {PUSH_GIT} -C oolite-dev fetch --prune origin", "```", ""]
    else:
        out += ["None: every seriesb branch on `origin` is a step or a parent.", ""]
    out += ["## Git Town", "",
            "The stack's lineage is local configuration (`git config --get-regexp git-town-branch`: each "
            "branch's `parent` and `branchtype`); "
            "pushing does not carry it, and renaming a branch with the series tool moves it. The parents are "
            "`observed` (they follow upstream's PRs and are never pushed by Git Town); the steps are `feature` "
            "branches, so a bare `git town sync --stack` pushes them, without a lease. For the first push of "
            "the rebuilt steps use the commands above. `git town branch` shows the stack.", "",
            "## Dry run on the fork (Jon)", "",
            f"Each PR against the previous branch in `{FORK_REPO}`, so every diff is one step:", "", "```bash"]
    for s in steps:
        out.append(f"gh pr create -R {FORK_REPO} --draft --base {s['parent']} --head {s['branch']} "
                   f"--title {sh_quote(s['title'])} --body-file {body(s)}")
    out += ["```", "", "## Upstream, one at a time (Jon)", ""]
    open_prs = [p for p in live if p.get("kind") == "upstream"]
    if open_prs:
        prs = ", ".join(f"#{p['upstream_pr']}" for p in open_prs)
        out += [f"Wait: {prs} are not merged into upstream `master` yet. A PR for step 1 opened against `master` "
                "now would carry their commits as well as its own. When they are merged, run `parents --retire` "
                "(it moves step 1 onto `seriesb/000m-upstream-master`), sync, re-verify and regenerate this "
                "handover; this section then lists the commands.", ""]
    else:
        out += [f"Against `{UPSTREAM_REPO}` `master`, each opened when the one before it has merged:", "", "```bash"]
        for s in steps:
            out.append(f"gh pr create -R {UPSTREAM_REPO} --base master --head jonmseaman:{s['branch']} "
                       f"--title {sh_quote(s['title'])} --body-file {body(s)}")
        out += ["```", ""]
    return "\n".join(out)


def check_handover_replay(m):
    """The handover exists and names every parent and step (contract: describe --handover)."""
    if not os.path.exists(HANDOVER):
        return [f"rule 8: no {os.path.relpath(HANDOVER, ROOT)}; run `describe --handover`"]
    with open(HANDOVER, encoding="utf-8") as f:
        text = f.read()
    if text != render_handover_replay(m, origin_branches()):
        return ["rule 8: the handover is out of date; run `describe --handover`"]
    return []


HANDOVER = os.path.join(SERIES_DIR, "HANDOVER.md")
PUSH_GIT = "/mingw64/bin/git"  # Git for Windows: it has the credential helper; MSYS2's git hangs on a prompt
UPSTREAM_REPO = "OoliteProject/oolite"
FORK_REPO = "jonmseaman/oolite"


def sh_quote(text):
    return "'" + text.replace("'", "'\\''") + "'"


def verification_summary(step):
    v = step.get("verification") or {}
    checks = v.get("checks") or {}
    if not checks:
        return "not verified"
    passed = sum(1 for r in checks.values() if str(r).startswith("pass"))
    na = sum(1 for r in checks.values() if str(r).startswith("n/a"))
    failed = len(checks) - passed - na
    return f"{passed} pass, {na} n/a" + (f", {failed} FAIL" if failed else "") + f" ({v.get('date', '')})"


def render_handover(m):
    from tools.series import manifest
    a, steps = m["anchors"], m["steps"]
    spec_dir = os.path.relpath(os.path.dirname(SERIES_DIR), ROOT).replace(os.sep, "/")
    body = lambda s: f"{spec_dir}/{s['description']}"
    out = ["# Handover: the migration as a PR series", "",
           f"Generated by `python -I tools/series/series.py describe --handover` from the manifest. "
           f"{len(steps)} steps, each one commit on the one before. Run `python -I tools/series/series.py check --verified` "
           "first: it exits 0 only if every step's verification below is current.", "",
           "## Anchors", "",
           f"- Series base: upstream `{a['upstream_base']}` (`{manifest.ROOT_BRANCH}`, a Git Town perennial branch).",
           f"- End: the fork's `develop` at `{a['develop_target']}`, outside the exclusions below.",
           f"- Format: clang-format {a['format']['clang_format_version']}, style from `{a['format']['style_file_from']}`.", "",
           "## Exclusions", "", "What `develop` has and the series does not carry:", ""]
    for e in m.get("exclusions", []):
        what = f"`{e['path_glob']}`" if e.get("path_glob") else f"commit `{e['revert_commit']}` (reverted)"
        out.append(f"- {what}: {e['reason']}.")
    out += ["", "## Temporary code", ""]
    ledger = m.get("ledger") or []
    if ledger:
        for t in ledger:
            out.append(f"- `{t['id']}`: {t['description']}; added in step {t['added_in']}, removed in step {t['removed_in']}.")
    else:
        out.append("None: no step adds a shim that a later step has to remove.")
    out += ["", "## Steps", "", "| Step | Branch | Base | Title | Size (src / tests / other) | Verification |",
            "|---|---|---|---|---|---|"]
    for s in steps:
        z = s.get("size") or {}
        size = f"{fmt_k(z.get('src', 0))} / {fmt_k(z.get('tests', 0))} / {fmt_k(z.get('other', 0))}" if z else "—"
        title = s["title"].replace("|", "\\|")
        out.append(f"| {s['n']} | `{s['branch']}` | `{s['parent']}` | {title} | {size} | {verification_summary(s)} |")
    branches = " ".join([manifest.ROOT_BRANCH] + [s["branch"] for s in steps])
    out += ["", "## Push (Jon)", "",
            "Push every branch to the fork with Git for Windows' git (MSYS2's has no credentials and waits "
            "for a username forever):", "", "```bash",
            f"GIT_TERMINAL_PROMPT=0 {PUSH_GIT} -C oolite-dev push origin {branches}", "```", "",
            "## Dry run on the fork (Jon)", "",
            f"Each PR against the previous step's branch in `{FORK_REPO}`, so every diff is one step:", "", "```bash"]
    for s in steps:
        base = s["parent"]  # the first step's is series/000-upstream-base, upstream's commit
        out.append(f"gh pr create -R {FORK_REPO} --draft --base {base} --head {s['branch']} "
                   f"--title {sh_quote(s['title'])} --body-file {body(s)}")
    out += ["```", "", "## Upstream, one at a time (Jon)", "",
            f"Against `{UPSTREAM_REPO}` `master`, each opened when the one before it has merged:", "", "```bash"]
    for s in steps:
        out.append(f"gh pr create -R {UPSTREAM_REPO} --base master --head jonmseaman:{s['branch']} "
                   f"--title {sh_quote(s['title'])} --body-file {body(s)}")
    out += ["```", ""]
    return "\n".join(out)


def cmd_handover(m):
    with open(HANDOVER, "w", encoding="utf-8", newline="\n") as f:
        f.write(render_handover(m))
    print(os.path.relpath(HANDOVER, ROOT))
    return 0


SERIES_ONLY = ("inventory", "hoist")  # history commands: feature 001 only


# --- seriesb: the replay (research R3; contracts/series-cli-seriesb.md) ----------------------------

def _old_manifest(m):
    from tools.series import manifest
    return manifest.load(os.path.join(ROOT, m["anchors"]["old_manifest"]))


def cmd_cut_replay(args):
    from tools.series import manifest, profile, replay, seriesb
    if profile.current() != "seriesb" or not args.replay:
        print("cut: --replay is for --series seriesb, and seriesb takes only --replay", file=sys.stderr)
        return 2
    m = load_manifest()
    if not m.get("parents"):
        print("cut: no parents; run `parents --setup` first", file=sys.stderr)
        return 1
    replay.cut(GAME, m, _old_manifest(m))
    if args.target:
        if not (args.title and args.slug and args.test_ledger):
            print("cut --target: give --title, --slug and --test-ledger", file=sys.stderr)
            return 2
        replay.set_target(GAME, m, args.target, args.title, args.slug, args.test_ledger)
    problems = seriesb.validate(m)
    if problems:
        print("cut: manifest invalid:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1
    manifest.save(MANIFEST, m)
    switch = sum(1 for s in m["steps"] if replay.is_target(s))
    print(f"cut: {len(m['steps']) - switch} replay steps" + (", then the switch" if switch else "")
          + f"; {len(m.get('dropped', []))} dropped")
    return 0


def _replay_step(m, n):
    for s in m.get("steps", []):
        if s["n"] == n:
            return s
    raise SystemExit(f"no step {n}")


def cmd_tree_replay(args):
    """Compute a seriesb step's tree; --rule/--show/--record resolve its conflicts."""
    from tools.series import manifest, replay, trees
    m = load_manifest()
    step = _replay_step(m, args.n)
    if replay.is_target(step) and (args.take_old or args.rule or args.show or args.record):
        print(f"tree {args.n}: the switch takes its target's tree; there is nothing to resolve", file=sys.stderr)
        return 2
    scratch = os.path.join(RESOLVE_SCRATCH, f"{step['n']:03d}")
    rdir = replay.res_dir(SERIES_DIR, step)
    if args.take_old:
        if not args.reason:
            print("tree: --take-old needs --reason", file=sys.stderr)
            return 2
        replay.take_old(step, args.keep, args.reason)
        manifest.save(MANIFEST, m)
    if args.rule:
        if not args.paths or not args.reason:
            print("tree: --rule needs --paths and --reason", file=sys.stderr)
            return 2
        if any(g.startswith("tests/") for g in args.paths):
            print("tree: a rule never covers tests/ (rule 1)", file=sys.stderr)
            return 1
        replay.add_rule(step, args.paths, args.reason)
        manifest.save(MANIFEST, m)
    if args.show or args.record:
        path = args.show or args.record
        if path.startswith("tests/"):
            print(f"tree {args.n}: {path} is a test file; tests are never resolved by hand (rule 1)", file=sys.stderr)
            return 1
        base, ours, theirs = replay.inputs(GAME, m, step)
        if args.show:
            merged, conflicts = trees.merge(GAME, base, ours, theirs)
            key = conflicts.get(path, {})
            os.makedirs(os.path.dirname(os.path.join(scratch, path)), exist_ok=True)
            if all(key.get(k) for k in ("base", "ours", "theirs")):
                lines = trees.merge_file_by_hunks(GAME, key["base"], key["ours"], key["theirs"], ours, path)[0]
                content = "".join(lines).encode("utf-8", "surrogateescape")
            else:
                content = trees._git(GAME, "cat-file", "-p", f"{merged}:{path}", ok=(0, 128)).stdout
            blobs = {"": content}
            for side, suffix in (("ours", ".new-parent"), ("theirs", ".old-step"), ("base", ".old-parent")):
                blobs[suffix] = trees._git(GAME, "cat-file", "blob", key[side]).stdout if key.get(side) else b""
            for suffix, data in blobs.items():
                with open(os.path.join(scratch, path + suffix), "wb") as f:
                    f.write(data)
            print(os.path.join(scratch, path))
            return 0
        if not args.reason:
            print("tree --record: give --reason (what each side changed, and why this resolution)", file=sys.stderr)
            return 2
        src = os.path.join(scratch, path)
        content = None
        if os.path.exists(src):
            with open(src, "rb") as f:
                content = f.read()
            if b"<<<<<<<" in content or b">>>>>>>" in content:
                print(f"tree {args.n}: {src} still has conflict markers", file=sys.stderr)
                return 1
        trees.record_resolution(GAME, base, ours, theirs, rdir, path, content)
        step.setdefault("reasons", {})[path] = args.reason
        manifest.save(MANIFEST, m)
        print(f"recorded: {path}" + (" deleted" if content is None else ""))
        return 0
    tree, conflicts, report = replay.compute(GAME, m, step, SERIES_DIR)
    if tree:
        step["differs_from_old"] = replay.differs(GAME, m, step)
    manifest.save(MANIFEST, m)
    if conflicts:
        print(f"tree {args.n}: {len(conflicts)} conflicts")
        for p in conflicts:
            print(f"  {p}")
        return 1
    if report:
        import collections
        kinds = collections.Counter(how for _, how in report)
        print(f"tree {args.n}: {len(report)} conflicts resolved ("
              + ", ".join(f"{v} {k}" for k, v in sorted(kinds.items())) + ")", file=sys.stderr)
    unexplained = [d["path"] for d in step["differs_from_old"] if not d["reason"]]
    if unexplained:
        print(f"tree {args.n}: {len(unexplained)} path(s) differ from the old step with no reason: "
              + ", ".join(unexplained[:8]), file=sys.stderr)
    print(tree)
    return 0


def cmd_build_replay(args):
    from tools.series import manifest, replay
    m = load_manifest()
    if args.steps:
        ns = sorted(args.steps)
    else:
        ns = list(range(args.from_ or 1, (args.to or len(m["steps"])) + 1))
    for n in ns:
        step = _replay_step(m, n)
        try:
            result = replay.build(GAME, m, step, SERIES_DIR, STACK_WORKTREE, reset=args.reset)
        finally:
            manifest.save(MANIFEST, m)
        print(f"build {n}: {step['branch']} {result}", flush=True)
    return 0


def cmd_fold(args):
    from tools.series import manifest, replay, seriesb
    m = load_manifest()
    for s in m["steps"]:
        built = replay._sha(GAME, f"refs/heads/{s['branch']}")
        if args.first_old <= s["source"].get("old_step", 0) < args.into_old and built:
            raise SystemExit(f"fold: {s['branch']} is built; a built step is not folded")
    replay.fold(GAME, m, _old_manifest(m), args.first_old, args.into_old, args.title, args.reason)
    problems = seriesb.validate(m)
    if problems:
        print("fold: manifest invalid:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1
    manifest.save(MANIFEST, m)
    print(f"fold: old steps {args.first_old}-{args.into_old} are one step; {len(m['steps'])} steps")
    return 0


def cmd_sync_record(args):
    from tools.series import manifest, sync
    m = load_manifest()
    entry = sync.record(GAME, m, args.sync_command, [sync.parse_conflict(c) for c in args.conflict])
    manifest.save(MANIFEST, m)
    print(f"sync-record: sync {len(m['syncs'])} on {entry['date']}, {len(entry['conflicts'])} conflict(s); "
          "every step is stale until `verify --from 1`")
    return 0


def cmd_drop(args):
    from tools.series import manifest, replay
    m = load_manifest()
    replay.drop(GAME, m, args.n, args.covered_by, args.reason, SERIES_DIR)
    manifest.save(MANIFEST, m)
    print(f"drop: step {args.n} dropped; {len(m['steps'])} steps, renumbered")
    return 0
SERIESB_ONLY = ("parents", "gate", "drop", "fold", "sync-record")
GATE_WORKTREE = os.path.join(ROOT, ".agent-tmp", "seriesb-gate")
GATE_LOGS = os.path.join(ROOT, ".agent-tmp", "seriesb-verify")


def cmd_gate(args):
    """Gate G1 for one parent (research R6); records it and exits 0 only on pass (or a waiver)."""
    from tools.series import gate, manifest
    m = load_manifest()
    match = [p for p in m.get("parents", []) if p["branch"] == args.parent or p["branch"].startswith(f"seriesb/{args.parent}-")]
    if len(match) != 1:
        print(f"gate: no single parent matches {args.parent!r}", file=sys.stderr)
        return 2
    p = gate.run(GAME, match[0], GATE_WORKTREE, GATE_LOGS)
    manifest.save(MANIFEST, m)
    for k, v in sorted(p["verification"]["checks"].items()):
        print(f"  {k}: {v}")
    print(f"gate {p['branch']}: {p['gate']}" + (f" ({p['flag']})" if p.get("flag") else ""))
    return 0 if p["gate"] in ("pass", "waived") else 1


SERIESB_ANCHORS = {"develop_target": "3aa8d65e8", "upstream_master": "7437f22a5"}


def cmd_parents(args):
    """Set up, refresh or report the seriesb parents (contracts/series-cli-seriesb.md)."""
    from tools.series import history, manifest, parents
    m = load_manifest()
    if args.setup:
        old_path = os.path.join(ROOT, "specs", "001-split-migration-prs", "series", "manifest.json")
        old = manifest.load(old_path)
        full = lambda c: history.git(GAME, "rev-parse", "--verify", f"{c}^{{commit}}")
        anchors = {k: full(v) for k, v in SERIESB_ANCHORS.items()}
        anchors["old_manifest"] = os.path.relpath(old_path, ROOT).replace(os.sep, "/")
        anchors["format"] = old["anchors"]["format"]
        parents.setup(GAME, m, anchors=anchors)
        m.setdefault("exclusions", old.get("exclusions", []))
        for k in ("steps", "dropped", "additions", "ledger", "syncs"):
            m.setdefault(k, [])
    elif args.refresh:
        if not m:
            raise SystemExit("parents: no manifest; run `parents --setup` first")
        parents.refresh(GAME, m)
    elif args.retire:
        history.git(GAME, "fetch", "-q", "upstream", "master")
        parents.retire(GAME, m)
    if args.setup or args.refresh or args.retire:
        os.makedirs(SERIES_DIR, exist_ok=True)
        manifest.save(MANIFEST, m)
    for p in m.get("parents", []):
        tip = history.git(GAME, "rev-parse", "-q", "--verify", f"refs/heads/{p['branch']}", check=False).stdout.strip()
        print(f"{p['branch']}: tip {tip[:10] or '-'} | PR #{p.get('upstream_pr', '-')} head {str(p.get('head'))[:10]} "
              f"| gate {p.get('gate')}")
    problems = parents.status(GAME, m)
    for line in problems:
        print(line, file=sys.stderr)
    if not m.get("parents"):
        print("parents: none set up; run `parents --setup`", file=sys.stderr)
        return 1
    return 1 if problems else 0

HANDLERS = {"sync-record": cmd_sync_record, "fold": cmd_fold, "drop": cmd_drop, "gate": cmd_gate, "parents": cmd_parents, "inventory": cmd_inventory, "cut": cmd_cut, "hoist": cmd_hoist, "renumber": cmd_renumber, "tree": cmd_tree, "build": cmd_build, "check": cmd_check, "verify": cmd_verify, "describe": cmd_describe}


def main(argv=None):
    args = parser().parse_args(argv)
    from tools.series import profile
    profile.activate(args.series)
    if args.series == "series" and args.command in SERIESB_ONLY:
        print(f"series.py {args.command}: only for --series seriesb", file=sys.stderr)
        return 2
    if args.series == "seriesb" and args.command in SERIES_ONLY:
        print(f"series.py {args.command}: not for --series seriesb (its steps replay the series/ steps)", file=sys.stderr)
        return 2
    handler = HANDLERS.get(args.command)
    if handler is None:
        print(f"series.py {args.command}: not implemented", file=sys.stderr)
        return 2
    return handler(args)


if __name__ == "__main__":
    # run in the package's module, the one profile.activate rebinds (this file is __main__ here)
    from tools.series import series as _series
    sys.exit(_series.main())
