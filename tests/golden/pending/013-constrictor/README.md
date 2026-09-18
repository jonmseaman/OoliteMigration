# Golden scenario `013-constrictor`

The 1.75-era checklist save `upstream/oolite-tests/Checklist-files/Missions/Constrictor.oolite-save`
is loaded through the game's own `-load` argument, the game runs a **fixed tick count** in a
**fixed system** under a **fixed seed**, and the run emits a canonical dump whose `evidence` block
and top-level `mission_variables` prove **this save's mission state** reached the running engine.
Implemented by bead `oo-5h8e`, composing bead `oo-8ij`'s save-load scenario `006` (the `-load`
route), bead `oo-jor`'s scenario `001` (layout, populator suppression, at-rest assertion) and bead
`oo-gxp`'s scenario `010` (evidence design, the independent witness, the frame asymmetry).

> **This directory is `tests/golden/pending/`, not `tests/golden/scenarios/`, and the golden is
> here rather than under `goldens/`.** Both are guarded: `tools/guardrails.sh` refuses *any* change
> under them — including a brand-new file — without a matching line in
> `tools/rebless-approvals.txt`, which only Jon may add, in a separate commit. See
> [LANDING.md](LANDING.md).

```bash
export PATH=/ucrt64/bin:$PATH      # else the loader kills oolite.exe with 3221225781, no log

bash tests/golden/scenario_013.sh --check          # one run, ~25-37 s
bash tests/golden/scenario_013.sh --stability 10   # 10 runs, REFUSED vs DIFFERED reported apart
bash tests/golden/scenario_013.sh --differential   # the two control arms
python3 -m pytest tests/golden/test_constrictor_save.py -q   # offline, no game
```

## What is pinned

| knob | value | where |
|---|---|---|
| seed | `20260918` → `OO_RANDOM_SEED` | `spec.json`, exported by `console.py::_env` |
| system | ID `240` (Esgebi), **asserted** | `spec.json`, checked in `run()` |
| ticks | `24` × `0.125 s` = 3.0 s of **game** time | `spec.json`, `run_ticks()` |
| save | `Checklist-files/Missions/Constrictor.oolite-save`, 25 826 bytes, `written_by_version 1.75` | `spec.json` |
| quantisation | 3 decimals | policy; `golden_diff.py` refuses anything else |
| control save | `ThargoidPlans.oolite-save` | `spec.json` |

Every one of those knobs is **read by `constrictor_save.py`** (asserted on the source by
`test_every_determinism_knob_is_actually_read_by_the_script`) and every one is **equal to the value
recorded in `provenance.json → scenario_knobs`** (asserted by
`test_spec_knobs_equal_the_knobs_the_golden_was_blessed_with`). A knob a fresh-run-vs-golden
comparison cannot see — the seed is the classic case, because changing it changes *both* sides — is
pinned against provenance instead (bead `oo-3ya`).

The tick budget is measured on `clock.absoluteSeconds` **inside the game**, never on the harness
clock, so the dump does not depend on how loaded this box is.

## The finding: this save is *pre*-mission, so `mission_conhunt` is legitimately ABSENT

The bead asks for `mission_conhunt` in the dump. Measured in a running game with this save loaded:

```
missionVariables = {"CT_thargonCount":0,"snoopers_CRCNews":"|",
                    "snoopers_usedSlots":0,"trumbles":"NOT_NOW"}
typeof missionVariables.conhunt = "object"      (null — not set)
```

That is not a load failure. `oolite-constrictor-hunt-mission.js:117` sets
`missionVariables.conhunt = "STAGE_1"` only when

```js
galaxyNumber < 2 && !missionVariables.conhunt && player.score > 255
```

and this commander's `ship_kills` is **exactly 255**. The fixture is the state *one kill before*
the Constrictor hunt is offered. Three of the five checklist saves (CloakingDevice, Nova,
ThargoidPlans) carry `mission_conhunt = MISSION_COMPLETE`; Constrictor and Trumbles do not. So the
honest value is "absent", it is recorded as `mission_conhunt: null` with
`mission_conhunt_present: false`, and it is asserted as such — including a test on the **fixture**
itself, so if upstream ever changes the save this goes red and demands re-measurement rather than
drifting.

## Anti-vacuity: why a dead run, a wrong-save run and a fresh game all fail

A save-load golden that only proves "a game started" is worthless: a default new commander with no
mission satisfies it. **Absence of a field would be an equally weak assertion on its own** — a
fresh game is also absent. So it is required *together with* the behavioural consequence.

`oolite-constrictor-hunt-mission.js` deletes its own three event handlers in `_cleanUp()` (`:35-41`)
as soon as `conhunt === "MISSION_COMPLETE"` (`startUp`, `:48-51`). Measured on this box, three
arms of the **identical** scenario:

| arm | commander | system | `mission_conhunt` | mission vars | live handlers | script loaded |
|---|---|---|---|---|---|---|
| **subject** `Constrictor` | `Constrictor` | Esgebi (240) | *absent* | 4 | **3** | yes |
| control `ThargoidPlans` | `ThargoidPlans` | Quedle (147) | `MISSION_COMPLETE` | 5 | **0** | yes |
| control *no `-load`* | `Jameson` | Lave (7) | *absent* | **0** | **0** | **no** |

`live_mission_handlers` is a `typeof` read off a **live JS object inside the running engine**, not
a field copied out of the file. So the conjunction

> commander `Constrictor` **and** system Esgebi/240 **and** galaxy 1 **and** score exactly 255
> **and** exactly those four mission variables **and** `conhunt` absent **and**
> `oolite-constrictor-hunt` loaded with all three handlers still live **and** the player clock at
> or past `ship_clock` **and** `written_by_version == "1.75"`

is a signature **no other checklist save and no default new game produces**. The evidence checker
enforces every clause, and `tests/golden/test_constrictor_save.py` runs 13 data mutants proving
each clause is load-bearing.

### The differential, measured

`scenario_013.sh --differential`:

* **Constrictor vs ThargoidPlans — 7 of 8 mission-state fields MOVED**, including
  `mission_conhunt: None → 'MISSION_COMPLETE'`, `mission_conhunt_present: False → True`,
  `live_mission_handlers: ['guiScreenChanged','missionScreenOpportunity','systemWillPopulate'] → []`,
  `mission_variable_names` gaining `conhunt`.
* **Constrictor vs a fresh game — 6 of 8 MOVED**, including `mission_variable_names: 4 names → []`
  and `mission_script_loaded: True → False`. (`mission_conhunt` itself does *not* move here, which
  is exactly why the handler read is required alongside it — and why absence alone would be an
  insufficient assertion.)

Both control dumps are **REJECTED** by `check_constrictor_evidence.py` with rc=1, naming the
fields; the subject passes with rc=0.

## The frame, and the deliberate asymmetry

A 64×64 average-pooled luminance grid of the docked status screen is stored **beside** the dump as
`frame.grid` (4096 raw bytes), never inside it, and compared with the tolerance bead `oo-ae9`
**measured** (`frame_hash.derive_tolerance()` = 0.004377).

| pair | distance | ratio |
|---|---|---|
| two launches of the same scenario | 0.001534 | **0.35×** (within) |
| subject vs the ThargoidPlans control | 0.017065 | **3.90×** (beyond) |
| subject vs a fresh game | 0.062845 | **14.36×** (beyond) |

llvmpipe is not bit-reproducible across runs, so **the grid is never byte-hashed** — doing so makes
the gate flake on renderer noise instead of catching a real change. The **dump** *is* byte-hashed,
and its `sha256` and byte count live in `provenance.json`.

## The independent witness

Bead `oo-gxp` found that perturbing `state.json` by one quantised unit left its comparison line
**green**, because the line compared the stored golden against *a copy of itself*: mutating the
golden moves both sides. The fix, adopted here: `provenance.json → artifacts["state.json"]` records
the golden's `sha256` and `bytes`, and an acceptance line verifies them. Provenance is a **separate
file the mutant does not touch**, so a one-unit edit to the golden is detected by a byte-count and
digest mismatch. The same record exists for `frame.grid`, annotated as *not* a gate (it is the
provenance of what was blessed, and the grid is compared by tolerance).

The stronger mutant is a **laundered re-bless** that edits the golden *and* its provenance
consistently. That one is killed by content: `check_constrictor_evidence.py` holds the mission
values as constants in a **third** file, so a consistent re-bless of the golden pair still has to
carry `Constrictor`/Esgebi/240/4-mission-variables/3-live-handlers or the checker goes red.

## Files

| file | role |
|---|---|
| `tests/golden/constrictor_save.py` | the scenario: launch with `-load`, assert, dump, capture the frame; also the two control arms and `--compare-frame` |
| `tests/golden/check_constrictor_evidence.py` | the mission-state evidence checker (rc 0/1/2) |
| `tests/golden/test_constrictor_save.py` | offline falsifiability: data mutants + checker mutants + knob/provenance pins |
| `tests/golden/scenario_013.sh` | `--check`, `--stability N`, `--differential` |
| `tests/golden/pending/013-constrictor/spec.json` | the pinned knobs and the measured expectations |
| `tests/golden/pending/013-constrictor/state.json` | the blessed canonical dump |
| `tests/golden/pending/013-constrictor/frame.grid` | the blessed reference frame grid |
| `tests/golden/pending/013-constrictor/provenance.json` | the independent witness |

## Mutation campaign (final)

`bash tests/golden/pending/013-constrictor/mutate.sh` - every mutant is written to a THROWAWAY
COPY under `$LOCALAPPDATA/Temp`, and each is judged by replaying the ENTIRE stored acceptance
block (line 9 excluded only because it launches the game).

**23 killed / 24. The one survivor is deliberate.**

Judging a mutant by the single line its author expected to catch it is the wrong question - the
gate is the block. Three mutants first scored as survivors under per-line judging turned out to be
killed by a *different* line (M19 by line 4, M22 by line 2, M23 by line 6).

The surviving mutant removes BOTH halves of the subject/golden agreement pair
(`gate_013_differential.py` and `test_constrictor_save.py::test_the_differential_subject_is_the_blessed_golden`)
and then desynchronises provenance. It survives because no defence remains - this is the honest
floor of the campaign, recorded rather than hidden. Removing *either* half alone is killed by the
other; that second witness was added *because* the campaign found the single-witness version blind.
