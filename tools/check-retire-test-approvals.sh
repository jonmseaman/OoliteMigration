#!/usr/bin/env bash
# Fast proof of ADR-0049 retire-test-approvals (accept gate; full selftest is nightly).
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'tests/unit/game/test_defaults_bridge.mm' tools/retire-test-approvals.txt
grep -q 'tests/unit/game/meson.build' tools/retire-test-approvals.txt
grep -q 'retire_test_approval_on_record' tools/guardrails.sh
grep -q 'RETIRE_TEST_APPROVALS' tools/guardrails.sh

# Exercise the shell helpers by extracting and running them against sample lines.
RETIRE_TEST_APPROVALS=tools/retire-test-approvals.txt
retire_test_approval_on_record() {
  [ -f "$RETIRE_TEST_APPROVALS" ] || return 1
  local line first
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case "$line" in
      ''|'#'*) continue ;;
      [[:space:]]*) continue ;;
    esac
    first=${line%%[[:space:]]*}
    [ "$first" = "$1" ] && return 0
  done < "$RETIRE_TEST_APPROVALS"
  return 1
}

retire_test_approval_on_record 'upstream/oolite/tests/unit/game/test_defaults_bridge.mm' \
  || { echo 'missing approval for test_defaults_bridge.mm' >&2; exit 1; }
retire_test_approval_on_record 'upstream/oolite/tests/unit/game/meson.build' \
  || { echo 'missing approval for meson.build' >&2; exit 1; }
retire_test_approval_on_record 'upstream/oolite/tests/unit/game/no-such.mm' \
  && { echo 'unexpected approval for no-such.mm' >&2; exit 1; }

echo "check-retire-test-approvals: OK"
