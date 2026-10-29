#!/usr/bin/env bash
# The bead's gate, and the only thing that opens its pull request. Called by the loop, never by the
# agent that wrote the code (CLAUDE.md hard rule 3 — the guard shim in tools/guard refuses `bd
# close` outright, and this script does not close anything either).
#
# The work is already committed on the bead's feature branch in oolite-dev. This script runs the
# bead's acceptance commands and, only if every one exits 0, runs `git town propose` to open a pull
# request against develop and marks the bead `proposed`. The bead stays OPEN: it closes when you
# merge that pull request and a later tick notices (land.sh).
#
# Acceptance runs with cwd = the OUTER repo root, not oolite-dev: acceptance lines spell the
# submodule explicitly (`cd oolite-dev && tests/run.sh unit`).
#
# Exit 0 = acceptance passed, pull request open · 1 = rejected, new information · 2 = rejected, stale.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
id="${1:?usage: accept.sh <bead>}"

# The gate only means something on a tree that holds exactly the committed work being judged.
dev_clean || die "oolite-dev has uncommitted changes; commit them before accepting $id:
$(real_git -C "$DEV" status --short | head -20)"
branch="$(dev_branch)"
main="$(dev_main)"
[ "$branch" != "$main" ] || die "oolite-dev is on $main; a bead's work belongs on its own branch (run branch.sh $id)"
if [ "$(real_git -C "$DEV" rev-list --count "$main..$branch")" -eq 0 ]; then
  attempts="$(( $(bead_attempts "$id") + 1 ))"
  real_bd update "$id" --set-metadata "attempts=$attempts" --append-notes \
    "accept attempt $attempts on $(date -u +%FT%TZ): $branch has no commits beyond $main. The worker committed nothing." -q >&2
  echo "rejected $id (attempt $attempts): nothing committed on $branch"; exit 1
fi

acceptance="$(bead_acceptance "$id")"
[ -n "$acceptance" ] || die "bead $id has no acceptance commands; refusing to propose without a gate"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
ran=0
# The whole block shares ONE budget (about five minutes). Each line gets what is left of it; a line
# that runs out exits 124 and the note names the budget, so the fix is a faster proof, not a
# bigger number.
budget="${BEADS_ACCEPT_BUDGET:-300}"
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
      echo "[exit $status] ACCEPTANCE BUDGET EXCEEDED: the whole block must finish within BEADS_ACCEPT_BUDGET=${budget}s. Replace slow proofs (stability sweeps, repeated launches) with a fast one, or split the bead. Do not raise the budget." >>"$log"
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
  # Open the pull request, or reuse the one this bead already has (a retried bead keeps its PR and
  # `git town propose` would fail on a second call).
  pr="$(bead_json "$id" | jq -r '.metadata.pr // empty')"
  if [ -z "$pr" ]; then
    ( cd "$DEV" && git town propose ) >&2 || die "acceptance passed but 'git town propose' failed for $id; the branch $branch is intact, nothing was lost"
    pr="$(real_git -C "$DEV" config --get "branch.$branch.git-town-proposal-url" 2>/dev/null || true)"
    [ -n "$pr" ] || pr="$(cd "$DEV" && gh pr view "$branch" --json url -q .url 2>/dev/null || true)"
    real_bd update "$id" --set-metadata "pr=$pr" -q >&2 || true
  else
    ( cd "$DEV" && git push ) >&2 || true
  fi
  real_bd label add "$id" proposed >/dev/null 2>&1 || real_bd tag "$id" proposed >/dev/null 2>&1 || true
  real_bd update "$id" --set-metadata "dev_commit=$(real_git -C "$DEV" rev-parse HEAD)" \
    --append-notes "acceptance passed on $(date -u +%FT%TZ); proposed as ${pr:-<pull request>}. Awaiting review and merge." -q >&2
  echo "proposed $id: $branch → $main  ${pr:-}"
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
