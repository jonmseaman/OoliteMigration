# Story: G1 — Exit the game via mouse on the start screen

Hand-written 2026-09-06 as the **calibration exemplar** for story grain. G1 is a *seam*: it fails
sizing checks 5 and 7 because the `row → screen point` helper and the launch/kill fixture do not
exist yet, so it is human + frontier work. Once it lands, G2–G9 are replications that cite this
file as their exemplar and score 7/7. Phase: [0](../phases/0-safety-net.md), item 0.8.
Specification: [0-gui-tier.md](../phases/0-gui-tier.md).

## Task

Add `tests/gui/test_g1_exit_via_mouse.py`: launch the Objective-C build with a real window at a
pinned size, click start-screen row 27 (` Exit Game `) to select it, double-click to confirm, and
assert the process exits within 10 s with code 0, no crash log, and no orphaned process. Provide
the `row → screen point` helper and the launch/kill fixture that G2–G9 will reuse.

**Do it the way `/Users/jonms/OoliteMigration/upstream/oolite/tests/launch_snapshot.py` does it**
for launch, environment, and timeout handling — but with `SDL_VIDEODRIVER` *unset* (real window),
`SDL_AUDIODRIVER=dummy`, and `ALSOFT_DRIVERS=null`.

## Facts the implementation depends on (verified against source)

- GUI is a fixed virtual grid: `MAIN_GUI_PIXEL_WIDTH/HEIGHT 480×480`, `GUI_DEFAULT_ROWS 30`,
  `MAIN_GUI_ROW_HEIGHT 16`, `MAIN_GUI_PIXEL_ROW_START 40` (`src/Core/GuiDisplayGen.h:34-43`).
- Start screen rows 22–27 are selectable; 27 is ` Exit Game ` (`PlayerEntity.m:9900-9960`).
- **A single click selects; it does not activate.** Activation is Enter or double-click
  (`PlayerEntityControls.m:763-780`; `n_key_gui_select || gvMouseDoubleClick`).
- Do not image-match. Compute the point from the window rect and the grid.

## Files

- `upstream/oolite/tests/gui/conftest.py` (new: launch fixture, hard timeout with forced kill, `row_to_point(row)`, the desktop lock)
- `upstream/oolite/tests/gui/test_g1_exit_via_mouse.py` (new)
- `upstream/oolite/tests/gui/requirements.txt` (new: `pytest`, `pyautogui`)

Reads: `tests/launch_snapshot.py` (230 lines), `GuiDisplayGen.h` header block, the two cited
`PlayerEntity*.m` ranges. Under 1,500 lines. Writes: ~150 lines.

## Acceptance (run by the wrapper)

```bash
# nonzero before (file absent), zero after; from the repo root, on the Windows desktop (ADR-0017):
python3 -m pytest upstream/oolite/tests/gui/test_g1_exit_via_mouse.py -x -q
```

Post-exit hygiene (G9) asserted inside the test: no core dump; no `ERROR`/exception lines in
`Latest.log`; defaults file written and re-parseable.

## Prohibitions

- Do not modify anything under `goldens/`.
- Do not modify or delete existing tests, including `tests/launch_snapshot.py`.
- Do not add `-Wno-*` or `#pragma` diagnostic suppressions.
- Do not mark this unit done; the wrapper does.
- Do not read expansion (OXP/OXZ) content.
- Commit only to the worktree branch you were given.

## Carry-over

(empty on first dispatch)

## Sizing check

| # | Check | ✓ |
|---:|---|---|
| 1 | Reads ≤ ~1,500 lines | ✓ |
| 2 | Writes ≤ ~400 lines | ✓ |
| 3 | ≤ 8 files | ✓ |
| 4 | Command-shaped acceptance | ✓ |
| 5 | Zero new interfaces | ✗ — defines `row_to_point` and the fixture (**seam**) |
| 6 | 2–3 sentences | ✓ |
| 7 | Names an exemplar | ✗ — `launch_snapshot.py` is a partial exemplar; the GUI fixture has none (**seam**) |

5/7 → seam. G2–G9 will score 7/7 against this file.
