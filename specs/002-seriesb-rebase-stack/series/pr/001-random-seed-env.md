# Let OO_RANDOM_SEED pin the random seed

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 1 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/001-random-seed-env`.

## What this changes

`GameController` seeds RANROT from the `OO_RANDOM_SEED` environment variable when it is set and
not empty (`strtoul`, base 10), and logs the seed under `rand.seed`. Unset, the seed is the wall
clock, as before.

## Why

Nothing downstream of RANROT can be repeated without a fixed seed: a run that shows a bug cannot
be run again, and tests that drive the game (the component scenarios that step 2 adds) need the
same universe every time. It is independent of the rest of the series and useful on its own.

## Behaviour changes

None unless `OO_RANDOM_SEED` is set. With it set, the same seed gives the same RANROT sequence
from start-up, and the log has one `rand.seed` line. Not pinned by a unit test; every component
scenario from step 2 on launches the game with it (`tests/component/console.py`).

## How to review

One hunk in `src/Core/GameController.m`. Run with `OO_RANDOM_SEED=42` twice and compare the
`rand.seed` line and the first system generated; run without it and see no `rand.seed` line.

## Verified **(gen)**

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
