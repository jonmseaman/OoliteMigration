#!/usr/bin/env python3
"""Coverage-table extractor and totals counter for the parity audit.

Two jobs (see parity/METHOD.md):

  skeleton  Write one skeleton findings file per area. Each upstream .m file gets a
            `## <Name>` section with an anchor, a Status placeholder and a coverage table:
            one row per ObjC method / C function, with its upstream line. The C++ column is
            left empty for the auditor. The area -> file grouping is read from the
            Checklist in parity/README.md, so it stays stable between runs.

  totals    Sum the `**Status:** done - N rows: a ✅ b ⚠️ c ❌ d ➖` lines across the area
            files and print per-file and grand totals, plus any section not yet done.

The extractor is regex-based and deliberately simple. Auditors must add rows it misses
(multi-line static functions, JSFunctionSpec/JSPropertySpec tables, macros that define
functions) and delete false rows.

Usage:
  python parity/tools/extract_coverage.py skeleton --upstream upstream/oolite/src \
      --port .worktrees/parity-028/src --out .agent-tmp/parity-skeletons
  python parity/tools/extract_coverage.py totals [--dir parity]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PARITY_DIR = Path(__file__).resolve().parent.parent

AREA_HEADING = re.compile(r"^### (.+?) — \[([\w-]+\.md)\]\(\2\)\s*$")
CHECK_ROW = re.compile(r"^- \[[ x]\] `([^`]+\.m)`")

IMPL = re.compile(r"^@implementation\s+(\w+)\s*(?:\(\s*(\w*)\s*\))?")
END = re.compile(r"^@end\b")
METHOD = re.compile(r"^([-+])\s*\(")
# A top-level C function definition: starts at column 0, has a name followed by '(',
# and is not a declaration (no trailing ';' before the body opens).
C_FUNC = re.compile(
    r"^(?!(?:if|for|while|switch|return|else|do|typedef|struct|enum|union)\b)"
    r"(?:static\s+|inline\s+|OOINLINE\s+|extern\s+|const\s+|unsigned\s+|signed\s+)*"
    r"[A-Za-z_][\w<>]*[\s\*]+\**\s*([A-Za-z_]\w*)\s*\(([^;]*)$"
)
STATUS = re.compile(
    r"^\*\*Status:\*\*\s*done\s*[—-]+\s*(\d+)\s*rows?:\s*(\d+)\s*✅\s*(\d+)\s*⚠️\s*(\d+)\s*❌\s*(\d+)\s*➖"
)
SECTION = re.compile(r"^## (.+)$")


def read_checklist(readme: Path) -> dict[str, list[str]]:
    """Area file name -> upstream .m paths (relative to upstream src), in checklist order."""
    areas: dict[str, list[str]] = {}
    current = None
    for line in readme.read_text(encoding="utf-8").splitlines():
        m = AREA_HEADING.match(line)
        if m:
            current = m.group(2)
            areas.setdefault(current, [])
            continue
        if line.startswith("### ") or line.startswith("## "):
            current = None
            continue
        m = CHECK_ROW.match(line)
        if m and current:
            areas[current].append(m.group(1))
    return areas


def selector(sig: str) -> str:
    """'- (id) foo:(int)a bar:(id)b' -> 'foo:bar:'; '- (void) update' -> 'update'."""
    body = re.sub(r"^[-+]\s*\([^)]*\)\s*", "", sig.strip())
    body = body.split("{")[0].strip()
    parts = re.findall(r"(\w+)\s*:", body)
    if parts:
        return "".join(p + ":" for p in parts)
    m = re.match(r"(\w+)", body)
    return m.group(1) if m else body


def extract(path: Path) -> list[tuple[str, int]]:
    rows: list[tuple[str, int]] = []
    cls = None
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    # Definitions start at column 0 and bodies are indented in this codebase, so no
    # brace tracking is needed (it breaks on #if/#else branches that each open a brace).
    for i, raw in enumerate(lines, 1):
        line = raw.rstrip()
        m = IMPL.match(line)
        if m:
            cls = m.group(1) + (f"({m.group(2)})" if m.group(2) else "")
            continue
        if END.match(line):
            cls = None
            continue
        if METHOD.match(line) and cls:
            # Join continuation lines until the body opens or a ';' (declaration).
            sig, j = line, i
            while "{" not in sig and not sig.rstrip().endswith(";") and j < len(lines):
                sig += " " + lines[j].strip()
                j += 1
            if not sig.split("{")[0].rstrip().endswith(";"):
                rows.append((f"`{line[0]}[{cls} {selector(sig)}]`", i))
        else:
            m = C_FUNC.match(line)
            if m:
                nxt = lines[i] if i < len(lines) else ""
                if "{" in line or nxt.strip().startswith("{") or nxt.startswith(("\t", " ")) and "{" in nxt:
                    rows.append((f"`{m.group(1)}`", i))
    return rows


def anchor(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def port_counterpart(port: Path, rel: str) -> str:
    stem = rel[:-2]
    for ext in (".cpp", ".mm", ".hpp", ".h"):
        p = port / (stem + ext)
        if p.exists():
            return stem + ext
    return ""


def line_count(p: Path) -> int:
    return len(p.read_text(encoding="utf-8", errors="replace").splitlines())


def cmd_skeleton(args) -> int:
    upstream, port, out = Path(args.upstream), Path(args.port), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    areas = read_checklist(PARITY_DIR / "README.md")
    listed = {f for files in areas.values() for f in files}
    unlisted = sorted(
        str(p.relative_to(upstream)).replace("\\", "/")
        for p in upstream.rglob("*.m")
        if str(p.relative_to(upstream)).replace("\\", "/") not in listed
    )
    if unlisted:
        print("Upstream .m files not in any checklist area (assign them):", file=sys.stderr)
        for f in unlisted:
            print("  " + f, file=sys.stderr)
    total_rows = 0
    for area, files in areas.items():
        parts = [f"# Parity findings: {area[:-3]}\n",
                 "Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.\n"]
        for rel in files:
            src = upstream / rel
            name = Path(rel).stem
            rows = extract(src) if src.exists() else []
            total_rows += len(rows)
            cp = port_counterpart(port, rel)
            cp_txt = f"`{cp}` ({line_count(src)} / {line_count(port / cp)} lines)" if cp else "*(no same-named port file; find where it went)*"
            parts.append(f"\n## {name}\n\n<a id=\"{anchor(name)}\"></a>\nUpstream `src/{rel}` ↔ {cp_txt}\n\n"
                         f"**Status:** todo — {len(rows)} extracted rows\n\n"
                         "| Upstream (line) | C++ counterpart | Verdict |\n|---|---|---|\n")
            parts.extend(f"| {label} ({ln}) | | |\n" for label, ln in rows)
            parts.append("\n**Differences:**\n\n")
        (out / area).write_text("".join(parts), encoding="utf-8")
        print(f"{area}: {len(files)} files")
    print(f"total extracted rows: {total_rows}")
    return 0


def cmd_totals(args) -> int:
    d = Path(args.dir)
    grand = [0, 0, 0, 0, 0]
    pending = []
    for f in sorted(d.glob("*.md")):
        if f.name in ("README.md", "AUDIT-BRIEF.md", "METHOD.md") or f.name.endswith("-plan.md"):
            continue
        sums = [0, 0, 0, 0, 0]
        section = None
        has_status = set()
        sections = []
        for line in f.read_text(encoding="utf-8").splitlines():
            m = SECTION.match(line)
            if m:
                section = m.group(1)
                sections.append(section)
                continue
            if line.startswith("**Status:**"):
                has_status.add(section)
                m = STATUS.match(line)
                if m:
                    for k in range(5):
                        sums[k] += int(m.group(k + 1))
                elif not line.startswith("**Status:** done"):
                    pending.append(f"{f.name} § {section}: {line}")
        if sums[0]:
            print(f"{f.name:22} {sums[0]:5} rows: {sums[1]} ✅ {sums[2]} ⚠️ {sums[3]} ❌ {sums[4]} ➖")
        for k in range(5):
            grand[k] += sums[k]
    print(f"{'TOTAL':22} {grand[0]:5} rows: {grand[1]} ✅ {grand[2]} ⚠️ {grand[3]} ❌ {grand[4]} ➖")
    if sum(grand[1:]) != grand[0]:
        print(f"WARNING: verdicts sum to {sum(grand[1:])}, not {grand[0]}")
    for p in pending:
        print("NOT DONE: " + p)
    return 1 if pending else 0


VERDICTS = ("✅", "⚠️", "❌", "➖")


def parse_sections(text: str):
    """Split a findings file into (header, [section]), where a section is a dict with
    name, pre (lines before the table), rows (table body lines) and post (the rest)."""
    lines = text.splitlines()
    header, sections, cur = [], [], None
    for line in lines:
        m = SECTION.match(line)
        if m:
            cur = {"name": m.group(1), "pre": [], "rows": [], "post": [], "state": "pre"}
            sections.append(cur)
            continue
        if cur is None:
            header.append(line)
            continue
        if cur["state"] == "pre" and line.startswith("| Upstream"):
            cur["state"] = "head"
            cur["pre"].append(line)
        elif cur["state"] == "head":
            cur["pre"].append(line)  # the |---| separator
            cur["state"] = "rows"
        elif cur["state"] == "rows" and line.startswith("|"):
            cur["rows"].append(line)
        else:
            if cur["state"] == "rows":
                cur["state"] = "post"
            cur[cur["state"] if cur["state"] in ("pre", "post") else "post"].append(line)
    return header, sections


def render_section(s) -> str:
    return "\n".join([f"## {s['name']}", *s["pre"], *s["rows"], *s["post"]]).rstrip() + "\n\n"


def cmd_split(args) -> int:
    """Pack skeleton sections into auditor part files of at most --max-rows rows.
    A section bigger than that is cut into row ranges that `merge` joins again."""
    import json
    src, out = Path(args.skeletons), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = []
    for area_file in sorted(src.glob("*.md")):
        header, sections = parse_sections(area_file.read_text(encoding="utf-8"))
        chunks = []
        for s in sections:
            rows = s["rows"] or [None]
            n = max(1, -(-len(s["rows"]) // args.max_rows))
            size = -(-len(s["rows"]) // n) if s["rows"] else 0
            for k in range(n):
                part = dict(s, rows=s["rows"][k * size:(k + 1) * size] if size else [])
                if n > 1:
                    part["pre"] = s["pre"][:-2] + [f"<!-- rows {k * size + 1}-{min((k + 1) * size, len(s['rows']))} of {len(s['rows'])} -->"] + s["pre"][-2:]
                chunks.append(part)
        packs, cur, cur_rows = [], [], 0
        for c in chunks:
            if cur and cur_rows + len(c["rows"]) > args.max_rows:
                packs.append(cur)
                cur, cur_rows = [], 0
            cur.append(c)
            cur_rows += len(c["rows"])
        if cur:
            packs.append(cur)
        stem = area_file.stem
        for i, pack in enumerate(packs, 1):
            name = f"{stem}.{i:02}.md"
            body = "\n".join(header).rstrip() + "\n\n" + "".join(render_section(c) for c in pack)
            (out / name).write_text(body, encoding="utf-8")
            rows = sum(len(c["rows"]) for c in pack)
            manifest.append({"part": name, "area": area_file.name, "rows": rows,
                             "sections": [c["name"] for c in pack]})
            print(f"{name}: {rows} rows, {len(pack)} sections")
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(f"{len(manifest)} parts")
    return 0


def verdict_of(row: str) -> str | None:
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    last = cells[-1] if cells else ""
    for v in VERDICTS:
        if v in last or (v == "⚠️" and "⚠" in last):
            return v
    return None


def cmd_merge(args) -> int:
    """Join completed part files back into one findings file per area, recomputing each
    section's Status line from the verdict column."""
    import json
    parts_dir, out = Path(args.parts), Path(args.out)
    manifest = json.loads((parts_dir / "manifest.json").read_text(encoding="utf-8"))
    by_area: dict[str, list[str]] = {}
    for m in manifest:
        by_area.setdefault(m["area"], []).append(m["part"])
    problems = 0
    for area, parts in by_area.items():
        header, merged = None, []
        for p in parts:
            h, secs = parse_sections((parts_dir / p).read_text(encoding="utf-8"))
            header = header or h
            for s in secs:
                s["pre"] = [l for l in s["pre"] if not l.startswith("<!-- rows ")]
                if merged and merged[-1]["name"] == s["name"]:
                    merged[-1]["rows"] += s["rows"]
                    merged[-1]["post"] += [l for l in s["post"] if l.strip() != "**Differences:**"]
                else:
                    merged.append(s)
        for s in merged:
            counts = {v: 0 for v in VERDICTS}
            for r in s["rows"]:
                v = verdict_of(r)
                if v:
                    counts[v] += 1
                else:
                    problems += 1
                    print(f"NO VERDICT: {area} § {s['name']}: {r[:100]}")
            status = (f"**Status:** done — {len(s['rows'])} rows: {counts['✅']} ✅ {counts['⚠️']} ⚠️ "
                      f"{counts['❌']} ❌ {counts['➖']} ➖")
            s["pre"] = [status if l.startswith("**Status:**") else l for l in s["pre"]]
            # Collapse runs of blank lines left by the joins.
            post, blank = [], False
            for l in s["post"]:
                if l.strip() == "" and blank:
                    continue
                blank = l.strip() == ""
                post.append(l)
            s["post"] = post
        text = "\n".join(header).rstrip() + "\n\n" + "".join(render_section(s) for s in merged)
        (out / area).write_text(text, encoding="utf-8")
        print(f"{area}: {len(merged)} sections from {len(parts)} parts")
    return 1 if problems else 0


def cmd_checklist(args) -> int:
    """Print the README Checklist (area headings from the current README, one row per
    section, counts from each section's Status line)."""
    readme = (PARITY_DIR / "README.md").read_text(encoding="utf-8").splitlines()
    out = []
    for line in readme:
        m = AREA_HEADING.match(line)
        if not m:
            continue
        area = m.group(2)
        out.append(f"\n{line}\n")
        _, secs = parse_sections((Path(args.dir) / area).read_text(encoding="utf-8"))
        for s in secs:
            anchor_id = next((re.search(r'id="([^"]+)"', l).group(1) for l in s["pre"] if 'id="' in l), anchor(s["name"]))
            link = next((l for l in s["pre"] if l.startswith("Upstream ")), "")
            m2 = re.match(r"Upstream `src/([^`]+)` ↔ (.*)", link)
            up, port = (m2.group(1), m2.group(2)) if m2 else (s["name"], "")
            status = next((l for l in s["pre"] if l.startswith("**Status:**")), "")
            m3 = STATUS.match(status)
            counts = ""
            if m3:
                parts = [f"{m3.group(k)}{v}" for k, v in zip(range(2, 6), VERDICTS) if m3.group(k) != "0"]
                counts = " ".join(parts)
            out.append(f"- [{'x' if m3 else ' '}] `{up}` → {port} — {counts} — [findings]({area}#{anchor_id})\n")
    print("".join(out))
    return 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("skeleton")
    s.add_argument("--upstream", required=True)
    s.add_argument("--port", required=True)
    s.add_argument("--out", required=True)
    sp = sub.add_parser("split")
    sp.add_argument("--skeletons", required=True)
    sp.add_argument("--out", required=True)
    sp.add_argument("--max-rows", type=int, default=300)
    mg = sub.add_parser("merge")
    mg.add_argument("--parts", required=True)
    mg.add_argument("--out", default=str(PARITY_DIR))
    c = sub.add_parser("checklist")
    c.add_argument("--dir", default=str(PARITY_DIR))
    t = sub.add_parser("totals")
    t.add_argument("--dir", default=str(PARITY_DIR))
    args = ap.parse_args()
    return {"skeleton": cmd_skeleton, "split": cmd_split, "merge": cmd_merge, "totals": cmd_totals, "checklist": cmd_checklist}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
