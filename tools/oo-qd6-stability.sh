#!/usr/bin/env bash
# Multi-run stability sweep for golden scenario 008-material-test-suite (bead oo-qd6).
#
# WHY THIS EXISTS AS A SEPARATE SCRIPT. It captures stdout AND stderr for EVERY run REGARDLESS OF
# EXIT CODE, and classifies each run by what it actually produced rather than by its return code. A
# sibling harness recorded results only when returncode==0 and thereby hid runs that wrote a correct
# dump but exited nonzero, reporting "1/10 dumped" when four identical dumps existed.
#
# Four outcomes, reported separately and never collapsed:
#   MATCH    - dumped, byte-identical to run 1's dump
#   DIFFERED - dumped, but the bytes differ (a FINDING: the scenario is not deterministic)
#   REFUSED  - no dump; the scenario's own assertions went red (this is the gate working)
#   BROKEN   - no dump and no recognisable refusal (a harness or environment failure)
#
# Usage: bash tools/oo-qd6-stability.sh [N]   (default 10)
set -u

N="${1:-10}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

export PATH=/ucrt64/bin:$PATH
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)
APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
if [ ! -d "$APP_DIR" ]; then
  echo "no Oolite build at $APP_DIR; build it first (tools/build-windows.sh test)"
  exit 1
fi

W="${LOCALAPPDATA:-/tmp}/Temp/oo_qd6_stability.$$"
rm -rf "$W"; mkdir -p "$W"
NW=$(cygpath -m "$W" 2>/dev/null || echo "$W")

dumped=0; refused=0; broken=0; rc_nonzero_but_dumped=0
for i in $(seq 1 "$N"); do
  t0=$(date +%s)
  # Capture BOTH streams unconditionally; the exit code is recorded, never used as a filter.
  "$PY" tests/golden/material_test_suite.py --app-dir "$APP_DIR" \
      --out "$NW/run$i.json" --frame-out "$NW/run$i.grid" --run-root "$NW/runs" \
      >"$W/run$i.log" 2>&1
  rc=$?
  w=$(( $(date +%s) - t0 ))
  if [ -f "$W/run$i.json" ]; then
    dumped=$(( dumped + 1 ))
    [ "$rc" -ne 0 ] && rc_nonzero_but_dumped=$(( rc_nonzero_but_dumped + 1 ))
    printf 'run %2d  rc=%d  wall=%3ds  DUMPED  %s bytes  md5=%s\n' \
      "$i" "$rc" "$w" "$(wc -c < "$W/run$i.json")" \
      "$("$PY" -c 'import hashlib,sys;print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$NW/run$i.json")"
  elif grep -q 'ScenarioError' "$W/run$i.log"; then
    refused=$(( refused + 1 ))
    printf 'run %2d  rc=%d  wall=%3ds  REFUSED  %s\n' "$i" "$rc" "$w" \
      "$(grep -m1 'ScenarioError' "$W/run$i.log" | cut -c1-160)"
  else
    broken=$(( broken + 1 ))
    printf 'run %2d  rc=%d  wall=%3ds  BROKEN   %s\n' "$i" "$rc" "$w" \
      "$(tail -1 "$W/run$i.log" | cut -c1-160)"
  fi
done

echo
echo "runs=$N dumped=$dumped refused=$refused broken=$broken rc_nonzero_but_dumped=$rc_nonzero_but_dumped"

if [ "$dumped" -lt 2 ]; then
  echo "!! FEWER THAN 2 RUNS PRODUCED A DUMP ($dumped). There are no pairs to compare, so NO"
  echo "!! stability claim can be made from this sweep. Reporting a comparison over zero pairs"
  echo "!! would be a reassuring number with nothing behind it."
  rm -rf "$W"
  exit 1
fi

"$PY" - "$NW" "$N" <<'PYEOF'
import hashlib, json, os, sys
nw, n = sys.argv[1], int(sys.argv[2])
dumps = {}
grids = {}
for i in range(1, n + 1):
    p = os.path.join(nw, "run%d.json" % i)
    if os.path.isfile(p):
        dumps[i] = hashlib.md5(open(p, "rb").read()).hexdigest()
    g = os.path.join(nw, "run%d.grid" % i)
    if os.path.isfile(g):
        grids[i] = hashlib.md5(open(g, "rb").read()).hexdigest()
distinct = sorted(set(dumps.values()))
print("distinct dump digests: %d %s" % (len(distinct), distinct))
print("distinct frame-grid digests: %d of %d grids (llvmpipe is NOT bit-reproducible; this is"
      " expected and is why the grid is compared with a TOLERANCE and is NOT in state.json)"
      % (len(set(grids.values())), len(grids)))
sys.exit(0 if len(distinct) == 1 else 1)
PYEOF
rc=$?
rm -rf "$W"
exit $rc
