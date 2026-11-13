---
description: "Tasks for replacing the last .tbl table (spec 011)"
---

# Tasks: Replace the last `.tbl` table

**Input**: [spec.md](spec.md) (US1, FR-001–FR-007, SC-001–SC-004), [plan.md](plan.md),
[research.md](research.md) (R1–R4), [contracts/gl-state-items.md](contracts/gl-state-items.md),
[quickstart.md](quickstart.md)

**Where**: `$W` is `.agent-tmp/wt-tbl`, a worktree of `oolite-dev` on `seriesb/027-modern-cpp`, in
an MSYS2 UCRT64 shell. `UNIT` is `meson test -C build/meson_test --print-errorlogs`, run from `$W`.
Spec docs commit in the planning repo. One commit per task in `$W`, message starting with
`spec 011 T00n:`. clang-format 22 on the changed `src/` file only.

## Phase 1: Setup

- [x] T001 Worktree on `seriesb/027-modern-cpp` (research R4), with QuickJS copied in.
  **Accept:** `git -C .agent-tmp/wt-tbl rev-parse --abbrev-ref HEAD | grep -qx seriesb/027-modern-cpp`
- [x] T002 Build the base, run the unit suites, and record in plan.md *Results* the result and
  the `warning:` lines the build log has for `OOOpenGLStateManager.cpp`.
  **Accept:** `cd $W && ./mk.sh build test && tests/run.sh unit`

## Phase 2: User Story 1 — the OpenGL state list is plain code (P1)

**Independent test**: no `.tbl` anywhere; `test_OOOpenGLStateManager` (unchanged) and
`test_OOOpenGLStateVerifier` pass.

- [x] T003 [US1] Add `tests/unit/core/test_OOOpenGLStateVerifier.cpp` (research R3) and its
  `tests/unit/core/meson.build` entry, which has `test_OOOpenGLStateManager`'s sources. It must
  pass on the base.
  **Accept:** `cd $W && ./mk.sh build test && $UNIT test_OOOpenGLStateVerifier`
- [x] T004 [US1] In `src/Core/OOOpenGLStateManager.cpp`, per the contract:
  - Write out the record's fields.
  - Add `StateItem`, the four builders, `kStateItems` (30 items, the `.tbl`'s order),
    `AggregateFieldCount` and the field-count `static_assert`.
  - Turn the `SetState_*` macros into functions, and compile `GetState_*` in every build.
  - Make read, compare, log and write loops over the table, with the blend function outside it.
  - Rewrite the design-notes comment.
  - Delete `src/Core/Tables/OOOpenGLStates.tbl`.

  **Accept:** `cd $W && test -z "$(ls src/Core/Tables/*.tbl 2>/dev/null)" && ! git grep -q '\.tbl"' -- src tests && ./mk.sh build test && $UNIT test_OOOpenGLStateManager && $UNIT test_OOOpenGLStateVerifier && git diff --quiet 3732f6126 -- tests/unit/core/test_OOOpenGLStateManager.cpp`
- [x] T005 [US1] SC-002 trials, each reverted and recorded in plan.md *Results*:
  (a) a field added to `OOOpenGLState` with no item fails at the field-count `static_assert`;
  (b) `SHADE_MODEL`'s `IntItem` without its setter fails at that line.
  **Accept:** `grep -q 'OpenGL record field without an item — result: [a-z]' specs/011-replace-tbl-tables/plan.md && grep -q 'OpenGL item without a setter — result: [a-z]' specs/011-replace-tbl-tables/plan.md`
- [x] T006 [US1] Unit, component and smoke suites; a GCC build directory; compare the
  `OOOpenGLStateManager.cpp` and `test_OOOpenGLStateVerifier.cpp` warnings on both compilers with
  T002's; record in plan.md *Results*.
  **Accept:** `cd $W && tests/run.sh unit && tests/run.sh component && tests/run.sh smoke && meson compile -C build/gcc`

## Phase 3: Polish

- [x] T007 [P] Update `docs/parity/c-and-tables.md` (the `Core/Tables/*.tbl` row) and
  `docs/current-state.md` (where the state items live) in the planning repo (FR-007).
  **Accept:** `! grep -q 'Core/Tables/\*.tbl` (11 files)' docs/parity/c-and-tables.md && grep -q 'kStateItems' docs/current-state.md`
- [x] T008 Leave everything committed in `$W` and in the planning repo. Do not push
  (plan Notes 2). Leave the worktree for Jon to merge from or remove.
  **Accept:** `test -z "$(git -C .agent-tmp/wt-tbl status --porcelain)"`

## Dependencies

T001 → T002 → T003 → T004 → T005, T006 → T008; T007 any time after T004.
