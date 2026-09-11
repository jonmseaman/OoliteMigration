#!/usr/bin/env bash
# Create (or reuse) .worktrees/<bead> on branch bead/<bead>, based on the base branch. Print the path.
# `worktree.sh --remove <bead>` removes the worktree and deletes the branch (after close/escalate).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
if [ "${1:-}" = "--remove" ]; then
  # Never discards work: uncommitted changes are harvested first, and the branch is deleted only
  # if it is merged into the base branch. An unmerged branch (escalated bead) is kept for the
  # frontier agent, which recreates its worktree from it.
  id="${2:?usage: worktree.sh --remove <bead>}"; base="${BEADS_WORKER_BASE_BRANCH:-main}"
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -d "$WORKTREES/$id" ] && "$here/harvest.sh" "$id" >/dev/null 2>&1 || true
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREES/$id" >/dev/null 2>&1 || true
  if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/bead/$id"; then
    if git -C "$REPO_ROOT" merge-base --is-ancestor "bead/$id" "$base"; then
      git -C "$REPO_ROOT" branch -D "bead/$id" >/dev/null 2>&1; echo "removed worktree and merged branch for $id"
    else
      echo "removed worktree for $id; kept unmerged branch bead/$id ($(git -C "$REPO_ROOT" rev-list --count "$base..bead/$id") commit(s) not on $base)"
    fi
  else
    echo "removed worktree for $id (no branch)"
  fi
  exit 0
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
