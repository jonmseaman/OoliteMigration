# Compile the remaining C sources as C++; build QuickJS-ng with the fork's patches

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 21/28. Replays `series/024-c-as-cxx`.

## What this changes

- The last seven C sources (`OOTCPStreamDecoder`, MiniZip `ioapi`/`unzip`, `OOPlanetData`,
  `OOVoxel`, `legacy_random`, EXR `miniz`) build as C++ and are renamed `.cpp`.
- `BOOL`/`YES`/`NO`/`nil` become `bool`/`true`/`false`/`nullptr` in `src` (241 files) and the unit
  tests (228); the game's own `extern "C"` wrappers go (oofnd's Windows API and vendored ones stay).
  `-DGNUSTEP_BASE_LIBRARY` and the `OOLITE_GNUSTEP` guards go; upstream's `OOLITE_SDL` guards stay.
- `main.cpp`'s Windows start-up, `OOCPUInfo` and `OOMeshToOctreeConverter` replace fixed buffers
  with `std::string`/`std::vector`; `OOFoundation.h` no longer includes `<windows.h>` everywhere.
- `subprojects/quickjs-ng.wrap` becomes a 0.17.0 `[wrap-file]` with four patches (`-O2`,
  void-return, #768's two); the flatpak manifest fetches the same tarball.
- New `tests/check_debug_monitor_guards.py` (`headers` suite, #756's rule) on `tests/idiom_check.py`;
  `.clang-tidy`, `.editorconfig`, root `compile_commands.json`, `tests/unit/asan-suppressions.txt`.

## Why

Makes the last C units and Objective-C spellings plain C++, and lets the build patch QuickJS-ng.

## Behaviour changes

- The Clang `-Wall -Wextra` build has no warnings (was QuickJS-ng's 4 `-Wpedantic`). Not pinned by a test.
- Windows: the executable path is not cut at 256 characters, and with `OO_GAME_DATA_TO_USER_FOLDER` the user folder is its own string (was appended to the `LOCALAPPDATA` buffer). Not pinned by a test.
- `-help` after a trailing `-load` no longer reads `argv[argc]`. Not pinned by a test.
- QuickJS-ng builds at `-O2` (was wrapdb's `-O3`). Not pinned by a test.
- Otherwise none: spellings, linkage and always-true guards.

## How to review

Mostly mechanical: `git diff --word-diff seriesb/020-tests-and-tooling seriesb/021-c-as-cxx`
(touched lines also take 80-column wraps and sorted includes). Read by hand:
`subprojects/quickjs-ng.wrap`, `subprojects/packagefiles/`, `OOFoundation.h`,
`OOProfilingStopwatch.h`, `src/SDL/main.cpp`, `OOMeshToOctreeConverter.cpp`, and the renamed `.c`
files (`git diff -M`). One commit is clang-format 22 on `OOCallByName.h` only.

Test edits:
- Unit tests (228 files): `BOOL`/`YES`/`NO`/`nil` spellings only.
- GUI and component tiers: the `desktop_lock` fixture and its environment variables go, with
  `test_g10`'s `test_the_child_cannot_deadlock_on_the_lock_its_parent_holds` (tested the outside
  `tools/gui-lock`).
- `test_g1`: its precondition checks the `gui_runtime` fixture instead of `tools/gui-tier.sh`.
- Comments no longer point at documents and tools outside this repository.

## Verified

Not verified at `7258f16a92`.
