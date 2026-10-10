#!/usr/bin/env bash
#
# Silent C++ <-> Objective-C pointer casts (bead oo-tzd3n).
#
#     tools/objc-cast-scan.sh <file>...    # scan these translation units
#     tools/objc-cast-scan.sh --all        # every .m/.mm under src/ and tests/ in the build (nightly)
#
# A C-style (or static_/reinterpret_) cast between a C++ record pointer and an Objective-C
# object pointer compiles WITHOUT a diagnostic and reinterprets the pointer: casting a
# cxx::Entity * to the Objective-C Entity * hands out a facade that does not exist. Batch O
# (oo-9ht.144) found three wormhole bugs of this shape already on main. -Wall -Wextra say
# nothing, so this asks clang itself: tools/objc-cast-scan.query is a clang-query AST matcher
# run with each TU's own compile command (the build's compile_commands.json), and every match
# in the TU or in a project header (src/, tests/) is a finding. There is no baseline and no
# suppression comment: the tree has zero hits, so any hit is new. A cast that really is meant
# to cross must say so by going through void * (`(Foo *)(void *)p`), which the matcher leaves
# alone, as it leaves alone Core Foundation bridging and the runtime's objc_object.
#
# Wired into tools/tier-a.sh as step 4 (per file, ~3 s even on ShipEntity.mm); the whole-tree
# --all line runs nightly (tests/nightly/checks.txt [oo-tzd3n]); tools/objc-cast-scan-selftest
# proves it fails on planted casts and passes on the legitimate look-alikes.
#
# Exit: 0 no finding; 1 findings (printed as `upstream/oolite/<path>:<line>:<col>: ...`);
# 2 the scan could not be run (no build directory, file not in the build, clang-query failed).
# The build directory is upstream/oolite/build/meson_${OOLITE_TIER_A_FLAVOUR:-test}, as tier-a's.
#
# OOLITE_CASTSCAN_SOURCE_ONLY=1 . tools/objc-cast-scan.sh   defines castscan_tu and returns.

CASTSCAN_QUERY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/objc-cast-scan.query"

# castscan_tu <cwd> <source> <clang-arg>...
#   Runs the matcher over one TU (cwd = the directory its compile arguments are relative to).
#   Prints one line per finding and returns 0 (none), 1 (findings) or 2 (clang-query failed,
#   or the TU did not parse).
castscan_tu() {
  local cwd="$1" src="$2"; shift 2
  local out rc=0
  out="$(cd "$cwd" && clang-query -f "$(cygpath -m "$CASTSCAN_QUERY" 2>/dev/null || printf '%s' "$CASTSCAN_QUERY")" \
           "$src" -- clang "$@" 2>&1)" || rc=$?
  # A TU that does not parse still ends "0 matches." with rc 0, so an error diagnostic is a
  # failed scan too: tier-a has compiled the TU first, and a scan of half a TU is not a pass.
  if [ "$rc" -ne 0 ] || ! printf '%s\n' "$out" | grep -qE '^[0-9]+ match(es)?\.$' \
     || printf '%s\n' "$out" | grep -qE '(^|: )(fatal )?error: '; then
    printf '%s\n' "$out" | grep -E 'error' | head -20 >&2
    printf 'objc-cast-scan: clang-query did not complete on %s (exit %s)\n' "$src" "$rc" >&2
    return 2
  fi
  local hits
  hits="$(printf '%s\n' "$out" | sed -n 's/^\(.*\):\([0-9][0-9]*\):\([0-9][0-9]*\): note: "root" binds here$/\1:\2:\3/p' \
          | sed -e 's#\\#/#g' -e 's#^.*/upstream/oolite/##' -e 's#^\(\.\./\)*##' \
          | sed 's#^#upstream/oolite/#' | sort -u)"
  [ -n "$hits" ] || return 0
  printf '%s: explicit cast between a C++ pointer and an Objective-C pointer (silently reinterprets; convert through oo::ToCxx/oo::ToObjC or the C++ type)\n' $hits
  return 1
}

if [ "${OOLITE_CASTSCAN_SOURCE_ONLY:-0}" = 1 ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
  return 0
fi

set -uo pipefail
die() { printf 'objc-cast-scan: %s\n' "$*" >&2; exit 2; }

# Same re-exec as tools/tier-a.sh: the native clang-query and the compile database need UCRT64.
if [ "${MSYSTEM:-}" != UCRT64 ] && [ -z "${OOLITE_CASTSCAN_REEXEC:-}" ]; then
  for root in "${MSYS2_ROOT:-}" /c/msys64 /c/tools/msys64 "${HOME:-/nonexistent}/scoop/apps/msys2/current"; do
    [ -n "$root" ] && [ -x "$root/usr/bin/bash.exe" ] && [ -d "$root/ucrt64/bin" ] || continue
    export OOLITE_CASTSCAN_REEXEC=1
    exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$root/usr/bin/bash.exe" -lc \
      "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
  done
  die "not in MSYS2 UCRT64 and no MSYS2 installation found"
fi
export PATH="/ucrt64/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/upstream/oolite/build/meson_${OOLITE_TIER_A_FLAVOUR:-test}"
COMPDB_READER="$REPO_ROOT/tools/tier-a-compdb.py"
command -v clang-query >/dev/null 2>&1 || die "no clang-query on PATH (mingw-w64-ucrt-x86_64-clang-tools-extra)"
[ -f "$BUILD_DIR/compile_commands.json" ] || die "no compile database at ${BUILD_DIR#"$REPO_ROOT"/}; build first (tools/build-windows.sh test)"

# scan_one <source> : one TU through its compile-database entry.
scan_one() {
  local src_native fields
  src_native="$(cygpath -m "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")")"
  fields="$(mktemp)"
  ( cd "$BUILD_DIR" && python "$(cygpath -m "$COMPDB_READER")" compile_commands.json "$src_native" ) >"$fields" \
    || { rm -f "$fields"; printf 'objc-cast-scan: %s is not in the build\n' "$1" >&2; return 2; }
  local -a f
  mapfile -d '' -t f <"$fields"; rm -f "$fields"
  castscan_tu "$BUILD_DIR" "$src_native" "${f[@]:1}"
}

case "${1:-}" in
  ""|-h|--help) sed -n '2,28p' "${BASH_SOURCE[0]}"; [ -n "${1:-}" ]; exit $? ;;
  --one) scan_one "$2"; exit $? ;;
  --all)
    LIST="$(mktemp)"; OUT="$(mktemp)"; trap 'rm -f "$LIST" "$OUT"' EXIT
    ( cd "$BUILD_DIR" && python -c '
import json, os, sys
seen = set()
for e in json.load(open("compile_commands.json")):
    p = os.path.normpath(os.path.join(e["directory"], e["file"])).replace("\\", "/")
    rel = p.split("/upstream/oolite/", 1)[-1]
    if rel.startswith(("src/", "tests/")) and rel.endswith((".m", ".mm")) and p not in seen:
        seen.add(p); print(p)
' ) >"$LIST" || die "cannot read the compile database"
    n=$(wc -l <"$LIST")
    [ "$n" -gt 0 ] || die "the compile database lists no .m/.mm under src/ or tests/"
    # Two at a time: the fleet machine is shared (CPU rule); ~600 TUs at ~3 s is ~15 min.
    rc=0
    tr '\n' '\0' <"$LIST" | xargs -0 -n 1 -P "${OOLITE_CASTSCAN_JOBS:-2}" bash "${BASH_SOURCE[0]}" --one >"$OUT" || rc=$?
    sort -u "$OUT"
    hits=$(sort -u "$OUT" | grep -c . || true)
    echo "objc-cast-scan: $n translation units, $hits finding(s)"
    # xargs exits 123 when any invocation exits 1-125: a finding (1) or a failed scan (2).
    [ "$hits" -eq 0 ] || exit 1
    [ "$rc" -eq 0 ] || die "a scan failed (see above)"
    exit 0 ;;
esac

rc=0
for src in "$@"; do
  [ -f "$src" ] || die "no such file: $src"
  scan_one "$src"; r=$?
  [ "$r" -gt "$rc" ] && rc=$r
done
exit "$rc"
