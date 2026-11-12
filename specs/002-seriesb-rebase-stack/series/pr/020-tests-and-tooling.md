# Tests and developer tooling

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 20 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/023-tests-and-tooling`.

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
committed executable. The GUI tier's only change is `pillow` in its requirements; its tests are
not changed by this step.

## Verified **(gen)**

Not verified at this branch's tip (`9ec1bec16e`) yet; the last record (2026-11-03) is for an earlier build.
