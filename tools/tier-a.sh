#!/usr/bin/env bash
#
# Tier A — the agent inner loop. Phase 0 item 0.9 (docs/phases/0-safety-net.md),
# tiers defined in docs/execution-model.md §3.1.
#
#     tools/tier-a.sh upstream/oolite/src/Core/OOColor.m
#
# Three steps against ONE translation unit, offline, in under 30 seconds:
#
#   1. compile   the single TU, via its ninja object target (so it is byte-for-byte the
#                command the real build uses, and it hits the shared ccache)
#   2. tidy      clang-tidy with the repo's .clang-tidy, findings are failures
#   3. deny-list grep for reintroduced JS_* / libgnustep-base symbols, counted against
#                the merge base so pre-existing sites do not fail every run
#
# Exits 0 only if all three pass; the first failing step is named on the last line.
# Nothing here touches the network: it reuses an existing meson build directory and
# configures one only if none exists (which is the one slow path, and it says so).
#
# Deliberately NOT included: that module's unit tests. execution-model §3.1 lists them in
# Tier A, but the component tier (ADR-0018) costs ~5-10 s per game launch and there is no
# per-module unit test target in this tree yet. When one exists it belongs here, behind the
# same 30 s budget. Tier B runs the tagged component subset today.

set -euo pipefail

BUILD_FLAVOUR="${OOLITE_TIER_A_FLAVOUR:-test}"
BUDGET_SECONDS="${OOLITE_TIER_A_BUDGET:-30}"

# --- Re-exec into the UCRT64 shell -------------------------------------------------------
#
# Same reason as tools/build-windows.sh: this runs as a bead's acceptance command, and
# accept.sh runs those with a plain `bash -c` in whatever shell the orchestrator started
# in. Without this, Tier A fails on MSYSTEM rather than on the code.

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_TIER_A_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OOLITE_TIER_A_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
BUILD_DIR="$OOLITE/build/meson_$BUILD_FLAVOUR"
NATIVE_FILE="$REPO_ROOT/tools/meson/ccache-clang.ini"
DENY_LIST="$REPO_ROOT/tools/deny-list.txt"
COMPDB_READER="$REPO_ROOT/tools/tier-a-compdb.py"

STARTED_AT=$SECONDS
step()   { printf '==> %s\n' "$*"; }
detail() { printf '    %s\n' "$*"; }
die()    { printf 'tier-a: %s\n' "$*" >&2; exit 1; }

fail() {
  printf 'tier-a: FAIL (%s) in %ss\n' "$1" "$(( SECONDS - STARTED_AT ))" >&2
  exit 1
}

usage() { sed -n '2,24p' "${BASH_SOURCE[0]}"; }

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; die "expected exactly one source file argument" ;;
esac
[ $# -eq 1 ] || die "expected exactly one source file argument, got $#"

SOURCE="$1"
[ -f "$SOURCE" ] || die "no such file: $SOURCE"

# Absolute, and relative to the repo root, in forward-slash form. Every later step needs one
# or the other, and MSYS paths (/c/...) must never reach a native binary — clang, ninja,
# meson and python are all native Windows here and read /c/foo as a relative path.
SOURCE_ABS="$(cd "$(dirname "$SOURCE")" && pwd)/$(basename "$SOURCE")"
SOURCE_NATIVE="$(cygpath -m "$SOURCE_ABS")"
SOURCE_REL="${SOURCE_ABS#"$REPO_ROOT"/}"
[ "$SOURCE_REL" != "$SOURCE_ABS" ] || die "$SOURCE is outside the repository at $REPO_ROOT"

for c in clang clang-tidy ninja meson python cygpath; do
  command -v "$c" >/dev/null 2>&1 \
    || die "missing '$c' on PATH; run tools/setup-windows.sh (Phase 0 item 0.2)"
done
[ -f "$DENY_LIST" ]      || die "missing deny-list $DENY_LIST"
[ -f "$COMPDB_READER" ]  || die "missing $COMPDB_READER"

step "tier-a $SOURCE_REL (flavour $BUILD_FLAVOUR, budget ${BUDGET_SECONDS}s)"

# --- ccache, exactly as tools/build-windows.sh sets it up --------------------------------
#
# Depend mode (meson's -MF path is relative to the build dir and does not resolve from
# ccache's temp dir in preprocessor mode), base_dir so worktrees at different absolute paths
# share entries, and a pinned version macro so a bead branch does not miss on every object.
# Without all three, Tier A is a cold compile and misses the 30 s budget.
export CCACHE_DEPEND=1
export CCACHE_BASEDIR="$(cygpath -m "$REPO_ROOT")"
export OOLITE_VER_FULL="${OOLITE_VER_FULL:-0.0.0-fleet}"

# --- The build directory -----------------------------------------------------------------
#
# Reuse it. Configuring is the one thing here that takes minutes, so it happens only when
# there is nothing to reuse (a clean checkout), and it is announced as being off-budget.
# `meson setup` is offline: this project vendors no subprojects and has no .wrap files, so
# there is nothing for meson to fetch.

if [ ! -f "$BUILD_DIR/build.ninja" ]; then
  step "no build directory at ${BUILD_DIR#"$REPO_ROOT"/}; configuring once (off-budget, minutes)"
  [ -f "$NATIVE_FILE" ] || die "missing native file $NATIVE_FILE"
  ( cd "$OOLITE" && PYTHONUTF8=1 ./mk.sh setup "$BUILD_FLAVOUR" \
      --native-file="$(cygpath -m "$NATIVE_FILE")" \
      --ver-full="$OOLITE_VER_FULL" >/dev/null ) \
    || die "meson setup failed; run tools/build-windows.sh to see the log"
  STARTED_AT=$SECONDS   # the budget is the steady-state loop, not first-run provisioning
fi
[ -f "$BUILD_DIR/compile_commands.json" ] || die "no compile_commands.json in $BUILD_DIR"

# --- Read this file's compile command out of the compile database ------------------------
#
# The object target tells step 1 what to build; the argument list tells step 2 how to parse
# the TU. Both come from the database so they cannot drift from the real build. Paths in it
# are relative to the build directory, so everything below runs with cwd = build directory.

# Via a temp file, not $(...): the fields are NUL-separated (an argument may contain
# spaces and embedded quotes) and command substitution silently drops NUL bytes, which
# splices all 57 arguments onto the ninja target as one word.
COMPDB_OUT="$(mktemp)"
trap 'rm -f "$COMPDB_OUT"' EXIT
( cd "$BUILD_DIR" && python "$(cygpath -m "$COMPDB_READER")" \
    compile_commands.json "$SOURCE_NATIVE" ) > "$COMPDB_OUT" \
  || die "$SOURCE_REL is not in the $BUILD_FLAVOUR build (a header, or not in meson.build?)"

mapfile -d '' -t COMPDB_FIELDS < "$COMPDB_OUT"
OBJECT_TARGET="${COMPDB_FIELDS[0]}"
CLANG_ARGS=("${COMPDB_FIELDS[@]:1}")
[ -n "$OBJECT_TARGET" ] || die "compile database entry for $SOURCE_REL has no output target"

# --- 1. Compile the single translation unit ----------------------------------------------
#
# Via ninja rather than a hand-rolled clang line: ninja also brings up whatever generated
# header or PCH the TU depends on, and it is the same command the full build runs.

step "1/3 compile  $OBJECT_TARGET"
T0=$SECONDS
( cd "$BUILD_DIR" && ninja "$OBJECT_TARGET" ) || fail "compile"
detail "$(( SECONDS - T0 ))s"

# --- 2. clang-tidy ------------------------------------------------------------------------
#
# --warnings-as-errors='*' is what makes a finding fail; -header-filter is pinned to the
# empty match so a shared header is not re-reported by every TU that includes it. The check
# set itself lives in .clang-tidy at the repo root, found by clang-tidy walking up from the
# source file.

step "2/3 tidy     clang-tidy"
T0=$SECONDS
( cd "$BUILD_DIR" && clang-tidy \
    --quiet \
    -header-filter='$^' \
    --warnings-as-errors='*' \
    "$SOURCE_NATIVE" -- clang "${CLANG_ARGS[@]}" ) || fail "clang-tidy"
detail "$(( SECONDS - T0 ))s"

# --- 3. Deny-list -------------------------------------------------------------------------
#
# Baseline-relative: a hit count that is no worse than the same file at the merge base
# passes. See tools/deny-list.txt for why absolute would fail on every file today.
# A file with no committed baseline (newly added) is compared against zero.

step "3/3 deny     tools/deny-list.txt"
T0=$SECONDS

BASE_REF="${OOLITE_TIER_A_BASE:-}"
if [ -z "$BASE_REF" ]; then
  BASE_REF="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || echo HEAD)"
fi

deny_count() {   # deny_count <text-on-stdin> ; prints total hits across all patterns
  local text; text="$(cat)"
  local total=0 pattern hits
  while IFS= read -r pattern; do
    case "$pattern" in ''|'#'*) continue ;; esac
    hits="$(printf '%s' "$text" | grep -cE "$pattern" || true)"
    total=$(( total + hits ))
  done < "$DENY_LIST"
  printf '%s' "$total"
}

NOW_COUNT="$(deny_count < "$SOURCE_ABS")"
if BASE_TEXT="$(git -C "$REPO_ROOT" show "$BASE_REF:$SOURCE_REL" 2>/dev/null)"; then
  BASE_COUNT="$(printf '%s' "$BASE_TEXT" | deny_count)"
else
  BASE_COUNT=0
fi

detail "deny-list hits: $NOW_COUNT now, $BASE_COUNT at ${BASE_REF:0:12}"
if [ "$NOW_COUNT" -gt "$BASE_COUNT" ]; then
  echo "tier-a: $SOURCE_REL reintroduces deny-listed symbols ($BASE_COUNT -> $NOW_COUNT):" >&2
  while IFS= read -r pattern; do
    case "$pattern" in ''|'#'*) continue ;; esac
    grep -nE "$pattern" "$SOURCE_ABS" >&2 || true
  done < "$DENY_LIST"
  fail "deny-list"
fi
detail "$(( SECONDS - T0 ))s"

# --- Report -------------------------------------------------------------------------------

ELAPSED=$(( SECONDS - STARTED_AT ))
if [ "$ELAPSED" -gt "$BUDGET_SECONDS" ]; then
  echo "tier-a: PASS but ${ELAPSED}s exceeds the ${BUDGET_SECONDS}s budget for $SOURCE_REL" >&2
  exit 1
fi
echo "tier-a: PASS $SOURCE_REL in ${ELAPSED}s (budget ${BUDGET_SECONDS}s)"
