# ADR-0048 — S6's fight-dependent survival assertion stays as written and is tracked nightly

**Status:** Proposed — default in effect (Claude Code, orchestrator, bead oo-9aq4, 2026-09-23;
ADR-0013, CLAUDE.md rule 10). Made under Jon's 2026-09-23 authorisation to resolve `human` and
frontier beads by best judgement when they would otherwise block progress. Jon may override; the
recommended override is option (b) below.
**Date:** 2026-09-23
**Refines** [ADR-0020](0020-component-scenarios-are-smoke-tests-for-now.md) for S6.

## Context

oo-sjvz pinned the cast of the component scenarios (police `[viper]`, pirate `[sidewinder]` with a
100-credit bounty). S1 and S5 then went 10/10 over two 5-run sweeps on a phase-2 test build, but
S6 (`test_s6_damaged_ship_flees.py`, seed 20260918) still failed 1/5 with the sidewinder and 2/5
with an adder as the pirate hull (experiment, reverted). An instrumented replay caught the failure
as `police died: energy damage by pirate` about 15 s after spawn. The pirate won a real-time 1-v-1
dogfight. That outcome is not seed-deterministic on a software renderer, so no hull choice makes
"a ship with role police survives" after up to 900 ticks a certainty.

Under ADR-0020, S2–S8 are smoke scenarios. Their survival assertion exists to prove that the
scenario's setup runs for its duration without crashing. It was never meant to predict who wins a
fight, and it does not test fleeing. S6 asserts the survival of a role that the fight it sets up
can remove. That is a defect in the smoke design, not in the game.

There are three ways out:

- (a) End S6's run once the police ship engages, as S1 does.
- (b) Assert the survival of a role the fight cannot remove, for example a bystander the scenario
  spawns, or drop the survival line and keep `no ERROR appears in the log`.
- (c) Leave S6 as written and track its pass rate nightly.

(a) and (b) change what the test asserts. That is CLAUDE.md rule 2, and the guardrails refuse
edits to feature step text, so both options are Jon's.

## Decision

1. **S6 stays exactly as written** in tier-b and tier-c. The flake policy Jon set on 2026-09-22
   ("for flaky tests, retry") applies to it at merge and phase gates. A red S6 is retried. A red S6
   that stays red on retry is a real failure and is reported as one.
2. **A nightly line tracks the rate.** `tests/nightly/checks.txt` runs S6 five times and fails the
   night if fewer than 3 of the 5 runs pass. That is below the 4/5 and 3/5 rates observed, so a
   regression in flee or fight behaviour, or a crash, still turns the night red. The count is
   printed every night so drift is visible.
3. **The recommended permanent fix is (b)**, left for Jon. It matches ADR-0020's intent (liveness
   of the setup), removes the dependence on the fight's outcome, and needs a one-line
   feature-file change that only Jon may approve.

## Consequences

- No test is modified. S6 keeps its current assertion, and its flakiness stays visible, both in
  the retry logs and in the nightly count.
- The duplicated `[oo-sjvz]` S1/S5 nightly line (left twice by a union merge) is removed in the
  same change. Keeping both would have run the same proof twice.
- If Jon picks (a) or (b), this ADR is superseded, the nightly line is dropped, and S6 joins the
  plain `[oo-sjvz]` stability loop.

## History

- 2026-09-23: proposed by the orchestrator (bead oo-9aq4), default in effect.
