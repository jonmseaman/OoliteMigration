#!/usr/bin/env bash
#
# tools/merge-queue-acceptance.sh -- the STORED ACCEPTANCE lines for bead oo-pmg, as one script per
# check, so accept.sh can replay each of them individually and cheaply on a fresh merge of main.
#
#     bash tools/merge-queue-acceptance.sh <check>
#
# Every check is offline, needs no build and no game, and touches nothing outside
# $LOCALAPPDATA/Temp. The expensive proof (12 selftest scenarios, 12 mutants) is split across
# checks so no single acceptance line runs for many minutes.

set -u -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/.."

fail() { printf 'oo-pmg acceptance: FAIL (%s): %s\n' "${CHECK:-?}" "$*" >&2; exit 1; }
pass() { printf 'oo-pmg acceptance: PASS (%s): %s\n' "${CHECK:-?}" "$*"; }

CHECK="${1:?usage: merge-queue-acceptance.sh <check>}"

# scan_entries <file> -- the file's code, with comment-only lines removed. A gate that greps a
# WHOLE FILE for a forbidden word is failed by its own documentation; scan entries, not comments.
scan_entries() { sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1"; }

case "$CHECK" in

# ------------------------------------------------------------------------------------------------
files)
  for f in tools/merge-queue.sh tools/merge-queue-selftest tools/merge-queue-mutants.sh docs/infra/merge-queue.md; do
    [ -f "$f" ] || fail "$f is missing"
  done
  # CLAUDE.md's file-mode rule: merge-queue-selftest is invoked as a BARE PROGRAM by this script's
  # sibling checks, so it must be 100755 with a shebang. Assert on the INDEX, never with test -x:
  # MSYS on NTFS reports rwx for every file and is blind to the defect.
  m="$(git ls-files -s tools/merge-queue-selftest | awk '{print $1}')"
  [ "$m" = 100755 ] || fail "tools/merge-queue-selftest is mode $m in the index, must be 100755 (it is invoked as a bare program)"
  head -1 tools/merge-queue-selftest | grep -q '^#!' || fail "tools/merge-queue-selftest has no shebang"
  for f in tools/merge-queue.sh tools/merge-queue-mutants.sh; do
    m="$(git ls-files -s "$f" | awk '{print $1}')"
    [ "$m" = 100644 ] || fail "$f is mode $m; it is always invoked through bash, so it must be 100644"
  done
  pass "4 files present, modes agree with the index"
  ;;

# ------------------------------------------------------------------------------------------------
composes)
  # The queue must INVOKE tier-c.sh, not reimplement it, and must not take the desktop/gui lock.
  E="$(scan_entries tools/merge-queue.sh)"
  printf '%s\n' "$E" | grep -q 'GATE="${OO_MQ_GATE:-tools/tier-c.sh}"' \
    || fail "the default gate is not tools/tier-c.sh"
  # Scan for an INVOCATION, not a mention: the deadlock refusal message necessarily names
  # tools/gui-lock, and a guard that failed on its own error text would be unmaintainable. The
  # pattern is "the tool in command position", i.e. at the start of a statement or behind a run
  # prefix -- which is exactly how tools/check-desktop-lock.sh defines a launcher.
  for forbidden in 'gui-lock' 'desktop_lock\.py' 'oolite\.exe' 'build-windows\.sh' 'corpus\.sh' 'pytest'; do
    if printf '%s\n' "$E" | grep -qE "(^|[;&|]|\\$\(|\bexec |\bbash |\btimeout [0-9]+ )[[:space:]]*[\"'\$A-Za-z_/.]*${forbidden}"; then
      fail "the queue's CODE INVOKES '$forbidden'; it must compose with tier-c.sh, not duplicate a stage or take the desktop lock (that is how a queue deadlocks against its own gate)"
    fi
  done
  # And the sequential guarantee must be enforced, not merely documented.
  printf '%s\n' "$E" | grep -q '\[ "\$JOBS" = 1 \] || die' \
    || fail "--jobs is not REFUSED above 1; concurrent gates would deadlock on tier-c's gui-lock"
  pass "the gate defaults to tools/tier-c.sh, the queue's code takes no desktop lock, and --jobs>1 is refused"
  ;;

# ------------------------------------------------------------------------------------------------
push-off)
  # The standing rule: nothing pushes. Prove the DEFAULT from the code, and prove all three
  # conditions exist. The behavioural proof is scenario S10, against a bare repo in the temp dir.
  E="$(scan_entries tools/merge-queue.sh)"
  printf '%s\n' "$E" | grep -qE '(^|[[:space:]])PUSH=0([[:space:]]|;|$)' || fail "PUSH does not default to 0"
  printf '%s\n' "$E" | grep -q 'OO_MQ_PUSH_CONFIRM' || fail "there is no confirmation variable; --push alone would push"
  printf '%s\n' "$E" | grep -q 'OO_MQ_ALLOW_REMOTE_HOST' || fail "there is no forge guard"
  n="$(printf '%s\n' "$E" | grep -c 'git -C "\$REPO" push')"
  [ "$n" = 1 ] || fail "the code contains $n push call sites; there must be exactly ONE, inside the triple guard"
  # ADR-0017 step 7's mirror is the SECOND network write, and it gets the same treatment: exactly
  # one call site, and it must be a `git subtree push` at the documented prefix/remote/branch.
  m="$(printf '%s\n' "$E" | grep -c 'git -C "\$REPO" subtree push')"
  [ "$m" = 1 ] || fail "the code contains $m subtree-push call sites; there must be exactly ONE"
  printf '%s\n' "$E" | grep -q 'SUBTREE_PREFIX="${OO_MQ_SUBTREE_PREFIX:-upstream/oolite}"' \
    || fail "the subtree prefix does not default to upstream/oolite (ADR-0017)"
  printf '%s\n' "$E" | grep -q 'SUBTREE_REMOTE="${OO_MQ_SUBTREE_REMOTE:-fork}"' \
    || fail "the mirror remote does not default to 'fork' (ADR-0017)"
  printf '%s\n' "$E" | grep -q 'SUBTREE_BRANCH="${OO_MQ_SUBTREE_BRANCH:-migration}"' \
    || fail "the mirror branch does not default to 'migration' (ADR-0017)"
  # The mirror must be INSIDE the push guard: its only invocation is dominated by a successful push.
  printf '%s\n' "$E" | grep -q '\[ "\$PUSHED" = 1 \] && mirror_subtree' \
    || fail "mirror_subtree is not gated on a SUCCESSFUL push; a fork mirrored from a tree that was never pushed is the drift ADR-0017 exists to stop"
  # The mirror carries its OWN forge guard, because fork and origin are different URLs.
  printf '%s\n' "$E" | grep -q 'SUBTREE REFUSED' \
    || fail "the mirror has no forge refusal; a guard that only vets \$REMOTE lets the mirror reach a real forge"
  # The single push must be dominated by the green verdict AND the confirmation.
  printf '%s\n' "$E" | grep -q 'if \[ "\$VERDICT" = green \] && \[ "\$PUSH" = 1 \]' \
    || fail "the push is not gated on a GREEN verdict"
  pass "push and the ADR-0017 subtree mirror are OFF by default, have one call site each, and both need --push + OO_MQ_PUSH_CONFIRM + a non-forge remote"
  ;;

# ------------------------------------------------------------------------------------------------
# The behavioural proof, split so no line runs for many minutes. Each delegates to the selftest,
# which builds throwaway repos under $LOCALAPPDATA/Temp and asserts POSITIVE evidence: gate
# invocation counts, base SHAs before and after, and ancestry of every branch.
green|bisect|multi|flake|policy|mirror)
  case "$CHECK" in
    green)  SCEN="S1 S2 S3 S4" ;;   # fast-forward, dry-run inert, empty batch, attestation
    bisect) SCEN="S5" ;;            # the headline: 8 branches, 1 culprit
    multi)  SCEN="S6 S7" ;;         # two culprits; an interaction
    flake)  SCEN="S8 S9" ;;         # a flake and a poisoned base: INCONCLUSIVE, nobody blamed
    policy) SCEN="S10 S11 S12" ;;   # push, the deadlock guard, a conflicting branch
    mirror) SCEN="S13" ;;           # ADR-0017 step 7: origin AND fork/migration match the tree
  esac
  OUT="$(bash tools/merge-queue-selftest $SCEN 2>&1)"; RC=$?
  printf '%s\n' "$OUT" | tail -20
  [ "$RC" -eq 0 ] || fail "the selftest was RED for $SCEN"
  # ANTI-VACUITY: rc=0 is also what a selftest that ran nothing returns.
  got="$(printf '%s\n' "$OUT" | grep -oE '^merge-queue-selftest: [0-9]+ scenario' | grep -oE '[0-9]+')"
  want="$(printf '%s' "$SCEN" | wc -w)"
  [ "${got:-0}" = "$want" ] || fail "the selftest ran ${got:-0} scenario(s), expected $want"
  asserts="$(printf '%s\n' "$OUT" | grep -c '^    ok ')"
  [ "${asserts:-0}" -ge 10 ] || fail "only ${asserts:-0} assertion(s) were made; a green from a silent run proves nothing"
  pass "$want scenario(s), $asserts positive assertion(s)"
  ;;

# ------------------------------------------------------------------------------------------------
# The mutants. For every property the queue defends, one mutant corrupts the DATA and one weakens
# the CHECKER; each must turn the selftest RED *naming the defect*.
mutants-ff|mutants-bisect|mutants-flake|mutants-admit|mutants-mirror)
  case "$CHECK" in
    mutants-ff)     MUT="M1 M2 M12" ;;
    mutants-bisect) MUT="M3 M4" ;;
    mutants-flake)  MUT="M5 M6 M7 M8" ;;
    mutants-admit)  MUT="M9 M10 M11" ;;
    mutants-mirror) MUT="M13 M14 M15" ;;
  esac
  OUT="$(bash tools/merge-queue-mutants.sh $MUT 2>&1)"; RC=$?
  printf '%s\n' "$OUT" | grep -E '^(==|    ok|    FAIL|merge-queue-mutants:)'
  [ "$RC" -eq 0 ] || fail "a mutant ESCAPED: $MUT"
  caught="$(printf '%s\n' "$OUT" | grep -c '^    ok ')"
  want="$(printf '%s' "$MUT" | wc -w)"
  [ "${caught:-0}" = "$want" ] || fail "only ${caught:-0} of $want mutant(s) were caught"
  pass "$want planted defect(s), $caught caught, each naming the failure"
  ;;

# ------------------------------------------------------------------------------------------------
design)
  D=docs/infra/merge-queue.md
  for s in '1327' 'ceil(log2' 'INCONCLUSIVE' 'gui-lock' 'OFF by default' 'attestation' \
           'git subtree push --prefix=upstream/oolite fork migration' 'ADR-0017'; do
    grep -q -- "$s" "$D" || fail "$D does not state '$s'"
  done
  # The measured cost table must agree with what the selftest actually observes. A document that
  # claims a bisection cost nobody measures is a claim, not a design note.
  grep -qE '^\| one culprit \(`f5`\) \| `f5` evicted, 7 merged \| 7 \|' "$D" \
    || fail "$D's cost table does not record the measured 7 gate invocations for the one-culprit batch"
  pass "the design note states the arithmetic, the lock analysis, the flake policy and the push default"
  ;;

*) fail "unknown check '$CHECK'" ;;
esac
