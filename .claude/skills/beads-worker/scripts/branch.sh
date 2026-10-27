#!/usr/bin/env bash
# Start a bead's branch in oolite-dev: feature/MMDD-slug, appended to the Git Town main branch
# (develop). Prints the branch name.
#
# Bead branches are siblings, not a stack: each one is appended to develop so you can review and
# merge them on GitHub in any order. A bead that genuinely needs another bead's unmerged work
# should depend on it in beads (`bd dep add`) and wait, rather than stack on it.
#
# Re-running for a bead already on its branch is a no-op, so a retried bead keeps its branch and
# its open pull request.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: branch.sh <bead>}"
dev_clean || die "oolite-dev has uncommitted changes; commit or stash them before starting $id"

existing="$(bead_json "$id" | jq -r '.metadata.branch // empty')"
current="$(dev_branch)"
if [ -n "$existing" ]; then
  if [ "$current" != "$existing" ]; then
    real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$existing" \
      || die "bead $id records branch $existing but it no longer exists in oolite-dev"
    real_git -C "$DEV" checkout -q "$existing"
  fi
  echo "$existing"
  exit 0
fi

main="$(dev_main)"
branch="$(bead_branch_name "$id")"
real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$branch" \
  && die "branch $branch already exists in oolite-dev but no bead claims it; rename or remove it"
[ "$current" = "$main" ] || real_git -C "$DEV" checkout -q "$main"
( cd "$DEV" && git town append "$branch" ) >&2
real_bd update "$id" --set-metadata "branch=$branch" -q >&2 || true
echo "$branch"
