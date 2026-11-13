# Port upstream #783 (joystick control of GUI screens); build the macOS bundle without Foundation

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 22/28. Replays `series/025-upstream-49a5eb9fc-ports`.

## What this changes

- Adds #783's tests: `guiFunctionsHaveATableOfTheirOwn`, `decodesGuiButtons`,
  `savesAndLoadsGuiButtons` (`test_OOJoystickManager`) and `decodesGuiButtonsFromSDL`
  (`test_OOSDLJoystickManager`). The decoding tests go through `NewDecodingManager()`, since #742
  moved the decoders to `OOSDLJoystickManager`.
- #783's (`28ceaaba0`) and #786's code is already in C++ from step 016 (GUI button table,
  `guiButtonFunctions()`, `GuiJoystickButs`). Here 4 files only rewrap the lines #783 touched and
  drop the parentheses in `bool x = (a || b)`; one form changes: `displayFunctionList()`'s
  `default:` assigns the `HW_BUTTON` case's `bf` instead of declaring its own.
- Deviation from #783 (carried since step 016): `clearMappings()` also resets the GUI table.
  Without it the table starts at 0 (`BUTTON_INCTHRUST`), so unmapped buttons drive increase-thrust
  and a saved `"0"` entry binds it on load. Upstream may want this fix.
- Version 1.95 in the Debug OXP manifest, `Info-gnustep.plist` and `InfoPlist.strings` (stored
  UTF-8; `.gitattributes` keeps it UTF-16LE with a BOM on disk).
- macOS without Foundation: `darwin/meson.build` links only OpenGL, `darwin.ini` has no `objc`,
  `bundle_dylibs()` finds `@loader_path` siblings (ICU); the component console finds the binary
  under `Contents/MacOS`.

## Why

#783's code lives in the steps that convert its files; this step adds its tests and the version
and macOS files a Foundation-free macOS build needs.

## Behaviour changes

- Joystick: none beyond layout. Pinned by `guiFunctionsHaveATableOfTheirOwn`, `decodesGuiButtons`,
  `savesAndLoadsGuiButtons`, `decodesGuiButtonsFromSDL`; existing `savesAndLoadsSettings` fails
  without the `clearMappings()` fix.
- The version reads 1.95. Not pinned.
- macOS packaging (no Foundation, `@loader_path` siblings) and the console's bundle lookup. Not
  pinned, and not verified by this series.

## How to review

Tests are additions only (`test_OOJoystickManager.cpp` +171, `test_OOSDLJoystickManager.cpp`
+35). Check the source hunks are rewraps apart from the `bf` line and the dropped parentheses:
`git diff --word-diff seriesb/021-c-as-cxx seriesb/022-upstream-28ceaaba0-ports -- src/Core`.
The macOS files are used only by a macOS build.

## Verified

Not verified at `ea8c747b92`.
