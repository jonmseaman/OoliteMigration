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

# The tracked bead DB export (.beads/*.jsonl) is fleet bookkeeping regenerated from Dolt, never
# the record of truth: every note, status and field reaches the JSONL through `bd`, which writes
# Dolt first. A merge conflict in that file therefore carries nothing a `bd export` on the base
# branch does not already have (bead oo-c4ly: 36 of 200 commits on main were hand-resolutions of
# exactly this conflict). resolve_beads_db_conflict <checkout> finishes a half-done merge whose
# ONLY conflicts are .beads/*.jsonl by taking the base side ("ours" in a checkout of the base) and
# staging it. Returns 1 and leaves the merge untouched if any other path conflicts: a real
# conflict in bead work is still the worker's to resolve.
resolve_beads_db_conflict() {
  local co="$1" conflicts other p
  conflicts="$(git -C "$co" diff --name-only --diff-filter=U 2>/dev/null)"
  [ -n "$conflicts" ] || return 1
  other="$(printf '%s\n' "$conflicts" | grep -vE '^\.beads/[^/]+\.jsonl$' || true)"
  [ -z "$other" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    git -C "$co" checkout --ours -- "$p" 2>/dev/null || return 1
    git -C "$co" add -- "$p" || return 1
  done <<EOF
$conflicts
EOF
  [ -z "$(git -C "$co" diff --name-only --diff-filter=U 2>/dev/null)" ]
}

# refresh_beads_export <base>: regenerate .beads/issues.jsonl from Dolt in the root checkout and
# commit it on the base branch if it changed. With export.auto off in .beads/config.yaml this is
# the export's only writer, so the tracked copy is always main's and always fresh (an export of
# ~750 issues takes under a second). Never fatal: a stale export is a nuisance, not a lost bead.
refresh_beads_export() {
  local base="$1" out="$REPO_ROOT/.beads/issues.jsonl"
  [ "$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null)" = "$base" ] || return 0
  real_bd export -o "$out" >/dev/null 2>&1 || { echo "beads-worker: bd export failed; the tracked export is stale until the next accept" >&2; return 0; }
  git -C "$REPO_ROOT" diff --quiet -- .beads/issues.jsonl 2>/dev/null && return 0
  git -C "$REPO_ROOT" -c user.name=beads-worker -c user.email=beads-worker@local \
    commit -q -m "fleet: bead DB export refreshed from Dolt after accept" -- .beads/issues.jsonl >/dev/null 2>&1 \
    || echo "beads-worker: could not commit the refreshed export on $base; it is left modified in $REPO_ROOT" >&2
}
