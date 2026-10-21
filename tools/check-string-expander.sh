#!/usr/bin/env bash
#
# The differential regression test of OOStringExpander's engine (bead oo-3rb.61, proposed
# ADR-0034 decision 4): compile the tree's upstream/oolite/src/Core/OOStringExpander.cpp against
# the stubs in upstream/oolite/tests/unit/expander (Universe, PlayerEntity, ResourceManager, the
# JavaScript engine, the credit formatter, the collection extractors) and the real
# legacy_random.c, run it over the shipped descriptions.plist and a generated corpus, and
# compare FNV-1a digests captured from the original NSString engine.
#
#     bash tools/check-string-expander.sh             # the tree's OOStringExpander.cpp
#     bash tools/check-string-expander.sh FILE.cpp    # another copy
#     OO_EXPANDER_PRINT=1 bash tools/check-string-expander.sh   # print every recorded line
#
# The .cpp (.mm until bead oo-dbz.5) is copied next to the stubs so that its quote-includes find them before the real
# headers. Since bead oo-6e1.2 the harness is C++ and links no gnustep-base (CLAUDE.md rule 8): it
# drives cxx_OOExpandDescriptionString with the same inputs and records the same lines, so the
# digests (taken through the Foundation surface the bead deleted) are unchanged.
# About 30 s from a clean checkout (four translation units, then ~2 s to run).

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
EXPANDER="${1:-$SRC/Core/OOStringExpander.cpp}"

die() { printf 'check-string-expander: %s\n' "$*" >&2; exit 1; }

command -v clang++ >/dev/null 2>&1 || die "clang++ is not on PATH; run tools/setup-windows.sh"
[ -f "$EXPANDER" ] || die "missing $EXPANDER"
[ -f "$TEST_DIR/test_string_expander.cpp" ] || die "missing $TEST_DIR/test_string_expander.cpp"

# Native paths for every argument clang sees (docs/fleet/LEARNINGS.md), and a temp directory
# clang can see.
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
if command -v cygpath >/dev/null 2>&1 && [ -n "${LOCALAPPDATA:-}" ]; then
  TMPDIR="$(cygpath -m "$LOCALAPPDATA/Temp")"
  export TMPDIR TMP="$TMPDIR" TEMP="$TMPDIR"
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TEST_DIR"/*.h "$TEST_DIR/test_string_expander.cpp" "$WORK/"
cp "$EXPANDER" "$WORK/OOStringExpander.cpp"
# The expander calls the Universe, PlayerEntity and ResourceManager stubs' C++ members directly
# since bead oo-9ht.159 deleted its bridge (the stubs stand in for the C++ classes).

inc=()
for d in "$SRC" "$SRC/Core" "$SRC/Core/Debug" "$SRC/Core/Entities" "$SRC/Core/Materials" "$SRC/Core/MiniZip" "$SRC/Core/OXPVerifier" "$SRC/Core/Scripting" "$SRC/Core/Tables" "$SRC/SDL"; do
  inc+=("-I$(native "$d")")
done
# The game's C++ flags (src/meson.build), with the debug warnings compiled in. (Objective-C++ on the
# gnustep-2.2 runtime until bead oo-dbz.5: -fobjc-exceptions -DGNUSTEP_RUNTIME=1 -D_NONFRAGILE_ABI=1
# -fobjc-runtime=gnustep-2.2 -fblocks went with it.)
flags=(-x c++ -std=gnu++20 -O2 -Wall -DOOLITE_DEBUG=1 -D_FILE_OFFSET_BITS=64 -DWIN32 -DXP_WIN
       -DWINVER=0x0A00 -DGNUSTEP_BASE_LIBRARY=1 -fexceptions -ffp-contract=off -pthread)

w="$(native "$WORK")"
# Since bead oo-6e1.2 the harness has no Foundation surface and no Foundation prefix: every unit
# gets the game's own Foundation-free headers.
clang++ "${flags[@]}" "${inc[@]}" -c "$w/OOStringExpander.cpp" -o "$w/expander.o" || die "OOStringExpander.cpp does not compile against the stubs"
clang++ "${flags[@]}" "${inc[@]}" -c "$w/test_string_expander.cpp" -o "$w/test.o" || die "the test does not compile"
# The expander raises oo::Exception and describes values with oo::DescriptionOf (the PList's, a
# header), so the oofnd runtime it stands on is compiled in, with ICU, as oofnd's meson dependency,
# for oo::str's normalisation (build plumbing, bead oo-qqz6; OODescription.mm, which described an
# Objective-C object, went with libobjc2, bead oo-dbz.2). The harness's player answers the by-name
# calls itself since bead oo-6e1.2 (OOCallByName.mm, the call on an Objective-C object, is deleted).
support=()
for f in "$SRC"/oofnd/objc/*.cpp "$SRC"/oofnd/Exception.cpp; do	# Exception.cpp: OORaiseException, from objc/OOException.mm (bead oo-4aq6a.1)
  o="$w/oofnd-$(basename "$f" .cpp).o"
  clang++ "${flags[@]}" "${inc[@]}" -c "$(native "$f")" -o "$o" || die "$f does not compile"
  support+=("$o")
done
clang -O2 "-I$(native "$SRC/Core")" -c "$(native "$SRC/Core/legacy_random.c")" -o "$w/legacy_random.o"
# Neither libobjc2 (linked alone, the game's runtime, until bead oo-dbz.5) nor gnustep-base (rule 8).
read -r -a libs <<< "$(pkg-config --libs icu-i18n)"
clang++ -fuse-ld=lld -o "$w/test_string_expander.exe" "$w/expander.o" "${support[@]}" "$w/test.o" "$w/legacy_random.o" "${libs[@]}" \
  || die "link failed"

config="$(native "$OOLITE/Resources/Config")"
if [ -n "${OO_EXPANDER_PRINT:-}" ]; then
  "$w/test_string_expander.exe" "$config/descriptions.plist" "$config/whitelist.plist" --print
else
  "$w/test_string_expander.exe" "$config/descriptions.plist" "$config/whitelist.plist"
fi
