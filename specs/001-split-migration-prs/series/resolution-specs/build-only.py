"""Scratch: build one step's branch in the Clang verification worktree; print rc, warnings, errors."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.series import series as S, verify as V
n = int(sys.argv[1])
m = S.load_manifest(); st = S.step_by_n(m, n)
c = V._git(S.GAME, "rev-parse", "refs/heads/" + st["branch"]).strip()
era = V.era(S.GAME, V._git(S.GAME, "rev-parse", c + "^{tree}").strip())
wt = V.ensure_worktree(S.GAME, V.WORKTREES["clang"], c)
log = os.path.join(V.LOG_DIR, f"{n:03d}-build_clang.log")
if os.path.exists(log): os.remove(log)
rc, w = V.run_build(era, wt, "clang", "--clean" in sys.argv, log)
text = open(log, encoding="utf-8", errors="replace").read()
print(f"step {n} ({era}): rc={rc} warnings={w}")
for line in sorted(set(re.findall(r"^\.\./\.\./(src/\S+: (?:warning|error): .*)$", text, re.M)))[:60]:
    print("  " + line[:220])
for line in sorted(set(re.findall(r"^(ld\.lld: error: .*)$", text, re.M)))[:10]:
    print("  " + line)
