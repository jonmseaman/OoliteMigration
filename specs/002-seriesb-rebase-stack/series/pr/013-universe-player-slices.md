# Convert Universe and PlayerEntity to C++

**Series:** step 13 of 26 · base `seriesb/012-shipentity-slices` · next `seriesb/014-facade-deletions` **(gen)**

**Replays:** `series/015-universe-player-slices` (old 15 of the master-based series) · 17.7k src, 3.6k tests, 0 other changed lines; 1.2k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Two pieces of work share this step.

- **Universe slices.** Slices 2 to 26 of `Universe.mm` move into `cxx::Universe`, whose shell came
  in step 12: set-up of space and the system populator, adding ships by role and position,
  witchspace, the main station and beacons, drawing and the view frustum, the entity lists,
  targeting and collisions, `update:`, the shipyard, markets, routes, system data and
  descriptions, speech and message logs, sounds and wormholes. Upstream code in them is kept:
  #766's multisample colour renderbuffer and `OOLITE_MAC_COCOA_UI` guards on the Mac speech
  routines, and #756's `OO_DEBUG_MONITOR_ENABLED` guards on the debug entity dumps.
- **PlayerEntity slice 1.** The player's state moves to a new `cxx::PlayerEntity : cxx::ShipEntity`,
  as public data members with the ivars' names. The Objective-C `PlayerEntity` (now in
  `PlayerEntity+ObjCBridge.h`) keeps all of its methods for now, and they and the categories
  (`PlayerEntityControls.mm`, `PlayerEntityContracts.mm`, `PlayerEntityLoadSave.mm` and the
  others) reach the state as `_cxxPlayer->name`.

The step also:
- deletes six bridges whose last Objective-C caller had gone: `OOExhaustPlumeEntity`,
  `OOFlasherEntity`, `OOTextureSprite`, `OOJSFunction`, `OOCombinedEmissionMapGenerator`, and the
  `OOJSVisualEffect+ObjCBridge.mm` category of #768's binding;
- converts `StationEntity`'s NPC launchers (slice 4) and `MyOpenGLView+Input.mm`, whose methods
  become `cxx::MyOpenGLView` members (its category header goes); `OOLegacyScriptWhitelist.mm` calls
  `cxx::ResourceManager` directly;
- adds `OOJSPrivateObject.h/.cpp`, the C++ counterpart of #768's glue for a JS object whose private
  slot holds an Objective-C object (`DEFINE_JS_OBJECT_GETTER`, `OOJSObjectWrapperFinalize`,
  `OOJSObjectWrapperToString`). A C++ class implements the `OOJSPrivateObject` interface and its JS
  class uses `OOJSGetCxxPrivate`, `OOJSCxxObjectWrapperFinalize` and
  `OOJSCxxObjectWrapperToString`. #768 has no such glue; `cxx::OOJSTimer` is its first user, and a
  Timer's slot now holds the C++ timer rather than its bridge. The Timer finalizer's
  unrooted-timer warning moves into `OOJSTimer::clearJSSelf()` and keeps #768's
  `willNotFireAgain()` test, so a one-shot timer freed by its own callback still does not warn;
- has the music controller hold `OOMusic` as `oo::Ref<OOMusic>`.

## Why

The player and the universe are the two classes nearly every other file messages, and the
player's methods override `ShipEntity`'s, so both had to wait for step 12. The player starts with
its state alone because its methods are spread over the class file and nine category files: moving
the ivars first lets every category keep compiling, and the player's method slices follow in
step 14. The universe's slices are independent of the player's, so they land in the same step.

## Behaviour changes

- The debug-only `dumpGrayAlphaToFileNamed` (`cxx::MyOpenGLView`, in `src/SDL/MyOpenGLView.mm`;
  its caller `OODumpPixMap` is `#ifndef NDEBUG`) made its RGBA surface over the caller's
  two-byte-a-pixel buffer and wrote four bytes a pixel into it, overwriting the source and running
  past its end on the last row. It now makes its own surface, as `dumpGrayToFileNamed` already did.
  The bug is in upstream too. Pinned by `dumpGrayAlphaLeavesTheCallersBytes` in
  `tests/unit/core/test_MyOpenGLView.mm`.

## How to review

For the Universe part, start with `src/Core/Universe.h` (`cxx::Universe`, inside `namespace cxx`)
and `Universe+ObjCBridge.h/.mm` (the bridge's forwarders). `Universe.mm`'s bodies are the
Objective-C ones with message syntax rewritten; `tests/unit/core/test_Universe.mm` has one block of
cases per slice, written against the Objective-C API. Spot-check a few methods with
`git diff --word-diff -w seriesb/012-shipentity-slices seriesb/013-universe-player-slices -- src/Core/Universe.mm`.
Slice 26 opens `namespace cxx` before its `#if OO_LOCALIZATION_TOOLS`, not inside it, so deployment
builds (which set `OO_LOCALIZATION_TOOLS=0`) still compile.

For the PlayerEntity part, read `src/Core/Entities/PlayerEntity.h` (the data members, all
zero-initialised as the runtime zeroed the ivars) and `PlayerEntity+ObjCBridge.h`. The changes in
`PlayerEntityControls.mm` and the other categories are almost all the insertion of `_cxxPlayer->`
before an ivar name, which is mechanical:
`git diff seriesb/012-shipentity-slices seriesb/013-universe-player-slices -- src/Core/Entities/PlayerEntityControls.mm | grep '^+[^+]' | grep -v '_cxxPlayer->'`
shows the added lines that are anything else (three closing braces).
`tests/unit/core/test_PlayerEntity.mm` pins the player's answers against the Objective-C class.

For `OOJSPrivateObject`, read its header, then `OOJSTimer.mm`, and
`tests/unit/core/test_OOJSPrivateObject.mm`; `unrootedRunningTimerGC` in
`tests/unit/core/test_OOJSTimer.mm` covers the finalizer path the warning moved to (no test
checks whether the warning is logged). The Timer's object converter still answers the
Objective-C bridge, because Objective-C code holds and messages that.

The bridge deletions remove `X+ObjCBridge.*`, move `cxx::X` to the global namespace and turn the
remaining `[x foo]` sends into calls. Their tests move to the C++ class; the Test changes section
lists each changed check.

## Verified **(gen)**

Not verified at this branch's tip (`dafa48f08b`) yet: the last record is for `d9bf73afa4` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
