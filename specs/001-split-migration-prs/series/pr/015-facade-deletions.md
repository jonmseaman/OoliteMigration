# Delete the Objective-C facades

**Series:** step 15 of 25 · base `series/014-universe-player-slices` · next `series/016-entity-facade` **(gen)**

**Chapter:** P3 · facade-deletion batches · history `d01d45e47c`..`2c2aae1316` (51 merges) · 50.3k src, 27.6k tests, 0 other changed lines; 22.1k lines in deleted files **(gen)**

## What this changes

The step first finishes the large classes: `PlayerEntity.mm` slices 2 to 28, the player's category
files (`PlayerEntityControls`, `KeyMapper`, `StickMapper`, `StickProfile`, `LegacyScriptEngine`,
`Contracts`, `LoadSave`, `Sound`), `ProxyPlayerEntity`, `OOJSShip.mm` slices 2 to 6, and the last
Objective-C class syntax in `Universe.mm`. It then deletes the Objective-C facades whose last
Objective-C caller is gone, about sixty of them (123 `+ObjCBridge` files), among them `ShipEntity`,
`StationEntity`, `DockEntity`, `PlayerEntity`, the proxy player, `HeadUpDisplay`, `GuiDisplayGen`,
`OOColor`, `OOScript`, `OOJSScript`, `OOScriptTimer`, the planet, sun, sky, wormhole and waypoint,
the drawables and the visual effects. Each deletion moves `cxx::X` to the global namespace as `X`
and turns the remaining `[x foo]` sends into C++ calls. A ship made from C++ (`oo::NewShipObject`,
`ProxyPlayerEntity::newProxyObject()`) now lives under the root `Entity` facade. About
twenty-five facades remain (`Entity`, `Universe`, `GameController`, `MyOpenGLView`, the JS engine,
`AI`, the texture and material roots and a few more); the next step removes all of them but
`OOWeakReference`'s, which goes in step 17.

## Why

A facade can go only when nothing sends Objective-C messages to its class any more, and for the
entity classes that happened only once the player, the universe and the JS ship binding (their
heaviest callers) were C++. So this step comes straight after the last slices, and the
deletions run leaves first and roots last: the ship's facade goes after the player's, station's
and dock's, and `Entity`'s own facade waits for step 16.

## Behaviour changes

None. Two regressions that intermediate commits in this range introduced are fixed within the
range, so neither is in the step: the player and the proxy player stay visible to scripts
(`tests/unit/core/test_ProxyPlayerEntity.mm`), and a station keeps its `Station` JS class
(`stationAnswersTheStationJSClass` in `tests/unit/core/test_StationEntity.mm`).

## How to review

Read it in two parts. The conversions first: `src/Core/Entities/PlayerEntity.h` and
`PlayerEntity.mm`, then the category files; as in step 13 the bodies are the Objective-C ones with
message syntax rewritten (`git diff --word-diff -w series/014-universe-player-slices series/015-facade-deletions -- src/Core/Entities/PlayerEntity.mm`
for a spot-check). The new cases in `tests/unit/core/test_PlayerEntity.mm` and `test_OOJSShip.mm`
were run on the Objective-C code first.

Then the deletions, which are mechanical: `git diff --stat --diff-filter=D series/014-universe-player-slices series/015-facade-deletions`
lists the facade files removed. For any one class, check that its `X+ObjCBridge.*` entries are
gone from its directory's `meson.build`, that `namespace cxx` is gone from `X.h`, and that the
callers' hunks only turn `[x foo:y]` into `x->foo(y)` and drop `oo::ToObjC` / `oo::ToCxx`
crossings. The test files change the same way: cases that tested a facade itself (forwarding,
one facade per object) are removed, the tests' Objective-C stand-ins become C++, and the other
cases are re-spelled for the C++ API. `Entity+ObjCBridge.mm` grows because the subclasses'
methods that are still called by selector name (AI scripts, shader bindings, the JS glue) move
there as `Entity (...SelectorsCalledByName)` categories forwarding to the C++ ship, player,
station, dock or visual effect.

## Verified **(gen)**

Not verified yet.

macOS (Phase 5: not converted) and Linux are not verified by this series.
