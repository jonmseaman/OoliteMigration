#!/usr/bin/env bash
# The only path to `bd close`. Called by the orchestrator (never by the implementing worker).
# Fresh checkout of bead/<id> → run the bead's acceptance commands → close on success.
# On failure: append the output tail to the bead notes, bump attempts, keep the claim so the bead
# comes back for another round. There is no attempt cap. A failure whose signature is identical to
# the previous one is "stale" (no new learning); after BEADS_WORKER_STALE_REPEATS (default 5)
# identical failures in a row the script exits 2 to tell the orchestrator to escalate.
# Exit 0 = closed · 1 = rejected, new learning · 2 = rejected, stale.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: accept.sh <bead>}"
branch="bead/$id"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/accept-$id.XXXXXX")"
trap 'git -C "$REPO_ROOT" worktree remove --force "$tmp" >/dev/null 2>&1 || rm -rf "$tmp"' EXIT
git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch" || die "no branch $branch (worker did not commit?)"
git -C "$REPO_ROOT" worktree add --detach "$tmp" "$branch" >/dev/null
acceptance="$(bead_field "$id" '.acceptance_criteria // .acceptance')"
[ -n "$acceptance" ] || die "bead $id has no acceptance commands; refusing to close without a gate"
log="$(mktemp)"
status=0
if command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout "${BEADS_ACCEPT_TIMEOUT:-1500}")
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout "${BEADS_ACCEPT_TIMEOUT:-1500}")
else TIMEOUT_CMD=(); fi
while IFS= read -r cmd; do
  case "$cmd" in ''|'#'*) continue;; esac
  echo "\$ $cmd" >>"$log"
  rc=0
  ( cd "$tmp" && "${TIMEOUT_CMD[@]}" bash -o pipefail -c "$cmd" ) >>"$log" 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    status=$rc
    echo "[exit $status]" >>"$log"
    break
  fi
done <<<"$acceptance"
attempts="$(bead_attempts "$id")"
if [ "$status" -eq 0 ]; then
  BEADS_ACCEPT=1 real_bd close "$id" --reason "accepted: $(git -C "$tmp" rev-parse --short HEAD) all acceptance commands exit 0" -q >&2
  touch "$REPO_ROOT/.fleet-progress.$id"
  echo "closed $id"
  exit 0
fi
attempts=$((attempts + 1))
tail_out="$(tail -c 3000 "$log")"
# Failure signature: the output with hex hashes, timestamps and addresses blanked, so two attempts that
# fail the same way compare equal even if incidental numbers differ.
sig="$(printf %s "$tail_out" | sed -E 's/[0-9a-f]{7,}/H/g; s/[0-9]{2}:[0-9]{2}:[0-9]{2}/T/g; s/0x[0-9a-fA-F]+/A/g; s/[0-9]+/N/g' | shasum -a 256 | cut -c1-16)"
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
