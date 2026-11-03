# Make comments describe the code; use #pragma once

**Series:** step 20 of 25 · base `seriesb/019-develop-fixes` · next `seriesb/021-tests-and-tooling` **(gen)**

**Replays:** `series/022-source-hygiene` (old 22 of the master-based series) · 56.8k src, 153.2k tests, 48 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

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

## Differences from the old step **(gen)**

None: the same change as `series/022-source-hygiene`.

## Verified **(gen)**

Windows x64, `4d85d7996e`, 2026-11-03.

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
