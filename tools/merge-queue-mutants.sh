#!/usr/bin/env bash
#
# tools/merge-queue-mutants.sh -- PROOF THAT THE QUEUE CAN FAIL.
#
# A validator nobody validates is a hole one refactor wide (bead oo-jor shipped exactly that). So
# for every property tools/merge-queue.sh defends there are TWO mutants here: one that corrupts the
# DATA the queue reasons about, and one that WEAKENS the CHECKER itself. Both must turn
# tools/merge-queue-selftest RED, and the RED must NAME the defect -- an assertion that can only
# say "rc != 0" cannot tell the failure you engineered from an unrelated one.
#
#     bash tools/merge-queue-mutants.sh          # every mutant
#     bash tools/merge-queue-mutants.sh --list   # names and descriptions
#     bash tools/merge-queue-mutants.sh M3       # one mutant
#
# EVERY MUTATION IS APPLIED TO A THROWAWAY COPY under $LOCALAPPDATA/Temp. Nothing here edits a
# tracked file, not even transiently: a sibling bead was killed mid-mutation and harvest committed
# its gate with the central predicate replaced, because a restore-on-exit trap does not run when
# the process is killed. A copy that is never restored cannot be committed by accident.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LA="${LOCALAPPDATA:-}"
if [ -n "$_LA" ] && command -v cygpath >/dev/null 2>&1; then _LA="$(cygpath -u "$_LA")"; fi
WORK="${_LA:-/tmp}/Temp/oo-pmg-mutants.$$"
mkdir -p "$WORK" || { echo "mutants: cannot create $WORK" >&2; exit 2; }
trap 'rm -rf "$WORK" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '    ok   %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '    FAIL %s\n' "$*" >&2; }

# A mutant is: a python one-liner edit against a COPY, the scenario(s) that must catch it, and a
# string the RED output must contain so the failure is the engineered one and not a bystander.
run_mutant() { # run_mutant <id> <target: queue|selftest> <old> <new> <scenarios> <expect-substring>
  local id="$1" target="$2" old="$3" new="$4" scen="$5" expect="$6"
  local dir="$WORK/$id"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$HERE/merge-queue.sh" "$HERE/merge-queue-selftest" "$dir/"
  local file="$dir/merge-queue.sh"; [ "$target" = selftest ] && file="$dir/merge-queue-selftest"

  OLD="$old" NEW="$new" FILE="$file" python -c '
import os,sys
p=os.environ["FILE"]; old=os.environ["OLD"]; new=os.environ["NEW"]
s=open(p,encoding="utf-8").read()
if old not in s:
    sys.stderr.write("MUTANT DID NOT APPLY: anchor not found: %r\n" % old[:90]); sys.exit(9)
open(p,"w",encoding="utf-8",newline="\n").write(s.replace(old,new,1))
' || { bad "$id: the mutation did not apply (the anchor moved; the mutant is stale, not the queue innocent)"; return; }

  # THE ANTI-VACUITY CHECK ON THE MUTANT ITSELF: the copy must actually differ.
  if cmp -s "$file" "$HERE/$(basename "$file")"; then
    bad "$id: the mutated copy is byte-identical to the original; nothing was planted"
    return
  fi

  local out rc
  out="$( cd "$dir" && bash ./merge-queue-selftest $scen 2>&1 )"; rc=$?
  if [ "$rc" -eq 0 ]; then
    bad "$id: the selftest stayed GREEN on a mutated queue -- the property is NOT actually checked"
    return
  fi
  if printf '%s\n' "$out" | grep -q -- "$expect"; then
    ok "$id: RED, naming the defect ('$expect')"
  else
    bad "$id: RED (rc=$rc) but for the wrong reason -- expected '$expect' in the output"
    printf '%s\n' "$out" | grep -E '^ *FAIL' | head -5 >&2
  fi
}

LIST=0; WANT=""
[ "${1:-}" = "--list" ] && LIST=1
[ $# -gt 0 ] && [ "$LIST" = 0 ] && WANT="$1"
want() { [ -z "$WANT" ] || [ "$WANT" = "$1" ]; }

printf 'merge-queue-mutants: %d mutant(s) against throwaway copies in %s\n' 12 "$WORK"

# ================================================================================================
# PROPERTY 1: a fast-forward only happens on a GREEN verdict, and it really moves the ref. (G5/G9)
# ================================================================================================
if want M1; then
  printf '\n== M1  CHECKER: the fast-forward stops consulting the verdict (it merges an INCONCLUSIVE batch)\n'
  run_mutant M1 queue \
    'if [ "$VERDICT" = green ]; then
  step "fast-forward $BASE"' \
    'if [ "$VERDICT" = green ] || [ "$VERDICT" = inconclusive ]; then
  step "fast-forward $BASE"' \
    "S8" "base unmoved"
fi
if want M2; then
  printf '\n== M2  DATA: the batch tip is replaced by the base, so the "merge" moves nothing\n'
  run_mutant M2 queue \
    '  git -C "$REPO" update-ref "refs/heads/$BASE" "$BATCH_TIP" "$BASE_BEFORE" \' \
    '  BATCH_TIP="$BASE_BEFORE"; git -C "$REPO" update-ref "refs/heads/$BASE" "$BATCH_TIP" "$BASE_BEFORE" \' \
    "S1" "base did not move"
fi

# ================================================================================================
# PROPERTY 2: the bisection identifies the RIGHT branch. (G6)
# ================================================================================================
if want M3; then
  printf '\n== M3  CHECKER: the bisection is replaced by "blame the first branch" -- the classic wrong answer\n'
  run_mutant M3 queue \
    '  local k="$hi" culprit="${QUEUE[$(( hi - 1 ))]}"' \
    '  local k="$hi" culprit="${QUEUE[0]}"' \
    "S5" "CULPRIT f5 (independently red)"
fi
if want M4; then
  printf '\n== M4  DATA: the binary search inverts its verdict, so it converges on an innocent prefix\n'
  run_mutant M4 queue \
    '    if run_gate "P($mid)" "$c"; then lo="$mid"; else hi="$mid"; HI_COMMIT="$c"; fi' \
    '    if run_gate "P($mid)" "$c"; then hi="$mid"; HI_COMMIT="$c"; else lo="$mid"; fi' \
    "S5" "CULPRIT f5 (independently red)"
fi

# ================================================================================================
# PROPERTY 3: a FLAKE is never attributed to a branch. (the re-run policy)
# ================================================================================================
if want M5; then
  printf '\n== M5  CHECKER: the confirming re-run is deleted, so the first red is believed outright\n'
  run_mutant M5 queue \
    '  confirm "P($k)" "$c_k" 1; rc=$?' \
    '  rc=1' \
    "S8" "evicted          0"
fi
if want M6; then
  printf '\n== M6  CHECKER: a detected flake still evicts (FLAKY is recorded and then ignored)\n'
  run_mutant M6 queue \
    'elif [ "$VERDICT" = inconclusive ]; then
  # G9: an INCONCLUSIVE evicts nobody. Drop any eviction recorded before the flake was seen.
  EVICTED=()' \
    'elif [ "$VERDICT" = inconclusive ]; then
  EVICTED=("${QUEUE[0]}")' \
    "S8" "evicted          0"
fi

# ================================================================================================
# PROPERTY 4: an INTERACTION is reported as a pair, not as a defect in one branch. (attribution)
# ================================================================================================
if want M7; then
  printf '\n== M7  CHECKER: the solo attribution run is skipped, so an interaction is blamed on one branch\n'
  run_mutant M7 queue \
    '  if ! run_gate "solo($culprit)" "$solo"; then
    BISECT_RESULT="culprit:$culprit:independent"; return 0
  fi' \
    '  BISECT_RESULT="culprit:$culprit:independent"; return 0' \
    "S7" "is GREEN alone but RED in P("
fi
if want M8; then
  printf '\n== M8  DATA: the interaction partner is read off the wrong end of the suffix search\n'
  run_mutant M8 queue \
    '  local partner="${QUEUE[$(( jlo - 1 ))]}"' \
    '  local partner="${QUEUE[0]}"' \
    "S7" "INTERACTION between f6 and f3"
fi

# ================================================================================================
# PROPERTY 5: admission requires a Tier-B attestation bound to the exact tip SHA. (G2)
# ================================================================================================
if want M9; then
  printf '\n== M9  CHECKER: the attestation requirement is dropped (un-gated code enters the batch)\n'
  run_mutant M9 queue \
    '  if [ "$REQUIRE_ATTEST" = 1 ] && [ ! -f "$(attest_path "$sha")" ]; then' \
    '  if [ "$REQUIRE_ATTEST" = 2 ] && [ ! -f "$(attest_path "$sha")" ]; then' \
    "S4" "no-tier-b-attestation"
fi
if want M10; then
  printf '\n== M10 DATA: the attestation is keyed on the BRANCH NAME, so an amended tip keeps its green\n'
  run_mutant M10 queue \
    'attest_path() { printf '"'"'%s/%s'"'"' "$ATTEST_DIR" "$1"; }' \
    'attest_path() { printf '"'"'%s/any'"'"' "$ATTEST_DIR"; }' \
    "S4" "expected '0', got '2'"
fi

# ================================================================================================
# PROPERTY 6: evidence that the gate ACTUALLY RAN. (G4) and the empty batch. (G1)
# ================================================================================================
if want M11; then
  printf '\n== M11 DATA: the on-disk invocation tally is pinned at 1, so the evidence contradicts the run\n'
  run_mutant M11 queue \
    '  GATE_RUNS=$(( GATE_RUNS + 1 ))
  printf '"'"'%s\n'"'"' "$GATE_RUNS" > "$COUNT_FILE"' \
    '  GATE_RUNS=$(( GATE_RUNS + 1 ))
  printf '"'"'1\n'"'"' > "$COUNT_FILE"' \
    "S5" "expected '"'"'1'"'"', got '"'"'2'"'"'"
fi
if want M12; then
  printf '\n== M12 CHECKER: the empty-batch guard becomes a quiet green instead of a fatal error\n'
  run_mutant M12 queue \
    '[ "${#CANDIDATES[@]}" -gt 0 ] \
  || die "the candidate list is EMPTY (G1)' \
    '[ "${#CANDIDATES[@]}" -gt 0 ] \
  || exit 0 # "the candidate list is EMPTY (G1)' \
    "S3" "expected '2', got '0'"
fi

printf '\n================================================================\n'
if [ $((PASS+FAIL)) -eq 0 ]; then
  printf 'merge-queue-mutants: FATAL -- no mutant ran; a mutant harness that plants nothing proves nothing\n' >&2
  exit 2
fi
if [ "$FAIL" -eq 0 ]; then
  printf 'merge-queue-mutants: GREEN -- %d/%d mutant(s) were CAUGHT by the selftest\n' "$PASS" "$PASS"
  exit 0
fi
printf 'merge-queue-mutants: RED -- %d caught, %d ESCAPED (an escaped mutant is an unchecked property)\n' "$PASS" "$FAIL" >&2
exit 1
