#!/usr/bin/env bash
# Close every bead of an epic whose branch Jon has merged into develop. Run at the START of each
# tick, so the queue reflects his merges rather than lagging a tick behind.
#
# This is the only script that closes a bead (CLAUDE.md hard rule 3). The evidence is local: the
# epic branch is merged into develop in oolite-dev, by merge commit, fast-forward or rebase (see
# epic_merged in _lib.sh). The worker cannot fake it: it never touches develop. A squash merge
# leaves no trace to detect; Jon closes those beads himself with `bd close`.
#
# Prints one line per bead it touched. Exit 0 always (nothing to land is not a failure).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
epics="$(worker_list --label ready-to-merge --status open,in_progress | jq -r '.[].id' | nocr)"
[ -n "$epics" ] || { echo "nothing ready to merge"; exit 0; }
[ -e "$DEV/.git" ] || { echo "oolite-dev is not checked out; left alone"; exit 0; }
main="$(dev_main)"

for epic in $epics; do
  branch="$(bead_json "$epic" | jq -r '.metadata.branch // empty')"
  if [ -z "$branch" ]; then echo "$epic: labelled ready-to-merge but no branch recorded; left alone"; continue; fi
  if ! epic_merged "$branch"; then
    echo "$epic: $branch ready; not merged into $main yet"
    continue
  fi
  sha="$(real_git -C "$DEV" rev-parse --short=12 "$main")"
  # Unfiltered on purpose: an interactive `design` bead that was committed closes with its epic.
  # bd refuses to close a bead whose blocker is still open, so close in passes: blockers first.
  pending=""
  for id in $(real_bd list --label committed --status open,in_progress --json -n 0 2>/dev/null | jq -r '.[].id' | nocr); do
    [ "$(epic_of "$id")" = "$epic" ] && pending="$pending $id"
  done
  pass=0
  while [ -n "${pending// /}" ] && [ "$pass" -lt 20 ]; do
    pass=$((pass + 1)); left=""
    for id in $pending; do
      if real_bd close "$id" --actor "$(bead_actor "$id")" --reason "accepted: $branch merged into $main (at $sha)" -q >/dev/null 2>&1; then
        echo "$id: closed - $branch merged"
      else
        left="$left $id"
      fi
    done
    [ "$left" != "$pending" ] || break
    pending="$left"
  done
  for id in $pending; do echo "$id: could not close; close it by hand"; done
  real_bd update "$epic" --set-metadata "merge_commit=$sha" -q >&2 || true
  if real_bd close "$epic" --actor "$(bead_actor "$epic")" --reason "accepted: $branch merged into $main (at $sha)" -q >&2; then
    echo "$epic: closed - $branch merged"
  else
    echo "$epic: could not close (open children?); close the rest, then it closes next tick"
  fi
done
