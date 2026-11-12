# Remove the Objective-C runtime and rename the sources to .cpp

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 16 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/018-objc-runtime-out`.

## What this changes

With no Objective-C class left in the game, this step removes what supported them and builds
every unit as C++.

- Deferred releases move from Objective-C autorelease pools to `oo::AutoreleaseScope`
  (`src/oofnd/Ref.hpp`), opened where upstream's pools were (start-up, the frame loop, the game
  tick). Pools with nothing to drain are deleted.
- Exceptions become C++: `OORaiseException` and `OOAssert` throw `oo::Exception`
  (`src/oofnd/Exception.hpp`), and the `@try`/`@catch` handlers become `try`/`catch`.
- The last Objective-C support code goes: `OOObject.mm`, `OOConstantString`,
  `OOWeakReference` (with the last bridge) and `OOWeakSet`, `NSObjectOOExtensions`,
  `OOCallByName.mm`, the Objective-C priority and async queues, `OODescription.mm` and the
  `oofnd/objc` runtime headers (`OORuntime.h`, `OOObjCPeer.h`, `OOObjCRef.h`).
- The few `@encode()` strings that are still compared or logged become literals in the generated
  `src/Core/OOTypeEncodings.h`.
- Every `.mm` file is renamed `.cpp`, and `#import` becomes `#include` in the sources (the
  macOS-only blocks, which the series does not convert, keep theirs).
  `meson.build` drops the `objc`/`objcpp` languages, libobjc2 and every `-fobjc-*` flag (so
  `src/oofnd/meson.build`'s Objective-C floor no longer links the `objc_lib` step 4 found);
  `clang.ini` and `gcc.ini` drop their Objective-C lines; the README drops its Objective-C section.

#768's own Objective-C becomes C++ in the same way: `OOJSObjectWrapperFinalize` and
`OOJSBasicPrivateObjectConverter` in the engine, the mission reset observer, and the `@catch (id)`
handlers in the console, the world scripts and `OOJSSystem`. `OOJSReportWrappedException(id)` goes
with them. #768's harness in `src/Core/Scripting/poc/` is converted and renamed too: it builds as
C++ against oofnd and QuickJS-ng, with no Objective-C runtime.

Upstream changes kept in the converted code: #748's include order in the files this step touches,
and #766's macOS legacy-context check in `OOOpenGLExtensionManager.cpp`, now in C++. The sites
that #766 moved to its `OOLITE_MACOS` macro use it here too; other macOS-only blocks keep
`OOLITE_MAC_OS_X`.

Tests: the tests of the deleted support code retire with it (`test_OOAsyncQueue`,
`test_OOWeakReference`, `test_OOWeakSet`, and in oofnd `test_objc_call_by_name`, `_description`,
`_exception`, `_floor`, `_peer`, `_plist`, `_ref` and `_runtime`). `test_OOPriorityQueue` keeps
its two cases of the C++ queue. `test_objc_assert_ndebug` loses its 4 checks of the method forms
(`OOAssert`, `OOParameterAssert`), which went with libobjc2; its `OOCAssert`/`OOCParameterAssert`
checks stay. Two tests are new: `test_EntityScriptEvents` (8 cases), which checks the script events
that #780 sends through `doScriptEvent()`, and `test_plist_hdr_brightness_index` in oofnd, which
pins upstream's answer for an HDR brightness that is not in `hdr_maxBrightness_array`.

## Why

This is the point of the series: after it the game needs no Objective-C compiler or runtime to
build or run. GNUstep-base already left the build in earlier steps. It can only come after steps
14 and 15, because until the last bridge was deleted something still needed an Objective-C
object. The rename is last so that each file is renamed once, after its contents stopped being
Objective-C.

## Behaviour changes

None.

- Exceptions keep their names and log text (`oo::Exception`'s names are the same strings as
  Foundation's), and a native exception still reaches a script as `Native exception: ...`:
  `nativeExceptions` in `tests/unit/core/test_OOJSWaypoint.cpp`.
- Objects released at a scope's drain are released at the same points as with upstream's pools:
  `clearCacheReleasesAtTheNearestScopesDrain` in `tests/unit/core/test_OOTexture.cpp`.
- The type encodings are byte-identical to what `@encode()` produced: `typesFromEncodings` in
  `tests/unit/core/test_OOShaderUniformMethodType.cpp`, and the logged encodings in
  `objectNamesAnsweredWithoutTheObject` in `tests/unit/core/test_OOEntityCalledByName.cpp`.

## How to review

Most of the diff is the rename:
`git diff -M --stat seriesb/015-entity-facade seriesb/016-objc-runtime-out` shows 390 `.mm` to
`.cpp` renames, most with small or no content changes. To see only what changed inside renamed
files, use `git diff -M --diff-filter=R seriesb/015-entity-facade seriesb/016-objc-runtime-out`.
The common edits are `#import` to `#include` in the sources, `@autoreleasepool { }` to a plain
block or an `oo::AutoreleaseScope` in the tests, and dropped `__OBJC__` guards. The tests keep
their `#import` lines here (Clang accepts them); step 17 converts them. One commit only runs
clang-format 22 over `PlayerEntityControls.cpp` (three of #783's GUI-button conditions), so the
step passes upstream's format check.

The parts worth reading:

- `meson.build`, `src/meson.build` and `src/Core/Scripting/poc/meson.build` (languages and
  dependencies);
- `src/oofnd/Exception.hpp` and its users (`GameController.cpp`'s tick handler,
  `OOJSEngineNativeWrappers.cpp`);
- the scope changes in `OOTexture.cpp` and `ResourceManager.cpp`;
- `src/Core/OOTypeEncodings.h` and its users (`OOShaderUniformMethodType.cpp`,
  `EntityShaderBindings.cpp`, `OOEntityCalledByName.cpp`, `OOJSConsole.cpp`). Like step 15's
  tables, it was generated by a script that is not part of this tree; its header comment still
  names the script.

Deleted files
(`git diff --stat --diff-filter=D seriesb/015-entity-facade seriesb/016-objc-runtime-out`, 44 of
them) are the Objective-C support code and the tests of that code only. A few `.mm` and `.cpp`
pairs did not pair as renames and show as a delete and an add (`OOShaderUniformMethodType`,
`poc/main`, `test_OOJSCall`, `test_OOPriorityQueue`, `test_OOShaderUniformMethodType`,
`test_string_expander`).

## Verified **(gen)**

Not verified at this branch's tip (`4b585f4a80`) yet; the last record (2026-11-03) is for an earlier build.
