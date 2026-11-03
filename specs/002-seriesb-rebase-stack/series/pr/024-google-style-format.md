# Reformat with Google-style clang-format (optional)

**Series:** step 24 of 25 · base `seriesb/023-upstream-49a5eb9fc-ports` · next `seriesb/025-upstream-quickjs-binding` **(gen)**

**Replays:** `series/026-google-style-format` (old 26 of the master-based series) · 431.9k src, 5 tests, 55 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

The fork's formatting: `.clang-format` becomes Google style, and every C and C++ source and
test is run through clang-format 22, the version upstream's CI pins. `./mk.sh format` reformats
`src/` in place and `./mk.sh format-check` reports what the CI check would reject, warning when
the local clang-format's major version is not CI's.

Reproduce: take `.clang-format` from this step, then run clang-format 22 with `-i` on every
`.h`, `.hpp`, `.c` and `.cpp` under `src/` and `tests/`. The result is this step except for 88
files, which keep the fork's layout or include order where clang-format's output depends on its
input's (`verify` checks that they differ in nothing else).

## Why

Optional. This is the style the fork prefers, and the series ends on the fork exactly. Every
step before it passes upstream's own clang-format check in upstream's style, so taking the
series without this step leaves upstream's style as it is.

## Behaviour changes

None: formatting only.

## How to review

Run the command above and compare; there is nothing to read line by line. Decide on the style,
not the diff.

## Differences from the old step **(gen)**

None: the same change as `series/026-google-style-format`.

## Verified **(gen)**

Windows x64, `29f6d6dead`, 2026-11-03.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: does not build with GCC yet (exit 1); the parent does not either |
| clang_format | n/a: the reformat step changes the style; upstream's check follows it |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core, headers |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
