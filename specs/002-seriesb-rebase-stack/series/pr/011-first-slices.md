# Convert the large files in slices; delete the first Objective-C facades

**Series:** step 11 of 25 · base `seriesb/010-module-conversions` · next `seriesb/012-shipentity-slices` **(gen)**

**Replays:** `series/013-first-slices` (old 13 of the master-based series) · 26.2k src, 12.9k tests, 51 other changed lines; 5.1k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step does two separate kinds of work.

**Large files converted in slices.** Files too big to convert in one change are converted a group of
methods at a time, each group (a "slice") small enough to check on its own. These files finish
here, each as a C++ class with an `X+ObjCBridge` facade for its remaining Objective-C callers:
- `HeadUpDisplay`, `OOMesh`, `OOOXZManager`, `ResourceManager`;
- `MyOpenGLView`, `OOJavaScriptEngine`;
- `OOOXPVerifier`, `OOJSScript`, `OOJSSystem`, `OOJSPlayerShip`, `OOJSSpecialFunctions` (now
  `.cpp`).

`ShipEntity` only starts. Its state (every ivar) moves to `cxx::ShipEntity`, and its Objective-C
interface moves, copied exactly, to `ShipEntity+ObjCBridge.h`. Most methods keep their Objective-C
bodies for now and read the state through `_cxxShip->`. Later slices, in step 14, move them across
one group at a time. `PlayerEntityStickProfile` is partly converted the same way.

**Facade deletions.** 30 facades from steps 11–12 are deleted, because no Objective-C code messages
those classes any more. Each class leaves `namespace cxx`, and its callers use it directly:
- Materials: `OOBasicMaterial`, `OOConcreteTexture`, `OODefaultShaderSynthesizer`,
  `OOMaterialConvenienceCreators`, `OOMultiTextureMaterial`, `OONullTexture`, `OOShaderMaterial`,
  `OOShaderUniform`, `OOSingleTextureMaterial`;
- audio: `OOALBufferedSound`, `OOALSoundChannel`, `OOALSoundMixer`, `OOALStreamedSound`;
- OXP verifier: `OOOXPVerifierStage`, `OOPListSchemaVerifier` and four stages;
- others: `OOJoystickProfile`, `OORegExpMatcher`, `OOMeshToOctreeConverter`, `OOECMBlastEntity`,
  `OOPListScript`, and six `OOJS*` binding categories.

## Why

Steps 11 and 12 converted everything that the large files depend on, so the large files can now
follow. They come before `PlayerEntity` and `Universe` (steps 14–15) because those two message
them most. The facade deletions belong here because converting the large files removed the last
Objective-C callers of those classes. Deleting each facade as soon as it has no caller keeps the
two-headed state short-lived.

## Behaviour changes

- Windows debug builds: a paused game no longer drops into efficiency mode (`IDLE_PRIORITY_CLASS`)
  while a debug console is connected. On a loaded machine that mode left a console-driven game
  answering one command every 15–60 s. Pinned by `tests/component/test_paused_console_priority.py`.
- Linux/X11, not built or verified here: upstream's fix for the blank window (#774), which replaces
  the splash window with a new game window sharing its GL context, is not in this step. The C++
  `MyOpenGLView` keeps the old splash window. Step 25 ports #774. No test pins this.
- macOS only, not built or verified here: upstream's front-buffer screenshot path (#766) is not in
  this step. Step 25 restores it.

## How to review

Review the two parts separately.

For the slices, start with `src/Core/Entities/ShipEntity+ObjCBridge.h`. Its header comment
describes the split state:
- `cxx::ShipEntity` (in `ShipEntity.h`) holds the members by their old names;
- the facade keeps the old interface and one borrowed pointer, `_cxxShip`;
- each slice gets its bodies back verbatim by deleting `_cxxShip->`.

So most of the 4,000-line `ShipEntity.mm` hunk, and the `ShipEntityAI.mm` and `PlayerEntity.mm`
hunks, are `_cxxShip->` / `->_cxxShip->` insertions. To spot-check, strip that prefix
from a hunk and compare with the base. The fully converted files read like step 11's classes: check
`HeadUpDisplay.mm` against its base `@implementation` method by method, and read
`tests/unit/core/test_HeadUpDisplay.mm`. Each of the 11 converted files has a matching test in
`tests/unit/core`.

`OOOXZManager.mm` also has to carry upstream's copy-URL key (`n_key_oxzmanager_copyurl`,
`-setOXPURL:`, `-processCopyUrlKey`). In the converted class those are the members
`setOXPURL(const std::optional<std::string>&)` and `processCopyUrlKey()`, with
`std::optional<std::string> _currentOXPURL`. Check them against the base's Objective-C.

For the deletions, each one is mechanical (git's rename detection pairs
`OOJSSpecialFunctions+ObjCBridge.mm` with the deleted `OOModelVerifierStage+ObjCBridge.mm`; they
are unrelated):
- the two bridge files and their `meson.build` line go;
- `namespace cxx { ... }` goes from the header;
- callers lose their `oo::ToObjC` / `oo::ToCxx` crossings.

`git grep` for the deleted facade's class name in a message send (`[X ` or `[x foo]` on that type)
should find nothing.

The `GameController.mm` hunk is the priority change, debug builds only (`#ifndef NDEBUG`).

## Differences from the old step **(gen)**

None: the same change as `series/013-first-slices`.

## Verified **(gen)**

Windows x64, `4ca2448d62`, 2026-11-02.

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
| warnings_clang | pass: 0 new warnings (3 inherited from the parent, 4 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
