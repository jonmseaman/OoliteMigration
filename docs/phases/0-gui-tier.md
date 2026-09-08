# Phase 0 — GUI smoke-test tier (PyAutoGUI)

Part of [Phase 0](0-safety-net.md), item 0.8. Kept separate because it is the most concrete
specification in the project and the **calibration exemplar** for story grain: G1 is a seam
(scores 5/7 on the sizing rule, failing only "no new interfaces" and "names an exemplar"), and
G2–G9 are its replications. The hand-written [G1 story](../stories/G1-exit-via-mouse.md) is the
reference for what a fleet-ready story looks like.

A second, separate test tier that drives the game through **real OS-level mouse and keyboard input
against a real window**.

## Why this exists alongside the golden harness

The two tiers test disjoint things, and the boundary must stay sharp:

| | Golden harness (Phase 0 item 0.4) | PyAutoGUI tier |
|---|---|---|
| Driven via | Debug-console TCP, JS commands | Synthetic OS input events |
| Window | **None** — `SDL_VIDEODRIVER=offscreen` | Real, on-screen |
| Tests | Simulation, gameplay, data, OXP behaviour | Launch, window, input path, shutdown |
| Volume | Hundreds of assertions | ~10 smoke tests |

Note the row that matters: `tests/launch_snapshot.py:93` sets `SDL_VIDEODRIVER=offscreen`, so the
existing test never creates a window. The entire windowing, event-loop, and input path is
**currently untested**, and it is exactly the layer that a new platform target breaks. On Apple
Silicon (Phase 3) this tier is the difference between "it compiles and the simulation runs" and
"it is a working macOS application" — it is what catches a missing `.app` bundle, a Gatekeeper
block, a GL context that never gets a drawable, or a window that opens behind the dock.

It also covers what the console path structurally cannot: the debug console injects commands
*inside* the game, bypassing SDL entirely, so it can never prove that a keypress or a click reaches
the game at all.

## Locating UI elements: compute, don't image-match

`pyautogui.locateOnScreen()` with reference screenshots is the obvious approach and the wrong one
here — it is resolution-dependent, theme-dependent, and breaks on every HUD tweak.

Oolite's GUI is a **fixed virtual grid**, so coordinates can be computed exactly
(`src/Core/GuiDisplayGen.h:34-43`):

```
MAIN_GUI_PIXEL_WIDTH/HEIGHT  480 × 480     GUI_DEFAULT_ROWS  30
MAIN_GUI_ROW_HEIGHT          16            MAIN_GUI_PIXEL_ROW_START  40
```

The start screen (`PlayerEntity.m:9900-9960`) lays out six selectable rows, 22–27, centred, with
mouse interaction explicitly enabled:

| Row | Label |
|---:|---|
| 22 | ` Start New Commander ` |
| 23 | ` Load Commander ` |
| 24 | ` View Ship Library ` |
| 25 | ` Game Options ` |
| 26 | ` Manage Expansion Packs ` |
| **27** | **` Exit Game `** |

So a helper resolves `row → screen point` from the window rect and the virtual grid, launched at a
pinned window size. Deterministic, and it survives cosmetic changes. Reserve image matching for the
one thing coordinates cannot give you — "did *something* render" — and do that with the coarse
frame-size check the existing snapshot test already uses.

## How the menu actually works (verified against the source)

Three mechanics that are not what you would guess, and that change how these tests must be written:

**1. A single click selects a row. It does not activate it.**
`PlayerEntityControls.m:763-780` — a left click only calls `setSelectedRow:` on whatever row the
cursor is over. Activation requires **Enter** or a **double-click**
(`n_key_gui_select || gvMouseDoubleClick`, the pattern repeated ~15 times throughout the file).

So "click the Exit button" is two actions: move the selection to row 27, then confirm. A test that
single-clicks ` Exit Game ` and waits will sit on the start screen until it times out.

**2. ` Start New Commander ` does not start a game.** It opens a *scenario* screen
(`GUI_SCREEN_NEWGAME`, `PlayerEntityLoadSave.m:207`) listing four choices from `scenarios.plist`:

| Row | Label |
|---:|---|
| 1 | `Return to Menu` (red) |
| **3** | **`Normal Start`** ← initially selected |
| 4 | `Easy Start` |
| 5 | `Tutorial` |
| 6 | `Strict Mode` |

Reaching the cockpit is therefore: confirm row 22 → confirm row 3.

**3. There is no universal "back" key.** Each screen differs:

| Screen | How you leave it |
|---|---|
| Scenario / New Game | Confirm row 1, `Return to Menu` |
| Ship Library | **Space** (`PlayerEntityControls.m:5033`) |
| Game Options | Select the `Back` row (`GUI_ROW_GAMEOPTIONS_BACK`) and confirm |
| Expansion Manager | Its own in-screen navigation |

That inconsistency is itself worth knowing: per-screen back semantics are exactly the kind of thing
a rewrite silently breaks, and G5 exists to catch it.

**One screen to avoid automating.** ` Load Commander ` sets `disc_operation_in_progress`
(`PlayerEntityControls.m:4949`) and goes into file-dialog territory — OS-native, and a reliable
source of flakes. Cover save/load through the golden harness instead, where it can be tested
properly.

## The tests

`tests/gui/`, pytest + PyAutoGUI. Every test gets a hard timeout with a forced kill, so a hang fails
the run instead of wedging CI.

| # | Test | Steps | What it catches |
|---|---|---|---|
| **G1** | **Exit via mouse** | Launch → click row 27 (` Exit Game `) to select → **double-click** to confirm. Assert: exits within 10 s, code 0, no crash log, no orphaned process. | The baseline. Window opens, mouse input reaches the game, shutdown path works. |
| **G2** | **Exit via keyboard** | Launch → `Down`×5 → `Enter` | Keyboard path independently of mouse — a separate SDL3 code path from G1. |
| **G3** | **Exit via window close** | Launch → close button (⌘Q on macOS via `exitAppCommandQ`, Alt-F4 on Windows) | `SDL_EVENT_QUIT` (`MyOpenGLView.m:2247`) — a genuinely *different* shutdown path from the menu, and the one most likely to leak on a new platform. |
| **G4** | **Start a game** | Launch → confirm row 22 → land on scenario screen → confirm row 3 (`Normal Start`) → wait for the cockpit → assert the HUD renders → exit | The "does the game actually work end-to-end" smoke test. Covers the two-screen flow, not one. |
| **G5** | **Screen round-trips** | Enter and leave each of: Ship Library (row 24, exit with `Space`), Game Options (row 25, exit via its `Back` row), Expansion Manager (row 26). Assert the start screen is reachable again each time. | Screens that crash on entry — a classic rewrite regression. Also pins the per-screen back semantics. Row 26 additionally exercises the network path. Skip row 23 (see above). |
| **G6** | **Window lifecycle** | Resize, minimise/restore, fullscreen toggle | GL context survival. Behaves differently on macOS; `OOGraphicsResetManager` exists for exactly this and is currently untested. |
| **G7** | **First run** | Delete the config/prefs directory → launch → verify defaults are created → exit cleanly | The "works because I already have a config file" bug class. High value on a brand-new platform. |
| **G8** | **Scenario-screen back-out** | Launch → confirm row 22 → confirm row 1 (`Return to Menu`) → verify start screen → exit | Confirms G4's flow is reversible; cheap, and it catches a stuck GUI-state machine. |
| **G9** | **Post-exit hygiene** (asserted after every test above) | No core dump; no `ERROR`/exception lines in `Latest.log`; defaults file written and re-parseable | Silent-failure shutdowns. |

**Scope discipline:** these are smoke tests. They assert *launched / responded / exited cleanly* and
nothing about gameplay state — that belongs to the golden harness, which can assert it far more
precisely and without flakiness. Holding this line is what stops the tier from becoming a
maintenance sink. If a GUI test starts asserting on ship positions, it is in the wrong file.

## Platform and CI notes

| Platform | Approach | Caveat |
|---|---|---|
| **Linux** | `xvfb-run` + `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe` (as `launch_snapshot.py` already does), `DISPLAY` pointed at Xvfb | Works headless on hosted runners. |
| **Windows** | Hosted runners have an interactive desktop session | Works directly. |
| **macOS** | **Needs a self-hosted runner** on Jon's own Apple Silicon machine | ⚠️ PyAutoGUI needs **Accessibility** (to synthesise input) and **Screen Recording** (to screenshot) TCC grants. These are per-app, granted interactively once, and cannot be scripted. Hosted GitHub macOS runners cannot grant them. |

That macOS caveat is worth deciding early rather than discovering at Phase 3: either stand up a
self-hosted runner, or accept that the macOS GUI tier is a local pre-release gate rather than a
per-commit one. The Linux and Windows tiers can run per-commit regardless.

**Audio** should be forced to `SDL_AUDIODRIVER=dummy` / `ALSOFT_DRIVERS=null` as the existing test
does — CI machines have no audio device and OpenAL init failure would otherwise masquerade as a
launch failure.

## When to build it

G1–G4 in Phase 0, against the current Objective-C build, so there is a known-good baseline before
anything changes. G5–G9 can follow. The whole tier becomes load-bearing at **Phase 3**, where it is
the primary evidence that the Apple Silicon build is a real application and not just a binary that
links.
