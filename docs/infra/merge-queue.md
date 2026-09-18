# The merge queue

Phase 0 item 0.10, bead `oo-pmg`. Implementation: `tools/merge-queue.sh`; proof:
`tools/merge-queue-selftest`.

The queue turns N Tier-B-green branches into ONE Tier C run and a fast-forward of `main`. It
re-implements nothing: the gate is `tools/tier-c.sh` (7 stages, ~1327 s, bead `oo-j4u`), invoked as
an opaque command whose only contract is its exit status.

## The arithmetic came first

One Tier C run costs ~1327 s (~22 min). Everything below follows from that number.

| strategy | runs for N=8 | runs for N=16 | wall clock at N=8 |
|---|---|---|---|
| batch, all green | 1 | 1 | ~22 min |
| linear scan | 8 | 16 | ~3 h |
| prefix bisection + attribution | 7 | 8 | ~2.6 h |

Be honest about the win: at N=8 bisection is 7 runs against a linear scan's 8, which is nearly
nothing. The win is asymptotic and arrives quickly (N=16: 8 vs 17; N=32: 9 vs 33). The *other*
reason to prefer it matters more at every N: a linear scan gates `base + c_i` in **isolation**, so
it is structurally blind to an interaction failure. Prefix bisection gates `base + c_1..c_k` — the
tree that would actually be merged — so an interaction surfaces as a red prefix with a green solo
and gets a named verdict instead of a mystery.

## The algorithm

`P(k)` = base + `c_1..c_k` merged in queue order. `P(0)` = base, assumed green (`--verify-base`
turns that assumption into a measurement for +1 run).

1. **`P(N)` green** → fast-forward. 1 run.
2. **`P(N)` red** → binary search the smallest `k` with `P(k)` red. `P(k-1)` is green, so `c_k` is
   the branch that first turns the prefix red. `ceil(log2 N)` runs.
3. **Confirm the deciding red** (`--rerun`, default 1) on the *same commit* that was gated, not a
   rebuilt one. Disagreement ⇒ the gate is flaky ⇒ `INCONCLUSIVE` (rc 3): nothing merged, nobody
   blamed.
4. **Attribute.** Gate `base + c_k` alone (1 run).
   - red → `c_k` is independently red. Evict it.
   - green → **interaction**. Binary search the largest `j<k` with `base + c_j..c_k` red
     (`ceil(log2 k)` runs) to name the partner. Report the *pair*; evict last-in (`c_k`), keep
     `c_j`.
5. **Retry the remainder** (1 run). Green → fast-forward. Red → a second independent culprit: back
   to step 2, up to `--max-culprits` (default 3), after which the batch is quarantined as
   `INCONCLUSIVE` rather than dismantled branch by branch.

Measured on the synthetic fixtures (N=8, stub gate):

| scenario | verdict | gate invocations |
|---|---|---|
| all green | `green`, fast-forward | 1 |
| one culprit (`f5`) | `f5` evicted, 7 merged | 8 |
| two culprits (`f2`,`f6`) | both evicted, 6 merged | 13 |
| interaction (`f3`+`f6`) | pair named, `f6` evicted, 7 merged | 9 |
| flaky gate | `INCONCLUSIVE`, 0 evicted, 0 merged | 3 |
| conflicting branch | evicted before any gate runs | 1 |

## The three hard cases

**Two independently red branches.** Step 5 is what handles this: after evicting the first culprit
the *remainder* is re-gated, and a second red sends the queue back through bisection. It costs
another `ceil(log2 N) + 3` runs per culprit, which is why `--max-culprits` exists — past three, a
batch is more likely poisoned than unlucky, and quarantining it is cheaper and more honest than
paying 30 Tier C runs to take it apart.

**An interaction.** Neither branch is red alone, so neither is "the bug"; blaming either one is a
lie that will be repeated in a bead's notes. The queue detects this from the shape of the evidence
(red in the prefix, green solo), names both branches, and evicts the later one purely as a
tie-break — stated as policy, not disguised as a finding.

**A flake.** This is the failure mode that costs the most trust, because a wrongly evicted branch
looks exactly like a correctly evicted one. The queue never attributes a red it has not seen twice
on the same tree. If the two runs disagree it emits `INCONCLUSIVE` and touches nothing: no
fast-forward, no eviction, no requeue. Doing nothing is the correct response to an instrument you
cannot trust, and the gate log records both verdicts so the flaky stage can be found and
quarantined at its source.

## Why this cannot deadlock against its own gate

Tier C's `gui` stage serialises on `tools/gui-lock`; its `asan` stage launches the real game under
the same lock; `tier-b`'s smoke stage takes the desktop lock too.

- The queue takes **neither** lock. It runs git plumbing only — no launcher, no window, nothing
  `tools/check-desktop-lock.sh` classifies as a spawn of the game binary.
- The queue runs gates **strictly sequentially**. `--jobs` above 1 is *refused with an error*
  rather than ignored, so "make the queue parallel" is a conversation instead of a quiet regression
  into two concurrent `gui-lock` holders.
- Its own mutual exclusion is a separate file, `.mq/queue.lock`, which `tier-c` never touches.

## Admission: the Tier-B attestation

A branch enters a batch only with an attestation keyed on its **exact tip SHA**
(`.mq/attest/<sha>`), written by `tools/merge-queue.sh --attest <branch>` after Tier B goes green.
Keying on the SHA rather than the branch name is the point: an attestation that survived a
force-push or an amend would admit un-gated code, and the queue would then spend an hour bisecting
a tree nobody ever ran Tier B on.

## Anti-vacuity guards

A queue that passes because nothing ran is worse than no queue. `rc=0` and an absence of error
lines are both satisfiable by a dead run. Each of these is a hard failure, never a skip:

| id | guard |
|---|---|
| G1 | an empty candidate list is fatal — "0 branches merged, GREEN" is the purest vacuous pass |
| G2 | every admitted branch carries a Tier-B attestation naming its exact tip SHA |
| G3 | the gate command must exist in the tree being gated |
| G4 | no verdict may be issued with zero gate invocations; the counter is asserted `> 0` and cross-checked against the on-disk tally |
| G5 | a fast-forward must MOVE the ref, the old tip must be an ancestor of the new one, and the base must not have moved during gating |
| G6 | a bisection must strictly narrow the candidate set |
| G7 | merged + evicted + conflicted == admitted |
| G8 | `--dry-run` leaves the invocation counter at 0 and every ref byte-identical |
| G9 | a non-green verdict may never have moved the base; an `INCONCLUSIVE` evicts nobody |

## Exit codes

| rc | meaning |
|---|---|
| 0 | green, fast-forwarded, nothing evicted |
| 1 | red: a culprit was attributed and evicted (the survivors may still have fast-forwarded — requeue the evicted bead) |
| 2 | usage or fatal error (empty batch, missing gate, `--jobs>1`, stale base) |
| 3 | `INCONCLUSIVE`: flake, poisoned base, or too many culprits — nothing merged, nobody blamed |

## Pushing

**Push is OFF by default.** The fleet's standing rule is that nothing pushes. Three independent
things must all be true before a single `git push` runs:

1. `--push` on the command line,
2. `OO_MQ_PUSH_CONFIRM=yes` in the environment,
3. a remote whose URL does not look like a real forge (`github.com`), overridable only by
   `OO_MQ_ALLOW_REMOTE_HOST=1`, which the fleet never sets.

Missing any of them, the queue prints the push it *would* have run and exits green. Scenario S10
proves all four branches of this against a **bare repository under `$LOCALAPPDATA/Temp`**; nothing
in this bead was ever run against `origin`.

Likewise the requeue step: when a branch is evicted the queue **prints** the `bd update ... --notes`
command and never runs it. The agent that implements a bead does not mutate bead state.

## Proving it without the real gate

`tools/merge-queue-selftest` builds throwaway git repositories under `$LOCALAPPDATA/Temp` with
scripted good/bad/interacting branches and a stub gate whose entire contract — like `tier-c.sh`'s —
is its exit status. Twelve scenarios, ~93 assertions, ~6 minutes. Against the real gate the same
coverage would be 60+ Tier C runs, about 22 hours, and would merge real branches into real `main`.

Every assertion is positive evidence: gate invocation counts, base SHA before and after, ancestry
checks that each surviving branch is genuinely reachable from `main` and the culprit genuinely is
not. `tools/merge-queue-mutants.sh` then proves the instrument can fail: it copies the queue and
the fixtures to a temp directory, plants defects (a fast-forward that ignores the verdict, a
bisection that blames the first branch, an eviction on a flake, a dropped attestation check) and
requires the selftest to go RED naming each one.
