# Fix code that GCC warns about or evaluates differently

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 17/28. Replays `series/019-gcc-build`.

## What this changes

- Calls making several random draws in one argument list (25 sites: `OOVector.cpp`,
  `OOHPVector.cpp`, `Universe.cpp`'s sky colours, random descriptions in `PlayerEntity.cpp` and
  others) draw into locals first, in Clang's argument order.
- New `OO_PRINTF_FORMAT` (`src/oofnd/PrintfFormat.h`) names MinGW GCC's `gnu_printf`; `PRIu64`
  for 64-bit prices and credits. Files include what they use (`<cstring>`, `<cinttypes>`);
  `OOFoundation.h` drops step 9's `<string.h>`.
- One hunk per diagnostic: `-Wstrict-aliasing` (`memcpy`), `-Wnonnull-compare`,
  `-Wmaybe-uninitialized`, `-Wsign-compare`, unchecked `chdir()`, `gnu_inline`; `legacy_random.c`'s
  `sReallyRandomInited` is debug-only (the release build's one warning).
- `oofnd` tests keep `-Werror` under Clang only (GCC fires inside libstdc++ on correct code). No
  warning flags change. GCC is not claimed to build or pass; CI stays Clang-only.

## Why

Removes the last places where the code relies on Clang's headers, formats or argument order.

## Behaviour changes

None: draws keep Clang's order, so a seed gives the same results. Not pinned (no test pins these draws' order).

## How to review

Start with `PrintfFormat.h` and `src/oofnd/meson.build`. Rule for each random-draw hunk: locals are
drawn in the order the arguments appeared. All 25 are marked:
`git diff seriesb/016-objc-runtime-out seriesb/017-gcc-build -- src | grep -n 'Clang evaluates'`.

Test edits:
- All tests: `#import` -> `#include` (left after step 16).
- `test_Entity.cpp`: type-checked accessor instead of `reinterpret_cast`.
- `test_OOCombinedEmissionMapGenerator.cpp`: comparison split so both sides evaluate in Clang's order.
- `test_objc_assert.cpp`: `__PRETTY_FUNCTION__` checks gain a GCC-spelling branch.

## Verified

Not verified at `e05dea569a`.
