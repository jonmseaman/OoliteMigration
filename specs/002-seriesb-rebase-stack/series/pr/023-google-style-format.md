# Reformat with Google-style clang-format (optional)

**Series:** step 23 of 24 · base `seriesb/022-upstream-28ceaaba0-ports` · next `seriesb/024-post-conversion-fixes` **(gen)**

**Replays:** `series/026-google-style-format` (old 26 of the master-based series) · 418.8k src, 23.2k tests, 55 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Formatting only. `.clang-format` becomes Google style (with a section that keeps headers holding
fenced Mac code from being formatted as Objective-C), and clang-format 22, the version upstream's
CI pins, is run over `src/` and part of `tests/`: 570 files change, 515 of them in `src/` and 52
test sources. `./mk.sh format` reformats `src/` in place and `./mk.sh format-check` reports what
the CI check would reject, warning when the local clang-format's major version is not CI's; the
`README` says so.

Reproduce: take `.clang-format` from this step, then run clang-format 22 with `-i` over every
`.h`, `.hpp`, `.c`, `.cpp`, `.m` and `.mm` under `src/` until it changes nothing (two passes:
one leaves some comment reflows). Every file in `src/` then equals this step's. In `tests/`, 84
C and C++ files that clang-format 22 would change are left as they are.

One hand edit: Google style sorts includes, which put `<timeapi.h>` ahead of `<windef.h>` in
`OOProfilingStopwatch.h` and broke the Windows build. A comment line between the two keeps
clang-format from sorting them.

## Why

Optional. This is the style the fork prefers. The steps before it keep upstream's style and pass
upstream's clang-format check with upstream's `.clang-format`, so the series can be taken without
this step; step 024 is written in this step's style.

## Behaviour changes

None: formatting only. Code tokens are the same before and after in every file, include lines
compared as a set; the only exceptions are two Objective-C `@"..."` literals in fenced Mac code
that clang-format splits.

## How to review

Run the command above on `seriesb/022-upstream-28ceaaba0-ports` and compare with this branch;
there is nothing to read line by line. Decide on the style, not the diff. Use clang-format 22:
CI is the authority, and clang-format 23 formats some wrapped enum initialisers differently (for
example in `PlayerEntity.h`), so `./mk.sh format-check` with 23 reports files that CI accepts.

## Verified **(gen)**

Not verified at this branch's tip (`9814ba3131`) yet: the last record is for `29f6d6dead` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
