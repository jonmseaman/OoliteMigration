# Tests and developer tooling

**Series:** step 20 of 24 · base `seriesb/019-source-hygiene` · next `seriesb/021-c-as-cxx` **(gen)**

**Replays:** `series/023-tests-and-tooling` (old 23 of the master-based series) · 19 src, 1.2k tests, 13 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- **A tutorial scenario.** `tests/component/features/t1_tutorial_walkthrough.feature` walks the
  tutorial through the keyboard, with its keyboard driver (`keyboard.py`), its steps
  (`steps/tutorial_steps.py`) and an offline test of those steps (`test_tutorial_steps_offline.py`).
- **An exit test.** `tests/component/test_exit_runs_js_leak_check.py` quits a test build through
  `quitGame()` and checks that #768's JavaScript leak check ran at exit and found no leaked
  objects (the `script.javaScript.shutDown` log line).
- **`tests/run.sh`**, one entry point for the unit, component, smoke and GUI tiers, in a private
  virtualenv. The component requirements pin `pytest<9.1` (pytest-bdd 9.0 needs an API that pytest
  9.1 removed); the GUI requirements add `pillow`.
- **One fix.** `ShipEntity::update` updates every subentity again, not only ship subentities. Since
  step 14 the flashers and exhaust plumes of NPC and demo ships were frozen.
- **Tests of #768's delete behaviour.** `delete` of a property that a class serves natively
  (mission variables loaded from a save, system-info overrides, console settings) reaches the
  class's `delete_property` hook even when the object has no own property of that name. #768's
  binding already does this; the step adds the tests that pin it.
- **The GUI tier's source checks** in `test_g2`, `test_g6`, `test_g8` and `test_g9` look for the
  C++ spelling of the code they inspect (the game is C++ since step 16), and match across wrapped
  lines.
- **Editor setup.** `.clangd` points clangd at the meson compile database; `.gitignore` ignores
  `tests/__pycache__`.

## Why

The tutorial scenario covers the keyboard path end to end, and the exit test covers #768's leak
check, which nothing else would notice going missing. The subentity fix restores upstream's
behaviour, lost in this series' conversion of `ShipEntity`. The delete tests pin a behaviour that
SpiderMonkey had and that scripts rely on (deleting a mission variable a saved game set), so a
later change to the binding cannot drop it unnoticed.

## Behaviour changes

- Subentities that are not ships (flashers, exhaust plumes) animate again. Pinned by
  `updateReachesNonShipSubentities` in `tests/unit/core/test_ShipEntity.cpp`.

The delete behaviour is #768's and is unchanged here. It is pinned by
`deleteReachesTheClassHookWithNoOwnProperty` in `tests/unit/core/test_OOJavaScriptEngine.cpp` and
`deletingAVariableTheScriptNeverSet` in `tests/unit/core/test_OOJSMissionVariables.cpp`.

## How to review

Start with the fix in `src/Core/Entities/ShipEntity.cpp` (three loops in `update`) and its test,
then the two delete tests. The component tier's additions are new files; `tests/run.sh` is new and
committed executable. The GUI tests' changes are to the regular expressions they match against the
source.

The GUI tier was not run on the desktop for this step. Of the source-only checks in the four GUI
files the step changes, two fail on this tree: `test_g2`
`test_a_single_row_step_is_reachable_only_from_the_arrow_keys` and `test_g6`
`test_the_fullscreen_flag_is_only_assigned_by_the_toggle_at_runtime`.

## Verified **(gen)**

Not verified at this branch's tip (`49cb47e43a`) yet: the last record is for `f00dd009d6` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
