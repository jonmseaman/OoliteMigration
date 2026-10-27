#!/usr/bin/env bash
# Print the bead's carry-over: previous attempts, acceptance failures, anything a past tick
# recorded. The notes are the ONLY state that survives between ticks, so read this before
# implementing anything.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: context.sh <bead>}"
echo "## Bead $id notes (previous attempts, failures, findings)"
notes="$(bead_field "$id" '.notes')"; [ -n "$notes" ] && echo "$notes" || echo "(none yet)"
echo
echo "## Attempts"
echo "attempts=$(bead_attempts "$id") stale_count=$(bead_json "$id" | jq -r '(.metadata.stale_count // "0")')"
