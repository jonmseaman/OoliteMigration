# Small fixes after the conversion; Mozilla polyfills for expansions

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 24/28. Takes the tree of `feature/upstream-quickjs-poc-cxx` (`270c74ea78`), with the series' exclusions and additions.

## What this changes

- Scripting (#768's binding otherwise as upstream wrote it): `OOJavaScriptEngine.cpp` and
  `OOJSScript.cpp` clear the exception when a getter throws during the engine's own reads; the
  `willLoad` log indents unconditionally, as upstream's `OOJSScript.m`. `oolite-global-prefix.js`
  adds guarded Mozilla extensions; `oolite-quickjs-compat.js` is unchanged.
- Dead code: `OOLITE_MAC_COCOA_UI` and its derived macros go from 10 files, keeping the non-Cocoa
  arm; `OOObjCPList.h` (includers, 17 tests among them, include its three headers directly) and
  `dummy.cpp` are deleted.
- clang-tidy 22 `-fix` plus clang-format over ~130 files, one commit per check (7 checks).
- Build: `OOOpenGLOnly.h` also tests `LINUX` (plain C++ units lacked `GL_GLEXT_PROTOTYPES`);
  `OOProfilingStopwatch.h` fences its Windows includes from the sorter; macOS `bundle_dylibs()`
  resolves `@rpath/` deps; the 8 OpenAL tests also join suite `openal`.

## Why

Fixes found after the conversion: build fixes, never-compiled code, `.clang-tidy` checks, and
Mozilla extensions old expansions call.

## Behaviour changes

- A getter that throws during the engine's own property read leaves no pending exception; the read
  falls back as for a missing property (was left pending for the next script). Pinned by
  `throwingAccessorsLeaveNoPendingException` (`test_OOJavaScriptEngine.cpp`; fails without the fix).
- Scripts can call `String.prototype.quote()`, `Array.forEach(array, fn)` and the other generics
  (were undefined). Not pinned.
- `script.javaScript.willLoad` log indent is balanced after an early load failure (was outdented
  without an indent). Not pinned.
- macOS app bundles carry `libc++abi` and `libunwind` (was abort at launch). Not pinned, and not
  verified by this series.
- Otherwise none: Cocoa blocks were never compiled, `OOOpenGLExtensionManager` already locked on
  every build, clang-tidy fixes keep meaning.

## How to review

Read by commit. clang-tidy commits are mechanical (`git show --word-diff`); the
`bugprone-macro-parentheses` and `performance-unnecessary-copy-initialization` diffs were read by
hand. Cocoa removal is mostly deletions in `GameController.cpp` and `Universe.cpp`: check each
kept arm is the one an SDL build compiled.

Test edits (no existing assertion changes):
- `tests/unit/core/meson.build`: the 8 OpenAL tests also in suite `openal`; all stay in `core`.
- 17 `test_*.cpp`: include lines only (`OOObjCPList.h` deleted).
- `test_OOJavaScriptEngine.cpp`: also gains `throwingAccessorsLeaveNoPendingException`.

## Test changes

Existing test files changed (ledger `test-changes.md`):

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

## Verified

Not verified at `cb53755496`.
