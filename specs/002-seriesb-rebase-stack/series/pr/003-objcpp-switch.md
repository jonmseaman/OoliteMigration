# Compile the game as Objective-C++, keeping #768's QuickJS-ng binding

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 3/28. Replays `series/005-quickjs-switch` (old 3, 4, 5).

## What this changes

- Every Objective-C source in `src/` goes `.m` → `.mm` (247 renames, incl. #768's `poc/`); the
  build declares `objcpp` (`meson.build`, `clang.ini`), and `src/meson/meson.build` gives it
  Objective-C's exception flags and, for Clang off macOS, GNUstep-runtime flags. 288 files,
  +1738/−1334, none added or deleted.
- 131 renames are byte-identical; 116 and 29 headers get the edits C++ requires: keyword
  identifiers renamed (`this` → `thisObj` across #768's binding, `class` → `klass`, `new` →
  `newValue`, …), explicit `void *` and enum casts, VLAs → `std::vector`, `extern "C"` guards,
  declarations a `goto`/`case` would jump scoped or split.
- C-only constructs replaced: `OO_CAST_PARAMETER` (`OOStringExpander.h`) by overloads;
  `OOOpenGLStateManager.mm`'s table moved above first use; `OOSortFunction()` (`OOFoundation.h`)
  at the `sort…UsingFunction:` sites; `OOMaths.h` includes `<tgmath.h>` before `extern "C"`.
- `ShellScripts/common/post_build.sh` stages transitive Windows DLLs (`ldd` until none new,
  `staged_dlls`), e.g. `libsystre-0.dll` for `libtre-5.dll`.
- #768's QuickJS-ng binding stays the scripting layer; `oolite-quickjs-compat.js`, the wrap and
  patch, `tools/js-parity/` and `tools/oxp-upgrade/` are unchanged.

## Why

Step 4's C++20 `oofnd` and later C++-in-class steps need Objective-C++; one rename step keeps
later diffs to real changes.

## Behaviour changes

- Former VLAs are zero-initialised `std::vector`s on the heap (were stack arrays). Not pinned.

Otherwise none: `OOOpenGLStateManager.mm`'s table keeps the same five states and values, and the
step-2 component and GUI tiers run unchanged.

## How to review

Rule: each edit is the smallest the compiler requires, on upstream's code. Content changes only,
then without re-indentation:

    git diff -M --name-status seriesb/002-safety-net seriesb/003-objcpp-switch | grep -v '^R100'
    git diff -M -w seriesb/002-safety-net seriesb/003-objcpp-switch -- src ':!*meson.build'

Real reads: `OOStringExpander.h` (overloads must classify each type as the C branch does), the
moved table in `OOOpenGLStateManager.mm`, the new blocks in `OOPlanetTextureGenerator.mm` and
`OOStandaloneAtmosphereGenerator.mm`, then the build files above. Upstream kept: `--diff-filter=AD
--name-only` over the same range prints nothing; the joystick files (#742, #749) are `R100`;
`src/Core/OOOpenGLOnly.h` (#748) is unchanged; `git grep -n playerWillSaveGame
seriesb/003-objcpp-switch -- src` still shows #780's `doScriptEvent:` calls.

## Verified

Windows x64, `e8b7c8d6d9`, 2026-11-11. macOS and Linux are not verified.

| Check | Result |
|---|---|
| build_clang | pass |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships (1 earlier attempt(s) failed; see the log) |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | fail: src/Core/Scripting/poc/OOJavaScriptEnginePoc.mm: #pragma clang diagnostic ignored "-Wincomplete-implementatio |
| smoke | pass |
| tests_untouched | fail: tests/component/README.md, tests/component/conftest.py, tests/component/console.py, tests/gui/test_g2_exit_via_keyboard.py, tests/gui/test_g5_screen_round_trips.py, tests/gui/test_g6_window_lifecycle.py, tests/gui/test_g8_scenario_screen_back_out.py, tests/gui/test_g9_post_exit_hygiene.py |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

Not applicable here: build_gcc, poc, unit.
