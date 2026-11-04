# Fix code that GCC warns about or evaluates differently

**Series:** step 17 of 25 · base `seriesb/016-objc-runtime-out` · next `seriesb/018-upstream-9ee8ff22f-port` **(gen)**

**Replays:** `series/019-gcc-build` (old 19 of the master-based series) · 218 src, 1.7k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

Code that GCC warns about, or evaluates in a different order from Clang, is fixed, so the game and
its unit tests also build with GCC (MSYS2 UCRT64 `g++`, the `gcc.ini` native file already in the
tree). The changes are to the code, not to warning flags: GCC's `-Wstrict-aliasing`,
`-Wnonnull-compare` and format diagnostics are fixed where they fire, files include what they use
(`<cstring>` and the like, which Clang's headers happened to pull in), and a new `OO_PRINTF_FORMAT`
(`src/oofnd/PrintfFormat.h`) names MinGW GCC's C99 `printf` (`gnu_printf`) so `%zu` and `%lld`
check correctly; `PRIu64` formats the 64-bit credit counts. Calls that made more than one random
draw in one argument list (`randf()` for each of x, y and z in `OOHPVector.cpp` and `OOVector.cpp`,
sky colours in `Universe.cpp`, a description picked at random beside other arguments in
`StationEntity.cpp`, and similar in a few other files) now draw into locals first, in the order
Clang evaluated them, because GCC evaluates arguments in a different order and would otherwise
build a different universe from the same seed. The `oofnd` tests keep `-Werror` under Clang only.

GCC is not required and is not built in CI: the workflows still build with Clang alone. A GCC
build is optional (`./mk.sh build test --native-file=gcc.ini`).

## Why

With no Objective-C left after the previous step, nothing ties the code to Clang any more. Code
that a second compiler warns about, or reads in another order, is fragile under the first: an
include that only arrives through another header, a format string that only matches on one
platform, a seed that only gives the same universe because of one compiler's argument order.

## Behaviour changes

None. The random-draw rewrites keep the order the Clang build already drew in, so a seed gives
the same draws as before; a GCC build now draws in that order too. The unit tests'
expected values are unchanged for Clang; checks of `__PRETTY_FUNCTION__` text in
`tests/unit/oofnd/test_objc_assert.cpp` gain a GCC branch with GCC's spelling (the two in
`tests/unit/core/test_OOJSConsole.cpp` already have one).

## How to review

Start with `src/oofnd/PrintfFormat.h` and `src/oofnd/meson.build`, then the random-draw hunks,
each marked by a comment
(`git diff seriesb/016-objc-runtime-out seriesb/017-gcc-build -- src | grep -n 'Clang evaluates'`):
in each, check that the locals are drawn in the order the arguments appeared. The other source
hunks are small, one per GCC diagnostic, and say which in a comment.

The test changes are mostly mechanical: `#import` that the rename step left in the tests becomes
`#include`. The non-mechanical ones are `test_Entity.cpp` (a type-checked accessor instead of a
`reinterpret_cast`), `test_OOCombinedEmissionMapGenerator.cpp` (one comparison split so both
sides are evaluated in Clang's order) and the `__PRETTY_FUNCTION__` branches above. To build with
GCC: `./mk.sh build test --native-file=gcc.ini`.

## Differences from the old step **(gen)**

None: the same change as `series/019-gcc-build`.

## Verified **(gen)**

Windows x64, `db43363c08`, 2026-11-03.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 new warnings (1 inherited from the parent) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
