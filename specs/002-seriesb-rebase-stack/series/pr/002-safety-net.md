# Add a test safety net: deterministic runs, GUI and component tests

**Series:** step 2 of 26 · base `seriesb/001-random-seed-env` · next `seriesb/003-objcpp-switch` **(gen)**

**Replays:** `series/002-safety-net` (old 2 of the master-based series) · 484 src, 12.0k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step adds tests and the few game hooks those tests need, before any production code moves.

- `tests/gui/` is a PyAutoGUI tier (G1–G11) that drives the real game window with OS-level mouse
  and keyboard input. It runs on Windows; elsewhere its fixtures skip.
- `tests/component/` is a pytest-bdd tier (S1–S8) that launches the game, talks to it over the
  debug console's TCP protocol, spawns ships and asserts tolerant outcomes such as "no pirate
  remains within 900 ticks". Each scenario starts the game with `OO_RANDOM_SEED` (step 1).
- `tests/launch_snapshot.py` is reworked so several copies can run at once, each with its own
  console port and its own staged copy of `oolite.app`.
- On the game side: `ship.speed` becomes writable from scripts, and debug builds get an opt-in
  shuffle of `NSDictionary`/`NSSet` enumeration order (`OOEnumerationShuffle`), which
  `GameController` initialises at start-up so its seed is logged first.

## Why

Every later step in the series rewrites code that has no tests of its own: the Foundation layer,
the Objective-C classes, #768's JavaScript binding. These tests are written against the unmodified
Objective-C game, so they record what it does now, and each later step is checked against them.
They come first because a test added after a rewrite can only tell you what the new code does.

The game-side hooks make those runs repeatable or controllable. A writable `ship.speed` lets a
script hold a ship at a known speed, which writing `ship.velocity` cannot do (the engine rebuilds
the velocity from the flight speed on the next frame). The enumeration shuffle catches code that
silently relies on GNUstep's hash order, which the C++ containers in later steps will not reproduce.

## Behaviour changes

- **`ship.speed` is writable for non-player ships** (`OOJSShip.m`). The setter calls `-setSpeed:`,
  refuses negative values and NaN with a script error, has no upper clamp, and stays read-only on
  the player ship. Not pinned by a test in this step; `setterNumbers` in
  `tests/unit/core/test_OOJSShip` checks it from step 14 on.
- **Debug builds only: `OO_SHUFFLE_ENUMERATION=<seed>`** makes `foreach`/`foreachkey` walk
  dictionaries and sets in a seeded, reproducible order. When `OO_DEBUG` is 0 (deployment, test and
  dev builds) the macros are exactly upstream's and `OOEnumerationShuffle.m` compiles to nothing.
  The order logic is tested by `tests/unit/test_enumeration_shuffle.c`, which is not in the meson
  build: its header gives the one-line `cc` command that builds it. Unset, nothing changes.

## How to review

Start with the game side, which is small:

- `src/Core/OOFoundation.h`: the `foreach` macros. `OO_DEBUG` moves to the top of the file because
  the macros now test it; its meaning is unchanged.
- `src/Core/OOEnumerationShuffle.{h,m}`, `OOEnumerationShufflePRNG.h`, and the call in
  `src/Core/GameController.m`.
- The `kShip_speed` setter in `src/Core/Scripting/OOJSShip.m`, written in #768's idiom.
- `src/Core/meson.build`, which adds `OOEnumerationShuffle.m` to the sources. The top-level
  `meson.build` is unchanged.

Everything else, about 13.6k lines, is under `tests/`. For the component tier, read
`tests/component/README.md` (the step catalogue), then `console.py`, `steps/world_steps.py` and one
feature. For the GUI tier, `tests/gui/test_g1_exit_via_mouse.py` is the pattern the other G-tests
follow; most of the size is `tests/gui/conftest.py`. S2–S8 are labelled smoke tests in their
headers: they check that the setup runs cleanly, not the full behaviour their titles name.

Some comments and READMEs in the new tiers refer to documents and helper scripts kept outside this
repository. The fixtures do not need them: where one would use such a helper, it looks for it at
run time and carries on without it.

## Differences from the old step **(gen)**

Where this step's change differs from `series/002-safety-net`'s, and why:

- `src/Core/Scripting/OOJSShip.m`: conflict resolved (stored): #768 rewrote OOJSShip.m for QuickJS-ng (its property table as OOJS_PROPERTY_* macros, setters returning JSValue); the old step made ship.speed read/write for the safety net's tests. Kept #768's file with speed as OOJS_PROPERTY_RW and the old step's setter case in #768's idiom (JS_ToFloat64, JS_UNDEFINED, OOJSNativeFailure).

## Verified **(gen)**

Windows x64, `12eca88f7f`, 2026-11-11.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: not required for this series (the code builds with Clang, as upstream's CI) |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| poc | n/a: the harness needs GNUstep here, so upstream builds it on Linux only |
| smoke | pass |
| tests_untouched | fail: tests/component/README.md, tests/component/conftest.py, tests/component/console.py, tests/gui/test_g2_exit_via_keyboard.py, tests/gui/test_g5_screen_round_trips.py, tests/gui/test_g6_window_lifecycle.py, tests/gui/test_g8_scenario_screen_back_out.py, tests/gui/test_g9_post_exit_hygiene.py |
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
