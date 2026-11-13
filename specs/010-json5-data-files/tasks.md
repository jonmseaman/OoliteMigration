---
description: "Tasks for JSON5 data files beside property lists (spec 010)"
---

# Tasks: JSON5 data files beside property lists

**Input**: [spec.md](spec.md). T001–T005 were done in `oolite-dev` on `feature/json5-data-files`
(worktree `.agent-tmp/wt-json5`); T006 on are on `seriesb/030-json5-data-files`, which contains
those commits. Each task names the command that fails before it and passes after.

macOS unit check (D12), from the worktree:

```bash
clang++ -std=c++23 -Wall -Wextra -Werror -I src -I tests/unit/oofnd tests/unit/oofnd/test_plist_json5.cpp -o ../json5-logs/bin/test_plist_json5 && ../json5-logs/bin/test_plist_json5
```

## Phase 1: Reader (US1)

- [x] T001 [US1] `src/oofnd/PListJSON5.hpp` and `tests/unit/oofnd/test_plist_json5.cpp`
  (registered in `tests/unit/oofnd/meson.build`'s `oofnd_plist_tests`). Covers FR-001–FR-005:
  every mapping rule, every escape, numbers (hex, signs, `Infinity`, `NaN`, leading/trailing dot,
  range limits), comments, whitespace, `$data`/`$date`, errors with line and column, depth limit,
  invalid UTF-8. Check: the macOS command above (fails before: no such file).

## Phase 2: Writer (US1)

- [x] T002 [US1] `writeJSON5PList` in `src/oofnd/PListWriting.hpp` (FR-006), with round-trip cases in
  `test_plist_json5.cpp`. Check: as T001.

## Phase 3: Lookup (US2)

- [x] T003 [US2] `src/oofnd/PListFile.hpp` (`loadPListFile`) with cases in `test_plist_json5.cpp`,
  and `src/Core/OOPListParsing.cpp`'s `cxx_OOPropertyListFromFile` using it (FR-007). Check: as T001,
  plus `./mk.sh build debug`.

## Phase 4: Converter (US3)

- [x] T004 [US3] `tools/plist2json5/plist2json5.cpp` and `tools/plist2json5/meson.build` (FR-008,
  D8–D10), with cases in `tools/plist2json5/test_plist2json5.cpp` and tests in suite `plist2json5`. Check:
  `meson test -C build/meson_debug --suite plist2json5` (fails before: no such suite).

## Phase 5: Close-out

- [ ] T005 clang-format 22 on changed `src/` files; `./mk.sh build debug`; the existing plist tests
  by direct compile; commit; push `feature/json5-data-files`; read the CI result. Done up to CI:
  pushed `c492a87a2`; run
  [43168053948](https://github.com/jonmseaman/oolite/actions/runs/43168053948) was in progress.

## Phase 6: Core data in JSON5 (US4)

- [x] T006 [US4] `oo::isJSON5Path`, `oo::existingPListPath`, `oo::parsePListFile` and a direct
  `.json5` path in `oo::loadPListFile` (`src/oofnd/PListFile.hpp`, FR-010–FR-012), with cases in
  `test_plist_json5.cpp`; `ResourceManager::pathForFileNamed`, the built-in readers in
  `ResourceManager`, `Universe` and `OOOXPVerifier`, and `OOScript::scriptsFromFileAtPath` use
  them. Check: the macOS command above (fails before: no such functions), plus
  `./mk.sh --native-file=darwin.ini build debug`.
- [x] T007 [US4] `plist2json5 --parse` (FR-013) and the stale-plist removal in
  `ShellScripts/common/post_build.sh` (FR-014). Check: `plist2json5 --parse Resources` exits 1
  with "no .json5 files found" before T008 and 0 after.
- [x] T008 [US4] `plist2json5 --strings` over `Resources/`, then the 82 converted plists removed
  (D14, D15); `tools/plist2json5/meson.build` gains `json5_resources_parse` and its `--check`
  tests take `Resources/`, `DebugOXP/` and `tools/`. Check: `meson test -C build/meson_debug
  --suite plist2json5` (fails before: no test `json5_resources_parse`), then
  `BUILD_TYPE=debug tests/run.sh smoke` and
  `BUILD_TYPE=debug tests/run.sh component --oolite-app="$PWD/build/meson_debug/oolite.app"`.

## Results (2026-11-12, macOS, Apple clang via `darwin.ini`, debug)

- `test_plist_json5`: 34 tests, 170 checks, 0 failures; the same under ASan and UBSan.
- `test_plist2json5` and `--check` over all 85 core plists in both modes: `meson test --suite
  plist2json5` Ok 3, Fail 0.
- The other plist tests, compiled directly, are unchanged: `test_plist`, `_carrier`,
  `_game_tuples`, `_hdr_brightness_index`, `_oldstyle_strings`, `_oldstyle_structures`,
  `_writers`, `_xml` pass. `test_plist_get` fails 149 checks on macOS **at the base commit too**
  (its header says the `long` rows are exact only on LLP64 Windows); `test_plist_description`
  needs ICU headers the direct compile doesn't have. Neither file is touched here.
- Speed (`planetinfo.plist`, 2.7 MB, -O2, best of 7): OpenStep reader 13.2 ms, JSON5 (`--strings`
  conversion) 10.1 ms, JSON5 (`--typed`) 10.9 ms. The first JSON5 version took 15.0 ms; copying
  ASCII runs in one go fixed that.
- clang-tidy 22 (with the macOS SDK sysroot) reports nothing in the new or changed files.
  `./mk.sh format-check` fails on `PlayerEntity.h`, `OOShaderMaterial.h` and `OOTexture.h`, at the
  base commit too (027 work in progress); the files changed here are clean under clang-format 22.
- Not run: the game itself with a `.json5` file (no Windows machine; on the Mac a game window would
  take the desktop), and GCC. CI on Windows runs `tests/run.sh unit`, which builds
  `test_plist_json5` through meson.
- Found while converting: the XML reader marks every non-negative `<integer>` unsigned (GNUstep's
  NSNumber), which JSON5 can't express, so `--check` compares integers by value (D13).

## Results, Phase 6 (2026-11-13, macOS, Apple clang via `darwin.ini`, debug)

- `test_plist_json5` by direct compile: 37 tests, 198 checks, 0 failures.
- `meson test -C build/meson_debug --suite plist2json5`: Ok 4, Fail 0 (`test_plist2json5`, the two
  `--check` tests over the 21 plists left in `Resources/`, `DebugOXP/` and `tools/`, and
  `json5_resources_parse` over the 82 core `.json5` files).
- Each of the 82 committed `.json5` files compared with its plist at `c492a87a2` by
  `plist2json5::check` (`--strings`, tree `==`): 82 equal, 0 different.
- `./mk.sh --native-file=darwin.ini build debug`: builds; no warning in a changed file.
- `BUILD_TYPE=debug tests/run.sh smoke`: passes before the conversion and after it. The two game
  logs are the same line for line apart from times, temporary paths and one
  `dataCache.rebuild.datesChanged` line; the JSON5 run has no `plist.parse.failed` and no
  `plist.json5.shadowed`.
- `BUILD_TYPE=debug tests/run.sh component --oolite-app="$PWD/build/meson_debug/oolite.app"` on
  the converted tree: 18 passed, 2 skipped (the two Windows-only tests), 14 min 43 s.
- Both files present (the plists of `logcontrol`, `shipdata` and `nullAI` copied back beside their
  `.json5` in the build): the smoke test passes, the JSON5 files are read, and
  `plist.json5.shadowed` is logged once for each of the three. `logcontrol` is read before the
  log is configured, and that works.
- An existing build directory: after the conversion `post_build.sh` leaves 4 plists in the build's
  resources (`Info-gnustep`, `descriptions`, `whitelist`, the generated `manifest`) and 82 `.json5`.
- Not run here: the `gui` tier (Windows only) and the meson `oofnd`, `core` and `headers` suites
  (Windows only; see CI below). GCC locally (CI's Linux builds use it).
- CI on `seriesb/030-json5-data-files` at `dca141e57`
  ([43382544561](https://github.com/jonmseaman/oolite/actions/runs/43382544561)): clang-format,
  and build plus launch test on Ubuntu, Fedora, Windows, macOS, Flatpak and AppImage all pass;
  `unit-tests-windows` fails on `test_string_sweep` alone (the base's failure, below), 43 of 44
  `oofnd` tests passing, `test_plist_json5` among them.
- CI on `claude/030-ci-check` (the same tree plus `cc94abb6d`,
  [43382546855](https://github.com/jonmseaman/oolite/actions/runs/43382546855)): every job
  passes; `tests/run.sh unit` is `oofnd` 44 of 44, `core` 184 of 184 (`test_ResourceManager` with
  its new JSON5 case), `headers` 1 of 1.
- Found on the way: `post_build` runs only when the `oolite` binary is relinked, so a change to
  `Resources/` alone does not reach an existing build's bundle until
  `build/meson_<type>/src/.oolite_bundle.stamp` is removed. Not changed here.
- Found on the way: at the base commit `b692feb4e` the Windows `oofnd` suite fails
  `test_string_sweep` (`pointer_description_is_gnusteps`), which stops `tests/run.sh unit` before
  the `core` suite; `seriesb/027-modern-cpp` fixes it later in `cc94abb6d`. To see the `core`
  suite on this change, the same tree plus that one commit was pushed as `claude/030-ci-check`
  (a CI-only branch; delete it).

## Follow-ups (not in this feature)

- An install over an older one keeps the old core plists beside the new `.json5` files: the game
  reads the JSON5 and logs `plist.json5.shadowed` once per file. The installers (NSIS, Flatpak,
  AppImage, dmg) were not checked for whether they clear `Resources/` first.
- `Config/descriptions.plist` and `Config/whitelist.plist` can become JSON5 once
  `tests/unit/expander` and `tests/unit/sysdesc` read their inputs through `oo::parsePListFile`
  (a test change, so Jon's call).

- The OXP verifier checks for `equipment.plist`, `requires.plist`, `demoships.plist` and
  `shipdata.plist` by name (`src/Core/OXPVerifier/OOCheck*PListVerifierStage.cpp`), so it doesn't
  verify a JSON5-only expansion.
- `OOScript.cpp`: a legacy script found through `world-scripts` is taken in either format (T006),
  but `script.plist` is still looked for by that name only, and a `.json5` name given where a
  JavaScript file is wanted gets the "don't know how to load" message, not the "legacy scripts
  are not supported" one (D19).
- 5b.5 (`EXPANSION_MIGRATION.md`), and the JSON5 mode of `tools/plist_fuzz.py`.
