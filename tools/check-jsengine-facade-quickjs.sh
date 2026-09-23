#!/usr/bin/env bash
# tools/check-jsengine-facade-quickjs.sh — acceptance for Phase 1 seam 1.4b (bead oo-0kq):
# the ooscript façade's QuickJS-ng backend (Context/Value/Object/ClassDef lifecycle, with
# resolve/enumerate mapped onto JSClassExoticMethods, and private-pointer attach/retrieve).
#
# Complements tools/check-jsengine-facade.sh (the header's engine-neutrality and, since bead
# oo-7wx deleted SpiderMonkey, the tree's): QuickJS-ng is the only backend.
#
#   1. meson configures and builds libquickjs-ng (since bead oo-7wx the only engine, so no option selects it);
#   2. the façade header still compiles unmodified against the QuickJS-ng backend's include path;
#   3. the backend compiles clean under -std=c++20 -Wall -Wextra -Werror;
#   4. its unit test (tests/unit/test_jsengine_quickjs.cpp) links against the vendored QuickJS-ng
#      library and passes.
#
# Runs from the repo root in the MSYS2 UCRT64 shell (the only place the game builds anyway).
# Network access only on the first run per build directory (meson downloads the wrap once).
#
# Paths below are deliberately kept RELATIVE (cd'ing into place rather than interpolating
# absolute C:/... paths into meson/clang command lines): on this toolchain an absolute
# "C:/Users/..." argument gets MSYS-mangled into "/c/Users/..." and then meson/clang re-resolves
# it against the wrong root (observed as a doubled "C:/c/Users/..." build dir, or the compiler
# reporting "no such file" for an input file that plainly exists). Relative paths sidestep it.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."   # repo root

oo="upstream/oolite"
hdr="$oo/src/Core/Scripting/ooscript/JSEngine.hpp"
impl="$oo/src/Core/Scripting/ooscript/JSEngine_quickjs.cpp"
test_src="$oo/tests/unit/test_jsengine_quickjs.cpp"
CXX="${CXX:-clang++}"
builddir_name="${OO_QUICKJS_BUILD_NAME:-build-qjs-facade}"
builddir="$oo/$builddir_name"
work="${OO_FACADE_QJS_WORK:-$oo/.jsengine-facade-qjs-work}"
rm -rf "$work"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }

for f in "$hdr" "$impl" "$test_src"; do
	[ -f "$f" ] || fail "missing $f"
done

step "1/4 meson builds the vendored QuickJS-ng library"
if [ ! -d "$builddir" ]; then
	# The game links QuickJS-ng statically (bead oo-1gc.4); this unit-test build keeps its DLL.
	( cd "$oo" && meson setup "$builddir_name" -Dquickjs-ng:default_library=shared )
fi
qjs_rel="subprojects/quickjs-0.16.2"
( cd "$oo" && ninja -C "$builddir_name" "$qjs_rel/libqjs-0.dll" >/dev/null )
qjs_lib_dir="$builddir/$qjs_rel"
[ -f "$qjs_lib_dir/libqjs-0.dll" ] || fail "libqjs-0.dll was not built"
qjs_src_dir="$oo/$qjs_rel"
[ -f "$qjs_src_dir/quickjs.h" ] || fail "missing $qjs_src_dir/quickjs.h; meson subproject fetch failed"

flags=(-std=c++20 -Wall -Wextra -Werror)
defs=(-DXP_WIN -DWIN32)
incs=(-I"$oo/src/Core/Scripting" -I"$qjs_src_dir")

step "2/4 façade header still compiles unmodified against this backend"
printf '#include "ooscript/JSEngine.hpp"\nint main() { ooscript::Value v{0}; return v.bits == 0 ? 0 : 1; }\n' > "$work/hdr_only.cpp"
"$CXX" "${flags[@]}" -I"$oo/src/Core/Scripting" -fsyntax-only "$work/hdr_only.cpp"

step "3/4 QuickJS-ng backend compiles clean"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" -c "$impl" -o "$work/backend.o"

step "4/4 unit test builds against the vendored QuickJS-ng and passes"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" "$test_src" "$work/backend.o" -o "$work/test_jsengine_quickjs.exe" \
	-L"$qjs_lib_dir" -lqjs
cp "$qjs_lib_dir/libqjs-0.dll" "$work/"
PATH="$qjs_lib_dir:$PATH" "$work/test_jsengine_quickjs.exe"

echo "PASS: ooscript façade's QuickJS-ng backend builds and its unit test passes"
