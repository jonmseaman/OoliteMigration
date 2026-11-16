# Dependency injection for testable games

Status: **Prepare**. Not ready for an executor until Jon moves it to "Tasks".

Base: the stack tip, `seriesb/033-drop-oo-prefix`, which contains the C++ component tests
(`seriesb/029-cpp-component-tests`) and `oo::SpeechSynthesizer`. Make the branch with
`git town append`. Counts below are from that tip on 2026-11-16.

## Why

A component test can't fake a collaborator, and it can't build a second game in the same process.
Every service is reached through a process-wide global:

- `UNIVERSE` (2,402 lines in `src/`) and `PLAYER` (434 lines) are macros over `gSharedUniverse` and
  `gOOPlayer`.
- 15 `shared…()` accessors (357 lines in `src/`): `GameController`, `PlayerEntity`,
  `OOJavaScriptEngine`, `ShipRegistry`, `AsyncWorkManager`, `GraphicsResetManager`,
  `OpenGLExtensionManager`, `MusicController`, `OpenALController`, `SoundMixer`, `JoystickManager`,
  `OXZManager`, `DebugMonitor`, `NullTexture` and `SpeechSynthesizer::shared()`.
- `GameController::startHeadless` (`GameController.cpp:640`) refuses to start when a universe
  exists: "a headless game is one per process".

The full inventory is [global-state/2026-11-15-catalogue.md](../global-state/2026-11-15-catalogue.md).

The fix is **plain constructor injection with one composition root**. One function builds every
service in dependency order and hands each class the services it uses. Tests call the same
function with fakes substituted. There is no DI library and no lookup by type.

## Done checks

Every stage also needs `./mk.sh build dev`, `tests/run.sh unit` and `tests/run.sh component --cpp`
to pass with no test edited.

| Stage | Command (from `oolite-dev`) | Fails before because |
|---|---|---|
| 1 | `meson test -C build/meson_dev fake_speech_records_speech` | the test doesn't exist |
| 2 | `meson test -C build/meson_dev two_headless_games_in_turn` | the second `startHeadless` raises "one per process" |
| 3 to 5 | `tools/count-bridge-uses.sh --check` | a ceiling in `tests/global-state/bridge-ceilings.txt` is exceeded |

## Design

### The composition root

- **`oo::GameServices`** in `src/Core/GameServices.h` is a class whose members are the services of
  one game, declared in construction order. C++ destroys members in reverse declaration order, so
  teardown order is the declaration order read backwards, and it is visible in one place.
- **Ownership.** A member is a `std::shared_ptr` made with `oo::makeShared` when anything else holds
  a `weak_ptr` to it (the universe, the player, entities). Otherwise it is a `std::unique_ptr`.
  Accessors return references.
- **Building it.** `oo::BuildGameServices(const OOHeadlessOptions&, GameServiceOverrides)` lives in
  `src/Core/CompositionRoot.cpp`. `GameServiceOverrides` is a struct of `std::shared_ptr`s, empty by
  default. A member that is set replaces the real service, for example
  `overrides.speech = oo::makeShared<FakeSpeech>()`.
- **Who owns the root.** `GameController` holds a `std::unique_ptr<oo::GameServices>`. It builds the
  root in the windowed start and in `startHeadless`, and frees it when the game ends.
  `oo_component.cpp`'s `Game::start` passes overrides through.

### Rule for code that uses a service

1. A class takes the services it uses as constructor parameters and keeps them as members, for
   example `Foo(Universe& universe, oo::Speech& speech)`. It never takes the whole
   `GameServices`.
2. Only the composition root, factories and the QuickJS boundary see `GameServices`.
3. New code never uses `UNIVERSE`, `PLAYER` or a `shared…()` accessor.
4. An existing class converts when a stage or another task touches it. Its constructor gains the
   parameters, its body uses the members, and its `UNIVERSE` uses inside the class go away.

### The bridge, while the migration runs

There are 2,402 `UNIVERSE` lines, and 84 test files assign `gSharedUniverse` or `gOOPlayer`
themselves. So the globals stay, with a new meaning: they point at the services of the game that
is running.

- `gSharedUniverse` is already set by the `Universe` constructor and cleared by its destructor
  (`Universe.cpp:310`, `:465`). That doesn't change.
- `oo::GameServices::live()` returns the live root, or `nullptr` when none exists. It is the
  bridge's one new global.
- A `shared…()` accessor whose service has moved into the root returns the live root's member when
  a root exists. When none exists, it creates the service lazily as it does today. 101 test files
  call these accessors, and that fallback keeps every one of them unedited.
- `tools/count-bridge-uses.sh` counts `UNIVERSE`, `PLAYER`, `shared…()` and
  `GameServices::live()` in `src/`. With `--check`, it fails when a count is above its ceiling in
  `tests/global-state/bridge-ceilings.txt`. A stage that converts uses lowers the ceilings in the
  same commit.

### QuickJS native callbacks

A callback's signature is fixed, so it can't take constructor parameters. The engine stores the
root with `JS_SetContextOpaque(cx, &services)`, which nothing calls today. Callbacks read it through
`oo::ServicesFor(JSContext*)`, an inline helper in `Core/Scripting/OOJSEngineCore.h` over
`JS_GetContextOpaque`. This is the one place where a lookup is the design, not a bridge.

### Entities

Ships come from `shipdata` through `ShipRegistry` and `Universe`'s `newShip…` factories, and some
come from scripts. Each factory already has the universe, and it passes it to the entities it
builds. Entities aren't converted until stage 5.

## Steps

1. **Root and the first fake (speech).**
   - Add the `oo::Speech` interface (`Speech.h`) with `SpeechSynthesizer`'s public API: `speak`,
     `stop`, `isSpeaking`, `setVolume`, and the voice functions. `SpeechSynthesizer` implements it.
   - Add `GameServices`, `BuildGameServices` and `GameServiceOverrides`, holding only `speech`.
   - Convert the 14 `SpeechSynthesizer::shared()` callers (`Universe.cpp`, `PlayerEntityControls.cpp`,
     `MyOpenGLView.cpp`). `Universe` gets `oo::Speech&` in its constructor. `newUniverse` keeps
     its current signature as an overload that passes `SpeechSynthesizer::shared()`.
   - `SpeechSynthesizer::shared()` follows the bridge rule.
   - Add `tests/component-cpp/test_fake_speech.cpp`. It runs a headless game with a recording
     `FakeSpeech`, triggers a spoken message and asserts the recorded text.
2. **Two games in one process, one after the other.**
   - `startHeadless`'s check becomes "a game is already running".
   - Ending a headless game frees its root and its universe.
   - The player, today a never-freed static holder (`gOOPlayerHolder`, `PlayerEntity.cpp:438`),
     becomes a root member. `PlayerEntity::sharedPlayer()` follows the bridge rule.
   - The JS engine becomes a root member. Class IDs stay process-wide, because QuickJS-ng allocates
     them per runtime.
   - Add `test_two_headless_games.cpp`. It runs two seeds in turn and asserts that each game sees
     only its own ships.
   - Run the asan build on the new test. Changing the shutdown order is where use-after-free bugs
     will show up.
3. **The remaining per-game singletons move into the root**, one commit each, with the bridge
   fallback: `ShipRegistry`, `AsyncWorkManager`, `MusicController`, `OpenALController`,
   `SoundMixer`, `JoystickManager`, `OXZManager`, `DebugMonitor`.
   `OpenGLExtensionManager`, `GraphicsResetManager` and `NullTexture` stay process-wide (GL is
   per process), and are recorded as kept.
4. **Fakes for the presentation services** a component test wants to control: sound (`SoundMixer`
   behind an interface) and joystick or input. `OOGameClock` is already injectable through
   `OOHeadlessOptions`.
5. **Convert classes to constructor injection, in order of `UNIVERSE` count.** Work through
   `count-bridge-uses.sh`'s per-file report, lowering the ceilings each time. The JS callbacks move
   to `oo::ServicesFor(cx)`.

## Test-change ledger

None for steps 1 to 5. Every existing test compiles and passes unedited, because of the bridge.

Deleting the bridge (`gSharedUniverse`, `gOOPlayer`, the `shared…()` fallbacks) would edit the 84
and 101 test files above. That needs Jon's sign-off and its own ledger, so it isn't in this plan.

## Decisions

- **Plain injection, not a type-keyed context.** A `get<T>()` locator hides what a class depends on
  and fails only at runtime. Named members plus constructor parameters are checked by the compiler
  and show the teardown order. This replaces spec 003's R1/R2 `OOGameContext::get<T>()` with named
  members, and keeps its register idea as the bridge.
- **No DI library.** About 15 services fit in one hand-written function.
- **Keep the globals as a bridge.** This is the conservative default: no test edits, the cost of
  each `UNIVERSE` use doesn't change, and stages land one at a time. The ratchet stops new uses.
- **Upstream shape.** Public method names stay. Injected parameters arrive through new constructor
  overloads, so the old signatures remain for upstream merges and for tests.
- **Names.** `oo::GameServices`, `oo::Speech`, `oo::BuildGameServices` and `oo::ServicesFor` live
  in `namespace oo`, with no `OO` prefix.
- **Main thread only.** `GameServices::live()` is a plain global, not `thread_local`. MinGW's
  emulated TLS would make every access a function call.

## Alternatives considered

- **Type-keyed service locator** (`ctx.get<T>()`, spec 003 R2). It is simple, and an `IsService<T>`
  trait can make an unregistered type a compile error. But it can't check that a slot is filled,
  every class can reach every service, and the dependencies aren't visible in constructors.
  Rejected for the reasons above.
- **[Boost.DI](https://github.com/boost-ext/di)** (header-only, not part of Boost). It reads
  constructor parameter types by trying to construct `T` with an `any_type` that has a templated
  conversion operator, then resolves each parameter from `di::bind<I>.to<Impl>()`. That would save
  writing the root by hand. Against it:
  - ambiguous, template or variadic constructors need `BOOST_DI_INJECT`;
  - only unbound interfaces fail to compile, while concrete types are always built;
  - entities built from runtime data (`shipdata` keys) still need hand-written factories;
  - template-heavy builds and errors;
  - one maintainer.
  It adds little for about 15 services.
- **[Google Fruit](https://github.com/google/fruit).** It checks at compile time that every
  dependency is bound and that there are no cycles, through `fruit::Component<Required<…>, …>`
  types. Against it:
  - every injectable constructor needs `INJECT(...)` or `registerConstructor`, so it spreads into
    `Universe`, `PlayerEntity` and the entities;
  - `replace(...).with(...)`, which is how tests would swap in fakes, and some conflicts between
    combined components are resolved at runtime;
  - heavy templates, a slow release pace.
  Writing the root by hand gives the same order checking through member declaration order.
- **Constructor injection everywhere first, no bridge.** This is the same end state, but it would
  be one change of more than 2,400 lines before any test benefits, and it would edit 84 or more
  test files.
- **Keep the singletons and add `resetForTesting()`.** That gives neither fakes nor two games.

## Out of scope

- Splitting `OOGame` from `GameController` (spec 003 R3).
- Removing the bridge (see the ledger).
- Running two games at the same time on different threads.
- The input latches in `PlayerEntityControls.cpp` (84 globals). They stay, for upstream merges.

Follow-up: bring spec 003's `research.md` R1/R2 in line with this plan, or mark this plan as
superseding them.
