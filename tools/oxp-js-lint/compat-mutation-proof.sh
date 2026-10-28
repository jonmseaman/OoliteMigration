#!/usr/bin/env bash
# Mutation proof for compat-selftest.js (ADR-0069 layer 2; validation harness, not a gate).
#
# Each mutant breaks one property the selftest protects. The selftest must go RED under every
# mutant and GREEN after the restore; the script exits nonzero if any mutant survives.
#   bash tools/oxp-js-lint/compat-mutation-proof.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)
RUL=tools/oxp-js-lint/compat-rules.js
survivors=0

mutate() {   # mutate <label> <old> <new>
  cp "$RUL" "$RUL.mutbak"
  "$PY" - "$RUL" "$2" "$3" <<'EOF'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
assert old in s, "mutant anchor not found: " + old
open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(old, new, 1))
EOF
  if node tools/oxp-js-lint/compat-selftest.js >/dev/null 2>&1; then
    printf 'SURVIVED  %s\n' "$1"; survivors=$((survivors + 1))
  else
    printf 'killed    %s\n' "$1"
  fi
  mv "$RUL.mutbak" "$RUL"
}

mutate "no masking (strings/comments scanned)" "const masked = mask(src);" "const masked = src;"
mutate "for-each blinded" 'for\\s+each\\s*\\(' 'for\\s+each\\s+never\\('
mutate "read-only table empty" "(m.writable === false ? ro : rw).add(name);" "rw.add(name);"
mutate "strict files not recognised" 'return /^(["'"'"'])use strict\1/.test(body);' 'return false;'
mutate "silent removed APIs dropped" 'for (const re of silent) hits.push' 'for (const re of []) hits.push'
mutate "own fields not told from Function.caller" 'if (owner && !owner.has(receiverBefore(masked, h.index))) h.severity = "INFO";' ''
mutate "catch names never collected" 'function catchNames(masked) {
  const names = new Set();' 'function catchNames(masked) {
  const names = new Set();
  return names;'

if node tools/oxp-js-lint/compat-selftest.js >/dev/null 2>&1; then echo "restored: GREEN"; else echo "restored: RED"; survivors=$((survivors + 1)); fi
git status --porcelain -- "$RUL"
exit "$survivors"
