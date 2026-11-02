# Reformat with Google-style clang-format (optional)

**Series:** step 25 of 25 · base `series/024-upstream-49a5eb9fc-ports` · next `—` **(gen)**

**From:** `develop` commits `13eb19ee7`, `266118a39`, `4ef61a09d`, `21c3048a2` · 378.3k src, 658 tests, 55 other changed lines; 0 lines in deleted files **(gen)**

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

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
