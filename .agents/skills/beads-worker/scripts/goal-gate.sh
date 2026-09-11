#!/usr/bin/env bash
# /goal quality gate. Exit 0 when the phase is drained OR when progress was made since the last
# gate run (a bead closed or escalated). Exit 1 only on a turn with no progress, so Hermes's
# bounded gate retries (default 3) become stuck-detection instead of a cap on the whole run.
# Progress is signalled by marker files scripts/accept.sh and scripts/escalate.sh create at the
# repo root (.fleet-progress.<bead>); they also change `git status`, so Hermes re-runs the gate
# instead of replaying the previous failure. This script consumes the markers.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
phase="${1:?usage: goal-gate.sh <phase>}"
markers=( "$REPO_ROOT"/.fleet-progress.* )
progress=0
for m in "${markers[@]}"; do [ -e "$m" ] && { progress=1; rm -f "$m"; }; done
if "$(dirname "${BASH_SOURCE[0]}")/goal-check.sh" "$phase"; then
  exit 0
fi
if [ "$progress" -eq 1 ]; then
  echo "progress since last gate: continue"
  exit 0
fi
echo "no bead closed or escalated since the last gate run. Do a bead: scripts/next-bead.sh $phase"
exit 1
