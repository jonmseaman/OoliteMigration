# Data model: Encapsulate the game's global state

These are the entities from the spec, as the plan builds them on spec 009's base. The C++ shapes
are in [contracts/game-context.md](contracts/game-context.md) and
[contracts/headless-scenario.md](contracts/headless-scenario.md). The file formats are in
[contracts/global-state-check.md](contracts/global-state-check.md).

## OOGameContext

The root that owns one game's services ([research R1, R2](research.md)).

| Field | Meaning |
|---|---|
| hot services | `universe`, `player`, `game`: direct members, borrowed from `OOGame` |
| service slots | ordered `(std::type_index, std::shared_ptr<void>)`; registration order is kept |
| saved registers | this context's value of each register while it is not current |
| options | `OOGameContextOptions`: headless flag, seed, JS time limit |

**Rules:**
- **One registration per type.** `set<T>()` on a type already present replaces it in its
  original slot, so teardown order doesn't change.
- **Missing service.** `get<T>()` raises `OOMissingServiceException("<demangled T>")` (FR-004).
  `obtain<T>()` creates the service only in the process context.
- **Universe and player.** Replaced only through `OOGame` (new game, load, reset), which updates
  the hot members before the old object is released (FR-010).
- **Who may keep what.** An object outside the universe may hold `OOGameContext&`, but never a
  raw `Universe*`/`PlayerEntity*` or a `std::shared_ptr` to either: a shared one would keep a
  replaced universe alive. Objects owned by the universe (entities) may hold the raw pointer,
  because they die with it.
- **Teardown.** The process context is never destroyed. Any other context releases its slots in
  reverse registration order; after that the hot members are null.

**Kinds:** the **process context** (one, never destroyed: the GUI game and every existing test
that opens no scope) and **owned contexts** (made by a test or headless game, destroyed by it).

**Lifecycle:** *created* → *services registered* → *current* (inside an `OOGameContextScope`, its
values in the registers) ⇄ *not current* (its values saved) → *destroyed* (owned contexts only).
At most one context is current at a time, on the main thread; with no scope open, the process
context is current.

## Register

A pointer-sized global whose value belongs to the current context ([R1](research.md)). Listed in
one table in `OOGameContext.cpp`.

| Register | From | Holds |
|---|---|---|
| `gSharedUniverse` | M1 | the current context's universe |
| `gOOPlayer` | M1 | the current context's player |
| `gOOJSMainThreadContext` | M2 | the current context's `JSContext*` |
| `gOOJSPlayerIfStale` | M2 | the script layer's stale-player marker |

Each register is an inventory row with owner `bridge` and status `todo` until M6b.

## OOGame

The simulation and its lifecycle, on one context ([R3](research.md)).

| Field | Meaning |
|---|---|
| context | the `OOGameContext` it runs in (the process context in the GUI) |
| universe | `std::shared_ptr<Universe>`, from `oo::makeShared` |
| player | `EntityHold` |

**States:** *constructed* → *universe ready* (built with `OOUniverseOptions`) → *player ready* →
*running* (`simulate(dt)` may be called) → *destroyed*. A new game, load or reset goes from
*running* back to *universe ready*.

## GameController (after the split)

The GUI shell. It owns the window and drives the process context's `OOGame`.

| Field | Meaning |
|---|---|
| game | the `OOGame` it drives |
| tick schedule | was `sGameTickScheduled`, `sNextGameTick`, `sGameTickInterval` |
| progress message stack | was `sMessageStack` (OO_DEBUG only) |

## Services

Each service has one owner (a context) and any number of dependants. It is **simulation** or
**presentation**; a presentation service has a headless stand-in.

| Service | Today (on 009's base) | Kind | Headless stand-in |
|---|---|---|---|
| `Universe` | `gSharedUniverse` | simulation (hot) | real |
| `PlayerEntity` | `gOOPlayer`, `sharedPlayer()` | simulation (hot) | real, in flight, no controls ([R7](research.md)) |
| `OOGame` | (new) | simulation (hot) | real |
| `OODeferredCalls` | `sDeferredCalls`, `sLastDeferredCallException` | simulation | real |
| `GameController` | `sSharedController` | presentation | absent (`find` returns null) |
| `OORandomState` | `sRANROT`, `sReallyRandom*` | simulation | real, seeded from the context options |
| `OOClock` | `oo::date` monotonic calls | simulation | `OOManualClock` |
| `OOShipRegistry` | `sharedRegistry()` | simulation | real |
| `OOCacheManager` | `sharedCache()` | simulation | real, in memory only (no cache file) |
| `OOJavaScriptEngine` | `sharedEngine()`, `gOOJSMainThreadContext` | simulation | real, one per context; time limit from the options |
| `OOAsyncWorkManager` | `sharedAsyncWorkManager()` | simulation | real; destructor calls `shutdown()` ([R14](research.md)) |
| `OOOpenGLExtensionManager` → graphics | `sharedManager()` | presentation | `OOHeadlessGraphics` |
| `OOGraphicsResetManager` | `sharedManager()` | presentation | real (nothing registers) |
| texture loading | `OOTextureLoader` statics | presentation | does not decode |
| `OOSoundMixer` / `OOOpenALController` / `OOMusicController` | `shared…()` | presentation | null mixer: `play` is a no-op |
| `OOJoystickManager` / input | `sharedStickHandler()` | presentation | reports no input |
| `OOOXZManager` | `sharedManager()` | presentation | absent |
| `OODebugMonitor` | `sharedDebugMonitor()` | presentation | absent |
| `OONullTexture` | `sharedNullTexture()` | constant once initialised | shared |

The full list is the inventory, not this table. Rows it finds that are not listed here are added
with an owner.

## Inventory entry

One row of `tests/global-state/inventory.tsv` ([R9](research.md)).

| Field | Values |
|---|---|
| `symbol` | the demangled name, as `llvm-nm` prints it |
| `object` | the source path the object was built from, relative to `src/` |
| `category` | `session` · `subsystem` · `presentation` · `cache` · `constant-once` · `process-kept` |
| `owner` | the class or subsystem that will own it (`OOGame`, `GameController`, `OORandomState`, `bridge`, …) |
| `headless` | `yes` if the headless game needs it, else `no` |
| `status` | `todo` · `encapsulated` · `kept` |
| `reason` | required when the status is `kept` or the category is `process-kept`; one of the FR-012 reasons, plus a sentence |

**Status transitions:**
- `todo` → `encapsulated`, once the symbol is gone from the objects and the row is updated in
  the same commit;
- `todo` → `kept`, once a reason is written.

An `encapsulated` row stays as a record. The check fails if a row marked `encapsulated` names a
symbol that is still present.

## Ratchet

`tests/global-state/ratchet.json` ([R10](research.md)) holds ceilings, a total and one per
directory, for each tracked token, counted in `src/` only. A stage lowers its ceilings, then
removes uses until the counts meet them. A ceiling only ever goes down.

## Test-change ledger row

`test-ledger.md` in this directory, created at M6a with the one row M6b needs
([R15](research.md)), in spec 009's ledger format: test files, lines, forced by (the bridge's
deletion: `gSharedUniverse`/`gOOPlayer` assignments, `UNIVERSE`/`PLAYER`, `shared…()` calls),
assertions (`unchanged`), coverage (`needs sign-off`), commit, signed.

## Stage

A unit of mergeable work: one or more tasks on the feature branch. It records the inventory rows
it moves, the ratchet ceilings it lowers, and its acceptance command. Stages are listed in
[plan.md](plan.md#milestones).
