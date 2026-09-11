# Story: S1 — A police ship destroys a lone pirate

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
build headless, drives it over the debug-console TCP channel, spawns a police ship and a pirate, runs
the simulation for at most 900 ticks, and asserts that no pirate remains and a police ship survives.
Provide the console client, the launch fixture and the step library that S2–S8 will reuse.

**Do it the way `upstream/oolite/tests/launch_snapshot.py` does it** for
the protocol framing, launch, environment and timeout handling — headless, with
`SDL_AUDIODRIVER=dummy` and `ALSOFT_DRIVERS=null`, plus `OO_RANDOM_SEED` set for the run.

## Facts the implementation depends on (verified against source, 2026-09-10)

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
| Spawn | `addShips` (`src/Core/Scripting/OOJSSystem.m:192`), `legacy_spawnShip` (`:213`) |
| Count by role | `countShipsWithRole` (`OOJSSystem.m:197`) |
| Enumerate | `system.allShips` (`OOJSSystem.m:116,152`) |
| Position / orientation / scan class / liveness | `OOJSEntity.m:105,107,108,119` |
| AI state / motion / identity | `OOJSShip.m:340` (`AIState`), `:472` (`velocity`), `:458` (`speed`), `:439` (`primaryRole`) |
| Cross-command scratch state | `debugConsole` is a writable JS global (`src/Core/Debug/OODebugMonitor.m:761`) |

**Determinism:**
- `src/Core/GameController.m:100` seeds RANROT from the wall clock
  (`ranrot_srand((uint32_t)[[NSDate date] timeIntervalSince1970]);`).
- Combat consumes that RNG: 52 `randf()` sites in `ShipEntity.m`, 14 in `ShipEntityAI.m`, including
  the shot-attempt gate `if (range > randf() * weaponRange * (accuracy+7.5))  return NO;`
  (`ShipEntity.m:11481`).
- AI thinks every `0.125 s` (`AI_THINK_INTERVAL`, `src/Core/AI.h:31`), so 900 ticks ≈ 120 decisions —
  ample for acquire → close → fire → kill.

**Two things deliberately out of scope, because the API does not support them cleanly today:**
- **`energy` is not exposed to JS** (only `energyRechargeRate`, `OOJSShip.m:371`). Do not add a native
  property. Assert death and survival, not health.
- **Killer attribution.** `shipDied` / `shipKilledOther` do fire (`ShipEntity.m:9007,9020,9024`), but
  capturing them needs a script object on a ship (`setScript`, `OOJSShip.m:560`) and therefore a
  test-only script resource. **S1 does not assert attribution.** With exactly two ships spawned, "no
  pirate remains and a police ship survives" already proves the AI engaged, the weapon fired, damage
  landed and the target died. If a later scenario needs attribution, that is a **new step** → stop and
  file a bead ([ADR-0018](../decisions/0018-component-test-tier.md) §5).

## The scenario

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

The run step polls `countShipsWithRole("pirate")` on an interval and stops early when it reaches 0;
it must fail on timeout, not hang.

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
