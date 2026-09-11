#!/usr/bin/env bash
# Print the context block to paste into a worker or reviewer task: the bead's notes (previous
# attempts, failures, review findings) and the tail of the shared learnings file.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: context.sh <bead> [learnings-lines]}"; n="${2:-40}"
echo "## Bead $id notes (previous attempts, failures, review findings)"
notes="$(bead_field "$id" '.notes')"; [ -n "$notes" ] && echo "$notes" || echo "(none yet)"
echo; echo "## Fleet learnings (last $n)"
grep -E '^- ' "$REPO_ROOT/docs/fleet/LEARNINGS.md" 2>/dev/null | tail -n "$n" || echo "(none yet)"
