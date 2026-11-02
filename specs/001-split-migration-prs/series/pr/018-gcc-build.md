# Build with GCC as well as Clang

**Series:** step 18 of 25 · base `series/017-objc-runtime-out` · next `series/019-upstream-9ee8ff22f-port` **(gen)**

**Chapter:** P4 · 4.3 GCC · history `5fda5e404c`..`903e52cbdd` (3 merges) · 218 src, 1.7k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

The game and its unit tests now build with GCC (MSYS2 UCRT64 `g++`) as well as Clang, configured
with the `gcc.ini` native file already in the tree. The changes are to the code, not to warning
flags: GCC's `-Wstrict-aliasing`, `-Wnonnull-compare` and format diagnostics are fixed where they
fire, and a new `OO_PRINTF_FORMAT` (`src/oofnd/PrintfFormat.h`) names MinGW GCC's C99 `printf`
(`gnu_printf`) so `%zu` and `%lld` check correctly. Calls that made more than one random draw in one
argument list (`randf()` for each of x, y and z in `OOHPVector.cpp` and `OOVector.cpp`, sky colours
in `Universe.cpp`, a description picked at random beside other arguments in `StationEntity.cpp`,
and similar in a few other files) now draw into locals first, in the order Clang evaluated them,
because GCC evaluates arguments in a different order and would otherwise build a different
universe from the same seed. The `oofnd` tests keep `-Werror` under Clang only.

## Why

With no Objective-C left after step 17, nothing ties the game to Clang any more; GCC is the
compiler most Linux distributions build with, and a second compiler catches problems the first
does not. It comes after step 17 because until then the game was Objective-C++ built against
libobjc2, which the build supported only with Clang.

## Behaviour changes

None. The random-draw rewrites keep the order the Clang build already drew in, so a seed gives
the same draws as before; a GCC build now draws in that order too. The unit tests'
expected values are unchanged for Clang; four checks of `__PRETTY_FUNCTION__` text gain a GCC
branch with GCC's spelling (`tests/unit/core/test_OOJSConsole.cpp`,
`tests/unit/oofnd/test_objc_assert.cpp`).

## How to review

Start with `src/oofnd/PrintfFormat.h` and `src/oofnd/meson.build`, then the random-draw hunks,
each marked by a comment
(`git diff series/017-objc-runtime-out series/018-gcc-build -- src | grep -n 'Clang evaluates'`):
in each, check that the locals are drawn in the order the arguments appeared. The other source
hunks are small, one per GCC diagnostic, and say which in a comment.

The test changes are mostly mechanical: `#import` that the rename step left in the tests becomes
`#include`. The non-mechanical ones are `test_Entity.cpp` (a type-checked accessor instead of a
`reinterpret_cast`), `test_OOCombinedEmissionMapGenerator.cpp` (one comparison split so both
sides are evaluated in Clang's order) and the `__PRETTY_FUNCTION__` branches above. To build with
GCC: `./mk.sh build test --native-file=gcc.ini`.

## Verified **(gen)**

Windows x64, `9e5a1f6512`, 2026-11-02.

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
| warnings_clang | pass: 0 warnings outside the history's tests (1 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
