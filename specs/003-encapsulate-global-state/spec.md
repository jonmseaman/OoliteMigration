# Feature Specification: Encapsulate the game's global state

**Feature Branch**: `003-encapsulate-global-state`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "I would like to build a plan for encapsulation of all data that is
currently global. I saw some global state for example in the controller class. I also know the
Universe and Player are currently globals. I would prefer those are injected with dependency
injection or perhaps a context where certain values can be pulled off by type."

Follow-up: "The purpose would be to enhance testability because then there could be a class like
OoliteGame (or something at a smaller level, maybe a scene) where you can create entities like
enemy ships and asteroids and simulate behavior without opening the GUI. This could greatly
enhance testability by enabling diamond tests as opposed to pyramid testing strategy."

## Purpose

**The goal is testability. Removing globals is the means.** When this feature is done, a test
creates a game in-process: an `OoliteGame`, or a smaller **scene**, with no window, GPU, audio
device or user input. It adds entities such as enemy ships, police, asteroids and stations. It
advances the simulation by a fixed number of ticks and asserts on what happened.

This supports a **diamond** test strategy instead of a pyramid. Most tests sit in the wide middle
layer: real game logic (AI, combat, physics, docking, scripting) exercised across several
subsystems at once, but headless, fast and deterministic. The layers above and below stay thin:
fine-grained unit tests below, and the slow tests that need the real window above.

Today that middle layer can't exist in-process. The nearest thing is the component suite
(`tests/component`). For example, `s1_police_kills_pirate.feature` spawns a police ship and a
pirate and waits for the engagement. But it drives the full GUI game over the debug console. Each
scenario pays for a game launch and a window, and runs in wall-clock time, not simulated ticks.
This feature makes those scenarios runnable as ordinary in-process tests.

Every decision in this spec is judged by whether it helps that headless game exist. The stage
order follows from it: subsystems that the headless game needs are converted first.

## Context

The game reaches its shared objects through process-wide globals. A survey of `oolite-dev/src` on
2026-11-02 found:

- **The universe and the player.** `gSharedUniverse` and `gOOPlayer` sit behind the `UNIVERSE` and
  `PLAYER` macros. `UNIVERSE` appears about 2,400 times and `PLAYER` about 540 times. A universe
  is built by `Universe::newUniverse(MyOpenGLView*)`, so making one requires the game's view.
- **14 `shared…()` singletons**: `GameController`, `OOMusicController`, `OOOpenALController`,
  `OOSoundMixer`, `OOJoystickManager`, `OOAsyncWorkManager`, `OOGraphicsResetManager`,
  `OOOpenGLExtensionManager`, `OOOXZManager`, `OOShipRegistry`, `OONullTexture`,
  `OOJavaScriptEngine`, `OODebugMonitor` and `PlayerEntity`.
- **About 500 file-scope mutable variables** (`s…` names). Among them is `GameController.cpp`'s
  controller pointer, game-tick schedule, deferred-call queue, message stack and last
  deferred-call exception. The largest clusters are in `OOJSEngineTimeManagement`,
  `OOLogOutputHandler`, `ResourceManager`, `OOJSFrameCallbacks` and `OOJavaScriptEngine`. These
  counts come from a rough pattern match. The inventory (User Story 1) replaces them.

Because of this, no part of the game runs without the whole process-wide set: window, OpenGL,
audio and all. Two games can't exist in one process. A test can't swap a collaborator for a fake.
And the order in which things start up and shut down is implicit.

## User Scenarios & Testing *(mandatory)*

The users are the people who change and review the game code: Jon, agents working on beads, and
the upstream Oolite maintainers. Most of all, they are the people who write tests.

### User Story 1 - A developer can see every piece of global state and who owns it (Priority: P1)

A developer opens one inventory and sees every mutable global in the game code. For each one it
gives the file, what the global holds, which subsystem should own it, a category (*game-session
state*, *subsystem state*, *presentation* (window, graphics, sound, input), *cache*, *constant
once initialised*, or *process-level, kept*), its status (*to do*, *encapsulated*, *kept with
reason*), and whether the headless game needs it. An automated check compares the inventory with
the source. It fails when a global exists in the code but not in the inventory, or when the
inventory lists one that is gone.

**Why this priority**: Every later story is measured against this list. The "needed headless"
column is what orders the stages.

**Independent Test**: Run the check on the current tree; it passes once the inventory is
complete. Add a new file-scope mutable variable in a scratch change; the check fails and names
it.

**Acceptance Scenarios**:

1. **Given** the current source, **When** the inventory check runs, **Then** it exits zero and
   every mutable global is listed with a category, an owner and its headless-need flag.
2. **Given** a change that adds an unlisted mutable global, **When** the check runs, **Then** it
   exits nonzero and names the file and the variable.
3. **Given** a change that removes a global, **When** its inventory row still says *to do*,
   **Then** the check exits nonzero until the row is marked *encapsulated*.

---

### User Story 2 - The game controller's state belongs to one game object (Priority: P1)

The controller's scheduling state, deferred calls, message stack and its own instance pointer now
belong to an object that the program creates at startup and destroys at exit. Code that needs the
controller is given it, either directly or through the game context (see FR-003). It no longer
calls a global accessor. This is the pilot: the first subsystem done end to end, and it sets the
pattern the other stages copy. It also separates the controller's simulation-tick role from its
window and event-loop role, which the headless game needs.

**Why this priority**: The user named the controller, and it owns the tick, which every headless
test drives. It is small, so it proves the pattern without taking on `UNIVERSE`'s 2,400 uses.

**Independent Test**: A unit test builds two controller instances in one process. It schedules a
deferred call on one and checks that the other never runs it. All existing suites still pass.

**Acceptance Scenarios**:

1. **Given** the pilot is merged, **When** the inventory check runs, **Then** all of
   `GameController`'s globals are marked *encapsulated* and none remain in the source.
2. **Given** two controller instances in one test, **When** each schedules work, **Then** neither
   sees the other's queue, messages or tick schedule.
3. **Given** the full test run (`unit`, `component`, `smoke`, `gui`), **When** it runs on the pilot
   branch, **Then** every suite gives the same result as on its parent.

---

### User Story 3 - A test simulates a scene of ships without the GUI (Priority: P1 — the purpose)

A test creates a headless game or scene with a fixed seed. It needs no window, OpenGL context,
audio device or input. It spawns a police viper and a pirate 10 km apart, and an asteroid field.
It steps the simulation 900 ticks at a fixed time step, then asserts that the police ship engaged
the pirate and survived. It queries the scene for entities by role, position and state, and
receives the events the game raised (attacked, destroyed, docked). The test runs in the ordinary
unit-test process, in seconds, and gives the same result every run.

**Why this priority**: This is why the feature exists. Stories 1 and 2 come first only because
they are prerequisites. Achieving this story is the feature's main milestone, not its last step.

**Independent Test**: Port `s1_police_kills_pirate.feature` to a headless in-process test. It
passes with the same seed, needs no display, and runs at least 10× faster than the component
scenario.

**Acceptance Scenarios**:

1. **Given** a headless scene seeded with 20260910 holding one police ship and one pirate 10 km
   apart, **When** it is stepped 900 ticks, **Then** the police ship engages the pirate and
   survives, matching the component scenario's result.
2. **Given** the same seed and spawns, **When** the test runs twice, **Then** both runs produce
   the same entity positions and events at every tick.
3. **Given** a machine with no display and no audio device (CI, a container), **When** the
   headless tests run, **Then** they pass.
4. **Given** a headless scene, **When** the game logic would draw, play a sound or read input,
   **Then** it calls a headless stand-in for that service: one that does nothing, or one that
   records the call for the test to inspect.
5. **Given** a scene that loads the core ship data and scripts, **When** a ship's AI or
   JavaScript runs, **Then** it behaves exactly as it does in the GUI game.

---

### User Story 4 - Universe and player are passed in, not looked up (Priority: P2)

Code that uses the universe or the player gets them through its constructor, its call
parameters or the game context. The global universe and player variables and the `UNIVERSE` and
`PLAYER` macros are gone. The script engine's native callbacks reach the universe and player
through the script engine instance they run under.

**Why this priority**: Story 3 can be reached with only one game per process, so before every
global is gone. Removing the universe and player globals is what makes the game context truly
independent. Then two scenes can run side by side, and each test starts from a clean game
rather than a reset one. The work is large and is done in subsystem-sized stages, simulation
code first.

**Independent Test**: For each stage, the inventory check shows fewer uses of the universe and
player globals than its parent, and all suites pass. In the final stage, a build where those
globals are not defined compiles and passes, and a test runs two headless scenes at once.

**Acceptance Scenarios**:

1. **Given** a stage that converts one subsystem (for example ship AI or the string expander),
   **When** it is built, **Then** that subsystem's source has no `UNIVERSE`/`PLAYER` uses and the
   suites pass.
2. **Given** all stages merged, **When** the source is searched, **Then** it defines no universe
   or player global and no `UNIVERSE`/`PLAYER` macro.
3. **Given** two headless scenes in one test with different seeds, **When** both are stepped,
   **Then** each produces exactly the result it produces alone.
4. **Given** a new game started from the menu, **When** the universe is rebuilt, **Then** every
   holder of the old universe receives the new one. No object is left holding a stale one.

---

### User Story 5 - The remaining singletons and file-scope state are owned (Priority: P3)

Every other entry in the inventory is either encapsulated, so that an owning object holds it and
dependants are given it, or marked *kept* with a written reason. This covers the 14 `shared…()`
singletons and the file-scope variables in scripting, resources, logging, graphics and sound.

**Why this priority**: This finishes the job. The entries the headless game needs are done
within Stories 3 and 4. What is left is mostly presentation-side and does not block testing.

**Independent Test**: The inventory shows no *to do* rows. Every *kept* row has a reason.

**Acceptance Scenarios**:

1. **Given** the feature is complete, **When** the inventory is read, **Then** every row is
   *encapsulated* or *kept with reason*.
2. **Given** a *kept* row, **When** a reviewer reads it, **Then** the reason names a concrete
   constraint, such as an OS signal handler, a C library callback with no user-data pointer, or
   logging needed before anything else exists.

### Edge Cases

- **Entities that touch rendering.** Ships and other entities load meshes, textures and shaders,
  and some do so while they are being set up. A headless scene must create entities without a
  GPU. Geometry the simulation needs, such as collision radius and bounding box, must be
  available without uploading anything to OpenGL.
- **Simulated time vs wall-clock time.** The GUI game advances by measured frame time, but a
  headless scene steps a fixed time step it is given. Script timers, AI think intervals and the
  JS time limiter must all follow simulated time in a headless scene.
- **Early start-up.** Logging, resource paths and the OpenGL extension probe run before any
  universe or player exists. These services must be available before the rest of the context, or
  be marked *process-level, kept*. A headless context skips the OpenGL probe entirely.
- **The player in a headless scene.** Much game logic assumes a player ship exists. A scene must
  either contain a player entity, possibly one that no one controls, or the logic must work
  without one. The plan picks which.
- **New game, load game, reset.** The universe and player are rebuilt mid-run
  (`Universe::newUniverse`). Anything holding them must see the replacement. It must not keep a
  pointer to the destroyed one.
- **Shutdown order.** Destroying the context must tear services down in reverse dependency
  order. Today's exit path depends on the order in which static variables are destroyed.
- **Worker threads.** Work in `OOAsyncWorkManager` and the audio thread reaches shared state. A
  service handed to another thread must be safe to share, or be confined to its thread, as it is
  today.
- **Script callbacks.** QuickJS native functions get no game argument. They must reach the game
  through the script runtime they run in, never through a global.
- **C callbacks.** Callbacks from vendored C libraries (OpenAL, SDL, libpng) that carry no
  user-data pointer may force a global. Such globals stay as *process-level, kept*, with that
  reason.
- **Debug-only state.** Globals that exist only in debug builds (`OODebugMonitor`, assertion
  helpers) are inventoried like any other.
- **Constants built once.** A table that is filled once at start-up and only read afterwards is
  categorised *constant once initialised*. It may stay shared between scenes. It is still moved
  off globals if its filling depends on game state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST keep an inventory of every mutable global in the game's own code
  (`oolite-dev/src`, including `oofnd`), with file, symbol, category, owning subsystem, status
  and whether the headless game needs it.
- **FR-002**: An automated check MUST compare the inventory with the source. It MUST exit nonzero
  on any unlisted mutable global, on any listed global that no longer exists while still marked
  *to do*, and on any *kept* row without a reason. It MUST run as part of the unit tests.
- **FR-003**: The game MUST have an owning root, the **game context**, that owns or refers to
  every encapsulated service. Code gets a service by having it passed in (constructor or
  parameter), or by asking the context for it by type. The GUI program creates one at start-up;
  a test may create its own.
- **FR-004**: Asking the context for a service it does not hold MUST fail immediately with a
  message naming the service type.
- **FR-005**: The context MUST let a service be swapped, so that a test can supply a fake or
  recording stand-in for any service.
- **FR-006**: There MUST be a headless game entry point, an `OoliteGame` or a scene, for tests to
  use. It builds a context with headless stand-ins for window, graphics, sound and input. It
  loads the core game data. It lets a test spawn entities by role or ship key at a position,
  step the simulation N ticks at a fixed time step, query entities, and observe game events.
- **FR-007**: A headless game MUST run with no display, GPU or audio device present. Its results
  MUST be deterministic for a given seed and sequence of calls.
- **FR-008**: The simulation (AI, physics, combat, docking, scripting) MUST run the same code in
  headless and GUI play. The two modes differ only in the presentation services they are given.
- **FR-009**: The universe and the player MUST be reachable only through the context or explicit
  passing. The global variables that hold them and the `UNIVERSE`/`PLAYER` macros MUST be
  removed by the end of the feature.
- **FR-010**: When the universe or player is replaced (new game, load, reset), every dependant
  MUST see the new instance on its next access. No dependant may keep the old one.
- **FR-011**: Script engine native callbacks MUST reach game services through the script runtime
  they run in.
- **FR-012**: Every inventory entry MUST end the feature as *encapsulated* or *kept with reason*.
  Allowed reasons: a callback API with no user-data pointer, process-level OS state, start-up
  ordering before the context exists, or immutable data safe to share between contexts.
- **FR-013**: The work MUST be split into stages. Each stage builds, passes every suite, and
  changes no game behaviour, so that it can be merged and proposed upstream on its own. Entries
  the headless game needs are converted before those it does not.
- **FR-014**: The services MUST keep the project's ownership conventions (`oo::Ref<T>` /
  `oo::WeakRef<T>`). The feature MUST NOT introduce a third-party dependency-injection library.
- **FR-015**: Vendored C code MUST NOT be changed by this feature (hard rule 7). Its globals are
  listed in the inventory as *kept* and are not converted.
- **FR-016**: The game's behaviour, saved games, expansion (OXP/OXZ) scripting API and debug
  console protocol MUST be unchanged. The existing `component` and `gui` suites stay, as the
  layer above the headless tests.

### Key Entities

- **Game context**: the root that owns a game's services. It hands each service out by type, or
  to the objects it constructs. There is one in the GUI program, and one per headless game in
  tests.
- **Headless game / scene**: the test-facing entry point (`OoliteGame` or a smaller scene). It
  wraps a game context with headless presentation services and offers spawn, step, query and
  observe operations.
- **Service**: an object that today is reached through a global or a `shared…()` accessor
  (controller, universe, player, sound mixer, script engine, ship registry …). It has one owner
  and possibly several dependants. Presentation services (window, graphics, sound, input) have a
  headless stand-in.
- **Inventory entry**: one mutable global. It records file, symbol, category, owner, status,
  whether the headless game needs it, and the reason when kept.
- **Stage**: one independently mergeable unit of conversion. It moves a set of inventory entries
  from *to do* to *encapsulated* or *kept*.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A headless test of the police-vs-pirate scenario passes with the component
  scenario's seed. It runs with no display and no audio device, and runs at least 10× faster
  than the component scenario.
- **SC-002**: Running a headless scenario twice with the same seed gives identical results.
  Measured over 100 consecutive runs, it is flaky 0 times.
- **SC-003**: At least 5 headless scenario tests exist by the end of the feature, covering
  combat, docking, an asteroid field, a script-driven event and a witchspace jump or system
  change. They are tests in the middle of the diamond, and they run in the `unit` suite's
  process.
- **SC-004**: The inventory lists 100% of the mutable globals in the game's own code, and the
  check enforces this on every unit-test run.
- **SC-005**: When the feature is done, 0 inventory entries are *to do*. Every *kept* entry has a
  reason, and kept entries are no more than 10% of the starting count.
- **SC-006**: 0 uses of the universe or player globals remain, counted from about 2,400 and
  about 540 at the start. A test runs two headless scenes at once, each giving its solo result.
- **SC-007**: Every stage passes `unit`, `component`, `smoke` and `gui` with the same results as
  its parent, and builds with no new warnings under both Clang and GCC.
- **SC-008**: Frame time in the smoke run stays within 2% of the parent stage's.
- **SC-009**: No stage's diff exceeds the size the upstream maintainers will review in one
  sitting. The plan sets the limit.

## Assumptions

Each decision below was taken on a conservative default (CLAUDE.md rule 8). Jon may override any
of them.

- **Deliverable.** The feature delivers the encapsulation and the headless game, staged. A plan
  document alone is not the deliverable. `/speckit-plan` sets the stage order.
- **Game or scene.** The user left open whether the entry point is a whole `OoliteGame` or a
  smaller scene. The default: the headless entry point covers one star system's worth of
  simulation, which is what the scenarios need. Whether it is built as a full game with headless
  presentation, or as a scene class inside it, is a plan decision, chosen for the smallest change
  to `Universe`.
- **Mechanism.** The user offered dependency injection or a context that hands out values by
  type. The spec requires both, with explicit passing preferred: objects take what they need in
  their constructor or parameters, and lookup by type from the context is used where explicit
  passing cannot reach (script callbacks, deep call chains during migration). The plan chooses
  the exact shape. It follows `src/Core/OOColor.*` style and uses no external library.
- **Scope.** All of `oolite-dev/src`, including `oofnd`. Vendored C and compile-time constants
  are excluded; vendored C globals are listed as *kept*.
- **Order.** Inventory and check, then the `GameController` pilot, then the services the
  headless game needs, up to the first headless scenario passing. After that, the universe and
  player globals are removed in subsystem-sized stages, then the remaining singletons and
  file-scope state. The rebuild of `Universe` planned for Phase 6 (separating scene graph,
  simulation and presentation) is out of scope beyond what the headless game strictly needs.
  This feature changes how the universe is reached and lets it be created without a view; it
  does not redesign its internals.
- **Test framework.** The headless tests use the existing unit test framework under `tests/unit`
  and run in the `unit` suite. Porting component scenarios to Gherkin-over-headless is a possible
  follow-up, not part of this feature.
- **Relation to 4p.** This is source hygiene and test infrastructure for upstream, so it sits in
  Phase 4p. Because of its size it may run alongside Phase 5. The plan records that.
- **Threading.** Thread confinement stays as it is today. The feature does not make any service
  thread-safe that is not already. Headless scenes may run tests in parallel only as separate
  processes until Story 4 is done.
- **Upstream review.** The upstream maintainers accept a long series of small mechanical PRs
  more readily than one large one. The `seriesb/*` approach from feature 002 is the model.
