# Implementation Plan: Replace the `.tbl` tables

**Branch**: `feature/replace-tbl-tables` (in `oolite-dev`, Git Town parent `seriesb/026-migration-completion`) | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-replace-tbl-tables/spec.md`

## Summary

Delete all eleven `src/Core/Tables/*.tbl` files. The ten named enums each become one
self-contained header: a scoped `std::int32_t` enum with `kPascalCase` members, an exhaustive
`OOEnumName` switch holding today's names, a name table derived from that switch at compile time,
`static_assert`s on every external number, and a marked block of aliases for today's member names
so that call sites keep compiling. The conversion functions and the script engine's name tables
read those headers instead of re-expanding the tables. `OOOpenGLStates.tbl` becomes a `constexpr`
item table in the state manager, checked field for field against the state record.

Planning measured what the scoping costs (research R2): on the base, the aliases keep every test
and almost every call site compiling; 61 lines in 8 files used these enums as plain numbers and
need an explicit type or conversion. The spec was amended to allow exactly those edits.

## Technical Context

**Language/Version**: C++20 (`src/meson.build:25`; no `std::to_underlying`). Clang (MSYS2 UCRT64,
23.1.4 locally) and GCC (`--native-file=gcc.ini`); clang-format 22 for formatting.

**Primary Dependencies**: none new. `src/Core/OOEnumTable.h` comes from spec 009's T046 with one
function appended (research R1, R3). The script layer on the base is QuickJS-ng's own API (`JSAtom` tables).

**Storage**: saved games store `chart_colour_mode` (`OOLongRangeChartMode`, ordinals 0–4) and
behaviour numbers; plists and scripts use the names. All unchanged (pinned).

**Testing**: `tests/run.sh unit` (meson suites, Windows), `component`, `smoke`, `all`; a new
`test_OOConstToStringEnums` written before the first conversion (research R9);
`test_OOOpenGLStateManager` unchanged; a new `test_OOOpenGLStateVerifier` that captures the debug verifier's log lines, also written before the change; `tools/check-enum-headers.sh` (new, research R6);
`-Wall` clean on Clang and GCC; the expansion corpus at the end.

**Target Platform**: Windows x64 for the suites; macOS arm64 and Linux x64 CI builds must also
compile (they may surface conversion lines R2's Windows-only check missed).

**Project Type**: desktop game; source-structure change only.

**Performance Goals**: none beyond "no measurable change": the tables are `constexpr`; the GL
write loops over 30 items per state change.

**Constraints**: no observable change; CLAUDE.md's hard rules; `Resources/`, MiniZip and the EXR
code untouched; one test edit.

**Scale/Scope**: 11 files (238 lines) deleted; 10 headers and 1 helper added; 7 including files
reworked; 61 call-site lines in 8 files; 1 test line block; 2 new tests; 1 check script; 2 docs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the blank template, so the gates are CLAUDE.md's hard
rules, as in specs 003 and 009.

| Gate | Plan | Status |
|---|---|---|
| 1. No test changed to make it pass | One edit, `test_OOJSSound.cpp:33-40`, under rule 1's third exception (a header the test names replaced), in `test-ledger.md` in the same commit. Two tests added (`test_OOConstToStringEnums`, `test_OOOpenGLStateVerifier`). R2 measured that no other test needs a change. | pass |
| 2. No warning silenced | None. Missing names surface as `-Wswitch`; `-Werror=switch` is used only inside the check script, not added to the build. | pass |
| 3. Never touch `develop`/`master`/`main`/`upstream-master` | Work on `feature/replace-tbl-tables` (Git Town parent `seriesb/026-migration-completion`) in a worktree; pushed, later synced with `git town sync --stack --detached`; Jon merges. Spec docs commit on the planning repo's current branch. | pass |
| 4. Never read expansion content | Corpus results only, through `tools/corpus.sh`. | pass |
| 5. Tools judge correctness | `static_assert`s, `test_OOConstToStringEnums` before and after, the suites, the check script, `-Wall` on two compilers. | pass |
| 6. No `libgnustep-base` or SpiderMonkey | Nothing added. | pass |
| 7. No rewriting C for its own sake | No C files involved. | pass |
| 8. Never wait for Jon | Every open choice has a default (*Notes*). | pass |
| 9. No writes outside the repo | Worktree and scratch under `.agent-tmp/`. | pass |
| 10. clang-format 22 on changed files, never `tests/` | Changed `src/` files only; the test edit by hand. | pass |
| Every task has a failing-then-passing command | Each group: `test ! -e` its `.tbl` files plus the suites and the check script; see [quickstart.md](quickstart.md). | pass |
| Follow the exemplar | The header shape is spec 009's contract and its `OODebugFlags` exemplar; naming rule likewise (R4). | pass |

**Re-check after Phase 1:** pass. Two additions need a reason (*Complexity Tracking*).

## Project Structure

### Documentation (this feature)

```text
specs/011-replace-tbl-tables/
├── spec.md              # the feature (amended after research, Notes item 5)
├── plan.md              # this file
├── research.md          # R1–R10
├── data-model.md        # named enum, groups G1–G5, alias, GL item, ledger format
├── quickstart.md        # how to verify each group
├── contracts/
│   ├── enum-header.md   # OOEnumTable.h addition; the header shape; consumers
│   ├── js-const-tables.md
│   └── gl-state-items.md
├── checklists/requirements.md
├── test-ledger.md       # created by the commit that edits test_OOJSSound.cpp
└── tasks.md             # /speckit-tasks
```

### Source Code (`oolite-dev`)

```text
src/Core/OOEnumTable.h                    # NEW: T046's file + MakeEnumTableInRange
src/Core/Tables/
├── .clang-tidy                           # NEW: scoped-enumerator naming, as errors
├── OOBehaviour.h … OOViewID.h            # NEW: ten headers (replace ten .tbl)
├── OO*.tbl                               # DELETED: all eleven
└── meson.build                           # unchanged
src/Core/OOTypes.h, src/Core/OOEntityEnums.h, src/Core/Entities/ShipEntity.h   # enum bodies → includes
src/Core/OOConstToString.cpp              # lookups through the tables
src/Core/Scripting/OOConstToJSString.cpp, .h   # rows from the tables; explicit conversions
src/Core/OOOpenGLStateManager.cpp         # item table + field-count check
src/Core/Entities/{PlayerEntity,PlayerEntityControls,PlayerEntityLegacyScriptEngine,ShipEntity}.cpp,
src/Core/{GuiDisplayGen,HeadUpDisplay,Universe}.cpp, src/Core/Scripting/OOJSGlobal.cpp   # R2 lines
tools/check-enum-headers.sh               # NEW, 100755
tests/unit/core/test_OOConstToStringEnums.cpp   # NEW (+ its tests/unit/core/meson.build entry)
tests/unit/core/test_OOJSSound.cpp        # the one edit
```

Planning repo: `docs/parity/c-and-tables.md` and `docs/current-state.md` (FR-015).

**Structure Decision**: headers stay in `src/Core/Tables`, where the `.tbl` files were and which
both the game and the unit tests already have on their include path, so no build file changes
except the new test's entry. `OOEnumTable.h` goes in `src/Core/` where spec 009 put it.

## Order of work

1. **G0 — groundwork.** `OOEnumTable.h`; `src/Core/Tables/.clang-tidy`; `tools/check-enum-headers.sh`
   (passes vacuously: no headers yet); `test_OOConstToStringEnums` and `test_OOOpenGLStateVerifier` passing on the unconverted tree.
2. **G1–G4** (data-model.md), each one change: write the headers, rework the consumers (the first
   group moves `OOConstToJSString.*` to the new shape), fix that group's R2 lines, delete the `.tbl`
   files; then the quickstart checks. G1 carries the test edit and creates `test-ledger.md`. Order
   G1→G4 matches spec 009's T060–T063; the groups do not depend on each other beyond
   `OOConstToJSString.*`, so they are sequential, not parallel.
3. **G5 — OpenGL items.** Independent of G1–G4; may run before or after. Drop-able (spec Notes 2).
4. **Close.** SC-004 trials recorded below; `tests/run.sh all`; GCC build; corpus; docs.

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| `MakeEnumTableInRange` appended to spec 009's helper | FR-005: the table must come from the switch, with no second member list | T046's explicit value list is a second list that can silently miss a member (R3) |
| `tools/check-enum-headers.sh` | FR-010: the naming rule must actually apply to the headers, and a missing name must be an error somewhere | a per-directory `.clang-tidy` alone does not reach headers (measured, R6); there is no `-Werror` build to rely on |

## Notes and decisions

Defaults taken without Jon (hard rule 8). Each is also in research.md with its reasons.

1. **Base and helper (R1).** A Git Town feature branch on `seriesb/026-migration-completion`
   (not `origin/develop`, which is 219 commits behind and still on the `ooscript` façade); take only `OOEnumTable.h` from
   `310cd4480`, verbatim plus one appended function.
2. **Scoped, with explicit conversions at 61 lines (R2).** The spec was amended (Notes item 5).
   Rejected: unscoped-with-underlying-type, which defers the point of the change.
3. **Mechanical member names (R4)**, giving `kOxzmanager`, `kSuncolor`; nicer spellings are spec
   009's naming sweep.
4. **Script tables (R5)** take the 2026-11-07 note's `JSAtom` design: rows from the headers, a
   parallel atom array interned once per process, no `qsort`. The base's search already uses signed
   bounds, so the underflow the `develop`-era code had is not present.
5. **The verifier's display quirk is kept (R7):** special items are logged through
   `OOGLFlagToString` whatever the `.tbl` named. **For Jon:** fixing it changes debug log text only.
6. **No script-API snapshot on the base (R9):** SC-003 rests on `test_OOConstToStringEnums`, the
   component suite and the pinned numbers, plus one by-hand save check.
7. **Worktree (R10):** `oolite-dev`'s own checkout is in use by another session.

**SC-004 trials** (filled in by the implementation): enum member without a case — result: _;
OpenGL record field without an item — result: _.
