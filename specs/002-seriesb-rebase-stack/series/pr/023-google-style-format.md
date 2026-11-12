# Reformat with Google-style clang-format (optional)

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 23 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/026-google-style-format`.

## What this changes

Formatting only. `.clang-format` becomes Google style (with a section that keeps headers holding
fenced Mac code from being formatted as Objective-C), and clang-format 22, the version upstream's
CI pins, is run over `src/` and part of `tests/`: 570 files change, 515 of them in `src/` and 52
test sources. `./mk.sh format` reformats `src/` in place and `./mk.sh format-check` reports what
the CI check would reject, warning when the local clang-format's major version is not CI's; the
`README` says so.

Reproduce: take `.clang-format` from this step, then run clang-format 22 with `-i` over every
`.h`, `.hpp`, `.c`, `.cpp`, `.m` and `.mm` under `src/` until it changes nothing (two passes:
one leaves some comment reflows). Every file in `src/` then equals this step's, apart from the
two hand edits below. The step's later format commits (`OOFoundation.h`'s `OOSortFunction`
comment, 20 files in a second run, and 7 more files) are the same command over code that came in
from earlier steps after the first run, so every file passes upstream's clang-format check. In `tests/`, 84 C and C++ files
that clang-format 22 would change are left as they are.

Two hand edits, both because Google style sorts includes:

- `OOProfilingStopwatch.h`: sorting put `<timeapi.h>` ahead of `<windef.h>` and broke the Windows
  build. A comment line between the two keeps clang-format from sorting them.
- `OOMatrix.cpp`: sorting put `<SDL3/SDL_opengl.h>` above `OOOpenGLOnly.h`, so SDL's header was
  read before `GL_GLEXT_PROTOTYPES` was defined and `glUniformMatrix3fvARB` was not declared. The
  include is removed; `OOOpenGLOnly.h` includes it in the right order.

## Why

Optional. This is the style the fork prefers. The steps before it keep upstream's style and pass
upstream's clang-format check with upstream's `.clang-format`, so the series can be taken without
this step; step 024 is written in this step's style.

## Behaviour changes

None: formatting only. Code tokens are the same before and after in every file, include lines
compared as a set; the exceptions are two Objective-C `@"..."` literals in fenced Mac code that
clang-format splits, and `OOMatrix.cpp`'s `<SDL3/SDL_opengl.h>` include, which goes (the header
still reaches the file through `OOOpenGLOnly.h`).

## How to review

Run the command above on `seriesb/022-upstream-28ceaaba0-ports` and compare with this branch;
there is nothing to read line by line. Decide on the style, not the diff. Use clang-format 22:
CI is the authority, and clang-format 23 formats some wrapped enum initialisers differently (for
example in `PlayerEntity.h`), so `./mk.sh format-check` with 23 reports files that CI accepts.

## Verified **(gen)**

Not verified at this branch's tip (`248fc953ba`) yet; the last record (2026-11-03) is for an earlier build.
