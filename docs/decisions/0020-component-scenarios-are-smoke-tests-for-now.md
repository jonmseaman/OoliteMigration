# ADR-0020 — Component scenarios S2–S8 are smoke scenarios until the step library grows

**Status:** accepted (Jon, 2026-09-18, in chat; recorded by Claude Code at his request)
**Date:** 2026-09-18
**Amends** [ADR-0018](0018-component-test-tier.md) §5 and the S2–S8 table in
[0-component-tier.md](../phases/0-component-tier.md). Supersedes nothing.

## Context

Between 2026-09-17 and 2026-09-18 five component-scenario beads (S2 `oo-8wry`, S3 `oo-s1rw`,
S4 `oo-8c4g`, S5 `oo-on18`, S6 `oo-fjku`, S7 `oo-3roh`) stopped and filed the same finding from
independent workers: the step library in `upstream/oolite/tests/component/steps/world_steps.py`
exposes only role-count and liveness observables, and the assertion each story names needs an
observable that does not exist:

| Story asserts | Missing capability | Proposal bead |
|---|---|---|
| S2: the target registers an attacker | a step reading `Ship.AIPrimaryAggressor` / `AIFoundTarget` | `oo-kbqw` |
| S3: a ship enters `ATTACK` | `Ship.AIState` is dead for JS AIs (always `GLOBAL`); `hasHostileTarget` cannot tell ATTACK from FLEE | `oo-3cvh` |
| S4: killed *by missile* | `damageType` only reaches a per-ship script event | `oo-kbqw` |
| S6: range increases while fleeing | no step samples a number twice, none asserts a behaviour transition | `oo-kbqw` |
| S5, S7: *the ships I spawned* survive | `addShips()`'s array is discarded; role counts are inflated by the system populator | `oo-bdl0` |

Each proposal is a new native or step-library interface, which is frontier work, and each was
correctly parked as `proposed-adr` under ADR-0018 §5. Two of the scenarios were re-dispatched
before the dependency was recorded and burned a worker cycle re-deriving the same report.

## Decision

1. **S2–S8 are smoke scenarios for now.** Each feature file sets the world up exactly as its
   story says (load, launch, spawn the named roles, set their AIs, per ADR-0019), runs the
   simulation for the stated ticks, and asserts only what the existing steps can say:
   `no ERROR appears in the log`, and `a ship with role "<x>" survives` for a role the scenario
   spawned. That proves the setup runs for the scenario's duration without crashing. It does
   **not** prove the behaviour the story is named for.
2. **No new steps, no new native interfaces** for this sweep. A scenario that cannot be written
   with the current step catalogue is written as the smoke version, not blocked.
3. **The behavioural assertions are deferred, not dropped.** Jon tests them by hand later. The
   seam beads `oo-bdl0` and `oo-3cvh` stay on record, closed as deferred, so the day the step
   library grows they are the specification.
4. **A bead blocked on a capability that does not exist is a dependency, not a retry** (adopted
   from `oo-kbqw`): the orchestrator adds `bd dep add <bead> <seam>` the first time a blocked
   report is verified, and the bead leaves the ready queue until the seam closes.

## Consequences

- The seven scenario beads are re-scoped in their notes and given executable acceptance: one
  pytest run of the scenario (`-k sN_`); green means done. The generator's former shape, a single
  run followed by a three-run loop, cost four real-time game runs per accept and is retired
  (Jon, 2026-09-18). Their earlier "BLOCKED" notes are superseded by this ADR.
- The phase 0 exit criterion "S2–S8 replicate S1" is met by smoke scenarios. Anyone reading a
  green S3 must not conclude that ATTACK transitions work; the feature file's name and a comment
  in each file say so.
- Manual verification of the deferred behaviours is Jon's, on his own schedule, and is not a
  gate for phase 0.
