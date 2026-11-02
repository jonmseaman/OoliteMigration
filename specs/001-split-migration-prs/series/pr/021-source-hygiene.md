# Make comments describe the code; use #pragma once

**Series:** step 21 of 25 · base `series/020-develop-fixes` · next `series/022-tests-and-tooling` **(gen)**

**From:** `develop` commits `2ceced1f8`, `c9c225c78`, `0b49abd31` · 56.8k src, 153.2k tests, 48 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

Comments describe the code as it is: references to the migration's tracker ids, decision
records, phases, slices and tiers are removed, and the comments that only recorded the
migration's history are deleted. Headers use `#pragma once` instead of include guards. Test
assertions that matched tracker ids match the message text instead, and one test-name suffix
becomes `GnustepDiffers`.

## Why

The ids point into a tracker and documents that are not part of this repository, so they mean
nothing to a reader here. `#pragma once` is what upstream's newer headers use.

## Behaviour changes

None. Comments, include guards and test names only; the tests check the same things.

## How to review

Large but repetitive: almost every hunk deletes a parenthesised reference or a history
comment. `git diff --word-diff` is the easiest way to read it. The fork rewrapped its comments at
80 columns when it made this change, and formatting cannot unwrap them, so the files it touches
carry that wrapping (the code itself stays in upstream's layout, and upstream's clang-format
check passes).

## Verified **(gen)**

Windows x64, `ee5a9ab940`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core, headers |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
