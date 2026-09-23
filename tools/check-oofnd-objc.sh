#!/usr/bin/env bash
# tools/check-oofnd-objc.sh — the standalone acceptance for oofnd's Foundation-free Objective-C
# floor (bead oo-3rb.1, proposed ADR-0029): the OOObject root class and the OOConstantString class
# behind @"..." literals, on libobjc2 ALONE. tools/check-oofnd.sh runs it; it also runs by itself:
#
#     bash tools/check-oofnd-objc.sh
#
# No build directory, no meson, no network, like check-oofnd.sh.
#
#   1. inventory  every upstream/oolite/tests/unit/oofnd/test_*.mm; ZERO is a failure, and so is
#                 one that tests/unit/oofnd/meson.build does not register;
#   2. canary     each src/oofnd/objc/*.h compiles alone as Objective-C++ at -Wall -Wextra -Werror;
#   3. tests      each test_*.mm is built with the game's runtime flags (-fobjc-runtime=gnustep-2.2,
#                 -fobjc-exceptions) plus the floor's (-fno-constant-cfstrings
#                 -fconstant-string-class=OOConstantString), linked with -lobjc and NOTHING else
#                 from GNUstep, with -Wl,--fatal-warnings (as meson's werror links), and run;
#   4. no-gnustep the linked executable's PE import table (objdump -p) must name libobjc and must
#                 not name any gnustep-base DLL: the proof that the floor needs no Foundation;
#   5. asan       each is rebuilt under -fsanitize=address and run.
#
# lld is required: GNU ld cannot resolve the gnustep-2 ABI's COFF selector symbols (ADR-0029).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."   # repo root; paths stay RELATIVE (see check-oofnd.sh on MSYS path mangling)

oo="upstream/oolite"
src_dir="$oo/src/oofnd/objc"
test_dir="$oo/tests/unit/oofnd"
CXX="${CXX:-clang++}"
work="${OO_OOFND_OBJC_WORK:-$oo/.oofnd-objc-check-work}"
rm -rf "$work"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== objc $*"; }
t0=$(date +%s)

command -v "$CXX" >/dev/null 2>&1 || fail "no $CXX on PATH (MSYSTEM=${MSYSTEM:-unset}); run this from the MSYS2 UCRT64 shell"

flags=(-x objective-c++ -std=c++20 -Wall -Wextra -Werror
	-fobjc-runtime=gnustep-2.2 -fexceptions -fobjc-exceptions -fblocks
	-fno-constant-cfstrings -fconstant-string-class=OOConstantString)
incs=(-I"$oo/src" -I"$test_dir")
link=(-fuse-ld=lld -Wl,--fatal-warnings -lobjc)

# --- 1. inventory -------------------------------------------------------------------------------
step "1/5 inventory"
shopt -s nullglob
headers=("$src_dir"/*.h)
sources=("$src_dir"/*.mm)
tests=("$test_dir"/test_*.mm)
shopt -u nullglob
[ "${#headers[@]}" -gt 0 ] || fail "no headers under $src_dir"
[ "${#sources[@]}" -gt 0 ] || fail "no sources under $src_dir"
[ "${#tests[@]}" -gt 0 ] || fail "found ZERO tests matching $test_dir/test_*.mm; an empty suite is not a pass"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	grep -q "'$name'" "$test_dir/meson.build" || fail "$t is not registered in $test_dir/meson.build, so meson test --suite oofnd would skip it"
done
echo "   ${#headers[@]} header(s), ${#sources[@]} source(s), ${#tests[@]} test file(s)"

# --- 2. canary ----------------------------------------------------------------------------------
step "2/5 canary: every oofnd/objc header compiles alone"
for h in "${headers[@]}"; do
	hn="$(basename "$h")"
	one="$work/canary_${hn%.h}.mm"
	printf '#include "oofnd/objc/%s"\n#include "oofnd/objc/%s"\nint main() { return 0; }\n' "$hn" "$hn" > "$one"
	"$CXX" "${flags[@]}" -I"$oo/src" -fsyntax-only "$one" || fail "oofnd/objc/$hn does not compile on its own (or is not include-guarded)"
done

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
	LAST_TESTS="$(printf '%s\n' "$summary" | sed -E 's/.*: ([0-9]+) tests, ([0-9]+) checks, ([0-9]+) failures.*/\1/')"
	LAST_CHECKS="$(printf '%s\n' "$summary" | sed -E 's/.*: ([0-9]+) tests, ([0-9]+) checks, ([0-9]+) failures.*/\2/')"
	[ "$LAST_TESTS" -gt 0 ] || fail "$(basename "$exe") ran zero tests"
}

# --- 3 + 4. build, prove the imports, run -------------------------------------------------------
step "3/5 unit tests: libobjc2 only, -Wall -Wextra -Werror, --fatal-warnings"
step "4/5 import table: libobjc, no gnustep-base"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	exe="$work/$name.exe"
	echo "   link: $CXX ... $t ${sources[*]} ${link[*]}"
	"$CXX" "${flags[@]}" "${incs[@]}" "$t" "${sources[@]}" "${link[@]}" -o "$exe" || fail "$t does not build"
	imports="$(objdump -p "$exe" | sed -n 's/^[[:space:]]*DLL Name:[[:space:]]*//p')"
	printf '%s\n' "$imports" | grep -qi '^libobjc' || fail "$name does not import libobjc; the floor is not on the runtime it claims"
	if printf '%s\n' "$imports" | grep -qi 'gnustep'; then
		fail "$name imports a GNUstep Foundation DLL: $(printf '%s\n' "$imports" | grep -i gnustep | tr '\n' ' ')"
	fi
	echo "   $name imports: $(printf '%s\n' "$imports" | grep -vi '^api-ms-win' | tr '\n' ' ')"
	run_test "$exe" "$work/$name.log"
	total_tests=$((total_tests + LAST_TESTS))
	total_checks=$((total_checks + LAST_CHECKS))
done

# --- 5. ASan ------------------------------------------------------------------------------------
step "5/5 unit tests under -fsanitize=address"
rd="$(bash "$script_dir/asan-resource-dir.sh" --print)" || fail "could not build the spliced ASan resource directory"
dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir)" || fail "could not locate the ASan runtime DLL directory"
cp "$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$work/" 2>/dev/null || true
cp "$dlldir/libc++.dll" "$work/" 2>/dev/null || true   # the ASan runtime imports it
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	"$CXX" "${flags[@]}" -fsanitize=address -fno-omit-frame-pointer -g -O1 -resource-dir "$rd" \
		"${incs[@]}" "$t" "${sources[@]}" "${link[@]}" -o "$work/${name}_asan.exe" || fail "$t does not build under -fsanitize=address"
	PATH="$work:$dlldir:$PATH" run_test "$work/${name}_asan.exe" "$work/${name}_asan.log"
	! grep -qi 'AddressSanitizer' "$work/${name}_asan.log" || fail "${name} printed an AddressSanitizer report"
done

echo "PASS: oofnd objc floor — ${#tests[@]} test file(s), $total_tests tests, $total_checks checks, libobjc2 only, green plain and under ASan ($(( $(date +%s) - t0 ))s)"
