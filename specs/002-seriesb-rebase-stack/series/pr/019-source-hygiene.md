# Make comments describe the code; use #pragma once

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 19/28. Replays `series/022-source-hygiene`.

## What this changes

- Comments in `src/`, `tests/` and `meson.build` lose tracker ids, decision records, phases and
  history, and describe the C++ rather than the Objective-C it replaced.
- 131 headers swap include guards for `#pragma once`; duplicate includes and one duplicate forward
  declaration go.
- `meson.build` adds a default Windows test setup that puts the compiler's `bin` first on `PATH`.
- Many touched files take 80-column wrapping and grouped, sorted includes (`Http.hpp`'s and
  `test_http.cpp`'s tables are kept from reflow); a last commit runs clang-format 22 over seven files.

## Why

The ids point at documents outside this repository; the `PATH` setup stops tests failing to start
(`0xc0000139`) when another toolchain's runtime is earlier on `PATH`.

## Behaviour changes

None in the game. Windows tests load the toolchain's own `libstdc++`/`libwinpthread` (was whichever came first on `PATH`, e.g. Git for Windows'). Not pinned.

## How to review

721 files, mostly deleted references or rewraps: read with `git diff -w --word-diff`. Read the
`add_test_setup` block in `meson.build` in full. GUI and component comments still name the fork's
`docs/phases/…`, `docs/stories/…` and outside helper scripts; not removed here.

Test edits:
- GUI tier: assertions match a failure message's text, not a tracker id.
- Ten case names: nine decision-record suffixes become `_GnustepDiffers` (oofnd differs from
  GNUstep on purpose); `missingArgumentsPrintAsNil` loses its suffix. Each checks the same things.

## Verified

Not verified at `f60dc7c70b`.
