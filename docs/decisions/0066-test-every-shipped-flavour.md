# ADR-0066: Assertions are live in every flavour, and the shipped flavour is tested

- Status: Accepted (Jon, in chat 2026-10-27: "approve ADR-0066"). Proposed with its default taken
  under Jon's 2026-10-20 delegation (docs/decisions/delegated-2026-10-19.md), bead oo-pdsng.
- Date: 2026-10-27
- Beads: oo-pdsng (Jon, 2026-10-26: "When I press 1 repeatedly, it is like I repeatedly undock. The
  game is kinda broken." ... "we need to run the tests against all versions of the game since
  there are a bunch of macros.")

## Context

The deployment flavour (`./mk.sh build deployment`, `pkg-win deployment`, what Jon installs) is
built with `NDEBUG`, LTO and strip. Every unit suite, golden and component test ran against the
`test` flavour only, which has no `NDEBUG`. The deployment game could not launch:
`tests/golden/launch_dock.py` on `build/meson_deployment` fails with "player.ship.docked never
became false within 120s"; at the keyboard every '1' starts the launch again.

Root cause: `src/oofnd/objc/OOAssert.h` compiled `OOCAssert` to an empty statement under `NDEBUG`,
on the stated belief that upstream's `NSAssert` was blocked the same way. It was not. Upstream's
`OOFoundation.h` defines `NS_BLOCK_ASSERTIONS` only after `#import <Foundation/Foundation.h>`, and
gnustep-base 1.31.1's include-guarded `NSException.h:432` chooses the blocked or live macros when it
is first parsed, so upstream's assertions were live in every flavour. `PlayerEntity::deferredInit`
(`PlayerEntity.cpp:448`, upstream `PlayerEntity.m:1604`) does the player ship's set-up inside an
assertion: `[super initWithKey:PLAYER_SHIP_DESC definition:...]`. In the converted deployment build
that set-up never ran. The core suite's `test_PlayerEntity` `deferredInit` case checks exactly
this, but was never built with `NDEBUG`.

An audit of every flavour conditional in the converted tree against upstream (oo-pdsng) found no
other conversion-introduced divergence with behavioural effect; `OOConstToJSString.cpp`'s `sInited`
had been moved under `#ifndef NDEBUG` to match the blocked asserts and is restored.

## Decision

1. `OOCAssert`/`OOCParameterAssert` are live in every flavour, as upstream's were. Not conditional
   on `NDEBUG`. `tests/unit/oofnd/test_objc_assert_ndebug.cpp` compiles `OOAssert.h` with `NDEBUG`
   in every flavour and checks the condition's side effects run and a false one raises.
2. The unit suites are also built and run under the deployment macro set: meson option
   `deployment_unit_tests` (default off, so the shipped build is unchanged), driven by
   `tools/check-deployment-tests.sh` into `build/meson_deployment_tests` without LTO/strip (the
   macros are the subject; LTO is covered by item 3). Today that is the oofnd suite (39 tests);
   `test_objc_assert`, which refuses `NDEBUG` by `#error`, is skipped there and its twin above
   covers it. The core suite joins with bead oo-n77z0: 78 of its executables do not build under
   `NDEBUG` yet (their `gDebugFlags` definitions are still guarded on `!NDEBUG`, which upstream #756
   moved to `OO_DEBUG_MONITOR_ENABLED` in the game, and similar test-side guards).
3. Every blessed golden (001, 001-launch-dock) runs against the real deployment binary (LTO,
   stripped): `tools/check-deployment-goldens.sh`, which is tier-c's goldens stage with `OO_APP_DIR`
   at `build/meson_deployment`. The goldens are flavour-independent dumps; no new golden is blessed.
4. Both run nightly (`tests/nightly/checks.txt`, `[oo-pdsng]`). A `deployment` stage in
   `tools/tier-c.sh` is bead oo-41cpr (the stage table is pinned by `tools/tier_c_selftest.py` and
   `tools/test_tier_c_stage_selection.py`, whose expected lists change with it); the fork's Windows
   CI is bead oo-gkylp.

Rejected: hoisting the set-up out of the one assertion only (fixes the symptom, leaves every other
`OOCAssert` diverging from upstream in deployment); building the core tests with LTO (cost, and LTO
is covered by the goldens on the real binary); a separate deployment golden set (needs Jon's bless
and adds nothing while the dumps are flavour-independent).

## Consequences

- A deployment build now raises (and logs in class `gnustep`) where upstream's did; the asserts'
  cost is upstream's.
- Cost: the deployment-macro unit build ~ one non-LTO game build plus the test links (ccache
  shared), the deployment goldens ~2 min after a deployment build. Nightly, not per-merge.
- `OOFoundation.h`'s `NS_BLOCK_ASSERTIONS` define stays (upstream's, inert, as it always was).

## History

- 2026-10-27: proposed, default taken (oo-pdsng).
