#!/usr/bin/env bash
# Hand a bead the fleet cannot finish to the frontier tier: fleet → frontier, add escalated, release.
# After this the bead no longer counts toward goal-check.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# Fail fast before any path is computed (oo-aqzj): unsourced _lib.sh leaves these empty and
# "$WORKTREES/$id" / "$REPO_ROOT/docs/..." land at the filesystem root. Keep above the first use.
: "${REPO_ROOT:?_lib.sh not sourced (REPO_ROOT unset): refusing to compute paths from an empty prefix}" \
  "${WORKTREES:?_lib.sh not sourced (WORKTREES unset): refusing to compute paths from an empty prefix}"
id="${1:?usage: escalate.sh <bead> <reason>}"; reason="${2:-escalated by beads-worker}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; base="${BEADS_WORKER_BASE_BRANCH:-main}"
# Preserve the fleet's partial work for the frontier agent: harvest, keep the branch, say where it is.
[ -d "$WORKTREES/$id" ] && "$here/harvest.sh" "$id" >&2 || true
if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/bead/$id"; then
  reason="$reason. Partial work: branch bead/$id, $(git -C "$REPO_ROOT" rev-list --count "$base..bead/$id") commit(s) ahead of $base (worktree.sh $id recreates the checkout)"
fi
real_bd update "$id" --remove-label fleet --add-label frontier --add-label escalated \
  --status open --assignee "" --append-notes "escalated on $(date -u +%FT%TZ): $reason" -q >&2
touch "$REPO_ROOT/.fleet-progress.$id"
phase="$(bead_json "$id" | jq -r '.labels[]? | select(startswith("phase:")) | sub("phase:";"")' | head -1)"
attempts="$(bead_attempts "$id")"
printf '| %s | %s | %s | %s | %s | |\n' "$(date -u +%F)" "$id" "${phase:-?}" "$attempts" "$(printf %s "$reason" | tr '|\n' '/ ')" >> "$REPO_ROOT/docs/fleet/FLEET_FAILURES.md"
echo "escalated $id: $reason"
