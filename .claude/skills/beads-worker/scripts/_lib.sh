#!/usr/bin/env bash
# Shared helpers for the beads-worker scripts. Source, do not execute.
set -euo pipefail
# `git rev-parse --show-toplevel` prints a Windows-style path under MSYS (C:/Users/...); round-trip
# it through `cd`/`pwd` so REPO_ROOT is a POSIX path that composes with the rest of the script.
REPO_ROOT="$(cd "$(git rev-parse --show-toplevel)" && pwd)"
DEV="$REPO_ROOT/oolite-dev"
die() { echo "beads-worker: $*" >&2; exit "${2:-1}"; }
need() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "missing command: $c" 2; done; }
need bd git jq
# Thin wrappers kept so every caller reads the same; there is no shim to bypass.
real_bd() { command bd "$@"; }
real_git() { command git "$@"; }
# The UCRT64 jq writes CRLF. Every value that reaches a shell variable goes through nocr, or ids
# carry a trailing \r, `bd show` is handed a bead that cannot exist, and `set -e` kills the script
# with no output at all. Stripping
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
bead_has_label() { [ "$(bead_json "$1" | jq -r --arg l "$2" '(.labels // []) | index($l) | if . == null then "no" else "yes" end' | nocr)" = yes ]; }
# bead_actor <bead>: who holds the bead (bd refuses to close a bead as anyone else), else this worker.
bead_actor() { local a; a="$(bead_field "$1" '.assignee')"; echo "${a:-$(worker_actor)}"; }
# Beads for a human or an interactive session are never the worker's. Everything else is selected
# by the caller's selector, which is passed through to `bd list` verbatim.
BEADS_WORKER_EXCLUDE="${BEADS_WORKER_EXCLUDE:-rebless proposed-adr design human}"
# worker_list <bd list flags...>: one JSON array of matching beads, minus the excluded labels.
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
# The branch epic branches start from and are merged into by Jon.
dev_main() { echo "${OOLITE_DEV_MAIN:-develop}"; }
# slugify <text>: lower-case, hyphen-separated, at most 40 characters.
slugify() {
  printf %s "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//'
}
# epic_of <bead>: the id of the epic a bead belongs to. Walks `parent` upward and returns the first
# ancestor whose type is epic; failing that the topmost parent; empty when the bead has no parent.
epic_of() {
  local id="$1" p="" top="" i=0
  while [ "$i" -lt 8 ]; do
    p="$(bead_field "$id" '.parent')"
    [ -n "$p" ] || break
    top="$p"
    [ "$(bead_field "$p" '.issue_type')" = "epic" ] && { echo "$p"; return 0; }
    id="$p"; i=$((i + 1))
  done
  echo "$top"
}
# epic_branch <epic>: the branch every bead of the epic commits on. Recorded on the epic by
# branch.sh the first time; before that, epic/<slug of its title> (or of its id).
epic_branch() {
  local epic="$1" b slug
  b="$(bead_json "$epic" | jq -r '.metadata.branch // empty')"
  if [ -z "$b" ]; then
    slug="$(slugify "$(bead_field "$epic" '.title')")"
    [ -n "$slug" ] || slug="$(slugify "$epic")"
    b="epic/$slug"
  fi
  echo "$b"
}
# epic_merged <branch>: success when Jon has merged the branch into the main branch in oolite-dev,
# by merge commit or fast-forward (ancestor) or by rebase (every commit has a patch-equivalent on
# main). A squash merge is not detectable; Jon closes those beads himself.
epic_merged() {
  local b="$1" m cherry
  m="$(dev_main)"
  real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$b" || return 1
  real_git -C "$DEV" merge-base --is-ancestor "$b" "$m" && return 0
  cherry="$(real_git -C "$DEV" cherry "$m" "$b" 2>/dev/null || true)"
  [ -n "$cherry" ] || return 1
  ! printf '%s\n' "$cherry" | grep -q '^+'
}
