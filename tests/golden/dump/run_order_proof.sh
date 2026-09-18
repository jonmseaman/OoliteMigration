#!/usr/bin/env bash
# oo-gla: prove the ENTITY SORT is load-bearing, not decoration.
#
# WHY THIS EXISTS, AND WHY THE THREE-RUN DIFF DOES NOT COVER IT.
# The bead's headline gate (accept.sh line 7) runs the same scenario three times and requires
# byte-identical dumps. That gate is real, but it was MEASURED not to discriminate the entity
# sort: deleting `ents.sort(...)` from dump_state.js and re-running three times still produced
# three identical dumps, because repeating the IDENTICAL spawn sequence on the IDENTICAL build
# happens to hand system.allShips back in the same order every time. The same mutant DID change
# the dump content versus the sorted baseline - so the sort does real reordering work that the
# repeat-run gate cannot see. Without this script the sort would be guarded only by a grep of the
# source text, which a comment could satisfy.
#
# THE PERTURBATION. Spawn the same two roles (2 police + 2 pirates, same count, same position,
# same names) in the OPPOSITE order. The SET of ships and every field value is unchanged; only
# the order system.allShips yields them changes. A dump sorted by a stable key must be
# byte-identical across the two; a dump in allShips order must not be.
#
# POSITIVE CONTROL FIRST. --raw-order emits the unsorted allShips id sequence. If reversing the
# spawn order did NOT change that sequence, the perturbation is inert and the "dumps match"
# assertion would be vacuously true - so this script FAILS LOUDLY in that case instead of
# reporting a green. (Fleet learning: a sweep whose control fails is uninterpretable.)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
APP_DIR="${OO_APP_DIR:-$REPO_ROOT/upstream/oolite/build/meson_test/oolite.app}"
WORK="${LOCALAPPDATA:-/tmp}/oo_gla_order.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# MSYS path conversion is disabled on this host, so a native python3.exe resolves /c/... against
# the current drive instead of converting it. cygpath -m (never -u) for every path that crosses
# into a native binary - same guard as run_epsilon_proof.sh and golden_run.py's to_native().
native() { cygpath -m "$1"; }

PY="$(command -v python3 || command -v python || echo /ucrt64/bin/python3)"
RUN_DUMP_PY="$(native "$HERE/run_dump.py")"
NATIVE_APP_DIR="$(native "$APP_DIR")"
NATIVE_WORK="$(native "$WORK")"

test -d "$APP_DIR" || { echo "FAIL: no Oolite build at $APP_DIR; build it first" >&2; exit 1; }

run() {
  # run <tag> <spawn-order> [extra args...]
  local tag="$1" order="$2"; shift 2
  "$PY" "$RUN_DUMP_PY" --app-dir "$NATIVE_APP_DIR" --port 8563 --seed 1 \
    --spawn-order "$order" --output-dir "$NATIVE_WORK/$tag" --out "$(native "$WORK/$tag.json")" "$@"
}

echo "==> positive control: does reversing the spawn order change allShips iteration order?"
run ctl_fwd "police,pirate" --raw-order
run ctl_rev "pirate,police" --raw-order
echo "    forward: $(cat "$WORK/ctl_fwd.json")"
echo "    reverse: $(cat "$WORK/ctl_rev.json")"
if diff -q "$WORK/ctl_fwd.json" "$WORK/ctl_rev.json" >/dev/null; then
  echo "FAIL: control - reversing the spawn order did NOT change the raw allShips order, so this" >&2
  echo "      proof is inert and its result must not be read as evidence about ents.sort()." >&2
  exit 1
fi
echo "ok: control - raw allShips order genuinely differs between the two spawn orders"

echo "==> dumps: forward spawn order vs reverse spawn order"
run fwd "police,pirate"
run rev "pirate,police"

if ! diff -u "$WORK/fwd.json" "$WORK/rev.json"; then
  echo "FAIL: the dump changed when only the SPAWN ORDER changed. Entities are being emitted in" >&2
  echo "      system.allShips iteration order rather than a stable sorted order, so every golden" >&2
  echo "      blessed against this dump is hostage to entity creation order (bead oo-djn's class" >&2
  echo "      of bug). Expected: byte-identical dumps; observed: the diff above." >&2
  exit 1
fi

echo "PASS: entity sort is load-bearing - the same world spawned in two different orders produces"
echo "      byte-identical dumps, while the underlying allShips order provably differed"
