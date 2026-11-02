"""Hoisting: turn history commits into an `independent` step ahead of the first chapter (research R7).

A hoisted step's tree is the series base with each commit's change merged in, in the space the
history steps are merged in (`snap`: a history commit -> its normalised game tree). The history steps
merge incrementally (research R15), so the first one takes the last independent step's tree as
`ours`; the fix then rides along unchanged until its own chapter, where both sides have it.
"""
from tools.series import trees


class DoesNotApply(Exception):
    pass


def first_parent(repo, commit):
    return trees._git(repo, "rev-parse", f"{commit}^1").stdout.decode().strip()


def hoisted_tree(repo, start, commits, snap):
    """`start` with each commit's change (snap(c^1) -> snap(c)) merged in, in order.

    Raises DoesNotApply, naming the conflicted paths, if a change does not merge cleanly."""
    tree = start
    for c in commits:
        before, after = snap(first_parent(repo, c)), snap(c)
        if before == after:
            raise DoesNotApply(f"{c[:10]} changes nothing in the game")
        tree, conflicts = trees.merge(repo, before, tree, after)
        if conflicts:
            raise DoesNotApply(f"{c[:10]} conflicts with the series base in {', '.join(sorted(conflicts))}")
    return tree


def insert(m, commits, slug, title, tree, root_branch, era):
    """Insert an independent step after the existing ones; renumber the steps after it in `n` and
    `parent` (their branches, descriptions and resolution directories keep their old numbers until
    `renumber`). Returns the new step."""
    steps = m.setdefault("steps", [])
    at = 0
    while at < len(steps) and steps[at].get("kind") == "independent":
        at += 1
    n = at + 1
    step = {"n": n, "branch": f"series/{n:03d}-{slug}", "kind": "independent", "title": title,
            "source": {"type": "hoisted", "commits": list(commits)}, "chapter": None,
            "mechanical_command": None, "description": f"series/pr/{n:03d}-{slug}.md", "era": era,
            "target_tree": tree, "merge_tree": tree, "verification": None, "resolutions": [],
            "temporaries": []}
    for s in steps[at:]:
        s["n"] += 1
    steps.insert(at, step)
    for i, s in enumerate(steps):
        s["parent"] = root_branch if i == 0 else steps[i - 1]["branch"]
    return step


def series_base(m, upstream_base_tree):
    """`ours` for the first history step: the last independent step's tree, or upstream's."""
    last = None
    for s in m.get("steps", []):
        if s.get("kind") != "independent":
            break
        last = s
    if last is None:
        return upstream_base_tree
    return last.get("merge_tree") or last["target_tree"]
