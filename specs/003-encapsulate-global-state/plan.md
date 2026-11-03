# Implementation Plan: Encapsulate the game's global state

**Branch**:
- Spec docs: `feature/phase4-polish` (OoliteMigration).
- Game work: `epic/encapsulate-global-state` in `oolite-dev`, branched from `develop`.

**Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-encapsulate-global-state/spec.md`

## Summary

The purpose is a headless, deterministic, in-process game for tests in the middle of the
diamond. Removing globals is how we get there.

**How the work is built:**
- **`OOGameContext`** owns every game service. Most code reaches a service by having it passed
  in; anything else asks the context for it by type.
- **`OOGame`** holds the simulation, split out from `GameController`. It runs a single
  `simulate(dt)` that both the GUI and the headless game call.
- **The bridge.** During the migration, one current-context pointer stands behind the `UNIVERSE`
  and `PLAYER` macros. The roughly 4,300 uses keep compiling while the state behind them moves.
  The headless game therefore lands early (milestone M3), before the long conversion (M5).
- **Headless seams:**
  - universe options: no add-ons, no populating, minimum detail;
  - a graphics service whose stand-in turns off the five GL call sites on the
    construction/simulation path;
  - a clock service, with a manual clock in headless runs;
  - an RNG service seeded by the test;
  - the real player, put into flight with no controls.
- **Measured progress.** The inventory comes from the built objects, so it can't miss a global.
  A ratchet on uses of the bridge makes every stage's progress mechanical, and gives each bead a
  command that fails before its change and passes after.

See [research.md](research.md) for the decisions and what was rejected.

## Technical Context

**Language/Version**: C++20 (`gnu++20`, `src/meson.build:53`), Clang and GCC on Windows MSYS2
UCRT64. The check script is Python 3, standard library only.

**Primary Dependencies**:
- no new ones;
- `oofnd` (`oo::Ref`, `oo::RefCounted`);
- the `ooscript` façade over QuickJS-ng;
- `llvm-nm` or GNU `nm` from the existing toolchains, used for the inventory.

**Storage**: the inventory file `tests/global-state/inventory.tsv` and the ratchet
`tests/global-state/ratchet.json` (see [contracts/global-state-check.md](contracts/global-state-check.md)).

**Testing**:
- `oo_test` (`tests/unit/oofnd/oo_test.hpp`) in the `core` suite and in a new `scenario` suite;
- `global_state_check.py` as the `global-state` test;
- `tests/run.sh all` unchanged as the regression gate.

**Target Platform**: Windows x64 now. The unit suites are Windows-only (`meson.build:154-170`).
macOS and Linux follow Phase 5.

**Project Type**: desktop game (C++), with test infrastructure.

**Performance Goals**:
- Frame time in the smoke run stays within 2% of the parent stage's (SC-008).
- The headless S1 port runs at least 10× faster than the component scenario, which takes about
  20 s plus a 5–10 s launch (SC-001).

**Constraints**:
- No change in behaviour, saved games, the OXP JS API or the debug-console protocol (FR-016).
- No new warnings on Clang or GCC.
- No `JS_*` outside the QuickJS backend.
- Vendored C is untouched.
- Headless runs read no expansion content (hard rule 4).

**Scale/Scope**:
- about 3,600 `UNIVERSE` and 690 `PLAYER` uses;
- 14 `shared…()` singletons;
- about 500 file-scope mutable variables;
- about 100 calls of `Universe::gameController()`;
- 48 `sharedEngine()` call sites.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules and `docs/workflow.md`'s definition of done.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | Existing tests are only added to. `test_Universe` uses `new Universe()` (default construction), which still works. If a stage breaks an existing test, the stage is wrong. | pass |
| 2. No warning silenced | Nothing in the design needs it. New code is built at the game's warning level, and `oofnd` additions at level 2. | pass |
| 3. Never push; never touch `develop`, `master` or `main` | Game work goes on `epic/encapsulate-global-state`, and Jon merges it. Spec docs go on the current OoliteMigration branch. | pass |
| 4. Never read expansion content | Headless universes use `SCENARIO_OXP_DEFINITION_NONE`. Scenario fixtures use an empty `AddOns`. The check reads only object files and `src/`. | pass |
| 5. Tools judge correctness | Every stage is accepted by the suites, the inventory check and the ratchet. | pass |
| 6. No `libgnustep-base` or `JS_*` | Script callbacks use `ooscript::getContextPrivate`. Backend globals move inside the backend. | pass |
| 7. No rewriting C for its own sake | Vendored C is listed as *kept*. `legacy_random.cpp` is C++, and its state moves into a service only because it is global state. | pass |
| 8. Never wait for Jon | Every open choice has a default, recorded in research.md and in *Notes* below. | pass |
| 9. No writes outside the repo | Scratch goes in `.agent-tmp/`. | pass |
| Every bead has a failing-then-passing command | The inventory check and the ratchet (R10) provide one for conversion beads. New tests provide one for feature beads. | pass |
| Ownership is `oo::Ref` | Services are `oo::Ref<oo::RefCounted>`. There is no `shared_ptr` and no DI library. | pass |

**Re-check after Phase 1:** pass. The design adds one global during the migration, the
current-context pointer. It is justified under *Complexity Tracking* and is an inventory row
with status *to do* until M6.

## Project Structure

### Documentation (this feature)

```text
specs/003-encapsulate-global-state/
├── spec.md
├── plan.md                         # this file
├── research.md                     # R1–R12
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── game-context.md             # OOGameContext, OOGame, the bridge, script access
│   ├── headless-scenario.md        # OOScenario, the test-support interface
│   └── global-state-check.md       # the check script, inventory.tsv, ratchet.json
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
src/Core/
├── OOGameContext.h / .cpp          # new: service registry, hot members, scope, bridge
├── OOGame.h / .cpp                 # new: simulation and lifecycle, simulate(dt), deferred calls
├── OOClock.h / .cpp                # new: OOMonotonicClock, OOManualClock
├── OOHeadless.h / .cpp             # new: headless stand-ins (graphics, sound, input, textures)
├── GameController.*                # GUI shell only: window, loop, splash, display modes
├── Universe.*                      # OOUniverseOptions; GL sites behind graphics().available()
├── legacy_random.*                 # state moved into OORandomState
├── Entities/OOSunEntity.cpp        # setSunColor behind graphics().available()
├── Materials/OOTexture*.cpp        # upload and dimensions behind graphics().available()
├── Scripting/OOJSEngineCore.h      # OOJSGameContext(cx)
└── Scripting/ooscript/JSEngine_quickjs.cpp   # M5: backend globals into RuntimeState
src/SDL/main.cpp                    # creates the OOGame and its context, then the GameController

tests/
├── global_state_check.py           # new, 100755
├── global-state/inventory.tsv      # new
├── global-state/ratchet.json       # new
├── unit/core/test_OOGameContext.cpp   # new
├── unit/core/test_OOGame.cpp          # new: two games, deferred-call isolation (US2)
├── unit/scenario/                     # new suite 'scenario'
│   ├── meson.build
│   ├── oo_scenario.hpp / .cpp
│   ├── fixture/                       # Resources link, empty AddOns
│   ├── test_scenario_combat.cpp       # S1 port (SC-001)
│   ├── test_scenario_determinism.cpp  # 100 runs (SC-002)
│   ├── test_scenario_two_scenes.cpp   # (SC-006)
│   └── test_scenario_{docking,asteroids,script_event,witchspace}.cpp   # (SC-003)
├── run.sh                          # unit adds --suite scenario
meson.build                         # registers global-state and the scenario subdir
```

**Structure Decision:**
- The game code stays in `src/Core` beside the classes it replaces.
- Headless stand-ins are part of the game, so headless is a mode of the real program.
- Scenario test support lives in `tests/unit/scenario`, as an ordinary `oo_test` suite that links
  the `['*']` set of objects, like `test_Universe` does.

## Milestones

Each milestone is one or more stages. Each stage builds, passes `tests/run.sh all` on Clang and
GCC, and changes no behaviour. The gate is checked at the end of each milestone, not at each
bead.

| # | Milestone | Stories | Gate |
|---|---|---|---|
| M0 | Inventory and ratchet: `global_state_check.py`; `inventory.tsv` seeded with `--list` and categorised; `ratchet.json` at today's counts | US1 | `meson test --suite core global-state` passes. Adding a scratch global makes it fail. |
| M1 | `OOGameContext` and `OOGame`. `GameController` split (R3). Its six statics move into members. `sharedController()` replaced. `OOClock` added. `main.cpp` creates the game. | US2 | `test_OOGame` runs two games, and neither sees the other's deferred calls. Six inventory rows become `encapsulated`. |
| M2 | Bridge. `UNIVERSE`/`PLAYER` read through `OOGameContext::current()`. `gSharedUniverse` and `gOOPlayer` go. `newUniverse` is no longer single-instance. The services the simulation needs move into the context: `OORandomState`, ship registry, JS engine, async work, cache, extension manager → graphics, sound, input. Each `shared…()` becomes `OOGameContext::current()->get<T>()`, its ratchet ceiling is set, and the singleton static goes. | US3 (prep), US5 (part) | Smoke frame time within 2%. Every inventory row marked `headless=yes` is `encapsulated`, apart from rows in M3. |
| M3a | Headless with a hidden GL context. `OOUniverseOptions`; a player in flight; `OOManualClock` in `simulate`; JS limit from the options; the scenario suite; `OOScenario`; the S1 port, run under `OOTestGLContext`. | US3 | `test_scenario_combat` passes. |
| M3b | No GL at all. `OOHeadlessGraphics`; the five GL sites guarded; textures not decoded headless. | US3 | `test_scenario_combat` passes with no window created, and is at least 10× faster than component S1. **Main milestone.** |
| M4 | The diamond's middle layer: determinism ×100, two scenes in turn on one thread, docking, asteroid field, a script event, witchspace. `OOGameEventObserver`. | US3, US4 (AS-3) | SC-001, SC-002 and SC-003 met. The two-scene test passes. |
| M5 | Explicit passing, by subsystem, simulation first. Stages run in this order: `Core/Entities` (Entity, ShipEntity, AI, Station, Wormhole …) → `Core/Scripting` (callbacks through `OOJSGameContext`, then one engine per context with the backend globals in `RuntimeState`) → `Universe.cpp` internals → presentation (HUD, `GuiDisplayGen`, `PlayerEntityControls`, `PlayerEntityLoadSave`). Each stage lowers its directory's ratchet ceilings. | US4 | Ratchet ceilings for `UNIVERSE` and `PLAYER` reach 0 directory by directory. |
| M6 | Remove the bridge. Delete the macros, `OOGetUniverse`/`OOGetPlayer` and `OOGameContext::current()`. Move or keep the remaining file-scope statics: logging, resources, OpenGL state, frame callbacks, time management … | US4, US5 | No `todo` rows. Kept rows are at most 10% of the starting count. A build with no bridge compiles and `all` passes. |

**Order and parallelism:**
- M0 → M1 → M2 → M3a → M3b → M4 are sequential.
- M5's stages for different directories can run in parallel on separate beads, because each
  ratchet ceiling is per directory.
- M6 follows M5.
- M2's per-singleton stages are independent of each other.

## Complexity Tracking

| Exception | Why it is needed | Simpler alternative, and why it was rejected |
|---|---|---|
| The current-context pointer, a new global during M2–M5 | It lets about 4,300 uses keep compiling while their state moves, so the headless game (the purpose) lands at M3 and not after M5. It also lets one thread switch between two scenes. | Converting every use first would put the purpose behind a change of more than 4,000 lines. A `thread_local` pointer would cost a function call per access under MinGW emulated TLS. |
| Headless stand-ins in production `src/` | Headless has to be a mode of the real program (FR-008), and a future `--headless` flag would use the same stand-ins. | Putting them in `tests/` only would make the test build differ from the shipped game. |

## Notes: decisions taken on defaults

These are also recorded in research.md, under the R item named.

- **The class is `OOGame`, not `OoliteGame`.** The exemplar names Core classes with the `OO`
  prefix (R3).
- **"Scene" means one star system.** It is an `OOGame` whose universe is set up headless, not a
  new class (R3). Splitting `Universe` itself stays in Phase 6.
- **A headless tick is 1/60 s of game time.** S1's 900 component ticks map to 112.5 s of game
  time (R6).
- **The real player is kept**, in flight with no controls (R7).
- **The JS time limit headless is 10 s** (R6).
- **Inventory from object symbols, not source** (R9). Ratchet counts come from stripped source
  (R10).
- **Stage size:** at most about 1,500 changed lines of hand-written change. A mechanical sweep
  may be larger only when it is one pattern applied by a named command (R11).
- **Where the tests run:** the scenario suite is Windows-only until Phase 5 lifts the unit
  suites' guard (R12).
- **This is not migration-phase work** (spec, *Relation to the migration phases*). It is not
  part of `series/*`/`seriesb/*`, and it is proposed upstream as its own series after the
  faithful port.

## Risks

- **`OOTextureLoader` uses `UNIVERSE`, possibly on a worker thread.** The bridge is main-thread
  only. M2 must check every `UNIVERSE`/`PLAYER` use reachable from `OOAsyncWorkManager` tasks.
  Each one captures what it needs on the main thread before the task is queued. If any can't, the
  bridge needs a different design: stop and record it in this plan.
- **Hidden GL use beyond the five known sites.** M3b's test fails on the first GL call, because
  no context exists and there is a debug assert in the loader, so the test itself finds the
  sites. Each one becomes a bead.
- **Cost of `UNIVERSE` through the bridge.** It is two loads instead of one. If the smoke run
  shows more than a 2% regression, the context's hot members are cached in `Entity` during M5,
  and that subsystem's conversion moves earlier.
- **The context could become a header that drags in every service.** Per-service accessors would
  make every file that includes the context pull in the whole game. The contract forbids them,
  limits the header's includes to an allow-list, and a test enforces it
  ([contracts/game-context.md](contracts/game-context.md)).
  - **Opportunity:** today 96 files include `Universe.h` (25 includes of its own), and 57 include
    `PlayerEntity.h`, mostly to reach the macros. M5 should replace those with forward
    declarations where a file only needs the pointer.
  - **Measure:** record the clean build time at M0 and at the end of M5. It must not grow.
- **Determinism from systems not yet reviewed:** octree building, async completion order, and
  hash-map iteration order in `std::unordered_map` containers that the simulation walks. The
  100-run test in M4 exposes them, and each fix is its own bead.
