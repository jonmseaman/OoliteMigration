#!/usr/bin/env bash
# Exit 0 iff no ACTIONABLE bead matches the caller's selector, i.e. the loop has nothing left to do
# and should stop. Beads whose pull request is open (`proposed`) are not actionable — they are
# waiting on Jon's review, not on the worker — so they are reported but do not hold the loop open.
# Human-only beads (rebless, proposed-adr) are never counted, so the queue is always reachable
# without waiting for a human (CLAUDE.md hard rule 10).
#   queue-check.sh --label phase:5
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ "$#" -gt 0 ] || die "usage: queue-check.sh <bd list selector…>   e.g. queue-check.sh --label phase:5"
open_beads="$(worker_list "$@" --status open,in_progress)"
actionable="$(printf '%s' "$open_beads" | jq -r '.[] | select(((.labels // []) | index("proposed")) | not) | "\(.id)\t\(.status)\t\(.title)"')"
awaiting="$(printf '%s' "$open_beads" | jq -r '.[] | select((.labels // []) | index("proposed")) | "\(.id)\t\(.metadata.pr // "?")\t\(.title)"')"

if [ -n "$awaiting" ]; then
  echo "awaiting your review and merge:"
  echo "$awaiting"
fi
if [ -z "$actionable" ]; then
  echo "queue drained: nothing actionable for selector: $*"
  exit 0
fi
echo "still actionable for selector: $*"
echo "$actionable"
exit 1
