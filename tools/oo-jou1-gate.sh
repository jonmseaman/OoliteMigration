#!/usr/bin/env bash
# tools/oo-jou1-gate.sh - the ship.speed seam gate, offline, no build required.
#
# Three vectors, each of which fails for its own reason:
#
#   1. GREEN   the offline tier passes: the seam is present in the engine source, the recorded
#              witness from the fixed binary shows a ship at rest for 10 consecutive frames, and
#              the positive control shows a nonzero speed held for 10 consecutive frames.
#   2. RED     the recorded witness from the UNFIXED binary is REJECTED, naming the
#              re-acceleration. This reproduces the original defect on demand rather than merely
#              asserting the fix's code is present, so it cannot be satisfied by a refactor.
#   3. REFUSE  an unjudgeable witness returns 2, never 0 - a checker that returns "equal" when it
#              could not perform the comparison is the most dangerous failure a gate can have.
#
# Deliberately launches nothing. The live measurement is already recorded in
# tests/golden/motion/fixtures/ (each witness naming the binary, size and md5 it came from) and
# tools/oo-jou1-mutants.sh proves the judgement of it discriminates. An acceptance replay runs on
# a fresh merge of main with NO build directory, so a gate that needed the game would pass for the
# author and fail at acceptance.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
cd "$repo"

# Native paths for the native python (MSYS conversion is disabled on this host; an unconverted
# /c/... path makes pytest exit 4 "file or directory not found", which reads like a red gate).
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
R="$(native "$repo")"
MOTION="$R/tests/golden/motion"
CHECK="$MOTION/check_settled.py"
PY="${PYTHON:-python3}"

fail=0
note() { printf '%s\n' "$*"; }

note "== 1/4 GREEN: the offline tier"
if "$PY" -m pytest "$MOTION" -q; then
  note "   ok"
else
  note "   FAIL: the offline tier did not pass"
  fail=1
fi

note "== 2/4 RED: the unfixed engine's witness must be REJECTED"
out="$("$PY" "$CHECK" "$MOTION/fixtures/red-unfixed-engine.json" --arm velocity --expect rest 2>&1)"
rc=$?
if [ "$rc" -ne 1 ]; then
  note "   FAIL: expected rc=1 (a real difference), got rc=$rc"
  note "$out" | head -5
  fail=1
elif ! printf '%s' "$out" | grep -q "RE-ACCELERATED"; then
  note "   FAIL: rc=1 but the verdict does not name the re-acceleration, so it may be failing for"
  note "         an unrelated reason:"
  note "$out" | head -5
  fail=1
else
  note "   ok: $(printf '%s' "$out" | sed -n '2p')"
fi

note "== 3/4 CRUISE: a written nonzero speed is HELD and the ship travels"
out="$("$PY" "$CHECK" "$MOTION/fixtures/green-speed-arm.json" --arm cruise --expect cruise 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  note "   FAIL: the positive control did not pass (rc=$rc); a seam that only accepts 0 is a"
  note "         stop() spelled as a property, not a writable speed:"
  note "$out" | head -5
  fail=1
else
  note "   ok: $(printf '%s' "$out" | head -1)"
fi

note "== 4/4 REFUSE: an unjudgeable witness must return 2, not 0"
rc=0
"$PY" "$CHECK" "$MOTION/fixtures/green-speed-arm.json" --arm no-such-arm >/dev/null 2>&1 || rc=$?
if [ "$rc" -ne 2 ]; then
  note "   FAIL: expected rc=2 (cannot tell), got rc=$rc"
  fail=1
else
  note "   ok"
fi

if [ "$fail" -eq 0 ]; then
  note "PASS: ship.speed seam gate (green, red, refusal)"
else
  note "FAIL: ship.speed seam gate"
fi
exit "$fail"
