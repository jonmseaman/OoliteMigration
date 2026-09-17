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
tools/gui-tier.sh upstream/oolite/tests/gui/test_g1_exit_via_mouse.py
```

Run the tier through `tools/gui-tier.sh`, not bare `pytest`. The runner installs
`upstream/oolite/tests/gui/requirements.txt` (which nothing else does) and sets
`OO_GUI_REQUIRE=1`, so a machine that cannot run G1 — wrong platform, or pyautogui missing —
**fails and says what to install** instead of skipping to a green exit 0. A skip is a silent
pass, and this command's whole job is to distinguish "G1 passed" from "G1 never ran".

Post-exit hygiene (G9) asserted inside the test: no core dump; no `ERROR`/exception lines in
`Latest.log`; defaults file written and re-parseable.

### What the command needs, and what it does *not* need (bead oo-0p8f)

`-m offline` is **not** an acceptable substitute for the command above. `@pytest.mark.offline`
covers only the pure-arithmetic tests, so `pytest -q -m offline` deselects
`test_g1_exit_via_mouse` — the entire point of this story — and still reports success. If this
tier's acceptance ever reports "N passed, 1 deselected", it is not gating G1.

The command runs in `accept.sh`'s clean detached checkout, which contains the tests but not
`build/` (gitignored, `upstream/oolite/.gitignore:25`). `conftest._default_app_dir` therefore
falls back to the main checkout's `build/meson_test/oolite.app` via the shared git common dir, so
the real test runs from a worktree rather than being skipped out of the gate. `--oolite-app` and
`$OO_APP_DIR` still override.

It does need the interactive desktop, unlocked and logged in (ADR-0017), and it takes
`tools/gui-lock` for the duration.

### Two environment dependencies that make this fail on some desktops and not others

Both were diagnosed under bead oo-0p8f, after the same code passed for the implementer and failed
for the reviewer at a *correctly computed* coordinate. Neither is flake; both are now asserted
rather than hoped for.

1. **DPI awareness.** Oolite's manifest declares PerMonitorV2
   (`src/SDL/OOResourcesWin/oolite.exe.manifest:34-35`), so its window is in physical pixels. A
   DPI-*unaware* `python.exe` is handed virtualised logical pixels by `GetClientRect`,
   `ClientToScreen` and `SendInput` alike. At 100% scaling the two agree and everything passes;
   above it, every point `row_to_point` computes is off by the scale factor, the confirm click
   misses ` Exit Game `, and the game just keeps running — while the arithmetic tests all still
   pass. `conftest` declares PerMonitorV2 at import and
   `test_test_process_is_dpi_aware_like_the_game` asserts it took.
2. **Foreground ownership.** `SetForegroundWindow` is a request, not a command: Windows refuses it
   from a process that does not already own the foreground, and with
   `SPI_GETFOREGROUNDLOCKTIMEOUT` at `0x7FFFFFFF` (observed on this desktop) the refusal is
   permanent and silent — it returns 0 and flashes the taskbar. Synthetic clicks then go to
   whatever *is* focused, which looks exactly like a coordinate bug. `GameWindow.focus` now
   attaches to the foreground thread's input queue, retries, and **fails the test** if it cannot
   take the foreground; `assert_focused` re-checks immediately before every click.

Also pinned: the confirm double-click's inter-click interval, which must stay under the game's
`MOUSE_DOUBLE_CLICK_INTERVAL` (0.40 s, `MyOpenGLView.h:59`) or
`MyOpenGLView+Input.m:285-293` records two single clicks and never sets `gvMouseDoubleClick` —
the row is selected but never activated.

### The third failure mode: focus is not enough (bead oo-0p8f, attempt 2)

A gating reviewer reproduced the original symptom *after* the two fixes above, with **neither**
cause active: `focus()` returned successfully and `assert_focused()` passed, yet the double-click
still did not activate the row. The missing cause is that **foreground ownership and Z-ORDER are
different things**.

`pyautogui` clicks with `mouse_event` (`_pyautogui_win.py:_click`), which — exactly like a
physical click — is delivered **by position** to the topmost window at that point, *not* to the
foreground window. So a window sitting above the game at the click point swallows the click while
`GetForegroundWindow()` still answers with the game's `hwnd` and `assert_focused()` still passes.

The occluder this tier manufactures for itself is a **leaked `oolite.exe`**. `_pin_window` parks
every instance at exactly (0,0) at the same 960x720 client size, so an orphan covers the next
run's rows pixel for pixel, is the same window class (`SDL_app`), and — being on the start screen
itself — silently consumes the click. Measured directly on this desktop: with an orphan present,
`GetForegroundWindow()` was our `hwnd` while `WindowFromPoint(488,727)` returned the **orphan's**.

Two changes close it:

- `GameWindow.start` now kills the process it launched if any later step raises. Previously the
  fixture's teardown only ran once `yield window.start()` had been reached, so every failure
  inside `start()` — including the new hard failure in `focus()` — leaked a live game. One
  failure therefore poisoned every subsequent run on the machine.
- `assert_click_point_is_ours` checks `WindowFromPoint` before each click, so an occluded click
  point is a named failure instead of a mystery miss.

### When the desktop itself cannot run this tier

An **elevated** window owning the foreground wedges the tier permanently: `AttachThreadInput`
cannot cross the UIPI/integrity boundary, so `focus()`'s retry loop can never succeed. Measured:
an elevated Task Manager (integrity `0x3000` against the test process's `0x2000`) refused
`AttachThreadInput` with `ERROR_ACCESS_DENIED` on 11 consecutive runs, and `taskkill` answered
"Access is denied".

This is reported as its own thing, not as a G1 failure. `conftest.describe_untakeable_foreground`
detects it, `assert_desktop_can_run_gui_tests` fails with the `GUI TIER PRECONDITION FAILED`
marker and names the offending window, and `tools/gui-tier.sh` runs that check **before** it
launches a game, so the cause rather than the symptom lands in the log.

It is a hard failure rather than a skip **on purpose**: the condition is fixable in seconds by
closing the window, and a run that reported success without exercising G1 would be exactly the
vacuous pass bead oo-7by1 removed. What it must never be is indistinguishable from "G1 is
broken" — those two call for opposite responses.

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
