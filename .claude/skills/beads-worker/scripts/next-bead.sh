#!/usr/bin/env bash
# Claim ONE ready bead matching the caller's selector and print it as a JSON record.
# The selector is whatever `bd list` understands and is passed through verbatim:
#   next-bead.sh --label phase:5
#   next-bead.sh --label cleanup --priority 1
# Human-only beads (rebless, proposed-adr) are always excluded — see _lib.sh.
# Exit 3 when nothing is ready.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
[ "$#" -gt 0 ] || die "usage: next-bead.sh <bd list selector…>   e.g. next-bead.sh --label phase:5"
me="$(worker_actor)"
# Retries first: a bead we already hold kept its claim across a failed accept, and its notes carry
# the failure the next attempt must read. Then bugs before tasks — a bug is a defect in work that
# already landed, so fixing it first stops later beads building on it. Then priority, then age.
order='sort_by([(if .issue_type == "bug" then 0 else 1 end), .priority, .created_at])'
# A bead whose pull request is open is not workable: it is waiting on Jon's review, not on us.
# land.sh picks it up again once the pull request is merged or closed.
actionable='map(select(((.labels // []) | index("proposed")) | not))'
ids="$( { worker_list "$@" --status in_progress \
  | jq -r --arg me "$me" "$actionable | map(select(.assignee==\$me)) | $order | .[].id";
  worker_list "$@" --ready --status open \
  | jq -r "$actionable | $order | .[].id"; } | nocr | awk '!seen[$0]++' | head -n 1)"
[ -n "$ids" ] || { echo "no ready bead for selector: $*" >&2; exit 3; }
id="$ids"
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
