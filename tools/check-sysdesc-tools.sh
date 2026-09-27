#!/usr/bin/env bash
#
# The regression test of the localisation tools --export-sysdesc / --compile-sysdesc (bead
# oo-vjwp): compile the tree's upstream/oolite/src/Core/OOConvertSystemDescriptions.mm against the
# stubs in upstream/oolite/tests/unit/sysdesc (ResourceManager, Universe), run it over the shipped
# descriptions.plist, and compare FNV-1a digests captured from the ported tool (oo-xh1g). See the
# banner of tests/unit/sysdesc/test_sysdesc_tools.mm for what is pinned and why.
#
#     bash tools/check-sysdesc-tools.sh               # the tree's OOConvertSystemDescriptions.mm
#     OO_SYSDESC_PRINT=1 bash tools/check-sysdesc-tools.sh   # print every recorded line
#
# The .mm is copied next to the stubs so that its quote-includes find them before the real
# headers. It still links gnustep-base (the Foundation boundary the tools keep: the log calls and
# the descriptions dictionary); it moves when those leave Foundation (oo-qps).

set -euo pipefail

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_SYSDESC_CHECK_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_SYSDESC_CHECK_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
SRC="$OOLITE/src"
TEST_DIR="$OOLITE/tests/unit/sysdesc"
TOOLS="${1:-$SRC/Core/OOConvertSystemDescriptions.mm}"

die() { printf 'check-sysdesc-tools: %s\n' "$*" >&2; exit 1; }

command -v clang++ >/dev/null 2>&1 || die "clang++ is not on PATH; run tools/setup-windows.sh"
command -v gnustep-config >/dev/null 2>&1 || die "gnustep-config is not on PATH; run tools/setup-windows.sh"
[ -f "$TOOLS" ] || die "missing $TOOLS"
[ -f "$TEST_DIR/test_sysdesc_tools.mm" ] || die "missing $TEST_DIR/test_sysdesc_tools.mm"

# Native paths for every argument clang sees (docs/fleet/LEARNINGS.md), and a temp directory
# clang can see.
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
if command -v cygpath >/dev/null 2>&1 && [ -n "${LOCALAPPDATA:-}" ]; then
  TMPDIR="$(cygpath -m "$LOCALAPPDATA/Temp")"
  export TMPDIR TMP="$TMPDIR" TEMP="$TMPDIR"
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TEST_DIR"/*.h "$TEST_DIR/test_sysdesc_tools.mm" "$WORK/"
cp "$TOOLS" "$WORK/OOConvertSystemDescriptions.mm"

inc=()
for d in "$SRC" "$SRC/Core" "$SRC/Core/Debug" "$SRC/Core/Entities" "$SRC/Core/Materials" "$SRC/Core/MiniZip" "$SRC/Core/OXPVerifier" "$SRC/Core/Scripting" "$SRC/Core/Tables" "$SRC/SDL"; do
  inc+=("-I$(native "$d")")
done
# The game's Objective-C++ flags (src/meson.build), with the debug warnings compiled in.
flags=(-x objective-c++ -std=gnu++20 -O2 -Wall -DOOLITE_DEBUG=1 -D_FILE_OFFSET_BITS=64 -DWIN32 -DXP_WIN
       -DWINVER=0x0A00 -DGNUSTEP_BASE_LIBRARY=1 -fexceptions -fobjc-exceptions -DGNUSTEP_RUNTIME=1
       -D_NONFRAGILE_ABI=1 -fobjc-runtime=gnustep-2.2 -fblocks -ffp-contract=off -pthread)

w="$(native "$WORK")"
clang++ "${flags[@]}" "${inc[@]}" -c "$w/OOConvertSystemDescriptions.mm" -o "$w/tools.o" || die "OOConvertSystemDescriptions.mm does not compile against the stubs"
clang++ "${flags[@]}" "${inc[@]}" -c "$w/test_sysdesc_tools.mm" -o "$w/test.o" || die "the test does not compile"
read -r -a libs <<< "$(gnustep-config --base-libs)"
clang++ -fuse-ld=lld -o "$w/test_sysdesc_tools.exe" "$w/tools.o" "$w/test.o" "${libs[@]}"   || die "link failed"

config="$(native "$OOLITE/Resources/Config")"
if [ -n "${OO_SYSDESC_PRINT:-}" ]; then
  "$w/test_sysdesc_tools.exe" "$config/descriptions.plist" --print
else
  "$w/test_sysdesc_tools.exe" "$config/descriptions.plist"
fi
