#!/usr/bin/env bash
# Shared helpers for the beads-worker scripts. Source, do not execute.
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREES="$REPO_ROOT/.worktrees"
die() { echo "beads-worker: $*" >&2; exit "${2:-1}"; }
need() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "missing command: $c" 2; done; }
need bd git jq
# Real bd, bypassing the guard shim (the shim lives in scripts/bin).
real_bd() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local p; p="$(echo "$PATH" | tr ':' '\n' | grep -vx "$here/bin" | paste -sd: -)"
  PATH="$p" command bd "$@"
}
bead_json() { real_bd show "$1" --json 2>/dev/null | jq -c 'if type=="array" then .[0] else . end'; }
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
