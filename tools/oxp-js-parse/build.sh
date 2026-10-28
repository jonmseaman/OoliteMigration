#!/usr/bin/env bash
#
# tools/oxp-js-parse/build.sh -- build the compile-only host against the game's pinned QuickJS-ng.
#
#     bash tools/oxp-js-parse/build.sh [--quickjs-src DIR] [--out FILE]
#
# The QuickJS-ng source is the one oolite-dev's meson build unpacks from
# oolite-dev/subprojects/quickjs-ng.wrap. In a worktree whose oolite-dev submodule is not
# initialised, pass --quickjs-src (or OO_QUICKJS_SRC) pointing at the main checkout's copy. The
# build refuses a source whose version differs from the wrap's, so the parser is always the one the
# game ships. The binary goes under .agent-tmp/ and is never committed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

die() { printf 'oxp-js-parse build: %s\n' "$*" >&2; exit 2; }

SRC="${OO_QUICKJS_SRC:-}"
OUT="$REPO_ROOT/.agent-tmp/oxp-js-parse/oxp-js-parse.exe"
while [ $# -gt 0 ]; do
  case "$1" in
    --quickjs-src) SRC="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

wrap_of() { sed -n 's/^directory *= *//p' "$1/subprojects/quickjs-ng.wrap"; }

WRAP_ROOT=""
for cand in "$REPO_ROOT/oolite-dev" "$REPO_ROOT/../../oolite-dev"; do
  if [ -f "$cand/subprojects/quickjs-ng.wrap" ]; then WRAP_ROOT="$cand"; break; fi
done
[ -n "$WRAP_ROOT" ] || die "cannot find oolite-dev/subprojects/quickjs-ng.wrap"
WANT_DIR="$(wrap_of "$WRAP_ROOT")"
[ -n "$WANT_DIR" ] || die "quickjs-ng.wrap names no directory"
[ -n "$SRC" ] || SRC="$WRAP_ROOT/subprojects/$WANT_DIR"
[ -f "$SRC/quickjs.c" ] || die "no QuickJS-ng source at $SRC (run oolite-dev's meson setup once, or pass --quickjs-src)"
[ "$(basename "$(cd "$SRC" && pwd)")" = "$WANT_DIR" ] || die "source $SRC is not the pinned $WANT_DIR"

CC="${CC:-clang}"
mkdir -p "$(dirname "$OUT")"
build() {   # build <main.c> <output>
  "$CC" -std=gnu11 -O2 -ffp-contract=off \
    -D_GNU_SOURCE -DQUICKJS_NG_BUILD -DWIN32_LEAN_AND_MEAN -D_WIN32_WINNT=0x0601 \
    -I"$SRC" \
    "$1" "$SRC/quickjs.c" "$SRC/libregexp.c" "$SRC/libunicode.c" "$SRC/dtoa.c" \
    -lm -o "$2"
}
build "$HERE/parse.c" "$OUT"
build "$HERE/engine-probe.c" "$(dirname "$OUT")/engine-probe.exe"
printf '%s\n' "$WANT_DIR" > "$OUT.version"
printf '%s\n' "$OUT"
