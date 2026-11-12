# Small fixes after the conversion; Mozilla polyfills for expansions

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 24 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Takes the tree of `feature/upstream-quickjs-poc-cxx` (`270c74ea78`), with the series' exclusions and additions.

## What this changes

Small fixes, dead-code removal and clang-tidy cleanups on top of step 023, in step 023's style,
and one addition for expansions. The scripting layer stays upstream #768's QuickJS-ng binding as
steps 003–023 carry it: its code, its profiler macros, its time-limiter clock, its
`dependency('quickjs-ng')` build wiring and its `src/Core/Scripting/README.md`.

| File | What | Why |
|---|---|---|
| `src/Core/OOOpenGLOnly.h` | Also tests the build's `LINUX` define | A plain C++ unit (`OO_PLAIN_CPP_UNIT`) does not include `OOFoundation.h`, so on Linux it had no `GL_GLEXT_PROTOTYPES`; #748's condition is otherwise unchanged |
| `src/Core/OOHPVector.h` | Drops an empty `#if __OBJC__` / `#endif` pair | Left behind when its Objective-C declaration moved out |
| `Resources/Scripts/oolite-global-prefix.js` | Adds `String.prototype.quote()` and the Array/String generics (`Array.forEach(array, fn)`, `String.replace(string, …)`) | Mozilla extensions that SpiderMonkey-era expansions call; `oolite-quickjs-compat.js` (#768) already defines `toSource()` and `uneval()` and is not changed; each install is guarded |
| `tests/unit/core/meson.build` | The 8 tests that open OpenAL are also in suite `openal` | A sanitized run can leave them out (`--no-suite openal`); every test stays in `core` |
| `src/Core/Scripting/OOJavaScriptEngine.cpp`, `OOJSScript.cpp` | Clears the exception when a getter throws while the engine reads an error's `name`/`stack`, a value's `constructor`/`name`, a function's `name`, a described array element, the const rewriter or an unconstructable class's `name` | The exception was left pending for the next script |
| `src/Core/Scripting/OOJSScript.cpp` | Indents the `script.javaScript.willLoad` log unconditionally | It outdented without indenting after an early load failure; upstream's `OOJSScript.m` indents unconditionally |
| `GameController`, `Universe`, `PlayerEntity*`, `OOFoundation.h`, `OOMacroOpenGL.h`, `OOOpenGLExtensionManager`, `OOMusicController.h`, `OOFullScreenController.h`, `OOLogHeader.cpp`, `OOOXPVerifier.cpp` | Removes `OOLITE_MAC_COCOA_UI` and the macros derived from it (`OO_USE_FULLSCREEN_CONTROLLER`, `OOLITE_ITUNES_SUPPORT`, `OOOPENGLEXTMGR_LOCK_SET_ACCESS`), keeping the non-Cocoa arm of each conditional | The Cocoa front end's Objective-C blocks are never compiled in the C++ tree (`OOLITE_SDL` is 1 on every build) |
| `src/Core/OOObjCPList.h` (deleted) and its includers, 17 tests among them | Each file includes `OODescription.h`, `oofnd/PList.hpp` and `oofnd/StdLib.hpp` as it needs them | The header only forwarded those three |
| `src/Core/dummy.cpp` (deleted) | — | An empty file from the Xcode project; no build file lists it |
| About 130 files under `src/Core`, `src/SDL`, `src/oofnd` | clang-tidy 22 `-fix`, then clang-format 22: `modernize-use-nullptr`, `modernize-redundant-void-arg`, `modernize-use-using`, `modernize-use-override`, `performance-inefficient-vector-operation`, `bugprone-macro-parentheses`, `performance-unnecessary-copy-initialization` | One commit per check; the last two diffs were read by hand |
| `src/Core/OOProfilingStopwatch.h` | Fences `<windef.h>` and `<timeapi.h>` with `clang-format off`/`on` | Keeps the include sorter from putting `timeapi.h` first again, which breaks the Windows build |
| `src/Core/Entities/DockEntity.h`, `ShipEntity.cpp` | Comment fixes | Trailing comments moved above the code they describe; a stale section comment dropped |
| `ShellScripts/macOS/create_app_bundle_fn.sh` | `bundle_dylibs()` resolves `@rpath/` dependencies through the original file's rpaths | Homebrew LLVM's `libc++` names `libc++abi` and `libunwind` as `@rpath/…`; the bundler skipped them and the app aborted at launch |

## Why

These are the fixes found after the conversion that belong with the series: build fixes for
Linux, macOS and Windows that the reformat or the converted tree needed, removal of code that is
never compiled, the clang-tidy checks the series' `.clang-tidy` enables, and the Mozilla
extensions that SpiderMonkey-era expansions call and #768's compatibility script does not
define. The fork's restyle of #768's binding is not here: the series uses that binding as
upstream wrote it.

## Behaviour changes

- A getter that throws while the engine reads a property for its own bookkeeping no longer
  leaves the exception pending for the next script; the read falls back as for a missing
  property. Pinned by `throwingAccessorsLeaveNoPendingException` in
  `tests/unit/core/test_OOJavaScriptEngine.cpp` (added; it fails without the fix).
- Scripts can call `String.prototype.quote()`, `Array.forEach(array, fn)` and the other
  Array/String generics. Not pinned by a test.
- The `script.javaScript.willLoad` log indent is balanced after an early load failure. Not pinned
  by a test.
- macOS app bundles carry `libc++abi` and `libunwind`. Not pinned by a test, and not verified by
  this series.
- Otherwise none: the Cocoa blocks were never compiled, `OOOpenGLExtensionManager` already took
  its lock on every build, and the clang-tidy fixes keep the code's meaning.

## How to review

Read the commits; each names its files and is small, apart from the clang-tidy ones, which are
one check each and mechanical (`git show --word-diff`). The Cocoa removal is mostly deletions in
`GameController.cpp` and `Universe.cpp`; check that each kept arm is the one an SDL build
compiled. No existing assertion changes; one test is added, and 17 tests change their include
lines only.

## Test changes

Existing test files this step changes (test ledger: `test-changes.md`):

- `tests/unit/core/meson.build`
- `tests/unit/core/test_OOCache.cpp`
- `tests/unit/core/test_OOCharacter.cpp`
- `tests/unit/core/test_OODebugMonitor.cpp`
- `tests/unit/core/test_OOJSEquipmentInfo.cpp`
- `tests/unit/core/test_OOJSPlayer.cpp`
- `tests/unit/core/test_OOJSShipGroup.cpp`
- `tests/unit/core/test_OOJSStation.cpp`
- `tests/unit/core/test_OOJSSystem.cpp`
- `tests/unit/core/test_OOJSSystemInfo.cpp`
- `tests/unit/core/test_OOJSVisualEffect.cpp`
- `tests/unit/core/test_OOJavaScriptEngine.cpp`
- `tests/unit/core/test_OOPlanetTextureGenerator.cpp`
- `tests/unit/core/test_OOProbabilitySet.cpp`
- `tests/unit/core/test_OOShaderMaterial.cpp`
- `tests/unit/core/test_OOStandaloneAtmosphereGenerator.cpp`
- `tests/unit/core/test_OOVector.cpp`
- `tests/unit/core/test_StationEntity.cpp`

## Verified **(gen)**

Not verified at this branch's tip (`cb53755496`) yet; the last record (2026-11-03) is for an earlier build.
