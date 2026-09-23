#!/usr/bin/env bash
# tools/tier-b-mutants.sh -- PROVE TIER B'S GOLDENS STAGE CAN FAIL (bead oo-1bf.10).
#
# Phase 0 exit-gate box 36 asks for evidence that "a deliberately perturbed market-price
# calculation is caught by the goldens stage, not by a reviewer". A gate nobody has watched go red
# is a gate nobody has tested, and a review that reads a diff is not a gate at all. So this script
# plants a real defect in the ENGINE's market-price path, builds the test flavour with it, runs
# Tier B's goldens stage against the BLESSED goldens, and requires a RED verdict that NAMES the
# golden whose market fields moved.
#
#     tools/tier-b-mutants.sh              # every arm
#     tools/tier-b-mutants.sh market-price # one arm by name
#     tools/tier-b-mutants.sh --list       # names only, run nothing
#
# Exemplar: tools/tier-c-mutants.sh. The shape is deliberately the same -- the RED assertion is on
# the STAGE NAME and the REASON, never merely on rc!=0 (bead oo-1xz lost an acceptance because a
# red-proof line got the right exit code from the WRONG stage), and every arm is TWO-SIDED.
#
# ------------------------------------------------------------------------------------------------
# WHY THE PROOF IS TWO-SIDED
# ------------------------------------------------------------------------------------------------
#
# An arm that only ever shows red proves nothing about what it detects: a tier that is red on every
# tree is red for free. So each arm runs the SAME goldens stage twice against the SAME scratch
# build tree, changing exactly one thing:
#
#   CONTROL  perturbation ABSENT  -> the goldens stage must report "stage goldens ok"
#   MUTANT   perturbation PRESENT -> it must report "FAIL (stage goldens)" AND name the scenario
#                                    AND show a market.<good>.price field that moved
#
# The CONTROL is judged on the stage's own success line, not on an exit code, for the same reason
# the MUTANT is judged on "FAIL (stage goldens)": a proof that accepts any exit code passes for the
# wrong reason in both directions.
#
# ------------------------------------------------------------------------------------------------
# WHY THE GOLDENS STAGE IS RUN IN ISOLATION -- MEASURED, NOT ASSUMED
# ------------------------------------------------------------------------------------------------
#
# The obvious implementation drives the whole of `tools/tier-b.sh --fast` and greps its output.
# That was tried first and it DOES NOT WORK, for a reason worth recording:
#
#   tier-b runs its stages in cost order and STOPS AT THE FIRST RED ONE. Stage 2 (tests) precedes
#   stage 3 (goldens). Measured on the mutant arm: 'tier-b: FAIL (stage tests): tests/golden failed
#   (pytest rc=1, 1015 passed)' after 68 s, with three failures --
#     test_launch_preflight.py::test_walker_finds_the_gallium_deps_when_the_runtime_dir_is_absent_from_path
#     test_launch_preflight.py::test_preflight_repairs_path_and_is_idempotent
#     test_launch_preflight.py::test_preflight_raises_a_named_error_when_no_directory_can_supply_the_dlls
#   -- i.e. the Mesa/gallium staging order-dependence that tier-b.sh's own stage_mesa comment
#   documents, NOT the market price. The perturbation was never reached. So the failure that
#   pre-empts the goldens stage here is an ENVIRONMENT artefact of a freshly built scratch app dir,
#   and an arm that accepted it would have banked a kill it did not earn. The harness refused it
#   ("right exit code, WRONG stage") and that refusal is why this note can be written at all.
#
# tier-b.sh has no stage selector (--fast and --list are its only switches) and adding one is out
# of scope for this bead, so the arm drives stage 3 DIRECTLY. This is a reimplementation of the
# stage's DRIVER only -- the discovery rule, the private-port discipline, the runners and the
# comparison are the REAL ones tier-b stage 3 invokes:
#
#     tests/golden/dump/run_dump.py            (scenario 001)
#     tests/golden/launch_dock.py              (scenario 001-launch-dock)
#     tests/golden/golden_diff.py              THE comparison, with its 0/1/2 rc convention
#     tests/golden/check_launch_dock_evidence.py
#
# A hand-rolled diff would prove nothing about the gate, so there is none here. goldens_stage()
# below is deliberately a transcription of tier-b.sh's stage_goldens, including its failure text,
# so the string this arm asserts on is the string tier-b prints.
#
# The CONTROL arm was ALSO measured through the unmodified full tier-b once, to confirm the
# isolated stage agrees with the real one: 'stage goldens ok: 2 scenario(s) in 28s', 001 MATCH 6s,
# 001-launch-dock MATCH 19s. Set OOLITE_TIER_B_MUTANTS_FULL=1 to repeat that (it costs ~19 min,
# almost all of it stages this arm does not judge).
#
# ------------------------------------------------------------------------------------------------
# WHICH GOLDENS THIS ARM TARGETS, AND WHY NOT 004 / 019
# ------------------------------------------------------------------------------------------------
#
# The bead body named scenario 004 (trade-cycle) and 019 (equipment pin prices). THOSE SCENARIOS
# ARE NOT BLESSED. `ls goldens/windows-x64/` returns exactly two directories, 001 and
# 001-launch-dock; 002-017 are staged under tests/golden/pending/ awaiting a human re-bless
# (goldens/ is guarded by tools/guardrails.sh + tools/rebless-approvals.txt, and CREATING a golden
# is refused just as loudly as modifying one -- bead oo-8ij), and 018-020 are newer still.
# tier-b.sh's stage 3 compares "every blessed golden under goldens/<platform>/" and NOTHING else,
# so an arm that required 004 or 019 to move could not go red on any tree, fixed or broken: it
# would be exactly the vacuous proof this bead exists to prevent, and a green-only replay could
# never reveal that. This arm therefore targets the BLESSED corpus, where both scenarios carry a
# full 17-commodity market.<good>.price table. Nothing under goldens/ is blessed, created, edited
# or touched by this script.
#
# ------------------------------------------------------------------------------------------------
# MUTATION SAFETY -- READ BEFORE ADDING AN ARM
# ------------------------------------------------------------------------------------------------
#
# This script plants a defect in ENGINE SOURCE. It NEVER edits a file in the repository, not even
# with a restore-on-exit trap: a trap does not run when the process is killed at a timeout, and
# the fleet's harvest commits whatever is on disk at that instant. That has happened twice in this
# project -- bead oo-dto was harvested with `if False:` in place of the one predicate its gate was
# named for, and bead oo-qd6 left a 3-byte stub under the guarded goldens/ path and it was
# committed. So:
#
#   * the whole engine tree is COPIED to a throwaway directory under $TMPDIR first (~1 s, it is
#     source only);
#   * the perturbation is applied to the COPY and built in the COPY;
#   * the repository is only ever READ. Tracked-file cleanliness is asserted before and after every
#     arm, including on failure, so a kill at any instant leaves a clean tree.
#
# Kill this script at any point and the worst that survives is a directory under $TMPDIR.
#
# PROCESS HYGIENE. The goldens stage launches real games. Other agents launch theirs concurrently
# out of THEIR OWN trees, so this script never runs a blanket `taskkill` sweep over every
# oolite.exe: reap_own_games() kills only processes whose image path is under THIS run's scratch
# directory. A sibling's game is left strictly alone, and the live count is reported beside every
# result as a contention proxy (bead oo-rkm: a bare rc=1 cannot distinguish starvation from a
# defect, while "rc=1 wall=117s oolite_procs=4" diagnoses itself).

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO" || exit 2
[ -d /ucrt64/bin ] && export PATH="/ucrt64/bin:$PATH"
PY=python3; command -v $PY >/dev/null 2>&1 || PY=python
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

PLATFORM="${OOLITE_TIER_B_PLATFORM:-windows-x64}"
# tier-b.sh:131 -- the same anti-vacuity floor. A goldens stage with nothing to compare passes
# vacuously, so this arm refuses to testify about a corpus smaller than the tier's own minimum.
GOLDEN_FLOOR="${OOLITE_TIER_B_GOLDEN_FLOOR:-2}"

ARMS="market-price"
PASS=0; FAIL=0
ONLY="${1:-}"
case "$ONLY" in
  --list) printf '%s\n' $ARMS; exit 0 ;;
  -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
  "" ) ;;
  * ) printf '%s\n' $ARMS | grep -qx -- "$ONLY" || { printf 'tier-b-mutants: unknown arm %s (try --list)\n' "$ONLY" >&2; exit 2; } ;;
esac

SCRATCH=""
RUN_ROOT=""

hr() { printf '\n%s\n' "------------------------------------------------------------------------"; }
note() { printf '  %s\n' "$*"; }

# oolite_procs -- the contention proxy, reported and never acted on.
oolite_procs() { ps -W 2>/dev/null | grep -ci oolite || true; }

# reap_own_games -- kill ONLY games launched from this run's scratch tree. `ps -W` reports the
# Windows PID in field 4 and the image path in the remainder, so the path filter is what keeps a
# sibling's game (which lives under a completely different path) untouched. A bare `kill` or
# `taskkill //PID` silently fails under MSYS argument mangling; use the native binary with one
# slash (bead oo-rkm).
reap_own_games() {
  [ -n "$SCRATCH" ] || return 0
  local key
  key="$(basename "$SCRATCH")"
  local pid n=0
  while read -r pid; do
    [ -n "$pid" ] || continue
    /c/Windows/System32/taskkill.exe /PID "$pid" /F >/dev/null 2>&1 && n=$(( n + 1 ))
  done < <(ps -W 2>/dev/null | grep -i oolite | grep -F "$key" | awk '{print $4}')
  [ "$n" -gt 0 ] && note "reaped $n game process(es) launched from this run's scratch tree (siblings untouched)"
  return 0
}

cleanup() {
  reap_own_games
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then
    rm -rf "$SCRATCH" 2>/dev/null \
      || printf 'tier-b-mutants: could not fully remove %s (a handle is still held); remove it by hand\n' \
           "$(native "$SCRATCH")" >&2
  fi
  [ -n "$RUN_ROOT" ] && [ -d "$RUN_ROOT" ] && rm -rf "$RUN_ROOT" 2>/dev/null
  return 0
}
trap cleanup EXIT

# assert_repo_clean -- no TRACKED file may be modified or deleted at any checkpoint. This is the
# guard that makes the script safe to kill: if it fires, a mutation escaped into the repository and
# the arm stops rather than continuing to build evidence on a poisoned tree.
#
# Untracked entries ('??') are excluded on purpose and only those: a developer running this before
# committing the script itself must not be told a mutation escaped, while any M/D/A/R on a tracked
# path -- the only shape a leaked perturbation can take -- still aborts.
assert_repo_clean() {
  local where="$1" dirty
  dirty="$(git -C "$REPO" status --porcelain 2>/dev/null | grep -v '^??' || true)"
  if [ -n "$dirty" ]; then
    printf '\ntier-b-mutants: ABORT (%s): a tracked file is modified, so a mutation may have escaped the scratch tree:\n%s\n' \
      "$where" "$dirty" >&2
    exit 2
  fi
}

free_port() {
  "$PY" -c "
import socket
s = socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
"
}

# ------------------------------------------------------------------------------------------------
# stage_scratch_tree -- a throwaway copy of the engine plus the two build inputs build-windows.sh
# needs. Source only (~258 MB, under a second); the build directory is NOT copied, so the mutant is
# built in a tree no other agent shares. ccache makes the first build ~60 s even so.
# ------------------------------------------------------------------------------------------------
stage_scratch_tree() {
  local tmpbase="${TMPDIR:-${LOCALAPPDATA:-/tmp}/Temp}"
  [ -d "$tmpbase" ] || tmpbase=/tmp
  SCRATCH="$(mktemp -d "$tmpbase/tier-b-mutants-XXXXXX")" || { printf 'tier-b-mutants: cannot create a scratch dir\n' >&2; exit 2; }
  case "$SCRATCH" in
    "$REPO"*) printf 'tier-b-mutants: REFUSING -- the scratch dir %s is inside the repository\n' "$SCRATCH" >&2; exit 2 ;;
  esac
  mkdir -p "$SCRATCH/upstream" "$SCRATCH/tools/meson" || exit 2
  cp -a "$REPO/upstream/oolite" "$SCRATCH/upstream/oolite" || { printf 'tier-b-mutants: could not copy the engine tree\n' >&2; exit 2; }
  rm -rf "$SCRATCH/upstream/oolite/build"
  cp "$REPO/tools/build-windows.sh" "$SCRATCH/tools/" || exit 2
  cp "$REPO/tools/meson/ccache-clang.ini" "$SCRATCH/tools/meson/" || exit 2
  RUN_ROOT="$(mktemp -d "$tmpbase/tier-b-mutants-run-XXXXXX")" || exit 2
  note "scratch tree $(native "$SCRATCH")  (engine source only; the repo is never written)"
}

build_scratch() {
  # Declared separately: `local a="$1" b="$a"` does not see $a under `set -u` in this bash.
  local label="$1"
  local log="$SCRATCH/build-$label.log"
  local t0=$SECONDS
  if ! bash "$SCRATCH/tools/build-windows.sh" test > "$log" 2>&1; then
    tail -25 "$log" >&2
    printf 'tier-b-mutants: the %s build failed; full log %s\n' "$label" "$(native "$log")" >&2
    return 1
  fi
  local bin="$SCRATCH/upstream/oolite/build/meson_test/oolite.app/oolite.exe"
  [ -f "$bin" ] || { printf 'tier-b-mutants: the %s build reported success but there is no oolite.exe\n' "$label" >&2; return 1; }
  # Mesa beside the binary, exactly as tier-b.sh's stage_mesa does: a freshly built oolite.app has
  # no opengl32.dll / libgallium_wgl.dll and the game cannot render without them.
  local prefix="${MINGW_PREFIX:-/ucrt64}" dll
  for dll in opengl32.dll libgallium_wgl.dll; do
    [ -f "$prefix/bin/$dll" ] && cp -f "$prefix/bin/$dll" "$SCRATCH/upstream/oolite/build/meson_test/oolite.app/" 2>/dev/null
  done
  [ -f "$SCRATCH/upstream/oolite/build/meson_test/oolite.app/libgallium_wgl.dll" ] \
    || { printf 'tier-b-mutants: no libgallium_wgl.dll staged beside the %s binary; the launches would fail for an unrelated reason\n' "$label" >&2; return 1; }
  note "$(printf '%-8s build ok: %s bytes in %ss (%s)' "$label" "$(stat -c %s "$bin")" "$(( SECONDS - t0 ))" "$(grep -m1 'ccache this run' "$log" | sed 's/.*run: //')")"
  return 0
}

# ------------------------------------------------------------------------------------------------
# goldens_stage <label> -- TIER B STAGE 3, against the scratch build.
#
# A transcription of tier-b.sh's stage_goldens (discovery rule, GOLDEN_FLOOR, private console port
# per scenario, the debugConfig.plist that makes the port real for run_dump.py, golden_diff's
# 0/1/2 rc convention, the launch/dock evidence check) INCLUDING ITS FAILURE TEXT, so the string
# this arm asserts on is the string tier-b prints. The runners and the comparison are the real
# ones; nothing here re-implements a diff. See the header for why the stage is driven directly
# instead of through tier-b.sh.
#
# Writes its transcript to $RUN_ROOT/<label>.out and echoes the path.
# ------------------------------------------------------------------------------------------------
goldens_stage() {
  local label="$1"
  local app="$SCRATCH/upstream/oolite/build/meson_test/oolite.app"
  local gdir="$REPO/goldens/$PLATFORM"
  local work="$RUN_ROOT/$label"
  local transcript="$RUN_ROOT/$label.out"
  mkdir -p "$work"
  : > "$transcript"
  local t0=$SECONDS

  {
    printf '==> [goldens] every blessed scenario under goldens/%s (floor %s)\n' "$PLATFORM" "$GOLDEN_FLOOR"

    local names=() dir
    for dir in "$gdir"/*/; do
      [ -f "$dir/state.json" ] || continue
      names+=("$(basename "$dir")")
    done
    local n=${#names[@]}
    if [ "$n" -lt "$GOLDEN_FLOOR" ]; then
      printf 'tier-b: FAIL (stage goldens): found %s blessed scenario(s) under %s, fewer than the floor of %s -- a golden stage with nothing to compare passes vacuously\n' \
        "$n" "$(native "$gdir")" "$GOLDEN_FLOOR"
      return 1
    fi

    local name ok=0
    for name in "${names[@]}"; do
      local out="$work/$name.json" log="$work/$name.log" port rc=0 s=$SECONDS
      port="$(free_port)"
      case "$name" in
        001-launch-dock)
          # launch_dock.py reserves its own port, stages a private app dir and writes its own
          # debugConfig.plist, so this one only needs a private run root.
          ( cd "$REPO" && "$PY" "$(native "$REPO/tests/golden/launch_dock.py")" \
              --app-dir "$(native "$app")" --out "$(native "$out")" \
              --run-root "$(native "$work/ld-$name")" ) > "$log" 2>&1 || rc=$?
          ;;
        *)
          # run_dump.py takes a --port but does NOT write the plist that makes it real, so the game
          # would dial the default 8563 and be answered by whatever sibling is listening there
          # (bead oo-gla). Write the plist into a private OO_ADDITIONALADDONSDIRS ourselves.
          local cfg="$work/cfg-$name/Config"
          mkdir -p "$cfg"
          "$PY" -c "
import plistlib, sys
plistlib.dump({'console-host': '127.0.0.1', 'console-port': int(sys.argv[2])},
              open(sys.argv[1], 'wb'), fmt=plistlib.FMT_XML)
" "$(native "$cfg/debugConfig.plist")" "$port" \
            || { printf 'tier-b: FAIL (stage goldens): could not write the private debugConfig.plist for %s\n' "$name"; return 1; }
          ( cd "$REPO" \
            && OO_ADDITIONALADDONSDIRS="$(native "$work/cfg-$name")" \
               "$PY" "$(native "$REPO/tests/golden/dump/run_dump.py")" \
                 --app-dir "$(native "$app")" --port "$port" \
                 --out "$(native "$out")" --output-dir "$(native "$work/out-$name")" ) > "$log" 2>&1 || rc=$?
          ;;
      esac
      local wall=$(( SECONDS - s ))
      if [ "$rc" -ne 0 ]; then
        tail -20 "$log"
        printf 'tier-b: FAIL (stage goldens): scenario %s did not produce a dump (rc=%s after %ss); %s\n' \
          "$name" "$rc" "$wall" "$(native "$log")"
        return 1
      fi
      [ -s "$out" ] || { printf 'tier-b: FAIL (stage goldens): scenario %s exited 0 but wrote no dump\n' "$name"; return 1; }

      # golden_diff.py's rc convention (bead oo-jor): 0 = verified equal, 1 = a real difference,
      # 2 = REFUSED (unreadable, empty, self-comparison, off-policy quantisation). 2 is never a pass.
      local drc=0
      "$PY" "$(native "$REPO/tests/golden/golden_diff.py")" \
        "$(native "$gdir/$name/state.json")" "$(native "$out")" > "$work/diff-$name.log" 2>&1 || drc=$?
      case "$drc" in
        0) : ;;
        1) sed -n '1,25p' "$work/diff-$name.log"
           printf 'tier-b: FAIL (stage goldens): scenario %s DIFFERS from its blessed golden (golden_diff rc=1)\n' "$name"
           return 1 ;;
        *) sed -n '1,25p' "$work/diff-$name.log"
           printf 'tier-b: FAIL (stage goldens): scenario %s could not be compared (golden_diff rc=%s = refused); a refusal is not a pass\n' "$name" "$drc"
           return 1 ;;
      esac

      if [ -f "$REPO/tests/golden/check_launch_dock_evidence.py" ] && [ "$name" = "001-launch-dock" ]; then
        if ! "$PY" "$(native "$REPO/tests/golden/check_launch_dock_evidence.py")" "$(native "$out")" \
             > "$work/ev-$name.log" 2>&1; then
          cat "$work/ev-$name.log"
          printf 'tier-b: FAIL (stage goldens): scenario %s matched its golden but failed its own launch/dock evidence check\n' "$name"
          return 1
        fi
        printf '    %s\n' "$(head -1 "$work/ev-$name.log" | sed 's|.*/||')"
      fi
      printf '    %s\n' "$(printf '%-18s MATCH  %3ds  port %s' "$name" "$wall" "$port")"
      ok=$(( ok + 1 ))
    done
    [ "$ok" -eq "$n" ] || { printf 'tier-b: FAIL (stage goldens): %s of %s scenarios verified\n' "$ok" "$n"; return 1; }
    printf '    stage goldens ok: %s scenario(s) in %ss\n' "$ok" "$(( SECONDS - t0 ))"
    return 0
  } > "$transcript" 2>&1
  local src=$?
  note "goldens stage ($label): rc=$src wall=$(( SECONDS - t0 ))s oolite_procs=$(oolite_procs) transcript $(native "$transcript")"
  reap_own_games
  return $src
}

# ================================================================================================
# ARM market-price
# ================================================================================================
#
# THE PERTURBATION, and why this one.
#
# The price a market screen, a trade script and the state dump all read is whatever was last
# written through -[OOCommodityMarket setPrice:forGood:]
# (upstream/oolite/src/Core/OOCommodityMarket.m): every path that computes a price -- OOCommodities'
# generatePriceForGood:/adjustPrice:byRule: for a generated market, loadStationAmounts: for a
# restored one, StationEntity's setPrice:forCommodity: for a scripted one -- converges on that one
# setter, and -priceForGood: reads the value straight back out. Perturbing it by ONE decicredit is
# therefore the smallest edit that changes the market price of every good the blessed scenarios
# record, and it is the kind of off-by-one a reviewer skims past: `price + 1` in a four-line setter
# reads like rounding.
#
# TWO REJECTED CANDIDATES, recorded because they cost a build each and would look like better
# choices to the next person:
#
#   * OOCommodities.m generatePriceForGood: `base += econ + random` -> `base -= econ + random`.
#     Built and run: the goldens stage stayed GREEN. Scenario 001 restores a saved commander, and
#     PlayerEntity.m:1124 saves the station market into the save file's `localMarket` array, which
#     StationEntity -setLocalMarket: replays through loadStationAmounts:. The generator never runs
#     for this scenario, so that mutant is EQUIVALENT here.
#   * OOCommodities.m adjustPrice:byRule: `p * pm` -> `p * pm * 3.0`. Same result, same reason
#     (that path serves stations carrying a marketDefinition, not the restored main-system market).
#
# That is the useful half of a surviving mutant: it said which code the blessed goldens actually
# execute. The arm perturbs the path the scenarios DO run.
arm_market_price() {
  hr
  printf 'ARM market-price\n  perturbs: -[OOCommodityMarket setPrice:forGood:] (+1 decicredit), in a scratch tree\n'
  printf '  expects: CONTROL green at the goldens stage, MUTANT red naming a blessed golden whose market price moved\n\n'

  assert_repo_clean "before staging"
  stage_scratch_tree

  local src="$SCRATCH/upstream/oolite/src/Core/OOCommodityMarket.mm"
  [ -f "$src" ] || { printf '  RESULT: cannot find OOCommodityMarket.m in the scratch tree\n'; FAIL=$(( FAIL + 1 )); return 1; }

  # ---- CONTROL: the perturbation is ABSENT ------------------------------------------------------
  printf '\n  --- CONTROL (perturbation absent) ---\n'
  build_scratch control || { FAIL=$(( FAIL + 1 )); return 1; }

  if [ -n "${OOLITE_TIER_B_MUTANTS_FULL:-}" ]; then
    # Optional parity run: the WHOLE tier, unperturbed, to confirm the isolated stage above agrees
    # with tier-b's own stage 3. Off by default -- measured at ~19 min, almost all of it in stages
    # this arm does not judge.
    local flog="$RUN_ROOT/tier-b-full.log" frc=0 ft0=$SECONDS
    ( cd "$REPO" && OO_APP_DIR="$(native "$SCRATCH/upstream/oolite/build/meson_test/oolite.app")" \
        bash "$REPO/tools/tier-b.sh" --fast ) > "$flog" 2>&1 || frc=$?
    note "full tier-b --fast (parity, unperturbed): rc=$frc wall=$(( SECONDS - ft0 ))s $(grep -c 'stage goldens ok' "$flog" || true) goldens-ok line(s)"
    grep -F 'stage goldens ok' "$flog" | sed 's/^/    | /'
    reap_own_games
  fi

  local cout crc=0
  goldens_stage control || crc=$?
  cout="$(cat "$RUN_ROOT/control.out")"
  assert_repo_clean "after the control arm"
  if [ "$crc" -eq 0 ] && printf '%s' "$cout" | grep -qF 'stage goldens ok'; then
    note "CONTROL: $(printf '%s\n' "$cout" | grep -F 'stage goldens ok' | tail -1 | sed 's/^ *//')"
    printf '%s\n' "$cout" | grep -F 'MATCH' | sed 's/^ */    | /'
    note "CONTROL RESULT: GREEN -- the arm can pass, so a red verdict below is not free."
    PASS=$(( PASS + 1 ))
  else
    printf '%s\n' "$cout" | tail -12 | sed 's/^/    | /'
    note "CONTROL RESULT: the goldens stage did NOT report success on an UNPERTURBED build (rc=$crc)."
    note "  Without a green control the mutant's red proves nothing, so this arm FAILS here."
    FAIL=$(( FAIL + 1 )); return 1
  fi

  # ---- MUTANT: the perturbation is PRESENT ------------------------------------------------------
  printf '\n  --- MUTANT (perturbation present) ---\n'
  $PY - "$src" <<'PYEOF' || { printf '  RESULT: could not apply the perturbation\n'; FAIL=$(( FAIL + 1 )); return 1; }
import pathlib, sys
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding="utf-8", errors="surrogateescape")
old = "\t[definition oo_setUnsignedInteger:price forKey:kOOCommodityPriceCurrent];"
if t.count(old) != 1:
    raise SystemExit("setPrice:forGood: no longer has the expected body (%d matches); "
                     "repoint the perturbation rather than loosening the match" % t.count(old))
p.write_text(t.replace(old, "\t[definition oo_setUnsignedInteger:price + 1 forKey:kOOCommodityPriceCurrent];"),
             encoding="utf-8", errors="surrogateescape")
print("  perturbation applied to the SCRATCH copy of OOCommodityMarket.m: price -> price + 1")
PYEOF
  build_scratch mutant || { FAIL=$(( FAIL + 1 )); return 1; }
  local mout mrc=0
  goldens_stage mutant || mrc=$?
  mout="$(cat "$RUN_ROOT/mutant.out")"
  assert_repo_clean "after the mutant arm"

  # The verdict. Three independent assertions, because any one alone passes for the wrong reason:
  # rc!=0 alone accepts a failure anywhere; the stage name alone accepts a golden that moved for an
  # unrelated reason; the moved field alone could come from a diff nobody acted on.
  local named_scenario moved_field
  named_scenario="$(printf '%s\n' "$mout" | grep -oE 'scenario [0-9][A-Za-z0-9.-]* DIFFERS from its blessed golden' | head -1)"
  moved_field="$(printf '%s\n' "$mout" | grep -oE 'market\.[a-z_]+\.price: [0-9]+ != [0-9]+' | head -1)"

  printf '%s\n' "$mout" | grep -E 'tier-b: FAIL|market\.[a-z_]+\.price|DIFFERENCES' | head -8 | sed 's/^/    | /'
  if [ "$mrc" -eq 0 ]; then
    note "MUTANT RESULT: SURVIVED -- the goldens stage stayed GREEN with a perturbed market price. BLIND GATE."
    FAIL=$(( FAIL + 1 )); return 1
  fi
  if ! printf '%s' "$mout" | grep -qF 'tier-b: FAIL (stage goldens)'; then
    note "MUTANT RESULT: rc=$mrc but NOT from the goldens stage -- right exit code, WRONG stage."
    note "  A stage can fail for a missing binary or a staging fault; that is not this arm's evidence."
    FAIL=$(( FAIL + 1 )); return 1
  fi
  if [ -z "$named_scenario" ] || [ -z "$moved_field" ]; then
    note "MUTANT RESULT: the goldens stage went red but did not NAME the golden and the moved field"
    note "  (scenario='${named_scenario:-none}', field='${moved_field:-none}'); a red verdict a reader"
    note "  cannot attribute to the market price is not the evidence box 36 asks for."
    FAIL=$(( FAIL + 1 )); return 1
  fi
  note "MUTANT RESULT: KILLED by the GOLDENS stage (rc=$mrc)"
  note "  named:  $named_scenario"
  note "  moved:  $moved_field   <- a blessed golden's market price, caught by the gate, not by a reviewer"
  PASS=$(( PASS + 1 ))

  # Restoring is a rm -rf of a directory nothing else references, which is the point of mutating a
  # copy: there is no in-tree edit to undo and therefore no window in which a kill leaves a defect.
  reap_own_games
  rm -rf "$SCRATCH"; SCRATCH=""
  assert_repo_clean "after restore"
  note "RESTORED: the scratch tree is deleted and no tracked file is modified."
  return 0
}

# ================================================================================================

[ -d "$REPO/goldens/$PLATFORM" ] || { printf 'tier-b-mutants: no goldens/%s to prove anything against\n' "$PLATFORM" >&2; exit 2; }
printf '==> tier-b-mutants (%s), blessed goldens: %s\n' "$PLATFORM" \
  "$(ls "$REPO/goldens/$PLATFORM" 2>/dev/null | tr '\n' ' ')"

if [ -z "$ONLY" ] || [ "$ONLY" = market-price ]; then
  arm_market_price || true
fi

hr
printf 'tier-b-mutants: %d assertion(s) passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
