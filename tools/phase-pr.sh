#!/usr/bin/env bash
# Open the phase's pull request: oolite-dev's develop → master on the game fork.
#
# Individual beads already reached develop through their own reviewed pull requests, so this one is
# the phase gate, not a code review of unseen work. It refuses unless the phase is genuinely done:
# nothing actionable left in the queue, nothing still awaiting your review, develop clean and in
# step with the fork, and no open review-finding bead from the phase-end review.
#
#   bash tools/phase-pr.sh --selector "--label phase:5" [--title "..."] [--ready] [--dry-run]
#
# The phase-end review itself is the beads-worker skill's job, not this script's: a shell script
# cannot read a diff. The script enforces its OUTCOME — findings are filed as beads labelled
# review-finding, and an open one blocks the pull request.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
DEV="$ROOT/oolite-dev"
base="master"; head=""; title=""; selector=""; draft="--draft"; dry=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) base="$2"; shift 2;;
    --head) head="$2"; shift 2;;
    --title) title="$2"; shift 2;;
    --selector) selector="$2"; shift 2;;
    --ready) draft=""; shift;;
    --draft) draft="--draft"; shift;;
    --dry-run) dry=1; shift;;
    -h|--help) sed -n '2,14p' "$0"; exit 0;;
    *) echo "phase-pr: unknown argument: $1" >&2; exit 2;;
  esac
done
die() { echo "phase-pr: $*" >&2; exit 1; }
run() { if [ "$dry" -eq 1 ]; then echo "  would run: $*"; else "$@"; fi; }

[ -e "$DEV/.git" ] || die "oolite-dev is not checked out"
[ -n "$head" ] || head="$(git -C "$DEV" config --get git-town.main-branch || echo develop)"
[ "$head" != "$base" ] || die "head and base are both '$base'"
command -v gh >/dev/null 2>&1 || die "gh is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run: gh auth login"

# 1. The queue for this phase must hold nothing actionable and nothing awaiting review.
if [ -n "$selector" ]; then
  # shellcheck disable=SC2086
  "$ROOT/.claude/skills/beads-worker/scripts/queue-check.sh" $selector \
    || die "the queue is not drained for $selector; finish or park those beads first"
  # shellcheck disable=SC2086
  awaiting="$("$ROOT/.claude/skills/beads-worker/scripts/queue-check.sh" $selector | sed -n '/awaiting your review/,$p' | tail -n +2)"
  [ -z "$awaiting" ] || die "beads are still awaiting your review and merge:
$awaiting"
fi

# 2. The phase-end review's findings must be dealt with.
findings="$(bd list --label review-finding --status open,in_progress --json -n 0 2>/dev/null \
  | jq -r 'if type=="array" then .[] else empty end | "\(.id)\t\(.title)"' || true)"
[ -z "$findings" ] || die "open review findings block the pull request:
$findings"

# 3. develop must be clean, in step with the fork, and actually ahead of master.
[ -z "$(git -C "$DEV" status --porcelain)" ] || die "oolite-dev has uncommitted changes"
git -C "$DEV" fetch -q origin
[ "$(git -C "$DEV" rev-parse "$head")" = "$(git -C "$DEV" rev-parse "origin/$head")" ] \
  || die "$head differs from origin/$head; run: bash tools/sync-dev.sh"
ahead="$(git -C "$DEV" rev-list --count "origin/$base..origin/$head")"
[ "$ahead" -gt 0 ] || die "origin/$head has nothing beyond origin/$base"

# 4. An existing pull request is reported, not duplicated.
existing="$(cd "$DEV" && gh pr list --base "$base" --head "$head" --state open --json url -q '.[0].url' 2>/dev/null || true)"
if [ -n "$existing" ]; then echo "phase-pr: a pull request is already open: $existing"; exit 0; fi

[ -n "$title" ] || title="Merge $head into $base ($ahead commits)"
body="$(mktemp)"; trap 'rm -f "$body"' EXIT
{
  echo "$ahead commits from \`$head\`, each already reviewed and merged as its own pull request."
  echo
  echo "## Commits"
  git -C "$DEV" log --no-merges --format='- %s' "origin/$base..origin/$head" | head -100
  if [ -n "$selector" ]; then
    echo
    echo "## Beads"
    # shellcheck disable=SC2086
    bd list $selector --status closed --json -n 0 2>/dev/null \
      | jq -r 'if type=="array" then .[] else empty end | "- \(.id) \(.title)"' | head -100 || true
  fi
} > "$body"

echo "phase-pr: $head → $base on the game fork, $ahead commits"
if [ "$dry" -eq 1 ]; then
  echo "  would run: gh pr create --base $base --head $head --title \"$title\" --body-file <generated> $draft"
  echo "--- body ---"; cat "$body"
  exit 0
fi
( cd "$DEV" && gh pr create --base "$base" --head "$head" --title "$title" --body-file "$body" $draft )
