"""Scratch: build a step's history snapshot (N(history), no upstream) to tell merge damage from the
history's own problems. Usage: python -I .agent-tmp/build-history.py N [--clean]"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, verify as V, stack
n = int(sys.argv[1])
m = S.load_manifest(); st = S.step_by_n(m, n)
_, _, theirs = S.merge_inputs(m, st)
commit = stack.git(S.GAME, "commit-tree", theirs, "-m", f"history snapshot of step {n} (scratch)")
era = V.era(S.GAME, theirs)
wt = V.ensure_worktree(S.GAME, V.WORKTREES["clang"], commit)
log = os.path.join(V.LOG_DIR, f"{n:03d}-history-build_clang.log")
if os.path.exists(log): os.remove(log)
rc, w = V.run_build(era, wt, "clang", "--clean" in sys.argv, log)
text = open(log, encoding="utf-8", errors="replace").read()
print(f"history snapshot {n} ({era}): rc={rc} warnings={w}")
for line in sorted(set(re.findall(r"^\.\./\.\./(src/\S+: (?:warning|error): .*)$", text, re.M)))[:80]:
    print("  " + line[:200])
