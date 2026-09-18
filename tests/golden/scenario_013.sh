#!/usr/bin/env bash
#
# Golden scenario 013 (load the Constrictor checklist save) - the runnable entry point.
#
#   scenario_013.sh --check             one run: mission-state evidence + golden diff + frame
#   scenario_013.sh --stability N       N runs: per-run wall time, REFUSED vs DIFFERED vs FAILED
#   scenario_013.sh --differential      the control arms: a DIFFERENT save, and no save at all
#
# WHY A SHELL WRAPPER AND NOT JUST THE PYTHON - three things an acceptance line must not be
# trusted to remember:
#
#   1. PATH. /ucrt64/bin must be on PATH or oolite.exe dies with 3221225781
#      (STATUS_DLL_NOT_FOUND) and writes no log at all.
#   2. THE APP DIR IS NOT IN THE WORKTREE. Worktrees are source-only; the build lives in the main
#      checkout, so it is pointed at explicitly and `test -d` is asserted up front.
#   3. REFUSED IS NOT DIFFERED. rc=2 (the comparison was unsound) is reported separately from
#      rc=1 (a real difference) and rc=3 (the run itself failed). Collapsing them is how
#      "3 runs correctly refused to dump" gets reported as "3 failures", or worse, how
#      "I cannot tell you" gets read as "they match".
#
# EVERY RUN'S STDOUT AND STDERR IS CAPTURED REGARDLESS OF EXIT CODE, and the dump is looked for on
# disk rather than inferred from the return code: a sibling harness recorded results only when
# returncode==0 and thereby hid runs that wrote a correct dump but exited nonzero, reporting
# "1/10 dumped" when four byte-identical dumps existed.
set -u

cd "$(dirname "$0")/../.." || exit 2
export PATH=/ucrt64/bin:$PATH

APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
SCEN="tests/golden/constrictor_save.py"
CHECKER="tests/golden/check_constrictor_evidence.py"
SCRATCH="${LOCALAPPDATA:-$HOME}/Temp/oo_5h8e_scenario"

die() { printf 'scenario-013: %s\n' "$*" >&2; exit 2; }

[ -d "$APP_DIR" ] || die "no Oolite build at $APP_DIR (worktrees are source-only; set OO_APP_DIR)"
command -v python3 >/dev/null 2>&1 || die "python3 not on PATH (expected /ucrt64/bin/python3)"

mkdir -p "$SCRATCH" || die "cannot create scratch dir $SCRATCH"
NSCRATCH=$(cygpath -m "$SCRATCH" 2>/dev/null || echo "$SCRATCH")

# The guarded goldens/ path FIRST, the pending staging path second, through the IDENTICAL idiom,
# so these lines keep working after a human approval moves the files.
G=$(ls goldens/windows-x64/013-constrictor/state.json \
       tests/golden/pending/013-constrictor/state.json 2>/dev/null | head -1)
F=$(ls goldens/windows-x64/013-constrictor/frame.grid \
       tests/golden/pending/013-constrictor/frame.grid 2>/dev/null | head -1)

mode="${1:---check}"

case "$mode" in
  --check)
    out="$NSCRATCH/check-$$.json"
    grid="$NSCRATCH/check-$$.grid"
    rm -f "$out" "$grid"
    echo "== one run: load Constrictor.oolite-save and assert its MISSION STATE =="
    python3 "$SCEN" --app-dir "$APP_DIR" --out "$out" --frame-out "$grid" \
      --run-root "$NSCRATCH/runs"; rc=$?
    case "$rc" in
      0) : ;;
      1) echo "scenario-013: DIFFERED" >&2; exit 1 ;;
      2) echo "scenario-013: REFUSED - the run was unsound, no verdict given" >&2; exit 2 ;;
      *) echo "scenario-013: the run itself FAILED (rc=$rc)" >&2; exit "$rc" ;;
    esac

    echo
    echo "== the dump proves THIS SAVE's mission state, not merely that a game started =="
    python3 "$CHECKER" "$out" --label "fresh run" || exit 1

    if [ -n "$G" ] && [ -f "$G" ]; then
      echo
      echo "== regression pin: the fresh dump vs the stored golden (byte-wise) =="
      python3 tests/golden/golden_diff.py "$G" "$out" \
        --label-left "stored golden" --label-right "fresh run"; grc=$?
      case "$grc" in
        0) : ;;
        1) echo "scenario-013: the fresh run DIFFERS from the golden (a finding to investigate," \
                "not a file to rewrite)" >&2; exit 1 ;;
        *) echo "scenario-013: golden comparison REFUSED (rc=$grc)" >&2; exit 2 ;;
      esac
    fi
    if [ -n "$F" ] && [ -f "$F" ]; then
      echo
      echo "== the frame, compared with the MEASURED tolerance and NEVER byte-hashed =="
      python3 "$SCEN" --compare-frame "$grid" "$F" || {
        echo "scenario-013: the rendered frame is beyond the measured tolerance" >&2; exit 1; }
    fi
    rm -f "$out" "$grid"
    echo
    echo "scenario-013: PASS"
    ;;

  --stability)
    n="${2:-10}"
    echo "== $n runs; per-run wall time; REFUSED reported separately from DIFFERED; the dump is"
    echo "   looked for ON DISK, not inferred from the return code =="
    dumped=0; refused=0; differed=0; failed=0; nonzero_but_dumped=0
    first=""
    for i in $(seq 1 "$n"); do
      out="$NSCRATCH/stab-$$-$i.json"
      log="$SCRATCH/stab-$$-$i.log"
      rm -f "$out"
      start=$(date +%s)
      python3 "$SCEN" --app-dir "$APP_DIR" --out "$out" --frame-out "$NSCRATCH/stab-$$-$i.grid" \
        --run-root "$NSCRATCH/runs" >"$log" 2>&1
      rc=$?
      wall=$(( $(date +%s) - start ))
      note=""
      # THE DUMP IS EVIDENCE WHEREVER THE RETURN CODE LANDED.
      if [ -s "$SCRATCH/stab-$$-$i.json" ] || [ -s "$out" ]; then
        dumped=$((dumped + 1))
        [ "$rc" -eq 0 ] || { nonzero_but_dumped=$((nonzero_but_dumped + 1));
                             note=" <-- WROTE A DUMP BUT EXITED rc=$rc"; }
        md5=$(python3 -c "import hashlib,sys;print(hashlib.md5(open(sys.argv[1],'rb').read()).hexdigest())" "$out")
        # GNU md5sum prefixes a backslash when the filename contains one, silently truncating a
        # naively extracted digest to 31 characters. Computed in python for that reason, and
        # checked anyway (bead oo-jor).
        [ "${#md5}" -eq 32 ] || die "digest is ${#md5} chars, not 32: $md5"
        [ -n "$first" ] || first="$md5"
        [ "$md5" = "$first" ] || note="$note   <-- DIFFERS from run 1"
        printf '  run %-3s rc=%s DUMPED    wall=%3ss bytes=%-6s md5=%s%s\n' \
          "$i" "$rc" "$wall" "$(wc -c < "$out")" "$md5" "$note"
      else
        case "$rc" in
          1) differed=$((differed + 1)); tag="DIFFERED " ;;
          2) refused=$((refused + 1));   tag="REFUSED  " ;;
          *) failed=$((failed + 1));     tag="FAILED   " ;;
        esac
        printf '  run %-3s rc=%s %s wall=%3ss :: %s\n' "$i" "$rc" "$tag" "$wall" "$(tail -1 "$log")"
      fi
    done
    distinct=$(python3 - "$SCRATCH" "$$" <<'PY'
import glob, hashlib, os, sys
root, pid = sys.argv[1], sys.argv[2]
digests = {hashlib.md5(open(f, "rb").read()).hexdigest()
           for f in glob.glob(os.path.join(root, "stab-%s-*.json" % pid))
           if os.path.getsize(f)}
print(len(digests))
PY
)
    echo
    echo "  $dumped/$n dumped ($nonzero_but_dumped of them with a NONZERO exit code)," \
         "$distinct distinct digest(s); $refused REFUSED, $differed DIFFERED, $failed FAILED"
    if [ "$dumped" -lt 2 ]; then
      echo "  *** FEWER THAN 2 RUNS PRODUCED A DUMP. There is nothing to compare, and any" >&2
      echo "  *** statement about stability here would be a comparison over zero pairs." >&2
      rm -f "$SCRATCH"/stab-"$$"-*
      exit 1
    fi
    rm -f "$SCRATCH"/stab-"$$"-*
    [ "$dumped" -eq "$n" ] || exit 1
    [ "$distinct" -eq 1 ] || { echo "scenario-013: dumps are not byte-identical" >&2; exit 1; }
    echo "scenario-013: STABLE"
    ;;

  --differential)
    # THE CONTROL ARMS. A save-load golden that only proves "a game started" would pass against a
    # fresh commander with no mission at all. These two arms measure how far the mission state
    # moves when the SAVE changes, which is the thing this scenario claims to observe.
    echo "== arm 1: the SUBJECT (Constrictor.oolite-save) =="
    python3 "$SCEN" --app-dir "$APP_DIR" --out "$NSCRATCH/diff-sub-$$.json" \
      --frame-out "$NSCRATCH/diff-sub-$$.grid" --run-root "$NSCRATCH/runs" || exit 3
    echo
    echo "== arm 2: a DIFFERENT checklist save (ThargoidPlans, mission_conhunt=MISSION_COMPLETE) =="
    python3 "$SCEN" --app-dir "$APP_DIR" --control --out "$NSCRATCH/diff-ctl-$$.json" \
      --frame-out "$NSCRATCH/diff-ctl-$$.grid" --run-root "$NSCRATCH/runs" || exit 3
    echo
    echo "== arm 3: NO -load at all (a default new game) =="
    python3 "$SCEN" --app-dir "$APP_DIR" --fresh-control --out "$NSCRATCH/diff-fresh-$$.json" \
      --frame-out "$NSCRATCH/diff-fresh-$$.grid" --run-root "$NSCRATCH/runs" || exit 3
    echo
    python3 - "$NSCRATCH/diff-sub-$$.json" "$NSCRATCH/diff-ctl-$$.json" \
             "$NSCRATCH/diff-fresh-$$.json" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("cs", "tests/golden/constrictor_save.py")
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)
sub = json.load(open(sys.argv[1]))["evidence"]
bad = 0
for label, path in (("ThargoidPlans", sys.argv[2]), ("fresh game", sys.argv[3])):
    ctl = json.load(open(path))["evidence"]
    moved, same = cs.differential(sub, ctl, "Constrictor", label)
    print("== Constrictor vs %s: %d of %d mission-state field(s) MOVED"
          % (label, len(moved), len(moved) + len(same)))
    for line in moved:
        print("   MOVED  " + line)
    for line in same:
        print("   same   " + line)
    if not moved:
        print("   *** NO FIELD MOVED: the dump does not observe the loaded save at all. The "
              "golden would pass against %s and is therefore vacuous." % label)
        bad += 1
    print()
sys.exit(1 if bad else 0)
PY
    rc=$?
    # The evidence checker must REJECT both control arms; the subject must pass.
    python3 "$CHECKER" "$NSCRATCH/diff-sub-$$.json" --label "subject" || exit 1
    for arm in ctl fresh; do
      python3 "$CHECKER" "$NSCRATCH/diff-$arm-$$.json" --label "control $arm" >/dev/null 2>&1
      [ $? -eq 1 ] || { echo "scenario-013: the checker did NOT reject the $arm control arm; it " \
        "cannot tell this save from another" >&2; exit 1; }
      echo "  control $arm: REJECTED by the evidence checker (rc=1), as required"
    done
    rm -f "$NSCRATCH"/diff-*-"$$".json "$NSCRATCH"/diff-*-"$$".grid
    exit $rc
    ;;

  *)
    die "unknown mode '$mode' (expected --check, --stability N, --differential)"
    ;;
esac
