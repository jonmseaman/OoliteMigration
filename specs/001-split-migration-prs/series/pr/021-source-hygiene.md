# Make comments describe the code; use #pragma once

**Series:** step 21 of 25 · base `series/020-develop-fixes` · next `series/022-tests-and-tooling` **(gen)**

**From:** `develop` commits `2ceced1f8`, `c9c225c78`, `0b49abd31` · 80.7k src, 153.2k tests, 48 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

Comments describe the code as it is: references to the migration's tracker ids, decision
records, phases, slices and tiers are removed, and the comments that only recorded the
migration's history are deleted. Headers use `#pragma once` instead of include guards. Test
assertions that matched tracker ids match the message text instead, and one test-name suffix
becomes `GnustepDiffers`.

## Why

The ids point into a tracker and documents that are not part of this repository, so they mean
nothing to a reader here. `#pragma once` is what upstream's newer headers use.

## Behaviour changes

None. Comments, include guards and test names only; the tests check the same things.

## How to review

Large but repetitive: almost every hunk deletes a parenthesised reference or a history
comment. `git diff --word-diff` is the easiest way to read it. The fork rewrapped its comments at
80 columns when it made this change, and formatting cannot unwrap them, so the files it touches
carry that wrapping (the code itself stays in upstream's layout, and upstream's clang-format
check passes).

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
