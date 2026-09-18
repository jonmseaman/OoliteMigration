#!/usr/bin/env bash
# Exit 0 iff no open or in-progress bead carries `phase:<N>` and a BEADS_WORKER_LABELS label
# (default `fleet`; see _lib.sh). Beads for humans (rebless, proposed-adr) and reviews are never
# counted; seams (frontier) only when BEADS_WORKER_LABELS includes frontier.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
phase="${1:?usage: goal-check.sh <phase>}"
remaining="$(worker_list "$phase" --status open,in_progress \
  | jq -r '.[] | "\(.id)\t\(.status)\t\(.title)"')"
if [ -z "$remaining" ]; then
  # Drained is not done if any bead's work is still off the base branch (gc.sh --check audits).
  if "$(dirname "${BASH_SOURCE[0]}")/gc.sh" --check >/dev/null 2>&1; then
    echo "phase $phase: no open $BEADS_WORKER_LABELS beads; all bead work is on the base branch"
    exit 0
  fi
  echo "phase $phase: no open $BEADS_WORKER_LABELS beads, but work is at risk. Run scripts/gc.sh:"
  # Filter the ROUTINE lines only. `gc: <branch> is merged into <base> (bead <st>)` fires for every
  # cleanly-merged bead on every run, which is why this filter exists. But the old pattern
  # `^gc: .* merged` also matched gc's WARNING lines - above all
  #   gc: bead/<id> is merged but its worktree still holds uncommitted work
  # (oo-y8fa) - so the operator was told "work is at risk" with NO BEAD NAMED: the single line
  # identifying which worktree holds unharvested work was the line being dropped. Anchor the noise
  # pattern on the literal "is merged into " of the routine line so "is merged but ..." survives.
  "$(dirname "${BASH_SOURCE[0]}")/gc.sh" --check 2>&1 | grep -v "^gc: .* is merged into \|^gc: all" || true
  exit 1
fi
echo "phase $phase: $BEADS_WORKER_LABELS beads still open:"
echo "$remaining"
exit 1
