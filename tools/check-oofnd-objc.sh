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
# Every build and run happens concurrently (bead oo-n712; OO_OOFND_JOBS bounds it, default nproc),
# each run with its own TMP/TEMP/TMPDIR; the report then walks the logs in the fixed order above
# and fails at the first failure, as a serial run did.
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
# report_test <exe> <log>: reports one finished run (exit status in <log>.rc); fails on nonzero
# exit, no summary line, or zero tests.
report_test() {
	local exe="$1" log="$2" rc=1 line summary=""
	[ ! -f "$log.rc" ] || read -r rc < "$log.rc" || true
	cat "$log"
	[ "$rc" -eq 0 ] || fail "${exe##*/} exited $rc"
	# The first "oo_test: " line (as grep -m1 '^oo_test: '), parsed with builtins: forks are the
	# expensive part of this loop on MSYS.
	while IFS= read -r line || [ -n "$line" ]; do
		if [[ $line == 'oo_test: '* ]]; then summary="$line"; break; fi
	done < "$log"
	[ -n "$summary" ] || fail "${exe##*/} printed no oo_test summary line"
	local re='.*: ([0-9]+) tests, ([0-9]+) checks, ([0-9]+) failures'
	[[ $summary =~ $re ]] && [ "${BASH_REMATCH[1]}" -gt 0 ] || fail "${exe##*/} ran zero tests"
	LAST_TESTS="${BASH_REMATCH[1]}"; LAST_CHECKS="${BASH_REMATCH[2]}"
}

# --- build and run everything concurrently (bead oo-n712), then report in the serial order -------
# Same compiles, same runs as one test at a time; each keeps its own log and exit status, and the
# report below walks them in the fixed order, failing at the first failure exactly as before.
rd_ok=1; rd="" dlldir=""
rd="$(bash "$script_dir/asan-resource-dir.sh" --print)" || rd_ok=0
[ "$rd_ok" -eq 0 ] || dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir)" || rd_ok=2
jobs="${OO_OOFND_JOBS:-$(nproc 2>/dev/null || echo 4)}"
throttle() { while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do wait -n || true; done; }
bg_rc() { local rcf="$1"; shift; ( rc=0; "$@" || rc=$?; echo "$rc" > "$rcf" ) & }
# build_one <test.mm> <plain|asan> <exe>; run_one <exe> <log>: TMP/TEMP/TMPDIR is a private dir.
build_one() {
	if [ "$2" = plain ]; then
		"$CXX" "${flags[@]}" "${incs[@]}" "$1" "${sources[@]}" "${link[@]}" -o "$3"
	else
		"$CXX" "${flags[@]}" -fsanitize=address -fno-omit-frame-pointer -g -O1 -resource-dir "$rd" \
			"${incs[@]}" "$1" "${sources[@]}" "${link[@]}" -o "$3"
	fi
}
run_one() {
	local sbx="$PWD/$work/sandbox/$(basename "$1" .exe)"
	mkdir -p "$sbx"
	sbx="$(cygpath -w "$sbx" 2>/dev/null || printf '%s' "$sbx")"
	TMP="$sbx" TEMP="$sbx" TMPDIR="$sbx" "$1" > "$2" 2>&1
}
kinds=(plain)
[ "$rd_ok" -ne 1 ] || kinds+=(asan)
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	for kind in "${kinds[@]}"; do
		[ "$kind" = plain ] && exe="$work/$name.exe" || exe="$work/${name}_asan.exe"
		throttle
		bg_rc "$exe.build.rc" build_one "$t" "$kind" "$exe" > "$exe.build.log" 2>&1
	done
done
wait
if [ "$rd_ok" -eq 1 ]; then
	cp "$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$work/" 2>/dev/null || true
	cp "$dlldir/libc++.dll" "$work/" 2>/dev/null || true   # the ASan runtime imports it
fi
asan_opts="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	if [ "$(cat "$work/$name.exe.build.rc" 2>/dev/null)" = 0 ]; then
		throttle
		bg_rc "$work/$name.log.rc" run_one "$work/$name.exe" "$work/$name.log"
	fi
	if [ "$(cat "$work/${name}_asan.exe.build.rc" 2>/dev/null)" = 0 ]; then
		throttle
		ASAN_OPTIONS="$asan_opts" PATH="$work:$dlldir:$PATH" \
			bg_rc "$work/${name}_asan.log.rc" run_one "$work/${name}_asan.exe" "$work/${name}_asan.log"
	fi
done
wait

# --- 3 + 4. build, prove the imports, run -------------------------------------------------------
step "3/5 unit tests: libobjc2 only, -Wall -Wextra -Werror, --fatal-warnings"
step "4/5 import table: libobjc, no gnustep-base"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	exe="$work/$name.exe"
	echo "   link: $CXX ... $t ${sources[*]} ${link[*]}"
	cat "$exe.build.log" >&2
	[ "$(cat "$exe.build.rc" 2>/dev/null)" = 0 ] || fail "$t does not build"
	imports="$(objdump -p "$exe" | sed -n 's/^[[:space:]]*DLL Name:[[:space:]]*//p')"
	grep -qi '^libobjc' <<<"$imports" || fail "$name does not import libobjc; the floor is not on the runtime it claims"
	if grep -qi 'gnustep' <<<"$imports"; then
		fail "$name imports a GNUstep Foundation DLL: $(printf '%s\n' "$imports" | grep -i gnustep | tr '\n' ' ')"
	fi
	echo "   $name imports: $(printf '%s\n' "$imports" | grep -vi '^api-ms-win' | tr '\n' ' ')"
	report_test "$exe" "$work/$name.log"
	total_tests=$((total_tests + LAST_TESTS))
	total_checks=$((total_checks + LAST_CHECKS))
done

# --- 5. ASan ------------------------------------------------------------------------------------
step "5/5 unit tests under -fsanitize=address"
[ "$rd_ok" -ne 0 ] || fail "could not build the spliced ASan resource directory"
[ "$rd_ok" -ne 2 ] || fail "could not locate the ASan runtime DLL directory"
for t in "${tests[@]}"; do
	name="$(basename "$t" .mm)"
	cat "$work/${name}_asan.exe.build.log" >&2
	[ "$(cat "$work/${name}_asan.exe.build.rc" 2>/dev/null)" = 0 ] || fail "$t does not build under -fsanitize=address"
	report_test "$work/${name}_asan.exe" "$work/${name}_asan.log"
	! grep -qi 'AddressSanitizer' "$work/${name}_asan.log" || fail "${name} printed an AddressSanitizer report"
done

echo "PASS: oofnd objc floor — ${#tests[@]} test file(s), $total_tests tests, $total_checks checks, libobjc2 only, green plain and under ASan ($(( $(date +%s) - t0 ))s)"
