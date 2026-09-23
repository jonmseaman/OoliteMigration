#!/usr/bin/env bash
# tools/check-oofnd.sh — the fast, standalone acceptance for oofnd, the Phase 2 Foundation
# replacement (bead oo-fde established it; every later oofnd seam reuses it unchanged).
#
#     bash tools/check-oofnd.sh
#
# No build directory, no meson, no network: it compiles straight from the tree, so it runs from
# a clean checkout well inside the ADR-0021 accept budget (about ten seconds per test file).
#
#   1. inventory  every upstream/oolite/tests/unit/oofnd/test_*.cpp; ZERO tests is a failure, and
#                 so is a test file that tests/unit/oofnd/meson.build does not register (the
#                 `meson test --suite oofnd` wiring must not silently lag the tree);
#   2. canary     one TU per oofnd header, plus one TU including every header, compiles at
#                 -std=c++20 -Wall -Wextra -Werror (ADR-0011's canary TU): each header is
#                 self-contained. The all-headers TU is compiled a second time with
#                 -fno-exceptions, since oofnd APIs must not depend on exceptions;
#   3. tests      each test_*.cpp is compiled with -std=c++20 -Wall -Wextra -Werror and run;
#   4. asan       each is rebuilt under -fsanitize=address (tools/asan-resource-dir.sh splices
#                 the CLANG64 ASan runtime into UCRT64 clang) and run; any AddressSanitizer
#                 report fails the check even if the test exited 0.
#
# Totals are parsed from each test's "oo_test: <file>: N tests, M checks, F failures" line.
#
# Runs from anywhere in the MSYS2 UCRT64 shell. Paths are deliberately kept RELATIVE to the
# repo root (see tools/check-jsengine-facade-quickjs.sh: absolute C:/... arguments get
# MSYS-mangled and re-resolved against the wrong root).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."   # repo root

oo="upstream/oolite"
src_dir="$oo/src/oofnd"
test_dir="$oo/tests/unit/oofnd"
CXX="${CXX:-clang++}"
work="${OO_OOFND_WORK:-$oo/.oofnd-check-work}"
rm -rf "$work"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }
t0=$(date +%s)

command -v "$CXX" >/dev/null 2>&1 || fail "no $CXX on PATH (MSYSTEM=${MSYSTEM:-unset}); run this from the MSYS2 UCRT64 shell"

flags=(-std=c++20 -Wall -Wextra -Werror)
incs=(-I"$oo/src" -I"$test_dir")

# --- 1. inventory -------------------------------------------------------------------------------
step "1/4 inventory"
shopt -s nullglob
headers=("$src_dir"/*.hpp)
tests=("$test_dir"/test_*.cpp)
shopt -u nullglob
[ "${#headers[@]}" -gt 0 ] || fail "no headers under $src_dir"
[ "${#tests[@]}" -gt 0 ] || fail "found ZERO tests matching $test_dir/test_*.cpp; an empty suite is not a pass"
[ -f "$test_dir/meson.build" ] || fail "missing $test_dir/meson.build (the meson test --suite oofnd wiring)"
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	grep -q "'$name'" "$test_dir/meson.build" || fail "$t is not registered in $test_dir/meson.build, so meson test --suite oofnd would skip it"
done
echo "   ${#headers[@]} header(s), ${#tests[@]} test file(s)"

# --- 2. canary TUs ------------------------------------------------------------------------------
step "2/4 canary: every oofnd header compiles alone and together at -std=c++20 -Wall -Wextra -Werror"
all="$work/canary_all.cpp"
: > "$all"
for h in "${headers[@]}"; do
	hn="$(basename "$h")"
	one="$work/canary_${hn%.hpp}.cpp"
	printf '#include "oofnd/%s"\n#include "oofnd/%s"\nint main() { return 0; }\n' "$hn" "$hn" > "$one"
	"$CXX" "${flags[@]}" -I"$oo/src" -fsyntax-only "$one" || fail "oofnd/$hn does not compile on its own (or is not include-guarded)"
	printf '#include "oofnd/%s"\n' "$hn" >> "$all"
done
printf 'int main() { return 0; }\n' >> "$all"
"$CXX" "${flags[@]}" -I"$oo/src" -fsyntax-only "$all" || fail "the all-headers canary TU does not compile"
"$CXX" "${flags[@]}" -fno-exceptions -I"$oo/src" -fsyntax-only "$all" || fail "the all-headers canary TU does not compile with -fno-exceptions"

# run_test <exe> <log>: runs one test binary; echoes its output; fails on nonzero exit or no summary.
total_tests=0
total_checks=0
run_test() {
	local exe="$1" log="$2" rc=0
	"$exe" > "$log" 2>&1 || rc=$?
	cat "$log"
	[ "$rc" -eq 0 ] || fail "$(basename "$exe") exited $rc"
	local summary
	summary="$(grep -m1 '^oo_test: ' "$log" || true)"
	[ -n "$summary" ] || fail "$(basename "$exe") printed no oo_test summary line"
	local nt nc
	nt="$(printf '%s\n' "$summary" | sed -E 's/.*: ([0-9]+) tests, ([0-9]+) checks, ([0-9]+) failures.*/\1/')"
	nc="$(printf '%s\n' "$summary" | sed -E 's/.*: ([0-9]+) tests, ([0-9]+) checks, ([0-9]+) failures.*/\2/')"
	[ "$nt" -gt 0 ] || fail "$(basename "$exe") ran zero tests"
	LAST_TESTS="$nt"; LAST_CHECKS="$nc"
}

# --- 3. plain build + run ------------------------------------------------------------------------
step "3/4 unit tests: -std=c++20 -Wall -Wextra -Werror"
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	"$CXX" "${flags[@]}" "${incs[@]}" "$t" -o "$work/$name.exe" || fail "$t does not compile"
	run_test "$work/$name.exe" "$work/$name.log"
	total_tests=$((total_tests + LAST_TESTS))
	total_checks=$((total_checks + LAST_CHECKS))
done

# --- 4. ASan build + run -------------------------------------------------------------------------
step "4/4 unit tests under -fsanitize=address"
rd="$(bash "$script_dir/asan-resource-dir.sh" --print)" || fail "could not build the spliced ASan resource directory"
dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir)" || fail "could not locate the ASan runtime DLL directory"
asan_flags=("${flags[@]}" -fsanitize=address -fno-omit-frame-pointer -g -O1 -resource-dir "$rd" -fuse-ld=lld)
cp "$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$work/" 2>/dev/null || true
cp "$dlldir/libc++.dll" "$work/" 2>/dev/null || true
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	"$CXX" "${asan_flags[@]}" "${incs[@]}" "$t" -o "$work/${name}_asan.exe" || fail "$t does not compile under -fsanitize=address"
	PATH="$work:$dlldir:$PATH" run_test "$work/${name}_asan.exe" "$work/${name}_asan.log"
	! grep -qi 'AddressSanitizer' "$work/${name}_asan.log" || fail "${name} printed an AddressSanitizer report"
done

# --- the Objective-C floor (bead oo-3rb.1): Objective-C++ tests on libobjc2 alone -----------------
bash "$script_dir/check-oofnd-objc.sh" || fail "the oofnd Objective-C floor check (tools/check-oofnd-objc.sh) failed"

echo "PASS: oofnd — ${#headers[@]} header(s) canary-clean; ${#tests[@]} test file(s), $total_tests tests, $total_checks checks, green plain and under ASan ($(( $(date +%s) - t0 ))s)"
