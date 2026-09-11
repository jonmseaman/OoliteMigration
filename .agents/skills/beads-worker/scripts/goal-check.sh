#!/usr/bin/env bash
# Exit 0 iff no open or in-progress bead carries both `fleet` and `phase:<N>`.
# Beads for humans (rebless, proposed-adr) and seams (frontier) are not counted by construction.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
phase="${1:?usage: goal-check.sh <phase>}"
remaining="$(real_bd list --label fleet --label "phase:$phase" --status open,in_progress --json -n 0 2>/dev/null \
  | jq -r 'if type=="array" then .[] else empty end | "\(.id)\t\(.status)\t\(.title)"')"
if [ -z "$remaining" ]; then
  echo "phase $phase: no open fleet beads"
  exit 0
fi
echo "phase $phase: fleet beads still open:"
echo "$remaining"
exit 1
