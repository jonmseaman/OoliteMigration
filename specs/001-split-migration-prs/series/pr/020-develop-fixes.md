# Small fixes after the migration

**Series:** step 20 of 25 · base `series/019-upstream-9ee8ff22f-port` · next `series/021-source-hygiene` **(gen)**

**From:** `develop` commits `935aedb20`, `5346a1800`, `66567dc26`, `736572b67`, `c971f1641` · 104 src, 386 tests, 9 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

Fixes made on the fork after the migration was squashed, and the gap between the squash and
the history's last state.

- Assertions stay live in every build flavour. `OOCAssert`/`OOCParameterAssert` compiled to
  nothing under `NDEBUG`, unlike upstream, where GNUstep's assertion macros stayed live in every
  build; `PlayerEntity::deferredInit` sets the player's ship up inside an assertion, so a
  deployment build never finished initialising the player. `OOConstToJSString.cpp` sets `sInited`
  unconditionally again. A meson option, `deployment_unit_tests`, builds the oofnd unit suite
  with the deployment macros.
- Headers include what they use. `OOHPVector.h`, `OOQuaternion.h`, `OOMatrix.h`,
  `OOBoundingBox.h`, `OOTriangle.h` and `OOVoxel.h` include the maths headers they depend on;
  `EntityHelpers.h` includes `Entity.h`; `OOPointMaths.h` includes `OOFoundationTypes.h`.
  `OOMaths.h` keeps the `INCLUDED_OOMATHS_h` marker the maths sub-headers check, so they are
  still reachable only through it. The maths headers take the fork's form here, with the guard
  that says so (`#error Do not include … directly; include OOMaths.h`), in place of the
  guard-free form upstream's #748 gave them, which needs its includer to define `OOScalar` first.
- `tests/check_headers_standalone.py` (`meson test --suite headers`) compiles every header the
  build uses on its own, with the command of a source file that includes it.
- Paths in comments, test helpers and READMEs that named the old `upstream/oolite/` location.

## Why

The squash of the migration was taken before the assertion fix, so this step restores it as
the fork has it. Self-contained headers let a formatter sort includes without breaking the
build, which is what the last step of the series relies on; the header check keeps them that
way.

## Behaviour changes

- A deployment (`NDEBUG`) build evaluates its assertions, as upstream's does; before this, the
  player's ship was never set up in such a build and the ship could not launch. Pinned by
  `tests/unit/oofnd/test_objc_assert_ndebug.cpp`.
- `test_objc_assert`: two one-line helpers that record `__LINE__` are kept on one line under
  `clang-format off`, so the line they record is the assertion's.

## How to review

Read `src/oofnd/objc/OOAssert.h` and the maths headers' new includes; `meson test --suite headers`
checks the second. The README and test-path changes are mechanical. Files the step changes keep
upstream's layout where the change merged as it stands; a few headers carry the fork's
80-column wrapping where it did not.

## Verified **(gen)**

Windows x64, `b1b58353fe`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | pass: s6_damaged_ship_flees |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | fail: exit 1 (see .agent-tmp\series-verify-logs\020-unit.log) |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
