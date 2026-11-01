#!/usr/bin/env python3
"""Command line for the PR series: see specs/001-split-migration-prs/contracts/series-cli.md.

Exit codes: 0 success, 1 a check or verification failed, 2 usage or environment error.
Never pushes, never runs `git town sync` or `propose`, never touches develop, master or main.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

COMMANDS = ("inventory", "cut", "hoist", "tree", "build", "verify", "describe", "check", "renumber")


def parser():
    p = argparse.ArgumentParser(prog="series.py", description="Build and check the migration PR series.")
    sub = p.add_subparsers(dest="command", required=True, metavar="{" + ",".join(COMMANDS) + "}")
    sub.add_parser("inventory", help="list the history's first-parent merges into series/inventory.tsv")
    c = sub.add_parser("cut", help="write the planned steps into the manifest")
    c.add_argument("--chapters", action="store_true", required=True, help="use research R14's chapters")
    h = sub.add_parser("hoist", help="turn history commits into an independent step at the front")
    h.add_argument("commits", nargs="+")
    h.add_argument("--slug", required=True)
    t = sub.add_parser("tree", help="compute a step's target tree")
    t.add_argument("n", type=int)
    b = sub.add_parser("build", help="create or reset step branches")
    b.add_argument("steps", nargs="*", type=int)
    b.add_argument("--from", dest="from_", type=int)
    b.add_argument("--to", type=int)
    v = sub.add_parser("verify", help="run a step's verification matrix")
    v.add_argument("n", nargs="?", type=int)
    v.add_argument("--from", dest="from_", type=int)
    v.add_argument("--clean", action="store_true")
    d = sub.add_parser("describe", help="write a step's PR description, or the handover")
    d.add_argument("n", nargs="?", type=int)
    d.add_argument("--handover", action="store_true")
    k = sub.add_parser("check", help="validate manifest, branches, lineage and trees")
    k.add_argument("--verified", action="store_true")
    k.add_argument("--only")
    k.add_argument("--steps")
    sub.add_parser("renumber", help="renumber branches and files after inserting or removing a step")
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


STATE_FIELDS = ("target_tree", "verification", "boundary_moved", "resolutions", "temporaries", "size", "era")


def load_manifest():
    from tools.series import manifest
    return manifest.load(MANIFEST) if os.path.exists(MANIFEST) else {}


def cmd_cut(args):
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


HANDLERS = {"inventory": cmd_inventory, "cut": cmd_cut}


def main(argv=None):
    args = parser().parse_args(argv)
    handler = HANDLERS.get(args.command)
    if handler is None:
        print(f"series.py {args.command}: not implemented", file=sys.stderr)
        return 2
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
