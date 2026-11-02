# Port upstream changes #369 to #765 into the C++ code

**Series:** step 20 of 26 · base `series/019-gcc-build` · next `series/021-develop-fixes` **(gen)**

**Chapter:** P4 · upstream 9ee8ff22f pulled and ported · history `883d339f93`..`6504faa3b9` (4 merges) · 12.4k src, 303 tests, 45 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

The series' base is upstream master, so upstream's commits `dc55e3e05..9ee8ff22f` reached the
earlier steps through their conflict resolutions; where a hunk touched code the migration had
rewritten, those steps took it as upstream wrote it (in places still Objective-C) and kept the
migration's older `!NDEBUG` guards. This step finishes the port of each change into the C++ code:

- #740 the last save name: `setLastsaveName` writes `last_savename` through `oo::Defaults`, a new
  game reads it back, and the AppKit and custom load/save macros go.
- #744 the dark-mode declarations left in `MyOpenGLView.h` go.
- #747 the OXZ manager's copy-URL key: `OOOXZManager::setOXPURL` and `processCopyUrlKey` in C++.
- #748, #749, #751 clang-format: include order fixed where sorting would break it
  (`OOFoundation.h`, `OOTexture.cpp`), the generated tables marked `clang-format off`, and
  `a | b | c` over bools replaced by a small `AnyKeyPressed` helper.
- #756 debug-monitor code is guarded by `OO_DEBUG_MONITOR_ENABLED` instead of `!NDEBUG` in the
  code the migration wrote (about fifty guards), so the deployment build has the debug console and the OXP
  verifier, as upstream's does.
- #758, #765 build scripts, as upstream wrote them.
- #369 needs no source change (its fix is in a JS script); a new test runs it on QuickJS.

#737 (`OOCocoa` renamed `OOFoundation`), #742 (one `STICK_DEADZONE`) and #745 (renamed selectors,
none of which is left) were already complete in the earlier steps. Changes of the fork's own ride
along: `OOCAssert` and `OOAssert` are live in every build flavour; the unit tests are built in
every flavour but deployment, on Windows only; the Windows dependency script installs ICU (which
`oofnd` uses) and the LLVM archiver `clang.ini` names; and the packaging scripts no longer
require a GNUstep config file.

## Why

Upstream merged these while the migration was under way. Porting them in one step, after the code
is C++ and builds with both compilers, means each port is written once against the final shape of
the code, instead of once per intermediate Objective-C/C++ state. It comes before the remaining
steps so that they build on code that matches upstream's behaviour at `9ee8ff22f`.

Carried here: #369, #737, #740, #742, #744, #745, #747, #748, #749, #751, #756, #758, #765. Deferred
from this step: #766's macOS changes (the app-bundle resource path, the `GameController` Cocoa-UI
code and the front-buffer screenshot), which come back, dormant, in step 25 since macOS is not
converted; and #774 (the Linux/X11 blank window after the splash screen), also in step 25. #766's
plain-socket debug console client for macOS is not needed: the C++ client already uses a plain
socket on every platform, so this step removes the Mac-only copy. #742's move of the joystick
event decoders into `OOSDLJoystickManager` is not taken; the decoders stay in `OOJoystickManager`.

## Behaviour changes

- `OOCAssert`/`OOAssert` are no longer compiled out under `NDEBUG`. Upstream's
  `NS_BLOCK_ASSERTIONS` was defined too late to block Foundation's assertions, so upstream's
  deployment build always ran them, and one has a side effect the player's ship set-up needs; with
  the C++ macros compiled out, a deployment build could not launch. Pinned by
  `tests/unit/oofnd/test_objc_assert_ndebug.cpp`.
- #740: the last save name is written to and read from the user defaults. Pinned by
  `lastsaveNameIsRememberedInTheDefaults` in `tests/unit/core/test_PlayerEntity.cpp`.
- #747: the OXZ manager's info page keeps the add-on's URL (lowercased) and the copy-URL key puts
  it on the clipboard, instead of copying it as soon as the page opens. Pinned by `copyUrlKey` in
  `tests/unit/core/test_OOOXZManager.cpp`.
- #756: deployment builds include the debug-monitor code the migration had guarded by `NDEBUG`.
  No unit test runs a deployment build of the core suite yet.
- #369: pinned by `tests/unit/core/test_OoliteEquipmentControlScript.cpp`.

## How to review

Read it upstream PR by upstream PR. `src/Core/OOOXZManager.cpp` (#747),
`src/Core/Entities/PlayerEntity.cpp` and `PlayerEntity.h` (#740) and `src/oofnd/objc/OOAssert.h`
are the hunks to read closely. For #756,
`git diff series/019-gcc-build series/020-upstream-9ee8ff22f-port -- src | grep -n OO_DEBUG_MONITOR_ENABLED`
lists every guard that changed; each should be debug-monitor or console code.

Most of the line count is mechanical: `OOEntityCalledByNameTable.h`, `OOJSCallEntityMethods.h` and
`OOTypeEncodings.h` are generated. They change layout (each row's body on one line, the generator's own
spacing, kept out of clang-format) and lose the rows of the methods #740 removed;
`git diff --word-diff` on them shows the few content changes. `meson.build`'s unit-test conditions
and `.github/workflows/test_builds.yaml` set what CI builds. The workflow here is the migration's
at this point: it has no macOS job (macOS is not converted), and its Fedora job still packages an
AppImage, which upstream dropped in #782; a later step in the series removes it.

## Verified **(gen)**

Windows x64, `8bbb632453`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
