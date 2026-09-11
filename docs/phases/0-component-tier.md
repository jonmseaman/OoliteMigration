# Phase 0 — Component test tier (Gherkin over the debug console)

Part of [Phase 0](0-safety-net.md), item 0.13. Decided in
[ADR-0018](../decisions/0018-component-test-tier.md). Kept separate from
[0-gui-tier.md](0-gui-tier.md) and from item 0.4 for the same reason those are separate from each
other: the three tiers test disjoint things and the boundaries have to stay sharp.

A third tier that drives the game **over the debug-console TCP channel, headless**, and asserts
**named, tolerant invariants** about simulated gameplay — written as Gherkin scenarios in readable
English.

## Why this exists alongside the golden harness

| | Golden harness (0.4) | **Component tier (0.13)** | PyAutoGUI (0.8) |
|---|---|---|---|
| Driven via | debug-console TCP/JS | debug-console TCP/JS | synthetic OS input |
| Window | none on Linux (`SDL_VIDEODRIVER=offscreen`); on Windows a window opens but takes no input | same as the goldens | real, on-screen, takes input |
| Asserts | full state dump, byte-compared | named invariants, tolerant | launched / responded / exited |
| On failure says | "1,800 floats moved" | "pirates no longer die" | "window never opened" |
| Determinism needed | fixed seed + fixed dt + quantised floats + per-platform bless | **fixed seed only** | n/a |
| Human gate | re-bless (Jon, weekly) | **none** | none |
| Volume | ~20 scenarios | ~8 growing to dozens | ~10 smoke tests |
| Runs in | Tier B subset / Tier C | Tier B subset / Tier C | Tier C + nightly |

The golden harness catches **what nobody thought to assert** — that is the whole point of comparing a
full dump, and nothing here replaces it. What it cannot do is say *which behaviour* broke. Across a
686-bead conversion programme that diagnostic gap is most of the debugging cost, and it lands on the
scarcest resource in the project (Jon's adjudication time).

The inverse is equally true: a component suite only catches what someone wrote a scenario for. **The
two tiers are complements, and neither is a reason to skip the other.**

**Scope discipline, in both directions.** A component test that starts byte-comparing a state dump
belongs in the goldens. A golden that grows a hand-written assertion belongs here. If a scenario needs
the window or real input, it is a GUI test and belongs in [0-gui-tier.md](0-gui-tier.md).

## Determinism: what this tier needs, and what it does not

**Needs `OO_RANDOM_SEED`.** `src/Core/GameController.m:100` seeds RANROT from the wall clock. Combat
draws on it heavily — 52 `randf()` sites in `ShipEntity.m`, 14 in `ShipEntityAI.m`, including the
shot-attempt gate at `ShipEntity.m:11481`. Without a pinned seed, "the pirate dies within 900 ticks" is
genuinely flaky. The fix is ~3 lines and is also a prerequisite of item 0.4, which requires a fixed
seed but never had a bead for it.

**Does not need fixed-delta-t stepping, quantised floats, or per-platform blessing.** Those exist
because goldens byte-compare positions. Tolerant assertions survive float jitter, which is why this
tier can land *before* the golden harness, *before* item 0.1's iteration-order work, and stays valid
across the Phase 5 platforms unchanged.

Scenarios must still be written to be robust: assert **"within N ticks"**, never "at tick N"; assert
**"no pirate remains"**, never an exact position. A scenario that needs an exact float is a golden.

## The observation surface (all of it already exists)

Steps send small JS strings through the existing `Perform Command` packet — exactly as
`upstream/oolite/tests/launch_snapshot.py:156` sends `"takeSnapShot(); quit();"`.

| Need | Existing JS surface |
|---|---|
| Spawn a scene | `addShips` (`src/Core/Scripting/OOJSSystem.m:192`), `legacy_spawnShip` (`:213`) |
| Count survivors | `countShipsWithRole` (`OOJSSystem.m:197`) |
| Enumerate the world | `system.allShips` (`OOJSSystem.m:116,152`) |
| Position, orientation, scan class, liveness | `OOJSEntity.m:105,107,108,119` (`position`, `orientation`, `scanClass`, `isValid`) |
| AI state, motion, identity | `OOJSShip.m:340` (`AIState`), `:472` (`velocity`), `:458` (`speed`), `:388` (`heading`), `:439` (`primaryRole`) |
| Death and killer attribution | `shipDied` / `shipKilledOther`, fired from `-noteKilledBy:damageType:` (`ShipEntity.m:9007,9020,9024`) |

**`energy` is not exposed to JS** (only `energyRechargeRate`, `OOJSShip.m:371`). Do not add a native
property for it — assert "took damage" through the death events, `isValid`, and `countShipsWithRole`.
Asserting only on what is already observable is what keeps this a small seam rather than a native-API
project.

Ship AI thinks on a `0.125 s` interval (`AI_THINK_INTERVAL`, `src/Core/AI.h:31`), so 900 ticks is
roughly 120 AI decisions — comfortably enough for acquire → close → fire → kill.

## What a scenario looks like

```gherkin
Feature: Ship-to-ship combat
  Scenario: A police viper destroys a lone pirate
    Given a universe seeded with 20260910
    When I spawn 1 ship with role "police"
    And I spawn 1 ship with role "pirate" within 10 km
    And the simulation runs for at most 900 ticks
    Then no ship with role "pirate" remains
    And a ship with role "police" survives
```

`Given` sets `OO_RANDOM_SEED` at launch; `When` sends `addShips`; the run step polls
`countShipsWithRole` and stops early when it reaches 0, failing on timeout rather than hanging;
`Then` asserts in Python on the counts.

**Killer attribution is deliberately absent.** `shipDied` / `shipKilledOther` do fire
(`ShipEntity.m:9007,9020,9024`), but capturing them needs a script object on a ship (`setScript`,
`OOJSShip.m:560`) and therefore a test-only script resource. With exactly two ships spawned, "no
pirate remains and a police ship survives" already proves the AI engaged, the weapon fired, damage
landed and the target died. Attribution is a **new step** when something needs it — file a bead.

## The tests

`upstream/oolite/tests/component/`, pytest + pytest-bdd. Every scenario gets a hard timeout with a
forced kill, as the GUI tier does, so a hang fails the run instead of wedging it.

| # | Scenario | What it catches |
|---|---|---|
| **S1** | **Police ship destroys a lone pirate** | The baseline: AI engages, weapon fires, damage lands, death fires, killer is attributed. The seam and the exemplar. |
| S2 | Pirate attacks; the target registers an attacker | The damage path independently of the kill path — catches "weapons fire but do nothing". |
| S3 | A hostile spawn drives a ship into `ATTACK` | AI state-machine transitions (`Ship.AIState`), independent of whether combat resolves. |
| S4 | A missile-armed ship kills by missile | The second weapon path and `damageType` attribution; missiles are simulated projectiles, lasers are hitscan. |
| S5 | Escorts converge on their mother | Group and formation behaviour (`OOShipGroup`), which no other tier touches. |
| S6 | A damaged ship flees and range increases | The FLEE branch — the most commonly broken AI transition. |
| S7 | 8 neutral ships, 900 ticks, nobody dies, no `ERROR` in `Latest.log` | The canary: accidental carnage, NaN blowups, scan-class confusion. Fails loudly when physics goes wrong. |
| S8 | Destroyed ships leave `system.allShips` | **Entity lifetime.** [ADR-0003](../decisions/0003-intrusive-refcount.md) says hand-translated refcounting *will* produce use-after-free; a leaked entity shows up here as "the ship never left the list" long before ASan catches the UAF in Tier C. |

S1 is a seam (5/7 on the sizing rule): [S1-police-kills-pirate.md](../stories/S1-police-kills-pirate.md).
S2–S8 are replications scoring 7/7 against it, exactly as G2–G9 replicate G1.

## Growing the suite

Later beads are *expected* to add scenarios for behaviour they touch. The rule
([ADR-0018](../decisions/0018-component-test-tier.md) §5):

- **A new `.feature` scenario using only existing steps is fleet work** — a `.feature` file is data,
  not an interface, so sizing check 5 holds and the story scores 7/7 against S1.
- **A new step definition is a new interface** — check 5 fails, so stop and file a bead. The step
  library grows by seam, never opportunistically inside a conversion bead.
- Adding a test was never prohibited; only modifying or deleting one is.
- The item 0.11 deleted-test guardrail must cover `.feature` files and the step library, or a bead
  trying to go green can quietly gut the tier.

## Where it runs

Tier B runs a **tagged subset** (the fast scenarios), alongside the 3–5 fast goldens. Tier C runs the
whole suite. Not Tier A: a game launch alone costs ~5-10 s, which blows the 30 s budget on its own.

Each scenario is one native game process with Mesa's llvmpipe `opengl32.dll` beside the binary, on its
own port, so the tier competes for the same RAM budget as the goldens
([I0](../infra/0-machines.md)) and shares their console client. It takes no input, so unlike the GUI tier it
needs no desktop lock and can run per bead (on Windows a window still opens; the desktop must be unlocked, [I0](../infra/0-machines.md)).

Audio forced to `SDL_AUDIODRIVER=dummy` / `ALSOFT_DRIVERS=null` as the existing tests do.

## When to build it

S1 in Phase 0, against the current Objective-C build, so there is a known-good baseline before
anything changes — and **before** the golden harness runner (`oo-16s`), since this tier needs strictly
less machinery and the harness can then reuse its console client. S2–S8 follow as a sweep. The tier
becomes load-bearing in **Phase 3**, where it is the thing that turns "a golden moved" into "this
conversion broke targeting".
