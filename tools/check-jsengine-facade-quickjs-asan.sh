#!/usr/bin/env bash
# tools/check-jsengine-facade-quickjs-asan.sh — acceptance for Phase 1 seam 1.4c (bead oo-s0y):
# rooted-handle/GC and exception plumbing on the ooscript façade's QuickJS-ng backend.
#
# Reuses tools/check-jsengine-facade-quickjs.sh's plain build+run (façade header unmodified,
# backend compiles -Wall -Wextra -Werror, unit test passes) and additionally rebuilds the backend
# and its unit test under AddressSanitizer (tools/asan-resource-dir.sh splices the CLANG64 ASan
# archives into the UCRT64 clang this repo builds with) and runs the sanitized binary: "ASan
# clean" means the sanitized test exits 0 with no ASan report, exercising the rooting/GC and
# exception-plumbing surface this bead added (addNamedObjectRoot/addNamedValueRoot/
# removeObjectRoot/removeValueRoot, ExceptionState save/restore/drop, isExceptionPending/
# getPendingException/setPendingException/clearPendingException/reportPendingException/
# reportError/reportWarning/reportOutOfMemory/setErrorReporter).
#
# Runs from the repo root in the MSYS2 UCRT64 shell (the only place the game builds anyway).
# Network access only on the first run per build directory (meson downloads the wrap once).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."   # repo root

# 1) The plain (non-sanitized) build+run: façade header unmodified, backend compiles clean,
#    unit test passes. This also builds the QuickJS-ng library the ASan pass below reuses.
bash "$script_dir/check-jsengine-facade-quickjs.sh"

oo="upstream/oolite"
hdr="$oo/src/Core/Scripting/ooscript/JSEngine.hpp"
impl="$oo/src/Core/Scripting/ooscript/JSEngine_quickjs.cpp"
test_src="$oo/tests/unit/test_jsengine_quickjs.cpp"
CXX="${CXX:-clang++}"
builddir_name="${OO_QUICKJS_BUILD_NAME:-build-qjs-facade}"
builddir="$oo/$builddir_name"
qjs_rel="subprojects/quickjs-0.16.2"
qjs_lib_dir="$builddir/$qjs_rel"
qjs_src_dir="$oo/$qjs_rel"
work="${OO_FACADE_QJS_ASAN_WORK:-$oo/.jsengine-facade-qjs-asan-work}"
rm -rf "$work"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }

for f in "$hdr" "$impl" "$test_src"; do
	[ -f "$f" ] || fail "missing $f"
done
[ -f "$qjs_lib_dir/libqjs-0.dll" ] || fail "libqjs-0.dll was not built by check-jsengine-facade-quickjs.sh"

step "ASan 1/3 splice the CLANG64 AddressSanitizer runtime into UCRT64 clang's resource dir"
rd="$(bash "$script_dir/asan-resource-dir.sh" --print)" || fail "could not build the spliced ASan resource directory"
dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir)" || fail "could not locate the ASan runtime DLL directory"

flags=(-std=c++20 -Wall -Wextra -Werror -fsanitize=address -fno-omit-frame-pointer -g -resource-dir "$rd" -fuse-ld=lld)
defs=(-DXP_WIN -DWIN32)
incs=(-I"$oo/src/Core/Scripting" -I"$qjs_src_dir")

step "ASan 2/3 backend and unit test build under -fsanitize=address"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" -c "$impl" -o "$work/backend_asan.o"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" "$test_src" "$work/backend_asan.o" -o "$work/test_jsengine_quickjs_asan.exe" \
	-L"$qjs_lib_dir" -lqjs

step "ASan 3/3 sanitized unit test runs clean"
cp "$qjs_lib_dir/libqjs-0.dll" "$work/"
cp "$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$work/" 2>/dev/null || true
cp "$dlldir/libc++.dll" "$work/" 2>/dev/null || true
out="$work/asan_run.log"
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"
PATH="$work:$dlldir:$PATH" "$work/test_jsengine_quickjs_asan.exe" >"$out" 2>&1
rc=$?
cat "$out"
[ "$rc" -eq 0 ] || fail "sanitized unit test exited $rc"
! grep -qi 'AddressSanitizer' "$out" || fail "the sanitized unit test printed an AddressSanitizer report"

echo "PASS: ooscript façade's QuickJS-ng backend (rooting/GC + exception plumbing) is ASan clean"
