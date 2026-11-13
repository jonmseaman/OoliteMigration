# Add oofnd, a small Foundation replacement, and an Objective-C floor without Foundation

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 4/28. Replays `series/006-oofnd-core`.

## What this changes

- `src/oofnd/`: header-only C++20 library (namespace `oo`) replacing the Foundation the
  game uses (`Ref`, `PList` with readers/writers ported quirk for quirk, `FileSystem`, `Thread`,
  `Defaults`, …; table in its README).
- `src/oofnd/objc/`: a Foundation-free Objective-C floor on libobjc2 (`OOObject`,
  `OOConstantString`, `OOException`, `OORuntime.h`), linking the `objc_lib` that
  `src/meson/linux/meson.build` found, if any (Fedora: `/usr/local/lib64`).
- New meson suite `oofnd`: 20 tests in `tests/unit/oofnd/`, Windows, all flavours but deployment.
  The game builds as `c++20` (not `gnu++20`).
- 60 game files adopt it: `oo::process`, `oo::thread`, a priority queue in `OOAsyncWorkManager`,
  `OORoleSet` on `OOObject`, typed `get<bool>`/`get<T>` via `OOPListView.h`, four `OOException`
  raise sites, type-encoding matching in `OOJSCall`/`OOShaderUniform`. Deleted:
  `NSThreadOOExtensions`, `OONSOperation.h`, unused `ReleaseLockProxy`.

## Why

No class can leave Objective-C until a GNUstep-exact Foundation replacement exists, tested on its
own before the game depends on it.

## Behaviour changes

None intended. Each component the game switches to matches GNUstep (tests in `tests/unit/oofnd/`):
- Plist readers/writers. Pinned by `test_plist_oldstyle_strings.cpp`,
  `test_plist_oldstyle_structures.cpp`, `test_plist_xml.cpp`, `test_plist_writers.cpp`.
- Typed lookup with GNUstep's conversions. Pinned by `test_plist_get.cpp`.
- Process arguments and processor count. Pinned by `test_process.cpp`.
- Main-thread detection and thread naming. Pinned by `test_thread.cpp`.
- Defaults file, search list and coercions. Pinned by `test_defaults.cpp`.
- Resource and save paths. Pinned by `test_resourcepaths.cpp`.
- `OOObject` floor and `OOException`. Pinned by `test_objc_floor.mm`, `test_objc_exception.mm`,
  `test_objc_runtime.mm`.
- Game-side uses, the work queue order (highest priority first, FIFO within one) and the method-type
  matching in `OOJSCall`/`OOShaderUniform`. Not pinned.
- The four raise sites (`nil` insert, mutation while enumerating, failed allocation) escape
  `@catch (NSException *)` (only `@catch (id)` catches) and print objects as `<ClassName: 0x...>`
  (were `NSException` and `-description`). Not pinned.
- `c++20` defines `__STRICT_ANSI__`, so `OOMaths.h`'s own `MIN`/`MAX`/`ABS` evaluate arguments
  twice (were GNU statement expressions). Not pinned.

`OORoleSet` keeps `-description`; other `OOObject` subclasses log as `<ClassName: 0x...>`, as
`NSObject` did, via temporary `src/Core/OOObjectGNUstepBridge.mm`. The step-2 tiers also run.

## How to review

Start at `src/oofnd/README.md` (rules: C++20, no exceptions across the API, header-first), then
read each header in dependency order next to its test. Rule: the tests' expected values were
captured from GNUstep and are the spec. `OOConstantString` is built and tested, but `@"..."` still
compiles against GNUstep's `NSConstantString`.

    meson test --suite oofnd
    git diff --stat seriesb/003-objcpp-switch seriesb/004-oofnd-core -- src/Core src/SDL

On the game side read `src/SDL/main.mm`, `OOAsyncWorkManager.mm`, `OOJSCall.mm`,
`OOShaderUniformMethodType.mm` and `OOFoundation.h` (parses `<compare>`/`<optional>` before the
game's `true`/`false` macros); the rest are small swaps.

## Verified

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
