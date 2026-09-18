#!/usr/bin/env bash
# oo-ss8: produce the measurement inputs for the golden storage policy.
#
# Four SEQUENTIAL launches against the SHARED build (a worktree has none):
#   runA, runB  - default quantisation. runA becomes the stored golden; runB is the independent
#                 second run the zero-difference claim is made about.
#   rawA, rawB  - the SAME scenario dumped at 15 decimal places (--quant-decimals 15), i.e. the
#                 raw doubles. Diffing these two measures the run-to-run float spread that the
#                 quantisation has to absorb, so QUANT_DECIMALS is derived from data rather than
#                 picked. If rawA and rawB are bit-identical, that is itself the result and must
#                 be reported as "spread not measurable on this host", never rounded up into a
#                 fabricated number.
#
# Sequential, never concurrent: the game DIALS OUT to the port in debugConfig.plist (8563), so two
# runs at once attach to each other's game (bead oo-gla).
set -euo pipefail
export PATH=/ucrt64/bin:$PATH   # else the loader kills oolite.exe with 3221225781, no log

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
OUT="${1:-${LOCALAPPDATA:-/tmp}/Temp/oo_ss8_measure}"

test -d "$APP_DIR" || { echo "no Oolite build at $APP_DIR" >&2; exit 1; }
mkdir -p "$OUT"
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)
RUN_DUMP="$(cygpath -m "$REPO_ROOT/tests/golden/dump/run_dump.py")"
NATIVE_OUT="$(cygpath -m "$OUT")"

one() {
  local name="$1"; shift
  local t0 t1
  t0=$(date +%s)
  "$PY" "$RUN_DUMP" --app-dir "$APP_DIR" --port 8563 --seed 1 \
    --output-dir "$NATIVE_OUT/$name.work" --out "$NATIVE_OUT/$name.json" "$@"
  t1=$(date +%s)
  echo "  $name: rc=0 wall=$((t1 - t0))s bytes=$(wc -c < "$OUT/$name.json")"
}

echo "==> runA (policy quantisation, becomes the golden)"; one runA
echo "==> runB (policy quantisation, independent second run)"; one runB
echo "==> rawA (15 decimals, raw doubles)"; one rawA --quant-decimals 15
echo "==> rawB (15 decimals, raw doubles)"; one rawB --quant-decimals 15
echo "measurement inputs in $OUT"
