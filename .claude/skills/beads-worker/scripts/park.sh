#!/usr/bin/env bash
# Park a bead the loop cannot finish: label it for Jon's inbox (`bd human list`), record why, undo
# the bead's unaccepted commits on the epic branch, and release the claim so it stops being handed
# back. The loop then picks up the next bead — it never waits for a human (CLAUDE.md hard rule 9).
#
# Undo is `git revert`, never a reset: a half-finished bead must not break later beads, and
# history is not rewritten. Uncommitted changes are left alone and named in the notes.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: park.sh <bead> \"<why>\"}"
why="${2:?usage: park.sh <bead> \"<why>\"}"
real_bd label add "$id" human >/dev/null 2>&1 || real_bd tag "$id" human >/dev/null 2>&1 || true

undo=""
base="$(bead_json "$id" | jq -r '.metadata.base_commit // empty')"
if [ -n "$base" ] && ! bead_has_label "$id" committed && [ -e "$DEV/.git" ]; then
  if ! dev_clean; then
    undo=" Uncommitted changes were left in oolite-dev; Jon decides what to keep."
  elif real_git -C "$DEV" merge-base --is-ancestor "$base" HEAD 2>/dev/null \
      && [ "$(real_git -C "$DEV" rev-list --count "$base..HEAD")" -gt 0 ]; then
    if real_git -C "$DEV" revert --no-edit "$base..HEAD" >/dev/null 2>&1; then
      undo=" Its commits since $base were reverted on $(dev_branch)."
    else
      real_git -C "$DEV" revert --abort >/dev/null 2>&1 || true
      undo=" Reverting its commits since $base failed; $(dev_branch) still holds them."
    fi
  fi
fi
real_bd update "$id" --append-notes "parked for Jon on $(date -u +%FT%TZ): $why.$undo" -q >&2
# --actor matters: bd defaults it to git user.name, but the bead was claimed as worker_actor, and
# bd refuses to unclaim a bead held by somebody else.
real_bd unclaim "$id" --actor "$(worker_actor)" -q >&2 || true
echo "parked $id: $why.$undo"
