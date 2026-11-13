---
description: "Tasks for replacing the .tbl tables (spec 011)"
---

# Tasks: Replace the `.tbl` tables

**Input**: Design documents from `specs/011-replace-tbl-tables/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md) (US1–US3, FR-001–FR-016, SC-001–SC-007),
[research.md](research.md) (R1–R10), [data-model.md](data-model.md) (groups G1–G5),
[contracts/enum-header.md](contracts/enum-header.md),
[contracts/js-const-tables.md](contracts/js-const-tables.md),
[contracts/gl-state-items.md](contracts/gl-state-items.md), [quickstart.md](quickstart.md)

**Tests**: Included. CLAUDE.md requires every task to have a command that exits nonzero before it
and zero after. Three new tests (T004, T005) are written and passing on the base **before** any
conversion; they are the before-and-after checks for US1 and US3. Each task ends with its
**Accept:** command.

**Where**: game work happens in the worktree `.agent-tmp/wt-tbl` on `feature/replace-tbl-tables`
(parent `seriesb/026-migration-completion`, research R1, R10), in an MSYS2 UCRT64 shell. Spec docs
commit in the planning repo. In the commands below, `$W` is `.agent-tmp/wt-tbl` relative to the
planning repo's root, and `UNIT` is
`meson test -C build/meson_test --print-errorlogs`, run from `$W`.

`WARN` (FR-013) builds the tree from scratch in its own directory with one compiler and prints its
warnings with line and column numbers stripped, one per line, sorted. `./mk.sh` cannot do this:
it always uses `build/meson_test` and would reconfigure the Clang directory for GCC. Define it
once per shell, in `$W`:

```bash
WARN() { rm -rf build/warn-$1 && meson setup build/warn-$1 -Ddebug=false -Dstrip_bin=true -Db_lto=true --native-file $1.ini >/dev/null && meson compile -C build/warn-$1 >build/warn-$1.log 2>&1 && touch build/warn-$1/ok && { grep -E ': warning:' build/warn-$1.log | sed -E 's/:[0-9]+:[0-9]+: warning:/: warning:/' | sort -u; true; }; }
```

The options are the ones `./mk.sh build test` passes. A warning is new if
`comm -13 ../tbl-warn-base-$1.txt <(WARN $1)` prints it; that command must print nothing, and
`build/warn-$1/ok` must exist afterwards (it is written only when the build succeeded, since a
failed build prints no warnings either).

**Commits**: one commit per task in `$W`, message starting with the task id (`T007: …`). Format
changed `src/` files with clang-format 22 only; never `tests/`. Push the branch after each phase
with `git push -u origin feature/replace-tbl-tables`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3 (spec.md)

---

## Phase 1: Setup

**Purpose**: the branch, its worktree and a passing baseline build.

- [ ] T001 Create the worktree and branch from the planning repo's root:
  `git -C oolite-dev worktree add ../.agent-tmp/wt-tbl -b feature/replace-tbl-tables origin/seriesb/026-migration-completion`,
  then `git -C .agent-tmp/wt-tbl town set-parent seriesb/026-migration-completion`; copy
  `oolite-dev/subprojects/quickjs-0.17.0` to `.agent-tmp/wt-tbl/subprojects/`.
  **Accept:** `test "$(git -C oolite-dev config git-town-branch.feature/replace-tbl-tables.parent)" = seriesb/026-migration-completion && git -C .agent-tmp/wt-tbl rev-parse --abbrev-ref HEAD | grep -qx feature/replace-tbl-tables`
- [ ] T002 Build the base in `$W` and run the unit suites; record any test that fails on the
  untouched base in plan.md *Notes* (those are not this feature's to fix). Record the base's
  warnings for FR-013 before anything changes: `WARN clang > ../tbl-warn-base-clang.txt` and
  `WARN gcc > ../tbl-warn-base-gcc.txt` (both in `.agent-tmp/`, not committed); note each file's
  line count in plan.md *Notes*.
  **Accept:** `cd $W && ./mk.sh build test && tests/run.sh unit && test -f build/warn-clang/ok && test -f build/warn-gcc/ok && test -f ../tbl-warn-base-clang.txt && test -f ../tbl-warn-base-gcc.txt`

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the shared helper, the header check, and the two before-and-after tests. No `.tbl`
file changes in this phase.

- [ ] T003 [P] Add `src/Core/OOEnumTable.h`: the text of `git show 310cd4480:src/Core/OOEnumTable.h`
  unchanged, plus `#include <type_traits>` and `oo::MakeEnumTableInRange<E, Lo, Hi>()` appended
  exactly as [contracts/enum-header.md](contracts/enum-header.md) gives it.
  **Accept:** `cd $W && rg -q 'consteval auto MakeEnumTableInRange' src/Core/OOEnumTable.h && ! git diff --no-index <(git show 310cd4480:src/Core/OOEnumTable.h) src/Core/OOEnumTable.h | grep -q '^-[^-]'`
- [ ] T004 [P] Add two tests and their entries in `tests/unit/core/meson.build`. Both check
  literals copied from `specs/009-modern-cpp-std/external-values.md`, name only the old member
  spellings (so they compile before and after), and must pass on the base.
  - `tests/unit/core/test_OOConstToStringEnums.cpp` (same sources as `test_OOConstToString`, line 99,
    with its own copy of that test's stubs; `test_OOConstToString.cpp` is not touched): the 144
    (value, name) pairs of the nine types other than `OOViewID` through the nine `cxx_OOStringFrom…`
    functions (the base has no `cxx_OOStringFromViewID`), and back through the six `…FromString`
    functions for the types that have them; the fallbacks (`cxx_OOStringFromBehaviour` of an
    unnamed value is `** BEHAVIOUR UNKNOWN **`, the other eight `UNDEFINED`); each `…FromString`
    default for an unknown name; `BEHAVIOR_ALL_SYSTEMS_REACHABLE` read as
    `BEHAVIOUR_ALL_SYSTEMS_REACHABLE`.
  - `tests/unit/core/test_OOConstToJSStringEnums.cpp` (sources: `Core/Scripting/OOConstToJSString.cpp`
    plus the fewest of `test_OOJSGlobal`'s, line 119, that link; context set up as that test's
    `SetUpContext` does, `JS_NewRuntime`, `JS_NewContext`, `OOConstToJSStringInit`): for each of the
    nine types with a script table (all but `OOBehaviour`), every (value, name) pair through
    `OOJSValueFrom<Type>` and back through `<Type>FromJSValue`, `OOViewID`'s 8 among them; a value
    with no row gives `"UNDEFINED"`; an unknown string and a non-string give `kOO<Type>Default`.
    Then an engine reset as the game does it (FR-007: `OOConstToJSStringDestroy()`,
    `JS_FreeContext`, a new `JS_NewContext` on the same runtime, `OOConstToJSStringInit`), and the
    same checks again on the new context.
  **Accept:** `cd $W && ./mk.sh build test && $UNIT test_OOConstToStringEnums && $UNIT test_OOConstToJSStringEnums`
- [ ] T005 [P] Add `tests/unit/core/test_OOOpenGLStateVerifier.cpp` and its entry in
  `tests/unit/core/meson.build` (same sources and GL context as `test_OOOpenGLStateManager`; that
  file is not touched). With a debug build (`OO_GL_STATE_VERIFICATION` 1), it captures
  `rendering.opengl.state` log lines through `oo::log`'s `setSink`, sets
  `OPENGL_STATE_OPAQUE`, then perturbs GL directly (`glDisable(GL_DEPTH_TEST)`,
  `glDisableClientState(GL_NORMAL_ARRAY)`, `glDepthMask(GL_FALSE)`, `glShadeModel(GL_FLAT)`,
  `glBlendFunc(GL_ONE, GL_ONE)`), calls `OOVerifyOpenGLState()`, and checks the exact lines logged
  (mismatch lines in item order, the special item's `OOGLFlagToString` text, the blend-mode line)
  and that GL was restored. The expected lines are what the base prints. If the message class
  cannot be enabled in a unit test, stop and record why in plan.md *Notes*; US3 then falls back to
  the by-hand log comparison in quickstart.md.
  **Accept:** `cd $W && ./mk.sh build test && $UNIT test_OOOpenGLStateVerifier`
- [ ] T006 [P] Add `src/Core/Tables/.clang-tidy` (only `readability-identifier-naming`, with
  `ScopedEnumConstantCase: CamelCase`, `ScopedEnumConstantPrefix: k`, in `WarningsAsErrors`) and
  `tools/check-enum-headers.sh` (`#!/usr/bin/env bash`, committed `100755`): for each argument,
  or every `src/Core/Tables/*.h` if none, run
  `clang-tidy --config-file=src/Core/Tables/.clang-tidy <h> -- -x c++ -std=c++20 -Isrc/Core -Isrc/Core/Tables`
  and `clang++ -x c++ -std=c++20 -fsyntax-only -Wall -Wextra -Werror=switch -Isrc/Core -Isrc/Core/Tables <h>`;
  exit 1 if any fails. The `--config-file` is required: without it clang-tidy takes the config from
  the header's own folder and its parents, so a header outside `src/Core/Tables` (the scratch one
  below) would get no naming check at all. With no headers yet it exits 0. Check it against a
  scratch header `.agent-tmp/bad-enum.h` (planning repo; `../bad-enum.h` from `$W`) holding
  `enum class E : int { kGood, BAD_ONE };`.
  **Accept:** `cd $W && git ls-files -s tools/check-enum-headers.sh | grep -q '^100755' && tools/check-enum-headers.sh && ! tools/check-enum-headers.sh ../bad-enum.h`

**Checkpoint**: helper, check script and both new tests are in, all passing on unconverted code.

---

## Phase 3: User Story 1 — each named enum is one readable header (Priority: P1) 🎯 MVP

**Goal**: FR-001–FR-008, FR-010, FR-012; the ten enum `.tbl` files replaced by headers in
[contracts/enum-header.md](contracts/enum-header.md)'s shape.

**Independent test**: none of the ten enum `.tbl` files exists; `test_OOConstToStringEnums` and
every other unit test pass; the component and smoke suites pass; a save from the base keeps its
chart colour mode on the branch.

**Rules for T008–T011** (one task per group, data-model.md): each header follows the contract
exactly (`std::int32_t` with its comment; members in `.tbl` order named by research R4's rule;
values from `external-values.md`, never a fictional `.tbl` column; literal names equal to today's;
`kOO<Type>Default` typed; `MakeEnumTableInRange` with research R3's range and a size
`static_assert`; one value `static_assert` per member; the compatibility block last). Then: replace
the type's enum body in its defining file with an `#include`; switch its `OOConstToString.cpp`
functions to the table (contract *Consumers*); switch its `OOConstToJSString.cpp` rows from the
temporary array to `ToConstRows(kOO<Type>Table)`; fix the lines the compiler then rejects (research
R2's list for the type, plus any GCC or another platform reports), each by giving the variable or
key the enum's type or by one `static_cast`, meaning unchanged; delete the `.tbl` files. No other
file changes.

- [ ] T007 [US1] Move `src/Core/Scripting/OOConstToJSString.cpp` and `.h` to
  [contracts/js-const-tables.md](contracts/js-const-tables.md)'s shape (`ConstRow`, `ConstTable`
  of rows and atoms, `JS_NewAtomLen`, no `qsort`), with every enum's rows still coming from its
  `.tbl` through a temporary array (`ENTRY(label, value)` → `{static_cast<std::int32_t>(label), "label"}`:
  the label's own value, never the column), sorted at compile time with `std::sort` (constexpr in
  C++20) and `static_assert`ed ascending. Make the header's inline wrappers convert explicitly.
  **Accept:** `cd $W && ! rg -n 'qsort|CompareEntries|TableEntry' src/Core/Scripting/OOConstToJSString.cpp && ./mk.sh build test && $UNIT test_OOConstToJSStringEnums && tests/run.sh unit && tests/run.sh component`
- [ ] T008 [US1] G1: `src/Core/Tables/OOScanClass.h`, `OOEntityStatus.h`, `OOShipDamageType.h`
  (ranges `-1, 999`; `-10, 999`; `0, 6`); bodies out of `src/Core/OOEntityEnums.h`; R2 lines for
  `OOScanClass` (`PlayerEntity.cpp`, `PlayerEntityLegacyScriptEngine.cpp`, `HeadUpDisplay.cpp`) and
  `OOEntityStatus` (`ShipEntity.cpp`, `GuiDisplayGen.cpp`, `Universe.cpp`); in
  `tests/unit/core/test_OOJSSound.cpp:33-40`, the `ENTRY` stand-in becomes
  `#include "OOEntityStatus.h"` (by hand, fork layout) and
  `specs/011-replace-tbl-tables/test-ledger.md` is created with that one row (data-model.md
  *Test-change ledger*), committed in the planning repo.
  **Accept:** `cd $W && test ! -e src/Core/Tables/OOScanClass.tbl && test ! -e src/Core/Tables/OOEntityStatus.tbl && test ! -e src/Core/Tables/OOShipDamageType.tbl && tools/check-enum-headers.sh && ./mk.sh build test && tests/run.sh unit`
- [ ] T009 [US1] G2: `OOBehaviour.h` (`0, 811`; no default; fallback `** BEHAVIOUR UNKNOWN **`),
  `OOGalacticHyperspaceBehaviour.h` (`-1, 2`; names `BEHAVIOUR_*` without the pasted prefix; old
  names `GALACTIC_HYPERSPACE_BEHAVIOUR_*` as aliases; `GALACTIC_HYPERSPACE_MAX` a typed constant;
  the `BEHAVIOR_` retry kept verbatim), `OOLegalStatusReason.h` (`0, 16`; prose names; the
  commented-out `ThereCanBeOnlyOne` stays commented); bodies out of `src/Core/Entities/ShipEntity.h`,
  `src/Core/OOEntityEnums.h`, `src/Core/OOTypes.h`; R2 line `ShipEntity.cpp:445`.
  **Accept:** `cd $W && test ! -e src/Core/Tables/OOBehaviour.tbl && test ! -e src/Core/Tables/OOGalacticHyperspaceBehaviour.tbl && test ! -e src/Core/Tables/OOLegalStatusReason.tbl && tools/check-enum-headers.sh && ./mk.sh build test && tests/run.sh unit`
- [ ] T010 [US1] G3: `OOCompassMode.h` (`-1, 6`, written values, shader-visible) and `OOViewID.h`
  (ordinals: `kCustom` 4, `kNone` 5, `kGuiDisplay` 6, `kBreakPattern` 7, `static_assert`ed, as the
  contract's worked example); bodies out of `src/Core/OOTypes.h`; R2 lines for `OOViewID`
  (`PlayerEntityControls.cpp:2121`, `HeadUpDisplay.cpp` scanner grid). Leave the scanner grid's
  missing `VIEW_CUSTOM` case as it is.
  **Accept:** `cd $W && test ! -e src/Core/Tables/OOCompassMode.tbl && test ! -e src/Core/Tables/OOViewID.tbl && tools/check-enum-headers.sh && ./mk.sh build test && tests/run.sh unit`
- [ ] T011 [US1] G4: `OOLongRangeChartMode.h` (ordinals `0, 4`, each `static_assert`ed with a
  comment naming the saved game's `chart_colour_mode`) and `OOGUIScreenID.h` (ordinals `0, 28`;
  `GUI_SCREEN_CONTRACTS` stays commented); bodies out of `src/Core/OOTypes.h`,
  `src/Core/OOEntityEnums.h`; R2 lines for both (`PlayerEntity.cpp` including the
  `chart_colour_mode` read at 1617, `PlayerEntityControls.cpp`, `OOJSGlobal.cpp`). Remove the now
  unused `ENTRY`/`DIFF_STRING_ENTRY`/`GALACTIC_HYPERSPACE_ENTRY` macros and the temporary row
  arrays.
  **Accept:** `cd $W && test "$(ls src/Core/Tables/*.tbl | wc -l)" -eq 1 && ! rg -n '#define (ENTRY|DIFF_STRING_ENTRY|GALACTIC_HYPERSPACE_ENTRY)\b' src tests && tools/check-enum-headers.sh && ./mk.sh build test && tests/run.sh unit`
- [ ] T012 [US1] Build from scratch with GCC and with Clang through `WARN`. Fix any further
  R2-style lines GCC rejects, by the same rule, and add each to plan.md *Notes*. Fix any warning
  that is not in the base's list, and never by silencing it. Then run the component and smoke
  suites.
  **Accept:** `cd $W && test -z "$(comm -13 ../tbl-warn-base-gcc.txt <(WARN gcc))" && test -f build/warn-gcc/ok && test -z "$(comm -13 ../tbl-warn-base-clang.txt <(WARN clang))" && test -f build/warn-clang/ok && tests/run.sh component && tests/run.sh smoke`
- [ ] T013 [US1] SC-003 and SC-004 by hand, results recorded in plan.md *Notes* (planning repo):
  save on a base build with the long-range chart in economy mode and load it on the branch (same
  mode; `chart_colour_mode` 2 in both saves); add a member with no `case` to `OOViewID.h`, confirm
  `tools/check-enum-headers.sh` fails and the game build warns `-Wswitch`, revert.
  **Accept:** `grep -q 'enum member without a case — result: [a-z]' specs/011-replace-tbl-tables/plan.md && grep -q 'chart_colour_mode' specs/011-replace-tbl-tables/plan.md`

**Checkpoint**: US1 done; only `OOOpenGLStates.tbl` remains.

---

## Phase 4: User Story 2 — call sites keep working (Priority: P2)

**Goal**: FR-009, SC-006, SC-007. The aliases are written in T008–T011; this phase checks that the
change stayed inside its allowed files.

**Independent test**: the diff from the base touches only the allowed files, and every header's
compatibility block says it is temporary.

- [ ] T014 [US2] Check that every converted header has the compatibility block comment naming spec
  009's naming milestone, and that the branch's changed files are only: `src/Core/OOEnumTable.h`,
  `src/Core/Tables/*`, `src/Core/OOTypes.h`, `src/Core/OOEntityEnums.h`,
  `src/Core/Entities/ShipEntity.h`, `src/Core/OOConstToString.cpp`,
  `src/Core/Scripting/OOConstToJSString.{cpp,h}`, research R2's files, files T012 added (each line
  listed in plan.md *Notes*), `src/Core/OOOpenGLStateManager.cpp` (after US3), `tools/check-enum-headers.sh`,
  `tests/unit/core/meson.build`, the three new tests and `tests/unit/core/test_OOJSSound.cpp`.
  The pattern below is that list; a file T012 added goes into it, with its line in plan.md *Notes*.
  Anything else, `Resources/`, `src/Core/MiniZip` and `src/SDL/EXRSnapshotSupport` included
  (FR-014), fails the check. Record the per-change line counts (SC-007, about 400 each at most) in
  plan.md *Notes*.
  **Accept:** `cd $W && test "$(rg -l "Compatibility: today's names" src/Core/Tables/*.h | wc -l)" -eq 10 && test -z "$(git diff --name-only seriesb/026-migration-completion | grep -vxE 'src/Core/OOEnumTable\.h|src/Core/Tables/[^/]+|src/Core/(OOTypes|OOEntityEnums)\.h|src/Core/Entities/ShipEntity\.h|src/Core/OOConstToString\.cpp|src/Core/Scripting/OOConstToJSString\.(cpp|h)|src/Core/Entities/(PlayerEntity|PlayerEntityControls|PlayerEntityLegacyScriptEngine|ShipEntity)\.cpp|src/Core/(GuiDisplayGen|HeadUpDisplay|Universe)\.cpp|src/Core/Scripting/OOJSGlobal\.cpp|src/Core/OOOpenGLStateManager\.cpp|tools/check-enum-headers\.sh|tests/unit/core/(meson\.build|test_OOConstToStringEnums\.cpp|test_OOConstToJSStringEnums\.cpp|test_OOOpenGLStateVerifier\.cpp|test_OOJSSound\.cpp)')" && test "$(git diff --name-only seriesb/026-migration-completion -- tests | grep -v -e 'meson.build$' -e 'test_OOConstToStringEnums.cpp$' -e 'test_OOConstToJSStringEnums.cpp$' -e 'test_OOOpenGLStateVerifier.cpp$' | wc -l)" -eq 1`

**Checkpoint**: US1 and US2 done.

---

## Phase 5: User Story 3 — the OpenGL state list is plain code (Priority: P3)

**Goal**: FR-011; [contracts/gl-state-items.md](contracts/gl-state-items.md). Independent of
Phases 3–4 apart from T005; may run before them. Droppable (spec Notes 2).

**Independent test**: no `.tbl` file anywhere; `test_OOOpenGLStateManager` (unchanged) and
`test_OOOpenGLStateVerifier` pass.

- [ ] T015 [US3] In `src/Core/OOOpenGLStateManager.cpp`: keep `OOOpenGLState`'s fields and
  `kStandardStates` as they are; add the `constexpr` `kStateItems` table built with the four kind
  functions (30 items, `.tbl` order), the local `AggregateFieldCount` and the
  `static_assert(AggregateFieldCount<OOOpenGLState>() == 1 + std::size(kStateItems) + 2)`; turn the
  `SetState_*` macros into functions; make read, compare, log and write loops over the table with
  the behaviour table of the contract (the "maybe" rule, specials logged through
  `OOGLFlagToString`, the blend function outside the table and rewritten when the source `BLEND` is
  `kStateFalse`); rewrite the design-notes comment; delete `src/Core/Tables/OOOpenGLStates.tbl`.
  **Accept:** `cd $W && test -z "$(ls src/Core/Tables/*.tbl 2>/dev/null)" && ! rg -n '\.tbl"' src tests && ./mk.sh build test && $UNIT test_OOOpenGLStateManager && $UNIT test_OOOpenGLStateVerifier`
- [ ] T016 [US3] SC-004 trials, two, each reverted afterwards and recorded in plan.md *Notes*:
  (a) add a field to `OOOpenGLState` with no item, and confirm the build fails at the field-count
  `static_assert`; (b) the case SC-004 and US3 acceptance 4 name, an item with no way to set it:
  drop the setter argument from one integer item's builder call (`SHADE_MODEL`), and confirm the
  build fails at that call.
  **Accept:** `grep -q 'OpenGL record field without an item — result: [a-z]' specs/011-replace-tbl-tables/plan.md && grep -q 'OpenGL item without a setter — result: [a-z]' specs/011-replace-tbl-tables/plan.md`

**Checkpoint**: all three stories done; SC-001 holds.

---

## Phase 6: Polish and close-out

- [ ] T017 [P] Update `docs/parity/c-and-tables.md` (the `Core/Tables/*.tbl` row: replaced by the
  ten headers and the item table, with the reason) and `docs/current-state.md` (where the enum
  names live; the check script) in the planning repo (FR-015).
  **Accept:** `! grep -q 'Core/Tables/\*.tbl` (11 files)' docs/parity/c-and-tables.md && grep -q 'check-enum-headers' docs/current-state.md`
- [ ] T018 Run everything once more, then the expansion corpus from the planning repo
  (`bash tools/corpus.sh tier1`) and compare it with the base's result; record both in plan.md
  *Notes*. Repeat T012's warning check, since US3 landed after it (FR-013). Push the branch;
  remove nothing (Jon merges).
  **Accept:** `cd $W && tests/run.sh all && test -z "$(comm -13 ../tbl-warn-base-clang.txt <(WARN clang))" && test -f build/warn-clang/ok && test -z "$(comm -13 ../tbl-warn-base-gcc.txt <(WARN gcc))" && test -f build/warn-gcc/ok && git status --porcelain | wc -l | grep -qx 0 && git rev-parse @{u} >/dev/null`
- [ ] T019 Remove the worktree with `git -C oolite-dev worktree remove ../.agent-tmp/wt-tbl` (never
  `prune`), after T018's push.
  **Accept:** `! git -C oolite-dev worktree list | grep -q 'wt-tbl' && git -C oolite-dev ls-remote --exit-code origin feature/replace-tbl-tables`

---

## Dependencies

- T001 → T002 → Phase 2. In Phase 2, T003–T006 are independent.
- US1: T007 needs T002; T008 needs T003, T004, T006, T007; T009–T011 each need the one before
  (they share `OOConstToString.cpp`, `OOConstToJSString.cpp` and the defining headers); T012 needs
  T011; T013 needs T012.
- US2: T014 needs T013 (and T015 if US3 ran first).
- US3: T015 needs T005 only; T016 needs T015.
- Polish: T017 any time after T015; T018 after everything; T019 after T018.

Story order: US1 → US2; US3 independent.

## Parallel opportunities

- Phase 2: T003, T004, T005, T006 touch different files (T004 and T005 both add a line to
  `tests/unit/core/meson.build`; do them in one sitting or rebase the second).
- US3 (T015–T016) can run alongside US1 in a second worktree branched from T006's commit, since it
  touches only `OOOpenGLStateManager.cpp` and the `.tbl` it deletes; merge order then does not
  matter.
- T017 alongside T015.

## Implementation strategy

- **MVP**: Phases 1–3 (US1). The game's ten enums are readable headers with every external name
  and number pinned.
- Then US2's audit (cheap) and US3 (independent, droppable).
- Each group (T008–T011) is a reviewable commit of its own; stop after any of them and the tree is
  consistent.
