#!/usr/bin/env bash
# Preserve a worker's work: commit anything left uncommitted in .worktrees/<bead> onto bead/<bead>.
# Workers are told to commit, but a worker that times out, crashes or forgets leaves the work in
# the worktree, invisible to the reviewer and to accept.sh. This makes it visible. Idempotent.
#   harvest.sh <bead>          commit uncommitted changes (if any); print what happened
# Exit 0 = worktree clean (nothing to do, or harvested) · 3 = no worktree for this bead.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# Fail fast before any path is computed (oo-aqzj): unsourced _lib.sh leaves these empty and
# "$WORKTREES/$id" becomes "/$id" - a path at the filesystem root. Keep above the first use.
: "${REPO_ROOT:?_lib.sh not sourced (REPO_ROOT unset): refusing to compute paths from an empty prefix}" \
  "${WORKTREES:?_lib.sh not sourced (WORKTREES unset): refusing to compute paths from an empty prefix}"
id="${1:?usage: harvest.sh <bead>}"
branch="bead/$id"; path="$WORKTREES/$id"; base="${BEADS_WORKER_BASE_BRANCH:-main}"
[ -d "$path/.git" ] || [ -f "$path/.git" ] || { echo "harvest: no worktree at $path" >&2; exit 3; }
# The worktree must be on its bead branch; a worker that checked something else out is put back.
cur="$(git -C "$path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)"
if [ "$cur" != "$branch" ]; then
  git -C "$path" checkout -q -B "$branch" 2>/dev/null || die "harvest: cannot return $path to $branch (was $cur)"
  echo "harvest $id: worktree was on $cur; returned to $branch"
fi
# Abort a merge or rebase a worker left half-done so the tree is committable; the notes get the fact.
if [ -f "$path/.git/MERGE_HEAD" ] || [ -d "$path/.git/rebase-merge" ] || [ -d "$path/.git/rebase-apply" ] \
   || git -C "$path" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  git -C "$path" merge --abort >/dev/null 2>&1 || git -C "$path" rebase --abort >/dev/null 2>&1 || true
  real_bd update "$id" --append-notes "harvest on $(date -u +%FT%TZ): a merge/rebase was left in progress in the worktree and was aborted; redo it" -q >&2
  echo "harvest $id: aborted an in-progress merge/rebase"
fi
if [ -n "$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
  n_before="$(git -C "$path" rev-list --count "$base..$branch" 2>/dev/null || echo 0)"
  git -C "$path" add -A
  git -C "$path" -c user.name=beads-worker -c user.email=beads-worker@local commit -q -m "bead $id: uncommitted work harvested by beads-worker" \
    || die "harvest: commit failed in $path"
  files="$(git -C "$path" show --stat --format= HEAD | tail -1)"
  real_bd update "$id" --append-notes "harvest on $(date -u +%FT%TZ): the worker left uncommitted changes; committed as $(git -C "$path" rev-parse --short HEAD) ($files). Workers must commit." -q >&2
  echo "harvest $id: committed leftover work ($files); branch had $n_before commit(s) before"
else
  echo "harvest $id: worktree clean"
fi
ahead="$(git -C "$REPO_ROOT" rev-list --count "$base..$branch" 2>/dev/null || echo 0)"
echo "harvest $id: $branch is $ahead commit(s) ahead of $base"
