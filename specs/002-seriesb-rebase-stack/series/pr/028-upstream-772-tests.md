# Add upstream #772's JavaScript tests; reject non-dictionary arguments as 1.93 did

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 28/28.

## What this changes

- Imports upstream #772's JavaScript tests and parity probe unchanged, from #772 at `12c39549e`
  (David Hobley's commit): 69 in-game tests over five phases in `tests/js/`, run by
  `tests/run_js_tests.py` through `tests/oolite_harness.py`; their event-recorder and compatibility
  OXPs in `tests/oxp/`; and the probe in `tools/js-parity/`, which replaces #768's older one. #772's
  OXP downloader is left out.
- Fixes what the probe found: `mission.markSystem()`, `mission.unmarkSystem()`,
  `Ship.setMaterials()` and `Ship.setShaders()` (and `VisualEffect`'s) raise when a script passes
  an array or a string where 1.93 expected a dictionary.

## Why

#772's tests run unchanged against the C++ build with outputs stored from upstream's Objective-C
build, so a difference points at the translation.

## Behaviour changes

- A non-dictionary passed to those methods is a script error, as in 1.93 (was read as an empty
  dictionary). Pinned by `tests/component/test_dictionary_arguments_reject_arrays.py` (3 of 4 fail
  without the fix).
- Otherwise none: the rest is tests and tooling.

## How to review

The import is #772's files as upstream has them; read the fix commit (`OOJSMission.cpp`,
`OOMaterialConvenienceCreators.cpp`) and its test. To run the in-game tests:
`tests/run_js_tests.py --path <built game>`. It sometimes stops at "Could not start the hyperspace
countdown" because the player dies in flight; that happens without the fix too.

## Verified

Not verified yet.
