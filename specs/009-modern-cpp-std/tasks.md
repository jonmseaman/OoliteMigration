---

description: "Tasks for moving the game onto the C++ standard library (spec 009)"
---

# Tasks: Modern C++ on the standard library

**Input**: Design documents from `specs/009-modern-cpp-std/`

**Prerequisites**:

- [plan.md](plan.md) (milestones M0–M8)
- [spec.md](spec.md) (US1–US7, FR-001–FR-028, SC-001–SC-011)
- [research.md](research.md) (R1–R17)
- [data-model.md](data-model.md)
- [contracts/ownership.md](contracts/ownership.md), [contracts/enums.md](contracts/enums.md),
  [contracts/threads.md](contracts/threads.md), [contracts/strings.md](contracts/strings.md),
  [contracts/guards.md](contracts/guards.md)
- [quickstart.md](quickstart.md)

**Tests**: Included. CLAUDE.md requires every task to have a command that exits nonzero before it
and zero after, and FR-016 asks for tests of preserved behaviour that nothing covers yet. Each task
ends with its **Accept:** command.

**Organization**: by user story, in **execution order**, not priority order (plan.md
*Milestones*). US2 (P2) runs after US7 because its bridge commit waits for Jon's sign-off on two
test-ledger rows; if he signs before Phase 3 ends, Phase 9 may run directly after Phase 3.

| Phase | Milestone | Story |
|---|---|---|
| 1 Setup | — | — |
| 2 Foundational | M0 | — |
| 3 | M1 | US1 C allocation (P1) 🎯 MVP |
| 4 | M2 | US3 threads (P3) |
| 5 | M3 | US4 `oofnd` → std (P4) |
| 6 | M4 | US5 enums P1–P9 (P5) |
| 7 | M5 | US6 casts (P6) |
| 8 | M6 | US7 C strings (P7) |
| 9 | M7 | US2 ownership (P2) |
| 10 Polish | M8 | P10 rename, close-out |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can be done in any order relative to the other [P] tasks of its phase (different files,
  no dependency on an unfinished task). All tasks commit on one branch, one at a time.
- **[Story]**: US1–US7 from spec.md.

## Rules for every task

- **Where.** Game changes in `oolite-dev` on `seriesb/027-modern-cpp`; spec files in the planning
  repo's current branch. Never touch `develop`, `master` or `main`; never force-push.
- **One commit per task**, titled `T0NN: <title>`, ending with the attribution trailer. In
  `oolite-dev`, push after the commit (`git push origin seriesb/027-modern-cpp`) so CI runs; the
  task is done when CI's jobs pass with only the base's known failures (`test_http`,
  `test_OOOXZManager` in `unit-tests-windows`). A task whose Accept is (or includes) a CI run puts
  that run's URL in its commit message as `CI: <url>`, and the run must show the new or changed test
  executing.
- **Platform.** CLAUDE.md's *Commands* assume an MSYS2 UCRT64 shell on Windows. This feature is
  done from macOS: the build, smoke run, clang-tidy and sanitizers run locally, the unit suites run
  in CI's `unit-tests-windows` job (they build only on Windows, research R2), and the component and
  GUI tiers run on a Windows machine when one is available (T009, T105).
- **Every game task's gate**, from `oolite-dev`, before committing:
  `./mk.sh build test && ./mk.sh test test` and, from T007 on, `./mk.sh tidy`.
- **Searches.** `C=../specs/009-modern-cpp-std/check.sh` (from `oolite-dev`). `$C <category>` exits
  nonzero and prints the hits if any are not on the exceptions list; `$C <category> --area <area>`
  limits it to one area; `$C <category> --count` prints the count. Areas: `entities`
  (`src/Core/Entities`), `scripting` (`src/Core/Scripting`), `materials` (`src/Core/Materials`,
  `src/Core/OOOpenGL*`, `src/Core/OOTexture*`), `sdl-debug` (`src/SDL`, `src/Core/Debug`), `core`
  (the rest of `src/Core`), `oofnd` (`src/oofnd`).
- **Exceptions.** A construct that may stay gets its `exceptions.md` row in the same commit.
- **Tests.** Edit a test only under hard rule 1's third exception, with its `test-ledger.md` row in
  the same commit. Never delete a test. A *borderline* or *needs sign-off* row waits for Jon's
  signature before the change that needs it. Never format `tests/`.
- **Format** only the `src/` files you changed, with `/opt/homebrew/opt/llvm@22/bin/clang-format -i`.
- **No suppressions**: no `-Wno-*`, `#pragma … diagnostic`, `NOLINT`, or clang-tidy `IgnoredRegexp`.
- **Never open expansion content** (OXP/OXZ, `AddOns`). The corpus is run through
  `bash tools/corpus.sh tier1` (planning repo) and only its results are read.
- **Behaviour is unchanged** (FR-001). A bug revealed by a conversion is converted unchanged,
  recorded in research.md R14, and fixed in its own task with a test.
- Scratch goes in `.agent-tmp/` (planning repo root).

---

## Phase 1: Setup

**Purpose**: the records and the search tool every later task uses.

- [X] T001 Create `specs/009-modern-cpp-std/exceptions.md` with one table whose columns are
  `category | file | match | construct | required by | owner / release | commit`, where `match` is
  a fixed substring of the permitted line (the search tool drops a hit whose file equals `file` and
  whose line contains `match`); add a sentence above the table saying so, and update the
  *Exceptions list* section of `specs/009-modern-cpp-std/data-model.md` to list the `match` field.
  **Accept:** `grep -q '| category | file | match |' specs/009-modern-cpp-std/exceptions.md`
- [X] T002 Create `specs/009-modern-cpp-std/test-ledger.md` with the columns of data-model.md
  *Test-change ledger* (`test file | lines | forced by | assertions | coverage | commit | signed`),
  and add now, before any change, the rows Jon must sign: `tests/unit/oofnd/test_ref.cpp:514`
  (`willDisposeRunsOnceWithTheObjectWhole`: weak references become empty from the start of
  disposal; *needs sign-off*); the stack and static instances in
  `tests/unit/core/test_OOShaderMaterial.cpp:309,501,588`, `tests/unit/core/test_OODebugMonitor.cpp:780`
  and `tests/unit/oofnd/test_ref.cpp:35` (made shared-owned; *borderline*); the P10 renames of the
  20 existing `enum class` enumerators (*needs sign-off*); `tests/unit/oofnd/test_stdlib.cpp`
  (*reported*: its header leaves the game; Jon decides whether it is retired).
  **Accept:** `grep -c 'needs sign-off\|borderline\|reported' specs/009-modern-cpp-std/test-ledger.md` prints at least 4
- [X] T003 Create `specs/009-modern-cpp-std/check.sh` (bash, `#!/usr/bin/env bash`, committed
  `100755`, check with `git ls-files -s`) implementing the categories `alloc`, `ownership`,
  `thread`, `oofnd`, `enum`, `tbl`, `cast`, `naming`, `cstring`, `cstring-types` with exactly the
  searches in data-model.md *Converted category* (run from `oolite-dev`; `cast` and `naming` run
  `run-clang-tidy -p . -quiet -checks='-*,<check>'` over `src/(Core|SDL|oofnd)/.*\.cpp` with
  `google-readability-casting` and `readability-identifier-naming` respectively, and count
  findings), the `--area` and `--count` options, and the exceptions filter from `exceptions.md`'s
  `file` and `match` columns. Also a `bound <metric>@<milestone>` subcommand: it reads
  `baselines.md`'s table (`| metric | median | spread | better |`), finds the base row `<metric>`
  and the row `<metric>@<milestone>`, and exits 0 only if the later median is no worse than the
  base median by more than the base spread (worse means higher when `better` is `lower`, and
  lower when it is `higher`). `cstring-types` only reports
  (exit 0) unless given `--unclassified`, which lists hits that are neither on the list nor a
  literal-typed declaration (`constexpr`, or initialised from a string literal).
  **Accept:** `cd oolite-dev && ../specs/009-modern-cpp-std/check.sh alloc --count` prints `135` and `../specs/009-modern-cpp-std/check.sh alloc; test $? -eq 1`

---

## Phase 2: Foundational (M0)

**Purpose**: C++23, the guards, baselines and the tests of preserved behaviour (FR-012, FR-016,
FR-021). **No story task starts until this phase is done.**

- [X] T004 Switch the standard to C++23: `cpp_std=c++23` in `oolite-dev/src/meson.build:25` (and
  its comment at `:21`), `oolite-dev/src/oofnd/meson.build:18` (comment at `:3`) and
  `oolite-dev/tools/icosmesh/meson.build:9`; no source change (research R1).
  **Accept:** `cd oolite-dev && ./mk.sh build test && grep -q -- '-std=c++23' compile_commands.json && ! grep -q -- '-std=c++20' compile_commands.json`
- [X] T005 [P] Rewrite the "C++20 only", "compiles with `-fno-exceptions`" and "Header-only,
  C++20" claims in `oolite-dev/src/oofnd/README.md:3,8,50` and the `oofnd` header banners to say
  C++23 and that the game uses exceptions (research R1, R7); leave `tests/` alone.
  **Accept:** `cd oolite-dev && ! rg -n -i 'C\+\+20 only|Header-only, C\+\+20|compiles? with -fno-exceptions' src`
- [X] T006 [P] Add a `tidy` command to `oolite-dev/mk.sh` (`execute_target`), per
  [contracts/guards.md](contracts/guards.md) *`./mk.sh tidy`*: clang-tidy 22
  (`/opt/homebrew/opt/llvm@22/bin` on macOS, `PATH` elsewhere), `run-clang-tidy -p . -quiet
  'src/(Core|SDL|oofnd)/.*\.cpp'`, building first if `compile_commands.json` is missing, exiting
  nonzero when a `WarningsAsErrors` check reports.
  **Accept:** `cd oolite-dev && ./mk.sh tidy`
- [X] T007 Add `cppcoreguidelines-no-malloc`, `cppcoreguidelines-use-enum-class`,
  `readability-identifier-naming` and `google-readability-casting` to `Checks` in
  `oolite-dev/.clang-tidy`, with the `CheckOptions` of contracts/guards.md, none in
  `WarningsAsErrors` yet.
  **Accept:** `cd oolite-dev && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | grep -q 'google-readability-casting' && ./mk.sh tidy`
- [X] T008 Add a step running `./mk.sh tidy` after the Arch build in
  `oolite-dev/.github/workflows/build-all.yaml` (contracts/guards.md *CI step*). Arch's `clang`
  package provides `clang-tidy` and `run-clang-tidy`; the step first prints `clang-tidy --version`
  so a finding that appears only in CI can be traced to a version difference, which is then fixed
  or recorded in `exceptions.md`, never suppressed.
  **Accept:** `grep -q 'mk.sh tidy' oolite-dev/.github/workflows/build-all.yaml`, and the pushed run's Arch job passes
- [X] T009 Record baselines in a new `specs/009-modern-cpp-std/baselines.md`: every category's
  `check.sh --count` (and `--area` counts for `cast` and `cstring`) on the tree after T004 (C++23,
  no source change); and a table `| metric | median | spread | better |` with the base rows
  `start` (start-up seconds from `tests/launch_snapshot.py`, `lower`), `frame` (frames per second
  by the method of `notes/2026-11-10 Frame Rate Comparison.md`, `higher`) and `quit` (seconds to
  exit while start-up planet generation runs, `lower`), each the median and spread (max − min) of
  five runs on this Mac. Also, on the same tree, the sanitizer baselines as rows with spread 0 and
  `lower`: `asan-smoke` (ASan reports in the smoke run), `tsan-smoke` (TSan reports, Homebrew
  clang) and `leaks` (leaks reported by `leaks --atExit`), with the reports saved under
  `.agent-tmp/sanitizers/base-*.txt`. And, on a Windows machine if one is available, the logged
  script-event order of the component scenarios that kill, dock and jump
  (`tests/run.sh component`) saved to `.agent-tmp/events/base.log`; if none is available, add the
  line `events: no Windows machine` to `baselines.md`. Copy the counts into data-model.md's *now*
  column.
  **Accept:** `grep -c '^| ' specs/009-modern-cpp-std/baselines.md` prints at least 15 and `{ test -s .agent-tmp/events/base.log || grep -q '^events: no Windows machine' specs/009-modern-cpp-std/baselines.md; }`
- [X] T010 [P] Add `oolite-dev/tests/unit/core/test_SaveEnumValues.cpp` (registered in
  `tests/unit/core/meson.build`, copying `test_PlayerEntity.cpp`'s set-up): save a player and
  assert today's numbers for `chart_ana_mode`, `chart_colour_mode`, `speech_on`, the legacy
  `energy_unit`, a ship's behaviour, and that loading each back gives the same enum value; pin the
  ordinals of `OOLongRangeChartMode` (research R8: `OOLRC_MODE_UNKNOWN` is 0,
  `OOLRC_MODE_TECHLEVEL` is 4).
  **Accept:** CI `unit-tests-windows` runs `test_SaveEnumValues` and it passes (it does not exist before)
  Added in `f72909226` (4 tests, 50 checks), passing on macOS; CI has not run it yet. Two
  decisions, the conservative reading (rule 8): the whole load (`setCommanderDataFromDictionary`)
  needs the game's data and add-ons (`UNIVERSE->setUseAddOns`, the ship registry), so the saved
  numbers are read back with the loader's own conversion rather than through it; and a ship's
  behaviour is not in a saved game, so its numbers are pinned where they leave the program, the
  by-name `behaviour` call. A full save-and-load belongs to the component suite.
- [X] T011 [P] Add `oolite-dev/tests/unit/core/test_EnumNameFallbacks.cpp`: for every enum with a
  string reverse lookup in `src/Core/OOConstToString.cpp` and `src/Core/Scripting/OOConstToJSString.cpp`,
  assert the default returned for an unknown name and for each known name its value, and for each
  value its exact string.
  **Accept:** CI `unit-tests-windows` runs `test_EnumNameFallbacks` and it passes
  Added in `1790fac04` (38 tests, 535 checks), passing on macOS; CI has not run it yet.
- [X] T012 [P] Add `oolite-dev/tests/unit/core/test_FormatEquivalence.cpp` (registered): a table of
  rows `{printf format, std::format format, arguments}`, each asserting
  `oo::str::format(printf, args...) == std::format(std, args...)`. Seed it with one row per
  specifier mapping research R7 gives (`%g`→`{:g}`, `%u` of an unsigned→`{}`, `%60s`→`{:>60}`,
  `%.4X`→`{:04X}`, `%.*f`→`{:.{}f}`, `%c` of a `char`→`{:c}`, `%06x`, `%016llx`, `%zu`, `%llu`,
  `%.2f`, `%.3g`, `%.3f`, `%i`), with edge values (0, negative, large, NaN for floats). The
  format tasks (T037–T042, T077–T082) add one row per converted call whose format has anything
  but plain `%s` or a same-typed `%d`, using that call's real format strings and argument types;
  rows are only ever added, never changed. In the same task add
  `oolite-dev/tests/unit/core/test_ParseResults.cpp` (registered): for each of the 6
  `atoi`/`atof`/`strtol`/`strtod` call sites in first-party C++, call the function that contains it
  (or the same call with the same arguments) on inputs with a sign, a leading `+`, leading spaces,
  trailing junk, an empty string and an overflowing value, asserting today's results (FR-028).
  **Accept:** CI `unit-tests-windows` runs `test_FormatEquivalence` and `test_ParseResults` and both pass

- [X] T013 [P] Restore the JS API snapshot generator Jon removed from the repo, into scratch only:
  `git show bd7a4392d^:tools/js_api_snapshot.py`, `bd7a4392d^:tools/js-api-snapshot.sh` and
  `8958acc80^:tools/js-api-check.sh` into `.agent-tmp/js-api/` (not committed; nothing is added
  back to `tools/`). Run it against the T004 build to write `.agent-tmp/js-api/base.json`, run it a
  second time to `.agent-tmp/js-api/base2.json` to prove it is deterministic, and record the file's
  `sha256` in `baselines.md` as `| js-api | <sha256> |`. If it no longer runs against today's
  game, record why in research.md R12, mark FR-001's and SC-006's "script API snapshot" as dropped
  in spec.md's *Decisions and notes*, and remove the snapshot steps from the later tasks.
  **Accept:** `diff -q .agent-tmp/js-api/base.json .agent-tmp/js-api/base2.json && grep -q '^| js-api | [0-9a-f]\{64\} |' specs/009-modern-cpp-std/baselines.md`

**Checkpoint**: C++23 builds everywhere CI builds; `./mk.sh tidy` runs locally and in CI;
baselines and the FR-016 tests exist and pass on the base.

---

## Phase 3: User Story 1 — C allocation (Priority: P1, M1) 🎯 MVP

**Goal**: no `malloc`/`calloc`/`realloc`/`free` in first-party C++ outside the exceptions list
(FR-004, FR-005, SC-001). **Independent test**: `$C alloc` exits 0; a planted `malloc` fails
`./mk.sh tidy`; ASan smoke clean.

- [X] T014 [US1] Add `oolite-dev/src/Core/OODemangle.h` with `std::string OODemangle(const char*
  mangled)` (calls `abi::__cxa_demangle`, frees through `std::unique_ptr<char,
  decltype(&std::free)>`, returns the input on failure), use it at the 8 sites
  (`src/Core/OOALSound.cpp:169`, `src/Core/OODrawable.cpp:67`, `src/Core/Materials/OOMaterial.cpp:70`,
  `src/Core/Materials/OOTexture.cpp:388`, `src/Core/Materials/OOTextureLoader.cpp:234`,
  `src/Core/OXPVerifier/OOOXPVerifierStage.cpp:81`, `src/Core/Scripting/OOScript.cpp:69`,
  `src/Core/Entities/EntityHelpers.cpp:130`), and
  add the `exceptions.md` row (category `alloc`, file `src/Core/OODemangle.h`, required by
  `abi::__cxa_demangle` returning `malloc` memory).
  **Accept:** `cd oolite-dev && ! rg -n 'free\s*\(\s*demangled' src`
- [ ] T015 [P] [US1] (part 1 done, `oolite-dev` `a47133c73`: streamed buffer and the Vorbis leak; the `readCreatingBuffer` interface waits for its borderline ledger row) Sound buffers to `std::vector<char>` in `src/Core/OOALSoundDecoder.cpp:316,351,443`,
  `src/Core/OOALStreamedSound.cpp:35,62` and `src/Core/OOALBufferedSound.cpp:35`; this fixes the
  per-read leak in `OOReadOXZVorbis` (`OOALSoundDecoder.cpp:442`, research R4).
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/OOALSoundDecoder.cpp src/Core/OOALStreamedSound.cpp src/Core/OOALBufferedSound.cpp`
- [X] T016 [P] [US1] Zip read buffers to `std::vector<char>` in `src/Core/OODataFromOXZFile.cpp:124,138`.
  **Accept:** `cd oolite-dev && $C alloc --area core | { ! grep -q OODataFromOXZFile; }`
- [ ] T017 [US1] (waits for the pixel-chain borderline ledger row) The pixel-buffer chain as one unit: an owning buffer (`std::vector<std::uint8_t>`)
  in `src/Core/Materials/OOPixMap.cpp`/`.h` (`:76,85,110`), and its users
  `src/Core/OOTextureScaling.cpp:283,355-360,1684`, `src/Core/Materials/OOPixMapChannelOperations.cpp:122,125`,
  `src/Core/Materials/OOTextureLoader.cpp:201,349,364,381,398`, `src/Core/Materials/OOConcreteTexture.cpp:137,478,568`,
  `src/Core/Materials/OOPNGTextureLoader.cpp:88,136-160` (libpng fills our rows; GL copies).
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Materials/OOPixMap.cpp src/Core/OOTextureScaling.cpp src/Core/Materials/OOPixMapChannelOperations.cpp src/Core/Materials/OOTextureLoader.cpp src/Core/Materials/OOConcreteTexture.cpp src/Core/Materials/OOPNGTextureLoader.cpp`
- [ ] T018 [US1] (waits for the pixel-chain borderline ledger row) The planet and atmosphere generators: remove the `FREE` macro (`:63/:65`) and its
  about 12 `malloc`s in `src/Core/Materials/OOPlanetTextureGenerator.cpp` and
  `src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp`, using T017's buffer where the result
  becomes a pixmap and `std::vector` elsewhere.
  **Accept:** `cd oolite-dev && ! rg -n -P '\bFREE\s*\(|(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Materials/OOPlanetTextureGenerator.cpp src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp`
- [X] T019 [P] [US1] Snapshot buffers to `std::vector` in `src/SDL/MyOpenGLView.cpp:1289-1516`.
  **Accept:** `cd oolite-dev && $C alloc --area sdl-debug | { ! grep -q MyOpenGLView; }`
- [ ] T020 [P] [US1] JS vector and quaternion private data in `src/Core/Scripting/OOJSVector.cpp:177,184,495`
  and `src/Core/Scripting/OOJSQuaternion.cpp:143,150,461`: `new`/`delete` of the C++ type, deleted
  in the existing finaliser; `exceptions.md` rows (category `alloc`, owner the JS object, release
  the finaliser).
  **Accept:** `cd oolite-dev && ! rg -n -P '\b(malloc|calloc|free)\s*\(' src/Core/Scripting/OOJSVector.cpp src/Core/Scripting/OOJSQuaternion.cpp`
- [ ] T021 [P] [US1] Static tables in `src/Core/Scripting/OOJSClasses.cpp:71,122-123` to
  `std::array`/`std::vector` with static lifetime (QuickJS keeps the pointer and never frees it).
  **Accept:** `cd oolite-dev && ! rg -n -P '\b(malloc|calloc|realloc)\s*\(' src/Core/Scripting/OOJSClasses.cpp`
- [ ] T022 [P] [US1] Growable arrays to `std::vector` in `src/Core/Octree.cpp:84,113,809-917`,
  `src/Core/CollisionRegion.cpp:67,98,202` and `src/Core/OOPolygonSprite.cpp:187-622`.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Octree.cpp src/Core/CollisionRegion.cpp src/Core/OOPolygonSprite.cpp`
- [ ] T023 [P] [US1] Growable arrays to `std::vector` in `src/Core/OOSkyDrawable.cpp:522-608`,
  `src/Core/OOCrosshairs.cpp:44,89`, `src/Core/HeadUpDisplay.cpp:4470-4533`,
  `src/Core/Materials/OOShaderProgram.cpp:559-580` and `src/Core/Materials/OOShaderMaterial.cpp:301,707`.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/OOSkyDrawable.cpp src/Core/OOCrosshairs.cpp src/Core/HeadUpDisplay.cpp src/Core/Materials/OOShaderProgram.cpp src/Core/Materials/OOShaderMaterial.cpp`
- [ ] T024 [P] [US1] The rest: `std::vector` in `src/Core/OOProbabilitySet.cpp:391-514`,
  `src/Core/OOProbabilisticTextureManager.cpp:93-169` (four parallel arrays), `src/Core/OOSoundSourcePool.cpp:62,76`,
  `src/Core/Scripting/OOJSFrameCallbacks.cpp:366,377`, `src/Core/Entities/ShipEntity.cpp:13807,13823`
  (`JSValue` argv); `std::unique_ptr` for the handle in `src/Core/Debug/OOTCPStreamDecoder.cpp:72,98`.
  **Accept:** `cd oolite-dev && $C alloc`
- [ ] T025 [US1] Make `cppcoreguidelines-no-malloc` fatal (`WarningsAsErrors` in
  `oolite-dev/.clang-tidy`); run the ASan smoke run (quickstart M1) and `leaks --atExit` and
  record them as `asan-smoke@M1` and `leaks@M1` in `baselines.md`; mark `alloc` `fatal` in
  data-model.md.
  **Accept:** `cd oolite-dev && $C alloc && $C bound asan-smoke@M1 && $C bound leaks@M1 && ./mk.sh tidy && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | sed -n '/WarningsAsErrors/,/^[A-Z]/p' | grep -q no-malloc`

**Checkpoint**: US1 complete and independently verified (SC-001).

---

## Phase 4: User Story 3 — threads (Priority: P3, M2)

**Goal**: owned standard threads; no `oo::thread::detach`; `isMainThread()` a helper over the standard id (FR-010, FR-011).
**Independent test**: `$C thread` exits 0; quit with a background task within the baseline; TSan
smoke clean. Contract: [contracts/threads.md](contracts/threads.md).

- [X] T026 [US3] (design D4) In `src/Core/OOAsyncWorkManager.cpp`/`.h`: workers as
  `std::vector<std::jthread>` in the internal object, waiting on
  `std::condition_variable_any::wait(lock, stopToken, pred)`; `void shutdown() noexcept` exactly as
  the contract declares; the singleton as a never-deleted function-local static
  (`static auto& s = *new …`, an `exceptions.md` row) replacing `pthread_once` and the Windows
  mutex; remove the `oo::thread::detach` call (`:183`), keeping `setCurrentPriority(0.5)` and
  `setCurrentName(...)` (`:193-194`).
  **Accept:** `cd oolite-dev && ! rg -n 'oo::thread::detach|pthread_once' src/Core/OOAsyncWorkManager.cpp`
- [X] T027 [US3] Call `OOAsyncWorkManager`'s `shutdown()` on the quit path before `exit(0)` in
  `src/Core/GameController.cpp:706`; add `tests/unit/core/test_OOAsyncWorkManagerShutdown.cpp`
  (queue a long task, call `shutdown()`, assert it returns once the task ends and that queued tasks
  do not run), registered as **its own** meson test executable so that shutting down the
  process-wide manager cannot affect other tests. Quitting during an expansion download (US3 AS-2)
  is already pinned by `tests/unit/oofnd/test_http.cpp`'s `cancel_interrupts_a_stalled_body` (a
  download stalled mid-body is cancelled and its destructor joins the worker within 10 s), and
  `oo::http` does not change in this story, so no new HTTP test is added (decided 2026-11-12).
  **Accept:** `cd oolite-dev && rg -q 'shutdown\(\)' src/Core/GameController.cpp`, and CI runs the new test and it passes
- [X] T028 [US3] Add `inline const std::thread::id kMainThreadId` to `src/oofnd/Thread.hpp` per the
  contract; replace `isMainThread()` at `src/Core/OORegExpMatcher.cpp:43,90`,
  `src/Core/GameController.cpp:143`, `src/Core/OOAsyncWorkManager.cpp:304` with
  `std::this_thread::get_id() == oo::thread::kMainThreadId`; make
  `src/Core/OOLogOutputHandler.cpp:100,107,238` use it instead of `sMainThreadID`; delete `detach`
  from `Thread.hpp` (`isMainThread()` stays as a helper over `kMainThreadId`, Jon 2026-11-12); port their cases in `tests/unit/oofnd/test_thread.cpp`
  (ledger rows, *covered*).
  **Accept:** `cd oolite-dev && $C thread && ! rg -n 'sMainThreadID' src`
- [X] T029 [US3] TSan smoke run (quickstart M2) and quit-time measurement (five runs); record the
  rows `| quit@M2 | median | spread | lower |` and `tsan-smoke@M2` in `baselines.md`. Check the
  worker threads' names under a debugger (`lldb`, `thread list` while the game runs) and record
  them in `baselines.md` as `thread names: <names>`; they must read `OOAsyncWorkManager thread N`
  as on the base (US3 AS-4).
  Measure the base again in the same session from a `git worktree` of `518520d43` and record it as the base rows for the comparison (baselines.md *Same-session comparison*).
  **Accept:** `cd oolite-dev && $C bound quit@M2 --base quit@M2-base && $C bound tsan-smoke@M2 && grep -q '^thread names: .*OOAsyncWorkManager thread' ../specs/009-modern-cpp-std/baselines.md`

**Checkpoint**: US3 complete.

---

## Phase 5: User Story 4 — `oofnd` keeps only what std lacks (Priority: P4, M3)

**Goal**: FR-012–FR-014; research R7. **Independent test**: `$C oofnd` exits 0;
`src/oofnd/Expected.hpp` gone; README lists every survivor with its reason.

- [X] T030 [US4] `oo::Expected`/`oo::Unexpected`/`oo::unexpect`/`oo::BadExpectedAccess` to
  `std::expected`/`std::unexpected`/`std::unexpect`/`std::bad_expected_access` across `src`
  (18 game names in 10 files, 26 in `src/oofnd/FileSystem.hpp`, the other `oofnd` headers); delete
  `src/oofnd/Expected.hpp`; port `tests/unit/oofnd/test_expected.cpp` and the other tests that name
  them (ledger rows, *covered*).
  **Accept:** `cd oolite-dev && ! rg -n 'oo::(Expected|Unexpected|unexpect|BadExpectedAccess)\b|oofnd/Expected\.hpp' src tests && test ! -e src/oofnd/Expected.hpp`
- [X] T031 [US4] Replace every `#include "oofnd/StdLib.hpp"` in game code (164 files) with the
  standard headers that file uses; fix the stale true/false-guard comment at
  `src/Core/OOAsyncWorkManager.cpp:34`; keep `src/oofnd/StdLib.hpp` itself until Jon rules on the
  `test_stdlib` ledger row.
  **Accept:** `cd oolite-dev && ! rg -n 'oofnd/StdLib\.hpp' src --glob '!src/oofnd/StdLib.hpp' --glob '!*.md'`
- [X] T032 [P] [US4] Derive `oo::Exception` from `std::exception` in `src/oofnd/Exception.hpp`
  (`what()` returns today's message); add `tests/unit/oofnd/test_exception_std.cpp` (registered)
  that catches a raised `oo::Exception` as `std::exception` and checks the message text.
  **Accept:** CI runs `test_exception_std` and it passes (it does not compile before)
- [X] T033 [US4] Integer aliases (research R7): `NSInteger` → `std::ptrdiff_t`, `NSUInteger` →
  `std::size_t`, `NSTimeInterval` and `CGFloat` → the type `src/oofnd/objc/OOFoundationTypes.h`
  aliases today; `NSNotFound` → `inline constexpr std::ptrdiff_t kNotFound = INTPTR_MAX;` in
  namespace `oo` in that header; `NSRange`'s fields to `std::size_t`; delete the aliases. Leave the
  frozen strings in `src/Core/OOTypeEncodings.h` and `src/Core/Entities/OOEntityObjectNamesTable.h`
  untouched. Port the tests that name them, and `tests/unit/oofnd/test_foundation_types.cpp`
  where each assertion has a counterpart; report the rest (ledger).
  **Accept:** `cd oolite-dev && $C oofnd`
- [X] T034 [P] [US4] `src/oofnd/Date.hpp`: replace the hand-written civil-date arithmetic
  (`:80-106`) with `std::chrono::year_month_day` and `std::format("{:%F %T}",
  std::chrono::floor<std::chrono::seconds>(…))`; keep the 2001 reference-date constant,
  `localUTCOffsetMinutes` and the double-seconds helpers; `tests/unit/oofnd/test_date.cpp`
  unchanged.
  **Accept:** CI `test_date` passes and `cd oolite-dev && ! rg -n -P '\b(146097|719468|365\s*\*\s*4\s*\+\s*1)\b' src/oofnd/Date.hpp`
- [X] T035 [P] [US4] (decided 2026-11-12, no code change: the six wrappers are one- or two-line helpers over `std::filesystem` that turn its `std::error_code` into `std::expected`; calling `std::filesystem` directly would add `std::error_code ec;` at 23 game and 27 test call sites, so they stay under decision 11) `src/oofnd/FileSystem.hpp`: callers of `fileExists`, `isDirectory`,
  `fileSize`, `freeSpace`, `currentDirectory` and `setCurrentDirectory` use `std::filesystem`'s
  `std::error_code` overloads directly; delete those six wrappers; port their cases in
  `tests/unit/oofnd/test_filesystem.cpp` (ledger, *covered*). The other functions keep GNUstep
  semantics and stay.
  **Accept:** `cd oolite-dev && ! rg -n -P 'oo::fs::(fileExists|isDirectory|fileSize|freeSpace|currentDirectory|setCurrentDirectory)\b' src tests`
- [X] T036 [US4] Survey: build once locally with `-Wformat-signedness` added on the command line
  (`meson configure` of a scratch build directory, not committed) and write the per-area findings
  and every `oo::str::format` literal containing `{` or `}` to `specs/009-modern-cpp-std/format-survey.md`.
  **Accept:** `test -s specs/009-modern-cpp-std/format-survey.md && grep -c '^## ' specs/009-modern-cpp-std/format-survey.md` prints 6
- [X] T037 [US4] Literal `oo::str::format` calls → `std::format` in area `entities`, by hand per
  research R7 (`%g` → `{:g}`, `%u` of a signed value keeps its unsigned conversion, `%60s` →
  `{:>60}`, `%c` of an `int` → `{:c}` of a `char`, `%.4X` → `{:04X}`, braces escaped); `DESC`
  formats and `vformat` stay printf.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Entities` and CI `test_FormatEquivalence` (with this area's rows added) and `test_SaveEnumValues` pass
- [X] T038 [US4] As T037, area `scripting` (leave `src/Core/Scripting/OOJSPlayerShip.cpp:1928`'s
  data format).
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Scripting`
- [X] T039 [US4] As T037, area `materials`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Materials src/Core/OOOpenGL* src/Core/OOTexture*`
- [X] T040 [US4] As T037, area `sdl-debug`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/SDL src/Core/Debug`
- [X] T041 [US4] As T037, area `core` (leave `OOShipLibraryDescriptions.cpp:154,161,171`'s data
  formats).
  **Accept:** `cd oolite-dev && $C oofnd && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core --glob '!src/Core/{Entities,Scripting,Materials,Debug}/**'`
- [X] T042 [US4] (nothing to convert: no literal `oo::str::format` call in `src/oofnd` outside `String.hpp`) As T037, area `oofnd` (its own literal calls).
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/oofnd --glob '!src/oofnd/String.hpp'`
- [X] T043 [US4] (done 2026-11-12: 672 sites remain, all outside literal `oo::str::format` calls, so the flag stays off; research R7 lists them) Add `-Wformat-signedness` to the game's warning flags in `src/meson.build` if the
  whole tree builds without that warning; if not, record the remaining sites in research.md R7 and
  leave it off.
  **Accept:** `cd oolite-dev && ./mk.sh build test 2>&1 | { ! grep -q 'Wformat-signedness'; }`
- [X] T044 [US4] Rewrite `src/oofnd/README.md`'s rules (C++23; exceptions are used) and add a
  *Surviving components* table (component | reason | pinned by) covering every row of data-model.md
  *Surviving `oofnd` component*. Where a component's reason names a difference from the standard
  library and no existing test pins it, add the case to a new
  `tests/unit/oofnd/test_std_differences.cpp` (registered), for example `hasPrefix("")` false
  where `starts_with("")` is true (FR-014); the table's *pinned by* names that test.
  **Accept:** `cd oolite-dev && for c in Data String FileSystem Date Exception Finally NSRange PrintfFormat Notification Scanner Process Log LogFile Http Defaults ResourcePaths Encoding PList OOAssert Thread; do grep -q "| \`*$c" src/oofnd/README.md || exit 1; done && ! grep -E '^\| .*\|\s*\|\s*$' src/oofnd/README.md` (no empty *pinned by*), and CI runs `test_std_differences` and it passes

**Checkpoint**: US4 complete (US4 acceptance 1–4).

---

## Phase 6: User Story 5 — enums P1–P9 (Priority: P5, M4)

**Goal**: FR-017–FR-020; research R8; [contracts/enums.md](contracts/enums.md).
**Independent test**: `$C enum` exits 0; only `OOOpenGLStates.tbl` remains; `test_SaveEnumValues`
and `test_EnumNameFallbacks` pass; corpus unchanged. Every test stand-in that redeclares a
production enum changes in the same commit as it.

- [X] T045 [US5] Create `specs/009-modern-cpp-std/external-values.md` (columns of data-model.md
  *External names and values*) with a row for every name and number in research.md R8's
  visibility table, the value read from the code (not a `.tbl` column), and `pin` set to the
  `static_assert` or test that will pin it.
  **Accept:** `grep -c '^| ' specs/009-modern-cpp-std/external-values.md` prints at least 40
- [X] T046 [US5] (design D3) Add `src/Core/OOEnumFlags.h` and `src/Core/OOEnumTable.h` exactly as
  contracts/enums.md declares them; convert `src/Core/Debug/OODebugFlags.h` to the exemplar shape
  (`enum class OODebugFlags : std::uint32_t`, `OOEnableFlagOperators`, `OOEnumName` with the
  `DEBUG_*` spellings, `static_assert`s), replacing `#define DEBUG_ALL` and the `#x` stringification
  in `src/Core/Scripting/OOJSConsole.cpp:222-223` with `OOEnumName`; check whether the global
  operators are found inside `namespace oo` and record the answer in the contract.
  **Accept:** `cd oolite-dev && rg -q 'enum class OODebugFlags' src/Core/Debug/OODebugFlags.h && ! rg -n '#define DEBUG_ALL' src`
- [X] T047 [P] [US5] P2: named enums local to a `.cpp` file (about 12) to `enum class` with
  `kPascalCase` enumerators.
  **Accept:** `cd oolite-dev && ! rg -n -P '^\s*(typedef\s+)?enum\s+(?!class\b)\w+' src --glob '*.cpp' --glob '!src/Core/MiniZip/**' --glob '!src/SDL/EXRSnapshotSupport/**'`
- [X] T048 [P] [US5] P3: anonymous enums that hold one constant → `inline constexpr` of the
  constant's natural type, areas `entities` and `core`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core --glob '!src/Core/{Scripting,Materials,Debug}/**'`
- [X] T049 [P] [US5] As T048, areas `scripting` and `sdl-debug`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core/Scripting src/Core/Debug src/SDL --glob '!src/SDL/EXRSnapshotSupport/**'`
- [X] T050 [P] [US5] As T048, area `materials`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core/Materials src/Core/OOOpenGL* src/Core/OOTexture*`
- [X] T051 [US5] P4: named header enums in `src/Core/Entities` (and `src/Core/OOTypes.h`,
  `src/Core/OOEntityEnums.h`) that are neither in `external-values.md` nor flags nor P9 groups
  (for example `OOPrimedEquipmentMode`, `OOAegisStatus`, `OOMassUnit`, `OOCargoFlag`), converted to
  the contract's shape.
  **Accept:** `cd oolite-dev && ! rg -n -P '(\}\s*|\benum\s+)(OOPrimedEquipmentMode|OOStellarBodyType|OOComparisonType|OOOperationType|OOEntityObjectNameKind|OOAegisStatus|OOMassUnit|OOCargoFlag)\b(?!\s*class)' src` (all eight match today)
- [X] T052 [US5] P5: `ALERT_FLAG_*` (`src/Core/Entities/PlayerEntity.h:216`) → `enum class
  OOAlertFlags : std::uint16_t` with flag operators; mixed comparisons such as
  `alertFlags > ALERT_FLAG_YELLOW_LIMIT` (`PlayerEntity.cpp:5870`) keep their meaning through
  `oo::ToUnderlying`; the JS alert-flag properties (`OOJSPlayer.cpp:273-293`) keep their numbers
  (`static_assert`s).
  **Accept:** `cd oolite-dev && ! rg -n '\bALERT_FLAG_' src`
  Done as the `OODebugFlags` exemplar: the player keeps the flags as a `std::uint16_t` number
  (the by-name `alertFlags` answers it) and `OOAlertFlagIsOn` reads a bit. `test_OOJSPlayer`'s
  stand-in keeps its own `ALERT_FLAG_*` numbers; the `static_assert`s match them.
- [X] T053 [US5] P5: `OOWeaponFacing` and `VALID_WEAPON_FACINGS` (`src/Core/OOTypes.h:204-215`) →
  `enum class OOWeaponFacing : std::uint8_t` flags; `weapon_facings` plist bits and
  `weaponFacings` JS numbers pinned.
  **Accept:** `cd oolite-dev && ! rg -n '\bVALID_WEAPON_FACINGS\b|\bWEAPON_FACING_' src`
- [X] T054 [US5] P5: `kOOUniformConvert*` (`src/Core/Materials/OOShaderMaterial.h:48`),
  `kOOExpand*` (`src/Core/OOStringExpander.h:34`), `kOORegExp*` → flag `enum class`es.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<!::)\bkOO(UniformConvert|Expand|RegExp)\w+' src`
- [X] T055 [US5] P5: `kOOByName*` (`src/Core/Entities/OOEntityCalledByName.h:46`, about 1,006
  references in `OOEntityCalledByNameTable.h`) → `enum class OOByName : unsigned` flags.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<!::)\bkOOByName\w+' src`
- [X] T056 [US5] P5, last: `OOTexture` flags (`src/Core/Materials/OOTexture.h:47`, 29 values,
  multi-bit filter and channel fields; 275 src and 95 test references) → flag `enum class
  OOTextureFlags : std::uint32_t`; the `%X` cache key (`OODefaultShaderSynthesizer.cpp:353`)
  keeps its text; tests that name the flags change with it (ledger, *covered*).
  **Accept:** `cd oolite-dev && $C enum --area materials | { ! grep -q 'Materials/OOTexture.h'; }` and `rg -q 'enum class OOTextureFlags' src/Core/Materials/OOTextureFlags.h`
  Done in `9ef8f2e7c`: made on its own branch while its *borderline* ledger rows (literal option
  numbers and `uint32_t` stand-ins in the tests) waited; Jon signed them on 2026-11-12 and it was
  cherry-picked onto `seriesb/027-modern-cpp` after T059.
  The enum is in `OOTextureFlags.h`, not `OOTexture.h` (the accept's second half was changed to
  match): the loaders do not include `OOTexture.h`, so tests can stand in for `OOTexture`.
- [X] T057 [US5] P6: number-visible enums (`OOAlertCondition` in `src/Core/Entities/ShipEntity.h:191-198`;
  `OOSpeechSettings`, `OOFuelScoopStatus`, `OOMissileStatus`, `OOPlayerFleeingStatus`,
  `OOMarketFilterMode`, `OOMarketSorterMode` in `src/Core/Entities/PlayerEntity.h:86-262`;
  `OOStationAlertLevel` in `src/Core/Entities/StationEntity.h:39-43`) → `enum class … :
  std::int32_t` with a `static_assert` per value used by shaders (`EntityShaderBindings.cpp:611-661`),
  saves, JS and description keys.
  **Accept:** `cd oolite-dev && ! rg -n -P '\}\s*(OOAlertCondition|OOSpeechSettings|OOFuelScoopStatus|OOMissileStatus|OOPlayerFleeingStatus|OOMarketFilterMode|OOMarketSorterMode|OOStationAlertLevel)\s*;' src`
- [X] T058 [US5] P7, step 1: replace every `CASE(#foo)`/`REVERSE_CASE` use in
  `src/Core/OOConstToString.cpp:33-37` and the hand switch in `src/Core/Entities/WormholeEntity.cpp:854-866`
  with explicit `OOEnumName` switches spelling today's strings, before any rename; `test_EnumNameFallbacks` passes.
  **Accept:** `cd oolite-dev && ! rg -n -P '\bCASE\s*\(|REVERSE_CASE' src/Core/OOConstToString.cpp`
- [X] T059 [US5] P7, step 2: `OOCargoType`, `OORouteType`, `OOEnergyUnitType`,
  `OODockingClearanceStatus`, `OOGraphicsDetail` (`src/Core/OOTypes.h`), `OOHDRToneMapper`,
  `OOSDRToneMapper` (`src/SDL/MyOpenGLView.h:148-164`), `OOShaderSetting` (`src/Core/OOOpenGL.h:38-44`),
  `WORMHOLE_SCANINFO` (`src/Core/Entities/WormholeEntity.h:42-49`) → `enum class` with
  `kPascalCase` enumerators.
  **Accept:** `cd oolite-dev && ! rg -n -P '\}\s*(OOCargoType|OORouteType|OOEnergyUnitType|OODockingClearanceStatus|OOGraphicsDetail|OOHDRToneMapper|OOSDRToneMapper|OOShaderSetting|WORMHOLE_SCANINFO)\s*;' src`
- [X] T060 [US5] P8: `OOScanClass`, `OOEntityStatus`, `OOShipDamageType` tables → headers per
  `notes/2026-11-07 Enum Tables from tbl X-Macros.md` and contracts/enums.md; delete their `.tbl`
  files; update `OOConstToString.cpp:39-48,122-127` and `OOConstToJSString.cpp:76-82`.
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOScanClass.tbl && test ! -e src/Core/Tables/OOEntityStatus.tbl && test ! -e src/Core/Tables/OOShipDamageType.tbl`
- [X] T061 [US5] P8: `OOBehaviour`, `OOGalacticHyperspaceBehaviour` (its `GALACTIC_HYPERSPACE_##label`
  pasting replaced by explicit strings), `OOLegalStatusReason`.
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOBehaviour.tbl && test ! -e src/Core/Tables/OOGalacticHyperspaceBehaviour.tbl && test ! -e src/Core/Tables/OOLegalStatusReason.tbl`
- [X] T062 [US5] P8: `OOCompassMode`, `OOViewID` (the program's ordinals, not the `.tbl` column:
  `VIEW_CUSTOM` 4, `VIEW_NONE` 5, `VIEW_GUI_DISPLAY` 6, `VIEW_BREAK_PATTERN` 7, `static_assert`ed;
  leave the `HeadUpDisplay.cpp:4658` missing-`VIEW_CUSTOM` behaviour as it is and record it in R14).
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOCompassMode.tbl && test ! -e src/Core/Tables/OOViewID.tbl`
- [X] T063 [US5] P8: `OOLongRangeChartMode` (save-visible ordinals pinned by `test_SaveEnumValues`)
  and `OOGUIScreenID` (ordinals 0…28); update the `.tbl` include in
  `tests/unit/core/test_OOJSSound.cpp` (ledger, *covered*).
  **Accept:** `cd oolite-dev && ls src/Core/Tables/*.tbl | grep -c tbl` prints 1 and `$C tbl`
- [X] T064 [US5] (design D5) Decide, per int-natured group, `enum class` or typed constants
  (JS property IDs, GUI rows, `AXIS_*`/`BUTTON_*`, `STICKPROFILE_TYPE_*`, `GameViewKeys`,
  `OOPixMapFormat`, the debug TCP protocol numbers), defaulting as research R8 says; record each
  decision in research.md R8 and each typed-constant group in `exceptions.md`.
  **Accept:** `grep -c 'D5:' specs/009-modern-cpp-std/research.md` prints 7
- [X] T065 [US5] P9: the 27 JS property-ID enums (`src/Core/Scripting/OOJSShip.cpp:202` and the
  others) → `enum class … : std::int16_t`; cast once in the `OOJS_PROPERTY_*` macros
  (`src/Core/Scripting/OOJSEngineCore.h`), `using enum` in each getter's `switch (magic)`;
  `OOJS_PROP_*` flags stay (exceptions row).
  **Accept:** `cd oolite-dev && $C enum --area scripting`
- [X] T066 [US5] P9: GUI rows: `GUI_ROW()` (`src/Core/Entities/PlayerEntity.h:68-72`) and the row
  macro sets in `PlayerEntityKeyMapper.h:42-65`, `PlayerEntityContracts.h:59`,
  `PlayerEntityStickMapper.h:40-51`, `PlayerEntityStickProfile.cpp:38`, `PlayerEntityLoadSave.h:42-52`
  → per T064; replace `#if GUI_FIRST_ROW() < 0` (`PlayerEntity.h:165,199`) with a `static_assert`.
  **Accept:** `cd oolite-dev && ! rg -n 'GUI_ROW\(|#if GUI_FIRST_ROW' src`
- [X] T067 [US5] P9: `AXIS_*`/`BUTTON_*` (`src/Core/OOJoystickManager.h:60,75`), `HW_AXIS`/`HW_BUTTON`
  (`:157`), `CUBE_FACE_*` (`src/Core/OOVoxel.h:37-42`), `STICKPROFILE_TYPE_*`
  (`src/Core/OOJoystickProfile.h:44`) per T064; arrays indexed by them become `std::array`
  indexed through `oo::ToUnderlying`; the preference-key ordinals (`ENUMKEY`,
  `OOJoystickManager.h:186`) `static_assert`ed in both `OO_FOV_INFLIGHT_CONTROL_ENABLED`
  configurations; `tests/unit/core/test_OOJoystickManager.cpp` changes with it (ledger).
  **Accept:** `cd oolite-dev && ! rg -n -P '#define\s+(CUBE_FACE_|HW_AXIS|HW_BUTTON|STICKPROFILE_TYPE_)' src && $C enum --area core`
  Part 1 in `6329b654f`: the joystick, hardware, cube-face and stick-profile groups, as typed
  constants (D5 revised for `AXIS_*`/`BUTTON_*`, research R8); no test change was needed. The
  accept's second half, `$C enum --area core`, also covers every other unscoped enum left in
  `src/Core` (about 40: `OOOXZManager.h`, `Universe.h`, `OOCache.h`, `OOTrumble.h`,
  `OOMusicController.*`, `GuiDisplayGen.h`, `ResourceManager.h`, …), which no other task names;
  read as part of this task (the conservative reading: the accept is the contract) and done in
  further commits, each enum as the contract shapes it (a named value enum → `enum class`, a group
  of constants → typed constants).
- [X] T068 [US5] P9: `GameViewKeys`, `OOPixMapFormat`, `OODebugTCPConsoleProtocol.h` numbers and
  the remaining `sdl-debug` and `materials` enums per T064.
  **Accept:** `cd oolite-dev && $C enum`
- [X] T069 [US5] Make `cppcoreguidelines-use-enum-class` fatal; run the corpus
  (`bash tools/corpus.sh tier1`) and compare with its base result; regenerate the JS API snapshot
  with T013's restored tool into `.agent-tmp/js-api/m4.json` and compare it with the base; check
  every `external-values.md` row has its pin.
  **Accept:** `cd oolite-dev && $C enum && $C tbl && ./mk.sh tidy && ! grep -q '| to add |' ../specs/009-modern-cpp-std/external-values.md && diff -q ../.agent-tmp/js-api/base.json ../.agent-tmp/js-api/m4.json`
  Done in `03549f57c`: the JS API snapshot `m4.json` is byte-identical to `base.json`. The corpus
  was not run: `tools/corpus.sh tier1` launches `oolite.exe` and runs only on Windows, and no base
  result was recorded (T009); T105 runs the corpus on a Windows machine, which covers it.

**Checkpoint**: US5 complete apart from P10 (Phase 10).

---

## Phase 7: User Story 6 — C-style casts (Priority: P6, M5)

**Goal**: FR-024, FR-025, SC-010; research R16; [contracts/strings.md](contracts/strings.md)
*Casts*. **Independent test**: `$C cast` exits 0; build warning-free with `-Wold-style-cast`.
Each area: run `run-clang-tidy -p . -checks='-*,google-readability-casting' -fix` over the area,
review every fix, convert the rest by hand per the contract's table.

- [X] T070 [US6] Area `entities`, `PlayerEntity*.cpp` (about 169 in `PlayerEntity.cpp`).
  **Accept:** `cd oolite-dev && $C cast --area entities | { ! grep -q 'PlayerEntity'; }`
- [X] T071 [US6] Area `entities`, the rest (`ShipEntity*.cpp` about 144, the other entities; the
  152 `(Entity*)nullptr` arms → `static_cast<Entity*>(nullptr)`).
  **Accept:** `cd oolite-dev && $C cast --area entities`
- [X] T072 [US6] Area `core` (`Universe.cpp` about 99, the rest of `src/Core`).
  **Accept:** `cd oolite-dev && $C cast --area core`
  *Done (11758e5ff).* `check.sh`'s `core` area now leaves out the other areas' clang-tidy lines, as its
  search globs already did; before, it also reported Scripting, Materials and Debug. Two macOS-only
  failures found at the C++20 base were added to `baselines.md`.
- [X] T073 [US6] Area `materials` (`src/Core/OOOpenGLExtensionManager.cpp` about 131); the
  `memcpy` byte punning at `src/Core/Materials/OOPlanetTextureGenerator.cpp:809` and
  `src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp:438` → `std::bit_cast`.
  **Accept:** `cd oolite-dev && $C cast --area materials`
  *Done (0527cdda7).* The 139 casts in `OOOpenGLExtensionManager.cpp` are under `#if OOLITE_WINDOWS`, so
  the macOS check does not see them; they were converted by hand (`reinterpret_cast<PFN...>`) and
  T105's Windows build is the first to compile them.
- [X] T074 [US6] Area `scripting`.
  **Accept:** `cd oolite-dev && $C cast --area scripting`
- [X] T075 [US6] Areas `sdl-debug` and `oofnd`; casts from third-party macro expansions, if any are
  reported, become `exceptions.md` rows.
  **Accept:** `cd oolite-dev && $C cast`
  *Done (223ccc6fa).* No third-party macro expansion was reported, so no exceptions rows. The
  oofnd test sweep found a T037 regression (`pointerDescription` printed `0x0` for a zero low word,
  where printf's `%#x` printed `0`), fixed in cc94abb6d; `test_resourcepaths`' two Windows-home cases
  fail at the C++20 base too and went to `baselines.md`.
- [X] T076 [US6] Make `google-readability-casting` fatal and add `-Wold-style-cast` to the game's
  warning flags in `src/meson.build` in the same commit. If T009 saved a base event log, repeat it
  on a Windows machine into `.agent-tmp/events/m5.log` (US6 AS-4).
  **Accept:** `cd oolite-dev && ./mk.sh tidy && ./mk.sh build test 2>&1 | { ! grep -q 'Wold-style-cast'; }` and `grep -q 'Wold-style-cast' src/meson.build` and `{ test ! -s ../.agent-tmp/events/base.log || diff -q ../.agent-tmp/events/base.log ../.agent-tmp/events/m5.log; }`
  *Done (879e99e14; T068 follow-up afafe37c9).* Third-party headers became system headers and the
  vendored sources a library without the flag (research R16, *Third-party and vendored code*). No base
  event log was saved (T009), so there is no m5.log. The deployment build had not compiled since T068
  (`StateFlagToString` outside the verifier block); fixed in afafe37c9. A planted C-style cast fails
  clang-tidy. Windows (miniz, tinyexr's split, the extension manager) is first compiled by T105.

**Checkpoint**: US6 complete (SC-010).

---

## Phase 8: User Story 7 — C strings (Priority: P7, M6)

**Goal**: FR-026–FR-028, SC-011; research R17; contracts/strings.md *Text*. **Independent test**:
`$C cstring` exits 0; `$C cstring-types --unclassified` prints nothing; save round trip and
`test_FormatEquivalence` (with each area's rows added) pass; ASan clean. Each area: signatures (`std::string_view` read, `std::string`
kept or returned, `std::optional` where null meant "no text"), literal tables to
`constexpr std::array<std::string_view, N>`, comparisons and searches, `printf`-family calls to
`std::format` by M3's method, parses kept identical; every C call takes `c_str()` or a literal.

- [X] T077 [US7] Area `entities`.
  **Accept:** `cd oolite-dev && $C cstring --area entities && test -z "$($C cstring-types --unclassified --area entities)"`
- [X] T078 [US7] Area `scripting` (QuickJS calls take `c_str()` or literals).
  **Accept:** `cd oolite-dev && $C cstring --area scripting && test -z "$($C cstring-types --unclassified --area scripting)"`
- [X] T079 [US7] Area `materials` (GL shader sources and uniform names).
  **Accept:** `cd oolite-dev && $C cstring --area materials && test -z "$($C cstring-types --unclassified --area materials)"`
- [X] T080 [US7] Area `sdl-debug` (`src/SDL/main.cpp` argv, SDL calls, the debug console).
  **Accept:** `cd oolite-dev && $C cstring --area sdl-debug && test -z "$($C cstring-types --unclassified --area sdl-debug)"`
- [X] T081 [US7] Area `core`, including the exception-name `strcmp`s in
  `src/Core/Universe.cpp:4496,4562,4602,10451` → `std::string_view` `==`, and the fixed buffers C
  fills (`src/Core/OOCPUInfo.cpp`, OS paths) as `std::array<char, N>` at the call.
  **Accept:** `cd oolite-dev && $C cstring --area core && test -z "$($C cstring-types --unclassified --area core)"`
- [X] T082 [US7] Area `oofnd`: the `std::snprintf` calls in `src/oofnd/Defaults.hpp:259-318` and
  `src/oofnd/Date.hpp:114` → `std::format` with byte-identical output (pinned by
  `tests/unit/oofnd/test_defaults.cpp` and `test_date.cpp`, unchanged); parses whose
  `std::from_chars` answer differs stay in `src/oofnd/String.hpp` helpers (research R17); the
  printf engine that data formats and `OORaiseException` need stays: `std::vsnprintf` in
  `src/oofnd/String.hpp:502,508`, `src/oofnd/Exception.cpp:26,30` and `src/oofnd/objc/OOAssert.cpp:20,24`,
  one `exceptions.md` row each (category `cstring`, required by "printf-syntax data formats",
  FR-026).
  **Accept:** `cd oolite-dev && $C cstring && test -z "$($C cstring-types --unclassified)"`
- [X] T083 [US7] Set `bugprone-unsafe-functions.CustomFunctions` in `oolite-dev/.clang-tidy` to
  contracts/strings.md's list, which leaves out `vsnprintf` so the printf engine T082 keeps needs
  no suppression (confirm the expressions against clang-tidy 22 on a sample file first); ASan
  smoke run clean.
  **Accept:** `cd oolite-dev && ./mk.sh tidy && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | grep -q 'strcpy'`
  *Done (ae5729de0).* The ASan smoke run is `ASAN_OPTIONS=detect_leaks=0 bash -c 'source
  tests/run_test_fn.sh && run_test asan'` from `oolite-dev` (`mk.sh` does not take an `asan` build
  type); it reported nothing. The ASan build compiled one OO_DEBUG-only C-style cast that the other
  builds do not, fixed in 9ec7544c1.

**Checkpoint**: US7 complete (SC-011).

---

## Phase 9: User Story 2 — ownership (Priority: P2, M7)

**Goal**: FR-005–FR-009, SC-002; research R5; [contracts/ownership.md](contracts/ownership.md).
**Independent test**: `$C ownership` exits 0; `src/oofnd/Ref.hpp` gone; disposal, finalisation and
the FR-016 tests pass; ASan and leaks clean; frame rate within the baseline. **T088 and everything
after it wait for Jon's signature on the T002 rows for `test_ref.cpp:514` and the construction-form
edits.**

- [X] T084 [US2] (design D2) Inventory every function reachable from `Entity::willDispose()` and
  the `willDealloc` overrides (`src/Core/Entities/Entity.cpp:96-137`) that reads a weak reference
  to the dying entity, using the compile database (clangd call hierarchy or `clang-query`), not
  grep; fill data-model.md *Disposal reader*; answer whether any script event is sent from
  `willDispose()` and record it in research.md R5.
  Write the script-event answer in R5 as a line starting `D2 answer:`.
  **Accept:** `test "$(awk '/^## Disposal reader/{f=1} f' specs/009-modern-cpp-std/data-model.md | grep -c '^| \`')" -ge 2 && grep -q '^D2 answer:' specs/009-modern-cpp-std/research.md`
- [X] T085 [US2] Add `tests/unit/core/test_EntityDisposalReaders.cpp` (registered): one test per
  T084 reader pinning its effect (beacon list after a beacon ship is removed, dock and station
  teardown), passing on the base.
  **Accept:** CI runs `test_EntityDisposalReaders` and it passes on today's ownership code
- [X] T086 [P] [US2] Add `tests/unit/core/test_ScriptFinalisationRelease.cpp` (registered): a
  native object referred to by a script object is released when the engine finalises the script
  object and not before; and an entity's disposal hook runs once, at the same point relative to
  removal from the universe.
  **Accept:** CI runs `test_ScriptFinalisationRelease` and it passes on today's ownership code
- [X] T087 [US2] Rewrite each T084 reader per its chosen fix (`before release` or `identity`) so it
  no longer depends on weak references being live inside `willDispose()`; both T085 and the
  existing tests pass with today's ownership code.
  **Accept:** CI `test_EntityDisposalReaders` passes, and every *Disposal reader* row in data-model.md has a `fix`
  *Done (no code change).* Both readers' fix is `before release`, which the code already does:
  `clearBeacon` runs at removal, and on the disposal path only for an entity `Universe::entities`
  still owns, which cannot be disposed (data-model.md). `test_EntityDisposalReaders` passes locally;
  CI runs it with T105.
- [X] T088 [US2] (design D1; needs the T002 signatures) Add `src/oofnd/Object.hpp` and
  `src/oofnd/AutoreleaseScope.hpp` exactly as contracts/ownership.md declares them; rebuild
  `src/oofnd/WeakSet.hpp` on `std::weak_ptr`; turn `src/oofnd/Ref.hpp` into the bridge (the
  contract's table, including the "+1 from `new`" rules for `adopt`); port
  `tests/unit/oofnd/test_ref.cpp` and `tests/unit/oofnd/test_weakset.cpp` and make the
  construction-form edits (ledger rows from T002, now signed).
  **Accept:** `cd oolite-dev && rg -q 'class Object : public std::enable_shared_from_this<Object>' src/oofnd/Object.hpp` and CI `test_ref`, `test_weakset` and the whole `core` suite pass
- [X] T089 [US2] Exemplar: `src/Core/OOColor.cpp`/`.h` and its holders off the bridge onto
  `std::shared_ptr<OOColor>`/`oo::makeShared`/`oo::share`.
  **Accept:** `cd oolite-dev && ! rg -n 'oo::(Ref|WeakRef)<\s*OOColor\b|makeRef<\s*OOColor\b' src`
- [X] T090 [US2] The never-destroyed singletons (`makeRef(...).leakRef()` in
  `src/Core/GameController.cpp`, `OOCacheManager.cpp`, `OOShipRegistry.cpp`, `OOOXZManager.cpp`,
  `OOMusicController.cpp`, `OOGraphicsResetManager.cpp`, `OOALSoundMixer.cpp`, `OOALMusic.cpp`,
  `OOSoundSourcePool.cpp`, `OOTrumble.cpp`, `OOOpenGLExtensionManager.cpp`, `HeadUpDisplay.cpp`,
  `Materials/OONullTexture.cpp`, `Entities/PlayerEntitySound.cpp`, `Debug/OODebugMonitor.cpp`,
  `Scripting/OOJavaScriptEngine.cpp` ×2, `src/SDL/main.cpp`, and the work manager if T026 did not)
  → plain std at each site, no helper: `static const auto& s = *new
  std::shared_ptr<T>(oo::makeShared<T>(...));` where others share it, `static auto& s = *new
  T(...);` where nothing does; one `exceptions.md` row each.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'makeRef<[^>]+>\((?:[^()]|\([^()]*\))*\)\s*\.leakRef\(\)' src --glob '!src/Core/Scripting/poc/**'`
- [X] T091 [US2] Leaf types in area `core` (role sets, probability sets, characters, sounds,
  caches, async tasks, `PList::Object` → `std::shared_ptr<PListForeign>`) off the bridge; exclusive
  owners (research R5.8) → `std::unique_ptr` or values.
  **Accept:** `cd oolite-dev && $C ownership --area core`
  Part 1 (`fa8db72c2`): the bridge takes `oo::Object` types. Part 2 (`f21d46d5e`):
  every `oo::Ref`/`oo::WeakRef`/`makeRef` in `src` (the bridge's own headers aside) and in the tests
  (but `test_ref`, `test_weakset`) is `std::shared_ptr`/`std::weak_ptr`/`oo::makeShared`, ahead of
  T092–T097's renames, because the game's signatures and the tests' stand-ins must agree (168
  ledger rows); `.leakRef()` is the bridge function `oo::leakRef(sp)`, weak comparisons are
  `oo::sameObject`/`oo::isUnset` (Object.hpp). Second owners are checked by two clang-query scans
  (`.agent-tmp/rawowner.sh`, `.agent-tmp/rawowner_emplace.sh`, the second for emplace/insert and
  pair/optional/container constructions, whose `shared_ptr` is built inside the standard headers);
  both are clean over the game and the tests. Locally, a stand-in `process.h` under `.agent-tmp/fakeinc`
  (only for compile checks, `FAKEINC=1`) lets the Windows-only tests compile; their remaining errors
  are platform ones (T105 checks them on Windows). Left: the ~50 core classes from `oo::RefCounted` to
  `oo::Object`, their manual retain/release and `adopt(new …)` sites, `PList::Object`, the exclusive
  owners, the comments that still say `oo::Ref`, and an exceptions row for `OOTypeEncodings.h`'s
  measured strings. Not from T091: six `-Wtautological-pointer-compare` warnings
  (`assert(out != nullptr)` on nonnull parameters in `OOJSVector.cpp`, `OOJSQuaternion.cpp`,
  `OOOpenGLStateManager.cpp`) and one `sprintf` deprecation in the vendored `stb_image_write.h`
  were in the build before it; left for their own fix (default: not silenced, not in this task).
  Part 3 (`ccab6c723`): the 50 core classes derive from `oo::Object`; their manual holds are
  standard owners (the universe a `std::unique_ptr` kept by the controller; never-destroyed heap
  `std::shared_ptr`s for the joystick manager, the OpenAL controller, the sky's texture managers,
  the trumble sounds and the empty probability set; holders never deleted for statics still set at
  `exit(0)`, whose destructors would run after the logger and the GL context have gone: the player's
  sounds, the recent-textures cache, the HUD's encoding converter; nine exceptions rows). Tests that
  asserted `retainCount()` use `weak_from_this().use_count()` (11 ledger rows).
  Part 4 (`0d62ed6c3`): `adopt(new X)` → `oo::makeShared` (or the same `std::shared_ptr(new X,
  oo::Dispose{})` inside a class whose factory keeps its constructor private); the `leakRef` +1s in
  core files held as `std::shared_ptr` or never-deleted holders; `PList::Object` is
  `std::shared_ptr<PListForeign>`; the crosshairs and sky quad sets are `std::unique_ptr` (research
  R5.8's correction); four exceptions rows (the encodings' measured strings; `OOCharacter` and
  `OOEquipmentType` keep the bridge's adopt until T096 moves `oo::PListForeign`). The raw-owner scan
  also sees constructions through an alias now. *Done:* `$C ownership --area core` exits 0.
- [X] T092 [US2] Area `materials` (textures, materials, shaders, meshes) off the bridge.
  **Accept:** `cd oolite-dev && $C ownership --area materials`
  *Done* (`5436ba8b0`). `OOConcreteTexture` keeps the bridge's `adopt` until T096 (its base is
  `oo::PListForeign`; exceptions row). `test_OOMaterial`'s willDealloc case lost its cleanup
  `release()` (no manual hold exists): ledger row marked *borderline* for Jon's review; default taken:
  the line goes, the assertions stay.
- [X] T093 [US2] The script slot: `OOJSSetCxxPrivate`/`OOJSGetCxxPrivate` and the finaliser in
  `src/Core/Scripting/OOJSPrivateObject.cpp` per the contract (heap `std::shared_ptr<oo::Object>`,
  today's finaliser order); `src/Core/Scripting/OOJSEntityHolder.h` and `ScriptPrivate` hold
  `std::weak_ptr`; `exceptions.md` row for the slot.
  **Accept:** `cd oolite-dev && ! rg -n 'leakRef|adopt\s*\(' src/Core/Scripting/OOJSPrivateObject.cpp && rg -q 'std::weak_ptr' src/Core/Scripting/OOJSEntityHolder.h` and CI `test_ScriptFinalisationRelease` passes
  *Done* (`e2bfc9323`). Decision (default taken): the contract's signature names a `JSContext *`, but
  says D1 keeps today's other parameters, so `OOJSSetCxxPrivate(JSValueConst, std::shared_ptr<oo::Object>)`
  keeps today's (no context; `bool` back). The finaliser keeps the code's order (`clearJSSelf`, empty
  the slot, delete the holder). Every reader of a C++ slot goes through `OOJSCxxPrivateFromOpaque`.
  `test_ScriptFinalisationRelease` passes locally; CI runs it with T105.
- [X] T094 [US2] Entities, step 1: `src/Core/Entities/OOEntityHold.h` per the contract
  (`using EntityHold = std::shared_ptr<Entity>`, `Hold(e)`); entities made with `oo::makeShared`;
  the +1 creators (`newShipWithRole`, `newShipWithName`, …) return `std::shared_ptr`;
  `MadeEntity`/`MadeEntityRetained` in `src/Core/Entities/EntityHelpers.cpp` per the contract.
  **Accept:** `cd oolite-dev && rg -q 'using EntityHold = std::shared_ptr<Entity>' src/Core/Entities/OOEntityHold.h` and CI `test_EntityDisposalReaders`, `test_ScriptFinalisationRelease` pass
  Part 1 (`76e4f8627`): `EntityHold` is `std::shared_ptr<Entity>`; `oo::Hold`, and for
  the bridge's manual references `oo::AdoptHold`/`oo::LeakHold` (removed in T095); `oo::FindHold`/
  `oo::EraseHold`; every raw construction and `emplace_back(raw)` is `oo::Hold` (scans clean). Left:
  the +1 creators and `MadeEntityRetained` return `std::shared_ptr`.
  Part 2 (`94a39d493`): `MadeEntityRetained` and the `Universe` creators answer `std::shared_ptr`;
  their 66 callers take the old +1 through the bridge adapter `oo::RetainedEntity` (removed in T095,
  where each site becomes an owner). Decision (default taken): `newVisualEffectWithName` is a virtual
  member the tests override, so it keeps its +1 until T095; the object makers `NewShipObject`/
  `NewVisualEffect` keep theirs (24 test calls) likewise. *Done:* the alias check and both tests pass.
- [X] T095 [US2] Entities, step 2: remove `RetainEntity`/`ReleaseEntity`/`AutoreleaseEntity` and
  the remaining `Ref`/`WeakRef` uses in `src/Core/Entities` and `src/Core/Universe.cpp`.
  **Accept:** `cd oolite-dev && $C ownership --area entities && ! rg -n '\b(Retain|Release|Autorelease)Entity\b' src`
  *Done.* Parts: `7cf0125e7`, `0e080ed67`, `a3818c071`, `bb784244b`. A creator's ship is a local
  `std::shared_ptr`; retained raw lists keep a vector of holds beside them (`oo::HoldIn`);
  `[[e retain] autorelease]` is `oo::AutoreleaseHold`; deliberate leaks move into never-deleted holders;
  `Entity` is an `oo::Object` (its weak references are already empty in `willDispose()`, so
  `dropWeakReferences()` went). A release followed by a further use of the pointer keeps the owner
  to the end of its scope (`.agent-tmp/resetcheck2.py` lists every added `reset()` read afterwards);
  three unbalanced releases from the conversion (two adopts of an owner's pointer, one release of
  one) were found and fixed in part 3. The tests keep their manual references in
  `tests/unit/core/EntityManualRefs.h` (on the bridge for their own stand-ins; a list of owning
  references per `oo::Object` entity), until T097/T098. Decision (default taken): a demo ship the
  universe cannot add is destroyed with its creator's reference instead of leaking.
- [ ] T096 [US2] Areas `scripting`, `sdl-debug`, `oofnd`: the remaining bridge uses.
  **Accept:** `cd oolite-dev && $C ownership`
- [ ] T097 [US2] The tests' remaining `oo::Ref`, `oo::WeakRef`, `oo::makeRef`, `retainCount()` and
  `oofnd/Ref.hpp` includes → `std::shared_ptr`, `std::weak_ptr`, `oo::makeShared`, `use_count()`,
  `<memory>` and `oofnd/Object.hpp`, including `tests/unit/core/EntityStandIn.h` (one ledger row per
  file, *covered*); assertions unchanged.
  **Accept:** `cd oolite-dev && ! rg -n -P '\boo::(Ref|WeakRef)\b|\bmakeRef\b|retainCount\s*\(|oofnd/Ref\.hpp' tests`
- [ ] T098 [US2] Delete the bridge: `src/oofnd/Ref.hpp`, `RefCounted`, `dropWeakReferences`;
  regenerate the JS API snapshot into `.agent-tmp/js-api/m7.json`; if T009 saved a base event log,
  repeat it on a Windows machine into `.agent-tmp/events/m7.log` (US2 AS-5).
  **Accept:** `cd oolite-dev && test ! -e src/oofnd/Ref.hpp && $C ownership && diff -q ../.agent-tmp/js-api/base.json ../.agent-tmp/js-api/m7.json && { test ! -s ../.agent-tmp/events/base.log || diff -q ../.agent-tmp/events/base.log ../.agent-tmp/events/m7.log; }`
- [ ] T099 [US2] Measure: ASan smoke and `leaks --atExit`; frame rate and start-up, five runs each;
  record the rows `| frame@M7 | … | lower |` (CPU ms per frame, baselines.md), `| start@M7 | … | lower |`, `asan-smoke@M7` and
  `leaks@M7` in `baselines.md` (SC-005, SC-008).
  Measure the base again in the same session from a `git worktree` of `518520d43` and record it as the base rows for the comparison (baselines.md *Same-session comparison*).
  **Accept:** `cd oolite-dev && $C bound frame@M7 && $C bound start@M7 && $C bound asan-smoke@M7 && $C bound leaks@M7`
- [ ] T100 [US2] Update CLAUDE.md's "Ownership is `oo::Ref<T>`, not `shared_ptr`" line to the new
  rule (`std::shared_ptr`/`std::weak_ptr`/`std::unique_ptr`, objects from `oo::makeShared`) and
  spec 003's plan gate row (`specs/003-encapsulate-global-state/plan.md:99`).
  **Accept:** `! grep -q 'Ownership is `oo::Ref<T>`' CLAUDE.md && ! grep -q 'oo::Ref<oo::RefCounted>' specs/003-encapsulate-global-state/plan.md`

**Checkpoint**: US2 complete (SC-002, SC-008, SC-009).

---

## Phase 10: Polish and close-out (M8)

- [ ] T101 (needs the T002 signature for the P10 rows) P10: rename the enumerators of the 20
  existing `enum class` types to `kPascalCase` (`oo::PList::Type`, `oo::FileType`,
  `oo::Http::Scheme`, `OOJSCallEntityMethodForm`, …), with their test edits (ledger rows signed).
  **Accept:** `cd oolite-dev && $C naming` (fails before: the 20 types' enumerators are not `kPascalCase`)
- [ ] T102 Make `readability-identifier-naming` fatal in `oolite-dev/.clang-tidy`.
  **Accept:** `cd oolite-dev && ./mk.sh tidy` and the check is in `WarningsAsErrors`
- [ ] T103 [P] Docs (FR-023): `docs/phases/4p-upstream-polish.md` (the "Out of scope here (Phase
  6)" paragraph), `docs/phases/6-modernise.md` (exit-gate items this feature did),
  `notes/2026-10-28 Modern C++ Idiom Review.md` (the `.tbl` "keep" lines at `:66` and `:222`, and
  the `Ref` decision), `notes/2026-11-07 Enum Tables from tbl X-Macros.md` (stale gates), and
  `oolite-dev/src/oofnd/README.md` (final component list).
  **Accept:** `! grep -q 'defensible pattern' 'notes/2026-10-28 Modern C++ Idiom Review.md' && grep -q '009-modern-cpp-std' docs/phases/6-modernise.md`
- [ ] T104 [P] If Jon has ruled on `test_stdlib` (T002 row), act on it: delete `src/oofnd/StdLib.hpp`
  only if he approved retiring the test; otherwise leave both and note it in the checklist.
  **Accept:** `row=$(grep 'test_stdlib' specs/009-modern-cpp-std/test-ledger.md); echo "$row" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' && if echo "$row" | grep -q 'retire'; then test ! -e oolite-dev/src/oofnd/StdLib.hpp; else test -e oolite-dev/src/oofnd/StdLib.hpp; fi`
- [ ] T107 (FR-029, Jon 2026-11-12) Remove the `cxx_` prefix from every identifier that has it
  (functions, types, constants and enumerators alike; the most used are functions such as
  `cxx_OOStringFromJSValue`, 290 uses): 3,306 references to 384 names (2026-11-12), about 2,310 in
  175 `src` files and 996 in 91 test files. Do it after US6 and US7 (T070–T083), which
  rewrite many of the same lines, and before T108 and T105. Rename with a literal-aware tool (the
  renamer under `.agent-tmp/us5/` that skips strings and block comments; extend it to `//`
  comments that name the identifier), one area per commit. 115 of the bare names are already in
  use (`path`, `description`, `manifest`, `setText`, …); for each, look up upstream's name in
  `upstream/oolite` (`kGuiShipyardHeadingColor` for `cxx_kGuiShipyardHeadingColor`) and take it,
  and where it still clashes (a member or local of the same name) let the build find the clash
  and settle it at that site, writing each choice in this task's notes. Tests name the new
  identifiers (ledger, *covered*: a name the test uses, renamed, assertions unchanged).
  **Accept:** `cd oolite-dev && ! rg -n '\bcxx_\w+' src tests --glob '!src/Core/MiniZip/**' --glob '!src/SDL/EXRSnapshotSupport/**'`
- [ ] T108 (FR-030, Jon 2026-11-12) Remove every unused include from the game and its tests: run
  `run-clang-tidy -checks='-*,misc-include-cleaner' -fix` over `src` and `tests/unit` (not the
  vendored directories), keep only its removals (it also suggests adding headers; those are
  reported, not applied), then build, test, smoke and tidy; a removal that breaks a platform
  build (Windows `process.h`, `winsock2.h`, an `#if` branch macOS does not compile) goes back with
  a `// IWYU pragma: keep` and its reason. Add `misc-include-cleaner` to `oolite-dev/.clang-tidy`
  with its `MissingIncludes: false` option so new unused includes are reported, and make it fatal
  once the count is zero. Test files' removed includes go in the ledger (*covered*: no assertion
  changes). Run it last of the code changes, after T107: every task before it moves includes.
  (On macOS add `-extra-arg=-isysroot$(xcrun --show-sdk-path)` to the accept's `run-clang-tidy`, as
  `mk.sh tidy` does. Checked 2026-11-12: `GuiDisplayGen.cpp` alone reports five, `cstdint` and
  `OODescription.h` among them.)
  **Accept:** `cd oolite-dev && test "$(/opt/homebrew/opt/llvm@22/bin/run-clang-tidy -p . -quiet -checks='-*,misc-include-cleaner' -config='{CheckOptions: {misc-include-cleaner.MissingIncludes: false}}' '^(?!.*/(MiniZip|EXRSnapshotSupport)/).*/(src|tests/unit)/.*\.cpp$' 2>/dev/null | grep -c 'warning:.*misc-include-cleaner')" -eq 0`
- [ ] T105 On a Windows machine: `tests/run.sh all` on Clang and on GCC
  (`--native-file=gcc.ini`); the unit suites under ASan (`meson setup <dir> -Db_sanitize=address`)
  on the branch and, in a `git worktree` of the base commit, on the base, reporting nothing the
  base does not (SC-005); the corpus; the JS API snapshot against `.agent-tmp/js-api/base.json`;
  `oofnd`'s line count (`wc -l src/oofnd/*.hpp src/oofnd/*.h src/oofnd/*.cpp src/oofnd/objc/*`)
  against the base's 13,322 (SC-004); 20 heap allocations picked with `rg -n 'makeShared|make_unique|\bnew\b' src | shuf -n 20`, each with its owner (SC-009); record results, SC-001 to SC-011 and the final
  converted-category table (every category `fatal`) in `checklists/requirements.md` and
  data-model.md.
  Write one line per criterion: `SC-0NN: met (evidence)` or `SC-0NN: not met — reason`.
  **Accept:** `test "$(grep -c -E '^- SC-0(0[1-9]|1[01]): (met|not met — )' specs/009-modern-cpp-std/checklists/requirements.md)" -eq 11`
- [ ] T106 Last, after T105: bring `seriesb/027-modern-cpp` onto the rewritten series. On
  `jonmseaman/oolite` the `seriesb/*` branches were rewritten (merge commits squashed into each
  other), so 027's history still holds the old commits of its parent `seriesb/026-migration-completion`.
  In `oolite-dev` only (local config, the same as Jon's Windows machine):
  `git config --local rerere.enabled true` and
  `git config --local git-town.sync-feature-strategy rebase`. Before fetching, record the old parent
  tip: `old=$(git merge-base seriesb/027-modern-cpp seriesb/026-migration-completion)`, and tag
  every local `seriesb/*` tip (`git tag pre-rewrite/<branch> <branch>`) so nothing is lost. Then
  `git fetch origin`.
  **The rewrite was force-pushed (Jon, 2026-11-12).** The local `seriesb/*` parents still hold the
  pre-rewrite commits, so they must not be synced or rebased onto their remotes: that would replay
  the old commits on top of the rewritten ones and duplicate them. Do not run `git town sync` for
  this step. For each local parent with no commits of its own beyond its old remote tip
  (`git log --oneline origin/<branch>@{1}..<branch>` empty, or `git cherry` shows every commit as
  already upstream), point it at the rewritten remote with `git branch -f <branch> origin/<branch>`
  (never `develop`, `master` or `main`). A parent that has local-only commits is left alone and
  reported. Then `git rebase --onto origin/seriesb/026-migration-completion "$old"
  seriesb/027-modern-cpp`, so only 027's own commits are replayed (rerere reuses any conflict
  resolution it has seen). Compare before and after with `git range-diff "$old"..pre-rewrite/seriesb/027-modern-cpp
  origin/seriesb/026-migration-completion..seriesb/027-modern-cpp`: every 027 commit should appear
  once, unchanged except for conflict resolutions. After the
  rebase: `./mk.sh build test`, smoke and `./mk.sh tidy` as at every task. The rewritten branch
  needs a forced push, which hard rule 3 leaves to Jon (`git push --force-with-lease origin
  seriesb/027-modern-cpp`); say so in the report.
  **Accept:** `cd oolite-dev && test "$(git config --local rerere.enabled)" = true && test "$(git config --local git-town.sync-feature-strategy)" = rebase && git merge-base --is-ancestor origin/seriesb/026-migration-completion seriesb/027-modern-cpp && test -z "$(git rev-list --merges origin/seriesb/026-migration-completion..seriesb/027-modern-cpp)"`

---

## Dependencies and execution order

```text
Phase 1 (T001–T003) → Phase 2 (T004–T013)
  → Phase 3 US1 (T014–T025)
  → Phase 4 US3 (T026–T029)        ┐ any order after Phase 2,
  → Phase 5 US4 (T030–T044)        ┘ one task at a time
  → Phase 6 US5 (T045–T069)        after Phases 3–5
  → Phase 7 US6 (T070–T076)        after Phase 6 (enum casts first)
  → Phase 8 US7 (T077–T083)        after Phases 5 and 7 (format method, cast rules)
  → Phase 9 US2 (T084–T100)        T084–T086 any time after Phase 2 (they only add or record);
                                    T087 (rewrites Entities code) never beside Phases 6–8;
                                    T088+ after Jon signs
  → Phase 10 (T101–T108)           T101 after Jon signs the P10 rows; T107 after US6 and US7, then
                                   T108, both before T105; T106 is the last task
```

- Phase 9 may move to directly after Phase 3 if Jon signs early (it never runs beside Phases 6–8:
  they all rewrite `src/Core/Entities`).
- Inside a phase, unmarked tasks are sequential; [P] tasks may go in any order.
- T017 before T018 (the generators use the pixmap buffer). T030 before T033 (FileSystem's
  `oo::Unexpected`). T036 before T037–T042. T045–T046 before every other Phase 6 task. T058 before
  T059. T064 before T065–T068. T084 → T085 → T087 → T088 → T089 → T090 … → T098.

## Parallel opportunities

- Phase 2: T005, T006 together; T010–T013 together.
- Phase 3: T015, T016, T019–T024 in any order.
- Phase 4 and Phase 5 interleave freely with each other.
- Phase 5: T032, T034, T035 beside the format tasks.
- Phase 6: T047–T050 in any order.
- Phase 9: T084–T086 can be done during Phases 3–8 (they add tests on today's code).

## Independent tests per story

| Story | Done when |
|---|---|
| US1 | `$C alloc` exits 0; `no-malloc` fatal; ASan smoke and leaks clean |
| US3 | `$C thread` exits 0; shutdown test passes; quit time within baseline; TSan clean |
| US4 | `$C oofnd` exits 0; `Expected.hpp` gone; README survivors table complete |
| US5 | `$C enum`, `$C tbl` exit 0; save and name tests pass; corpus unchanged |
| US6 | `$C cast` exits 0; `-Wold-style-cast` on, warning-free |
| US7 | `$C cstring` exits 0; no unclassified `const char*`; ASan clean |
| US2 | `$C ownership` exits 0; `Ref.hpp` gone; disposal and finalisation tests pass; frame rate within baseline |

## Implementation strategy

- **MVP: Phases 1–3** (US1). Self-contained, needs no test edits, fixes a real leak, and proves the
  guard mechanism end to end.
- Then the cheap, contained stories (US3, US4), the large mechanical ones (US5, US6, US7), and US2
  last unless Jon signs early. Each phase ends green and can be merged by Jon on its own.
