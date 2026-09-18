#!/usr/bin/env bash
# Audit and clean what workers leave behind: bead/* branches and .worktrees/* checkouts.
# Rules (work is never discarded):
#   branch merged into the base branch, worktree clean -> delete branch and worktree (work is on main)
#   branch merged into the base branch, worktree dirty -> harvest onto the branch, KEEP both, exit 1
#   branch with no commits of its own             -> NOT started: keep (a live worker may be in it)
#   branch not merged, bead open/in_progress      -> harvest uncommitted work, keep (it is going round again)
#   branch not merged, bead closed or missing     -> WORK NOT ON MAIN: report, reopen the bead, exit 1
#   worktree with no branch                       -> harvest onto bead/<id> if it has changes, else remove
#   gc.sh --check   audit only, no changes; exit 1 if any work is at risk (used by goal-check)
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="${BEADS_WORKER_BASE_BRANCH:-main}"; check=0; [ "${1:-}" = "--check" ] && check=1
rc=0
git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
# Never fails (set -e): a bead that no longer exists reports "missing" and its branch is treated as at risk.
status_of() {
  local j; j="$(real_bd show "$1" --json 2>/dev/null || true)"
  [ -n "$j" ] && printf %s "$j" | jq -r '(if type=="array" then .[0] else . end) | .status // "missing"' 2>/dev/null || echo missing
}
# Has this branch any commit of its own, or is it still sitting where worktree.sh created it?
# `git merge-base --is-ancestor "$branch" "$base"` is TRUE for both a fully-merged bead and a
# brand-new worktree that has committed nothing (it was created AT $base, so it is trivially an
# ancestor). Telling them apart matters: the old code deleted live workers' worktrees for this.
# `rev-list --count "$base..$branch"` cannot do it either - it is 0 in BOTH cases, so using it
# alone as the merged-test would stop gc from ever cleaning a merged bead.
# The discriminator that works in both directions: accept.sh merges with --no-ff, so a merged
# bead's tip is a second parent and never sits on $base's own first-parent trunk, while an
# unstarted bead's tip IS a trunk commit (worktree.sh branched it from $base).
# Returns 0 = the branch contributed commits, 1 = it is still at $base (not started).
branch_contributed() {
  local tip trunk
  tip="$(git -C "$REPO_ROOT" rev-parse --verify --quiet "$1^{commit}" 2>/dev/null)" || return 1
  [ -n "$tip" ] || return 1
  # No pipe into grep here on purpose: _lib.sh sets pipefail and grep -q closing the pipe early
  # would make git rev-list die of SIGPIPE, turning a found tip into a failed test.
  trunk="$(git -C "$REPO_ROOT" rev-list --first-parent "$2" 2>/dev/null || true)"
  case $'\n'"$trunk"$'\n' in
    *$'\n'"$tip"$'\n'*) return 1;;
  esac
  return 0
}
# Remove a worktree, or report it and leave it ALONE. A failing `git worktree remove` is never a
# licence to rm -rf: "Device or resource busy" means a live process is holding the tree, and the
# old `git worktree remove --force ... || rm -rf "$path"` emptied a running worker's worktree
# (P0 oo-ymmj: bead oo-6zd lost its work that way). The only residue safe to clear is a directory
# git does not know about that is ALREADY EMPTY - and rmdir, which cannot destroy content, does it.
# Returns 0 = the worktree is gone, 1 = it is still there and was reported.
remove_worktree() {
  local path="$1" id="$2" err=""
  if [ ! -e "$path" ]; then
    git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    return 0
  fi
  if err="$(git -C "$REPO_ROOT" worktree remove --force "$path" 2>&1)"; then
    git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    return 0
  fi
  if printf %s "$err" | grep -qi 'not a working tree' && rmdir "$path" 2>/dev/null; then
    git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
    return 0
  fi
  echo "gc: REFUSING to force-remove worktree $id: $(printf %s "$err" | head -1)"
  echo "gc: worktree $id left in place, nothing was deleted; stop whatever is using it and rerun gc"
  return 1
}
for path in "$WORKTREES"/*/; do
  [ -d "$path" ] || continue
  id="$(basename "$path")"
  if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/bead/$id"; then
    if [ -n "$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
      echo "gc: worktree $id has changes but no branch bead/$id"
      [ $check -eq 1 ] && { rc=1; continue; }
      "$here/harvest.sh" "$id" >/dev/null && echo "gc: harvested $id onto bead/$id"
    else
      echo "gc: worktree $id is empty and has no branch"
      if [ $check -eq 0 ]; then
        if remove_worktree "$path" "$id"; then echo "gc: removed worktree $id"; else rc=1; fi
      fi
    fi
  fi
done
for branch in $(git -C "$REPO_ROOT" branch --list 'bead/*' --format='%(refname:short)'); do
  id="${branch#bead/}"; st="$(status_of "$id")"; path="$WORKTREES/$id"
  ahead="$(git -C "$REPO_ROOT" rev-list --count "$base..$branch" 2>/dev/null || echo 0)"
  dirty=""; [ -d "$path" ] && dirty="$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null || true)"
  # A branch that has committed nothing is NOT merged work, whatever merge-base says about it.
  if ! branch_contributed "$branch" "$base"; then
    echo "gc: $branch has no commits of its own (worktree still at $base): not started, kept"
    if [ -n "$dirty" ]; then
      echo "gc: $branch has uncommitted work in its worktree"
      [ $check -eq 1 ] && { rc=1; continue; }
      "$here/harvest.sh" "$id" >/dev/null && echo "gc: harvested $id"
    fi
    continue
  fi
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$branch" "$base"; then
    echo "gc: $branch is merged into $base (bead $st)"
    if [ $check -eq 1 ]; then
      # --check must SEE the hole it used to walk into: uncommitted work under a merged branch is
      # at risk, because the non-check path used to delete the worktree holding it.
      [ -n "$dirty" ] && { echo "gc: $branch is merged but its worktree still holds uncommitted work"; rc=1; }
      continue
    fi
    # accept.sh closes the bead before its worktree is retired. A bead still in_progress whose
    # branch is merged may have a worker living in the worktree: report, do not remove.
    if [ "$st" = "in_progress" ]; then
      echo "gc: $branch is merged but bead $id is still in_progress: worktree kept (a worker may be using it)"
      continue
    fi
    # MERGED IS NOT A LICENCE TO DELETE UNCOMMITTED WORK (oo-y8fa). The branch being on $base says
    # nothing about the files still sitting unstaged in the worktree: they are, by definition, not
    # in any commit and so not on $base either. The old code went straight to `worktree remove
    # --force`, which threw them away silently - the same silent-data-loss class oo-ymmj closed for
    # live workers. Harvest first, with the SAME helper the dirty path uses, then stop: the harvest
    # commit is NOT on $base, so deleting the branch here would destroy what we just rescued.
    # Keep worktree and branch, report, and exit non-zero so the caller runs accept.sh.
    if [ -n "$dirty" ]; then
      echo "gc: $branch is merged but its worktree still holds uncommitted work"
      if "$here/harvest.sh" "$id" >/dev/null; then
        echo "gc: harvested $id onto $branch before any cleanup; worktree and branch KEPT"
        echo "gc: $branch now has work that is NOT on $base: run accept.sh $id"
      else
        echo "gc: REFUSING to remove worktree $id: could not harvest its uncommitted work" >&2
        echo "gc: worktree $id left in place, nothing was deleted" >&2
      fi
      rc=1; continue
    fi
    if [ -d "$path" ] && ! remove_worktree "$path" "$id"; then rc=1; continue; fi
    git -C "$REPO_ROOT" branch -D "$branch" >/dev/null 2>&1 && echo "gc: removed $branch and its worktree"
    continue
  fi
  case "$st" in
    open|in_progress)
      if [ -n "$dirty" ]; then
        echo "gc: $branch (bead $st) has uncommitted work in its worktree"
        [ $check -eq 1 ] && { rc=1; continue; }
        "$here/harvest.sh" "$id" >/dev/null && echo "gc: harvested $id"
      else
        echo "gc: $branch (bead $st) unmerged, kept: $ahead commit(s) ahead"
      fi;;
    *)
      echo "gc: WORK NOT ON $base: $branch has $ahead unmerged commit(s) but bead $id is $st"
      rc=1
      if [ $check -eq 0 ]; then
        [ -n "$dirty" ] && "$here/harvest.sh" "$id" >/dev/null
        if [ "$st" = "closed" ]; then
          BEADS_ACCEPT=1 real_bd update "$id" --status open --append-notes "gc on $(date -u +%FT%TZ): reopened; $branch has commits that never reached $base. Run accept.sh $id." -q >&2 \
            && echo "gc: reopened $id; run accept.sh $id"
        fi
      fi;;
  esac
done
[ $rc -eq 0 ] && echo "gc: all bead work is on $base or on a live branch" || echo "gc: work at risk (see above)"
exit $rc
