#!/usr/bin/env bash
# oo-gla: prove float quantisation (decision 11) is LOAD-BEARING, not a no-op truncation.
#
# Two mutant runs against the same scenario as run_dump.py's default (paused, deterministic
# spawn), each nudging allShips[0].position.x by a fixed amount just before the dump:
#   * sub-epsilon (0.0002 m): strictly less than half the quantisation step at 3 decimals
#     (QUANT_DECIMALS in dump_state.js) - toFixed(3) rounds it away, so the dump must be
#     BYTE-IDENTICAL to the unperturbed baseline. If it differs, quantisation is not absorbing
#     anything and every golden bit-flips on harmless platform float noise.
#   * super-epsilon (0.01 m): larger than the quantisation step - the dump MUST differ from the
#     baseline. If it does not, quantisation is truncating real signal (e.g. always rounding to
#     a coarser grid than intended, or the mutant hook is dead code), defeating the golden's
#     purpose of catching an actual behaviour change.
#
# Usage: tools handles this directly (not part of accept.sh; accept.sh calls run_dump.py three
# times for the byte-identical proof, which already exercises the same code path). This script is
# for local verification and is safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
APP_DIR="${OO_APP_DIR:-$REPO_ROOT/upstream/oolite/build/meson_test/oolite.app}"
WORK="${TMPDIR:-${LOCALAPPDATA:-/tmp}/Temp}/oo_gla_epsilon.$$"
mkdir -p "$WORK"

# run_dump.py is executed by a NATIVE python3.exe, not MSYS python - MSYS-style /c/... paths
# handed to it are resolved against the current drive rather than converted, which is exactly the
# class of bug tests/golden/golden_run.py's to_native() guards against. cygpath -m (never -u)
# turns each POSIX path this script builds into the native C:/... form before it crosses that
# boundary.
native() { cygpath -m "$1"; }

RUN_DUMP_PY="$(native "$HERE/run_dump.py")"
NATIVE_APP_DIR="$(native "$APP_DIR")"
NATIVE_WORK="$(native "$WORK")"

run() {
  local out="$1"; shift
  local base
  base="$(basename "$out" .json)"
  /ucrt64/bin/python3.exe "$RUN_DUMP_PY" --app-dir "$NATIVE_APP_DIR" --port 8563 --seed 1 \
    --output-dir "$NATIVE_WORK/$base" --out "$(native "$out")" "$@"
}

echo "==> baseline"
run "$WORK/base.json"
echo "==> sub-epsilon (0.0002m, must be absorbed)"
run "$WORK/sub.json" --perturb 0.0002
echo "==> super-epsilon (0.01m, must be visible)"
run "$WORK/sup.json" --perturb 0.01

if ! diff -q "$WORK/base.json" "$WORK/sub.json" >/dev/null; then
  echo "FAIL: sub-epsilon perturbation changed the dump; quantisation is not absorbing it" >&2
  exit 1
fi
echo "ok: sub-epsilon perturbation absorbed (quantisation working)"

if diff -q "$WORK/base.json" "$WORK/sup.json" >/dev/null; then
  echo "FAIL: super-epsilon perturbation did not change the dump; quantisation is truncating everything" >&2
  exit 1
fi
echo "ok: super-epsilon perturbation is visible (quantisation not defeating the golden)"

echo "PASS: quantisation is load-bearing"
