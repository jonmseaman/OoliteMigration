# Compile the remaining C sources as C++; upgrade QuickJS-ng

**Series:** step 23 of 25 · base `series/022-tests-and-tooling` · next `series/024-upstream-49a5eb9fc-ports` **(gen)**

**From:** `develop` commits `448aa6d20`, `6e1654a6b` · 31.7k src, 5.7k tests, 3.1k other changed lines; 48.2k lines in deleted files **(gen)**

## What this changes

- The remaining C sources build as C++ (`OOTCPStreamDecoder`, MiniZip's `ioapi` and `unzip`,
  `OOPlanetData`, `OOVoxel`, `legacy_random`, and the EXR snapshot's `miniz`), and the code uses C++'s `bool`, `true`/`false` and `nullptr` where it had
  Objective-C's `BOOL`, `YES`/`NO` and `nil`/`NULL`.
- Guards on `OOLITE_GNUSTEP` go where there is no other build left (the debug monitor's
  application-terminate hooks, `main.cpp`'s GNUstep set-up).
- QuickJS-ng 0.17.0 (was 0.16.2), with the patch for its void returns moved to the new line
  numbers.
- `.clang-tidy` and `.editorconfig`; `meson.build`'s comments no longer point at documents that
  are not in the tree.

## Why

With Objective-C gone, the Objective-C spellings and the C-only units were the last places the
code differed from plain C++. QuickJS-ng 0.17.0 is the current release.

## Behaviour changes

None intended: the type and literal changes are mechanical, and the unit tests pass unchanged
apart from the same spellings.

## How to review

Mostly mechanical; `git diff --word-diff` shows the `BOOL`/`bool` and `nil`/`nullptr` changes.
Read `subprojects/quickjs-ng.wrap` and `subprojects/packagefiles/quickjs-ng-void-return.patch`
for the upgrade, and the removed `OOLITE_GNUSTEP` guards.

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
