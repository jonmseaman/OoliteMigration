# Global state catalogue (2026-11-15)

Every global variable in `oolite-dev/src`. The aim is to get rid of global state so the game can be
tested without its process-wide singletons. The work it feeds is spec 003,
[`specs/003-encapsulate-global-state`](../../specs/003-encapsulate-global-state/spec.md). This
catalogue is the inventory its R9 describes but no one has built yet (`tests/global-state/inventory.tsv`
doesn't exist).

**Full list:** [2026-11-15-globals.tsv](2026-11-15-globals.tsv), one row per variable, with
columns `area`, `file`, `kind`, `role` and `symbol`.

## How it was found

The list comes from spec 003's R9 method, which reads the compiler's output rather than the source:
- `llvm-nm --defined-only --demangle` over every object of the `oolite` target in
  `build/meson_dev`, the dev build of `oolite-dev` `df5869f9d` plus the working tree's uncommitted
  changes;
- keeping symbols in writable data sections (`b B d D`).

That catches namespace-scope globals, `static` file-locals, class statics and function-local
statics, including the ones macros create. It drops guard variables, vtables and typeinfo, and the
vendored code (MiniZip, EXR, miniz, stb). A variable defined in a header shows up in every object
that includes it, so it is listed once.

Each symbol has a **kind** (where it lives) and a **role** (what it is for). The role is a
heuristic from names and declarations, so check it before relying on it.

**What this misses:**
- code compiled only on Linux or macOS, because only the Windows dev build was read;
- `const` and `constexpr` globals in read-only sections. Those aren't state;
- variables the optimiser removed;
- `tests/`, QuickJS-ng and `third_party/`.

To redo it, run the `llvm-nm` loop over `build/meson_dev/src/oolite.exe.p/*.obj`. The scripts are
`.agent-tmp/globals.py` and `globals2.py` (scratch, not committed).

## Totals: 740 globals in 128 files

**By kind**

| Kind | Count |
|---|---:|
| function-local `static` | 375 |
| file-local (`static` or an anonymous namespace) | 265 |
| external (an `extern` global or a class static) | 95 |
| header-defined (`inline`) variable | 5 |

**By role**

| Role | Count | What it is | Matters for testing? |
|---|---:|---|---|
| mutable state | 277 | Real state that changes during a game: timers, saved chart positions, the music being played, "loaded" flags, recursion limiters | **Yes**, the main target |
| JS atom cache | 160 | The interned `JSAtom` behind each `OOJSID(...)`/`OOJSSTR(...)` use (`…::idCache`). Spread across about 60 functions | Per JS runtime: wrong if two engines exist. The idiom plan's I6 turns these into functions; the cache could live on the engine |
| input/controls latch | 84 | `PlayerEntityControls.cpp`'s file-scope `…_pressed` flags. Upstream has the same | **Yes** for input tests. Decided to stay for now (upstream merges) |
| GL function pointers | 65 | Extension entry points loaded at start-up (`OOOpenGLExtensionManager.cpp`) | Process-wide by nature; keep |
| JS class / prototype handles | 58 | Each `OOJS*.cpp`'s class ID and prototype objects | Per JS runtime, the same issue as the atoms |
| lookup tables (built once) | 30 | Enum-to-JS-string tables (`gOO…ConstTable`) and the legacy-script whitelists | Constant after start-up; low priority |
| singletons / shared accessors | 25 | `sharedX()` holders, listed below | **Yes**, the hardest to fake |
| run-time-initialised constants | 17 | `static const` values computed at start-up (e.g. `ShipEntity.cpp`'s scanner colours) | No |
| engine-wide `g…` globals | 13 | Listed below | **Yes** |
| caches | 11 | `ResourceManager`'s sound and string caches, the shader cache, the live texture cache, `OOJSSystemInfo`'s cached system | **Yes**: they leak between tests |

## Singletons (25)

The `sharedX()` accessors, which hold their instance in a function-local or file-local static:
- `GameController::sharedController`
- `PlayerEntity::sharedPlayer` (`gOOPlayerHolder`)
- `OOJavaScriptEngine::sharedEngine`
- `OOShipRegistry::sharedRegistry`
- `OOCacheManager::sharedCache`
- `OOAsyncWorkManager::sharedAsyncWorkManager`
- `OOGraphicsResetManager::sharedManager`
- `OOOpenGLExtensionManager::sharedManager`
- `OOMusicController::sharedController`
- `OOOpenALController::sharedController`
- `OOJoystickManager::sharedStickHandler`
- `OOOXZManager::sharedManager`
- `OODebugMonitor::sharedDebugMonitor`
- `OONullTexture::sharedNullTexture`
- the default material (`OOBasicMaterial`)
- `sSharedProperties`, `sSharedEngine`
- `oofnd`'s `oo::log::logger`, `oo::NotificationCenter::defaultCenter`, `oo::Defaults::standard`
  and `oo::process` argument store

The rest of the 25 are second statics belonging to the same accessors (holder plus raw pointer).

## Engine-wide `g…` globals (13)

| Global | File |
|---|---|
| `gSharedUniverse`, `gOOJSPlayerIfStale` | `Universe.cpp` |
| `gOOPlayer` | `PlayerEntity.cpp` |
| `gLiveEntityCount`, `gTotalEntityMemory` | `Entity.cpp` |
| `gOOTextureInfo` | `OOTexture.cpp` |
| `gOOJSMainThreadContext`, `gOOJS{Array,Boolean,Number,Object,String}ClassID` | `OOJavaScriptEngine.cpp` |
| `gDebugFlags` | `SDL/main.cpp` |

`UNIVERSE` and `PLAYER` are macros over `gSharedUniverse` and `gOOPlayer`. They have 2,373 and 429
uses (idiom review, 2026-10-28), which spec 003's ratchet (R10) is meant to drive down.

## By file (4 or more globals)

Columns are the roles above. "mutable" is the testing target.

| File | Total | mutable | JS atoms | input | GL ptrs | JS classes | tables | singletons | run-time consts | g� globals | caches |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `Core/Entities/PlayerEntityControls.cpp` | 101 | 11 | 6 | 84 |  |  |  |  |  |  |  |
| `Core/OOOpenGLExtensionManager.cpp` | 66 |  |  |  | 65 |  |  | 1 |  |  |  |
| `Core/Entities/ShipEntity.cpp` | 62 | 10 | 46 |  |  |  |  |  | 6 |  |  |
| `Core/Entities/PlayerEntity.cpp` | 49 | 4 | 43 |  |  |  |  | 1 |  | 1 |  |
| `Core/Universe.cpp` | 23 | 13 | 8 |  |  |  |  |  |  | 2 |  |
| `Core/Scripting/OOJavaScriptEngine.cpp` | 21 | 12 |  |  |  |  |  | 2 |  | 6 | 1 |
| `Core/Scripting/OOConstToJSString.cpp` | 20 |  |  |  |  |  | 20 |  |  |  |  |
| `Core/ResourceManager.cpp` | 16 | 14 |  |  |  |  |  |  |  |  | 2 |
| `Core/HeadUpDisplay.cpp` | 13 | 11 | 1 |  |  |  |  |  | 1 |  |  |
| `Core/Entities/ShipEntityAI.cpp` | 11 | 1 | 8 |  |  |  |  |  |  |  | 2 |
| `Core/Entities/OOExhaustPlumeEntity.cpp` | 10 | 10 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOLegacyScriptWhitelist.cpp` | 10 |  |  |  |  |  | 10 |  |  |  |  |
| `Core/GuiDisplayGen.cpp` | 9 | 8 | 1 |  |  |  |  |  |  |  |  |
| `Core/Entities/PlayerEntityKeyMapper.cpp` | 9 | 9 |  |  |  |  |  |  |  |  |  |
| `Core/Entities/StationEntity.cpp` | 9 |  | 9 |  |  |  |  |  |  |  |  |
| `Core/GameController.cpp` | 8 | 5 | 1 |  |  |  |  | 2 |  |  |  |
| `Core/OOLogOutputHandler.cpp` | 8 | 8 |  |  |  |  |  |  |  |  |  |
| `Core/OOSkyDrawable.cpp` | 8 | 8 |  |  |  |  |  |  |  |  |  |
| `Core/Entities/PlayerEntityContracts.cpp` | 8 | 1 | 7 |  |  |  |  |  |  |  |  |
| `Core/Entities/PlayerEntitySound.cpp` | 8 | 8 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOJSEngineTimeManagement.cpp` | 8 | 8 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOJSMission.cpp` | 8 | 5 | 1 |  |  | 2 |  |  |  |  |  |
| `Core/Materials/OOTexture.cpp` | 7 | 5 |  |  |  |  |  |  |  | 1 | 1 |
| `Core/Scripting/OOJSSystemInfo.cpp` | 7 | 2 |  |  |  | 2 |  |  |  |  | 3 |
| `Core/OOTrumble.cpp` | 6 | 6 |  |  |  |  |  |  |  |  |  |
| `Core/Debug/OOJSConsole.cpp` | 6 | 6 |  |  |  |  |  |  |  |  |  |
| `Core/Entities/DockEntity.cpp` | 6 |  | 6 |  |  |  |  |  |  |  |  |
| `Core/Entities/PlayerEntityLegacyScriptEngine.cpp` | 6 | 5 | 1 |  |  |  |  |  |  |  |  |
| `Core/Materials/OOShaderProgram.cpp` | 6 | 5 |  |  |  |  |  |  |  |  | 1 |
| `Core/Scripting/OOJSShip.cpp` | 6 |  | 4 |  |  | 2 |  |  |  |  |  |
| `Core/AI.cpp` | 5 | 5 |  |  |  |  |  |  |  |  |  |
| `Core/legacy_random.cpp` | 5 | 5 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOJSClasses.cpp` | 5 | 3 |  |  |  |  |  | 1 | 1 |  |  |
| `Core/Scripting/OOJSScript.cpp` | 5 | 2 | 1 |  |  | 2 |  |  |  |  |  |
| `SDL/main.cpp` | 5 | 4 |  |  |  |  |  |  |  | 1 |  |
| `Core/OOEquipmentType.cpp` | 4 | 4 |  |  |  |  |  |  |  |  |  |
| `Core/OOStringExpander.cpp` | 4 | 3 |  |  |  |  |  |  |  |  | 1 |
| `Core/Entities/PlayerEntityLoadSave.cpp` | 4 |  | 4 |  |  |  |  |  |  |  |  |
| `Core/Materials/OOTextureLoader.cpp` | 4 | 4 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOJSFrameCallbacks.cpp` | 4 | 4 |  |  |  |  |  |  |  |  |  |
| `Core/Scripting/OOJSPlayer.cpp` | 4 |  | 2 |  |  | 2 |  |  |  |  |  |
| `header, in 2 objects` | 4 | 4 |  |  |  |  |  |  |  |  |  |

86 more files have 1�3 each; see the TSV.

## Where to start (suggestions, not a plan)

- **Cheap wins with no upstream cost:**
  - the 11 caches, which can move onto their owners and gain a `clear()` for tests;
  - the JS atom caches and class handles, which can move onto `OOJavaScriptEngine`, so one engine
    per test is clean;
  - the "loaded" flags and the `GuiDisplayGen::drawStarChart` saved-state statics, which can
    become members.
- **The real seam for testing** is the singletons and `g…` globals. Spec 003 plans a game context
  (`OOGame`/`OOGameContext`) that owns them, with a "bridge" (the current accessors) kept until the
  callers move. Spec 011 already gives one headless game per process.
- **Leave for now:**
  - the input latches, which match upstream;
  - the GL function pointers, which are process-wide by nature;
  - the run-time constants and built-once tables, which aren't state that changes.
