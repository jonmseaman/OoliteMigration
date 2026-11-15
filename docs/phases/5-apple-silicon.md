# Phase 5 — Apple Silicon and Linux x64

**Status:** in progress · **Depends on:** [Phase 4p](4p-upstream-polish.md)

## Goal

Oolite plays on Apple Silicon and Linux x64 with expansions, and the same tests that hold Windows
also hold those two.

## Where it stands (2026-11-15)

**Done:**
- **macOS build:** the game builds for `aarch64-apple-darwin` from `src/meson/darwin/`. CI's
  `build-macos` job builds it, packages an app bundle and a DMG, and runs the smoke launch
  (`./mk.sh test deployment`). Jon plays it on his Mac.
- **Linux builds:** CI builds AppImage, Ubuntu, Fedora and Flatpak, and runs the smoke launch on
  each.
- **Upstream's Apple Silicon port** (#766, #781) is in, in C++.

**Left:** the work items below. The port works. What's missing is test coverage on macOS and Linux,
and three macOS bugs.

## Work items

1. **Build and run the tests on macOS and Linux.** Today they're Windows-only.
   - `meson.build:132-150` builds the unit suites (`oofnd`, `core`) and the `headers` checks only
     when `host_machine.system() == 'windows'`, so `tests/run.sh unit` on a Mac runs nothing.
     Remove the Windows guard, keeping the Windows-only `PATH` test setup at `:123-130`.
   - Fix what fails:
     - The LP64 integer clamping in `oofnd/PListGet.hpp:66-68` is "exact on Windows (LLP64)" only,
       and five `oofnd` tests depend on it.
     - Anything that assumes `long` is 32 bits.
   - Add CI jobs that run `tests/run.sh unit` and `tests/run.sh component --cpp` on `macos-latest`
     and on Ubuntu, like `unit-tests-windows`.
   - Done when both jobs are green.
2. **macOS key mappings.** `KeyMappingsFileName()` in `Entities/PlayerEntityKeyMapper.cpp` has no
   macOS branch, so it returns `""` and `Resources/Config/keymappings_mac.plist` is never used.
   - Add the branch, plus a unit test that it names the Mac file on macOS.
3. **macOS log folder.** `LogBasePath()` in `OOLogOutputHandler.cpp` has branches for Linux and
   Windows only. On macOS, without `OO_LOGSDIR`, the log goes to `Logs/` under the working
   directory.
   - Use upstream 1.93's `~/Library/Logs/Oolite`.
4. **Save, prefs and OXZ paths.** Check that the Mac (Application Support) and Linux (`~/.Oolite`,
   the GNUstep defaults dir) locations match upstream 1.93, so existing players keep their saves
   and OXZs, and pin each one with a unit test.
   - Linux: `run_oolite.sh` computes `OO_GNUSTEPDEFAULTSDIR` but never exports it. Check the
     defaults still land where upstream's did.
5. **CPU detection by architecture.** The x86 `cpuid` assembly in `OOCPUInfo.cpp` is guarded by OS
   (`OOLITE_WINDOWS || OOLITE_LINUX`), not by architecture. It breaks Linux on ARM and
   Windows on ARM.
   - Guard it with `__x86_64__ || _M_X64`, and use `sysctl` or `std::thread::hardware_concurrency()`
     elsewhere.
   - This overlaps P3 in [notes/plans/platform-layer.md](../../notes/plans/platform-layer.md).
6. **Expansions on the Mac.** Run the Tier-1 OXP corpus (`tools/corpus.sh`) and the windowed
   component scenarios (`tests/run.sh component --windowed`) on the Mac once, and record the
   result here.

Items 2, 3 and 5 are listed with their evidence in `notes/2026-11-07 Cross-Platform Correctness.md`.

## Exit gate

- [x] `meson` builds `aarch64-apple-darwin` (`src/meson/darwin/`)
- [x] An app bundle and a DMG are built in CI, and the game launches (the smoke run)
- [x] Linux x64 builds in CI (AppImage, Ubuntu, Fedora, Flatpak)
- [ ] `tests/run.sh unit` and `component --cpp` run and pass on macOS and Linux, in CI (item 1)
- [ ] The macOS key mappings, log folder and path bugs are fixed (items 2–4)
- [ ] The Tier-1 OXP corpus and the windowed component scenarios pass on the Mac (item 6)
- [ ] macOS arm64 and Linux x64 added to the definition of done in `docs/workflow.md`

## Commands

From `oolite-dev`, on each platform: `./mk.sh build dev`, then `tests/run.sh unit` and
`tests/run.sh component`.

## Decisions

- **Signing and notarisation are out of scope.** The DMG stays ad-hoc signed (issue #779). Developer
  ID signing is for upstream to take on.

- **The macOS legs run on Jon's Mac and on CI's `macos-latest`.** Jon grants the TCC prompts on his
  Mac.
- **Renderer:** legacy OpenGL 2.1 stays while macOS still provides it. A new renderer is only needed
  if Apple removes it.
