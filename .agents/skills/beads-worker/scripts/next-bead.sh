#!/usr/bin/env bash
# Claim up to <count> (default 1) ready `fleet` + `phase:<N>` beads, previously-failed ones first,
# and print one JSON record per line. Exit 3 when nothing is ready.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
phase="${1:?usage: next-bead.sh <phase> [count]}"
count="${2:-1}"
me="${BEADS_ACTOR:-$(git config user.name || echo hermes)}"
# Retries first: beads already claimed by us (their claim is kept across failed accepts), then the
# highest-priority ready beads, up to <count> in total.
ids="$( { real_bd list --label fleet --label "phase:$phase" --status in_progress --json -n 0 2>/dev/null \
  | jq -r --arg me "$me" 'if type=="array" then map(select(.assignee==$me)) | sort_by(.priority) | .[].id else empty end';
  real_bd list --ready --label fleet --label "phase:$phase" --status open --json -n 0 2>/dev/null \
  | jq -r 'if type=="array" then sort_by(.priority) | .[].id else empty end'; } | awk '!seen[$0]++' | head -n "$count")"
[ -n "$ids" ] || { echo "no ready fleet bead for phase $phase" >&2; exit 3; }
for id in $ids; do
real_bd update "$id" --claim --actor "$me" -q >&2
acc="$(bead_acceptance "$id")"
bead_json "$id" | jq -c --arg id "$id" --arg acc "$acc" '{
  id: $id,
  title: .title,
  body: (.description // ""),
  acceptance: $acc,
  notes: (.notes // ""),
  exemplar: ((.metadata.exemplar // "") ),
  attempts: ((.metadata.attempts // "0") | tonumber),
  stale_count: ((.metadata.stale_count // "0") | tonumber),
  labels: (.labels // [])
}'
done
