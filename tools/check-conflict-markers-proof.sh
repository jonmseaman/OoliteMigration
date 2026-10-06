#!/usr/bin/env bash
# Fast proof (accept budget) that tools/guardrails.sh refuses merge-conflict markers (bead oo-w6uwu).
# The full set of marker cases lives in tools/guardrails-selftest ("=== markers"), which runs
# nightly ([oo-1gc.5] in tests/nightly/checks.txt) because it takes minutes. This runs the
# SHIPPING guard in one throwaway fixture repo: a planted marker must fail it, a clean edit and a
# seven-'=' line that predates the change must not. Nothing here touches this repository.
set -u
cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
TMPROOT="${TMPDIR:-${TEMP:-/tmp}}"
D="$(mktemp -d "$TMPROOT/oo-marker-proof.XXXXXX")" || exit 1
trap 'cd /; rm -rf "$D"' EXIT
g() { git -c user.email=s@l -c user.name=s "$@"; }
SEP=$(printf '=%.0s' 1 2 3 4 5 6 7); OURS=$(printf '<%.0s' 1 2 3 4 5 6 7); THEIRS=$(printf '>%.0s' 1 2 3 4 5 6 7)

# The guard's anti-vacuity checks need a protected golden and a collected test to exist, as in
# guardrails-selftest's fixture (whose goldens/ exemption line is dropped for the same reason).
mkdir -p "$D/tools" "$D/goldens" "$D/tests/golden/scenarios/001" "$D/upstream/oolite/tests/component/features" || exit 1
grep -v '^goldens/|not populated yet' "$REPO/tools/guardrails.sh" > "$D/tools/guardrails.sh"
cp "$REPO/tools/deny-list.txt" "$D/tools/" || exit 1
cd "$D" || exit 1
printf 'golden
' > goldens/g1.txt
printf '{}
' > tests/golden/scenarios/001/scenario.json
printf 'Feature: f
  Scenario: s
    Given a thing
' > upstream/oolite/tests/component/features/s1.feature
printf "project('x', 'c')\n" > meson.build
printf 'README\n%s\n' "$SEP" > readme.txt
g init -q -b main . && g add -A && g commit -qm base || exit 1
unset BEADS_WORKER_BASE_BRANCH OO_GUARDRAILS_BASE

fail=0
run() { OUT=$(bash tools/guardrails.sh 2>&1); RC=$?; }

printf "src = ['a.mm']\n" >> meson.build; printf 'more\n' >> readme.txt
run
if [ "$RC" -ne 0 ]; then echo "FAIL: clean edit (and a pre-existing 7-'=' line) refused:"; echo "$OUT"; fail=1
else echo "PASS: clean edit passes"; fi

g checkout -q -- .
printf '%s HEAD\na\n%s\nb\n%s main\n' "$OURS" "$SEP" "$THEIRS" >> meson.build
run
if [ "$RC" -eq 0 ] || ! printf '%s' "$OUT" | grep -qF 'merge-conflict marker'; then
  echo "FAIL: planted conflict markers not refused (rc=$RC):"; echo "$OUT"; fail=1
else echo "PASS: planted conflict markers refused"; fi

g checkout -q -- .
printf '%s ours\n' "$OURS" > new-untracked.txt
run
if [ "$RC" -eq 0 ] || ! printf '%s' "$OUT" | grep -qF 'new-untracked.txt'; then
  echo "FAIL: marker in an untracked file not refused (rc=$RC):"; echo "$OUT"; fail=1
else echo "PASS: marker in an untracked file refused"; fi

[ "$fail" -eq 0 ] && echo "check-conflict-markers-proof: OK"
exit "$fail"
