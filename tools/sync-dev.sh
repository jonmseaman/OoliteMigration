#!/usr/bin/env bash
# Bring oolite-dev's develop up to date with the pull requests you merged on GitHub, and record the
# new commit in this repo. Run it after a review session; the bead loop never touches the pointer
# itself, so this repo only ever names a commit that went through a reviewed, merged pull request.
#
# Also deletes local bead branches whose work is now on develop. A branch that is NOT merged is
# left alone, however old it looks: an unmerged branch is somebody's open pull request or unlanded
# work, never litter.
#
#   bash tools/sync-dev.sh [--dry-run]
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
DEV="$ROOT/oolite-dev"
dry=0
[ "${1:-}" = "--dry-run" ] && dry=1
say() { echo "sync-dev: $*"; }
run() { if [ "$dry" -eq 1 ]; then echo "  would run: $*"; else "$@"; fi; }

[ -e "$DEV/.git" ] || { echo "sync-dev: oolite-dev is not checked out" >&2; exit 1; }
[ -z "$(git -C "$DEV" status --porcelain)" ] || {
  echo "sync-dev: oolite-dev has uncommitted changes; deal with them first:" >&2
  git -C "$DEV" status --short >&2; exit 1; }

main="$(git -C "$DEV" config --get git-town.main-branch || echo develop)"
git -C "$DEV" fetch -q origin
before="$(git -C "$DEV" rev-parse "$main")"
remote="$(git -C "$DEV" rev-parse "origin/$main")"

if [ "$before" = "$remote" ]; then
  say "$main already at $(git -C "$DEV" rev-parse --short "$main")"
elif git -C "$DEV" merge-base --is-ancestor "$remote" "$before"; then
  # Local $main is AHEAD of the fork. Under this workflow $main only ever moves by merging a pull
  # request on GitHub, so commits that exist only here were made directly to $main — exactly the
  # thing the pull-request flow exists to prevent. Refuse: inventing a merge or force-moving the
  # branch would bury them.
  echo "sync-dev: $main is $(git -C "$DEV" rev-list --count "origin/$main..$main") commit(s) ahead of origin/$main." >&2
  git -C "$DEV" log --oneline "origin/$main..$main" | sed 's/^/  /' >&2
  echo "sync-dev: those commits bypassed the pull-request flow. Move them onto a branch and propose them, or push them deliberately, then re-run." >&2
  exit 1
else
  [ "$(git -C "$DEV" branch --show-current)" = "$main" ] || run git -C "$DEV" checkout -q "$main"
  # Fast-forward only: a genuine divergence is a human's to resolve, not a merge invented here.
  run git -C "$DEV" merge --ff-only "origin/$main"
  say "$main $(git -C "$DEV" rev-parse --short "$before")..$(git -C "$DEV" rev-parse --short "$remote")"
fi

# Only bead branches are ever deleted. `git branch --merged` also lists master, main and any
# other long-lived branch that happens to be an ancestor of $main — deleting those would be
# destructive and is never what "clean up after a review session" means.
merged="$(git -C "$DEV" branch --merged "$main" --format '%(refname:short)' | grep -E '^feature/' || true)"
if [ -n "$merged" ]; then
  say "deleting branches already on $main:"
  while IFS= read -r b; do [ -n "$b" ] && { echo "  $b"; run git -C "$DEV" branch -q -d "$b"; }; done <<<"$merged"
fi

recorded="$(git -C "$ROOT" rev-parse "HEAD:oolite-dev" 2>/dev/null || true)"
now="$(git -C "$DEV" rev-parse HEAD)"
if [ "$recorded" = "$now" ]; then
  say "pointer already records $(git -C "$DEV" rev-parse --short HEAD)"
  exit 0
fi
# Path-scoped: anything else dirty in this repo (goldens, notes, work in progress) is untouched.
run git -C "$ROOT" add -- oolite-dev
run git -C "$ROOT" commit -q -m "oolite-dev: sync $main to $(git -C "$DEV" rev-parse --short HEAD)" -- oolite-dev
say "recorded oolite-dev $(git -C "$DEV" rev-parse --short HEAD)"
