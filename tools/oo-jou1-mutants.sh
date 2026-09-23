#!/usr/bin/env bash
#
# tools/oo-jou1-mutants.sh - prove the ship.speed gate can FAIL, one mutant at a time.
#
# For every property the gate defends there are TWO mutants: one that corrupts the DATA and one
# that weakens the CHECKER (bead oo-jor: a gate that validates data with a validator nobody
# validates is a hole one refactor wide). The DATA/CHECKER mutants against the witness live in
# tests/golden/motion/test_check_settled.py, which runs them as ordinary tests. THIS script covers
# the mutants those cannot express, because they mutate files on disk:
#
#   M1  revert the property table to OOJS_PROP_READONLY_CB   (the seam's declaration)
#   M2  delete the `case kShip_speed:` setter body           (the seam's implementation)
#   M3  replace -setSpeed: with a no-op in the setter case   (the seam's effect)
#   M4  collapse MIN_REST_FRAMES to 1                        (the multi-frame requirement)
#   M5  delete the position_frozen defence                   (the independent position check)
#   M6  swap the GREEN witness for the RED one               (the evidence itself)
#
# Every mutant is applied to a BACKED-UP copy of the real file and restored by a trap, so an
# interrupted run cannot leave a mutated tree behind. Every file is baselined GREEN before any
# mutation: a line that is already red registers as a kill for every mutant and silently
# manufactures evidence (bead oo-4vdc).
#
# Runs entirely offline - it never launches the game. The live measurement is already recorded in
# tests/golden/motion/fixtures/; this proves the judgement of it discriminates.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
cd "$repo"

# NATIVE paths from here on. `pwd` in this shell yields /c/Users/..., and python3.exe is a native
# binary with MSYS path conversion disabled on this host, so it resolves that against the current
# drive and reports "file or directory not found" for a directory that plainly exists - which
# pytest returns as rc=4 (usage error), indistinguishable at a glance from a red gate. Measured
# here: the unconverted path aborted this script at its own baseline guard.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
repo_native="$(native "$repo")"

MOTION="$repo/tests/golden/motion"
MOTION_NATIVE="$repo_native/tests/golden/motion"
OOJSSHIP="$repo/upstream/oolite/src/Core/Scripting/OOJSShip.mm"
CHECKER="$MOTION/check_settled.py"
GREEN="$MOTION/fixtures/green-speed-arm.json"
CONTRACT="$repo/oxp-contract/js-api-1.93.json"
RED="$MOTION/fixtures/red-unfixed-engine.json"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "no $PY on PATH"; exit 2; }

backups=()
mutated_paths=()
restore() {
  local i
  for ((i=${#backups[@]}-1; i>=0; i--)); do
    local pair="${backups[$i]}"
    cp -f "${pair%%::*}" "${pair##*::}"
    rm -f "${pair%%::*}"
  done
  backups=()
  mutated_paths=()
}
trap restore EXIT INT TERM

backup() {  # backup <file>
  local tmp; tmp="$(mktemp)"
  cp -f "$1" "$tmp"
  backups+=("$tmp::$1")
  mutated_paths+=("$1")
}

kills=0
survivors=0

gate() {  # the gate under test, exactly as the stored acceptance line runs it
  "$PY" -m pytest "$MOTION_NATIVE" -q >/dev/null 2>&1
}

baseline() {
  echo "== BASELINE (every file unmutated)"
  if gate; then
    echo "   rc=0 GREEN - safe to mutate"
  else
    echo "   rc=$? *** the gate is ALREADY RED before any mutation; every mutant would register"
    echo "   as a kill and this run would manufacture evidence. Aborting."
    exit 1
  fi
}

# True when every file we backed up is byte-identical to its backup, i.e. the mutation edited
# nothing. Compared against the BACKUP rather than against git HEAD on purpose: a mutation that
# happens to reproduce the committed content (M10 reverting a value that was not yet committed)
# is still a real mutation of the working tree, and judging it by `git diff` silently mislabels
# it. The backup is the only honest before-image.
mutation_is_a_no_op() {
  local pair
  for pair in "${backups[@]}"; do
    cmp -s "${pair%%::*}" "${pair##*::}" || return 1
  done
  return 0
}

mutant() {  # mutant <name> <description>
  local name="$1" desc="$2"
  echo
  echo "== MUTANT $name: $desc"
  # A mutation that did not actually change the file is not a survivor, it is a broken harness -
  # and it reports identically to a blind gate. M9/M10 sat as "SURVIVED" through two runs because
  # their heredocs were malformed and edited nothing; only diffing the tree exposed it.
  if mutation_is_a_no_op; then
    echo "   *** MUTATION DID NOT APPLY - the harness is broken, not the gate ***"
    restore
    survivors=$((survivors + 1))
    return
  fi
  if gate; then
    echo "   rc=0 *** SURVIVED - THE GATE DOES NOT DISCRIMINATE THIS ***"
    survivors=$((survivors + 1))
  else
    echo "   rc=1 KILLED"
    kills=$((kills + 1))
    "$PY" -m pytest "$MOTION_NATIVE" -q 2>&1 | grep -E "^(FAILED|E  *AssertionError)" | head -3 \
      | sed 's/^/   /'
  fi
  restore
}

baseline

# --- M1: the seam's DECLARATION ---------------------------------------------------------------
backup "$OOJSSHIP"
"$PY" - "$(native "$OOJSSHIP")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
old = '{ "speed",\t\t\t\t\tkShip_speed,\t\t\t\tOOJS_PROP_READWRITE_CB },'
new = '{ "speed",\t\t\t\t\tkShip_speed,\t\t\t\tOOJS_PROP_READONLY_CB },'
assert old in s, "M1 anchor not found"
open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(s.replace(old, new))
EOF
mutant M1 "revert the property table to OOJS_PROP_READONLY_CB"

# --- M2: the seam's IMPLEMENTATION --------------------------------------------------------------
backup "$OOJSSHIP"
"$PY" - "$(native "$OOJSSHIP")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
head, _, tail = s.rpartition("static JSBool ShipSetProperty")
i = tail.index("case kShip_speed:")
j = tail.index("break;", i) + len("break;")
open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(
    head + "static JSBool ShipSetProperty" + tail[:i] + tail[j:])
EOF
mutant M2 "delete the case kShip_speed: setter body from ShipSetProperty"

# --- M3: the seam's EFFECT ----------------------------------------------------------------------
backup "$OOJSSHIP"
"$PY" - "$(native "$OOJSSHIP")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
head, _, tail = s.rpartition("static JSBool ShipSetProperty")
i = tail.index("case kShip_speed:")
j = tail.index("break;", i)
block = tail[i:j].replace("[entity setSpeed:fValue];", "/* mutant: write removed */")
assert "mutant: write removed" in block, "M3 anchor not found"
open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(
    head + "static JSBool ShipSetProperty" + tail[:i] + block + tail[j:])
EOF
mutant M3 "keep the setter case but remove its [entity setSpeed:] call"

# --- M7: the PLAYER guard -----------------------------------------------------------------------
backup "$OOJSSHIP"
"$PY" - "$(native "$OOJSSHIP")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
head, _, tail = s.rpartition("static JSBool ShipSetProperty")
i = tail.index("case kShip_speed:")
j = tail.index("break;", i)
block = tail[i:j].replace("if (EXPECT_NOT([entity isPlayer]))  goto playerReadOnly;",
                          "/* mutant: player guard removed */", 1)
assert "mutant: player guard removed" in block, "M7 anchor not found"
open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(
    head + "static JSBool ShipSetProperty" + tail[:i] + block + tail[j:])
EOF
mutant M7 "remove the [entity isPlayer] guard from the setter case"

# --- M8: the REFUSAL becomes a silent clamp -----------------------------------------------------
backup "$OOJSSHIP"
"$PY" - "$(native "$OOJSSHIP")" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
head, _, tail = s.rpartition("static JSBool ShipSetProperty")
i = tail.index("case kShip_speed:")
j = tail.index("break;", i)
block = tail[i:j]
block = re.sub(r"if \(isnan\(fValue\) \|\| fValue < 0\)\s*\{.*?\}", "", block, count=1, flags=re.S)
block = block.replace("[entity setSpeed:fValue];", "[entity setSpeed:fmax(fValue, 0.0)];")
assert "fmax(" in block and "isnan" not in block, "M8 anchor not found"
open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(
    head + "static JSBool ShipSetProperty" + tail[:i] + block + tail[j:])
EOF
mutant M8 "replace the loud refusal with a silent fmax() clamp"

# --- M4: THE MULTI-FRAME REQUIREMENT ------------------------------------------------------------
backup "$CHECKER"
"$PY" - "$(native "$CHECKER")" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2 = re.sub(r"^MIN_REST_FRAMES = \d+", "MIN_REST_FRAMES = 1", s, count=1, flags=re.M)
assert s2 != s, "M4 anchor not found"
open(p, "w", encoding="utf-8", newline="\n").write(s2)
EOF
mutant M4 "weaken the multi-frame check to a single frame (MIN_REST_FRAMES = 1)"

# --- M5: the independent POSITION defence -------------------------------------------------------
backup "$CHECKER"
"$PY" - "$(native "$CHECKER")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = '    ("position_frozen", check_position_frozen),\n'
assert old in s, "M5 anchor not found"
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old, ""))
EOF
mutant M5 "remove the position_frozen defence from the DEFENCES table"

# --- M9: the CRUISE defences (the positive control) --------------------------------------------
backup "$CHECKER"
"$PY" - "$(native "$CHECKER")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = '    ("cruise_speed_held", check_cruise_speed_held),' + chr(10)
assert old in s, "M9 anchor not found"
open(p, "w", encoding="utf-8", newline=chr(10)).write(s.replace(old, ""))
EOF
mutant M9 "remove the cruise_speed_held defence (a decayed write would pass)"

# --- M10: the CONTRACT ---------------------------------------------------------------------------
backup "$CONTRACT"
"$PY" - "$(native "$CONTRACT")" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["globals"]["Ship"]["prototype_members"]["speed"]["writable"] = False
open(p, "w", encoding="utf-8", newline=chr(10)).write(
    json.dumps(d, indent=2, sort_keys=True) + chr(10))
EOF
mutant M10 "revert the recorded contract to writable:false for Ship.speed"

# --- M6: the EVIDENCE ---------------------------------------------------------------------------
backup "$GREEN"
cp -f "$RED" "$GREEN"
mutant M6 "replace the GREEN witness with the RED one (unfixed engine's numbers)"

echo
echo "== RESTORED"
if gate; then
  echo "   rc=0 GREEN - the tree is clean again"
else
  echo "   rc=$? *** the tree did NOT come back green; something was not restored"
  exit 1
fi

echo
echo "kills=$kills survivors=$survivors"
[ "$survivors" -eq 0 ] || exit 1
