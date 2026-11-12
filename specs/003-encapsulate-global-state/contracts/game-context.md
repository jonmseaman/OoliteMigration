# Contract: `OOGameContext`, the registers, `OOGame` and script access

New files in `oolite-dev/src/Core/`: `OOGameContext.h/.cpp`, `OOGame.h/.cpp` and
`OODeferredCalls.h/.cpp`. They follow the style of `Core/OOColor.*` as spec 009 left it:
- a GPL banner with a one-line description, then `#pragma once`;
- `OO`-prefixed classes in the global namespace;
- spec 009's ownership: `std::shared_ptr`/`std::weak_ptr`/`std::unique_ptr`, shared game objects
  from `oo::makeShared`; camelCase methods;
- Google formatting (clang-format 22).

The signatures below are the interface. Their bodies belong to the tasks. Research: R1, R2, R3,
R8, R14.

## OOGameContext

```cpp
struct OOGameContextOptions {
  bool headless = false;
  std::optional<uint64_t> seed;          // nullopt: seed from the wall clock, as today
  double jsTimeLimitSeconds = 0;         // 0: the engine's built-in default
};

class OOGameContext {
 public:
  explicit OOGameContext(OOGameContextOptions options = {});
  ~OOGameContext();                      // releases slots in reverse registration order
  OOGameContext(const OOGameContext&) = delete;
  OOGameContext& operator=(const OOGameContext&) = delete;

  const OOGameContextOptions& options() const;

  // The three hot services: direct, no lookup. Borrowed; OOGame keeps them current. While this
  // context is current they read the registers, otherwise its own saved values.
  Universe* universe() const;
  PlayerEntity* player() const;
  OOGame* game() const;

  // Every other service, looked up by type.
  template <class T> T& get() const;     // raises OOMissingServiceException naming T
  template <class T> T* find() const;    // nullptr when absent
  template <class T> T& obtain();        // get(); in the process context, creates T if absent
  template <class T> void set(std::shared_ptr<T> service);  // adds, or replaces in place

  // The bridge (removed in M6b). Main thread only.
  static OOGameContext& process();       // never destroyed; the GUI game and existing tests
  static OOGameContext& current();       // innermost scope's context, else process()
  bool isCurrent() const;
};

class OOGameContextScope {               // RAII: makes ctx current, restores the previous one
 public:
  explicit OOGameContextScope(OOGameContext& ctx);
  ~OOGameContextScope();
};

class OOMissingServiceException;         // what(): "no <TypeName> service in this game context"
```

Rules:
- **The header stays small, to keep compiles fast.**
  - `OOGameContext.h` includes only `<memory>`, `<typeindex>`, `<typeinfo>`, `<vector>`,
    `<optional>` and `<cstdint>`.
  - It forward-declares `Universe`, `PlayerEntity` and `OOGame`, and includes no service header.
    Adding a service never edits this file.
  - No per-service accessors beyond the three hot members; `T` is complete only where
    `get<T>()` is called.
  - Enforced by `test_OOGameContext`, which checks the header's `#include` list against this
    allow-list.
- **Slots** hold `std::shared_ptr<void>` keyed by `std::type_index(typeid(T))`. A service needs no
  common base. An `oo::Object` made with `oo::makeShared` keeps its `oo::Dispose` deleter.
- **`obtain<T>()`** creates only in the process context. In any other context a missing service
  raises, so a test's context never builds a real window, mixer or engine by accident (FR-004).
- **Universe and player are not slots.** `OOGame` owns them (`std::shared_ptr<Universe>`,
  `EntityHold` for the player) and updates the hot members; the old one is released only after
  the new one is in place (FR-010).
- **Teardown.** The process context is never destroyed. Any other context, on destruction,
  releases its slots newest first; each service it held must have a working destructor (R14).
  Destroying a context that is current is a programming error and asserts.

## The registers (until M6b)

```cpp
// Universe.h and PlayerEntity.h: unchanged readers.
OOINLINE Universe* OOGetUniverse() { return gSharedUniverse; }
#define UNIVERSE OOGetUniverse()
// OOGetPlayer() the same way over gOOPlayer, keeping its OO_DEBUG assert.
```

- A **register** is a pointer-sized global whose value belongs to the current context.
  `gSharedUniverse` and `gOOPlayer` are registers from M1; `gOOJSMainThreadContext` and
  `gOOJSPlayerIfStale` from M2. Others join only when the inventory shows a many-reader global
  the headless game needs per game.
- All registers are listed in one table in `OOGameContext.cpp`. Each context has a saved value
  per register (null for a new context).
- **Entering a scope** for `ctx`, when `ctx` is not already current: save every register into
  the outgoing context, load `ctx`'s saved values, make `ctx` current. **Leaving** does the
  reverse. Nesting the same context is a no-op.
- So `UNIVERSE` and `PLAYER` cost what they cost today, tests that assign `gSharedUniverse` /
  `gOOPlayer` (81 files) act on the process context as before, and `Universe::newUniverse`'s
  one-universe check holds per context.
- **Scopes are opened per call, never held by an object.** Every `OOGame` entry point
  (`startUniverse`, `replaceUniverse`, `simulate`) opens a scope for its own context for the
  length of the call. The GUI game runs in the process context and needs no scope.
  `test_OOGameContext` covers nesting, the register swap, restoring after an exception, and two
  games driven in turn.

M6b deletes the macros, `OOGetUniverse`/`OOGetPlayer`, the registers, `current()` and
`process()`, once Jon has signed the test-ledger row (research R15).

## Singletons through the context

```cpp
// was: static auto& sShared = *new std::shared_ptr<OOShipRegistry>(...) (spec 009)
OOShipRegistry* OOShipRegistry::sharedRegistry() {
  return &OOGameContext::current().obtain<OOShipRegistry>();
}
```

The accessor's name and observable behaviour stay; its never-deleted static and its spec 009
`exceptions.md` row go. A test or headless game that wants a stand-in calls `set<T>()` on its
own context before first use.

## OOGame

```cpp
struct OOUniverseOptions {               // the defaults are today's behaviour
  std::string addOns = SCENARIO_OXP_DEFINITION_ALL;
  bool populate = true;
  bool runWorldScripts = true;
  std::optional<OOGraphicsDetail> detailLevel;   // nullopt: from user defaults
};

class OOGame : public oo::Object {
 public:
  explicit OOGame(OOGameContext& context);   // the GUI passes OOGameContext::process()
  OOGameContext& context();

  // Lifecycle
  void startUniverse(MyOpenGLView* view, const OOUniverseOptions& options = {});  // view may be null
  void replaceUniverse(...);             // new game, load and reset go through here (FR-010)

  // One simulation frame: universe update, sound update, frame callbacks, then the deferred
  // calls due by the context's clock. It does not draw.
  void simulate(OOTimeDelta dt);
};
```

A headless test owns its context (`std::unique_ptr<OOGameContext>`) and an `OOGame` made with
`oo::makeShared`, destroying the game before the context.

`GameController::doPerformGameTick` becomes three steps: measure dt; `game().simulate(dt)`;
`_gameView->updateScreen()`.

## Deferred calls

```cpp
class OODeferredCalls {                  // a context service; was GameController.cpp's statics
 public:
  void schedule(OOTimeDelta delay, std::function<void()> call);
  void runDue(double now);               // called by OOGame::simulate
};

// Unchanged free function: schedules on OOGameContext::current().obtain<OODeferredCalls>().
void OOScheduleDeferredCall(...);
```

## Script callbacks

```cpp
// Core/Scripting/OOJSEngineCore.h
inline OOGameContext& OOJSGameContext(JSContext* cx) {
  return *static_cast<OOGameContext*>(JS_GetContextOpaque(cx));
}
```

Each context's engine calls `JS_SetContextOpaque(cx, &context)` once, when it creates its
`JSContext`. Callbacks converted in M5 call `OOJSGameContext(cx).universe()` in place of
`UNIVERSE`.

## Headless stand-ins (in `src/Core`, compiled into the game)

They live in the game's own sources, so headless is a mode of the real program and a future
`--headless` flag could use them:
- `OOHeadlessGraphics` (`available() == false`);
- `OOManualClock`;
- the null sound mixer;
- the no-input handler;
- the non-decoding texture loader.
