# Compile the remaining C sources as C++; build QuickJS-ng with the fork's patches

**Series:** step 21 of 24 · base `seriesb/020-tests-and-tooling` · next `seriesb/022-upstream-28ceaaba0-ports` **(gen)**

**Replays:** `series/024-c-as-cxx` (old 24 of the master-based series) · 13.6k src, 5.3k tests, 239 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- The last seven C sources build as C++ and are renamed `.cpp`: `OOTCPStreamDecoder`, MiniZip's
  `ioapi` and `unzip`, `OOPlanetData`, `OOVoxel`, `legacy_random` and the EXR snapshot's `miniz`.
  The changes C++ needs are small: casts from `malloc`'s `void *`, `legacy_random`'s designated
  initialisers in declaration order, `miniz`'s probe table defined before its use. The vendored
  MiniZip and EXR directories get a `.clang-tidy` of their own.
- In code, Objective-C's `BOOL`, `YES`/`NO` and `nil` become `bool`, `true`/`false` and
  `nullptr`, in `src` (241 files) and in the unit tests (228 files). The game's own `extern "C"`
  wrappers and `__cplusplus` tests go; `oofnd`'s declarations of Windows API functions and the
  vendored `miniz`, `tinyexr` and `stb_image_write.h` keep theirs.
- The `-DGNUSTEP_BASE_LIBRARY` define goes from `src/meson/meson.build`, and with it the guards
  that tested it: `OOFoundation.h` no longer derives `OOLITE_GNUSTEP` (`OOLITE_SDL` is 1 on every
  build), `main.cpp`'s `GNUSTEP_BASE_LIBRARY || OOLITE_SDL_MAC` blocks are unconditional, and the
  last `OOLITE_GNUSTEP` tests (`OOFileScannerVerifierStage`, `OOLogOutputHandler`) go. Upstream's
  `OOLITE_SDL` guards (the debug monitor's terminate hooks, `OOJSConsole`, `GameController`,
  `MyOpenGLView`) are kept as they are.
- `main.cpp`'s Windows start-up builds its paths in `std::string`s instead of fixed `char`
  buffers and `strcat`; `OOCPUInfo`'s version string and `OOMeshToOctreeConverter`'s overflow
  storage (`std::vector`) follow the same pattern.
- `OOProfilingStopwatch.h` takes `DWORD` and `timeGetTime()` from `<windef.h>` and
  `<timeapi.h>`: `OOFoundation.h` no longer includes `<winsock2.h>` and `<windows.h>` in every
  file, and including `<windows.h>` here
  would put `<winsock.h>` ahead of a later `<winsock2.h>`. #768's timer is unchanged.
- QuickJS-ng stays at 0.17.0, as #768 has it. `subprojects/quickjs-ng.wrap` becomes a
  `[wrap-file]` for the 0.17.0 tarball, with three patches: `quickjs-ng-o2.patch` (QuickJS-ng's
  own defaults build at `-O2` with `NDEBUG`, the game's pinned level, where its wrapdb defaults
  are `-O3`), `quickjs-ng-void-return.patch` (four `return` statements of a void expression in
  void functions, QuickJS-ng's 4 `-Wpedantic` warnings) and #768's primitive-property patch,
  kept. `subprojects/.gitignore` keeps the fetched source out of the tree, and the flatpak
  manifest fetches the same tarball.
- `tests/check_debug_monitor_guards.py` (new, in the `headers` suite) checks that debug-monitor
  code is guarded by `OO_DEBUG_MONITOR_ENABLED`, not `NDEBUG` (#756's rule). It uses
  `tests/idiom_check.py`, a comment-aware checker for old idioms, added here.
- Tooling: `.clang-tidy` and `.editorconfig`; `./mk.sh` copies `compile_commands.json` to the
  root, where `.clangd` now reads it; `tests/unit/asan-suppressions.txt` for sanitized runs.
- The GUI and component tiers no longer reach for a desktop lock outside this repository
  (`tools/gui-lock`): the `desktop_lock` fixture, its lock environment variables and
  `test_g10`'s guard test of the lock (`test_the_child_cannot_deadlock_on_the_lock_its_parent_holds`)
  go, and `test_g1`'s precondition test checks the `gui_runtime` fixture instead of
  `tools/gui-tier.sh`. Comments in `meson.build`, the meson files and the tests no longer point
  at documents and tools that are not in this repository.

## Why

With Objective-C gone, the C-only units and the Objective-C spellings were the last places the
code was not plain C++. The `[wrap-file]` form lets the build carry its own patches to
QuickJS-ng, and the void-return patch leaves the build with no warnings.

## Behaviour changes

- Warnings (Clang, `-Wall -Wextra`): QuickJS-ng's 4 `-Wpedantic` warnings are gone; the build
  has none.
- Windows start-up: the executable's path is no longer cut at 256 characters, and with
  `OO_GAME_DATA_TO_USER_FOLDER` the user folder path is built in its own string instead of
  being appended to the environment's `LOCALAPPDATA` buffer. Not pinned by a test.
- `-help` given after a trailing `-load` no longer reads `argv[argc]`. Not pinned by a test.
- QuickJS-ng builds at `-O2` from its own defaults (`quickjs-ng-o2.patch`). Not pinned by a test.
- Otherwise none: the other changes are spellings, linkage and guards that were always true.

## How to review

Most of the diff is mechanical; `git diff --word-diff seriesb/020-tests-and-tooling
seriesb/021-c-as-cxx` shows the `BOOL`/`bool` and `nil`/`nullptr` pairs, and many files also
take 80-column wraps and sorted includes on the lines they touch. Read by hand:
`subprojects/quickjs-ng.wrap` and `subprojects/packagefiles/`, `OOFoundation.h`,
`OOProfilingStopwatch.h`, `src/SDL/main.cpp`, `OOMeshToOctreeConverter.cpp`, and the renamed
`.c` files (`git diff -M`). `tests/check_debug_monitor_guards.py` passes on this tree with no
guard to fix.

## Verified **(gen)**

Not verified at this branch's tip (`c5897f4f21`) yet: the last record is for `f518b81af8` (2026-11-03), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
