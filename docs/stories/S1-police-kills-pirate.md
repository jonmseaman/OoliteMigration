# Story: S1 — A police ship engages a lone pirate

**Amended 2026-09-11 by [ADR-0019](../decisions/0019-component-tier-scenario-setup.md)**, which ran
this scenario for the first time and found that several facts stated below from source inspection do
not hold against the built game. The corrections are folded in here; the file name is unchanged so
that existing citations keep resolving. The assertion is **engagement, not a kill** — see
[ADR-0019](../decisions/0019-component-tier-scenario-setup.md) §"Why the kill assertion was
unreachable".

Hand-written 2026-09-10 as the **exemplar for the component tier**, the way
[G1](G1-exit-via-mouse.md) is the exemplar for the GUI tier. S1 is a *seam*: it fails sizing checks 5
and 7 because the console client, the launch fixture and the step library do not exist yet, so it is
human + frontier work. Once it lands, S2–S8 are replications that cite this file and score 7/7.
Phase: [0](../phases/0-safety-net.md), item 0.13. Specification:
[0-component-tier.md](../phases/0-component-tier.md). Decision:
[ADR-0018](../decisions/0018-component-test-tier.md).

**Depends on:** the `OO_RANDOM_SEED` bead. Without a pinned seed this scenario is genuinely flaky —
see the facts below. Do not start S1 before it lands.

## Task

Add `upstream/oolite/tests/component/`: a pytest + pytest-bdd suite that launches the Objective-C
build headless, drives it over the debug-console TCP channel, **loads a save and launches the player
so the simulation actually ticks**, empties the system of ambient traffic, spawns a police ship and a
pirate around a single locus **with their role's real AI**, runs the simulation for at most 900
ticks, and asserts that the police ship acquires the pirate as a hostile target and that the pirate
takes damage. Provide the console client, the launch fixture and the step library that S2–S8 will
reuse.

**Do it the way `upstream/oolite/tests/launch_snapshot.py` does it** for
the protocol framing, launch, environment and timeout handling — headless, with
`SDL_AUDIODRIVER=dummy` and `ALSOFT_DRIVERS=null`, plus `OO_RANDOM_SEED` set for the run.

## Facts the implementation depends on (source inspection 2026-09-10, corrected by observation 2026-09-11)

**Protocol and launch** — reuse, do not reinvent:
- Plist framing: 4-byte big-endian length + XML plist (`tests/launch_snapshot.py:31-77`).
- Handshake: game sends `Request Connection`, tester replies `Approve Connection`
  (`launch_snapshot.py:129-143`).
- Arbitrary JS: a `Perform Command` packet with the JS in `message`
  (`launch_snapshot.py:153-157`, e.g. `"takeSnapShot(); quit();"`).
- Headless env: `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`, `SDL_AUDIODRIVER=dummy`,
  `ALSOFT_DRIVERS=null` (`launch_snapshot.py:90-102`).
- `PORT = 8563` and `HOST` are hardcoded (`launch_snapshot.py:26-27`) — **parameterise the port**, one
  process per scenario, as item 0.4 also requires.

**The JS surface the steps use** (all already exists; add no native interfaces):

| Need | Surface |
|---|---|
| Spawn | `addShips(role, count[, position, radius])` (`src/Core/Scripting/OOJSSystem.m:192`, `:943`) — returns the array of ships added; `legacy_spawnShip` (`:213`). There is **no `addShipsWithinRadius`**. |
| Give a spawned ship a working AI | `ship.setAI("oolite-policeAI.js")` / `"oolite-pirateAI.js"`. Do **not** rely on the role's own AI: `shipdata.plist` does supply one (`oolite_template_viper` → `ai_type = "oolite-policeAI.js"` at `Resources/Config/shipdata.plist:3831`; the pirate templates → `"oolite-pirateAI.js"`, e.g. `:390`, `:1400`, `:1569`), but `-setAITo:` **discards it** and substitutes `oolite-nullAI.js` whenever `[PLAYER scriptsLoaded]` is false (`src/Core/Entities/ShipEntityAI.m:254-257`). Ships spawned before a game is loaded therefore never think, never target and never fire — which is exactly what ADR-0019 observed at the main menu and while docked. Load and launch first, then set the AI explicitly. |
| Count by role | `countShipsWithRole` (`OOJSSystem.m:197`) — counts the **ambient** population too, which the scenario must empty first |
| Enumerate | `system.allShips` (`OOJSSystem.m:116,152`) |
| Orientation / position / scan class / liveness | `OOJSEntity.m:105,107,108,119` (`orientation`, `position`, `scanClass`, `isValid`) |
| Health | `energy` / `maxEnergy` on **`Entity`**, read-write (`OOJSEntity.m:101,104`) |
| AI state / motion / identity | `OOJSShip.m:340` (`AIState`), `:472` (`velocity`), `:458` (`speed`), `:439` (`primaryRole`) |
| Targeting | `ship.target`, `ship.hasHostileTarget` |
| Message to the debug console | `debugConsole.consoleMessage(colorCode, message)` (`OOJSConsole.m:195`). The bare global `consoleMessage(...)` belongs to `player` and shows an **in-game** message, not a console one. |
| Cross-command scratch state | `debugConsole` is a writable JS global (`src/Core/Debug/OODebugMonitor.m:761`) |

**World setup is part of the `Given`** ([ADR-0019](../decisions/0019-component-tier-scenario-setup.md)):

- At the main menu there is **no simulation at all** — a demo scene with a docked player and a
  station. A save must be `-load`ed (`src/SDL/main.m:167`).
- A loaded save starts **docked**, and NPC AI does not tick while docked. `player.ship.launch()` is
  required.
- The standard scenario opens with **~80 entities, including 32 pirates and 5 police**. The system
  must be emptied before a role count measures the scenario rather than the ambient traffic.
- An *unpositioned* `addShips` scatters anywhere in the system — observed 415 km apart. Pass an
  explicit `position` and `radius` to place ships near each other.

**Determinism:**
- `src/Core/GameController.m:100` seeds RANROT from the wall clock
  (`ranrot_srand((uint32_t)[[NSDate date] timeIntervalSince1970]);`).
- Combat consumes that RNG: 52 `randf()` sites in `ShipEntity.m`, 14 in `ShipEntityAI.m`, including
  the shot-attempt gate `if (range > randf() * weaponRange * (accuracy+7.5))  return NO;`
  (`ShipEntity.m:11481`).
- AI thinks every `0.125 s` (`AI_THINK_INTERVAL`, `src/Core/AI.h:31`). 900 ticks was originally
  justified as "≈120 decisions — ample for acquire → close → fire → kill"; that arithmetic was never
  observed. **Measured**: engagement (target acquired, `hasHostileTarget` set) lands at ~136 ticks
  (~17 s), so 900 is a generous ceiling, not a target. A **kill does not happen at all** in this
  matchup — a GalCop Viper has 180 max energy against a stock pirate's 706, and the police ship is
  the one losing ([ADR-0019](../decisions/0019-component-tier-scenario-setup.md)).

**Two things deliberately out of scope:**
- **Killer attribution.** `shipDied` / `shipKilledOther` do fire (`ShipEntity.m:9007,9020,9024`), but
  capturing them needs a script object on a ship (`setScript`, `OOJSShip.m:560`) and therefore a
  test-only script resource. **S1 does not assert attribution.** With exactly two ships spawned,
  "the police acquires the pirate as a hostile target and the pirate's `energy` drops below its
  `maxEnergy`" already proves the AI engaged, the weapon fired and damage landed. If a later scenario
  needs attribution, that is a **new step** → stop and file a bead
  ([ADR-0018](../decisions/0018-component-test-tier.md) §5).
- **A kill assertion.** Unreachable in this matchup on any tick budget; it belongs in a scenario
  whose time-to-kill has been measured first.

**Adding native interfaces remains prohibited.** `energy` being observable widens what a scenario may
assert; it does not license exposing anything that is not already exposed.

## The scenario

```gherkin
Feature: Ship-to-ship combat

  Scenario: A police viper engages a lone pirate
    Given a universe seeded with 20260910
    And a launched player in an emptied system
    When I spawn 1 ship with role "police" at the locus
    And I spawn 1 ship with role "pirate" within 5 km of the locus
    And the simulation runs for at most 900 ticks
    Then the police ship has the pirate as a hostile target
    And the pirate has taken damage
```

`Given` sets `OO_RANDOM_SEED` at launch, `-load`s a save, calls `player.ship.launch()` and clears the
~80 ambient entities. The spawn steps call `addShips(role, 1, locus, radius)` and then `setAI` with
the role's real AI script, because `-setAITo:` replaces the template's `ai_type` with
`oolite-nullAI.js` until the player's scripts are loaded (`ShipEntityAI.m:254-257`) and a null-AI ship
never acts.
The run step polls the predicate on an interval and returns as soon as it holds; it must fail on
timeout, not hang. "Has taken damage" is `energy < maxEnergy` on the pirate (`Entity.energy`,
`OOJSEntity.m:101,104`).

## Files

Touches 6:

- `upstream/oolite/tests/component/console.py` (new: the debug-console
  client — framing, handshake, `perform(js)`, parameterised port. **Shared with the golden harness
  later; keep it free of component-tier assumptions.**)
- `upstream/oolite/tests/component/conftest.py` (new: launch fixture,
  seed injection, hard timeout with forced kill)
- `upstream/oolite/tests/component/steps/world_steps.py` (new: the step
  library S2–S8 reuse)
- `upstream/oolite/tests/component/features/s1_police_kills_pirate.feature` (new)
- `upstream/oolite/tests/component/requirements.txt` (new: `pytest`, `pytest-bdd`)
- `upstream/oolite/tests/component/README.md` (new: the step catalogue —
  the one place a later bead looks to find out which steps already exist)

Reads: `launch_snapshot.py` (230 lines), the cited property tables in `OOJSSystem.m` / `OOJSShip.m` /
`OOJSEntity.m`, the cited `ShipEntity.m` ranges. Under 1,500 lines. Writes: ~350 lines.

## Acceptance (run by the wrapper, never by the agent)

Nonzero before (the directory does not exist), zero after:

```bash
python3 -m pytest upstream/oolite/tests/component/ -x -q
```

Plus a flake check, because a tolerant assertion that is only usually true is worse than no test:

```bash
for i in 1 2 3 4 5; do python3 -m pytest upstream/oolite/tests/component/ -x -q || exit 1; done
```

## Prohibitions

- Do not modify anything under `goldens/`.
- Do not modify or delete tests, including `tests/launch_snapshot.py`. **Adding** tests is expected;
  only modifying or deleting them is prohibited.
- Do not add `-Wno-*`, `#pragma` diagnostic suppressions, or `[[maybe_unused]]` to silence a warning.
- Do not add native JS properties or other new interfaces to `upstream/oolite` to make an assertion
  easier. Assert on what is already observable, or stop and report.
- Do not mark this unit done; the wrapper does, via `accept`.
- Do not read expansion (OXP/OXZ) content.
- Commit only to the worktree branch you were given. Never push to `main`.

## Carry-over

(empty on first dispatch)

## Sizing check

| # | Check | ✓ |
|---:|---|---|
| 1 | Reads ≤ ~1,500 lines | ✓ |
| 2 | Writes ≤ ~400 lines | ✓ |
| 3 | ≤ 8 files | ✓ (6) |
| 4 | Command-shaped acceptance | ✓ |
| 5 | Zero new interfaces | ✗ — defines the console client, the launch fixture and the step library (**seam**) |
| 6 | 2–3 sentences | ✓ |
| 7 | Names a worked exemplar | ✗ — `launch_snapshot.py` is a partial exemplar for transport only (**seam**) |

5/7 → seam. S2–S8 will score 7/7 against this file.
