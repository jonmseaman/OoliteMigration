#!/usr/bin/env bash
# Exercise gc.sh's worktree-destroying paths in THROWAWAY repos built by gc-scratch-repo.sh.
# Never run gc.sh against a real repo: it removes worktrees and branches, and both defects this
# file pins (oo-ymmj, oo-y8fa) destroyed work that was not on main.
#
#   gc-safety.test.sh [gc.sh to test] [scenario...]
#
# Scenarios (default: all four):
#   rescue   a MERGED+CLOSED bead whose worktree holds an uncommitted leftover.txt must NOT lose it
#            (oo-y8fa). The content must be recoverable from the bead branch afterwards.
#   cleanup  a MERGED+CLOSED bead with a CLEAN worktree must still have worktree AND branch removed.
#            Without this, "protect the data by never cleaning" would pass `rescue` and be worthless.
#   live     a 0-commit worktree of an in_progress bead is KEPT with its files (oo-ymmj).
#   locked   a 0-commit worktree `git worktree remove` cannot remove is KEPT intact (oo-ymmj).
#   lockedmerged  a merged+closed+CLEAN worktree gc tries to remove but cannot (busy) is REFUSED
#            with rc=1 and nothing deleted - never rm -rf'd (oo-ymmj).
#   goalcheck  goal-check.sh's filter over gc --check discriminates (oo-0aw6): a routine
#            merged-and-cleaned pass stays quiet, while an at-risk bead's id REACHES the operator.
# Exit 0 = every selected scenario passed; 1 = at least one failed.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gc="${1:-$here/../gc.sh}"
[ -f "$gc" ] || { echo "gc-safety: no gc.sh at $gc" >&2; exit 2; }
gc="$(cd "$(dirname "$gc")" && pwd)/$(basename "$gc")"
shift 2>/dev/null || true
scenarios=("$@"); [ ${#scenarios[@]} -eq 0 ] && scenarios=(rescue cleanup mixed live locked lockedmerged goalcheck)
tmproot="${LOCALAPPDATA:-${TMPDIR:-/tmp}}"
case "$tmproot" in *\\*) tmproot="$(cygpath -u "$tmproot" 2>/dev/null || echo "$tmproot")";; esac
[ -d "$tmproot/Temp" ] && tmproot="$tmproot/Temp"
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1" >&2; fails=$((fails+1)); }
# build <scenario-spec>... -> prints the scratch repo dir
build() { local d; d="$(mktemp -d "$tmproot/gcsafe.XXXXXX")"; "$here/gc-scratch-repo.sh" "$d" "$gc" "$@" >/dev/null; echo "$d"; }
run_gc() { # run_gc <repo>; prints gc output, returns gc's rc
  ( cd "$1" && PATH="$1/stub:$PATH" bash scripts/gc.sh 2>&1 ); }

for s in "${scenarios[@]}"; do
  case "$s" in
  rescue)
    d="$(build mergeddirty:oo-rescue)"
    f="$d/.worktrees/oo-rescue/leftover-oo-rescue.txt"
    # VACUITY GUARD: the subject must exist before gc, or "it survived" is meaningless.
    if [ ! -f "$f" ] || [ "$(cat "$f")" != "precious uncommitted work" ]; then
      fail "rescue: harness did not create the uncommitted leftover"; continue
    fi
    out="$(run_gc "$d")"; rc=$?
    # POSITIVE post-condition: the exact content is readable from the bead branch afterwards.
    got="$(git -C "$d" show "bead/oo-rescue:leftover-oo-rescue.txt" 2>/dev/null || true)"
    if [ "$got" = "precious uncommitted work" ]; then
      pass "rescue: leftover harvested onto bead/oo-rescue (rc=$rc)"
    else
      fail "rescue: content LOST - bead/oo-rescue:leftover-oo-rescue.txt is '$got'"
      printf '%s\n' "$out" | sed 's/^/  gc| /' >&2
    fi
    [ $rc -ne 0 ] && pass "rescue: gc reported rc=$rc" || fail "rescue: gc exited 0 after leaving unmerged work"
    [ -d "$d/.worktrees/oo-rescue" ] && pass "rescue: worktree kept" || fail "rescue: worktree destroyed"
    ;;
  cleanup)
    d="$(build merged:oo-clean)"
    [ -d "$d/.worktrees/oo-clean" ] || { fail "cleanup: harness made no worktree"; continue; }
    git -C "$d" show-ref --verify --quiet refs/heads/bead/oo-clean || { fail "cleanup: harness made no branch"; continue; }
    out="$(run_gc "$d")"; rc=$?
    # POSITIVE post-condition: both really gone. A gc that never cleans must fail here.
    if [ -d "$d/.worktrees/oo-clean" ]; then fail "cleanup: clean merged worktree still present"; printf '%s\n' "$out" | sed 's/^/  gc| /' >&2
    else pass "cleanup: clean merged worktree removed"; fi
    if git -C "$d" show-ref --verify --quiet refs/heads/bead/oo-clean; then fail "cleanup: branch bead/oo-clean still present"
    else pass "cleanup: branch bead/oo-clean removed"; fi
    [ $rc -eq 0 ] && pass "cleanup: gc rc=0" || fail "cleanup: gc rc=$rc on a legitimate clean-up"
    ;;
  live)
    d="$(build live:oo-live)"
    [ -f "$d/.worktrees/oo-live/WORKER_FILE" ] || { fail "live: harness made no worker file"; continue; }
    run_gc "$d" >/dev/null
    if [ -f "$d/.worktrees/oo-live/WORKER_FILE" ]; then pass "live: 0-commit worktree kept with its files"
    else fail "live: live worker's worktree destroyed"; fi
    ;;
  locked)
    # A locked 0-COMMIT worktree: gc must not reach removal at all (the not-started path keeps it).
    d="$(build locked:oo-lock)"
    [ -f "$d/.worktrees/oo-lock/WORKER_FILE" ] || { fail "locked: harness made no worker file"; continue; }
    run_gc "$d" >/dev/null
    [ -f "$d/.worktrees/oo-lock/WORKER_FILE" ] && pass "locked: busy 0-commit worktree left intact" || fail "locked: busy worktree destroyed"
    git -C "$d" show-ref --verify --quiet refs/heads/bead/oo-lock && pass "locked: branch kept" || fail "locked: branch deleted"
    ;;
  lockedmerged)
    # The refusal path proper: merged+closed+clean, so gc DOES try to remove - but the worktree is
    # busy. It must be REPORTED and left alone, never rm -rf'd (oo-ymmj), with rc=1.
    d="$(build mergedlocked:oo-lm)"
    [ -f "$d/.worktrees/oo-lm/merged-oo-lm.txt" ] || { fail "lockedmerged: harness made no worktree"; continue; }
    out="$(run_gc "$d")"; rc=$?
    [ -f "$d/.worktrees/oo-lm/merged-oo-lm.txt" ] && pass "lockedmerged: busy worktree left intact" || fail "lockedmerged: busy worktree destroyed"
    git -C "$d" show-ref --verify --quiet refs/heads/bead/oo-lm && pass "lockedmerged: branch kept" || fail "lockedmerged: branch deleted despite failed removal"
    printf '%s\n' "$out" | grep -q 'REFUSING to force-remove worktree oo-lm' && pass "lockedmerged: refusal reported" || fail "lockedmerged: no refusal message"
    [ $rc -eq 1 ] && pass "lockedmerged: gc rc=1" || { fail "lockedmerged: gc rc=$rc, expected 1"; printf '%s\n' "$out" | sed 's/^/  gc| /' >&2; }
    ;;
  mixed)
    # Both merged scenarios in ONE repo: the realistic gc run, where a rescue and a legitimate
    # cleanup are decided in the same pass. Also pins the harness bug where two merged: scenarios
    # wrote the same file, so the second branch silently never advanced past main.
    d="$(build mergeddirty:oo-mx1 merged:oo-mx2)"
    f="$d/.worktrees/oo-mx1/leftover-oo-mx1.txt"
    [ -f "$f" ] || { fail "mixed: harness made no leftover"; continue; }
    [ "$(git -C "$d" rev-list --count main..bead/oo-mx2 2>/dev/null || echo 0)" -eq 0 ] \
      || { fail "mixed: bead/oo-mx2 was not actually merged into main"; continue; }
    git -C "$d" merge-base --is-ancestor bead/oo-mx2 main || { fail "mixed: bead/oo-mx2 is not an ancestor of main"; continue; }
    out="$(run_gc "$d")"; rc=$?
    [ "$(git -C "$d" show bead/oo-mx1:leftover-oo-mx1.txt 2>/dev/null)" = "precious uncommitted work" ] \
      && pass "mixed: dirty merged bead rescued" || { fail "mixed: dirty merged bead's work LOST"; printf '%s\n' "$out" | sed 's/^/  gc| /' >&2; }
    [ -d "$d/.worktrees/oo-mx1" ] && pass "mixed: rescued worktree kept" || fail "mixed: rescued worktree destroyed"
    [ -d "$d/.worktrees/oo-mx2" ] && { fail "mixed: clean merged worktree NOT cleaned"; printf '%s\n' "$out" | sed 's/^/  gc| /' >&2; } || pass "mixed: clean merged worktree removed"
    git -C "$d" show-ref --verify --quiet refs/heads/bead/oo-mx2 && fail "mixed: clean merged branch NOT removed" || pass "mixed: clean merged branch removed"
    [ $rc -eq 1 ] && pass "mixed: gc rc=1 (work at risk reported)" || fail "mixed: gc rc=$rc, expected 1"
    ;;
  goalcheck)
    # oo-0aw6: goal-check.sh filters gc --check's output. The routine "is merged into" line must
    # stay filtered (it fires on every clean run), but the at-risk line must reach the operator
    # NAMING THE BEAD. Two throwaway repos, one per direction.
    # (a) ROUTINE: merged+closed+CLEAN -> gc --check rc=0, goal-check rc=0 and says nothing new.
    dq="$(build merged:oo-gcq)"
    [ -f "$dq/scripts/goal-check.sh" ] || { fail "goalcheck: harness did not install goal-check.sh"; continue; }
    [ -d "$dq/.worktrees/oo-gcq" ] || { fail "goalcheck: harness made no worktree for oo-gcq"; continue; }
    outq="$( cd "$dq" && PATH="$dq/stub:$PATH" bash scripts/goal-check.sh 0 2>&1 )"; rcq=$?
    if [ $rcq -eq 0 ] && ! printf '%s\n' "$outq" | grep -q '^gc:'; then
      pass "goalcheck: routine merged+clean pass stays quiet (rc=0, no gc: noise)"
    else
      fail "goalcheck: routine pass was not quiet (rc=$rcq)"; printf '%s\n' "$outq" | sed 's/^/  goal| /' >&2
    fi
    # (b) AT RISK: merged+closed but the worktree still holds uncommitted work. goal-check must
    # exit 1 AND name oo-gcr. Asserting the POSITIVE: the id appears in the operator-visible output.
    dr="$(build mergeddirty:oo-gcr)"
    [ -f "$dr/.worktrees/oo-gcr/leftover-oo-gcr.txt" ] || { fail "goalcheck: harness made no leftover for oo-gcr"; continue; }
    outr="$( cd "$dr" && PATH="$dr/stub:$PATH" bash scripts/goal-check.sh 0 2>&1 )"; rcr=$?
    if printf '%s\n' "$outr" | grep -q 'oo-gcr'; then
      pass "goalcheck: at-risk bead oo-gcr is named in goal-check output (rc=$rcr)"
    else
      fail "goalcheck: at-risk output never names oo-gcr"; printf '%s\n' "$outr" | sed 's/^/  goal| /' >&2
    fi
    printf '%s\n' "$outr" | grep -q 'is merged but its worktree still holds uncommitted work' \
      && pass "goalcheck: the work-at-risk line survived the filter" \
      || fail "goalcheck: the work-at-risk line was filtered out"
    # The filter must still WORK: the routine line must not come back as noise.
    printf '%s\n' "$outr" | grep -q 'is merged into' \
      && fail "goalcheck: routine 'is merged into' noise is no longer filtered" \
      || pass "goalcheck: routine 'is merged into' line still filtered"
    [ $rcr -eq 1 ] && pass "goalcheck: goal-check rc=1 with work at risk" || fail "goalcheck: goal-check rc=$rcr, expected 1"
    ;;
  *) echo "gc-safety: unknown scenario $s" >&2; exit 2;;
  esac
done
[ $fails -eq 0 ] && { echo "gc-safety: all checks passed"; exit 0; }
echo "gc-safety: $fails check(s) failed" >&2; exit 1
