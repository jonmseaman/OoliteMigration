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
# Exit 0 = closed and merged · 1 = rejected, new learning · 2 = rejected, stale.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: accept.sh <bead>}"
branch="bead/$id"
base="${BEADS_WORKER_BASE_BRANCH:-main}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/accept-$id.XXXXXX")"
trap 'git -C "$REPO_ROOT" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"' EXIT
git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch" || die "no branch $branch (worker did not commit?)"
git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$base" || die "no base branch $base"
# Clean, detached checkout of the base branch; merge the bead into it. Nothing here touches the
# agent's worktree or the orchestrator's checkout.
git -C "$REPO_ROOT" worktree add --detach "$tmp" "$base" >/dev/null
if ! git -C "$tmp" -c user.name=beads-worker -c user.email=beads-worker@local merge --no-ff --no-edit -m "bead $id: merge into $base" "$branch" >"$tmp.merge.log" 2>&1; then
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
  BEADS_ACCEPT=1 real_bd close "$id" --reason "accepted: merged into $base as $(git -C "$REPO_ROOT" rev-parse --short "$merged"); all acceptance commands exit 0" -q >&2
  touch "$REPO_ROOT/.fleet-progress.$id"
  echo "closed $id: merged into $base as $(git -C "$REPO_ROOT" rev-parse --short "$merged")"
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
