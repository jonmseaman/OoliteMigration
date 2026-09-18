#!/usr/bin/env bash
#
# Golden scenario 006 (save/load round-trip) - the runnable entry point.
#
#   scenario_006.sh --check             one run: round-trip invariant + evidence + golden diff
#   scenario_006.sh --stability N       N runs: report per-run wall time, REFUSED vs DIFFERED
#   scenario_006.sh --prove-detection   the negative controls: prove the gate can go RED
#   scenario_006.sh --audit-exclusions  every save key the census does not compare, with values
#
# WHY A SHELL WRAPPER AND NOT JUST THE PYTHON. Three reasons, all of them things an acceptance
# line must not be trusted to remember:
#
#   1. PATH. /ucrt64/bin must be on PATH or oolite.exe dies with 3221225781
#      (STATUS_DLL_NOT_FOUND) after ~116s of retries and writes no log at all - a long, silent,
#      log-free failure that reads like a busy machine and is actually an environment defect
#      (bead oo-gla).
#   2. THE APP DIR IS NOT IN THE WORKTREE. Worktrees are source-only; nobody builds in them and
#      nobody should. The build lives in the MAIN checkout, so it is pointed at explicitly and
#      `test -d` is asserted up front with an error naming the path, rather than failing deep
#      inside a launch (bead oo-ae9). OO_APP_DIR overrides, so this is not welded to one machine.
#   3. REFUSED IS NOT DIFFERED. The stability loop reports rc=2 (refused: the comparison was
#      unsound) separately from rc=1 (a real difference) and rc=3 (the run itself failed).
#      Collapsing them is how "3 runs correctly refused to dump" gets reported as "3 failures",
#      or worse, how "I cannot tell you" gets read as "they match".
set -u

cd "$(dirname "$0")/../.." || exit 2
export PATH=/ucrt64/bin:$PATH

APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
SCEN="tests/golden/save_load.py"
CHECKER="tests/golden/check_save_load_evidence.py"
STAGED="tests/golden/staged/006-save-load"
SAVE="$APP_DIR/Resources/Scenarios/oolite-standard.oolite-save"
SCRATCH="${LOCALAPPDATA:-$HOME}/Temp/oo_8ij_scenario"

die() { printf 'scenario-006: %s\n' "$*" >&2; exit 2; }

[ -d "$APP_DIR" ] || die "no Oolite build at $APP_DIR (worktrees are source-only; set OO_APP_DIR)"
[ -f "$SAVE" ]    || die "no save fixture at $SAVE"
command -v python3 >/dev/null 2>&1 || die "python3 not on PATH (expected /ucrt64/bin/python3)"

mkdir -p "$SCRATCH" || die "cannot create scratch dir $SCRATCH"

mode="${1:---check}"

case "$mode" in
  --audit-exclusions)
    exec python3 "$SCEN" --audit-exclusions --app-dir "$APP_DIR"
    ;;

  --check)
    out="$SCRATCH/check-$$.json"
    rm -f "$out"
    echo "== INVARIANT 1 (primary): the save file's bytes vs the state a SEPARATE game process"
    echo "   reports after loading them =="
    python3 "$SCEN" --app-dir "$APP_DIR" --out "$out"; rc=$?
    case "$rc" in
      0) : ;;
      1) echo "scenario-006: DIFFERED - the round-trip did not preserve the census" >&2; exit 1 ;;
      2) echo "scenario-006: REFUSED - the comparison was unsound, no verdict given" >&2; exit 2 ;;
      *) echo "scenario-006: the run itself FAILED (rc=$rc)" >&2; exit "$rc" ;;
    esac

    echo
    echo "== the dump carries positive evidence that a save was really loaded =="
    python3 "$CHECKER" "$out" || exit 1

    if [ -f "$STAGED/state.json" ]; then
      echo
      echo "== SECONDARY regression pin: the fresh dump vs the blessed golden =="
      python3 tests/golden/golden_diff.py "$STAGED/state.json" "$out" \
        --label-left "staged golden" --label-right "fresh run"
      grc=$?
      case "$grc" in
        0) : ;;
        1) echo "scenario-006: the fresh run DIFFERS from the golden (a finding to investigate," \
                "not a file to rewrite)" >&2; exit 1 ;;
        *) echo "scenario-006: golden comparison REFUSED (rc=$grc)" >&2; exit 2 ;;
      esac
    else
      echo
      echo "scenario-006: no blessed golden at $STAGED/state.json; the primary invariant above"
      echo "              stands on its own (that is the point of a self-checking scenario)."
    fi
    rm -f "$out"
    echo
    echo "scenario-006: PASS"
    ;;

  --stability)
    n="${2:-10}"
    echo "== $n runs; per-run wall time, and REFUSED reported separately from DIFFERED =="
    dumped=0; differed=0; refused=0; failed=0
    first=""
    for i in $(seq 1 "$n"); do
      out="$SCRATCH/stab-$$-$i.json"
      start=$(date +%s)
      python3 "$SCEN" --app-dir "$APP_DIR" --out "$out" >"$SCRATCH/stab-$$-$i.log" 2>&1; rc=$?
      wall=$(( $(date +%s) - start ))
      case "$rc" in
        0)
          dumped=$((dumped + 1))
          md5=$(python3 -c "import hashlib,sys;print(hashlib.md5(open(sys.argv[1],'rb').read()).hexdigest())" "$out")
          # Assert the digest is 32 hex chars: GNU md5sum prefixes a backslash when the filename
          # contains one, which silently truncates a naively extracted digest to 31 characters
          # and leaves a hash nobody can audit later (bead oo-jor). Computed in python here for
          # that reason, and checked anyway.
          [ "${#md5}" -eq 32 ] || die "digest is ${#md5} chars, not 32: $md5"
          [ -n "$first" ] || first="$md5"
          printf '  run %-3s rc=0 DUMPED    wall=%3ss md5=%s%s\n' "$i" "$wall" "$md5" \
            "$([ "$md5" = "$first" ] && echo "" || echo "   <-- DIFFERS from run 1")"
          ;;
        1) differed=$((differed + 1))
           printf '  run %-3s rc=1 DIFFERED  wall=%3ss :: %s\n' "$i" "$wall" "$(tail -1 "$SCRATCH/stab-$$-$i.log")" ;;
        2) refused=$((refused + 1))
           printf '  run %-3s rc=2 REFUSED   wall=%3ss :: %s\n' "$i" "$wall" "$(tail -1 "$SCRATCH/stab-$$-$i.log")" ;;
        *) failed=$((failed + 1))
           printf '  run %-3s rc=%s FAILED    wall=%3ss :: %s\n' "$i" "$rc" "$wall" "$(tail -1 "$SCRATCH/stab-$$-$i.log")" ;;
      esac
    done
    distinct=$(python3 - "$SCRATCH" "$$" <<'PY'
import glob, hashlib, os, sys
root, pid = sys.argv[1], sys.argv[2]
digests = {hashlib.md5(open(f, 'rb').read()).hexdigest()
           for f in glob.glob(os.path.join(root, "stab-%s-*.json" % pid))}
print(len(digests))
PY
)
    echo
    echo "  $dumped/$n dumped, $distinct distinct digest(s); $refused REFUSED, $differed DIFFERED, $failed FAILED"
    rm -f "$SCRATCH"/stab-"$$"-*.json "$SCRATCH"/stab-"$$"-*.log
    # A wall time under a second per run means no game was launched - an implausibly fast PASS is
    # an environment artefact, not a result (bead oo-gla).
    [ "$dumped" -eq "$n" ] || exit 1
    [ "$distinct" -eq 1 ] || { echo "scenario-006: dumps are not byte-identical" >&2; exit 1; }
    echo "scenario-006: STABLE"
    ;;

  --prove-detection)
    # THE NEGATIVE CONTROLS. A gate nobody has seen go red is not known to be a gate.
    echo "== control 1: perturb ONE census field by one unit in a THROWAWAY COPY of the save,"
    echo "   load THAT, and expect against the ORIGINAL. The difference must be NAMED. =="
    mut="$SCRATCH/perturbed-$$.oolite-save"
    python3 - "$SAVE" "$mut" <<'PY'
import plistlib, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, 'rb') as fh:
    data = plistlib.load(fh)
before = float(data['credits'])
data['credits'] = before + 10.0          # one credit, the smallest unit the field represents
with open(dst, 'wb') as fh:
    plistlib.dump(data, fh)
print("  perturbed credits %.1f -> %.1f in %s (NEVER in goldens/)" % (before, before + 10.0, dst))
PY
    python3 "$SCEN" --app-dir "$APP_DIR" --save "$mut" --expect-from "$SAVE"; rc=$?
    rm -f "$mut"
    [ "$rc" -eq 1 ] || { echo "scenario-006: expected rc=1 (DIFFERED), got rc=$rc - the" \
        "comparison does NOT detect a one-unit perturbation and is therefore not a gate" >&2; exit 1; }
    echo "  -> rc=1 DIFFERED, as required"

    echo
    echo "== control 2: the evidence checker must REJECT a dump from a run that never loaded =="
    python3 "$CHECKER" tests/golden/samples/006-vacuous-state.json; rc=$?
    [ "$rc" -eq 1 ] || { echo "scenario-006: expected rc=1, got rc=$rc - the checker accepts a" \
        "dump with no evidence of a load" >&2; exit 1; }
    echo "  -> rc=1 NO EVIDENCE, as required"

    echo
    echo "== control 3: comparing a dump with ITSELF must be REFUSED (rc=2), never reported"
    echo "   as a match =="
    ref="$STAGED/state.json"
    [ -f "$ref" ] || ref="tests/golden/samples/006-vacuous-state.json"
    python3 tests/golden/golden_diff.py "$ref" "$ref"; rc=$?
    [ "$rc" -eq 2 ] || { echo "scenario-006: expected rc=2 (REFUSED), got rc=$rc" >&2; exit 1; }
    echo "  -> rc=2 REFUSED, as required"

    echo
    echo "scenario-006: all three negative controls fired; the gate can go RED"
    ;;

  *)
    die "unknown mode '$mode' (expected --check, --stability N, --prove-detection, --audit-exclusions)"
    ;;
esac
