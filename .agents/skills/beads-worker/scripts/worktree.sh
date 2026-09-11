#!/usr/bin/env bash
# Create (or reuse) .worktrees/<bead> on branch bead/<bead>, based on main. Print the absolute path.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: worktree.sh <bead>}"
base="${BEADS_WORKER_BASE_BRANCH:-main}"
path="$WORKTREES/$id"
branch="bead/$id"
mkdir -p "$WORKTREES"
if [ -d "$path" ]; then
  echo "$path"; exit 0
fi
if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$REPO_ROOT" worktree add "$path" "$branch" >/dev/null
else
  git -C "$REPO_ROOT" worktree add -b "$branch" "$path" "$base" >/dev/null
fi
echo "$path"
