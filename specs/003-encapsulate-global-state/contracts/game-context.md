# Contract: `OOGameContext`, `OOGame` and the migration bridge

New files in `oolite-dev/src/Core/`: `OOGameContext.h/.cpp` and `OOGame.h/.cpp`. They follow the
style of `Core/OOColor.*`:
- a GPL banner with a one-line description, then `#pragma once`;
- `OO`-prefixed classes in the global namespace;
- `oo::Ref` ownership and camelCase methods;
- Google formatting.

The signatures below are the interface. Their bodies belong to the tasks.

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
  ~OOGameContext();                      // releases services in reverse registration order
  OOGameContext(const OOGameContext&) = delete;
  OOGameContext& operator=(const OOGameContext&) = delete;

  const OOGameContextOptions& options() const;

  // The three hot services: direct, no lookup. They are borrowed; OOGame keeps them current.
  Universe* universe() const;
  PlayerEntity* player() const;
  OOGame* game() const;

  // Every other service, looked up by type.
  template <class T> T& get() const;     // raises OOMissingServiceException naming T
  template <class T> T* find() const;    // nullptr when absent
  template <class T> void set(oo::Ref<T> service);  // adds the service, or replaces it in place

  // The bridge (removed in M6). Main thread only.
  static OOGameContext* current();
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
  - `OOGameContext.h` includes only `oofnd/Ref.hpp`, `<typeindex>`, `<vector>`, `<optional>` and
    `<cstdint>`.
  - It forward-declares `Universe`, `PlayerEntity` and `OOGame`, and includes no service header.
  - Adding a service never edits this file.
  - There are no per-service accessors beyond the three hot members. Every other service uses
    `get<T>()`, so `T` has to be complete only where it is called.
  - Enforced by `test_OOGameContext`, which checks the header's `#include` list against this
    allow-list.
- A `T` passed to `set` derives from `oo::RefCounted`, which is enforced with a `static_assert`.
- Universe and player are not registered through `set`. `OOGame` owns them and updates the hot
  members.
- `current()` returns the context of the innermost live `OOGameContextScope`, or `nullptr`.
- **Scopes are opened per call, never held by an object.**
  - Every `OOGame` entry point (`startUniverse`, `replaceUniverse`, `simulate`,
    `scheduleDeferredCall`) opens a scope for its own context for the length of the call, so
    callers never manage scopes.
  - The one long-lived scope is in `main`, around the GUI run.
  - An object that kept a scope for its whole lifetime would leave its context current while
    another game is being driven. Its scope would also be restored in the wrong order whenever
    such objects are not destroyed last-created-first. `test_OOGameContext` covers nesting,
    restoring after an exception, and two games driven in turn.

## The bridge macros (until M6)

```cpp
// Universe.h
OOINLINE Universe* OOGetUniverse() { return OOGameContext::current()->universe(); }
#define UNIVERSE OOGetUniverse()
// PlayerEntity.h: OOGetPlayer() the same way, keeping its OO_DEBUG assert.
```

Behaviour must not change. In the GUI program the context is current for the whole run, set up
in `main` before `GameController` starts. M6 deletes both macros, `OOGetUniverse`,
`OOGetPlayer` and `current()`.

## OOGame

```cpp
struct OOUniverseOptions {               // the defaults are today's behaviour
  int addOns = SCENARIO_OXP_DEFINITION_ALL;
  bool populate = true;
  bool runWorldScripts = true;
  std::optional<OOGraphicsDetail> detailLevel;   // nullopt: from user defaults
};

class OOGame : public oo::RefCounted {
 public:
  explicit OOGame(OOGameContextOptions options = {});
  OOGameContext& context();

  // Lifecycle
  void startUniverse(MyOpenGLView* view, const OOUniverseOptions& options = {});  // view may be null
  void replaceUniverse(...);             // new game, load and reset go through here (FR-010)

  // One simulation frame: universe update, sound update, frame callbacks, then the deferred
  // calls due by the context's clock. It does not draw.
  void simulate(OOTimeDelta dt);

  // Was the free function OOScheduleDeferredCall.
  void scheduleDeferredCall(OOTimeDelta delay, std::function<void()> call);
};
```

`GameController::doPerformGameTick` becomes three steps:
1. measure dt;
2. `game().simulate(dt)`;
3. `_gameView->updateScreen()`.

## Script callbacks

```cpp
// Core/Scripting/OOJSEngineCore.h
inline OOGameContext& OOJSGameContext(ooscript::Context cx);  // from ooscript::getContextPrivate
```

Each context's engine sets the private slot once, when the context is created. Callbacks that are
converted (M5) call `OOJSGameContext(cx).universe()` in place of `UNIVERSE`.

## Headless stand-ins (in `src/Core`, compiled into the game)

The stand-ins live in the game's own sources, not only in `tests/`. That keeps "headless" a mode
of the real program, and a future `--headless` command-line flag could use them. They are:
- `OOHeadlessGraphics` (`available() == false`);
- `OOManualClock`;
- the null sound mixer;
- the no-input handler;
- the non-decoding texture loader.
