#!/usr/bin/env bash
# Hand a bead the fleet cannot finish to the frontier tier: fleet → frontier, add escalated, release.
# After this the bead no longer counts toward goal-check.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: escalate.sh <bead> <reason>}"; reason="${2:-escalated by beads-worker}"
real_bd update "$id" --remove-label fleet --add-label frontier --add-label escalated \
  --status open --assignee "" --append-notes "escalated on $(date -u +%FT%TZ): $reason" -q >&2
touch "$REPO_ROOT/.fleet-progress.$id"
phase="$(bead_json "$id" | jq -r '.labels[]? | select(startswith("phase:")) | sub("phase:";"")' | head -1)"
attempts="$(bead_attempts "$id")"
printf '| %s | %s | %s | %s | %s | |\n' "$(date -u +%F)" "$id" "${phase:-?}" "$attempts" "$(printf %s "$reason" | tr '|\n' '/ ')" >> "$REPO_ROOT/docs/fleet/FLEET_FAILURES.md"
echo "escalated $id: $reason"
