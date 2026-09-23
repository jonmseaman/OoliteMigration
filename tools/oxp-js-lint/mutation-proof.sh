#!/usr/bin/env bash
# Mutation proof for the oo-ctq acceptance block (validation harness, not the gate).
#
# For each stored acceptance line, apply a mutant that breaks exactly the
# property that line protects, show the line go RED with a message naming the
# failure, restore, and show it GREEN. Run from the worktree root.
set -u
cd "$(dirname "$0")/../.." || exit 2
ACC=tools/oxp-js-lint/acceptance.txt
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)

run_line() {                     # run_line <n>
  local n=$1 line
  line=$("$PY" -c "import sys;print(open(sys.argv[1],encoding='utf-8').read().splitlines()[int(sys.argv[2])-1])" "$ACC" "$n")
  bash -o pipefail -c "$line" 2>&1
  return $?
}

report() {                       # report <label> <n>
  local label=$1 n=$2 out rc
  out=$(run_line "$n"); rc=$?
  printf -- '--- %s (line %d) rc=%d\n%s\n' "$label" "$n" "$rc" "$out"
}

backup() { cp "$1" "$1.mutbak"; }
restore() { mv "$1.mutbak" "$1"; }

CFG=tools/oxp-js-lint/eslint.config.js
RUL=tools/oxp-js-lint/rules.js
CLEAN=tools/oxp-js-lint/fixtures/clean.js

echo "=========== MUTANT 1: disable let-block in eslint.config.js (lines 1,2) ==========="
backup "$CFG"
"$PY" - "$CFG" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
open(p,'w',encoding='utf-8',newline='\n').write(s.replace('"let-block": "error"','"let-block": "off"'))
EOF
report "RED?  line 1 (rule set)" 1
report "RED?  line 2 (positive control)" 2
restore "$CFG"
report "GREEN line 1" 1
report "GREEN line 2" 2

echo "=========== MUTANT 2: stop masking comments (line 3, negative control) ==========="
backup "$RUL"
"$PY" - "$RUL" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
old='''    if (c === "/" && d === "/") {'''
new='''    if (false && c === "/" && d === "/") {'''
assert old in s
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(old,new,1))
EOF
report "RED?  line 3 (false positives)" 3
restore "$RUL"
report "GREEN line 3" 3

echo "=========== MUTANT 3: plant a let block in an in-tree script (line 4) ==========="
VICTIM=upstream/oolite/Resources/Scripts/oolite-conditions.js
backup "$VICTIM"
printf '\nthis.$mutant = function () { let (x = 1) { return x; } };\n' >> "$VICTIM"
report "RED?  line 4 (in-tree zero hits)" 4
restore "$VICTIM"
report "GREEN line 4" 4

echo "=========== MUTANT 4: make the corpus reader extract no .js members (line 5) ==========="
LNT=tools/oxp-js-lint/lint.js
backup "$LNT"
"$PY" - "$LNT" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
old='''e.name.toLowerCase().endsWith(".js") && e.size > 0'''
new='''e.name.toLowerCase().endsWith(".nope") && e.size > 0'''
assert s.count(old)>=1
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(old,new,1))
EOF
report "RED?  line 5 (corpus report)" 5
restore "$LNT"
report "GREEN line 5" 5

echo "=========== MUTANT 5: rules.js detector deleted for quote-method (line 1,2) ==========="
backup "$RUL"
"$PY" - "$RUL" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
old='''    detect: byRegex(/\\.\\s*quote\\s*\\(/),'''
new='''    detect: () => [],'''
assert old in s, "anchor for the quote-method detector not found"
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(old,new,1))
EOF
report "RED?  line 2 (positive control, quote-method blinded)" 2
restore "$RUL"
report "GREEN line 2" 2

echo "=========== MUTANT 6: legacy-generator detector blinded (line 2; bead oo-1gc.16) ==========="
backup "$RUL"
"$PY" - "$RUL" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
old='''        if (fn && !fn.gen) hits.push('''
new='''        if (false) hits.push('''
assert old in s, "anchor for the legacy-generator detector not found"
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(old,new,1))
EOF
report "RED?  line 2 (positive control, legacy-generator blinded)" 2
restore "$RUL"
report "GREEN line 2" 2

echo "=========== MUTANT 7: generator frames not recognised (line 3: function* in clean.js; bead oo-1gc.16) ==========="
backup "$RUL"
"$PY" - "$RUL" <<'EOF'
import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read()
old='''  if (k >= 0 && text[k] === "*") return { gen: true };'''
new='''  if (k >= 0 && text[k] === "*") return { gen: false };'''
assert old in s, "anchor for the function* frame not found"
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(old,new,1))
EOF
report "RED?  line 3 (false positive on an ES2015 generator)" 3
restore "$RUL"
report "GREEN line 3" 3

echo "=========== git status after mutation sweep ==========="
git status --porcelain
