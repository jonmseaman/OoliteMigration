#!/usr/bin/env bash
# oo-jor: the bead's stated definition of done - N consecutive runs reproduce the golden
# byte-for-byte. Kept OUT of the stored acceptance block on purpose (see the bead notes): at ~30 s
# per run this is minutes of serialised game launches per acceptance attempt, and launches are the
# flakiest thing on this box. The gate replays a two-run version of the same comparison.
#
# THREE STATES ARE REPORTED SEPARATELY, and the distinction is the point (it is the same
# rc=2-refused vs rc=1-differs discipline golden_diff.py is built on):
#   MATCH    the run dumped and the dump equals the stored golden byte for byte
#   REFUSED  the run's own guards fired and it declined to dump a world it knew was unsettled
#   DIFFERS  the run dumped and the dump disagrees with the golden  <-- the only real failure
# A REFUSED run is the instrument working. Only DIFFERS (or a launch that died for an unrelated
# reason) means the scenario is not reproducible.
set -u
export PATH=/ucrt64/bin:$PATH
cd "$(dirname "$0")/.."
PY=$(command -v python3 || echo /ucrt64/bin/python3)
APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
N="${1:-10}"
W="${LOCALAPPDATA:-/tmp}/Temp/oo_jor_stability"
rm -rf "$W"; mkdir -p "$W"
NW=$(cygpath -m "$W" 2>/dev/null || echo "$W")
G="goldens/windows-x64/001-launch-dock/state.json"

# DIGEST EXTRACTION. GNU md5sum ESCAPES its output with a leading backslash when the filename
# contains a backslash (any native Windows path), so a naive `cut -c1-32` silently eats one hex
# digit and prints a 31-character digest - unverifiable by anyone auditing the report later.
# Feed it on stdin so there is no filename to escape, then assert the digest is 32 hex chars.
digest() {
  local d
  d=$(md5sum < "$1" | awk '{print $1}')
  case "$d" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) echo "$d" ;;
    *) echo "BAD-DIGEST($d)" ;;
  esac
}

match=0; refused=0; differs=0; broken=0
for i in $(seq 1 "$N"); do
  t0=$(date +%s)
  "$PY" tests/golden/launch_dock.py --app-dir "$APP_DIR" --no-snapshot \
      --out "$NW/run$i.json" --run-root "$NW/runs" >"$W/run$i.log" 2>&1
  rc=$?; wall=$(( $(date +%s) - t0 ))
  if [ $rc -ne 0 ]; then
    if grep -q "ScenarioError" "$W/run$i.log"; then
      echo "run $i: REFUSED wall=${wall}s  (the run's own guard fired; it declined to dump)"
      sed -n 's/^\[!\] ScenarioError: /    /p' "$W/run$i.log" | head -2
      refused=$((refused+1))
    else
      echo "run $i: BROKEN  wall=${wall}s rc=$rc (launch/environment failure, not a determinism result)"
      sed -n '1,3p' "$W/run$i.log" | sed 's/^/    /'
      broken=$((broken+1))
    fi
    continue
  fi
  md5=$(digest "$W/run$i.json")
  ev=$("$PY" tests/golden/check_launch_dock_evidence.py "$NW/run$i.json" --label "run $i" 2>&1); evrc=$?
  dout=$("$PY" tests/golden/golden_diff.py "$G" "$NW/run$i.json" \
         --label-left "stored golden" --label-right "run $i" 2>&1); drc=$?
  if [ $evrc -eq 0 ] && [ $drc -eq 0 ]; then
    echo "run $i: MATCH   wall=${wall}s bytes=$(wc -c <"$W/run$i.json") md5=$md5"
    match=$((match+1))
  else
    echo "run $i: DIFFERS wall=${wall}s evidence_rc=$evrc diff_rc=$drc md5=$md5"
    echo "$ev" | sed 's/^/    /'; echo "$dout" | sed 's/^/    /'
    differs=$((differs+1))
  fi
done
dumped=$((match + differs))
echo "RESULT: $N runs -> $match MATCH, $differs DIFFERS, $refused REFUSED (guard fired), $broken BROKEN"
echo "        of the $dumped run(s) that produced a dump, $match reproduced the golden byte-for-byte"
test "$differs" -eq 0 -a "$broken" -eq 0
