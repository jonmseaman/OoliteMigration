# Research: Encapsulate the game's global state

Three read-only surveys of `oolite-dev/src` and `oolite-dev/tests` (2026-11-02) plus spot checks.
Each item gives the decision, why it was taken, and what else was considered. All paths are
relative to `oolite-dev/src` unless they start with `tests/`.

## Findings that shape the plan

- **The simulation tick is clean.** `Universe::update(OOTimeDelta)` (`Core/Universe.cpp:7404`)
  takes a plain dt and makes no GL calls. `GameController::doPerformGameTick`
  (`Core/GameController.cpp:412-448`) does three things in order: it measures dt from the
  monotonic clock, calls `UNIVERSE->update(dt)`, `OOSound::update()` and
  `OOJSFrameCallbacksInvoke(dt)`, and then draws through `_gameView->updateScreen()`.
- **Game logic runs on game time.** Script timers, AI think intervals and the ship clock all use
  `universal_time`. The exceptions are key repeat, RNG seeding and the JS time limiter (a
  wall-clock watchdog, 0.2 s under `OO_DEBUG`).
- **Building a universe needs GL.** `Universe::initWithGameView` checks for null views, but
  `OOOpenGLExtensionManager` throws `OoliteOpenGLTooOldException` when no context exists.
  `initTargetFramebufferWithViewSize` makes FBO calls unconditionally, and both `setLighting`
  and `OOSunEntity::setSunColor` call `glLightfv`. Shaders compile eagerly unless the detail
  level is at its minimum.
- **Mesh and collision data stay on the CPU.** `OOMesh` loading and the octree are CPU-only, and
  display lists and texture uploads happen lazily at first draw. Texture *decoding* starts
  eagerly on `OOAsyncWorkManager` worker threads. `OOTexture::dimensions()` forces an upload.
- **`initWithGameView` boots the whole game in one call.** It creates the player, runs the world
  scripts and populates the system. It forces `useAddOns = SCENARIO_OXP_DEFINITION_ALL`, which
  reads `cwd/AddOns` and any managed OXZs.
- **One universe per process.** `newUniverse` raises if `gSharedUniverse` is already set.
  `GameController::applicationDidFinishLaunching` is its only caller.
- **The player is assumed everywhere.** `Entity::update` dereferences `PLAYER` without a check
  (`Core/Entities/Entity.cpp:757`), and so does `Universe::addEntity`. JS timers advance only
  inside `PlayerEntity::update`.
- **There is no service registry.** Nothing like a registry, service locator or game context
  exists. `ooscript::setContextPrivate` (the façade over `JS_SetContextOpaque`) is declared and
  has no callers. The QuickJS backend keeps its own globals: `gContexts`, `gCtxForRuntime` and
  `gDefaultCtx`.
- **The singletons share one pattern.** Each is a lazy anonymous-namespace `sSingleton`, created
  with `makeRef(...).leakRef()` and never released. `OOShipRegistry::reload` leaks the old one
  on purpose.
- **The controller is reached two ways.** `GameController::sharedController()` has 11 callers
  plus 23 `OO_DEBUG_*PROGRESS` macro uses. `Universe::gameController()`, through
  `gameView->getGameController()`, has about 100.
- **The RNG is global.** `sRANROT`, `sReallyRandomSeed` and `sReallyRandomInited` are file-scope
  in `Core/legacy_random.cpp`. `Universe.cpp:284` seeds the "really random" generator from the
  wall clock.
- **Use counts.** `UNIVERSE` has about 3,600 uses in 93 files; about 2,600 of them are under
  `Core/Entities`, and `PlayerEntity*.cpp` alone has about 1,100. `PLAYER` has about 690 uses in
  48 files, with `HeadUpDisplay.cpp` (101) and `Universe.cpp` (76) the largest.
- **Test infrastructure.** Unit tests use the custom header-only `tests/unit/oofnd/oo_test.hpp`
  (`OO_TEST`, `OO_CHECK`). There is no static library: core tests link the game's own objects
  through `extract_objects`. With `['*']` they link everything except `SDL/main.cpp`, and
  `test_Universe`/`test_ShipEntity` already do this. The `unit`/`core`/`headers` suites are built
  **only on Windows** (`meson.build:154-170`). `tests/unit/core/oo_gl_test_context.hpp`
  provides a hidden SDL GL window.
- **Component scenarios** are pytest-bdd over the debug console. Their "ticks" are wall clock
  (`TICK_SECONDS = 0.125`). A launch costs 5–10 s, and S1 takes about 20 s.
- **Warnings.** The game builds at meson warning level 1. `oofnd` builds at level 2 with
  `werror` on Clang. No sanitizer is wired into meson.

## R1 — How code reaches services

**Decision:**
- Add one class, `OOGameContext`, that owns every game service. Most code reaches a service by
  having it passed in. A service with no direct path is looked up by type: `ctx.get<T>()`.
- The three hot services (universe, player, game) are also direct members:
  `ctx.universe()`, `ctx.player()`, `ctx.game()`. Using them costs two loads and no lookup.
- During the migration, one plain global pointer, `gOOCurrentGameContext`, replaces the many
  globals it stands for. The `UNIVERSE`/`PLAYER` macros read through it.
- The pointer is switched by an RAII scope (`OOGameContextScope`). It is main-thread only. It is
  an inventory row with status *to do*, removed in milestone M6 (FR-009).

**Rationale:**
- The user offered dependency injection or a context that hands out values by type. Passing
  objects in is the end state; lookup by type covers the places passing can't reach yet: script
  callbacks and call chains 10 frames deep.
- The current-context pointer has two jobs:
  - It lets the 3,600 `UNIVERSE` uses keep compiling unchanged while the state behind them moves.
    So the headless game (US3, the purpose) lands early, not after all 3,600 uses are converted.
  - It lets one thread run two contexts in turn: a test switches scopes between scenes.
- It is a plain pointer, not `thread_local`. MinGW GCC implements `thread_local` with emulated
  TLS: every access is a call to `__emutls_get_address`. With `UNIVERSE` in `Entity::update`,
  that would put the frame-time budget at risk (SC-008).

**Alternatives considered:**
- **Constructor injection everywhere, done before the headless game.** This puts the purpose
  behind a change of more than 4,000 lines.
- **`thread_local` current context.** Rejected for MinGW emulated TLS.
- **A third-party DI library** (Boost.DI, Google Fruit). Excluded by FR-014, and nobody upstream
  would review it.
- **`std::shared_ptr` services.** The exemplar and `current-state.md` say ownership is
  `oo::Ref`.
- **Keep the singletons and add `resetForTesting()`.** This gives neither two contexts at once
  nor fakes.

## R2 — Looking up a service by type

**Decision:**
- Services derive from `oo::RefCounted` and are held as `oo::Ref<oo::RefCounted>`.
- They live in a small vector of slots in the context, keyed by `std::type_index` (RTTI is on;
  the build has no `-fno-rtti`).
- Error messages show the type through `oo::DemangledTypeName<T>()`.
- `get<T>()` raises `OOMissingServiceException` naming the type (FR-004). `find<T>()` returns
  `nullptr` for optional services. `set<T>()` adds or replaces a service (FR-005).
- Services are destroyed in reverse order of first registration.

**Rationale:** About 20 services means a linear scan is fine. Lookups happen at construction or
at the boundary of a script callback, never in an inner loop: the hot services are direct
members (R1). `type_index` needs no extra code in each service.

**Alternatives considered:**
- **A per-type static id** (the address of an inline variable). This adds a global per service
  type, and it breaks across DLL boundaries on Windows if the build ever splits into libraries.
- **A `kServiceName` string member in every service.** This is boilerplate for every service.
- **`std::any` storage.** It doesn't express "a Ref to a RefCounted", and it loses the shared
  teardown order.

## R3 — `OOGame`: the simulation, split from `GameController`

**Decision:**
- Add a new class, `OOGame`, owned by the program. It owns an `OOGameContext` and the game
  lifecycle: creating the universe, loading the player, and `simulate(OOTimeDelta)`.
  `simulate()` is the first half of today's `doPerformGameTick`: update the universe, update
  sound, run frame callbacks, and run the deferred calls that are due by the game's clock.
- `GameController` keeps the window, the event loop, splash and progress, display modes and
  exit. Each frame it measures dt, calls `game.simulate(dt)`, and then draws.
- The tick schedule (`sGameTickScheduled`, `sNextGameTick`, `sGameTickInterval`) becomes members
  of `GameController`.
- The deferred-call queue and `sLastDeferredCallException` become members of `OOGame`.
- `sMessageStack` becomes a member of `GameController` (debug builds only).
- `sharedController()` is replaced by `ctx.get<GameController>()`. A headless context has no
  controller, so the 11 progress-logging callers use `ctx.find<GameController>()` and skip when
  it is null.

**Rationale:**
- The GUI game and the headless game run the same `simulate()` (FR-008). Only the frame driver
  differs.
- The user asked for an `OoliteGame`. The name is `OOGame` because Core classes take the `OO`
  prefix (`OOColor`, the exemplar). CLAUDE.md says style comes from the exemplar.

**Alternatives considered:**
- **A separate "scene" class inside `Universe`.** That is Phase 6's split of `Universe` into
  scene graph, simulation and presentation. It needs no new class here, because one universe
  already holds one star system, which is all a scenario needs.
- **Keeping one `GameController`** with a "headless" flag. This leaves window code on the
  simulation path.

## R4 — Building a universe without the GUI

**Decision:**
- `Universe::initWithGameView(view)` becomes `initWithGameView(view, const OOUniverseOptions&)`.
  The defaults reproduce today's behaviour exactly.
- `OOUniverseOptions` has these fields:
  - `addOns`: today `SCENARIO_OXP_DEFINITION_ALL`. Headless sets `NONE`, so only the built-in
    `Resources` are read. This is also hard rule 4: tests never read expansions.
  - `populate`: whether `populateNormalSpace` runs. Headless sets `false`, so scenarios start
    empty.
  - `runWorldScripts`: default `true`.
  - `detailLevel`: headless sets the minimum, so no shaders are compiled.
- `newUniverse` no longer refuses a second universe. It is called once per context.

**Rationale:**
- There is one construction path with options, not a second headless constructor. A second path
  would drift from the real one, which FR-008 forbids.
- Strict add-on mode already exists (`ResourceManager.cpp:462-464`). It is simply overridden
  today.

**Alternatives considered:**
- **`Universe::newHeadlessUniverse()`.** A duplicate path.
- **Driving the full boot and clearing the system afterwards**, as the component tests do. This
  is slow, it reads AddOns, and it is non-deterministic.

## R5 — Running with no GPU

**Decision:**
- Add a `graphics` presentation service. `OOOpenGLExtensionManager` becomes that service in the
  context. Its headless stand-in, `OOHeadlessGraphics`, reports "no GL" without calling
  `glGetString`.
- These five places check `ctx.graphics().available()` and skip the GL work when it is false:
  1. FBO setup in `Universe`;
  2. `Universe::setLighting`;
  3. `OOSunEntity::setSunColor`;
  4. `OOTexture` upload and `dimensions()`;
  5. the drawables' render methods. The game never draws headless, so these are only assertions.
- The texture loader's headless stand-in does not decode at all. That removes worker-thread
  nondeterminism too.
- Milestone **M3a** first runs the scenario with `OOTestGLContext` (a hidden window) and
  `detailLevel` at its minimum. **M3b** removes the GL context: the test passes with
  `SDL_VIDEODRIVER` unset and no window created.

**Rationale:**
- The audit found exactly those GL calls on the simulation and construction paths; everything
  else is lazy.
- M3a gives a working headless scenario as early as possible. M3b then meets SC-001's "no
  display".

**Alternatives considered:**
- **A null OpenGL loader** that stubs every `gl*` call. This is a large surface, and it hides
  real GL use that the simulation shouldn't make.
- **Mesa/llvmpipe offscreen.** Not available on Windows, and still a GPU stack.

## R6 — Time and determinism

**Decision:**
- Add a `clock` service. `OOMonotonicClock` (the real one) and `OOManualClock` (headless,
  advanced only by `simulate`) both implement it. Deferred-call deadlines and the frame dt both
  read the clock service.
- The headless step is fixed: `step(ticks)` runs `ticks` calls of `simulate(1.0/60)`. A helper,
  `runFor(seconds)`, rounds up to whole ticks.
- **How S1 maps across.** The component scenario's "900 ticks" are 900 × 0.125 s = 112.5 s of
  wall-clock play. The headless port runs 112.5 s of game time at 60 Hz. This decision belongs
  to the plan, and it is recorded in the spec's notes through this file.
- The RNG state (`sRANROT`, `sReallyRandomSeed`, `sReallyRandomInited`) moves into an
  `OORandomState` service. The headless context seeds both the game and the "really random"
  generator from the test's seed, never from the wall clock.
- The JS time limiter keeps watching for runaway scripts. In a headless context its limit comes
  from the context options: 10 s by default. A slow run under ASan or a debugger then cannot
  change a result, while a runaway script is still caught.
- Determinism is proven by running the same scenario 100 times, comparing a per-tick hash of the
  entity positions and the event log (SC-002).

**Rationale:** Every remaining source of nondeterminism the survey found gets a named owner:
wall-clock dt, wall-clock seeding, worker-thread decoding (R5) and the watchdog.

**Alternatives considered:**
- **dt = 0.125 s**, to match the component tick literally. Physics and collision at 8 Hz differ
  from real play at 60 Hz or more, so a test would check behaviour that no player sees.
- **Turning the limiter off headless.** It hides runaway scripts, which a test should catch.

## R7 — The player in a headless game

**Decision:** Keep the real `PlayerEntity`. The headless game creates it as usual, then sets
`STATUS_IN_FLIGHT` at a given position, with no controls bound. Uncontrolled means the input
service is a stand-in that reports no keys. The scenario API treats it as just another ship
(`game.player()`).

**Rationale:** The game dereferences `PLAYER` unguarded in hot paths (`Entity::update`,
`addEntity`), and JS timers advance only through `PlayerEntity::update`. Removing the player
would change behaviour. The rule against redesign forbids that.

**Alternatives considered:**
- **A null player with guards everywhere.** This changes behaviour, and the guarded paths
  already silently return 0 (`baseMass`).
- **A minimal player subclass.** This adds a second player type to keep in step.

## R8 — Script callbacks

**Decision:**
- Each context's JS engine stores the context in `ooscript::setContextPrivate`, which today has
  no callers. Native callbacks get it with `OOJSGameContext(cx)`, a new inline helper in
  `Core/Scripting/OOJSEngineCore.h`.
- For now `OOJavaScriptEngine` stays one per process. In M5 it becomes one per context, and the
  QuickJS backend's `gContexts`/`gCtxForRuntime`/`gDefaultCtx` move into its `RuntimeState`
  (already reachable through `JS_SetRuntimeOpaque`).
- Class ids registered at start-up stay process-wide and are categorised *constant once
  initialised*.

**Rationale:**
- It uses a slot the engine already has, with no new mechanism.
- Hard rule 6 is kept: game code calls only the `ooscript::` façade, so no new `JS_*` symbols
  appear outside the backend.

**Alternatives considered:**
- **Passing the context through every native function's signature.** That rewrites more than
  1,000 callback signatures for no gain.

## R9 — Finding mutable globals (the inventory check)

**Decision:**
- Detect globals from the **built object files**, not the source. The script runs
  `llvm-nm --defined-only --demangle` (or `nm -C` with GCC) over the game's objects. A defined
  symbol in a writable data section (`b`/`B`/`d`/`D`, plus `S`/`s` on Mach-O) is a mutable
  global, whether it is a namespace-scope variable, a class static or a function-local static.
- Compiler artefacts are filtered out: guard variables (`_ZGV`), vtables, typeinfo, and
  `__emutls` control records.
- The inventory is `tests/global-state/inventory.tsv`: one row per symbol, sorted, so every
  change is a one-line diff.
- `tests/global_state_check.py` is stdlib-only. It is modelled on `tests/idiom_check.py`: exit 0
  when clean, 1 on findings and 2 on a usage error, with `--self-test` fixtures. It is
  registered as `test('global-state', ..., suite: 'core')` and depends on the `oolite` target.

**Rationale:**
- Writable data sections are the exact definition of "mutable global" in the compiler's own
  terms. A regex over the source misses function-local statics, inline variables and statics
  created by macros, and it matches look-alikes.
- `const` objects with dynamic initialisation (for example a `const std::string`) still land in
  `.bss`. They are categorised *constant once initialised*, which is correct.

**Alternatives considered:**
- **Regex over the source**, like `idiom_check.py`. Too inexact for a gate whose job is "100%".
- **libclang AST queries.** These need Python bindings that aren't in the toolchain.

## R10 — Ratchet on uses of the bridge

**Decision:**
- `tests/global-state/ratchet.json` records a ceiling on uses of `UNIVERSE`, `PLAYER`,
  `gOOCurrentGameContext` and each `shared…()` accessor, both in total and per directory.
- `global_state_check.py --ratchet` counts the uses in comment-stripped source, reusing
  `idiom_check.py`'s stripper. It fails if any count is above its ceiling, or below it by more
  than zero without the ceiling being lowered. The second rule forces every stage to write its
  progress down.
- Each conversion stage starts by lowering its ceilings, so the check fails. The stage is done
  when the check passes again. This is the "nonzero before, zero after" command each bead needs.

**Rationale:**
- It makes US4's "fewer uses than its parent" mechanical.
- It stops stages from reintroducing uses while they run side by side.

**Alternatives considered:**
- **Counting by hand in each PR.** Not verifiable.

## R11 — How stages are sized and branched

**Decision:**
- Game work is done on `epic/encapsulate-global-state` in `oolite-dev`, branched from `develop`
  by `branch.sh` (see `docs/workflow.md`).
- One stage is one or more beads that are mergeable on their own.
- **Size limit (SC-009):** a stage's hand-written change is at most about 1,500 changed lines. A
  mechanical sweep may be larger only when it is one pattern, applied by a named command
  recorded in the commit message, as `docs/workflow.md` allows for tool-driven beads.
- This work is not part of `series/*` or `seriesb/*` (spec, *Relation to the migration
  phases*).

**Rationale:** Upstream reviewers can follow a series of small, single-purpose PRs.

## R12 — Where the tests run

**Decision:**
- Headless scenario tests are ordinary `oo_test` executables in a new directory,
  `tests/unit/scenario/`, registered under a new `scenario` suite. They link the `['*']` set of
  objects, like `test_Universe`. `tests/run.sh unit` adds `--suite scenario`.
- For now they inherit the Windows-only guard of the unit suites. Running them on macOS and
  Linux arrives when Phase 5 lifts that guard.
- The headless scenarios set their working directory explicitly to a fixture root holding the
  built-in `Resources` and an empty `AddOns`.

**Rationale:**
- They are tests in the middle of the diamond, in the unit-test process, as the spec asks
  (SC-003).
- They get their own suite name so they can be run or skipped as a group.

**Note:** This macOS checkout can't run the unit suites. Every acceptance command in this plan is
run in the Windows MSYS2 UCRT64 shell named in CLAUDE.md.
