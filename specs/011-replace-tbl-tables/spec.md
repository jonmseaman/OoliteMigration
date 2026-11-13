# Feature Specification: Replace the last `.tbl` table

**Branch**: commits on `seriesb/027-modern-cpp` (in `oolite-dev`); spec directory `011-replace-tbl-tables`

**Created**: 2026-11-12 | **Re-scoped**: 2026-11-13

**Status**: In progress

**Input**: User description: "Plan replacement for `.tbl` files, which seem to be basically gross enums."

## Purpose

`src/Core/Tables` held eleven `.tbl` files: lists of macro calls whose meaning was set by
whatever macros the including file defined just before the `#include`. On `seriesb/027-modern-cpp`
ten of them are gone already: spec 009's T060–T063 turned the ten named enums into headers
(`OOScanClass.h` … `OOViewID.h`). One is left, `OOOpenGLStates.tbl`, and this feature replaces it
with ordinary C++, so that the source tree has no `.tbl` file. Nothing a player, an expansion, a
script, a shader or a saved game can observe changes.

## Context

What the tree is on `seriesb/027-modern-cpp` (`3732f6126`, 2026-11-13; "the base" below):

- **The file.** `src/Core/Tables/OOOpenGLStates.tbl` lists the 30 fixed-function OpenGL state
  items the state manager tracks (`ITEM_STATEFLAG(LIGHTING)`, `ITEM_INT(SHADE_MODEL)`, …). It is
  `#include`d five times in `src/Core/OOOpenGLStateManager.cpp`, each time under different
  `ITEM_*` macros: to declare the state record's fields and to read, compare, log and write the
  state, by pasting the item name into `GL_##NAME`, `GetState_##NAME` and `SetState_##NAME`.
- **The items.** 17 on/off flags (`glIsEnabled`/`glEnable`/`glDisable`; a standard state may leave
  one open, `StateFlag::kMaybe`), 6 client-array flags (`glEnableClientState`; never open),
  4 specials with their own getter and setter (`DEPTH_WRITEMASK`, `TEXTURE_ENV_MODE`,
  `ACTIVE_TEXTURE`, `CLIENT_ACTIVE_TEXTURE`), 3 integers (`glGetIntegerv`, own setter). The blend
  function is two fields set by one `glBlendFunc` call and is handled outside the list.
- **The verifier.** Debug builds (`OO_GL_STATE_VERIFICATION`, i.e. no `NDEBUG`, which includes the
  test flavour) read the GL state back at each state switch and log every mismatch to
  `rendering.opengl.state`, then repair it.
- **Why only now.** The fixed-function OpenGL this describes is due to be replaced (Phase 6,
  OpenGL 3.3 Core), which may delete the state manager. It is worth doing because it is the last
  `.tbl` file.

## User Scenarios & Testing *(mandatory)*

The users are the people who read and change the game's source. Players and expansions must not
notice.

### User Story 1 - The OpenGL state list is plain code (Priority: P1)

A developer who needs to add, remove or inspect a tracked OpenGL state item finds the list of items
written once, in ordinary C++, with each item's kind (on/off flag, client-array flag, integer,
special) and how it is read and set, and with no file that means different things at each of five
includes.

**Independent Test**: Before: `OOOpenGLStates.tbl` exists and the state manager includes it five
times. After: no `.tbl` file exists anywhere in the source tree; the state manager's
characterisation test passes without edits; the verifier's log for a deliberately mismatched state
is the same as on the base.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** the source tree is searched for `.tbl` files, **Then**
   there are none.
2. **Given** each of the standard OpenGL states, **When** it is set from any other standard state,
   **Then** every tracked item reads back as on the base (`test_OOOpenGLStateManager`, unchanged).
3. **Given** a debug build and a state mismatch, **When** the verifier reports it, **Then** the
   report lists the same lines, items in the same order, as on the base.
4. **Given** a new state item to track, **When** a developer adds it, **Then** the item is written
   in one place, and forgetting its field, its read or its write fails the build.

### Edge Cases

- **The "maybe" state.** Flags left open in a standard state are neither compared nor set, nor
  logged when expected open; client-array flags cannot be open. Both rules hold after the change.
- **The blend function** stays outside the list: read with two `glGetIntegerv`, compared, logged
  as one line after the items, and written when either value differs or the source state's `BLEND`
  is `StateFlag::kFalse`.
- **A display quirk.** The verifier shows every special item through `OOGLFlagToString`
  (`ENABLED`/`disabled`), whatever its type, so a `GL_TEXTURE1` active texture prints as
  `ENABLED`. Kept: the log text does not change.
- **Order of GL calls.** A switch makes the same GL calls in the same order as on the base.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `OOOpenGLStates.tbl` MUST be replaced by ordinary C++ in
  `OOOpenGLStateManager.cpp` that lists each tracked state item in one table, one entry per item,
  with its kind and how it is read and set, from which the read, the comparison, the log and the
  write all follow; the `.tbl` file MUST be deleted.
- **FR-002**: The build MUST check the table against the state record, so that a record field
  without an item, or an item without its field, read or write, fails to compile.
- **FR-003**: The items, their kinds, their order, the standard states' values, the "maybe" rule,
  the separate blend-function handling and the verifier's log lines MUST be as on the base.
- **FR-004**: No existing test MAY be modified. Tests MAY be added.
- **FR-005**: The build MUST produce no new warnings on Clang or GCC, and no warning MAY be
  silenced.
- **FR-006**: No file outside `src/Core/OOOpenGLStateManager.cpp`, `src/Core/Tables/OOOpenGLStates.tbl`
  and the added test with its `tests/unit/core/meson.build` entry MAY change in `oolite-dev`.
- **FR-007**: `docs/parity/c-and-tables.md` and `docs/current-state.md` MUST describe the tables
  as they are after the change.

### Key Entities

- **OpenGL state item**: one tracked piece of fixed-function OpenGL state; has a name (the GL
  enumerant without `GL_`), a kind, a field in the state record, how it is read and set, and a
  value in each standard state.

## Success Criteria *(mandatory)*

- **SC-001**: The source tree has no `.tbl` file (1 on the base) and no `#include` of one (5).
- **SC-002**: A record field added without an item, and an item listed without its setter, each
  fail the build (one trial each, recorded in the plan's notes).
- **SC-003**: `test_OOOpenGLStateManager` passes unchanged, and `test_OOOpenGLStateVerifier`,
  written and passing on the base before the change, passes after it.
- **SC-004**: The unit, component and smoke suites pass as on the base.

## Assumptions

- The ten enum tables are spec 009's work and are done on the base (T060–T063); this spec does not
  revisit them.
- The test flavour has `OO_GL_STATE_VERIFICATION` on, so the verifier's code is built and tested
  by `tests/run.sh unit`.

## Notes and decisions

Decisions taken without Jon (hard rule 8), each with its default and reason:

1. **Re-scoped, 2026-11-13.** The first version of this spec covered all eleven tables on
   `seriesb/026-migration-completion`. On `seriesb/027-modern-cpp` the ten enum tables are already
   headers (spec 009 T060–T063), so only the OpenGL table is left.
2. **Branch: Jon, 2026-11-13.** "Since the work is so much smaller, I guess it could just be added
   onto the seriesb/027 branch." The commits go on `seriesb/027-modern-cpp`, in the worktree
   `.agent-tmp/wt-tbl`, because `oolite-dev`'s own checkout is in use.
3. **The display quirk is kept**: fixing it would change debug log text.
4. **No corpus run.** The corpus loads expansions on a headless build. The GL state manager runs
   only when rendering, and its calls do not depend on expansions.
