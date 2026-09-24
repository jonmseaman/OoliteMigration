#!/usr/bin/env bash
#
# The differential regression test of OOStringExpander's engine (bead oo-3rb.61, proposed
# ADR-0034 decision 4): compile the tree's upstream/oolite/src/Core/OOStringExpander.mm against
# the stubs in upstream/oolite/tests/unit/expander (Universe, PlayerEntity, ResourceManager, the
# JavaScript engine, the credit formatter, the collection extractors) and the real
# legacy_random.c, run it over the shipped descriptions.plist and a generated corpus, and
# compare FNV-1a digests captured from the original NSString engine.
#
#     bash tools/check-string-expander.sh             # the tree's OOStringExpander.mm
#     bash tools/check-string-expander.sh FILE.mm     # another copy (how the digests were taken)
#     OO_EXPANDER_PRINT=1 bash tools/check-string-expander.sh   # print every recorded line
#
# The .mm is copied next to the stubs so that its quote-includes find them before the real
# headers. Like the expander itself, the test still links gnustep-base (NSString at the lookup
# boundary): it moves with the expander's lookups when they leave Foundation (oo-qps).
# About 30 s from a clean checkout (three Objective-C++ translation units, then ~2 s to run).

set -euo pipefail

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_EXPANDER_CHECK_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_EXPANDER_CHECK_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
SRC="$OOLITE/src"
TEST_DIR="$OOLITE/tests/unit/expander"
EXPANDER="${1:-$SRC/Core/OOStringExpander.mm}"

die() { printf 'check-string-expander: %s\n' "$*" >&2; exit 1; }

command -v clang++ >/dev/null 2>&1 || die "clang++ is not on PATH; run tools/setup-windows.sh"
command -v gnustep-config >/dev/null 2>&1 || die "gnustep-config is not on PATH; run tools/setup-windows.sh"
[ -f "$EXPANDER" ] || die "missing $EXPANDER"
[ -f "$TEST_DIR/test_string_expander.mm" ] || die "missing $TEST_DIR/test_string_expander.mm"

# Native paths for every argument clang sees (docs/fleet/LEARNINGS.md), and a temp directory
# clang can see.
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
if command -v cygpath >/dev/null 2>&1 && [ -n "${LOCALAPPDATA:-}" ]; then
  TMPDIR="$(cygpath -m "$LOCALAPPDATA/Temp")"
  export TMPDIR TMP="$TMPDIR" TEMP="$TMPDIR"
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TEST_DIR"/*.h "$TEST_DIR/test_string_expander.mm" "$WORK/"
cp "$EXPANDER" "$WORK/OOStringExpander.mm"

inc=()
for d in "$SRC" "$SRC/Core" "$SRC/Core/Debug" "$SRC/Core/Entities" "$SRC/Core/Materials" "$SRC/Core/MiniZip" "$SRC/Core/OXPVerifier" "$SRC/Core/Scripting" "$SRC/Core/Tables" "$SRC/SDL"; do
  inc+=("-I$(native "$d")")
done
# The game's Objective-C++ flags (src/meson.build), with the debug warnings compiled in.
flags=(-x objective-c++ -std=gnu++20 -O2 -Wall -DOOLITE_DEBUG=1 -D_FILE_OFFSET_BITS=64 -DWIN32 -DXP_WIN
       -DWINVER=0x0A00 -DGNUSTEP_BASE_LIBRARY=1 -fexceptions -fobjc-exceptions -DGNUSTEP_RUNTIME=1
       -D_NONFRAGILE_ABI=1 -fobjc-runtime=gnustep-2.2 -fblocks -ffp-contract=off -pthread)

w="$(native "$WORK")"
clang++ "${flags[@]}" "${inc[@]}" -c "$w/OOStringExpander.mm" -o "$w/expander.o" || die "OOStringExpander.mm does not compile against the stubs"
clang++ "${flags[@]}" "${inc[@]}" -c "$w/test_string_expander.mm" -o "$w/test.o" || die "the test does not compile"
clang -O2 "-I$(native "$SRC/Core")" -c "$(native "$SRC/Core/legacy_random.c")" -o "$w/legacy_random.o"
read -r -a libs <<< "$(gnustep-config --base-libs)"
clang++ -fuse-ld=lld -o "$w/test_string_expander.exe" "$w/expander.o" "$w/test.o" "$w/legacy_random.o" "${libs[@]}" \
  || die "link failed"

config="$(native "$OOLITE/Resources/Config")"
if [ -n "${OO_EXPANDER_PRINT:-}" ]; then
  "$w/test_string_expander.exe" "$config/descriptions.plist" "$config/whitelist.plist" --print
else
  "$w/test_string_expander.exe" "$config/descriptions.plist" "$config/whitelist.plist"
fi
