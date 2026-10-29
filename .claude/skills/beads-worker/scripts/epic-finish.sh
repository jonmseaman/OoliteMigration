#!/usr/bin/env bash
# Finish an epic: when every bead under it is committed (or parked for Jon), run the end gate on the
# epic branch and mark the epic `ready-to-merge`. Run by the loop when queue-check.sh drains.
# Nothing is merged or pushed here: Jon merges the branch into develop locally and pushes it, and
# land.sh closes the epic's beads when it sees the merge.
#
#   epic-finish.sh <epic>
#
# The gate is the list in BEADS_EPIC_GATE (one command per line, run from oolite-dev), default:
# build, then the unit, component, smoke and GUI tiers. Each command gets up to an hour. Safe to
# re-run: a failed gate leaves the epic as it was and records the failure in its notes.
#
# Exit 0 = ready to merge · 1 = not finishable (reason printed and noted on the epic).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
epic="${1:?usage: epic-finish.sh <epic>}"
[ "$(bead_field "$epic" '.issue_type')" = "epic" ] || die "$epic is not an epic"
branch="$(epic_branch "$epic")"
main="$(dev_main)"

real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$branch" \
  || die "epic $epic has no branch $branch in oolite-dev; nothing was committed for it"
dev_clean || die "oolite-dev has uncommitted changes; commit or discard them before finishing $epic"
[ "$(dev_branch)" = "$branch" ] || real_git -C "$DEV" checkout -q "$branch"

# Every child must be done on the branch, parked for Jon, or (interactive) accepted. Unfiltered on
# purpose: `design` beads are not the loop's but they still gate the epic.
open="$(real_bd list --parent "$epic" --status open,in_progress,blocked --json -n 0 2>/dev/null \
  | jq -r '.[] | select(((.labels // []) | (index("committed") or index("human"))) | not) | select(.issue_type != "epic") | "\(.id)\t\(.status)\t\(.title)"' | nocr || true)"
if [ -n "$open" ]; then
  echo "epic $epic is not finishable; these beads are still open:"
  echo "$open"
  exit 1
fi
parked="$(real_bd list --parent "$epic" --status open,in_progress,blocked --label human --json -n 0 2>/dev/null \
  | jq -r '.[] | "\(.id)\t\(.title)"' | nocr || true)"

gate="${BEADS_EPIC_GATE:-./mk.sh build test
tests/run.sh unit
tests/run.sh component
tests/run.sh smoke
tests/run.sh gui}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
while IFS= read -r cmd; do
  case "$cmd" in ''|'#'*) continue;; esac
  echo "\$ $cmd" >>"$log"
  rc=0
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$DEV" && timeout 3600 bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  else
    ( cd "$DEV" && bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    status=$rc
    echo "[exit $rc]" >>"$log"
    break
  fi
done <<<"$gate"

if [ "$status" -ne 0 ]; then
  tail_out="$(tail -c 3000 "$log")"
  real_bd update "$epic" --append-notes "end gate failed on $(date -u +%FT%TZ):
$tail_out" -q >&2
  echo "epic $epic: end gate failed; recorded in its notes. File a fix bead under the epic, then re-run."
  echo "$tail_out"
  exit 1
fi

real_bd label add "$epic" ready-to-merge >/dev/null 2>&1 || real_bd tag "$epic" ready-to-merge >/dev/null 2>&1 || true
real_bd update "$epic" --set-metadata "branch=$branch" --set-metadata "finished_at=$(date -u +%FT%TZ)" \
  --append-notes "end gate passed on $(date -u +%FT%TZ). Ready for Jon to merge $branch into $main." -q >&2
echo "epic $epic: end gate passed; $branch is ready to merge."
[ -z "$parked" ] || { echo "parked for Jon (not in the branch):"; echo "$parked"; }
cat <<EOF
To merge (Jon):
  git -C oolite-dev checkout $main
  git -C oolite-dev merge --no-ff $branch      # or rebase it onto $main and fast-forward
  git -C oolite-dev push origin $main
EOF
exit 0
