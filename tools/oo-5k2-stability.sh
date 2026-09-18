#!/usr/bin/env bash
# Bead oo-5k2: multi-run stability sweep for golden scenario 007-js-interface.
#
# Reports MATCH / DIFFERS / REFUSED / BROKEN as FOUR SEPARATE COUNTS, per bead oo-jor. A run that
# REFUSES to dump (its own guards caught an unsettled world, a rig that did not finish, an
# unexpected error line) is the instrument working, not a failure, and collapsing it into
# "failed" is how a stability claim becomes dishonest. golden_diff.py uses the same convention:
# rc=2 REFUSED ("I cannot tell you"), rc=1 DIFFERS, rc=0 verified equal.
#
# Per-run WALL TIME is reported because an implausibly fast pass is an environment artefact
# (bead oo-gla: three "runs" that claimed byte-identical dumps in six seconds were all talking to
# a leftover game on a shared port).
set -u
cd "$(dirname "$0")/.." || exit 1

RUNS="${1:-5}"
OUT="${2:-$LOCALAPPDATA/Temp/oo5k2_stability}"
OUT="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
rm -rf "$OUT"; mkdir -p "$OUT" || exit 1

export PATH=/ucrt64/bin:$PATH

match=0; differs=0; refused=0; broken=0
first=""
echo "== scenario 007-js-interface: $RUNS run(s) =="
for i in $(seq 1 "$RUNS"); do
  f="$OUT/run$i.json"
  s=$(date +%s)
  python3 tests/golden/js_interface.py --no-snapshot --out "$f" > "$OUT/run$i.log" 2>&1
  rc=$?
  e=$(( $(date +%s) - s ))
  if [ "$rc" -ne 0 ]; then
    # The scenario's own guards raise ScenarioError and the CLI prints it; that is a REFUSAL to
    # bless a dump it knows is not comparable. Anything else is BROKEN.
    if grep -q 'ScenarioError' "$OUT/run$i.log"; then
      refused=$((refused+1)); verdict="REFUSED"
    else
      broken=$((broken+1)); verdict="BROKEN"
    fi
    printf 'run %-2s %-8s %4ss  %s\n' "$i" "$verdict" "$e" "$(grep -m1 '\[!\]' "$OUT/run$i.log" | cut -c1-140)"
    continue
  fi
  md5=$(md5sum "$f" | awk '{print $1}')
  if [ -z "$first" ]; then
    first="$f"
    printf 'run %-2s %-8s %4ss  md5=%s bytes=%s (reference)\n' "$i" "FIRST" "$e" "$md5" "$(wc -c < "$f")"
    continue
  fi
  python3 tests/golden/golden_diff.py "$first" "$f" > "$OUT/diff$i.log" 2>&1
  drc=$?
  case "$drc" in
    0) match=$((match+1));   verdict="MATCH" ;;
    1) differs=$((differs+1)); verdict="DIFFERS" ;;
    *) refused=$((refused+1)); verdict="REFUSED" ;;
  esac
  printf 'run %-2s %-8s %4ss  md5=%s bytes=%s\n' "$i" "$verdict" "$e" "$md5" "$(wc -c < "$f")"
  [ "$drc" -eq 1 ] && sed 's/^/        /' "$OUT/diff$i.log"
done

echo "-- MATCH=$match DIFFERS=$differs REFUSED=$refused BROKEN=$broken (reference run excluded) --"
[ "$differs" -eq 0 ] && [ "$broken" -eq 0 ]
