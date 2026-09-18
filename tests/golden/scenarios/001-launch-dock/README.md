# Golden scenario `001-launch-dock`

The exemplar golden scenario: the player **launches** from the station, the simulation runs for a
**fixed tick count**, the player **docks** again, and the run emits a canonical state dump plus a
frame hash. Implemented by bead `oo-jor` on top of the storage policy from `oo-ss8`
([GOLDEN_STORAGE.md](../../GOLDEN_STORAGE.md)).

```bash
export PATH=/ucrt64/bin:$PATH      # else the loader kills oolite.exe with 3221225781, no log

# one run (~35 s warm)
python3 tests/golden/launch_dock.py --no-snapshot --out /tmp/r1.json

# the offline falsifiability suite (no game, ~2.5 s)
python3 -m pytest tests/golden/test_launch_dock.py -q

# does a dump prove the ship really launched and docked?
python3 tests/golden/check_launch_dock_evidence.py goldens/windows-x64/001-launch-dock/state.json

# a dump against the stored golden
python3 tests/golden/golden_diff.py goldens/windows-x64/001-launch-dock/state.json /tmp/r1.json
```

## What is pinned

| knob | value | where |
|---|---|---|
| seed | `20260918` → `OO_RANDOM_SEED` | `spec.json`, exported by `console.py::_env` |
| system | ID `7` (Lave), **asserted** | `spec.json`, checked by `assert_system()` |
| ticks | `24` × `0.125 s` = 3.0 s of **game** time | `spec.json`, `run_ticks()` |
| quantisation | 3 decimals | policy; `golden_diff.py` refuses anything else |
| save | `Resources/Scenarios/oolite-standard.oolite-save` | `spec.json` |
| pose | position `[0,0,0]`, orientation `[1,0,0,0]` | `spec.json` |

The tick budget is measured on `clock.absoluteSeconds` **inside the game**, never on the harness
clock, so the dump does not depend on how loaded this box is.

## How the scenario proves it really launched and docked

A scenario that crashes on tick 3 and dumps a near-empty world reproduces byte-for-byte perfectly
and proves nothing. So the dump carries an `evidence` block, and the block is **in the stored
golden**, which means every future comparison re-checks it rather than trusting a capture-time
assertion that once passed:

| field | what it means |
|---|---|
| `launch_events` | dispatches of `shipWillLaunchFromStation` (`DockEntity.m:935`) |
| `dock_events` | dispatches of `shipDockedWithStation` (`PlayerEntity.m:7206`) |
| `undocked_seen` | `player.ship.docked` really read **false** between the two docked states |
| `docked_at_start` / `docked_at_end` | the scenario starts and ends docked |
| `tick_budget_met` | the game clock advanced at least the pinned budget |

Both event counters are incremented by handlers the harness **installs but never calls**: the
engine delivers them to a world script via `PlayerEntity.m:12889-12893`. Nothing in the harness
can fake them, which is the point.

## What this golden does **not** pin, and why — read this before trusting a field

**The scenario deliberately dumps the SMALLEST REPRODUCIBLE WORLD**: the system's own fixed
entities (the Coriolis station and the rock hermit, both genuinely at rest) plus the player. No
cast is spawned. That is a design choice with evidence behind it, not a shortcut.

### The populator is switched off at the source

`system.setPopulator(key, null)` deletes a populator setting (`OOJSSystem.m:1311` →
`[UNIVERSE setPopulatorSetting:key to:nil]`); `system.populatorSettings` (`OOJSSystem.m:170`) is
read back afterwards to prove the suppression took. A real run reports
`evidence.populators_suppressed: 36`.

This is done **immediately after launch**, before the flight, because the populator is not merely
untidy: `system_repopulator` (`Universe.m:7101`) keeps adding traffic during the flight, and every
ship it adds consumes RANROT draws. **A fixed `OO_RANDOM_SEED` fixes the sequence, not how far
through it a wall-clock-timed flight has got.** Clearing ships before the dump treats the symptom;
suppressing the populator removes the cause, and makes the flight itself quiet for every scenario
that copies this exemplar.

Measured before the suppression: two runs picked up a `Cobra Mark I` and a `Worm` respectively,
both role `miner`, neither spawned by the scenario. That is bead `oo-qwk5`'s finding exactly — a
scenario asserting on a population the populator also writes to is re-falsifiable by a ship it
never spawned.

### Why no cast is spawned — a ship under thrust cannot be frozen from JS

`spawn_deterministic` gives ships identical **positions** run to run but scattered **velocities**
(12 differing fields across two runs, **no** positions, ids, roles or AI states among them):

```
entities[police-000].velocity[0]:   0.709 != 10.954
entities[pirate-001].velocity[1]:   1.418 != -10.716
```

Writing `velocity = [0,0,0]` does **not** fix it:

```objc
// ShipEntity.m:12830-12833
- (Vector) velocity { return vector_add([super velocity], [self thrustVector]); }
```

The JS setter reaches only the **Newtonian** half; the thrust component (`flightSpeed` along
`v_forward`) survives and reads straight back. `-setTotalVelocity:` would do it but is not exposed
to JS, and `speed` is read-only there. Measured: 4 of 6 ships still reading 60–97 m/s immediately
after the write, on 3 of 8 runs.

An earlier version wrote those zeros anyway, and the golden then carried them **as if measured**.
That is worse than a smaller world: it is a fabricated field in an artefact whose whole purpose is
to be evidence. The scenario now **asserts** the world is at rest and refuses to dump if it is not
(see below). A future scenario that genuinely needs moving NPCs needs a JS seam for `flightSpeed`
first — that gap is real and worth filing.

### `player.ship.position` and `player.ship.velocity` are declared, not measured

The player's velocity is frozen at the instant the docking sequence completes, and that instant
depends on `run_ticks`' 100 ms poll landing a few milliseconds either side of the budget. Measured:
`velocity[2]` at `-164.856` vs `-164.504`, and earlier `-42.968` vs `-38.552`. A probe zeroed it
and watched it grow back to `(0,0,54.784)` at t+1.0 s and `(0,0,110.72)` at t+2.5 s while `speed`
stayed pinned at 175. That is wall-clock frame count, not simulation state, so the scenario writes
the declared pose under the pause. **A test comparing only these two fields would be vacuous.**

**Quantisation was not touched.** None of these divergences is float noise, and coarsening would
have needed whole numbers, which `golden_diff.py` refuses outright. Rounding harder to make a
golden pass is forbidden.

### What IS measured

The entity set (ids, roles, positions, AI states), the station market (17 goods), the player's
ledger (credits, legal status, score, cargo), and the whole evidence block. `golden_diff` compares
the lot and reports any field that moves, by name.

## The guard that refuses to dump an unsettled world

After the pause the scenario asserts two things and **refuses to produce a dump** if either fails:

* the game clock did not advance between the pause and the dump (the world really is frozen);
* no non-player entity reports motion (`velocity.magnitude() > 0.0005`).

A refusal is **the instrument working**, not a flaky test — the same `rc=2 refused` vs
`rc=1 differs` distinction `golden_diff.py` is built on. In a 10-run stability sweep an unsettled
world must make the run decline to bless a dump it knows is frame-dependent, rather than store one
and let a later comparison fail for a reason nobody can attribute. `tools/oo-jor-stability.sh`
reports MATCH / DIFFERS / REFUSED / BROKEN as four separate counts for exactly this reason.

## Two guards that were vacuous and are not any more

Both were caught by mutation, not by reading:

* **`velocity.magnitude` is a function, not a property.** The residual-motion guard compared a JS
  function object with a number — always false — so it passed on runs whose dumps differed by 12
  velocity fields. It is called (`magnitude()`) now, and it fires.
* **`pauseGame()` returns a boolean and can refuse.** `GlobalPauseGame` (`OOJSGlobal.m:831-856`)
  returns `NO` without pausing on the chart, mission, **report**, keyboard-entry and save screens —
  and a docking can leave a report on screen (`PlayerEntity.m:12902`). An unchecked pause turns the
  scenario into a stopwatch. The return value is checked and the game clock is re-read after the
  pause to prove it stopped.

The docking wait learned the same lesson twice: `player.ship.docked` reads true while the break
pattern is still playing (`-enterDock:` sets it at `PlayerEntity.m:7088`), and even
`shipDockedWithStation` fires six lines before `-docked` finishes, so the scenario waits for
`player.ship.status == STATUS_DOCKED`.

## Build flags

`provenance.json` records `build_flags.verified: false` — the shared build was compiled without
`-ffp-contract=off` on all 242 translation units. That is a **known defect owned by bead
`oo-5ggu`**, not a fault of this scenario, and it is recorded honestly rather than papered over.