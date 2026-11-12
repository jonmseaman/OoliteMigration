# Make comments describe the code; use #pragma once

**Series:** step 19 of 26 · base `seriesb/018-develop-fixes` · next `seriesb/020-tests-and-tooling` **(gen)**

**Replays:** `series/022-source-hygiene` (old 22 of the master-based series) · 18.8k src, 77.1k tests, 15 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- **Comments describe the code as it is.** References to the migration's tracker ids, decision
  records, phases and slices are removed from comments in `src/`, `tests/` and `meson.build`, and
  comments that only recorded how the code got here are deleted. Comments that described the C++
  by the Objective-C it replaced (selectors, the bridging façade, `-description`, the golden
  harness) describe the C++ itself. `Http.hpp`'s and `test_http.cpp`'s header comments, which
  hold a two-column table, are kept from clang-format's reflow.
- **`#pragma once`.** 131 headers gain it, in place of their include guards (#768's
  `OOJSShipGroup.h` had none).
- **Tests.** Assertions in the GUI tier that looked for a tracker id in a failure message look for
  the message's text instead. Ten test cases named a decision record in a suffix: nine, the cases
  that pin where oofnd differs from GNUstep on purpose, take the suffix `_GnustepDiffers`
  instead, and `missingArgumentsPrintAsNil` loses its suffix.
- **Small source tidies.** Duplicate includes and one duplicate forward declaration are removed.
- **Test setup on Windows.** `meson.build` adds a default test setup that puts the compiler's own
  `bin` directory first on `PATH`, so tests load the toolchain's `libstdc++` and `libwinpthread`
  and not older copies found earlier on `PATH` (Git for Windows ships some).
- **Layout.** Many files the step touches take the fork's 80-column wrapping, of code as well as
  comments, with includes grouped (the file's own header, standard headers, then the rest) and
  sorted. Upstream's WebKit style accepts either wrapping. A last commit runs clang-format 22 over
  the seven files it would still change (comment closers, two statements sharing a line, one
  brace), so upstream's clang-format check passes; step 23 (`seriesb/023-google-style-format`)
  reformats every file.

## Why

The ids point into a tracker and documents that are not part of this repository, so they mean
nothing to a reader here. `#pragma once` is what upstream's newer headers use. The `PATH` setup
lets `meson test` run from a shell whose `PATH` has another toolchain's runtime ahead of MSYS2's;
such a test fails to start (exit `0xc0000139`) rather than failing an assertion.

## Behaviour changes

None in the game: comments, include guards, duplicate includes and layout only. Test names change
as listed above; each test checks the same things. The only change outside the source is the
Windows test environment's `PATH`, described above.

## How to review

Large but repetitive: 721 files, most hunks deleting a parenthesised reference or a history
comment, or rewrapping. `git diff -w --word-diff` is the easiest way to read it. The one non-comment
change to read in full is the `add_test_setup` block in `meson.build`.

Comments in the GUI and component tiers still name the fork's planning documents
(`docs/phases/…`, `docs/stories/…`) and helper scripts kept outside this repository; this step
does not remove those.

## Verified **(gen)**

Not verified at this branch's tip (`f60dc7c70b`) yet: the last record is for `4d85d7996e` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
