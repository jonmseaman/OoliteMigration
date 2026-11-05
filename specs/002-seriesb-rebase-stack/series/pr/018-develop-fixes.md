# Small fixes after the migration

**Series:** step 18 of 24 · base `seriesb/017-gcc-build` · next `seriesb/019-source-hygiene` **(gen)**

**Replays:** `series/021-develop-fixes` (old 21 of the master-based series) · 276 src, 355 tests, 9 other changed lines; 0 lines in deleted files **(gen)**

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

## Why

A header that compiles only after its includer has included something else breaks as soon as a
formatter sorts includes, which step 23 (`seriesb/023-google-style-format`) does. The headers suite
finds such headers and keeps them fixed; the `OOJSEngineNativeWrappers.h` declarations are what it
found in #768's code. For the maths headers the step follows #748, which made them includable on
their own, and adds `OOMathsBase.h` so that each one gets the shared definitions without going
through `OOMaths.h`.

## Behaviour changes

None. The changes are to includes and declarations, tests and comments; the game's code is the
same. `test_OOMathsHeaders` pins the standalone maths headers, the `headers` suite the rest.

## How to review

Start with `src/Core/OOMathsBase.h` against the lines `OOMaths.h` loses (a move), then the include
lines at the top of each maths header. The other header changes are one or three lines each.
`tests/check_headers_standalone.py` is new; its `FRAGMENTS` table lists the few headers that are
not standalone by design, each with the reason. The path changes in READMEs and the GUI and
component tiers are mechanical. `test_objc_assert.cpp`'s diff is layout (rewrapped comments,
braces, include order) apart from the `clang-format off`/`on` pair; its checks are unchanged.

## Verified **(gen)**

Not verified at this branch's tip (`ad4601e061`) yet: the last record is for `a83f7ad720` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
