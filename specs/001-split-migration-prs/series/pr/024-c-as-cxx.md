# Compile the remaining C sources as C++; upgrade QuickJS-ng

**Series:** step 24 of 26 · base `series/023-tests-and-tooling` · next `series/025-upstream-49a5eb9fc-ports` **(gen)**

**From:** `develop` commits `448aa6d20`, `6e1654a6b` · 14.4k src, 5.3k tests, 167 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

- The remaining C sources build as C++ (`OOTCPStreamDecoder`, MiniZip's `ioapi` and `unzip`,
  `OOPlanetData`, `OOVoxel`, `legacy_random`, and the EXR snapshot's `miniz`), and the code uses C++'s `bool`, `true`/`false` and `nullptr` where it had
  Objective-C's `BOOL`, `YES`/`NO` and `nil`/`NULL`.
- Guards on `OOLITE_GNUSTEP` go where there is no other build left (the debug monitor's
  application-terminate hooks, `main.cpp`'s GNUstep set-up).
- QuickJS-ng 0.17.0 (was 0.16.2), with the patch for its void returns moved to the new line
  numbers.
- `.clang-tidy` and `.editorconfig`; `meson.build`'s comments no longer point at documents that
  are not in the tree.

## Why

With Objective-C gone, the Objective-C spellings and the C-only units were the last places the
code differed from plain C++. QuickJS-ng 0.17.0 is the current release.

## Behaviour changes

None intended: the type and literal changes are mechanical, and the unit tests pass unchanged
apart from the same spellings.

## How to review

Mostly mechanical; `git diff --word-diff` shows the `BOOL`/`bool` and `nil`/`nullptr` changes.
Read `subprojects/quickjs-ng.wrap` and `subprojects/packagefiles/quickjs-ng-void-return.patch`
for the upgrade, and the removed `OOLITE_GNUSTEP` guards.

## Verified **(gen)**

Windows x64, `fac67c649a`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships, t1_tutorial_walkthrough |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core, headers |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
