# Landing 019-equipment-and-station-services into `goldens/`

These artifacts are STAGED, not blessed. `goldens/` is a guarded path: `tools/guardrails.sh`
refuses CREATE as well as MODIFY under it, and blessing is Jon's decision alone. This file is the
procedure for making that decision executable.

**Rehearsal scope — read this before trusting the claim.** The move below is rehearsed in a
detached scratch worktree by replaying **all eight stored acceptance lines** from the MOVED layout
and then again from the STAGED layout, requiring 8/8 `rc=0` in BOTH arms. That standard exists
because of scenario 002's finding: its first LANDING.md claimed "REHEARSED END TO END" while the
rehearsal re-ran only the two gates, leaving the scenario driver — which resolved `spec.json` from
the staged location ONLY — unexercised after the move. Performing the `git mv` therefore killed
three acceptance lines including the non-vacuity arm, i.e. the landing disarmed the one line
proving the gate has teeth. **A rehearsal that runs fewer commands than the acceptance block is
not a rehearsal.**

## What is staged

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus this scenario's own `equipment` and `evidence` blocks |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, so a human can SEE the status screen the grid was reduced from |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced: the blessed knobs, the two 10-run sweeps, both frame claims WITH their measurements, and the artifact digests that witness the files from outside |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/019-equipment-and-station-services/state.json \
           goldens/windows-x64/019-equipment-and-station-services/state.json
    git mv tests/golden/pending/019-equipment-and-station-services/provenance.json \
           goldens/windows-x64/019-equipment-and-station-services/provenance.json
    git mv tests/golden/pending/019-equipment-and-station-services/frame.grid \
           goldens/windows-x64/019-equipment-and-station-services/frame.grid
    git mv tests/golden/pending/019-equipment-and-station-services/frame.png \
           goldens/windows-x64/019-equipment-and-station-services/frame.png
    git mv tests/golden/pending/019-equipment-and-station-services/spec.json \
           goldens/windows-x64/019-equipment-and-station-services/spec.json

`LANDING.md` and `ACCEPTANCE.txt` are deleted by the same commit.

**No code change is required.** `tests/golden/equipment_services.py`,
`check_equipment_evidence.py`, `gate_019_spec.py`, `test_equipment_services.py`,
`test_equipment_checker_mutants.py` and every stored acceptance line resolve each artifact by
searching `goldens/windows-x64/019-equipment-and-station-services/` FIRST and falling back to
`tests/golden/pending/019-equipment-and-station-services/`. The Python side uses
`SPEC_CANDIDATES` / `GOLDEN_CANDIDATES` / `FRAME_CANDIDATES` / `PROVENANCE_CANDIDATES` tuples in
that order; the shell side uses the identical `ls A B 2>/dev/null | head -1` idiom. That is the
shape scenarios 010, 012 and 015 use, deliberately.

Note `spec.json` moves NEXT TO the golden rather than to `tests/golden/scenarios/`. Both
destinations are searched (`goldens/windows-x64/<id>/spec.json` first,
`tests/golden/scenarios/<id>/spec.json` second), so either choice works; keeping the spec beside
the artifacts it blessed is what `provenance.json`'s drift check is comparing against.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit —
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 tests/golden/gate_019_spec.py
    python3 tests/golden/check_equipment_evidence.py \
        goldens/windows-x64/019-equipment-and-station-services/state.json
    python3 -m pytest tests/golden/test_equipment_services.py \
                      tests/golden/test_equipment_checker_mutants.py -q

then replay the full stored acceptance block (`bd show oo-1bf.6 --json`), which is what the
rehearsal did.

## What this scenario pins that nothing else does

`tests/golden/dump/dump_state.js` emits `entities`, `market` and a player block of
`credits / legalStatus / score / cargo` plus four ship fields. **There is no equipment anywhere in
any landed golden.** Scenario 004 is commodities — a different registry, different pricing, a
different storage model. Scenario 003's damage is ship `energy`; equipment damage is a separate
state machine reached by a different call. The component tier sees role counts and liveness only.

The shared dump is deliberately NOT modified to add equipment: it is shared by every landed
golden, so an equipment block there would move 002–017's stored dumps and turn one new scenario
into a re-bless of the whole suite. Scenario 019 adds its own `equipment` and `evidence` blocks to
the state IT dumps, exactly as 015 does. `gate_019_spec.py` and
`test_equipment_services.py::test_the_shared_dump_state_js_carries_no_equipment` both assert the
shared dump stays clean.

`evidence.registry_order` stores the equipment registry's ENTIRE ORDERED KEY LIST (41 entries on
this build). Item 0.1 names equipment ordering as a prime suspect for iteration-order
non-determinism; this is the only artifact in the repository that pins it. A reordering with the
same members changes this dump and nothing else in the suite.

## What this scenario does NOT claim

The GUI purchase path was **not** exercised. `-buySelectedItem` (PlayerEntity.m:10174) is
reachable only from the equip-ship screen via `PlayerEntityControls.m`, i.e. a KEYPRESS, which is
out of reach of every headless harness in this repository (scenario 006's finding for the save
half, applied here). The purchase is modelled the way every OXP models it: the harness debits
`player.credits` by `price * equipmentPriceFactor`, where BOTH multiplicands come from the engine
— `EquipmentInfo.price` out of the loaded registry and `equipmentPriceFactor` off the station's
own shipdata. All five numbers (`credits_before`, `purchase_price`, `equipment_price_factor`,
`purchase_charge`, `credits_after`) are stored SEPARATELY so a pricing change disagrees BY NAME
instead of both sides sliding together, and `check_equipment_evidence.py` re-derives the
arithmetic independently of the harness that wrote it.

`player.credits` is topped up to the pinned `credits_start` first because the standard save
carries 100 credits and the item costs 6000. That write is SETUP, not measurement.

## Frame claims: BOTH asserted here, and why that differs from 015

Scenario 015 measured its frame tolerance and **rejected** it: animated trumbles made the
same-scene noise larger than the signal. This scenario measured the same thing and **accepted**
it, because the status screen RENDERS the equipment list. In one process at the same GUI screen,
three frames with no equipment and three after awarding EQ_ECM + EQ_CARGO_BAY + EQ_FUEL_SCOOPS
measured 0.00161–0.00172 WITHIN each group and 0.00509–0.00521 BETWEEN them — non-overlapping
populations straddling the shared derived tolerance 0.004377 at ~2.9x separation. Across all
twenty stability runs (separate processes) same-scene grids differ by at most 0.00174, 0.40x the
tolerance, so it holds across processes too.

Liveness is asserted at a floor of 0.2 against a measured spread of 0.662745 on every one of the
twenty frames (an empty render is 0.0). The frame is never byte-hashed: twenty runs produced
twenty distinct grid digests over twenty BYTE-IDENTICAL dumps, because llvmpipe is not
bit-reproducible. The dump is hashed byte-wise because it is quantised and deterministic. The
asymmetry is deliberate (bead oo-gxp).

## Stability

Two independent 10-run sweeps. Both: 10 dumped, 0 refused, 0 errored, and the SAME single dump
digest `81971b2f273d2a07ea046e75477c456f0bb607f1fca7515462b9d03a9f12990c` across all 20 runs at
4873 bytes each. `provenance.json` records the second sweep run by run. A REFUSAL (the harness
declining to dump an unsettled world) is counted separately from a DIFFERENCE; collapsing the two
is how a stability claim goes dishonest (bead oo-jor).
