# Golden scenario 016 — load the 1.75-era `CloakingDevice` checklist save

**The claim, in one sentence.** A save file written by Oolite 1.75 still means *the same commander*
to the modern engine — every observable it carries either survives verbatim or is changed by a
**declared migration** with a pinned destination and a named engine mechanism.

Built the way `tests/golden/scenarios/001/` is built: fixed seed, fixed tick count, a canonical
quantised dump, a frame grid held to a measured tolerance, blessed under the golden policy, and
proven stable over ten runs.

---

## How this differs from scenario 005 — read this first

Bead `oo-rkm`'s scenario **005-mission-trigger** loads **the same fixture**. That is deliberate, and
the two are not duplicates. They assert **disjoint** things about the same 26 KB of bytes:

|                        | **005-mission-trigger**                                   | **016-cloaking-save** (this one)                                |
| ---------------------- | --------------------------------------------------------- | --------------------------------------------------------------- |
| Subject                | the engine **wrote** one thing                             | the engine **preserved** everything else                          |
| Core assertion         | `cloakcounter` 6 → **7** because `systemWillPopulate` ran  | 13/15 census fields + 9/10 mission variables **identical**        |
| Reads                  | one mission variable, the populator key, the spawned ships | 15 census fields, 16 equipment keys, 10 mission variables         |
| `cloakcounter` is…     | the **whole point**                                        | the **one declared exception**, carved out by name                |
| Migrations measured    | none                                                       | **three**, each traced to engine source                           |
| A dead engine…         | fails (counter never moves)                                | fails (nothing to compare)                                        |

**The failures they catch are disjoint in both directions:**

* A load that corrupted `credits`, dropped `EQ_ESCAPE_POD`, regenerated `entity_personality` or
  lost `mission_nova` **still fires the trigger** and **still passes 005**. It fails here.
* A run in which the trigger never fired fails 005. Here it fails too — but as
  `DECLARED BUT ABSENT`, the *other* direction of the closed pair, which is a different clause.

`test_cloaking_load.py::test_scenario_016_asserts_something_scenario_005_does_not` pins this
structurally: 016's declared-write set must be **exactly** `{mission_cloakcounter}` — 005's entire
subject. If that set ever grew, the two beads would have started asserting the same thing, and the
test goes red.

---

## What the scenario does

1. Reads the save **as a file**, with Python's `plistlib`, in this process.
2. Launches the game with the engine's own `-load` argument at a pinned seed, clears every
   non-player ship to a **fixed point**, ticks a fixed 24 × 0.125 s, and settles.
3. Reads the same 15 quantities **as a live commander**, via JS over the debug console, in a
   **different OS process**.
4. Compares the two sides and asserts the **closed pair**: the set of fields that differ must
   **equal** the declared set — no more, and no fewer.

Two independent readers is the point. A single reader comparing a value to itself is a copy, not a
round trip.

---

## The three measured migrations

None of these were anticipated. The first live run exited 1 with
`the live ship is MISSING 1 item(s) the save restored: [EQ_ENERGY_BOMB]`. Chasing that through the
engine source turned up all three. **The assertion was not weakened to accommodate them** — they
were traced, pinned with a destination value, and declared.

| Field | 1.75 file | modern engine | Mechanism |
| ----- | --------- | ------------- | --------- |
| `EQ_ENERGY_BOMB` | present | **removed** | `PlayerEntity.m:1394-1398` — `equipmentTypeWithIdentifier:` returns nil, so the loader drops the key and sets `energyBombCompensation` |
| `credits` | 95622.6 | **96522.6** (+900) | `PlayerEntity.m:1730-1746` — the compensation branch tries to mount an `EQ_QC_MINE` first; all four pylons already carry `EQ_HARDENED_MISSILE`, so it falls through to `credits += 9000` tenths |
| `fuel_charge_rate` | 1.0 | **2.0** | `PlayerEntity.m:13007-13021` — **derived, not restored**. The modern engine never reads the stored key back; it computes the rate from hull mass and scales by state of repair (`ship_trade_in_factor` 85 sits in the 75–90 band) |

The credit delta is not asserted on arithmetic alone. The loader logs
`Compensated legacy energy bomb with 900 credits.` on the `load.upgrade.replacedEnergyBomb`
channel, and the gate requires that line: **+900 without it** would be satisfied equally by a save
whose credits were corrupted by exactly that amount.

`fuel_charge_rate` is the most interesting of the three. A key the 1.75 format stores and the
modern format silently ignores says more about save compatibility than any field that merely
copies — and pinning it means an engine that *started* honouring the stored value again would go
red instead of quietly changing fuel economics.

---

## Design notes worth the reader's time

**Presence is a key set, never a value.** A mission variable that is the empty string reads
*identically* to an absent one. The evidence records
`mission_variable_keys_in_file` / `..._in_engine` as **sets**, so a key the loader dropped is caught
even though a value comparison would see `"" == absent` and pass. A fresh commander has **no**
mission variables at all (`PlayerEntity.m:1986-1987`), which is exactly what makes the ten-key
assertion unsatisfiable by a run that ignored `-load`.

**Equal `cloakcounter` values are a failure, not a success.** If the file says 6 and the engine says
6, the save deserialised and the world-script event never ran — the *deserialiser-copy signature*.
The checker names it and refuses.

**No catch-all conversion.** `_normalise()` is the only place a scale or format mapping is applied,
and an unknown `kind` raises `Refusal` rather than inventing something that would make two sides
agree. The 1.75 weapon IDs are a **declared** integer→equipment-key table, so an upstream
renumbering is a finding rather than a silently absorbed difference.

**Refusal is by identity, not equality.** A mapping always equals itself, so comparing a dict to
itself would pass trivially; `compare_sides` refuses when the two arguments **are** the same object
(the in-memory twin of `golden_diff.py`'s `st_dev`/`st_ino` guard).

**The frame asymmetry is deliberate.** The dump is byte-hashed; `frame.grid` never is. The ten-run
sweep produced **ten distinct frame digests over one dump digest** — llvmpipe is not
bit-reproducible. The frame is instead held to the measured tolerance (0.004377, from bead
`oo-ae9`'s calibration, used as measured and never adjusted) and to a **liveness floor**:

* two launches of this scenario: max **0.00153** (0.35× tolerance) — inside
* the sibling `Trumbles` checklist save: **0.02380** (5.44× tolerance) — outside
* separation ratio **15.6×**, so the tolerance sits cleanly between the populations
* liveness **0.0521** against an all-black grid, floor 0.020 — a run that died before drawing
  scores 0 and is otherwise indistinguishable by exit code

(Contrast scenario 015, where an animated trumble HUD pushed same-scene pairs to 1.08×–2.49× and
the tolerance had to be measured and *rejected*. Same instrument, different verdict, because this
scene has no animated element.)

**Beware the cloak.** Bead `oo-qwk5` measured this ship family flipping `scanClass`
`CLASS_NEUTRAL → CLASS_NO_DRAW` at **t = 21.6 s**, and 005's trigger spawns exactly that ship into
this system on load. This scenario is immune twice over: it clears non-player ships to a fixed
point *before* ticking (one sweep is not enough — removing the Asp runs its `death_actions` and
drops a cargo container), and 24 × 0.125 = **3.0 s** is an order of magnitude short of 21.6 s.
`gate_016_spec.py` enforces that upper bound with the number named, so a future widening of the
tick budget past the cloak goes red.

**A golden cannot witness itself.** `state.json`'s sha256 **and** byte count live in
`provenance.json`, a separate file. A one-quantised-unit edit to the golden moves both sides of any
self-comparison and is otherwise invisible. The **declared-migration sets** are recorded there too
— they are the one place a failing run could be made to pass by widening them, so they are
witnessed from outside the spec.

---

## Stability

10 runs: **10 dumped / 0 refused / 0 errored**, `dumped + refused + errored == runs`, every run
recorded individually in `provenance.json`. One dump digest (5422 bytes), ten frame digests. Wall
12.1–23.3 s.

A refusal is **not** a difference, and the two are recorded separately — collapsing them is how a
stability claim goes dishonest.

---

## Red-proof — both arms live, both timed

| Arm | What it tests | Result |
| --- | --- | --- |
| Wrong save loaded (`--save Trumbles`) | the cheap system pin | refused in **5 s** at system 7 ≠ 80 |
| **Right save, sibling's expectations** (`--expect-from Trumbles`) | the round-trip comparison **itself** | refused after a genuine **17 s** launch, **no dump written** |

The second arm is the sharp one: the game loads the *correct* save, so the system pin cannot be
what fires. The acceptance line asserts the wall time is ≥ 5 s — a line claiming to launch the game
that returns in under a second did not launch it.

---

## Falsifiability

`tests/golden/test_cloaking_load.py` — **45 tests**, each mutating only a throwaway copy under
`tmp_path`. Both directions of the closed pair, the empty-string trap, the deserialiser-copy
signature, a shrunken census, a seed that drifted, a frame digest smuggled into the dump.

Seven of them are **mutants of the checker and the gate themselves**: weaken one clause, feed it
the input that clause exists to reject, and assert the *mutated* validator goes **green**. That is
what proves the kill belongs to that clause and not a neighbour. The suite refuses to report a kill
it did not earn — when the cloak-budget mutant turned out to be redundantly defended by the
knob-drift clause, the test said so, and the arm was reshaped into the **re-bless** case (both
files moved together) where only the cloak clause stands between a maintainer and a transition
inside the measured window.

Baseline first: `test_stored_golden_is_witnessed` proves the artifact passes its own checker, since
a checker that is already red registers a false kill for every mutant run against it.

---

## Files

**Authored (5, within the ≤ 8 budget):**

| File | Lines | Purpose |
| ---- | ----: | ------- |
| `tests/golden/cloaking_load.py` | 1061 | the live harness |
| `tests/golden/check_cloaking_evidence.py` | 259 | offline evidence checker — no game, no network |
| `tests/golden/gate_016_spec.py` | 446 | determinism knobs: pinned, read-where-they-act (AST), agreeing with provenance |
| `tests/golden/test_cloaking_load.py` | 641 | 45-test falsifiability suite |
| `tests/golden/pending/016-cloaking-save/spec.json` | 112 | the scenario contract |

**Data (not authored files):** `state.json`, `frame.grid`, `provenance.json`, `acceptance.txt` —
blessed run artifacts and the stored acceptance commands.

Nothing under `goldens/` was touched. Landing is a pure `git mv`: `spec.json` resolves
`tests/golden/scenarios/` first then `pending/`; the artifacts resolve `goldens/windows-x64/` first
then `pending/`.

---

## Running it

```bash
export PATH="/ucrt64/bin:$PATH"          # without this the game dies 0xC0000135 after ~117s

python3 tests/golden/cloaking_load.py --census-only     # file side only, no game
python3 tests/golden/gate_016_spec.py                   # knobs
python3 -m pytest tests/golden/test_cloaking_load.py -q # 45 falsifiability tests
python3 tests/golden/cloaking_load.py                   # live run, ~12-24s
python3 tests/golden/cloaking_load.py --stability 10    # the sweep
```

The seven executable acceptance commands are stored on the bead and mirrored in `acceptance.txt`.
They were rehearsed exactly as `accept.sh` runs them — detached checkout, merge,
`bash -o pipefail -c` per line — which is how three real defects in them were found and fixed
before storing: a cross-check naming an evidence field the dump does not carry, a second naming a
dict shape the harness never produces, and two live lines that failed on **console contention**
(the identical command was green in 12 s moments later with five other game instances on the box).
The live lines now retry **only `rc=3`**, the no-verdict exception arm — `rc=1`/`rc=2` are
verdicts, and retrying a verdict until it comes out green is how a gate becomes decoration.
