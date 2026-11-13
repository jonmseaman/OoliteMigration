# Convert the large files in slices; delete the first Objective-C bridges

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 11/28. Replays `series/013-first-slices`.

## What this changes

- Converts ten large classes slice by slice to `cxx::X` plus a bridge: `HeadUpDisplay`, `OOMesh`,
  `OOOXZManager`, `ResourceManager`, `MyOpenGLView`, `OOOXPVerifier` and #768's
  `OOJavaScriptEngine`, `OOJSScript`, `OOJSSystem`, `OOJSPlayerShip` (keeping #768's error
  reporting). `OOJSSpecialFunctions` becomes `.cpp` with no bridge.
- Starts `ShipEntity`: its ivars move to `cxx::ShipEntity`, its interface is copied to
  `ShipEntity+ObjCBridge.h`, its methods stay Objective-C via `_cxxShip->`. `StickProfileScreen`
  becomes `cxx::` with no bridge.
- Splits out plain-C++ `OOCPUInfoEndian.h`, `OOOpenGLCheck.h`, `OOOpenGLExtensionPointers.h`; keeps
  #747 (copy-URL key), #774 (game window shares the splash GL context), #766 (macOS snapshot).
- Deletes 30 bridges from steps 9-10 that lost their last Objective-C caller (9 materials, 4 audio,
  6 verifier, 6 #768 binding categories, 5 others); each class leaves `namespace cxx`.

## Why

The large files depend on what steps 9-10 converted, and steps 12-13's classes message them most.

## Behaviour changes

- Windows with the debug console (`OO_DEBUG_MONITOR_ENABLED`, deployment too): a paused game with a
  waiting console keeps normal priority (was `IDLE_PRIORITY_CLASS`, one command per 15-60 s).
  Pinned by `test_a_paused_game_with_a_console_keeps_normal_priority`
  (`tests/component/test_paused_console_priority.py`).

## How to review

Slices: start with the header comment of `ShipEntity+ObjCBridge.h`. In `ShipEntity.mm` only 26 of
2,074 added lines are not `_cxxShip->` insertions:
`git diff seriesb/010-module-conversions seriesb/011-first-slices -- src/Core/Entities/ShipEntity.mm | grep '^+[^+]' | grep -v '_cxxShip->'`.
Converted files: as step 9; compare `HeadUpDisplay.mm` with its `@implementation`. #747's
`setOXPURL`/`processCopyUrlKey` are covered by `copyUrlKey` in `test_OOOXZManager.mm`.
Deletions: bridge files and `meson.build` line gone, `namespace cxx` gone, callers drop
`oo::ToObjC`/`oo::ToCxx`; `git grep` for sends to a deleted class finds nothing. The priority fix
is the `GameController.mm` hunk.

New tests: nine `test_X.mm` (incl. `test_ShipEntity.mm`, `test_PlayerEntityStickProfile.mm`);
`OOJSSpecialFunctions` has none. In them, `test_OOJavaScriptEngine.mm` expects a non-object plus a
pending exception for a plain `OOObject`, and `test_OOMaterialConvenienceCreators.mm` binds
`*material.get()` before `typeid` (`-Wpotentially-evaluated-expression`).

Test edits:
- `test_OOJSScript.mm`: extended for the converted class.

## Verified

Not verified at `c245c5da16`.
