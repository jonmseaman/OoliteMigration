# Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation

**Series:** step 4 of 25 · base `seriesb/003-objcpp-switch` · next `seriesb/005-typed-accessors` **(gen)**

**Replays:** `series/006-oofnd-core` (old 6 of the master-based series) · 10.0k src, 6.4k tests, 3 other changed lines; 460 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step adds `src/oofnd/`, a header-only C++20 library, namespace `oo`, that reimplements the
parts of GNUstep Foundation the game uses:
- `Ref`/`WeakRef`/`AutoreleaseScope` and `WeakSet`;
- `Expected` (a `std::expected` polyfill);
- `PList`, with old-style and XML readers and writers ported from GNUstep quirk for quirk;
- `Data`, `FileSystem`, `ResourcePaths`, `Process`, `Thread` and `Defaults`.

`src/oofnd/objc/` adds a Foundation-free Objective-C floor on libobjc2: the `OOObject` root class,
`OOConstantString`, `OOException`, runtime lookups and Foundation's C types.

The game starts using some of these:
- `oo::process`, captured in `main`, replaces `NSProcessInfo`.
- `oo::thread` replaces `NSThread` and `NSThreadOOExtensions`.
- `OOAsyncWorkManager` gets its own priority queue in place of `OONSOperation`.
- `OOLogging`'s per-thread indent becomes `thread_local`.
- `OORoleSet` is rerooted onto `OOObject`.
- `OOPListView.h` gives Foundation collections `PList`'s typed `get<T>`; `OOWaypointEntity.mm`
  uses it.

The unused `ReleaseLockProxy` is deleted. The unit tests in `tests/unit/oofnd/` are registered as
`meson test --suite oofnd`.

## Why

The C++ conversion needs a replacement for GNUstep Foundation before any class can stop being
Objective-C, and the replacement has to behave exactly as GNUstep does on the game's own data:
plist parsing, number coercion, defaults search order and file paths. Each component is built on
its own with GNUstep-captured expectations in its tests, before the game depends on it, so a
mismatch shows up as a failing unit test rather than as a gameplay difference. Only a few call
sites are switched in this step; that's enough to show each component works in the game, and the
bulk adoption comes in steps 7 to 9. This step comes after the engine switch so that the
JavaScript layer underneath is already final.

## Behaviour changes

None intended. Where the game switches to an `oofnd` component, the component is tested against
the GNUstep behaviour it replaces:
- the plist readers and writers: `tests/unit/oofnd/test_plist_oldstyle_strings.cpp`,
  `test_plist_oldstyle_structures.cpp`, `test_plist_xml.cpp`, `test_plist_writers.cpp`;
- typed lookup with GNUstep's conversions: `tests/unit/oofnd/test_plist_get.cpp`;
- process arguments and processor count: `tests/unit/oofnd/test_process.cpp`;
- main-thread detection and thread naming: `tests/unit/oofnd/test_thread.cpp`;
- the defaults file, its search list and its coercions: `tests/unit/oofnd/test_defaults.cpp`;
- resource and save paths: `tests/unit/oofnd/test_resourcepaths.cpp`;
- the `OOObject` floor and `OOException`: `tests/unit/oofnd/test_objc_floor.mm`,
  `test_objc_exception.mm`, `test_objc_runtime.mm`.

`OORoleSet` keeps its `-description`. Other `OOObject` subclasses log as
`<ClassName: 0x...>`, as `NSObject` did, through the temporary
`src/Core/OOObjectGNUstepBridge.mm`. The game-level tiers from step 2 (`tests/component/`,
`tests/gui/`) also run against this step.

## How to review

1. `src/oofnd/README.md`: the component table and the rules (C++20, no exceptions across the API,
   header-first).
2. Read the components in dependency order: `Expected.hpp`, `Ref.hpp`, `PList.hpp`, `PListGet.hpp`,
   then the readers and writers (`PListOldStyle.hpp`, `PListXML.hpp`, `PListWriting.hpp`,
   `PListParsing.hpp`), then `FileSystem.hpp`, `ResourcePaths.hpp`, `Process.hpp`, `Thread.hpp`
   and `Defaults.hpp`. Read each header next to its `tests/unit/oofnd/test_*.cpp`. The tests'
   expected values were captured from GNUstep, so they are the specification.
3. `src/oofnd/objc/`: `OOObject.mm` and `OOConstantString.mm`. The constant-string class is built
   and tested here, but the game still compiles `@"..."` against GNUstep's `NSConstantString`.
4. The game side, about 1k lines across 55 files:
   - `src/SDL/main.mm`: argument capture, and the autorelease pool through the runtime;
   - `src/Core/OOAsyncWorkManager.mm`: the new queue, highest priority first and FIFO within a
     priority;
   - `src/Core/OOLogging.mm`;
   - `src/Core/OORoleSet.{h,mm}`;
   - `src/Core/OOPListView.h` with `src/Core/Entities/OOWaypointEntity.mm`;
   - `src/Core/OOFoundation.h`, which parses `<compare>` and `<optional>` before the game's
     `true`/`false` macros.

   The remaining files are small swaps of `NSThread`, `NSProcessInfo` or `NSClassFromString` calls
   for their `oo::` or `OORuntime.h` equivalents.

## Differences from the old step **(gen)**

None: the same change as `series/006-oofnd-core`.

## Verified **(gen)**

Windows x64, `6e3649712d`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
