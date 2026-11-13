# Let OO_RANDOM_SEED pin the random seed

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 1/28. Stacked on upstream #768's branch; needs #767 and #768 merged first. Replays `series/001-random-seed-env`.

## What this changes

- `GameController` seeds RANROT from `OO_RANDOM_SEED` when it is set and not empty (`strtoul`,
  base 10).
- The seed is logged under `rand.seed`.
- Unset, the seed is the wall clock, as before.

## Why

Makes RANROT-driven runs repeatable, which step 2's component scenarios need; useful on its own.

## Behaviour changes

- With `OO_RANDOM_SEED` set, the same seed gives the same RANROT sequence from start-up and one
  `rand.seed` log line (was always the wall clock). Not pinned by a unit test; every component
  scenario from step 2 on launches with it (`tests/component/console.py`).

## How to review

One hunk in `src/Core/GameController.m`. Run twice with `OO_RANDOM_SEED=42` and compare the
`rand.seed` line and the first system generated; without it there is no `rand.seed` line.

## Verified

Windows x64, `c58d86dbba`, 2026-11-11. macOS and Linux are not verified.

| Check | Result |
|---|---|
| build_clang | pass |
| clang_format | pass |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

Not applicable here: build_gcc, component, poc, unit.
