"""Step 3 (.m -> .mm): resolve the OOCocoa rename/rename and the Core meson source list.

Upstream (#737) renamed OOCocoa.m -> OOFoundation.m and dropped NSUserDefaults+Override.m from the
main source list; the history renamed every .m to .mm. Result: OOFoundation.mm with both sides'
content, and the history's .mm list with upstream's two list changes.
Usage: python -I .agent-tmp/res/003_custom.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from tools.series import series as S, trees  # noqa: E402

m = S.load_manifest()
st = S.step_by_n(m, 3)
b, o, t = S.merge_inputs(m, st)
_, c = trees.merge(S.GAME, b, o, t)
rd = S.resolutions_dir(st)

B = trees._lines(S.GAME, c["src/Core/OOCocoa.m"]["base"])
O = trees._lines(S.GAME, c["src/Core/OOFoundation.m"]["ours"])
T = trees._lines(S.GAME, c["src/Core/OOCocoa.mm"]["theirs"])
out = trees.auto_merge_text(B, O, T) or trees.transplant(B, O, T)
if out is None:
    raise SystemExit("OOFoundation.mm: the three versions do not merge")
for p in ("src/Core/OOCocoa.m", "src/Core/OOCocoa.mm", "src/Core/OOFoundation.m"):
    trees.record_resolution(S.GAME, b, o, t, rd, p, None)
trees.record_resolution(S.GAME, b, o, t, rd, "src/Core/OOFoundation.mm", "".join(out).encode("utf-8", "surrogateescape"))

T = trees._lines(S.GAME, c["src/Core/meson.build"]["theirs"])
i = next(i for i, line in enumerate(T) if line == "    'NSUserDefaults+Override.mm',\n")  # the main list's entry
out = [line.replace("'OOCocoa.mm'", "'OOFoundation.mm'") for line in T[:i] + T[i + 1:]]
assert sum("'OOFoundation.mm'" in line for line in out) == 1
trees.record_resolution(S.GAME, b, o, t, rd, "src/Core/meson.build", "".join(out).encode())
print("step 3: OOFoundation.mm and meson.build recorded")
