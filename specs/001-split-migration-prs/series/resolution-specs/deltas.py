"""Scratch: per unresolved hunk of step N, show upstream's own change (base -> ours) and the head of
the history's side. Usage: python -I .agent-tmp/deltas.py N"""
import difflib
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, trees  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
n = int(sys.argv[1])
m = S.load_manifest()
st = S.step_by_n(m, n)
b, o, t = S.merge_inputs(m, st)
tree, conf = trees.merge(S.GAME, b, o, t)
_, unresolved = trees.target_tree(S.GAME, b, o, t, S.resolutions_dir(st))
for p in unresolved:
    k = conf[p]
    if not all(k.values()):
        print(f"######## {p}: FILE-LEVEL base={bool(k['base'])} ours={bool(k['ours'])} theirs={bool(k['theirs'])}")
        if k["base"] and k["ours"]:
            d = list(difflib.unified_diff(trees._lines(S.GAME, k["base"]), trees._lines(S.GAME, k["ours"]), n=0))[2:]
            print("   upstream:", "".join(d)[:800])
        continue
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for name in ("ours", "base", "theirs"):
            f = os.path.join(tmp, name)
            open(f, "wb").write(trees._git(S.GAME, "cat-file", "blob", k[name]).stdout)
            files.append(f)
        txt = subprocess.run(["git", "merge-file", "-p", "--diff3", *files], capture_output=True).stdout.decode(
            "utf-8", "surrogateescape").splitlines(keepends=True)
    hunks, cur, sect = [], None, None
    for line in txt:
        if line.startswith("<<<<<<<"):
            cur, sect = {"o": [], "b": [], "t": []}, "o"
        elif cur is not None and line.startswith("|||||||"):
            sect = "b"
        elif cur is not None and line.startswith("=======") and sect == "b":
            sect = "t"
        elif cur is not None and line.startswith(">>>>>>>"):
            hunks.append(cur)
            cur = None
        elif cur is not None:
            cur[sect].append(line)
    hard = [h for h in hunks if trees.resolve_hunk(h["b"], h["o"], h["t"],
                                                   lambda r: trees.moved_elsewhere(S.GAME, o, p, r))[0] is None]
    print(f"######## {p}: {len(hard)} hunks")
    for i, h in enumerate(hard):
        d = [l for l in difflib.unified_diff(h["b"], h["o"], n=0)][2:]
        d = [l for l in d if not l.startswith("@@")]
        print(f"--- hunk {i}: upstream changed {len(d)} lines; history side {len(h['t'])} lines")
        print("".join("    U" + l for l in d[:14]), end="")
        print("".join("    H " + l for l in h["t"][:3]), end="")
