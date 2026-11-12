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
  `test_OOOXZManager` in `unit-tests-windows`).
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

- [ ] T001 Create `specs/009-modern-cpp-std/exceptions.md` with one table whose columns are
  `category | file | match | construct | required by | owner / release | commit`, where `match` is
  a fixed substring of the permitted line (the search tool drops a hit whose file equals `file` and
  whose line contains `match`); add a sentence above the table saying so, and update the
  *Exceptions list* section of `specs/009-modern-cpp-std/data-model.md` to list the `match` field.
  **Accept:** `grep -q '| category | file | match |' specs/009-modern-cpp-std/exceptions.md`
- [ ] T002 Create `specs/009-modern-cpp-std/test-ledger.md` with the columns of data-model.md
  *Test-change ledger* (`test file | lines | forced by | assertions | coverage | commit | signed`),
  and add now, before any change, the rows Jon must sign: `tests/unit/oofnd/test_ref.cpp:514`
  (`willDisposeRunsOnceWithTheObjectWhole`: weak references become empty from the start of
  disposal; *needs sign-off*); the stack and static instances in
  `tests/unit/core/test_OOShaderMaterial.cpp:309,501,588`, `tests/unit/core/test_OODebugMonitor.cpp:780`
  and `tests/unit/oofnd/test_ref.cpp:35` (made shared-owned; *borderline*); the P10 renames of the
  20 existing `enum class` enumerators (*needs sign-off*); `tests/unit/oofnd/test_stdlib.cpp`
  (*reported*: its header leaves the game; Jon decides whether it is retired).
  **Accept:** `grep -c 'needs sign-off\|borderline\|reported' specs/009-modern-cpp-std/test-ledger.md` prints at least 4
- [ ] T003 Create `specs/009-modern-cpp-std/check.sh` (bash, `#!/usr/bin/env bash`, committed
  `100755`, check with `git ls-files -s`) implementing the categories `alloc`, `ownership`,
  `thread`, `oofnd`, `enum`, `tbl`, `cast`, `cstring`, `cstring-types` with exactly the searches in
  data-model.md *Converted category* (run from `oolite-dev`; `cast` runs
  `run-clang-tidy -p . -quiet -checks='-*,google-readability-casting'` over
  `src/(Core|SDL|oofnd)/.*\.cpp` and counts findings), the `--area` and `--count` options, and the
  exceptions filter from `exceptions.md`'s `file` and `match` columns. `cstring-types` only reports
  (exit 0) unless given `--unclassified`, which lists hits that are neither on the list nor a
  literal-typed declaration (`constexpr`, or initialised from a string literal).
  **Accept:** `cd oolite-dev && ../specs/009-modern-cpp-std/check.sh alloc --count` prints `135` and `../specs/009-modern-cpp-std/check.sh alloc; test $? -eq 1`

---

## Phase 2: Foundational (M0)

**Purpose**: C++23, the guards, baselines and the tests of preserved behaviour (FR-012, FR-016,
FR-021). **No story task starts until this phase is done.**

- [ ] T004 Switch the standard to C++23: `cpp_std=c++23` in `oolite-dev/src/meson.build:25` (and
  its comment at `:21`), `oolite-dev/src/oofnd/meson.build:18` (comment at `:3`) and
  `oolite-dev/tools/icosmesh/meson.build:9`; no source change (research R1).
  **Accept:** `cd oolite-dev && ./mk.sh build test && grep -q -- '-std=c++23' compile_commands.json && ! grep -q -- '-std=c++20' compile_commands.json`
- [ ] T005 [P] Rewrite the "C++20 only", "compiles with `-fno-exceptions`" and "Header-only,
  C++20" claims in `oolite-dev/src/oofnd/README.md:3,8,50` and the `oofnd` header banners to say
  C++23 and that the game uses exceptions (research R1, R7); leave `tests/` alone.
  **Accept:** `cd oolite-dev && ! rg -n -i 'C\+\+20 only|Header-only, C\+\+20|compiles? with -fno-exceptions' src`
- [ ] T006 [P] Add a `tidy` command to `oolite-dev/mk.sh` (`execute_target`), per
  [contracts/guards.md](contracts/guards.md) *`./mk.sh tidy`*: clang-tidy 22
  (`/opt/homebrew/opt/llvm@22/bin` on macOS, `PATH` elsewhere), `run-clang-tidy -p . -quiet
  'src/(Core|SDL|oofnd)/.*\.cpp'`, building first if `compile_commands.json` is missing, exiting
  nonzero when a `WarningsAsErrors` check reports.
  **Accept:** `cd oolite-dev && ./mk.sh tidy`
- [ ] T007 Add `cppcoreguidelines-no-malloc`, `cppcoreguidelines-use-enum-class`,
  `readability-identifier-naming` and `google-readability-casting` to `Checks` in
  `oolite-dev/.clang-tidy`, with the `CheckOptions` of contracts/guards.md, none in
  `WarningsAsErrors` yet.
  **Accept:** `cd oolite-dev && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | grep -q 'google-readability-casting' && ./mk.sh tidy`
- [ ] T008 Add a step running `./mk.sh tidy` after the Arch build in
  `oolite-dev/.github/workflows/build-all.yaml` (contracts/guards.md *CI step*).
  **Accept:** `grep -q 'mk.sh tidy' oolite-dev/.github/workflows/build-all.yaml`, and the pushed run's Arch job passes
- [ ] T009 Record baselines in a new `specs/009-modern-cpp-std/baselines.md`: every category's
  `check.sh --count` (and `--area` counts for `cast` and `cstring`) on `518520d43`'s tree after
  T004; start-up time from `tests/launch_snapshot.py`; frame rate by the method of
  `notes/2026-11-10 Frame Rate Comparison.md`; quit time while start-up planet generation runs;
  each the median of five runs on this Mac. Copy the counts into data-model.md's *now* column.
  **Accept:** `grep -c '^| ' specs/009-modern-cpp-std/baselines.md` prints at least 12
- [ ] T010 [P] Add `oolite-dev/tests/unit/core/test_SaveEnumValues.cpp` (registered in
  `tests/unit/core/meson.build`, copying `test_PlayerEntity.cpp`'s set-up): save a player and
  assert today's numbers for `chart_ana_mode`, `chart_colour_mode`, `speech_on`, the legacy
  `energy_unit`, a ship's behaviour, and that loading each back gives the same enum value; pin the
  ordinals of `OOLongRangeChartMode` (research R8: `OOLRC_MODE_UNKNOWN` is 0,
  `OOLRC_MODE_TECHLEVEL` is 4).
  **Accept:** CI `unit-tests-windows` runs `test_SaveEnumValues` and it passes (it does not exist before)
- [ ] T011 [P] Add `oolite-dev/tests/unit/core/test_EnumNameFallbacks.cpp`: for every enum with a
  string reverse lookup in `src/Core/OOConstToString.cpp` and `src/Core/Scripting/OOConstToJSString.cpp`,
  assert the default returned for an unknown name and for each known name its value, and for each
  value its exact string.
  **Accept:** CI `unit-tests-windows` runs `test_EnumNameFallbacks` and it passes
- [ ] T012 [P] Add `oolite-dev/tests/unit/core/test_FormatOutput.cpp`: capture the exact output of
  one representative `oo::str::format` call per specifier in use (`%s %u %d %g %f %zu %i %.2f %.3g
  %.3f %llu %06x %c %.4X %60s %.*f %016llx`, research R7), including `%u` of −1 and a negative `%x`,
  so M3 and M6 cannot change text unnoticed.
  **Accept:** CI `unit-tests-windows` runs `test_FormatOutput` and it passes

**Checkpoint**: C++23 builds everywhere CI builds; `./mk.sh tidy` runs locally and in CI;
baselines and the FR-016 tests exist and pass on the base.

---

## Phase 3: User Story 1 — C allocation (Priority: P1, M1) 🎯 MVP

**Goal**: no `malloc`/`calloc`/`realloc`/`free` in first-party C++ outside the exceptions list
(FR-004, FR-005, SC-001). **Independent test**: `$C alloc` exits 0; a planted `malloc` fails
`./mk.sh tidy`; ASan smoke clean.

- [ ] T013 [US1] Add `oolite-dev/src/Core/OODemangle.h` with `std::string OODemangle(const char*
  mangled)` (calls `abi::__cxa_demangle`, frees through `std::unique_ptr<char,
  decltype(&std::free)>`, returns the input on failure), use it at the 8 sites
  (`src/Core/OOALSound.cpp:169`, `src/Core/OODrawable.cpp:67`, `src/Core/Materials/OOMaterial.cpp:70`,
  `src/Core/Materials/OOTexture.cpp:388`, `src/Core/Materials/OOTextureLoader.cpp:234`,
  `src/Core/OXPVerifier/OOOXPVerifierStage.cpp:81`, `src/Core/Scripting/OOScript.cpp:69`,
  `src/Core/Entities/EntityHelpers.cpp:130`), and
  add the `exceptions.md` row (category `alloc`, file `src/Core/OODemangle.h`, required by
  `abi::__cxa_demangle` returning `malloc` memory).
  **Accept:** `cd oolite-dev && ! rg -n 'free\s*\(\s*demangled' src`
- [ ] T014 [P] [US1] Sound buffers to `std::vector<char>` in `src/Core/OOALSoundDecoder.cpp:316,351,443`,
  `src/Core/OOALStreamedSound.cpp:35,62` and `src/Core/OOALBufferedSound.cpp:35`; this fixes the
  per-read leak in `OOReadOXZVorbis` (`OOALSoundDecoder.cpp:442`, research R4).
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/OOALSoundDecoder.cpp src/Core/OOALStreamedSound.cpp src/Core/OOALBufferedSound.cpp`
- [ ] T015 [P] [US1] Zip read buffers to `std::vector<char>` in `src/Core/OODataFromOXZFile.cpp:124,138`.
  **Accept:** `cd oolite-dev && $C alloc --area core | { ! grep -q OODataFromOXZFile; }`
- [ ] T016 [US1] The pixel-buffer chain as one unit: an owning buffer (`std::vector<std::uint8_t>`)
  in `src/Core/Materials/OOPixMap.cpp`/`.h` (`:76,85,110`), and its users
  `src/Core/OOTextureScaling.cpp:283,355-360,1684`, `src/Core/Materials/OOPixMapChannelOperations.cpp:122,125`,
  `src/Core/Materials/OOTextureLoader.cpp:201,349,364,381,398`, `src/Core/Materials/OOConcreteTexture.cpp:137,478,568`,
  `src/Core/Materials/OOPNGTextureLoader.cpp:88,136-160` (libpng fills our rows; GL copies).
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Materials/OOPixMap.cpp src/Core/OOTextureScaling.cpp src/Core/Materials/OOPixMapChannelOperations.cpp src/Core/Materials/OOTextureLoader.cpp src/Core/Materials/OOConcreteTexture.cpp src/Core/Materials/OOPNGTextureLoader.cpp`
- [ ] T017 [US1] The planet and atmosphere generators: remove the `FREE` macro (`:63/:65`) and its
  about 12 `malloc`s in `src/Core/Materials/OOPlanetTextureGenerator.cpp` and
  `src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp`, using T016's buffer where the result
  becomes a pixmap and `std::vector` elsewhere.
  **Accept:** `cd oolite-dev && ! rg -n -P '\bFREE\s*\(|(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Materials/OOPlanetTextureGenerator.cpp src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp`
- [ ] T018 [P] [US1] Snapshot buffers to `std::vector` in `src/SDL/MyOpenGLView.cpp:1289-1516`.
  **Accept:** `cd oolite-dev && $C alloc --area sdl-debug | { ! grep -q MyOpenGLView; }`
- [ ] T019 [P] [US1] JS vector and quaternion private data in `src/Core/Scripting/OOJSVector.cpp:177,184,495`
  and `src/Core/Scripting/OOJSQuaternion.cpp:143,150,461`: `new`/`delete` of the C++ type, deleted
  in the existing finaliser; `exceptions.md` rows (category `alloc`, owner the JS object, release
  the finaliser).
  **Accept:** `cd oolite-dev && ! rg -n -P '\b(malloc|calloc|free)\s*\(' src/Core/Scripting/OOJSVector.cpp src/Core/Scripting/OOJSQuaternion.cpp`
- [ ] T020 [P] [US1] Static tables in `src/Core/Scripting/OOJSClasses.cpp:71,122-123` to
  `std::array`/`std::vector` with static lifetime (QuickJS keeps the pointer and never frees it).
  **Accept:** `cd oolite-dev && ! rg -n -P '\b(malloc|calloc|realloc)\s*\(' src/Core/Scripting/OOJSClasses.cpp`
- [ ] T021 [P] [US1] Growable arrays to `std::vector` in `src/Core/Octree.cpp:84,113,809-917`,
  `src/Core/CollisionRegion.cpp:67,98,202` and `src/Core/OOPolygonSprite.cpp:187-622`.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/Octree.cpp src/Core/CollisionRegion.cpp src/Core/OOPolygonSprite.cpp`
- [ ] T022 [P] [US1] Growable arrays to `std::vector` in `src/Core/OOSkyDrawable.cpp:522-608`,
  `src/Core/OOCrosshairs.cpp:44,89`, `src/Core/HeadUpDisplay.cpp:4470-4533`,
  `src/Core/Materials/OOShaderProgram.cpp:559-580` and `src/Core/Materials/OOShaderMaterial.cpp:301,707`.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src/Core/OOSkyDrawable.cpp src/Core/OOCrosshairs.cpp src/Core/HeadUpDisplay.cpp src/Core/Materials/OOShaderProgram.cpp src/Core/Materials/OOShaderMaterial.cpp`
- [ ] T023 [P] [US1] The rest: `std::vector` in `src/Core/OOProbabilitySet.cpp:391-514`,
  `src/Core/OOProbabilisticTextureManager.cpp:93-169` (four parallel arrays), `src/Core/OOSoundSourcePool.cpp:62,76`,
  `src/Core/Scripting/OOJSFrameCallbacks.cpp:366,377`, `src/Core/Entities/ShipEntity.cpp:13807,13823`
  (`JSValue` argv); `std::unique_ptr` for the handle in `src/Core/Debug/OOTCPStreamDecoder.cpp:72,98`.
  **Accept:** `cd oolite-dev && $C alloc`
- [ ] T024 [US1] Make `cppcoreguidelines-no-malloc` fatal (`WarningsAsErrors` in
  `oolite-dev/.clang-tidy`); run the ASan smoke run (quickstart M1) and `leaks --atExit` and
  record both in `baselines.md`; mark `alloc` `fatal` in data-model.md.
  **Accept:** `cd oolite-dev && $C alloc && ./mk.sh tidy && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | sed -n '/WarningsAsErrors/,/^[A-Z]/p' | grep -q no-malloc`

**Checkpoint**: US1 complete and independently verified (SC-001).

---

## Phase 4: User Story 3 — threads (Priority: P3, M2)

**Goal**: owned standard threads; no `oo::thread::detach`/`isMainThread` (FR-010, FR-011).
**Independent test**: `$C thread` exits 0; quit with a background task within the baseline; TSan
smoke clean. Contract: [contracts/threads.md](contracts/threads.md).

- [ ] T025 [US3] (design D4) In `src/Core/OOAsyncWorkManager.cpp`/`.h`: workers as
  `std::vector<std::jthread>` in the internal object, waiting on
  `std::condition_variable_any::wait(lock, stopToken, pred)`; `void shutdown() noexcept` exactly as
  the contract declares; the singleton as a never-deleted function-local static
  (`static auto& s = *new …`, an `exceptions.md` row) replacing `pthread_once` and the Windows
  mutex; remove the `oo::thread::detach` call (`:183`), keeping `setCurrentPriority(0.5)` and
  `setCurrentName(...)` (`:193-194`).
  **Accept:** `cd oolite-dev && ! rg -n 'oo::thread::detach|pthread_once' src/Core/OOAsyncWorkManager.cpp`
- [ ] T026 [US3] Call `OOAsyncWorkManager`'s `shutdown()` on the quit path before `exit(0)` in
  `src/Core/GameController.cpp:706`; add `tests/unit/core/test_OOAsyncWorkManagerShutdown.cpp`
  (queue a long task, call `shutdown()`, assert it returns once the task ends and that queued tasks
  do not run).
  **Accept:** `cd oolite-dev && rg -q 'shutdown\(\)' src/Core/GameController.cpp`, and CI runs the new test and it passes
- [ ] T027 [US3] Add `inline const std::thread::id kMainThreadId` to `src/oofnd/Thread.hpp` per the
  contract; replace `isMainThread()` at `src/Core/OORegExpMatcher.cpp:43,90`,
  `src/Core/GameController.cpp:143`, `src/Core/OOAsyncWorkManager.cpp:304` with
  `std::this_thread::get_id() == oo::thread::kMainThreadId`; make
  `src/Core/OOLogOutputHandler.cpp:100,107,238` use it instead of `sMainThreadID`; delete `detach`
  and `isMainThread` from `Thread.hpp`; port their cases in `tests/unit/oofnd/test_thread.cpp`
  (ledger rows, *covered*).
  **Accept:** `cd oolite-dev && $C thread && ! rg -n 'sMainThreadID' src`
- [ ] T028 [US3] TSan smoke run (quickstart M2) and quit-time measurement; record in
  `baselines.md`; quit time must not exceed the T009 baseline's median plus its spread.
  **Accept:** `grep -q 'M2 quit' specs/009-modern-cpp-std/baselines.md` and the recorded time is within the bound

**Checkpoint**: US3 complete.

---

## Phase 5: User Story 4 — `oofnd` keeps only what std lacks (Priority: P4, M3)

**Goal**: FR-012–FR-014; research R7. **Independent test**: `$C oofnd` exits 0;
`src/oofnd/Expected.hpp` gone; README lists every survivor with its reason.

- [ ] T029 [US4] `oo::Expected`/`oo::Unexpected`/`oo::unexpect`/`oo::BadExpectedAccess` to
  `std::expected`/`std::unexpected`/`std::unexpect`/`std::bad_expected_access` across `src`
  (18 game names in 10 files, 26 in `src/oofnd/FileSystem.hpp`, the other `oofnd` headers); delete
  `src/oofnd/Expected.hpp`; port `tests/unit/oofnd/test_expected.cpp` and the other tests that name
  them (ledger rows, *covered*).
  **Accept:** `cd oolite-dev && ! rg -n 'oo::(Expected|Unexpected|unexpect|BadExpectedAccess)\b|oofnd/Expected\.hpp' src tests && test ! -e src/oofnd/Expected.hpp`
- [ ] T030 [US4] Replace every `#include "oofnd/StdLib.hpp"` in game code (164 files) with the
  standard headers that file uses; fix the stale true/false-guard comment at
  `src/Core/OOAsyncWorkManager.cpp:34`; keep `src/oofnd/StdLib.hpp` itself until Jon rules on the
  `test_stdlib` ledger row.
  **Accept:** `cd oolite-dev && ! rg -n 'oofnd/StdLib\.hpp' src --glob '!src/oofnd/StdLib.hpp'`
- [ ] T031 [P] [US4] Derive `oo::Exception` from `std::exception` in `src/oofnd/Exception.hpp`
  (`what()` returns today's message); add `tests/unit/oofnd/test_exception_std.cpp` (registered)
  that catches a raised `oo::Exception` as `std::exception` and checks the message text.
  **Accept:** CI runs `test_exception_std` and it passes (it does not compile before)
- [ ] T032 [US4] Integer aliases (research R7): `NSInteger` → `std::ptrdiff_t`, `NSUInteger` →
  `std::size_t`, `NSTimeInterval` and `CGFloat` → the type `src/oofnd/objc/OOFoundationTypes.h`
  aliases today; `NSNotFound` → `inline constexpr std::ptrdiff_t kNotFound = INTPTR_MAX;` in
  namespace `oo` in that header; `NSRange`'s fields to `std::size_t`; delete the aliases. Leave the
  frozen strings in `src/Core/OOTypeEncodings.h` and `src/Core/Entities/OOEntityObjectNamesTable.h`
  untouched. Port the tests that name them, and `tests/unit/oofnd/test_foundation_types.cpp`
  where each assertion has a counterpart; report the rest (ledger).
  **Accept:** `cd oolite-dev && $C oofnd`
- [ ] T033 [P] [US4] `src/oofnd/Date.hpp`: replace the hand-written civil-date arithmetic
  (`:80-106`) with `std::chrono::year_month_day` and `std::format("{:%F %T}",
  std::chrono::floor<std::chrono::seconds>(…))`; keep the 2001 reference-date constant,
  `localUTCOffsetMinutes` and the double-seconds helpers; `tests/unit/oofnd/test_date.cpp`
  unchanged.
  **Accept:** CI `test_date` passes and `cd oolite-dev && ! rg -n -P '\b(146097|719468|365\s*\*\s*4\s*\+\s*1)\b' src/oofnd/Date.hpp`
- [ ] T034 [P] [US4] `src/oofnd/FileSystem.hpp`: callers of `fileExists`, `isDirectory`,
  `fileSize`, `freeSpace`, `currentDirectory` and `setCurrentDirectory` use `std::filesystem`'s
  `std::error_code` overloads directly; delete those six wrappers; port their cases in
  `tests/unit/oofnd/test_filesystem.cpp` (ledger, *covered*). The other functions keep GNUstep
  semantics and stay.
  **Accept:** `cd oolite-dev && ! rg -n -P 'oo::fs::(fileExists|isDirectory|fileSize|freeSpace|currentDirectory|setCurrentDirectory)\b' src tests`
- [ ] T035 [US4] Survey: build once locally with `-Wformat-signedness` added on the command line
  (`meson configure` of a scratch build directory, not committed) and write the per-area findings
  and every `oo::str::format` literal containing `{` or `}` to `specs/009-modern-cpp-std/format-survey.md`.
  **Accept:** `test -s specs/009-modern-cpp-std/format-survey.md && grep -c '^## ' specs/009-modern-cpp-std/format-survey.md` prints 6
- [ ] T036 [US4] Literal `oo::str::format` calls → `std::format` in area `entities`, by hand per
  research R7 (`%g` → `{:g}`, `%u` of a signed value keeps its unsigned conversion, `%60s` →
  `{:>60}`, `%c` of an `int` → `{:c}` of a `char`, `%.4X` → `{:04X}`, braces escaped); `DESC`
  formats and `vformat` stay printf.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Entities` and CI `test_FormatOutput`, `test_SaveEnumValues` pass
- [ ] T037 [US4] As T036, area `scripting` (leave `src/Core/Scripting/OOJSPlayerShip.cpp:1928`'s
  data format).
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Scripting`
- [ ] T038 [US4] As T036, area `materials`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core/Materials src/Core/OOOpenGL* src/Core/OOTexture*`
- [ ] T039 [US4] As T036, area `sdl-debug`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/SDL src/Core/Debug`
- [ ] T040 [US4] As T036, area `core` (leave `OOShipLibraryDescriptions.cpp:154,161,171`'s data
  formats).
  **Accept:** `cd oolite-dev && $C oofnd && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/Core --glob '!src/Core/{Entities,Scripting,Materials,Debug}/**'`
- [ ] T041 [US4] As T036, area `oofnd` (its own literal calls).
  **Accept:** `cd oolite-dev && ! rg -U -n -P 'oo::str::format\s*\(\s*"' src/oofnd --glob '!src/oofnd/String.hpp'`
- [ ] T042 [US4] Add `-Wformat-signedness` to the game's warning flags in `src/meson.build` if the
  whole tree builds without that warning; if not, record the remaining sites in research.md R7 and
  leave it off.
  **Accept:** `cd oolite-dev && ./mk.sh build test 2>&1 | { ! grep -q 'Wformat-signedness'; }`
- [ ] T043 [US4] Rewrite `src/oofnd/README.md`'s rules (C++23; exceptions are used) and add a
  *Surviving components* table (component | reason | pinned by) covering every row of data-model.md
  *Surviving `oofnd` component*.
  **Accept:** `cd oolite-dev && for c in Data String FileSystem Date Exception Finally NSRange PrintfFormat Notification Scanner Process Log LogFile Http Defaults ResourcePaths Encoding PList OOAssert Thread; do grep -q "| \`*$c" src/oofnd/README.md || exit 1; done`

**Checkpoint**: US4 complete (US4 acceptance 1–4).

---

## Phase 6: User Story 5 — enums P1–P9 (Priority: P5, M4)

**Goal**: FR-017–FR-020; research R8; [contracts/enums.md](contracts/enums.md).
**Independent test**: `$C enum` exits 0; only `OOOpenGLStates.tbl` remains; `test_SaveEnumValues`
and `test_EnumNameFallbacks` pass; corpus unchanged. Every test stand-in that redeclares a
production enum changes in the same commit as it.

- [ ] T044 [US5] Create `specs/009-modern-cpp-std/external-values.md` (columns of data-model.md
  *External names and values*) with a row for every name and number in research.md R8's
  visibility table, the value read from the code (not a `.tbl` column), and `pin` set to the
  `static_assert` or test that will pin it.
  **Accept:** `grep -c '^| ' specs/009-modern-cpp-std/external-values.md` prints at least 40
- [ ] T045 [US5] (design D3) Add `src/Core/OOEnumFlags.h` and `src/Core/OOEnumTable.h` exactly as
  contracts/enums.md declares them; convert `src/Core/Debug/OODebugFlags.h` to the exemplar shape
  (`enum class OODebugFlags : std::uint32_t`, `OOEnableFlagOperators`, `OOEnumName` with the
  `DEBUG_*` spellings, `static_assert`s), replacing `#define DEBUG_ALL` and the `#x` stringification
  in `src/Core/Scripting/OOJSConsole.cpp:222-223` with `OOEnumName`; check whether the global
  operators are found inside `namespace oo` and record the answer in the contract.
  **Accept:** `cd oolite-dev && rg -q 'enum class OODebugFlags' src/Core/Debug/OODebugFlags.h && ! rg -n '#define DEBUG_ALL' src`
- [ ] T046 [P] [US5] P2: named enums local to a `.cpp` file (about 12) to `enum class` with
  `kPascalCase` enumerators.
  **Accept:** `cd oolite-dev && ! rg -n -P '^\s*(typedef\s+)?enum\s+(?!class\b)\w+' src --glob '*.cpp' --glob '!src/Core/MiniZip/**' --glob '!src/SDL/EXRSnapshotSupport/**'`
- [ ] T047 [P] [US5] P3: anonymous enums that hold one constant → `inline constexpr` of the
  constant's natural type, areas `entities` and `core`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core --glob '!src/Core/{Scripting,Materials,Debug}/**'`
- [ ] T048 [P] [US5] As T047, areas `scripting` and `sdl-debug`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core/Scripting src/Core/Debug src/SDL --glob '!src/SDL/EXRSnapshotSupport/**'`
- [ ] T049 [P] [US5] As T047, area `materials`.
  **Accept:** `cd oolite-dev && ! rg -U -n -P '\benum\s*(:\s*[\w:]+\s*)?\{\s*\w+\s*=\s*[^,{}]+,?\s*\}' src/Core/Materials src/Core/OOOpenGL* src/Core/OOTexture*`
- [ ] T050 [US5] P4: named header enums in `src/Core/Entities` (and `src/Core/OOTypes.h`,
  `src/Core/OOEntityEnums.h`) that are neither in `external-values.md` nor flags nor P9 groups
  (for example `OOPrimedEquipmentMode`, `OOAegisStatus`, `OOMassUnit`, `OOCargoFlag`), converted to
  the contract's shape.
  **Accept:** `cd oolite-dev && $C enum --area entities` lists only enums named in `external-values.md`, the flag enums of T051–T055, or the P9 groups
- [ ] T051 [US5] P5: `ALERT_FLAG_*` (`src/Core/Entities/PlayerEntity.h:216`) → `enum class
  OOAlertFlags : std::uint16_t` with flag operators; mixed comparisons such as
  `alertFlags > ALERT_FLAG_YELLOW_LIMIT` (`PlayerEntity.cpp:5870`) keep their meaning through
  `oo::ToUnderlying`; the JS alert-flag properties (`OOJSPlayer.cpp:273-293`) keep their numbers
  (`static_assert`s).
  **Accept:** `cd oolite-dev && ! rg -n '\bALERT_FLAG_' src`
- [ ] T052 [US5] P5: `OOWeaponFacing` and `VALID_WEAPON_FACINGS` (`src/Core/OOTypes.h:204-215`) →
  `enum class OOWeaponFacing : std::uint8_t` flags; `weapon_facings` plist bits and
  `weaponFacings` JS numbers pinned.
  **Accept:** `cd oolite-dev && ! rg -n '\bVALID_WEAPON_FACINGS\b|\bWEAPON_FACING_' src`
- [ ] T053 [US5] P5: `kOOUniformConvert*` (`src/Core/Materials/OOShaderMaterial.h:48`),
  `kOOExpand*` (`src/Core/OOStringExpander.h:34`), `kOORegExp*` → flag `enum class`es.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<!::)\bkOO(UniformConvert|Expand|RegExp)\w+' src`
- [ ] T054 [US5] P5: `kOOByName*` (`src/Core/Entities/OOEntityCalledByName.h:46`, about 1,006
  references in `OOEntityCalledByNameTable.h`) → `enum class OOByName : unsigned` flags.
  **Accept:** `cd oolite-dev && ! rg -n -P '(?<!::)\bkOOByName\w+' src`
- [ ] T055 [US5] P5, last: `OOTexture` flags (`src/Core/Materials/OOTexture.h:47`, 29 values,
  multi-bit filter and channel fields; 275 src and 95 test references) → flag `enum class
  OOTextureFlags : std::uint32_t`; the `%X` cache key (`OODefaultShaderSynthesizer.cpp:353`)
  keeps its text; tests that name the flags change with it (ledger, *covered*).
  **Accept:** `cd oolite-dev && $C enum --area materials | { ! grep -q 'Materials/OOTexture.h'; }` and `rg -q 'enum class OOTextureFlags' src/Core/Materials/OOTexture.h`
- [ ] T056 [US5] P6: number-visible enums (`OOAlertCondition` in `src/Core/Entities/ShipEntity.h:191-198`;
  `OOSpeechSettings`, `OOFuelScoopStatus`, `OOMissileStatus`, `OOPlayerFleeingStatus`,
  `OOMarketFilterMode`, `OOMarketSorterMode` in `src/Core/Entities/PlayerEntity.h:86-262`;
  `OOStationAlertLevel` in `src/Core/Entities/StationEntity.h:39-43`) → `enum class … :
  std::int32_t` with a `static_assert` per value used by shaders (`EntityShaderBindings.cpp:611-661`),
  saves, JS and description keys.
  **Accept:** `cd oolite-dev && ! rg -n -P '\}\s*(OOAlertCondition|OOSpeechSettings|OOFuelScoopStatus|OOMissileStatus|OOPlayerFleeingStatus|OOMarketFilterMode|OOMarketSorterMode|OOStationAlertLevel)\s*;' src`
- [ ] T057 [US5] P7, step 1: replace every `CASE(#foo)`/`REVERSE_CASE` use in
  `src/Core/OOConstToString.cpp:33-37` and the hand switch in `src/Core/Entities/WormholeEntity.cpp:854-866`
  with explicit `OOEnumName` switches spelling today's strings, before any rename; `test_EnumNameFallbacks` passes.
  **Accept:** `cd oolite-dev && ! rg -n -P '\bCASE\s*\(|REVERSE_CASE' src/Core/OOConstToString.cpp`
- [ ] T058 [US5] P7, step 2: `OOCargoType`, `OORouteType`, `OOEnergyUnitType`,
  `OODockingClearanceStatus`, `OOGraphicsDetail` (`src/Core/OOTypes.h`), `OOHDRToneMapper`,
  `OOSDRToneMapper` (`src/SDL/MyOpenGLView.h:148-164`), `OOShaderSetting` (`src/Core/OOOpenGL.h:38-44`),
  `WORMHOLE_SCANINFO` (`src/Core/Entities/WormholeEntity.h:42-49`) → `enum class` with
  `kPascalCase` enumerators.
  **Accept:** `cd oolite-dev && ! rg -n -P '\}\s*(OOCargoType|OORouteType|OOEnergyUnitType|OODockingClearanceStatus|OOGraphicsDetail|OOHDRToneMapper|OOSDRToneMapper|OOShaderSetting|WORMHOLE_SCANINFO)\s*;' src`
- [ ] T059 [US5] P8: `OOScanClass`, `OOEntityStatus`, `OOShipDamageType` tables → headers per
  `notes/2026-11-07 Enum Tables from tbl X-Macros.md` and contracts/enums.md; delete their `.tbl`
  files; update `OOConstToString.cpp:39-48,122-127` and `OOConstToJSString.cpp:76-82`.
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOScanClass.tbl && test ! -e src/Core/Tables/OOEntityStatus.tbl && test ! -e src/Core/Tables/OOShipDamageType.tbl`
- [ ] T060 [US5] P8: `OOBehaviour`, `OOGalacticHyperspaceBehaviour` (its `GALACTIC_HYPERSPACE_##label`
  pasting replaced by explicit strings), `OOLegalStatusReason`.
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOBehaviour.tbl && test ! -e src/Core/Tables/OOGalacticHyperspaceBehaviour.tbl && test ! -e src/Core/Tables/OOLegalStatusReason.tbl`
- [ ] T061 [US5] P8: `OOCompassMode`, `OOViewID` (the program's ordinals, not the `.tbl` column:
  `VIEW_CUSTOM` 4, `VIEW_NONE` 5, `VIEW_GUI_DISPLAY` 6, `VIEW_BREAK_PATTERN` 7, `static_assert`ed;
  leave the `HeadUpDisplay.cpp:4658` missing-`VIEW_CUSTOM` behaviour as it is and record it in R14).
  **Accept:** `cd oolite-dev && test ! -e src/Core/Tables/OOCompassMode.tbl && test ! -e src/Core/Tables/OOViewID.tbl`
- [ ] T062 [US5] P8: `OOLongRangeChartMode` (save-visible ordinals pinned by `test_SaveEnumValues`)
  and `OOGUIScreenID` (ordinals 0…28); update the `.tbl` include in
  `tests/unit/core/test_OOJSSound.cpp` (ledger, *covered*).
  **Accept:** `cd oolite-dev && ls src/Core/Tables/*.tbl | grep -c tbl` prints 1 and `$C tbl`
- [ ] T063 [US5] (design D5) Decide, per int-natured group, `enum class` or typed constants
  (JS property IDs, GUI rows, `AXIS_*`/`BUTTON_*`, `STICKPROFILE_TYPE_*`, `GameViewKeys`,
  `OOPixMapFormat`, the debug TCP protocol numbers), defaulting as research R8 says; record each
  decision in research.md R8 and each typed-constant group in `exceptions.md`.
  **Accept:** `grep -c 'D5:' specs/009-modern-cpp-std/research.md` prints 7
- [ ] T064 [US5] P9: the 27 JS property-ID enums (`src/Core/Scripting/OOJSShip.cpp:202` and the
  others) → `enum class … : std::int16_t`; cast once in the `OOJS_PROPERTY_*` macros
  (`src/Core/Scripting/OOJSEngineCore.h`), `using enum` in each getter's `switch (magic)`;
  `OOJS_PROP_*` flags stay (exceptions row).
  **Accept:** `cd oolite-dev && $C enum --area scripting`
- [ ] T065 [US5] P9: GUI rows: `GUI_ROW()` (`src/Core/Entities/PlayerEntity.h:68-72`) and the row
  macro sets in `PlayerEntityKeyMapper.h:42-65`, `PlayerEntityContracts.h:59`,
  `PlayerEntityStickMapper.h:40-51`, `PlayerEntityStickProfile.cpp:38`, `PlayerEntityLoadSave.h:42-52`
  → per T063; replace `#if GUI_FIRST_ROW() < 0` (`PlayerEntity.h:165,199`) with a `static_assert`.
  **Accept:** `cd oolite-dev && ! rg -n 'GUI_ROW\(|#if GUI_FIRST_ROW' src`
- [ ] T066 [US5] P9: `AXIS_*`/`BUTTON_*` (`src/Core/OOJoystickManager.h:60,75`), `HW_AXIS`/`HW_BUTTON`
  (`:157`), `CUBE_FACE_*` (`src/Core/OOVoxel.h:37-42`), `STICKPROFILE_TYPE_*`
  (`src/Core/OOJoystickProfile.h:44`) per T063; arrays indexed by them become `std::array`
  indexed through `oo::ToUnderlying`; the preference-key ordinals (`ENUMKEY`,
  `OOJoystickManager.h:186`) `static_assert`ed in both `OO_FOV_INFLIGHT_CONTROL_ENABLED`
  configurations; `tests/unit/core/test_OOJoystickManager.cpp` changes with it (ledger).
  **Accept:** `cd oolite-dev && ! rg -n -P '#define\s+(CUBE_FACE_|HW_AXIS|HW_BUTTON|STICKPROFILE_TYPE_)' src && $C enum --area core`
- [ ] T067 [US5] P9: `GameViewKeys`, `OOPixMapFormat`, `OODebugTCPConsoleProtocol.h` numbers and
  the remaining `sdl-debug` and `materials` enums per T063.
  **Accept:** `cd oolite-dev && $C enum`
- [ ] T068 [US5] Make `cppcoreguidelines-use-enum-class` fatal; run the corpus
  (`bash tools/corpus.sh tier1`) and compare with its base result; check every `external-values.md`
  row has its pin.
  **Accept:** `cd oolite-dev && $C enum && $C tbl && ./mk.sh tidy && ! grep -q '| to add |' ../specs/009-modern-cpp-std/external-values.md`

**Checkpoint**: US5 complete apart from P10 (Phase 10).

---

## Phase 7: User Story 6 — C-style casts (Priority: P6, M5)

**Goal**: FR-024, FR-025, SC-010; research R16; [contracts/strings.md](contracts/strings.md)
*Casts*. **Independent test**: `$C cast` exits 0; build warning-free with `-Wold-style-cast`.
Each area: run `run-clang-tidy -p . -checks='-*,google-readability-casting' -fix` over the area,
review every fix, convert the rest by hand per the contract's table.

- [ ] T069 [US6] Area `entities`, `PlayerEntity*.cpp` (about 169 in `PlayerEntity.cpp`).
  **Accept:** `cd oolite-dev && $C cast --area entities | { ! grep -q 'PlayerEntity'; }`
- [ ] T070 [US6] Area `entities`, the rest (`ShipEntity*.cpp` about 144, the other entities; the
  152 `(Entity*)nullptr` arms → `static_cast<Entity*>(nullptr)`).
  **Accept:** `cd oolite-dev && $C cast --area entities`
- [ ] T071 [US6] Area `core` (`Universe.cpp` about 99, the rest of `src/Core`).
  **Accept:** `cd oolite-dev && $C cast --area core`
- [ ] T072 [US6] Area `materials` (`src/Core/OOOpenGLExtensionManager.cpp` about 131); the
  `memcpy` byte punning at `src/Core/Materials/OOPlanetTextureGenerator.cpp:809` and
  `src/Core/Materials/OOStandaloneAtmosphereGenerator.cpp:438` → `std::bit_cast`.
  **Accept:** `cd oolite-dev && $C cast --area materials`
- [ ] T073 [US6] Area `scripting`.
  **Accept:** `cd oolite-dev && $C cast --area scripting`
- [ ] T074 [US6] Areas `sdl-debug` and `oofnd`; casts from third-party macro expansions, if any are
  reported, become `exceptions.md` rows.
  **Accept:** `cd oolite-dev && $C cast`
- [ ] T075 [US6] Make `google-readability-casting` fatal and add `-Wold-style-cast` to the game's
  warning flags in `src/meson.build` in the same commit.
  **Accept:** `cd oolite-dev && ./mk.sh tidy && ./mk.sh build test 2>&1 | { ! grep -q 'Wold-style-cast'; }` and `grep -q 'Wold-style-cast' src/meson.build`

**Checkpoint**: US6 complete (SC-010).

---

## Phase 8: User Story 7 — C strings (Priority: P7, M6)

**Goal**: FR-026–FR-028, SC-011; research R17; contracts/strings.md *Text*. **Independent test**:
`$C cstring` exits 0; `$C cstring-types --unclassified` prints nothing; save round trip and
`test_FormatOutput` pass; ASan clean. Each area: signatures (`std::string_view` read, `std::string`
kept or returned, `std::optional` where null meant "no text"), literal tables to
`constexpr std::array<std::string_view, N>`, comparisons and searches, `printf`-family calls to
`std::format` by M3's method, parses kept identical; every C call takes `c_str()` or a literal.

- [ ] T076 [US7] Area `entities`.
  **Accept:** `cd oolite-dev && $C cstring --area entities && test -z "$($C cstring-types --unclassified --area entities)"`
- [ ] T077 [US7] Area `scripting` (QuickJS calls take `c_str()` or literals).
  **Accept:** `cd oolite-dev && $C cstring --area scripting && test -z "$($C cstring-types --unclassified --area scripting)"`
- [ ] T078 [US7] Area `materials` (GL shader sources and uniform names).
  **Accept:** `cd oolite-dev && $C cstring --area materials && test -z "$($C cstring-types --unclassified --area materials)"`
- [ ] T079 [US7] Area `sdl-debug` (`src/SDL/main.cpp` argv, SDL calls, the debug console).
  **Accept:** `cd oolite-dev && $C cstring --area sdl-debug && test -z "$($C cstring-types --unclassified --area sdl-debug)"`
- [ ] T080 [US7] Area `core`, including the exception-name `strcmp`s in
  `src/Core/Universe.cpp:4496,4562,4602,10451` → `std::string_view` `==`, and the fixed buffers C
  fills (`src/Core/OOCPUInfo.cpp`, OS paths) as `std::array<char, N>` at the call.
  **Accept:** `cd oolite-dev && $C cstring --area core && test -z "$($C cstring-types --unclassified --area core)"`
- [ ] T081 [US7] Area `oofnd` (parses whose `std::from_chars` answer differs stay in
  `src/oofnd/String.hpp` helpers, research R17).
  **Accept:** `cd oolite-dev && $C cstring && test -z "$($C cstring-types --unclassified)"`
- [ ] T082 [US7] Set `bugprone-unsafe-functions.CustomFunctions` in `oolite-dev/.clang-tidy` to
  contracts/strings.md's list (confirm the expressions against clang-tidy 22 on a sample file
  first); ASan smoke run clean.
  **Accept:** `cd oolite-dev && ./mk.sh tidy && /opt/homebrew/opt/llvm@22/bin/clang-tidy --dump-config src/Core/OOColor.cpp | grep -q 'strcpy'`

**Checkpoint**: US7 complete (SC-011).

---

## Phase 9: User Story 2 — ownership (Priority: P2, M7)

**Goal**: FR-005–FR-009, SC-002; research R5; [contracts/ownership.md](contracts/ownership.md).
**Independent test**: `$C ownership` exits 0; `src/oofnd/Ref.hpp` gone; disposal, finalisation and
the FR-016 tests pass; ASan and leaks clean; frame rate within the baseline. **T087 and everything
after it wait for Jon's signature on the T002 rows for `test_ref.cpp:514` and the construction-form
edits.**

- [ ] T083 [US2] (design D2) Inventory every function reachable from `Entity::willDispose()` and
  the `willDealloc` overrides (`src/Core/Entities/Entity.cpp:96-137`) that reads a weak reference
  to the dying entity, using the compile database (clangd call hierarchy or `clang-query`), not
  grep; fill data-model.md *Disposal reader*; answer whether any script event is sent from
  `willDispose()` and record it in research.md R5.
  **Accept:** `grep -c '^| ' specs/009-modern-cpp-std/data-model.md` grows by the number of readers, `clearBeacon` among them, and `grep -q 'script event.*willDispose' specs/009-modern-cpp-std/research.md`
- [ ] T084 [US2] Add `tests/unit/core/test_EntityDisposalReaders.cpp` (registered): one test per
  T083 reader pinning its effect (beacon list after a beacon ship is removed, dock and station
  teardown), passing on the base.
  **Accept:** CI runs `test_EntityDisposalReaders` and it passes on today's ownership code
- [ ] T085 [P] [US2] Add `tests/unit/core/test_ScriptFinalisationRelease.cpp` (registered): a
  native object referred to by a script object is released when the engine finalises the script
  object and not before; and an entity's disposal hook runs once, at the same point relative to
  removal from the universe.
  **Accept:** CI runs `test_ScriptFinalisationRelease` and it passes on today's ownership code
- [ ] T086 [US2] Rewrite each T083 reader per its chosen fix (`before release` or `identity`) so it
  no longer depends on weak references being live inside `willDispose()`; both T084 and the
  existing tests pass with today's ownership code.
  **Accept:** CI `test_EntityDisposalReaders` passes, and every *Disposal reader* row in data-model.md has a `fix`
- [ ] T087 [US2] (design D1; needs the T002 signatures) Add `src/oofnd/Object.hpp` and
  `src/oofnd/AutoreleaseScope.hpp` exactly as contracts/ownership.md declares them; rebuild
  `src/oofnd/WeakSet.hpp` on `std::weak_ptr`; turn `src/oofnd/Ref.hpp` into the bridge (the
  contract's table, including the "+1 from `new`" rules for `adopt`); port
  `tests/unit/oofnd/test_ref.cpp` and `tests/unit/oofnd/test_weakset.cpp` and make the
  construction-form edits (ledger rows from T002, now signed).
  **Accept:** `cd oolite-dev && rg -q 'class Object : public std::enable_shared_from_this<Object>' src/oofnd/Object.hpp` and CI `test_ref`, `test_weakset` and the whole `core` suite pass
- [ ] T088 [US2] Exemplar: `src/Core/OOColor.cpp`/`.h` and its holders off the bridge onto
  `std::shared_ptr<OOColor>`/`oo::makeShared`/`oo::share`.
  **Accept:** `cd oolite-dev && ! rg -n 'oo::(Ref|WeakRef)<\s*OOColor\b|makeRef<\s*OOColor\b' src`
- [ ] T089 [US2] The never-destroyed singletons (`makeRef(...).leakRef()` in
  `src/Core/GameController.cpp`, `OOCacheManager.cpp`, `OOShipRegistry.cpp`, `OOOXZManager.cpp`,
  `OOMusicController.cpp`, `OOGraphicsResetManager.cpp`, `OOALSoundMixer.cpp`, `OOALMusic.cpp`,
  `OOSoundSourcePool.cpp`, `OOTrumble.cpp`, `OOOpenGLExtensionManager.cpp`, `HeadUpDisplay.cpp`,
  `Materials/OONullTexture.cpp`, `Entities/PlayerEntitySound.cpp`, `Debug/OODebugMonitor.cpp`,
  `Scripting/OOJavaScriptEngine.cpp` ×2, `src/SDL/main.cpp`, and the work manager if T025 did not)
  → plain std at each site, no helper: `static const auto& s = *new
  std::shared_ptr<T>(oo::makeShared<T>(...));` where others share it, `static auto& s = *new
  T(...);` where nothing does; one `exceptions.md` row each.
  **Accept:** `cd oolite-dev && ! rg -n -P 'makeRef<[^>]+>\([^)]*\)\.leakRef\(\)' src --glob '!src/Core/Scripting/poc/**'`
- [ ] T090 [US2] Leaf types in area `core` (role sets, probability sets, characters, sounds,
  caches, async tasks, `PList::Object` → `std::shared_ptr<PListForeign>`) off the bridge; exclusive
  owners (research R5.8) → `std::unique_ptr` or values.
  **Accept:** `cd oolite-dev && $C ownership --area core`
- [ ] T091 [US2] Area `materials` (textures, materials, shaders, meshes) off the bridge.
  **Accept:** `cd oolite-dev && $C ownership --area materials`
- [ ] T092 [US2] The script slot: `OOJSSetCxxPrivate`/`OOJSGetCxxPrivate` and the finaliser in
  `src/Core/Scripting/OOJSPrivateObject.cpp` per the contract (heap `std::shared_ptr<oo::Object>`,
  today's finaliser order); `src/Core/Scripting/OOJSEntityHolder.h` and `ScriptPrivate` hold
  `std::weak_ptr`; `exceptions.md` row for the slot.
  **Accept:** `cd oolite-dev && ! rg -n 'leakRef|adopt\s*\(' src/Core/Scripting/OOJSPrivateObject.cpp && rg -q 'std::weak_ptr' src/Core/Scripting/OOJSEntityHolder.h` and CI `test_ScriptFinalisationRelease` passes
- [ ] T093 [US2] Entities, step 1: `src/Core/Entities/OOEntityHold.h` per the contract
  (`using EntityHold = std::shared_ptr<Entity>`, `Hold(e)`); entities made with `oo::makeShared`;
  the +1 creators (`newShipWithRole`, `newShipWithName`, …) return `std::shared_ptr`;
  `MadeEntity`/`MadeEntityRetained` in `src/Core/Entities/EntityHelpers.cpp` per the contract.
  **Accept:** `cd oolite-dev && rg -q 'using EntityHold = std::shared_ptr<Entity>' src/Core/Entities/OOEntityHold.h` and CI `test_EntityDisposalReaders`, `test_ScriptFinalisationRelease` pass
- [ ] T094 [US2] Entities, step 2: remove `RetainEntity`/`ReleaseEntity`/`AutoreleaseEntity` and
  the remaining `Ref`/`WeakRef` uses in `src/Core/Entities` and `src/Core/Universe.cpp`.
  **Accept:** `cd oolite-dev && $C ownership --area entities && ! rg -n '\b(Retain|Release|Autorelease)Entity\b' src`
- [ ] T095 [US2] Areas `scripting`, `sdl-debug`, `oofnd`: the remaining bridge uses.
  **Accept:** `cd oolite-dev && $C ownership`
- [ ] T096 [US2] The tests' remaining `oo::Ref`, `oo::WeakRef`, `oo::makeRef`, `retainCount()` and
  `oofnd/Ref.hpp` includes → `std::shared_ptr`, `std::weak_ptr`, `oo::makeShared`, `use_count()`,
  `<memory>` and `oofnd/Object.hpp`, including `tests/unit/core/EntityStandIn.h` (one ledger row per
  file, *covered*); assertions unchanged.
  **Accept:** `cd oolite-dev && ! rg -n -P '\boo::(Ref|WeakRef)\b|\bmakeRef\b|retainCount\s*\(|oofnd/Ref\.hpp' tests`
- [ ] T097 [US2] Delete the bridge: `src/oofnd/Ref.hpp`, `RefCounted`, `dropWeakReferences`.
  **Accept:** `cd oolite-dev && test ! -e src/oofnd/Ref.hpp && $C ownership`
- [ ] T098 [US2] Measure: ASan smoke and `leaks --atExit`; frame rate and start-up five runs each;
  record in `baselines.md`; both within the base's spread (SC-008).
  **Accept:** `grep -q 'M7 frame rate' specs/009-modern-cpp-std/baselines.md` and the recorded medians are within the bound
- [ ] T099 [US2] Update CLAUDE.md's "Ownership is `oo::Ref<T>`, not `shared_ptr`" line to the new
  rule (`std::shared_ptr`/`std::weak_ptr`/`std::unique_ptr`, objects from `oo::makeShared`) and
  spec 003's plan gate row (`specs/003-encapsulate-global-state/plan.md:99`).
  **Accept:** `! grep -q 'Ownership is `oo::Ref<T>`' CLAUDE.md && ! grep -q 'oo::Ref<oo::RefCounted>' specs/003-encapsulate-global-state/plan.md`

**Checkpoint**: US2 complete (SC-002, SC-008, SC-009).

---

## Phase 10: Polish and close-out (M8)

- [ ] T100 (needs the T002 signature for the P10 rows) P10: rename the enumerators of the 20
  existing `enum class` types to `kPascalCase` (`oo::PList::Type`, `oo::FileType`,
  `oo::Http::Scheme`, `OOJSCallEntityMethodForm`, …), with their test edits (ledger rows signed).
  **Accept:** `cd oolite-dev && ./mk.sh tidy` with `readability-identifier-naming` enabled reports no scoped-enum-constant finding
- [ ] T101 Make `readability-identifier-naming` fatal in `oolite-dev/.clang-tidy`.
  **Accept:** `cd oolite-dev && ./mk.sh tidy` and the check is in `WarningsAsErrors`
- [ ] T102 [P] Docs (FR-023): `docs/phases/4p-upstream-polish.md` (the "Out of scope here (Phase
  6)" paragraph), `docs/phases/6-modernise.md` (exit-gate items this feature did),
  `notes/2026-10-28 Modern C++ Idiom Review.md` (the `.tbl` "keep" lines at `:66` and `:222`, and
  the `Ref` decision), `notes/2026-11-07 Enum Tables from tbl X-Macros.md` (stale gates), and
  `oolite-dev/src/oofnd/README.md` (final component list).
  **Accept:** `! grep -q 'defensible pattern' 'notes/2026-10-28 Modern C++ Idiom Review.md' && grep -q '009-modern-cpp-std' docs/phases/6-modernise.md`
- [ ] T103 [P] If Jon has ruled on `test_stdlib` (T002 row), act on it: delete `src/oofnd/StdLib.hpp`
  only if he approved retiring the test; otherwise leave both and note it in the checklist.
  **Accept:** the `test_stdlib` ledger row's `signed` column is filled and the tree matches it
- [ ] T104 On a Windows machine: `tests/run.sh all` on Clang and on GCC
  (`--native-file=gcc.ini`); the corpus; record results, SC-001 to SC-011 and the final
  converted-category table (every category `fatal`) in `checklists/requirements.md` and
  data-model.md.
  **Accept:** `grep -c 'SC-0[01][0-9]: met' specs/009-modern-cpp-std/checklists/requirements.md` prints 11, or each unmet one names its reason

---

## Dependencies and execution order

```text
Phase 1 (T001–T003) → Phase 2 (T004–T012)
  → Phase 3 US1 (T013–T024)
  → Phase 4 US3 (T025–T028)        ┐ any order after Phase 2,
  → Phase 5 US4 (T029–T043)        ┘ one task at a time
  → Phase 6 US5 (T044–T068)        after Phases 3–5
  → Phase 7 US6 (T069–T075)        after Phase 6 (enum casts first)
  → Phase 8 US7 (T076–T082)        after Phases 5 and 7 (format method, cast rules)
  → Phase 9 US2 (T083–T099)        T083–T086 any time after Phase 2; T087+ after Jon signs
  → Phase 10 (T100–T104)           T100 after Jon signs the P10 rows
```

- Phase 9 may move to directly after Phase 3 if Jon signs early (it never runs beside Phases 6–8:
  they all rewrite `src/Core/Entities`).
- Inside a phase, unmarked tasks are sequential; [P] tasks may go in any order.
- T016 before T017 (the generators use the pixmap buffer). T029 before T032 (FileSystem's
  `oo::Unexpected`). T035 before T036–T041. T044–T045 before every other Phase 6 task. T057 before
  T058. T063 before T064–T067. T083 → T084 → T086 → T087 → T088 → T089 … → T097.

## Parallel opportunities

- Phase 2: T005, T006 together; T010, T011, T012 together.
- Phase 3: T014, T015, T018–T023 in any order.
- Phase 4 and Phase 5 interleave freely with each other.
- Phase 5: T031, T033, T034 beside the format tasks.
- Phase 6: T046–T049 in any order.
- Phase 9: T083–T085 can be done during Phases 3–8 (they add tests on today's code).

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
