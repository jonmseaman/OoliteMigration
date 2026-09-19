#!/usr/bin/env bash
#
# Tier B -- the PER-COMMIT gate. Phase 0 item 0.9b (docs/phases/0-safety-net.md),
# tiers defined in docs/execution-model.md §3.1.
#
#     tools/tier-b.sh                 # everything, including the build
#     tools/tier-b.sh --fast          # accept.sh variant: NO build (see --fast below)
#     tools/tier-b.sh --list          # print the stages and their measured cost, run nothing
#
# Seven stages, in increasing cost, each of which must produce POSITIVE EVIDENCE that it did its
# work. Measured on the fleet box (i9-12900KS, 24 threads, 64 GiB), 2026-09-18, four sibling
# agents active:
#
#   0 guardrails  9-16 s     tools/guardrails.sh -- CLAUDE.md rules 1, 2, 3, 8, offline
#   1 build       13-22 s warm/incremental, ~142 s genuinely cold  (tools/build-windows.sh test)
#   2 tests       ~12 s      offline module tests, 3 suites
#   2b parity     ~3 s       tier-b's environment must agree with a bare shell's verdict
#   3 goldens     ~43 s      every blessed golden under goldens/<platform>/
#   4 component   769-957 s  upstream/oolite/tests/component (ADR-0018) -- see BUDGET HISTORY
#   5 smoke       ~14 s      upstream/oolite/tests/launch_snapshot.py
#   6 corpus      ~53 s      tools/corpus.sh tier1 --limit N  (N=3 by default)
#
#   TOTAL ~900-1100 s in --fast (build skipped, see below), ~1050-1250 s cold.  Budget: 1200 s.
#
# BUDGET HISTORY. The original figure was 600 s ("the bead's \"under 10 minutes\""), sized off the
# per-stage estimates above without ever timing stage 4 end to end -- stage 4's own original
# estimate in this table was "~22 s", off by a factor of ~35-40x from what it actually costs. Two
# separate js-retarget beads (oo-45g attempt 5, escalated) measured stage_component alone -- the
# full 8-scenario upstream/oolite/tests/component suite, one native game launch per scenario -- at
# 769-957 s wall, which alone exceeds 600 s even when every stage passes (bead oo-a6du). There is
# no pytest "fast" marker in tests/component to subset by (seam 0.9b assumed one would exist; it
# never landed), and ADR-0018 sizes this tier at Tier B in full, not a subset, so shrinking what
# --fast runs here would be a scope change to the ADR, not a budget fix. The 1200 s budget is the
# measured component range (769-957 s) plus the OTHER FIVE non-build --fast stages (0, 2, 2b, 3,
# 5, 6 above: 9-16 + 12 + 3 + 43 + 14 + 53 = ~134-141 s -- stage 1 (build) does not run in --fast
# and is excluded from this sum) plus headroom for sibling-agent contention on the fleet box:
# 957 + 141 = 1098 s worst-known-case, leaving ~100 s of headroom under the 1200 s budget. A full
# run (no --fast) additionally pays the build stage (13-142 s), which is why the cold TOTAL above
# runs higher than --fast's own budget; --fast is not required to fit a build it does not do.
#
# COMPONENT STAGE AND THE DESKTOP MUTEX. Stage 4 is not headless: upstream/oolite/tests/component
# /conftest.py's session-scoped `desktop_lock` fixture takes tools/gui-lock (owner "component")
# for the whole stage, exactly like the GUI tier does, because every scenario opens a real window
# on the real desktop (MSYS2's Mesa ships no EGL, so SDL_VIDEODRIVER=offscreen is not an option
# here). A concurrent sibling agent's own component or GUI-tier run can therefore make this stage
# queue for the lock or starve on CPU/IO while holding it, which can turn a real 769-957 s launch
# suite into something that blows even the 1200 s budget or times component-internal waits out --
# this is contention, not a code regression. If --fast's component stage fails with a message
# naming tools/gui-lock (e.g. "gui-lock: timed out ... held by :component"), treat it exactly as
# the beads-worker SKILL.md's "GUI acceptance verdicts" convention treats a GUI-tier acceptance
# failure: re-run once with `tools/gui-acceptance-recheck` before counting it as a genuine failure.
#
# STAGE 0's NUMBER IS MEASURED IN THIS REPO, NOT IN A TOY ONE. It is quoted as a RANGE because
# three timed runs of `bash tools/guardrails.sh` in this worktree gave 9.42 s, 10.04 s and
# 15.54 s wall (user ~2.5 s, sys ~6-8 s) -- the spread is sibling-agent load on the fleet box,
# and the sys-heavy profile says the cost is process creation under MSYS2, not computation.
# An earlier draft of this header claimed "~2-5 s" from a timing taken in the mutant proof's
# 5-file scratch repo; measured here on 1,999 tracked files the same script took 86.5 s, 113.3 s
# and 97.2 s. The gap was NOT the scan: guardrails.sh classified every tracked file with
# "$(basename -- "$1")", one fork per file, and on Windows a fork costs ~45 ms. Replacing it with
# the pure-bash "${1##*/}" (tools/guardrails.sh, is_test_path/is_collectable_test) selects the
# IDENTICAL 271 test files and takes the classifier loop from 126 s to 1 s. Nothing was scoped
# down or exempted to reach the number, so the guard still scans the bead's whole diff.
#
# WHY THESE AND NOT MORE. The full Tier 1 corpus is 36 groups at ~17 s each = 11-13 min on its
# own, which alone blows the budget; it belongs to Tier C. Only the first N groups run here. The
# GUI tier is excluded outright: it needs the interactive desktop and the exclusive gui-lock, and
# a per-commit gate that serialises behind a desktop mutex cannot run while another agent works.
#
# ------------------------------------------------------------------------------------------------
# THE TWO FAILURE MODES THIS FILE IS SHAPED AROUND
# ------------------------------------------------------------------------------------------------
#
# (a) VACUITY -- a gate that passes because nothing ran. Every one of these reports success:
#     a build that was skipped because the tree was already built; a pytest run that collected 0
#     tests; a golden stage that found no scenarios; a game launch that died in display init and
#     wrote a log with no ERROR lines in it (bead oo-het). So each stage asserts a POSITIVE fact:
#
#       build      the binary is NEWER than every source file under src/ (a skipped build that
#                  left a stale binary fails here), the compile database has >= MIN_TUS entries,
#                  and tests/golden/check_build_flags.py confirms the EFFECTIVE -O and
#                  -ffp-contract=off. "It exited 0" is not evidence.
#       tests      a COUNT, parsed out of pytest's summary and compared against a committed
#                  floor per suite. "0 passed" and "no tests ran" both fail.
#       goldens    the number of blessed scenarios found is compared against GOLDEN_FLOOR, each
#                  produces a dump that golden_diff.py rates rc=0, and the launch/dock scenario
#                  additionally passes check_launch_dock_evidence.py -- which reads ENGINE-
#                  dispatched shipWillLaunchFromStation / shipDockedWithStation counters, so a
#                  run that never undocked cannot satisfy it.
#       smoke      a PNG of plausible size AND [startup.complete] in the run's own Latest.log.
#       corpus     a PASS count equal to the number of groups requested.
#
# (b) FLAKINESS UNDER CONTENTION. Game launches are the flakiest thing on this box and four
#     agents share it. Isolation is designed in, not hoped for:
#
#       * PRIVATE CONSOLE PORTS. The game DIALS OUT and reads console-port from debugConfig.plist
#         (OODebugSupport.m:67-80, default kOOTCPConsolePort=8563), so a --port flag that only
#         changes what we LISTEN on is guaranteed to time out (bead oo-gla). Every stage that
#         launches gets a port this script has bound-and-released, and the one runner that does
#         not write its own plist (dump/run_dump.py) is handed a private OO_ADDITIONALADDONSDIRS
#         holding a Config/debugConfig.plist that names that port. Without this, a leftover game
#         of a sibling's can be accepted on 8563 and satisfy our gate in seconds (oo-gla again).
#       * PRIVATE RUN ROOT under $TMPDIR, never in the repo: scratch in the shared checkout
#         blocks acceptance for the whole fleet (bead oo-4vdc).
#       * PRIVATE ADDONS/PREFS ROOTS come free from golden_run.py and launch_snapshot.py, which
#         stage a whole oolite.app per run (src/SDL/main.m:119 overwrites GNUSTEP_USERS_ROOT, so
#         an env var cannot isolate preferences).
#
# ------------------------------------------------------------------------------------------------
# --fast
# ------------------------------------------------------------------------------------------------
#
# accept.sh replays a bead's acceptance block in a FRESH DETACHED CHECKOUT that contains no build
# and in which nobody should build (it costs minutes and duplicates a multi-GB tree; bead oo-ae9).
# --fast therefore SKIPS STAGE 1 and points the rest at the shared build. It is loud about it: the
# skip is printed as SKIPPED with the reason and the app dir, never as a pass, and the app dir is
# still asserted to hold a real binary. --fast is never the default, because a gate that does not
# build is not a gate on the code.
#
# ------------------------------------------------------------------------------------------------
# PATHS
# ------------------------------------------------------------------------------------------------
#
# MSYS path conversion is DISABLED on this host, so a native binary (python.exe, oolite.exe, git)
# reads "/c/Users/x" as a path relative to the current drive and silently resolves it somewhere
# else. Every path handed to a native tool below goes through `cygpath -m` first; /c/... forms are
# used only by bash builtins.

set -u -o pipefail

# --- Re-exec into the UCRT64 shell --------------------------------------------------------------
#
# Same reason as tools/build-windows.sh and tools/tier-a.sh: this runs as a bead's acceptance
# command and accept.sh runs those with a plain `bash -c`. Without a login UCRT64 shell the build
# dies inside get_version.sh with two EMPTY diagnostic values (bead oo-djn) and oolite.exe dies
# with 0xC0000135 after ~116 s because /ucrt64/bin is not on PATH (bead oo-gla).
MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ ! -x "$MSYS2_BASH" ] && command -v cygpath >/dev/null 2>&1; then
  _root="$(cygpath -m / 2>/dev/null || true)"
  [ -n "$_root" ] && [ -x "$_root/usr/bin/bash.exe" ] && MSYS2_BASH="$_root/usr/bin/bash.exe"
fi
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_TIER_B_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64"
  export OOLITE_TIER_B_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

# THE 0xC0000135 TRAP, again (tools/corpus.sh:44 carries the same fix). oolite.exe's staged
# opengl32.dll pulls libgallium_wgl.dll, which needs libLLVM / libSPIRV-Tools / libsystre from
# /ucrt64/bin and appears in NO import table. A shell without it gets exit 3221225781 before the
# entry point, writes no log, and burns ~116 s in the launcher's retry loop first.
if [ -d /ucrt64/bin ]; then export PATH="/ucrt64/bin:$PATH"; fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
PLATFORM="${OOLITE_TIER_B_PLATFORM:-windows-x64}"
BUILD_FLAVOUR="${OOLITE_TIER_B_FLAVOUR:-test}"
BUDGET_SECONDS="${OOLITE_TIER_B_BUDGET:-1200}"
CORPUS_GROUPS="${OOLITE_TIER_B_CORPUS_GROUPS:-3}"

native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
REPO_NATIVE="$(native "$REPO_ROOT")"

# --- Floors ------------------------------------------------------------------------------------
#
# These are the ANTI-VACUITY constants. Each is the count observed on this tree today; a stage
# that collects fewer FAILS, so deleting a test or a scenario turns the gate red instead of making
# it cheaper. They are floors, not equalities: adding tests must not require editing this file.
# See the deliberate exclusion note beside TESTS_DESELECT.
GOLDEN_FLOOR="${OOLITE_TIER_B_GOLDEN_FLOOR:-2}"
MIN_TUS=100

# A knob that can only make the gate STRICTER. Added to every per-suite floor below, clamped at
# zero, so no value of it can let a suite shrink -- which is what makes it safe to expose. It
# exists so the falsifiability of stage 2 can be demonstrated in seconds (raise the floor above
# the real count and watch the stage go red naming the suite and both numbers) without deleting a
# test to do it. CLAUDE.md rule 2 forbids deleting tests; a gate whose only red proof requires
# breaking that rule is a gate nobody ever proves.
TEST_FLOOR_BUMP="${OOLITE_TIER_B_TEST_FLOOR_BUMP:-0}"
case "$TEST_FLOOR_BUMP" in ''|*[!0-9]*) TEST_FLOOR_BUMP=0 ;; esac

# suite<TAB>floor -- the offline module tests. tests/golden is run with -m "not online": the
# online marker launches a real game and is what stage 3 is for.
TEST_SUITES="tests/golden	69	-m|not online
tools	86	
tests/fleet	23	"

# ONE deliberately deselected test, named, with its reason. It is NOT a test this gate may not
# survive: it asserts that the committed docs/fleet/REPORT-<date>.md still agrees with the LIVE
# beads database, so it goes red whenever anyone files or closes a bead -- i.e. it fails for
# reasons that have nothing to do with the commit under test, which is precisely the property
# that gets a per-commit gate switched off. It runs in Tier C, where a data-staleness failure is
# actionable. Recorded here rather than silently dropped, and the suite's floor (23) is the count
# with this one already excluded, so nothing else can vanish unnoticed behind it.
TESTS_DESELECT="tests/fleet/test_fleet_reporter.py::test_the_committed_report_exists_and_passes_its_own_check"

# --- Output ------------------------------------------------------------------------------------

STARTED_AT=$SECONDS
STAGE_NAME=""
FAILED_STAGE=""
step()   { printf '\n==> [%s] %s\n' "$1" "$2"; }
detail() { printf '    %s\n' "$*"; }
die()    { printf 'tier-b: %s\n' "$*" >&2; exit 2; }

# fail <stage> <reason> -- the ONE way a stage goes red. Names the stage and the reason on the
# last line, so a CI log tail says what broke without scrolling.
fail() {
  FAILED_STAGE="$1"
  printf '\ntier-b: FAIL (stage %s): %s\n' "$1" "$2" >&2
  printf 'tier-b: RED after %ss\n' "$(( SECONDS - STARTED_AT ))" >&2
  exit 1
}

# --- Arguments ---------------------------------------------------------------------------------

FAST=0
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fast)  FAST=1 ;;
    --list)  LIST=1 ;;
    --corpus-groups) CORPUS_GROUPS="${2:?--corpus-groups needs a number}"; shift ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

if [ "$LIST" = 1 ]; then
  sed -n '/^#   0 guardrails/,/^#   TOTAL/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,3\}//'
  exit 0
fi

# --- Preconditions ------------------------------------------------------------------------------

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || die "no python on PATH (did the UCRT64 re-exec happen? MSYSTEM=${MSYSTEM:-unset})"
command -v cygpath >/dev/null 2>&1 || die "no cygpath on PATH; this is not an MSYS2 shell"

APP_DIR="${OO_APP_DIR:-$OOLITE/build/meson_$BUILD_FLAVOUR/oolite.app}"
BUILD_DIR="$OOLITE/build/meson_$BUILD_FLAVOUR"

# Private run root, OUTSIDE the repository. Scratch inside the shared checkout blocks acceptance
# for every other bead (bead oo-4vdc), and worktrees are source-only.
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tier-b-$$-XXXXXX")" || die "cannot create a run root"
RUN_ROOT_NATIVE="$(native "$RUN_ROOT")"
cleanup() {
  # KEEP THE EVIDENCE ON RED. A per-commit gate that deletes the log of its own failure is a gate
  # nobody can debug and therefore nobody trusts: the first thing a contributor does after
  # "tier-b: FAIL ... full log <path>" is open that path. So the run root survives a failure and
  # is announced; it is removed only on a clean GREEN, where nothing in it is worth keeping.
  if [ -n "${OOLITE_TIER_B_KEEP:-}" ] || [ -n "$FAILED_STAGE" ]; then
    [ -n "$FAILED_STAGE" ] && printf 'tier-b: logs kept at %s\n' "$RUN_ROOT_NATIVE" >&2
    return 0
  fi
  rm -rf "$RUN_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

# free_port -- a port nothing is listening on, found by BINDING it and letting go. Not a fixed
# constant: on a shared box a constant is how a sibling's leftover game gets accepted as ours.
free_port() {
  "$PY" -c "
import socket
s = socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
"
}

printf '==> tier-b (%s, flavour %s, budget %ss%s)\n' \
  "$PLATFORM" "$BUILD_FLAVOUR" "$BUDGET_SECONDS" "$([ "$FAST" = 1 ] && echo ', --fast')"
detail "repo      $REPO_NATIVE"
detail "run root  $RUN_ROOT_NATIVE"

# ================================================================================================
# STAGE 0 -- GUARDRAILS (CLAUDE.md rules 1, 2, 3, 8)
# ================================================================================================
#
# Phase 0's exit gate (docs/phases/0-safety-net.md boxes 38 and 39) says a reintroduced
# JS_*/libgnustep-base symbol and a bead branch touching goldens/ without an approved re-bless
# must FAIL TIER B. Until this stage existed they did not: the deny-list ran in tier-a, and
# tools/guardrails.sh ran only where a bead's own acceptance block happened to name it -- i.e.
# exactly the beads least likely to violate it. A rule enforced only where someone remembered to
# ask is not enforced.
#
# FIRST, AND DELIBERATELY SO. It is offline, needs no build, no game and no port, and costs
# 9-16 s measured in this repo (three runs: 9.42 s, 10.04 s, 15.54 s -- see the cost table at the
# top of this file), so a red guard costs seconds rather than minutes: a change that reintroduces
# JS_* fails here instead of after a 142 s cold build and a 43 s golden stage. That is a ~10-20x
# saving on the failing path, not a free one, and it is worth stating plainly because the first
# draft of this stage claimed "2-5 s" from a timing taken in a 5-file scratch repo while the real
# figure in this 1,999-file tree was ~100 s. The honest number only became 9-16 s after the fork
# per tracked file in guardrails.sh's test classifier was removed; had it stayed at ~100 s this
# ordering would still be right (100 s before a 185 s build beats 285 s), but "costs nothing"
# would have been false. Nothing later in this file depends on this stage, so the ordering is
# purely about how cheaply the answer arrives.
#
# rc CONVENTION (the repo's, bead oo-jor): 0 = checked and clean, 1 = a real violation,
# 2 = REFUSED (no base ref resolves, no scratch dir). 2 IS NOT A PASS and is reported as its own
# reason, because a guard that could not run is indistinguishable from one that found nothing
# unless the two are told apart here.
#
# ANTI-VACUITY. guardrails.sh carries its own canaries (its suppression matcher must match 4
# built-in canary lines; the deny-list must score > 0 on known-bad text; the test classifier must
# match >= 1 tracked file) and turns each into a FAILURE rather than a skip. But a guard that
# silently became a no-op would also exit 0 with no output at all, so this stage additionally
# requires the two EVIDENCE lines that only a check which actually scanned the tree can print --
# "deny-list: <n> patterns, canary scores <n>" and "tests: classifier matches <n> tracked test
# files". An exit 0 without them is treated as red.
stage_guardrails() {
  local t0=$SECONDS log="$RUN_ROOT/guardrails.log" rc=0
  step guardrails "tools/guardrails.sh (goldens, suppression, tests, deny-list)"
  [ -f "$HERE/guardrails.sh" ] \
    || fail guardrails "tools/guardrails.sh is missing; the rule-1/2/3/8 guard cannot run"
  ( cd "$REPO_ROOT" && bash "$HERE/guardrails.sh" ) > "$log" 2>&1 || rc=$?
  case "$rc" in
    0) : ;;
    1) cat "$log" >&2
       fail guardrails "tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is the deny-list and goldens/ guard, not a style check" ;;
    *) cat "$log" >&2
       fail guardrails "tools/guardrails.sh could not run (rc=$rc = refused, e.g. no base ref); a refusal is not a pass" ;;
  esac
  grep -q 'deny-list: .* patterns, canary scores' "$log" \
    || { cat "$log" >&2; fail guardrails "guardrails.sh exited 0 but printed no deny-list evidence line; the deny-list check did not run and the gate would pass vacuously"; }
  grep -q 'tests: classifier matches' "$log" \
    || { cat "$log" >&2; fail guardrails "guardrails.sh exited 0 but printed no test-classifier evidence line; the rule-2 check did not run and the gate would pass vacuously"; }
  detail "$(grep -m1 '^guardrails: base ' "$log" || echo 'guardrails: base (unreported)')"
  detail "$(grep -m1 'deny-list: .* patterns' "$log")"
  detail "$(grep -m1 'tests: classifier matches' "$log")"
  detail "stage guardrails ok in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE 1 -- BUILD
# ================================================================================================

stage_build() {
  local t0=$SECONDS log="$RUN_ROOT/build.log"

  if [ "$FAST" = 1 ]; then
    step build "SKIPPED (--fast): accept.sh replays this in a checkout with no build (bead oo-ae9)"
    detail "using the shared build at $(native "$APP_DIR")"
    # A skip is not a pass: the thing the skipped stage would have produced is still asserted.
    [ -f "$APP_DIR/oolite.exe" ] \
      || fail build "--fast was given but there is no oolite.exe at $(native "$APP_DIR"); point OO_APP_DIR at a built tree"
    detail "binary    $(stat -c %s "$APP_DIR/oolite.exe") bytes, mtime $(stat -c %y "$APP_DIR/oolite.exe")"
    # The shared build's app dir is no likelier to hold Mesa than a fresh one; stage it here too,
    # or --fast reproduces exactly the order-dependent stage-2 failure described at stage_mesa.
    stage_mesa
    return 0
  fi

  step build "tools/build-windows.sh $BUILD_FLAVOUR"
  bash "$HERE/build-windows.sh" "$BUILD_FLAVOUR" > "$log" 2>&1 \
    || { tail -30 "$log" >&2; fail build "the build failed; last 30 lines above, full log $(native "$log")"; }

  local binary="$BUILD_DIR/oolite.app/oolite.exe"
  [ -f "$binary" ] || fail build "the build reported success but $(native "$binary") is missing"

  # POSITIVE EVIDENCE 1: a compiler was invoked, or there was provably nothing to invoke it on.
  # build-windows.sh prints its own ccache delta; its absence means the build did not get as far
  # as compiling and something else exited 0.
  local ccline
  ccline="$(grep -m1 'ccache this run' "$log" || true)"
  [ -n "$ccline" ] \
    || fail build "the build log has no 'ccache this run' line, so no compile phase ran; $(native "$log")"
  detail "${ccline#*==> }"

  # POSITIVE EVIDENCE 2: the binary is NEWER than every source file. This is the check that
  # catches the skipped build -- a stale binary left by an earlier run exits 0 from ninja and
  # looks exactly like a successful incremental build.
  local newer
  newer="$(find "$OOLITE/src" -type f \( -name '*.m' -o -name '*.c' -o -name '*.cpp' -o -name '*.h' \) \
             -newer "$binary" -print -quit 2>/dev/null || true)"
  [ -z "$newer" ] \
    || fail build "source file '${newer#"$REPO_ROOT"/}' is NEWER than the binary; the build did not rebuild it"
  detail "binary    $(stat -c %s "$binary") bytes, newer than every file under src/"

  # POSITIVE EVIDENCE 3: the compile database is real and the golden float policy is in force.
  # check_build_flags.py refuses a database with fewer than 100 TUs, because "0 of 0 TUs violate
  # the policy" is the vacuous form of this assertion (bead oo-ss8).
  [ -f "$BUILD_DIR/compile_commands.json" ] \
    || fail build "no compile_commands.json in $(native "$BUILD_DIR"); the configure did not complete"
  "$PY" "$(native "$REPO_ROOT/tests/golden/check_build_flags.py")" \
        --build-dir "$(native "$BUILD_DIR")" > "$RUN_ROOT/flags.log" 2>&1 \
    || { sed -n '1,20p' "$RUN_ROOT/flags.log" >&2
         fail build "check_build_flags.py rejected the build database (effective -O / -ffp-contract)"; }
  detail "$(head -1 "$RUN_ROOT/flags.log")"

  APP_DIR="$BUILD_DIR/oolite.app"
  stage_mesa
  detail "stage build ok in $(( SECONDS - t0 ))s"
}

# stage_mesa -- put MSYS2's Mesa llvmpipe beside the binary, as tests/golden/run.sh:130-139 and
# upstream/oolite/tests/run_test_fn.sh:28-33 do.
#
# THIS IS NOT COSMETIC AND IT IS NOT ONLY ABOUT RENDERING. A freshly built oolite.app does not
# contain opengl32.dll / libgallium_wgl.dll: nothing in the build produces them, and the only
# things that ever put them there are the golden and component runners, as a side effect of
# launching. That makes the app dir's contents depend on WHAT RAN BEFORE, which is exactly the
# order-dependence a per-commit gate must not have. It bit this gate on its first full run:
#
#   stage 2 in a worktree whose app dir had never been launched from
#     -> tests/golden/dump/test_launch_preflight.py 3 failed, 66 passed
#   the same tests, same tree, same box, standalone after any launch
#     -> 7 passed
#
# MEASURED MECHANISM (not inferred): those tests assert that stripping the UCRT64 runtime dir from
# PATH makes the gallium dependencies unresolvable. With Mesa staged, state_dump.unresolved_imports
# reports {'libsystre-0.dll', 'libLLVM-22.dll', 'libSPIRV-Tools.dll'} -> each imported by
# libgallium_wgl.dll. WITHOUT Mesa staged it reports {} -- there is no libgallium_wgl.dll to walk,
# so nothing is missing, the negative control cannot fire and all three tests fail. The failure is
# a MISSING FIXTURE in the environment the gate constructed, not a defect in the tests and not
# something to deselect (CLAUDE.md rule 2). Staging here makes stage 2's input identical to a
# developer's shell, and stage_environment_parity below pins that equality so it cannot regress.
stage_mesa() {
  [ -d "$APP_DIR" ] || return 0
  local prefix="${MINGW_PREFIX:-/ucrt64}" dll staged=0
  for dll in opengl32.dll libgallium_wgl.dll; do
    if [ -f "$prefix/bin/$dll" ]; then
      # Concurrency-safe: parallel copies of an identical file to one target succeed, including
      # while a sibling has it mapped. A failure here is not fatal (an existing copy is fine) but
      # it is never silent.
      cp -f "$prefix/bin/$dll" "$APP_DIR/" 2>/dev/null && staged=$(( staged + 1 )) \
        || printf 'tier-b: could not refresh %s (in use?); keeping the existing copy\n' "$dll" >&2
    fi
  done
  [ -f "$APP_DIR/libgallium_wgl.dll" ] \
    || fail build "no libgallium_wgl.dll in $(native "$APP_DIR") and none at $prefix/bin; the preflight tests in stage 2 need it staged and would fail for a reason unrelated to the commit"
  detail "mesa      $staged DLL(s) staged from $prefix/bin (llvmpipe beside the binary)"
}

# ================================================================================================
# STAGE 2 -- MODULE TESTS
# ================================================================================================
#
# A pytest run that collects nothing exits 5, but a run that collects a SHRINKING number exits 0.
# So the count is parsed and compared against a floor, and the floor is a committed constant.

stage_tests() {
  local t0=$SECONDS total=0 suite floor extra log passed
  step tests "offline module tests (3 suites, floors enforced)"
  while IFS="	" read -r suite floor extra; do
    [ -n "$suite" ] || continue
    floor=$(( floor + TEST_FLOOR_BUMP ))
    log="$RUN_ROOT/pytest-$(echo "$suite" | tr '/' '_').log"
    local args=()
    [ -n "$extra" ] && IFS='|' read -r -a args <<< "$extra"
    [ "$suite" = "tests/fleet" ] && args+=(--deselect "$TESTS_DESELECT")
    ( cd "$REPO_ROOT" && "$PY" -m pytest "$suite" -q -p no:cacheprovider "${args[@]+"${args[@]}"}" ) \
      > "$log" 2>&1
    local rc=$?
    passed="$(grep -oE '[0-9]+ passed' "$log" | tail -1 | grep -oE '[0-9]+' || true)"
    passed="${passed:-0}"
    if [ "$rc" -ne 0 ]; then
      tail -25 "$log" >&2
      fail tests "$suite failed (pytest rc=$rc, $passed passed); full log $(native "$log")"
    fi
    if [ "$passed" -lt "$floor" ]; then
      fail tests "$suite collected only $passed passing test(s), fewer than the committed floor of $floor -- a test was deleted, renamed or silently skipped"
    fi
    detail "$(printf '%-14s %3d passed (floor %s)' "$suite" "$passed" "$floor")"
    total=$(( total + passed ))
  done <<< "$TEST_SUITES"
  [ "$total" -gt 0 ] || fail tests "0 tests ran in total; the gate would pass vacuously"
  detail "stage tests ok: $total tests in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE 2b -- ENVIRONMENT PARITY
# ================================================================================================
#
# Nobody asked for this stage; the gate's first full run earned it.
#
# Tier B constructs an environment (a UCRT64 re-exec, an exported PATH, an OO_APP_DIR, a staged
# app dir) and then runs other people's tests inside it. If that environment differs from a
# developer's shell in any way that changes a VERDICT, the gate fails on things the commit did not
# break -- the single fastest way to destroy trust in a per-commit gate, and it happened here:
# stage 2 reported "3 failed, 66 passed" for a file that passes 7/7 standalone, because the
# constructed environment was missing a fixture (see stage_mesa).
#
# So the equality is now ASSERTED rather than assumed. The suite most sensitive to the environment
# is re-run in a DELIBERATELY BARE shell -- env -i, no inherited PATH beyond the UCRT64 minimum,
# nothing this script exported -- and the two verdicts must agree. This is a different check from
# "do the tests pass": both runs failing identically would also pass parity, correctly, because
# that is a real defect rather than an artefact of the gate.
#
# Cost: ~3 s (one small offline suite), which is why it is affordable on every commit.
stage_environment_parity() {
  local t0=$SECONDS
  local target="tests/golden/dump/test_launch_preflight.py"
  step parity "$target: tier-b's environment must produce a developer shell's verdict"
  [ -f "$REPO_ROOT/$target" ] \
    || fail parity "$target does not exist; the parity probe is pinned to a file that has moved or been deleted -- repoint it rather than dropping the check"

  # A: inside tier-b's environment, exactly as stage 2 runs things.
  local a_rc=0
  ( cd "$REPO_ROOT" && "$PY" -m pytest "$target" -q -p no:cacheprovider ) \
    > "$RUN_ROOT/parity-inside.log" 2>&1 || a_rc=$?
  local a_pass a_fail
  a_pass="$(grep -oE '[0-9]+ passed' "$RUN_ROOT/parity-inside.log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  a_fail="$(grep -oE '[0-9]+ failed' "$RUN_ROOT/parity-inside.log" | tail -1 | grep -oE '[0-9]+' || echo 0)"

  # B: a bare shell. env -i drops everything the CALLING shell happened to export -- an inherited
  # OO_APP_DIR, CCACHE_*, OOLITE_VER_FULL, a rich PATH, the re-exec marker -- and restores only
  # what any shell on this box has. OO_APP_DIR is passed through DELIBERATELY and explicitly,
  # because it is a documented input to the tests (they default to REPO_ROOT's build and honour
  # the override), so the two arms must agree on WHICH BUILD they are judging or the comparison
  # measures the app-dir choice instead of the environment. Everything else is dropped.
  #
  # This distinction is not theoretical: while writing this stage, an OO_APP_DIR left exported in
  # the calling shell made the inside arm read the main checkout's app dir (Mesa staged, 7 passed)
  # and the bare arm read the worktree's (Mesa absent, 3 failed). The stage correctly went red and
  # named both counts -- which is the whole point, but the fix belongs here, not in the tests.
  local b_rc=0
  ( cd "$REPO_ROOT" && env -i \
      PATH="/ucrt64/bin:/usr/bin:/bin" \
      HOME="${HOME:-/home/$USER}" \
      SYSTEMROOT="${SYSTEMROOT:-C:\\Windows}" \
      OO_APP_DIR="$(native "$APP_DIR")" \
      "$PY" -m pytest "$target" -q -p no:cacheprovider ) \
    > "$RUN_ROOT/parity-bare.log" 2>&1 || b_rc=$?
  local b_pass b_fail
  b_pass="$(grep -oE '[0-9]+ passed' "$RUN_ROOT/parity-bare.log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  b_fail="$(grep -oE '[0-9]+ failed' "$RUN_ROOT/parity-bare.log" | tail -1 | grep -oE '[0-9]+' || echo 0)"

  # Anti-vacuity: two runs that both collected NOTHING agree perfectly and prove nothing.
  [ "$(( a_pass + a_fail ))" -gt 0 ] && [ "$(( b_pass + b_fail ))" -gt 0 ] \
    || fail parity "a parity arm collected no tests (inside ${a_pass}p/${a_fail}f, bare ${b_pass}p/${b_fail}f); two empty runs agree vacuously"

  if [ "$a_pass" != "$b_pass" ] || [ "$a_fail" != "$b_fail" ]; then
    printf '\n--- inside tier-b ---\n' >&2; tail -12 "$RUN_ROOT/parity-inside.log" >&2
    printf '\n--- bare shell ---\n' >&2;   tail -12 "$RUN_ROOT/parity-bare.log" >&2
    fail parity "tier-b's environment changes the verdict: inside ${a_pass} passed/${a_fail} failed, bare shell ${b_pass} passed/${b_fail} failed. The gate would fail (or pass) for reasons unrelated to the commit. Fix the environment; do NOT deselect the tests."
  fi
  detail "inside and bare shell agree: ${a_pass} passed, ${a_fail} failed ($(( SECONDS - t0 ))s)"
}

# ================================================================================================
# STAGE 3 -- GOLDEN SCENARIOS
# ================================================================================================
#
# The scenarios are DISCOVERED from goldens/<platform>/, not listed here, so a golden blessed
# tomorrow is gated tomorrow with no edit to this file -- and the count is compared against
# GOLDEN_FLOOR, so a scenario that DISAPPEARS (or a wrong --platform) turns the gate red instead
# of making it free. The bead asks for 3-5; the tree has 2 blessed today and the floor rises with
# them. Each scenario's runner writes to the private run root; nothing under goldens/ is touched.

stage_goldens() {
  local t0=$SECONDS dir name n=0 ok=0
  step goldens "every blessed scenario under goldens/$PLATFORM (floor $GOLDEN_FLOOR)"
  local gdir="$REPO_ROOT/goldens/$PLATFORM"
  [ -d "$gdir" ] || fail goldens "no goldens directory at $(native "$gdir")"

  local names=()
  for dir in "$gdir"/*/; do
    [ -f "$dir/state.json" ] || continue
    names+=("$(basename "$dir")")
  done
  n=${#names[@]}
  [ "$n" -ge "$GOLDEN_FLOOR" ] \
    || fail goldens "found $n blessed scenario(s) under $(native "$gdir"), fewer than the floor of $GOLDEN_FLOOR -- a golden stage with nothing to compare passes vacuously"

  for name in "${names[@]}"; do
    local out="$RUN_ROOT/$name.json" log="$RUN_ROOT/$name.log" port
    port="$(free_port)"
    local s=$SECONDS rc=0
    case "$name" in
      001-launch-dock)
        # golden_run.py reserves its own port, stages a private app dir and writes its own
        # debugConfig.plist, so this one only needs a private run root.
        ( cd "$REPO_ROOT" && "$PY" "$(native "$REPO_ROOT/tests/golden/launch_dock.py")" \
            --app-dir "$(native "$APP_DIR")" --out "$(native "$out")" \
            --run-root "$RUN_ROOT_NATIVE/ld-$name" ) > "$log" 2>&1 || rc=$?
        ;;
      *)
        # dump/run_dump.py takes a --port but does NOT write the plist that makes it real, so the
        # game would dial the default 8563 and be answered by whatever sibling is listening there
        # (bead oo-gla). Write the plist into a private OO_ADDITIONALADDONSDIRS ourselves.
        local cfg="$RUN_ROOT/cfg-$name/Config"
        mkdir -p "$cfg"
        "$PY" -c "
import plistlib, sys
plistlib.dump({'console-host': '127.0.0.1', 'console-port': int(sys.argv[2])},
              open(sys.argv[1], 'wb'), fmt=plistlib.FMT_XML)
" "$(native "$cfg/debugConfig.plist")" "$port" \
          || fail goldens "could not write the private debugConfig.plist for $name"
        ( cd "$REPO_ROOT" \
          && OO_ADDITIONALADDONSDIRS="$(native "$RUN_ROOT/cfg-$name")" \
             "$PY" "$(native "$REPO_ROOT/tests/golden/dump/run_dump.py")" \
               --app-dir "$(native "$APP_DIR")" --port "$port" \
               --out "$(native "$out")" --output-dir "$(native "$RUN_ROOT/out-$name")" ) > "$log" 2>&1 || rc=$?
        ;;
    esac
    local wall=$(( SECONDS - s ))
    [ "$rc" -eq 0 ] || { tail -20 "$log" >&2
      fail goldens "scenario $name did not produce a dump (rc=$rc after ${wall}s); $(native "$log")"; }
    [ -s "$out" ] || fail goldens "scenario $name exited 0 but wrote no dump at $(native "$out")"

    # golden_diff.py's rc convention (bead oo-jor): 0 = verified equal, 1 = a real difference,
    # 2 = REFUSED (unreadable, empty, self-comparison, off-policy quantisation). 2 is never a pass.
    local drc=0
    "$PY" "$(native "$REPO_ROOT/tests/golden/golden_diff.py")" \
      "$(native "$gdir/$name/state.json")" "$(native "$out")" > "$RUN_ROOT/diff-$name.log" 2>&1 || drc=$?
    case "$drc" in
      0) : ;;
      1) sed -n '1,25p' "$RUN_ROOT/diff-$name.log" >&2
         fail goldens "scenario $name DIFFERS from its blessed golden (golden_diff rc=1)" ;;
      *) sed -n '1,25p' "$RUN_ROOT/diff-$name.log" >&2
         fail goldens "scenario $name could not be compared (golden_diff rc=$drc = refused); a refusal is not a pass" ;;
    esac

    # The launch/dock scenario carries ENGINE-dispatched evidence counters in the dump. Check them
    # explicitly: a run that never undocked reproduces a stale dump perfectly and proves nothing.
    if [ -f "$REPO_ROOT/tests/golden/check_launch_dock_evidence.py" ] && [ "$name" = "001-launch-dock" ]; then
      "$PY" "$(native "$REPO_ROOT/tests/golden/check_launch_dock_evidence.py")" "$(native "$out")" \
        > "$RUN_ROOT/ev-$name.log" 2>&1 \
        || { cat "$RUN_ROOT/ev-$name.log" >&2
             fail goldens "scenario $name matched its golden but failed its own launch/dock evidence check"; }
      detail "$(head -1 "$RUN_ROOT/ev-$name.log" | sed 's|.*/||')"
    fi
    detail "$(printf '%-18s MATCH  %3ds  port %s' "$name" "$wall" "$port")"
    ok=$(( ok + 1 ))
  done
  [ "$ok" -eq "$n" ] || fail goldens "$ok of $n scenarios verified"
  detail "stage goldens ok: $ok scenario(s) in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE 4 -- COMPONENT TIER (ADR-0018)
# ================================================================================================

stage_component() {
  local t0=$SECONDS log="$RUN_ROOT/component.log"
  step component "upstream/oolite/tests/component"
  local rc=0
  ( cd "$OOLITE/tests/component" \
    && OO_APP_DIR="$(native "$APP_DIR")" \
       "$PY" -m pytest . -q -p no:cacheprovider ) > "$log" 2>&1 || rc=$?
  local passed
  passed="$(grep -oE '[0-9]+ passed' "$log" | tail -1 | grep -oE '[0-9]+' || true)"
  passed="${passed:-0}"
  [ "$rc" -eq 0 ] || { tail -25 "$log" >&2
    fail component "the component tier failed (pytest rc=$rc, $passed passed); $(native "$log")"; }
  [ "$passed" -ge 1 ] \
    || fail component "the component tier collected $passed tests; a scenario tier that launches no game passes vacuously"
  detail "$passed scenario(s) passed in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE 5 -- SMOKE
# ================================================================================================
#
# One real launch of the shipped binary, end to end, with a screenshot. The point is not the
# picture: it is that the game got far enough to draw one. A dead launch writes a ~1.5 KB log
# containing the version banner, the CPU line and [process.args] and NO ERROR lines (bead oo-het),
# so absence-of-error is worthless here and [startup.complete] -- a marker from AFTER expansion
# parsing -- is the precondition that discriminates.

stage_smoke() {
  local t0=$SECONDS log="$RUN_ROOT/smoke.log" out="$RUN_ROOT/smoke" port
  port="$(free_port)"
  step smoke "launch_snapshot.py on port $port"
  mkdir -p "$out"
  local rc=0
  ( cd "$OOLITE" && "$PY" "$(native "$OOLITE/tests/launch_snapshot.py")" \
      --path "$(native "$APP_DIR")" --output "$(native "$out")" --port "$port" ) > "$log" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { tail -25 "$log" >&2; fail smoke "the smoke launch failed (rc=$rc); $(native "$log")"; }

  local png size
  png="$(ls "$out"/*.png 2>/dev/null | head -1 || true)"
  [ -n "$png" ] || fail smoke "the smoke run exited 0 but captured no PNG in $(native "$out")"
  size="$(stat -c %s "$png")"
  [ "$size" -ge 10000 ] \
    || fail smoke "the captured frame is only ${size} bytes; a frame that small is a failed render, not a game"

  local latest="$out/Latest.log"
  [ -f "$latest" ] || fail smoke "the smoke run wrote no Latest.log in $(native "$out")"
  grep -q '\[startup\.complete\]' "$latest" \
    || fail smoke "Latest.log has no [startup.complete]; the game died before expansions were parsed (a dead launch also has 0 ERROR lines, so absence-of-error proves nothing)"
  detail "$(( size / 1024 )) KB frame, $(wc -l < "$latest") log lines, [startup.complete] present"
  detail "stage smoke ok in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE 6 -- OXP CORPUS, TIER 1 SUBSET
# ================================================================================================
#
# The full Tier 1 list is 36 groups at ~17 s each = 11-13 min, which alone exceeds the budget, so
# only the first N run here and the rest belong to Tier C. The PASS count is compared against N:
# corpus.sh reports "K group(s) checked, F failed", and a run that staged nothing reports 0/0 and
# exits 0 (bead oo-het saw exactly that -- 35 of 36 silently never copied).

stage_corpus() {
  local t0=$SECONDS log="$RUN_ROOT/corpus.log"
  step corpus "tools/corpus.sh tier1 --limit $CORPUS_GROUPS"
  local rc=0
  ( cd "$REPO_ROOT" && OO_APP_DIR="$(native "$APP_DIR")" \
      bash "$HERE/corpus.sh" tier1 --limit "$CORPUS_GROUPS" ) > "$log" 2>&1 || rc=$?
  [ "$rc" -eq 0 ] || { tail -20 "$log" >&2; fail corpus "the Tier 1 subset failed (rc=$rc); $(native "$log")"; }
  local checked passes
  checked="$(grep -oE '[0-9]+ group\(s\) checked' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  passes="$(grep -c '^PASS ' "$log" || true)"
  [ "$checked" -eq "$CORPUS_GROUPS" ] \
    || fail corpus "asked for $CORPUS_GROUPS group(s) but corpus.sh checked $checked; a run that staged nothing reports 0 checked and exits 0"
  [ "$passes" -eq "$CORPUS_GROUPS" ] \
    || fail corpus "$passes of $CORPUS_GROUPS group(s) reported PASS"
  detail "$passes/$checked expansion group(s) loaded in $(( SECONDS - t0 ))s"
}

# ================================================================================================

stage_guardrails
stage_build
stage_tests
stage_environment_parity
stage_goldens
stage_component
stage_smoke
stage_corpus

ELAPSED=$(( SECONDS - STARTED_AT ))
printf '\n'
if [ "$ELAPSED" -gt "$BUDGET_SECONDS" ]; then
  printf 'tier-b: GREEN but OVER BUDGET: %ss > %ss. A per-commit gate this slow gets disabled.\n' \
    "$ELAPSED" "$BUDGET_SECONDS" >&2
  exit 1
fi
printf 'tier-b: GREEN in %ss (budget %ss%s)\n' \
  "$ELAPSED" "$BUDGET_SECONDS" "$([ "$FAST" = 1 ] && echo ', --fast: build SKIPPED')"
