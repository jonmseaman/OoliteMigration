# Convert Universe and PlayerEntity to C++

**Series:** step 14 of 25 · base `series/013-shipentity-slices` · next `series/015-facade-deletions` **(gen)**

**Chapter:** P3 · 3.7 PlayerEntity slices, 3.8 Universe slices · history `4b272b165e`..`33abe86219` (40 merges) · 17.7k src, 3.6k tests, 0 other changed lines; 1.2k lines in deleted files **(gen)**

## What this changes

Two pieces of work share this step.

- **Universe slices.** Slices 2 to 26 of `Universe.mm` move into `cxx::Universe`, whose shell came
  in step 13: set-up of space and the system populator, adding ships by role and position,
  witchspace, the main station and beacons, drawing and the view frustum, the entity lists,
  targeting and collisions, `update:`, the shipyard, markets, routes, system data and
  descriptions, speech and message logs, sounds and wormholes.
- **PlayerEntity slice 1.** The player's state moves to a new `cxx::PlayerEntity : cxx::ShipEntity`,
  as public data members with the ivars' names. The Objective-C `PlayerEntity` (now in
  `PlayerEntity+ObjCBridge.h`) keeps all of its methods for now, and they and the categories
  (`PlayerEntityControls.mm`, `PlayerEntityContracts.mm`, `PlayerEntityLoadSave.mm` and the
  others) reach the state as `_cxxPlayer->name`.

The range also deletes five facades whose last Objective-C caller had gone
(`OOExhaustPlumeEntity`, `OOFlasherEntity`, `OOTextureSprite`, `OOJSFunction`,
`OOCombinedEmissionMapGenerator`), converts `StationEntity`'s NPC launchers,
`MyOpenGLView+Input.mm` and `OOLegacyScriptWhitelist.mm`, adds `OOJSPrivateObject` (C++ objects in
a JS object's private slot), and has the music controller hold `OOMusic` as C++.

## Why

The player and the universe are the two classes nearly every other file messages, and the
player's methods override `ShipEntity`'s, so both had to wait for step 13. The player starts with
its state alone because its methods are spread over the class file and nine category files: moving
the ivars first lets every category keep compiling, and the player's method slices follow in
step 15. The universe's slices are independent of the player's, so they land in the same step.

## Behaviour changes

- The debug-only `dumpGrayAlphaToFileNamed:` (in `src/SDL/MyOpenGLView.mm`) made its RGBA surface
  over the caller's two-byte-a-pixel buffer and wrote four bytes a pixel into it, overwriting the
  source and running past its end on the last row. It now makes its own surface, as
  `dumpGrayToFileNamed:` already did. The bug is in upstream too. Pinned by
  `dumpGrayAlphaLeavesTheCallersBytes` in `tests/unit/core/test_MyOpenGLView.mm`.

## How to review

For the Universe part, start with `src/Core/Universe.h` (`cxx::Universe`, inside `namespace cxx`)
and `Universe+ObjCBridge.h/.mm` (the facade's forwarders). `Universe.mm`'s bodies are the
Objective-C ones with message syntax rewritten; `tests/unit/core/test_Universe.mm` has one block of
cases per slice, written against the Objective-C API first. Spot-check a few methods with
`git diff --word-diff -w series/013-shipentity-slices series/014-universe-player-slices -- src/Core/Universe.mm`.

For the PlayerEntity part, read `src/Core/Entities/PlayerEntity.h` (the data members, all
zero-initialised as the runtime zeroed the ivars) and `PlayerEntity+ObjCBridge.h`. The changes in
`PlayerEntityControls.mm` and the other categories are almost all the insertion of `_cxxPlayer->`
before an ivar name, which is mechanical: `git diff series/013-shipentity-slices series/014-universe-player-slices -- src/Core/Entities/PlayerEntityControls.mm | grep '^+' | grep -vc '_cxxPlayer->'`
counts the added lines that are anything else (four). `tests/unit/core/test_PlayerEntity.mm`
pins the player's answers against the Objective-C class.

The facade deletions remove `X+ObjCBridge.*`, move `cxx::X` to the global namespace and turn the
remaining `[x foo]` sends into calls; their tests drop only the facade's own cases.

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
