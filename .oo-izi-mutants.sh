#!/usr/bin/env bash
# SCRATCH mutation harness for bead oo-izi. Lives in the worktree; deleted before the final commit.
#
# For every property the gate defends: one mutant that corrupts the DATA and one that weakens the
# CHECKER. All mutation happens in a THROWAWAY COPY of the tree under $LOCALAPPDATA/Temp; the
# worktree is never modified, so a crashed run cannot strand a mutated file.
set -u
export PATH=/ucrt64/bin:$PATH
PY=$(command -v python3)
SRC="C:/Users/jon/OoliteMigration/.worktrees/oo-izi"
W="${LOCALAPPDATA}/Temp/oo_izi_mut"
rm -rf "$W"; mkdir -p "$W"
NW=$(cygpath -m "$W")

PASS=0; FAIL=0

# Copy the pieces the offline gate needs into a throwaway tree.
setup() {
  rm -rf "$W/t"; mkdir -p "$W/t/tests/golden/pending/003-combat" "$W/t/upstream/oolite/tests/component" "$W/t/goldens"
  cp "$SRC"/tests/golden/{combat.py,check_combat_evidence.py,test_combat.py,gate_003_spec.py,golden_diff.py,golden_run.py} "$W/t/tests/golden/"
  cp -r "$SRC/tests/golden/dump" "$W/t/tests/golden/dump"
  cp "$SRC"/tests/golden/pending/003-combat/* "$W/t/tests/golden/pending/003-combat/"
  cp "$SRC/upstream/oolite/tests/component/console.py" "$W/t/upstream/oolite/tests/component/"
  cp "$SRC/tests/golden/pytest.ini" "$W/t/tests/golden/" 2>/dev/null || true
}

# run <label> <expect: RED|GREEN> <command...>
run() {
  local label="$1" expect="$2"; shift 2
  local out rc
  out=$(cd "$W/t" && "$@" 2>&1); rc=$?
  local got="GREEN"; [ $rc -ne 0 ] && got="RED"
  if [ "$got" = "$expect" ]; then
    PASS=$((PASS+1)); echo "  [KILL] $label -> rc=$rc ($got, expected $expect)"
  else
    FAIL=$((FAIL+1)); echo "  [SURVIVOR] $label -> rc=$rc ($got, expected $expect)  *** THE GATE DOES NOT DISCRIMINATE ***"
  fi
  echo "$out" | grep -E "FAIL:|NO EVIDENCE|REFUSED|assert|Error|passed|failed|PASS:" | head -4 | sed 's/^/        /'
}

echo "=== BASELINE: every offline line must be GREEN before any mutant is applied ==="
setup
run "baseline gate_003_spec.py"        GREEN "$PY" tests/golden/gate_003_spec.py
run "baseline check_combat_evidence"   GREEN "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
run "baseline pytest test_combat.py"   GREEN "$PY" -m pytest tests/golden/test_combat.py -q -p no:cacheprovider
run "baseline golden_diff self-refuse" RED   "$PY" tests/golden/golden_diff.py tests/golden/pending/003-combat/state.json tests/golden/pending/003-combat/state.json
echo

# --- property: DAMAGE WAS DEALT --------------------------------------------------------------
echo "=== P1 damage_events: the engine dispatched shipTakingDamage on the victim ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(p));d['evidence']['damage_events']=0
open(p,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P1-DATA    zero damage_events in the golden copy" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if ev.get("damage_events", 0) < 1:','if False:')
s=s.replace('REQUIRED_POSITIVE = ("damage_events", "kill_events", "strikes_delivered", "ticks")',
            'REQUIRED_POSITIVE = ("kill_events", "strikes_delivered", "ticks")')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(q));d['evidence']['damage_events']=0
open(q,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P1-CHECKER both damage_events defences removed, fed a zero" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
echo

# --- property: A SHIP DIED -------------------------------------------------------------------
echo "=== P2 death_events: the engine dispatched shipDied exactly once ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(p));d['evidence']['death_events']=0
open(p,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P2-DATA    zero death_events (nobody died)" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if ev.get("death_events") != EXPECTED_DEATH_EVENTS:','if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(q));d['evidence']['death_events']=0
open(q,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P2-CHECKER death_events clause deleted, fed a zero" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
echo

# --- property: THE KILL IS ATTRIBUTED TO OUR ATTACKER ----------------------------------------
echo "=== P3 kill_events: the engine attributed the kill to THIS scenario's attacker ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(p));d['evidence']['kill_events']=0
open(p,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P3-DATA    zero kill_events (death unattributed)" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if ev.get("kill_events", 0) < 1:','if False:')
s=s.replace('REQUIRED_POSITIVE = ("damage_events", "kill_events", "strikes_delivered", "ticks")',
            'REQUIRED_POSITIVE = ("damage_events", "strikes_delivered", "ticks")')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(q));d['evidence']['kill_events']=0
open(q,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P3-CHECKER both kill_events defences removed, fed a zero" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
echo

# --- property: THE CAST FELL BY EXACTLY ONE (handle-scoped, not a role count) -----------------
echo "=== P4 cast_alive 2 -> 1: the scenario's own two handles ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(p));d['evidence']['cast_alive_after']=2
open(p,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P4-DATA    both ships still alive after the encounter" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if before != 2 or after != 1:','if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(q));d['evidence']['cast_alive_after']=2;d['evidence']['victim_destroyed']=True
open(q,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P4-CHECKER cast_alive clause deleted, fed 2 -> 2" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
echo

# --- property: DAMAGE TOTAL WAS NONZERO ------------------------------------------------------
echo "=== P5 damage_total: the strike landed for more than zero ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(p));d['evidence']['damage_total']=0.0
open(p,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P5-DATA    damage_total zeroed" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if not isinstance(total, (int, float)) or total <= 0:','if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/state.json'
d=json.load(open(q));d['evidence']['damage_total']=0.0
open(q,'w',newline='\n').write(json.dumps(d,sort_keys=True,separators=(',',':')))
EOF
run "P5-CHECKER damage_total clause deleted, fed a zero" RED "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
echo

# --- property: THE DETERMINISM KNOBS ---------------------------------------------------------
echo "=== P6 seed: pinned, read, and equal to the value the golden was blessed with ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(p));d['seed']=31337
json.dump(d,open(p,'w',newline='\n'),indent=2)
EOF
run "P6-DATA    spec seed changed 20260918 -> 31337 (oo-3ya's survivor)" RED "$PY" tests/golden/gate_003_spec.py
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/gate_003_spec.py'
s=open(p,encoding='utf-8').read()
s=s.replace('    if drift:','    if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(q));d['seed']=31337
json.dump(d,open(q,'w',newline='\n'),indent=2)
EOF
run "P6-CHECKER provenance-drift clause deleted, fed a changed seed" RED "$PY" tests/golden/gate_003_spec.py
echo

echo "=== P7 ticks: cut so the encounter cannot complete ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(p));d['ticks']=0
json.dump(d,open(p,'w',newline='\n'),indent=2)
EOF
run "P7-DATA    spec ticks -> 0" RED "$PY" tests/golden/gate_003_spec.py
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/gate_003_spec.py'
s=open(p,encoding='utf-8').read()
s=s.replace('    if not isinstance(spec["ticks"], int) or spec["ticks"] < 1:','    if False:')
s=s.replace('    if drift:','    if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(q));d['ticks']=0
json.dump(d,open(q,'w',newline='\n'),indent=2)
EOF
run "P7-CHECKER ticks predicate AND drift clause deleted, fed ticks=0" RED "$PY" tests/golden/gate_003_spec.py
echo

echo "=== P8 the cast is pinned by SHIP KEY, not by role (finding 1) ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(p));d['victim_key']='pirate'
json.dump(d,open(p,'w',newline='\n'),indent=2)
EOF
run "P8-DATA    victim_key reverted to the role 'pirate'" RED "$PY" tests/golden/gate_003_spec.py
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/gate_003_spec.py'
s=open(p,encoding='utf-8').read()
s=s.replace('''        if not (isinstance(value, str) and value.startswith("[") and value.endswith("]")
                and len(value) > 2):''','''        if False:''')
s=s.replace('    if drift:','    if False:')
open(p,'w',encoding='utf-8',newline='\n').write(s)
import json
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(q));d['victim_key']='pirate'
json.dump(d,open(q,'w',newline='\n'),indent=2)
EOF
run "P8-CHECKER ship-key predicate AND drift clause deleted, fed a role" RED "$PY" tests/golden/gate_003_spec.py
echo

echo "=== P9 a knob must be READ by combat.py, not merely declared ==="
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/combat.py'
s=open(p,encoding='utf-8').read()
s=s.replace('float(spec["strike_damage"]), float(spec["strike_range"])','60.0, 2500.0')
assert '60.0, 2500.0' in s
open(p,'w',encoding='utf-8',newline='\n').write(s)
EOF
run "P9-DATA    strike_damage/strike_range hardcoded in combat.py" RED "$PY" tests/golden/gate_003_spec.py
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/gate_003_spec.py'
s=open(p,encoding='utf-8').read()
s=s.replace("""        if 'spec["%s"]' % knob not in source:""","""        if False:""")
open(p,'w',encoding='utf-8',newline='\n').write(s)
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/combat.py'
t=open(q,encoding='utf-8').read().replace('float(spec["strike_damage"]), float(spec["strike_range"])','60.0, 2500.0')
open(q,'w',encoding='utf-8',newline='\n').write(t)
EOF
run "P9-CHECKER knob-is-read predicate deleted, fed a hardcoded knob" RED "$PY" tests/golden/gate_003_spec.py
echo

echo "=== P10 quantisation cannot be coarsened to manufacture agreement ==="
setup
"$PY" - <<'EOF'
import json;p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
d=json.load(open(p));d['quant_decimals']=0
json.dump(d,open(p,'w',newline='\n'),indent=2)
EOF
run "P10-DATA   spec quant_decimals -> 0" RED "$PY" tests/golden/gate_003_spec.py
setup
"$PY" - <<'EOF'
import json
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/provenance.json'
d=json.load(open(p));d['quant_decimals']=0;d['scenario_knobs']['quant_decimals']=0
json.dump(d,open(p,'w',newline='\n'),indent=2)
q=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/pending/003-combat/spec.json'
e=json.load(open(q));e['quant_decimals']=0
json.dump(e,open(q,'w',newline='\n'),indent=2)
EOF
run "P10-CHECKER spec AND provenance both coarsened to 0 (no drift to find)" RED "$PY" tests/golden/gate_003_spec.py
echo

echo "=== P11 a mutated CHECKER must still be caught by the test suite ==="
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/check_combat_evidence.py'
s=open(p,encoding='utf-8').read()
s=s.replace('if ev.get("kill_events", 0) < 1:','if False:')
s=s.replace('REQUIRED_POSITIVE = ("damage_events", "kill_events", "strikes_delivered", "ticks")',
            'REQUIRED_POSITIVE = ("damage_events", "strikes_delivered", "ticks")')
open(p,'w',encoding='utf-8',newline='\n').write(s)
EOF
run "P11-CHECKER kill_events defences removed -> pytest must go red" RED "$PY" -m pytest tests/golden/test_combat.py -q -p no:cacheprovider
setup
"$PY" - <<'EOF'
p=r'C:/Users/jon/AppData/Local/Temp/oo_izi_mut/t/tests/golden/combat.py'
s=open(p,encoding='utf-8').read()
s=s.replace('"velocity.magnitude() > 0.0005"','"velocity.magnitude > 0.0005"')
s=s.replace("s[i].velocity.magnitude() > 0.0005","s[i].velocity.magnitude > 0.0005")
open(p,'w',encoding='utf-8',newline='\n').write(s)
EOF
run "P11-DATA   motion guard reverted to the always-false form -> pytest must go red" RED "$PY" -m pytest tests/golden/test_combat.py -q -p no:cacheprovider
echo

echo "=== RESTORED: the real worktree is untouched and still green ==="
setup
run "restored gate_003_spec.py"      GREEN "$PY" tests/golden/gate_003_spec.py
run "restored check_combat_evidence" GREEN "$PY" tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
run "restored pytest"                GREEN "$PY" -m pytest tests/golden/test_combat.py -q -p no:cacheprovider
echo
echo "RESULT: $PASS killed / $((PASS+FAIL)) total, $FAIL survivor(s)"
rm -rf "$W"
[ $FAIL -eq 0 ]
