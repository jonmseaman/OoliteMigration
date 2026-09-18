#!/usr/bin/env bash
# Stability sweep for golden scenario 009-shaders (bead oo-rad).
#
# EVERY RUN IS RECORDED, whatever its exit code. A sibling harness stored results only when
# returncode==0 and reported "1/10 dumped" while four identical dumps sat on disk; a run that
# writes a correct dump and then exits nonzero is a DIFFERENT finding from a run that refused, and
# collapsing the two hides both.
#
#   MATCH    - dump written and byte-identical to the blessed golden
#   DIFFERS  - dump written but NOT byte-identical (the interesting case; the diff is printed)
#   REFUSED  - no dump written, the gate said why (stderr is printed)
#
# GPU work may be less deterministic than CPU work. If runs differ, the fields are reported with
# their values rather than the quantisation being coarsened to hide the difference.
set -u
export PATH=/ucrt64/bin:$PATH
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here" || exit 2

N="${1:-10}"
OO_APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
export OO_APP_DIR
G=$(ls goldens/windows-x64/009-shaders/state.json \
       tests/golden/pending/009-shaders/state.json 2>/dev/null | head -1)
if [ -z "$G" ]; then echo "no blessed golden for 009-shaders"; exit 2; fi

ROOT="$(cygpath -m "$LOCALAPPDATA")/Temp/oorad_stability"
rm -rf "$ROOT"; mkdir -p "$ROOT"

match=0; differs=0; refused=0
for i in $(seq 1 "$N"); do
  d="$ROOT/run$i"; mkdir -p "$d"
  start=$(date +%s.%N)
  python3 tests/golden/shader_fallback.py --out "$d/state.json" \
      --frame-out "$d/frame.grid" >"$d/stdout.txt" 2>"$d/stderr.txt"
  rc=$?
  end=$(date +%s.%N)
  wall=$(awk "BEGIN{printf \"%.1f\", $end-$start}")
  if [ -f "$d/state.json" ]; then
    if cmp -s "$d/state.json" "$G"; then
      match=$((match+1)); printf 'run %-2s rc=%s %ss MATCH\n' "$i" "$rc" "$wall"
    else
      differs=$((differs+1)); printf 'run %-2s rc=%s %ss DIFFERS\n' "$i" "$rc" "$wall"
      python3 tests/golden/golden_diff.py "$G" "$d/state.json" 2>&1 | head -20
    fi
  else
    refused=$((refused+1)); printf 'run %-2s rc=%s %ss REFUSED\n' "$i" "$rc" "$wall"
    tail -3 "$d/stderr.txt"
  fi
done
echo "MATCH=$match DIFFERS=$differs REFUSED=$refused of $N"
[ "$match" -eq "$N" ]
