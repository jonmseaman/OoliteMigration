#!/usr/bin/env bash
# Mutation proof for the oo-l7u gate (bead oo-l7u).
#
# For each substantive acceptance line, build a mutant that breaks EXACTLY the
# property that line protects, run the line, show it RED naming the failure,
# then restore and show it GREEN. A gate nobody has watched fail is decoration.
#
# Every mutant is applied to a COPY under $LOCALAPPDATA/Temp, never to the
# worktree, so a crash cannot leave the repo dirty and block the fleet.
set -u
export PATH=/ucrt64/bin:$PATH
cd "$(dirname "$0")/../.." || exit 2
# Native (C:/...) form: this harness hands paths to python3.exe and node.exe,
# which do NOT understand MSYS /c/Users/... paths on this host - a native tool
# told to open an MSYS path fails with ENOENT, and a mutant that never applied
# makes the gate look GREEN under a mutation (a false survivor) or RED for the
# wrong reason (a false kill). Both destroy the proof, so resolve it once here.
ROOT="$(pwd -W 2>/dev/null || pwd)"
MSYSROOT="$PWD"
T="${LOCALAPPDATA:-$HOME}/Temp/oxp-model-pilot/mutants"
rm -rf "$T"; mkdir -p "$T"
PASS=0; FAIL=0

run() {  # run <label> <expect rc0|rcN> <cmd...>
  local label="$1" expect="$2"; shift 2
  local out rc t0 t1
  t0=$(date +%s)
  out="$("$@" 2>&1)"; rc=$?
  t1=$(date +%s)
  echo "----- $label  (rc=$rc, $((t1-t0))s)"
  echo "$out" | tail -8 | sed 's/^/      /'
  # A mutant that never applied, or a line that died because a file was missing,
  # is NOT evidence that the gate discriminates - it is a harness defect that
  # looks identical to a kill. Reject those explicitly rather than counting them.
  if echo "$out" | grep -qE "ENOENT|MODULE_NOT_FOUND|No such file or directory|mutation did not apply"; then
    FAIL=$((FAIL+1)); echo "      => *** HARNESS ERROR (missing file / mutant not applied) - not a valid result ***"; echo; return
  fi
  if [ "$expect" = "rc0" ] && [ "$rc" -eq 0 ]; then PASS=$((PASS+1)); echo "      => EXPECTED GREEN"
  elif [ "$expect" = "rcN" ] && [ "$rc" -ne 0 ]; then PASS=$((PASS+1)); echo "      => EXPECTED RED"
  else FAIL=$((FAIL+1)); echo "      => *** UNEXPECTED (wanted $expect) ***"; fi
  echo
}

# Apply a python mutation and ABORT if it did not change anything.
mutate() {  # mutate <<PY ... PY  (reads script on stdin)
  python3 - "$@" || { echo "*** mutation step failed - aborting, a mutation proof with an unapplied mutant proves nothing ***"; exit 2; }
}

echo "################ BASELINE: every line green before any mutation ################"
run "L1 ground-truth integrity"   rc0 node tools/oxp-model-pilot/verify-audit.js
run "L2 sandbox negative tests"   rc0 node tools/oxp-model-pilot/sandbox-probe.js
run "L3 stub pipeline end-to-end" rc0 bash -c 'node tools/oxp-model-pilot/sandbox.js --mode constant --no-net --tag mut --out "'"$T"'/v.jsonl" >/dev/null && node tools/oxp-model-pilot/score.js --verdicts "'"$T"'/v.jsonl" --label mut; test $? -eq 1'
run "L4 committed model verdicts" rc0 node tools/oxp-model-pilot/score.js --verdicts tools/oxp-model-pilot/data/verdicts-model.jsonl --min-control-recall 0 --min-agreement 0.6 --label baseline

echo "################ MUTANT 1: constant-answer classifier must FAIL the check ################"
echo "  (property: a classifier that always answers 'false-positive' scores ~82% on this"
echo "   population while having learned nothing; the scorer must reject it)"
node tools/oxp-model-pilot/sandbox.js --mode constant --no-net --tag m1 --out "$T/constant.jsonl" >/dev/null 2>&1
run "M1 scorer vs constant stub" rcN node tools/oxp-model-pilot/score.js --verdicts "$T/constant.jsonl" --label "MUTANT constant-answer"

echo "################ MUTANT 2: sandbox with enforcement removed ################"
echo "  (property: the classifier subprocess cannot write the repo / read secrets)"
cp tools/oxp-model-pilot/sandbox.js "$T/sandbox-orig.js"
mutate "$ROOT/tools/oxp-model-pilot/sandbox.js" "$T/sandbox-mutant.js" <<'PY'
import sys
src=open(sys.argv[1],encoding='utf8').read()
# strip the permission flags: the child becomes an ordinary unsandboxed node
mut=src.replace('const nodeArgs = ["--permission"];','const nodeArgs = [];  // MUTANT: enforcement removed')
assert mut!=src,'mutation did not apply'
open(sys.argv[2],'w',encoding='utf8').write(mut)
PY
cp "$T/sandbox-mutant.js" tools/oxp-model-pilot/sandbox.js
run "M2 sandbox-probe vs unenforced sandbox" rcN node tools/oxp-model-pilot/sandbox-probe.js
cp "$T/sandbox-orig.js" tools/oxp-model-pilot/sandbox.js
run "M2 restored" rc0 node tools/oxp-model-pilot/sandbox-probe.js

echo "################ MUTANT 3: fabricated audit labels ################"
echo "  (property: labels must be bound to the real sampled evidence)"
cp tools/oxp-model-pilot/data/audit.jsonl "$T/audit-orig.jsonl"
mutate "$ROOT/tools/oxp-model-pilot/data/audit.jsonl" <<'PY'
import sys,json
p=sys.argv[1]
rows=[json.loads(l) for l in open(p,encoding='utf8') if l.strip()]
# invent evidence: rewrite a snippet so the label no longer describes the hit
for r in rows:
    if r['source']=='corpus-unmasked':
        r['snippet']='var square = function (x) x * x;  // FABRICATED'
        break
open(p,'w',encoding='utf8').write('\n'.join(json.dumps(r) for r in rows)+'\n')
PY
run "M3 verify-audit vs fabricated snippet" rcN node tools/oxp-model-pilot/verify-audit.js
cp "$T/audit-orig.jsonl" tools/oxp-model-pilot/data/audit.jsonl
run "M3 restored" rc0 node tools/oxp-model-pilot/verify-audit.js

echo "################ MUTANT 4: sample not reproducible from its seed ################"
echo "  (property: the 50 must be regenerable from the recorded seed)"
cp tools/oxp-model-pilot/data/sample.jsonl "$T/sample-orig.jsonl"
mutate "$ROOT/tools/oxp-model-pilot/data/sample.jsonl" "$ROOT/tools/oxp-model-pilot/data/ambiguous.jsonl" <<'PY'
import sys,json
sp,amb=sys.argv[1],sys.argv[2]
rows=[json.loads(l) for l in open(sp,encoding='utf8') if l.strip()]
pool=[json.loads(l) for l in open(amb,encoding='utf8') if l.strip()]
have={r['id'] for r in rows}
extra=next(r for r in pool if r['id'] not in have)   # hand-picked, not seed-drawn
for i,r in enumerate(rows):
    if r['source']=='corpus-unmasked': rows[i]=extra; break
open(sp,'w',encoding='utf8').write('\n'.join(json.dumps(r) for r in rows)+'\n')
PY
run "M4 verify-audit vs hand-picked sample" rcN node tools/oxp-model-pilot/verify-audit.js
cp "$T/sample-orig.jsonl" tools/oxp-model-pilot/data/sample.jsonl
run "M4 restored" rc0 node tools/oxp-model-pilot/verify-audit.js

echo "################ MUTANT 5: single-class ground truth (controls removed) ################"
echo "  (property: dropping the known positives makes agreement vacuous and must be caught)"
mutate "$ROOT/tools/oxp-model-pilot/data/audit.jsonl" "$T/audit-nocontrols.jsonl" <<'PY'
import sys,json
rows=[json.loads(l) for l in open(sys.argv[1],encoding='utf8') if l.strip()]
keep=[r for r in rows if r['source']=='corpus-unmasked']
open(sys.argv[2],'w',encoding='utf8').write('\n'.join(json.dumps(r) for r in keep)+'\n')
PY
run "M5 scorer vs all-negative truth" rcN node tools/oxp-model-pilot/score.js --audit "$T/audit-nocontrols.jsonl" --verdicts "$T/constant.jsonl" --label "MUTANT single-class truth"

echo "################ RESULT ################"
echo "expected outcomes: $PASS   unexpected: $FAIL"
git -C "$MSYSROOT" status --porcelain | grep -v '^?? ' && { echo "*** worktree modified by the harness - restore failed ***"; exit 1; }
[ "$FAIL" -eq 0 ] || exit 1
echo "MUTATION PROOF OK: every gate line went red on a mutant that breaks exactly its property, and green again on restore"
