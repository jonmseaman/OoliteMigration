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
cp "$here/../_lib.sh" "$here/../harvest.sh" "$dir/scripts/"
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
    merged)
      echo "$id=closed" >>"$dir/stub/statuses"
      git -C "$dir" worktree add -q -b "bead/$id" "$dir/.worktrees/$id" main
      echo "merged work" >"$dir/.worktrees/$id/merged.txt"
      git -C "$dir/.worktrees/$id" add -A
      commit_in "$dir/.worktrees/$id" "bead $id: work that gets merged"
      # Exactly accept.sh's merge: a --no-ff merge commit made on a detached checkout of main.
      m="$(mktemp -d "${TMPDIR:-/tmp}/scratch-merge.XXXXXX")"
      git -C "$dir" worktree add -q --detach "$m" main
      git -C "$m" -c user.email=scratch@local -c user.name=scratch -c commit.gpgsign=false \
        merge --no-ff --no-edit -m "bead $id: merge into main" "bead/$id" >/dev/null
      git -C "$dir" update-ref refs/heads/main "$(git -C "$m" rev-parse HEAD)"
      git -C "$dir" worktree remove --force "$m"
      ;;
    *) echo "gc-scratch-repo: unknown scenario $spec" >&2; exit 2;;
  esac
done
echo "$dir"
