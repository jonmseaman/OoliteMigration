#!/usr/bin/env bash
# tools/tier-b-guardrails-proof.sh -- PROVE TIER B'S GUARDRAILS STAGE CAN GO RED (bead oo-1bf.9).
#
# Phase 0's exit gate (docs/phases/0-safety-net.md boxes 38 and 39) says two things must FAIL
# TIER B: a reintroduced JS_*/libgnustep-base symbol, and a bead branch touching goldens/ without
# an approved re-bless. tools/tier-b.sh now runs tools/guardrails.sh as stage 0 to make that true.
# A gate nobody has watched go red is a gate nobody has tested, so this script plants each of the
# two defects, runs tools/tier-b.sh, and asserts it exits NONZERO **naming the stage and the
# guard** -- then shows the unmutated tree green through the same stage. Same shape as
# tools/tier-c-mutants.sh.
#
#     tools/tier-b-guardrails-proof.sh          # both arms plus the clean control
#     tools/tier-b-guardrails-proof.sh 2        # one arm by number
#
# ------------------------------------------------------------------------------------------------
# WHY EVERY MUTATION HAPPENS IN A SCRATCH REPOSITORY, NOT IN THIS WORKTREE
# ------------------------------------------------------------------------------------------------
#
# This script plants deliberate defects, and a restore-on-exit trap DOES NOT RUN when the process
# is killed at a timeout. The fleet has been bitten twice by exactly that:
#
#   * bead oo-dto timed out mid-mutation and harvest.sh committed `if False:` in place of the one
#     predicate its scenario was named for;
#   * bead oo-qd6 timed out and left a 3-byte '{}' stub at
#     goldens/windows-x64/008-material-test-suite/state.json, which was committed -- an unapproved
#     write into the very tree arm 2 below is about to prove is protected.
#
# So NOTHING here writes to a tracked file of this worktree. A throwaway MINIMAL repository is
# built under $TMPDIR, the real tools/guardrails.sh and tools/tier-b.sh are COPIED into it, and
# every mutation happens there. Kill this script at any instant and the worst that survives is a
# directory under Temp. In particular the goldens/ arm creates its golden inside the scratch repo:
# the real goldens/ tree is never read for writing, never copied back, and never touched.
#
# ------------------------------------------------------------------------------------------------
# WHY A SCRATCH REPO RATHER THAN A SCRATCH WORKTREE OR A CLONE
# ------------------------------------------------------------------------------------------------
#
# `git worktree add` is forbidden to a bead worker, and a full clone of this repository (the
# oolite subtree, the OXP corpus) costs gigabytes and minutes for a check that must stay under a
# few seconds. guardrails.sh needs surprisingly little to be FULLY LIVE, and the mini repo
# provides all of it so that no check degrades into a vacuous pass:
#
#   * a resolvable base ref (a `main` branch whose tip is HEAD's merge base);
#   * >= 1 tracked file under EACH protected prefix (goldens/, tests/golden/scenarios/), or the
#     protected-path anti-vacuity check fails and the run proves nothing;
#   * the REAL tools/deny-list.txt and tools/rebless-approvals.txt, copied verbatim, so the arms
#     are judged by the patterns and approvals that actually ship;
#   * >= 1 tracked file the test classifier recognises.
#
# The evidence that these are live is asserted, not assumed: the CONTROL arm below requires
# guardrails.sh's own evidence lines ("deny-list: N patterns, canary scores M", "tests: classifier
# matches N tracked test files") in tier-b's output before any mutant is applied. A mutant run
# against an already-broken baseline is a manufactured kill (bead oo-4vdc).
#
# ------------------------------------------------------------------------------------------------
# WHAT "RED" MEANS HERE
# ------------------------------------------------------------------------------------------------
#
# Never merely rc != 0. Bead oo-1xz lost an acceptance because a red-proof line got the RIGHT EXIT
# CODE FROM THE WRONG STAGE. Each arm therefore demands BOTH:
#
#     "tier-b: FAIL (stage guardrails)"   -- the failure came from this stage, not from the build
#     the guard's own message             -- "deny-list: ... reintroduces deny-listed symbols"
#                                            / "is under a protected golden path and is changed"
#
# tier-b is invoked with --fast in the scratch repo: --fast skips only the BUILD stage, which the
# mini repo has no binary for, and leaves stage 0 exactly as a real run performs it. The control
# arm consequently ends red at "FAIL (stage build)" -- and that is the point: it must get PAST
# guardrails ("stage guardrails ok") to reach it, which is precisely the green half of the proof.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO" || exit 2
[ -d /ucrt64/bin ] && export PATH="/ucrt64/bin:$PATH"

ONLY="${1:-}"
PASS=0
FAIL=0
RUN="$(mktemp -d "${TMPDIR:-/tmp}/tier-b-guardrails-proof-XXXXXX")" || exit 2
trap 'rm -rf "$RUN" 2>/dev/null || true' EXIT

hr() { printf '\n%s\n' "------------------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }

GIT="git -c user.email=proof@example.invalid -c user.name=proof -c commit.gpgsign=false"

# ------------------------------------------------------------------------------------------------
# build_scratch <dir> -- a minimal repository in which every guardrails check is LIVE.
# ------------------------------------------------------------------------------------------------
build_scratch() {
  local d="$1"
  rm -rf "$d"
  mkdir -p "$d/tools" "$d/goldens/windows-x64/001" "$d/tests/golden/scenarios/001" "$d/src"

  cp "$REPO/tools/guardrails.sh"         "$d/tools/guardrails.sh"
  cp "$REPO/tools/tier-b.sh"             "$d/tools/tier-b.sh"
  cp "$REPO/tools/deny-list.txt"         "$d/tools/deny-list.txt"
  cp "$REPO/tools/rebless-approvals.txt" "$d/tools/rebless-approvals.txt"
  chmod +x "$d/tools/guardrails.sh" "$d/tools/tier-b.sh"

  # A blessed golden, so goldens/ is a populated protected prefix (arm 2 edits THIS copy).
  printf '{"scenario": "001", "value": 1}\n' > "$d/goldens/windows-x64/001/state.json"
  # A scenario spec, so the second protected prefix is populated too and neither is vacuous.
  printf '{"scenario": "001"}\n' > "$d/tests/golden/scenarios/001/spec.json"
  # A collectable test, so the rule-2 classifier matches something.
  printf 'def test_probe():\n    assert 1 == 1\n' > "$d/tests/golden/scenarios/001/test_probe.py"
  # A C source file with ZERO deny-list hits (arm 1 plants one into THIS copy).
  printf 'int probe(void)\n{\n    return 0;\n}\n' > "$d/src/probe.c"

  ( cd "$d" \
    && $GIT init -q . >/dev/null 2>&1 \
    && $GIT checkout -q -b main 2>/dev/null \
    ; $GIT add -A >/dev/null 2>&1 \
    && $GIT commit -q -m "scratch baseline" >/dev/null 2>&1 ) || return 1
  # `git init` may already be on main; the checkout above is best-effort. Make it certain, because
  # guardrails.sh resolves its base as `git merge-base HEAD main` and a missing main falls back to
  # HEAD^1, which a single-commit repo does not have -- that would be rc=2 REFUSED, not a verdict.
  ( cd "$d" && $GIT rev-parse --verify --quiet main >/dev/null ) \
    || ( cd "$d" && $GIT branch -f main HEAD >/dev/null 2>&1 )
  ( cd "$d" && $GIT rev-parse --verify --quiet main >/dev/null )
}

run_tier_b() {  # run_tier_b <scratch-dir> -> prints combined output, returns tier-b's rc
  local d="$1" rc=0 out
  out="$( cd "$d" && TMPDIR="${TMPDIR:-/tmp}" bash tools/tier-b.sh --fast 2>&1 )" || rc=$?
  printf '%s\n' "$out"
  return $rc
}

# ------------------------------------------------------------------------------------------------
# CONTROL -- the unmutated scratch tree must reach and PASS stage 0, with live evidence.
# ------------------------------------------------------------------------------------------------
control() {
  hr; say "CONTROL: unmutated scratch tree -- stage guardrails must PASS, with live evidence"
  local d="$RUN/control" out rc=0
  build_scratch "$d" || { say "  RESULT: could not build the scratch repo"; FAIL=$((FAIL+1)); return 1; }
  out="$(run_tier_b "$d")" || rc=$?
  printf '%s\n' "$out" | grep -E 'guardrails|FAIL|GREEN' | sed 's/^/  | /' | head -12
  local ok=1
  printf '%s' "$out" | grep -qF 'stage guardrails ok' \
    || { say "  MISSING: 'stage guardrails ok' -- the stage did not pass"; ok=0; }
  printf '%s' "$out" | grep -qF 'FAIL (stage guardrails)' \
    && { say "  UNEXPECTED: the clean tree failed the guardrails stage"; ok=0; }
  # A mutant run against a baseline whose checks are already dead is a manufactured kill
  # (bead oo-4vdc): require the evidence lines that only a check which really scanned can print.
  printf '%s' "$out" | grep -qE 'deny-list: [0-9]+ patterns, canary scores [1-9]' \
    || { say "  MISSING: the deny-list evidence line -- that check is not live in the scratch repo"; ok=0; }
  printf '%s' "$out" | grep -qE 'tests: classifier matches [1-9]' \
    || { say "  MISSING: the test-classifier evidence line -- that check is not live"; ok=0; }
  if [ "$ok" = 1 ]; then
    say "  RESULT: GREEN through stage guardrails, both anti-vacuity evidence lines present"
    say "          (the run then ends at 'FAIL (stage build)' -- expected: a mini repo has no binary)"
    PASS=$((PASS+1))
  else
    printf '%s\n' "$out" | tail -20 | sed 's/^/  | /'
    FAIL=$((FAIL+1))
  fi
}

# ------------------------------------------------------------------------------------------------
# expect_red <n> <name> <protects> <mutate-fn> <guard-substring>
# ------------------------------------------------------------------------------------------------
expect_red() {
  local n="$1" name="$2" protects="$3" mutate="$4" guard="$5"
  [ -n "$ONLY" ] && [ "$ONLY" != "$n" ] && return 0
  hr
  printf 'MUTANT %s: %s\n  protects: %s\n  expects RED from: tier-b: FAIL (stage guardrails)\n  and the guard saying: %s\n\n' \
    "$n" "$name" "$protects" "$guard"
  local d="$RUN/mutant$n" out rc=0
  build_scratch "$d" || { say "  RESULT: could not build the scratch repo"; FAIL=$((FAIL+1)); return 1; }

  # BASELINE FIRST. Every line a mutant is judged by must be green BEFORE the mutation, or an
  # already-red line registers as a kill for any mutant (bead oo-4vdc).
  local base_out base_rc=0
  base_out="$(run_tier_b "$d")" || base_rc=$?
  if ! printf '%s' "$base_out" | grep -qF 'stage guardrails ok'; then
    say "  RESULT: BASELINE NOT GREEN at stage guardrails -- refusing to report a kill"
    printf '%s\n' "$base_out" | tail -15 | sed 's/^/  | /'
    FAIL=$((FAIL+1)); return 1
  fi
  say "  baseline: stage guardrails ok (the mutation below is the only change)"

  "$mutate" "$d" || { say "  RESULT: the mutation could not be applied"; FAIL=$((FAIL+1)); return 1; }

  out="$(run_tier_b "$d")" || rc=$?
  printf '%s\n' "$out" | grep -E 'guardrails:|FAIL|RED' | sed 's/^/  | /' | head -12
  printf '  -> rc=%s\n' "$rc"
  if [ "$rc" -eq 0 ]; then
    say "  RESULT: SURVIVED -- tier-b stayed GREEN with the defect planted. BLIND GATE."
    FAIL=$((FAIL+1)); return 1
  fi
  if ! printf '%s' "$out" | grep -qF 'FAIL (stage guardrails)'; then
    say "  RESULT: rc=$rc but NOT from stage guardrails -- right exit code, WRONG stage (bead oo-1xz)."
    FAIL=$((FAIL+1)); return 1
  fi
  if ! printf '%s' "$out" | grep -qF "$guard"; then
    say "  RESULT: failed at stage guardrails but the guard message did not contain: $guard"
    FAIL=$((FAIL+1)); return 1
  fi
  say "  RESULT: KILLED (rc=$rc, stage guardrails, and the guard names itself)"
  PASS=$((PASS+1))

  # RESTORED: undo the mutation inside the scratch repo and show the same command green again.
  ( cd "$d" && $GIT checkout -q -- . && $GIT clean -qfd ) || true
  local rout rrc=0
  rout="$(run_tier_b "$d")" || rrc=$?
  if printf '%s' "$rout" | grep -qF 'stage guardrails ok'; then
    say "  RESTORED: stage guardrails is GREEN again"
  else
    say "  RESTORED BUT STILL RED at stage guardrails (rc=$rrc)"
    printf '%s\n' "$rout" | tail -8 | sed 's/^/    | /'
    FAIL=$((FAIL+1))
  fi
}

# Arm 1 -- Phase 0 exit-gate box 38: a reintroduced JS_* symbol must fail Tier B.
# One JS_* call planted in a scratch .c file that had NONE, so the guard's per-file,
# baseline-relative count goes 0 -> 1. Nothing in this worktree is touched.
#
# THE SYMBOL IS BUILT BY CONCATENATION, exactly as guardrails.sh builds its own canaries, so the
# forbidden literals never appear in this file's source text and this script does not fail the
# guard it exists to prove. It is ALSO listed in guardrails.sh's SCAN_EXEMPT with a reason:
# either defence alone is a silent dependency (break the concatenation and the exemption still
# holds; drop the exemption and the concatenation still holds).
mutate_denylist() {
  local ctx="JS""Context" call="JS_""GetRuntime"
  printf 'void probe_js(%s *cx)\n{\n    %s(cx);\n}\n' "$ctx" "$call" >> "$1/src/probe.c"
}

# Arm 2 -- Phase 0 exit-gate box 39: a branch touching goldens/ with no approved re-bless must
# fail Tier B. ONE BYTE changed in the SCRATCH repo's golden. tools/rebless-approvals.txt was
# copied verbatim and approves only goldens/windows-x64/001/provenance.json, so this path is
# genuinely unapproved -- which also demonstrates the approval is PATH-EXACT, not per-directory.
mutate_goldens() {
  local f="$1/goldens/windows-x64/001/state.json"
  [ -f "$f" ] || return 1
  printf '{"scenario": "001", "value": 2}\n' > "$f"
}

if [ -z "$ONLY" ]; then control; fi

expect_red 1 "deny-list DATA: one JS_* call reintroduced in a file that had none" \
  "Phase 0 exit-gate box 38 -- a reintroduced JS_*/libgnustep-base symbol must fail TIER B" \
  mutate_denylist "reintroduces deny-listed symbols"

expect_red 2 "goldens DATA: a one-byte edit under goldens/ with no re-bless approval" \
  "Phase 0 exit-gate box 39 -- a branch touching goldens/ unapproved must fail TIER B" \
  mutate_goldens "is under a protected golden path and is changed"

# ------------------------------------------------------------------------------------------------
# THIS WORKTREE MUST BE UNHARMED. Asserted, not hoped for: the two failure modes this script is
# shaped around (oo-dto's disabled predicate, oo-qd6's unapproved golden stub) were both invisible
# until someone diffed the tree by hand.
# ------------------------------------------------------------------------------------------------
hr; say "TREE CHECK: this worktree must be clean and guardrails-green after the proof"
DIRTY="$(git status --porcelain)"
if [ -n "$DIRTY" ]; then
  say "  DIRTY -- the proof modified the worktree, which it must never do:"
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  FAIL=$((FAIL+1))
else
  say "  git status --porcelain is empty"
  PASS=$((PASS+1))
fi
GRC=0
GOUT="$(bash "$HERE/guardrails.sh" 2>&1)" || GRC=$?
if [ "$GRC" -eq 0 ]; then
  say "  tools/guardrails.sh is GREEN on this worktree (rc=0)"
  PASS=$((PASS+1))
else
  say "  tools/guardrails.sh is RED on this worktree (rc=$GRC):"
  printf '%s\n' "$GOUT" | tail -10 | sed 's/^/    /'
  FAIL=$((FAIL+1))
fi

hr
printf 'tier-b-guardrails-proof: %d check(s) passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
[ "$PASS" -gt 0 ] || { printf 'tier-b-guardrails-proof: nothing ran; that is not a pass\n' >&2; exit 1; }
exit 0
