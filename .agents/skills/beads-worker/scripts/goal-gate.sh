#!/usr/bin/env bash
# /goal quality gate. Exit 0 when the phase is drained OR when progress was made since the last
# gate run (a bead closed or escalated). Exit 1 only on a turn with no progress, so Hermes's
# bounded gate retries (default 3) become stuck-detection instead of a cap on the whole run.
# Progress is signalled by marker files scripts/accept.sh and scripts/escalate.sh create at the
# repo root (.fleet-progress.<bead>); they also change `git status`, so Hermes re-runs the gate
# instead of replaying the previous failure. This script consumes the markers.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# Fail fast before any path is computed (oo-aqzj): unsourced _lib.sh leaves these empty and the
# marker glob "$REPO_ROOT"/.fleet-progress.* becomes /.fleet-progress.* - matched AND rm -f'd at
# the filesystem root. Keep above the first use.
: "${REPO_ROOT:?_lib.sh not sourced (REPO_ROOT unset): refusing to compute paths from an empty prefix}" \
  "${WORKTREES:?_lib.sh not sourced (WORKTREES unset): refusing to compute paths from an empty prefix}"
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
# In-flight work is progress too. An orchestrator turn that only delegates workers closes nothing,
# and Hermes runs this gate at every turn boundary, so three such turns in a row exhausted the
# retries and paused the goal while five workers were mid-bead (2026-09-17). Hermes's resume does
# not reset the gate's attempt counter, so once exhausted every resume bought exactly one turn.
# A worker is alive if any file in a worktree changed in the last BEADS_GATE_ACTIVE_MINUTES
# (default 30; a build touches files constantly), or an accept holds the lock with a live pid.
active_min="${BEADS_GATE_ACTIVE_MINUTES:-30}"
if [ -d "$WORKTREES" ] && [ -n "$(find "$WORKTREES" -mindepth 2 -type f -mmin "-$active_min" -print -quit 2>/dev/null)" ]; then
  echo "workers active: a worktree under $WORKTREES changed in the last $active_min min; continue"
  exit 0
fi
lock="$REPO_ROOT/.beads-worker-accept.lock"
if [ -d "$lock" ] && kill -0 "$(cat "$lock/pid" 2>/dev/null)" 2>/dev/null; then
  echo "accept in progress (pid $(cat "$lock/pid")); continue"
  exit 0
fi
echo "no bead closed or escalated since the last gate run. Do a bead: scripts/next-bead.sh $phase"
exit 1
