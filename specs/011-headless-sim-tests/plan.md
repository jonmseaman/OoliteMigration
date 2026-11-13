# Implementation Plan: Headless simulation tests

**Branch**:
- Spec docs: `feature/phase4-polish` (OoliteMigration).
- Game work: `feature/headless-sim-tests` in a new `oolite-dev` worktree at
  `.agent-tmp/wt-sim-tests`, cut from the most recent `seriesb` branch when work starts (today
  `seriesb/027-modern-cpp`).

**Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-headless-sim-tests/spec.md`

## Summary

A new test tier, `sim`, whose C++ programs create the real game in their own process with no
window, no GL context and no sound, and step it at a fixed 1/60 s without waiting on the clock.

**How it is built:**

- **One headless entry point.** `GameController::startHeadless(options)` runs the normal start-up
  without the splash, the window, the expansion manager and the frame loop.
  `GameController::tick(dt)` is the simulation half of today's frame, shared by the windowed loop
  and the headless stepper.
- **No GL.** The known GL calls on the start-up and simulation paths are skipped when graphics are
  unavailable. On Linux and macOS the test programs also link a generated *GL trap* that aborts,
  naming the function, if any GL call is made. So a missed site fails a test.
- **Owned time and seeds.** A clock object that only `tick` advances, and one seed for every
  generator the simulation uses.
- **Real key events.** A view with no window, SDL's dummy video driver, and keys pushed onto
  SDL's own event queue. Keyboard layouts are supplied as recorded tables, because the operating
  system's layout step lives in SDL's video backends and cannot run without a display.
- **A census program** that restarts itself after a crash, so every definition gets an outcome.
- **Cross-platform from the first commit.** The suite skeleton goes into CI on Windows, macOS,
  Linux and the Flatpak build before any game code changes.

Decisions and rejected alternatives are in [research.md](research.md).

## Technical Context

**Language/Version**: C++23 (`src/meson.build:32`). Clang and GCC on Windows (MSYS2 UCRT64), Apple
Clang on macOS arm64, Clang or GCC on Linux x64.

**Primary Dependencies**:
- no new ones;
- SDL3, for the event queue and the `dummy` video driver;
- QuickJS-ng through upstream's binding, for `eval` and the seeded `Math.random`;
- `nm` from the toolchain, to generate the GL trap's symbol list.

**Storage**:
- per-run scratch directories under the build directory for settings, saves, logs and caches;
- `tests/sim/census-expectations.tsv` and the census report
  ([contracts/census.md](contracts/census.md));
- `tests/sim/layouts/*.tsv`, the recorded keyboard layouts.

**Testing**:
- `oo_test` (`tests/unit/oofnd/oo_test.hpp`) for the new programs, in a new meson suite `sim`;
- `tests/run.sh sim`, and `tests/run.sh all` as the regression gate;
- an address and undefined-behaviour sanitizer build of the suite.

**Target Platform**: Windows x64, macOS arm64, Linux x64, and the Flatpak build sandbox
(`org.freedesktop.Platform` 26.08).

**Project Type**: desktop game (C++), with test infrastructure.

**Performance Goals** (from the spec; all unmeasured until milestone M1):
- game time at least 20× real time while stepping; the first scenario under 15 s in all;
- census under 5 minutes; whole tier under 10 minutes in parallel;
- smoke-run frame time within 2% of before.

**Constraints**:
- The windowed game's behaviour, saved games and scripting API do not change. Every option
  defaults to today's behaviour.
- No existing test is edited or removed (hard rule 1).
- No expansion content is read (hard rule 4).
- No new warnings on Clang or GCC, none silenced.
- Vendored C (QuickJS, MiniZip, stb) is not edited.

**Scale/Scope**:
- 194 ship definitions (81 templates) and 41 equipment items;
- 9 known GL sites on the start-up and simulation paths, about 1,300 GL call lines in all;
- 13 real-clock reads that affect game state;
- 6 start-screen entries, about 29 screen ids;
- 8 combat scenarios to port;
- 4 CI jobs gain a step.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Tests are only added. S1–S8 keep their originals. A ported scenario that disagrees with its original stops and is reported (FR-032). The census's expected failures are a listed file with reasons, checked both ways. | pass |
| 2. No warning silenced | The GL trap is its own translation unit that includes no GL header, so it has no conflicting declarations. It needs LTO off, which the test builds already use in CI. | pass |
| 3. Never touch `develop`, `master`, `main`; never force-push | Game work is on `feature/headless-sim-tests`. It follows its base by merging (R11). | pass |
| 4. Never read expansion content | Add-ons are off by option, every add-on directory points at an empty scratch directory, and a test asserts the search path has one entry. The *Manage Expansion Packs* screen is opened and left; no row on it is activated. | pass |
| 5. Tools judge correctness | Each milestone's gate is a command. The key-path observations H1–H7 are written as tests, and a failing one is a finding, not a verdict. | pass |
| 6. No `libgnustep-base`, no SpiderMonkey | Script access is through upstream's QuickJS-ng binding. | pass |
| 7. No rewriting C for its own sake | `Math.random` is replaced through the public API. `quickjs.c` is not edited. | pass |
| 8. Never wait for Jon | Every open choice has a default in research.md and under *Notes* below. | pass |
| 9. No writes outside the repo | The worktree is under `.agent-tmp/`. Test scratch is under the build directory. | pass |
| 10. clang-format 22, never on `tests/` | Game files only. New files under `tests/sim` are laid out by hand like their neighbours. | pass |
| Every task has a failing-then-passing command | New tests supply it. For each GL site it is the trap. | pass |
| Do it the exemplar's way | New types follow the base branch's ownership as it stands (spec 009 is moving it). Nothing new is shared. | pass |

**Re-check after Phase 1:** pass. The design adds production code whose only caller is a test
(the headless entry point, the clock, the observer). That is justified under *Complexity
Tracking*.

## Project Structure

### Documentation (this feature)

```text
specs/011-headless-sim-tests/
├── spec.md
├── plan.md                    # this file
├── research.md                # findings and R1–R12
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── headless-game.md       # what the game exposes: options, tick, clock, observer
│   ├── sim-test-api.md        # oo_sim, the interface tests are written against
│   ├── census.md              # program arguments, report, expectations file, exit codes
│   └── runner.md              # tests/run.sh sim, the meson suite, CI steps
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
src/Core/
├── OOHeadless.h / .cpp            # new: OOHeadlessOptions, OOGameClock, OOGameObserver,
│                                  #      presentation record, OOGraphicsAvailable()
├── GameController.h / .cpp        # startHeadless(), tick(dt); frame loop calls tick
├── Universe.h / .cpp              # options into initWithGameView; GL sites guarded; seed
├── OOOpenGLExtensionManager.*     # headless state: no GL, no shaders
├── Entities/OOSunEntity.cpp       # setSunColor guarded
├── Entities/SkyEntity.cpp         # changeProperty guarded
├── Entities/PlayerEntity.cpp      # ship clock start from the game clock
├── Entities/PlayerEntityControls.cpp  # GUI time delta and double press from the game clock
├── Entities/ShipEntity.cpp        # script events reported to the observer
├── Materials/OOTexture*.cpp       # checkExtensions, loader set-up, upload guarded
├── Scripting/OOJavaScriptEngine.cpp   # seeded Math.random headless; limiter limit from options
├── Scripting/OOJSFrameCallbacks.cpp   # id start from the seed
└── Scripting/OOJSSystem.cpp       # the GL call at :577 guarded
src/SDL/
├── MyOpenGLView.h / .cpp          # initHeadless(): SDL events + dummy video, no window, no audio
└── MyOpenGLView+Input.cpp         # key lookup through a member that defaults to SDL's

tests/sim/                         # new tier
├── meson.build                    # suite 'sim', every platform
├── oo_sim.hpp / .cpp              # test support (contracts/sim-test-api.md)
├── gl_trap_gen.py                 # 100755: nm → gl_trap.cpp (Linux, macOS)
├── layouts/us.tsv, fr_azerty.tsv, ru.tsv
├── census-expectations.tsv
├── fixtures/                      # broken-ship/shipdata.plist, us-n-remapped.tsv
├── test_sim_skeleton.cpp          # links everything, boots nothing (M0)
├── test_sim_boot.cpp              # boots headless; search path has one entry (M1)
├── test_sim_s1_police_pirate.cpp  # US1; exemplar for the tier
├── test_sim_repeat.cpp            # same seed, same digest
├── test_sim_s2 … s8_*.cpp         # US5
├── sim_census.cpp                 # US2
├── test_sim_menus.cpp             # US3: start screen and options walk
├── test_sim_tutorial_keys.cpp     # US3: lessons 0 and 1 by `n`, per layout
├── test_sim_key_faults.cpp        # US4: H1–H5 as tests
└── repeat_100.sh                  # 100755: SC-002

tests/run.sh                       # new tier 'sim'; 'all' includes it
meson.build                        # subdir('tests/sim') on every host
.github/workflows/build-all.yaml   # sim step in the Windows, macOS and Fedora jobs
installers/flatpak/…               # optional sim step in the Oolite module
docs/ (OoliteMigration)            # current-state.md, workflow.md, GLOSSARY.md, CLAUDE.md
```

**Structure Decision:**
- The headless entry point lives in `src/Core` beside what it starts, so headless is a mode of
  the real program and not a second build of it.
- The tier is `tests/sim`, outside `tests/unit`, because the unit suites are declared only on
  Windows.
- `oo_sim` is the only thing tests include from the game. It is the place where a later spec 003
  swaps what is underneath.

## Milestones

Each milestone ends with a gate: a command that fails before it and passes after. `tests/run.sh
all` must give the same results as before at every gate (FR-031).

| # | Milestone | Stories | Gate |
|---|---|---|---|
| M0 | **Skeleton on every platform.** Worktree and branch. `tests/sim/meson.build`, `test_sim_skeleton` linking the `['*']` objects, `tests/run.sh sim`, the CI step in the Windows, macOS and Fedora jobs. Three probes written as cases: SDL's dummy driver initialises; a pushed key event comes back from `SDL_PollEvent`; what `SDL_GetKeyFromScancode` returns for `N` with Caps Lock. | — | `tests/run.sh sim` passes locally and the three CI jobs are green. |
| M1 | **Boots headless, with a hidden GL window.** `OOHeadlessOptions`, `startHeadless`, `tick`, the game clock, seeds, private directories, add-ons off. Start-up time and steps per second measured and written into `tasks.md`. | US1 | `test_sim_boot` passes: universe exists, system empty, player in flight, search path has one entry, 600 steps advance game time by 10 s. |
| M2 | **No GL at all.** Headless state in the extension manager; the nine sites guarded; textures not decoded; `gl_trap_gen.py` and the trap linked on Linux and macOS; the hidden window removed. Each further site the trap names is its own task. | US1 | `test_sim_boot` passes with no window created and the trap linked. Removing one guard makes it fail and name the GL function. |
| M3 | **First scenario.** `oo_sim` spawn, find, `eval`, the observer and the error record. S1 ported with the original's seed and expression. `test_sim_repeat` and `repeat_100.sh`. | US1 | `test_sim_s1_police_pirate` passes on three platforms. SC-001 and SC-002 measured. **Main milestone.** |
| M4 | **Census.** `sim_census` with child restart, per-definition reseeding, the report and the expectations file. Findings recorded in `tasks.md`. | US2 | `sim_census` exits zero with every definition accounted for. A broken definition added to a copy of the data makes it exit nonzero and name that key only. |
| M5 | **Keys and menus.** `initHeadless` on the view, pushed key events, the key-lookup member, recorded layouts. The start-screen and options walk. The tutorial's lessons 0 and 1. The mutation check. | US3 | `test_sim_menus` and `test_sim_tutorial_keys` pass on three platforms under three layouts. With `n` remapped in one layout table the tutorial test fails and names the press. |
| M6 | **Sanitizers and Flatpak.** The `sim` suite under address and undefined-behaviour sanitizers. The optional `meson test --suite sim` step in the Flatpak module, run in the Flatpak CI job. | US3, US4 | The sanitizer run is clean. The Flatpak job runs the suite to a result. |
| M7 | **The `n` report.** `test_sim_key_faults`: one case per observation H1–H5, each stating what a player should see. For each failing case, compare the same code in `upstream/oolite`, then fix it or record why not. The written finding. | US4 | Each case passes, or is recorded in the finding with its evidence. The finding exists in `tasks.md` with the three parts FR-030 requires. |
| M8 | **The other seven scenarios.** S2–S8, each with the original's seed, spawns and expressions. | US5 | All eight pass. Their total time is below one windowed scenario's. |
| M9 | **Docs.** `current-state.md`, `workflow.md`, `GLOSSARY.md`, the commands and exemplar table in `CLAUDE.md`, a one-line note in spec 003. | — | The docs name the tier, its command and its exemplar. |

**Order and parallelism:**
- M0 → M1 → M2 → M3 are sequential.
- After M3, three lines can run side by side on separate tasks: M4 (census), M5 (keys), M8
  (scenarios). They touch different files except `oo_sim`, whose additions are per-area.
- M6 needs M5. M7 needs M5 and M6. M9 is last.

## Complexity Tracking

| Exception | Why it is needed | Simpler alternative, and why it was rejected |
|---|---|---|
| Production code that only tests call: `startHeadless`, the game clock, the observer | Headless has to be the real program in another mode (FR-002). Each is one null check or one indirection on the windowed path. | Keeping them in `tests/` would mean a test build that differs from the shipped game, which is what the tier exists to avoid. |
| A generated GL trap linked into the test programs | It is the only way a missed GL call fails a test on its own (FR-003). Platforms disagree about what a GL call with no context does. | Guarding the known sites and trusting the list. 003 found five sites; this survey found nine. |
| The census program runs itself as a child | One crashing definition must not hide the rest (FR-021). | A single in-process loop stops at the first crash. |
| A key-lookup member on the view | Layouts cannot be tested headless otherwise, since SDL has no public call to set a keymap (R7). | Testing only the US layout. H2 would be unreachable. |

## Notes: decisions taken on defaults

Also recorded in research.md under the item named.

- **The tier is called `sim`** (R9). "Component" stays the Python tier's name.
- **The fixed step is 1/60 s** (R3).
- **Census spans:** 10 s of game time per ship, 5 s per equipment item (R8).
- **Layouts:** US QWERTY, French AZERTY, Russian (R7).
- **The operating system's layout step is out of headless reach** (R7). The spec's FR-023 and
  FR-027 were reworded on 2026-11-13 to say what is covered, and the spec's Context was corrected
  for the data counts and the tutorial's path.
- **The GL trap is on Linux and macOS only** (R2).
- **The branch is pushed and follows its base by merging** (R11).
- **Development is on the Mac; CI proves Windows and Linux** (R10).
- **Bugs found in the key path are fixed here if the fix is small** and the same code in
  `upstream/oolite` shows the same fault or the port introduced it. Anything else is recorded
  (spec, *Bugs the census finds*, applied to keys too).
- **`OOHeadlessOptions` is the type spec 003 calls `OOUniverseOptions`** plus the seed and step.
  003 gets a note at M9.

## Risks

- **A long tail of GL sites.** The trap turns each into a named failure, one task each. If the
  start screen's demo ships or planets need more than guards (for example a material that cannot
  be built without a context), the menu game may have to start with those elements off. That
  would be recorded as a limit of FR-025, not hidden.
- **Start-up cost.** Every program parses the core data afresh. If measured start-up is several
  seconds, 20 programs in parallel still meet SC-010, but SC-001's 15 s is at risk under
  sanitizers. R12 names the first remedy.
- **Repeatability from sources not yet seen:** hash-map iteration order, the octree build,
  pointer-keyed containers. `repeat_100.sh` exposes them; each is its own task.
- **SDL's dummy driver may be missing** from some platform's SDL3. M0 finds out. The fallback is
  the events subsystem alone with the key lookup always through the member; H-tests that depend
  on SDL's own lookup would then run only where the driver exists.
- **The base branch moves under the work.** `seriesb/027-modern-cpp` is being rewritten by spec
  009's tasks and has uncommitted work in the main checkout. R11 says how the branch follows.
- **A second `GameController`.** If `sharedController()` does create a second controller
  (research, *To be confirmed*), seeding and the pause flag are split between two objects. M1
  checks this first, because `startHeadless` must be called on the one the game uses.
- **The Flatpak sandbox may not allow the test to run** (no writable scratch, no `nm`). M6 would
  then record that the Flatpak leg could not run, with the error, and FR-028 would be met only by
  the Fedora leg. That is reported, not worked around.
- **The report may not be reproducible at all.** If H1–H5 all pass, the remaining candidates (the
  backend's layout step, focus, the sandbox) are outside this tier. FR-030 accepts a finding.
