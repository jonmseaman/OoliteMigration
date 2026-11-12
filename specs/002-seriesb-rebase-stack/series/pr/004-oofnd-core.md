# Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 4 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/006-oofnd-core`.

## What this changes

This step adds `src/oofnd/`, a header-only C++20 library, namespace `oo`, that reimplements the
parts of GNUstep Foundation the game uses:
- `Ref`/`WeakRef`/`AutoreleaseScope` and `WeakSet`;
- `Expected` (a `std::expected` polyfill);
- `PList`, with old-style and XML readers and writers ported from GNUstep quirk for quirk, and
  `PListGet`'s typed `get<T>`/`at<T>`;
- `Data`, `FileSystem`, `ResourcePaths`, `Process`, `Thread` and `Defaults`.

`src/oofnd/objc/` adds a Foundation-free Objective-C floor on libobjc2: the `OOObject` root class,
`OOConstantString`, `OOException`, `OORuntime.h` (class and selector lookups) and Foundation's C
types. The library and its 20 unit tests in `tests/unit/oofnd/` are 48 files, +14.6k lines. The
tests are registered as `meson test --suite oofnd`, built on Windows in every flavour but the
deployment build (they test assertion paths that `NDEBUG` compiles out, and use the Windows
toolchain's headers and LLP64 types). The floor links against the `objc_lib` that
`src/meson/linux/meson.build` found, where there is one (on Fedora, GNUstep's libobjc is in
`/usr/local/lib64`, off the linker's default path); elsewhere it searches for `objc` as before.

The game builds as `c++20` (not `gnu++20`) from here on, through `cpp_std` in `src/meson.build`,
which meson also applies to Objective-C++.

The game starts using some of these (60 files under `src/Core` and `src/SDL`, +917/−1069):
- `oo::process`, captured in `main`, replaces `NSProcessInfo`.
- `oo::thread` replaces `NSThread` and `NSThreadOOExtensions`, which is deleted.
- `OOAsyncWorkManager` gets its own priority queue; `OONSOperation.h` is deleted.
- `OOLogging`'s per-thread indent becomes `thread_local`.
- `OORoleSet` is rerooted onto `OOObject`.
- `OOPListView.h` gives Foundation collections `PList`'s typed `get<T>`; `OOWaypointEntity.mm`
  uses it. Booleans are read as `get<bool>`: there is no `BOOL` row, because outside Windows the
  GNUstep runtime's `BOOL` is `unsigned char` and the row would redefine that one.
- `CollisionRegion`, `OOPriorityQueue`, `OOProbabilitySet` and `OOShipGroup` raise `OOException`
  instead of `NSException`.
- `OOJSCall` and `OOShaderUniform` match a method's types through the runtime's type encodings
  instead of `NSMethodSignature`.
- `NSAutoreleasePool` objects become `@autoreleasepool` blocks or runtime pool calls;
  `NSSelectorFromString` and friends become `OORuntime.h` calls; `OOSkyDrawable` reads
  `oo::Defaults`; the OXP verifier checks its path with `oo::fs`.

The unused `ReleaseLockProxy` is deleted.

## Why

The C++ conversion needs a replacement for GNUstep Foundation before any class can stop being
Objective-C, and the replacement has to behave exactly as GNUstep does on the game's own data:
plist parsing, number coercion, defaults search order and file paths. Each component is built on
its own with GNUstep-captured expectations in its tests, before the game depends on it, so a
mismatch shows up as a failing unit test rather than as a gameplay difference. Only a few call
sites are switched in this step; that's enough to show each component works in the game, and the
bulk adoption comes in steps 5 to 7. The game is already Objective-C++ (step 3), so its files can
include the C++20 headers.

## Behaviour changes

None intended on the game's normal paths. Where the game switches to an `oofnd` component, the
component is tested against the GNUstep behaviour it replaces:
- the plist readers and writers: `tests/unit/oofnd/test_plist_oldstyle_strings.cpp`,
  `test_plist_oldstyle_structures.cpp`, `test_plist_xml.cpp`, `test_plist_writers.cpp`;
- typed lookup with GNUstep's conversions: `tests/unit/oofnd/test_plist_get.cpp`;
- process arguments and processor count: `tests/unit/oofnd/test_process.cpp`;
- main-thread detection and thread naming: `tests/unit/oofnd/test_thread.cpp`;
- the defaults file, its search list and its coercions: `tests/unit/oofnd/test_defaults.cpp`;
- resource and save paths: `tests/unit/oofnd/test_resourcepaths.cpp`;
- the `OOObject` floor and `OOException`: `tests/unit/oofnd/test_objc_floor.mm`,
  `test_objc_exception.mm`, `test_objc_runtime.mm`.

Not pinned by a test:
- The game-side uses of these components, the work manager's queue order (highest priority
  first, first in first out within a priority) and the method-type matching in `OOJSCall` and
  `OOShaderUniform`.
- The four `OOException` raise sites report programming errors (a `nil` insert, a mutation while
  enumerating, a failed allocation). A `@catch (NSException *)` does not catch an `OOException`
  (a `@catch (id)` does), and their messages print an object as `<ClassName: 0x...>` rather than
  through `-description`.
- Building as `c++20` defines `__STRICT_ANSI__`, so where `OOMaths.h` defines `MIN`, `MAX` and
  `ABS` itself it now uses the plain macros, which evaluate their arguments twice, rather than
  the GNU statement-expression ones.

`OORoleSet` keeps its `-description`. Other `OOObject` subclasses log as `<ClassName: 0x...>`,
as `NSObject` did, through the temporary `src/Core/OOObjectGNUstepBridge.mm`. The game-level
tiers from step 2 (`tests/component/`, `tests/gui/`) also run against this step.

## How to review

1. `src/oofnd/README.md`: the component table and the rules (C++20, no exceptions across the API,
   header-first).
2. Read the components in dependency order: `Expected.hpp`, `Ref.hpp`, `PList.hpp`, `PListGet.hpp`,
   then the readers and writers (`PListOldStyle.hpp`, `PListXML.hpp`, `PListWriting.hpp`,
   `PListParsing.hpp`), then `FileSystem.hpp`, `ResourcePaths.hpp`, `Process.hpp`, `Thread.hpp`
   and `Defaults.hpp`. Read each header next to its `tests/unit/oofnd/test_*.cpp`. The tests'
   expected values were captured from GNUstep, so they are the specification.
3. `src/oofnd/objc/`: `OOObject.mm`, `OOException.mm` and `OOConstantString.mm`. The
   constant-string class is built and tested here, but the game still compiles `@"..."` against
   GNUstep's `NSConstantString`.
4. The game side: `git diff --stat seriesb/003-objcpp-switch seriesb/004-oofnd-core -- src/Core src/SDL`.
   About 460 of its removed lines are the three deleted files. Read:
   - `src/SDL/main.mm`: argument capture, and the autorelease pool through the runtime;
   - `src/Core/OOAsyncWorkManager.mm`: the new queue and work threads;
   - `src/Core/OOLogging.mm` and `src/Core/OOLogOutputHandler.mm`;
   - `src/Core/Scripting/OOJSCall.mm` and `src/Core/Materials/OOShaderUniformMethodType.mm`: the
     type-encoding match;
   - `src/Core/OORoleSet.{h,mm}`;
   - `src/Core/OOPListView.h` with `src/Core/Entities/OOWaypointEntity.mm`;
   - `src/Core/OOFoundation.h`, which parses `<compare>` and `<optional>` before the game's
     `true`/`false` macros.

   The remaining files are small swaps of `NSProcessInfo`, `NSThread`, `NSException`,
   `NSSelectorFromString` or `NSAutoreleasePool` for their `oo::` or runtime equivalents.
5. `meson.build`, `src/meson.build`, `src/oofnd/meson.build`: the `oofnd` dependency, `c++20`,
   the floor's libobjc, and the test suite.

## Verified **(gen)**

Windows x64, `e178ae9254`, 2026-11-11. macOS and Linux are not verified.

| Check | Result |
|---|---|
| build_clang | pass |
| clang_format | pass |
| component | fail: exit 1 (see .agent-tmp\seriesb-verify-logs\004-component.log) (2 earlier attempt(s) failed; see the log) |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | fail: tests/component/README.md, tests/component/conftest.py, tests/component/console.py, tests/gui/test_g2_exit_via_keyboard.py, tests/gui/test_g5_screen_round_trips.py, tests/gui/test_g6_window_lifecycle.py, tests/gui/test_g8_scenario_screen_back_out.py, tests/gui/test_g9_post_exit_hygiene.py |
| unit | pass: oofnd |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

Not applicable here: build_gcc, poc.
