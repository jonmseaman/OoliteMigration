#!/usr/bin/env bash
# The only path to `bd close`. Called by the orchestrator (never by the implementing worker).
# Fresh checkout of the base branch → merge bead/<id> into it → run the bead's acceptance commands
# on the merged tree → on success fast-forward the base branch to the merge and close the bead.
# A merge conflict is a rejection like any other: its output goes to the notes and the worker
# resolves it next round (by merging the base branch into its worktree).
# On failure: append the output tail to the bead notes, bump attempts, keep the claim so the bead
# comes back for another round. There is no attempt cap. A failure whose signature is identical to
# the previous one is "stale" (no new learning); after BEADS_WORKER_STALE_REPEATS (default 5)
# identical failures in a row the script exits 2 to tell the orchestrator to escalate.
# "Done" means: the bead's work is a merge commit on the base branch and the acceptance commands
# passed on that merged tree. Before anything else, uncommitted work in the worktree is harvested
# onto the branch (harvest.sh), so nothing a worker left behind is lost. On success the worktree and
# branch are removed: the merge commit on the base branch is the record. One accept at a time
# (a lock), so two beads cannot race the base branch.
# Exit 0 = closed and merged · 1 = rejected, new learning · 2 = rejected, stale.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
id="${1:?usage: accept.sh <bead>}"
branch="bead/$id"
base="${BEADS_WORKER_BASE_BRANCH:-main}"
lock="$REPO_ROOT/.beads-worker-accept.lock"
# The lock records its owner's PID. An accept that is killed (timeout, control-C, a dead terminal)
# cannot run its EXIT trap, and without this check its lock would block every later accept until
# a human removed it (2026-09-17, oo-ptc: 13 minutes of the whole fleet waiting on an empty dir).
for _ in $(seq 1 "${BEADS_ACCEPT_LOCK_WAIT:-1800}"); do
  if mkdir "$lock" 2>/dev/null; then echo $$ > "$lock/pid"; break; fi
  owner="$(cat "$lock/pid" 2>/dev/null || true)"
  if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then
    echo "accept: reclaiming $lock left by dead accept pid '${owner:-unknown}'" >&2
    rm -rf "$lock"; continue
  fi
  sleep 1
done
[ -d "$lock" ] && [ "$(cat "$lock/pid" 2>/dev/null)" = "$$" ] || die "accept: could not take $lock"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/accept-$id.XXXXXX")"
trap 'git -C "$REPO_ROOT" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"; rm -rf "$lock" 2>/dev/null' EXIT
git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$base" || die "no base branch $base"
# Preserve whatever the worker left uncommitted, then insist there is something to merge.
[ -d "$WORKTREES/$id" ] && "$here/harvest.sh" "$id" >&2
git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch" || die "no branch $branch and no worktree: the worker produced nothing to merge"
if [ "$(git -C "$REPO_ROOT" rev-list --count "$base..$branch")" -eq 0 ]; then
  attempts="$(( $(bead_attempts "$id") + 1 ))"
  real_bd update "$id" --set-metadata "attempts=$attempts" --append-notes "accept attempt $attempts on $(date -u +%FT%TZ): $branch has no commits beyond $base; nothing to merge. The worker must commit its changes in the worktree." -q >&2
  touch "$REPO_ROOT/.fleet-progress.$id"
  echo "rejected $id (attempt $attempts): $branch has no commits beyond $base"; exit 1
fi
# Clean, detached checkout of the base branch; merge the bead into it. Nothing here touches the
# agent's worktree or the orchestrator's checkout.
git -C "$REPO_ROOT" worktree add --detach "$tmp" "$base" >/dev/null
if ! git -C "$tmp" -c user.name=beads-worker -c user.email=beads-worker@local merge --no-ff --no-edit -m "bead $id: merge into $base" "$branch" >"$tmp.merge.log" 2>&1 \
   && ! { resolve_beads_db_conflict "$tmp" \
          && git -C "$tmp" -c user.name=beads-worker -c user.email=beads-worker@local commit -q --no-edit >>"$tmp.merge.log" 2>&1 \
          && echo "accept: $id conflicted with $base only in the bead DB export (.beads/*.jsonl); took $base's copy, which is regenerated from Dolt after the close" >&2 \
          && { real_bd update "$id" --append-notes "accept on $(date -u +%FT%TZ): bead DB export conflict with $base auto-resolved by taking $base's .beads/*.jsonl (a generated file; every record comes from Dolt)" -q >&2 || true; }; }; then
  attempts="$(( $(bead_attempts "$id") + 1 ))"
  conflict="$(git -C "$tmp" diff --name-only --diff-filter=U 2>/dev/null | head -20)"
  real_bd update "$id" --set-metadata "attempts=$attempts" --append-notes "accept attempt $attempts: merge conflict with $base on $(date -u +%FT%TZ). Conflicting files:
$conflict
Resolve by merging $base into the worktree branch, then commit." -q >&2
  touch "$REPO_ROOT/.fleet-progress.$id"
  echo "rejected $id (attempt $attempts): merge conflict with $base"; echo "$conflict"; rm -f "$tmp.merge.log"
  exit 1
fi
rm -f "$tmp.merge.log"
merged="$(git -C "$tmp" rev-parse HEAD)"
acceptance="$(bead_acceptance "$id")"
[ -n "$acceptance" ] || die "bead $id has no acceptance commands; refusing to close without a gate"
log="$(mktemp)"
status=0
ran=0
if command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout "${BEADS_ACCEPT_TIMEOUT:-1500}")
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout "${BEADS_ACCEPT_TIMEOUT:-1500}")
else TIMEOUT_CMD=(); fi
while IFS= read -r cmd; do
  case "$cmd" in ''|'#'*) continue;; esac
  echo "\$ $cmd" >>"$log"
  ran=$((ran + 1))
  rc=0
  ( cd "$tmp" && "${TIMEOUT_CMD[@]}" bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    status=$rc
    echo "[exit $status]" >>"$log"
    break
  fi
done <<<"$acceptance"
attempts="$(bead_attempts "$id")"
# A block made only of comments (a frontier seam whose executable acceptance has not been written
# yet) must not close the bead: refusing is the gate.
[ "$ran" -gt 0 ] || die "bead $id has no executable acceptance command (comments only); write one before calling accept"
if [ "$status" -eq 0 ]; then
  # Advance the base branch to the merge commit. If the orchestrator's checkout has $base checked
  # out, fast-forward it there (git refuses to move a checked-out branch behind its worktree);
  # otherwise move the ref directly.
  if [ "$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null)" = "$base" ]; then
    git -C "$REPO_ROOT" merge --ff-only "$merged" >/dev/null 2>&1 || die "acceptance passed but fast-forwarding $base in $REPO_ROOT failed (dirty checkout?); merge commit $merged is intact, bead left open"
  else
    git -C "$REPO_ROOT" update-ref "refs/heads/$base" "$merged" "$(git -C "$REPO_ROOT" rev-parse "$base")"
  fi
  # The record is the merge commit on the base branch; prove it is there before closing anything.
  git -C "$REPO_ROOT" merge-base --is-ancestor "$merged" "$base" || die "acceptance passed but $merged is not on $base; bead left open"
  short="$(git -C "$REPO_ROOT" rev-parse --short "$merged")"
  BEADS_ACCEPT=1 real_bd close "$id" --reason "accepted: merged into $base as $short; all acceptance commands exit 0 on the merged tree" -q >&2
  real_bd update "$id" --set-metadata "merge_commit=$merged" -q >&2 || true
  # The work is on the base branch: the worktree and branch have nothing left to say.
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREES/$id" >/dev/null 2>&1 || true
  git -C "$REPO_ROOT" branch -D "$branch" >/dev/null 2>&1 || true
  touch "$REPO_ROOT/.fleet-progress.$id"
  # The tracked export follows the DB, on the base branch only (export.auto is off; see _lib.sh).
  refresh_beads_export "$base"
  echo "closed $id: merged into $base as $short; worktree and branch removed"
  exit 0
fi
attempts=$((attempts + 1))
tail_out="$(tail -c 3000 "$log")"
# Failure signature: the output with hex hashes, timestamps and addresses blanked, so two attempts that
# fail the same way compare equal even if incidental numbers differ.
sig="$(printf %s "$tail_out" | sed -E 's/[0-9a-f]{7,}/H/g; s/[0-9]{2}:[0-9]{2}:[0-9]{2}/T/g; s/0x[0-9a-fA-F]+/A/g; s/[0-9]+/N/g' | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | cut -c1-16)"
prev_sig="$(bead_json "$id" | jq -r '.metadata.last_failure_sig // empty')"
stale="$(bead_json "$id" | jq -r '(.metadata.stale_count // "0") | tonumber')"
if [ "$sig" = "$prev_sig" ]; then stale=$((stale + 1)); else stale=1; fi
real_bd update "$id" --set-metadata "attempts=$attempts" --set-metadata "last_failure_sig=$sig" --set-metadata "stale_count=$stale" \
  --append-notes "accept attempt $attempts failed on $(date -u +%FT%TZ):
$tail_out" -q >&2
limit="${BEADS_WORKER_STALE_REPEATS:-5}"
if [ "$stale" -ge "$limit" ]; then
  echo "stale $id (attempt $attempts): identical failure $stale times in a row — escalate"; echo "$tail_out"
  exit 2
fi
# New learning: counts as progress for the /goal gate. The claim is kept so next-bead hands it back.
touch "$REPO_ROOT/.fleet-progress.$id"
echo "rejected $id (attempt $attempts): new failure, retry"; echo "$tail_out"
exit 1
