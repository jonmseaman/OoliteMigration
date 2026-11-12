# Implementation Plan: Encapsulate the game's global state

**Branch**:
- Spec docs: `feature/phase4-polish` (OoliteMigration).
- Game work: `feature/encapsulate-global-state` in `oolite-dev`, a Git Town child of
  `seriesb/027-modern-cpp` (spec 009) once 009 is done, or of `develop` if 009 has been merged.

**Date**: 2026-11-02, refreshed 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-encapsulate-global-state/spec.md`

## Summary

The purpose is a headless, deterministic, in-process game for tests in the middle of the
diamond. Removing globals is how we get there.

**What the refresh changed** (details in [research.md](research.md#what-changed-since-2026-11-02)):
- The feature is built on **spec 009's implementation**: no `oo::Ref`/`oo::RefCounted`; standard
  smart pointers, `oo::Object`/`oo::makeShared`, C++23, `enum class`, clang-tidy guards (R13).
- The script layer is **upstream's QuickJS-ng binding**; the `ooscript` façade is gone, so
  callbacks reach the context through `JS_GetContextOpaque` (R8), and the engine is one per
  context from M2.
- **81 existing tests assign `gSharedUniverse`/`gOOPlayer`.** The bridge is redesigned so they
  keep working unchanged: the two globals become *registers* of the current context (R1), and
  deleting them at the end waits for Jon's sign-off (R15).

**How the work is built:**
- **`OOGameContext`** owns a game's services. Most code has its service passed in; anything
  else asks the context by type. The **process context** is the never-destroyed one the GUI game
  and existing tests run in.
- **`OOGame`** holds the simulation, split out from `GameController`, with one `simulate(dt)`
  that both the GUI and the headless game call.
- **The bridge.** `gSharedUniverse`, `gOOPlayer` and a few other many-reader globals hold the
  *current* context's values. `OOGameContextScope` swaps them in and out. `UNIVERSE` and `PLAYER`
  are unchanged in source and in cost, so the headless game lands early (M3), before the long
  conversion (M5).
- **Headless seams:** universe options (no add-ons, no populating, minimum detail); a graphics
  service whose stand-in turns off the five GL sites; a manual clock; a seeded RNG service; the
  real player in flight with no controls.
- **Measured progress.** The inventory comes from the built objects. A ratchet on bridge uses in
  `src/` gives each task a command that fails before its change and passes after.

## Technical Context

**Language/Version**: C++23 (spec 009's M0), Clang and GCC on Windows MSYS2 UCRT64. The check
script is Python 3, standard library only.

**Primary Dependencies**:
- no new ones;
- `oofnd` after 009: `oo::Object`, `oo::makeShared`, `oo::share`, `oo::AutoreleaseScope`;
- QuickJS-ng through upstream's binding (`JS_*` is allowed, hard rule 6);
- `llvm-nm` or GNU `nm` from the existing toolchains, for the inventory.

**Storage**: `tests/global-state/inventory.tsv` and `tests/global-state/ratchet.json`
([contracts/global-state-check.md](contracts/global-state-check.md)); this directory's
`test-ledger.md` for the one sign-off row (R15).

**Testing**:
- `oo_test` (`tests/unit/oofnd/oo_test.hpp`) in the `core` suite and in a new `scenario` suite
  (Google Test instead, if spec 005 lands first);
- `global_state_check.py` as the `global-state` test;
- `./mk.sh tidy` with 009's fatal guards;
- `tests/run.sh all` unchanged as the regression gate; CI's `unit-tests-windows` on every push.

**Target Platform**: Windows x64 now. The unit suites are Windows-only (`meson.build:121-148`).
macOS and Linux follow Phase 5.

**Project Type**: desktop game (C++), with test infrastructure.

**Performance Goals**:
- Frame time in the smoke run within 2% of the parent stage's (SC-008). The bridge itself adds
  no cost to `UNIVERSE`/`PLAYER`.
- The headless S1 port at least 10× faster than the component scenario (about 20 s plus a 5–10 s
  launch) (SC-001).

**Constraints**:
- No change in behaviour, saved games, the OXP JS API or the debug-console protocol (FR-016).
- No new warnings on Clang or GCC; `./mk.sh tidy` clean for 009's fatal categories.
- Existing tests are not edited (hard rule 1); new tests are added.
- Vendored C is untouched. Headless runs read no expansion content (hard rule 4).
- clang-format 22 on changed `src/` files only (hard rule 10).

**Scale/Scope** (2026-11-12, on 009's branch):
- 3,632 `UNIVERSE` uses in 94 files and 687 `PLAYER` uses in 49;
- 15 `shared…()` singletons;
- about 500 file-scope mutable variables (pattern match; M0's inventory replaces it);
- 135 calls of `Universe::gameController()`; 48 `sharedEngine()` calls;
- tests: 81 files assign the two globals, 64 call a `shared…()` accessor.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Existing tests are only added to. The bridge keeps every test that assigns `gSharedUniverse`/`gOOPlayer`, uses `UNIVERSE`/`PLAYER`, calls a `shared…()` accessor or `OOScheduleDeferredCall` working against the process context. Deleting the bridge (M6b) needs those tests edited; that waits for Jon's sign-off of a ledger row (R15). If a stage breaks an existing test, the stage is wrong. | pass |
| 2. No warning silenced | Nothing in the design needs it; no `NOLINT`. | pass |
| 3. Never touch `develop`/`master`/`main`; no force-push | Game work on `feature/encapsulate-global-state`, pushed fast-forward only; Jon merges. Spec docs on the current OoliteMigration branch. | pass |
| 4. Never read expansion content | Headless universes use `SCENARIO_OXP_DEFINITION_NONE` and an empty `AddOns`. The check reads only object files and `src/`. | pass |
| 5. Tools judge correctness | Every stage is accepted by the suites, the inventory check, the ratchet and `./mk.sh tidy`. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Script callbacks use QuickJS-ng's `JS_GetContextOpaque`, which rule 6 allows. | pass |
| 7. No rewriting C for its own sake | Vendored C is listed as *kept*. | pass |
| 8. Never wait for Jon | Every open choice has a default (*Notes*). The one sign-off blocks only M6b. | pass |
| 9. No writes outside the repo | Scratch goes in `.agent-tmp/`. | pass |
| 10. clang-format 22 only | On changed `src/` files; never on `tests/`. | pass |
| Every task has a failing-then-passing command | The inventory check and the ratchet for conversion tasks; new tests for feature tasks. | pass |
| Ownership follows spec 009 | Services are held as `std::shared_ptr` in the context's slots; shared game objects come from `oo::makeShared`; no DI library. | pass |

**Re-check after Phase 1:** pass. The design keeps two globals and adds three (the
current-context pointer, the process context, the register table) during the migration. They
are justified under *Complexity Tracking* and are inventory rows with status *to do* until M6b.

## Project Structure

### Documentation (this feature)

```text
specs/003-encapsulate-global-state/
├── spec.md
├── plan.md                         # this file
├── research.md                     # R1–R15
├── data-model.md
├── quickstart.md
├── test-ledger.md                  # created at M6a: the one sign-off row (R15)
├── contracts/
│   ├── game-context.md             # OOGameContext, the registers, OOGame, script access
│   ├── headless-scenario.md        # OOScenario, the test-support interface
│   └── global-state-check.md       # the check script, inventory.tsv, ratchet.json
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
src/Core/
├── OOGameContext.h / .cpp          # new: slots, hot members, process context, scope, registers
├── OOGame.h / .cpp                 # new: simulation and lifecycle, simulate(dt)
├── OODeferredCalls.h / .cpp        # new: the deferred-call queue (was GameController.cpp statics)
├── OOClock.h / .cpp                # new: OOMonotonicClock, OOManualClock
├── OOHeadless.h / .cpp             # new: headless stand-ins (graphics, sound, input, textures)
├── GameController.*                # GUI shell only: window, loop, splash, display modes
├── Universe.*                      # OOUniverseOptions; GL sites behind graphics().available()
├── OOAsyncWorkManager.cpp          # destructor calls shutdown() (R14)
├── legacy_random.*                 # state moved into OORandomState
├── Entities/OOSunEntity.cpp        # setSunColor behind graphics().available()
├── Materials/OOTexture*.cpp        # upload and dimensions behind graphics().available()
└── Scripting/OOJSEngineCore.h      # OOJSGameContext(JSContext*)
src/SDL/main.cpp                    # runs the GUI game in the process context

tests/
├── global_state_check.py           # new, 100755
├── global-state/inventory.tsv      # new
├── global-state/ratchet.json       # new
├── unit/core/test_OOGameContext.cpp   # new: slots, scopes, registers, teardown
├── unit/core/test_OOGame.cpp          # new: two games, deferred-call isolation (US2)
├── unit/scenario/                     # new suite 'scenario'
│   ├── meson.build
│   ├── oo_scenario.hpp / .cpp
│   ├── fixture/                       # Resources link, empty AddOns
│   ├── test_scenario_combat.cpp       # S1 port (SC-001)
│   ├── test_scenario_determinism.cpp  # 100 runs (SC-002)
│   ├── test_scenario_two_scenes.cpp   # (SC-006, US4 AS-3)
│   └── test_scenario_{docking,asteroids,script_event,witchspace}.cpp   # (SC-003)
├── run.sh                          # unit adds --suite scenario
meson.build                         # registers global-state and the scenario subdir
```

**Structure Decision:**
- Game code stays in `src/Core` beside the classes it replaces.
- Headless stand-ins are part of the game, so headless is a mode of the real program.
- Scenario support lives in `tests/unit/scenario`, an ordinary unit suite linking `['*']`.

## Milestones

**Prerequisite:** spec 009 complete (R13). Each stage builds, passes `tests/run.sh all` on Clang
and GCC and `./mk.sh tidy`, and changes no behaviour. The full gate is checked at the end of
each milestone.

| # | Milestone | Stories | Gate |
|---|---|---|---|
| M0 | Inventory and ratchet: `global_state_check.py`; `inventory.tsv` seeded with `--list` and categorised; `ratchet.json` at the base's counts; clean build time recorded. | US1 | `meson test --suite core global-state` passes. A scratch global makes it fail. |
| M1 | `OOGameContext` (slots, process context, scope, registers holding `gSharedUniverse`/`gOOPlayer`) and `OOGame`. `GameController` split (R3); its statics move into members and the `OODeferredCalls` service; `sharedController()` becomes `obtain<GameController>()`. `OOClock`. `main.cpp` runs the game in the process context. | US2 | `test_OOGame` runs two games and neither sees the other's deferred calls. `test_OOGameContext` passes. GameController's inventory rows are `encapsulated`. Every existing test passes unedited. |
| M2 | Services the simulation needs move into the context, one stage per singleton: `OORandomState`, ship registry, cache, async work (destructor per R14), JS engine (one per context; `gOOJSMainThreadContext` and `gOOJSPlayerIfStale` become registers; `JS_SetContextOpaque`), extension manager → graphics, sound, input. Each `shared…()` becomes `obtain<T>()`, its ratchet ceiling is set, and its 009 `exceptions.md` row goes. | US3 (prep), US5 (part) | Smoke frame time within 2%. Each moved service has a destroy-a-context test. Every `headless=yes` row is `encapsulated` or a register, apart from rows in M3. |
| M3a | Headless with a hidden GL context: `OOUniverseOptions`; a player in flight; `OOManualClock` in `simulate`; JS limit from the options; the scenario suite; `OOScenario`; the S1 port under `OOTestGLContext`. | US3 | `test_scenario_combat` passes. |
| M3b | No GL at all: `OOHeadlessGraphics`; the five GL sites guarded; textures not decoded headless. | US3 | `test_scenario_combat` passes with no window, at least 10× faster than component S1. **Main milestone.** |
| M4 | The diamond's middle layer: determinism ×100; two scenes driven in turn on one thread; docking, asteroid field, a script event, witchspace. `OOGameEventObserver`. | US3, US4 (AS-3) | SC-001, SC-002, SC-003 met. The two-scene test passes. |
| M5 | Explicit passing, by subsystem, simulation first: `Core/Entities` → `Core/Scripting` (callbacks through `OOJSGameContext`) → `Universe.cpp` internals → presentation (HUD, `GuiDisplayGen`, `PlayerEntityControls`, `PlayerEntityLoadSave`). Each stage lowers its directory's ceilings. | US4 | `src/` ceilings for `UNIVERSE` and `PLAYER` reach 0 directory by directory. Clean build time not above M0's. |
| M6a | No bridge use left in `src/`: the remaining file-scope statics moved or kept (logging, resources, OpenGL state, frame callbacks, time management …); the macros and accessors used only by tests. `test-ledger.md` row written for M6b. | US4, US5 | Every `src/` ceiling is 0. No `todo` rows except the bridge's own. Kept rows at most 10% of the starting count. |
| M6b | Delete the bridge: the macros, `OOGetUniverse`/`OOGetPlayer`, the accessors, `gSharedUniverse`/`gOOPlayer`, the registers, `current()` and `process()`; the tests that used them edited per the signed row. **Waits for Jon's sign-off** (R15). | US4 | No `todo` rows. A build with no bridge compiles and `all` passes. SC-006. |

**Order and parallelism:**
- M0 → M1 → M2 → M3a → M3b → M4 are sequential. M2's per-singleton stages are independent.
- M5's directory stages can run in parallel tasks, because each ceiling is per directory.
- M6a follows M5; M6b follows M6a and the sign-off.

## Complexity Tracking

| Exception | Why it is needed | Simpler alternative, and why it was rejected |
|---|---|---|
| The bridge: `gSharedUniverse`/`gOOPlayer` kept as registers, plus a current-context pointer, a process context and the register table, during M1–M6a | Existing tests assign the two globals and must not be edited (hard rule 1); 4,300 uses keep compiling at no extra cost while their state moves, so the headless game lands at M3; one thread can drive two scenes in turn. | A current-context pointer read by the macros (the first version of this plan) breaks 81 tests and adds a load to every use. Converting every use first puts the purpose behind more than 4,000 lines. |
| `obtain<T>()` creating services lazily in the process context | Keeps today's lazy singletons, and every caller and test of `shared…()`, unchanged. | Registering every service eagerly at start-up changes start-up order (FR-016). |
| Headless stand-ins in production `src/` | Headless has to be a mode of the real program (FR-008). | Test-only stand-ins make the test build differ from the shipped game. |

## Notes: decisions taken on defaults

Also recorded in research.md, under the R item named.

- **Built on spec 009**, started after its last task (R13).
- **Registers, not a current-context pointer behind the macros** (R1), because of the 81 tests.
- **Deleting the bridge waits for Jon** (R15). Default if he declines: the bridge stays, used
  only by tests; FR-009's deletion and SC-006 stay open and are recorded as such.
- **One JS engine per context from M2**, not M5 (R8): the new base has one binding global.
- **The class is `OOGame`, not `OoliteGame`** (R3). **"Scene" means one star system** (R3).
- **A headless tick is 1/60 s**; S1's 900 component ticks map to 112.5 s (R6).
- **The real player is kept**, in flight with no controls (R7). **JS limit headless: 10 s** (R6).
- **Inventory from object symbols** (R9); **ratchet counts `src/` only** (R10).
- **Stage size:** at most about 1,500 hand-written changed lines; a one-pattern sweep by a named
  command may be larger (R11).
- **The scenario suite is Windows-only** until Phase 5 lifts the guard (R12); Google Test if
  spec 005 lands first.
- **Not migration-phase work**: not part of `series/*`/`seriesb/*`.
- **`setup-plan.ps1` was not rerun for the refresh**: `.specify/feature.json` points at spec 011,
  and the plan already existed.

## Risks

- **`OOTextureLoader` reaches `UNIVERSE`, possibly on a worker thread.** The registers are
  main-thread state, swapped by main-thread scopes; a worker that reads one while a scope switches
  sees the wrong universe. M2 checks every `UNIVERSE`/`PLAYER` use reachable from
  `OOAsyncWorkManager` tasks; each captures what it needs before the task is queued. If any
  can't, stop and record it here.
- **A register missed.** A many-reader global the simulation needs that is neither encapsulated
  nor a register is shared by two scenes. The two-scene test (M4) and the inventory's
  `headless` column find them; each fix is its own task.
- **Hidden GL use beyond the five known sites.** M3b's test fails on the first GL call; each site
  found becomes a task.
- **Destructors never run before.** Moving a never-deleted singleton into a destroyable context
  exposes its destructor (R14). Each move has a destroy test under ASan.
- **The context header dragging in every service.** The contract limits its includes to an
  allow-list, and a test enforces it. 96 files include `Universe.h` and 57 `PlayerEntity.h`,
  mostly for the macros; M5 should forward-declare where only the pointer is needed. Clean build
  time is recorded at M0 and at the end of M5, and must not grow.
- **Determinism** from octree building, async completion order and `std::unordered_map`
  iteration. The 100-run test in M4 exposes them; each fix is its own task.
- **Overlap with other specs.** Specs 007 (RmlUi GUI) and 008 (display geometry, on
  `feature/double-wide-support`) change presentation code that M5's last stage converts; that
  stage rebases onto whichever has merged and goes last. Spec 006's performance scenarios may use
  the headless game once M3b lands.
- **009 slipping.** This feature waits for it. If 009 stops short of M7 (its ownership sign-off
  declined), this plan is refreshed again for `oo::Ref`; nothing here starts before that is known.
