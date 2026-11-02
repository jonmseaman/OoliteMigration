# Let OO_RANDOM_SEED pin the random seed

**Series:** step 1 of 26 · base `series/000-upstream-base` · next `series/002-safety-net` **(gen)**

**From:** the migration's history (an independent fix, ahead of it) commits `7555b5d42` · 11 src, 0 tests, 0 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

`GameController` seeds RANROT from the `OO_RANDOM_SEED` environment variable when it is set and
not empty (`strtoul`, base 10), and logs the seed under `rand.seed`. Unset, the seed is the wall
clock, as before.

## Why

Nothing downstream of RANROT can be repeated without a fixed seed: a run that shows a bug cannot
be run again, and tests that drive the game (the component scenarios later in this series) need
the same universe every time. It is independent of the rest of the series and useful on its own.

## Behaviour changes

None unless `OO_RANDOM_SEED` is set. With it set, the same seed gives the same RANROT sequence
from start-up, and the log has one `rand.seed` line.

## How to review

One hunk in `src/Core/GameController.m`. Run with `OO_RANDOM_SEED=42` twice and compare the
`rand.seed` line and the first system generated; run without it and see no `rand.seed` line.

## Verified **(gen)**

Windows x64, `ee25fd156b`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
