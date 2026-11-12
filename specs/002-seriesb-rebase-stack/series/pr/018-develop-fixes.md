# Small fixes after the migration

**Series:** step 18 of 26 · base `seriesb/017-gcc-build` · next `seriesb/019-source-hygiene` **(gen)**

**Replays:** `series/021-develop-fixes` (old 21 of the master-based series) · 276 src, 355 tests, 30 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- **Self-contained maths headers, in #748's form.** `OOMathsBase.h` (new) holds what `OOMaths.h`
  used to define before its sub-headers: the standard includes, the OpenGL types, `OOScalar` and
  `OOHPScalar`, the `M_*` constants and `MIN`/`MAX`/`ABS`. `OOVector.h`, `OOFastArithmetic.h`,
  `OOHPVector.h`, `OOQuaternion.h`, `OOMatrix.h`, `OOBoundingBox.h`, `OOTriangle.h` and `OOVoxel.h`
  each include it and the maths headers they use, and gain `#pragma once` where they had none.
  `OOMaths.h` now just includes them all. `tests/unit/core/test_OOMathsHeaders.cpp` includes three
  of them without `OOMaths.h` and uses their inline functions.
- **Other headers include what they use.** `EntityHelpers.h` includes `Entity.h`;
  `OOPointMaths.h` includes `oofnd/objc/OOFoundationTypes.h` for `NSPoint`;
  `OOJSEngineNativeWrappers.h` (#768's) declares `OOJSPauseTimeLimiter` and
  `OOJSResumeTimeLimiter`, which its `OOJSFullNativeScope` calls.
- **A `headers` test suite.** `tests/check_headers_standalone.py` compiles every header the build
  uses on its own, with the compile command of a source file that includes it
  (`meson test --suite headers`; Windows only, like the unit suites, and not in a
  `deployment_release` build).
- **Paths.** READMEs, comments and the GUI tier's build lookup (`tests/gui/conftest.py`,
  `tests/source_paths.py`) that assumed the game's checkout sat at `upstream/oolite/` inside a
  larger workspace now assume `oolite-dev/`.
- **`test_objc_assert.cpp`** takes the 80-column layout, with its two one-line helpers that record
  `__LINE__` kept on one line under `clang-format off`, so the line they record stays the
  assertion's.
- **macOS packaging.** `darwin.ini` adds Homebrew's keg-only `icu4c` to `pkg_config_path` and
  `ShellScripts/macOS/install_packages.sh` installs it, because oofnd needs `icu-uc` and
  `icu-i18n`. `ShellScripts/common/post_build.sh` keeps `Resources/Info-gnustep.plist` in the app
  bundle, since the game reads its version from it.

## Why

A header that compiles only after its includer has included something else breaks as soon as a
formatter sorts includes, which step 23 (`seriesb/023-google-style-format`) does. The headers suite
finds such headers and keeps them fixed; the `OOJSEngineNativeWrappers.h` declarations are what it
found in #768's code. For the maths headers the step follows #748, which made them includable on
their own, and adds `OOMathsBase.h` so that each one gets the shared definitions without going
through `OOMaths.h`. The macOS packaging lines are what a fresh macOS configure and app bundle
need once oofnd and the converted version lookup are in.

## Behaviour changes

- The macOS app bundle keeps `Resources/Info-gnustep.plist`. Without it the version is null,
  every resource directory is refused as incompatible and the game exits for want of
  `descriptions.plist`. No test pins it; macOS is not verified by this series.

Otherwise none. The other changes are to includes and declarations, tests and comments; the game's
code is the same. `test_OOMathsHeaders` pins the standalone maths headers, the `headers` suite the
rest.

## How to review

Start with `src/Core/OOMathsBase.h` against the lines `OOMaths.h` loses (a move), then the include
lines at the top of each maths header. The other header changes are one or three lines each.
`tests/check_headers_standalone.py` is new; its `FRAGMENTS` table lists the few headers that are
not standalone by design, each with the reason. The path changes in READMEs and the GUI and
component tiers are mechanical. `test_objc_assert.cpp`'s diff is layout (rewrapped comments,
braces, include order) apart from the `clang-format off`/`on` pair; its checks are unchanged. The
macOS packaging is one line each in `darwin.ini`, `install_packages.sh` and `post_build.sh`.

## Verified **(gen)**

Not verified at this branch's tip (`e40ed2d9fd`) yet: the last record is for `a83f7ad720` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
