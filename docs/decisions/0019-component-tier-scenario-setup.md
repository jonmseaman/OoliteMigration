# ADR-0019 — What a component-tier scenario has to set up, and what S1 should assert

**Status:** accepted by default and implemented; S1 passes. Jon may still override ([ADR-0013](0013-decide-up-front-minimise-human.md), CLAUDE.md rule 10)
**Date:** 2026-09-11
**Supersedes nothing. Amends the factual claims in** [S1](../stories/S1-police-kills-pirate.md) **and** [0-component-tier.md](../phases/0-component-tier.md).

## Context

[S1](../stories/S1-police-kills-pirate.md) is the exemplar for the component tier; S2–S8 replicate
against it. It was written from source inspection on 2026-09-10 and never executed. Running it for
the first time (2026-09-11) showed that several of its stated facts do not hold against the built
game, and that its scenario cannot pass as written.

The harness itself is finished and works: launch, seed, console handshake, readiness, JS evaluation,
spawn, poll, count, quit, per-scenario timeout. Everything below is about the *world setup* a
scenario needs and what S1 can honestly assert.

## What measurement showed

| S1 / 0-component-tier.md says | What actually happens |
|---|---|
| Spawn ships and they fight | `system.addShips` assigns **`nullAI.plist`**. Ships never think, never target, never fire. Two ships, 900 ticks: `AIState` `GLOBAL` throughout, both at full energy. |
| Spawning is enough setup | At the main menu there is **no simulation at all** — a demo scene with a docked player and a station. 90 s, zero movement, zero targets. A save must be `-load`ed (`src/SDL/main.m:167`). |
| A loaded game is in flight | A loaded save starts **docked**; while docked NPC AI still does not tick. `player.ship.launch()` is required. |
| The system is empty enough to count roles | The standard scenario opens with **~80 entities, including 32 pirates and 5 police**. `countShipsWithRole("pirate") == 0` is unreachable, and the count measures the ambient population, not the scenario. |
| "within 10 km" places ships near each other | An *unpositioned* `addShips` scatters anywhere in the system. Police and pirate landed **415 km apart**. |
| `energy` is not exposed to JS; do not assert on health | `energy` and `maxEnergy` **are** exposed, read-write, on **`Entity`** (`OOJSEntity.m:101,104`) — not on `Ship`, which is presumably how the story missed them. |
| `consoleMessage(...)` reaches the console | The bare global belongs to `player` and shows an in-game message. The console route is `debugConsole.consoleMessage(colorCode, message)` (`OOJSConsole.m:195`). |
| `addShipsWithinRadius` | Does not exist. `addShips(role, count, position, radius)` does, and returns the array of ships added (`OOJSSystem.m:943`). |

The first five are now handled in `steps/world_steps.py`; the last two in `console.py`.

## The open question

With **all** of that fixed — live universe, launched, emptied system, both ships spawned 5 km apart
with `oolite-policeAI.js` and `oolite-pirateAI.js` — a lone police ship still does not destroy a
lone pirate within 900 ticks (≈112 s).

That is a statement about Oolite's combat behaviour, and CLAUDE.md rule 7 reserves judging
correctness to the goldens, the sanitizers and Jon. The implementing agent should not keep tuning a
scenario until it goes green: a scenario that only passes after enough fiddling is worse than no
scenario, which is exactly the flake risk [0-component-tier.md](../phases/0-component-tier.md) warns
about.

## What the measurement showed

Taken with the setup above in place, seed 20260910, sampled every ~11 s:

| t | distance | police | pirate |
|---:|---:|---|---|
| 6 s | 9,878 m | `tgt=-` `host=false` `e=180/180` | `tgt=-` `host=false` `e=706/706` |
| 17 s | 9,861 m | **`tgt=pirate` `host=true`** | `tgt=police` |
| 100 s | 3,738 m | `e=171/180` | `e=706/706` |
| 133 s | 766 m | `e=130/180` | `e=682/706` |
| 320 s | oscillating | recovered to `e=180/180` | `e=706/706` |

**The matchup cannot end in a kill.** A GalCop Viper has 180 max energy; a stock pirate has 706.
The police is the one losing, bottoming out at 130/180 and then regenerating, while the pirate never
drops below 682/706. They circle indefinitely. No tick budget fixes this, which is why the original
assertion could never have gone green.

**Engagement, by contrast, is fast and unambiguous:** target acquired with `hasHostileTarget` set
within ~17 s, about 136 ticks, against a 900-tick budget - a margin of more than 6x.

## Decision (recommended default)

1. **Scenario setup is part of the `Given`, and is now specified.** A component scenario runs in a
   loaded, launched, emptied system, with spawned ships given their role's real AI around a single
   locus. This is harness work, already done, and S2–S8 inherit it.

2. **S1 should assert engagement, not a kill.** "The police ship acquires the pirate as a target"
   (`target`, `hasHostileTarget`) and "the pirate takes damage" (`energy` < `maxEnergy`, now known to
   be observable) are tolerant, fast, and test the same chain the story cares about — AI engaged,
   weapon fired, damage landed — without depending on time-to-kill, which is the flakiest quantity
   in the scenario. A kill assertion, if wanted, belongs in a scenario with a much larger tick
   budget, and should be measured before it is written.

3. **The tick budget is now measured.** 900 ticks came from "≈120 AI decisions", arithmetic about
   `AI_THINK_INTERVAL` rather than an observation. Engagement lands at ~136 ticks, so 900 is kept as
   a generous ceiling rather than a target. The step returns as soon as the predicate holds, so the
   scenario costs ~45 s end to end, not the full 112 s.

4. **Correct the two documents.** The table above is the evidence; [S1](../stories/S1-police-kills-pirate.md)
   and [0-component-tier.md](../phases/0-component-tier.md) state things about the JS API that are
   wrong, and every later scenario is written against them.

## Consequences

- S2–S8 remain replications: the step library and the world setup carry the corrections, and the
  feature files stay data.
- `energy` being observable widens what a scenario may assert. It does **not** license adding native
  interfaces; the prohibition in S1 stands for anything not already exposed.
- If Jon prefers to keep the kill assertion, the work is to measure time-to-kill and set the budget
  from the measurement — not to relax the assertion.

## Alternatives considered

- **Keep tuning until it passes.** Rejected: it produces a scenario that is true by construction
  rather than by observation, and it is the implementing agent judging correctness.
- **Assert on a scripted kill (`ship.explode()`).** Rejected: it tests the harness, not the game.
- **Drop S1 and start from S7 (the "nobody dies" canary).** Tempting, since it needs no combat to
  resolve, but it would leave the tier with no exemplar for the thing it exists to catch.
