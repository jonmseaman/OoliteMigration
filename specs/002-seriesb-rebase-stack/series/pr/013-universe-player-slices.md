# Convert Universe and PlayerEntity to C++

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 13/28. Replays `series/015-universe-player-slices`.

## What this changes

- Universe slices 2-26 move into `cxx::Universe` (set-up, ships, witchspace, drawing, entity
  lists, collisions, `update:`, markets, descriptions, logs, sounds), keeping #766's renderbuffer
  and Mac speech guards and #756's debug guards.
- PlayerEntity slice 1: the state moves to `cxx::PlayerEntity : cxx::ShipEntity` as public members;
  the Objective-C class (`PlayerEntity+ObjCBridge.h`) and its categories read `_cxxPlayer->name`.
- Deletes six bridges (`OOExhaustPlumeEntity`, `OOFlasherEntity`, `OOTextureSprite`, `OOJSFunction`,
  `OOCombinedEmissionMapGenerator`, `OOJSVisualEffect+ObjCBridge.mm`); converts `StationEntity`
  slice 4 and `MyOpenGLView+Input.mm`; `OOMusic` is held as `oo::Ref`.
- New `OOJSPrivateObject.h/.cpp`: JS private-slot glue for C++ objects (`OOJSGetCxxPrivate`,
  `OOJSCxxObjectWrapperFinalize`). First user `cxx::OOJSTimer`: the slot holds the C++ timer; the
  unrooted-timer warning moves to `clearJSSelf()`, keeping #768's `willNotFireAgain()` check.

## Why

Nearly every file messages these two and the player overrides `ShipEntity`, so they follow step 12.

## Behaviour changes

- Debug-only `dumpGrayAlphaToFileNamed` makes its own surface (was writing RGBA over the caller's
  two-byte buffer, overrunning the last row; upstream bug too). Pinned by
  `dumpGrayAlphaLeavesTheCallersBytes` in `test_MyOpenGLView.mm`.

## How to review

Universe: `Universe.h`, `Universe+ObjCBridge.*`, then `test_Universe.mm` (a block per slice).
Rule as step 12:
`git diff --word-diff -w seriesb/012-shipentity-slices seriesb/013-universe-player-slices -- src/Core/Universe.mm`.
Trap: slice 26 opens `namespace cxx` before `#if OO_LOCALIZATION_TOOLS`, so deployment builds
compile.

Player: `PlayerEntity.h` (members zero-initialised), `test_PlayerEntity.mm`. Category edits are
`_cxxPlayer->` insertions; only three closing braces are anything else:
`git diff seriesb/012-shipentity-slices seriesb/013-universe-player-slices -- src/Core/Entities/PlayerEntityControls.mm | grep '^+[^+]' | grep -v '_cxxPlayer->'`.

`OOJSPrivateObject`: header, `OOJSTimer.mm`, `test_OOJSPrivateObject.mm`. `unrootedRunningTimerGC`
(`test_OOJSTimer.mm`) covers the finalizer path; no test checks the warning is logged. The Timer converter still
answers the Objective-C bridge.

Test edits:
- Deleted bridges' tests: moved to the C++ class's test.

## Verified

Not verified at `dafa48f08b`.
