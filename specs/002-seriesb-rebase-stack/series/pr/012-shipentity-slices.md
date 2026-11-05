# Convert ShipEntity to C++

**Series:** step 12 of 24 · base `seriesb/011-first-slices` · next `seriesb/013-universe-player-slices` **(gen)**

**Replays:** `series/014-shipentity-slices` (old 14 of the master-based series) · 29.1k src, 6.9k tests, 105 other changed lines; 57 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

`ShipEntity` becomes the C++ class `cxx::ShipEntity`: slices 2 to 34 of `ShipEntity.mm` (set-up
from the ship dictionary, `update:`, behaviours, equipment, weapons, collisions and damage,
docking, escorts, comms, AI reactions), its `ScriptMethods` and `LoadRestore` categories and all of
`ShipEntityAI.mm` become C++ members. `StationEntity` follows with its class shell and three slices
(docking traffic and the launch queue; clearance, damage, allegiance and alert level).

The step also converts `GuiDisplayGen` (four slices, the star chart last), `GameController` (class
shell, frame loop and deferred calls, start-up), `OOVisualEffectEntity`, `OOStringExpander` and
`OOShipLibraryDescriptions`, and adds `Universe`'s class shell. `OOMatrix.mm`,
`OOPixMapChannelOperations.mm` and `OOConvertCubeMapToLatLong.mm`, which have no Objective-C left,
become `.cpp`.

Each converted class except `OOShipLibraryDescriptions` keeps an Objective-C bridge
(`X+ObjCBridge.h/.mm`) whose methods forward, one line each, to the C++ object, so code that still
sends Objective-C messages compiles and runs unchanged. `OOJSGlobal+ObjCBridge.mm` is deleted:
`log()` now calls the C++ engine's monitor member directly.

Upstream code in the moved methods is kept: #756's `OO_DEBUG_MONITOR_ENABLED` guards on the ship's
and the universe's debug members, #766's `OOLITE_MAC_COCOA_UI` guards and multisample colour
renderbuffer in `GameController` and `Universe`, and #768's shut-down of the JS engine at exit,
which its leak check needs.

## Why

`ShipEntity` is the superclass of the station, the dock, the player and the proxy player, so it
converts before them, and its AI category and `StationEntity` call and override its members, so
they follow its slices. `Universe`'s shell lands here because the ship's converted members call
`cxx::Universe`; its methods move in the next step. The bridges are what let a 13,000-line file
convert a slice at a time while the rest of the game still messages it; steps 14 and 15 delete them
once no Objective-C caller is left.

## Behaviour changes

None. Each converted class has a unit test written against its Objective-C API, so the
conversion is held to the answers the Objective-C code gave: new in this step,
`test_ShipEntityAI.mm`, `test_StationEntity.mm`, `test_GameController.mm`,
`test_OOVisualEffectEntity.mm` and `test_Universe.mm`; extended, `test_ShipEntity.mm` and
`test_GuiDisplayGen.mm` (all under `tests/unit/core/`).

## How to review

Start with `src/Core/Entities/ShipEntity.h` (the class `cxx::ShipEntity`, members in file order)
and `ShipEntity+ObjCBridge.h` (the old `@interface`, copied, with one ivar holding the C++
object). `ShipEntity+ObjCBridge.mm` is almost all one-line forwarders, plus the initialisers,
`-dealloc` and the two `SubEntityRelationship` categories, which need the Objective-C object as
`self`: skim it. `ShipEntity+ObjCAdapter.h` is the one non-obvious piece: the C++ part of a ship
that is still an Objective-C subclass (the station's bridge uses it too), whose virtual members
message the Objective-C object.

The bodies in `ShipEntity.mm`, `ShipEntityAI.mm`, `StationEntity.mm` and the other converted files
are the Objective-C bodies with message syntax rewritten (`[x foo:y]` to `x->foo(y)`, nil-guarded
where the receiver may be nil) and `BOOL`/`NSString` to `bool`/`std::string`. To spot-check, pick a
few methods and compare them with
`git diff --word-diff -w seriesb/011-first-slices seriesb/012-shipentity-slices -- src/Core/Entities/ShipEntity.mm`:
only the call syntax and types should differ. The tests are the place to look for intent: each
`OO_TEST` names the behaviour it pins.

One test detail: `test_Universe.mm`'s case `flags` passes 7 and 2 to `-setDisplayFPS:`,
`-setAutoMessageLogBg:` and `-setWitchspaceBreakPattern:` through `int` locals, because the literal
form warns (`-Wobjc-bool-constant-conversion`) against the `BOOL` setters. The values and checks
are the same.

## Verified **(gen)**

Not verified at this branch's tip (`eaf9516878`) yet: the last record is for `62b20bd82e` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
