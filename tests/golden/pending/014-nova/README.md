# Golden scenario 014-nova

Load `upstream/oolite-tests/Checklist-files/Missions/Nova.oolite-save` through the game's own
`-load` argument, at a fixed seed and a fixed tick count, and compare the loaded world against a
blessed canonical dump and a blessed frame.

Same design as scenario 015-trumbles (bead oo-hv4d), different fixture, different mission variable.
Two things are genuinely different and both were found by measuring rather than by copying.

---

## 1. The fixture is OLDER than the story says, and that is the contract

The bead's story calls `Nova.oolite-save` "a 1.75-era file". Measured with `plistlib`:

| | Trumbles (scenario 015) | Nova (this scenario) |
| --- | --- | --- |
| top-level keys | 52 | 49 |
| `written_by_version` | `"1.75"` | **absent** |
| `current_system_name`, `ship_name`, `entity_personality`, `fuel_charge_rate` | present | **absent** |
| `ootunes_on`, `reducedDetail`, `saved` | absent | **present** |
| `has_energy_bomb` | `false` | **`true`** |

Every Oolite 1.75 save writes `written_by_version`, so its absence places this fixture **before**
that era. The scenario therefore pins a strictly older compatibility contract, and asserts the
expectation as the **empty string** with the reason attached, so that "correcting" it to `"1.75"`
or swapping in a sibling checklist save fails loudly instead of quietly weakening the contract.

### The loader MIGRATES this save, and the migration is asserted twice

`has_energy_bomb` names an item Oolite **removed**. On load, `PlayerEntity.m:1730-1746` tries to
replace it with a Quirium cascade mine, finds all four pylons already holding `EQ_HARDENED_MISSILE`,
and falls through to:

    credits += 9000;   // deci-credits = 900 Cr
    OOLog(@"load.upgrade.replacedEnergyBomb", @"%@", @"Compensated legacy energy bomb with 900 credits.");

Measured live: the plist holds `credits = 933068`, the loaded game reports `93306.8 + 900 =
94206.8`. Two independent witnesses are required to agree:

* the `credits` census field, whose `kind` is `float_tenths_legacy_energy_bomb`, **predicts the
  arithmetic**; and
* `evidence.legacy_upgrades` requires the **engine's own log line** on the `load.upgrade` channel.

An engine that dropped the migration, compensated a different amount, or found a free pylon and
mounted the mine fails both. A checker holding only the number would pass for a coincidence; one
holding only the log line would not notice a changed amount.

---

## 2. Mission variables: presence, value, and a deliberate absence

Measured, this fixture's five mission variables are:

    mission_TL_FOR_EQ_NAVAL_ENERGY_UNIT = '13'
    mission_conhunt                     = 'MISSION_COMPLETE'
    mission_novacount                   = '3'
    mission_thargplans                  = 'MISSION_COMPLETE'
    mission_trumbles                    = 'NOT_NOW'

The bead names `mission_nova` and `mission_novacount`. **`mission_novacount` is present with the
non-empty value `'3'`; `mission_nova` is absent.** Both are asserted, and the asymmetry is the
design:

* **A mission variable that is the empty string reads identically to an absent one.** That is the
  trap scenario 015 was built around - its `mission_trumbles` was `''`, so value-equality would
  have been satisfiable by a game that never heard of the mission, and it had to fall back to a
  key set. So the **key set** is the primary evidence here too: a fresh commander's mission
  variable dictionary is empty (`PlayerEntity.m:1986-1987`), so five keys cannot be faked.
* **This fixture can do better, and does.** `novacount` holds a non-empty value, so it is *also*
  checked by value. A value check is strictly stronger where a value exists and worthless where it
  does not; both are applied where they apply.
* **`mission_nova`'s absence is asserted explicitly.** The nova mission sets it when it runs, so
  its appearance would mean the loaded game is not this save. The bead names it; an unasserted
  mention is how a claim becomes decoration.

The engine strips the `mission_` prefix for JS (`OOJSMissionVariables.m:191-193`), so the plist's
`mission_novacount` is `missionVariables.novacount`.

---

## 3. The determinism findings - two sweeps that were NOT stable, and why

Scenario 015 needs three suppressions. This scenario needs **four**, plus an ordering constraint,
and both were found by reading the dumps that disagreed.

### Finding 1: a rock hermit is a fourth traffic source

The first 10-run sweep gave **four distinct dump digests**:

* 5 runs dumped a two-entity world (Coriolis Station, Rock Hermit);
* 3 dumped a **three**-entity world whose extra entity was
  `{"id": "Mining Transporter", "role": "miner", "velocity": [17.557, -39.661, -24.874]}`;
* 2 **REFUSED** with `1 entity/entities still report motion: Cobra Mark I=254.8750`.

This save's system contains a **Rock Hermit**, and a rock hermit runs `rockHermitAI.plist`, whose
`CHECK_FOR_ROCKS` state calls `scanForRocks` on a 20 s `pauseAI` cycle and `launchMiner` on
`TARGET_FOUND` (`StationEntity.m:1736-1776`). **None of scenario 015's three suppressions touch
that path:** `hasNPCTraffic` gates the ordinary trader schedule, not a station's own AI. Scenario
015 never met this because its save is docked at Lave's main station.

Fix: `suppress_station_ai()` writes `oolite-nullAI.js` to every station and **verifies the
read-back**. Note the engine reports the AI by the name it *resolved* - `setAI("oolite-nullAI.js")`
reads back as `"nullAI.plist"` - so both names are pinned in the spec and a silently-ignored
`setAI` cannot pass.

### Finding 2: every probe that runs before the suppression is a launch window

Even with the AI silenced, a sweep still gave four digests. The census and mission-variable probes
- about fourteen console round trips, several seconds - ran **before** the suppressions. Moving
every probe after all four suppressions took the sweep to **10/10 byte-identical**, and a 30 s
watch with repeated clearing then saw no miner at all. Scenario 010 recorded the same finding for
the same reason.

Both were design defects in *this harness*, not flakiness in the engine. A 2-in-10 or 4-in-10
disagreement in a new gate is almost always an observable the scenario does not control yet.

### The final sweep

10 runs, **10 dumped / 0 refused / 0 errored** (`dumped + refused + errored == runs`), **one**
distinct dump digest, 2893 bytes, 12.0-17.9 s per run. Every run's outcome is in
`provenance.json` under `stability.per_run`.

---

## 4. The frame: asserted here, and its limit stated

Unlike scenario 015, this scenario's frame-vs-reference **tolerance IS asserted**, because the
measurement supports it. All 45 same-scene pairs across the 10-run sweep:

| measurement | value | x tolerance |
| --- | --- | --- |
| same-scene, 45 pairs over 10 runs | 0.001374 .. 0.001628 | 0.31x .. **0.37x** |
| all-black vs blessed scene | 0.051882 | 11.85x |
| all-white vs blessed scene | 0.948025 | 216.58x |

A 2.7x margin, because this scene carries no animated HUD population - scenario 015's live
trumbles *were* the picture, giving it 1.08x..2.49x and forcing `asserted: false` with a reason.

**The limit is recorded rather than implied.** Frames from the pre-fix sweep that carried the extra
Mining Transporter sit at 0.31x..0.36x - *inside* the same-scene band - because that ship is far
off camera. So the frame proves the **render** is the blessed render; the **dump**, not the frame,
carries this scenario's world-state claim. Bead oo-gxp's scenario 010 reached a 261-fold separation
for a change that was on screen; a change off screen has none.

`frame.grid` is **never byte-hashed into a verdict** - llvmpipe is not bit-reproducible, and this
scenario's own sweep produced 10 distinct grid digests over 10 byte-identical dumps. `state.json`
**is** byte-hashed, and its digest and byte size are witnessed by `provenance.json`, a separate
file: a golden cannot witness itself.

---

## Running it

    python3 tests/golden/nova_load.py --census-only          # no game launch
    python3 tests/golden/nova_load.py --audit-exclusions     # every save key the census skips
    python3 tests/golden/nova_load.py --out fresh.json --frame-out fresh.grid
    python3 tests/golden/nova_load.py --stability 10
    python3 tests/golden/nova_load.py --compare-frame fresh.grid <reference>.grid
    python3 tests/golden/check_nova_evidence.py <dump>.json
    python3 tests/golden/gate_014_spec.py
    python3 -m pytest tests/golden/test_nova_load.py -q

`--expect-from <other.oolite-save>` is the detection control: the game still loads this scenario's
save while the expected census is read from a different file, so a correct engine and a correct
comparison **must** report `CENSUS DIFFERS`.
