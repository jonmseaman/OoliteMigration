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
    t.add_argument("--show", metavar="PATH", help="write the conflicted file and its inputs to .agent-tmp/series-resolve")
    t.add_argument("--record", metavar="PATH", help="store the edited file from .agent-tmp/series-resolve as the resolution")
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


def resolutions_dir(step):
    return os.path.join(SERIES_DIR, "resolutions", f"{step['n']:03d}")


def merge_inputs(m, step):
    """(base, ours, theirs) trees for a history step: an incremental, rebase-style merge (research R15).

    base   = N(history at the previous chapter's boundary), or N(the history's start) for the first
    ours   = the previous step's resolved tree, or the series base for the first
    theirs = N(history at this chapter's boundary)
    """
    from tools.series import history, normalise
    a = m["anchors"]
    style = a["format"]["style_file_from"]
    snap = lambda c: normalise.normalise_tree(GAME, history.snapshot(GAME, c, a["history_prefix"]), style)
    prev = step_by_n(m, step["n"] - 1) if step["n"] > 1 else None
    if prev is None:
        base = snap(a["history_start"])
        ours = history.git(GAME, "rev-parse", f"{a['upstream_base']}^{{tree}}")
    else:
        if prev["source"]["type"] != "history":
            raise SystemExit(f"step {step['n']}: previous step is not a history step")
        ours = prev.get("target_tree")
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


def compute_tree(m, step, report=None):
    """(tree, conflicts) for a step; `report` receives (path, "stored" | "auto") per resolved conflict."""
    from tools.series import trees
    if step["source"]["type"] == "history":
        base, ours, theirs = merge_inputs(m, step)
        return trees.target_tree(GAME, base, ours, theirs, resolutions_dir(step), report=report)
    raise SystemExit(f"tree: source type {step['source']['type']!r} not implemented yet (T024)")


RESOLVE_SCRATCH = os.path.join(ROOT, ".agent-tmp", "series-resolve")


def cmd_tree(args):
    from tools.series import history, trees
    m = load_manifest()
    step = step_by_n(m, args.n)
    scratch = os.path.join(RESOLVE_SCRATCH, f"{step['n']:03d}")
    if args.show or args.record:
        if step["source"]["type"] != "history":
            raise SystemExit("tree --show/--record: history steps only")
        base, ours, theirs = merge_inputs(m, step)
        path = args.show or args.record
        if path.startswith("tests/"):
            print(f"tree {args.n}: {path} is a test file; tests are never resolved by hand (rule 1)", file=sys.stderr)
            return 1
        if args.show:
            merged, _ = trees.merge(GAME, base, ours, theirs)
            os.makedirs(os.path.dirname(os.path.join(scratch, path)), exist_ok=True)
            for name, tree in (("merged", merged), ("upstream", ours), ("history", theirs), ("base", base)):
                r = history.git(GAME, "cat-file", "-p", f"{tree}:{path}", check=False)
                out = os.path.join(scratch, path + (f".{name}" if name != "merged" else ""))
                with open(out, "w", encoding="utf-8", newline="\n") as f:
                    f.write(r.stdout + "\n" if r.returncode == 0 else "")
            print(os.path.join(scratch, path))
            return 0
        src = os.path.join(scratch, path)
        if not os.path.exists(src):
            trees.record_resolution(GAME, base, ours, theirs, resolutions_dir(step), path, None)
            print(f"recorded: {path} deleted")
            return 0
        with open(src, "rb") as f:
            content = f.read()
        if b"<<<<<<<" in content or b">>>>>>>" in content:
            print(f"tree {args.n}: {src} still has conflict markers", file=sys.stderr)
            return 1
        trees.record_resolution(GAME, base, ours, theirs, resolutions_dir(step), path, content)
        print(f"recorded: {path}")
        return 0
    report = []
    tree, conflicts = compute_tree(m, step, report)
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
    if step.get("target_tree") != tree or step.get("resolutions") != resolved:
        from tools.series import manifest
        step["resolutions"] = resolved
        step["target_tree"] = tree
        for later in m["steps"][step["n"]:]:  # later trees were computed on the old one
            later["target_tree"] = None
        manifest.save(MANIFEST, m)
    print(tree)
    return 0


HAND_SECTIONS = ("What this changes", "Why", "Behaviour changes", "How to review")
TODO = "_To write._"
NOT_VERIFIED_PLATFORMS = "macOS (Phase 5: not converted) and Linux are not verified by this series."


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
    from tools.series import history
    if not step.get("target_tree") or not parent_tree:
        return None
    num = history.git(GAME, "diff", "--numstat", "-M", parent_tree, step["target_tree"])
    status = history.git(GAME, "diff", "--name-status", "-M", parent_tree, step["target_tree"])
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
        lines += [f"**From:** `develop` commits {', '.join(f'`{c[:9]}`' for c in src.get('commits', []))} · "
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
    from tools.series import manifest
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


def cmd_handover(m):
    raise SystemExit("describe --handover: not implemented yet (T031)")


HANDLERS = {"inventory": cmd_inventory, "cut": cmd_cut, "tree": cmd_tree, "describe": cmd_describe}


def main(argv=None):
    args = parser().parse_args(argv)
    handler = HANDLERS.get(args.command)
    if handler is None:
        print(f"series.py {args.command}: not implemented", file=sys.stderr)
        return 2
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
