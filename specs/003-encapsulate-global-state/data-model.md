# Data model: Encapsulate the game's global state

These are the entities from the spec, as the plan builds them. The C++ shapes are in
[contracts/game-context.md](contracts/game-context.md) and
[contracts/headless-scenario.md](contracts/headless-scenario.md). The file formats are in
[contracts/global-state-check.md](contracts/global-state-check.md).

## OOGameContext

The root that owns one game's services ([research R1, R2](research.md)).

| Field | Meaning |
|---|---|
| hot services | `universe`, `player`, `game`: direct members, borrowed from their owners |
| service slots | ordered `(std::type_index, oo::Ref<oo::RefCounted>)`; registration order is kept |
| options | `OOGameContextOptions`: headless flag, seed, JS time limit |

**Rules:**
- **One registration per type.** `set<T>()` on a type already present replaces it in its
  original slot, so teardown order doesn't change.
- **Missing service.** `get<T>()` on a type that isn't registered raises
  `OOMissingServiceException("<demangled T>")` (FR-004).
- **Universe and player.** These are replaced only through `OOGame` (new game, load, reset), which
  updates the hot members before the old object is released (FR-010).
- **Who may keep a raw pointer.** An object outside the universe may hold `OOGameContext*`, but
  never a raw `Universe*` or `PlayerEntity*`. Objects owned by the universe (entities) may hold
  it, because they die with it.
- **Teardown.** Destruction releases the slots in reverse registration order. After that the
  hot members are null.

**Lifecycle:** *created* → *services registered* → *current* (inside an `OOGameContextScope`) ⇄
*not current* → *destroyed*. At most one context is current at a time, and only on the main
thread.

## OOGame

The simulation and its lifecycle. It owns one `OOGameContext` ([R3](research.md)).

| Field | Meaning |
|---|---|
| context | the `OOGameContext` it owns |
| deferred calls | the queue (was `sDeferredCalls` in `GameController.cpp`), ordered by deadline on the context's clock |
| last deferred-call exception | was `sLastDeferredCallException` |

**States:** *constructed* → *universe ready* (`Universe` built with `OOUniverseOptions`) →
*player ready* → *running* (`simulate(dt)` may be called) → *destroyed*. A new game, load or reset
goes from *running* back to *universe ready*.

## GameController (after the split)

The GUI shell. It owns an `OOGame` and the window.

| Field | Meaning |
|---|---|
| game | the `OOGame` it owns |
| tick schedule | was `sGameTickScheduled`, `sNextGameTick`, `sGameTickInterval` |
| progress message stack | was `sMessageStack` (OO_DEBUG only) |

## Services

Each service has one owner (the context) and any number of dependants. It is categorised as
**simulation** or **presentation**. A presentation service has a headless stand-in.

| Service | Today | Kind | Headless stand-in |
|---|---|---|---|
| `Universe` | `gSharedUniverse` | simulation (hot) | real |
| `PlayerEntity` | `gOOPlayer` | simulation (hot) | real, in flight, no controls ([R7](research.md)) |
| `OOGame` | (new) | simulation (hot) | real |
| `GameController` | `sSharedController` | presentation | absent (`find` returns null) |
| `OORandomState` | `sRANROT`, `sReallyRandom*` | simulation | real, seeded from the context options |
| `OOClock` | `oo::date::monotonicSeconds()` calls | simulation | `OOManualClock` |
| `OOShipRegistry` | `sharedRegistry()` | simulation | real |
| `OOJavaScriptEngine` | `sharedEngine()` | simulation | real; time limit from the options |
| `OOAsyncWorkManager` | `sharedAsyncWorkManager()` | simulation | real (manual-dispatch subclass) |
| `OOOpenGLExtensionManager` → graphics | `sharedManager()` | presentation | `OOHeadlessGraphics` |
| `OOGraphicsResetManager` | `sharedManager()` | presentation | real (nothing registers) |
| texture loading | `OOTextureLoader` statics | presentation | does not decode |
| `OOSoundMixer` / `OOOpenALController` / `OOMusicController` | `shared…()` | presentation | null mixer: `play` is a no-op |
| `OOJoystickManager` / input | `sharedStickHandler()` | presentation | reports no input |
| `OOOXZManager` | `sharedManager()` | presentation | absent |
| `OODebugMonitor` | `sharedDebugMonitor()` | presentation | absent |
| `OONullTexture` | `sharedNullTexture()` | constant once initialised | shared |

The full list is the inventory, not this table. Rows the inventory finds that are not listed
here are added to it with an owner.

## Inventory entry

One row of `tests/global-state/inventory.tsv` ([R9](research.md)).

| Field | Values |
|---|---|
| `symbol` | the demangled name, as `llvm-nm` prints it |
| `object` | the source path the object was built from, relative to `src/` |
| `category` | `session` · `subsystem` · `presentation` · `cache` · `constant-once` · `process-kept` |
| `owner` | the class or subsystem that will own it (`OOGame`, `GameController`, `OORandomState`, …) |
| `headless` | `yes` if the headless game needs it, else `no` |
| `status` | `todo` · `encapsulated` · `kept` |
| `reason` | required when the status is `kept` or the category is `process-kept`; one of the FR-012 reasons, plus a sentence |

**Status transitions:**
- `todo` → `encapsulated`, once the symbol is gone from the objects and the row is updated in
  the same commit;
- `todo` → `kept`, once a reason is written.

An `encapsulated` row stays in the file as a record. The check fails if a row marked
`encapsulated` names a symbol that is still present.

## Ratchet

`tests/global-state/ratchet.json` ([R10](research.md)) holds ceilings: a total and one per
directory, for each tracked token. A stage lowers its ceilings, then removes uses until the
counts meet them. A ceiling only ever goes down.

## Stage

A unit of mergeable work: one or more beads on the epic branch. It records:
- the inventory rows it moves;
- the ratchet ceilings it lowers;
- its acceptance command.

Stages are listed in [plan.md](plan.md#milestones).
