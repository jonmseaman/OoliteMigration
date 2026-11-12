"""Count what a version change rebuilds, from a configured build directory.

usage: graph.py <build_dir> <compile_commands_v1.json> <compile_commands_v2.json> <src_root>

Nothing is compiled. A compile edge reruns when its command line changes (ninja's command hash)
or when a header it includes changes. The first is the difference between the two compile
databases (the same tree configured with two versions); the second is every compile of a source
that includes the generated OOVersion.h. Anything downstream of a rerun edge (archives, links,
the post-build bundle step) reruns too.
"""
import collections
import json
import os
import re
import sys

build_dir, cc1, cc2, src_root = sys.argv[1:5]


def load_cc(path):
    out = {}
    for e in json.load(open(path, encoding="utf-8")):
        out[e["output"].replace("\\", "/")] = (e["file"], e.get("command") or " ".join(e["arguments"]))
    return out


v1, v2 = load_cc(cc1), load_cc(cc2)
changed_cmd = {o for o in v1 if v1[o][1] != v2.get(o, (None, None))[1]}

# Sources that include the generated version header (directly; no header includes it).
includers = set()
for d, _, files in os.walk(os.path.join(src_root, "src")):
    for f in files:
        if f.endswith((".cpp", ".c", ".h", ".hpp")):
            p = os.path.join(d, f)
            if '#include "OOVersion.h"' in open(p, encoding="utf-8", errors="replace").read():
                includers.add(os.path.normcase(os.path.abspath(p)))
header_dep = set()
for o, (f, _) in v1.items():
    full = os.path.normcase(os.path.abspath(os.path.join(build_dir, f)))
    if full in includers:
        header_dep.add(o)

# Parse build.ninja edges: outputs, rule, every input (explicit, implicit, order-only excluded).
text = open(os.path.join(build_dir, "build.ninja"), encoding="utf-8").read().replace("$\n", "")
edges = []
for line in text.splitlines():
    if not line.startswith("build "):
        continue
    head, _, rest = line[6:].partition(": ")
    rest = rest.split(" || ")[0]
    toks = re.split(r"(?<!\$) ", rest)
    rule = toks[0]
    ins = [t.replace("$ ", " ") for t in toks[1:] if t and t != "|"]
    outs = [t.replace("$ ", " ") for t in re.split(r"(?<!\$) ", head) if t and t != "|"]
    edges.append((rule, outs, ins))


def kind(rule, outs):
    o = outs[0]
    if "COMPILER" in rule:
        return "compile"
    if "STATIC_LINKER" in rule:
        return "archive"
    if "LINKER" in rule:
        if "tests/unit/core" in o:
            return "link: core test"
        if "tests/unit/oofnd" in o:
            return "link: oofnd test"
        if o.endswith(("src/oolite.exe", "src/oolite")):
            return "link: game"
        return "link: other"
    if "oolite_bundle" in o:
        return "post-build bundle"
    return "other: " + rule


totals = collections.Counter(kind(r, o) for r, o, _ in edges)
dup = collections.Counter()
for r, outs, ins in edges:
    if "COMPILER" in r:
        dup[os.path.basename(ins[0]) if ins else "?"] += 1


def affected(seed):
    hit = set(seed)
    again = True
    while again:
        again = False
        for r, outs, ins in edges:
            if outs[0] in hit:
                continue
            if any(i in hit for i in ins):
                hit.update(outs)
                again = True
    return collections.Counter(kind(r, o) for r, o, _ in edges if o[0] in hit)


report = {
    "edges": dict(totals),
    "compiles_whose_command_changed": len(changed_cmd),
    "compiles_including_OOVersion.h": len(header_dep),
    "rerun_on_version_change": dict(affected(changed_cmd | header_dep)),
    "most_compiled_sources": [(k, n) for k, n in dup.most_common(4) if n > 1],
}
print(json.dumps(report, indent=1))
