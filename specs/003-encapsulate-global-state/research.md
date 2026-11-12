# Research: Encapsulate the game's global state

First written 2026-11-02 from three read-only surveys of `oolite-dev/src` and `oolite-dev/tests`.
**Refreshed 2026-11-12** against `origin/seriesb/027-modern-cpp` (spec 009's branch, at T030) and
spec 009's planned end state, because this feature is built on spec 009's implementation (R13).
Each item gives the decision, why it was taken, and what else was considered. All paths are
relative to `oolite-dev/src` unless they start with `tests/`.

## What changed since 2026-11-02

- **The base is spec 009, not `develop`.** When this feature starts, `oo::RefCounted`, `oo::Ref`,
  `oo::WeakRef`, `makeRef`, `leakRef` and `adopt` are gone (009 M7). Shared objects derive from
  `oo::Object` (`std::enable_shared_from_this`) and are made with `oo::makeShared`; ownership is
  `std::shared_ptr`/`std::weak_ptr`/`std::unique_ptr`; entities are held as
  `EntityHold = std::shared_ptr<Entity>`; never-destroyed singletons are written in plain std
  (`static auto& s = *new T()`). The build is C++23. Unscoped enums are `enum class` with
  `kPascalCase` enumerators, C-style casts are gone, and clang-tidy guards run in CI. See R13.
- **The script layer is upstream's QuickJS-ng binding.** The `ooscript` façade the old R8 used
  no longer exists on the base; game code calls QuickJS-ng's `JS_*` API, which hard rule 6 now
  allows (Jon, 2026-11-02). R8 is rewritten.
- **`tests/idiom_check.py` was deleted** (Jon, 2026-11-10, `8ec7631d3`). Its comment-stripping
  helpers now live in `tests/check_debug_monitor_guards.py`. R9 and R10 no longer model on it.
- **Existing unit tests write the globals directly.** 81 files under `tests/unit/core` declare
  `extern Universe* gSharedUniverse` / `extern PlayerEntity* gOOPlayer` and assign them, 81 use
  `UNIVERSE`/`PLAYER`, 64 call a `shared…()` accessor, and 8 call `OOScheduleDeferredCall`. Under
  hard rule 1 none of them may be edited to make a stage pass. This was true on 2026-11-02 too,
  and the old plan (which deleted `gSharedUniverse` and `gOOPlayer` in M2) missed it. R1 is
  redesigned around it.
- **Hard rule 3** now lets agents push their own feature branches (never force-push). **Hard
  rule 10**: clang-format 22 only, on changed files, never on `tests/`.

## Findings that shape the plan

Counts are from `origin/seriesb/027-modern-cpp`, 2026-11-12. Spec 009's later milestones rename
enums and casts but do not change these counts much; M0 measures them again on the real base.

- **The simulation tick is clean.** `Universe::update(OOTimeDelta)` (`Core/Universe.cpp:7378`)
  takes a plain dt and makes no GL calls. `GameController::doPerformGameTick`
  (`Core/GameController.cpp:380`) measures dt, calls `UNIVERSE->update(dt)`, `OOSound::update()`
  and `OOJSFrameCallbacksInvoke(dt)`, and then draws through `_gameView->updateScreen()`.
- **Game logic runs on game time.** Script timers, AI think intervals and the ship clock use
  `universal_time`. The exceptions are key repeat, RNG seeding and the JS time limiter.
- **Building a universe needs GL.** `OOOpenGLExtensionManager` throws when no context exists;
  `initTargetFramebufferWithViewSize` (`Universe.cpp:11293`) makes FBO calls; `setLighting`
  (`:2483`) and `OOSunEntity::setSunColor` (`OOSunEntity.cpp:89-91`) call `glLightfv`. Shaders
  compile eagerly unless the detail level is at its minimum.
- **Mesh and collision data stay on the CPU.** Texture *decoding* starts eagerly on
  `OOAsyncWorkManager` worker threads; `OOTexture::dimensions()` forces an upload.
- **`initWithGameView` boots the whole game in one call** (`Universe.cpp:283`). It seeds the
  "really random" generator from the wall clock, forces `useAddOns = SCENARIO_OXP_DEFINITION_ALL`
  (`:292`), sets `gSharedUniverse = this` (`:295`), creates the player, runs the world scripts and
  populates the system.
- **One universe per process.** `Universe::newUniverse` (`:261`) raises if `gSharedUniverse` is
  already set. `PlayerEntity::sharedPlayer()` creates the player lazily into `gOOPlayer`
  (`PlayerEntity.cpp:436`).
- **The macros are inline readers of the globals.** `UNIVERSE` is `OOGetUniverse()`, which
  returns `gSharedUniverse` (`Universe.h:987-990`); `PLAYER` is `OOGetPlayer()`, which asserts and
  returns `gOOPlayer` (`PlayerEntity.h:1996-2004`).
- **The player is assumed everywhere.** `Entity::update` and `Universe::addEntity` dereference
  `PLAYER` without a check. JS timers advance only inside `PlayerEntity::update`.
- **There is no service registry.** No context or locator exists. The script engine keeps one
  `JSContext* gOOJSMainThreadContext` (`OOJavaScriptEngine.cpp:102`, 15 uses), created in the
  engine's constructor, which asserts it is null (`:170`). Neither `JS_SetContextOpaque` nor
  `JS_SetRuntimeOpaque` is used. Class ids are process-wide statics (`gOOJS…ClassID`).
  `gOOJSPlayerIfStale` (`OOJSEntity.h:118`) is another script global.
- **Singletons.** 15 `shared…()` accessors, by call count: `OOJavaScriptEngine::sharedEngine` 48,
  `OOJoystickManager::sharedStickHandler` 43, `OOShipRegistry::sharedRegistry` 39,
  `OOCacheManager::sharedCache` 38 (missing from the spec's list of 14), `OOMusicController` 29,
  `OOOpenGLExtensionManager` 25, `OOGraphicsResetManager` 17, `GameController` 17,
  `OODebugMonitor` 14, `OOAsyncWorkManager` 9, `OOOXZManager` 8, `OOSoundMixer` 7,
  `PlayerEntity::sharedPlayer` 6, `OOOpenALController` 5, `OONullTexture` 2. Today 53 sites use
  `makeRef(...).leakRef()`; after 009 M7 they are never-deleted function-local statics, each an
  `exceptions.md` row in spec 009.
- **The controller is reached two ways.** `GameController::sharedController()` (17 calls, plus 31
  `OO_DEBUG_*PROGRESS` macro uses) and `Universe::gameController()` (135 calls).
- **Destructors that must never run.** `OOAsyncWorkManager::~OOAsyncWorkManager` calls `abort()`
  (`OOAsyncWorkManager.cpp:259`); 009 added `shutdown()`, which the quit path calls before
  `exit(0)` (`GameController.cpp:710`). Other never-deleted singletons have never had their
  destructors run.
- **The RNG is global.** `sRANROT`, `sReallyRandomSeed` and `sReallyRandomInited` in
  `Core/legacy_random.cpp`.
- **Use counts.** `UNIVERSE` 3,632 uses in 94 files (about 2,600 under `Core/Entities`);
  `PLAYER` 687 in 49 files.
- **Test infrastructure.** Unit tests use the header-only `tests/unit/oofnd/oo_test.hpp`. Core
  tests link the game's own objects through `extract_objects`; `test_Universe`/`test_ShipEntity`
  link `['*']`. 19 tests build a universe with `new Universe()` and set `gSharedUniverse`
  themselves. The unit, core and headers suites are built **only on Windows**
  (`meson.build:121-148`), and CI's `unit-tests-windows` job runs them on every push.
  `tests/unit/core/oo_gl_test_context.hpp` provides a hidden SDL GL window. Spec 005 (Google Test)
  is specified only.
- **Component scenarios** are pytest-bdd over the debug console; their "ticks" are wall clock
  (`TICK_SECONDS = 0.125`). A launch costs 5–10 s, and S1 takes about 20 s.

## R1 — How code reaches services: the context and its registers

**Decision:**
- Add one class, `OOGameContext`, that owns a game's services. Most code reaches a service by
  having it passed in; a service with no direct path is looked up by type, `ctx.get<T>()`. The
  three hot services (universe, player, game) are direct members.
- **The process context.** There is one never-destroyed context for the process,
  `OOGameContext::process()`. The GUI game runs in it, and so does every existing test that never
  opens a scope. It behaves exactly as today's globals do, including lazy creation of singletons
  (R2) and doing no work at exit.
- **Registers.** During the migration, `gSharedUniverse` and `gOOPlayer` stay, but they change
  meaning: they hold the universe and player of the *current* context. An RAII
  `OOGameContextScope` makes a context current by saving the outgoing context's register values
  into it and loading the incoming context's values; its destructor does the reverse. So
  `UNIVERSE` and `PLAYER` compile and cost exactly what they cost today, and the 81 tests that
  assign the globals keep working unchanged against the process context.
- Other many-reader globals that the headless game needs per game join the register set in M2
  instead of being rewritten then: `gOOJSMainThreadContext` and `gOOJSPlayerIfStale` first. The
  registers are listed in one table in `OOGameContext.cpp`; a scope swaps them all. A register is
  a pointer-sized global; state that is not pointer-sized is a context member that a register
  points at.
- `OOGameContext::current()` returns the innermost scope's context, or the process context when
  no scope is open. It is main-thread only.
- The registers, the current-context pointer and the process context are the **bridge**:
  inventory rows with status *to do*. M6a removes every use of them from `src/`; M6b deletes them,
  which needs Jon's sign-off for the test edits (R15).

**Rationale:**
- The old R1 put a current-context pointer behind the macros and deleted the two globals in M2.
  That breaks 81 existing tests (hard rule 1), and it adds a load to every one of 4,300 uses.
  Registers keep both the source and the cost of every use unchanged, so the headless game
  (US3, the purpose) still lands early, with no regression risk from the bridge itself
  (SC-008).
- Two contexts are still independent: a scene's universe lives in its own context and is in the
  registers only while one of that scene's calls is running. A test can drive two scenes in turn
  on one thread.
- Plain globals, not `thread_local`: MinGW GCC implements `thread_local` with emulated TLS, a
  call to `__emutls_get_address` on every access.

**Alternatives considered:**
- **A current-context pointer read by the macros** (the old R1). It breaks the tests that assign
  the globals, and costs a load per use.
- **Constructor injection everywhere before the headless game.** This puts the purpose behind a
  change of more than 4,000 lines.
- **A third-party DI library.** Excluded by FR-014.
- **Keep the singletons and add `resetForTesting()`.** Neither two contexts nor fakes.

## R2 — Looking up a service by type

**Decision:**
- Slots are `(std::type_index, std::shared_ptr<void>)`, in registration order. `set<T>(std::
  shared_ptr<T>)` adds or replaces in place (FR-005). A service needs no common base: an
  `oo::Object` made with `oo::makeShared` keeps its `oo::Dispose` deleter through the
  `shared_ptr<void>`, and a service nothing else shares can be made with `std::make_shared`.
- `get<T>()` raises `OOMissingServiceException` naming the type through `OODemangle(typeid(T).
  name())` (`Core/OODemangle.h`, from 009) (FR-004). `find<T>()` returns `nullptr`.
- `obtain<T>()` is `get<T>()` except in the process context, where a missing `T` is created
  (`oo::makeShared<T>()` or the accessor's own factory) and registered, as the singleton is
  created today. Each `shared…()` accessor becomes a one-line `obtain<T>()` call. A test's own
  context never creates anything silently.
- Slots are released in reverse registration order.

**Rationale:**
- About 20 services: a linear scan is fine. Lookups happen at construction or at a script
  callback's boundary; the hot services are members.
- `std::shared_ptr<void>` is the base's ownership convention after 009, and it does not force
  every service into one hierarchy.
- `obtain<T>()` keeps every existing caller and test of `sharedX()` unchanged (hard rule 1).

**Alternatives considered:**
- **`std::shared_ptr<oo::Object>` slots** (009 research R12's wording). It forces `oo::Object` on
  services that nothing shares, such as `OOAsyncWorkManager`.
- **A per-type static id.** A global per service type.
- **`std::any`.** No shared teardown order and no cheap typed access.

## R3 — `OOGame`: the simulation, split from `GameController`

**Decision:**
- `OOGame` owns a context (or uses the process context, in the GUI program) and the game
  lifecycle: creating the universe, loading the player, and `simulate(OOTimeDelta)`, which is the
  first half of today's `doPerformGameTick`: universe update, sound update, frame callbacks, and
  the deferred calls due by the context's clock.
- `GameController` keeps the window, event loop, splash and progress, display modes and exit.
  Each frame it measures dt, calls `game.simulate(dt)`, then draws.
- The tick schedule (`sGameTickScheduled`, `sNextGameTick`, `sGameTickInterval`) becomes members
  of `GameController`. `sSharedController` becomes the context's `GameController` slot.
- The deferred-call queue and `sLastDeferredCallException` become an `OODeferredCalls` service
  in the context. The free function `OOScheduleDeferredCall` stays and schedules on the current
  context's queue, so its 8 test callers are unchanged. `OOGame::simulate` runs the queue.
- `sMessageStack` becomes a member of `GameController` (debug builds only).
- A headless context has no controller; the progress-logging callers use
  `find<GameController>()` and skip when it is null.

**Rationale:** the GUI and headless game run the same `simulate()` (FR-008). The name is
`OOGame` because Core classes take the `OO` prefix (the exemplar).

**Alternatives considered:** a scene class inside `Universe` (Phase 6's split); one
`GameController` with a headless flag (window code stays on the simulation path).

## R4 — Building a universe without the GUI

**Decision:**
- `Universe::initWithGameView(view)` gains a `const OOUniverseOptions&` parameter whose defaults
  reproduce today's behaviour: `addOns` (today `SCENARIO_OXP_DEFINITION_ALL`; headless `NONE`,
  which is also hard rule 4), `populate`, `runWorldScripts`, `detailLevel` (headless: the
  minimum, so no shaders compile), and the seed source for the "really random" generator (R6).
- `newUniverse` keeps its one-universe check. With registers (R1) the check is per context: a
  fresh context's register is null.
- Enumerator names are cited as they are today; where 009's M4 renamed them, its new names apply.

**Rationale:** one construction path with options, not a second headless constructor (FR-008).
Strict add-on mode already exists (`ResourceManager.cpp`); it is just overridden today.

**Alternatives considered:** `Universe::newHeadlessUniverse()` (a duplicate path); booting the
full game and clearing it (slow, reads AddOns, nondeterministic).

## R5 — Running with no GPU

**Decision:**
- `OOOpenGLExtensionManager` becomes the context's graphics service. Its headless stand-in,
  `OOHeadlessGraphics`, reports "no GL" without calling `glGetString`.
- Five places check `graphics().available()` and skip the GL work when it is false: FBO setup in
  `Universe`, `Universe::setLighting`, `OOSunEntity::setSunColor`, `OOTexture` upload and
  `dimensions()`, and the drawables' render methods (assertions only; headless never draws).
- The headless texture loader does not decode, which also removes worker-thread
  nondeterminism.
- M3a runs the scenario under `OOTestGLContext` with minimum detail. M3b removes the GL context.

**Alternatives considered:** a null OpenGL loader (large surface, hides real GL use);
Mesa/llvmpipe (not on Windows, still a GPU stack).

## R6 — Time and determinism

**Decision:**
- A clock service: `OOMonotonicClock` (real) and `OOManualClock` (headless, advanced only by
  `simulate`). Deferred-call deadlines and the frame dt read it.
- The headless step is fixed: `step(ticks)` runs `ticks` calls of `simulate(1.0/60)`;
  `runFor(seconds)` rounds up to whole ticks. S1's 900 component ticks (900 × 0.125 s) map to
  112.5 s of game time at 60 Hz.
- The RNG state moves into an `OORandomState` service. A headless context seeds both generators
  from the test's seed, never from the wall clock.
- The JS time limiter stays on; headless, its limit comes from the context options (10 s by
  default).
- Determinism is proven by 100 runs comparing a per-tick hash of entity state and the event log
  (SC-002).

**Alternatives considered:** dt = 0.125 s (8 Hz physics differs from real play); turning the
limiter off headless (hides runaway scripts).

## R7 — The player in a headless game

**Decision:** keep the real `PlayerEntity`, created as usual, then put in flight at a given
position with no controls bound (the input stand-in reports no keys).

**Rationale:** `PLAYER` is dereferenced unguarded in hot paths, and JS timers advance only
through `PlayerEntity::update`. Removing the player would change behaviour.

**Alternatives considered:** a null player with guards (changes behaviour); a minimal player
subclass (a second player type to keep in step).

## R8 — Script callbacks

**Decision:**
- Each context's JS engine stores the context with `JS_SetContextOpaque(cx, &gameContext)`,
  which nothing uses today. Native callbacks get it with `OOJSGameContext(JSContext* cx)`, a new
  inline helper in `Core/Scripting/OOJSEngineCore.h` over `JS_GetContextOpaque`.
- **One engine per context from M2.** With the façade gone, the binding's only per-engine global
  is `gOOJSMainThreadContext`, which becomes a register (R1). The engine's constructor assert
  then holds per context. Class ids stay process-wide (QuickJS-ng allocates them per process)
  and are categorised *constant once initialised*; classes are registered per runtime, as now.
- Converted callbacks (M5) call `OOJSGameContext(cx).universe()` in place of `UNIVERSE`.

**Rationale:** it uses a slot QuickJS-ng already has. Hard rule 6 allows `JS_*`. The old plan
kept one engine per process until M5 because the façade's backend had three globals; on the
new base that cost is gone, and two scenes need separate script state.

**Alternatives considered:** passing the context through every native function's signature
(more than 1,000 signatures); `JS_SetRuntimeOpaque` (the engine may use it later for its own
state; the context slot is free and is per `JSContext`).

## R9 — Finding mutable globals (the inventory check)

**Decision:**
- Detect globals from the **built object files**: `llvm-nm --defined-only --demangle` (or
  `nm -C`) over the `oolite` target's objects. A defined symbol in a writable data section
  (`b B d D`, plus `s S` on Mach-O) is a mutable global: namespace-scope, class static or
  function-local static. Guard variables, vtables, typeinfo, `__emutls` records and import stubs
  are filtered out.
- 009's never-deleted singletons (`static auto& s = *new T()`) show up as the reference's
  storage. They are inventoried like any other static.
- The inventory is `tests/global-state/inventory.tsv`, one sorted row per symbol.
- `tests/global_state_check.py` is stdlib-only, exits 0 clean, 1 on findings, 2 on a usage
  error, has `--self-test`, and is registered as `test('global-state', …, suite: 'core')`.

**Rationale:** writable data sections are the compiler's own definition of "mutable global". A
source regex misses function-local and macro-made statics. The 2026-11-10 retirement of
`idiom_check.py` removed a migration-era *source* scanner that had served its purpose; this is a
new check with a different job, and FR-002 requires it.

**Alternatives considered:** a source regex (inexact); libclang (no bindings in the toolchain);
clang-tidy `cppcoreguidelines-avoid-non-const-global-variables` (covers only namespace scope,
and cannot consult an inventory without `NOLINT`, which hard rule 2 forbids).

## R10 — Ratchet on uses of the bridge

**Decision:**
- `tests/global-state/ratchet.json` records ceilings, total and per directory, on uses **in
  `src/`** of `UNIVERSE`, `PLAYER`, `gSharedUniverse`, `gOOPlayer`, `OOGameContext::current`,
  `OOGameContext::process` and each `shared…()` accessor. Tests are not counted: they may keep
  using the bridge until M6b.
- `global_state_check.py --check ratchet` counts whole-word uses in comment- and literal-stripped
  source, using `strip_comments_and_literals` from `tests/check_debug_monitor_guards.py`
  (imported, not copied). It
  fails when a count is above its ceiling, or below it without the ceiling being lowered.
- Each conversion stage starts by lowering its ceilings (the check fails) and ends when it
  passes: the "nonzero before, zero after" command.

## R11 — How stages are sized and branched

**Decision:**
- Game work is on `feature/encapsulate-global-state` in `oolite-dev`. It is created with Git
  Town as a child of `seriesb/027-modern-cpp` once spec 009's last task is done (R13), or of
  `develop` if Jon has merged 009 by then. It is pushed (never force-pushed); Jon merges.
- One stage is one or more Spec Kit tasks, mergeable on its own. A stage's hand-written change is
  at most about 1,500 changed lines (SC-009); a mechanical sweep may be larger when it is one
  pattern applied by a named command recorded in the commit message.
- Not part of `series/*` or `seriesb/*`.

## R12 — Where the tests run

**Decision:**
- Headless scenario tests are `oo_test` executables in `tests/unit/scenario/`, suite `scenario`,
  linking the `['*']` objects like `test_Universe`. `tests/run.sh unit` adds `--suite scenario`.
- They inherit the Windows-only guard (`meson.build:121-148`). On a Mac, one test can be built
  and run against the test build's objects as 009 R2 describes (`.agent-tmp/link_run.py`).
- The scenarios run from a fixture root holding the built-in `Resources` and an empty `AddOns`.
- If spec 005 lands first, the scenario suite is written on Google Test instead (005 FR-019).

## R13 — Building on spec 009

**Decision:** this feature starts after spec 009's last task (T106 and M8's close-out), on its
branch. It uses 009's conventions everywhere: `std::shared_ptr`/`std::weak_ptr`/
`std::unique_ptr`; `oo::Object`, `oo::makeShared` and `oo::share` for shared game objects;
`EntityHold`/`oo::Hold` for entities; `oo::AutoreleaseScope` where today's code uses it; C++23;
`enum class` with `kPascalCase`; C++ casts; `std::string_view` at non-C interfaces; no
`malloc`. New code passes `./mk.sh tidy` with the guards 009 made fatal.

- Things the context takes over from 009: the never-deleted singletons become slots of the
  never-deleted process context. Each M2 stage that moves one deletes its row from 009's
  `exceptions.md` (its construct no longer exists) in the same commit.
- 009's spec-003 hooks: 009 T100 rewrites this plan's ownership gate row; this refresh already
  removes the `oo::Ref` wording, so T100's accept command passes for this file.

**Rationale:** starting before 009 is done would put two features rewriting `Core/Entities`
(009's M4–M7 and 003's M5) on top of each other, and the inventory would churn as 009 rewrites
every singleton.

**Alternatives considered:** start M0 (the check script) before 009 ends. Its self-test could,
but the seeded inventory would be wrong within days; M0 waits too.

## R14 — Destroying a context

**Decision:**
- The process context is never destroyed (it is itself a `*new` static), so the GUI program
  still does no work at exit, as today and as 009 keeps it.
- A test's context *is* destroyed, releasing its slots in reverse order. Every service that moves
  into the context therefore needs a working destructor. The stage that moves a service adds a
  test that builds a context holding it and destroys it; it runs under ASan where the platform
  has it.
- `OOAsyncWorkManager`'s destructor (today `abort()`) calls `shutdown()` and returns. That path
  is taken only by destroyed test contexts; the GUI's quit path is unchanged.

**Rationale:** the headless game's tests create and destroy many games in one process; a
destructor that was never meant to run is a crash or leak waiting for the second scene.

## R15 — Changes this refresh makes to the spec

- **FR-014** named `oo::Ref<T>`/`oo::WeakRef<T>`. It now names 009's conventions (R13).
- **Context:** counts refreshed; `OOCacheManager` added (15 singletons, not 14).
- **Assumptions:** the branch is built on spec 009, not on `develop`; a note on the existing
  tests and the bridge (below).
- **Existing tests and FR-009 (reported to Jon, not decided here).** FR-009 requires deleting
  the universe and player globals and the macros. 81 unit tests assign the globals and use the
  macros; deleting them means editing those tests, which no exception to hard rule 1 covers.
  Default: M6a removes every use from `src/`; M6b (the deletion) waits for Jon's sign-off of one
  ledger row in `test-ledger.md` (this directory) covering those edits. If he declines, the bridge
  stays, used only by tests, and SC-006 and the FR-009 deletion stay open; the feature closes with
  that recorded.
