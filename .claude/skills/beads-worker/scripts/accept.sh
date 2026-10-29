#!/usr/bin/env bash
# The bead's gate. Called by the loop, never by the agent that wrote the code (CLAUDE.md hard rule
# 3: this script does not close anything, and neither does the agent).
#
# The work is already committed on the epic's branch in oolite-dev (branch.sh put it there). This
# script runs the bead's acceptance commands and, only if every one exits 0, squashes the bead's
# commits since `base_commit` into ONE commit `<id>: <title>` and labels the bead `committed`.
# Nothing is pushed and no pull request is opened: the bead stays OPEN until Jon merges the epic's
# branch into develop and land.sh notices.
#
# Acceptance runs with cwd = the OUTER repo root, not oolite-dev: acceptance lines spell the
# submodule explicitly (`cd oolite-dev && tests/run.sh unit`).
#
# Exit 0 = acceptance passed, bead committed · 1 = rejected, new information · 2 = rejected, stale.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: accept.sh <bead>}"

# The gate only means something on a tree that holds exactly the committed work being judged.
dev_clean || die "oolite-dev has uncommitted changes; commit them before accepting $id:
$(real_git -C "$DEV" status --short | head -20)"
branch="$(dev_branch)"
epic="$(epic_of "$id")"
[ -n "$epic" ] || die "bead $id has no parent epic; attach it with: bd update $id --parent <epic>"
want="$(epic_branch "$epic")"
[ "$branch" = "$want" ] || die "oolite-dev is on $branch but $id belongs to $want (run branch.sh $id)"
base="$(bead_json "$id" | jq -r '.metadata.base_commit // empty')"
[ -n "$base" ] || die "bead $id has no base_commit; run branch.sh $id before implementing it"
real_git -C "$DEV" merge-base --is-ancestor "$base" HEAD \
  || die "base_commit $base of $id is not an ancestor of $branch; the branch was rewritten under the bead"
if [ "$(real_git -C "$DEV" rev-list --count "$base..HEAD")" -eq 0 ]; then
  attempts="$(( $(bead_attempts "$id") + 1 ))"
  real_bd update "$id" --set-metadata "attempts=$attempts" --append-notes \
    "accept attempt $attempts on $(date -u +%FT%TZ): $branch has no commits since the bead started ($base). The worker committed nothing." -q >&2
  echo "rejected $id (attempt $attempts): nothing committed on $branch"; exit 1
fi

acceptance="$(bead_acceptance "$id")"
[ -n "$acceptance" ] || die "bead $id has no acceptance commands; refusing to commit without a gate"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
ran=0
# The whole block shares ONE budget: 300 s by default (BEADS_ACCEPT_BUDGET), or the bead's own
# metadata.accept_budget when its proof is a full build and test run. Either is capped at 1800 s.
# Each line gets what is left of it; a line that runs out exits 124 and the note names the budget.
budget="${BEADS_ACCEPT_BUDGET:-300}"
bead_budget="$(bead_json "$id" | jq -r '.metadata.accept_budget // empty')"
case "$bead_budget" in ''|*[!0-9]*) ;; *) budget="$bead_budget";; esac
[ "$budget" -le 1800 ] || budget=1800
deadline=$(( $(date +%s) + budget ))
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN=gtimeout
else TIMEOUT_BIN=""; fi
over_budget=0
while IFS= read -r cmd; do
  case "$cmd" in ''|'#'*) continue;; esac
  echo "\$ $cmd" >>"$log"
  ran=$((ran + 1))
  rc=0
  left=$(( deadline - $(date +%s) ))
  if [ "$left" -le 0 ]; then
    rc=124
  elif [ -n "$TIMEOUT_BIN" ]; then
    ( cd "$REPO_ROOT" && "$TIMEOUT_BIN" "$left" bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  else
    ( cd "$REPO_ROOT" && bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  fi
  [ "$rc" -eq 124 ] && over_budget=1
  if [ "$rc" -ne 0 ]; then
    status=$rc
    if [ "$over_budget" -eq 1 ]; then
      echo "[exit $status] ACCEPTANCE BUDGET EXCEEDED: the whole block must finish within ${budget}s (default 300; a bead whose proof is a full build and test run sets metadata accept_budget, ceiling 1800). Replace slow proofs (stability sweeps, repeated launches) with a fast one, or set accept_budget if the proof is a build." >>"$log"
    else
      echo "[exit $status]" >>"$log"
    fi
    break
  fi
done <<<"$acceptance"
# A block made only of comments must not pass the gate: refusing is the gate.
[ "$ran" -gt 0 ] || die "bead $id has no executable acceptance command (comments only); write one before calling accept"

attempts="$(bead_attempts "$id")"
if [ "$status" -eq 0 ]; then
  # One commit per bead. Only this bead's own, unpublished commits (base..HEAD) are rewritten.
  # Co-Authored-By trailers from the squashed commits are kept.
  title="$(bead_field "$id" '.title')"
  trailers="$(real_git -C "$DEV" log --format=%B "$base..HEAD" | grep -E '^Co-Authored-By:' | sort -u || true)"
  msg="$id: $title"
  [ -z "$trailers" ] || msg="$msg

$trailers"
  real_git -C "$DEV" reset -q --soft "$base"
  real_git -C "$DEV" commit -q -m "$msg" >&2 \
    || die "acceptance passed but committing $id failed; the squashed changes are staged in oolite-dev, nothing was lost"
  commit="$(real_git -C "$DEV" rev-parse HEAD)"
  real_bd label add "$id" committed >/dev/null 2>&1 || real_bd tag "$id" committed >/dev/null 2>&1 || true
  real_bd update "$id" --set-metadata "dev_commit=$commit" \
    --append-notes "acceptance passed on $(date -u +%FT%TZ); committed as ${commit:0:12} on $branch. Closes when Jon merges $branch into $(dev_main)." -q >&2
  echo "committed $id: ${commit:0:12} on $branch"
  exit 0
fi

attempts=$((attempts + 1))
tail_out="$(tail -c 3000 "$log")"
# Failure signature: the output with hex hashes, timestamps and addresses blanked, so two attempts
# that fail the same way compare equal even if incidental numbers differ.
sig="$(printf %s "$tail_out" | sed -E 's/[0-9a-f]{7,}/H/g; s/[0-9]{2}:[0-9]{2}:[0-9]{2}/T/g; s/0x[0-9a-fA-F]+/A/g; s/[0-9]+/N/g' | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | cut -c1-16)"
prev_sig="$(bead_json "$id" | jq -r '.metadata.last_failure_sig // empty')"
stale="$(bead_json "$id" | jq -r '(.metadata.stale_count // "0") | tonumber')"
if [ "$sig" = "$prev_sig" ]; then stale=$((stale + 1)); else stale=1; fi
real_bd update "$id" --set-metadata "attempts=$attempts" --set-metadata "last_failure_sig=$sig" --set-metadata "stale_count=$stale" \
  --append-notes "accept attempt $attempts failed on $(date -u +%FT%TZ):
$tail_out" -q >&2
limit="${BEADS_WORKER_STALE_REPEATS:-5}"
if [ "$stale" -ge "$limit" ]; then
  echo "stale $id (attempt $attempts): identical failure $stale times in a row — re-read the task"; echo "$tail_out"
  exit 2
fi
echo "rejected $id (attempt $attempts): new failure, retry"; echo "$tail_out"
exit 1
