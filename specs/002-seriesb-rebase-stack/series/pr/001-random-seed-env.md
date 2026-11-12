# Let OO_RANDOM_SEED pin the random seed

**Series:** step 1 of 26 · base `seriesb/000b-upstream-768-quickjs-only` · next `seriesb/002-safety-net` **(gen)**

**Replays:** `series/001-random-seed-env` (old 1 of the master-based series) · 11 src, 0 tests, 0 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

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

Windows x64, `c58d86dbba`, 2026-11-11.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: not required for this series (the code builds with Clang, as upstream's CI) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| poc | n/a: the harness needs GNUstep here, so upstream builds it on Linux only |
| smoke | pass |
| tests_untouched | pass |
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
