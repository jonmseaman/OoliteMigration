#!/usr/bin/env bash
#
# Build Oolite natively on Windows from a clean clone.
# Phase 0 item 0.3 (docs/phases/0-safety-net.md).
#
# This is upstream's Windows CI job (.github/workflows/build-all.yaml) minus its per-run
# provisioning: no msys2/setup-msys2, no install_deps.sh. The machine is provisioned once by
# tools/setup-windows.sh (item 0.2) and every build after that is incremental behind ccache.
#
#     tools/build-windows.sh                 # the 'test' flavour, the one the goldens use
#     tools/build-windows.sh dev             # a single named flavour
#     tools/build-windows.sh --all           # deployment, test and dev, as CI builds them
#     tools/build-windows.sh --clean test    # discard the build directory first
#
# Exits nonzero if the machine is not provisioned, if a flavour fails to build, or if the
# expected binary is missing afterwards.

set -euo pipefail

# Flavours the upstream workflow builds (matrix.flavour in build-all.yaml). mk.sh also accepts
# 'debug'; it is not part of --all because CI does not ship it.
ALL_FLAVOURS=(deployment test dev)
DEFAULT_FLAVOUR=test

# --- Re-exec into the UCRT64 shell ------------------------------------------------------------
#
# Same reason as tools/setup-windows.sh: this runs as a bead's acceptance command, and accept.sh
# runs those with a plain `bash -c` in whatever shell the orchestrator was started from. Without
# this, every build-touching acceptance fails on MSYSTEM rather than on the build.

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_BUILD_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64"
  export OOLITE_BUILD_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
NATIVE_FILE="$REPO_ROOT/tools/meson/ccache-clang.ini"

say() { echo "==> $*"; }
die() { echo "build-windows: $*" >&2; exit 1; }

CLEAN=false
FLAVOURS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --all)   FLAVOURS=("${ALL_FLAVOURS[@]}") ;;
    --clean) CLEAN=true ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)      die "unknown option '$1'" ;;
    *)       FLAVOURS+=("$1") ;;
  esac
  shift
done
[ ${#FLAVOURS[@]} -gt 0 ] || FLAVOURS=("$DEFAULT_FLAVOUR")

[ -d "$OOLITE" ] || die "upstream/oolite not found under $REPO_ROOT"
[ -f "$NATIVE_FILE" ] || die "missing native file $NATIVE_FILE"

# --- The machine must already be provisioned --------------------------------------------------
#
# Fail here with the remedy rather than 200 lines into a meson log.

# Deliberately NOT `setup-windows.sh --check`: that queries every pinned package one pacman
# invocation at a time and takes over a minute on this hardware, which is far too slow to pay on
# every build. Check for the binaries this script actually needs and point at the full check.

missing=()
for c in clang meson ninja ccache cygpath; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "build-windows: missing on PATH: ${missing[*]}" >&2
  die "this machine is not provisioned; run tools/setup-windows.sh (Phase 0 item 0.2), or tools/setup-windows.sh --check to see what is absent"
fi

# --- ccache ------------------------------------------------------------------------------------
#
# The cache is configured once by setup-windows.sh (one directory shared by every agent worktree,
# so a file another worktree already compiled is a hit here). Record the counters up front so the
# run can report what the cache actually did, which is the only honest check that it is on:
# ccache being installed says nothing, as the stock build proves.

# Depend mode. Meson emits the depfile path relative to the build directory (-MF
# "src/oolite.exe.p/Foo.m.obj.d"). In ccache's default preprocessor mode the real compiler runs
# from ccache's temporary directory, so that relative path does not resolve and the compile dies
# with: error: error opening 'src/oolite.exe.p/Foo.m.obj.d': No such file or directory.
# It fails for a miss and not for a hit, so it shows up as a handful of random files failing out
# of a couple of hundred. In depend mode ccache runs the compiler with the original arguments in
# the original directory and uses the compiler's own depfile, which is both correct here and
# faster (no second preprocessor pass).
export CCACHE_DEPEND=1

# ccache hashes any absolute paths it is handed, and every agent worktree sits at a different
# absolute path. base_dir rewrites absolute paths beneath it to relative ones before hashing.
#
# It must be a *native* Windows path. ccache here is a native binary and rejects an MSYS path
# ("CCACHE_BASEDIR: not an absolute path: /c/Users/..."), which makes every later ccache
# invocation - including --print-stats - fail. That was silent: the stats query below returned
# empty and the build died in arithmetic instead, and base_dir was never actually in effect, so
# worktrees missed on every object.
export CCACHE_BASEDIR="$(cygpath -m "$REPO_ROOT")"

# Pin the version macro, which is what actually decides whether worktrees share the cache.
#
# mk.sh derives OO_VERSION_FULL from the checked-out branch, so a bead worktree compiles every
# translation unit with -DOO_VERSION_FULL="0.0.1-bead-<id>.1". That single differing -D is enough
# to miss on every object: measured 0 hit / 242 miss building the same tree in a second worktree,
# with base_dir already set. Across a fan-out of hundreds of fleet beads that is a full cold
# build each time, which is precisely the cost I1 item 2 exists to remove.
#
# Verification builds do not need a branch-derived version, so pin one. Release packaging does -
# it must not use this script, or must pass OOLITE_VER_FULL explicitly.
export OOLITE_VER_FULL="${OOLITE_VER_FULL:-0.0.0-fleet}"

ccache_stat() {
  local v
  v="$(ccache --print-stats 2>/dev/null | awk -v k="$1" '$1 == k {print $2}')"
  # Any ccache failure (bad config, missing cache dir) yields an empty string; never let that
  # reach an arithmetic context, where it aborts the build under `set -e` before a line compiles.
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}
HITS_BEFORE=$(( $(ccache_stat direct_cache_hit) + $(ccache_stat preprocessed_cache_hit) ))
MISS_BEFORE="$(ccache_stat cache_miss)"

say "ccache $(ccache --version | head -1 | awk '{print $3}'), cache_dir $(ccache --show-config 2>/dev/null | awk '/cache_dir =/{print $NF}')"

# --- Build --------------------------------------------------------------------------------------

STARTED_AT=$SECONDS
for flavour in "${FLAVOURS[@]}"; do
  case "$flavour" in
    deployment|test|dev|debug) ;;
    *) die "unknown flavour '$flavour' (expected: deployment, test, dev, debug)" ;;
  esac

  if $CLEAN; then
    say "cleaning build/meson_$flavour"
    ( cd "$OOLITE" && ./mk.sh clean "$flavour" >/dev/null 2>&1 ) || true
  fi

  say "building flavour '$flavour'"
  # PYTHONUTF8 matches the upstream workflow. --native-file replaces clang.ini rather than adding
  # to it; see tools/meson/ccache-clang.ini for why it cannot be layered.
  ( cd "$OOLITE" && PYTHONUTF8=1 ./mk.sh build "$flavour" \
      --native-file="$(cygpath -m "$NATIVE_FILE")" \
      --ver-full="$OOLITE_VER_FULL" )

  binary="$OOLITE/build/meson_$flavour/oolite.app/oolite.exe"
  [ -f "$binary" ] || die "flavour '$flavour' reported success but $binary is missing"
  say "flavour '$flavour' ok: $(stat -c %s "$binary") bytes"
done
ELAPSED=$(( SECONDS - STARTED_AT ))

# --- Report what the cache did -------------------------------------------------------------------

HITS_AFTER=$(( $(ccache_stat direct_cache_hit) + $(ccache_stat preprocessed_cache_hit) ))
MISS_AFTER="$(ccache_stat cache_miss)";       MISS_AFTER="${MISS_AFTER:-0}"
HITS=$(( HITS_AFTER - HITS_BEFORE ))
MISSES=$(( MISS_AFTER - MISS_BEFORE ))
TOTAL=$(( HITS + MISSES ))
if [ "$TOTAL" -gt 0 ]; then
  say "ccache this run: $HITS hit / $MISSES miss ($(( HITS * 100 / TOTAL ))% hit rate), ${ELAPSED}s"
else
  say "ccache this run: no compilations (nothing to rebuild), ${ELAPSED}s"
fi
echo "build-windows: built ${FLAVOURS[*]} in ${ELAPSED}s"
