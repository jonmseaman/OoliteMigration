"""Step 17 (.mm -> .cpp): the history's OOCocoa.cpp is upstream's OOFoundation: OOFoundation.cpp."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from tools.series import series as S, trees, history  # noqa: E402
m = S.load_manifest(); st = S.step_by_n(m, 17); b, o, t = S.merge_inputs(m, st)
_, c = trees.merge(S.GAME, b, o, t); rd = S.resolutions_dir(st)
B = trees._lines(S.GAME, history.git(S.GAME, "rev-parse", f"{b}:src/Core/OOCocoa.mm"))
O = trees._lines(S.GAME, c["src/Core/OOFoundation.mm"]["ours"])
T = trees._lines(S.GAME, c["src/Core/OOCocoa.cpp"]["theirs"])
out = trees.auto_merge_text(B, O, T) or trees.transplant(B, O, T)
if out is None:
    raise SystemExit("OOFoundation.cpp: the three versions do not merge")
for p in ("src/Core/OOCocoa.cpp", "src/Core/OOFoundation.mm"):
    trees.record_resolution(S.GAME, b, o, t, rd, p, None)
trees.record_resolution(S.GAME, b, o, t, rd, "src/Core/OOFoundation.cpp", "".join(out).encode("utf-8", "surrogateescape"))
print("step 17: OOFoundation.cpp recorded")
