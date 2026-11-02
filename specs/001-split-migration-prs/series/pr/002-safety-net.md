# Add a test safety net: deterministic runs, GUI and component tests

**Series:** step 2 of 26 · base `series/001-random-seed-env` · next `series/003-js-facade` **(gen)**

**Chapter:** P0 · 0.1 iteration-order determinism, 0.4 seed and floating-point hooks for reproducible runs, 0.8 GUI tier, 0.13 component tier · history `7555b5d425`..`8af7966e7d` (41 merges) · 493 src, 13.6k tests, 27 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

This step adds tests and the few game hooks those tests need, before any production code moves.
`tests/gui/` is a PyAutoGUI tier (G1–G11) that drives the real game window with OS-level mouse and
keyboard input; it runs on Windows and skips elsewhere. `tests/component/` is a pytest-bdd tier
(S1–S8) that launches the game, talks to it over the debug console's TCP protocol, spawns ships and
asserts tolerant outcomes such as "no pirate remains within 900 ticks". `tests/launch_snapshot.py`
is reworked so several copies can run at once, each with its own console port and its own staged
copy of `oolite.app`. On the game side the step adds an `OO_RANDOM_SEED` environment variable,
turns floating-point contraction off for every build, makes `ship.speed` writable from scripts,
and adds a debug-only shuffle of `NSDictionary`/`NSSet` enumeration order.

## Why

Every later step in the series rewrites code that has no tests of its own: the JavaScript engine,
the Foundation layer, the Objective-C classes. These tests are written against the unmodified
Objective-C game so they record what it does now, and each later step is checked against them. They
come first because a test added after a rewrite can only tell you what the new code does.

The game-side hooks exist to make those runs repeatable. A fixed RANROT seed makes a scenario
replayable, and `-ffp-contract=off` stops the compiler from fusing `a*b + c` into an FMA
differently from one machine or compiler version to another. The enumeration shuffle catches code
that silently relies on GNUstep's hash order, which the C++ containers in later steps will not
reproduce.

## Behaviour changes

- **`OO_RANDOM_SEED`.** If set, `GameController` seeds RANROT from it and logs the seed
  (`rand.seed`). If unset, it seeds from the clock as before. Every component scenario depends on
  this: `tests/component/console.py` sets it, and each feature starts with `Given a universe seeded
  with <n>`, e.g. `tests/component/features/s1_police_kills_pirate.feature`.
- **`-ffp-contract=off` in every build** (`meson.build`). Compilers that used to fuse multiply-adds
  may now produce different low-order bits in floating-point results. No test in this step checks
  this.
- **`ship.speed` is writable for non-player ships** (`OOJSShip.m`). It calls `-setSpeed:`, refuses
  negative values and NaN with a script error, has no upper clamp, and stays read-only on the
  player ship. No test in this step exercises it.
- **Debug builds only: `OO_SHUFFLE_ENUMERATION=<seed>`** makes `foreach`/`foreachkey` walk
  dictionaries and sets in a seeded, reproducible order. When `OO_DEBUG` is 0 (deployment, test and
  dev builds), the macros are exactly upstream's and `OOEnumerationShuffle.m` compiles to nothing.
  The order logic is tested by `tests/unit/test_enumeration_shuffle.c`. That file is not in the
  meson build yet; its header gives the one-line `cc` command to build it.

## How to review

Start with the game-side changes, which are small:
- `src/Core/GameController.m`: the seed.
- `src/Core/OOFoundation.h`: the `foreach` macros. `OO_DEBUG` moves to the top of the file because
  the macros now test it; its meaning is unchanged.
- `src/Core/OOEnumerationShuffle.{h,m}` and `OOEnumerationShufflePRNG.h`.
- The `kShip_speed` setter in `src/Core/Scripting/OOJSShip.m`.
- The two `meson.build` hunks.

Everything else, about 13.6k lines, is under `tests/`. For the component tier, read
`tests/component/README.md` (the step catalogue), then `console.py`, `steps/world_steps.py` and one
feature. For the GUI tier, `tests/gui/test_g1_exit_via_mouse.py` is the pattern the other G-tests
follow; most of the size is `tests/gui/conftest.py`. S2–S8 are labelled smoke tests in their
headers: they check that the setup runs cleanly, not the full behaviour their titles name.

The test READMEs and some comments mention helper scripts (`tools/gui-lock`,
`tools/gui-tier.sh`), a `tests/golden/` harness and design documents that are not in this tree.
Where a fixture uses one of those helpers, it looks for it at runtime and carries on without it.
Despite the title, no goldens or JS API snapshot files are added here: this step adds only the
pieces that make them reproducible: the seed, `-ffp-contract=off`, and a comment on the
existing `optimization=2` default explaining why it must stay fixed.

## Verified **(gen)**

Windows x64, `1d9fcd9d8c`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
