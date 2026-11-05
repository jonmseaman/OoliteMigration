# Delete the Objective-C bridges

**Series:** step 14 of 24 · base `seriesb/013-universe-player-slices` · next `seriesb/015-entity-facade` **(gen)**

**Replays:** `series/016-facade-deletions` (old 16 of the master-based series) · 49.8k src, 25.9k tests, 0 other changed lines; 22.0k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

The step has two parts.

First, the last Objective-C in the large classes becomes C++: the rest of `PlayerEntity.mm`, the
player's category files (`PlayerEntityContracts`, `Controls`, `KeyMapper`, `LegacyScriptEngine`,
`LoadSave`, `ScriptMethods`, `Sound`, `StickMapper`, `StickProfile`), `DockEntity` and
`ProxyPlayerEntity` (plain Objective-C classes until now), the rest of `OOJSShip.mm`, and the last
Objective-C class syntax in `Universe.mm`.

Then the Objective-C bridges whose last Objective-C caller is gone are deleted: the
`X+ObjCBridge.*` files of 64 classes (121 files) and `ShipEntity+ObjCAdapter.h`. Among them are
`ShipEntity`, `StationEntity`, `PlayerEntity`, `HeadUpDisplay`, `GuiDisplayGen`, `OOColor`,
`OOScript`, `OOJSScript`, `OOScriptTimer`, the planet, sun, sky, wormhole and waypoint, the
drawables, the sounds and the visual effects. Each deletion moves `cxx::X` to the global namespace
as `X` and turns the remaining `[x foo]` sends into C++ calls. 24 bridges remain (`Entity`,
`Universe`, `GameController`, `MyOpenGLView`, the JS engine, `AI`, the texture and material roots
and a few more). Step 15 deletes all of them but `OOWeakReference`'s, which goes in step 16.

The scripting layer is #768's QuickJS-ng binding, and its files are converted with the classes
they bind. The C++ objects that the binding keeps in a JS object's private slot (script, timer,
ship group, system info, equipment info, sound, sound source) use `OOJSCxxObjectWrapperFinalize`
and class-specific converters. The engine's own `OOJSObjectWrapperFinalize` and
`OOJSBasicPrivateObjectConverter` keep #768's Objective-C form until step 16 converts the engine.

Upstream changes kept in the converted code:

- #740: a new game reads the last save name back from the `last_savename` default. The new case
  `lastsaveNameIsRememberedInTheDefaults` in `tests/unit/core/test_PlayerEntity.mm` pins it.
- #749/#751 (clang-format): the GUI screens' `a | b | c | d` key reads become
  `AnyKeyPressed({ a, b, c, d })` in `PlayerEntityControls.mm`. It still reads every key, as the
  bitwise OR did, without the `|` between bools that Clang flags once the operators are spaced.
- #756: the converted debug-monitor code stays under `OO_DEBUG_MONITOR_ENABLED`, and the entity
  shader-binding table, which moves into `Entity+ObjCBridge.mm`, keeps the guard of
  `OOShaderUniformMethodType.h` (`OO_SHADERS || defined(OO_DEBUG_MONITOR_ENABLED)`).

New tests: `test_DockEntity`, `test_OOJSShip` and `test_ProxyPlayerEntity`.

## Why

A bridge can go only when nothing sends Objective-C messages to its class any more. For the entity
classes that happened only once the player, the universe and the JS ship binding, their heaviest
callers, were C++. So this step comes straight after the last slices. The deletions run from the
leaves to the roots: the subclasses' bridges go here, and `Entity`'s own bridge, with the other
roots, waits for step 15.

## Behaviour changes

None. The step keeps two behaviours that the deletions could easily lose, and tests pin both:

- The player and the proxy player stay visible to scripts: `playerAndProxyAreVisibleToScripts` in
  `tests/unit/core/test_ProxyPlayerEntity.mm`.
- A station keeps its `Station` JS class: `stationAnswersTheStationJSClass` in
  `tests/unit/core/test_StationEntity.mm`.

## How to review

Read it in two parts. The conversions come first: `src/Core/Entities/PlayerEntity.h` and
`PlayerEntity.mm`, then the category files. As in step 12, the bodies are the Objective-C ones
with the message syntax rewritten. For a spot-check, use
`git diff --word-diff -w seriesb/013-universe-player-slices seriesb/014-facade-deletions -- src/Core/Entities/PlayerEntity.mm`.

The deletions are mechanical:
`git diff --stat --diff-filter=D seriesb/013-universe-player-slices seriesb/014-facade-deletions`
lists the removed files. For any one class, check three things: its `X+ObjCBridge.*` entries are
gone from its directory's `meson.build`, `namespace cxx` is gone from `X.h`, and the callers'
hunks only turn `[x foo:y]` into `x->foo(y)` and drop `oo::ToObjC` / `oo::ToCxx` crossings.

The tests change the same way. Cases that tested a bridge itself (forwarding, one bridge per
object) are removed, the tests' Objective-C stand-ins become C++, and the other cases are
re-spelled for the C++ API.

`Entity+ObjCBridge.mm` grows by about 6,700 lines. The subclasses' methods that AI scripts, shader
bindings and the JS glue still call by selector name move there, as
`Entity (...SelectorsCalledByName)` categories that forward to the C++ ship, player, station, dock
or visual effect. Step 15 turns them into C++ tables.

## Verified **(gen)**

Not verified at this branch's tip (`aec817ac82`) yet: the last record is for `ee94df4a1b` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
