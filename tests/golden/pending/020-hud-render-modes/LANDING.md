# Landing 020-hud-render-modes into `goldens/`

These artifacts are STAGED, not blessed. `goldens/` is a guarded path: `tools/guardrails.sh`
refuses CREATE as well as MODIFY under it, and blessing is Jon's decision alone. This file is the
procedure for making that decision executable.

**Rehearsal scope — read this before trusting the claim.** The move below is rehearsed on a
throwaway copy under `$LOCALAPPDATA/Temp` by replaying **all four stored acceptance lines** from
the MOVED layout and then again from the STAGED layout, requiring 4/4 `rc=0` in BOTH arms. That
standard exists because of scenario 002's finding: its first LANDING.md claimed "REHEARSED END TO
END" while the rehearsal re-ran only the two gates, leaving the scenario driver — which resolved
`spec.json` from the staged location ONLY — unexercised after the move. Performing the `git mv`
therefore killed three acceptance lines including the non-vacuity arm, i.e. the landing disarmed
the one line proving the gate has teeth. It exists a second time because of scenario 018's
reviewer, who caught line 4 asserting `$D/spec.json` and `$D/LANDING.md` when landing moves the
spec and DELETES LANDING.md. **A rehearsal that runs fewer commands than the acceptance block is
not a rehearsal.**

## What is staged

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus this scenario's own `hud` and `evidence` blocks |
| `frame.grid` | 4096-byte 64x64 luminance grid of the primary mode's frame (`tests/golden/frame_hash.py`) |
| `frame-hud.grid`, `frame-hud-small.grid`, `frame-hidden.grid` | one grid per HUD mode — these are what make the separation claim re-derivable FROM PIXELS rather than from the dump's own numbers |
| `frame.png` | the blessed frame itself, so a human can SEE the HUD the grid was reduced from |
| `spec.json` | every determinism knob the run reads, including the tolerance THIS scenario measured |
| `provenance.json` | how the golden was produced: the blessed knobs, the own-calibration populations, the 10-run sweep run by run, the ambient-traffic finding, both frame claims WITH their measurements, and the artifact digests that witness the files from outside |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/020-hud-render-modes/state.json \
           goldens/windows-x64/020-hud-render-modes/state.json
    git mv tests/golden/pending/020-hud-render-modes/provenance.json \
           goldens/windows-x64/020-hud-render-modes/provenance.json
    git mv tests/golden/pending/020-hud-render-modes/frame.grid \
           goldens/windows-x64/020-hud-render-modes/frame.grid
    git mv tests/golden/pending/020-hud-render-modes/frame-hud.grid \
           goldens/windows-x64/020-hud-render-modes/frame-hud.grid
    git mv tests/golden/pending/020-hud-render-modes/frame-hud-small.grid \
           goldens/windows-x64/020-hud-render-modes/frame-hud-small.grid
    git mv tests/golden/pending/020-hud-render-modes/frame-hidden.grid \
           goldens/windows-x64/020-hud-render-modes/frame-hidden.grid
    git mv tests/golden/pending/020-hud-render-modes/frame.png \
           goldens/windows-x64/020-hud-render-modes/frame.png
    git mv tests/golden/pending/020-hud-render-modes/spec.json \
           goldens/windows-x64/020-hud-render-modes/spec.json

`LANDING.md` and `ACCEPTANCE.txt` are deleted by the same commit.

**No code change is required.** `tests/golden/hud_render_modes.py`,
`check_hud_render_evidence.py`, `gate_020_spec.py`, `test_hud_render_modes.py` and every stored
acceptance line resolve each artifact by searching `goldens/windows-x64/020-hud-render-modes/`
FIRST, `tests/golden/scenarios/020-hud-render-modes/` second and
`tests/golden/pending/020-hud-render-modes/` last. The Python side uses `SPEC_CANDIDATES` /
`GOLDEN_CANDIDATES` / `DIR_CANDIDATES` tuples in that order; the shell side uses the identical
`ls A B C 2>/dev/null | head -1` idiom. **All three positions are searched, so it does not matter
whether the spec lands beside the golden or under `tests/golden/scenarios/`.** That redundancy is
deliberate: scenario 018's reviewer found a line that resolved an artifact one way only.

No stored line references `LANDING.md` or any other file this commit deletes.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit —
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 tests/golden/gate_020_spec.py
    python3 tests/golden/check_hud_render_evidence.py \
        goldens/windows-x64/020-hud-render-modes/state.json
    python3 -m pytest tests/golden/test_hud_render_modes.py -q

then replay the full stored acceptance block (`bd show oo-1bf.7 --json`), which is what the
rehearsal did. Every line is offline; none launches the game.

## What this scenario pins that nothing else does

**No landed golden contains any HUD state at all.** `tests/golden/dump/dump_state.js` emits
`entities`, `market` and a player block; the HUD is not in it. Scenarios 002–019 capture frames,
but every one of them captures the frame as a *by-product* of some other subject — a witchspace
jump, a station service, a staged expansion — and none varies the HUD. This scenario makes the
HUD itself the independent variable: the same 3-D scene, the same pose, the same tick budget,
rendered three times with only the overlay changed.

The shared dump is deliberately NOT modified. It is shared by every landed golden, so a `hud`
block there would move 002–019's stored dumps and turn one new scenario into a re-bless of the
whole suite (scenario 019's finding). Scenario 020 adds its own `hud` and `evidence` blocks to the
state IT dumps, exactly as 015 and 019 do. `gate_020_spec.py::check_no_dump_surgery` and
`test_hud_render_modes.py::test_the_shared_dump_carries_no_hud_state` both assert it stays clean.

## The calibration: what `buildable-pending-own-calibration` asked for, and what it produced

020 is the ONLY scenario in the catalogue with that status. `docs/phases/0-scenarios-18-20.md`
explains why: the shared tolerance `0.004377268476873758` in `tests/golden/calibration.json` was
measured by bead oo-ae9 against **3-D scene changes**, and the same work measured the instrument
going **blind** on a small stimulus (a trader at 800 m scored below the noise floor). A HUD is a
modest, mostly-dark fraction of the frame. Whether it clears the bar was an **open question**, and
the doc is explicit that *loosening the tolerance to make it pass is forbidden*.

It was measured instead — `hud_render_modes.py --calibrate 4`, 12 captures from ONE game process
so the floor carries frame timing and clock state rather than the same PNG hashed twice:

| population | pairs | range |
| --- | --- | --- |
| **within-mode** (same HUD, captured again) | 18 | 0.001592 – **0.002073** |
| **between-mode** (different HUD) | 48 | **0.011000** – 0.022383 |

**Non-overlapping, 5.31x apart.** The tolerance is the geometric mean of the worst within and the
best between — `frame_hash.derive_tolerance`'s own rule, which places it at an equal
*multiplicative* margin (2.30x) from each population:

    within_mode_tolerance = sqrt(0.002073 * 0.011000) = 0.004774962186049237

That it lands near the shared 3-D constant is a **coincidence of this scene**, not an inheritance,
and the two are not equal. `gate_020_spec.py` RE-DERIVES the constant from the stored populations
and fails if they disagree, and separately fails if it ever equals the shared value — so a
hand-edited threshold cannot survive, because the measurements it would have to match are recorded
beside it.

Note the structure inside the between-mode population: `hud` vs `hud-small` (0.0221–0.0224) is
roughly double `hidden` vs `hud-small` (0.0110–0.0112), with `hud` vs `hidden` (0.0169–0.0185) in
between. That ordering is physically sensible — the full HUD covers the most screen, the small HUD
less, hidden none — and it is why the scenario declares three modes rather than two: with a single
pair there is no way to tell "the modes differ" from "this particular pair differs".

## Frame claims: BOTH asserted here, and why that differs from 018

Scenario 018 measured a frame tolerance and **deliberately did not adopt it**: staged expansions
have no visual consequence from a docked camera, so asserting one would have gated the renderer
rather than the subject. It asserted only a liveness floor.

**Here the opposite holds.** The HUD modes ARE the subject. A scenario about HUD rendering that
declined to assert a frame tolerance would assert nothing about HUD rendering at all. So the
tolerance is asserted in BOTH directions:

* the **same** mode, captured twice, must land **within** tolerance — stability;
* **different** modes must land **beyond** it — distinguishability;
* and the **ratio** between the two populations must clear `min_separation_ratio` (2.0), so the
  margin itself cannot quietly shrink towards the noise while both absolute checks still pass.
  That third clause is the one the falsifiability suite's `_thin_margin` mutant exists to prove
  load-bearing: it constructs a dump where both absolute assertions pass and only the ratio floor
  can object.

Liveness is asserted at a floor of 0.2 against measured spreads of 0.7216–0.7333 on every capture
(an empty render is 0.0) — a vacuity guard, deliberately not tight.

**Frame digests are NOT asserted.** Ten sweep runs produced TEN distinct grid digests, because
llvmpipe is not bit-reproducible (`calibration.json` records `exact_match_rate` 0.0). A digest
equality would flake on renderer noise while saying nothing about whether the HUD modes differ.
They are recorded for audit. The dump is hashed byte-wise because it is quantised and
deterministic; the frame is compared by DISTANCE. The asymmetry is deliberate (bead oo-gxp).

## Stability, and the ambient-traffic finding

Final sweep: **10 runs, 10 dumped, 0 refused, 0 errored**, separation held on every run
(worst within 0.001890, best between 0.011015, weakest run 5.83x). `provenance.json` records it
run by run. A REFUSAL is counted separately from a DIFFERENCE; collapsing the two is how a
stability claim goes dishonest (bead oo-jor).

Getting there produced a real finding, and it is recorded rather than smoothed over.

**An earlier sweep refused 2 of 10 runs (20%)** because non-player ships were in frame at capture
time — one run found 1 ship at the last capture, another found 3 at the FIRST capture, 1.5
game-seconds after a clear that had removed 4. All three JS-reachable traffic sources were already
suppressed (per-station `hasNPCTraffic`, `oolite-populator.systemWillRepopulate`, and the world
emptied to a fixed point).

**The fourth source is in the engine, and no JS write reaches it.** `StationEntity.m:991` gates
the patrol launch on

    if (!((isMainStation && [self hasNPCTraffic]) || hasPatrolShips) || [self launchPatrol] != nil)

so a station carrying `hasPatrolShips` launches patrols with `hasNPCTraffic` **already off** —
unlike the trader and shuttle arms at lines 979 and 967, which that flag does stop.

It cannot be suppressed the way the other three were; it can only be **outlasted**. `_capture_mode`
now clears the system to a fixed point and re-applies the pose immediately before each shutter, and
re-censuses AFTER it, refusing if the frame is not empty within 6 rounds. The world is empty *at
the instant of the snapshot* rather than some seconds earlier — the same discipline the pose
read-back already applies to the camera. After the fix: 10/10 dumped, and every capture reached an
empty frame on attempt 1 (`empty_frame_attempts == [1, 1, 1]` on all ten runs).

**Why this was not absorbed into the tolerance instead.** A ship in frame is a REAL difference
between two captures of the SAME mode. Tolerating it would inflate the within-mode population and
LOOSEN the very threshold this scenario exists to measure — destroying the 5.3x separation that is
the entire point. The check stays at exactly zero ships, and it is asserted PER CAPTURE, because a
run's final census cannot see traffic that was present for one capture and gone by the next, which
is precisely the shape the pre-fix sweep measured.

## What this scenario does NOT claim

The HUD is switched through `player.ship.hud = "<plist>"` and `player.ship.hudHidden`, which is
the JS surface OXPs use. The **keypress** path (`PlayerEntityControls.m`) is not exercised: it is
out of reach of every headless harness in this repository, as scenario 006 found for the save half.

`-switchHudTo:` (`PlayerEntity.m:4537-4542`) **fails silently from JS** — `OOJSPlayerShip.m:921-932`
discards the BOOL. That is why the scenario reads the HUD back after every write and why
`gate_020_spec.py` refuses any mode naming a plist that does not exist on disk: an unresolvable
name would leave the previous HUD rendering while the dump claimed the new one.

The engine's refusal of an unknown plist IS claimed, and it is the scenario's positive
anti-vacuity evidence: writing `oo-1bf7-no-such-hud.plist` must leave `player.ship.hud` reading
the previous plist. A permissive model that stores whatever string it is handed reports the bogus
name back instead. This matters because rc=0 and "no ERROR lines" are both satisfiable by a
corpse — bead oo-het's exit-87 process carried the startup banner and zero ERROR lines. A refusal
is not.
