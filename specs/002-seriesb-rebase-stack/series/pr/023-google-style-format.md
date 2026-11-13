# Reformat with Google-style clang-format (optional)

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 23/28. Replays `series/026-google-style-format`.

## What this changes

- `.clang-format` becomes Google style, with a section that keeps headers holding fenced Mac code
  from being formatted as Objective-C.
- clang-format 22 (upstream CI's version) reformats 570 files: 515 in `src/`, 52 test sources.
  84 C/C++ files in `tests/` that it would change are left as they are. Later format commits
  (20 files, then 7) are the same command over code from earlier steps.
- `./mk.sh format` reformats `src/`; `./mk.sh format-check` reports what CI would reject and warns
  on a non-22 major version (`README` says so).
- Two hand edits, both from include sorting: `OOProfilingStopwatch.h` keeps `<windef.h>` before
  `<timeapi.h>` with a comment line (else Windows breaks); `OOMatrix.cpp` drops
  `<SDL3/SDL_opengl.h>` (sorted above `OOOpenGLOnly.h`, it hid `glUniformMatrix3fvARB`;
  `OOOpenGLOnly.h` includes it in order).

## Why

Optional: the fork's preferred style; earlier steps pass upstream's check with upstream's
`.clang-format`, so the series works without this step (step 024 is written in this style).

## Behaviour changes

None (formatting only). Code tokens match in every file (includes compared as a set), except two
`@"..."` literals in fenced Mac code that clang-format splits and `OOMatrix.cpp`'s dropped
`<SDL3/SDL_opengl.h>`, which still arrives through `OOOpenGLOnly.h`.

## How to review

Decide on the style, not the diff. Reproduce on `seriesb/022-upstream-28ceaaba0-ports`: take this
step's `.clang-format`, run clang-format 22 `-i` over every `.h .hpp .c .cpp .m .mm` under `src/`
until nothing changes (two passes); every `src/` file then matches apart from the two hand edits.
Trap: use 22, not 23; 23 wraps some enum initialisers differently (`PlayerEntity.h`), so
`./mk.sh format-check` with 23 flags files CI accepts.

## Verified

Not verified at `248fc953ba`.
