#!/usr/bin/env bash
#
# Acceptance checks for the debug-only enumeration-order shuffle (bead oo-r3r, seam 0.1a).
# See upstream/oolite/src/Core/OOEnumerationShuffle.h for what the instrumentation is for.
#
#     tools/check-enumeration-shuffle.sh
#
# Four checks, all offline and all under about five seconds, because they are the checks
# that have to pass in accept.sh's clean checkout where a full game launch is not available:
#
#   1. determinism  the order logic is a pure function of (seed, count): compile and run
#                   tests/unit/test_enumeration_shuffle.c
#   2. macros       foreach/foreachkey expand to EXACTLY the upstream text when OO_DEBUG is
#                   0, and to the shuffle when it is 1. This is the "byte-identical when
#                   unset" requirement, checked by the preprocessor rather than asserted.
#   3. guarded      every shuffle definition in OOEnumerationShuffle.m sits inside an
#                   `#if OO_DEBUG` region, so a release build has no code to disable
#   4. binaries     if a built release and debug oolite are lying around, the release one
#                   must contain no shuffle symbols and the debug one must contain them.
#                   Skipped, not failed, when the binaries are absent.
#
# The full-launch evidence that a debug build with OO_SHUFFLE_ENUMERATION=1 reaches the main
# menu is produced by tests/launch_snapshot.py against build/meson_debug/oolite.app; it is
# not run here because a clean checkout has no built game.

set -euo pipefail

# --- Re-exec into the UCRT64 shell -------------------------------------------------------
#
# Same reason as tools/tier-a.sh: this is a bead's acceptance command, and accept.sh runs
# those with a plain `bash -c` in whatever shell the orchestrator started in. Without this,
# clang is not on PATH and the check fails on MSYSTEM rather than on the code.

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_SHUFFLE_CHECK_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_SHUFFLE_CHECK_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
CORE="$OOLITE/src/Core"
COCOA_H="$CORE/OOCocoa.h"
SHUFFLE_M="$CORE/OOEnumerationShuffle.mm"
UNIT_TEST="$OOLITE/tests/unit/test_enumeration_shuffle.c"

step() { printf '==> %s\n' "$*"; }
die()  { printf 'check-enumeration-shuffle: %s\n' "$*" >&2; exit 1; }

command -v clang >/dev/null 2>&1 || die "clang is not on PATH; run tools/setup-windows.sh"
for f in "$COCOA_H" "$SHUFFLE_M" "$UNIT_TEST"; do
  [ -f "$f" ] || die "missing $f"
done

# Native paths for every argument clang sees: MSYS /c/... paths reach clang as relative
# paths and it silently fails to find them (docs/fleet/LEARNINGS.md).
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

# clang needs a writable temp directory it can actually see, and an MSYS TMPDIR is not one.
if command -v cygpath >/dev/null 2>&1 && [ -n "${LOCALAPPDATA:-}" ]; then
  TMPDIR="$(cygpath -m "$LOCALAPPDATA/Temp")"
  export TMPDIR TMP="$TMPDIR" TEMP="$TMPDIR"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 1. The order logic is deterministic -------------------------------------------------
#
# A shuffled run is only useful if it can be re-run, so this is the property the whole
# instrumentation rests on. -Werror because a warning in a 150-line header-only unit is a
# defect, not noise.

step "1/4 determinism  tests/unit/test_enumeration_shuffle.c"
clang -std=c11 -Wall -Wextra -Werror \
  -I"$(native "$CORE")" \
  -o "$(native "$WORK/test_enumeration_shuffle.exe")" \
  "$(native "$UNIT_TEST")" || die "the determinism test did not compile"
"$WORK/test_enumeration_shuffle.exe" || die "the determinism test failed"

# --- 2. The macros compile out, rather than branching ------------------------------------
#
# The block between the sentinels in OOCocoa.h is extracted verbatim and preprocessed on its
# own under each setting of OO_DEBUG. Under 0 the expansion must be character-for-character
# upstream's `for(x in y)`: that is what "no behaviour change when the env var is unset"
# means for a shipping build, and it is a preprocessor fact rather than a code review.

step "2/4 macros       OOCocoa.h foreach/foreachkey"
awk '/OO_ENUMERATION_MACROS_BEGIN/{f=1; next} /OO_ENUMERATION_MACROS_END/{f=0} f' \
  "$COCOA_H" > "$WORK/macros.h"
[ -s "$WORK/macros.h" ] || die "could not find the OO_ENUMERATION_MACROS sentinels in OOCocoa.h"

cat > "$WORK/probe.c" <<'PROBE'
#include "macros.h"
PROBE
printf 'foreach(x, y)\nforeachkey(k, d)\n' >> "$WORK/probe.c"

expand() {   # expand <oo-debug-value> ; prints the two expanded lines, whitespace-squeezed
  clang -E -P -DOO_DEBUG="$1" -I"$(native "$WORK")" "$(native "$WORK/probe.c")" \
    | grep -E 'for *\(' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}

RELEASE_EXPANSION="$(expand 0)"
DEBUG_EXPANSION="$(expand 1)"

EXPECTED_RELEASE='for(x in y) for(k in d)'
[ "$RELEASE_EXPANSION" = "$EXPECTED_RELEASE" ] \
  || die "with OO_DEBUG=0 the macros expand to '$RELEASE_EXPANSION', not the upstream '$EXPECTED_RELEASE'"
printf '    OO_DEBUG=0 -> %s\n' "$RELEASE_EXPANSION"

case "$DEBUG_EXPANSION" in
  *OOShuffledObjects*OOShuffledKeys*) ;;
  *) die "with OO_DEBUG=1 the macros do not route through the shuffle: '$DEBUG_EXPANSION'" ;;
esac
printf '    OO_DEBUG=1 -> %s\n' "$DEBUG_EXPANSION"

# --- 3. Nothing in the .m escapes the OO_DEBUG guard -------------------------------------
#
# Check 2 proves the call sites vanish; this proves there is nothing left for them to have
# called. Tracks preprocessor conditional depth so a definition smuggled in after the guard
# closes is caught, which a plain grep would not do.

step "3/4 guarded      OOEnumerationShuffle.mm"
awk '
  /^[[:space:]]*#[[:space:]]*if.*OO_DEBUG/ { depth++; guard[depth] = 1; next }
  /^[[:space:]]*#[[:space:]]*if/           { depth++; guard[depth] = 0; next }
  /^[[:space:]]*#[[:space:]]*endif/        { delete guard[depth]; depth--; next }
  /^(id|BOOL|uint32_t|NSString|static)[[:space:]].*OOShuffled|^(id|BOOL|uint32_t|NSString)[[:space:]].*OOEnumerationShuffle/ {
    inside = 0
    for (d = 1; d <= depth; d++)  if (guard[d])  inside = 1
    if (!inside) { printf "unguarded definition at line %d: %s\n", NR, $0; bad++ }
  }
  END { exit (bad > 0) }
' "$SHUFFLE_M" || die "OOEnumerationShuffle.m defines shuffle code outside #if OO_DEBUG"
printf '    every shuffle definition is inside #if OO_DEBUG\n'

# --- 4. Built binaries, when there are any -----------------------------------------------
#
# The strongest evidence, and the one a clean checkout cannot produce: the release binary
# must not contain the shuffle at all. Skipped rather than failed when unbuilt, so this
# script stays runnable in accept.sh.
#
# nm's output goes to a variable rather than into `| grep -q`: under `set -o pipefail`,
# grep -q exits at the first match, nm dies of SIGPIPE, and the pipeline reports failure
# even though the match succeeded. And the path is converted: nm is a native binary, so an
# MSYS /c/... path makes it fail silently and every check here would vacuously "pass".

step "4/4 binaries     release must not contain the shuffle"

shuffle_symbols() {   # shuffle_symbols <binary> ; prints matching symbol names, if any
  local dump
  dump="$(nm -C "$(native "$1")" 2>/dev/null || true)"
  [ -n "$dump" ] || die "nm produced no symbols for $1; it cannot certify anything"
  printf '%s' "$dump" | grep -E 'OOShuffled|OOEnumerationShuffle' || true
}

checked=0
for flavour in deployment test dev; do
  BIN="$OOLITE/build/meson_$flavour/src/oolite.exe"
  [ -f "$BIN" ] || continue
  if [ -n "$(shuffle_symbols "$BIN")" ]; then
    die "the $flavour binary contains shuffle symbols; it should have compiled them out"
  fi
  printf '    %s: no shuffle symbols\n' "$flavour"
  checked=$(( checked + 1 ))
done

DEBUG_BIN="$OOLITE/build/meson_debug/src/oolite.exe"
if [ -f "$DEBUG_BIN" ]; then
  [ -n "$(shuffle_symbols "$DEBUG_BIN")" ] \
    || die "the debug binary does NOT contain the shuffle; the instrumentation is not built"
  printf '    debug: shuffle symbols present\n'
  checked=$(( checked + 1 ))
fi

[ "$checked" -gt 0 ] || printf '    skipped: no built binaries under upstream/oolite/build\n'

echo "check-enumeration-shuffle: PASS"
