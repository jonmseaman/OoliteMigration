---

description: "Tasks for the headless C++ component tests (spec 011)"
---

# Tasks: Headless component tests

**Input**: Design documents from `specs/011-headless-component-tests/`

**Prerequisites**:

- [plan.md](plan.md) (milestones M0–M9)
- [spec.md](spec.md) (US1–US6, FR-001–FR-039, SC-001–SC-013)
- [research.md](research.md) (R1–R12, observations H1–H7)
- [data-model.md](data-model.md)
- [contracts/headless-game.md](contracts/headless-game.md),
  [contracts/component-test-api.md](contracts/component-test-api.md),
  [contracts/census.md](contracts/census.md), [contracts/runner.md](contracts/runner.md)
- [examples.md](examples.md) (C++ samples; A = tests, B = support library, C = game changes)
- [quickstart.md](quickstart.md)

**Tests**: Included. The feature is tests, and CLAUDE.md requires every task to have a command that
exits nonzero before it and zero after. Each task ends with its **Accept:** command.

**Organization**: by user story, in **execution order**, not priority order (plan.md
*Milestones*). US6's first three tests come straight after US1 because they need no keys; its
fourth (the fire key) is in the US3 phase because it needs them.

| Phase | Milestone | Story |
|---|---|---|
| 1 Setup | M0 | — |
| 2 Foundational | M0 | — |
| 3 | M1, M2, M3 | US1 headless scene (P1) 🎯 MVP |
| 4 | M3 | US6 one behaviour at a time (P2), three of four tests |
| 5 | M4 | US2 census (P2) |
| 6 | M5 | US3 menus and keys (P2), and US6's fire-key test |
| 7 | M6 | sanitizers and the Flatpak leg (FR-015, FR-028) |
| 8 | M7 | US4 the Flatpak `n` report (P3) |
| 9 | M8 | US5 scenarios S2–S8 (P3) |
| 10 Polish | M9 | docs, close-out |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can be done in any order relative to the other [P] tasks of its phase (different files,
  no dependency on an unfinished task). All tasks commit on one branch, one at a time.
- **[Story]**: US1–US6 from spec.md.

## Rules for every task

- **Where.** Every game change is made in the worktree `.agent-tmp/wt-component-tests`, on
  **`seriesb/029-component-tests`**, based on `seriesb/027-modern-cpp` (Jon, 2026-11-13). Game
  paths below are relative to that worktree. Paths starting `specs/`, `docs/` or naming
  `CLAUDE.md`, `GLOSSARY.md` are in the planning repo. The main `oolite-dev` checkout holds spec
  009's uncommitted work: do not build in it, commit in it or switch its branch.
- **Never** touch `develop`, `master` or `main`. **Never force-push.** Never move the planning
  repo's recorded `oolite-dev` commit: in the planning repo stage files by path
  (`git add specs/011-headless-component-tests docs …`), never `git add -A`.
- **One commit per task** in the worktree, titled `T0NN: <title>`, ending with the attribution
  trailer. Then `git push origin seriesb/029-component-tests` so CI runs. A task whose Accept
  includes CI puts the run's URL in *Records* below, and the run must show the new test executing.
- **Then record it**: tick the task here, add its commit to *Records → Commits*, and commit this
  file in the planning repo as `Spec 011: T0NN done (oolite-dev <sha>)`.
- **If `seriesb/027-modern-cpp` is rewritten** (research R11): `git rebase --onto <new 027>
  <saved old base>` in the worktree, update *Records → Base*, and do not push. Write under
  *Records → Branch state* that the remote copy is stale and needs Jon's force-push, then carry on
  against the local build. Never sync or reset the local parents.
- **Platform.** Work and the first green run are on this Mac. Windows and Linux are proved by CI
  (`unit-tests-windows`, `build-fedora`, `build-macos`, later `build-flatpak`). Start the next task
  while CI runs (Jon's standing preference); a task whose Accept names CI is ticked when that run
  is green, and a red job is fixed in the next commit.
- **Build and gate**, from the worktree, before every game commit:

  ```bash
  ./mk.sh build test --setup-flags=-Db_lto=false     # B=build/meson_test
  tests/run.sh component --cpp                        # from T004 on
  ./mk.sh test test                                   # the smoke launch
  ```

  At each phase's checkpoint also run the four tiers one by one (`tests/run.sh unit`,
  `component`, `smoke`, `gui`) and compare with *Records → Baselines* (FR-031); "matches the
  baselines" below means this. A tier that could not run on this Mac at the base commit is
  compared in CI only. The windowed tiers open the real game window: run one at a time and start
  nothing else on the desktop meanwhile.
- **Tests.** Only add tests. No file under `tests/unit`, `tests/component`, `tests/gui` is edited,
  moved or deleted (hard rule 1). `tests/run.sh` is the runner and is changed only by T004. A new
  test that fails is never weakened to pass: stop, and record it under *Records → Findings*.
- **Windowed behaviour does not change.** Every option defaults to today's behaviour. A guard or
  an indirection must not change what the windowed game computes, logs or saves (FR-016).
- **No suppressions**: no `-Wno-*`, `#pragma … diagnostic`, unused-attribute, `NOLINT`, or
  sanitizer suppression. No new warning on Clang or GCC.
- **Never open expansion content** (OXP/OXZ, `AddOns`). Fixtures under
  `tests/component-cpp/fixtures/` are written for these tests and are not expansion content.
- **Vendored C is not edited** (`quickjs`, MiniZip, stb).
- **Format** only the `src/` files you changed, with
  `/opt/homebrew/opt/llvm@22/bin/clang-format -i`. Never format `tests/`; lay new test files out
  by hand like `tests/unit/core/test_OOColor.cpp`.
- **File modes.** `gl_trap_gen.py` and `repeat_100.sh` are committed `100755` with a `#!` line.
  Check with `git ls-files -s`.
- **Style.** Follow examples.md for names and shape. Ownership follows the base branch (spec 009
  FR-006): nothing new is shared; `game.player()` and `game.universe()` are plain pointers (Jon,
  2026-11-13); a ship is handed to a test as a `ShipHandle` over `std::weak_ptr`.
- **Never wait for Jon.** A choice with no default here takes the conservative option and is
  written under *Records → Decisions taken on defaults*. Anything only he can do goes under
  *Records → For Jon*.
- **A step that turns out bigger than its task** (a new GL site, a source of non-repeatability, a
  census finding, a sanitizer report) becomes its own task: append it to its phase as `T0NNa`,
  `T0NNb`, … with an Accept command, and do it in its own commit.
- Scratch goes in `.agent-tmp/` (planning repo root). Test scratch goes under the build directory.

---

## Phase 1: Setup

**Purpose**: the branch, the worktree and the numbers later tasks are compared against.

- [X] T001 Create the branch and worktree. From the planning repo root:
  `git -C oolite-dev fetch origin`, then
  `git -C oolite-dev worktree add -b seriesb/029-component-tests
  "$PWD/.agent-tmp/wt-component-tests" refs/heads/seriesb/027-modern-cpp`. The base is the
  **local** branch's committed tip (on 2026-11-13 that was `123146c11`, 36 commits ahead of the
  remote-tracking ref); uncommitted work in the main checkout is not included and is not touched.
  Write the base commit, and the remote ref's commit, into *Records → Base*.
  **Accept:** `git -C .agent-tmp/wt-component-tests rev-parse --abbrev-ref HEAD` prints
  `seriesb/029-component-tests`, and
  `! grep -q '_not recorded_' <(sed -n '/^### Base/,/^### /p' specs/011-headless-component-tests/tasks.md)`.
- [X] T002 Build the base and record the baselines in *Records → Baselines*. In the worktree:
  `./mk.sh build test --setup-flags=-Db_lto=false`, `./mk.sh test test` (record the smoke run's
  frame time, for SC-011), then `tests/run.sh unit`, `component`, `smoke` and `gui`, one at a
  time, and record each tier's result on this Mac at the base commit: passed, failed (with the
  failing names), or cannot run here (with the message).
  Record the real time of the windowed `tests/run.sh component -k s1` if it runs here; if not, take
  it from the most recent Windows run noted in `docs/current-state.md` and say so (SC-009's
  baseline). Record which compiler each of the four CI jobs uses (FR-011).
  **Accept:**
  `! grep -q '_not measured_' <(sed -n '/^### Baselines/,/^### /p' specs/011-headless-component-tests/tasks.md)`.

---

## Phase 2: Foundational (M0 — the skeleton on every platform)

**Purpose**: an empty suite that builds, runs and is in CI everywhere before any game code changes.

**⚠️ CRITICAL**: no user-story work starts until T006's three CI jobs are green.

- [X] T003 Create `tests/component-cpp/meson.build` and `tests/component-cpp/test_skeleton.cpp`,
  and include the directory from the top-level `meson.build` with
  `if not get_option('deployment_release')` and **no** platform guard
  ([contracts/runner.md](contracts/runner.md), *Meson*). The build file keeps a list of programs;
  each is `executable(name, name + '.cpp', <support sources>, objects:
  oolite_bin.extract_objects(<every game source except src/SDL/main.cpp>), include_directories:
  [oolite_includes, include_directories('../unit/oofnd')], dependencies: oolite_dependencies,
  override_options: oolite_override_options, install: false)`, as `tests/unit/core/meson.build`
  does for `['*']`, and `test(name, exe, suite: 'component', timeout: 60, workdir: <built
  application directory>, env: …)` with `OO_COMPONENT_SOURCE_ROOT` and `OO_COMPONENT_BUILD_ROOT`
  in the environment. `test_skeleton.cpp` uses `oo_test.hpp` and has one case,
  `the_whole_game_links`, that references one game symbol and boots nothing.
  **Accept:** `meson test -C build/meson_test --suite component --list | grep -q test_skeleton &&
  meson test -C build/meson_test --suite component --print-errorlogs`.
- [X] T004 Teach `tests/run.sh` the two halves ([contracts/runner.md](contracts/runner.md),
  *`tests/run.sh`*): `component` runs the C++ half then the windowed half and exits nonzero if
  either failed, with the windowed half still run after a C++ failure; `--cpp` runs only
  `meson test -C build/meson_$BUILD_TYPE --suite component --print-errorlogs` and needs no
  virtualenv; `--windowed` runs only pytest as today; `-k <name>` filters the C++ half by substring
  of the meson test name and **exits nonzero when nothing matches**; `all` keeps its order. Update
  the help comment at the top.
  **Accept:** `tests/run.sh component --cpp && tests/run.sh component --cpp -k skeleton &&
  ! tests/run.sh component --cpp -k no_such_test && tests/run.sh | grep -q -- '--cpp'`.
- [X] T005 [P] Add three probe cases to `tests/component-cpp/test_skeleton.cpp` (plan M0; research
  *To be confirmed*): `sdl_dummy_video_driver_initialises` (`SDL_SetHint(SDL_HINT_VIDEO_DRIVER,
  "dummy")`, `SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)` succeeds and
  `SDL_GetCurrentVideoDriver()` is `dummy`); `a_pushed_key_event_comes_back` (`SDL_PushEvent` of a
  `SDL_EVENT_KEY_DOWN` for `SDL_SCANCODE_N`, `SDL_PollEvent` returns it with the same scancode and
  modifiers); `caps_lock_n_lookup_is_printed` (prints
  `SDL_GetKeyFromScancode(SDL_SCANCODE_N, SDL_KMOD_CAPS, false)` in hex and checks only that it is
  `n` or `N`). Write each platform's printed value into *Records → Probes*. If the dummy driver is
  missing on a platform, do not skip the case: record it and take the plan's fallback (*Risks*) in
  T038.
  **Accept:** `tests/run.sh component --cpp -k skeleton`, and the *Probes* table has this Mac's
  row.
- [X] T006 Add the C++ component step to CI in `.github/workflows/build-all.yaml`
  ([contracts/runner.md](contracts/runner.md), *CI*): `unit-tests-windows` runs
  `tests/run.sh component --cpp` after `tests/run.sh unit`; `build-fedora` runs it after its
  test-flavour build, and that build gains `--setup-flags="-Db_lto=false"` (the GL trap of T016
  needs real objects; LTO on Linux stays covered by `build-appimage` and `build-ubuntu`; record
  this under *Decisions*); `build-macos` gains a test-flavour build with LTO off and the step.
  Leave `build-flatpak` to T051. Fill the Windows and Fedora rows of *Records → Probes* from the
  logs.
  **Accept:** the three jobs are green on the pushed commit and each log shows `test_skeleton`
  passing; the run's URL is in *Records → CI runs*.

**Checkpoint**: `tests/run.sh component --cpp` passes on three platforms. Nothing in `src/` has
changed.

---

## Phase 3: User Story 1 — a scene with no window, faster than real time (P1) 🎯 MVP

**Goal**: a C++ test creates the real game with a seed, no window, no GL and no sound, steps it at
1/60 s without waiting, and asserts on what happened.

**Independent Test**: `tests/run.sh component --cpp -k s1_police_kills_pirate` passes with no
display; game time is at least 20× real time while stepping; the test takes under 15 s; 100 runs
give the same digests.

### M1 — boots headless, under a hidden GL window

Until T021, `test_boot` needs a window, so it is registered in a temporary meson suite
`component-window` and run locally with `meson test -C build/meson_test --suite component-window`.
It is built on every platform, so CI still compiles it.

- [X] T007 [US1] Add `src/Core/OOHeadless.h` and `src/Core/OOHeadless.cpp` (examples C1;
  [contracts/headless-game.md](contracts/headless-game.md); data-model *Headless options*, *Game
  clock*, *Presentation record*) and list them in `src/meson.build`. `OOHeadlessOptions` has the
  fields `headless`, `seed`, `addOns`, `populate`, `startInFlight`, `inputView`, `step`,
  `scriptTimeLimit`; a default-constructed value means the windowed game exactly as today.
  Validation, raised by a `validate()` the controller will call: "`headless` true requires `seed`
  to be given" and "`addOns` is never `all` when `headless` is true". `OOGameClock` answers
  `monotonicSeconds()` and `timeOfDay()`; the real one reads the system; the manual one starts at
  0, derives time of day from the seed, and moves only by `advance(dt)`. Also declare
  `OOGameObserver` (`shipEvent(time, ship, name)`, `worldEvent(time, name)`), the presentation
  record (`framesRequested`, `soundsRequested`), the seeded generator `Math.random` will draw from,
  and `OOGraphicsAvailable()` (true for now; T017 gives it its meaning). The header includes
  nothing from the game beyond basic types. Cases in `tests/component-cpp/test_skeleton.cpp`:
  `default_options_are_the_windowed_game`, `headless_without_a_seed_is_rejected`,
  `headless_with_all_addons_is_rejected`, `the_manual_clock_moves_only_when_advanced`.
  **Accept:** `tests/run.sh component --cpp -k skeleton`.
- [X] T008 [US1] Split the frame in `src/Core/GameController.h` / `.cpp` (examples C2):
  `GameController::tick(OOTimeDelta dt)` is the simulation half of `doPerformGameTick` (clock
  advance, universe update, restart check, sound update, frame callbacks, in that order), and
  `doPerformGameTick` measures dt, caps it as today, calls `tick`, then draws. The controller owns
  an `OOGameClock`, the real one by default. No windowed behaviour changes. Add the case
  `the_controller_has_tick` to `tests/component-cpp/test_skeleton.cpp` (it takes
  `&GameController::tick`, so it does not compile before this task).
  **Accept:** `tests/run.sh component --cpp -k skeleton && ./mk.sh test test`, with the smoke
  run's frame time within 2% of the baseline (SC-011).
- [X] T009 [US1] Take the options into the universe: `Universe::newUniverse` and
  `initWithGameView` in `src/Core/Universe.h` / `.cpp` accept `const OOHeadlessOptions&`,
  defaulted. With `addOns` none, add-ons are not forced to "all" (`Universe.cpp:307, 342`) and
  `ResourceManager::setUseAddOns` gets the strict value; with `populate` false the system is left
  empty; with a seed given, RANROT and the "really random" generator (`Universe.cpp:301`) are
  seeded from it. Defaults reproduce today's calls exactly.
  **Accept:** `./mk.sh build test --setup-flags=-Db_lto=false && ./mk.sh test test`; T011's
  `test_boot` is this task's failing-then-passing test, so T009–T011 are pushed together.
- [X] T010 [US1] Add `GameController::startHeadless(const OOHeadlessOptions&)` in
  `src/Core/GameController.h` / `.cpp` (examples C3; contract *startHeadless*): the steps of
  `applicationDidFinishLaunching` in the same order, without the splash, display modes, the
  expansion manager, the window, the sound device and the frame loop; `-nosound`'s path for sound;
  the manual clock installed; the player put in flight in the empty system when `startInFlight`.
  It raises, with a message, on invalid options or if a universe already exists. **First** settle
  the open question in research (*To be confirmed*): read `GameController.cpp:215-229` and
  `src/SDL/main.cpp` and write under *Records → Findings → Start-up* whether `main`'s controller
  is the one `sharedController()` returns. `startHeadless` must run on the controller the game
  uses; if two can exist, make the headless path use the shared one and record the windowed
  double-seed as a finding, not a fix.
  **Accept:** as T009 (pushed together with T011).
- [X] T011 [US1] Create the support library `tests/component-cpp/oo_component.hpp` / `.cpp` with
  its first part (examples B1, B3; [contracts/component-test-api.md](contracts/component-test-api.md),
  *Creating a game*, *Time*) and `tests/component-cpp/test_boot.cpp`. `Game::scenario(seed)`:
  creates `<build>/component/scratch/<program>-<pid>/`, points `HOME`/`HOMEPATH`, `OO_SAVEDIR`,
  `OO_LOGSDIR`, `OO_SNAPSHOTSDIR`, `OO_MANAGEDADDONSDIR`, `OO_ADDONSEXTRACTDIR`,
  `OO_ADDITIONALADDONSDIRS` and (POSIX) `OO_GNUSTEPDEFAULTSDIR` at it before the game starts,
  then calls `startHeadless`. For now it first makes the hidden GL window with
  `tests/unit/core/oo_gl_test_context.hpp` (removed in T021). Also `Game::current()`, `step`,
  `simulate`, `time`, `universe()`, `player()`, `ticks(n)`, and the scratch directory removed on a
  pass and kept on a failure. A second `Game` in one process fails the test with a message.
  When the two environment variables are unset (a program run by hand, as quickstart does), it
  finds the build root from its own executable's path and changes to the built application
  directory. While stepping it prints `game time <t> s` to standard error every 10 s of real
  time, so a program meson stops at its timeout shows how far it got (FR-013).
  `test_boot.cpp` cases: `the_universe_exists`, `the_system_is_empty`,
  `the_player_is_in_flight`, `the_resource_search_path_has_one_entry`,
  `user_directories_are_under_the_scratch_directory`, `600_steps_advance_game_time_by_10_s`.
  Register `test_boot` in suite `component-window`.
  **Accept:** `meson test -C build/meson_test --suite component-window --print-errorlogs`.
- [X] T012 [US1] Send the state-affecting clock reads through the controller's `OOGameClock`
  (research *The real clock*; contract *Game clock*): the ship clock's start
  (`src/Core/Entities/PlayerEntity.cpp:2555-2566`), deferred-call deadlines
  (`src/Core/GameController.cpp:150-197`), the GUI-screen time delta and the escape-pod double
  press (`src/Core/Entities/PlayerEntityControls.cpp:1948` and nearby), and the frame-callback id
  start (`src/Core/Scripting/OOJSFrameCallbacks.cpp`, from the seed when headless). Log
  timestamps and profiling keep reading the system. Cases in `test_boot.cpp`:
  `the_ship_clock_starts_from_the_seed` (its start equals the value the manual clock derives from
  the seed) and `a_deferred_call_fires_on_game_time` (one scheduled for 2 s fires after 120 steps
  and not after 119).
  **Accept:** `meson test -C build/meson_test --suite component-window --print-errorlogs &&
  ./mk.sh test test`.
- [X] T013 [US1] Seed the script engine in `src/Core/Scripting/OOJavaScriptEngine.cpp` (research
  R4; contract *Script engine*): in a headless game only, replace `Math.random` through
  QuickJS-ng's public API with a function drawing from the generator of T007 seeded from
  `options.seed`, and take the time limiter's limit from `options.scriptTimeLimit` (10 s
  headless). `quickjs.c` is not edited. Add `Game::eval`, `evalBool`, `evalString` to
  `oo_component` (an expression that throws fails the test and prints the message). Case in
  `test_boot.cpp`: `math_random_draws_from_the_seed`: three `Math.random()` values equal the first
  three draws of the same generator class seeded the same way, computed in the test.
  **Accept:** `meson test -C build/meson_test --suite component-window --print-errorlogs`.
- [X] T014 [P] [US1] List what cannot follow simulated time (FR-005). Search the core scripts
  (`Resources/Scripts`, `Resources/Config/*.plist` script fragments; core data only, no add-ons)
  and `src/` for `Date.now`, `new Date`, `performance.now` and any remaining state-affecting
  real-clock read from research's list of thirteen. Write each under *Records → Clock exceptions*
  with its file, what it affects and why it stays.
  **Accept:**
  `! grep -q '_not listed_' <(sed -n '/^### Clock exceptions/,/^### /p' specs/011-headless-component-tests/tasks.md)`.
- [X] T015 [US1] Measure (research R12). Make `test_boot` print one line,
  `test_boot: startup <s> s, <n> steps/s, <x>x real time`, and write this Mac's numbers into
  *Records → Measurements*. If start-up is over 5 s, or stepping is under 20×, say so there with
  the number; the targets in SC-001, SC-004 and SC-010 are not changed.
  **Accept:** `meson test -C build/meson_test --suite component-window -v | grep -q 'steps/s'`,
  and the *Measurements* row for M1 is filled.

### M2 — no GL at all

A second temporary test drives this milestone: `test_boot_nogl`, the same source built without
the hidden window and, on Linux and macOS, linked with the GL trap, in suite `component-nogl`. It
fails, naming a GL function, until the last site is guarded.

- [X] T016 [P] [US1] Write `tests/component-cpp/gl_trap_gen.py`
  ([contracts/runner.md](contracts/runner.md), *The GL trap generator*; examples C5): run the
  toolchain's `nm` over the given objects, collect every undefined GL function symbol, and write
  `gl_trap.cpp` with one definition per symbol that prints `GL call <name> while headless`, then a
  backtrace from `<execinfo.h>`, and aborts. The generated file includes no GL header. Exit 0 on
  success, 2 on a usage error or missing `nm`. `--self-test` builds a fixture object, runs the
  generator over it and checks the output. Mode `100755`. In `tests/component-cpp/meson.build`
  add the `custom_target` on Linux and macOS when `b_lto` is off, and define
  `OO_COMPONENT_GL_TRAP` for the programs that link it. With LTO on the trap is left out (its
  definitions would clash with the GL headers' at link time, a warning that may not be silenced)
  and meson prints a `message()` saying so.
  **Accept:** `tests/component-cpp/gl_trap_gen.py --self-test &&
  git ls-files -s tests/component-cpp/gl_trap_gen.py | grep -q '^100755'`.
- [X] T017 [US1] Give `OOGraphicsAvailable()` its meaning (research R2; contract
  *OOGraphicsAvailable*): `src/Core/OOOpenGLExtensionManager.h` / `.cpp` gain a headless state,
  set by `startHeadless`, that reports no GL and no shaders without calling `glGetString`, and
  `OOGraphicsAvailable()` reads it (true in the windowed game once the context exists). Register
  `test_boot_nogl` in suite `component-nogl` as described above.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` now fails with
  `GL call <name> while headless` for a function called **outside**
  `OOOpenGLExtensionManager.cpp` (before this task it names one inside it).
- [X] T018 [US1] Guard the `Universe` sites in `src/Core/Universe.cpp` with
  `if (!OOGraphicsAvailable()) return;` or the narrowest equivalent (examples C4):
  `initTargetFramebufferWithViewSize` (`:11349`), `setLighting`, `useGUILightSource`. A site whose
  skipped GL work feeds game state is not guarded: stop and record it under *Findings → GL sites*.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` no longer names a function
  whose backtrace is in `Universe.cpp`.
- [X] T019 [P] [US1] Guard the entity and script sites: `OOSunEntity::setSunColor`
  (`src/Core/Entities/OOSunEntity.cpp`), `SkyEntity::changeProperty`
  (`src/Core/Entities/SkyEntity.cpp`), the system setter at
  `src/Core/Scripting/OOJSSystem.cpp:577`.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` names none of these three
  files.
- [X] T020 [P] [US1] Textures are not decoded headless (`src/Core/Materials/OOTexture*.cpp`,
  `OOTextureLoader`): `OOTexture::checkExtensions`, `OOTextureLoader::setUp`, upload and
  `dimensions()` do nothing and report zero size; no loader thread is started; materials are the
  basic kind.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` names no function whose
  backtrace is in `src/Core/Materials`.
- [X] T021 [US1] Finish M2. Run `test_boot_nogl`; for each further site the trap names, add a task
  `T021a`, `T021b`, … (one site or one file each, its own commit, listed under *Findings → GL
  sites*) until it passes. Then remove the hidden window from `oo_component.cpp`, delete the
  `component-window` and `component-nogl` suites and the `test_boot_nogl` target, link the trap
  into every component program on Linux and macOS, and register `test_boot` in suite `component`.
  `test_boot` prints `GL trap: linked` or `GL trap: not linked (<reason>)`, and CI's Fedora and
  macOS steps fail unless the log has the first.
  Prove the trap works (quickstart step 4): remove the guard in `OOSunEntity::setSunColor`,
  rebuild, run, and paste the failing line into *Findings → GL sites*; restore the guard.
  **Accept:** `tests/run.sh component --cpp -k boot` passes with no window created, and CI's
  three jobs are green with `test_boot` in their logs, and `GL trap: linked` in the Fedora and
  macOS ones.

### M3 — the first scenario

- [X] T022 [US1] Wire the observer and the records (research R6; contract *OOGameObserver*;
  examples C7; data-model *Event record*). The controller holds an optional `OOGameObserver*`,
  null by default. `src/Core/Entities/ShipEntity.cpp` tells it of each ship script event where the
  event is dispatched, and the world-script dispatch site tells it of each world event, both
  before the scripts run. Each sound request is appended to the presentation record before the
  "sound not OK" path returns, and each frame the game would have drawn is counted. In
  `oo_component`: the event record (`time`, `kind`, `name`, `subject`, `text`, `isError`), a log
  sink installed with `oo::log::logger().setSink` that still writes the log file, `events()` with
  `has`, `count`, `firstOf`, `errors()`, `errorsSince`, `presentation()`, and
  `OO_COMPONENT_CHECK_NO_ERRORS`. `isError` is true for `scriptError`, and for `log` lines with
  the `***** ERROR` prefix or a class in this list: `shipData.load.error`, `setup.ship.badEntry.*`,
  `script.javaScript.exception.*`, `exception`, `equipment.load`. Cases in `test_boot.cpp`:
  `a_spawned_ship_raises_shipSpawned`, `a_thrown_script_error_is_an_error_entry`,
  `a_clean_run_has_no_errors`, `frames_and_sounds_asked_for_are_recorded` (US1 scenario 4).
  **Accept:** `tests/run.sh component --cpp -k boot && ./mk.sh test test`.
- [X] T022a [US1] The observer and the T012 clock reads made a `GameController` as a side effect
  (`sharedController()` makes one when none exists, and its constructor reseeds RANROT), so a core
  unit test with no controller saw role checks change by chance (`test_OOJSShip` `getterKind`,
  red in CI on `unit-tests-windows` at `01b466dea`). They use `GameController::currentObserver()`
  and `currentClock()`, which make nothing.
  **Accept:** `meson test -C build/meson_dev --suite core test_OOJSShip --repeat 10` and the unit
  tier pass; `unit-tests-windows` green on the next push.
- [X] T023 [US1] Add the scenario steps to `oo_component` (examples B1–B3; contract *Entities*,
  *Script expressions*, *Failure output*): `ShipsWithRole(role).count(n).withinKm(k)`,
  `spawn`, `countWithRole`, `engages`, `simulateUntil`, and `simulateAtMost(span)` (the windowed
  step "the simulation runs for at most N ticks": it stops early once every spawned role except
  `police` has no ship left). Each runs the **same script** as its step in
  `tests/component/steps/world_steps.py`, including `ROLE_SHIP_KEY`, `ROLE_AI`, `PIRATE_BOUNTY`
  and the locus the first spawn fixes; read that file, do not edit it. Every failed check prints
  the seed, the game time, the showing screen and the last ten event entries. Cases in
  `test_boot.cpp`: `spawn_returns_the_ships_it_added`, `spawned_ships_carry_the_scenario_role`,
  `within_km_is_measured_from_the_first_spawn`.
  **Accept:** `tests/run.sh component --cpp -k boot`.
- [X] T024 [US1] Port S1 as `tests/component-cpp/test_s1_police_kills_pirate.cpp` (examples A1),
  the exemplar for C++ component tests: seed 20260910; one `police`; one `pirate` within 10 km;
  within `ticks(900)` a `police` ship engages a `pirate` ship; a `police` ship survives;
  `OO_COMPONENT_CHECK_NO_ERRORS`. Each check carries the Gherkin line it ports as a comment. Its
  last output line is `game <s> s, real <s> s, <x>x`. If it disagrees with the windowed original,
  stop and report under *Findings* (FR-032); change neither.
  **Accept:** `tests/run.sh component --cpp -k s1_police_kills_pirate`.
- [X] T025 [US1] Repeatability (research R4; data-model *Scenario digest*; contract *Repeat
  check*). `Game::digest()` hashes, per step, every entity's id, definition key, position,
  orientation and energy, and the event record so far. Every scenario program takes
  `--digest-out <path>` and writes one digest per step. `tests/component-cpp/test_repeat.cpp` runs
  `test_s1_police_kills_pirate --digest-out` twice as child processes and compares the files,
  reporting the first step that differs. `tests/component-cpp/repeat_100.sh <program>` does the
  same 100 times, prints `100 runs, identical`, and is `100755`. Each cause of a difference
  (hash-map order, pointer-keyed containers, the octree build) is its own task `T025a`, … listed
  under *Findings → Repeatability*.
  **Accept:** `tests/run.sh component --cpp -k repeat &&
  tests/component-cpp/repeat_100.sh test_s1_police_kills_pirate`.
- [X] T026 [US1] Measure SC-001 and SC-002 and write them into *Records → Measurements*: S1's
  game-to-real ratio and total real time on this Mac and from each CI job's log, and the
  `repeat_100.sh` result. On Linux CI the S1 step runs with `env -u DISPLAY -u WAYLAND_DISPLAY`.
  **Accept:** CI's three jobs are green with `test_s1_police_kills_pirate` and `test_repeat` in
  their logs; the *Measurements* rows for SC-001 and SC-002 are filled.

**Checkpoint**: US1 is done. A developer can write a scenario by copying
`test_s1_police_kills_pirate.cpp`. The four tiers match the baselines.

---

## Phase 4: User Story 6 — one behaviour of one ship (P2), the three tests that need no keys

**Goal**: a few-line test adds a ship, calls the game's own methods on it, simulates and asserts.

**Independent Test**: the three programs pass with no display; each fails with
`--without-weapon`.

- [X] T027 [US6] Add the plain style to `oo_component` (examples A0, B1; contract *Entities*,
  *Who owns what*, *Ship handles*): `ShipWithKey(key).at(position)` / `.aheadOf(entity, metres)` /
  `.near(entity, metres)`, `add` (the ship is made with `Universe::newShipWithName`, placed, added
  with `Universe::addEntity`, and the owning pointer dropped), `spawnKey` (returns the
  `std::shared_ptr<ShipEntity>`), `remove`, `shipsWithRole`, `entityCount`, and `ShipHandle`:
  `alive()`, `id()` kept after the ship is gone, `operator->` that fails the test by name if the
  ship is gone, conversion to `ShipEntity*` that is null if gone. `spawn` and `shipsWithRole`
  return handles. `events().has(name, handle)` matches by id, so it works after the ship is gone.
  Cases in `test_boot.cpp`: `a_removed_ship_is_gone_for_its_handle` (after `game.remove`,
  `alive()` is false and `entityCount()` is back to what it was), and
  `a_handle_does_not_keep_a_ship_alive` (the ship's use count is unchanged by taking a handle).
  **Accept:** `tests/run.sh component --cpp -k boot`.
- [X] T028 [P] [US6] `tests/component-cpp/test_laser_fires.cpp` (examples A0.1; US6 scenario 1):
  a ship with `EQ_WEAPON_PULSE_LASER` on its forward mount and a target directly ahead in range;
  `fireMainWeapon`; the weapon heats (`laserHeatLevelForward()`), the target's energy drops, and
  the record has `shipBeingAttacked` for the target. `--without-weapon` skips `setWeaponMount`.
  **Accept:** `tests/run.sh component --cpp -k laser_fires &&
  ! build/meson_test/tests/component-cpp/test_laser_fires --without-weapon`, and the failing
  output names the seed and the game time (FR-014).
- [X] T029 [P] [US6] `tests/component-cpp/test_ship_attacks.cpp` (US6 scenario 2): a ship with a
  laser, a target a few kilometres away, `addTarget` and `performAttack`; within 60 s of game time
  the target has been attacked and has lost energy. `--without-weapon` as above.
  **Accept:** `tests/run.sh component --cpp -k ship_attacks &&
  ! build/meson_test/tests/component-cpp/test_ship_attacks --without-weapon`.
- [X] T030 [P] [US6] `tests/component-cpp/test_mining_laser.cpp` (examples A0.1; US6 scenarios 3
  and 6): an `asteroid` near the player, an `adder` 2 km from it with
  `EQ_WEAPON_MINING_LASER`, `performMining`; within 2 minutes the asteroid's handle is not
  `alive()`, at least two ships of role `boulder` exist where there were none, and
  `events().has("shipDied", asteroid)`. `--without-weapon` as above.
  **Accept:** `tests/run.sh component --cpp -k mining_laser &&
  ! build/meson_test/tests/component-cpp/test_mining_laser --without-weapon`.
- [X] T031 [US6] The M3 gate. Push; record each of the three tests' real time per platform in
  *Records → Measurements* (SC-012 asks for under 15 s each).
  **Accept:** CI's three jobs are green with the three tests in their logs; the four tiers match the baselines.

**Checkpoint**: the main milestone (plan M3). After it, phases 5, 6 and 9 touch different files
except `oo_component`, whose additions are per area, and may be done in any order.

---

## Phase 5: User Story 2 — every ship and every equipment item is tried (P2)

**Goal**: one program gives every definition in the core data exactly one outcome.

**Independent Test**: `tests/run.sh component --cpp -k census` exits 0 with every definition
accounted for; with the broken-ship overlay it exits 1 and names that key only.

In the Accept lines below `component_census` is
`build/meson_test/tests/component-cpp/component_census`, run from the worktree root, and scratch
files go under `build/meson_test/component/`.

- [X] T032 [US2] Start `tests/component-cpp/component_census.cpp` with enumeration and `--list`
  ([contracts/census.md](contracts/census.md); data-model *Definition*). Ships are every
  top-level key of the merged core `shipdata.plist`, equipment every entry of `equipment.plist`,
  both read at run time through the game's own loaders; no name is written in the program
  (FR-017). Classes: `template` (the definition has `is_template`); `part` (the registry tagged it
  as a sub-part and no role selects it); `service` (an equipment item with no fitted state after
  award: `EQ_FUEL`, `EQ_RENOVATION`, `EQ_MISSILE_REMOVAL`, `EQ_PASSENGER_BERTH_REMOVAL` are what
  the data holds today, recognised by behaviour, not by name); `candidate` (everything else).
  `--list` prints `kind`, `key`, `class` per row, sorted, then the totals. Write the totals into
  *Records → Measurements* (194 ships and 41 items at the research commit).
  **Accept:** `component_census --list | tail -1 | grep -Eq '^[0-9]+ ships, [0-9]+ equipment$'`, and no row has a class outside the four.
- [X] T033 [US2] `--only <kind>:<key>` tries one definition in this process and prints its report
  row (`kind`, `key`, `class`, `outcome`, `seed`, `gameTime`, `evidence`). The game is reseeded
  from the base seed (`--seed`, default 20260910) and the key first. **A ship**: spawned by key
  near the player in the empty system with `spawnKey`, run 10 s of game time, checked, removed.
  It passes only if: "spawn returned an entity; it is in the universe at the end of the span; it
  has one attached part for each sub-part its definition declares; no error entry in the event
  record names it or occurred during its span; after removal the entity count equals the count
  before the spawn." **An equipment item**: on the player's ship, or a pylon for missiles and
  mines, run 5 s. It passes only if: "award succeeded; the ship reports it fitted; activation, if
  it has a script, raised no error; no error entry during its span; after removal the ship no
  longer reports it." A station gets a system, a missile a target, an escort a leader; a need
  that cannot be met is `not-applicable` with the reason. A `part` is `not-applicable` only if at
  least one ship that carries it passed, otherwise `failed` with "no passing parent" (decided by
  the parent in T034).
  **Accept:** `component_census --only ship:adder` and `--only equipment:EQ_ECM` each print one
  row with outcome `passed` and exit 0; `--only ship:no-such-key` exits 2.
- [X] T034 [US2] The whole run ([contracts/census.md](contracts/census.md), *How a run goes*,
  *Output*, *Exit codes*): the parent starts itself as a child with
  `--child --from <index> --progress <path>`; the child writes the index and key to the progress
  file and flushes before each try, and stops with a distinct exit code when a definition leaves
  the universe unclean, recording it `failed` first; on any other nonzero exit or a kill the
  parent records the definition being tried as `failed` with "child exited <code>" and the tail
  of the child's output, and starts a new child at the next index; more than 50 restarts stops the
  run with exit 2. The parent sorts the rows by kind and key, writes
  `<build>/component/census-report.tsv` (`--report` overrides), prints one line per `failed`
  definition and the summary
  `component_census: <n> ships, <m> equipment: P passed, L left, N not-applicable, F failed, X expected`.
  Exit 0, 1 or 2 as the contract's table says; no definitions found or a count that differs from
  the data's is 2 (FR-020).
  **Accept:** `component_census --report build/meson_test/component/census-try.tsv;
  test $? -le 1` and the report's
  row count equals `component_census --list`'s total; a child killed by hand mid-run (send
  `SIGKILL` to the child once) still yields a full report with that key `failed`.
- [X] T035 [US2] The expectations file `tests/component-cpp/census-expectations.tsv` (columns
  `kind`, `key`, `expect`, `reason`; `expect` is `failed`, `left` or `not-applicable`) and its
  checks in the parent: "a key not in the data is an error; a listed definition whose outcome
  differs from `expect` is an error (so a fixed fault must be taken off the list); an empty
  `reason` is an error." The first and third exit 2, the second exits 1. A definition that
  removes itself within the span is `left` only if the file says so. The file starts with its
  header and no rows.
  **Accept:** with scratch copies passed by `--expectations`: a file naming an unknown key
  gives exit 2; one with an empty reason gives exit 2; one listing `ship adder failed <reason>`
  gives exit 1 naming `adder`; the committed file gives 0 or 1, never 2.
- [X] T036 [US2] Prove the census can fail: `--data-overlay <dir>` merges one fixture
  `shipdata.plist` after the core data, and
  `tests/component-cpp/fixtures/broken-ship/shipdata.plist` holds one definition whose model does
  not exist.
  **Accept:** `component_census --data-overlay tests/component-cpp/fixtures/broken-ship;
  test $? -eq 1`, and its output names the fixture's key and no other as an unexpected failure.
- [X] T037 [US2] The first full run. Register
  `test('census', component_census, suite: 'component', timeout: 600)` in
  `tests/component-cpp/meson.build`. Run it, and write every `failed` and `left` definition under
  *Records → Findings → Census* with its key, seed and evidence (FR-022). For each: a small fix to
  the game or the core data that unblocks it is its own task `T037a`, … with the census row as its
  Accept; anything larger gets a row in `census-expectations.tsv` with a one-sentence reason and
  an entry under *For Jon*, who adjudicates the list. Record the census's real time (SC-004:
  under 5 minutes) and the counts (SC-003).
  **Accept:** `tests/run.sh component --cpp -k census` exits 0; CI's three jobs are green with
  `census` in their logs.

**Checkpoint**: US2 is done. A definition added to the core data is tried without editing a test.

---

## Phase 6: User Story 3 — menus and the tutorial answer to keys (P2), and US6's fire key

**Goal**: tests press real SDL key events into the game's own input loop, under three keyboard
layouts, on three platforms.

**Independent Test**: `tests/run.sh component --cpp -k menus` and `-k tutorial_keys` pass with no
display under `us`, `fr_azerty` and `ru`; with `n` remapped in one layout table the tutorial test
fails and names the press.

- [X] T038 [US3] `MyOpenGLView::initHeadless()` in `src/SDL/MyOpenGLView.h` / `.cpp` (contract
  *initHeadless*; research R7): SDL's events and video subsystems with the video driver hint set
  to `dummy`, no audio, joystick or gamepad subsystem, no window, no GL context, a fixed nominal
  view size. `startHeadless` creates the view this way when `options.inputView`, and
  `Game::step` calls the real `pollControls()` before each `tick` when there is a view. Add
  `Game::atStartScreen(seed)` (populate on, not in flight) and `Game::screen()`. If T005 found no
  dummy driver on a platform, use the events subsystem alone there and record it under
  *Decisions*. Start `tests/component-cpp/test_menus.cpp` with the case
  `the_start_screen_shows`. The start screen's demo ships and text are new ground for the GL
  trap: each site it names is a task `T038a`, …; if one needs more than a guard, start the menu
  game with that element off and record the limit of FR-025 under *Findings → GL sites*.
  **Accept:** `tests/run.sh component --cpp -k menus && ./mk.sh test test`.
- [X] T039 [US3] The key-lookup member (contract *Key lookup member*; examples C6):
  `MyOpenGLView` gains one replaceable member that maps (scancode, modifiers) to a key code,
  defaulting to `SDL_GetKeyFromScancode(scancode, modifiers, false)`, and
  `src/SDL/MyOpenGLView+Input.cpp` calls it at the one place that line is today (`:365`).
  Nothing else in the file changes. Case in `test_menus.cpp`:
  `the_default_lookup_is_sdls_own` (for every scancode and the modifier sets `-`, `shift`,
  `caps`, the member's answer equals SDL's).
  **Accept:** `tests/run.sh component --cpp -k menus && ./mk.sh test test`.
- [X] T040 [US3] Keys and screens in `oo_component` (contract *Keys and screens*; data-model *Key
  event*, *Recorded layout*; examples B3): `press` (key down, steps until the game has sampled
  it, key up, steps until sampled), `hold`, `pressScancode`, `keyDownScancode`, `keyUpScancode`,
  `type`, `useLayout(name)` and the `--layout <name-or-path>` program argument, `selectedRow`,
  `rowText`, `rowKey`, `selectRowWithKey` (fails after one full cycle), `exitRequested`, and
  `OO_COMPONENT_PRESS_EXPECT`, which fails with
  `pressing <key> had no effect at <screen>, game time <t>` and the layout's translation of the
  key. Every press is `SDL_EVENT_KEY_DOWN` / `SDL_EVENT_KEY_UP` pushed with `SDL_PushEvent`;
  `keys[]` is never written directly. A layout file has the columns `scancode`, `mods` (`-`,
  `shift`, `caps`, `shift+caps`, `altgr`), `keycode` (hex), `comment`, and a header comment saying
  how it was recorded and on what system. Write `tests/component-cpp/layouts/us.tsv` from SDL's
  built-in map. Cases in `test_menus.cpp`: `us_tsv_agrees_with_sdls_built_in_map`,
  `down_up_and_enter_move_and_open` (US3 scenario 1), `a_held_enter_acts_once` (scenario 5).
  **Accept:** `tests/run.sh component --cpp -k menus`.
- [X] T041 [P] [US3] Record the other two layouts,
  `tests/component-cpp/layouts/fr_azerty.tsv` and `ru.tsv` (FR-027; examples C8). Add a small
  program `tests/component-cpp/record_layout.cpp` (built, not registered as a test) that starts
  SDL's real video backend and prints the table for the current layout. **Do not change this
  Mac's keyboard layout.** Default: CI's `build-fedora` job gains a step that runs it under a
  throwaway X server (`xvfb-run`, with `setxkbmap fr` and then `setxkbmap ru`), uploads the two
  tables as an artifact, and fails if a committed table differs from the fresh one. Fetch the
  first run's artifact with `gh run download` and commit the files with the run's URL in their
  headers. If that job cannot run an X server, derive both tables from xkeyboard-config's
  `fr(basic)` and `ru(basic)`, say "derived, not recorded" in each header, drop the CI step, and
  add an entry under *For Jon* asking for a real recording.
  **Accept:** both files load (case `every_layout_file_loads` in `test_menus.cpp`), `fr_azerty`
  gives `a` for `SDL_SCANCODE_Q`, and `ru` gives a code point above 326 for `SDL_SCANCODE_N`.
- [X] T042 [US3] The menu walk in `tests/component-cpp/test_menus.cpp` (examples A4; FR-024,
  FR-025; US3 scenarios 2, 6, 7): for every selectable row the start screen itself reports, and
  for every row on the options screens beneath it, select it by key, open it, check the screen
  that shows, back out by key and check the game is where it was. The rows are counted from the
  game's own menu, never listed in the test (SC-006), and the count visited is asserted equal to
  the count reported. *Manage Expansion Packs* is opened and left; no row on it is activated
  (hard rule 4). The exit row is checked through `exitRequested()`. Register the program three
  times in meson, with `--layout us`, `fr_azerty` and `ru`. One case asserts that every user
  directory the game resolved is under the scratch directory.
  **Accept:** `tests/run.sh component --cpp -k menus` (three tests).
- [X] T043 [US3] The tutorial by `n`: `tests/component-cpp/tutorial_steps.hpp` (`StartTutorial`,
  `Progress`, `Stage`) and `tests/component-cpp/test_tutorial_keys.cpp` (examples A5; FR-026).
  `StartTutorial` goes *Start New Commander* → the scenario screen → the tutorial scenario →
  Enter → the mission screen, Enter → launch → lesson 0 step 2, checking the screen after each
  press. `Progress` presses the game's own *activate equipment* key, looked up from the game's key
  settings and not written as `n`, with `OO_COMPONENT_PRESS_EXPECT`, for every step of lessons 0
  and 1, checking the tutorial's stage moved each time. Take the step list from the game's
  tutorial script state at run time; read `tests/component/steps/tutorial_steps.py` for what the
  windowed walkthrough checks, and do not edit it. Register three tests, one per layout.
  **Accept:** `tests/run.sh component --cpp -k tutorial_keys` (three tests).
- [X] T044 [US3] Show the key tests can fail (FR-029, SC-007): the fixture
  `tests/component-cpp/fixtures/us-n-remapped.tsv` is `us.tsv` with the `n` key's row giving
  another letter.
  **Accept:** `! build/meson_test/tests/component-cpp/test_tutorial_keys --layout
  tests/component-cpp/fixtures/us-n-remapped.tsv`, its output contains
  `pressing n had no effect at`, and `--layout us` still passes. Paste the failing line into
  *Records → Findings → Keys*.
- [X] T045 [US3] Games that start with keys and settings (contract *Creating a game*, *Keys and
  screens*; FR-037, FR-039): `Settings().remapKey(control, key)` and `.keyboardCode(code)`,
  written to the test's private settings file before the game starts in the form the keyboard
  settings screen stores (`KeyConfigOverrides`, as `PlayerEntity::saveKeySetting` writes it);
  `Game::inFlightWithKeys(seed, settings)` (the scenario game with `inputView` true);
  `Game::docked(seed, settings)` (a new commander docked at the main station, with keys). Each
  needs a program of its own (one game per process), so this task's tests are T046's and T047's.
  **Accept:** as T046 (pushed together).
- [X] T046 [US3] `tests/component-cpp/test_launch_key.cpp` (examples A0.2; FR-038; US3 scenarios
  8 and 9): docked; hold the launch key (`key_launch_ship`, `1`) until the player is in flight
  and `Universe::breakPatternOver()`; exactly one `shipLaunchedFromStation`; press the key again
  and simulate 5 s; still in flight, the break pattern is not replayed, the view is forward, and
  the count is still one. Before the launch cases, one case exercises `game.type(text)` on the
  first text-entry screen reachable by key from the docked game (default: the long-range chart's
  find-system entry) and checks the text arrived; if none is reachable without a save file,
  record that under *Decisions* and keep `type` covered by the case in T040's file instead.
  **Accept:** `tests/run.sh component --cpp -k launch_key`.
- [X] T047 [P] [US3] `tests/component-cpp/test_remapped_key.cpp` (FR-039; US3 scenario 10):
  `Game::inFlightWithKeys(20260910, Settings().remapKey("key_fire_lasers", "k"))`, a target
  ahead; holding `k` heats the weapon and drains the target; holding the old key `a` does
  neither.
  **Accept:** `tests/run.sh component --cpp -k remapped_key`.
- [X] T048 [P] [US6] `tests/component-cpp/test_fire_key.cpp` (US6 scenario 4): the player in
  flight with a pulse laser and a target directly ahead; holding the fire key (looked up from the
  key settings) drops the target's energy and heats the player's weapon. `--without-weapon` as in
  T028.
  **Accept:** `tests/run.sh component --cpp -k fire_key &&
  ! build/meson_test/tests/component-cpp/test_fire_key --without-weapon`.
- [ ] T049 [US3] The M5 gate. Push; record per platform under *Measurements* that the menu,
  tutorial, launch-key, remapped-key and fire-key tests passed (SC-005, SC-013).
  **Accept:** CI's three jobs are green with those tests in their logs; the four tiers match the baselines.

**Checkpoint**: US3 and US6 are done.

---

## Phase 7: Sanitizers and the Flatpak leg (M6)

**Purpose**: FR-015 and FR-028. Needs Phase 6.

- [ ] T050 Run the suite under address and undefined-behaviour sanitizers
  ([contracts/runner.md](contracts/runner.md), *Sanitizers*):
  `meson setup build/meson_asan -Db_sanitize=address,undefined -Db_lto=false`, then
  `meson test -C build/meson_asan --suite component --print-errorlogs -t 4`. No suppression is
  added. Each report is a finding under *Records → Findings → Sanitizers*; a small fix is its own
  task `T050a`, … with a test where one can be written; one that cannot be fixed here is recorded
  with its stack and listed under *For Jon*. This covers the census (US2 scenario 7).
  **Accept:** the `meson test` command above exits 0 with no sanitizer report in
  `build/meson_asan/meson-logs/testlog.txt`, or every remaining report is recorded as above.
- [ ] T051 The Flatpak leg ([contracts/runner.md](contracts/runner.md), *CI*; FR-028; US4
  scenario 1). Read `installers/flatpak/create_flatpak_fn.sh` and
  `installers/flatpak/space.oolite.Oolite.yaml` first. When `OO_FLATPAK_RUN_COMPONENT=1`, the
  manifest's `oolite` module, before install, also builds the test flavour with LTO off inside
  the build sandbox and runs `meson test --suite component` there (the module itself builds
  `deployment`, which builds no tests). Without the variable nothing changes for a packager. CI's
  `build-flatpak` job sets it. If the sandbox cannot run the suite (no writable scratch, no
  `nm`), record the error under *Findings → Flatpak*: FR-028 is then met by the Fedora leg only,
  and that is reported, not worked around.
  **Accept:** the `build-flatpak` job's log shows `meson test`'s summary for suite `component`
  (the URL is under *CI runs*), or the recorded error with its log lines.

---

## Phase 8: User Story 4 — the Flatpak `n` report (P3)

**Goal**: the report is reproduced and fixed, or ruled out with a written finding.

**Independent Test**: *Records → Finding: the Flatpak `n` report* names a test that failed before a
named fix and passes after it, or holds the three parts FR-030 requires.

- [X] T052 [US4] `tests/component-cpp/test_key_faults.cpp` (examples A6; research H1–H5): one case
  per observation, each stating what a player should see, each in flight with an equipment item
  primed so that *activate equipment* has a visible effect. **H1** with Caps Lock on, the `n` key
  activates. **H2** under `ru`, the `n` key activates. **H3** with an extra modifier bit that is
  not shift, ctrl or alt in the setting's sense (AltGr reported as Alt; Num Lock), the `n` key
  activates. **H4** pressing Caps Lock or Num Lock alone does not act as `9` or `S`. **H5** a
  scancode above 326 does not read outside `scancode2Unicode` (the sanitizer build is this
  case's judge). Register each case as its own meson test (`key_fault_h1` … `key_fault_h5`).
  Record each case's result per platform under *Findings → Keys*. A failing case is a finding,
  not a verdict: it is not rewritten to pass.
  **Accept:** `tests/run.sh component --cpp -k key_fault` runs five tests to a result, and each
  result is recorded.
- [X] T053 [US4] For each case of T052 that fails: read the same code in `upstream/oolite`
  (reference only) and record whether upstream has the same fault or the port introduced it. Fix
  it here, in its own commit `T053a`, …, if the fix is small and one of those holds; the case then
  passes and stays in the suite. Otherwise register that one test with `should_fail: true` and a
  comment naming its entry in the finding, so it is checked both ways like the census's list, and
  list it under *For Jon*.
  **Accept:** `tests/run.sh component --cpp -k key_fault` exits 0, and
  `meson test -C build/meson_asan --suite component` is still clean.
- [ ] T054 [US4] Write *Records → Finding: the Flatpak `n` report* (FR-030, SC-008; US4 scenario
  3) with the result of the key tests inside the Flatpak environment (T051), and either the
  failing-then-passing case and its fix, or the three parts: what the tests covered (the game's
  whole handling of a key, under three layouts, on each platform's SDL); what they cannot cover
  (SDL's Win32, Cocoa, X11 and Wayland layout step, window focus including H7's XWayland note,
  input methods, the sandbox's access to input devices, and whether the report was against
  upstream's Objective-C build); and a manual procedure for those, including H6's game-side
  conditions (`n` on the mission screen, during launch, after Shift+N re-primed another item).
  **Accept:**
  `! grep -q '_not written_' <(sed -n '/^### Finding: the Flatpak/,/^### /p' specs/011-headless-component-tests/tasks.md)`.

**Checkpoint**: US4 is closed either way.

---

## Phase 9: User Story 5 — the other seven scenarios (P3)

**Goal**: S2–S8 each have a C++ counterpart with the original's seed, spawns and assertions.

**Independent Test**: all eight pass with no display, in less total real time than one windowed
scenario takes.

Each file has the same base name as its windowed original, carries the Gherkin lines as comments,
uses only the steps of T023, ends with `OO_COMPONENT_CHECK_NO_ERRORS`, and takes `--digest-out`.
"at most 900 ticks" is `simulateAtMost(ticks(900))`; "runs for 900 ticks" is
`simulate(ticks(900))`. If a counterpart disagrees with its original, stop work on that scenario
and report it under *Findings* (FR-032); change neither.

- [X] T055 [P] [US5] `tests/component-cpp/test_s2_pirate_attacks_target_registers_attacker.cpp`:
  seed 20260918; 1 `trader`; 1 `pirate` within 10 km; at most 900 ticks; a `trader` survives.
  **Accept:** `tests/run.sh component --cpp -k s2_`.
- [X] T056 [P] [US5] `tests/component-cpp/test_s3_hostile_spawn_drives_ship_into_attack.cpp`:
  seed 20260918; 1 `trader`; 1 `pirate` within 10 km; at most 900 ticks; a `trader` survives.
  **Accept:** `tests/run.sh component --cpp -k s3_`.
- [X] T057 [P] [US5] `tests/component-cpp/test_s4_missile_armed_ship_kills_by_missile.cpp`: seed
  20260918; 1 `pirate`; 1 `trader` within 10 km; at most 900 ticks; a `pirate` survives.
  **Accept:** `tests/run.sh component --cpp -k s4_`.
- [X] T058 [P] [US5] `tests/component-cpp/test_s5_escorts_converge_on_their_mother.cpp`: seed
  20260910; 1 `trader`; 2 `escort` within 5 km; at most 900 ticks; an `escort` survives.
  **Accept:** `tests/run.sh component --cpp -k s5_`.
- [X] T059 [P] [US5] `tests/component-cpp/test_s6_damaged_ship_flees.cpp`: seed 20260918; 1
  `police`; 1 `pirate` within 10 km; at most 900 ticks; a `police` ship survives.
  **Accept:** `tests/run.sh component --cpp -k s6_`.
- [X] T060 [P] [US5] `tests/component-cpp/test_s7_neutral_traffic_is_quiet.cpp`: seed 20260910; 8
  `shuttle`; runs for 900 ticks; a `shuttle` survives.
  **Accept:** `tests/run.sh component --cpp -k s7_`.
- [X] T061 [P] [US5] `tests/component-cpp/test_s8_destroyed_ships_leave_allships.cpp`: seed
  20260910; 1 `pirate`; 8 `police` within 10 km; runs for 900 ticks; a `police` ship survives.
  **Accept:** `tests/run.sh component --cpp -k s8_`.
- [ ] T062 [US5] The M8 gate. Record the eight scenarios' total real time against the windowed
  baseline of one (SC-009) under *Measurements*.
  **Accept:** `for n in 1 2 3 4 5 6 7 8; do tests/run.sh component --cpp -k "test_s${n}_" ||
  exit 1; done`;
  `git diff --stat <base> -- tests/component tests/gui tests/unit` is empty (US5 scenario 3,
  FR-031); CI's three jobs are green.

**Checkpoint**: US5 is done.

---

## Phase 10: Polish (M9)

- [X] T063 [P] Docs, in the planning repo (FR-033): `docs/current-state.md` (the component tier
  has a headless C++ half and a windowed half; what the C++ half covers and does not),
  `docs/workflow.md` (the commands, how to add a scenario, the census's expectations file),
  `GLOSSARY.md` (component test, headless, windowed, census, GL trap, recorded layout),
  `CLAUDE.md` (*Commands*: `tests/run.sh component [--cpp|--windowed] [-k name]`; *Exemplars*: a
  row "C++ component test | `oolite-dev/tests/component-cpp/test_s1_police_kills_pirate.cpp`";
  the file stays under 1,000 words), and one line in
  `specs/003-encapsulate-global-state/spec.md` saying this feature delivered its User Story 3,
  SC-001 and SC-002 with one game per process and that `OOHeadlessOptions` is its
  `OOUniverseOptions`. Describe the code as it is; add no history.
  **Accept:** `grep -q 'component-cpp' CLAUDE.md docs/current-state.md docs/workflow.md &&
  grep -qi 'GL trap' GLOSSARY.md && grep -q '011' specs/003-encapsulate-global-state/spec.md &&
  test "$(wc -w < CLAUDE.md)" -lt 1000`.
- [ ] T064 Run [quickstart.md](quickstart.md) from top to bottom in the worktree, steps 1 to 9,
  and record each step's result under *Records → Quickstart*.
  **Accept:** every step has a recorded result, and none is "failed" without a finding beside it.
- [ ] T065 Final measurements under *Records → Measurements*: the whole tier in parallel
  (`meson test -C build/meson_test --suite component`; SC-010: under 10 minutes) and one at a
  time (`--num-processes 1`), with the same results; the smoke run's frame time against the
  baseline (SC-011: within 2%); `repeat_100.sh` once more for S1 and one of S2–S8; and FR-016:
  `./mk.sh build deployment` builds nothing under `tests/component-cpp`, and the deployment
  build's install list is the same as at the base commit. FR-011: if no CI job builds the suite
  with GCC, add the GCC build of the suite to the job that already has that toolchain
  (`--native-file=gcc.ini`), or record under *For Jon* that it could not be added and why.
  **Accept:** the rows are filled; a target that was missed is stated with its number.
- [ ] T066 Close out. Every task above is ticked with its commit; *Records → Branch state* says
  whether `origin/seriesb/029-component-tests` matches the local branch or is stale and needs
  Jon's force-push; *For Jon* lists what is his: merging the branch, adjudicating
  `census-expectations.tsv` and any `should_fail` key-fault case, any real layout recording still
  wanted. Nothing is left uncommitted in the worktree or in `specs/011-headless-component-tests`.
  **Accept:** `git -C .agent-tmp/wt-component-tests status --porcelain | wc -l` prints 0, and
  `! grep -nE '^- \[ \] T0' specs/011-headless-component-tests/tasks.md`.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 → Phase 2 → Phase 3** are strictly sequential (plan: M0 → M1 → M2 → M3).
- **Phase 4** needs Phase 3 (T023's steps and T022's records).
- **Phases 5, 6 and 9** each need Phase 4's T027 and are independent of one another.
- **Phase 7** needs Phase 6 (the key tests must exist to run in the Flatpak sandbox) and benefits
  from Phase 5 (the census under sanitizers).
- **Phase 8** needs Phases 6 and 7.
- **Phase 10** is last.

### Story dependencies

| Story | Needs | Independent of |
|---|---|---|
| US1 (P1) | Phase 2 | everything else |
| US6 (P2) | US1; its fire-key test also needs T045 | US2, US5 |
| US2 (P2) | US1, T027 | US3, US5 |
| US3 (P2) | US1, T027 | US2, US5 |
| US4 (P3) | US3, T050, T051 | US2, US5 |
| US5 (P3) | US1 | US2, US3 |

### Within Phase 3

T007 → T008 → T009 → T010 → T011 (T009–T011 are pushed together) → T012 → T013 → T015;
T014 any time after T011. T016 any time. T017 → T018 → {T019, T020} → T021. T022 → T023 → T024 →
T025 → T026.

### Parallel opportunities

- T005 beside T004; T014 and T016 beside the M1 chain.
- T019 and T020 after T018.
- T028, T029, T030 after T027.
- T041 beside T042 and T043; T047 and T048 after T046.
- T055–T061, all seven.
- After T031, one line each on Phase 5, Phase 6 and Phase 9. They all commit to one branch, so
  "parallel" means any order, or separate sessions that each rebase their local commits onto the
  branch tip before pushing (a plain fast-forward push; never a force-push).

## Parallel example: Phase 9

```text
Task: "T055 test_s2_pirate_attacks_target_registers_attacker.cpp"
Task: "T056 test_s3_hostile_spawn_drives_ship_into_attack.cpp"
Task: "T057 test_s4_missile_armed_ship_kills_by_missile.cpp"
Task: "T058 test_s5_escorts_converge_on_their_mother.cpp"
Task: "T059 test_s6_damaged_ship_flees.cpp"
Task: "T060 test_s7_neutral_traffic_is_quiet.cpp"
Task: "T061 test_s8_destroyed_ships_leave_allships.cpp"
```

Each adds one file and one line to the program list in `tests/component-cpp/meson.build`; that
line is the only place two of them meet.

## Implementation strategy

### MVP first (US1)

1. Phase 1 and Phase 2: the empty suite is green on three platforms.
2. Phase 3: the game boots headless, makes no GL call, and S1 passes repeatably.
3. **Stop and validate**: quickstart steps 1 to 4. This alone replaces the slowest part of the
   developer loop.

### Then, in this order by default

4. Phase 4: the three basic tests, which are the pattern for every later small test.
5. Phase 5: the census.
6. Phase 6: keys and menus.
7. Phases 7 and 8: sanitizers, Flatpak, the `n` report.
8. Phase 9: S2–S8.
9. Phase 10.

Phase 9 is cheap and may be pulled forward to any point after Phase 4.

## Requirements to tasks

| Requirement | Tasks |
|---|---|
| FR-001 no devices | T010, T021, T038 |
| FR-002 same code and data | T008, T009, T010 |
| FR-003 carry on without devices; name what cannot | T016–T022 |
| FR-004 advance by game time, fixed steps, no waiting | T008, T011 |
| FR-005 everything follows simulated time; exceptions listed | T012, T013, T014 |
| FR-006 seed and repeatability | T009, T013, T025 |
| FR-007 spawn, find, read events | T022, T023, T027 |
| FR-008 private settings, saves, logs, caches | T011, T042 |
| FR-009 no dependency on spec 003 | T011 (one game per process) |
| FR-010 a named tier in the runner | T004 |
| FR-011 three platforms, Clang and GCC | T003, T006, T065 |
| FR-012 parallel, no exclusive resource | T003, T011, T065 |
| FR-013 real-time limit, reported by name | T003, T011 |
| FR-014 failure output and rerun command | T004, T023, T028 |
| FR-015 sanitizers | T050 |
| FR-016 shipped game unchanged | T008, T065 |
| FR-017 census list from the data | T032 |
| FR-018, FR-019 ship and equipment pass conditions | T033 |
| FR-020 one outcome each; count checked | T034 |
| FR-021 one failure does not stop or alter the rest | T033, T034 |
| FR-022 findings and the expectations list, both ways | T035, T037 |
| FR-023 press, hold, release, text, through the real queue | T040, T046 |
| FR-024 read screen, selection, rows | T040 |
| FR-025 every start-screen and options entry | T042 |
| FR-026 tutorial lessons 0 and 1 by the "next" control | T043 |
| FR-027 three recorded layouts | T040, T041, T042, T043 |
| FR-028 inside the Flatpak build environment | T051 |
| FR-029 the key tests can fail | T044 |
| FR-030 the report's outcome | T052, T053, T054 |
| FR-031 existing tiers unchanged | every checkpoint, T062 |
| FR-032 S1–S8 counterparts; disagreement stops work | T024, T055–T061 |
| FR-033 docs, commands, exemplar, glossary | T063 |
| FR-034 four basic behaviours | T028, T029, T030, T048 |
| FR-035 add one ship by key at a place | T027 |
| FR-036 a handle does not keep a ship alive | T027, T030 |
| FR-037 an in-flight game takes keys | T045, T047, T048 |
| FR-038 the launch key launches once | T046 |
| FR-039 a remapped control | T045, T047 |

---

## Records

Filled in as tasks finish. A placeholder in italics is what an Accept command looks for.

### Base

- The branch is **`seriesb/029-cpp-component-tests`**, which Jon cut on 2026-11-14 on top of
  `seriesb/028-upstream-772-tests` (git town parent 028; 028's own parent is 027) and checked out
  in the main `oolite-dev` checkout. It replaces the `seriesb/029-component-tests` worktree T001
  named: git cannot check one branch out twice, the main checkout was clean, and Jon's branch is
  the stack as it now is (see *Decisions*).
- Branch base (tip of `seriesb/028-upstream-772-tests` when work started): `d4fe31640`
  (`d4fe3164002449d1eba2fa7a8ccaa6602dec9ee6`); `seriesb/027-modern-cpp` was then `0c480b408`.
- `origin/seriesb/028-upstream-772-tests` and `origin/seriesb/029-cpp-component-tests` at that
  time: both `d4fe31640`, the same as the local branches.

### Baselines

At the base commit `d4fe31640`, on Jon's Windows machine (MSYS2 UCRT64, Clang 23, dev flavour),
2026-11-14, unless stated.

| What | Result |
|---|---|
| Smoke run frame time (`./mk.sh test dev`) | passed; the smoke run prints no frame time (see *Decisions*): it served the console after 1.2 s and drew 2.1 s of game time, `GUI_SCREEN_INTRO1`, snapshot passed |
| `tests/run.sh unit` | passed: oofnd 42, core 189, headers 1, 0 failures |
| `tests/run.sh component` (windowed) | 14 passed, 1 failed: `test_t1_tutorial_walkthrough` (the game drops the console connection while `n` is held, `ConnectionResetError`). Spec 009 recorded the same test failing every run on this machine at earlier bases (`specs/009-modern-cpp-std/tasks.md`, T108), so it is not this feature's. The second run (858 s) was at T008's tree because the first (889 s) overlapped a rebuild; both gave the same result |
| `tests/run.sh smoke` | passed (as the first row) |
| `tests/run.sh gui` | not run: Jon skipped the GUI tier on this machine on 2026-11-13 (spec 009 T108), and it takes over the desktop; there is no GUI job in CI either |
| One windowed S1 run, real time (and where measured) | 6.70 s (`pytest --durations`, the test's call phase, this machine); S2-S8 take 118-119 s each |
| Compiler per CI job (Windows, Fedora, macOS, Flatpak) | `unit-tests-windows`: MSYS2 UCRT64 Clang (`install_deps.sh clang`, `clang.ini`); `build-fedora`: Clang 23.1.5 (`clang.ini`); `build-macos`: Apple Clang (`darwin.ini`); `build-flatpak`: `mk.sh flatpak-internal` with `clang.ini`. No job builds with GCC (FR-011, T065) |

### Probes

| Platform | SDL version | `dummy` driver | pushed key returns | `N` with Caps Lock |
|---|---|---|---|---|
| Windows x64 (local, 2026-11-14) | 3.4.18 | yes | came back, same scancode and mods | `0x4e` (`N`) |
| macOS arm64 (CI, `build-macos`) | 3.4.18 | yes | came back | `0x4e` (`N`) |
| Windows x64 (CI, `unit-tests-windows`) | 3.4.20 | yes | came back | `0x4e` (`N`) |
| Fedora (CI, `build-fedora`) | 3.4.20 | yes | came back | `0x4e` (`N`) |
| Flatpak sandbox (CI) | | | | |

### Measurements

| What | Target | macOS | Windows CI | Fedora CI |
|---|---|---|---|---|
| M1 start-up, s | — | 0.61-0.66 (Windows, local) | 1.03 | 0.47; macOS 0.57 (at `22afdd2a0`: 0.88; macOS 1.07) |
| M1 steps per second, and × real time | 20× | 257,000-304,000 steps/s, 4,300-5,100× (Windows, local; empty system, hidden GL window) | 74,962 steps/s, 1,249× (no window, trap not linked) | 183,890 steps/s, 3,065×; macOS 235,641, 3,927× (no window, trap linked); at `22afdd2a0`: 90,489, 1,508×; macOS 156,359, 2,606× |
| S1 game ÷ real while stepping (SC-001) | ≥ 20 | stepping ~4,000× (test_boot); S1 engages after 0.2 s of game time, so its own ratio line is dominated by start-up | stepping 1,249× (test_boot) | stepping 1,508×; macOS 2,606× (test_boot) |
| S1 whole test, s (SC-001) | < 15 | 0.41 | 1.17 (meson, at `22afdd2a0`) | 0.61 (meson), macOS 0.62; at `22afdd2a0`: 0.95, macOS 1.09 |
| `repeat_100.sh` S1 (SC-002) | identical | 100 runs, identical (56 s) | `test_repeat` (two runs, same digest) passed, 2.38 s | `test_repeat` passed, 1.83 s; macOS 1.83 s |
| Basic tests, s each (SC-012) | < 15 | laser 0.49, attack 0.49, mining 0.50 | laser 1.18, attack 1.15, mining 1.13 | laser 0.54, attack 0.43, mining 0.47; macOS 0.60, 0.62, 0.46 |
| Definitions in the data: ships, equipment | — | 194, 41 (as at the research commit) | | |
| Census: passed / left / n-a / failed / expected (SC-003) | 100% accounted | 127 / 2 / 100 / 6 / 8: 235 of 235 | the same | the same; macOS the same |
| Census real time, s (SC-004) | < 300 | 2.2 | 3.90 | 2.83; macOS 3.37 |
| Menu, tutorial, launch, remap, fire tests (SC-005, SC-013) | pass | passed (Windows, local; `_ru` tutorial an expected failure, H2) | passed, at `6750c2f5c` | passed on Fedora and macOS at `dcb598ada`; macOS's `us_tsv` case failed there on shift+caps (fixed in the test's scope, see *Decisions*) |
| S1–S8 total, s, against one windowed run (SC-009) | less | 4.31 (one `meson test`, serial: 0.46-0.63 each) against 6.70 for windowed S1 alone (S2-S8 windowed: 118-119 s each); 12.3 through eight `tests/run.sh` calls | | |
| Whole tier, parallel and serial, s (SC-010) | < 600 | 4 parallel (24 cores), 18 serial (`build/meson_test`, 29 tests; same results both ways: 24 OK, 5 expected fail) | | |
| Smoke frame time against baseline (SC-011) | within 2% | not measurable: the smoke run prints no frame time (as at the baseline); it passed | | |

### Clock exceptions (FR-005)

Searched 2026-11-14 (T014): `Resources/Scripts`, `Resources/Config` (core data only) and `src/`.
The core scripts use **no** `Date.now`, `new Date` or `performance.now` (their `clock.seconds` is
game time); `oolite-quickjs-compat.js` only defines `Date.prototype.toSource`. What still reads the
system, and why it stays:

| Where | What it affects | Why it stays |
|---|---|---|
| `src/Core/Scripting/OOJavaScriptEngine.cpp` `MonotonicTime()` (the time limiter) | when a script that runs too long is stopped | it limits real CPU time, which is its job; headless the limit is 10 s (`scriptTimeLimit`) |
| QuickJS `Date.now`, `new Date`, `performance.now` | anything a script computes from them | no core script uses them; an expansion's use is outside this tier (add-ons off) |
| `src/SDL/MyOpenGLView.cpp:501-504`, `MyOpenGLView+Input.cpp:199` | mouse double-click and mouse-wheel timing | mouse input; no headless test uses the mouse |
| `src/Core/Entities/PlayerEntityControls.cpp:4490` (`last_time`) | the custom view's zoom speed | the view only, not game state |
| `GameController.cpp` splash and start-up log times, `OOLogOutputHandler.cpp` flush deadline, `OOEncodingConverter.cpp` profiling | log text and flushing | not game state (contract: log timestamps and profiling keep reading the system) |
| `src/Core/OOOXZManager.cpp:593` | a download's file name | the expansion manager, which a headless game does not create |
| `GameController.cpp` frame-loop deadlines (`TickClock`) | when the windowed loop ticks and sleeps | the windowed loop itself; a headless game never runs it |
| `GameController`'s constructor seeding RANROT from the clock | the first RANROT state | re-seeded from the seed by `startHeadless` and again by `initWithGameView` |

### Findings

**Start-up** (T010): `main`'s controller is **not** the one `sharedController()` returns.
`src/SDL/main.cpp` makes its own with `oo::makeShared<GameController>()`; the constructor raises
only if a shared one already exists and never registers itself
(`src/Core/GameController.cpp:210-229`), so the first `sharedController()` call (from
`Universe::initWithGameView`'s progress messages on) makes a second controller, whose constructor
seeds RANROT a second time and reads `animation_timer_interval` again. Upstream has the same shape
(`upstream/oolite/src/Core/GameController.m:70-85`, `src/SDL/main.m:185`), so it is not a port
fault. Recorded, not fixed (T010). `startHeadless` is called on `sharedController()`, the one the
game's code reaches, and seeds after it exists. 

**GL sites** (T018–T021, T038): the nine known sites are in research R2. Further sites, one row
each: file, function, GL call the trap named, task, commit.
- T038a (`60fe34c06`), found by the menu walk: the headless view had no display modes, so the
  game options screen built nothing (`setGuiToGameOptionsScreen` returns when the controller has
  no modes); and its *Play in Full Screen* row made the view create a window, which the dummy
  driver cannot, and the game exited. `startHeadless` now calls `setUpDisplayModes()`, and
  `MyOpenGLView::initialiseGLWithSize` makes no window when `!OOGraphicsAvailable()`.
- T038b (`d6f090f95`), found by `key_fault_h5`: the snapshot key reached
  `MyOpenGLView::snapShot`, which reads the GL framebuffer; crashed (0xC0000005) with no GL.
  Guarded.
- Not a GL site, recorded for FR-025: headless, the game options screen's detail-level row is
  empty, and the log has `Unknown expansion key [detailLevel]` (twice per build of the screen):
  the detail level comes from the GL setup that does not run.
- `Universe::deleteOpenGLObjects` (T018, `bfe20378f`): reached when `newUniverse` tears down a
  universe whose start-up raised; guarded beside the listed sites.
- The JS engine was made as a side effect of the extension manager's per-GPU regular expression
  while the windowed view sets up GL; headless, `startHeadless` makes it at that point (T018). Not
  a GL site, but the headless reset skipped it and equipment loading then asserted.
- `SkyEntity::changeProperty` and the JS system setter (`OOJSSystem.cpp:577`) call GL only through
  `Universe::setLighting`, so T018's guard covers them (T019).
- After T020, `test_boot_nogl` linked with the trap (140 GL functions) **passed on Fedora**:
  no further site on the boot path. On Windows the extension pointers' `OOBadOpenGLExtensionUsed`
  stub, under gdb, named the same first site (`initTargetFramebufferWithViewSize`).
- The trap proven (T021): `test_gl_trap` runs itself as a child that makes one unguarded call
  headless (`OOTexture::applyNone`); on Fedora and macOS the child exits 134 with
  `GL call glBindTexture while headless` and a backtrace. A standing test replaces the one-off
  "remove a guard" check (see *Decisions*).

**Repeatability** (T025): two runs of S1 gave the same digest at all 134 steps, and
`repeat_100.sh test_s1_police_kills_pirate` gave `100 runs, identical` on Windows. No cause of
difference found, so no `T025a`. 

**Census** (T037): key, seed, evidence, and how it was cleared (fix task, or expectations row).
First full run, 2026-11-14, Windows, base seed 20260910, 2.2 s: 194 ships and 41 items; 127
passed, 2 left, 100 not-applicable (81 templates, 11 parts, 4 services by behaviour, 4 items not
available to the player), 6 failed; all 8 listed in `census-expectations.tsv`:
- `EQ_FUEL` (seed 3038534992): "award refused": `awardEquipment` never awards it
  (`OOJSShip.cpp` ShipAwardEquipment).
- `EQ_MILITARY_JAMMER`, `EQ_MILITARY_SCANNER_FILTER`, `EQ_OOLITE_TUTORIAL_CONTROLS`,
  `EQ_RENOVATION`: "award refused" by their condition script `oolite-conditions.js`.
- `missile`, `ecm-proof-missile`: leave within the 10 s span with no target (`left`).
- `asp-cloaked`: "6 entities after removal, 5 before": one entity it made stays. Not
  investigated: listed, and under *For Jon*.
Census-harness faults found and fixed on the way (in T034, not game faults): the player drifted
into the planet over ~2,000 s of game time (now stopped before each try); hostile definitions
10 km away attacked it (now spawned 40 km out, away from the planet); `Universe::removeEntity`
left other ships pointing at removed ones, crashing later tries (now removed as `ship.remove()`
does). The crash-and-resume path was exercised by those crashes (children exiting 0xC0000005 and
on `std::bad_weak_ptr` were recorded failed and the next child resumed, report complete): the
SIGKILL check of T034's Accept is met by them, not by a kill by hand.

**S2-S8** (T055-T061): each counterpart agrees with its original (FR-032): every survivor
check holds and no log line contains `ERROR`. The windowed step "no ERROR appears in the log"
fails on any log line containing `ERROR`, wider than `OO_COMPONENT_CHECK_NO_ERRORS`'s classes, so
each port checks both: `Game::logLinesContaining("ERROR")` is the windowed step's meaning. S6 stops
after 21 s of game time, the rest at 112.5 s: `simulateAtMost` stops once every non-police role
spawned is gone, as `world_steps.py` `run_simulation` does (S6's pirate is destroyed).

**Keys** (T044, T052, T053):
- T044, Windows: `test_tutorial_keys --layout tests/component-cpp/fixtures/us-n-remapped.tsv`
  exits 1 with
  `FAIL ../../tests/component-cpp/test_tutorial_keys.cpp:38 [the_next_key_advances_every_step_of_lessons_0_and_1]: pressing n had no effect at GUI_SCREEN_MAIN, game time 2.667`
  and `layout us-n-remapped: n -> scancode 17 (N), no modifiers -> key 0x6d`; `--layout us`
  passes.
- T052, Windows (the dummy driver's built-in map): **H1 fails** (Caps Lock on, the n key does not
  move the tutorial); **H3 fails for AltGr's mode bit** (`SDL_KMOD_MODE`), passes for Num Lock;
  **H4 fails** (Caps Lock alone is seen as `9`, Num Lock as `S`); **H5 passes** without a
  sanitizer (T050 is its judge); **H2** waits for `ru.tsv` (T041).
- T053: upstream's `src/SDL/MyOpenGLView+Input.m` (upstream `4bb1f53de`) has the same code at each
  point: `:379` `key_id = SDL_GetKeyFromScancode(kbd_event->scancode, kbd_event->mod, NO)` into a
  16-bit `key_id` (H4), and `:598-609` the Caps Lock reset left commented (H1); the exact
  modifier match is upstream's `checkKeyPress` (H3). So the port did not introduce them. A fix
  changes the windowed game's key handling, which this feature's contract keeps unchanged, so
  `key_fault_h1`, `h3`, `h4` are registered `should_fail: true` (checked both ways) and listed
  under *For Jon*.

**Sanitizers** (T050): MSYS2's Clang on this machine has no sanitizer runtime
(`meson setup -Db_sanitize=address,undefined`: "Linker clang does not support sanitizer
arguments"), so the suite runs under ASan and UBSan in `build-fedora` (step "C++ component tests
under sanitizers"; `-t 4`; no suppression). Reports, at `b0baff428` (run 43632980653):
- UBSan, every program: `legacy_random.cpp:109:32: signed integer overflow: 156 * 16777216
  cannot be represented in type 'int'` (in `RanrotSeedFromRNGSeed`). Fixed by T050a
  (`28e852a9d`, unsigned arithmetic, same bits); gone at `b0baff428`.
- UBSan, `key_fault_h5`: `MyOpenGLView+Input.cpp:662:18: index 327 out of bounds for type
  'int[327]'` (`scancode2Unicode`, research H5; upstream has the same lines). Fixed by T053a
  (`45f02a36f`, bounds checks; nothing defined changes).
- LeakSanitizer, every program that makes a game: about 1.22 MB in about 12,480 allocations
  unfreed at exit (`SUMMARY: AddressSanitizer: 1220852 byte(s) leaked in 12484 allocation(s)`),
  and 8 bytes allocated through `libSDL3.so.0`. The stacks are unsymbolized in that run (no
  `llvm-symbolizer`); the step now installs `llvm`. The game keeps many objects for the
  process's life by design (the "exit(0) runs no destructor" holders), so this is not fixed here:
  the step reports and continues (`continue-on-error`), and it is listed under *For Jon*.
  Because LSan's exit code fails each program, the census's parent saw its `--list` child fail
  (`component_census: --list failed`); not a separate report.

**Flatpak** (T051): with `OO_FLATPAK_RUN_COMPONENT=1` (CI's `build-flatpak`) the manifest's
`oolite` module builds the test flavour with LTO off inside the build sandbox and runs
`meson test --suite component` there. First attempt (run 43630366242): the sandbox could not run
`get_version.sh` (`meson.build:5:13 ... get_version.sh ... failed with status 1`); the test
build now takes the module's `--ver-full` / `--buildtime`. Run 43632980653 (`b0baff428`), in the
sandbox: **22 OK, 5 expected fail, 3 fail**. The three are `test_menus_us`, `_fr_azerty`, `_ru`,
all on `us_tsv_agrees_with_sdls_built_in_map`: the sandbox's SDL is the manifest's 3.4.8, whose
built-in map has no key code for scancode 165 (`us.tsv 0x400000a5, SDL 0x0`); SDL 3.4.18 (here,
macOS) and 3.4.20 (Fedora, Windows CI) have one. Every key test (tutorial, launch, remapped, fire,
key faults) gave the same result in the sandbox as on Fedora. The sandbox's result is now
reported without stopping the package build.

### Finding: the Flatpak `n` report

**Not reproduced; ruled out for the game's own key handling, with the limits below.**

*What the tests covered.* The game's whole handling of a key, from the SDL event the platform
layer hands it to the control acting: key events pushed onto SDL's queue and read by the game's
own `pollControls()`, through `MyOpenGLView`'s translation and `PlayerEntity`'s key settings, to
the tutorial moving on. `test_tutorial_keys` presses the game's own activate-equipment key (`n`,
looked up from the key settings) through every step of lessons 0 and 1: it passes under `us` and
`fr_azerty` on Windows, macOS, Fedora and **inside the Flatpak build sandbox** (SDL 3.4.8, run
43632980653). It fails, as it must, when the layout gives another letter for that key
(`fixtures/us-n-remapped.tsv`: "pressing n had no effect at GUI_SCREEN_MAIN"). The key-path faults
found (`test_key_faults`): **H1** with Caps Lock on, `n` does not activate; **H2** on a non-Latin
layout whose `n` key gives a code point above 326 (the derived `ru` table), it is dropped; **H3**
an AltGr mode bit stops the exact modifier match (Num Lock does not); **H4** Caps Lock alone reads
as `9`, Num Lock as `S`; **H5** a scancode above 326 indexed `scancode2Unicode` out of bounds
(fixed, T053a). H1-H4 are upstream's code too and are kept, `should_fail`, for Jon. Any of H1-H3
would make `n` do nothing for a player in that state, on any platform, Flatpak included: Caps
Lock on (H1) is the likeliest explanation of a report that "n does nothing".

*What they cannot cover.* SDL's own step from a real keyboard to a key code on each platform
(Win32, Cocoa, X11 and Wayland layout handling, including SDL's default keycode options, which
may give Latin letters on a Russian layout and so remove H2 in practice); the `fr` and `ru`
tables are derived, not recorded (T041). Window focus, including the XWayland note at
`src/SDL/MyOpenGLView.cpp:547-552` (H7). Input methods. The Flatpak sandbox's access to input
devices (the tests run in its build sandbox, which has none). Whether the report was against
upstream's Objective-C build, which has the same key code as this port at each fault above.

*Manual procedure for those.* On the Flatpak build (`flatpak run space.oolite.Oolite`), on X11
and on Wayland: start the tutorial (Start New Commander, Tutorial, Enter, Enter, launch) and at
lesson 0 step 2 press `n`: it should move on. Repeat with Caps Lock on (H1), with a French and a
Russian layout active, and with the window refocused by clicking after switching away (H7).
Then the game-side conditions (H6): press `n` while the mission screen is still up (nothing is
expected), during the launch (nothing is expected), and after Shift+N has primed another
equipment item (the primed item, not the tutorial's, activates). Note for each: platform,
session type, layout, Caps Lock, what happened.

### Quickstart

| Step | Result |
|---|---|
| 1 | passed: `tests/run.sh component --cpp` exit 0 (24 OK, 5 expected fail) |
| 2 | passed, 0.50 s; no window. Its ratio line reads `game 0.2 s, real 0.40 s, 1x`: S1 engages within 0.2 s of game time, so the line is start-up (stepping runs ~4,000x, test_boot). `env -u DISPLAY` run: Fedora and macOS CI |
| 2a | passed: laser_fires, ship_attacks, mining_laser, fire_key; each with `--without-weapon` exit 1 |
| 3 | passed: `100 runs, identical` (S1; S2 also, T065) |
| 4 | covered by the standing `test_gl_trap` on Fedora and macOS CI (a child's unguarded GL call dies with `GL call glBindTexture while headless`); the remove-a-guard edit was not made (see *Decisions*, T021) |
| 5 | passed: 194 ships, 41 equipment; with `fixtures/broken-ship` exit 1 naming `oo-component-broken-ship` |
| 6 | passed: `test_menus` under us, fr_azerty, ru; `test_tutorial_keys` under us and fr_azerty; `_ru` is an expected failure (H2); the mutated layout fails with `pressing n had no effect at GUI_SCREEN_MAIN, game time 2.667` |
| 7 | not runnable here (no sanitizer runtime in MSYS2's Clang); run in `build-fedora`: see *Findings -> Sanitizers* |
| 8 | ran to a result: h5 passes; h1-h4 fail and are named in *Findings -> Keys* (expected failures) |
| 9 | unit, smoke: same as the baseline; windowed component: 14 passed, `test_t1_tutorial_walkthrough` failed as at the base; gui: not run (as at the base, Jon's 2026-11-13 decision) |

### CI runs

| Task | Run URL | Jobs green |
|---|---|---|
| T006 (at T011, `0b7534e7d`) | https://github.com/jonmseaman/oolite/actions/runs/43618713800 | `unit-tests-windows`, `build-fedora`, `build-macos`: green, `test_skeleton` in each log |
| T021, T024–T030 (at `01b466dea`) | https://github.com/jonmseaman/oolite/actions/runs/43622970759 | `build-fedora`, `build-macos`: green, 8 programs each, `GL trap: linked`; `unit-tests-windows`: red on `test_OOJSShip` (T022a) |
| T021, T026, T031, T037 (at `22afdd2a0`) | https://github.com/jonmseaman/oolite/actions/runs/43624664527 | `unit-tests-windows` (8 programs, census included), `build-fedora`, `build-macos` (9 each, `GL trap: linked`): green. Outside this feature: `build-appimage` red on a pacman download error (`could not open file /var/cache/pacman/pkg/download-…`), `build-github-pages` red as on `develop` |

### Commits

| Task | `oolite-dev` commit |
|---|---|
| T003 | `f30caa454` |
| T004 | `16a9bc890` |
| T005 | `39177a84e`, `dda7c68e4` (probes printed in every log) |
| T006 | `ff63d0536` |
| T007 | `0e879c9df` |
| T008 | `6afa4a587` |
| T009 | `005edee67` |
| T010 | `4940ab9a7` |
| T011 | `0b7534e7d` |
| T012 | `4c3544d5e` |
| T013 | `055615fa1` |
| T014 | planning repo only (*Clock exceptions*) |
| T015 | `c149886c7` |
| T016 | `e9ee4b655` |
| T017 | `42bd77824` |
| T018 | `bfe20378f` |
| T019 | `00ac082a4` |
| T020 | `12f0d6123` |
| T021 | `4d332bb18` |
| T022 | `c7a74b47a`, `22afdd2a0` (T022a) |
| T023 | `a8ce6a21c` |
| T024 | `374741edb` |
| T025 | `8475a163c` |
| T027 | `b986c180b` |
| T028 | `e5b0f9d61` |
| T029 | `fbda7a212` |
| T030 | `01b466dea` |
| T032, T033 | `3cbc764ad` (one file; one commit) |
| T034 | `2573fd93e` |
| T035 | `013a43702` |
| T036 | `06c6a3b4a` |
| T037 | `cebd698f1` |
| T055 | `46eba00c1` (with `Game::logLinesContaining`) |
| T056 | `f20a9f68c` |
| T057 | `8f75067e3` |
| T058 | `a643da044` |
| T059 | `b04018dbe` |
| T060 | `c494dd55e` |
| T061 | `f6df6746c` |
| T038 | `8386f36d9` |
| T039 | `5f6ea3d71` |
| T040 | `c36470430` (with `record_layout.cpp`) |
| T041 | `737aa6bd4` (the CI step; the tables follow) |
| T038a | `60fe34c06` |
| T042-T048 | `dcb598ada` (one commit), `e6ebbe8d2` (T044) |
| T038b | `d6f090f95` |
| T052 | `16c1456b9` |
| T053 | `b5f3a001a`, `6750c2f5c`; T053a `45f02a36f` |
| T041 (tables) | `d85a6eae3` |
| T050 | `7af900620`, `114d71511`; T050a `28e852a9d` |
| T051 | `945b37abb`, `b0baff428`, `114d71511` |
| T063 | planning repo `08ad1f136` |
| T065 | `b627daf99` (GCC step, removed in `114d71511`) |

### Branch state

`origin/seriesb/029-cpp-component-tests` is pushed by fast-forward only and matched the local
branch at each push; *Commits* has the tip.

### Decisions taken on defaults

Decisions already in plan.md (*Notes*) and research.md are not repeated. Added by these tasks:

- **The game branch is Jon's `seriesb/029-cpp-component-tests`, in the main checkout** (T001,
  2026-11-14). Jon cut it on `seriesb/028-upstream-772-tests` and checked it out, clean, in the
  main `oolite-dev` checkout; a second worktree cannot check out the same branch, and a separate
  `seriesb/029-component-tests` would fork the stack he set up. Every rule for "the worktree"
  applies to `oolite-dev` itself on that branch.
- **Work is on Windows, not the Mac** (2026-11-14): this session ran on Jon's Windows machine.
  "This Mac" in the tasks reads as "this machine"; the build is the **dev** flavour
  (`build/meson_dev`, no LTO, what `tests/run.sh` and `unit-tests-windows` use) instead of
  `./mk.sh build test --setup-flags=-Db_lto=false`. macOS is proved by CI. The GL trap is Linux
  and macOS only (R2), so on this machine GL sites are found from CI's Fedora and macOS logs.
- **clang-format 22 comes from PyPI** (`clang-format` 22.1.8 in `.agent-tmp/cf22`): this machine
  has only LLVM 23, and CI's format check uses 22.
- **The smoke run prints no frame time** (T002): `tests/launch_snapshot.py` reports only that game
  time advanced. SC-011's baseline is therefore the smoke run's result and its real time; the
  frame split (T008) is checked by the smoke run passing and by `tick` being the moved body
  unchanged. A frame-rate figure would need a new probe in the smoke script, which is not this
  feature's to change.
- **The scenario game is the windowed tier's set-up** (T010, T011): `startInFlight` loads
  `Resources/Scenarios/oolite-standard.oolite-save` (world_steps.py `SCENARIO_SAVE`), launches the
  player and ticks until in flight; `Game::scenario` then lets it settle 2 s and runs the windowed
  steps' own clear expression until only the player is left. So the game clock is not at 0 when a
  test starts, and the save sets the ship clock.
- **`the_ship_clock_starts_from_the_seed`** (T012) checks what the scenario game can show: the game
  clock's time of day comes from the seed, and the ship clock follows game time. The start itself
  is overwritten by the save in this game; a new commander's start is checked in the docked game
  (T045).
- **The manual clock counts whole nanoseconds** (T012), so 120 steps of 1/60 s are 2 s exactly
  (a double sum gives 1.9999999999999978 s) and a deadline falls due on the step it should.
- **The frame-callback id seed and the headless scripting are setters**
  (`OOJSFrameCallbacksSetIDSeed`, `OOJSSetHeadlessScripting`) that `startHeadless` calls, not reads
  of `GameController`: core unit tests link those files without the controller.
- **The case `600_steps_...` is named `six_hundred_steps_advance_game_time_by_10_s`** (T011): a
  C++ identifier cannot start with a digit.
- **The key tests are registered once per committed layout** (T042): meson registers
  `<test>_<layout>` only for a `layouts/<name>.tsv` that exists, so until T041's tables are
  committed only the `us` variants run.
- **T042-T048 are one commit** (`dcb598ada`): their additions to `oo_component` and `meson.build`
  are in the same two files; T038a, the game fix the walk found, is its own commit.
- **A character no key of the layout gives is pressed at its US position** (T043): a Russian
  player presses the key the letter is printed on; the layout says what that key gives (the
  example A5 message `n -> scancode 17 (N) ... key 0x442`).
- **`Game::docked` releases Return after the load** (T046): a load holds every key until one is
  released (`suppressKeysUntilKeyUp`), as a player's load ends with the release of the key that
  chose it; without it the first press after the load was swallowed.
- **`aheadOf` uses a ship's own forward vector** (T047): the player's orientation is held the
  other way round, so the quaternion's forward put the target behind the player.
- **The menu walk backs out of each screen as its handler reads keys** (T042): the scenario
  screen and the expansion manager by their `exit` / `_EXIT` rows, the ship library and the
  keyboard screen by space, the game options by their last row (Back), anything else by Escape.
  The expansion manager is opened and left; no other row of it is activated (hard rule 4).
- **The fr and ru tables are derived, not recorded** (T041): the Xvfb + `setxkbmap` recording in
  `build-fedora` (run 43628739112) gave the US table for both layouts (`fr` gave `a` in the US A
  position), so, as T041's fallback says, both are `us.tsv` with the keys fr(basic) and ru(basic)
  move, each header says so, and the CI step is dropped.
- **`us.tsv`'s agreement check leaves out shift+caps** (T041): SDL's own built-in map answers it
  differently by platform (`A` on macOS, `a` on Windows and Linux; macOS CI at `dcb598ada`), so
  no one table agrees everywhere. The case checks no modifiers, shift and caps, as T039's case does.
- **The sanitizer run is Fedora's, and reports without failing the job** (T050): no sanitizer
  runtime here; LeakSanitizer's whole-game report would otherwise fail every program on every run.
- **The Flatpak sandbox reports its component result without stopping the package** (T051): its
  SDL (3.4.8) answers one scancode differently, which fails `test_menus` there (*Findings ->
  Flatpak*).
- **Key faults H1-H4 are kept, `should_fail`** (T053): upstream's code, and fixing them changes
  the windowed game's keys; H5's out-of-bounds index is fixed (T053a), as nothing defined changes.
- **No GCC job** (T065, FR-011): `build-ubuntu` with `gcc.ini` (GCC 15.2) failed compiling the game
  itself (`OOStringExpander.h:368:29: could not convert '{<expression error>}' ...`), outside this
  feature, so the step was removed and the build is listed under *For Jon*.
- **One unit-tier failure not captured** (T050a): one of five unit runs after the T050a rebuild
  reported `Fail: 1`; its log was overwritten before it was read; the four reruns were clean.
- **Headless, a request to quit is recorded, not obeyed** (T040): `exitAppWithContext` returns
  after logging when the game is headless, and `GameController::exitRequested()` holds the
  context, so the menu test can check *Exit Game* without the process ending under it.
- **`record_layout.cpp` came with T040**, not T041: `us.tsv` is its output under
  `--video-driver dummy` (SDL's built-in map), and T040 needed the table.
- **A press is two steps down and two up** (T040): the game samples keys once a frame, and a key
  not seen up makes the next press a repeat. A pushed event's `key` field is what a real one
  would carry: the recorded layout's key code, or `SDL_GetKeyFromScancode(…, true)` with none.
- **The new-game screen is left by its `exit` row** (T040): Escape does nothing there in the
  windowed game either (`PlayerEntityControls.cpp`, `kNewGame`).
- **CI is pushed only once a run has finished** (2026-11-14): the workflow's concurrency group
  cancels a running run on each push, and pushing per task left no run complete on every job.
- **The GL trap's proof is a standing test** (T021): `test_gl_trap` makes one unguarded GL call in
  a child and requires it to die naming the function, on every Linux and macOS run, instead of the
  one-off "remove the sun's guard, paste the line" (which needs a Linux build here).
- **Sounds are names without data headless** (T022): with no device no `OOSound` loads, so a play
  request never reached a source; `OOSound::setNamedWithoutDevice(true)` (set by `startHeadless`)
  makes a silent named sound, and `OOSoundSource`'s play observer records each request.
- **Every failed case prints the game's state** (T028): `oo_test`'s `OO_CHECK` knows nothing of the
  game and `oo_test.hpp` is not edited, so `oo_component` runs the registered cases itself, in
  `runAll`'s format, and after a failed case prints the seed, game time, screen, last ten events
  and the rerun command.
- **`--without-weapon` mounts `EQ_WEAPON_NONE`** (T028–T030): an adder carries a pulse laser by
  definition, so skipping the mount changed nothing; the basic tests' ships fly `nullAI.plist` so
  their own AI script does not replace the ordered behaviour.
- **The census reseeds RANROT only** (T033): the really-random generator is seeded once per
  process by design (`legacy_random.h`, an assertion).
- **Census services are found by behaviour** (T032): awarded (needs from the item's own data met
  first) and then not fitted. That gives `EQ_MISSILE_REMOVAL`, `EQ_PASSENGER_BERTH`,
  `EQ_PASSENGER_BERTH_REMOVAL` and `EQ_TRUMBLE`, not research's four names: `EQ_FUEL` and
  `EQ_RENOVATION` are refused a scripted award, and a passenger berth is a capacity, not an item.
  Items not available to the player are not-applicable, by `isAvailableToPlayer()`.
- **`T032` and `T033` are one commit**: both are the one new file.
- **`tests/run.sh component --cpp -k boot` is T022's Accept before T021** only after T021 moved
  `test_boot` into suite `component`; T022's cases were run under the temporary suites first.
- **`tests/run.sh component -k <name>` with no flag** (T004): a name that matches no C++ program
  is reported and the C++ half passes, so today's `tests/run.sh component -k s1` still runs the
  windowed S1 before its C++ counterpart exists. With `--cpp` no match is an error, as T004 asks.

- **Fedora's CI test build turns LTO off** (T006), as `unit-tests-windows` already does, because
  the GL trap is generated from real objects. LTO on Linux stays covered by the AppImage and
  Ubuntu jobs.
- **The suite is not built by the deployment flavour** (T003), as the unit suites are not. The
  Flatpak leg therefore builds a second, test-flavour tree when asked to run the suite (T051).
- **With LTO on, the GL trap is left out and the programs say so** (T016, T021). Stopping the
  configure step instead would break the default `./mk.sh build test` on macOS and Linux. CI's
  Fedora and macOS steps require the trap.
- **Two temporary meson suites, `component-window` and `component-nogl`, exist from T011 to
  T021** so that work in progress never makes `tests/run.sh component --cpp` red in CI.
- **`simulateAtMost(span)` was added to the test interface** (T023) for the windowed step "the
  simulation runs for at most N ticks", which seven of the eight scenarios use.
- **`fr_azerty` and `ru` are recorded in a throwaway X server in CI**, not on this Mac, so nobody's
  keyboard settings are changed, and CI re-records them to catch drift (T041).
- **A key-fault case that fails and is not fixed here stays in the suite as `should_fail`**
  (T053), so it is noticed when it starts passing.
- **The weapon-removed runs are Accept commands, not standing tests** (T028–T030, T048): a
  `should_fail` test would also pass on a crash.

### For Jon

- Merging `seriesb/029-cpp-component-tests`, and any force-push it needs after `seriesb/027-modern-cpp`
  is rewritten.
- The game's LeakSanitizer report (about 1.22 MB in 12,480 allocations at exit in every program;
  *Findings -> Sanitizers*): the sanitizer step continues while it stands.
- The game does not compile with GCC 15.2 on Ubuntu 26.04 (`OOStringExpander.h:368`), so no CI job
  builds the suite with GCC (FR-011).
- A real recording of the `fr_azerty` and `ru` tables (they are derived), and whether SDL's
  default keycode options make H2 moot for Russian players.
- SDL in the Flatpak manifest is 3.4.8; its built-in map lacks scancode 165, which fails
  `test_menus`' `us.tsv` check in the sandbox.
- The key faults H1, H2, H3 (AltGr's mode bit) and H4 (Findings -> Keys): upstream's behaviour, kept;
  `key_fault_h1`, `h3`, `h4` are `should_fail` until a fix is wanted.
- Adjudicating `tests/component-cpp/census-expectations.tsv` (eight rows), and in particular
  `asp-cloaked`, which leaves one entity behind after it is removed (not investigated).
- `test_t1_tutorial_walkthrough` (windowed) fails on this machine at the base, as spec 009 found.
