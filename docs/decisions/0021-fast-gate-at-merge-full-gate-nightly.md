# ADR-0021 — A five-minute gate at merge; the full gate nightly and at phase end

**Status:** accepted (Jon, 2026-09-21, in chat; recorded and implemented by Claude Code at his request)
**Date:** 2026-09-21
**Amends** [ADR-0013](0013-decide-up-front-minimise-human.md) decision 14 ("merges to `main` are
automatic on Tier C green"), [ADR-0016](0016-no-forge-local-verification.md) (which tiers run
where), and the exit-gate wording in [0-safety-net.md](../phases/0-safety-net.md). Supersedes nothing.

## Context

Measured on the fleet machine over phase 0 (116 closed beads):

| Gate | Cost | Who paid it |
|---|---|---|
| A bead's acceptance block, replayed by `accept.sh` on the merged tree | 6.5 lines on average; 46 of 116 blocks carried a live game launch, a 10-run stability sweep or a mutant sweep; recorded live-run walls median 22 s, worst 1,122 s | every bead, at every accept |
| Tier B (`tools/tier-b.sh`) | 165 s warm, 295 s cold | nobody per merge: the fleet's `accept.sh` fast-forwards `main` itself |
| Tier C (`tools/tier-c.sh`) through `tools/merge-queue.sh` | 20 to 27 minutes | nobody per merge: the queue is built but not in the fleet's loop |

The slow part of landing was therefore not a test tier but the fleet's habit of writing every
proof into the acceptance block. The block is the right place for the proof that the bead is done;
it is the wrong place for the proof that it stays done under repetition, sanitizers and the full
corpus. Those are properties of `main`, not of one bead, and they are worth running once a night
and once at the end of a phase, not once per bead.

## Decision

1. **The merge gate is the bead's acceptance block, and it has a five-minute budget.**
   `accept.sh` gives the whole block one budget, `BEADS_ACCEPT_BUDGET` (default 300 s); each line
   gets what is left. A block that runs out is rejected with a note that names the budget and says
   where the slow proof goes. The budget is not raised to make a bead pass; the proof is moved.
2. **Slow proofs live in `tests/nightly/checks.txt`**, one shell command per line, run from the
   repository root by `tools/run-nightly-checks.sh`. A worker whose bead needs a stability sweep, a
   mutant sweep, a repeated launch or anything else that cannot finish inside the budget adds it
   there and leaves a one-line fast proof in the acceptance block.
3. **Tier C runs nightly and at phase end, not per merge.** The nightly task (bead oo-1bf.11)
   runs `tools/tier-c.sh` (which already runs Tier B as its stage 0) and then
   `tools/run-nightly-checks.sh`. The phase-end review runs the same two before the exit gate is
   walked. `tools/merge-queue.sh` keeps `tools/tier-c.sh` as its gate: it is the phase-end and
   nightly batch verifier that bisects a red night to its commit, not the per-bead gate.
4. **A red night is bisected, not ignored.** The morning's first fleet turn files a `bug` bead per
   distinct failure with the bisected commit in its body, before any other bead is claimed.

## Consequences

- Landing a bead costs its acceptance block (≤ 5 min) plus the review round. Nothing else runs
  on the merge path.
- ASan, the full Tier 1 corpus, the GUI tier and the stability sweeps catch a defect the next
  morning instead of at merge. The goldens are byte-compared in Tier B and in the bead's own fast
  proof, so a behaviour change still fails at merge; what moves to the morning is the slow
  evidence, not the fast one.
- The worker and reviewer prompts state the budget; the reviewer rejects a block that cannot
  finish inside it as "not done", the same as one that cannot fail.
- Existing beads whose stored acceptance exceeds the budget are rejected on their next accept with
  the budget note; their worker moves the slow lines and re-runs. No stored block is edited by
  this decision.
