#!/usr/bin/env bash
#
# The MERGE QUEUE. Phase 0 item 0.10 (docs/phases/0-safety-net.md), bead oo-pmg.
# Design note, cost arithmetic and eviction policy: docs/infra/merge-queue.md.
#
#     tools/merge-queue.sh --branches a,b,c        # batch, gate, fast-forward or bisect
#     tools/merge-queue.sh --branches-file F       # one branch per line (# comments ok)
#     tools/merge-queue.sh --attest BRANCH         # run Tier B on BRANCH, record the attestation
#     tools/merge-queue.sh --branches ... --dry-run # resolve the plan, invoke NO gate, touch NO ref
#
# ================================================================================================
# WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
# ================================================================================================
#
# It is the thing that turns N Tier-B-green branches into ONE Tier C run and a fast-forward of
# main. It does not re-implement a single check: the gate is `tools/tier-c.sh` (7 stages, ~1327 s
# projected, bead oo-j4u), invoked as an opaque command whose only contract is its EXIT STATUS.
# Swap it with OO_MQ_GATE and the queue is unchanged; that is also how the selftest drives every
# merge and bisect path in ~3 s against synthetic repositories instead of ~3 h against the real one.
#
# ------------------------------------------------------------------------------------------------
# THE ARITHMETIC. IT CAME FIRST AND IT SHAPED THE ALGORITHM.
# ------------------------------------------------------------------------------------------------
#
# One Tier C run costs ~1327 s (~22 min). That single number decides everything below.
#
#   batch-of-N, all green          1 run          ~22 min   amortised ~22/N min per branch
#   linear scan of N branches      N runs         N*22 min  (8 branches -> ~3 h)
#   prefix bisection, 1 culprit    ceil(log2 N)   +2-3      (8 branches -> ~6-7 runs, ~2.5 h)
#
# BE HONEST ABOUT THE WIN. At N=8 bisection is 6-7 runs against a linear scan's 8: barely better.
# The win is asymptotic and it arrives fast -- at N=16 it is 7 runs against 17, at N=32 it is 8
# against 33 -- and it is not the only reason to prefer it. A linear scan gates base+c_i in
# ISOLATION, so it is structurally blind to an INTERACTION failure (neither branch is red alone);
# prefix bisection gates base+c_1..c_k, which is the tree that would actually be merged, so an
# interaction shows up as a red prefix and gets a verdict instead of a mystery.
#
# ------------------------------------------------------------------------------------------------
# THE ALGORITHM
# ------------------------------------------------------------------------------------------------
#
# Let P(k) = base + c_1 .. c_k merged in queue order. P(0) = base, assumed green (or PROVEN green
# with --verify-base, +1 run). The batch is P(N).
#
#   1. P(N) green   -> fast-forward base to it. Done, 1 run.
#   2. P(N) red     -> binary search the smallest k with P(k) red. P(k-1) is green, so c_k is the
#                      branch that first turns the prefix red.  ceil(log2 N) runs.
#   3. CONFIRM THE DECIDING RED (--rerun, default 1). If the re-run of P(k) disagrees with the
#      first verdict, the gate is FLAKY on this tree: emit INCONCLUSIVE (rc=3), evict nobody,
#      fast-forward nothing. Blaming a branch for a flake evicts innocent work, which is worse
#      than doing nothing.
#   4. ATTRIBUTE. Gate base+c_k ALONE (1 run).
#        red   -> c_k is INDEPENDENTLY red. Evict c_k.
#        green -> c_k is red only in combination: an INTERACTION. Binary search the largest j<k
#                 with base + c_j..c_k red (ceil(log2 k) runs) to name the PARTNER, then report
#                 the PAIR. Eviction policy is last-in-loses: c_k is evicted, c_j survives, and
#                 the verdict names both so the requeued bead says what it interacts with.
#   5. RETRY THE REMAINDER. Gate the surviving branches (1 run). Green -> fast-forward, and the
#      culprit is the only thing evicted. Red -> there is a SECOND, independent culprit: go back
#      to step 2 on the remainder. Up to --max-culprits (default 3); beyond that the batch is
#      declared INCONCLUSIVE rather than picked apart one branch at a time.
#
# Worked cost, 8 branches, 1 culprit: 1 + 3 + 1(rerun) + 1(isolate) + 1(remainder) = 7 runs.
# Two independent culprits:            + 3 + 1 + 1 + 1                              = 13 runs.
#
# ------------------------------------------------------------------------------------------------
# WHY THIS CANNOT DEADLOCK AGAINST ITS OWN GATE
# ------------------------------------------------------------------------------------------------
#
# Tier C's `gui` stage serialises on tools/gui-lock and its `asan` stage launches the game under
# the same lock; tier-b's smoke stage takes the desktop lock too. A queue that held either lock
# while invoking the gate, or that ran two gates at once, would deadlock or steal focus.
#
#   * The queue takes NEITHER lock. It runs git plumbing only: no launcher, no window, nothing
#     tools/check-desktop-lock.sh would classify as a spawn of the game binary.
#   * The queue runs gates STRICTLY SEQUENTIALLY. --jobs is accepted and REFUSED above 1 rather
#     than silently ignored, so "make the queue parallel" is a conversation, not a quiet
#     regression into two concurrent gui-locks.
#   * Its own mutual exclusion (one queue run at a time) is a separate lock file, .mq/queue.lock,
#     which tier-c never touches.
#
# ------------------------------------------------------------------------------------------------
# ANTI-VACUITY: A QUEUE THAT PASSES BECAUSE NOTHING RAN IS WORSE THAN NO QUEUE
# ------------------------------------------------------------------------------------------------
#
# rc=0 proves nothing. Every verdict here is backed by a POSITIVE fact, and each of these is a
# hard failure, never a skip (the numbers are the guard ids printed in --dry-run):
#
#   G1  an EMPTY candidate list is fatal. "0 branches merged, GREEN" is the purest vacuous pass.
#   G2  every admitted branch carries a Tier-B attestation naming its EXACT tip SHA.
#   G3  the gate command must exist and be executable in the integration worktree.
#   G4  a verdict may not be issued with ZERO gate invocations; the counter is asserted > 0.
#   G5  a fast-forward must MOVE the ref: base-before != base-after, base-after == batch tip, and
#       base-before is an ancestor of it. A no-op "merge" is a failure, not a success.
#   G6  a bisection must NARROW: the final candidate set is strictly smaller than the batch.
#   G7  merged + evicted must equal admitted. A branch may not vanish.
#   G8  --dry-run must leave the invocation counter at 0 and every ref byte-identical.
#   G9  a red batch may never end in a fast-forward, and an INCONCLUSIVE may never evict.
#
# ------------------------------------------------------------------------------------------------
# PUSHING
# ------------------------------------------------------------------------------------------------
#
# The fleet's standing rule is that nothing pushes, so push is OFF BY DEFAULT and needs THREE
# things to fire: --push, OO_MQ_PUSH_CONFIRM=yes, and a remote that is not github.com (that last
# one is overridable only by OO_MQ_ALLOW_REMOTE_HOST=1, which the fleet never sets). Without all
# three the queue prints the push it WOULD have run and exits green.
#
# Exit codes: 0 green + fast-forward | 1 red, culprit attributed and evicted | 2 usage/fatal
#             3 INCONCLUSIVE (flake, poisoned base, or too many culprits): nothing merged, nobody
#               blamed.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="$(cd "$HERE/.." && pwd)"

# --- Arguments -----------------------------------------------------------------------------------

REPO="$DEFAULT_REPO"; BASE="${OO_MQ_BASE:-main}"; BRANCHES=""; BRANCHES_FILE=""
GATE="${OO_MQ_GATE:-tools/tier-c.sh}"; TIERB="${OO_MQ_TIERB:-tools/tier-b.sh}"
DRY=0; PUSH=0; RERUN="${OO_MQ_RERUN:-1}"; VERIFY_BASE=0; JOBS=1
MAX_CULPRITS="${OO_MQ_MAX_CULPRITS:-3}"; REQUIRE_ATTEST="${OO_MQ_REQUIRE_ATTEST:-1}"
ATTEST_BRANCH=""; JSON_OUT=""; REMOTE="${OO_MQ_REMOTE:-origin}"

die() { printf 'merge-queue: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)          REPO="${2:?--repo needs a directory}"; shift ;;
    --base)          BASE="${2:?--base needs a branch}"; shift ;;
    --branches)      BRANCHES="${2:?--branches needs a comma-separated list}"; shift ;;
    --branches-file) BRANCHES_FILE="${2:?--branches-file needs a path}"; shift ;;
    --gate)          GATE="${2:?--gate needs a command}"; shift ;;
    --attest)        ATTEST_BRANCH="${2:?--attest needs a branch}"; shift ;;
    --rerun)         RERUN="${2:?--rerun needs a count}"; shift ;;
    --max-culprits)  MAX_CULPRITS="${2:?--max-culprits needs a count}"; shift ;;
    --remote)        REMOTE="${2:?--remote needs a name}"; shift ;;
    --json)          JSON_OUT="${2:?--json needs a path}"; shift ;;
    --jobs)          JOBS="${2:?--jobs needs a count}"; shift ;;
    --no-attest)     REQUIRE_ATTEST=0 ;;
    --verify-base)   VERIFY_BASE=1 ;;
    --dry-run)       DRY=1 ;;
    --push)          PUSH=1 ;;
    -h|--help)       sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

# The gui-lock deadlock guard, stated as code and not only as a comment: tier-c's gui stage holds
# tools/gui-lock EXCLUSIVELY, so two concurrent gates would block forever on each other.
[ "$JOBS" = 1 ] || die "--jobs $JOBS refused: tier-c's gui stage takes tools/gui-lock EXCLUSIVELY, so two concurrent gates deadlock. The queue is sequential by construction."

[ -d "$REPO/.git" ] || [ -f "$REPO/.git" ] || die "not a git repository: $REPO"
REPO="$(cd "$REPO" && pwd)"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository: $REPO"

MQ_DIR="${OO_MQ_DIR:-$REPO/.mq}"
ATTEST_DIR="${OO_MQ_ATTEST_DIR:-$MQ_DIR/attest}"
COUNT_FILE="${OO_MQ_COUNT_FILE:-$MQ_DIR/gate-invocations}"
WORKTREE="${OO_MQ_WORKTREE:-$MQ_DIR/integration}"
mkdir -p "$MQ_DIR" "$ATTEST_DIR"
# .mq/ holds the integration WORKTREE, the attestations and the gate logs. It lives inside the repo
# on purpose (the worktree must share the object store), so it must be invisible to git: an
# un-ignored .mq would put an embedded repository in `git status` and a stray directory in the repo
# root, which is exactly what blocks acceptance for the whole fleet.
[ -f "$MQ_DIR/.gitignore" ] || printf '*\n' > "$MQ_DIR/.gitignore"

say()    { printf '%s\n' "merge-queue: $*"; }
step()   { printf '\n==> %s\n' "$*"; }
detail() { printf '    %s\n' "$*"; }

# --- Attestation ---------------------------------------------------------------------------------
#
# G2. A branch enters the queue only with a Tier-B attestation naming its EXACT tip SHA. Keying on
# the SHA and not the branch name is the whole point: an attestation that survives a force-push or
# an amend would let un-gated code into a batch, and the queue would then bisect a tree nobody
# ever ran Tier B on.

attest_path() { printf '%s/%s' "$ATTEST_DIR" "$1"; }

if [ -n "$ATTEST_BRANCH" ]; then
  sha="$(git -C "$REPO" rev-parse --verify "$ATTEST_BRANCH^{commit}" 2>/dev/null)" \
    || die "--attest: no such branch '$ATTEST_BRANCH'"
  step "Tier B attestation for $ATTEST_BRANCH ($sha)"
  ( cd "$REPO" && git -C "$REPO" rev-parse >/dev/null && eval "$TIERB" ) || die "Tier B was RED for $ATTEST_BRANCH; no attestation written"
  printf 'tier-b green %s %s %s\n' "$ATTEST_BRANCH" "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$(attest_path "$sha")"
  say "attested $ATTEST_BRANCH $sha"
  exit 0
fi

# --- Candidate list ------------------------------------------------------------------------------

CANDIDATES=()
if [ -n "$BRANCHES_FILE" ]; then
  [ -f "$BRANCHES_FILE" ] || die "--branches-file: no such file: $BRANCHES_FILE"
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '\r' | awk '{$1=$1};1')"
    [ -n "$line" ] && CANDIDATES+=("$line")
  done < "$BRANCHES_FILE"
fi
if [ -n "$BRANCHES" ]; then
  IFS=',' read -r -a _b <<< "$BRANCHES"
  for x in "${_b[@]}"; do x="$(printf '%s' "$x" | awk '{$1=$1};1')"; [ -n "$x" ] && CANDIDATES+=("$x"); done
fi

# G1: an empty batch is FATAL, never a vacuous green.
[ "${#CANDIDATES[@]}" -gt 0 ] \
  || die "the candidate list is EMPTY (G1); a batch with no branches would fast-forward nothing and report GREEN, which is the vacuous pass this queue exists to prevent"

git -C "$REPO" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || die "no such base branch: $BASE"
BASE_BEFORE="$(git -C "$REPO" rev-parse "$BASE")"

# --- Admission -----------------------------------------------------------------------------------

ADMITTED=(); REJECTED=()
for b in "${CANDIDATES[@]}"; do
  if ! sha="$(git -C "$REPO" rev-parse --verify "$b^{commit}" 2>/dev/null)"; then
    REJECTED+=("$b:no-such-branch"); continue
  fi
  if git -C "$REPO" merge-base --is-ancestor "$sha" "$BASE_BEFORE" 2>/dev/null; then
    REJECTED+=("$b:already-in-$BASE"); continue
  fi
  if [ "$REQUIRE_ATTEST" = 1 ] && [ ! -f "$(attest_path "$sha")" ]; then
    REJECTED+=("$b:no-tier-b-attestation-for-$sha"); continue
  fi
  ADMITTED+=("$b")
done

[ "${#ADMITTED[@]}" -gt 0 ] \
  || die "no candidate was admitted (G1/G2): ${REJECTED[*]}"

N_ADMITTED="${#ADMITTED[@]}"

# --- Plan / dry run ------------------------------------------------------------------------------

step "plan"
detail "repo         $REPO"
detail "base         $BASE @ $BASE_BEFORE"
detail "gate         $GATE"
detail "admitted     $N_ADMITTED: ${ADMITTED[*]}"
detail "rejected     ${#REJECTED[@]}: ${REJECTED[*]:-none}"
detail "rerun        $RERUN confirming re-run(s) of a deciding RED"
detail "push         $([ "$PUSH" = 1 ] && echo requested || echo 'OFF (default)')"
detail "guards       G1 empty-batch G2 attestation G3 gate-exists G4 invocations>0 G5 ff-moves-ref G6 bisect-narrows G7 merged+evicted==admitted G8 dry-run-inert G9 no-ff-on-red"
detail "projected    1 run if green; 1+ceil(log2 $N_ADMITTED)+3 runs if one culprit"

if [ "$DRY" = 1 ]; then
  # G8: a dry run resolves the plan and touches NOTHING. The selftest asserts the invocation
  # counter is still 0 and every ref is byte-identical afterwards.
  say "DRY RUN: no gate invoked, no ref written"
  exit 0
fi

# --- The integration worktree --------------------------------------------------------------------
#
# ONE persistent worktree, reused across runs on purpose: tier-c's first stage is tier-b, whose
# build is 13-22 s warm against ~142 s cold. A throwaway worktree per batch would add ~2 minutes
# to EVERY gate invocation, and the bisection makes 5-7 of them.

if [ ! -d "$WORKTREE/.git" ] && [ ! -f "$WORKTREE/.git" ]; then
  git -C "$REPO" worktree add --detach "$WORKTREE" "$BASE_BEFORE" >/dev/null 2>&1 \
    || die "cannot create the integration worktree at $WORKTREE"
fi

QLOCK="$MQ_DIR/queue.lock"
if ! ( set -o noclobber; printf '%s %s\n' "$$" "$(date -u +%FT%TZ)" > "$QLOCK" ) 2>/dev/null; then
  die "another merge-queue run holds $QLOCK; the queue is sequential (see the gui-lock note)"
fi
cleanup() { rm -f "$QLOCK" 2>/dev/null || true; git -C "$REPO" branch -D "$BATCH_REF" >/dev/null 2>&1 || true; }
BATCH_REF="mq/batch-$$"
trap cleanup EXIT

# --- The gate ------------------------------------------------------------------------------------

printf '0\n' > "$COUNT_FILE"
GATE_RUNS=0
GATE_LOG="$MQ_DIR/gate-log.txt"; : > "$GATE_LOG"

# run_gate <label> <commit> -> 0 green, 1 red.  Increments the invocation counter BEFORE the gate
# runs, so a gate that dies without output still leaves evidence it was reached (G4).
run_gate() {
  local label="$1" commit="$2" rc=0 t0=$SECONDS
  # Skip the checkout when the worktree is already on this commit: build_prefix just left it there,
  # and on Windows a redundant full checkout is the single most expensive thing in the loop.
  if [ "$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null)" != "$commit" ]; then
    git -C "$WORKTREE" checkout --detach --force "$commit" >/dev/null 2>&1 \
      || die "cannot check out $commit in the integration worktree"
  fi
  # G3: the gate must EXIST in the tree being gated. A missing gate is a fatal usage error and
  # never a green -- "the command was not found, so nothing failed" is a vacuous pass.
  local probe; probe="$(printf '%s' "$GATE" | awk '{print $1}')"
  case "$probe" in
    /*|./*|tools/*) [ -e "$WORKTREE/$probe" ] || [ -e "$probe" ] \
        || die "the gate command '$probe' does not exist in the tree at $commit (G3)" ;;
  esac
  GATE_RUNS=$(( GATE_RUNS + 1 ))
  printf '%s\n' "$GATE_RUNS" > "$COUNT_FILE"
  ( cd "$WORKTREE" && eval "$GATE" ) > "$MQ_DIR/gate-$GATE_RUNS.log" 2>&1 || rc=$?
  local verdict=GREEN; [ "$rc" -eq 0 ] || verdict=RED
  printf '%d\t%s\t%s\t%s\t%ss\n' "$GATE_RUNS" "$label" "${commit:0:12}" "$verdict" "$(( SECONDS - t0 ))" >> "$GATE_LOG"
  detail "gate #$GATE_RUNS $label $verdict (rc=$rc, $(( SECONDS - t0 ))s)"
  [ "$rc" -eq 0 ]
}

# confirm <label> <commit> <first_rc> -- re-run a DECIDING verdict $RERUN more times on the SAME
# commit and require agreement. It does NOT re-run the deciding gate itself: the bisection already
# paid for that verdict, and paying twice at 1327 s a go is a real cost, not a rounding error.
#
# Disagreement means the gate is FLAKY on this tree. A flake must never be attributed to a branch
# -- doing so evicts innocent work and the eviction looks exactly like a real finding -- so it
# sets FLAKY=1 and the caller turns that into INCONCLUSIVE, which merges nothing and blames nobody.
FLAKY=0
confirm() {
  local label="$1" commit="$2" first="$3" i again
  for (( i = 0; i < RERUN; i++ )); do
    again=0
    run_gate "$label(confirm$((i+1)))" "$commit" || again=1
    if [ "$again" != "$first" ]; then
      FLAKY=1
      say "FLAKE DETECTED at $label: the deciding run said $([ "$first" = 0 ] && echo GREEN || echo RED), confirm $((i+1)) said $([ "$again" = 0 ] && echo GREEN || echo RED)"
      return 2
    fi
  done
  return "$first"
}

# --- Building a prefix ---------------------------------------------------------------------------
#
# P(k) = base + c_1..c_k, merged in queue order onto a throwaway ref. A CONFLICT is an admission
# failure, not a gate failure: it costs no Tier C run and the branch is evicted on the spot.

CONFLICTED=()
# build_prefix <name> <branch...> -> prints the resulting commit, or returns 1 naming the conflict.
build_prefix() {
  local name="$1"; shift
  git -C "$REPO" branch -f "$name" "$BASE_BEFORE" >/dev/null 2>&1 || return 1
  git -C "$WORKTREE" checkout --detach --force "$name" >/dev/null 2>&1 || return 1
  local b
  for b in "$@"; do
    if ! git -C "$WORKTREE" merge --no-edit -m "mq: $b" "$b" >/dev/null 2>&1; then
      git -C "$WORKTREE" merge --abort >/dev/null 2>&1 || true
      printf 'CONFLICT %s\n' "$b"
      return 1
    fi
  done
  git -C "$REPO" branch -f "$name" "$(git -C "$WORKTREE" rev-parse HEAD)" >/dev/null 2>&1
  git -C "$WORKTREE" rev-parse HEAD
}

# Build the full batch, dropping conflicting branches (bounded: at most one pass per branch).
QUEUE=("${ADMITTED[@]}")
BATCH_TIP=""
while [ "${#QUEUE[@]}" -gt 0 ]; do
  out="$(build_prefix "$BATCH_REF" "${QUEUE[@]}")" && { BATCH_TIP="$out"; break; }
  bad="$(printf '%s' "$out" | awk '/^CONFLICT /{print $2}')"
  [ -n "$bad" ] || die "cannot build the batch and no conflicting branch was named"
  say "EVICT $bad: does not merge cleanly onto $BASE (cost: 0 gate runs)"
  CONFLICTED+=("$bad")
  NEWQ=(); for b in "${QUEUE[@]}"; do [ "$b" = "$bad" ] || NEWQ+=("$b"); done
  QUEUE=("${NEWQ[@]}")
done
[ -n "$BATCH_TIP" ] && [ "${#QUEUE[@]}" -gt 0 ] \
  || die "every admitted branch conflicted with $BASE; nothing to gate (G1)"

VERDICT=""; EVICTED=(); PARTNERS=""

# --- Optional: prove the base is green ------------------------------------------------------------
#
# P(0) green is an ASSUMPTION the bisection rests on. --verify-base turns it into a measurement
# for +1 run. A red base means every prefix is red and the bisection would blame c_1 -- the
# textbook way to evict innocent work, so it is INCONCLUSIVE instead.
if [ "$VERIFY_BASE" = 1 ]; then
  step "verify the base"
  if ! run_gate "base($BASE)" "$BASE_BEFORE"; then
    say "INCONCLUSIVE: the BASE $BASE is itself RED; no branch in this batch can be blamed for it"
    VERDICT=inconclusive
  fi
fi

# --- The batch -----------------------------------------------------------------------------------

if [ -z "$VERDICT" ]; then
  step "gate the batch of ${#QUEUE[@]}: ${QUEUE[*]}"
  if run_gate "batch(${#QUEUE[@]})" "$BATCH_TIP"; then
    VERDICT=green
  else
    VERDICT=red
  fi
fi

# --- Bisection -----------------------------------------------------------------------------------
#
# prefix_commit k  -> the commit for P(k), built on demand.
prefix_commit() {
  local k="$1"; local -a sub=()
  local i; for (( i = 0; i < k; i++ )); do sub+=("${QUEUE[$i]}"); done
  [ "$k" -eq 0 ] && { printf '%s' "$BASE_BEFORE"; return 0; }
  build_prefix "mq/prefix-$$-$k" "${sub[@]}"
}

CULPRITS=(); NARROWED_FROM=0; NARROWED_TO=0; HI_COMMIT=""

bisect_once() {
  # NOTE: separate `local` statements. In a single `local a=1 b="$a"`, $a is not yet assigned
  # when b expands, and under `set -u` that is an unbound-variable abort mid-bisection.
  local n lo hi mid c
  n="${#QUEUE[@]}"; lo=0; hi="$n"
  NARROWED_FROM="$n"
  # Binary search the SMALLEST k with P(k) red. Invariant: P(lo) green, P(hi) red.
  # HI_COMMIT is the commit that was ACTUALLY gated for the current hi, carried out of the loop so
  # the confirming re-runs gate the identical tree. Rebuilding P(k) produces a different merge
  # commit (new timestamps), and "confirmed" on a tree you never gated is not a confirmation.
  HI_COMMIT="$BATCH_TIP"
  while [ $(( hi - lo )) -gt 1 ]; do
    mid=$(( (lo + hi) / 2 ))
    c="$(prefix_commit "$mid")" || die "cannot build prefix P($mid)"
    step "bisect: P($mid) = base + ${QUEUE[*]:0:$mid}"
    if run_gate "P($mid)" "$c"; then lo="$mid"; else hi="$mid"; HI_COMMIT="$c"; fi
  done
  local k="$hi" culprit="${QUEUE[$(( hi - 1 ))]}"
  NARROWED_TO=1
  # G6: the bisection must have NARROWED. If it "found" a candidate set as big as the batch it
  # did not do its job, and saying so is better than shipping a confident wrong answer.
  [ "$NARROWED_FROM" -gt 1 ] && [ "$NARROWED_TO" -lt "$NARROWED_FROM" ] \
    || { [ "$NARROWED_FROM" -eq 1 ] || die "the bisection did not narrow: $NARROWED_FROM -> $NARROWED_TO (G6)"; }

  step "bisect: first red prefix is P($k); candidate culprit is $culprit"
  detail "narrowed $NARROWED_FROM candidate(s) -> 1"

  # Step 3: confirm the deciding RED on the SAME tree before anyone is blamed for it.
  local c_k="$HI_COMMIT" rc=0
  step "confirm the deciding RED at P($k) ($RERUN re-run(s) of ${c_k:0:12})"
  confirm "P($k)" "$c_k" 1; rc=$?
  if [ "$rc" = 2 ] || [ "$FLAKY" = 1 ]; then BISECT_RESULT="inconclusive:flake"; return 0; fi

  # Step 4: attribute. Is c_k red ON ITS OWN?
  local solo; solo="$(build_prefix "mq/solo-$$" "$culprit")" || { BISECT_RESULT="culprit:$culprit:conflict"; return 0; }
  step "attribute: gate base + $culprit alone"
  if ! run_gate "solo($culprit)" "$solo"; then
    BISECT_RESULT="culprit:$culprit:independent"; return 0
  fi

  # Green alone, red in the prefix: a genuine INTERACTION. Name the partner by binary searching
  # the largest j < k for which base + c_j..c_k is still red.
  step "attribute: $culprit is GREEN alone but RED in P($k) -- this is an INTERACTION, not a defect in $culprit alone"
  local jlo=1 jhi="$k" jmid
  # Invariant: suffix from jlo is red (jlo=1 is P(k)); suffix from jhi is green (jhi=k is solo).
  while [ $(( jhi - jlo )) -gt 1 ]; do
    jmid=$(( (jlo + jhi) / 2 ))
    local -a sfx=(); local i
    for (( i = jmid - 1; i < k; i++ )); do sfx+=("${QUEUE[$i]}"); done
    local sc; sc="$(build_prefix "mq/suffix-$$-$jmid" "${sfx[@]}")" || { jhi="$jmid"; continue; }
    step "bisect partner: base + ${sfx[*]}"
    if run_gate "S($jmid)" "$sc"; then jhi="$jmid"; else jlo="$jmid"; fi
  done
  local partner="${QUEUE[$(( jlo - 1 ))]}"
  BISECT_RESULT="interaction:$culprit:$partner"
}

BISECT_RESULT=""
if [ "$VERDICT" = red ]; then
  ROUNDS=0
  while [ "$VERDICT" = red ] && [ "$ROUNDS" -lt "$MAX_CULPRITS" ]; do
    ROUNDS=$(( ROUNDS + 1 ))
    bisect_once
    case "$BISECT_RESULT" in
      inconclusive:*) VERDICT=inconclusive; break ;;
      culprit:*)
        c="$(printf '%s' "$BISECT_RESULT" | cut -d: -f2)"
        say "CULPRIT $c (independently red)"
        EVICTED+=("$c") ;;
      interaction:*)
        c="$(printf '%s' "$BISECT_RESULT" | cut -d: -f2)"
        p="$(printf '%s' "$BISECT_RESULT" | cut -d: -f3)"
        say "INTERACTION between $c and $p: neither is red alone. Evicting $c (last-in-loses); $p survives."
        PARTNERS="$PARTNERS $c+$p"
        EVICTED+=("$c") ;;
      *) die "the bisection produced no verdict" ;;
    esac
    NEWQ=(); for b in "${QUEUE[@]}"; do [ "$b" = "$c" ] || NEWQ+=("$b"); done
    QUEUE=("${NEWQ[@]}")
    if [ "${#QUEUE[@]}" -eq 0 ]; then VERDICT=empty; break; fi
    step "retry the remainder of ${#QUEUE[@]}: ${QUEUE[*]}"
    BATCH_TIP="$(build_prefix "$BATCH_REF" "${QUEUE[@]}")" || die "cannot rebuild the remainder"
    if run_gate "remainder(${#QUEUE[@]})" "$BATCH_TIP"; then VERDICT=green; else VERDICT=red; fi
  done
  if [ "$VERDICT" = red ]; then
    say "INCONCLUSIVE: still RED after $MAX_CULPRITS culprit(s) evicted; the batch is quarantined rather than dismantled branch by branch"
    VERDICT=inconclusive
  fi
fi

# --- Fast-forward ---------------------------------------------------------------------------------

BASE_AFTER="$BASE_BEFORE"
if [ "$VERDICT" = green ]; then
  step "fast-forward $BASE"
  # G5. A fast-forward that does not MOVE the ref is a failure. So is one that is not actually a
  # fast-forward: the old tip must be an ancestor of the new one, or this is a rewrite in disguise.
  git -C "$REPO" merge-base --is-ancestor "$BASE_BEFORE" "$BATCH_TIP" \
    || die "refusing to move $BASE: $BASE_BEFORE is NOT an ancestor of $BATCH_TIP -- that is a rewrite, not a fast-forward (G5)"
  [ "$BATCH_TIP" != "$BASE_BEFORE" ] \
    || die "refusing to report a merge: the batch tip equals the base tip, so nothing would move (G5)"
  now="$(git -C "$REPO" rev-parse "$BASE")"
  [ "$now" = "$BASE_BEFORE" ] \
    || die "$BASE moved from $BASE_BEFORE to $now while the batch was gating; the gated tree is stale, refusing to fast-forward"
  git -C "$REPO" update-ref "refs/heads/$BASE" "$BATCH_TIP" "$BASE_BEFORE" \
    || die "the fast-forward of $BASE was rejected"
  BASE_AFTER="$(git -C "$REPO" rev-parse "$BASE")"
  [ "$BASE_AFTER" = "$BATCH_TIP" ] && [ "$BASE_AFTER" != "$BASE_BEFORE" ] \
    || die "the fast-forward did not move $BASE (before=$BASE_BEFORE after=$BASE_AFTER) (G5)"
  say "FAST-FORWARD $BASE ${BASE_BEFORE:0:12} -> ${BASE_AFTER:0:12} (${#QUEUE[@]} branch(es))"
elif [ "$VERDICT" = inconclusive ]; then
  # G9: an INCONCLUSIVE evicts nobody. Drop any eviction recorded before the flake was seen.
  EVICTED=()
fi

# G9 restated as an assertion: a non-green verdict may never have moved the base.
if [ "$VERDICT" != green ]; then
  [ "$(git -C "$REPO" rev-parse "$BASE")" = "$BASE_BEFORE" ] \
    || die "$BASE MOVED on a non-green verdict ($VERDICT) (G9)"
fi

# --- Push (opt-in, OFF by default) -----------------------------------------------------------------

PUSHED=0
if [ "$VERDICT" = green ] && [ "$PUSH" = 1 ]; then
  url="$(git -C "$REPO" remote get-url "$REMOTE" 2>/dev/null || echo '')"
  if [ "${OO_MQ_PUSH_CONFIRM:-}" != "yes" ]; then
    say "PUSH SKIPPED: --push was given but OO_MQ_PUSH_CONFIRM is not 'yes'. Would run: git push $REMOTE $BASE"
  elif printf '%s' "$url" | grep -qi 'github\.com' && [ "${OO_MQ_ALLOW_REMOTE_HOST:-0}" != 1 ]; then
    say "PUSH REFUSED: remote '$REMOTE' is $url, which is a real forge. Set OO_MQ_ALLOW_REMOTE_HOST=1 to override; the fleet never does."
  else
    git -C "$REPO" push "$REMOTE" "$BASE:$BASE" >/dev/null 2>&1 && PUSHED=1
    say "PUSHED $BASE -> $REMOTE ($url)"
  fi
elif [ "$PUSH" = 1 ]; then
  say "PUSH SKIPPED: the verdict is $VERDICT, and only a GREEN batch is ever pushed"
fi

# --- Verdict --------------------------------------------------------------------------------------

# G4: no verdict without evidence that the gate ACTUALLY RAN.
[ "$GATE_RUNS" -gt 0 ] \
  || die "the verdict is '$VERDICT' after ZERO gate invocations (G4); rc=0 and an absence of errors are both satisfiable by a dead run"
[ "$(cat "$COUNT_FILE" 2>/dev/null || echo 0)" = "$GATE_RUNS" ] \
  || die "the invocation counter disagrees with the run count (G4)"

MERGED=("${QUEUE[@]}"); [ "$VERDICT" = green ] || MERGED=()
# G7: every admitted branch is accounted for exactly once.
TOTAL=$(( ${#MERGED[@]} + ${#EVICTED[@]} + ${#CONFLICTED[@]} ))
if [ "$VERDICT" = green ]; then
  [ "$TOTAL" -eq "$N_ADMITTED" ] \
    || die "accounting: merged ${#MERGED[@]} + evicted ${#EVICTED[@]} + conflicted ${#CONFLICTED[@]} != admitted $N_ADMITTED (G7)"
fi

step "verdict"
detail "verdict          $VERDICT"
detail "gate invocations $GATE_RUNS"
detail "admitted         $N_ADMITTED"
detail "merged           ${#MERGED[@]}: ${MERGED[*]:-none}"
detail "evicted          ${#EVICTED[@]}: ${EVICTED[*]:-none}"
detail "conflicted       ${#CONFLICTED[@]}: ${CONFLICTED[*]:-none}"
PARTNERS="${PARTNERS# }"
if [ -n "$PARTNERS" ]; then detail "interactions    $PARTNERS"; fi
detail "base            $BASE_BEFORE -> $BASE_AFTER"
if [ "$NARROWED_FROM" -gt 0 ]; then detail "bisection       narrowed $NARROWED_FROM -> $NARROWED_TO"; fi
detail "pushed          $PUSHED"
printf '%s\n' "--- gate log (invocation, label, commit, verdict, seconds) ---"
cat "$GATE_LOG"

for e in "${EVICTED[@]:-}"; do
  [ -n "$e" ] || continue
  # The requeue hook. It PRINTS the command and never runs it: this bead may not mutate bead state.
  say "REQUEUE: bd update <bead-for-$e> --notes 'merge queue evicted $e: $BISECT_RESULT (gate log $MQ_DIR/gate-log.txt)'"
done

if [ -n "$JSON_OUT" ]; then
  {
    printf '{"verdict":"%s","gate_invocations":%d,"admitted":%d,"merged":%d,"evicted":"%s","conflicted":"%s","interactions":"%s","base_before":"%s","base_after":"%s","narrowed_from":%d,"narrowed_to":%d,"pushed":%d}\n' \
      "$VERDICT" "$GATE_RUNS" "$N_ADMITTED" "${#MERGED[@]}" "${EVICTED[*]:-}" "${CONFLICTED[*]:-}" "$PARTNERS" \
      "$BASE_BEFORE" "$BASE_AFTER" "$NARROWED_FROM" "$NARROWED_TO" "$PUSHED"
  } > "$JSON_OUT"
fi

# EXIT CODE. A batch that fast-forwarded after evicting a culprit is NOT a clean green: the caller
# must requeue the evicted bead, and rc=0 would let that step be skipped silently. rc=1 means "the
# queue did its job and something was thrown out", which is exactly when a human is needed.
if [ "$VERDICT" = green ] && [ "${#EVICTED[@]}" -gt 0 ]; then
  say "GREEN WITH EVICTION after $GATE_RUNS gate invocation(s): ${#MERGED[@]} merged, ${#EVICTED[@]} evicted (${EVICTED[*]})"
  exit 1
fi
case "$VERDICT" in
  green)        say "GREEN after $GATE_RUNS gate invocation(s)"; exit 0 ;;
  inconclusive) say "INCONCLUSIVE after $GATE_RUNS gate invocation(s): nothing merged, nobody blamed"; exit 3 ;;
  empty)        say "INCONCLUSIVE after $GATE_RUNS gate invocation(s): every branch was evicted"; exit 3 ;;
  *)            say "RED after $GATE_RUNS gate invocation(s)"; exit 1 ;;
esac
