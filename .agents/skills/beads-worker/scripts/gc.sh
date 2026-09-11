#!/usr/bin/env bash
# Audit and clean what workers leave behind: bead/* branches and .worktrees/* checkouts.
# Rules (work is never discarded):
#   branch merged into the base branch            -> delete branch and worktree (the work is on main)
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
      [ $check -eq 1 ] || { git -C "$REPO_ROOT" worktree remove --force "$path" >/dev/null 2>&1 || rm -rf "$path"; echo "gc: removed worktree $id"; }
    fi
  fi
done
for branch in $(git -C "$REPO_ROOT" branch --list 'bead/*' --format='%(refname:short)'); do
  id="${branch#bead/}"; st="$(status_of "$id")"; path="$WORKTREES/$id"
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$branch" "$base"; then
    echo "gc: $branch is merged into $base (bead $st)"
    [ $check -eq 1 ] && continue
    [ -d "$path" ] && { git -C "$REPO_ROOT" worktree remove --force "$path" >/dev/null 2>&1 || rm -rf "$path"; }
    git -C "$REPO_ROOT" branch -D "$branch" >/dev/null 2>&1 && echo "gc: removed $branch and its worktree"
    continue
  fi
  dirty=""; [ -d "$path" ] && dirty="$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null)"
  case "$st" in
    open|in_progress)
      if [ -n "$dirty" ]; then
        echo "gc: $branch (bead $st) has uncommitted work in its worktree"
        [ $check -eq 1 ] && { rc=1; continue; }
        "$here/harvest.sh" "$id" >/dev/null && echo "gc: harvested $id"
      else
        echo "gc: $branch (bead $st) unmerged, kept: $(git -C "$REPO_ROOT" rev-list --count "$base..$branch") commit(s) ahead"
      fi;;
    *)
      echo "gc: WORK NOT ON $base: $branch has $(git -C "$REPO_ROOT" rev-list --count "$base..$branch") unmerged commit(s) but bead $id is $st"
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
