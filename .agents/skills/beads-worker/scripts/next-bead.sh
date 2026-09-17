#!/usr/bin/env bash
# Claim up to <count> (default 1) ready `phase:<N>` beads carrying a BEADS_WORKER_LABELS label
# (default `fleet`; see _lib.sh), previously-failed ones first,
# and print one JSON record per line. Exit 3 when nothing is ready.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
phase="${1:?usage: next-bead.sh <phase> [count]}"
count="${2:-1}"
me="${BEADS_ACTOR:-$(git config user.name || echo hermes)}"
# Retries first: beads already claimed by us (their claim is kept across failed accepts), then the
# highest-priority ready beads, up to <count> in total.
ids="$( { worker_list "$phase" --status in_progress \
  | jq -r --arg me "$me" 'map(select(.assignee==$me)) | sort_by(.priority) | .[].id';
  worker_list "$phase" --ready --status open \
  | jq -r 'sort_by(.priority) | .[].id'; } | awk '!seen[$0]++' | head -n "$count")"
[ -n "$ids" ] || { echo "no ready bead ($BEADS_WORKER_LABELS) for phase $phase" >&2; exit 3; }
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
