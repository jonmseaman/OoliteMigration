# Scenario 017 — load the 1.75-era `ThargoidPlans` checklist save

Bead **oo-zyj1**. Scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame hash,
blessed under the golden policy, 10-run stability) starting from
`upstream/oolite-tests/Checklist-files/Missions/ThargoidPlans.oolite-save`, loaded through the
game's own `-load` argument. Written as a sibling of scenario 015 (bead oo-hv4d, the Trumbles
fixture), which is the exemplar to read first.

Everything below was **measured on this box**. Where a measurement contradicted the design, the
design changed — twice, and both are recorded rather than quietly fixed.

---

## 1. The fixture

| field | value |
| --- | --- |
| `written_by_version` | `1.75` |
| bytes | 25976 |
| commander | `ThargoidPlans` |
| system | Quedle — **ID 147**, measured live (the save stores only the name) |
| galaxy (`galaxy_number`) | 1 |
| `ship_kills` | **1281** — one over the Thargoid Plans threshold of 1280 |
| credits (plist, decicredits) | 994547 |
| mission variables | five, **all non-empty** |

```
mission_CT_thargonCount     '0'
mission_conhunt             'MISSION_COMPLETE'
mission_snoopers_CRCNews    '|'
mission_snoopers_usedSlots  '0'
mission_trumbles            'NOT_NOW'
```

---

## 2. The mission variable assertion is a **map**, and that is a measurement, not a preference

Scenario 015's fixture holds `mission_trumbles` as the **empty string**, and an *absent* mission
variable reads identically to an empty one over the JS bridge — so that scenario could assert only
a **key set**: presence, never value.

**This fixture was checked before the assertion was designed.** Every one of its five values is a
non-empty string, so scenario 017 asserts the whole **key → value map**. That is strictly
stronger: a key set is satisfied by any save carrying the same five names, whereas the map pins
`conhunt == MISSION_COMPLETE` — the flag that *arms* the Thargoid Plans mission and the one value
no other checklist save has.

The strength is guarded from erosion in three places:

* `saved_mission_variables()` **refuses** (rc=2) if a future fixture ever carries an empty value,
  rather than keeping a value assertion that cannot fail;
* `gate_017_spec.py` fails if any expected value is `""`;
* `test_thargoid_plans_load.py` proves the refusal fires, using the **real sibling Trumbles save**
  as the input — a real file, not a synthetic one.

---

## 3. `mission_thargplans` is **not in this file**, and the first design was wrong about why

The bead's prose names `mission_thargplans`. It is **absent**: the fixture sits *before* the
mission starts. `oolite-thargoid-plans-mission.js:77-90` arms the first briefing on

```js
!missionVariables.thargplans && missionVariables.conhunt === "MISSION_COMPLETE"
    && player.score > 1280 && galaxyNumber === 2 && system.ID !== 83
```

**Four of those five clauses hold. The fifth does not.**

A first draft asserted `galaxy_is_two: true`, reasoning that the plist's `galaxy_number` of 1 was
0-based and JS was 1-based. **The live run returned `false`.** `OOJSGlobal.m:190-191` resolves
`galaxyNumber` to `[player currentGalaxyID]` — the *same* 0-based index the plist stores. So the
save is in galaxy 1 while the mission runs in galaxy 2. The fixture carries `EQ_GAL_DRIVE` and
`has_galactic_hyperdrive`: it is positioned **one galactic jump short** of the mission, which is
exactly the step the checklist asks a human tester to perform.

The assertion was corrected to the measurement, not the other way round. The scenario records the
clause map **including the false clause**:

```json
{"conhunt_complete": true, "galaxy_is_two": false, "has_galactic_hyperdrive": true,
 "not_in_system_83": true, "score_over_1280": true, "thargplans_unset": true}
```

An engine that moved the fixture's galaxy, cleared `conhunt`, or rounded the kill score across
1280 now goes red **by clause name**. `gate_017_spec.py` additionally fails an *all-true* map,
because that is what the discredited assumption looks like if it ever comes back.

---

## 4. The 1.75 save-format contract: a **real migration**, found by running it

The bead says this scenario "pins the save-format compatibility contract". It turned out to pin a
concrete, currently-live migration.

**How it was found.** The first otherwise-green run failed:

```
CENSUS DIFFERS: credits: 99454.7 (saved) != 100354.7 (loaded)
```

A delta of exactly 9000 plist units, and the run's own log named the cause:

```
[load.upgrade.replacedEnergyBomb]: Compensated legacy energy bomb with 900 credits.
```

**What it is.** `PlayerEntity.m:1731-1746`. The save carries `has_energy_bomb` and
`EQ_ENERGY_BOMB` — equipment that no longer exists. The loader tries to mount an `EQ_QC_MINE` in
its place and, failing that (all four of this commander's pylons already hold
`EQ_HARDENED_MISSILE`), does `credits += 9000` — 9000 **deci**credits, 900 credits — and logs it.

**How it is handled, and what was rejected.** The delta is declared in `spec.load_migrations` and
added by `apply_load_migrations()` **to the file side**, so the round trip stays an **exact
equality**. Widening `credits` to a tolerance was rejected: a 900-credit tolerance would hide any
credit bug smaller than 900 credits, which is most of them.

**Why it cannot become a fudge factor.** The engine's own log line is required as evidence
(`evidence.load_upgrade_messages`). The version string alone is *copied out of the plist by the
harness*; this line is emitted by the loader **actually performing the migration**. A loader that
stopped migrating goes red on `credits` **and** on the missing line that names why.

The engine's 9000 is pinned in **two** files — `spec.json` and `provenance.json` — and
`test_gate_017_spec.py` measured that: removing only the spec-side predicate left the input still
rejected by the provenance-side one. That MISKILL is recorded in the test rather than papered
over; the mutant removes both, which is what it takes to make a wrong delta pass.

---

## 5. Determinism: 10 runs, all ten identical

```
runs 10 · dumps_written 10 · refused 0 · errored 0
distinct dump digests: 1  (a57b51d9…, 3085 bytes)
distinct frame grid digests: 10
wall seconds 10.8 … 11.5
```

`dumps_written + refused == runs`, `errored == 0`, exactly one dump digest. The blessed
`state.json` is byte-identical to all ten sweep dumps.

The ten *frame* grids are all distinct, as expected — llvmpipe is not bit-reproducible. **The
frame is never byte-hashed into a verdict.** The dump is hashed byte-wise because it is quantised
and deterministic; the frame is not. The asymmetry is deliberate and stated in `provenance.json`.

---

## 6. The frame: tolerance **asserted** here, unlike scenario 015

| measurement | value | × tolerance |
| --- | --- | --- |
| 45 same-scene pairs over the 10-run sweep | 0.001367 – 0.001545 | 0.31× – 0.35× |
| a **different** scene (scenario 015's blessed Lave frame) | 0.025080 – 0.025224 | 5.7× |
| an all-black frame | 0.052149 – 0.052251 | 11.9× |
| an all-white frame | 0.947749 | 216× |

Tolerance = 0.004377 from `frame_hash.derive_tolerance()` over `calibration.json`, **used as
measured, never adjusted to make a run pass**.

**Separation ratio = min(wrong-scene) / max(same-scene) = 16.2.** Scenario 015 measured **0.25** on
an animated scene — its `-drawTrumbles:` HUD redraws a live population every frame — and correctly
asserted *liveness only*. This scenario's docked scene is static, the signal is 16× the noise, so
the tolerance **is** asserted, alongside liveness. Two scenarios, opposite verdicts, reached the
same way: by measuring first.

Liveness is asserted **in addition**, not instead: a frame can sit within tolerance of a reference
that was itself black, so liveness is checked against an absolute (floor 0.020, cleared by 2.6×).

---

## 7. Anti-vacuity: what a fresh commander cannot produce

A run that ignored `-load` still starts, answers every JS probe, exits 0 and writes a clean log
(bead oo-het caught seven expansions that way). Every check is **positive**:

1. **`evidence.load_stages`** — the engine's own 14-stage trace, logged only inside
   `-loadPlayerFromFile:`. A run that never loaded emits **none**; a load that died partway emits a
   **prefix**. Held by three clauses in the checker, and
   `test_removing_every_load_stage_clause_lets_a_dead_run_through` proves all three are
   load-bearing by cutting them all out of a throwaway copy and watching a dead-run dump be
   **accepted** (rc=0).
2. **`evidence.mission_variables`** — the five-entry map. A fresh commander's dictionary is empty
   (`PlayerEntity.m:1986-1987`).
3. **`evidence.load_upgrade_messages`** — the migration above, emitted by the loader.
4. **`census`** — 11 fields read from the **file** by Python's plistlib and from the **live game**
   by the JS API, in two OS processes sharing no code.
5. **`evidence.thargplans_preconditions`** — the mission's own arming clauses, read live.
6. **`mission_variables_stable_across_ticks`** — measured before *and* after the tick budget.

### The live red-proof

```
--expect-from …/Trumbles.oolite-save     rc=1 in 11s, no dump written
CENSUS DIFFERS: … player_name: 'Trumbles' (saved) != 'ThargoidPlans' (loaded); …
                credits, current_system_name, galaxy_number, max_cargo, missiles, ship_kills
```

The game loads ThargoidPlans while the harness expects a **sibling checklist save's** census. Seven
of eleven fields disagree, the run refuses, and **no dump is written**. The census is a real
observable, not a formality.

---

## 8. Files

| file | what it is |
| --- | --- |
| `tests/golden/thargoid_plans_load.py` | the harness: load, suppress, tick, dump, frame |
| `tests/golden/check_thargoid_plans_evidence.py` | offline evidence checker (rc 0/1/2) |
| `tests/golden/gate_017_spec.py` | knob gate: pinned, read-where-it-acts (AST), agrees with provenance |
| `tests/golden/test_thargoid_plans_load.py` | 46 offline tests, no game |
| `tests/golden/test_gate_017_spec.py` | 33 mutants against the gate |
| `pending/017-thargoid-plans/` | `spec.json`, `state.json`, `frame.grid`, `frame.png`, `provenance.json` |

Artifacts are staged under `tests/golden/pending/` rather than `goldens/` because
`tools/guardrails.sh` refuses **creation** as well as modification under the protected path.
See `LANDING.md` — the move is a pure `git mv`, rehearsed for real.
