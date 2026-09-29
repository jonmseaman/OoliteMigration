#!/usr/bin/env bash
#
# The unit tests of converted game classes (Phase 3; proposed ADR-0056, exemplar bead oo-11m):
# upstream/oolite/tests/unit/core/test_<Class>.mm, one executable each, linked from the game's own
# objects by tests/unit/core/meson.build and run as `meson test --suite core`.
#
#     tools/build-windows.sh test && bash tools/check-core-tests.sh           # every class
#     bash tools/check-core-tests.sh test_OOColor                              # one class
#
# Needs the 'test' build directory (tools/build-windows.sh test makes it); meson rebuilds what
# changed before it runs. Fails when a test_*.mm is not registered in the meson file (it would
# never run), when no test ran, or when any test fails.

set -euo pipefail

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_CORE_TESTS_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_CORE_TESTS_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
TEST_DIR="$OOLITE/tests/unit/core"
BUILD_DIR="$OOLITE/build/meson_test"

die() { printf 'check-core-tests: %s\n' "$*" >&2; exit 1; }

command -v meson >/dev/null 2>&1 || die "meson is not on PATH; run this from the MSYS2 UCRT64 shell"
[ -f "$BUILD_DIR/build.ninja" ] || die "no build directory at $BUILD_DIR; run tools/build-windows.sh test first"

shopt -s nullglob
tests=("$TEST_DIR"/test_*.mm)
shopt -u nullglob
[ "${#tests[@]}" -gt 0 ] || die "found ZERO tests matching $TEST_DIR/test_*.mm; an empty suite is not a pass"
for t in "${tests[@]}"; do
  name="$(basename "$t" .mm)"
  grep -q "'$name'" "$TEST_DIR/meson.build" || die "$t is not registered in $TEST_DIR/meson.build, so it would never run"
done

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
rc=0
meson test -C "$BUILD_DIR" --suite core --print-errorlogs "$@" 2>&1 | tee "$log" || rc=$?
[ "$rc" -eq 0 ] || die "meson test --suite core failed (exit $rc)"
ok="$(sed -n 's/^Ok:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log" | tail -n 1)"
[ -n "$ok" ] && [ "$ok" -gt 0 ] || die "no core test ran"
echo "check-core-tests: $ok test(s) passed"
