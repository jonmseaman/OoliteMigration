# ADR-0057: Tier C's budget is 3000 s (Tier B stays 1200 s)

- Status: Proposed. Jon approved the change in chat on 2026-09-30 (relayed by the orchestrator);
  recorded here as a proposed ADR with that default in effect (CLAUDE.md rule 10).
- Date: 2026-09-30
- Beads: oo-3rb.331 (this ADR, the tier-c.sh constant, and tier-b's concurrent test stage);
  oo-ndo (the Phase 2 exit gate, which runs Tier C)

## Context

`tools/tier-c.sh` fails on elapsed time alone: `BUDGET_SECONDS` defaults to 2400 s and the script
exits 1 with "GREEN but OVER BUDGET" past it. The 2400 s figure was sized from the script's own
projection (1176-1646 s for tier-b 165-295 + jsapi 1 + asan 135 + goldens 90-300 + corpus 660-790
+ gui 120 + fleetdata 5) when the offline suites took ~12 s and the ASan build was warm.

Measured on phase-2 d3ab83db9 (bead oo-3rb.331, evidence in its notes and
`.agent-tmp/p2exit/`), every stage green:

| Stage | Measured | Projection in tier-c.sh |
|---|---:|---:|
| tier-b (full, incl. build) | ~2080 s before oo-3rb.331; ~1360 s after (build ~344 + other stages ~1020) | 165-295 s |
| jsapi | 5 s | 1 s |
| asan (cold debug+ASan build in a fresh worktree) | 566 s | 135 s |
| goldens | 34 s | 90-300 s |
| corpus (36/36 groups) | 436 s | 660-790 s |
| gui | ~125 s | 120 s |
| fleetdata | 2 s | 5 s |

Tier B's offline test stage grew ~30x (tests/golden ~218 s, tools ~135 s, fleet ~25 s serial,
uncontended) and its component stage is 769-957 s. oo-3rb.331 runs the three suites and their
shards concurrently (`tools/pytest_plugins/oo_shard.py`), which takes the tests stage from 716 s
to ~216 s under load without dropping a test or lowering a floor. Even so, the sum with that fix
is ~1360 + 5 + 566 + 34 + 436 + 125 + 2 = **~2530 s**, over 2400 s with nothing red. No stage can be
cut without losing coverage Tier C exists to provide (the ASan build and the full corpus are the
only places those defects are caught).

## Decision (default in effect)

1. Tier C's budget is **3000 s** (50 min): `BUDGET_SECONDS="${OOLITE_TIER_C_BUDGET:-3000}"` in
   `tools/tier-c.sh`. That is the measured ~2530 s plus ~470 s (~16%) of headroom for load on the
   fleet box. Tier C runs on a merge, not on a commit; the reasoning the script gives for a long
   budget there is unchanged.
2. Tier B's budget stays **1200 s**. It is the per-commit gate, and a slow per-commit gate gets
   disabled; oo-3rb.331's concurrent test stage is the way back under it, not a larger number.
3. The override `OOLITE_TIER_C_BUDGET` stays, for measurement only.

## Consequences

- The Phase 2 exit gate (oo-ndo) is no longer red on Tier C's clock alone.
- If Tier C creeps toward 3000 s, the answer is the one oo-3rb.331 took for Tier B (run
  independent work concurrently, measure, update the stage table), not another raise. A further
  raise needs a new ADR with fresh measurements.
- Tier B inside Tier C still enforces its own 1200 s: if the component stage alone keeps
  measuring 900 s+ under load, that is a Tier B finding with its own bead, not something this ADR
  absorbs.

## History

- 2026-09-30: proposed with Jon's chat approval as the default in effect (oo-3rb.331).
