# Move the scripting layer to upstream's QuickJS-ng binding

**Series:** step 25 of 25 · base `seriesb/024-google-style-format` · next `—` **(gen)**

**Switch:** the tree of `feature/upstream-quickjs-binding` (`531ddd6592`), with the series' exclusions and additions · 28.4k src, 11.3k tests, 285 other changed lines; 6.6k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

The scripting layer moves to upstream's QuickJS-ng binding (#767, #768), converted to C++. The
fork's `ooscript` façade (`src/Core/Scripting/ooscript/`) is deleted. The 100 files under
`src/Core/Scripting/` use #768's API directly: natives take `OOJS_NATIVE_ARGS`, property tables
are `JSCFunctionListEntry` arrays, classes use `JSClassExoticMethods`, and ownership is explicit
(`JS_FreeValue`), with `OOJSClasses.cpp` registering the class IDs. The 50 callers outside the
scripting layer (the debug console and monitor, `Universe`, `GuiDisplayGen`, the entities,
`OOEquipmentType`, `OOShipGroup`) are ported with it. `Resources/Scripts/oolite-quickjs-compat.js`
and #768's two log classes (`script.javaScript.cache`, `script.javaScript.load.modern`) come
from #768.

The unit tests move from the façade to the same API. Every test this step changes or deletes is
listed in `series/test-changes.md`; the façade's own backend test, `test_jsengine_quickjs.cpp`,
goes with the façade.

## Why

#768's binding is the one upstream is reviewing, and it is an improvement on the fork's façade
(Jon, 2026-11-02). Ending the series on it means the C++ game and upstream's QuickJS-ng work share
one scripting layer, so the rest of the series does not have to be ported again when #768 lands.
It comes last because steps 4 to 24 were built and tested on the façade; switching here keeps each
of them as it was verified, and keeps the binding change and its test changes in one reviewable
step.

## Behaviour changes

These follow #768; each one that a test observes is in the test ledger.
- **Assignments #768 rejects now throw**: an invalid manifest value or deleting a manifest entry,
  and in strict code a write to a read-only property such as `wormhole.origin`.
- **Class tags**: `Object.prototype.toString.call(<game object>)` gives `[object Object]`, not
  e.g. `[object Vector3D]`.
- **Natives**: `effect.scale(2)` returns `undefined`; a native called on the wrong `this` throws.
- **SystemInfo**: `Object.keys()` and for..in list only the system data keys. The fork adds a
  `has_property` hook so for..in works on QuickJS-ng 0.17 (it lists nothing on #768 itself);
  with it `'economy' in info` is `true`, while `hasOwnProperty()` stays `false`.
- **Exceptions from a `filteredEntities` predicate** are reported and stop the script.
- **Smaller ones**: Timer caches its callback's name; `isExecutableJavaScript('1 +')` is `false`;
  `quitGame()` is deferred until the script returns; `SoundFromJSValue` resumes the time limiter;
  the debug monitor has only warning and exception messages, and stack dumps use #768's format.

Not applied: #768's QuickJS-ng patch `0001-oolite-primitive-property-assignment.patch`, so a
strict-mode `"s".foo = 1` is silently ignored, as on `develop`. The JavaScript parity probe
(`tools/js-parity`) needs Linux and has not been run against this step.

## How to review

1. Compare `src/Core/Scripting/` with #768's branch file by file: most files are #768's with the
   C++ conversion (`.m` → `.cpp`, the fork's Google style, `oo::` types in place of Foundation).
   `OOJSSystemInfo.cpp`'s `has_property` hook is the one addition #768 does not have.
2. Read the 50 callers outside `src/Core/Scripting/`; each ports a call from `ooscript` types to
   #768's, and the two use-after-free fixes (the ship-killed event, the ECM blast) follow #768's.
3. Read `series/test-changes.md` with the test diff: each row names a test and why it changes.

`git grep -n ooscript -- src tests` is empty on this step.

## Test changes **(gen)**

The tests move to upstream's engine API with the code; each changed test is listed in `specs/002-seriesb-rebase-stack/series/test-changes.md` (spec FR-015).

## Verified **(gen)**

Windows x64, `57a0c89a9e`, 2026-11-03.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass: every changed test is in the test ledger (FR-015) |
| unit | pass: oofnd, core, headers |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
