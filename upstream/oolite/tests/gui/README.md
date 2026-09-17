# GUI test tier

PyAutoGUI smoke tests that drive the game through **real OS-level mouse and keyboard input
against a real window**. Specified in
[`docs/phases/0-gui-tier.md`](../../../../docs/phases/0-gui-tier.md); the seam and exemplar is
[G1](../../../../docs/stories/G1-exit-via-mouse.md).

```bash
tools/gui-tier.sh upstream/oolite/tests/gui/test_g1_exit_via_mouse.py
```

Run it through `tools/gui-tier.sh`, not bare `pytest`. The runner installs
[`requirements.txt`](requirements.txt) — nothing else in the repository does, so without it the
missing-`pyautogui` case is the *expected* case — and exports `OO_GUI_REQUIRE=1`.

**A skip is a silent pass.** On Windows, a missing `pyautogui` is a hard `pytest.fail` naming the
install command, never an `importorskip`. The one legitimate skip is a non-Windows host, where
this tier genuinely does not apply (ADR-0017); `OO_GUI_REQUIRE=1` turns even that into a failure,
so a run that was *supposed* to exercise G1 cannot come back green from the wrong machine.
`tools/setup-windows.sh` installs `pyautogui` too, for a machine set up once up front.

It needs a **real desktop**: logged in, unlocked, and not doing anything else, because the tier
takes the desktop exclusively while it runs ([ADR-0017](../../../../docs/decisions/0017-native-windows-subtree.md)).
That exclusion is `tools/gui-lock`, taken by the session-scoped `desktop_lock` fixture. It runs
in Tier C and nightly, **never per bead**. An RDP disconnect takes the desktop with it.

### The lock is not this tier's private business

**Any tool that launches the game on the interactive desktop must take `tools/gui-lock`** (bug
oo-ccy9). This tier is not the only thing that opens a window: on Windows the console-driven
"headless" launchers are not headless either, because `SDL_VIDEODRIVER=offscreen` is deliberately
left unset there (MSYS2's Mesa ships no EGL, so the offscreen driver cannot create a context — see
`tests/component/console.py::_env`). A JS-API snapshot run that skipped the lock stole the
foreground from a G1 click, once in 35 measured G1 runs on a clean tree.

Python launchers outside this tier take it through `tools/desktop_lock.py`, a thin wrapper that
shells out to the same `tools/gui-lock` with a distinct owner tag (`jsapi`, `smoke`, `component`,
`splashcheck`) so the ownership-checked release can tell them apart. This tier keeps its own
in-fixture implementation, because it must still work with no bash.

Two launchers are exempt, on purpose: `tests/golden/golden_run.py` runs N scenarios concurrently by
design and never needs the foreground, and `tests/component/console.py` is the transport those N
runs share. `tools/check-desktop-lock.sh` enforces the rule and the exemptions, and fails on a new
launcher that is in neither list.

It also needs a built game: by default `upstream/oolite/build/meson_test/oolite.app`, overridden
with `--oolite-app <path>` or `OO_APP_DIR`.

| Variable | Default | What it does |
|---|---:|---|
| `OO_GUI_READY_TIMEOUT` | `180` | How long to wait for `startup.complete` in the game's log. |
| `OO_GUI_SETTLE` | `5` | Seconds for the start screen to draw once the game reports ready. |
| `OO_GUI_LOCK_DIR` | `%LOCALAPPDATA%\Temp\oolite-gui-desktop.lock` | Where the desktop mutex lives. Must match `tools/gui-lock`. |
| `OO_GUI_LOCK_TIMEOUT` | `900` | How long to queue for the desktop. |
| `OO_GUI_LOCK_STALE` | `1800` | Age at which a lock is assumed abandoned and reclaimed. |
| `OO_APP_DIR` | the test build | Which `oolite.app` to drive. |

## What conftest.py gives G2-G9

| Name | Kind | Notes |
|---|---|---|
| `row_to_point(row, client_rect)` | function | Row -> absolute screen point, computed from the window rect and the fixed virtual grid. Raises `ValueError` for a row the cursor clamp cannot reach, rather than silently returning a point that selects its neighbour. |
| `point_to_row(x, y, client_rect)` | function | The inverse, walking the same chain the game does. Lets the maths be tested with no game running. |
| `game` | fixture | One process with a real, pinned window, ready and focused; killed unconditionally on teardown. `game.select_row`, `game.confirm_row`, `game.client_rect`. |
| `desktop_lock` | fixture | Session-scoped, takes `tools/gui-lock`. |
| `assert_clean_exit(output_dir)` | function | G9 hygiene: no crash dump, no `ERROR` in `Latest.log`. |

## Three things that are not what you would guess

**1. A single click selects; it does not activate.** `PlayerEntityControls.m:765-780` - a left
click only calls `setSelectedRow:`. Activation is Enter or a double-click. A test that
single-clicks ` Exit Game ` and waits sits on the start screen until it times out.

**2. The window you first see is not the window you click.** The game creates a surface during
init and re-creates it at the end of startup (`Requested a new surface of ... windowed`), so a
resize applied before `startup.complete` is silently discarded and every early click is dropped.
Readiness is therefore read from the game's own log line, never slept for.

**3. Mesa's software `opengl32.dll` is fatal here.** The component tier stages llvmpipe beside
the binary so a headless VM can render offscreen; with it present the game dies during `initGL`
with `0x80070057` and never opens a window. The `game` fixture moves those DLLs aside for the
duration and puts them back on teardown.
