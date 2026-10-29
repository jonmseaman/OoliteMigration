#!/usr/bin/env bash
# Exit 0 iff no ACTIONABLE bead matches the caller's selector, i.e. the loop has nothing left to do
# and should stop. Beads that are `committed` are done on the epic branch and waiting for Jon's
# merge, so they are reported but do not hold the loop open. Beads for a human or an interactive
# session (rebless, proposed-adr, design) are never counted, so the queue is always reachable
# without waiting for a human (CLAUDE.md hard rule 9).
#   queue-check.sh --parent oo-abc
# When it drains and some committed bead's epic is not yet `ready-to-merge`, it says to run
# epic-finish.sh for that epic.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ "$#" -gt 0 ] || die "usage: queue-check.sh <bd list selector…>   e.g. queue-check.sh --parent oo-abc"
open_beads="$(worker_list "$@" --status open,in_progress)"
actionable="$(printf '%s' "$open_beads" | jq -r '.[] | select(.issue_type != "epic") | select(((.labels // []) | index("committed")) | not) | "\(.id)\t\(.status)\t\(.title)"')"
done_ids="$(printf '%s' "$open_beads" | jq -r '.[] | select((.labels // []) | index("committed")) | .id' | nocr)"

if [ -n "$done_ids" ]; then
  echo "committed on the epic branch, awaiting Jon's merge into $(dev_main):"
  printf '%s' "$open_beads" | jq -r '.[] | select((.labels // []) | index("committed")) | "\(.id)\t\(.title)"'
fi
if [ -z "$actionable" ]; then
  echo "queue drained: nothing actionable for selector: $*"
  epics=""
  for b in $done_ids; do
    e="$(epic_of "$b")"
    [ -n "$e" ] && ! bead_has_label "$e" ready-to-merge && epics="$epics $e"
  done
  for e in $(printf '%s\n' $epics | sort -u); do
    echo "next: bash .claude/skills/beads-worker/scripts/epic-finish.sh $e"
  done
  exit 0
fi
echo "still actionable for selector: $*"
echo "$actionable"
exit 1
