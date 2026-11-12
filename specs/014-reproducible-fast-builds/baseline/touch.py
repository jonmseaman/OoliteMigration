"""What touching one game source reruns (static walk of build.ninja; nothing is built).

usage: touch.py <build_dir> <object basename>...   e.g. Core_OOColor.cpp.obj
"""
import collections
import os
import re
import sys

bd, objs = sys.argv[1], sys.argv[2:]
text = open(os.path.join(bd, "build.ninja"), encoding="utf-8").read().replace("$\n", "")
E = []
for line in text.splitlines():
    if not line.startswith("build "):
        continue
    head, _, rest = line[6:].partition(": ")
    toks = re.split(r"(?<!\$) ", rest.split(" || ")[0])
    E.append((toks[0], [t for t in re.split(r"(?<!\$) ", head) if t and t != "|"],
              [t for t in toks[1:] if t and t != "|"]))


def kind(rule, o):
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
    return None


for obj in objs:
    hit = {o[0] for r, o, i in E if "COMPILER" in r and o[0].endswith("oolite.exe.p/" + obj)}
    again = True
    while again:
        again = False
        for r, outs, ins in E:
            if outs[0] not in hit and any(x in hit for x in ins):
                hit.update(outs)
                again = True
    c = collections.Counter(kind(r, o[0]) for r, o, i in E if o[0] in hit)
    c.pop(None, None)
    print(f"touch {obj.replace('Core_', '').replace('.obj', '')}: {dict(c)}")
