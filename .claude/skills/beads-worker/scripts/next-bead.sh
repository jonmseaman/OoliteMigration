#!/usr/bin/env bash
# Claim ONE ready bead matching the caller's selector and print it as a JSON record.
# The selector is whatever `bd list` understands and is passed through verbatim:
#   next-bead.sh --parent oo-abc
#   next-bead.sh --label cleanup --priority 1
# Human-only and interactive beads (rebless, proposed-adr, design) are always excluded — see
# _lib.sh. Epics are never handed out. Exit 3 when nothing is ready.
#
# "Ready" is decided here, not by `bd ready`: all work of an epic lands on one branch and nothing
# closes before Jon merges it, so a bead is ready when every blocker is either closed or already
# `committed` on the epic branch. (`bd list --json` carries no dependency data, so each candidate
# costs one `bd show`; the first ready one wins.)
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ "$#" -gt 0 ] || die "usage: next-bead.sh <bd list selector…>   e.g. next-bead.sh --parent oo-abc"
me="$(worker_actor)"
# Retries first: a bead we already hold kept its claim across a failed accept, and its notes carry
# the failure the next attempt must read. Then bugs before tasks — a bug is a defect in work that
# already landed, so fixing it first stops later beads building on it. Then priority, then age.
order='sort_by([(if .issue_type == "bug" then 0 else 1 end), .priority, .created_at])'
# A committed bead is done on the epic branch, waiting for Jon's merge; an epic is never work.
actionable='map(select(((.labels // []) | index("committed")) | not) | select(.issue_type != "epic"))'

# blockers_satisfied <bead>: every blocking dependency is closed or committed.
blockers_satisfied() {
  local dep
  for dep in $(bead_json "$1" | jq -r '.dependencies[]? | select(.dependency_type == "blocks" or .dependency_type == "conditional-blocks" or .dependency_type == "waits-for") | select(.status != "closed") | .id' | nocr); do
    bead_has_label "$dep" committed || return 1
  done
  return 0
}

id=""
for cand in $( { worker_list "$@" --status in_progress \
    | jq -r --arg me "$me" "$actionable | map(select(.assignee==\$me)) | $order | .[].id";
  worker_list "$@" --status open \
    | jq -r "$actionable | $order | .[].id"; } | nocr | awk '!seen[$0]++'); do
  if blockers_satisfied "$cand"; then id="$cand"; break; fi
done
[ -n "$id" ] || { echo "no ready bead for selector: $*" >&2; exit 3; }
real_bd update "$id" --claim --actor "$me" -q >&2
acc="$(bead_acceptance "$id")"
bead_json "$id" | jq -c --arg id "$id" --arg acc "$acc" '{
  id: $id,
  title: .title,
  body: (.description // ""),
  acceptance: $acc,
  notes: (.notes // ""),
  attempts: ((.metadata.attempts // "0") | tonumber),
  stale_count: ((.metadata.stale_count // "0") | tonumber),
  labels: (.labels // [])
}'
