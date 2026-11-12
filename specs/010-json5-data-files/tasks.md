---
description: "Tasks for JSON5 data files beside property lists (spec 010)"
---

# Tasks: JSON5 data files beside property lists

**Input**: [spec.md](spec.md). Work happens in `oolite-dev` on `feature/json5-data-files`
(worktree `.agent-tmp/wt-json5`). Each task names the command that fails before it and passes after.

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

## Follow-ups (not in this feature)

- The OXP verifier checks for `equipment.plist`, `requires.plist`, `demoships.plist` and
  `shipdata.plist` by name (`src/Core/OXPVerifier/OOCheck*PListVerifierStage.cpp`), so it doesn't
  verify a JSON5-only expansion.
- `OOScript.cpp:192,222,251` picks a script kind by the extension `plist`; a `.json5` legacy script
  file named directly is not recognised.
- Run the game once with a converted `Resources/Config/*.json5` beside its plist (or a test
  expansion shipping `shipdata-overrides.json5`) and read the log for `plist.json5.shadowed`.
- 5b.4 (component scenarios over a converted tree), 5b.5 (`EXPANSION_MIGRATION.md`), 5b.6.
