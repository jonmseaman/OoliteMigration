#!/usr/bin/env bash
# Close every proposed bead whose pull request you have merged. Run at the START of each tick, so
# the queue drains as you review rather than only when the loop next looks.
#
# This is the only script that closes a bead (CLAUDE.md hard rule 4): the evidence is a merged pull
# request on the game fork, which the worker cannot fake — it has no write access to develop.
# A pull request you CLOSED without merging sends the bead back to the queue with its branch
# intact, so the next tick can read the review and try again.
#
# Prints one line per bead it touched. Exit 0 always (nothing to land is not a failure).
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
proposed="$(worker_list --status open,in_progress \
  | jq -r '.[] | select((.labels // []) | index("proposed")) | .id' | nocr)"
[ -n "$proposed" ] || { echo "nothing proposed"; exit 0; }

for id in $proposed; do
  pr="$(bead_json "$id" | jq -r '.metadata.pr // empty')"
  branch="$(bead_json "$id" | jq -r '.metadata.branch // empty')"
  if [ -z "$pr" ]; then echo "$id: labelled proposed but no pull request recorded; left alone"; continue; fi
  state="$(cd "$DEV" && gh pr view "$pr" --json state,mergedAt,mergeCommit -q '[.state, (.mergedAt // ""), (.mergeCommit.oid // "")] | @tsv' 2>/dev/null | nocr || true)"
  [ -n "$state" ] || { echo "$id: could not read $pr (offline?); left alone"; continue; }
  IFS=$'\t' read -r st merged_at merge_oid <<<"$state"
  case "$st" in
    MERGED)
      BEADS_ACCEPT=1 real_bd close "$id" --reason "accepted: $pr merged into $(dev_main) at ${merged_at}${merge_oid:+ as ${merge_oid:0:12}}" -q >&2
      real_bd update "$id" --set-metadata "merge_commit=$merge_oid" -q >&2 || true
      echo "$id: closed — $pr merged"
      ;;
    CLOSED)
      real_bd label remove "$id" proposed >/dev/null 2>&1 || true
      real_bd update "$id" --append-notes "pull request $pr was closed without merging on $(date -u +%FT%TZ). Read the review, fix the work on branch ${branch:-?}, and accept again." -q >&2
      echo "$id: reopened for rework — $pr closed unmerged"
      ;;
    *)
      echo "$id: $pr still $st"
      ;;
  esac
done
