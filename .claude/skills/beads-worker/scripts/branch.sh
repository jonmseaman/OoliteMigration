#!/usr/bin/env bash
# Put oolite-dev on the bead's epic branch, creating it once from develop. Prints the branch name.
#
# One branch per epic (`epic/<slug>`), not one per bead: every bead of the epic commits onto it,
# one commit per bead, and Jon merges the whole branch into develop locally when the epic is done.
# Records the commit the bead starts from (`base_commit`) so accept.sh can squash the bead's work
# into a single commit.
#
# Re-running for a bead already on its branch is a no-op and keeps the original base_commit.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: branch.sh <bead>}"
dev_clean || die "oolite-dev has uncommitted changes; commit or stash them before starting $id"

epic="$(epic_of "$id")"
[ -n "$epic" ] || die "bead $id has no parent epic; attach it with: bd update $id --parent <epic>"
branch="$(epic_branch "$epic")"
main="$(dev_main)"

if real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$branch"; then
  [ "$(dev_branch)" = "$branch" ] || real_git -C "$DEV" checkout -q "$branch"
else
  real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$main" \
    || die "oolite-dev has no local $main branch to start $branch from"
  real_git -C "$DEV" checkout -q -b "$branch" "$main"
fi
real_bd update "$epic" --set-metadata "branch=$branch" -q >&2 || true

# A retried bead keeps its first base so the squash covers every attempt.
base="$(bead_json "$id" | jq -r '.metadata.base_commit // empty')"
if [ -z "$base" ] || ! real_git -C "$DEV" merge-base --is-ancestor "$base" HEAD 2>/dev/null; then
  base="$(real_git -C "$DEV" rev-parse HEAD)"
  real_bd update "$id" --set-metadata "base_commit=$base" -q >&2 || true
fi
echo "$branch"
