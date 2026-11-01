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


def main(argv=None):
    args = parser().parse_args(argv)
    print(f"series.py {args.command}: not implemented", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
