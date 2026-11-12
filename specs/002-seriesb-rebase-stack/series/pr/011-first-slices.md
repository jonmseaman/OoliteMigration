# Convert the large files in slices; delete the first Objective-C bridges

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 11 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/013-first-slices`.

## What this changes

This step does two separate kinds of work.

**Large files converted.** Files too big to convert in one change are converted a group of methods
at a time, each group (a "slice") small enough to check on its own. Ten classes finish here, each
as a C++ class `cxx::X` with an Objective-C bridge (`X+ObjCBridge.h/.mm`) for its remaining
Objective-C callers:
- `HeadUpDisplay`, `OOMesh`, `OOOXZManager`, `ResourceManager`, `MyOpenGLView`, `OOOXPVerifier`;
- four of #768's binding files: `OOJavaScriptEngine`, `OOJSScript`, `OOJSSystem`, `OOJSPlayerShip`.

The engine is `cxx::OOJavaScriptEngine`, with #768's members and runtime. Its bridge keeps #768's
selectors and is the object that posts the engine's reset notifications, so `oo::ToObjC(engine)`
always answers the same object. The converted engine and error reporter keep #768's current
behaviour: errors and exceptions always reach the debug monitor (only an ignored warning stops
early), a stack frame's location is read from its first `(`, and the non-SpiderMonkey globals are
removed when the context is set up. `OOJSSpecialFunctions.mm`, which has no Objective-C left, becomes
`.cpp` with no bridge; it keeps #768's `JSSpecialFunctionsObjectWrapper`.

`ShipEntity` only starts. Its state (every ivar) moves to `cxx::ShipEntity`, and its Objective-C
interface moves, copied exactly, to `ShipEntity+ObjCBridge.h`. Its methods keep their Objective-C
bodies for now and read the state through `_cxxShip->`; step 12 moves them across one slice at a
time. `StickProfileScreen` (in `PlayerEntityStickProfile.h`) becomes `cxx::StickProfileScreen` with
no bridge, since the player is its only caller; the player's `StickProfile` category stays
Objective-C.

Three plain-C++ headers are split out so that C++ files can use them without Objective-C:
`OOCPUInfoEndian.h`, `OOOpenGLCheck.h` and `OOOpenGLExtensionPointers.h`.

Upstream changes already in the parent are kept in the converted code: #747's copy-URL key in
`OOOXZManager`, #774's replacement of the splash window by a new game window sharing its GL
context, and #766's front-buffer snapshot on macOS, both in `MyOpenGLView`.

**Bridge deletions.** 30 bridges from steps 9–10 are deleted, because no Objective-C code messages
those classes any more. Each class leaves `namespace cxx`, and its callers use it directly:
- materials: `OOBasicMaterial`, `OOConcreteTexture`, `OODefaultShaderSynthesizer`,
  `OOMaterialConvenienceCreators`, `OOMultiTextureMaterial`, `OONullTexture`, `OOShaderMaterial`,
  `OOShaderUniform`, `OOSingleTextureMaterial`;
- audio: `OOALBufferedSound`, `OOALSoundChannel`, `OOALSoundMixer`, `OOALStreamedSound`;
- OXP verifier: `OOOXPVerifierStage`, `OOPListSchemaVerifier` and four stages (check ship data,
  file scanner, model, texture);
- others: `OOJoystickProfile`, `OORegExpMatcher`, `OOMeshToOctreeConverter`, `OOECMBlastEntity`,
  `OOPListScript`, and the six `OOJS*+ObjCBridge.mm` categories of #768's binding (exhaust plume,
  flasher, planet, sun, waypoint, wormhole).

## Why

Steps 9 and 10 converted everything that the large files depend on, so the large files can now
follow. They come before `ShipEntity`, `Universe` and `PlayerEntity` (steps 12–13) because those
message them most. The bridge deletions belong here because converting the large files removed the
last Objective-C callers of those classes. Deleting each bridge as soon as it has no caller keeps
the two-headed state short-lived.

## Behaviour changes

- Windows builds with the debug console (`OO_DEBUG_MONITOR_ENABLED`, which deployment builds also
  set): a paused game no longer drops into efficiency mode (`IDLE_PRIORITY_CLASS`) while a debug
  console is waiting on it. On a loaded machine that mode left a console-driven game answering one
  command every 15–60 s. Pinned by `test_a_paused_game_with_a_console_keeps_normal_priority` in
  `tests/component/test_paused_console_priority.py`.

## How to review

Review the two parts separately.

For the slices, start with `src/Core/Entities/ShipEntity+ObjCBridge.h`. Its header comment
describes the split state:
- `cxx::ShipEntity` (in `ShipEntity.h`) holds the members by their old names;
- the bridge keeps the old interface and one borrowed pointer, `_cxxShip`;
- each slice gets its bodies back verbatim by deleting `_cxxShip->`.

So most of the 4,000-line `ShipEntity.mm` hunk, and the `ShipEntityAI.mm` and `PlayerEntity.mm`
hunks, are `_cxxShip->` / `->_cxxShip->` insertions. In `ShipEntity.mm`, 26 of the 2,074 added lines
are anything else:
`git diff seriesb/010-module-conversions seriesb/011-first-slices -- src/Core/Entities/ShipEntity.mm | grep '^+[^+]' | grep -v '_cxxShip->'`.

The fully converted files read like step 9's classes: check `HeadUpDisplay.mm` against its base
`@implementation` method by method, and read `tests/unit/core/test_HeadUpDisplay.mm`. Nine of the
converted classes get a new test in `tests/unit/core` (`test_X.mm`, plus `test_ShipEntity.mm` and
`test_PlayerEntityStickProfile.mm`); `OOJSScript` extends its existing `test_OOJSScript.mm`, and
`OOJSSpecialFunctions`, a two-line change, has no test of its own.

In `OOOXZManager.mm`, #747's `-setOXPURL:` and `-processCopyUrlKey` are the members
`setOXPURL(const std::optional<std::string>&)` and `processCopyUrlKey()`, with
`std::optional<std::string> _currentOXPURL`; the new case `copyUrlKey` in
`tests/unit/core/test_OOOXZManager.mm` covers them. Check them against the base's Objective-C.

Two test checks are worth knowing about. In `test_OOJavaScriptEngine.mm`, converting a plain
`OOObject` (no JS glue) gives a non-object and leaves an exception pending, because #768 boxes
`undefined` with `JS_ToObject`; the test checks `!JS_IsObject(...)` and clears the exception.
`test_OOMaterialConvenienceCreators.mm` binds `*material.get()` to a reference before `typeid`,
because the direct form warns (`-Wpotentially-evaluated-expression`).

For the deletions, each one is mechanical:
- the two bridge files and their `meson.build` line go;
- `namespace cxx { ... }` goes from the header;
- callers lose their `oo::ToObjC` / `oo::ToCxx` crossings.

`git grep` for a deleted bridge's class name in a message send (`[X ` or `[x foo]` on that type)
should find nothing.

The `GameController.mm` hunk is the priority change, under `OO_DEBUG_MONITOR_ENABLED`.

## Verified **(gen)**

Not verified at this branch's tip (`c245c5da16`) yet; the last record (2026-11-02) is for an earlier build.
