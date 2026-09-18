#!/usr/bin/env bash
# Replay every acceptance line individually from the worktree root, reporting per-line rc AND wall
# time. Not part of the deliverable - a scratch driver kept in the worktree, deleted before commit.
set -u

FILE="${1:-tests/golden/pending/013-constrictor/acceptance.txt}"
n=0; fail=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  n=$((n+1))
  t0=$(date +%s)
  OUT=$(bash -c "$line" 2>&1); rc=$?
  wall=$(( $(date +%s) - t0 ))
  if [ $rc -eq 0 ]; then
    printf '=== line %d: rc=0 wall=%ss GREEN\n' "$n" "$wall"
  else
    printf '=== line %d: rc=%d wall=%ss *** RED ***\n' "$n" "$rc" "$wall"
    fail=$((fail+1))
  fi
  printf '%s\n' "$OUT" | tail -6
  echo
done < "$FILE"
echo "TOTAL lines=$n red=$fail"
exit $fail
