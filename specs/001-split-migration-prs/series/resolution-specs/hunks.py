"""Scratch: dump step N's conflict hunks that the tool's rules can't resolve, with context.

Usage: python -I .agent-tmp/hunks.py N [context_lines] > .agent-tmp/hunks-NNN.txt
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, trees  # noqa: E402

n = int(sys.argv[1])
ctx = int(sys.argv[2]) if len(sys.argv) > 2 else 4
m = S.load_manifest()
st = S.step_by_n(m, n)
b, o, t = S.merge_inputs(m, st)
tree, conf = trees.merge(S.GAME, b, o, t)
_, unresolved = trees.target_tree(S.GAME, b, o, t, S.resolutions_dir(st))
for p in unresolved:
    k = conf[p]
    if not all(k.values()):
        print(f"######## {p}: FILE-LEVEL {k}")
        continue
    lines = "".join(trees.merge_file_by_hunks(S.GAME, k["base"], k["ours"], k["theirs"], o, p)[0]).splitlines()
    starts = [i for i, l in enumerate(lines) if l.startswith("<<<<<<<")]
    print(f"######## {p}: {len(starts)} hunks")
    for h, s in enumerate(starts):
        e = next(i for i in range(s, len(lines)) if lines[i].startswith(">>>>>>>"))
        print(f"--- hunk {h} (lines {s + 1}-{e + 1})")
        for i in range(max(0, s - ctx), min(len(lines), e + ctx + 1)):
            print(f"{i + 1:6}| {lines[i]}")
