#!/usr/bin/env bash
# tools/oxp-deps-mutants.sh - falsifiability proof for bead oo-kcrw's gate.
#
# For each substantive property the stored acceptance block protects, break
# EXACTLY that property and show the gate go RED naming the failure, then
# restore and show it GREEN again.  Every mutated file is backed up and restored
# by a trap, so an interrupted run leaves the tree clean.
#
# THE BASELINE IS CHECKED FIRST, FOR EVERY LINE THAT WILL BE MUTATED.  A line
# that is already red at baseline registers as a successful "kill" for every
# mutant and silently manufactures evidence that the gate discriminates when it
# does not.
set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || exit 2
[ -d /ucrt64/bin ] && export PATH="/ucrt64/bin:$PATH"
PY="$(command -v python3 || command -v python || echo /ucrt64/bin/python3)"

DEPS="tools/oxp_deps.py"
LOADC="tools/oxp_load_check.py"
COMP="tools/oxp-corpus/companions.json"
BACKUP_DIR="$(mktemp -d "${LOCALAPPDATA:-/tmp}/Temp/oo-kcrw-mutants.XXXXXX")"
restore() {
	for f in "$DEPS" "$LOADC" "$COMP"; do
		b="$BACKUP_DIR/$(basename "$f")"
		[ -f "$b" ] && cp "$b" "$f"
	done
}
trap 'restore; rm -rf "$BACKUP_DIR"' EXIT INT TERM
for f in "$DEPS" "$LOADC" "$COMP"; do cp "$f" "$BACKUP_DIR/$(basename "$f")"; done

fail=0
GATE_UNIT="$PY -m pytest tools/test_oxp_deps.py -q"

run_gate() { eval "$GATE_UNIT" 2>&1 | tail -6; return "${PIPESTATUS[0]}"; }

baseline() {
	echo "=== BASELINE: every line that will be mutated must be GREEN first ==="
	run_gate; local rc=$?
	if [ "$rc" -ne 0 ]; then
		echo "ABORT: the offline gate is ALREADY RED at baseline (rc=$rc)."
		echo "Every mutant would register a bogus kill against it. Fix the tree first."
		exit 2
	fi
	echo "baseline rc=0 (green)"
	echo
}

mutant() {  # mutant <name> <what it breaks> <sed-ish python edit>
	local name="$1" what="$2" edit="$3"
	echo "=== MUTANT: $name"
	echo "    breaks: $what"
	restore
	eval "$edit" || { echo "    MUTANT DID NOT APPLY - proof void"; fail=1; return; }
	local out rc
	out="$(run_gate)"; rc=$?
	echo "$out"
	if [ "$rc" -eq 0 ]; then
		echo "    *** GATE STAYED GREEN ON A BROKEN TREE - the line does not protect $what"
		fail=1
	else
		echo "    RED as required (rc=$rc)"
	fi
	restore
	out="$(run_gate)"; rc=$?
	if [ "$rc" -ne 0 ]; then
		echo "    *** RESTORE FAILED: still red after restoring (rc=$rc)"
		fail=1
	else
		echo "    restored -> GREEN (rc=0)"
	fi
	echo
}

py_edit() {  # py_edit FILE OLD NEW
	"$PY" - "$1" "$2" "$3" <<-'PYEOF'
		import sys, pathlib
		p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
		if sys.argv[2] not in t:
		    sys.stderr.write("pattern not found: %r\n" % sys.argv[2][:60]); raise SystemExit(1)
		p.write_text(t.replace(sys.argv[2], sys.argv[3], 1), encoding="utf-8")
	PYEOF
}

baseline

# 1. THE CLOSURE WALK.  If dependencies are not collected, the seven expansions
#    oo-het measured go straight back to NOTLOADED.  Break the walk at the
#    narrowest point: stop following the requires edges.
mutant "closure-walk-collects-no-dependencies" \
	"the transitive requires_oxps walk (without it the 7 go back to NOTLOADED)" \
	"py_edit $DEPS '        deps = list(rec[\"requires\"])' '        deps = []'"

# 2. TRANSITIVITY specifically.  A walk that follows only DIRECT requirements
#    looks right on a 2-member group and under-stages a chain.  Mutate at the
#    narrowest point: queue a dependency only while expanding the ROOT.
mutant "closure-is-direct-only-not-transitive" \
	"transitivity - a dependency's own dependency must also be staged" \
	"py_edit $DEPS '            if dep and dep != ident and dep not in seen:
                stack.append(dep)         # <- cycle brake (b), append-time' '            if dep and dep != ident and dep not in seen and ident == root:
                stack.append(dep)'"

# 3. CYCLE HANDLING.  BOTH brakes must go: removing either alone still
#    terminates (measured - a one-sided mutant returned ['A','B'] and would have
#    been a false proof).  The mutant is run under a TIMEOUT so the proof is
#    "it hangs" rather than hanging this script.
echo "=== MUTANT: cycle-brakes-removed (both pop-time and append-time)"
echo "    breaks: termination on a cyclic dependency graph"
restore
py_edit "$DEPS" '        if ident in seen:
            continue                      # <- cycle brake (a), pop-time' '        if False:
            continue' \
&& py_edit "$DEPS" '            if dep and dep != ident and dep not in seen:
                stack.append(dep)         # <- cycle brake (b), append-time' '            if dep and dep != ident:
                stack.append(dep)' \
|| { echo "    MUTANT DID NOT APPLY"; fail=1; }
cyc_out="$(timeout 25 "$PY" -c "
import sys; sys.path.insert(0,'tools')
import oxp_deps as od
idx={'A':{'identifier':'A','title':'A','version':'1','url':'u','size':1,'sha256':'','requires':['B'],'optional':[]},
     'B':{'identifier':'B','title':'B','version':'1','url':'u','size':1,'sha256':'','requires':['A'],'optional':[]}}
o,m=od.closure(idx,'A'); print('returned', o[:10], 'len', len(o))
" 2>&1)"
cyc_rc=$?
echo "$cyc_out" | tail -3
if [ "$cyc_rc" -eq 124 ]; then
	echo "    HUNG (timeout 25s) as required - the visited set is what makes a cycle terminate"
else
	echo "    *** did not hang (rc=$cyc_rc); this mutant did not exercise the brake"
	fail=1
fi
restore
cyc_out="$(timeout 25 "$PY" -c "
import sys; sys.path.insert(0,'tools')
import oxp_deps as od
idx={'A':{'identifier':'A','title':'A','version':'1','url':'u','size':1,'sha256':'','requires':['B'],'optional':[]},
     'B':{'identifier':'B','title':'B','version':'1','url':'u','size':1,'sha256':'','requires':['A'],'optional':[]}}
o,m=od.closure(idx,'A'); print('RESTORED returned', o)
" 2>&1)"
cyc_rc=$?
echo "    $cyc_out"
[ "$cyc_rc" -eq 0 ] || { echo "    *** restore failed (rc=$cyc_rc)"; fail=1; }
echo

# 4. ATTRIBUTION.  Make a dependency's error be blamed on the primary - the
#    single mis-attribution the bead forbids.
mutant "attribution-first-owner-always-wins" \
	"per-expansion attribution (a dependency's error must not be blamed on the primary)" \
	"py_edit $DEPS '    for line in lines:
        low = line.lower()
        best_label, best_len = None, 0' '    for line in lines:
        low = line.lower()
        best_label, best_len = owners[0][\"label\"] if owners else None, 10**9'"

# 5. UNSATISFIABLE vs LOAD FAILURE.  Folding a missing-from-corpus requirement
#    into a load failure is a false accusation against the expansion.
mutant "unsatisfiable-reported-as-a-load-failure" \
	"the distinction between 'not in the corpus' and 'failed to load'" \
	"py_edit $DEPS '            missing.add(ident)
            continue
        order.append(ident)' '            order.append(ident)
            continue
        order.append(ident)'"

# 6. THE COMPANION TABLE'S WRITTEN REASON.  An entry with no argument is
#    indistinguishable from silencing XenonUI's error.
mutant "companion-entry-loses-its-written-reason" \
	"the requirement that a companion pairing states a reason and evidence" \
	"$PY -c \"
import json,pathlib
p=pathlib.Path('$COMP'); d=json.loads(p.read_text(encoding='utf-8'))
for k in d['companions']: d['companions'][k]['reason']='because'
p.write_text(json.dumps(d,indent=2),encoding='utf-8')
\""

# 7. THE VACUITY GUARD ITSELF, under grouping.  Weakening P5 for the primary is
#    the exact 'make tier1 exit 0' move the bead forbids.
mutant "group-P5-accepts-an-absent-primary" \
	"the vacuity guard: a primary absent from searchPaths.dumpAll must be NOTLOADED" \
	"py_edit $LOADC '    if not per[primary[\"identifier\"]][\"loaded\"]:' '    if False:'"

# 8. THE NO-MANIFEST EXEMPTION MUST NOT WIDEN.  Dropping the "every error line
#    matches" narrowing turns a documented legacy-fixture state into a blanket
#    pass for any expansion that also happens to lack a manifest.
mutant "no-manifest-exemption-widened-to-any-error" \
	"the narrowing that keeps the legacy-fixture state from becoming a silencer" \
	"py_edit $LOADC '    if all_errs and not unowned and all(NOMANIFEST_RE.search(l) for l in all_errs):' '    if all_errs and any(NOMANIFEST_RE.search(l) for l in all_errs):'"

echo "==============================================================="
if [ "$fail" -ne 0 ]; then
	echo "MUTATION HARNESS FAILED: at least one property is not protected."
	exit 1
fi
echo "MUTATION HARNESS OK: every mutant went RED, every restore went GREEN."
