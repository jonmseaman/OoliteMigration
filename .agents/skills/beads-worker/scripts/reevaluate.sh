#!/usr/bin/env bash
# Ask the frontier model (Claude Code, headless) whether a stuck or blocked bead is the right task,
# and apply its decision. Read-only for Claude; every write goes through the scripts below.
#   reevaluate.sh <bead> "<trigger: blocked reason | stale acceptance failure | reviewer stalemate>"
# Decision (JSON, from Claude):
#   retry       -> guidance appended to notes; stale counter reset (the guidance is new information)
#   reclassify  -> tools/gen-stories.py --reclassify <bead> <sweep>   (rename->convert, convert->presplit, ...)
#   add_dep     -> bead now depends on seam:<key>; released until it closes
#   escalate    -> escalate.sh <bead> "<reason>"
# Any decision may carry generator_bug: one deduplicated frontier bead is filed to fix the rule.
# The frontier model is Claude Opus 5 (BEADS_FRONTIER_MODEL overrides; Jon, 2026-09-11).
# Exit 0 = decision applied. Exit 3 = Claude unavailable or unparsable; caller falls back to escalate.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
# Fail fast before any path is computed (oo-aqzj): unsourced _lib.sh leaves these empty and the
# `cd "$REPO_ROOT"` / marker touch land at the filesystem root. Keep above the first use.
: "${REPO_ROOT:?_lib.sh not sourced (REPO_ROOT unset): refusing to compute paths from an empty prefix}" \
  "${WORKTREES:?_lib.sh not sourced (WORKTREES unset): refusing to compute paths from an empty prefix}"
id="${1:?usage: reevaluate.sh <bead> \"<trigger>\"}"; trigger="${2:-stuck}"
command -v claude >/dev/null 2>&1 || { echo "reevaluate: claude CLI not on PATH" >&2; exit 3; }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
title="$(bead_field "$id" '.title')"; labels="$(bead_json "$id" | jq -r '(.labels // []) | join(",")')"
body="$(bead_field "$id" '.description')"; ctx="$("$here/context.sh" "$id" 20)"
prompt="You are the frontier adjudicator for an autonomous migration fleet (see CLAUDE.md and docs/execution-model.md in this repo). A cheap-model worker is stuck on the bead below. Decide whether the TASK is right, not whether the code is right: acceptance commands and a reviewer decide correctness.

Trigger: $trigger

Bead $id — $title
Labels: $labels

$body

$ctx

Read the files the bead names (they are under upstream/oolite/src) before deciding. Then answer with ONE JSON object on the last line and nothing after it:
{\"action\": \"retry|reclassify|add_dep|escalate\", \"sweep\": \"<target sweep for reclassify: convert|presplit|renames|foundation|extractors>\", \"seam\": \"<seam key for add_dep, e.g. 2.10>\", \"guidance\": \"<concrete instructions for the next attempt, for retry>\", \"reason\": \"<one sentence>\", \"generator_bug\": \"<if the task was mis-generated: what rule in tools/gen-stories.py is wrong, else empty>\"}
Rules: retry only if a cheap model can plausibly finish with your guidance; reclassify when the file is a different kind of task than the sweep assumes; add_dep when it needs something a named seam produces first; escalate when it needs a frontier model or a human decision."
out="$(cd "$REPO_ROOT" && printf %s "$prompt" | claude -p --model "${BEADS_FRONTIER_MODEL:-claude-opus-5}" --output-format json --max-turns "${BEADS_REEVAL_MAX_TURNS:-12}" --allowedTools "Read,Grep,Glob" --disallowedTools "Edit,Write,Bash" 2>/dev/null)" || { echo "reevaluate: claude call failed" >&2; exit 3; }
text="$(printf %s "$out" | jq -r '.result // empty' 2>/dev/null)"; [ -n "$text" ] || text="$out"
dec="$(printf %s "$text" | grep -o '{[^{}]*"action"[^{}]*}' | tail -1)"
[ -n "$dec" ] && printf %s "$dec" | jq -e . >/dev/null 2>&1 || { echo "reevaluate: no JSON decision in Claude's output" >&2; printf %s "$text" | tail -c 600 >&2; exit 3; }
action="$(printf %s "$dec" | jq -r .action)"; reason="$(printf %s "$dec" | jq -r '.reason // ""')"; guidance="$(printf %s "$dec" | jq -r '.guidance // ""')"
gbug="$(printf %s "$dec" | jq -r '.generator_bug // ""')"
real_bd update "$id" --append-notes "claude re-evaluation ($trigger) on $(date -u +%FT%TZ): $action — $reason${guidance:+
guidance: $guidance}" -q >&2
if [ -n "$gbug" ]; then
  gtitle="Fix story generator: ${gbug:0:90}"
  if ! real_bd list --all --json -n 0 --title-contains "Fix story generator" 2>/dev/null | jq -e --arg t "$gtitle" 'map(select(.title==$t)) | length > 0' >/dev/null; then
    real_bd create "$gtitle" --labels frontier,phase:0,generator-bug --description "Reported by reevaluate.sh from bead $id. $gbug

After fixing tools/gen-stories.py, run it with --dry-run and reclassify or regenerate the affected beads." --priority 1 -q >&2
    echo "filed generator-bug bead: $gtitle"
  fi
fi
case "$action" in
  retry)
    real_bd update "$id" --set-metadata stale_count=0 -q >&2; touch "$REPO_ROOT/.fleet-progress.$id"
    echo "retry $id with guidance: $guidance";;
  reclassify)
    sweep="$(printf %s "$dec" | jq -r '.sweep // ""')"; [ -n "$sweep" ] || { echo "reevaluate: reclassify without sweep" >&2; exit 3; }
    (cd "$REPO_ROOT" && "${PYTHON:-python3}" tools/gen-stories.py --reclassify "$id" "$sweep") || exit 3
    real_bd update "$id" --set-metadata stale_count=0 --set-metadata attempts=0 -q >&2; touch "$REPO_ROOT/.fleet-progress.$id"
    echo "reclassified $id -> $sweep";;
  add_dep)
    seam="$(printf %s "$dec" | jq -r '.seam // ""')"
    sid="$(real_bd list --all --json -n 0 --label "seam:$seam" 2>/dev/null | jq -r '.[0].id // empty')"
    [ -n "$sid" ] || { echo "reevaluate: seam $seam not found" >&2; exit 3; }
    real_bd dep add "$id" "$sid" -q >&2; real_bd update "$id" --status open --assignee "" --set-metadata stale_count=0 -q >&2; touch "$REPO_ROOT/.fleet-progress.$id"
    echo "$id now depends on seam $seam ($sid); released";;
  escalate)
    "$here/escalate.sh" "$id" "claude: $reason";;
  *) echo "reevaluate: unknown action $action" >&2; exit 3;;
esac
