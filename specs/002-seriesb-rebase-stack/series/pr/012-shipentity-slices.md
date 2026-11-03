# Convert ShipEntity to C++

**Series:** step 12 of 25 · base `seriesb/011-first-slices` · next `seriesb/013-universe-player-slices` **(gen)**

**Replays:** `series/014-shipentity-slices` (old 14 of the master-based series) · 29.1k src, 6.9k tests, 105 other changed lines; 57 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

`ShipEntity` becomes the C++ class `cxx::ShipEntity`: slices 2 to 34 of `ShipEntity.mm` (set-up
from the ship dictionary, `update:`, behaviours, equipment, weapons, collisions and damage,
docking, escorts, comms, AI reactions), its `ScriptMethods` and `LoadRestore` categories and all of
`ShipEntityAI.mm` become C++ members. `StationEntity` follows with its class shell and three slices
(docking traffic and the launch queue; clearance, damage, allegiance and alert level). The same
range converts `GuiDisplayGen` (four slices, the star chart last), `GameController` (class shell,
frame loop and deferred calls, start-up), `OOVisualEffectEntity`, `OOStringExpander` and
`OOShipLibraryDescriptions`, adds `Universe`'s class shell, and renames `OOMatrix.mm` and
`OOPixMapChannelOperations.mm`, which had no Objective-C left, to `.cpp`. Every converted class
keeps an Objective-C facade (`X+ObjCBridge.h/.mm`) whose methods forward one line each to the C++
object, so code that still sends Objective-C messages compiles and runs unchanged.

## Why

`ShipEntity` is the superclass of the station, the dock, the player and the proxy player, so it
converts before them, and its AI category and `StationEntity` call and override its members, so
they follow its slices. `Universe`'s shell lands here because the ship's converted members call
`cxx::Universe`; its methods move in the next step. The facades are what let a 13,000-line file
convert a slice at a time while the rest of the game still messages it; steps 16 and 17 delete them once
no Objective-C caller is left.

## Behaviour changes

None. Each converted class has a unit test written against its Objective-C API and run on the
unconverted class first, so the conversion is held to the answers the Objective-C code gave:
`tests/unit/core/test_ShipEntity.mm`, `test_ShipEntityAI.mm`, `test_StationEntity.mm`,
`test_GuiDisplayGen.mm`, `test_GameController.mm`, `test_OOVisualEffectEntity.mm` and
`test_Universe.mm` (all under `tests/unit/core/`).

## How to review

Start with `src/Core/Entities/ShipEntity.h` (the class `cxx::ShipEntity`, members in file order)
and `ShipEntity+ObjCBridge.h` (the old `@interface`, copied, with one ivar holding the C++
object). `ShipEntity+ObjCBridge.mm` is one-line forwarders: skim it. `ShipEntity+ObjCAdapter.h` is
the one non-obvious piece: the C++ part of a ship that is still an Objective-C subclass (the
station's facade uses it too), whose virtual members message the Objective-C object.

The bodies in `ShipEntity.mm`, `ShipEntityAI.mm`, `StationEntity.mm` and the other converted files
are the Objective-C bodies with message syntax rewritten (`[x foo:y]` to `x->foo(y)`, nil-guarded
where the receiver may be nil) and `BOOL`/`NSString` to `bool`/`std::string`. To spot-check, pick a
few methods and compare them with
`git diff --word-diff -w series/013-first-slices series/014-shipentity-slices -- src/Core/Entities/ShipEntity.mm`:
only the call syntax and types should differ. The tests are the place to look for intent: each
`OO_TEST` names the behaviour it pins.

## Differences from the old step **(gen)**

None: the same change as `series/014-shipentity-slices`.

## Verified **(gen)**

Windows x64, `62b20bd82e`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 new warnings (4 inherited from the parent, 7 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
