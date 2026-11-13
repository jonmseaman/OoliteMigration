# Add a test safety net: deterministic runs, GUI and component tests

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 2/28. Replays `series/002-safety-net`.

## What this changes

- `tests/gui/`: PyAutoGUI tier G1–G11 driving the real window with OS-level input. Windows only;
  elsewhere its fixtures skip.
- `tests/component/`: pytest-bdd tier S1–S8 over the debug console's TCP protocol, asserting
  tolerant outcomes ("no pirate remains within 900 ticks"). Each launch sets `OO_RANDOM_SEED`.
- `tests/launch_snapshot.py`: several copies can run at once, each with its own console port and
  staged `oolite.app`.
- Game hooks: writable `ship.speed`, and a debug-only seeded shuffle of `NSDictionary`/`NSSet`
  enumeration (`OOEnumerationShuffle`), initialised in `GameController` so its seed logs first.

## Why

Later steps rewrite untested code, so these tests first record what the unmodified game does.

## Behaviour changes

- `ship.speed` is writable on non-player ships via `-setSpeed:`; negative or NaN is a script
  error, no upper clamp, still read-only on the player (was read-only). Not pinned here;
  `setterNumbers` in `tests/unit/core/test_OOJSShip` checks it from step 14.
- Debug builds: `OO_SHUFFLE_ENUMERATION=<seed>` gives `foreach`/`foreachkey` a seeded, reproducible
  order (was hash order); unset, nothing changes. With `OO_DEBUG` 0 the macros are upstream's and
  `OOEnumerationShuffle.m` compiles to nothing. Pinned by `tests/unit/test_enumeration_shuffle.c`
  (not in meson; its header gives the `cc` command).

## How to review

Rule: production code changes only for these hooks. Start with the game side:

- `src/Core/OOFoundation.h`: the `foreach` macros; `OO_DEBUG` moves to the top, meaning unchanged.
- `src/Core/OOEnumerationShuffle.{h,m}`, `OOEnumerationShufflePRNG.h`, the call in
  `GameController.m`, and `src/Core/meson.build` (top-level `meson.build` unchanged).
- The `kShip_speed` setter in `src/Core/Scripting/OOJSShip.m`, in #768's idiom.

The other ~13.6k lines are `tests/`: read `tests/component/README.md`, `console.py`,
`steps/world_steps.py` and one feature; `tests/gui/test_g1_exit_via_mouse.py` is the G-test
pattern. S2–S8 are smoke tests: they check the setup runs, not the behaviour their titles name.
Some comments name helpers outside this repo; the fixtures carry on without them.

## Differences from the old step

- `src/Core/Scripting/OOJSShip.m`: conflict resolved (stored): #768 rewrote OOJSShip.m for QuickJS-ng (its property table as OOJS_PROPERTY_* macros, setters returning JSValue); the old step made ship.speed read/write for the safety net's tests. Kept #768's file with speed as OOJS_PROPERTY_RW and the old step's setter case in #768's idiom (JS_ToFloat64, JS_UNDEFINED, OOJSNativeFailure).

## Verified

Windows x64, `12eca88f7f`, 2026-11-11. macOS and Linux are not verified.

| Check | Result |
|---|---|
| build_clang | pass |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | fail: tests/component/README.md, tests/component/conftest.py, tests/component/console.py, tests/gui/test_g2_exit_via_keyboard.py, tests/gui/test_g5_screen_round_trips.py, tests/gui/test_g6_window_lifecycle.py, tests/gui/test_g8_scenario_screen_back_out.py, tests/gui/test_g9_post_exit_hygiene.py |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

Not applicable here: build_gcc, poc, unit.
