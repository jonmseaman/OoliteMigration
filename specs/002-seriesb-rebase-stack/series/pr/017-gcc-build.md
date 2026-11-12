# Fix code that GCC warns about or evaluates differently

**Series:** step 17 of 26 · base `seriesb/016-objc-runtime-out` · next `seriesb/018-develop-fixes` **(gen)**

**Replays:** `series/019-gcc-build` (old 19 of the master-based series) · 270 src, 1.7k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Code that GCC warns about, or evaluates in a different order from Clang, is fixed in the code.
No warning flag changes.

- **Random draws in argument lists.** Calls that made more than one random draw in one argument
  list now draw into locals first, in the order Clang evaluates the arguments. Examples are
  `randf()` for each of x, y and z in `OOHPVector.cpp` and `OOVector.cpp`, the sky colours in
  `Universe.cpp`, and a description that is an array (so picked at random) passed beside other
  arguments in `PlayerEntity.cpp`, `StationEntity.cpp` and `OOOXZManager.cpp`. C++ leaves the
  order unspecified, and GCC uses another one, so the same seed could give different draws.
- **Formats.** A new `OO_PRINTF_FORMAT` (`src/oofnd/PrintfFormat.h`) names MinGW GCC's C99
  `printf` (`gnu_printf`), so `%zu` and `%lld` check correctly. `PRIu64` formats a 64-bit
  commodity price and a character's insurance credits.
- **Includes.** Files include what they use (`<cstring>`, `<cinttypes>` and the like), where
  Clang's headers happened to pull them in. `OOFoundation.h` drops the `<string.h>` that step 9
  added to stand in for Foundation.h's, since the files that use it now include it themselves.
- **Other diagnostics**, one small hunk each: `-Wstrict-aliasing` (type punning through a cast,
  now `memcpy`), `-Wnonnull-compare`, `-Wmaybe-uninitialized`, `-Wsign-compare`, unchecked
  `chdir()` results in `src/SDL/main.cpp`, and the C-only `gnu_inline` attribute in
  `OOCPUInfo.cpp`.
- **`legacy_random.c`.** `sReallyRandomInited`, which only debug builds read, is declared only in
  debug builds. This removes the one warning the release (deployment) build had.

The `oofnd` tests keep `-Werror` under Clang only (`src/oofnd/meson.build`), because GCC's
flow-sensitive diagnostics fire inside libstdc++ inlines on correct test code. In the tests, every
`#import` left after step 16 becomes `#include`.

GCC is not required by the series. The step does not claim that the stack builds or passes its
tests with GCC, and CI still builds with Clang alone.

## Why

Code that a second compiler warns about, or reads in another order, is fragile under the first:
an include that only arrives through another header, a format string that only matches on one
platform, a seed that only gives the same universe because of one compiler's argument order. With
no Objective-C left after step 16, these are the remaining places where the code leans on Clang.

## Behaviour changes

None. The random-draw rewrites keep the order the Clang build already drew in, so a seed gives
the same draws as before, and the unit tests' expected values are unchanged. No test pins the
order of these particular draws.

## How to review

Start with `src/oofnd/PrintfFormat.h` and `src/oofnd/meson.build`. Then read the random-draw
hunks. Each is marked by a comment
(`git diff seriesb/016-objc-runtime-out seriesb/017-gcc-build -- src | grep -n 'Clang evaluates'`
finds 25). In each, check that the locals are drawn in the order the arguments appeared. The other
source hunks are small, one per diagnostic.

The test changes are mostly mechanical (`#import` to `#include`). The others are:

- `test_Entity.cpp`: a type-checked accessor instead of a `reinterpret_cast`;
- `test_OOCombinedEmissionMapGenerator.cpp`: one comparison split so both sides are evaluated in
  Clang's order;
- `tests/unit/oofnd/test_objc_assert.cpp`: the `__PRETTY_FUNCTION__` checks gain a GCC branch with
  GCC's spelling (the two in `test_OOJSConsole.cpp` already have one).

## Verified **(gen)**

Not verified at this branch's tip (`e05dea569a`) yet: the last record is for `db43363c08` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
