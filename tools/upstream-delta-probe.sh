#!/usr/bin/env bash
#
# Proof that tools/upstream-delta.sh --check fails on each defect it claims to catch (bead oo-kih).
# Each case edits a copy of docs/UPSTREAM_DELTA.md and expects --check to pass or fail.
#
#     bash tools/upstream-delta-probe.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL="$REPO_ROOT/docs/UPSTREAM_DELTA.md"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

fails=0
probe() {  # probe <pass|fail> <description> <sed script or empty>
  local want="$1" what="$2" script="$3" got
  if [ -n "$script" ]; then sed "$script" "$REAL" >"$tmp"; else cp "$REAL" "$tmp"; fi
  if bash "$REPO_ROOT/tools/upstream-delta.sh" --file "$tmp" --check >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then echo "ok   $what ($got)"; else echo "FAIL $what: expected $want, got $got"; fails=$((fails + 1)); fi
}

row='| 0123abc | 2026-10-01 | `src/Core` | Example change | to-port | oo-abc1 |'

probe pass "the real file" ""
probe fail "no baseline" '/^Baseline:/d'
probe fail "a source directory missing from the table" '/^| `src\/Core\/Debug`/d'
probe fail "a module with Phase 3 work left open" 's/^| `src\/Core\/OXPVerifier` | frozen/| `src\/Core\/OXPVerifier` | open/'
probe fail "a module status that is neither frozen nor open" 's/^| `src\/Core\/Debug` | open/| `src\/Core\/Debug` | thawed/'
probe fail "a table row for a directory that does not exist" "/<!-- modules:end -->/i | \`src/NoSuchDir\` | open | x |"
probe pass "a well-formed delta row" "/<!-- delta:end -->/i $row"
probe fail "a to-port delta row without a bead" "/<!-- delta:end -->/i ${row/oo-abc1/-}"
probe fail "a delta row with an unknown status" "/<!-- delta:end -->/i ${row/to-port/maybe}"
openrow='| 0123abc | 2026-10-01 | `src/Core/Debug` | Example change | to-port | oo-abc1 |'
probe fail "a delta row in an open module" "/<!-- delta:end -->/i $openrow"
probe fail "a delta row whose commit is not a commit id" "/<!-- delta:end -->/i ${row/0123abc/HEAD}"

[ "$fails" -eq 0 ] || { echo "upstream-delta-probe: $fails case(s) wrong"; exit 1; }
echo "upstream-delta-probe: all cases as expected"
