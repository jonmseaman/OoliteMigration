# Feature Specification: Encapsulate the game's global state

**Feature Branch**: `003-encapsulate-global-state`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "I would like to build a plan for encapsulation of all data that is
currently global. I saw some global state for example in the controller class. I also know the
Universe and Player are currently globals. I would prefer those are injected with dependency
injection or perhaps a context where certain values can be pulled off by type."

## Context

The game reaches its shared objects through process-wide globals. A survey of `oolite-dev/src` on
2026-11-02 found:

- **The universe and the player.** `gSharedUniverse` and `gOOPlayer` sit behind the `UNIVERSE` and
  `PLAYER` macros. `UNIVERSE` appears about 2,400 times and `PLAYER` about 540 times.
- **14 `shared…()` singletons**: `GameController`, `OOMusicController`, `OOOpenALController`,
  `OOSoundMixer`, `OOJoystickManager`, `OOAsyncWorkManager`, `OOGraphicsResetManager`,
  `OOOpenGLExtensionManager`, `OOOXZManager`, `OOShipRegistry`, `OONullTexture`,
  `OOJavaScriptEngine`, `OODebugMonitor` and `PlayerEntity`.
- **About 500 file-scope mutable variables** (`s…` names). Among them is `GameController.cpp`'s
  controller pointer, game-tick schedule, deferred-call queue, message stack and last
  deferred-call exception. The largest clusters are in `OOJSEngineTimeManagement`,
  `OOLogOutputHandler`, `ResourceManager`, `OOJSFrameCallbacks` and `OOJavaScriptEngine`. These
  counts come from a rough pattern match. The inventory (User Story 1) replaces them.

Because of this, no part of the game can be built or tested without the whole process-wide set.
Two game instances can't exist in one process. A test can't swap a collaborator for a fake. And
the order in which things start up and shut down is implicit.

## User Scenarios & Testing *(mandatory)*

The users here are the people who change and review the game code: Jon, agents working on beads,
and the upstream Oolite maintainers who will review the result.

### User Story 1 - A developer can see every piece of global state and who owns it (Priority: P1)

A developer opens one inventory and sees every mutable global in the game code. For each one it
gives the file, what the global holds, which subsystem should own it, a category (*game-session
state*, *subsystem state*, *cache*, *constant once initialised*, or *process-level, kept*) and its
status (*to do*, *encapsulated*, *kept with reason*). An automated check compares the inventory
with the source. It fails when a global exists in the code but not in the inventory, or when the
inventory lists one that is gone.

**Why this priority**: Every later story is measured against this list. Without it, "all global
data" has no edge, and no stage can show it made progress.

**Independent Test**: Run the check on the current tree; it passes once the inventory is
complete. Add a new file-scope mutable variable in a scratch change; the check fails and names
it.

**Acceptance Scenarios**:

1. **Given** the current source, **When** the inventory check runs, **Then** it exits zero and
   every mutable global is listed with a category and an owner.
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
pattern the other stages copy.

**Why this priority**: The user named the controller. It is small, and it touches the main loop,
so it shows the pattern works without taking on `UNIVERSE`'s 2,400 uses.

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

### User Story 3 - Universe and player are passed in, not looked up (Priority: P2)

Code that uses the universe or the player gets them through its constructor, its call
parameters or the game context. The global universe and player variables and the `UNIVERSE` and
`PLAYER` macros are gone. The script engine's native callbacks reach the universe and player
through the script engine instance they run under.

**Why this priority**: These are the two most-used globals and the user named them. But they are
the largest change. They go after the pattern is proven (Story 2) and the inventory exists
(Story 1), and they are done in many stages.

**Independent Test**: For each stage, the inventory check shows fewer uses of the universe and
player globals than its parent, and all suites pass. In the final stage, a build where those
globals are not defined compiles and passes.

**Acceptance Scenarios**:

1. **Given** a stage that converts one subsystem (for example the HUD or the string expander),
   **When** it is built, **Then** that subsystem's source has no `UNIVERSE`/`PLAYER` uses and the
   suites pass.
2. **Given** all stages merged, **When** the source is searched, **Then** it defines no universe
   or player global and no `UNIVERSE`/`PLAYER` macro.
3. **Given** a new game started from the menu, **When** the universe is rebuilt, **Then** every
   holder of the old universe receives the new one. No object is left holding a stale one.

---

### User Story 4 - The remaining singletons and file-scope state are owned (Priority: P3)

Every other entry in the inventory is either encapsulated, so that an owning object holds it and
dependants are given it, or marked *kept* with a written reason. This covers the 14 `shared…()`
singletons and the file-scope variables in scripting, resources, logging, graphics and sound.

**Why this priority**: This finishes the job, but each item is small and independent. They can be
done in any order once Stories 1 and 2 have set the pattern.

**Independent Test**: The inventory shows no *to do* rows. Every *kept* row has a reason.

**Acceptance Scenarios**:

1. **Given** the feature is complete, **When** the inventory is read, **Then** every row is
   *encapsulated* or *kept with reason*.
2. **Given** a *kept* row, **When** a reviewer reads it, **Then** the reason names a concrete
   constraint, such as an OS signal handler, a C library callback with no user-data pointer, or
   logging needed before anything else exists.

---

### User Story 5 - A test can build a game context with fakes (Priority: P3)

A unit test builds a game context that contains only the services it needs. Real ones are
replaced by fakes, for example a sound mixer that records calls, or a universe holding two ships.
The code under test runs against that context, and the test needs no window, audio device or
script engine.

**Why this priority**: This is the payoff of the work, but it only becomes possible after
Stories 2–4 have removed the global lookups in the code a given test exercises.

**Independent Test**: Add one unit test for a converted subsystem that runs against a context of
fakes and asserts on the fake's recorded calls.

**Acceptance Scenarios**:

1. **Given** a converted subsystem, **When** a test builds it against a context holding a fake
   collaborator, **Then** the subsystem's calls reach the fake and the test needs no other
   service.
2. **Given** a test that asks the context for a service it did not provide, **When** the lookup
   happens, **Then** it fails at once with a message naming the missing service type. It does
   not return null and crash later.

### Edge Cases

- **Early start-up.** Logging, resource paths and the OpenGL extension probe run before any
  universe or player exists. These services must be available before the rest of the context, or
  be marked *process-level, kept*.
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
  categorised *constant once initialised*. It is still moved off globals if its filling depends
  on game state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST keep an inventory of every mutable global in the game's own code
  (`oolite-dev/src`, including `oofnd`), with file, symbol, category, owning subsystem and status.
- **FR-002**: An automated check MUST compare the inventory with the source. It MUST exit nonzero
  on any unlisted mutable global, on any listed global that no longer exists while still marked
  *to do*, and on any *kept* row without a reason. It MUST run as part of the unit tests.
- **FR-003**: The game MUST have one owning root, the **game context**, created at program start
  and destroyed at exit. It owns or refers to every encapsulated service. Code gets a service by
  having it passed in (constructor or parameter), or by asking the context for it by type.
- **FR-004**: Asking the context for a service it does not hold MUST fail immediately with a
  message naming the service type.
- **FR-005**: The context MUST let a service be swapped, so that a test can supply a fake for any
  service it needs.
- **FR-006**: The universe and the player MUST be reachable only through the context or explicit
  passing. The global variables that hold them and the `UNIVERSE`/`PLAYER` macros MUST be
  removed by the end of the feature.
- **FR-007**: When the universe or player is replaced (new game, load, reset), every dependant
  MUST see the new instance on its next access. No dependant may keep the old one.
- **FR-008**: Script engine native callbacks MUST reach game services through the script runtime
  they run in.
- **FR-009**: Every inventory entry MUST end the feature as *encapsulated* or *kept with reason*.
  Allowed reasons: a callback API with no user-data pointer, process-level OS state, or start-up
  ordering before the context exists.
- **FR-010**: The work MUST be split into stages. Each stage builds, passes every suite, and
  changes no game behaviour, so that it can be merged and proposed upstream on its own.
- **FR-011**: The services MUST keep the project's ownership conventions (`oo::Ref<T>` /
  `oo::WeakRef<T>`). The feature MUST NOT introduce a third-party dependency-injection library.
- **FR-012**: Vendored C code MUST NOT be changed by this feature (hard rule 7). Its globals are
  listed in the inventory as *kept* and are not converted.
- **FR-013**: The game's behaviour, saved games, expansion (OXP/OXZ) scripting API and debug
  console protocol MUST be unchanged.

### Key Entities

- **Game context**: the single root that owns the session's services for the life of the
  program. It hands each service out by type, or to the objects it constructs.
- **Service**: an object that today is reached through a global or a `shared…()` accessor
  (controller, universe, player, sound mixer, script engine, ship registry …). It has one owner
  and possibly several dependants.
- **Inventory entry**: one mutable global. It records file, symbol, category, owner, status and
  the reason when kept.
- **Stage**: one independently mergeable unit of conversion. It moves a set of inventory entries
  from *to do* to *encapsulated* or *kept*.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The inventory lists 100% of the mutable globals in the game's own code, and the
  check enforces this on every unit-test run.
- **SC-002**: When the feature is done, 0 inventory entries are *to do*. Every *kept* entry has a
  reason, and kept entries are no more than 10% of the starting count.
- **SC-003**: 0 uses of the universe or player globals remain, counted from about 2,400 and
  about 540 at the start.
- **SC-004**: At least one unit test runs two independent game contexts in one process. At least
  one unit test runs a converted subsystem against fakes with no window, audio device or script
  engine.
- **SC-005**: Every stage passes `unit`, `component`, `smoke` and `gui` with the same results as
  its parent, and builds with no new warnings under both Clang and GCC.
- **SC-006**: Frame time in the smoke run stays within 2% of the parent stage's.
- **SC-007**: No stage's diff exceeds the size the upstream maintainers will review in one
  sitting. The plan sets the limit.

## Assumptions

Each decision below was taken on a conservative default (CLAUDE.md rule 8). Jon may override any
of them.

- **Deliverable.** The feature delivers the encapsulation itself, staged. A plan document alone
  is not the deliverable. `/speckit-plan` sets the stage order.
- **Mechanism.** The user offered dependency injection or a context that hands out values by
  type. The spec requires both, with explicit passing preferred: objects take what they need in
  their constructor or parameters, and lookup by type from the context is used where explicit
  passing cannot reach (script callbacks, deep call chains during migration). The plan chooses
  the exact shape. It follows `src/Core/OOColor.*` style and uses no external library.
- **Scope.** All of `oolite-dev/src`, including `oofnd`. Vendored C and compile-time constants
  are excluded; vendored C globals are listed as *kept*.
- **Order.** Inventory and check, then the `GameController` pilot, then the universe and player
  in subsystem-sized stages, then the remaining singletons and file-scope state. The rebuild of
  `Universe` planned for Phase 6 is out of scope. This feature changes how the universe is
  reached, not what is inside it.
- **Relation to 4p.** This is source hygiene for upstream, so it sits in Phase 4p. Because of its
  size it may run alongside Phase 5. The plan records that.
- **Threading.** Thread confinement stays as it is today. The feature does not make any service
  thread-safe that is not already.
- **Upstream review.** The upstream maintainers accept a long series of small mechanical PRs
  more readily than one large one. The `seriesb/*` approach from feature 002 is the model.
