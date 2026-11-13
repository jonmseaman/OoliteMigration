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

- [ ] T001 Create the branch and worktree. From the planning repo root:
  `git -C oolite-dev fetch origin`, then
  `git -C oolite-dev worktree add -b seriesb/029-component-tests
  "$PWD/.agent-tmp/wt-component-tests" refs/heads/seriesb/027-modern-cpp`. The base is the
  **local** branch's committed tip (on 2026-11-13 that was `123146c11`, 36 commits ahead of the
  remote-tracking ref); uncommitted work in the main checkout is not included and is not touched.
  Write the base commit, and the remote ref's commit, into *Records → Base*.
  **Accept:** `git -C .agent-tmp/wt-component-tests rev-parse --abbrev-ref HEAD` prints
  `seriesb/029-component-tests`, and
  `! grep -q '_not recorded_' <(sed -n '/^### Base/,/^### /p' specs/011-headless-component-tests/tasks.md)`.
- [ ] T002 Build the base and record the baselines in *Records → Baselines*. In the worktree:
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

- [ ] T003 Create `tests/component-cpp/meson.build` and `tests/component-cpp/test_skeleton.cpp`,
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
- [ ] T004 Teach `tests/run.sh` the two halves ([contracts/runner.md](contracts/runner.md),
  *`tests/run.sh`*): `component` runs the C++ half then the windowed half and exits nonzero if
  either failed, with the windowed half still run after a C++ failure; `--cpp` runs only
  `meson test -C build/meson_$BUILD_TYPE --suite component --print-errorlogs` and needs no
  virtualenv; `--windowed` runs only pytest as today; `-k <name>` filters the C++ half by substring
  of the meson test name and **exits nonzero when nothing matches**; `all` keeps its order. Update
  the help comment at the top.
  **Accept:** `tests/run.sh component --cpp && tests/run.sh component --cpp -k skeleton &&
  ! tests/run.sh component --cpp -k no_such_test && tests/run.sh | grep -q -- '--cpp'`.
- [ ] T005 [P] Add three probe cases to `tests/component-cpp/test_skeleton.cpp` (plan M0; research
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
- [ ] T006 Add the C++ component step to CI in `.github/workflows/build-all.yaml`
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

- [ ] T007 [US1] Add `src/Core/OOHeadless.h` and `src/Core/OOHeadless.cpp` (examples C1;
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
- [ ] T008 [US1] Split the frame in `src/Core/GameController.h` / `.cpp` (examples C2):
  `GameController::tick(OOTimeDelta dt)` is the simulation half of `doPerformGameTick` (clock
  advance, universe update, restart check, sound update, frame callbacks, in that order), and
  `doPerformGameTick` measures dt, caps it as today, calls `tick`, then draws. The controller owns
  an `OOGameClock`, the real one by default. No windowed behaviour changes. Add the case
  `the_controller_has_tick` to `tests/component-cpp/test_skeleton.cpp` (it takes
  `&GameController::tick`, so it does not compile before this task).
  **Accept:** `tests/run.sh component --cpp -k skeleton && ./mk.sh test test`, with the smoke
  run's frame time within 2% of the baseline (SC-011).
- [ ] T009 [US1] Take the options into the universe: `Universe::newUniverse` and
  `initWithGameView` in `src/Core/Universe.h` / `.cpp` accept `const OOHeadlessOptions&`,
  defaulted. With `addOns` none, add-ons are not forced to "all" (`Universe.cpp:307, 342`) and
  `ResourceManager::setUseAddOns` gets the strict value; with `populate` false the system is left
  empty; with a seed given, RANROT and the "really random" generator (`Universe.cpp:301`) are
  seeded from it. Defaults reproduce today's calls exactly.
  **Accept:** `./mk.sh build test --setup-flags=-Db_lto=false && ./mk.sh test test`; T011's
  `test_boot` is this task's failing-then-passing test, so T009–T011 are pushed together.
- [ ] T010 [US1] Add `GameController::startHeadless(const OOHeadlessOptions&)` in
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
- [ ] T011 [US1] Create the support library `tests/component-cpp/oo_component.hpp` / `.cpp` with
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
- [ ] T012 [US1] Send the state-affecting clock reads through the controller's `OOGameClock`
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
- [ ] T013 [US1] Seed the script engine in `src/Core/Scripting/OOJavaScriptEngine.cpp` (research
  R4; contract *Script engine*): in a headless game only, replace `Math.random` through
  QuickJS-ng's public API with a function drawing from the generator of T007 seeded from
  `options.seed`, and take the time limiter's limit from `options.scriptTimeLimit` (10 s
  headless). `quickjs.c` is not edited. Add `Game::eval`, `evalBool`, `evalString` to
  `oo_component` (an expression that throws fails the test and prints the message). Case in
  `test_boot.cpp`: `math_random_draws_from_the_seed`: three `Math.random()` values equal the first
  three draws of the same generator class seeded the same way, computed in the test.
  **Accept:** `meson test -C build/meson_test --suite component-window --print-errorlogs`.
- [ ] T014 [P] [US1] List what cannot follow simulated time (FR-005). Search the core scripts
  (`Resources/Scripts`, `Resources/Config/*.plist` script fragments; core data only, no add-ons)
  and `src/` for `Date.now`, `new Date`, `performance.now` and any remaining state-affecting
  real-clock read from research's list of thirteen. Write each under *Records → Clock exceptions*
  with its file, what it affects and why it stays.
  **Accept:**
  `! grep -q '_not listed_' <(sed -n '/^### Clock exceptions/,/^### /p' specs/011-headless-component-tests/tasks.md)`.
- [ ] T015 [US1] Measure (research R12). Make `test_boot` print one line,
  `test_boot: startup <s> s, <n> steps/s, <x>x real time`, and write this Mac's numbers into
  *Records → Measurements*. If start-up is over 5 s, or stepping is under 20×, say so there with
  the number; the targets in SC-001, SC-004 and SC-010 are not changed.
  **Accept:** `meson test -C build/meson_test --suite component-window -v | grep -q 'steps/s'`,
  and the *Measurements* row for M1 is filled.

### M2 — no GL at all

A second temporary test drives this milestone: `test_boot_nogl`, the same source built without
the hidden window and, on Linux and macOS, linked with the GL trap, in suite `component-nogl`. It
fails, naming a GL function, until the last site is guarded.

- [ ] T016 [P] [US1] Write `tests/component-cpp/gl_trap_gen.py`
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
- [ ] T017 [US1] Give `OOGraphicsAvailable()` its meaning (research R2; contract
  *OOGraphicsAvailable*): `src/Core/OOOpenGLExtensionManager.h` / `.cpp` gain a headless state,
  set by `startHeadless`, that reports no GL and no shaders without calling `glGetString`, and
  `OOGraphicsAvailable()` reads it (true in the windowed game once the context exists). Register
  `test_boot_nogl` in suite `component-nogl` as described above.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` now fails with
  `GL call <name> while headless` for a function called **outside**
  `OOOpenGLExtensionManager.cpp` (before this task it names one inside it).
- [ ] T018 [US1] Guard the `Universe` sites in `src/Core/Universe.cpp` with
  `if (!OOGraphicsAvailable()) return;` or the narrowest equivalent (examples C4):
  `initTargetFramebufferWithViewSize` (`:11349`), `setLighting`, `useGUILightSource`. A site whose
  skipped GL work feeds game state is not guarded: stop and record it under *Findings → GL sites*.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` no longer names a function
  whose backtrace is in `Universe.cpp`.
- [ ] T019 [P] [US1] Guard the entity and script sites: `OOSunEntity::setSunColor`
  (`src/Core/Entities/OOSunEntity.cpp`), `SkyEntity::changeProperty`
  (`src/Core/Entities/SkyEntity.cpp`), the system setter at
  `src/Core/Scripting/OOJSSystem.cpp:577`.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` names none of these three
  files.
- [ ] T020 [P] [US1] Textures are not decoded headless (`src/Core/Materials/OOTexture*.cpp`,
  `OOTextureLoader`): `OOTexture::checkExtensions`, `OOTextureLoader::setUp`, upload and
  `dimensions()` do nothing and report zero size; no loader thread is started; materials are the
  basic kind.
  **Accept:** `meson test -C build/meson_test --suite component-nogl` names no function whose
  backtrace is in `src/Core/Materials`.
- [ ] T021 [US1] Finish M2. Run `test_boot_nogl`; for each further site the trap names, add a task
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

- [ ] T022 [US1] Wire the observer and the records (research R6; contract *OOGameObserver*;
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
- [ ] T023 [US1] Add the scenario steps to `oo_component` (examples B1–B3; contract *Entities*,
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
- [ ] T024 [US1] Port S1 as `tests/component-cpp/test_s1_police_kills_pirate.cpp` (examples A1),
  the exemplar for C++ component tests: seed 20260910; one `police`; one `pirate` within 10 km;
  within `ticks(900)` a `police` ship engages a `pirate` ship; a `police` ship survives;
  `OO_COMPONENT_CHECK_NO_ERRORS`. Each check carries the Gherkin line it ports as a comment. Its
  last output line is `game <s> s, real <s> s, <x>x`. If it disagrees with the windowed original,
  stop and report under *Findings* (FR-032); change neither.
  **Accept:** `tests/run.sh component --cpp -k s1_police_kills_pirate`.
- [ ] T025 [US1] Repeatability (research R4; data-model *Scenario digest*; contract *Repeat
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
- [ ] T026 [US1] Measure SC-001 and SC-002 and write them into *Records → Measurements*: S1's
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

- [ ] T027 [US6] Add the plain style to `oo_component` (examples A0, B1; contract *Entities*,
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
- [ ] T028 [P] [US6] `tests/component-cpp/test_laser_fires.cpp` (examples A0.1; US6 scenario 1):
  a ship with `EQ_WEAPON_PULSE_LASER` on its forward mount and a target directly ahead in range;
  `fireMainWeapon`; the weapon heats (`laserHeatLevelForward()`), the target's energy drops, and
  the record has `shipBeingAttacked` for the target. `--without-weapon` skips `setWeaponMount`.
  **Accept:** `tests/run.sh component --cpp -k laser_fires &&
  ! build/meson_test/tests/component-cpp/test_laser_fires --without-weapon`, and the failing
  output names the seed and the game time (FR-014).
- [ ] T029 [P] [US6] `tests/component-cpp/test_ship_attacks.cpp` (US6 scenario 2): a ship with a
  laser, a target a few kilometres away, `addTarget` and `performAttack`; within 60 s of game time
  the target has been attacked and has lost energy. `--without-weapon` as above.
  **Accept:** `tests/run.sh component --cpp -k ship_attacks &&
  ! build/meson_test/tests/component-cpp/test_ship_attacks --without-weapon`.
- [ ] T030 [P] [US6] `tests/component-cpp/test_mining_laser.cpp` (examples A0.1; US6 scenarios 3
  and 6): an `asteroid` near the player, an `adder` 2 km from it with
  `EQ_WEAPON_MINING_LASER`, `performMining`; within 2 minutes the asteroid's handle is not
  `alive()`, at least two ships of role `boulder` exist where there were none, and
  `events().has("shipDied", asteroid)`. `--without-weapon` as above.
  **Accept:** `tests/run.sh component --cpp -k mining_laser &&
  ! build/meson_test/tests/component-cpp/test_mining_laser --without-weapon`.
- [ ] T031 [US6] The M3 gate. Push; record each of the three tests' real time per platform in
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

- [ ] T032 [US2] Start `tests/component-cpp/component_census.cpp` with enumeration and `--list`
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
- [ ] T033 [US2] `--only <kind>:<key>` tries one definition in this process and prints its report
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
- [ ] T034 [US2] The whole run ([contracts/census.md](contracts/census.md), *How a run goes*,
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
- [ ] T035 [US2] The expectations file `tests/component-cpp/census-expectations.tsv` (columns
  `kind`, `key`, `expect`, `reason`; `expect` is `failed`, `left` or `not-applicable`) and its
  checks in the parent: "a key not in the data is an error; a listed definition whose outcome
  differs from `expect` is an error (so a fixed fault must be taken off the list); an empty
  `reason` is an error." The first and third exit 2, the second exits 1. A definition that
  removes itself within the span is `left` only if the file says so. The file starts with its
  header and no rows.
  **Accept:** with scratch copies passed by `--expectations`: a file naming an unknown key
  gives exit 2; one with an empty reason gives exit 2; one listing `ship adder failed <reason>`
  gives exit 1 naming `adder`; the committed file gives 0 or 1, never 2.
- [ ] T036 [US2] Prove the census can fail: `--data-overlay <dir>` merges one fixture
  `shipdata.plist` after the core data, and
  `tests/component-cpp/fixtures/broken-ship/shipdata.plist` holds one definition whose model does
  not exist.
  **Accept:** `component_census --data-overlay tests/component-cpp/fixtures/broken-ship;
  test $? -eq 1`, and its output names the fixture's key and no other as an unexpected failure.
- [ ] T037 [US2] The first full run. Register
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

- [ ] T038 [US3] `MyOpenGLView::initHeadless()` in `src/SDL/MyOpenGLView.h` / `.cpp` (contract
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
- [ ] T039 [US3] The key-lookup member (contract *Key lookup member*; examples C6):
  `MyOpenGLView` gains one replaceable member that maps (scancode, modifiers) to a key code,
  defaulting to `SDL_GetKeyFromScancode(scancode, modifiers, false)`, and
  `src/SDL/MyOpenGLView+Input.cpp` calls it at the one place that line is today (`:365`).
  Nothing else in the file changes. Case in `test_menus.cpp`:
  `the_default_lookup_is_sdls_own` (for every scancode and the modifier sets `-`, `shift`,
  `caps`, the member's answer equals SDL's).
  **Accept:** `tests/run.sh component --cpp -k menus && ./mk.sh test test`.
- [ ] T040 [US3] Keys and screens in `oo_component` (contract *Keys and screens*; data-model *Key
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
- [ ] T041 [P] [US3] Record the other two layouts,
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
- [ ] T042 [US3] The menu walk in `tests/component-cpp/test_menus.cpp` (examples A4; FR-024,
  FR-025; US3 scenarios 2, 6, 7): for every selectable row the start screen itself reports, and
  for every row on the options screens beneath it, select it by key, open it, check the screen
  that shows, back out by key and check the game is where it was. The rows are counted from the
  game's own menu, never listed in the test (SC-006), and the count visited is asserted equal to
  the count reported. *Manage Expansion Packs* is opened and left; no row on it is activated
  (hard rule 4). The exit row is checked through `exitRequested()`. Register the program three
  times in meson, with `--layout us`, `fr_azerty` and `ru`. One case asserts that every user
  directory the game resolved is under the scratch directory.
  **Accept:** `tests/run.sh component --cpp -k menus` (three tests).
- [ ] T043 [US3] The tutorial by `n`: `tests/component-cpp/tutorial_steps.hpp` (`StartTutorial`,
  `Progress`, `Stage`) and `tests/component-cpp/test_tutorial_keys.cpp` (examples A5; FR-026).
  `StartTutorial` goes *Start New Commander* → the scenario screen → the tutorial scenario →
  Enter → the mission screen, Enter → launch → lesson 0 step 2, checking the screen after each
  press. `Progress` presses the game's own *activate equipment* key, looked up from the game's key
  settings and not written as `n`, with `OO_COMPONENT_PRESS_EXPECT`, for every step of lessons 0
  and 1, checking the tutorial's stage moved each time. Take the step list from the game's
  tutorial script state at run time; read `tests/component/steps/tutorial_steps.py` for what the
  windowed walkthrough checks, and do not edit it. Register three tests, one per layout.
  **Accept:** `tests/run.sh component --cpp -k tutorial_keys` (three tests).
- [ ] T044 [US3] Show the key tests can fail (FR-029, SC-007): the fixture
  `tests/component-cpp/fixtures/us-n-remapped.tsv` is `us.tsv` with the `n` key's row giving
  another letter.
  **Accept:** `! build/meson_test/tests/component-cpp/test_tutorial_keys --layout
  tests/component-cpp/fixtures/us-n-remapped.tsv`, its output contains
  `pressing n had no effect at`, and `--layout us` still passes. Paste the failing line into
  *Records → Findings → Keys*.
- [ ] T045 [US3] Games that start with keys and settings (contract *Creating a game*, *Keys and
  screens*; FR-037, FR-039): `Settings().remapKey(control, key)` and `.keyboardCode(code)`,
  written to the test's private settings file before the game starts in the form the keyboard
  settings screen stores (`KeyConfigOverrides`, as `PlayerEntity::saveKeySetting` writes it);
  `Game::inFlightWithKeys(seed, settings)` (the scenario game with `inputView` true);
  `Game::docked(seed, settings)` (a new commander docked at the main station, with keys). Each
  needs a program of its own (one game per process), so this task's tests are T046's and T047's.
  **Accept:** as T046 (pushed together).
- [ ] T046 [US3] `tests/component-cpp/test_launch_key.cpp` (examples A0.2; FR-038; US3 scenarios
  8 and 9): docked; hold the launch key (`key_launch_ship`, `1`) until the player is in flight
  and `Universe::breakPatternOver()`; exactly one `shipLaunchedFromStation`; press the key again
  and simulate 5 s; still in flight, the break pattern is not replayed, the view is forward, and
  the count is still one. Before the launch cases, one case exercises `game.type(text)` on the
  first text-entry screen reachable by key from the docked game (default: the long-range chart's
  find-system entry) and checks the text arrived; if none is reachable without a save file,
  record that under *Decisions* and keep `type` covered by the case in T040's file instead.
  **Accept:** `tests/run.sh component --cpp -k launch_key`.
- [ ] T047 [P] [US3] `tests/component-cpp/test_remapped_key.cpp` (FR-039; US3 scenario 10):
  `Game::inFlightWithKeys(20260910, Settings().remapKey("key_fire_lasers", "k"))`, a target
  ahead; holding `k` heats the weapon and drains the target; holding the old key `a` does
  neither.
  **Accept:** `tests/run.sh component --cpp -k remapped_key`.
- [ ] T048 [P] [US6] `tests/component-cpp/test_fire_key.cpp` (US6 scenario 4): the player in
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

- [ ] T052 [US4] `tests/component-cpp/test_key_faults.cpp` (examples A6; research H1–H5): one case
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
- [ ] T053 [US4] For each case of T052 that fails: read the same code in `upstream/oolite`
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

- [ ] T055 [P] [US5] `tests/component-cpp/test_s2_pirate_attacks_target_registers_attacker.cpp`:
  seed 20260918; 1 `trader`; 1 `pirate` within 10 km; at most 900 ticks; a `trader` survives.
  **Accept:** `tests/run.sh component --cpp -k s2_`.
- [ ] T056 [P] [US5] `tests/component-cpp/test_s3_hostile_spawn_drives_ship_into_attack.cpp`:
  seed 20260918; 1 `trader`; 1 `pirate` within 10 km; at most 900 ticks; a `trader` survives.
  **Accept:** `tests/run.sh component --cpp -k s3_`.
- [ ] T057 [P] [US5] `tests/component-cpp/test_s4_missile_armed_ship_kills_by_missile.cpp`: seed
  20260918; 1 `pirate`; 1 `trader` within 10 km; at most 900 ticks; a `pirate` survives.
  **Accept:** `tests/run.sh component --cpp -k s4_`.
- [ ] T058 [P] [US5] `tests/component-cpp/test_s5_escorts_converge_on_their_mother.cpp`: seed
  20260910; 1 `trader`; 2 `escort` within 5 km; at most 900 ticks; an `escort` survives.
  **Accept:** `tests/run.sh component --cpp -k s5_`.
- [ ] T059 [P] [US5] `tests/component-cpp/test_s6_damaged_ship_flees.cpp`: seed 20260918; 1
  `police`; 1 `pirate` within 10 km; at most 900 ticks; a `police` ship survives.
  **Accept:** `tests/run.sh component --cpp -k s6_`.
- [ ] T060 [P] [US5] `tests/component-cpp/test_s7_neutral_traffic_is_quiet.cpp`: seed 20260910; 8
  `shuttle`; runs for 900 ticks; a `shuttle` survives.
  **Accept:** `tests/run.sh component --cpp -k s7_`.
- [ ] T061 [P] [US5] `tests/component-cpp/test_s8_destroyed_ships_leave_allships.cpp`: seed
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

- [ ] T063 [P] Docs, in the planning repo (FR-033): `docs/current-state.md` (the component tier
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

- Branch base (commit of `seriesb/027-modern-cpp` when cut): _not recorded_
- `origin/seriesb/027-modern-cpp` at that time: _not recorded_

### Baselines

At the base commit, on this Mac unless stated.

| What | Result |
|---|---|
| Smoke run frame time (`./mk.sh test test`) | _not measured_ |
| `tests/run.sh unit` | _not measured_ |
| `tests/run.sh component` (windowed) | _not measured_ |
| `tests/run.sh smoke` | _not measured_ |
| `tests/run.sh gui` | _not measured_ |
| One windowed S1 run, real time (and where measured) | _not measured_ |
| Compiler per CI job (Windows, Fedora, macOS, Flatpak) | _not measured_ |

### Probes

| Platform | SDL version | `dummy` driver | pushed key returns | `N` with Caps Lock |
|---|---|---|---|---|
| macOS arm64 (local) | | | | |
| Windows x64 (CI) | | | | |
| Fedora (CI) | | | | |
| Flatpak sandbox (CI) | | | | |

### Measurements

| What | Target | macOS | Windows CI | Fedora CI |
|---|---|---|---|---|
| M1 start-up, s | — | | | |
| M1 steps per second, and × real time | 20× | | | |
| S1 game ÷ real while stepping (SC-001) | ≥ 20 | | | |
| S1 whole test, s (SC-001) | < 15 | | | |
| `repeat_100.sh` S1 (SC-002) | identical | | | |
| Basic tests, s each (SC-012) | < 15 | | | |
| Definitions in the data: ships, equipment | — | | | |
| Census: passed / left / n-a / failed / expected (SC-003) | 100% accounted | | | |
| Census real time, s (SC-004) | < 300 | | | |
| Menu, tutorial, launch, remap, fire tests (SC-005, SC-013) | pass | | | |
| S1–S8 total, s, against one windowed run (SC-009) | less | | | |
| Whole tier, parallel and serial, s (SC-010) | < 600 | | | |
| Smoke frame time against baseline (SC-011) | within 2% | | | |

### Clock exceptions (FR-005)

_not listed_

### Findings

**Start-up** (T010): 

**GL sites** (T018–T021, T038): the nine known sites are in research R2. Further sites, one row
each: file, function, GL call the trap named, task, commit.

**Repeatability** (T025): 

**Census** (T037): key, seed, evidence, and how it was cleared (fix task, or expectations row).

**Keys** (T044, T052, T053): 

**Sanitizers** (T050): 

**Flatpak** (T051): 

### Finding: the Flatpak `n` report

_not written_

### Quickstart

| Step | Result |
|---|---|
| 1 | |
| 2 | |
| 2a | |
| 3 | |
| 4 | |
| 5 | |
| 6 | |
| 7 | |
| 8 | |
| 9 | |

### CI runs

| Task | Run URL | Jobs green |
|---|---|---|

### Commits

| Task | `oolite-dev` commit |
|---|---|

### Branch state

Not created yet.

### Decisions taken on defaults

Decisions already in plan.md (*Notes*) and research.md are not repeated. Added by these tasks:

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

- Merging `seriesb/029-component-tests`, and any force-push it needs after `seriesb/027-modern-cpp`
  is rewritten.
