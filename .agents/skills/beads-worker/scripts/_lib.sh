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
# Which beads the loop works: every bead carrying phase:<N> and at least one label in
# BEADS_WORKER_LABELS (default: fleet), minus any carrying a label in BEADS_WORKER_EXCLUDE. Set
# BEADS_WORKER_LABELS="fleet frontier" to let a frontier-model session take the seams as well.
# review, rebless and proposed-adr beads are never the loop's; escalated ones already failed here.
# Label set this host works. Precedence: the environment, then `git config beads-worker.labels`
# (repo-local, shared by every worktree, survives any launcher), then `fleet`. The git config
# exists because a desktop-launched Hermes runs its terminal as a non-login `bash -c` that
# inherits nothing from a login shell or profile.d, so an exported variable never reached the
# workers' scripts (2026-09-17: next-bead.sh silently fell back to `fleet` alone).
BEADS_WORKER_LABELS="${BEADS_WORKER_LABELS:-$(git config --get beads-worker.labels 2>/dev/null || true)}"
BEADS_WORKER_LABELS="${BEADS_WORKER_LABELS:-fleet}"
BEADS_WORKER_EXCLUDE="${BEADS_WORKER_EXCLUDE:-review rebless proposed-adr escalated}"
# worker_list <phase> [bd list flags...]: one JSON array of matching beads, deduplicated by id.
worker_list() {
  local phase="$1"; shift
  for l in $BEADS_WORKER_LABELS; do
    real_bd list --label "$l" --label "phase:$phase" "$@" --json -n 0 2>/dev/null       | jq -c 'if type=="array" then .[] else empty end'
  done | jq -s --arg ex "$BEADS_WORKER_EXCLUDE" '
    ($ex | split(" ") | map(select(. != ""))) as $ex
    | map(select(((.labels // []) | map(. as $l | $ex | index($l)) | any) | not))
    | unique_by(.id)'
}
bead_attempts() { bead_json "$1" | jq -r '(.metadata.attempts // "0") | tonumber'; }
