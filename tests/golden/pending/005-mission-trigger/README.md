# Golden scenario 005 — mission trigger

**A mission script fires from a world-script event, and its variables pin.**

Loading `upstream/oolite-tests/Checklist-files/Missions/CloakingDevice.oolite-save` through the
game's own `-load` argument calls `[UNIVERSE populateNormalSpace]`
(`PlayerEntityLoadSave.m:777`), which fires the **`systemWillPopulate` world-script event**
(`Universe.m:1732-1737`). `oolite-cloaking-device-mission.js:47-103` handles it and, in galaxy 5
with `cloak` unset, does three things inside one `if` block:

| # | consequence | source |
|---|---|---|
| A | `missionVariables.cloakcounter++` | `:62` |
| B | `system.setPopulator("oolite-cloaking-device-mission", ...)` | `:71` |
| C | the callback spawns a cloaked Asp with escorts | `:77-80` |

## The falsifiable core

The fixture holds `cloakcounter = 6` **on disk**; the running engine reads **7**.

A value the deserialiser merely copied would read **6**. Equal values are the *deserialiser-copy
signature*, and excluding it is the entire point of this scenario — so the dump records
`mission_counter_in_file` and `mission_counter_in_engine` as **separate fields**, and the
checker asserts `engine == file + 1` as well as both pinned literals.

6 is also the smallest value that fires the trigger at all: the ambush block is guarded by
`> 6` (`:66`), so the incremented 7 crosses it by exactly one.

## What is measured, and what is deliberately not

**Measured caution on role counts.** `asp-pirate` is *not* mission-exclusive — `shipdata.plist`
gives the ordinary Asp that role, so the ambient populator adds them. A system-wide
`countShipsWithRole('asp-pirate')` was observed at **2, 3 and 4** across ten runs and aborted 2 of
them. The first ten-run stability pass failed 2/10 for exactly this reason. The escorts are now
read off the ambush **leader's own `escortGroup`**, whose size is fixed by `escorts = 2` in the
`asp-cloaked` template, and the second pass was **10/10 byte-identical**. *The flake was in the
gate's choice of observable, not in the engine.*

Only `asp-cloaked` is counted by role, because only this mission's template creates it.

**The frame is not byte-hashed.** llvmpipe is not bit-reproducible, so `frame.grid` is compared
with the tolerance `frame_hash.derive_tolerance()` measured in bead oo-ae9, never byte-for-byte.
`state.json` *is* byte-hashed. The asymmetry is deliberate.

## Files

| file | role |
|---|---|
| `tests/golden/mission_trigger.py` | the scenario: launch, load, clear, tick, dump |
| `tests/golden/check_mission_trigger_evidence.py` | offline: *did a mission script actually fire?* |
| `tests/golden/test_mission_trigger.py` | 47 offline falsifiability tests (21 data mutants, 8 checker mutants) |
| `spec.json` | every determinism knob, each one read by the script |
| `state.json` | the blessed canonical dump (3099 bytes) |
| `frame.grid` | 64×64 luminance grid, tolerance-compared |
| `provenance.json` | the **independent witness**: knobs, digests, controls, stability |
| `acceptance.txt` | the seven executable gate lines |

## Evidence

- **Stability**: 10/10 runs, one digest, 0 flakes (after the observable fix).
- **Differential**: 9/10 trigger fields move against the Constrictor arm, 10/10 against a fresh
  game; the evidence checker rejects both control dumps with rc=1.
- **Frames**: two launches of this scenario differ by 0.34× the tolerance; the Constrictor arm
  sits at 4.08× and a fresh game at 14.66×.

## Why provenance is a separate file

A golden cannot witness itself. Comparing the stored golden against a copy of itself moves *both*
sides when the golden is edited, so a one-quantised-unit perturbation is invisible to it.
`provenance.json` pins `state.json`'s sha256 **and** byte size from outside, and gate line 5
checks them.

`scenario_knobs` exists for the same reason: a fresh-run-vs-golden comparison cannot catch a
changed seed, because the change moves both sides. Gate line 2 asserts `spec.json` still agrees
with the knobs the golden was *blessed* with.
