# Convert ShipEntity to C++

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 12/28. Replays `series/014-shipentity-slices`.

## What this changes

- `ShipEntity` becomes `cxx::ShipEntity`: slices 2-34 of `ShipEntity.mm`, its `ScriptMethods` and
  `LoadRestore` categories and all of `ShipEntityAI.mm`.
- Also converts `StationEntity` (shell and three slices), `GuiDisplayGen` (four), `GameController`
  (three), `OOVisualEffectEntity`, `OOStringExpander`, `OOShipLibraryDescriptions`; adds
  `Universe`'s class shell. Three files with no Objective-C left become `.cpp` (`OOMatrix` and two
  pixmap files); `OOOpenGLOnly.h` also tests `LINUX` before defining `GL_GLEXT_PROTOTYPES`.
- Each converted class but `OOShipLibraryDescriptions` keeps a one-line-forwarder bridge.
  `OOJSGlobal+ObjCBridge.mm` is deleted (`log()` calls the engine's monitor directly).
- Keeps #756's debug guards, #766's `OOLITE_MAC_COCOA_UI` guards and multisample renderbuffer, and
  #768's JS engine shut-down at exit.

## Why

`ShipEntity` is the superclass of the station, dock, player and proxy player, so it converts first.

## Behaviour changes

None. Held to the Objective-C answers by new `test_ShipEntityAI.mm`, `test_StationEntity.mm`,
`test_GameController.mm`, `test_OOVisualEffectEntity.mm`, `test_Universe.mm` (`tests/unit/core`).

## How to review

Start with `ShipEntity.h` (members in file order) and `ShipEntity+ObjCBridge.h` (the old
`@interface`); skim `ShipEntity+ObjCBridge.mm`. The non-obvious piece is `ShipEntity+ObjCAdapter.h`:
the C++ part of a ship that is still an Objective-C subclass, whose virtuals message that object.
Rule: Objective-C bodies with message syntax rewritten (nil-guarded) and `BOOL`/`NSString` ->
`bool`/`std::string`. Spot-check:
`git diff --word-diff -w seriesb/011-first-slices seriesb/012-shipentity-slices -- src/Core/Entities/ShipEntity.mm`.

Test edits:
- `test_ShipEntity.mm`, `test_GuiDisplayGen.mm`: extended for the new slices.

`test_Universe.mm`'s `flags` passes 7 and 2 to `BOOL` setters through `int` locals
(`-Wobjc-bool-constant-conversion`); values and checks unchanged.

## Verified

Not verified at `d2b32c525e`.
