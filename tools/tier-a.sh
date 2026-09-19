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
#
# Two rules, because the previous version had neither and so was a guard that could not
# fail (bead oo-wfvu):
#
#   1. MSYS2 is DISCOVERED, not assumed to be at /c/msys64. It is /c/msys64 on a default
#      install, C:/Users/<user>/scoop/apps/msys2/current under scoop, and anywhere at all
#      with a custom prefix, so a hard-coded path makes the guard a no-op on most machines.
#   2. If the UCRT64 environment cannot be reached or confirmed, this DIES. Continuing
#      would resolve clang / clang-tidy / ninja / meson from whatever PATH happened to be
#      inherited and report a tier-A result produced by an unknown toolchain.

# --- The source-only seam ----------------------------------------------------------------
#
# `OOLITE_TIER_A_SOURCE_ONLY=1 . tools/tier-a.sh` defines this file's deny-list functions and
# returns without running a step, so tools/tier-a-deny-probe.sh exercises the REAL gate
# rather than a paraphrase of it. Two things must not happen on that path: the re-exec below
# (an exec would replace the probe process), and the UCRT64 environment assertions after it
# (probing pure shell functions needs no toolchain, and accept.sh runs its lines from a
# plain MSYSTEM=MSYS shell).
#
# The seam is deliberately NOT the environment variable alone: it ALSO requires that this
# file really was sourced, so exporting OOLITE_TIER_A_SOURCE_ONLY=1 can never weaken an
# EXECUTED tier-A run. An executed script has $0 == ${BASH_SOURCE[0]}; a sourced one does not,
# because $0 still belongs to the calling shell. Both conditions, or no seam -- which is why
# `OOLITE_TIER_A_SOURCE_ONLY=1 bash tools/tier-a.sh <file>` still re-execs, still asserts
# UCRT64 and still runs all three steps (bead oo-wfvu's guard stays intact).
OOLITE_TIER_A_SOURCE_SEAM=0
if [ "${OOLITE_TIER_A_SOURCE_ONLY:-0}" = 1 ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
  OOLITE_TIER_A_SOURCE_SEAM=1
fi

die() { printf 'tier-a: %s\n' "$*" >&2; exit 1; }

# A candidate MSYS2 root counts only if it has BOTH usr/bin/bash.exe and a ucrt64/bin
# directory. The second test is what tells a real MSYS2 apart from Git-for-Windows' bash
# (which also ships usr/bin/bash.exe and cygpath, but has no ucrt64 prefix — re-exec'ing
# into it with MSYSTEM=UCRT64 would produce a shell whose MSYSTEM is a lie).
msys2_bash_from_root() {
  local root="${1%/}"
  [ -n "$root" ] || return 1
  [ -x "$root/usr/bin/bash.exe" ] || return 1
  [ -d "$root/ucrt64/bin" ] || return 1
  printf '%s' "$root/usr/bin/bash.exe"
}

# Candidates, best first: an explicit caller override; this shell's own MSYS2 root (correct
# whenever we are already inside MSYS2 under some other MSYSTEM, wherever it is installed),
# found via `cygpath -m /` and, if cygpath is unavailable, via the running bash's own path;
# then the conventional install locations, last.
find_msys2_bash() {
  local root candidates=()
  if [ -n "${MSYS2_BASH:-}" ]; then
    [ -x "$MSYS2_BASH" ] || return 1
    printf '%s' "$MSYS2_BASH"
    return 0
  fi
  if [ -n "${MSYS2_ROOT:-}" ]; then
    candidates+=("$MSYS2_ROOT")
  fi
  if command -v cygpath >/dev/null 2>&1; then
    root="$(cygpath -m / 2>/dev/null || true)"
    if [ -n "$root" ]; then candidates+=("$root"); fi
  fi
  case "${BASH:-}" in
    */usr/bin/bash*) candidates+=("${BASH%/usr/bin/bash*}") ;;
  esac
  candidates+=(/c/msys64 /c/tools/msys64 "${HOME:-/nonexistent}/scoop/apps/msys2/current")
  for root in "${candidates[@]}"; do
    msys2_bash_from_root "$root" && return 0
  done
  return 1
}

if [ "$OOLITE_TIER_A_SOURCE_SEAM" != 1 ] \
   && [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_TIER_A_REEXEC:-}" ]; then
  MSYS2_BASH_RESOLVED="$(find_msys2_bash)" || die \
"MSYSTEM is '${MSYSTEM:-unset}' and no MSYS2 installation with a UCRT64 environment was found.
       Looked at: \$MSYS2_BASH, \$MSYS2_ROOT, cygpath -m /, \$BASH, /c/msys64, /c/tools/msys64,
       \$HOME/scoop/apps/msys2/current (a root counts only with usr/bin/bash.exe AND ucrt64/bin).
       Run tier-a.sh from an MSYS2 UCRT64 shell, or set MSYS2_BASH=<msys2-root>/usr/bin/bash.exe."
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64 ($MSYS2_BASH_RESOLVED)" >&2
  export OOLITE_TIER_A_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH_RESOLVED" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

# The re-exec did not happen, or happened and did not take. Either way, prove we are in a
# real UCRT64 environment before trusting PATH — the assertion tools/setup-windows.sh:98
# makes, and which this script was missing entirely.
#
# MSYSTEM alone is not sufficient evidence: any shell can export MSYSTEM=UCRT64. So also
# require the MSYS2 prefix to be the UCRT64 one and to exist. MSYSTEM_PREFIX/MINGW_PREFIX
# are exported by /etc/profile but not by a non-login `bash -c`, so an unset prefix is
# normal and falls back to /ucrt64; a prefix set to something ELSE (/mingw64, /clang64) is
# a contradiction and is refused.
#
# Skipped ONLY on the genuinely-sourced probe path (see the source-only seam above): sourcing
# this file defines shell functions and touches no compiler, so demanding a UCRT64 toolchain
# there would make the probe unrunnable from accept.sh's MSYSTEM=MSYS shell. Every executed
# run -- including `OOLITE_TIER_A_SOURCE_ONLY=1 bash tools/tier-a.sh <file>` -- still asserts.
if [ "$OOLITE_TIER_A_SOURCE_SEAM" != 1 ]; then
  [ "${MSYSTEM:-}" = "UCRT64" ] || die \
    "refusing to run with MSYSTEM='${MSYSTEM:-unset}': tier A must use the MSYS2 UCRT64 toolchain (start <msys2-root>/ucrt64.exe, or set MSYS2_BASH and unset OOLITE_TIER_A_REEXEC)"
  OOLITE_UCRT_PREFIX="${MSYSTEM_PREFIX:-${MINGW_PREFIX:-/ucrt64}}"
  [ "$OOLITE_UCRT_PREFIX" = "/ucrt64" ] || die \
    "MSYSTEM says UCRT64 but MSYSTEM_PREFIX/MINGW_PREFIX is '$OOLITE_UCRT_PREFIX', not /ucrt64; this environment is inconsistent, refusing to guess a toolchain"
  command -v cygpath >/dev/null 2>&1 || die \
    "MSYSTEM=UCRT64 but there is no cygpath on PATH; this is not an MSYS2 shell"
  [ -d "$OOLITE_UCRT_PREFIX/bin" ] || die \
    "MSYSTEM=UCRT64 but $OOLITE_UCRT_PREFIX/bin does not exist; this is not a working MSYS2 UCRT64 installation"
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
# die() is defined above, with the MSYS2/UCRT64 guard, because that guard needs it.

fail() {
  printf 'tier-a: FAIL (%s) in %ss\n' "$1" "$(( SECONDS - STARTED_AT ))" >&2
  exit 1
}

usage() { sed -n '2,24p' "${BASH_SOURCE[0]}"; }

# --- the deny-list gate (step 3), defined here so a probe can source the REAL code -----------
#
# Sourcing: `OOLITE_TIER_A_SOURCE_ONLY=1 . tools/tier-a.sh` defines resolve_base_ref,
# deny_count and deny_gate and returns without running any step, so
# tools/tier-a-deny-probe.sh exercises these functions rather than a paraphrase of them.
# That is the tools/check-file-modes.sh pattern (bead oo-tqmx) applied here.
#
# Three defects this replaces (bead oo-2ixr), each of which on its own made step 3 a gate
# that could never fail:
#
#   A. `merge-base HEAD main || echo HEAD` compared the working tree against ITSELF whenever
#      the merge base was unavailable (single-branch clone, detached CI checkout), so the
#      baseline count always equalled the current count. A baseline that cannot be resolved
#      is now fatal: a gate that cannot fail must not be allowed to report PASS.
#   B. `grep -cE` counts LINES. Adding two more JS_* calls to a line that already had one was
#      invisible, and packing previously-separate hits onto fewer lines LOWERED the baseline
#      enough to mask new ones. Occurrences are counted with `grep -oE` instead.
#   C. `|| true` swallowed grep's exit 2 (malformed ERE, unreadable input) exactly as it
#      swallowed exit 1 (no match), so one typo in tools/deny-list.txt retired that rule for
#      good and nothing said so. rc >= 2 is now an error, distinct from "no match".

# deny_count [deny-list-path] -- text on stdin; prints the TOTAL NUMBER OF OCCURRENCES of all
# patterns (not the number of matching lines). Exit 0 ok, 2 if a pattern is unusable.
deny_count() {
  local list="${1:-$DENY_LIST}"
  local text; text="$(cat)"
  local total=0 pattern out rc hits
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    case "$pattern" in ''|'#'*) continue ;; esac
    # grep's status is CAPTURED, never swallowed: 0 = hits, 1 = no match, >= 2 = grep itself
    # failed. Captured with `|| rc=$?` rather than by toggling `set +e` / `set -e`: this file
    # is also SOURCED by tools/tier-a-deny-probe.sh, and a bare `set -e` here would switch
    # errexit ON in the probe's shell and kill it at its first deliberately-failing case.
    rc=0
    out="$(printf '%s\n' "$text" | grep -oE "$pattern")" || rc=$?
    if [ "$rc" -ge 2 ]; then
      printf 'tier-a: deny-list pattern is unusable (grep exit %s): %s\n' "$rc" "$pattern" >&2
      printf 'tier-a: fix it in %s -- a pattern that cannot run is a rule that never runs\n' \
        "$list" >&2
      return 2
    fi
    if [ -n "$out" ]; then
      hits="$(printf '%s\n' "$out" | wc -l)"
      total=$(( total + hits ))
    fi
  done < "$list"
  printf '%s' "$total"
}

# resolve_base_ref <repo-root> -- print the commit the deny-list baseline is read from.
# Exit 1 (never a silent fallback to HEAD) when no baseline can be resolved.
resolve_base_ref() {
  local root="$1" branch="${OOLITE_TIER_A_BASE_BRANCH:-main}" ref='' cand head
  if [ -n "${OOLITE_TIER_A_BASE:-}" ]; then
    ref="$(git -C "$root" rev-parse --verify --quiet "${OOLITE_TIER_A_BASE}^{commit}")" || ref=''
    if [ -z "$ref" ]; then
      printf 'tier-a: OOLITE_TIER_A_BASE=%s does not name a commit in %s\n' \
        "$OOLITE_TIER_A_BASE" "$root" >&2
      return 1
    fi
  else
    # The base branch may be local (`main`) or only a remote-tracking ref (a CI checkout that
    # fetched one branch); try both before giving up. This is the resolution order
    # tools/guardrails.sh uses, and it is what makes the gate live in accept.sh's DETACHED
    # merged checkout, where HEAD is the merge commit and `main` is still a local branch.
    for cand in "$branch" "origin/$branch" "refs/remotes/origin/$branch"; do
      git -C "$root" rev-parse --verify --quiet "${cand}^{commit}" >/dev/null || continue
      ref="$(git -C "$root" merge-base HEAD "$cand" 2>/dev/null)" || ref=''
      [ -n "$ref" ] && break
    done
    if [ -z "$ref" ]; then
      printf 'tier-a: no merge base between HEAD and %s in %s.\n' "$branch" "$root" >&2
      printf 'tier-a: refusing to run the deny-list against HEAD itself -- that compares the\n' >&2
      printf 'tier-a: file with itself and can never fail. Fetch %s, or set OOLITE_TIER_A_BASE.\n' \
        "$branch" >&2
      return 1
    fi
  fi
  head="$(git -C "$root" rev-parse --verify --quiet 'HEAD^{commit}')" || head=''
  if [ -n "$head" ] && [ "$ref" = "$head" ]; then
    printf 'tier-a: note: deny-list baseline is HEAD (%s); a committed regression at HEAD\n' \
      "${ref:0:12}" >&2
    printf 'tier-a: note: is part of the baseline and only uncommitted hits can fail.\n' >&2
  fi
  printf '%s' "$ref"
}

# deny_gate <repo-root> <base-ref> <source-file> <source-rel-path>
#   0 = no new hits, 1 = REGRESSION (more occurrences than the baseline), 2 = the gate could
#   not be evaluated (bad ref, unusable pattern). 2 is never reported as a pass.
deny_gate() {
  local root="$1" base="$2" file="$3" rel="$4"
  local now_count base_count base_text pattern rc parent

  [ -f "$file" ] || { printf 'tier-a: no such file: %s\n' "$file" >&2; return 2; }
  git -C "$root" rev-parse --verify --quiet "${base}^{commit}" >/dev/null \
    || { printf 'tier-a: deny-list baseline %s is not a commit\n' "$base" >&2; return 2; }

  now_count="$(deny_count <"$file")" || return 2

  if git -C "$root" cat-file -e "$base:$rel" 2>/dev/null; then
    # THE VACUITY CHECK. If the baseline is HEAD itself and the file on disk is byte-identical
    # to the blob at HEAD, both counts are computed from the SAME BYTES: the comparison is a
    # tautology and step 3 cannot fail, whatever the file contains. That is exactly the state
    # the old `|| echo HEAD` fallback produced, and it reported PASS. Step back to HEAD's
    # first parent, which is a real baseline ("did the last commit add deny-listed symbols?");
    # if there is no such baseline, refuse rather than run a check that cannot fail.
    # "unmodified" is decided with `git diff` on the REPO-RELATIVE path, not by hashing an
    # absolute one: on MSYS an absolute /c/... path handed to native git resolves elsewhere.
    if [ "$base" = "$(git -C "$root" rev-parse --verify --quiet 'HEAD^{commit}')" ] \
       && git -C "$root" diff --quiet "$base" -- "$rel"; then
      parent="$(git -C "$root" rev-parse --verify --quiet "${base}^1^{commit}")" || parent=''
      if [ -n "$parent" ] && git -C "$root" cat-file -e "$parent:$rel" 2>/dev/null; then
        printf 'tier-a: baseline %s is HEAD and %s is unmodified there; using %s instead\n' \
          "${base:0:12}" "$rel" "${parent:0:12}" >&2
        base="$parent"
      else
        printf 'tier-a: the deny-list baseline for %s is HEAD, the file is unmodified, and\n' \
          "$rel" >&2
        printf 'tier-a: there is no earlier commit of it: both counts would read the same\n' >&2
        printf 'tier-a: bytes and step 3 could never fail. Set OOLITE_TIER_A_BASE.\n' >&2
        return 2
      fi
    fi
    base_text="$(git -C "$root" show "$base:$rel")" \
      || { printf 'tier-a: cannot read %s at %s\n' "$rel" "$base" >&2; return 2; }
    base_count="$(printf '%s\n' "$base_text" | deny_count)" || return 2
  else
    # Genuinely absent at the baseline (a newly added file): compared against zero. This is
    # the ONLY case that may default, and it is decided by cat-file -e, not by a swallowed error.
    base_count=0
  fi

  detail "deny-list hits: $now_count now, $base_count at ${base:0:12}"
  if [ "$now_count" -gt "$base_count" ]; then
    printf 'tier-a: %s reintroduces deny-listed symbols (%s -> %s):\n' \
      "$rel" "$base_count" "$now_count" >&2
    while IFS= read -r pattern || [ -n "$pattern" ]; do
      case "$pattern" in ''|'#'*) continue ;; esac
      rc=0
      grep -nE "$pattern" "$file" >&2 || rc=$?
      [ "$rc" -le 1 ] || printf 'tier-a: (pattern unusable while reporting: %s)\n' "$pattern" >&2
    done < "$DENY_LIST"
    return 1
  fi
  return 0
}

# --- the stale-build-dir detector (used before step 1), in the sourced surface ---------------
#
# WHY THIS EXISTS (bead oo-1bf.8, found by the Phase 0 review of oo-ss8). When meson.build (or
# meson.options, a subdir meson.build, the native file) is newer than build.ninja, ninja does
# not just compile: it first runs its REGENERATE_BUILD rule, i.e. `meson --internal regenerate`.
# On this box that path DIES, and it dies looking like a compile error in the file under test.
# tools/build-windows.sh:54-63 documents the trap for the SETUP path and it applies verbatim to
# the REGENERATE path: upstream's ShellScripts/common/get_version.sh:7-27 refuses to run unless
# it can identify meson as its parent, and under the regenerate rule the parent shows as
# python.exe. Reproduced directly on this tree with meson.build touched:
#
#   [0/1] Regenerating build files
#   ../../meson.build:5:13: ERROR: Command `... get_version.sh ...` failed with status 1.
#   ninja: error: rebuilding 'build.ninja': subcommand failed
#
# which tier-a reported as `FAIL (compile) in 3s` on EVERY file for ~20 hours after oo-ss8.
#
# These two functions are defined HERE rather than beside their use site so the source-only
# seam exposes them and tools/tier-a-stale-probe.sh can drive the REAL detector.

# buildsystem_files <build-dir> -- every file whose change makes build.ninja stale, one per
# line. Meson records the list itself in meson-info/intro-buildsystem_files.json, which is the
# same set ninja names as inputs of its `build build.ninja: REGENERATE_BUILD ...` edge, so this
# cannot drift from what actually triggers a regeneration. The hard-coded fallback is used only
# when that file is absent (an old or partially-written build dir) and is deliberately WIDER
# than necessary: over-reporting costs one reconfigure, under-reporting costs the 20-hour
# outage this exists to prevent.
buildsystem_files() {
  local dir="$1" info
  info="$dir/meson-info/intro-buildsystem_files.json"
  if [ -f "$info" ]; then
    # One JSON string per line, as meson writes it; entries are native forward-slash paths
    # (C:/...), which bash's own file tests accept on MSYS.
    sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}[[:space:]]*$/\1/p' "$info"
    return 0
  fi
  printf '%s\n' "$OOLITE/meson.build" "$OOLITE/meson.options" "$NATIVE_FILE"
  find "$OOLITE/src" -name meson.build 2>/dev/null || true
}

# stale_buildsystem_files <build-dir> -- print every build-system file NEWER than that dir's
# build.ninja. Empty output means the build dir is current and ninja will not regenerate.
# mtime-only: no subprocess per file, so the warm path pays nothing.
stale_buildsystem_files() {
  local dir="$1" f ninja
  ninja="$dir/build.ninja"
  # No build.ninja at all is NOT this check's business (the configure-once block above owns
  # that case); reporting every build-system file as stale here would hide it.
  [ -f "$ninja" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -e "$f" ] || continue
    [ "$f" -nt "$ninja" ] || continue
    printf '%s\n' "$f"
  done < <(buildsystem_files "$dir")
}

# End of the sourced surface: a probe that sourced this file has what it came for. Keyed on
# the seam, not on the bare variable, so an EXECUTED run with OOLITE_TIER_A_SOURCE_ONLY=1 in
# its environment falls through here and runs the full three-step gate instead of exiting 0.
if [ "$OOLITE_TIER_A_SOURCE_SEAM" = 1 ]; then
  return 0
fi

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

# And they must be THE UCRT64 ones. This is the other half of the bug in bead oo-wfvu: with
# MSYSTEM right but PATH wrong (a mingw64 shell's leftovers, a native LLVM in Program Files)
# the tier-A verdict would be produced by an unknown toolchain and reported as authoritative.
# cygpath is an /usr/bin tool in every MSYSTEM, so it is exempt from the prefix check.
for c in clang clang-tidy ninja meson python; do
  OOLITE_TOOL_PATH="$(command -v "$c")"
  case "$OOLITE_TOOL_PATH" in
    "$OOLITE_UCRT_PREFIX"/*) ;;
    *) die "'$c' resolves to $OOLITE_TOOL_PATH, outside the UCRT64 prefix $OOLITE_UCRT_PREFIX; PATH is not the UCRT64 toolchain's (start <msys2-root>/ucrt64.exe)" ;;
  esac
done
[ -f "$DENY_LIST" ]      || die "missing deny-list $DENY_LIST"
[ -f "$COMPDB_READER" ]  || die "missing $COMPDB_READER"

step "tier-a $SOURCE_REL (flavour $BUILD_FLAVOUR, budget ${BUDGET_SECONDS}s)"

# --- ccache, exactly as tools/build-windows.sh sets it up --------------------------------
#
# Depend mode (meson's -MF path is relative to the build dir and does not resolve from
# ccache's temp dir in preprocessor mode), base_dir so worktrees at different absolute paths
# share entries, and a pinned version macro so a bead branch does not miss on every object.
# These raise the hit RATE across worktrees; they are not what keeps Tier A inside the budget.
# Measured 2026-09-17 (docs/phases/0-safety-net.md "Commands"): with CCACHE_DIR redirected to an
# empty directory a steady-state run is ~4 s versus ~4.4 s warm — one TU is cheap either way.
# The first-run cost is `meson setup` (~10 s), not compilation.
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

# --- A build directory OLDER than the build system that generated it ---------------------
#
# WHY THIS EXISTS (bead oo-1bf.8, found by the Phase 0 review of oo-ss8). When meson.build
# (or meson.options, a subdir meson.build, the native file) is newer than build.ninja, ninja
# will not just compile: it first runs its REGENERATE_BUILD rule, i.e. `meson --internal
# regenerate`. On this box that path dies, and it dies in a way that looks like a compile
# error in the file under test. tools/build-windows.sh:54-63 documents the trap for the SETUP
# path and it applies verbatim here: upstream's ShellScripts/common/get_version.sh:7-27
# refuses to run unless it can identify meson as its parent, and under the regenerate rule the
# parent process is python.exe. After oo-ss8 touched upstream/oolite/meson.build this made
# tier-a report `FAIL (compile)` on EVERY file for ~20 hours, until build-windows.sh was
# re-run by hand.
#
# The remedy is build-windows.sh's remedy: do the configure THROUGH tools/build-windows.sh,
# which supplies MINGW_PREFIX and the rest of the environment get_version.sh's guard needs,
# before ninja is ever asked to regenerate. Upstream's get_version.sh is not edited
# (ADR-0012/0017).
#
# The check is mtime-only and runs no subprocess on the warm path, so it costs nothing in the
# steady state; the reconfigure itself is announced and off-budget, exactly like the
# first-run configure above.

# buildsystem_files / stale_buildsystem_files are defined with the deny-list gate above, in
# this file's SOURCED surface, so tools/tier-a-stale-probe.sh exercises the real detector
# rather than a paraphrase of it (the tools/tier-a-deny-probe.sh pattern).

STALE_FILES="$(stale_buildsystem_files "$BUILD_DIR")"
if [ -n "$STALE_FILES" ]; then
  STALE_COUNT="$(printf '%s\n' "$STALE_FILES" | grep -c . || true)"
  STALE_FIRST="$(printf '%s\n' "$STALE_FILES" | head -1)"
  # meson records these paths in NATIVE form (C:/...), while $REPO_ROOT is this shell's MSYS
  # form (/c/...), so strip both before reporting or the message carries an absolute path.
  STALE_FIRST="${STALE_FIRST#"$REPO_ROOT"/}"
  STALE_FIRST="${STALE_FIRST#"$(cygpath -m "$REPO_ROOT")"/}"
  step "build.ninja is older than $STALE_COUNT build-system file(s) ($STALE_FIRST); reconfiguring through tools/build-windows.sh rather than letting ninja regenerate (off-budget)"
  RECONFIG_LOG="$(mktemp)"
  if ! "$REPO_ROOT/tools/build-windows.sh" "$BUILD_FLAVOUR" >"$RECONFIG_LOG" 2>&1; then
    cat "$RECONFIG_LOG" >&2
    rm -f "$RECONFIG_LOG"
    die "tools/build-windows.sh $BUILD_FLAVOUR failed while reconfiguring the stale build directory (log above)"
  fi
  rm -f "$RECONFIG_LOG"
  [ -f "$BUILD_DIR/build.ninja" ] \
    || die "tools/build-windows.sh ran but there is still no $BUILD_DIR/build.ninja"
  # Refuse to continue into ninja if the reconfigure did not actually refresh build.ninja:
  # that is the exact state whose regeneration this section exists to avoid, and reporting a
  # compile failure for it would blame the source file again.
  STALE_FILES="$(stale_buildsystem_files "$BUILD_DIR")"
  [ -z "$STALE_FILES" ] || die \
    "build.ninja is still older than $(printf '%s\n' "$STALE_FILES" | head -1) after tools/build-windows.sh; refusing to let ninja run its regenerate rule"
  STARTED_AT=$SECONDS   # the budget is the steady-state loop, not a reconfigure
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

BASE_REF="$(resolve_base_ref "$REPO_ROOT")" \
  || die "cannot resolve a deny-list baseline; see the message above"
[ -n "$BASE_REF" ] || die "cannot resolve a deny-list baseline for $SOURCE_REL"

DENY_RC=0
deny_gate "$REPO_ROOT" "$BASE_REF" "$SOURCE_ABS" "$SOURCE_REL" || DENY_RC=$?
case "$DENY_RC" in
  0) ;;
  1) fail "deny-list" ;;
  *) die "the deny-list gate could not be evaluated for $SOURCE_REL (exit $DENY_RC); refusing to report PASS" ;;
esac
detail "$(( SECONDS - T0 ))s"

# --- Report -------------------------------------------------------------------------------

ELAPSED=$(( SECONDS - STARTED_AT ))
if [ "$ELAPSED" -gt "$BUDGET_SECONDS" ]; then
  echo "tier-a: PASS but ${ELAPSED}s exceeds the ${BUDGET_SECONDS}s budget for $SOURCE_REL" >&2
  exit 1
fi
echo "tier-a: PASS $SOURCE_REL in ${ELAPSED}s (budget ${BUDGET_SECONDS}s)"
