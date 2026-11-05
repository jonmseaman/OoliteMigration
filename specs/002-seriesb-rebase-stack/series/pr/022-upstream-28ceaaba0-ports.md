# Port upstream #783 (joystick control of GUI screens); build the macOS bundle without Foundation

**Series:** step 22 of 24 · base `seriesb/021-c-as-cxx` · next `seriesb/023-google-style-format` **(gen)**

**Replays:** `series/025-upstream-49a5eb9fc-ports` (old 25 of the master-based series) · 436 src, 234 tests, 42 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Two things. Upstream's #783 (`28ceaaba0`: `82705fe48` and `38aa005d3`), written against the C++
code, with one fix; and the macOS packaging and version files for the tree without Foundation.
The other recent upstream PRs (#766, #774, #781 and the rest) are not in this step: each is
already in the step that converts or writes the code it touches.

- #783, joystick control of GUI screens: `OOJoystickManager` gains `BUTTON_GUILEFT` ..
  `BUTTON_GUISELECT` and a GUI button table of their own (`guiButtonFunctions()`,
  `setGuiFunctionForButton()`, `unsetGuiButtonFunction()`), saved and loaded under
  `GuiJoystickButs`. `OOSDLJoystickManager`'s button decoder also sets the GUI button's state
  (the decoders are there since #742). `PlayerEntityControls`, `PlayerEntityKeyMapper`,
  `PlayerEntityLoadSave` and `PlayerEntityStickMapper` take the GUI buttons where they take the
  GUI keys, and the stick mapper lists and assigns them; `descriptions.plist` has their strings.
  #783's `!NEW_PLANETS` game-options hunk has no C++ counterpart (that block is not in the C++
  code).
- One deviation from #783: `clearMappings()` resets the GUI table with the axis and button tables.
  In #783 it does not, so the table starts all 0, which is `BUTTON_INCTHRUST`: every button
  without a GUI function also drives increase-thrust, `guiButtonFunctions()` saves a `"0"` entry
  for the last stick's last button, and loading it binds increase-thrust to that button in the
  flight table. Upstream may want to take this fix.
- #783's tests: `guiFunctionsHaveATableOfTheirOwn`, `decodesGuiButtons` and
  `savesAndLoadsGuiButtons` in `test_OOJoystickManager`, and `decodesGuiButtonsFromSDL` in
  `test_OOSDLJoystickManager`. The two decoding tests send SDL's event types through the test's
  `OOSDLJoystickManager` subclass (`NewDecodingManager()`), since #742 moved the decoders there.
- Version 1.95 in the Debug OXP's `manifest.plist` and in `Info-gnustep.plist`;
  `Resources/InfoPlist.strings` is stored as UTF-8 (`.gitattributes` keeps it UTF-16LE with a BOM
  on disk) with the same version.
- macOS, for the tree without Foundation: `src/meson/darwin/meson.build` links only the OpenGL
  framework (upstream's `-DOOLITE_SDL_MAC=1` and `-g` kept); `install_packages.sh` installs ICU
  (`icu4c`), and `darwin.ini` adds its `pkg-config` path and has no `objc` compiler;
  `post_build.sh` keeps `Info-gnustep.plist` in the bundle, since the C++ code reads that file at
  run time where upstream read `NSBundle`'s Info dictionary; `bundle_dylibs()` finds a library's
  `@loader_path` siblings next to the original (ICU's `libicui18n` and `libicudata`).
- The test harness on macOS: the component console runs the game in a real window (SDL's
  offscreen driver has no OpenGL there) and finds the binary under `Contents/MacOS`;
  `tests/launch_snapshot.py` stages and runs an app bundle.

## Why

#783 changes code that the earlier steps have already converted, so it is ported here onto the
C++ code, once. The macOS files are what a macOS build of the converted tree needs: it has no Foundation
and uses ICU through `oofnd`.

## Behaviour changes

- Joystick buttons can be assigned to the GUI functions and drive GUI screens (#783). Pinned by
  `test_OOJoystickManager`'s `guiFunctionsHaveATableOfTheirOwn`, `decodesGuiButtons` and
  `savesAndLoadsGuiButtons`, and `test_OOSDLJoystickManager`'s `decodesGuiButtonsFromSDL`. The
  screens' handling of the GUI buttons (`PlayerEntityControls`, the mappers, load and save) is
  not pinned by a test.
- Against #783 as upstream has it: a button with no GUI function drives no GUI or thrust state,
  and saving and loading the joystick settings keeps the increase-thrust binding. Pinned by
  `decodesGuiButtons` (no `BUTTON_INCTHRUST` from unassigned buttons),
  `guiFunctionsHaveATableOfTheirOwn` (`clearMappings()` empties the GUI table) and the existing
  `savesAndLoadsSettings`, which fails without the fix.
- The version reads 1.95. Not pinned by a test.
- macOS packaging (ICU, the bundle's `Info-gnustep.plist`, `@loader_path` siblings) and the macOS
  harness: not pinned by a test, and not verified by this series.

## How to review

Compare the joystick code with upstream's `82705fe48` and `38aa005d3`: `git diff
seriesb/021-c-as-cxx seriesb/022-upstream-28ceaaba0-ports -- src Resources/Config`. The
`clearMappings()` fix is five lines in `OOJoystickManager.cpp`, with its comment. The tests are
additions only (`test_OOJoystickManager.cpp` +171, `test_OOSDLJoystickManager.cpp` +35); no
existing assertion changes. The macOS files are small and are only used by a macOS build.

## Verified **(gen)**

Not verified at this branch's tip (`c04d10b0b9`) yet: the last record is for `3ff3867320` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
