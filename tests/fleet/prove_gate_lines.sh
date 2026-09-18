#!/usr/bin/env bash
# Prove the STORED acceptance lines can fail.  For each substantive line: copy the tree to a
# scratch dir, run the line there UNMUTATED (must be rc=0), apply a mutation that breaks exactly
# the property that line protects, run the same line again (must be rc!=0 and its output must
# name the failure).  Nothing here touches the real worktree.
#
#   bash tests/fleet/prove_gate_lines.sh              # read the block from bd
#   bash tests/fleet/prove_gate_lines.sh <block.txt>  # or from a file
#
# Lines 6 and 7 are themselves mutation harnesses with their own controls (gate_mutants.py);
# line 1 is the checker the other lines call; line 9 is proved by the 'stray write' mutation.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYX="$(command -v python3 || command -v python || echo /ucrt64/bin/python3)"

BLOCK="${1:-}"
if [ -z "$BLOCK" ]; then
  BLOCK="$ROOT/.gate-block-$$.txt"
  "${BD_EXE:-C:/tools/bd/bd.exe}" show oo-l7r0 --json 2>/dev/null > "$ROOT/.gate-show-$$.json"
  "$PYX" -c "import json,sys;d=open(sys.argv[1],encoding='utf-8').read();a=json.loads(d[d.find('['):])[0]['acceptance_criteria'];open(sys.argv[2],'w',encoding='utf-8',newline='\n').write(a)" \
    "$ROOT/.gate-show-$$.json" "$BLOCK"
  rm -f "$ROOT/.gate-show-$$.json"
  trap 'rm -f "$BLOCK"' EXIT
fi
STORED=$(awk 'END{print NR}' "$BLOCK")
echo "stored acceptance lines: $STORED"

L=${LOCALAPPDATA:-C:\\Users\\jon\\AppData\\Local}
BASE=${L//\\//}/Temp/oo-l7r0-lineproof-$$
pass=0; fail=0

prove() {   # $1=line no  $2=description  $3=needle  $4=mutation name
  local n="$1" desc="$2" needle="$3" mut="$4"
  local W="$BASE-$n"
  rm -rf "$W"; mkdir -p "$W"
  ( cd "$ROOT" && cp -r tools tests docs .git "$W/" ) 2>/dev/null
  local cmd; cmd="$(sed -n "${n}p" "$BLOCK")"

  local green grc red rrc
  green="$(cd "$W" && bash -o pipefail -c "$cmd" 2>&1)"; grc=$?
  ( cd "$W" && "$PYX" tests/fleet/mutate.py "$mut" ) >/dev/null 2>&1 || { echo "MUTATION $mut FAILED TO APPLY"; fail=$((fail+1)); rm -rf "$W"; return; }
  red="$(cd "$W" && bash -o pipefail -c "$cmd" 2>&1)"; rrc=$?

  echo
  echo "=== line $n — $desc"
  echo "--- GREEN (unmutated copy) rc=$grc"
  echo "$green" | tail -2
  echo "--- RED (mutant: $mut) rc=$rrc"
  echo "$red" | tail -3
  if [ "$grc" = "0" ] && [ "$rrc" != "0" ] && printf '%s' "$red" | grep -qF "$needle"; then
    echo "--- verdict: GOOD (green, then red with a message naming the failure)"
    pass=$((pass+1))
  else
    echo "--- verdict: BAD (grc=$grc rrc=$rrc needle '$needle' found=$(printf '%s' "$red" | grep -cF "$needle"))"
    fail=$((fail+1))
  fi
  rm -rf "$W"
}

prove 2 "a metric the doc defines is dropped from the report" "missing from the report" drop-metric
prove 3 "the fork/migration matched figure is removed"        "fork_migration_matched"  drop-fork-figure
prove 4 "an uncomputable metric is printed as a silent 0"      "printed as 0"            silent-zero
prove 5 "a reported count no longer matches the recount"       "independent count"       fake-count
prove 8 "the write enforcement is stripped from the reporter"  "test_writing_outside_the_report_file_is_refused" strip-write-guard

echo
echo "==== $((pass+fail)) line proofs: $pass good, $fail bad"
[ "$fail" = "0" ] || exit 1
echo "EVERY PROVEN LINE WENT GREEN THEN RED WITH A NAMING MESSAGE"
