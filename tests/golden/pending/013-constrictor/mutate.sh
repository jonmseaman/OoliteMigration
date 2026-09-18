#!/usr/bin/env bash
# MUTATION HARNESS for bead oo-5h8e. Every mutant is written to a THROWAWAY COPY of the real tree
# under $LOCALAPPDATA/Temp; the real worktree is NEVER mutated in place, because restore-on-exit
# does not run when the process is killed at a timeout and the orchestrator's gc may harvest the
# worktree at any instant.
#
# Each mutant is judged by replaying the ENTIRE stored acceptance block; the line number recorded
# against each mutant is documentation of which line the author expected to catch it, nothing more.
# A mutant surviving the whole block must be diagnosed by READING THE CODE: blind gate, equivalent
# mutant, or redundant defence.
set -u
REPO="C:/Users/jon/OoliteMigration/.worktrees/oo-5h8e"
BASE="${LOCALAPPDATA}/Temp/oo_5h8e_mutation"
ACC="$REPO/tests/golden/pending/013-constrictor/acceptance.txt"
export PATH=/ucrt64/bin:$PATH

rm -rf "$BASE"; mkdir -p "$BASE"

line_n() { sed -n "${1}p" "$ACC"; }

kills=0; survivors=0; n=0

# $1 = label, $2 = acceptance line number, $3 = python mutator run inside the COPY
mutant() {
  local label="$1" ln="$2" prog="$3"
  n=$((n+1))
  local W="$BASE/m$n"
  rm -rf "$W"; mkdir -p "$W"
  # A file-level copy of only what the gate reads; far cheaper than cloning upstream/.
  (cd "$REPO" && tar cf - tests/golden tools upstream/oolite-tests/Checklist-files \
      upstream/oolite/tests/component 2>/dev/null) | (cd "$W" && tar xf -)
  mkdir -p "$W/tests/golden/pending/013-constrictor"; cp "$ACC" "$W/tests/golden/pending/013-constrictor/acceptance.txt"
  ( cd "$W" && python3 -c "$prog" ) || { echo "MUTANT $n ($label): mutator FAILED to apply"; return; }
  # Replay the WHOLE stored acceptance block, not one hand-picked line. Judging a mutant by the
  # single line its author expected to catch it answers the wrong question: the gate is the BLOCK,
  # and a mutant is only a survivor if EVERY line stays green. Measured consequence - three
  # mutants scored as survivors under per-line judging were in fact killed by a different line.
  # Line 9 is skipped only because it launches the game (~30s x 23 mutants).
  local OUT rc i=0 red=0 redlines="" FIRST=""
  while IFS= read -r aline; do
    [ -n "$aline" ] || continue
    i=$((i+1))
    [ $i -eq 9 ] && continue
    OUT=$( cd "$W" && bash -c "$aline" 2>&1 ); rc=$?
    if [ $rc -ne 0 ]; then
      red=$((red+1)); redlines="$redlines $i"
      if [ $red -eq 1 ]; then
        FIRST=$(printf '%s\n' "$OUT" | grep -E 'FAIL|AssertionError|Error' | head -1 | cut -c1-150)
      fi
    fi
  done < "$ACC"
  if [ $red -gt 0 ]; then
    kills=$((kills+1))
    printf '\n### MUTANT %d: %s\n  *** KILLED *** by acceptance line(s):%s   [author expected %s]\n  %s\n' \
      "$n" "$label" "$redlines" "$ln" "$FIRST"
  else
    survivors=$((survivors+1))
    printf '\n### MUTANT %d: %s\n  *** GREEN - SURVIVOR *** (all 8 replayed acceptance lines rc=0)\n' \
      "$n" "$label"
  fi
  rm -rf "$W"
}

echo "=================== MUTATION CAMPAIGN (throwaway copies only) ==================="

# --- DATA mutants: corrupt the artefact the gate defends ---------------------------------------
mutant "golden state.json: one float perturbed by ONE quantised unit" 6 '
import json,io
p="tests/golden/pending/013-constrictor/state.json"
d=json.load(open(p,encoding="utf-8"))
d["player"]["credits"]=round(d["player"]["credits"]+0.001,3)
open(p,"w",encoding="utf-8",newline="\n").write(json.dumps(d,sort_keys=True,separators=(",",":")))
'

mutant "LAUNDERED RE-BLESS: golden perturbed AND its provenance digest updated to match" 5 '
import hashlib,json
g="tests/golden/pending/013-constrictor/state.json"
p="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(g,encoding="utf-8"))
d["evidence"]["mission_variables"]={}
d["mission_variables"]={}
blob=json.dumps(d,sort_keys=True,separators=(",",":")).encode("utf-8")
open(g,"wb").write(blob)
pr=json.load(open(p,encoding="utf-8"))
pr["artifacts"]["state.json"]={"bytes":len(blob),"sha256":hashlib.sha256(blob).hexdigest(),
                               "md5":hashlib.md5(blob).hexdigest(),
                               "note":pr["artifacts"]["state.json"]["note"]}
json.dump(pr,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "spec seed changed (provenance untouched)" 2 '
import json
p="tests/golden/pending/013-constrictor/spec.json"
d=json.load(open(p,encoding="utf-8")); d["seed"]=99999999
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "spec tick count changed (provenance untouched)" 2 '
import json
p="tests/golden/pending/013-constrictor/spec.json"
d=json.load(open(p,encoding="utf-8")); d["ticks"]=48
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "spec load_save swapped for ANOTHER checklist save" 2 '
import json
p="tests/golden/pending/013-constrictor/spec.json"
d=json.load(open(p,encoding="utf-8"))
d["load_save"]="upstream/oolite-tests/Checklist-files/Missions/Nova.oolite-save"
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "spec load_save == control_save (a differential that cannot move)" 2 '
import json
p="tests/golden/pending/013-constrictor/spec.json"
d=json.load(open(p,encoding="utf-8")); d["control_save"]=d["load_save"]
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "THE MISSION VARIABLE ITSELF: mission_conhunt planted in the golden" 5 '
import json
p="tests/golden/pending/013-constrictor/state.json"
d=json.load(open(p,encoding="utf-8"))
d["evidence"]["mission_conhunt"]="MISSION_COMPLETE"
d["evidence"]["mission_conhunt_present"]=True
d["evidence"]["mission_variables"]["conhunt"]="MISSION_COMPLETE"
d["mission_variables"]["conhunt"]="MISSION_COMPLETE"
open(p,"w",encoding="utf-8",newline="\n").write(json.dumps(d,sort_keys=True,separators=(",",":")))
'

mutant "the live mission handlers emptied in the golden" 5 '
import json
p="tests/golden/pending/013-constrictor/state.json"
d=json.load(open(p,encoding="utf-8")); d["evidence"]["live_mission_handlers"]=[]
open(p,"w",encoding="utf-8",newline="\n").write(json.dumps(d,sort_keys=True,separators=(",",":")))
'

mutant "provenance differential subject desynchronised from the golden" 7 '
import json
p="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(p,encoding="utf-8"))
d["mission_state_differential"]["subject"]["mission_conhunt"]="MISSION_COMPLETE"
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "provenance control arm made identical to the subject (a dead differential)" 7 '
import json
p="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(p,encoding="utf-8"))
md=d["mission_state_differential"]
md["control_thargoidplans"]=dict(md["subject"])
md["control_fresh_game"]=dict(md["subject"])
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "the frame grid truncated" 1 '
p="tests/golden/pending/013-constrictor/frame.grid"
b=open(p,"rb").read()[:2048]
open(p,"wb").write(b)
'

mutant "provenance frame tolerance loosened to hide the control separation" 6 '
import json
p="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(p,encoding="utf-8"))
d["frame_control"]["tolerance"]=0.5
json.dump(d,open(p,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "the .oolite-save fixture given a mission_conhunt (upstream drift)" 3 '
import plistlib
p="upstream/oolite-tests/Checklist-files/Missions/Constrictor.oolite-save"
d=plistlib.load(open(p,"rb"))
d["mission_variables"]["mission_conhunt"]="MISSION_COMPLETE"
plistlib.dump(d,open(p,"wb"))
'

# --- CHECKER mutants: weaken the validator, not the data ----------------------------------------
mutant "CHECKER: EXPECTED_MISSION_VARIABLES emptied (accept any mission state)" 4 '
p="tests/golden/check_constrictor_evidence.py"
s=open(p,encoding="utf-8").read()
i=s.index("EXPECTED_MISSION_VARIABLES = {"); j=s.index("}",i)+1
open(p,"w",encoding="utf-8",newline="\n").write(s[:i]+"EXPECTED_MISSION_VARIABLES = {}"+s[j:])
'

mutant "CHECKER: the live-handler defences BOTH replaced by if False" 4 '
p="tests/golden/check_constrictor_evidence.py"
s=open(p,encoding="utf-8").read()
s=s.replace("if not isinstance(handlers, list) or not handlers:","if False:",1)
s=s.replace("elif sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS):","elif False:",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
'

mutant "CHECKER: the conhunt-presence clause neutered" 4 '
p="tests/golden/check_constrictor_evidence.py"
s=open(p,encoding="utf-8").read()
s=s.replace("EXPECTED_CONHUNT_PRESENT = False","EXPECTED_CONHUNT_PRESENT = True",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
'

mutant "CHECKER: the commander identity check widened to the engine default" 4 '
p="tests/golden/check_constrictor_evidence.py"
s=open(p,encoding="utf-8").read()
s=s.replace(chr(34)+"Constrictor"+chr(34),chr(34)+"Jameson"+chr(34),1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
'

mutant "CHECKER: the top-level/evidence mission_variables agreement check removed" 4 '
p="tests/golden/check_constrictor_evidence.py"
s=open(p,encoding="utf-8").read()
s=s.replace("elif top != mv:","elif False:",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
'

mutant "GATE: the differential-subject predicate removed AND the data desynchronised" 7 '
import json
p="tests/golden/gate_013_differential.py"
s=open(p,encoding="utf-8").read()
s=s.replace("if sub.get(key) != ev.get(key):","if False:",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
q="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(q,encoding="utf-8"))
d["mission_state_differential"]["subject"]["mission_conhunt"]="MISSION_COMPLETE"
json.dump(d,open(q,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "GATE: the empty-movement refusal removed AND the control arm made dead" 7 '
import json
p="tests/golden/gate_013_differential.py"
s=open(p,encoding="utf-8").read()
s=s.replace("if not moved:","if False:",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
q="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(q,encoding="utf-8"))
md=d["mission_state_differential"]
md["control_thargoidplans"]=dict(md["subject"])
md["control_fresh_game"]=dict(md["subject"])
json.dump(d,open(q,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

mutant "GATE: the mutant driver made a no-op (every mutant trivially accepted)" 8 '
p="tests/golden/gate_013_mutants.py"
s=open(p,encoding="utf-8").read()
s=s.replace("if proc.returncode != 1:","if False:",1)
s=s.replace("MUTANTS = (","MUTANTS = ()  # emptied\nUNUSED = (",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
'

mutant "TEST: the knob-is-read pin removed AND a knob made unread" 4 '
p="tests/golden/test_constrictor_save.py"
s=open(p,encoding="utf-8").read()
s=s.replace("assert \x27spec[\"%s\"]\x27 % knob in src, (","assert True or \x27spec[\"%s\"]\x27 % knob in src, (",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
q="tests/golden/constrictor_save.py"
t=open(q,encoding="utf-8").read()
t=t.replace("spec[\"mission_script_name\"]","{\"mission_script_name\":\"oolite-constrictor-hunt\"}[\"mission_script_name\"]")
open(q,"w",encoding="utf-8",newline="\n").write(t)
'

mutant "TEST: the provenance-digest pin removed AND the golden perturbed" 4 '
import json
p="tests/golden/test_constrictor_save.py"
s=open(p,encoding="utf-8").read()
s=s.replace("assert hashlib.sha256(blob).hexdigest() == rec[\"sha256\"], (",
            "assert True or hashlib.sha256(blob).hexdigest() == rec[\"sha256\"], (",1)
s=s.replace("assert len(blob) == rec[\"bytes\"], (","assert True or len(blob) == rec[\"bytes\"], (",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
g="tests/golden/pending/013-constrictor/state.json"
d=json.load(open(g,encoding="utf-8"))
d["player"]["credits"]=round(d["player"]["credits"]+0.001,3)
open(g,"w",encoding="utf-8",newline="\n").write(json.dumps(d,sort_keys=True,separators=(",",":")))
'

# The subject/golden agreement is now defended TWICE (gate_013_differential.py and
# test_constrictor_save.py::test_the_differential_subject_is_the_blessed_golden). Removing ONE half
# is killed by the other. This mutant removes BOTH and is the honest floor of the campaign: it
# survives, and it must, because no defence remains to fire. It is recorded rather than hidden.
mutant "BOTH subject/golden witnesses removed AND provenance subject desynchronised (expected survivor)" 7 '
import json
p="tests/golden/gate_013_differential.py"
s=open(p,encoding="utf-8").read().replace("if sub.get(key) != ev.get(key):","if False:",1)
open(p,"w",encoding="utf-8",newline="\n").write(s)
t="tests/golden/test_constrictor_save.py"
u=open(t,encoding="utf-8").read().replace("assert sub.get(key) == ev.get(key), (","assert True or sub.get(key) == ev.get(key), (",1)
open(t,"w",encoding="utf-8",newline="\n").write(u)
q="tests/golden/pending/013-constrictor/provenance.json"
d=json.load(open(q,encoding="utf-8"))
d["mission_state_differential"]["subject"]["mission_conhunt"]="MISSION_COMPLETE"
json.dump(d,open(q,"w",encoding="utf-8",newline="\n"),indent=2,sort_keys=True)
'

echo
echo "=================== KILLS: $kills/$n   SURVIVORS: $survivors ==================="
