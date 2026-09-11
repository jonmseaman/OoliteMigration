#!/usr/bin/env bash
# Create (or reuse) .worktrees/<bead> on branch bead/<bead>, based on the base branch. Print the path.
# `worktree.sh --remove <bead>` removes the worktree and deletes the branch (after close/escalate).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
if [ "${1:-}" = "--remove" ]; then
  id="${2:?usage: worktree.sh --remove <bead>}"
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREES/$id" >/dev/null 2>&1 || true
  git -C "$REPO_ROOT" branch -D "bead/$id" >/dev/null 2>&1 || true
  echo "removed worktree and branch for $id"; exit 0
fi
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
