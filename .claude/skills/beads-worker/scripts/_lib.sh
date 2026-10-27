#!/usr/bin/env bash
# Shared helpers for the beads-worker scripts. Source, do not execute.
set -euo pipefail
# `git rev-parse --show-toplevel` prints a Windows-style path under MSYS (C:/Users/...), which
# never matches the POSIX-style entries in PATH. Round-trip it through `cd`/`pwd` so the guard
# directory can actually be stripped below; without this, real_bd would re-enter the shim.
REPO_ROOT="$(cd "$(git rev-parse --show-toplevel)" && pwd)"
DEV="$REPO_ROOT/oolite-dev"
die() { echo "beads-worker: $*" >&2; exit "${2:-1}"; }
need() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "missing command: $c" 2; done; }
need bd git jq
# Real bd and git, bypassing the guard shims in tools/guard.
_unguarded_path() { echo "$PATH" | tr ':' '\n' | grep -vx "$REPO_ROOT/tools/guard" | paste -sd: -; }
real_bd() { PATH="$(_unguarded_path)" command bd "$@"; }
real_git() { PATH="$(_unguarded_path)" command git "$@"; }
# The UCRT64 jq writes CRLF. Every value that reaches a shell variable goes through nocr, or ids
# carry a trailing \r, `bd show` is handed a bead that cannot exist, and `set -e` kills the script
# with no output at all. (Same trap as tools/check-beads-db-merge.sh's `tr -d '\r'`.) Stripping
# literal CR is safe for JSON: a real carriage return inside a string is encoded as \r, two
# characters, not a literal one.
nocr() { tr -d '\r'; }
bead_json() { real_bd show "$1" --json 2>/dev/null | jq -c 'if type=="array" then .[0] else . end' | nocr; }
bead_field() { bead_json "$1" | jq -r "$2 // empty"; }
# Acceptance commands: the bead's acceptance field, else the fenced block under '## Acceptance' in
# its description (the generator writes it there; graph plans cannot set the field).
bead_acceptance() {
  local acc; acc="$(bead_field "$1" '.acceptance_criteria // .acceptance')"
  if [ -z "$acc" ]; then
    acc="$(bead_field "$1" '.description' | awk '/^## Acceptance/{f=1;next} f&&/^```/{if(c){exit}else{c=1;next}} f&&c{print}')"
  fi
  printf '%s\n' "$acc"
}
bead_attempts() { bead_json "$1" | jq -r '(.metadata.attempts // "0") | tonumber'; }
# Beads for a human are never the worker's. Everything else is selected by the caller's selector,
# which is passed through to `bd list` verbatim: the old fleet/frontier tier split is gone.
BEADS_WORKER_EXCLUDE="${BEADS_WORKER_EXCLUDE:-rebless proposed-adr}"
# worker_list <bd list flags...>: one JSON array of matching beads, minus the human-only labels.
worker_list() {
  real_bd list "$@" --json -n 0 2>/dev/null \
    | jq -c --arg ex "$BEADS_WORKER_EXCLUDE" '
        (if type=="array" then . else [] end) as $all
        | ($ex | split(" ") | map(select(. != ""))) as $ex
        | $all
        | map(select(((.labels // []) | map(. as $l | $ex | index($l)) | any) | not))
        | unique_by(.id)' | nocr
}
# Each worker runs in its own outer-repo worktree; the worktree's directory name is the actor, so
# two workers sharing one beads database never claim the same bead.
worker_actor() { echo "${BEADS_ACTOR:-$(basename "$REPO_ROOT")}"; }
# The branch oolite-dev currently has checked out.
dev_branch() {
  local b; b="$(real_git -C "$DEV" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$b" ] && [ "$b" != "HEAD" ] || die "oolite-dev is not on a branch (detached HEAD); check one out before working beads"
  echo "$b"
}
dev_clean() { [ -z "$(real_git -C "$DEV" status --porcelain 2>/dev/null)" ]; }
# Git Town's main branch inside oolite-dev: the branch bead branches are appended to and propose
# against. Configured by preflight.sh; `develop` unless someone changed it.
dev_main() { real_git -C "$DEV" config --get git-town.main-branch || echo develop; }
# The bead DB export (.beads/*.jsonl) is bookkeeping regenerated from Dolt, never the record of
# truth: every note, status and field reaches the JSONL through `bd`, which writes Dolt first. A
# merge conflict in that file therefore carries nothing a fresh `bd export` does not already have.
# resolve_beads_db_conflict <checkout> finishes a half-done merge whose ONLY conflicts are
# .beads/*.jsonl by taking the base side and staging it. Returns 1 and leaves the merge untouched
# if any other path conflicts: a real conflict in bead work is still a human's to resolve.
# The worker no longer merges anything, so nothing here calls this; it survives because
# tools/check-beads-db-merge.sh is the control that proves the rule, and because a branch cut
# before 2026-10-07 can still carry a tracked export.
resolve_beads_db_conflict() {
  local co="$1" conflicts other p
  conflicts="$(real_git -C "$co" diff --name-only --diff-filter=U 2>/dev/null)"
  [ -n "$conflicts" ] || return 1
  other="$(printf '%s\n' "$conflicts" | grep -vE '^\.beads/[^/]+\.jsonl$' || true)"
  [ -z "$other" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    real_git -C "$co" checkout --ours -- "$p" 2>/dev/null || return 1
    real_git -C "$co" add -- "$p" || return 1
  done <<EOF
$conflicts
EOF
  [ -z "$(real_git -C "$co" diff --name-only --diff-filter=U 2>/dev/null)" ]
}
# feature/MMDD-slug, the branch name for a bead. The slug comes from the bead's title so a branch
# and its pull request are readable without looking the id up.
bead_branch_name() {
  local id="$1" title slug
  title="$(bead_field "$id" '.title')"
  slug="$(printf %s "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')"
  [ -n "$slug" ] || slug="$(printf %s "$id" | tr '[:upper:]' '[:lower:]')"
  echo "feature/$(date +%m%d)-$slug"
}
