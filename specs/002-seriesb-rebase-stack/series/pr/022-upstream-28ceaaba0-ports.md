# Port upstream #783 (joystick control of GUI screens); build the macOS bundle without Foundation

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 22 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/025-upstream-49a5eb9fc-ports`.

## What this changes

Upstream's #783 (`28ceaaba0`: `82705fe48` and `38aa005d3`) and #786 are now in the base, and
the earlier steps already carry their code in C++: `OOJoystickManager`'s GUI button table
(`BUTTON_GUILEFT` .. `BUTTON_GUISELECT`, `guiButtonFunctions()`, saved under `GuiJoystickButs`),
the GUI buttons in `PlayerEntityControls` and the mappers, and the `clearMappings()` fix below
are there from step 016. So this step's own #783 port largely repeats what earlier steps carry;
its code is left as it is. What it adds:

- **#783's tests.** `guiFunctionsHaveATableOfTheirOwn`, `decodesGuiButtons` and
  `savesAndLoadsGuiButtons` in `test_OOJoystickManager`, and `decodesGuiButtonsFromSDL` in
  `test_OOSDLJoystickManager`. The two decoding tests send SDL's event types through the test's
  `OOSDLJoystickManager` subclass (`NewDecodingManager()`), since #742 moved the decoders there.
- **Layout of the #783 lines.** `PlayerEntityControls.cpp`, `PlayerEntityStickMapper.cpp`,
  `PlayerEntityLoadSave.cpp` and `OOJoystickManager.cpp` rewrap the lines the port touched, and
  `bool x = (a || b)` loses its parentheses. One form changes: in `displayFunctionList()` the
  `default:` branch assigns the `bf` that the `HW_BUTTON` case declares instead of declaring its
  own (upstream declares `int bf` in both).
- **Version 1.95** in the Debug OXP's `manifest.plist` and in `Info-gnustep.plist`;
  `Resources/InfoPlist.strings` is stored as UTF-8 (`.gitattributes` keeps it UTF-16LE with a BOM
  on disk) with the same version.
- **macOS, for the tree without Foundation.** `src/meson/darwin/meson.build` links only the OpenGL
  framework (upstream's `-DOOLITE_SDL_MAC=1` and `-g` kept); `darwin.ini` has no `objc` compiler;
  `bundle_dylibs()` finds a library's `@loader_path` siblings next to the original (ICU's
  `libicui18n` and `libicudata`). The component console finds the binary under `Contents/MacOS`
  when the build is an app bundle.

The deviation from #783 that the earlier steps carry: `clearMappings()` resets the GUI table with
the axis and button tables. In #783 it does not, so the table starts all 0, which is
`BUTTON_INCTHRUST`: every button without a GUI function also drives increase-thrust,
`guiButtonFunctions()` saves a `"0"` entry for the last stick's last button, and loading it binds
increase-thrust to that button in the flight table. Upstream may want to take this fix.

## Why

#783 changed code that the earlier steps convert, so its C++ is in the step that converts each
file; what is left for this step is #783's tests, which pin both upstream's behaviour and the
fix, and the version and macOS files a macOS build of the converted tree needs (no Foundation, ICU
through `oofnd`). Jon's default is to leave this step's code as it is rather than fold it into the
earlier steps.

## Behaviour changes

- None in the joystick code: it is the earlier steps', unchanged here apart from layout. The new
  tests pin it: `guiFunctionsHaveATableOfTheirOwn` (the GUI table is separate, and
  `clearMappings()` empties it), `decodesGuiButtons` (GUI buttons decode, and unassigned buttons
  set no `BUTTON_INCTHRUST`), `savesAndLoadsGuiButtons`, and `decodesGuiButtonsFromSDL`. The
  existing `savesAndLoadsSettings` fails without the `clearMappings()` fix.
- The version reads 1.95. Not pinned by a test.
- macOS packaging (no Foundation, `@loader_path` siblings) and the component console's bundle
  lookup: not pinned by a test, and not verified by this series.

## How to review

The tests are additions only (`test_OOJoystickManager.cpp` +171, `test_OOSDLJoystickManager.cpp`
+35); no existing assertion changes. `git diff --word-diff seriesb/021-c-as-cxx
seriesb/022-upstream-28ceaaba0-ports -- src/Core` shows the source hunks are rewraps, apart from
the `bf` line in `PlayerEntityStickMapper.cpp` and the dropped parentheses. The version and macOS
files are small; the macOS ones are only used by a macOS build.

## Verified **(gen)**

Not verified at this branch's tip (`ea8c747b92`) yet; the last record (2026-11-03) is for an earlier build.
