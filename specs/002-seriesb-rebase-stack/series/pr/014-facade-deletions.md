# Delete the Objective-C bridges

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 14/28. Replays `series/016-facade-deletions`.

## What this changes

- Converts the last Objective-C in the large classes: the rest of `PlayerEntity.mm` and its nine
  category files, `DockEntity`, `ProxyPlayerEntity`, the rest of `OOJSShip.mm`, and `Universe.mm`'s
  last class syntax. New tests: `test_DockEntity`, `test_OOJSShip`, `test_ProxyPlayerEntity`.
- Deletes the bridges of 64 classes (121 files) and `ShipEntity+ObjCAdapter.h`; `cxx::X` becomes
  `X`. 24 bridges remain: step 15 deletes all but `OOWeakReference`'s (step 16).
- #768 private-slot C++ objects (script, timer, ship group, system and equipment info, sound,
  sound source) use `OOJSCxxObjectWrapperFinalize`; the engine's own finalizer and converter stay
  Objective-C until step 16.
- Keeps #740 (last save name from `last_savename`), #749/#751 (`AnyKeyPressed({ ... })` for
  `a | b | c`), #756 guards (incl. the shader-binding table's), #783 GUI joystick buttons, #786
  stick-mapper names from descriptions.

## Why

A bridge can go only when nothing messages its class; for entities that needed steps 12-13 first.

## Behaviour changes

None. Upstream behaviour kept and pinned:
- #740 last save name. Pinned by `lastsaveNameIsRememberedInTheDefaults` (`test_PlayerEntity.mm`).
- #786 hardware names. Pinned by `stickMapperHardwareAndGuiDicts` (`test_PlayerEntity.mm`).
- #783 GUI-button reads in the GUI screens. Not pinned.
- Player and proxy stay visible to scripts. Pinned by `playerAndProxyAreVisibleToScripts`
  (`test_ProxyPlayerEntity.mm`).
- A station keeps its `Station` JS class. Pinned by `stationAnswersTheStationJSClass`
  (`test_StationEntity.mm`).

## How to review

Conversions first: `PlayerEntity.h`/`.mm`, then the categories; rule as step 12:
`git diff --word-diff -w seriesb/013-universe-player-slices seriesb/014-facade-deletions -- src/Core/Entities/PlayerEntity.mm`.
Deletions: `git diff --stat --diff-filter=D seriesb/013-universe-player-slices seriesb/014-facade-deletions`.
Per class: bridge gone from `meson.build`, `namespace cxx` gone, callers only rewrite sends and
drop `oo::ToObjC`/`oo::ToCxx`. `Entity+ObjCBridge.mm` grows ~6,700 lines: methods still called by
selector name move into `Entity (...SelectorsCalledByName)` forwarding categories (C++ tables in
step 15).

Test edits:
- Cases that tested a bridge itself (forwarding, one bridge per object): removed.
- Objective-C stand-ins become C++; other cases re-spelled for the C++ API.

## Verified

Not verified at `1acb43182f`.
