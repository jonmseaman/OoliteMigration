# Golden scenarios 18–20

Part of [Phase 0](0-safety-net.md), item 0.4. Defined by bead `oo-9w5`. The exemplar for shape and
anti-vacuity evidence is scenario `001-launch-dock` (bead `oo-jor`,
[`tests/golden/scenarios/001-launch-dock/README.md`](../../tests/golden/scenarios/001-launch-dock/README.md)).

The machine-readable form is [`scenario-catalogue.json`](scenario-catalogue.json), which carries all
twenty scenarios and the full specification of these three. Later beads consume that file; this
document is the argument behind it. The gate is `tools/check-scenario-catalogue.py`.

## The constraint this design is built around

Five beads have already been parked because a scenario was specified that could not be built:
S2/`oo-8wry`, S4/`oo-8c4g`, S5/`oo-on18`, S6/`oo-fjku`, S7/`oo-3roh`, and then S8/`oo-qwk5`, all on
the same root cause. So each scenario below states which observables it needs and whether each
exists **today**, and the gate resolves every one of those claims against artefacts in the tree:
JS members against `oxp-contract/js-api-1.93.json`, log channels against `upstream/oolite/src`,
harness references against the filesystem. A claim that does not resolve fails the gate by name.

What is **not** available, and therefore what no scenario here may rest on:

| Wanted | Why it does not work today | Seam |
|---|---|---|
| A per-ship handle surviving across steps | `countShipsWithRole` cannot distinguish a ship the scenario spawned from one the populator injected — `oo-qwk5` measured `pirate=2` at t=32.2 s with `allShips` going 10 → 14 | `oo-kbqw`, `oo-bdl0` |
| A meaningful `Ship.AIState` | `-setAITo:` substitutes `oolite-nullAI.js` while the player's scripts are not loaded (`ShipEntityAI.m:254-257`); measured permanently `GLOBAL`, zero `setState` hits | `oo-kbqw` |
| ATTACK vs FLEE | `hasHostileTarget` returns YES for both, so the predicate cannot discriminate the two behaviours | `oo-3cvh` |
| A frozen ship under thrust | `velocity` = newtonian + `thrustVector` (`ShipEntity.m:12830-12833`); the JS setter reaches only the first half, `-setTotalVelocity:` is not exposed. Measured: 4 of 6 ships still at 60–97 m/s right after the write, on 3 of 8 runs | none filed |

Every one of these is recorded in the catalogue's `rejected_candidates`, with the observable that is
missing and the bead that would supply it. The gate checks that a rejection naming a blocker names a
**real, still-open** bead — so when a seam closes, the rejection goes red and is re-examined rather
than quietly rotting.

**All three scenarios below avoid those gaps entirely**: 018 and 019 never leave the dock, and 020
suppresses the populator exactly as 001 does. Nothing here needs a new step, a new native property
or a new seam. That is deliberate: a set that is entirely aspirational is decoration.

## 018 · expansion-closure-and-manifestless — *buildable today*

> Two launches of the same build differing only in what is staged: an expansion with a non-empty
> `requires_oxps` loads with its transitive closure and is refused without it, and a manifest-less
> in-tree fixture loads while emitting exactly its two standards errors.

**What it exercises that nothing else does.** Scenarios 007–012 each load exactly **one** in-tree
test-oxp, solo, and pin what its *content* does. None of them stages a dependency **closure**, none
carries a **negative control** in which the same expansion is refused, and none pins the standards
diagnostics of an expansion with no `manifest.plist`. 001–006 stage no expansion at all; 013–017
load saves. The resource-path composition layer is therefore unobserved by any golden.

**Why this is worth a golden, from measurement.** `oo-kcrw` proved the behaviour causally on this
build, two launches differing only in staging:

```
solo:    staged [GNN]           rc=0 10.4s  NOTLOADED — absent from [searchPaths.dumpAll],
                                            "[oxp.requirementMissing]: OXP ... had unmet
                                            requirements and was removed from the loading list"
closure: staged [GNN, Library]  rc=0 14.8s  PASS — named in searchPaths.dumpAll, reached
                                            shipData.load.begin and startup.complete
```

and separately measured the `NOMANIF` state: five in-tree test-oxps ship no `manifest.plist` and
emit **exactly 2** `[oxp-standards.error]` lines each. Both are load-path invariants that the corpus
tooling depends on and that nothing pins.

**Knobs.** seed `20260918`, system 7 (Lave), 8 ticks × 0.125 s, quantisation 3 decimals, standard
save, **no flight** — the populator and the thrust-velocity problem are out of scope by construction.

**Evidence a run must produce** (all five stored *in the dump*, so every future comparison re-checks
them rather than trusting a capture-time assertion): the primary named in `[searchPaths.dumpAll]` of
the closure run; `[oxp.requirementMissing]` present in the control run **and** the primary absent
from its search paths; `[startup.complete]` in **both** runs; exactly 2 standards errors attributed
to the manifest-less fixture by `tools/oxp_load_check.py`; and the exact staged closure list, which
is recomputed and compared at diff time.

Explicitly **not** evidence: exit code 0, absence of `ERROR` lines, the version banner. `oo-het`
captured a real corpse — `exit 87`, a 1476-byte log with the banner and `[process.args]`, zero
`ERROR` lines, nothing loaded — and separately a run that a *sibling worker's* console quit early
with `rc=0` and no errors. This scenario's evidence is therefore a **differential between two runs**,
never an absence in one.

**Observables, all present today**: `searchPaths.dumpAll`, `oxp.requirementMissing`,
`startup.complete`, `oxp-standards.error` (all four resolved in `upstream/oolite/src`),
`tools/oxp_deps.py::closure`, `tools/oxp_load_check.py::NOMANIFEST_RE`, `System.mainStation`,
`Entity.isValid`. **No seam dependency.**

**Cost ≈ 40 s per run** — two docked launches at the measured 10.4 s and 14.8 s plus staging and
dump round trips; independently cross-checked against the 36-group tier run's 18–22 s per group.

**RED means**: the control run naming the primary in its search paths → requirement resolution
stopped enforcing `requires_oxps`, i.e. expansions load with unmet dependencies. A missing
`[oxp.requirementMissing]` → the diagnostic channel died or the refusal moved, and corpus verdicts
become unattributable. A standards-error count ≠ 2 → manifest parsing or the standards channel
changed. Either run lacking `[startup.complete]` → a dead launch; every other signal in it is void.
A recomputed closure differing from the stored one → the run measured a different composition.

## 019 · equipment-and-station-services — *buildable today, and the cheapest of the three*

> Docked at the main station: award, query, damage and remove equipment, and buy one item — pinning
> the equipment registry, the OK/DAMAGED status machine, the station's tech-level-derived pricing
> and the resulting credit balance.

**What it exercises that nothing else does.** Look at what a golden actually stores today
(`tests/golden/dump/dump_state.js`): `entities`, `market`, and a player block of
`credits / legalStatus / score / cargo` plus four ship fields. **There is no equipment anywhere in
any golden.** Scenario 004 is commodities — a different registry, different pricing, a different
storage model. Scenario 003's damage is ship `energy`; equipment damage is a separate state machine
(`EQUIPMENT_OK` → `EQUIPMENT_DAMAGED`) reached by a different call. The component tier cannot see it
at all: its step library exposes role counts and liveness only.

**Why it matters beyond coverage.** Item 0.1 names *equipment ordering* as a prime suspect for
iteration-order non-determinism, the failure class this whole phase opens with. The equipment array
is the only place a golden could ever see that regression, and today nothing looks at it.

**Knobs.** seed `20260918`, system 7 (Lave), 8 ticks × 0.125 s, quantisation 3 decimals, standard
save, **docked throughout** — `undocked_seen` is expected **false** and is recorded as such rather
than omitted. The equipment key is named in the spec, not picked as "whatever was first in a list".

**Evidence a run must produce.** `equipment_count_delta`: the array grows by exactly one and
contains the awarded key — and `Ship.equipment` is **read-only** in the API snapshot, so the harness
physically cannot write it. `status_transition`: `EQUIPMENT_OK` then `EQUIPMENT_DAMAGED`, **both
readings stored**, so a collapsed state machine shows as the same value twice. `duplicate_award_refused`:
`canAwardEquipment` returns **false** for a second award of a non-multiple item — a refusal is
positive evidence that rules are being applied, where a model that accepts every write returns true.
`credits_delta` beside the price the engine computed, so a pricing change makes the two disagree by
name. `tick_budget_met` on `clock.absoluteSeconds`, which only advances while the run loop steps.

Not evidence: exit code, absence of `ERROR`, the banner — and *specifically* not "the equipment
array is non-empty", because the starting ship already carries equipment.

**Observables, all present today**: `Ship.equipment` (read), `awardEquipment`, `canAwardEquipment`,
`equipmentStatus`, `setEquipmentStatus`, `removeEquipment`, `Player.credits`, `PlayerShip.serviceLevel`,
`PlayerShip.docked`, `Station.equipmentPriceFactor`, `Station.equivalentTechLevel`,
`EquipmentInfo.price / techLevel / canBeDamaged`, `Clock.absoluteSeconds`. **No seam dependency.**

**Cost ≈ 22 s per run.** 001 measured 24–32 s *with* a flight, a dock and a frame capture; this is
the same harness minus the flight, floored by the ~13.5 s load and the ~4.1–4.3 s warm-launch figure.

**RED means**: an unchanged array after a successful award → equipment can be bought and silently
not installed. `EQUIPMENT_OK` after a damage write → the status machine collapsed and damaged
equipment keeps working. `canAwardEquipment` true for a duplicate → the refusal branch is gone.
Credits unchanged or moved by the wrong amount → the pricing path is dead or the formula moved.
**The array reordered with the same members → an enumeration-order regression, item 0.1's exact
failure class, which only this scenario is positioned to see.**

## 020 · hud-render-modes — *buildable, pending its own calibration*

> From one fixed camera pose in flight, render the same scene under three HUD modes (`hud.plist`,
> `hud-small.plist`, hidden) and assert the frame hashes agree within mode and differ between modes
> by more than the measured tolerance.

**What it exercises that nothing else does.** `tests/golden/frame_capture.py:apply_pose` begins with
`player.ship.hudHidden = true`, so **no golden in existence renders a HUD**. The GUI tier asserts a
window opened, took input and exited; it never compares what was drawn. The component tier never
looks at a frame. Scenario 003 differs in the *3-D scene*; here the 3-D stimulus is held constant and
only the overlay changes, which is what isolates the HUD path. Every checklist and test-oxp scenario
is a load-time assertion; the HUD runs on every frame of every session and is unobserved.

**Why the technique is ready.** `oo-ae9` measured a real tolerance — noise floor 0.002541, weakest
real signal 0.007541, threshold **0.004377**, a 1.72× margin in each direction, recorded in
`tests/golden/calibration.json`. Scenario 001 consumes only the same-scene half. Nothing exercises
the different-scene half as a standing assertion.

**Knobs.** seed `20260918`, system 7, 16 ticks × 0.125 s, the `ref` pose (`[0,0,0]`, `[1,0,0,0]`),
three modes × two repeats **each from its own game process** (a floor measured by hashing one PNG
twice is zero and proves nothing), 960×720 windowed, `LIBGL_ALWAYS_SOFTWARE=1` + llvmpipe, populator
suppressed via `system.setPopulator(key, null)` as 001 does so no traffic drifts into frame.

**Evidence a run must produce.** `hud_readback` — `player.ship.hud` reads back the requested plist:
an unapplied write yields three renders of the *same* scene, which passes a within-mode check while
measuring nothing, the identical trap `apply_pose` already pays for on the camera. `in_flight` —
`docked` false and `guiScreen` `GUI_SCREEN_MAIN`, because the HUD is not drawn on station screens.
`pose_applied` — position read back within 1.0 m. `frame_bytes` — every PNG above 50 KB, against a
measured 300–343 KB for real captures and ~5 KB for a black frame. `separation` — the worst
within-mode and best between-mode distances are **both stored in the artifact**, so the golden
carries its own discrimination margin and a later run cannot pass by shrinking the stimulus.

Not evidence: exit code, absence of `ERROR`, the banner — and *specifically* not byte-identity, since
the measured `exact_match_rate` is **0.0**.

**The honest risk, stated as a risk.** Nobody has measured whether `hud.plist` and `hud-small.plist`
differ by more than 0.004377 on a 960×720 llvmpipe surface. That threshold was measured for **3-D
scene** changes, and `oo-ae9` found the instrument goes blind on a stimulus that covers few pixels —
a trader at 800 m scored *below* the noise floor. A HUD is a modest, mostly dark fraction of the
frame, so it may or may not clear the bar. The catalogue therefore records
`measurement_risk.required_before_blessing`: run this scenario's own calibration (3 modes × 3
repeats, each in its own process) and store both populations. If they overlap, fall back to the
largest stimulus pair (hidden vs `hud.plist`); if that also overlaps, mark the scenario
**INFEASIBLE at 960×720** and file the finding. **Loosening the tolerance to make it pass is
forbidden** — that is precisely the decoration `oo-ae9`'s threshold work exists to prevent.

This is why 020's status is `buildable-pending-own-calibration` rather than `buildable`: the
machinery exists and resolves today; what is unmeasured is whether the *stimulus* is visible, and
that is a measurement a future implementer must make and report, not a gap in the observables.

**Observables, all present today**: `PlayerShip.hud`, `PlayerShip.hudHidden`, `PlayerShip.docked`,
`Entity.position`, `Entity.orientation`, `System.setPopulator`, `tests/golden/frame_hash.py::frame_hash`,
`tests/golden/frame_capture.py::apply_pose`, `tests/golden/calibration.json`, and both HUD plists.
**No seam dependency.**

**Cost ≈ 170 s per run** — 6 captures at the measured 26–28 s each, every one in its own game
process; the one-off separation calibration adds ~5 min (measured 306.9 s for 11 captures).

**RED means**: a within-mode distance above tolerance → the HUD render became nondeterministic
between processes, or rasteriser noise outgrew the calibration — re-measure the floor first. A
between-mode distance below tolerance → switching the HUD no longer changes what is drawn: dial
definitions are not loading, or the overlay pass was skipped. A `hud` read-back mismatch → the setter
silently failed and the comparison is void. `docked` or `hudHidden` true at capture → no HUD is in
frame regardless of the hashes. A PNG under the byte floor → a black frame; the run is void.

## Why three, and not four or two

The candidates that did **not** survive are in the catalogue with their reasons, because a selection
without its rejections is taste rather than argument. Briefly: an NPC AI-state census would store a
field that is constant by construction (`GLOBAL`), which is a fabricated field, not a measurement; an
attack-versus-flee scenario would go green on either behaviour, since one predicate covers both; a
scenario-scoped survival check needs a handle to the ships it spawned, which is the gap six beads
have already reduced to; and a moving-world golden — the most *valuable* of the four, because 001
pins only 21 float literals that all happen to be exact binary fractions — cannot be built until
something exposes `flightSpeed` or `setTotalVelocity:` to JS. **That last gap has no bead at all.
Filing one is the prerequisite, and it is the highest-value follow-up this analysis produces.**

Three defensible scenarios remain after those exclusions, and all three are buildable with today's
observables. The set is deliberately weighted away from simulated flight, because every unobserved
surface that is *cheap and static* — resource composition, the equipment registry, the HUD overlay —
is worth more per second than another variation on a flight that the populator keeps perturbing.
