#!/usr/bin/env bash
# tools/check-oofnd.sh — the fast, standalone acceptance for oofnd, the Phase 2 Foundation
# replacement (bead oo-fde established it; every later oofnd seam reuses it unchanged).
#
#     bash tools/check-oofnd.sh
#     OO_CHECK_OOFND_NO_MEMO=1 bash tools/check-oofnd.sh    # never answer from the memo
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
# Speed (bead oo-n712, the ADR-0021 300 s budget). WHAT is checked is unchanged; only when:
#   * concurrency  the canary TUs compile concurrently; the Objective-C floor
#                  (tools/check-oofnd-objc.sh) runs in the background from the start and its
#                  output is printed where a serial run printed it; every plain and ASan test
#                  binary runs concurrently. All are bounded by the build's job count
#                  (OO_OOFND_JOBS, default nproc). Each run keeps its own log; the logs are then
#                  reported in the same fixed order as a serial run, and the first failure in that
#                  order fails the check exactly as before, so the exit status is the OR of all.
#   * sandboxes    each test run gets its own directory as TMP/TEMP/TMPDIR, so binaries that use
#                  a fixed name under the temp directory (test_defaults, test_resourcepaths; the
#                  plain and ASan builds of one test) cannot collide on disk.
#   * memo         a sha256 over every input: src/oofnd/** and tests/unit/oofnd/** (which hold
#                  the objc floor's sources and tests too), this script, check-oofnd-objc.sh,
#                  asan-resource-dir.sh, the compiler's and objdump's identity, the libobjc2 and
#                  ASan runtime binaries, the installed MSYS2 package set, CXX and ASAN_OPTIONS.
#                  When a previous run with the same hash was fully green it prints
#                  "PASS (memoised: <hash>, green at <time>): <that run's summary>" and exits 0.
#                  The cache is ${XDG_CACHE_HOME:-$HOME/.cache}/oolite/check-oofnd/<hash>, written
#                  only after a fully green real run. OO_CHECK_OOFND_NO_MEMO=1 forces a real run
#                  (tests/nightly/checks.txt does, so the memo never hides a flake from the night).
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

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }
t0=$(date +%s)

command -v "$CXX" >/dev/null 2>&1 || fail "no $CXX on PATH (MSYSTEM=${MSYSTEM:-unset}); run this from the MSYS2 UCRT64 shell"

asan_opts="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"

# --- memo (bead oo-n712) ------------------------------------------------------------------------
# input_hash: one sha256 over the content of everything this check and the objc floor compile,
# include or run, plus the toolchain's identity. Any change to any of it forces a real run.
input_hash() {
	local bindir dlldir b
	bindir="$(dirname "$(command -v "$CXX")")"
	dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir 2>/dev/null || true)"
	{
		echo "check-oofnd memo v1"
		echo "CXX=$CXX ($(command -v "$CXX"))"
		echo "ASAN_OPTIONS=$asan_opts"
		"$CXX" --version 2>&1 || true
		"$CXX" -print-resource-dir 2>&1 || true
		objdump --version 2>&1 | head -n 1 || true
		find "$src_dir" "$test_dir" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
		for b in check-oofnd.sh check-oofnd-objc.sh asan-resource-dir.sh; do
			echo "tools/$b $(sha256sum < "$script_dir/$b")"
		done
		for b in "$bindir"/libobjc*.dll "$bindir"/../lib/libobjc*.a \
			"$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$dlldir/libc++.dll"; do
			if [ -f "$b" ]; then echo "$(basename "$b") $(sha256sum < "$b")"; fi
		done
		# Every installed MSYS2 package as name-version: system headers, libobjc2, compiler-rt.
		ls /var/lib/pacman/local 2>/dev/null || true
	} | sha256sum | cut -c1-64
}
memo_dir="${XDG_CACHE_HOME:-$HOME/.cache}/oolite/check-oofnd"
memo_key="$(input_hash)" || memo_key=""
if [ "${OO_CHECK_OOFND_NO_MEMO:-0}" != 1 ]; then
	if [ -n "$memo_key" ] && [ -s "$memo_dir/$memo_key" ]; then
		echo "PASS (memoised: $memo_key, green at $(sed -n 1p "$memo_dir/$memo_key")): $(sed -n 2p "$memo_dir/$memo_key")"
		exit 0
	fi
fi

objc_pid=""
cleanup() {
	# A failure can exit while background jobs still run: stop them before removing their files.
	local p
	for p in $objc_pid $(jobs -p); do kill "$p" 2>/dev/null || true; done
	wait 2>/dev/null || true
	rm -rf "$work"
}
rm -rf "$work"; mkdir -p "$work"
trap cleanup EXIT

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

jobs="${OO_OOFND_JOBS:-$(nproc 2>/dev/null || echo 4)}"
# throttle: block until fewer than $jobs background jobs run. bg_rc <rcfile> <cmd...>: run cmd in
# the background and record its exit status in rcfile (read back with rc_of, so a status reaped
# early by `wait -n` is never lost).
throttle() { while [ "$(jobs -rp | wc -l)" -ge "$jobs" ]; do wait -n || true; done; }
bg_rc() { local rcf="$1"; shift; ( rc=0; "$@" || rc=$?; echo "$rc" > "$rcf" ) & }
rc_of() { cat "$1" 2>/dev/null || echo 1; }
wait_pids() { local p; for p in "$@"; do wait "$p" 2>/dev/null || true; done; }

# The Objective-C floor (bead oo-3rb.1) is independent of everything below: start it now, keep its
# output, and print it where a serial run did (after the ASan stage).
bash "$script_dir/check-oofnd-objc.sh" > "$work/objc.out" 2> "$work/objc.err" &
objc_pid=$!

# --- 2. canary TUs ------------------------------------------------------------------------------
step "2/4 canary: every oofnd header compiles alone and together at -std=c++20 -Wall -Wextra -Werror"
all="$work/canary_all.cpp"
: > "$all"
pids=()
for h in "${headers[@]}"; do
	hn="$(basename "$h")"
	one="$work/canary_${hn%.hpp}.cpp"
	printf '#include "oofnd/%s"\n#include "oofnd/%s"\nint main() { return 0; }\n' "$hn" "$hn" > "$one"
	throttle
	bg_rc "$one.rc" "$CXX" "${flags[@]}" -I"$oo/src" -fsyntax-only "$one" 2> "$one.log"; pids+=("$!")
	printf '#include "oofnd/%s"\n' "$hn" >> "$all"
done
printf 'int main() { return 0; }\n' >> "$all"
throttle
bg_rc "$all.rc" "$CXX" "${flags[@]}" -I"$oo/src" -fsyntax-only "$all" 2> "$all.log"; pids+=("$!")
throttle
bg_rc "$all.noexc.rc" "$CXX" "${flags[@]}" -fno-exceptions -I"$oo/src" -fsyntax-only "$all" 2> "$all.noexc.log"; pids+=("$!")
wait_pids "${pids[@]}"
for h in "${headers[@]}"; do
	hn="$(basename "$h")"
	one="$work/canary_${hn%.hpp}.cpp"
	[ "$(rc_of "$one.rc")" -eq 0 ] || { cat "$one.log" >&2; fail "oofnd/$hn does not compile on its own (or is not include-guarded)"; }
done
[ "$(rc_of "$all.rc")" -eq 0 ] || { cat "$all.log" >&2; fail "the all-headers canary TU does not compile"; }
[ "$(rc_of "$all.noexc.rc")" -eq 0 ] || { cat "$all.noexc.log" >&2; fail "the all-headers canary TU does not compile with -fno-exceptions"; }

# report_test <exe> <log>: reports one finished test run (its exit status is in <log>.rc); echoes
# its output; fails on nonzero exit or no summary.
total_tests=0
total_checks=0
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

# --- build every test binary (plain and ASan) in parallel, through ccache when it is installed --
#
# Bead oo-3rb.56: this script sits in every oofnd bead's acceptance block (300 s budget, ADR-0021),
# and compiling each test twice, serially and uncached, grew past the budget as components landed.
# Same TUs, same flags, same runs: each TU is compiled with -c (the only form ccache can cache;
# relative paths plus CCACHE_BASEDIR make clean clones hit), then linked, all jobs concurrently.
rd="$(bash "$script_dir/asan-resource-dir.sh" --print)" || fail "could not build the spliced ASan resource directory"
dlldir="$(bash "$script_dir/asan-resource-dir.sh" --dll-dir)" || fail "could not locate the ASan runtime DLL directory"
asan_flags=("${flags[@]}" -fsanitize=address -fno-omit-frame-pointer -g -O1 -resource-dir "$rd")
cc=("$CXX")
if command -v ccache >/dev/null 2>&1; then
	cc=(ccache "$CXX")
	export CCACHE_BASEDIR="${CCACHE_BASEDIR:-$(cygpath -m "$PWD" 2>/dev/null || pwd)}"
fi

# build_one <test.cpp> <plain|asan>: compile then link one binary; its log is kept for the report.
build_one() {
	local t="$1" kind="$2" name out
	name="$(basename "$t" .cpp)"
	if [ "$kind" = plain ]; then
		out="$work/$name"
		"${cc[@]}" "${flags[@]}" "${incs[@]}" -c "$t" -o "$out.o" > "$out.build.log" 2>&1 			&& "$CXX" "${flags[@]}" "$out.o" -o "$out.exe" >> "$out.build.log" 2>&1
	else
		out="$work/${name}_asan"
		"${cc[@]}" "${asan_flags[@]}" "${incs[@]}" -c "$t" -o "$out.o" > "$out.build.log" 2>&1 			&& "$CXX" "${asan_flags[@]}" -fuse-ld=lld "$out.o" -o "$out.exe" >> "$out.build.log" 2>&1
	fi
}

step "3/4 build: ${#tests[@]} test file(s) x {plain, -fsanitize=address}, $jobs job(s)"
pids=(); what=()
for t in "${tests[@]}"; do
	for kind in plain asan; do
		throttle
		name="$(basename "$t" .cpp)"
		[ "$kind" = plain ] && rcf="$work/$name.build.rc" || rcf="$work/${name}_asan.build.rc"
		bg_rc "$rcf" build_one "$t" "$kind"; pids+=("$!"); what+=("$t:$kind")
	done
done
wait_pids "${pids[@]}"
build_failed=0
for i in "${!what[@]}"; do
	t="${what[$i]%:*}"; kind="${what[$i]##*:}"; name="$(basename "$t" .cpp)"
	[ "$kind" = plain ] && out="$work/$name" || out="$work/${name}_asan"
	if [ "$(rc_of "$out.build.rc")" -ne 0 ]; then
		cat "$out.build.log" >&2
		echo "FAIL: $t does not compile ($kind)" >&2
		build_failed=1
	fi
done
[ "$build_failed" -eq 0 ] || fail "one or more oofnd tests do not compile"

# --- run every test binary (plain and ASan) concurrently, each in its own temp sandbox ----------
cp "$dlldir/libclang_rt.asan_dynamic-x86_64.dll" "$work/" 2>/dev/null || true
cp "$dlldir/libc++.dll" "$work/" 2>/dev/null || true
native() { cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
# run_one <exe> <log>: run one binary with TMP/TEMP/TMPDIR pointing at a private, empty directory.
run_one() {
	local exe="$1" log="$2" sbx
	sbx="$PWD/$work/sandbox/$(basename "$exe" .exe)"
	mkdir -p "$sbx"
	sbx="$(native "$sbx")"
	TMP="$sbx" TEMP="$sbx" TMPDIR="$sbx" "$exe" > "$log" 2>&1
}
pids=()
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	throttle
	bg_rc "$work/$name.log.rc" run_one "$work/$name.exe" "$work/$name.log"; pids+=("$!")
	throttle
	ASAN_OPTIONS="$asan_opts" PATH="$work:$dlldir:$PATH" \
		bg_rc "$work/${name}_asan.log.rc" run_one "$work/${name}_asan.exe" "$work/${name}_asan.log"; pids+=("$!")
done
wait_pids "${pids[@]}"

step "3/4 unit tests: -std=c++20 -Wall -Wextra -Werror"
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	report_test "$work/$name.exe" "$work/$name.log"
	total_tests=$((total_tests + LAST_TESTS))
	total_checks=$((total_checks + LAST_CHECKS))
done

step "4/4 unit tests under -fsanitize=address"
for t in "${tests[@]}"; do
	name="$(basename "$t" .cpp)"
	report_test "$work/${name}_asan.exe" "$work/${name}_asan.log"
	! grep -qi 'AddressSanitizer' "$work/${name}_asan.log" || fail "${name} printed an AddressSanitizer report"
done

# --- the Objective-C floor (bead oo-3rb.1): Objective-C++ tests on libobjc2 alone -----------------
objc_rc=0; wait "$objc_pid" || objc_rc=$?; objc_pid=""
cat "$work/objc.out"
cat "$work/objc.err" >&2
[ "$objc_rc" -eq 0 ] || fail "the oofnd Objective-C floor check (tools/check-oofnd-objc.sh) failed"

pass_line="oofnd — ${#headers[@]} header(s) canary-clean; ${#tests[@]} test file(s), $total_tests tests, $total_checks checks, green plain and under ASan"
echo "PASS: $pass_line ($(( $(date +%s) - t0 ))s)"

# Fully green: remember it. Written atomically; a failure to write the memo never fails the check.
if [ -n "$memo_key" ] && mkdir -p "$memo_dir" 2>/dev/null; then
	if ! { { date -u +%Y-%m-%dT%H:%M:%SZ; echo "$pass_line"; } > "$memo_dir/$memo_key.$$" \
		&& mv -f "$memo_dir/$memo_key.$$" "$memo_dir/$memo_key"; } 2>/dev/null; then
		rm -f "$memo_dir/$memo_key.$$" 2>/dev/null || true
	fi
fi
