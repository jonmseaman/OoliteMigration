# Tests and developer tooling

**Series:** step 21 of 25 · base `seriesb/020-source-hygiene` · next `seriesb/022-c-as-cxx` **(gen)**

**Replays:** `series/023-tests-and-tooling` (old 23 of the master-based series) · 35 src, 1.1k tests, 13 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- A component scenario that walks the tutorial (`t1_tutorial_walkthrough.feature`), with its
  keyboard driver and steps, and an offline test of the steps.
- `tests/run.sh`, one entry point for the unit, component, smoke and GUI tiers.
- Two fixes found by comparing the C++ code with upstream's Objective-C, file by file:
  `ShipEntity::update` updates every subentity, not only ship subentities (flashers and exhaust
  plumes of NPC and demo ships were frozen), and deleting a JavaScript property that a class
  handles (mission variables, system-info overrides, console settings) reaches the class's
  delete hook even when the object has no own slot, as it did under SpiderMonkey.
- Editor setup: `.clangd` points clangd at the meson compile database.

## Why

The tutorial scenario covers the keyboard path end to end. The two fixes restore upstream's
behaviour; each comes with a test that fails before it.

## Behaviour changes

- Subentities that are not ships (flashers, exhaust plumes) animate again. Pinned by
  `updateReachesNonShipSubentities` in `tests/unit/core/test_ShipEntity.cpp`.
- `delete missionVariables.x` for a variable loaded from a save or set by a legacy script, and
  `delete` on a system-info override or a console setting, now clear it. Pinned by
  `deletingAVariableTheScriptNeverSet` in `tests/unit/core/test_OOJSMissionVariables.cpp` and the
  delete test in `tests/unit/test_jsengine_quickjs.cpp`; `test_OOJSConsole` expects the fourth
  configuration call that upstream's console makes on such a delete.

## How to review

The two fixes are small (`ShipEntity.cpp`, `JSEngine_quickjs.cpp`); start there, with their
tests. The component tier's additions are new files. The editor settings for VS Code and Zed
are not part of the series.

## Differences from the old step **(gen)**

None: the same change as `series/023-tests-and-tooling`.

## Verified **(gen)**

Windows x64, `f00dd009d6`, 2026-11-03.

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
