"""Scratch runner: apply hand resolutions for step N from .agent-tmp/res/NNN.py and record them.

NNN.py defines
  RES = {path: [spec, spec, ...]}   one spec per conflict hunk, in file order:
        "ours" | "theirs" | "both" (ours then theirs) | "theirs+ours" | literal text
  DELETE = [path, ...]              paths resolved by deleting them
Usage: python -I .agent-tmp/apply_res.py N [--dry]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, trees, history  # noqa: E402

n = int(sys.argv[1])
dry = "--dry" in sys.argv
spec_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "res", f"{n:03d}.py")
ns = {}
with open(spec_file, encoding="utf-8") as f:
    exec(f.read(), ns)
RES, DELETE = ns.get("RES", {}), ns.get("DELETE", [])

m = S.load_manifest()
st = S.step_by_n(m, n)
b, o, t = S.merge_inputs(m, st)
tree, conf = trees.merge(S.GAME, b, o, t)
HUNK = re.compile(r"^<<<<<<< [^\n]*\n(.*?)^=======\n(.*?)^>>>>>>> [^\n]*\n", re.S | re.M)
for path, specs in RES.items():
    if path not in conf:
        raise SystemExit(f"{path}: not a conflict in step {n}")
    k = conf[path]
    text = "".join(trees.merge_file_by_hunks(S.GAME, k["base"], k["ours"], k["theirs"])[0])
    hunks = list(HUNK.finditer(text))
    if len(hunks) != len(specs):
        raise SystemExit(f"{path}: {len(hunks)} hunks, {len(specs)} specs")
    out, pos = [], 0
    for mt, spec in zip(hunks, specs):
        ours, theirs = mt.group(1), mt.group(2)
        out.append(text[pos:mt.start()])
        if callable(spec):
            out.append(spec(ours, theirs))
        elif spec == "ours":
            out.append(ours)
        elif spec == "theirs":
            out.append(theirs)
        elif spec == "both":
            out.append(ours + theirs)
        elif spec == "theirs+ours":
            out.append(theirs + ours)
        else:
            out.append(spec if spec.endswith("\n") or spec == "" else spec + "\n")
        pos = mt.end()
    out.append(text[pos:])
    result = "".join(out)
    if re.search(r"^(<<<<<<<|=======$|>>>>>>>)", result, re.M):
        raise SystemExit(f"{path}: markers left")
    print(f"{path}: {len(hunks)} hunks resolved")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path,
                                result.encode("utf-8", "surrogateescape"))
for path in DELETE:
    print(f"{path}: deleted")
    if not dry:
        trees.record_resolution(S.GAME, b, o, t, S.resolutions_dir(st), path, None)
