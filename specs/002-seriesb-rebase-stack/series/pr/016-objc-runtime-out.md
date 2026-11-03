# Remove the Objective-C runtime and rename the sources to .cpp

**Series:** step 16 of 25 · base `seriesb/015-entity-facade` · next `seriesb/017-gcc-build` **(gen)**

**Replays:** `series/018-objc-runtime-out` (old 18 of the master-based series) · 6.6k src, 1.8k tests, 10.3k other changed lines; 8.5k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

With no Objective-C class left in the game, this step removes what supported them and builds
every unit as C++. Deferred releases move from Objective-C autorelease pools to
`oo::AutoreleaseScope` (`src/oofnd/Ref.hpp`), opened where upstream's pools were (start-up, the
frame loop, the game tick), and pools with nothing to drain are deleted. Exceptions become C++:
`OORaiseException` and `OOAssert` throw `oo::Exception` (`src/oofnd/Exception.hpp`) and the
`@try`/`@catch` handlers become `try`/`catch`. The last Objective-C support code goes:
`OOObject`, `OOConstantString`, `OOWeakReference`/`OOWeakSet`, `NSObjectOOExtensions`,
`OOCallByName.mm`, the Objective-C priority and async queues, `OODescription.mm` and the
`oofnd/objc` runtime headers; selector look-ups become name tables, and the few `@encode()` strings
still compared or logged become literals in the generated `src/Core/OOTypeEncodings.h`. Finally
every `.mm` file is renamed `.cpp`, `#import` becomes `#include`, and `meson.build` drops the
`objc`/`objcpp` languages, libobjc2 and every `-fobjc-*` flag.

## Why

This is the point of the series: after it the game needs no Objective-C compiler or runtime to
build or run (GNUstep-base already left the build in earlier steps). It can only come after steps 16 and 17, because until the last facade was
deleted something still needed an Objective-C object. The rename is last so that each file is
renamed once, after its contents stopped being Objective-C.

## Behaviour changes

None. Exceptions keep their names and log text (`oo::Exception`'s names are the same strings as
Foundation's), objects released at a scope's drain are released at the same points as with
upstream's pools (`clearCacheReleasesAtTheNearestScopesDrain` in
`tests/unit/core/test_OOTexture.cpp`), and the type encodings are byte-identical to what
`@encode()` produced.

## How to review

Most of the diff is the rename: `git diff -M --stat series/017-entity-facade series/018-objc-runtime-out`
shows 381 `.mm` to `.cpp` renames, most of them with small or no content changes. To see only
what changed inside renamed files, use
`git diff -M --diff-filter=R series/017-entity-facade series/018-objc-runtime-out`; the common edits
are `#import` to `#include`, `@autoreleasepool { }` to a plain block in the tests, and dropped
`__OBJC__` guards.

The parts worth reading: `meson.build` and `src/meson.build` (languages and dependencies),
`src/oofnd/Exception.hpp` and its users (`GameController.cpp`'s tick handler,
`OOJSEngineNativeWrappers`), the scope changes in `OOTexture.cpp` and `ResourceManager.cpp`, and
`src/Core/OOTypeEncodings.h` with its users (`OOShaderUniformMethodType`, `EntityShaderBindings`,
`OOJSConsole`). Deleted files (`git diff --stat --diff-filter=D ...`) are the Objective-C support
code and the tests of that code only (`tests/unit/oofnd/test_objc_*`, `test_OOWeakReference`,
`test_OOPriorityQueue` and similar).

## Differences from the old step **(gen)**

None: the same change as `series/018-objc-runtime-out`.

## Verified **(gen)**

Windows x64, `1cfe5a027e`, 2026-11-03.

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
| warnings_clang | pass: 0 new warnings (0 inherited from the parent, 1 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
