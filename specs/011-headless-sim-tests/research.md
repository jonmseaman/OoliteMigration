# Research: Headless simulation tests

Three read-only surveys of `oolite-dev` on 2026-11-13, at `seriesb/027-modern-cpp` commit
`76e4f8627`, plus spot checks. Paths are relative to `oolite-dev`. Line numbers are from that
commit and will drift.

Spec 003's research (`specs/003-encapsulate-global-state/research.md`, 2026-11-02) covered some of
the same ground against `develop`. Where it still holds it is cited as *003 Rn* and not repeated.

Each item gives the decision, the reason and what else was considered.

## Findings that shape the plan

**Start-up and the frame**

- **One frame is already nearly a function of dt.** `GameController::doPerformGameTick`
  (`src/Core/GameController.cpp:390-422`) measures dt from the steady clock, caps it at 0.25 s,
  then calls `UNIVERSE->update(dt)`, the restart check, `OOSound::update()` and
  `OOJSFrameCallbacksInvoke(dt)`, then draws through a null-guarded `updateScreen`.
  `Universe::update` (`src/Core/Universe.cpp:7427`) is public and takes any dt. Frame callbacks
  are outside it, so a stepper must call them too.
- **Game logic runs on game time.** AI thinking, script timers (driven from
  `PlayerEntity::update`) and the ship clock all use the universe's time.
- **A null view is already accepted.** `Universe` null-checks the view. It fails on OpenGL, not
  on the view. With no view, `getPollControls` skips all input
  (`src/Core/Entities/PlayerEntityControls.cpp:714`).
- **Building a universe needs OpenGL today.** `OOOpenGLExtensionManager::reset` calls
  `glGetString` and raises below GL 3.3. `initTargetFramebufferWithViewSize`
  (`Universe.cpp:11349`) makes about 89 GL calls unguarded. Lighting, the sun colour, the sky,
  the first texture (`OOTexture::checkExtensions`) and `OOTextureLoader::setUp` also call GL.
  Entity `update` code makes no GL calls.
- **Meshes are CPU-side until drawn, materials are not.** `OOMesh::initWithName` binds materials
  at load. With shaders on, GLSL compiles at load. Display lists and texture uploads wait for the
  first draw. Planets create textures and shader materials at once.
- **Sound already degrades to nothing.** If the OpenAL device does not open, `isSoundOK` stays
  false and every sound call is a no-op. `-nosound` forces that.
- **`initWithGameView` boots the whole game and forces add-ons to "all"** (`Universe.cpp:307,
  342`). Strict mode exists (`ResourceManager::setUseAddOns("strict")`,
  `src/Core/ResourceManager.cpp:478-480`) and is overridden.
- **One universe per process**, and the player is never freed (003's findings, unchanged).

**The real clock**

Thirteen places read the real clock on paths that affect game state. The ones a headless game
must own: the frame dt; the ship clock's start (local time of day,
`PlayerEntity.cpp:2555-2566`); the "really random" seed (`Universe.cpp:301`); the RANROT seed when
`OO_RANDOM_SEED` is unset; the start value of frame-callback ids; deferred calls
(`GameController.cpp:150-197`); the GUI-screen time delta that paces menu key repeat
(`PlayerEntityControls.cpp:1948`); the escape-pod double press; the JS time limiter. QuickJS seeds
`Math.random` from the clock inside vendored code, and scripts can read `Date.now`.

**Keys**

- **All input comes through one loop.** `MyOpenGLView::pollControls`
  (`src/SDL/MyOpenGLView+Input.cpp:188`) drains `SDL_PollEvent` in one `switch`. It never checks
  the window id or focus, so an event pushed with `SDL_PushEvent` is handled like a real one.
- **The key is whatever SDL's current keymap says.**
  `key_id = SDL_GetKeyFromScancode(scancode, mod, false)` (`:365`), stored in a `Uint16`. Then
  `keys[key_id] = true` only if `key_id < NUM_KEYS` (327). Special keys are overridden from
  `event.key`.
- **The layout step is inside SDL's video backend.** The Win32, Cocoa, X11 and Wayland backends
  each load the operating system's layout into SDL's keymap. With no real video backend, SDL uses
  its built-in US map. A headless test therefore cannot reach the operating system's layout
  translation. It can reach everything the game does with the result.
- **A control fires only on an exact match.** `checkKeyPress` (`PlayerEntityControls.cpp:667-700`)
  needs the key down and shift, ctrl and alt all equal to the setting. `n` is *activate
  equipment* in all 16 layout sections of `keyconfig2.plist`; `N` with shift is *prime next*.
- **Text entry is built from key events.** There is no `SDL_StartTextInput` anywhere. String
  input does not suppress `keys[]`.
- **`n` only works in flight.** Status must be in flight or witchspace countdown, not paused, no
  mission screen, a flight mouse mode. Then it calls the primed equipment's `activated()`.
- **How the tutorial is reached.** There is no Tutorial row on the start screen. The path is
  *Start New Commander* → the scenario screen → the tutorial scenario → Enter → a mission screen
  that Enter dismisses → launch → lesson 0 step 2, the first "press n".
- **Unused data.** `keymappings_windows.plist` / `keymappings_linux.plist` are loaded and never
  read.

**Things in the key path that look wrong** (for Story 4; none is judged here, each gets a test):

| # | Observation | Where |
|---|---|---|
| H1 | Caps Lock is not neutralised: its reset line is commented out. With Caps Lock on, the `n` key gives `N`, which with no shift matches neither *activate* nor *prime next*. | `MyOpenGLView+Input.cpp:612-632` |
| H2 | On a non-Latin layout the `n` key gives a code point above 326, which is dropped. | `:645-646` |
| H3 | Any extra modifier bit (AltGr reported as Alt, a compositor's modifier) fails the exact match. | `PlayerEntityControls.cpp:688-697` |
| H4 | Non-character keys (`SDLK_*` with bit 30 set) are truncated to 16 bits and alias real keys: Caps Lock becomes `9`, Num Lock `S`. | `:201, 365` |
| H5 | `scancode2Unicode` has 327 entries and is indexed by scancode, which goes to 511. | `MyOpenGLView.h:402`, `:635, 664` |
| H6 | The game-side conditions above: pressing `n` on the mission screen, during launch, or after Shift+N re-primed another item. | `oolite-tutorial.js`, `PlayerEntityControls.cpp:718, 1207, 1265` |
| H7 | Focus loss under XWayland, noted in a code comment. It would affect every key. | `src/SDL/MyOpenGLView.cpp:547-552` |

**Data**

- `Resources/Config/shipdata.plist` has **194** definitions, **81** of them templates
  (`is_template`). The registry drops templates and anything with no roles or no model, logging
  `shipData.load.error`. `OOShipRegistry::shipKeys()` lists the rest.
- `Resources/Config/equipment.plist` has **41** entries. Four are services (`EQ_FUEL`,
  `EQ_RENOVATION`, `EQ_MISSILE_REMOVAL`, `EQ_PASSENGER_BERTH_REMOVAL`).
- Spawn failure is a null return from `Universe::newShipWithName`, with a log line of class
  `shipData.load.error`, `setup.ship.badEntry.*` or `exception`.
- Log lines can be captured in-process: `oo::log::logger().setSink(...)`
  (`src/oofnd/Log.hpp:228-236`). Script errors are logged as `script.javaScript.exception.*`.
- Every user directory has an environment variable (`OO_SAVEDIR`, `OO_LOGSDIR`,
  `OO_SNAPSHOTSDIR`, `OO_MANAGEDADDONSDIR`, `OO_ADDONSEXTRACTDIR`, `OO_ADDITIONALADDONSDIRS`,
  `OO_GNUSTEPDEFAULTSDIR` on POSIX) or follows `HOME` / `HOMEPATH`. Built-in data is
  `<cwd>/Resources`.

**Build and CI**

- The game is one executable. Tests link its objects with `oolite_bin.extract_objects`; `['*']`
  means all of them except `src/SDL/main.cpp`. No test initialises a real universe.
- The `oofnd`, `core` and `headers` suites are declared **only on Windows**
  (`meson.build:121-149`), because the test sources use Windows headers. The harness itself
  (`tests/unit/oofnd/oo_test.hpp`) includes only `<csignal>`, `<cstdio>` and `<vector>`.
- Google Test is not in the tree. The only wrap is `quickjs-ng`.
- The language standard is C++23 (`src/meson.build:32`).
- No sanitizer option is wired in. `build/meson_asan` and `build/meson_tsan` were set up by hand
  with `-Db_sanitize=`. The `test` flavour builds with LTO on; CI's unit job turns it off.
- CI (`.github/workflows/build-all.yaml`) runs `meson test` in one job, `unit-tests-windows`. The
  Linux and macOS jobs run only the smoke launch. The Flatpak job runs `flatpak-builder` on
  `installers/flatpak/space.oolite.Oolite.yaml`: runtime `org.freedesktop.Platform` 26.08, SDL3
  3.4.8 built from source inside it, Oolite built by `mk.sh flatpak-internal`.

**To be confirmed by the first tasks** (the surveys could not settle them by reading):

- whether SDL's `dummy` video driver is compiled into each platform's SDL3, including the one the
  Flatpak manifest builds;
- how SDL 3.4.8's `SDL_GetKeyFromScancode` treats Caps Lock;
- whether `main`'s `GameController` is the one `sharedController()` returns. The constructor
  raises if a shared one exists but only `sharedController()` sets it
  (`GameController.cpp:215-229`), so a second controller may be created, which would re-seed
  RANROT;
- whether the start screen's demo ships and `addLongText`'s font metrics touch GL.

## R1 — How a headless game is created

**Decision:** Add one entry point on `GameController`, `startHeadless(const OOHeadlessOptions&)`.
It runs the same start-up as `applicationDidFinishLaunching` with these parts left out: the splash
screen, display modes, the expansion manager, the window and the frame loop. It calls the same
`Universe::newUniverse`, which takes the options. Defaults reproduce today's behaviour exactly.

The options are: seed; add-ons (`none` headless); whether the system is populated; the fixed step;
whether a view exists for input. See [contracts/headless-game.md](contracts/headless-game.md).

**Rationale:** One construction path with options cannot drift from the real one (FR-002). This is
003 R4's decision, and the type is the one 003 names, so 003 extends it later.

**Alternatives considered:**
- **Boot the whole game and clear the system**, as the component tier does. It reads add-ons and
  populates from the clock.
- **A separate headless constructor.** A second path to keep in step.
- **Wait for 003's `OOGame` split.** The spec rules it out (FR-009).

## R2 — Running with no graphics device

**Decision:** A headless game has no GL context and never calls GL.

- `OOOpenGLExtensionManager` gets a headless state that reports "no GL, no shaders" without
  calling `glGetString`. One query, `OOGraphicsAvailable()`, reads it.
- The known GL sites on the construction and simulation paths check it and skip: the target
  framebuffer set-up, `setLighting`, `OOSunEntity::setSunColor`, `SkyEntity::changeProperty`, the
  JS system setter at `OOJSSystem.cpp:577`, `useGUILightSource`, `OOTexture::checkExtensions`,
  `OOTextureLoader::setUp`, and texture upload and `dimensions()`.
- Textures are not decoded headless. That also removes the worker threads from the simulation.
- **A GL trap finds the sites nobody listed.** On Linux and macOS the headless test programs link
  a generated file that defines every `gl*` symbol the game's objects import. Each definition
  prints its own name and aborts. A GL call from a headless test therefore fails that test and
  names the function (FR-003). The list of symbols is generated from the built objects.
- The work is staged. First the headless game runs under the existing hidden GL window
  (`tests/unit/core/oo_gl_test_context.hpp`) so that time, seeds and events can be settled. Then
  the window is removed and the trap is linked.

**Rationale:**
- The spec requires no graphics device at all (FR-001), and macOS has no offscreen GL.
- A GL call with no context does different things on each platform: usually nothing on Linux and
  Windows, usually a crash on macOS. A test cannot rely on that to find a missed site. The trap
  makes it certain on two platforms, and the code is the same on the third.
- Only 725 of roughly 1,300 GL call lines go through the `OOGL()` macro, so a check inside the
  macro would miss about half.

**Alternatives considered:**
- **A hidden GL window permanently.** Fails FR-001; needs a real window on macOS and Mesa on
  Windows.
- **Stub every GL call to do nothing.** It hides real GL use that the simulation should not make.
- **A guard inside `OOGL()`.** Misses the unwrapped calls.
- **A trap on Windows too.** GL imports there are `__imp_` references and extension functions are
  pointers. More work for no new coverage, since the call sites are shared code.

## R3 — Time

**Decision:**
- The middle of `doPerformGameTick` becomes `GameController::tick(OOTimeDelta)`: update, restart
  check, sound update, frame callbacks. The windowed loop calls it with the dt it measured. A
  headless game calls it with a fixed dt and never sleeps.
- **The fixed step is 1/60 s.** `runFor(seconds)` rounds up to whole steps.
- A small clock object owned by `GameController` answers "monotonic seconds" and "time of day".
  The real one reads the system. The headless one advances only in `tick`. The state-affecting
  reads listed above go through it.
- The JS time limiter stays on, with a 10 s limit in a headless game (003 R6).
- `Date.now`, `performance.now` and anything else that cannot follow simulated time is listed in
  the feature's notes (FR-005) once a search of the core scripts shows whether anything uses it.

**Rationale:**
- 1/60 s is inside the range the windowed game produces (it caps dt at 0.25 s and has no minimum),
  so a headless run is evidence about real play. 112.5 s is 6,750 steps.
- Menus pace key repeat from the real clock. Without the clock object the menu tests would depend
  on how fast the machine is.

**Alternatives considered:**
- **dt = 0.125 s** to match the component tier's "tick". Physics at 8 Hz is not what a player
  gets (003 R6).
- **Raising the time-acceleration factor.** It makes each step bigger, which the spec forbids.
- **Replacing `oo::date` process-wide.** A new global, and it would also move log timestamps.

## R4 — Seeds and repeatability

**Decision:** The headless options carry one seed. From it the game seeds RANROT, the "really
random" generator, the frame-callback id start and the ship clock's start. `Math.random` in the
script engine is replaced, in a headless game only, by a function drawing from a generator seeded
the same way. The replacement is made through QuickJS-ng's public API by the binding; the vendored
source is not edited (hard rule 7).

Repeatability is tested by running a scenario 100 times in separate processes and comparing a
digest of entity positions and the event record at every step.

**Rationale:** `OO_RANDOM_SEED` pins only RANROT. String expansion uses the "really random"
generator, and QuickJS seeds itself from the clock.

**Alternatives considered:**
- **Patch QuickJS to accept a seed.** Edits vendored C.
- **Leave `Math.random` alone.** Any core script that uses it would make a scenario differ from
  run to run.

## R5 — The player

**Decision:** Keep the real `PlayerEntity` (003 R7). A scenario game puts it in flight with no
keys pressed. A menu game leaves it at the start screen as a normal launch does.

## R6 — What a test can see

**Decision:**
- **Entities** are read directly from the universe, and through `eval`, which runs a script
  expression in the game's engine the way the debug console does. A ported scenario uses the same
  expression as its windowed original, so the assertion means the same thing.
- **Events.** One optional observer on `GameController` is told of each ship script event and
  world script event as it is dispatched, with the game time. It is null in the windowed game.
- **Errors.** The headless game installs a log sink that keeps every line with its game time and
  still writes the log file. Error-level lines are those with the `***** ERROR` prefix or a class
  in a fixed list (`shipData.load.error`, `setup.ship.badEntry.*`, `script.javaScript.exception.*`,
  `exception`, `equipment.load`).
- **Presentation.** A record of what was asked for: the number of frames the game would have
  drawn and the names of sounds it would have played. The showing screen, its rows and the
  selection are read from `GuiDisplayGen`, where they are plain data.

**Alternatives considered:**
- **Only `eval`.** Simple, but a test could not assert on the order of events.
- **003's `OOGameEventObserver` as a context service.** There is no context yet. The observer
  here is the same idea with one owner, and 003 can move it.

## R7 — Keys

**Decision:**
- A menu game has a `MyOpenGLView` that is initialised without a window. SDL is started with its
  `dummy` video driver, chosen by a hint set in the headless path, with no audio.
- A test presses a key by pushing `SDL_EVENT_KEY_DOWN` / `KEY_UP` with a scancode and modifier
  state onto SDL's queue. The stepper calls the real `pollControls` before each `tick`. Nothing in
  the key path is bypassed.
- **Layouts.** The one line that asks SDL for the key becomes a call through a view member that
  defaults to `SDL_GetKeyFromScancode`. A test may install a **recorded layout**: a table from
  (scancode, modifiers) to key code, taken once from a real layout. The set is US QWERTY, French
  AZERTY and Russian.
- Text entry is typed the same way, since the game builds text from key events.

**What this covers and what it does not.** It covers the game's whole handling of a key on every
platform, with the SDL build that platform ships, under three layouts. It does not cover the step
where SDL's Win32, Cocoa, X11 or Wayland backend reads the operating system's layout, nor focus,
nor the Flatpak sandbox's access to devices. Those need a real display. Spec FR-023 and FR-027 are
worded to match, and the limits go in Story 4's finding.

**Rationale:**
- Pushing events through SDL's own queue uses the same SDL calls as real input.
- H1, H2, H3, H4 and H5 are all reachable this way. H2 needs only a layout table.

**Alternatives considered:**
- **Setting `keys[]` directly** through the existing test-access friend. It skips the translation
  the report is about.
- **SDL's real backend under a virtual display** (Xvfb, a headless Wayland compositor). It would
  cover the layout step on Linux only, and it is a windowed test. It belongs to the component
  tier and is listed as follow-on work in the finding.
- **Splitting `pollControls` into a per-event handler.** Not needed once events are pushed.

## R8 — The census

**Decision:** One program, `sim_census`.

- **Enumeration** is from the data at run time: every top-level key of the merged core
  `shipdata.plist`, and every entry of `equipment.plist`.
- **Classification from the data alone:** a template is *not applicable (template)*. A key the
  registry tagged as a sub-part and that no role selects is *not applicable (part)*, provided at
  least one definition that carries it passed. A service item is *not applicable (service)*.
- **A ship is tried** by reseeding, spawning it by key near the player in an empty system,
  running 10 s of game time, checking it, removing it, and checking that the entity count is back
  to where it started.
- **An equipment item is tried** on the player's ship (or on a pylon for missiles and mines):
  award, check it is fitted, activate if it has a script, run 5 s, remove.
- **Crashes.** The program runs itself as a child. The child writes each key before trying it. If
  the child dies, the parent records that key as failed (crashed) and starts a new child at the
  next key. A definition that leaves the universe unclean also ends the child. So one failure
  neither stops nor changes the rest (FR-021).
- **Reseeding per definition** from the base seed and the key makes each result independent of
  the order.
- **Expectations file.** `tests/sim/census-expectations.tsv` lists definitions expected to fail
  or to leave by design, each with a reason. A listed definition that passes is an error.
- The report format and exit codes are in [contracts/census.md](contracts/census.md).

**Alternatives considered:**
- **One meson test per definition.** 235 game start-ups, and the list would have to be known at
  configure time.
- **A Python driver.** The crash-and-resume loop is twenty lines in C++, and one language is
  simpler to run on three platforms.
- **Try every role.** Roles select among definitions at random, so coverage would be by chance.

## R9 — Where the tests live and how they run

**Decision:**
- A new directory `tests/sim/` and a meson suite `sim`, declared on every platform. Each test
  program links the game's `['*']` objects and a small support library, `oo_sim`.
- The harness is `oo_test.hpp`, which is portable. If spec 005 lands first, new programs use
  Google Test and existing ones move with 005's batches.
- **One game per program.** A program may have several cases sharing its game where that is safe
  (the menu walk). A scenario has a program of its own.
- `tests/run.sh sim [-k name]` runs `meson test --suite sim`. `all` runs it after `unit`.
- Meson runs the programs in parallel. Each creates its own scratch directory under the build
  directory and points every user-directory variable at it before the game starts.
- Timeouts: 60 s per program, 600 s for the census.
- The working directory is the built application directory, for `Resources`. Add-ons are off by
  option, every add-on directory variable points at an empty directory, and a test asserts that
  the resource search path has exactly one entry.
- The sanitizer run is `meson setup build/meson_asan -Db_sanitize=address,undefined -Db_lto=false`
  and `meson test -C build/meson_asan --suite sim`.

**Rationale:** The unit suites cannot be the home, because they are Windows-only and the spec
requires three platforms from the start (FR-011). "sim" is short and is not "component", which
the glossary gives to the Python tier.

**Alternatives considered:**
- **`tests/unit/scenario/`** (003 R12). It would inherit the Windows-only guard.
- **A fixture directory holding a link to `Resources`.** Directory links need a junction on
  Windows. The search-path assertion gives the same guarantee.

## R10 — Platforms and CI

**Decision:**
- Development and the first green run are on this Mac. Windows and Linux are proved by CI.
- CI gets a `sim` step in four places: `unit-tests-windows`, `build-macos`, `build-fedora`, and
  the Flatpak manifest's Oolite module, which runs `meson test --suite sim` inside the build
  sandbox when a variable asks for it.
- The suite skeleton, with one trivial test that boots nothing, goes into CI on all platforms
  before any game code changes. Every later milestone is then cross-platform from its first
  commit.

**Rationale:** Jon's standing preference is to keep moving on the local build and fix other
platforms after. Putting the skeleton into CI first means "after" is the next push, not the end
of the feature.

## R11 — Branch and worktree

**Decision:**
- A new worktree `.agent-tmp/wt-sim-tests` of `oolite-dev`, on branch `feature/headless-sim-tests`,
  cut from the tip of the most recent `seriesb` branch when work starts (Jon, 2026-11-13). The
  base commit is written into `tasks.md` when it is cut.
- The branch is pushed for CI. It is never force-pushed. When its base is rewritten, the new base
  is merged in, and the merge is recorded in `tasks.md`.
- If a merge of a rewritten base cannot be made cleanly, a fresh branch
  (`feature/headless-sim-tests-2`) is cut from the new base and the work is cherry-picked onto it.
  The old branch is left as it is.

**Rationale:** Hard rule 3 forbids force-pushing, and CI needs pushes. `seriesb` branches are
rebased by their owner, so a pushed child cannot follow by rebasing.

## R12 — Speed targets

**Decision:** The first task after the skeleton measures start-up and stepping, on this Mac and in
CI, and writes the numbers into `tasks.md`. The targets in SC-001, SC-004 and SC-010 stand until
then. If a measurement shows a target cannot be met, the task reports it with the number. The
known lever is start-up: each program parses the core data afresh because the cache is private.
A read-only cache built once per test run is the first thing to try.

## Ownership and style

New types follow the tree as it is on the base branch. Spec 009 is moving ownership from
`oo::Ref` to the standard library there, so whichever the touched class uses is used. The
headless types are owned by value or by one owner inside `GameController`; nothing new is shared.
Game files are formatted with clang-format 22. Files under `tests/` are not run through it (hard
rule 10).
