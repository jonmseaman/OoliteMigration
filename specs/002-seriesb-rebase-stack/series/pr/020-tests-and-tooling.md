# Tests and developer tooling

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 20/28. Replays `series/023-tests-and-tooling`.

## What this changes

- Component tier: `t1_tutorial_walkthrough.feature` (keyboard driver `keyboard.py`,
  `steps/tutorial_steps.py`, offline `test_tutorial_steps_offline.py`), and
  `test_exit_runs_js_leak_check.py`, which checks #768's exit leak check ran clean.
- New `tests/run.sh` for the unit, component, smoke and GUI tiers in a private virtualenv; component
  requirements pin `pytest<9.1` (for pytest-bdd 9.0), GUI requirements add `pillow`.
- Fix: `ShipEntity::update` updates every subentity again, not only ships.
- New tests pinning #768's `delete` reaching a class's `delete_property` hook with no own property.
- `.clangd` reads the meson compile database; `.gitignore` ignores `tests/__pycache__`.

## Why

Covers the keyboard path, #768's leak check and `delete` hook, and restores upstream's subentity
updates.

## Behaviour changes

- Non-ship subentities (flashers, exhaust plumes) animate again (were frozen on NPC and demo ships since step 14). Pinned by `updateReachesNonShipSubentities` in `test_ShipEntity.cpp`.
- `delete` behaviour is #768's, unchanged. Pinned by `deleteReachesTheClassHookWithNoOwnProperty` in `test_OOJavaScriptEngine.cpp` and `deletingAVariableTheScriptNeverSet` in `test_OOJSMissionVariables.cpp`.

## How to review

Start with the three loops in `ShipEntity::update` and their test, then the two delete tests. The
rest is new files; `tests/run.sh` is committed executable. No existing test is edited; the GUI
tier only gains `pillow`.

## Verified

Not verified at `9ec1bec16e`.
