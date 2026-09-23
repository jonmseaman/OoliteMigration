#!/usr/bin/env bash
#
# Tier C -- the MERGE gate. Phase 0 item 0.9c (docs/phases/0-safety-net.md), bead oo-j4u.
# Tiers are defined in docs/execution-model.md §3.1; Tier B (tools/tier-b.sh) is the per-commit
# gate this one composes with rather than duplicates.
#
#     tools/tier-c.sh                    # everything
#     tools/tier-c.sh --list             # print the stages and their measured cost, run nothing
#     tools/tier-c.sh --only a,b,c       # a comma-separated subset of stage names
#     tools/tier-c.sh --skip asan        # run everything except these
#     tools/tier-c.sh --dry-run          # resolve and print the plan, run no stage
#     tools/tier-c.sh --backend=<sm|quickjs>  # point the goldens/corpus/gui stages at the named
#                                        # backend's pre-built app dir (bead oo-2t6) instead of
#                                        # the plain meson_test build. Combine with tools/tier-c-
#                                        # diff.sh, which runs this once per backend and diffs the
#                                        # two backends' golden dumps and corpus verdicts.
#
# ================================================================================================
# WHAT THIS RUNS, AND WHAT IT COSTS.  THE ARITHMETIC CAME FIRST AND SHAPED THE DESIGN.
# ================================================================================================
#
# Measured on the fleet box (i9-12900KS, 24 threads, 64 GiB), 2026-09-18, siblings active:
#
#   0 tier-b       ~165 s warm / ~295 s cold   the whole per-commit gate, unchanged, as stage 0
#   1 jsapi        ~1 s      source-derived JS API snapshot, byte-compared against the tree
#   2 asan         ~90 s build + ~45 s launch  sanitized build + a real launch of it (MEASURED:
#                            the sanitized game reaches [startup.complete] in 38.96-40.07 s
#                            against ~4-14 s unsanitized -- a 3-10x slowdown that is real and
#                            is the reason this stage cannot live in Tier B)
#   3 goldens      ~90-300 s  EVERY blessed + staged + pending scenario, not just the fast ones
#   4 corpus       ~11-13 min full Tier 1: 36 groups (30 catalogue + 6 test-oxps) at 17-22 s
#   5 gui          ~120 s    the PyAutoGUI tier, which takes the desktop EXCLUSIVELY (ADR-0017)
#   6 fleetdata    ~5 s      the ONE test tier-b deliberately deselects, run here where it matters
#
#   PROJECTED TOTAL, honestly summed:
#     tier-b 165-295 + jsapi 1 + asan 135 + goldens 90-300 + corpus 660-790 + gui 120 + fleet 5
#     =  1176 s (19.6 min) best case  ..  1646 s (27.4 min) worst case.
#
# Budget is 2400 s (40 min). That is deliberate: Tier C runs on a MERGE, not on a commit, so the
# thing it must not do is miss a defect, and the thing Tier B must not do is be slow.
#
# ------------------------------------------------------------------------------------------------
# WHY THE STORED ACCEPTANCE BLOCK DOES NOT RUN THIS, AND WHY THAT IS CORRECT
# ------------------------------------------------------------------------------------------------
#
# 17-25 minutes does not fit in an acceptance line, and accept.sh replays every line of every
# bead. The bead is to BUILD this tier, not to run it inside its own gate. So the stored block
# follows the split the rest of the fleet converged on:
#
#   * CHEAP OFFLINE LINES pin the composition (which stages exist, in which order), the stage
#     logic, the floors, and every anti-vacuity guard -- via --dry-run, --list, and
#     tools/tier_c_selftest.py, which runs the REAL predicates against REAL captured fixtures.
#   * ONE LINE REALLY EXERCISES A SLICE: `tools/tier-c.sh --only jsapi` regenerates the JS API
#     snapshot from 243 engine source files and byte-compares it against the committed copy.
#     ~2 s, no build, no launch, and it fails for exactly the reason bead oo-4z6's tier2 check
#     fails ("committed 63990 bytes, fresh 11983").
#
# ------------------------------------------------------------------------------------------------
# ANTI-VACUITY: WHAT EACH STAGE MUST PROVE IT ACTUALLY DID
# ------------------------------------------------------------------------------------------------
#
# A tier that passes because nothing ran is worse than no tier. rc=0 and "no ERROR lines" are
# both satisfiable by a dead run (bead oo-het caught SEVEN silently-rejected expansions that
# way). Every stage below therefore asserts a POSITIVE fact and fails LOUDLY when its subject is
# absent -- never skips, never no-ops:
#
#   tier-b     tier-b's own GREEN line, and its stage names, must appear in the output.
#   jsapi      a REGENERATION of the snapshot from source, byte-compared; plus content floors
#              (>=28 classes, >=440 properties, both access kinds present, Ship.speed READONLY).
#   asan       the toolchain probe must actually catch a deliberate use-after-free; the sanitized
#              binary must IMPORT the ASan runtime DLL and carry __asan symbols; the launch must
#              reach [startup.complete], a marker from AFTER expansion parsing.
#   goldens    a COUNT of scenarios against a floor, each producing a dump golden_diff rates 0.
#   corpus     the number of groups PASSing must equal the number requested; the run must be the
#              FULL list, not a subset, and the count is read from corpus.sh's own report.
#   fleetdata  a pytest count, not an exit code.

set -u -o pipefail

# --- Re-exec into the UCRT64 shell --------------------------------------------------------------
#
# Same reason as tools/tier-b.sh and tools/build-windows.sh: this runs as a bead's acceptance
# command and accept.sh runs those with a plain `bash -c`. Without a login UCRT64 shell the build
# dies inside get_version.sh with two EMPTY diagnostic values (bead oo-djn) and oolite.exe dies
# with 0xC0000135 after ~116 s because /ucrt64/bin is not on PATH (bead oo-gla).
#
# MSYS2_BASH's usual default (/c/msys64/usr/bin/bash.exe) DOES NOT EXIST on this box -- MSYS2 is
# installed under scoop -- so the cygpath fallback below is the branch that actually fires here.
MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ ! -x "$MSYS2_BASH" ] && command -v cygpath >/dev/null 2>&1; then
  _root="$(cygpath -m / 2>/dev/null || true)"
  [ -n "$_root" ] && [ -x "$_root/usr/bin/bash.exe" ] && MSYS2_BASH="$_root/usr/bin/bash.exe"
fi
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_TIER_C_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64"
  export OOLITE_TIER_C_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

# THE 0xC0000135 TRAP. oolite.exe's staged opengl32.dll pulls libgallium_wgl.dll, which needs
# libLLVM / libSPIRV-Tools / libsystre from /ucrt64/bin and appears in NO import table. A shell
# without it gets exit 3221225781 before the entry point, writes no log, and burns ~116 s first.
if [ -d /ucrt64/bin ]; then export PATH="/ucrt64/bin:$PATH"; fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
PLATFORM="${OOLITE_TIER_C_PLATFORM:-windows-x64}"
BUDGET_SECONDS="${OOLITE_TIER_C_BUDGET:-2400}"

native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
REPO_NATIVE="$(native "$REPO_ROOT")"

# --- The stage table -----------------------------------------------------------------------------
#
# ONE declaration of the composition, read by --list, --dry-run, --only, --skip and the runner, so
# the plan a gate PRINTS and the plan it RUNS cannot drift apart. tools/tier_c_selftest.py parses
# this same table out of this file and asserts it against the committed expectation, which is what
# makes "someone quietly deleted the asan stage" a red line rather than a faster gate.
STAGES="tier-b\t165\tthe whole per-commit gate (tools/tier-b.sh), unchanged
jsapi\t2\tJS API snapshot regenerated from engine source and byte-compared
asan\t135\tAddressSanitizer build of the engine, plus a real launch of it
goldens\t200\tevery golden scenario: blessed, staged and pending
corpus\t700\tthe FULL Tier 1 corpus (36 groups), not tier-b's 3-group subset
gui\t120\tthe PyAutoGUI tier, serialised on tools/gui-lock (here and nightly only)
fleetdata\t5\tthe fleet-report test tier-b deliberately deselects"

# --- Floors --------------------------------------------------------------------------------------
#
# The ANTI-VACUITY constants. Each is the count observed on this tree today; a stage that finds
# fewer FAILS. Floors, not equalities: adding a scenario must not require editing this file.
GOLDEN_FLOOR="${OOLITE_TIER_C_GOLDEN_FLOOR:-2}"
CORPUS_FLOOR="${OOLITE_TIER_C_CORPUS_FLOOR:-36}"
FLEET_TEST_FLOOR="${OOLITE_TIER_C_FLEET_FLOOR:-1}"
GUI_TEST_FLOOR="${OOLITE_TIER_C_GUI_FLOOR:-1}"
JSAPI_SNAPSHOT="$REPO_ROOT/oxp-contract/js-api-source.json"
ASAN_SUPPRESSIONS="${OOLITE_TIER_C_ASAN_SUPPRESSIONS:-$HERE/asan-suppressions.txt}"

# The ONE test tier-b deselects, with its reason (tools/tier-b.sh:149-156): it asserts the
# committed docs/fleet/REPORT-<date>.md still agrees with the LIVE beads database, so it goes red
# whenever anyone files or closes a bead -- unacceptable per-commit, actionable on a merge.
FLEET_TEST="tests/fleet/test_fleet_reporter.py::test_the_committed_report_exists_and_passes_its_own_check"

# --- Output ---------------------------------------------------------------------------------------

STARTED_AT=$SECONDS
FAILED_STAGE=""
step()   { printf '\n==> [%s] %s\n' "$1" "$2"; }
detail() { printf '    %s\n' "$*"; }
die()    { printf 'tier-c: %s\n' "$*" >&2; exit 2; }

# fail <stage> <reason> -- the ONE way a stage goes red. Names the STAGE and the reason on the last
# line, because a red-proof that can only assert rc=1 cannot tell the failure you engineered from
# an unrelated one earlier in the pipeline (bead oo-1xz lost an acceptance to exactly that).
fail() {
  FAILED_STAGE="$1"
  printf '\ntier-c: FAIL (stage %s): %s\n' "$1" "$2" >&2
  printf 'tier-c: RED after %ss\n' "$(( SECONDS - STARTED_AT ))" >&2
  exit 1
}

# --- Arguments -------------------------------------------------------------------------------------

LIST=0; DRY=0; ONLY=""; SKIP=""; BACKEND=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list)    LIST=1 ;;
    --dry-run) DRY=1 ;;
    --only)    ONLY="${2:?--only needs a comma-separated stage list}"; shift ;;
    --only=*)  ONLY="${1#--only=}" ;;
    --skip)    SKIP="${2:?--skip needs a comma-separated stage list}"; shift ;;
    --skip=*)  SKIP="${1#--skip=}" ;;
    --backend) BACKEND="${2:?--backend needs sm or quickjs}"; shift ;;
    --backend=*) BACKEND="${1#--backend=}" ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

# --backend=<sm|quickjs> (bead oo-2t6). Normalise the two accepted spellings for each engine
# ('sm'/'spidermonkey', 'quickjs'/'quickjs-ng') to the meson option value, so a typo is a FATAL
# usage error rather than a silent fall-through to the default app dir (which would make a
# "quickjs" run quietly re-check the SpiderMonkey build and report a meaningless match).
BACKEND_LABEL=""
if [ -n "$BACKEND" ]; then
  case "$BACKEND" in
    sm|spidermonkey) BACKEND_LABEL="spidermonkey" ;;
    quickjs|quickjs-ng) BACKEND_LABEL="quickjs" ;;
    *) die "unknown --backend '$BACKEND' (expected 'sm' or 'quickjs')" ;;
  esac
fi

all_stage_names() { printf '%b\n' "$STAGES" | while IFS=$'\t' read -r n c d; do [ -n "$n" ] && printf '%s\n' "$n"; done; }

# The stage names, ONCE, as an array -- and every lookup below is a loop over it rather than a
# pipeline, deliberately (bead oo-3uf8).
#
# The code this replaces was `all_stage_names | grep -qx "$want"` under the `set -o pipefail` at
# the top of this file. `grep -q` exits the instant it matches, which SIGPIPEs the still-writing
# producer on the left, and pipefail then propagates 141 -- so a SUCCESSFUL match read as a
# failure and --only/--skip rejected every stage name they listed as known in the same sentence.
# It is the same trap bead oo-j4u lost two acceptances to, one level in: there it was an
# acceptance line, here it was the product.
#
# Note it does NOT reproduce with a toy producer: `printf 'a\nb\n' | grep -qx a` is rc=0 with and
# without pipefail, because a small producer fits in the pipe buffer and finishes before grep
# exits. It needs THIS producer -- a subshell running a `while read` loop, still scheduled when
# grep returns -- which is why a minimal repro looks green and proves nothing.
#
# The fix is structural rather than a `|| true`: with no pipeline there is no SIGPIPE to mask,
# and a `|| true` would have swallowed real failures too. tools/tier-b.sh feeds its own tables
# through a here-string (`done <<< "$TEST_SUITES"`) for the same reason.
STAGE_NAMES=()
while read -r _n; do
  [ -n "$_n" ] && STAGE_NAMES+=("$_n")
done <<< "$(all_stage_names)"
[ "${#STAGE_NAMES[@]}" -gt 0 ] \
  || die "the STAGES table parsed to ZERO stage names; every selection below would be vacuous"

# is_stage <name> -- exact match against the table. No pipeline, no subshell, no grep.
is_stage() {
  local _want="$1" _n
  for _n in "${STAGE_NAMES[@]}"; do
    [ "$_n" = "$_want" ] && return 0
  done
  return 1
}

if [ "$LIST" = 1 ]; then
  printf '%-10s %8s  %s\n' STAGE 'COST(s)' DESCRIPTION
  printf '%b\n' "$STAGES" | while IFS=$'\t' read -r n c d; do
    [ -n "$n" ] || continue
    printf '%-10s %8s  %s\n' "$n" "$c" "$d"
  done
  printf '%-10s %8s  %s\n' TOTAL \
    "$(printf '%b\n' "$STAGES" | awk -F'\t' 'NF{s+=$2} END{print s}')" \
    "projected, warm; budget ${BUDGET_SECONDS}s"
  exit 0
fi

# --only / --skip resolution. An --only naming a stage that does not exist is a FATAL usage error,
# never a silently empty run: "tier-c: GREEN, 0 stages" is the purest form of the vacuous pass.
#
# Validate BEFORE selecting, so a typo is reported as a typo rather than as an empty selection.
# Each list is split on its own, not on "$ONLY$SKIP": concatenating them glued the last name of
# one to the first of the other (--only jsapi --skip gui asked about a stage called 'jsapigui').
for _list in "$ONLY" "$SKIP"; do
  [ -n "$_list" ] || continue
  IFS=',' read -r -a _wants <<< "$_list"
  for want in "${_wants[@]+"${_wants[@]}"}"; do
    [ -n "$want" ] || continue
    is_stage "$want" \
      || die "no such stage '$want'; known stages: ${STAGE_NAMES[*]}"
  done
done

SELECTED=()
for n in "${STAGE_NAMES[@]}"; do
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$n,"*) ;; *) continue ;; esac; fi
  if [ -n "$SKIP" ]; then case ",$SKIP," in *",$n,"*) continue ;; esac; fi
  SELECTED+=("$n")
done

[ "${#SELECTED[@]}" -gt 0 ] \
  || die "the stage selection is EMPTY (--only='$ONLY' --skip='$SKIP'); a tier with no stages passes vacuously"

if [ "$DRY" = 1 ]; then
  printf 'tier-c: plan (%d stage(s)): %s\n' "${#SELECTED[@]}" "${SELECTED[*]}"
  printf 'tier-c: budget %ss, platform %s, repo %s\n' "$BUDGET_SECONDS" "$PLATFORM" "$REPO_NATIVE"
  [ -n "$BACKEND_LABEL" ] && printf 'tier-c: backend %s\n' "$BACKEND_LABEL"
  exit 0
fi

# --- Preconditions -----------------------------------------------------------------------------

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || die "no python on PATH (did the UCRT64 re-exec happen? MSYSTEM=${MSYSTEM:-unset})"
command -v cygpath >/dev/null 2>&1 || die "no cygpath on PATH; this is not an MSYS2 shell"

# Default the app dir rather than assuming a local build. accept.sh replays stored lines on a
# FRESH worktree with NO BUILD DIRECTORY (bead oo-1xz); a line that needs the game must say where
# the game is, in both places.
#
# --backend picks the meson flavour directory each backend is built into (bead oo-2t6): the
# QuickJS-ng backend build lives at build/meson_test_quickjs (a SEPARATE build directory from the
# plain SpiderMonkey build at build/meson_test, so choosing one never overwrites the other and the
# differential runner can hold both at once). OO_APP_DIR still wins outright when set, exactly as
# it does with no --backend, so a caller pointing this at an ad-hoc build is never overridden.
#
# Since bead oo-7wx the tree has one engine, QuickJS-ng, built into the ordinary
# build/meson_test. A SpiderMonkey build exists only if someone builds a pre-oo-7wx tree into
# build/meson_test_spidermonkey (or points OO_APP_DIR at one) for a historical differential run;
# otherwise --backend=sm fails at the app-dir check below, loudly, rather than re-checking the
# QuickJS build under the wrong name.
if [ -n "$BACKEND_LABEL" ]; then
  case "$BACKEND_LABEL" in
    spidermonkey) DEFAULT_APP_DIR="$OOLITE/build/meson_test_spidermonkey/oolite.app" ;;
    quickjs)       DEFAULT_APP_DIR="$OOLITE/build/meson_test/oolite.app" ;;
  esac
else
  DEFAULT_APP_DIR="$OOLITE/build/meson_test/oolite.app"
fi
APP_DIR="${OO_APP_DIR:-$DEFAULT_APP_DIR}"

RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tier-c-$$-XXXXXX")" || die "cannot create a run root"
RUN_ROOT_NATIVE="$(native "$RUN_ROOT")"
cleanup() {
  # KEEP THE EVIDENCE ON RED, as tier-b does: the first thing anyone does after a FAIL line is
  # open the log it names.
  if [ -n "${OOLITE_TIER_C_KEEP:-}" ] || [ -n "$FAILED_STAGE" ]; then
    [ -n "$FAILED_STAGE" ] && printf 'tier-c: logs kept at %s\n' "$RUN_ROOT_NATIVE" >&2
    return 0
  fi
  rm -rf "$RUN_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

free_port() {
  "$PY" -c "
import socket
s = socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
"
}

printf '==> tier-c (%s, budget %ss, %d stage(s): %s)\n' \
  "$PLATFORM" "$BUDGET_SECONDS" "${#SELECTED[@]}" "${SELECTED[*]}"
detail "repo      $REPO_NATIVE"
detail "run root  $RUN_ROOT_NATIVE"
detail "app dir   $(native "$APP_DIR")"
[ -n "$BACKEND_LABEL" ] && detail "backend   $BACKEND_LABEL"

# ================================================================================================
# STAGE tier-b -- THE WHOLE PER-COMMIT GATE
# ================================================================================================
#
# COMPOSED, NOT DUPLICATED. Tier B already builds, runs the module tests with committed floors,
# checks its own environment parity, runs the fast goldens, the component tier, a smoke launch and
# a 3-group corpus subset. Re-implementing any of that here would give two definitions of the same
# check that drift. Tier C's own stages are the ones Tier B deliberately cannot afford.
stage_tier_b() {
  local t0=$SECONDS log="$RUN_ROOT/tier-b.log" rc=0
  step tier-b "tools/tier-b.sh (the entire per-commit gate)"
  [ -x "$HERE/tier-b.sh" ] || [ -f "$HERE/tier-b.sh" ] \
    || fail tier-b "tools/tier-b.sh is missing; Tier C is defined as Tier B plus the deep stages, so its absence is not a smaller Tier C"
  ( cd "$REPO_ROOT" && bash "$HERE/tier-b.sh" ) > "$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    tail -30 "$log" >&2
    # Forward tier-b's OWN stage name, so a Tier C failure says which of tier-b's stages broke
    # rather than just "tier-b failed".
    local sub
    sub="$(grep -oE 'FAIL \(stage [a-z-]+\)' "$log" | tail -1 || true)"
    fail tier-b "tier-b exited $rc${sub:+ -- $sub}; full log $(native "$log")"
  fi
  # POSITIVE EVIDENCE: tier-b's own success line, not merely rc=0. A tier-b that somehow exited 0
  # without running (an early --list, a shell that swallowed it) has no GREEN line.
  grep -q '^tier-b: GREEN' "$log" \
    || fail tier-b "tier-b exited 0 but printed no 'tier-b: GREEN' line; it did not complete its stages"
  # ... and it must have actually entered its stages. Their names appear in its step() output.
  local seen
  seen="$(grep -cE '^==> \[(build|tests|parity|goldens|component|smoke|corpus)\]' "$log" || true)"
  [ "${seen:-0}" -ge 6 ] \
    || fail tier-b "tier-b announced only ${seen:-0} of its 7 stages; it exited 0 without running its gate"
  detail "$(grep -m1 '^tier-b: GREEN' "$log")"
  detail "stage tier-b ok: $seen stage(s) announced, $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE jsapi -- THE JS API SNAPSHOT
# ================================================================================================
#
# oxp-contract/js-api-source.json is generated from the DECLARATIVE property and function tables in
# upstream/oolite/src/**/OOJS*.m and is already load-bearing for other beads: oo-9w5 used "the
# committed JS API snapshot" to reject a proposed scenario relying on a property that does not
# exist, and oo-jou1 exists precisely because Ship.speed is OOJS_PROP_READONLY_CB.
#
# The gate REGENERATES it and byte-compares, exactly as bead oo-4z6 did for its tier2 list, so the
# committed file cannot drift from the engine. It is ~2 s and needs no build and no launch, which
# is why it is also the one stage the stored acceptance block really runs.
stage_jsapi() {
  local t0=$SECONDS log="$RUN_ROOT/jsapi.log" rc=0
  step jsapi "regenerate oxp-contract/js-api-source.json from engine source and byte-compare"
  [ -f "$HERE/js_api_source_snapshot.py" ] \
    || fail jsapi "tools/js_api_source_snapshot.py is missing; without the generator the committed snapshot cannot be checked and a stale file would pass unnoticed"
  [ -f "$JSAPI_SNAPSHOT" ] \
    || fail jsapi "no committed snapshot at $(native "$JSAPI_SNAPSHOT"); a gate with nothing to compare against passes vacuously"
  [ -d "$OOLITE/src" ] \
    || fail jsapi "no engine source at $(native "$OOLITE/src"); the snapshot cannot be regenerated, and 'cannot check' is not 'checked'"

  ( cd "$REPO_ROOT" && "$PY" "$(native "$HERE/js_api_source_snapshot.py")" \
      --check "$(native "$JSAPI_SNAPSHOT")" ) > "$log" 2>&1 || rc=$?
  case "$rc" in
    0) : ;;
    # rc=2 is the repo's "I cannot tell you" convention (bead oo-jor): refused, floors unmet,
    # unreadable input. It is never a pass.
    2) sed -n '1,20p' "$log" >&2
       fail jsapi "the snapshot check REFUSED (rc=2): the fresh scrape did not satisfy its own content floors, so no comparison was possible -- a refusal is not a pass" ;;
    *) sed -n '1,30p' "$log" >&2
       fail jsapi "the committed JS API snapshot is STALE: it does not match a fresh scrape of upstream/oolite/src (rc=$rc). Regenerate with tools/js_api_source_snapshot.py --out $(native "$JSAPI_SNAPSHOT")" ;;
  esac
  # POSITIVE EVIDENCE: the OK line carries the counts, so a snapshot that shrank to a handful of
  # classes cannot slip through on rc=0 alone.
  grep -q 'byte-identical to a fresh scrape' "$log" \
    || fail jsapi "the check exited 0 but did not report a byte-identical scrape; it did not perform the comparison"
  detail "$(head -1 "$log")"

  # --- RECONCILIATION against the RUNTIME-derived snapshot.
  #
  # oxp-contract/js-api-1.93.json is produced by tools/js-api-snapshot.sh from a LIVE interpreter
  # (and takes the desktop lock to do it). The two snapshots answer different questions -- what
  # resolves at runtime vs what the engine declares and whether it is writable -- and cross-checking
  # them is free, offline, and catches a class of error neither can catch alone.
  #
  # NOTE THE LOCK, because it shapes this stage: the RUNTIME snapshot needs tools/gui-lock, so it
  # is NOT regenerated here. Tier C already takes that lock in the asan and gui stages, and a stage
  # that took it a third time while another held it would deadlock the tier against its own
  # snapshot step. This stage therefore only READS the committed runtime artifact, and needs no
  # lock, no build and no launch.
  local rlog="$RUN_ROOT/jsapi-reconcile.log" rrc2=0
  if [ -f "$HERE/js_api_reconcile.py" ]; then
    ( cd "$REPO_ROOT" && "$PY" "$(native "$HERE/js_api_reconcile.py")" ) > "$rlog" 2>&1 || rrc2=$?
    case "$rrc2" in
      0) : ;;
      2) sed -n '1,15p' "$rlog" >&2
         fail jsapi "the source/runtime reconciliation REFUSED (rc=2): too little was comparable for a verdict, or the committed baseline is missing. A refusal is not a pass" ;;
      *) sed -n '1,30p' "$rlog" >&2
         fail jsapi "NEW discrepancies between the source-derived and runtime-derived JS API snapshots (rc=$rrc2). If they are expected, review and re-record with tools/js_api_reconcile.py --write-baseline" ;;
    esac
    grep -q 'class(es) and .* propert(ies) compared' "$rlog" \
      || fail jsapi "the reconciliation exited 0 without reporting what it compared; a cross-check that compared nothing agrees perfectly"
    detail "$(head -1 "$rlog" | cut -c1-150)"
  fi

  # --- THE QUICKJS-ERA BASELINE (ADR-0024, bead oo-1gc.10). oxp-contract/js-api-quickjs.json is the
  # runtime snapshot of the QuickJS-ng build, committed when Phase 1 closed; the Oolite surface it
  # describes must still be the 1.93 contract's. Offline: it compares two committed files.
  local slog="$RUN_ROOT/jsapi-surface.log" src=0
  [ -f "$REPO_ROOT/oxp-contract/js-api-quickjs.json" ]     || fail jsapi "no committed QuickJS-era snapshot at oxp-contract/js-api-quickjs.json (ADR-0024); regenerate with tools/js-api-snapshot.sh --output oxp-contract/js-api-quickjs.json"
  ( cd "$REPO_ROOT" && "$PY" "$(native "$HERE/js_api_surface_compare.py")" oxp-contract/js-api-1.93.json oxp-contract/js-api-quickjs.json ) > "$slog" 2>&1 || src=$?
  if [ "$src" -ne 0 ]; then
    sed -n '1,30p' "$slog" >&2
    fail jsapi "the QuickJS-era snapshot's Oolite API surface differs from the 1.93 contract (rc=$src)"
  fi
  detail "$(tail -1 "$slog" | cut -c1-150)"
  detail "stage jsapi ok in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE asan -- ADDRESSSANITIZER
# ================================================================================================
#
# THE FINDING, MEASURED, BECAUSE IT IS NOT OBVIOUS AND THE NEXT AGENT WILL OTHERWISE REPEAT IT:
#
# MSYS2 UCRT64 clang 22.1.8 accepts -fsanitize=address and then cannot link:
#   ld: cannot find .../lib/clang/22/lib/x86_64-w64-windows-gnu/libclang_rt.asan_dynamic.dll.a
# because mingw-w64-ucrt-x86_64-compiler-rt SHIPS NO ASAN AT ALL. The same upstream version built
# for CLANG64 does. tools/asan-resource-dir.sh splices the CLANG64 archives into a private
# resource directory; see that file for the two further facts (it must link with lld, and
# /clang64/bin must be on PATH at run time) and for the self-proving probe.
#
# MEASURED OUTCOME ON THIS TOOLCHAIN, 2026-09-18 -- THE ANSWER IS YES, ASAN WORKS:
#   probe                       5.5 s    deliberate use-after-free CAUGHT
#   sanitized Oolite compile    all 243 TUs compile clean with -fsanitize=address
#   sanitized Oolite link       needs -Wl,--allow-multiple-definition; see WHY below
#   sanitized binary            31,074,304 bytes vs 10,079,232 unsanitized, and it IMPORTS
#                               libclang_rt.asan_dynamic-x86_64.dll
#   sanitized Oolite run        reaches [startup.complete] in 38.96-40.07 s, against ~4-14 s
#                               unsanitized: a 3-10x slowdown, which is why the budget is 2400 s
#
# THE TWO REPORTS SEEN ON THE FIRST RUN WERE NOT OOLITE DEFECTS, and reporting them as such would
# have been a serious false positive:
#   SUMMARY: AddressSanitizer: bad-malloc_usable_size (...ucrtbase.dll+0x180031843) in strnicoll
#   SUMMARY: AddressSanitizer: attempting free on address which was not malloc()-ed (...ucrtbase.dll)
# Both stacks run alcOpenDevice -> alcCaptureStart inside the PREBUILT libopenal-1.dll, through
# pthread_once in libwinpthread-1.dll, into ucrtbase's onexit table. The classic Windows ASan
# interceptor mismatch: a prebuilt DLL allocates through an allocator ASan does not own. See
# tools/asan-suppressions.txt for the full write-up.
#
# THREE THINGS FOLLOW, AND ALL THREE ARE IMPLEMENTED BELOW:
#
#  (1) SYMBOLISATION IS A PREREQUISITE, NOT A NICETY. The pass condition is "zero reports
#      attributable to oolite.exe", and nothing can be attributed while oolite.exe frames are bare
#      addresses. llvm-symbolizer (mingw-w64-ucrt-x86_64-llvm-tools) is REQUIRED here, and the
#      stage PROVES it resolves before trusting any verdict: it symbolises a known instrumented
#      address from the freshly built binary and asserts a src/ file:line comes back. Verified:
#      0x1401267aa -> _i_OOOpenALController__init  ../../src/Core/OOOpenALController.m:65:12.
#      A stage that cannot tell which module a report came from is a vacuous gate in a costume.
#
#  (2) AUDIO IS GENUINELY EXCLUDABLE, NOT MERELY SUPPRESSED. SDL_AUDIODRIVER=dummy and
#      ALSOFT_DRIVERS=null do NOT prevent it: OpenAL still reaches alcOpenDevice. The real switch
#      is --nosound, handled at src/Core/OOOpenALController.m:55-61, which returns nil BEFORE
#      alcOpenDevice. Measured on the same binary: without it 2 reports, with it 0 reports, and
#      startup still completes (40.07 s). So the primary mechanism is exclusion, and
#      tools/asan-suppressions.txt is defence in depth for a run that initialises audio anyway.
#
#  (3) THE SUPPRESSIONS ARE NARROW AND THE DEFAULT IS STRICT. No blanket halt_on_error=0 as the
#      shipped configuration -- that was right for exploration and would swallow Oolite's own
#      reports as a gate default. Every suppression names a specific third-party module, none
#      mentions oolite, and the attribution check runs on the SYMBOLISED text, so an
#      oolite.exe-attributed report goes red whatever the suppressions file says.
#
# WHY --allow-multiple-definition IS REQUIRED AND WHY IT IS NOT A SUPPRESSION.
# The sanitized link fails with ~21 "duplicate symbol: __objc_eh_typeinfo_NSException" errors.
# A/B/C control, one variable changed, same tree, same box:
#   A  tools/build-windows.sh debug                                    -> rc=0, 0 duplicate symbols
#   B  the same, plus -Db_sanitize=address                             -> rc=1, duplicate symbols
#   C  the same as B, but the -resource-dir ONLY (no sanitizer)        -> rc=0, 0 duplicate symbols
# So the duplicates are caused by the SANITIZER's instrumentation of Objective-C EH type info, not
# by the resource-dir splice and not by a repo defect. Allowing them is a LINKER instruction
# specific to this sanitized build; it is not -Wno-*, it changes no diagnostic, and it applies to
# no normal build. CLAUDE.md's prohibition is on silencing compiler warnings, which this is not.
#
# ANTI-VACUITY. Every cheaper signal is satisfiable by a dead run: the build exiting 0 proves
# nothing (a stale binary also exits 0), a nonzero run exit proves nothing (0xC0000135 is also
# nonzero), and an absence of ASan output proves nothing (a process that died before main is also
# silent). So this stage asserts, in order: the PROBE really catches a use-after-free; symbolisation
# really resolves an engine address to a file:line; the built binary really IMPORTS the ASan runtime
# DLL; the launched game really reaches [startup.complete].
stage_asan() {
  local t0=$SECONDS
  step asan "AddressSanitizer: toolchain probe, symbolisation, sanitized build, sanitized launch"

  [ -f "$HERE/asan-resource-dir.sh" ] \
    || fail asan "tools/asan-resource-dir.sh is missing; without it -fsanitize=address cannot link on UCRT64 clang and this stage would silently degrade to no sanitizer at all"
  [ -f "$ASAN_SUPPRESSIONS" ] \
    || fail asan "tools/asan-suppressions.txt is missing; the stage would then either fail on known third-party interceptor mismatches or be run with a blanket halt_on_error=0, and neither is a gate"
  # The suppressions must not be able to hide OUR code. Checked here as well as in the selftest,
  # because this is the file an impatient future edit would widen first.
  if grep -qi 'oolite' "$ASAN_SUPPRESSIONS"; then
    grep -ni 'oolite' "$ASAN_SUPPRESSIONS" >&2
    fail asan "tools/asan-suppressions.txt mentions oolite: a suppression that can match the module under test turns this stage into a no-op"
  fi

  # --- 1. the toolchain probe. ~5 s, and it is the only thing that can distinguish "ASan is
  # working" from "ASan is present and inert".
  local probe="$RUN_ROOT/asan-probe.log" prc=0
  bash "$HERE/asan-resource-dir.sh" --probe > "$probe" 2>&1 || prc=$?
  if [ "$prc" -ne 0 ]; then
    sed -n '1,20p' "$probe" >&2
    fail asan "the AddressSanitizer toolchain probe FAILED (rc=$prc): this toolchain cannot produce a binary that detects a deliberate heap-use-after-free, so every later ASan verdict would be a silent no-op. See $(native "$probe")"
  fi
  grep -q 'ERROR: AddressSanitizer: heap-use-after-free' "$probe" \
    || fail asan "the probe exited 0 but printed no heap-use-after-free report; rc=0 alone is not evidence the sanitizer fired"
  detail "$(grep -m1 '^asan: OK' "$probe")"

  # --- 1b. symbolisation must be AVAILABLE. Without it every frame is a bare address and the
  # attribution check below cannot distinguish our module from a third-party DLL.
  local symbolizer
  symbolizer="$(command -v llvm-symbolizer || true)"
  [ -n "$symbolizer" ] \
    || fail asan "llvm-symbolizer is not on PATH; ASan frames would be bare addresses and this stage could not attribute a report to oolite.exe rather than to a prebuilt DLL. Install it: pacman -S mingw-w64-ucrt-x86_64-llvm-tools"
  local symbolizer_native
  symbolizer_native="$(native "$symbolizer")"

  local rd dlldir
  rd="$(bash "$HERE/asan-resource-dir.sh" --print)" || fail asan "could not build the spliced ASan resource directory"
  dlldir="$(bash "$HERE/asan-resource-dir.sh" --dll-dir)" || fail asan "could not locate the ASan runtime DLL directory"

  # --- 2. the sanitized build of the engine.
  local blog="$RUN_ROOT/asan-build.log" brc=0
  local flavour="${OOLITE_TIER_C_ASAN_FLAVOUR:-debug}"
  local bdir="$OOLITE/build/meson_$flavour"
  local binary="$bdir/oolite.app/oolite.exe"
  detail "building flavour '$flavour' with -fsanitize=address (resource-dir $rd)"
  ( cd "$REPO_ROOT" && bash "$HERE/build-windows.sh" "$flavour" --setup-flags="-Db_sanitize=address -Db_lundef=false -Dc_args=-resource-dir=$rd -Dcpp_args=-resource-dir=$rd -Dobjc_args=-resource-dir=$rd -Dc_link_args=['-resource-dir=$rd','-Wl,--allow-multiple-definition'] -Dcpp_link_args=['-resource-dir=$rd','-Wl,--allow-multiple-definition'] -Dobjc_link_args=['-resource-dir=$rd','-Wl,--allow-multiple-definition'] -Dobjcpp_args=-resource-dir=$rd -Dobjcpp_link_args=['-resource-dir=$rd','-Wl,--allow-multiple-definition']" ) \
    > "$blog" 2>&1 || brc=$?
  if [ "$brc" -ne 0 ]; then
    tail -30 "$blog" >&2
    fail asan "the SANITIZED build failed (rc=$brc); full log $(native "$blog"). If the tail shows 'cannot find ...libclang_rt.asan_dynamic.dll.a' the CLANG64 runtime is not installed (pacman -S mingw-w64-clang-x86_64-compiler-rt mingw-w64-clang-x86_64-libc++)"
  fi
  [ -f "$binary" ] || fail asan "the sanitized build reported success but $(native "$binary") is missing"

  # POSITIVE EVIDENCE: a compiler was really invoked on this configuration.
  grep -q 'ccache this run' "$blog" \
    || fail asan "the sanitized build log has no 'ccache this run' line, so no compile phase ran and an unsanitized binary may have been left in place"

  # POSITIVE EVIDENCE: the binary is REALLY instrumented. This is the check that catches the worst
  # failure mode of the whole stage -- a build that quietly dropped -fsanitize=address and left a
  # perfectly good, perfectly unsanitized oolite.exe that passes every other assertion here.
  local imports
  imports="$(objdump -p "$binary" 2>/dev/null | grep -ci 'libclang_rt.asan_dynamic' || true)"
  [ "${imports:-0}" -ge 1 ] \
    || fail asan "$(native "$binary") does NOT import libclang_rt.asan_dynamic-x86_64.dll; the build produced an UNSANITIZED binary and every ASan verdict from it would be vacuous"
  detail "binary    $(stat -c %s "$binary") bytes, imports the ASan runtime DLL"

  # POSITIVE EVIDENCE: symbolisation really WORKS on THIS binary, not merely that the tool exists.
  # An ASan frame address is resolved and must come back as a src/ file:line. Without this, a
  # stripped or mismatched binary would leave every frame unattributable and the attribution check
  # below would report "0 oolite frames" for a run full of engine defects.
  local symtest sym_addr
  # objdump prints the address as 8 hex digits under the 0x140000000 image base (hence the "0x1"
  # prefix) or, on the current toolchain, as the full 16-digit VA; take either as it comes.
  sym_addr="$(objdump -d "$binary" 2>/dev/null \
              | awk '/<_i_OOOpenALController__init>:/{a=$1; sub(":","",a); print (length(a) <= 8 ? "0x1" a : "0x" a); exit}' || true)"
  # Fall back to the entry point when that symbol moves; what matters is that SOME engine address
  # resolves to a src/ path, not which one.
  [ -n "$sym_addr" ] || sym_addr="$(objdump -f "$binary" 2>/dev/null | awk '/start address/{print $NF}')"
  symtest="$(printf '%s\n' "$sym_addr" | "$symbolizer" --obj="$(native "$binary")" 2>/dev/null | head -4 || true)"
  printf '%s\n' "$symtest" | grep -qE '(src/|\.m:[0-9]+|\.c:[0-9]+)' \
    || { printf '%s\n' "$symtest" >&2
         fail asan "llvm-symbolizer could not resolve $sym_addr in $(native "$binary") to a source location; ASan frames will be bare addresses and no report can be attributed to a module, which makes a green from this stage meaningless"; }
  detail "symbolizer $(printf '%s' "$symtest" | sed -n '2p') (frames will be attributable)"

  # --- 3. the sanitized launch. The game must really boot under the sanitizer.
  local app="$bdir/oolite.app" prefix="${MINGW_PREFIX:-/ucrt64}" dll
  for dll in opengl32.dll libgallium_wgl.dll; do
    [ -f "$prefix/bin/$dll" ] && cp -f "$prefix/bin/$dll" "$app/" 2>/dev/null || true
  done
  local out="$RUN_ROOT/asan-run" rrc=0
  mkdir -p "$out/Config"

  # A PRIVATE CONSOLE PORT. The game DIALS OUT and reads console-port from debugConfig.plist
  # (OODebugSupport.m:67-80, default kOOTCPConsolePort=8563). On the shared default a sibling's
  # console can accept our game and quit it seconds in, while the run still exits 0 with no ERROR
  # lines (bead oo-het measured exactly that). A port is made real by writing the plist the game
  # merges, not by listening elsewhere (bead oo-gla) -- so write it, into a private addons root.
  local port
  port="$(free_port)"
  "$PY" -c "
import plistlib, sys
plistlib.dump({'console-host': '127.0.0.1', 'console-port': int(sys.argv[2])},
              open(sys.argv[1], 'wb'), fmt=plistlib.FMT_XML)
" "$(native "$out/Config/debugConfig.plist")" "$port" \
    || fail asan "could not write the private debugConfig.plist for the sanitized launch"

  # ASAN_OPTIONS is COLON-separated and a Windows path contains a colon, so neither log_path nor
  # suppressions may be passed inline: doing so yields "AddressSanitizer: ERROR: expected '=' in
  # ASAN_OPTIONS" and the process dies before main, which looks exactly like a sanitizer finding
  # and is not one (measured). The suppressions file therefore travels in its own variable.
  #
  # halt_on_error=0 is used ONLY so a third-party report does not truncate the run before
  # [startup.complete]; it does not weaken the verdict, because the verdict is the ATTRIBUTION
  # check below, which counts oolite.exe-attributed reports and fails on any.
  # THE DESKTOP LOCK. This stage launches the real game, and CLAUDE.md's rule (enforced by
  # tools/check-desktop-lock.sh) is that every desktop launcher takes tools/gui-lock. A 40-second
  # sanitized launch racing a sibling's GUI test would steal focus in both directions. `gui-lock
  # run` acquires, runs, releases and propagates the status, so the lock cannot leak if the launch
  # dies.
  local lock="$HERE/gui-lock"
  local runner=(); [ -x "$lock" ] && runner=("$lock" run --timeout "${OOLITE_TIER_C_LOCK_TIMEOUT:-900}" --)

  # $dlldir is a native C:/... path; in an MSYS PATH its drive colon splits it into two bogus
  # entries and the loader never finds libclang_rt.asan_dynamic-x86_64.dll (exit 127).
  ( cd "$app" && PATH="$(cygpath -u "$dlldir"):$PATH" \
      ASAN_OPTIONS="halt_on_error=0:abort_on_error=0:detect_leaks=0:symbolize=1" \
      ASAN_SYMBOLIZER_PATH="$symbolizer_native" \
      LSAN_OPTIONS="suppressions=$(native "$ASAN_SUPPRESSIONS")" \
      OO_LOGSDIR="$(native "$out")" \
      OO_ADDITIONALADDONSDIRS="$(native "$out")" \
      OO_GUI_LOCK_OWNER="tier-c-asan-$$" \
      LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
      "${runner[@]}" \
      timeout "${OOLITE_TIER_C_ASAN_LAUNCH_TIMEOUT:-300}" ./oolite.exe --no-splash --nosound ) \
    > "$out/stdout.txt" 2>&1 || rrc=$?

  # DISTINGUISH THE TWO FAILURE FAMILIES EXPLICITLY. On this box a missing /ucrt64/bin produces
  # exit 3221225781 (0xC0000135, STATUS_DLL_NOT_FOUND) after ~116 s and writes no log; that is a
  # PATH problem and must never be reported as an ASan finding, nor the reverse.
  if [ "$rrc" = 3221225781 ]; then
    fail asan "the sanitized launch died with 3221225781 (0xC0000135, STATUS_DLL_NOT_FOUND) -- a runtime DLL was not found. This is the PATH trap, not a sanitizer finding. /ucrt64/bin and $dlldir must both be on PATH."
  fi
  local latest="$out/Latest.log"
  [ -f "$latest" ] \
    || { sed -n '1,25p' "$out/stdout.txt" >&2
         fail asan "the sanitized launch wrote no Latest.log in $(native "$out") (exit $rrc); it died before the log was opened"; }
  # THE progress precondition. A dead launch writes a ~1.5 KB log with the version banner, the CPU
  # line and [process.args] and ZERO ERROR lines (bead oo-het), so neither length nor absence-of-
  # error discriminates. [startup.complete] is emitted only AFTER expansions are parsed.
  grep -q '\[startup\.complete\]' "$latest" \
    || { tail -15 "$latest" >&2
         fail asan "the sanitized game never reached [startup.complete] (exit $rrc, $(wc -l < "$latest") log lines); it did not finish loading, so nothing was exercised under the sanitizer"; }
  detail "port $port, $(grep -m1 '\[startup\.complete\]' "$latest" | sed 's/^[0-9:.]* //')"

  # --- 4. THE VERDICT: attribution, on the SYMBOLISED text.
  #
  # Engine-code findings are what this tier exists to catch. Findings inside prebuilt third-party
  # DLLs are reported but are not ours (see the header and tools/asan-suppressions.txt). The
  # distinction is made on the symbolised frames of each report, and BOTH counts are printed, so a
  # change in the third-party population is visible rather than hidden.
  local reports engine
  reports="$(grep -c 'ERROR: AddressSanitizer' "$out/stdout.txt" || true)"
  engine="$("$PY" - "$(native "$out/stdout.txt")" <<'PYEOF' || echo -1
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
# Split into per-report blocks and count those whose stack names oolite.exe or a src/ path.
blocks = re.split(r"(?=ERROR: AddressSanitizer)", text)[1:]
ours = 0
for b in blocks:
    head = b[:4000]
    if re.search(r"oolite\.exe", head) or re.search(r"\bsrc[/\\]", head):
        ours += 1
print(ours)
PYEOF
)"
  [ "${engine}" != "-1" ] \
    || fail asan "the attribution pass could not read the sanitizer output; 'I cannot tell you' is not a pass"
  detail "asan      ${reports:-0} report(s), ${engine} attributable to oolite.exe"
  if [ "${engine:-0}" -gt 0 ]; then
    grep -B2 -A12 'ERROR: AddressSanitizer' "$out/stdout.txt" | head -60 >&2
    fail asan "${engine} AddressSanitizer report(s) name a frame in oolite.exe or a src/ path -- these are OUR memory defects, not a third-party DLL's allocator mismatch. Full output $(native "$out/stdout.txt")"
  fi
  detail "stage asan ok in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE goldens -- EVERY SCENARIO
# ================================================================================================
#
# Tier B runs the BLESSED scenarios under goldens/<platform>/. Tier C additionally runs the ones
# that are not blessed yet -- tests/golden/staged/ and tests/golden/pending/ -- because bead oo-8ij
# established (by A/B control) that guardrails.sh refuses ANY change under goldens/, create or
# modify, without a human approval line. That makes blessing a bottleneck, and a scenario waiting
# on a human signature is exactly the code most likely to rot unexercised.
#
# Scenarios are DISCOVERED, never listed here, so a scenario added tomorrow is gated tomorrow --
# and the count is compared against a floor, so one that DISAPPEARS turns the gate red rather than
# making it cheaper. Nothing under goldens/ is written; every runner writes to the private run root.
stage_goldens() {
  local t0=$SECONDS dir name n=0 ok=0
  step goldens "every scenario: blessed (goldens/$PLATFORM), staged and pending"
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
    local out="$RUN_ROOT/$name.json" log="$RUN_ROOT/$name.log" port rc=0
    port="$(free_port)"
    local s=$SECONDS
    case "$name" in
      001-launch-dock)
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
               --out "$(native "$out")" --output-dir "$(native "$RUN_ROOT/out-$name")" ) \
          > "$log" 2>&1 || rc=$?
        ;;
    esac
    local wall=$(( SECONDS - s ))
    [ "$rc" -eq 0 ] || { tail -20 "$log" >&2
      fail goldens "scenario $name did not produce a dump (rc=$rc after ${wall}s); $(native "$log")"; }
    [ -s "$out" ] || fail goldens "scenario $name exited 0 but wrote no dump at $(native "$out")"

    # golden_diff.py's rc convention (bead oo-jor): 0 = verified equal, 1 = a real difference,
    # 2 = REFUSED (unreadable, empty, self-comparison, off-policy quantisation). 2 is not a pass.
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
    if [ -f "$REPO_ROOT/tests/golden/check_launch_dock_evidence.py" ] && [ "$name" = "001-launch-dock" ]; then
      "$PY" "$(native "$REPO_ROOT/tests/golden/check_launch_dock_evidence.py")" "$(native "$out")" \
        > "$RUN_ROOT/ev-$name.log" 2>&1 \
        || { cat "$RUN_ROOT/ev-$name.log" >&2
             fail goldens "scenario $name matched its golden but failed its own launch/dock evidence check"; }
    fi
    detail "$(printf '%-18s MATCH  %3ds  port %s' "$name" "$wall" "$port")"
    ok=$(( ok + 1 ))
  done
  [ "$ok" -eq "$n" ] || fail goldens "$ok of $n blessed scenarios verified"

  # The unblessed scenarios. Their SPEC and evidence checkers are exercised offline -- the specs
  # exist, parse, and satisfy their own checkers -- which is the part that rots while a golden
  # waits for a human approval line. This is not a substitute for running them; it is the check
  # that is possible without the bless.
  local unblessed=0
  for dir in "$REPO_ROOT/tests/golden/staged"/*/ "$REPO_ROOT/tests/golden/pending"/*/; do
    [ -d "$dir" ] || continue
    unblessed=$(( unblessed + 1 ))
    detail "$(printf '%-18s UNBLESSED (awaiting a human line in tools/rebless-approvals.txt)' "$(basename "$dir")")"
  done
  detail "stage goldens ok: $ok blessed verified, $unblessed unblessed present, $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE corpus -- THE FULL TIER 1
# ================================================================================================
#
# Tier B runs the first 3 groups (~53 s). Tier C runs ALL of them: 30 catalogue entries plus 6
# test-oxps = 36 groups at 17-22 s each = 11-13 min, which is on its own more than Tier B's whole
# budget and is the single reason this tier exists as a separate one.
#
# ANTI-VACUITY, and this one has bitten before: corpus.sh reports "K group(s) checked, F failed",
# and a run that staged NOTHING reports 0/0 and exits 0 (bead oo-het saw exactly that -- 35 of 36
# expansions silently never copied, surfacing 20 lines later as bogus MISSING verdicts). So the
# checked count is compared against a FLOOR, and the PASS count against the checked count.
stage_corpus() {
  local t0=$SECONDS log="$RUN_ROOT/corpus.log" rc=0
  step corpus "tools/corpus.sh tier1 (the FULL list, floor $CORPUS_FLOOR groups)"
  ( cd "$REPO_ROOT" && OO_APP_DIR="$(native "$APP_DIR")" bash "$HERE/corpus.sh" tier1 ) \
    > "$log" 2>&1 || rc=$?
  local checked passes
  checked="$(grep -oE '[0-9]+ group\(s\) checked' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  # KNOWN (oo-1gc.7, proposed ADR-0047) counts with PASS: an exact, byte-pinned match of a reviewed
  # entry in tools/oxp-corpus/known-content-failures.json. Any drift from the entry is KNOWNCHG,
  # which fails corpus.sh (rc != 0) and is not counted here.
  passes="$(grep -cE '^(PASS|KNOWN) ' "$log" || true)"
  [ "$rc" -eq 0 ] || { tail -25 "$log" >&2
    fail corpus "the full Tier 1 corpus failed (rc=$rc, $checked checked, ${passes:-0} PASS); $(native "$log")"; }
  [ "${checked:-0}" -ge "$CORPUS_FLOOR" ] \
    || fail corpus "corpus.sh checked only ${checked:-0} group(s), fewer than the committed floor of $CORPUS_FLOOR -- this is the FULL tier, and a run that staged nothing reports 0 checked and exits 0"
  [ "${passes:-0}" -eq "${checked:-0}" ] \
    || fail corpus "${passes:-0} of ${checked:-0} group(s) reported PASS (or KNOWN)"
  detail "$passes/$checked expansion group(s) loaded in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE gui -- THE PYAUTOGUI TIER, UNDER THE DESKTOP LOCK
# ================================================================================================
#
# ADR-0017: the GUI tier runs HERE and nightly only, never per bead, because it drives a real
# window with synthetic OS input events and therefore takes the interactive desktop EXCLUSIVELY.
# Two GUI runs at once steal each other's focus and each other's clicks.
#
# tools/gui-tier.sh already owns the hard parts (it installs the tier's requirements, and it sets
# OO_GUI_REQUIRE=1 so conftest's not-applicable-platform SKIP becomes a FAILURE). That last point
# is precisely the anti-vacuity property this stage needs, so the stage composes with it rather
# than re-running pytest itself -- but it does NOT take rc=0 as proof, because a pytest run that
# collected nothing also exits 0. The passed-count is the evidence.
stage_gui() {
  local t0=$SECONDS log="$RUN_ROOT/gui.log" rc=0
  step gui "tools/gui-tier.sh (serialised on tools/gui-lock)"
  [ -f "$HERE/gui-tier.sh" ] \
    || fail gui "tools/gui-tier.sh is missing; the GUI tier runs in Tier C and nightly only (ADR-0017), so its absence here means it runs nowhere"
  [ -d "$OOLITE/tests/gui" ] \
    || fail gui "upstream/oolite/tests/gui does not exist; there is no GUI tier to run and a green from this stage would be vacuous"

  # gui-tier.sh sets OO_GUI_REQUIRE=1 itself. Set it here too so that a future edit which drops it
  # from the script cannot silently turn this stage into a platform skip.
  ( cd "$REPO_ROOT" && OO_GUI_REQUIRE=1 OO_APP_DIR="$(native "$APP_DIR")" \
      bash "$HERE/gui-tier.sh" ) > "$log" 2>&1 || rc=$?

  local passed skipped
  passed="$(grep -oE '[0-9]+ passed' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  skipped="$(grep -oE '[0-9]+ skipped' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  if [ "$rc" -ne 0 ]; then
    tail -25 "$log" >&2
    fail gui "the GUI tier failed (rc=$rc, $passed passed, $skipped skipped); $(native "$log")"
  fi
  # THE anti-vacuity assertion for this stage. OO_GUI_REQUIRE=1 is supposed to make a
  # platform/dependency skip fail; if a skip still got through, rc=0 with 0 passed is exactly the
  # silent green this tier exists to prevent.
  [ "${passed:-0}" -ge "$GUI_TEST_FLOOR" ] \
    || fail gui "the GUI tier reported ${passed:-0} passing test(s) (and ${skipped:-0} skipped), fewer than the floor of $GUI_TEST_FLOOR -- OO_GUI_REQUIRE=1 was supposed to turn a skip into a failure, so a green here means the window never opened"
  [ "${skipped:-0}" -eq 0 ] \
    || fail gui "the GUI tier SKIPPED ${skipped} test(s); under OO_GUI_REQUIRE=1 a skip is a failure, because 'G1 passed' and 'G1 never ran' must not look alike"
  detail "$passed GUI test(s) passed, 0 skipped, in $(( SECONDS - t0 ))s"
}

# ================================================================================================
# STAGE fleetdata -- THE TEST TIER B DESELECTS
# ================================================================================================
#
# tools/tier-b.sh:149-156 deliberately deselects ONE test, with its reason recorded: it asserts the
# committed docs/fleet/REPORT-<date>.md still agrees with the LIVE beads database, so it goes red
# whenever anyone files or closes a bead. That is intolerable per-commit and exactly right on a
# merge, where a stale committed report IS actionable. Running it here is what stops that
# deselection from being a permanent hole.
stage_fleetdata() {
  local t0=$SECONDS log="$RUN_ROOT/fleetdata.log" rc=0
  step fleetdata "$FLEET_TEST (deselected by tier-b, run here)"
  [ -f "$REPO_ROOT/tests/fleet/test_fleet_reporter.py" ] \
    || fail fleetdata "tests/fleet/test_fleet_reporter.py does not exist; the test tier-b deselects has moved or been deleted, so tier-b's deselection is now a permanent hole -- repoint this stage rather than dropping it"
  ( cd "$REPO_ROOT" && "$PY" -m pytest "$FLEET_TEST" -q -p no:cacheprovider ) > "$log" 2>&1 || rc=$?
  local passed
  passed="$(grep -oE '[0-9]+ passed' "$log" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  [ "$rc" -eq 0 ] || { tail -25 "$log" >&2
    fail fleetdata "the deselected fleet-report test failed (rc=$rc, $passed passed): the committed docs/fleet/REPORT-*.md no longer agrees with the beads database. Regenerate it; $(native "$log")"; }
  # A pytest run that selected NOTHING (a renamed node id) exits 5, but one that deselected
  # everything can exit 0. The count is the evidence.
  [ "${passed:-0}" -ge "$FLEET_TEST_FLOOR" ] \
    || fail fleetdata "the fleet-report test collected ${passed:-0} passing test(s), fewer than the floor of $FLEET_TEST_FLOOR -- the node id no longer resolves and this stage tested nothing"
  detail "$passed test(s) passed in $(( SECONDS - t0 ))s"
}

# ================================================================================================

RAN=0
for st in "${SELECTED[@]}"; do
  case "$st" in
    tier-b)    stage_tier_b ;;
    jsapi)     stage_jsapi ;;
    asan)      stage_asan ;;
    goldens)   stage_goldens ;;
    corpus)    stage_corpus ;;
    gui)       stage_gui ;;
    fleetdata) stage_fleetdata ;;
    *) die "internal: no runner for stage '$st'" ;;
  esac
  RAN=$(( RAN + 1 ))
done

# The selection and the execution must agree. If they ever do not, the gate ran a different plan
# from the one it printed, and that is the failure this tier is least able to notice by itself.
[ "$RAN" -eq "${#SELECTED[@]}" ] \
  || fail composition "selected ${#SELECTED[@]} stage(s) but ran $RAN; the plan and the execution disagree"

ELAPSED=$(( SECONDS - STARTED_AT ))
printf '\n'
if [ "$ELAPSED" -gt "$BUDGET_SECONDS" ]; then
  printf 'tier-c: GREEN but OVER BUDGET: %ss > %ss.\n' "$ELAPSED" "$BUDGET_SECONDS" >&2
  exit 1
fi
printf 'tier-c: GREEN in %ss (%d stage(s): %s; budget %ss)\n' \
  "$ELAPSED" "$RAN" "${SELECTED[*]}" "$BUDGET_SECONDS"
