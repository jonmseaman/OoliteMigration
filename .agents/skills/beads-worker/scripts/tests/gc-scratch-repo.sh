#!/usr/bin/env bash
# Build a THROWAWAY beads-worker repo for exercising gc.sh, and print its path.
# Never point a gc.sh experiment at a real repo: gc.sh removes worktrees and branches, and the
# defect this harness exists to pin (P0 oo-ymmj) destroyed a live worker's worktree.
#
#   gc-scratch-repo.sh <dir> <gc.sh to install> [scenario...]
#
# Scenarios (repeatable, order-independent):
#   live:<id>     bead <id> in_progress, worktree created at main with ZERO commits (a worker
#                 that has not committed yet). Must survive gc.
#   locked:<id>   like live:, plus `git worktree lock` so `git worktree remove` FAILS - the
#                 portable stand-in for "Device or resource busy". Must survive gc intact.
#   dirty:<id>    bead <id> in_progress, worktree with uncommitted work. Must be harvested.
#   merged:<id>   bead <id> closed, branch merged into main exactly as accept.sh does it
#                 (--no-ff merge commit on main). Worktree and branch must be cleaned up.
#   mergeddirty:<id>  like merged:, but the worktree ALSO holds an uncommitted leftover.txt whose
#                 content is "precious uncommitted work". Merged does NOT put that file on main,
#                 so removing the worktree destroys it (oo-y8fa): it must be harvested or refused.
# A stub `bd` serving the bead statuses is put first on PATH, so no real beads database is touched.
set -euo pipefail
dir="${1:?usage: gc-scratch-repo.sh <dir> <gc.sh> [scenario...]}"
gc_src="${2:?usage: gc-scratch-repo.sh <dir> <gc.sh> [scenario...]}"
shift 2
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$dir"; dir="$(cd "$dir" && pwd)"
git -C "$dir" init -q -b main .
git -C "$dir" config user.email scratch@local
git -C "$dir" config user.name scratch
echo base >"$dir/base.txt"
git -C "$dir" add -A
git -C "$dir" -c commit.gpgsign=false commit -qm "base commit"
mkdir -p "$dir/.worktrees" "$dir/scripts" "$dir/stub"
# The scripts under test: the gc.sh being exercised, beside the real _lib.sh and harvest.sh.
cp "$gc_src" "$dir/scripts/gc.sh"
# goal-check.sh goes in too: it is the layer that filters gc.sh's output, and the `goalcheck`
# scenario in gc-safety.test.sh exercises that filter against the same scratch scenarios.
cp "$here/../_lib.sh" "$here/../harvest.sh" "$here/../goal-check.sh" "$dir/scripts/"
chmod +x "$dir/scripts/"*.sh
# Stub bd: `bd show <id> --json` answers from statuses file; every other subcommand is a no-op.
: >"$dir/stub/statuses"
cat >"$dir/stub/bd" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = "show" ]; then
  st="$(grep -E "^${2}=" "$(dirname "$0")/statuses" 2>/dev/null | head -1 | cut -d= -f2)"
  [ -n "$st" ] || st=missing
  printf '{"id":"%s","status":"%s"}\n' "$2" "$st"
  exit 0
fi
exit 0
STUB
chmod +x "$dir/stub/bd"
commit_in() { # commit_in <worktree> <message>
  git -C "$1" -c user.email=scratch@local -c user.name=scratch -c commit.gpgsign=false commit -qm "$2"
}
for spec in "$@"; do
  kind="${spec%%:*}"; id="${spec#*:}"
  case "$kind" in
    live|locked)
      echo "$id=in_progress" >>"$dir/stub/statuses"
      git -C "$dir" worktree add -q -b "bead/$id" "$dir/.worktrees/$id" main
      # A real worker's worktree has files in it; they are what the old gc.sh destroyed.
      echo "work in progress by a live worker" >"$dir/.worktrees/$id/WORKER_FILE"
      [ "$kind" = locked ] && git -C "$dir" worktree lock --reason "live worker holds it" "$dir/.worktrees/$id"
      ;;
    dirty)
      echo "$id=in_progress" >>"$dir/stub/statuses"
      git -C "$dir" worktree add -q -b "bead/$id" "$dir/.worktrees/$id" main
      echo "committed work" >"$dir/.worktrees/$id/done.txt"
      git -C "$dir/.worktrees/$id" add -A
      commit_in "$dir/.worktrees/$id" "bead $id: real work"
      echo "uncommitted work" >"$dir/.worktrees/$id/leftover.txt"
      ;;
    merged|mergeddirty|mergedlocked)
      echo "$id=closed" >>"$dir/stub/statuses"
      git -C "$dir" worktree add -q -b "bead/$id" "$dir/.worktrees/$id" main
      # Per-id filename: two merged:/mergeddirty: scenarios in one repo would otherwise both write
      # the SAME merged.txt with the same content, so the second worktree has nothing to commit,
      # its commit fails and the branch silently stays at main - a scenario that never got built.
      echo "merged work by $id" >"$dir/.worktrees/$id/merged-$id.txt"
      git -C "$dir/.worktrees/$id" add -A
      commit_in "$dir/.worktrees/$id" "bead $id: work that gets merged"
      # Fail loudly rather than build a scenario that isn't the one asked for.
      [ "$(git -C "$dir" rev-list --count "main..bead/$id")" -ge 1 ] \
        || { echo "gc-scratch-repo: bead/$id did not advance past main for $spec" >&2; exit 2; }
      # Exactly accept.sh's merge: a --no-ff merge commit made on a detached checkout of main.
      m="$(mktemp -d "${TMPDIR:-/tmp}/scratch-merge.XXXXXX")"
      git -C "$dir" worktree add -q --detach "$m" main
      git -C "$m" -c user.email=scratch@local -c user.name=scratch -c commit.gpgsign=false \
        merge --no-ff --no-edit -m "bead $id: merge into main" "bead/$id" >/dev/null
      git -C "$dir" update-ref refs/heads/main "$(git -C "$m" rev-parse HEAD)"
      git -C "$dir" worktree remove --force "$m"
      # The leftover goes in AFTER the merge, so it is on no branch and on no commit anywhere.
      # `|| true`: under set -e a false test as the LAST command of the branch would abort the harness.
      { [ "$kind" = mergeddirty ] && echo "precious uncommitted work" >"$dir/.worktrees/$id/leftover-$id.txt"; } || true
      # mergedlocked: clean and merged, so gc DOES try to remove it, but `git worktree remove` fails
      # on a locked worktree - the portable stand-in for "Device or resource busy".
      { [ "$kind" = mergedlocked ] && git -C "$dir" worktree lock --reason "live process holds it" "$dir/.worktrees/$id"; } || true
      ;;
    *) echo "gc-scratch-repo: unknown scenario $spec" >&2; exit 2;;
  esac
done
echo "$dir"
