# Small fixes after the migration

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 18/28. Replays `series/021-develop-fixes`.

## What this changes

- New `src/Core/OOMathsBase.h` holds `OOMaths.h`'s shared definitions; the 8 maths sub-headers
  include it and what they use, gain `#pragma once`, and `OOMaths.h` just includes them (#748's
  form). New `test_OOMathsHeaders.cpp` uses three of them without `OOMaths.h`.
- Three other headers include or declare what they use: `EntityHelpers.h`, `OOPointMaths.h`, and
  #768's `OOJSEngineNativeWrappers.h` (`OOJSPauseTimeLimiter`, `OOJSResumeTimeLimiter`).
- New `headers` suite: `tests/check_headers_standalone.py` compiles each header on its own
  (Windows only, like the unit suites; not in a `deployment_release` build).
- Paths assuming `upstream/oolite/` now assume `oolite-dev/` (READMEs, comments,
  `tests/gui/conftest.py`, `tests/source_paths.py`).
- macOS: `darwin.ini` and `install_packages.sh` add keg-only `icu4c`; `post_build.sh` keeps
  `Resources/Info-gnustep.plist` in the bundle.

## Why

Prerequisite for step 23's include sorting, which breaks any header that is not standalone.

## Behaviour changes

- The macOS bundle keeps `Info-gnustep.plist` (was dropped: null version, every resource directory refused, game exits). Not pinned; macOS is not verified by this series.
- Otherwise none. Standalone maths headers pinned by `test_OOMathsHeaders`; the rest by the `headers` suite.

## How to review

Start with `OOMathsBase.h` against the lines `OOMaths.h` loses (a move), then each maths header's
includes. Check each entry of `check_headers_standalone.py`'s `FRAGMENTS` table (not standalone by
design) gives its reason. Run `meson test --suite headers`.

Test edits:
- `test_objc_assert.cpp`: 80-column layout only; its two `__LINE__` helpers stay on one line under
  `clang-format off`, so recorded lines and checks are unchanged.
- GUI and component tiers: path changes only.

## Verified

Not verified at `e40ed2d9fd`.
