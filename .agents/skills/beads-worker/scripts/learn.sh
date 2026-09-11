#!/usr/bin/env bash
# Record a cross-bead learning: one line into docs/fleet/LEARNINGS.md and the same line into the
# bead's notes. Use for things the *next* bead should know; per-bead detail goes in notes only.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: learn.sh <bead> \"<one-line learning>\"}"; text="${2:?usage: learn.sh <bead> \"<one-line learning>\"}"
text="$(printf %s "$text" | tr '\n' ' ')"
line="- $(date -u +%F) [$id] $text"
echo "$line" >> "$REPO_ROOT/docs/fleet/LEARNINGS.md"
real_bd update "$id" --append-notes "learning: $text" -q >&2
echo "$line"
