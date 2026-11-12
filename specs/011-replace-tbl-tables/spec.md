# Feature Specification: Replace the `.tbl` tables

**Feature Branch**: `feature/replace-tbl-tables` (in `oolite-dev`); spec directory `011-replace-tbl-tables`

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Plan replacement for `.tbl` files, which seem to be basically gross enums."

## Purpose

`src/Core/Tables` holds eleven `.tbl` files. None of them is valid C++ on its own: each is a list
of macro calls (`ENTRY(...)`, `DIFF_STRING_ENTRY(...)`, `GALACTIC_HYPERSPACE_ENTRY(...)`,
`ITEM_STATEFLAG(...)` …) whose meaning is set by whatever macros the including file has defined
just before the `#include`. A reader of a `.tbl` cannot tell what it produces, and a reader of the
enum it feeds cannot see that enum's members or values without opening the table and working out
which expansion applies. This feature replaces every `.tbl` file with ordinary C++ that says what it
is where it is written: an enum and its names in one header, and the OpenGL state list as plain
code. Nothing a player, an expansion author, a script, a shader or a saved game can observe changes.

## Context

What the tree is today (`oolite-dev` `develop`, 2026-11-12):

- **The files.** 11 `.tbl` files, 238 lines, `#include`d 40 times from 7 files
  (`OOConstToString.cpp` 15, `OOConstToJSString.cpp` 9, `OOEntityEnums.h` 5,
  `OOOpenGLStateManager.cpp` 5, `OOTypes.h` 4, `ShipEntity.h` 1, and one test,
  `tests/unit/core/test_OOJSSound.cpp`). They are byte-identical to upstream's
  (`docs/parity/c-and-tables.md`).
- **Ten are enums with names.** `OOBehaviour`, `OOCompassMode`, `OOEntityStatus`,
  `OOGalacticHyperspaceBehaviour`, `OOGUIScreenID`, `OOLegalStatusReason`, `OOLongRangeChartMode`,
  `OOScanClass`, `OOShipDamageType`, `OOViewID`: 152 rows in all. Each table is expanded into an enum
  body, a value-to-name `switch`, a name-to-value `if` chain, and a script-engine name table, and
  the last of these is a separate list the compiler never checks against the others.
- **The value column is fiction in three of them.** `ENTRY(label, value)` has two expansions in the
  tree, one that honours the value and one that drops it. `OOViewID`, `OOLongRangeChartMode` and
  `OOGUIScreenID` use the second, so their real values are ordinals (`VIEW_CUSTOM` is 4, not the 7
  written; all 29 `GUI_SCREEN_*` rows say −1 and are 0…28). `OOLongRangeChartMode`'s ordinal is
  written to saved games as `chart_colour_mode`. Nothing in the files says so
  (`notes/2026-11-07 Enum Tables from tbl X-Macros.md`, *The numeric trap*).
- **The eleventh is not an enum.** `OOOpenGLStates.tbl` lists the fixed-function OpenGL state items
  the state manager tracks (`ITEM_STATEFLAG(LIGHTING)`, `ITEM_INT(SHADE_MODEL)`, …) and is expanded
  five times in `OOOpenGLStateManager.cpp` to declare the state record and to read, compare, log and
  write it, by pasting the item name into `GL_##NAME`, `GetState_##NAME` and `SetState_##NAME`.
- **The design for the ten already exists.** Jon's note of 2026-11-07 (above) works out the header
  shape, the value decision per table, the compatibility constraints and the staging, and spec 009
  (modern C++) adopts it as US5 P8, tasks T060–T063, not yet started. Spec 009's enum-table helper
  (`src/Core/OOEnumTable.h`, T046, commit `310cd4480`) is written but is not yet on `develop`.
  This feature is that P8 work as a feature of its own, plus the eleventh table, which the note and
  spec 009 keep.

## User Scenarios & Testing *(mandatory)*

The users of this feature are the people who read and change the game's source: Oolite
maintainers reviewing the fork, and agents working on it. Players, expansion authors and saved
games are the people it must not affect.

### User Story 1 - Each named enum is one readable header (Priority: P1)

A developer who wants to know what `OOScanClass` is opens one header and finds, in ordinary C++,
every member, its number, the name scripts and property lists use for it, and the value an unknown
name falls back to. No `.tbl` file, and no macro defined somewhere else, takes part. Adding a member
without a name is reported by the build.

**Why this priority**: These ten tables are 152 of the 11 files' rows and 35 of their 40 includes,
they carry the three fictional value columns, and one of those columns is save-game-visible. They
are what the request calls "gross enums".

**Independent Test**: Before: ten enum `.tbl` files exist. After: none do; the unit, component
and smoke suites pass; the script API snapshot is unchanged; a game saved on `develop` loads on the
branch with every setting intact, the long-range chart colour mode included.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** `src/Core/Tables` is listed, **Then** none of the ten enum
   tables is there, and each of the ten types is defined, named and given its default in a single
   header.
2. **Given** a name that scripts, property lists or saved games use today (for example
   `CLASS_NEUTRAL`, `STATUS_IN_FLIGHT`, `BEHAVIOUR_ALL_SYSTEMS_REACHABLE`, `"attacked police"`),
   **When** it is converted to its value and back, **Then** the result is the same name and number
   as on `develop`; an unknown name gives the same default as on `develop`.
3. **Given** `OOViewID`, `OOLongRangeChartMode` and `OOGUIScreenID`, **When** their values are read
   on the branch, **Then** they are the ordinals the program uses today, not the numbers the `.tbl`
   files wrote, and the header states each number so that a change to it fails the build.
4. **Given** a game saved on `develop` with a non-default long-range chart colour mode, **When** it
   is loaded on the branch, **Then** the chart shows the same mode.
5. **Given** a member added to one of the ten enums with no name, **When** the game is built,
   **Then** the build reports it.

---

### User Story 2 - Call sites keep working while the names change later (Priority: P2)

A developer converting one enum does not have to touch the roughly 1,900 places that name its
members. The old spellings (`STATUS_IN_FLIGHT`, `GUI_SCREEN_MAIN`, …) keep compiling, marked in each
header as temporary, so each conversion is a reviewable change to one header and its few consumers,
and the later rename to `kPascalCase` is its own mechanical step.

**Why this priority**: Without it, Story 1 is one change of several thousand lines across about
200 files, which nobody can review against upstream.

**Independent Test**: For one converted enum, the change touches only its header, the files that
used to include its `.tbl`, and the files that defined that enum; a search of the rest of `src`
finds no other edited line.

**Acceptance Scenarios**:

1. **Given** one enum converted, **When** the diff is listed, **Then** no call site outside the
   table's former consumers is edited.
2. **Given** the converted tree, **When** a header's compatibility block is read, **Then** it says
   that the old names are temporary and which later step removes them.

---

### User Story 3 - The OpenGL state list is plain code (Priority: P3)

A developer who needs to add, remove or inspect a tracked OpenGL state item finds the list of items
written once, in ordinary C++, with each item's kind (on/off flag, client-array flag, integer,
special) and how it is read and set, and with no file that means different things at each of five
includes.

**Why this priority**: It is one file, it is not an enum, and the fixed-function OpenGL it describes
is due to be replaced (Phase 6, OpenGL 3.3 Core), which may delete the state manager outright. It
is worth doing now only because it is the last `.tbl` file; it is independent of Stories 1 and 2
and can be dropped without affecting them.

**Independent Test**: Before: `OOOpenGLStates.tbl` exists and the state manager includes it five
times. After: no `.tbl` file exists anywhere in the source tree; the OpenGL state manager's
characterisation test passes without edits; in a debug build, the state verifier's log output for a
deliberately mismatched state names the same items as on `develop`.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** the source tree is searched for `.tbl` files, **Then**
   there are none.
2. **Given** each of the standard OpenGL states, **When** it is set from any other standard state,
   **Then** every tracked item reads back as on `develop` (the existing characterisation test, run
   unchanged).
3. **Given** a debug build and a state mismatch, **When** the verifier reports it, **Then** the
   report lists the same item names in the same order as on `develop`.
4. **Given** a new state item to track, **When** a developer adds it, **Then** the item is written
   in one place, and forgetting to say how it is read or set fails the build.

---

### Edge Cases

- **Fictional value columns.** For `OOViewID`, `OOLongRangeChartMode` and `OOGUIScreenID` the
  program's ordinals win everywhere; the numbers in the `.tbl` files are not carried over.
- **Values that are not just names.** `OOCompassMode` numbers reach shaders; status, behaviour,
  compass mode and galactic hyperspace behaviour reach scripts as raw numbers through `callObjC`;
  code steps the chart mode with `+ 1` and range-checks the galactic hyperspace behaviour against
  its maximum. All keep their numbers and their order.
- **Storage width.** The type-encoding strings record these types as 32-bit integers and a frozen
  layout encoding has 32-bit slots for them, so each keeps a 32-bit underlying type even though the
  values would fit in less.
- **Names that are prose.** `OOLegalStatusReason` and `OOShipDamageType` map members to phrases
  (`"attacked police"`, `"scrape damage"`) that scripts and the bounty log see; they keep them
  exactly.
- **Prefix pasting.** `OOGalacticHyperspaceBehaviour`'s names are `BEHAVIOUR_*` while its members are
  `GALACTIC_HYPERSPACE_BEHAVIOUR_*`; both survive, and the American `BEHAVIOR_` spelling is still
  accepted on input.
- **One-way tables.** Three enums (`OOBehaviour`, `OOShipDamageType`, `OOLegalStatusReason`) have no
  name-to-value lookup today; none is added.
- **Different fallbacks.** An unnamed behaviour reads as `** BEHAVIOUR UNKNOWN **`; every other
  unnamed value reads as `UNDEFINED`. Each keeps its own.
- **Commented-out rows.** `GUI_SCREEN_CONTRACTS` and `kOOLegalStatusReasonThereCanBeOnlyOne` are
  commented out today and stay commented out, with no value and no name.
- **A table nobody reads.** `OOLongRangeChartMode` has a script-engine name table that is built but
  never looked up; it is carried across as it is, with a comment.
- **A test that includes a table.** `test_OOJSSound.cpp` rebuilds `OOEntityStatus` from its `.tbl`
  file; that include is the only test line the feature may change (FR-012).
- **Engine resets.** The script engine's interned names survive an engine reset today; they still
  do.
- **The OpenGL "maybe" state.** Some on/off items may be left open (`kStateMaybe`) in a standard
  state and are then neither compared nor set; client-array flags cannot be left open. Both rules
  hold after the change.
- **The blend function.** It is two values set by one call and is handled outside the list today;
  it stays outside the list, read, compared, logged and set exactly as now.

## Requirements *(mandatory)*

### Functional Requirements

**The ten named enums (Story 1, Story 2)**

- **FR-001**: Each of the ten enum tables MUST be replaced by one header in `src/Core/Tables` named
  after its type (`OOScanClass.tbl` → `OOScanClass.h`) that declares the enum, its default value,
  its names and its name table, in the shape spec 009's enum contract
  (`specs/009-modern-cpp-std/contracts/enums.md`, *The shape of a converted enum header*) gives; the
  `.tbl` file MUST be deleted.
- **FR-002**: Every enum MUST be a scoped enum with an explicit 32-bit signed underlying type and a
  comment saying why it is 32-bit.
- **FR-003**: Every member's value MUST be the value the program uses on `develop`, read from the
  code rather than from the `.tbl` column, and every value that leaves the program (saved games,
  scripts, shaders, the debug console) MUST be pinned in the header so that changing it fails the
  build. The rows of `specs/009-modern-cpp-std/external-values.md` for these ten types are the list.
- **FR-004**: Every name MUST be written out as text in the header, never derived from the
  identifier, and MUST equal today's name byte for byte, the prose names of `OOLegalStatusReason`
  and `OOShipDamageType` included.
- **FR-005**: Each enum's value-to-name mapping MUST be a single exhaustive mapping that the
  compiler checks against the enum, and its name table MUST be derived from that mapping, so that a
  member without a name fails the build and there is no second list to drift.
- **FR-006**: The fifteen conversion functions in `OOConstToString.cpp` (nine value-to-name, six
  name-to-value) MUST keep their signatures, their fallbacks and their behaviour, including
  `** BEHAVIOUR UNKNOWN **` for behaviours and the `BEHAVIOR_` spelling accepted for galactic
  hyperspace behaviours; no new lookup direction is added.
- **FR-007**: The script engine's name tables (`OOConstToJSString.cpp`) MUST take their names and
  order from the new headers rather than from a list of their own, MUST give scripts the same
  strings and numbers as on `develop`, and MUST keep their behaviour across engine resets.
- **FR-008**: The enum bodies, `#define`/`#undef` scaffolding and `typedef enum` blocks in
  `OOTypes.h`, `OOEntityEnums.h` and `ShipEntity.h` MUST be replaced by includes of the new headers;
  `OOEntityEnums.h` MAY survive as a short umbrella for the files that include it.
- **FR-009**: Each new header MUST keep today's member names usable as temporary aliases, in a block
  marked as temporary that names the later step that removes them, so that no call site outside the
  table's former consumers is edited. Renaming the call sites to `kPascalCase` is out of scope
  (spec 009, naming milestone).
- **FR-010**: Each new header MUST be clean under the project's naming check for scoped
  enumerators (`kPascalCase`), enforced for `src/Core/Tables` from the first converted header.

**The OpenGL state list (Story 3)**

- **FR-011**: `OOOpenGLStates.tbl` MUST be replaced by ordinary C++ in or beside
  `OOOpenGLStateManager.cpp` that names each tracked state item once, with its kind and how it is
  read and set, and from which the state record, the read, the comparison, the log output and the
  write all follow; the `.tbl` file MUST be deleted. The items, their kinds, their order, the
  standard states' values, the "maybe" rule and the separate blend-function handling MUST be as on
  `develop`.

**Both**

- **FR-012**: No test MAY be modified except `tests/unit/core/test_OOJSSound.cpp`'s
  `OOEntityStatus` stand-in, which MUST take the enum from the new header instead of rebuilding it
  from the `.tbl` file, keeping every assertion; that edit MUST be listed in a test-change ledger in
  this spec's directory with the same columns as `specs/009-modern-cpp-std/test-ledger.md`. Tests
  MAY be added. Comments in tests that mention a `.tbl` file are not changed.
- **FR-013**: The build MUST produce no new warnings on Clang or GCC, and no warning MAY be silenced.
- **FR-014**: The change MUST NOT touch `Resources/`, expansion-visible data, or any file under
  `src/Core/MiniZip` or `src/SDL/EXRSnapshotSupport`.
- **FR-015**: `docs/parity/c-and-tables.md` and `docs/current-state.md` MUST describe the tables as
  they are after the change (no `.tbl` files; the headers that replace them).
- **FR-016**: Each table MUST be convertible and landable on its own (one table, or a small group
  sharing consumers, per change), with the full unit suite passing after each.

### Key Entities

- **Named enum**: one of the ten constant sets; has members, a 32-bit value per member, an external
  name per member (identifier-like or prose), a default for unknown names, and zero or more
  external uses of its numbers (saved games, scripts, shaders).
- **Name table**: the ordered list of a named enum's (value, name) pairs, derived from its mapping,
  used by the conversion functions and the script engine.
- **Compatibility alias**: a temporary second name for a member, spelled as today, kept until the
  call-site rename.
- **OpenGL state item**: one tracked piece of fixed-function OpenGL state; has a name, a kind
  (on/off flag, client-array flag, integer, special with its own read, write and description), and
  a value in each standard state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The source tree has no `.tbl` files (11 today) and no `#include` of one (40 today).
- **SC-002**: For each of the ten enums, a reader answers "what members, numbers and names does this
  type have, and what does an unknown name become" from one file; today that takes the `.tbl` file
  plus two to four including files.
- **SC-003**: Every external name and number is unchanged: the script API snapshot is identical to
  `develop`'s; every row of spec 009's external-values list for these ten types is pinned; a game
  saved on `develop` loads with every setting identical, the chart colour mode included.
- **SC-004**: A member added to any of the ten enums without a name, or an OpenGL state item added
  without a way to read or set it, is reported by the build in every case tried (at least one trial
  per kind, recorded in the plan's notes).
- **SC-005**: The unit, component and smoke suites pass on the branch as on `develop`, the OpenGL
  state manager's characterisation test among them without edits, and the expansion corpus result
  does not regress.
- **SC-006**: Exactly one test file is edited, and the ledger lists it.
- **SC-007**: Each conversion change touches only its table's header, its former consumers and its
  former enum definitions (Story 2), so that no single change exceeds about 400 changed lines.

## Assumptions

- The design for the ten enums is the one in `notes/2026-11-07 Enum Tables from tbl X-Macros.md` and
  spec 009's enum contract; this spec states what must hold, and the plan follows that design rather
  than drawing a new one.
- Spec 009's enum-table helper (`src/Core/OOEnumTable.h`, T046) is reused, not rewritten. It is on
  `origin/feature/json5-data-files` (commit `310cd4480`) and not yet on `develop`; the plan picks the
  base for `feature/replace-tbl-tables` accordingly.
- The program's behaviour on `develop` is the reference, not upstream's text: where the `.tbl`
  value columns disagree with the program, the program wins (it matches upstream's behaviour,
  since the dropped-value expansion is upstream's own, 2011).
- The known scanner-grid omission of `VIEW_CUSTOM` (`HeadUpDisplay.cpp`) is left as it is, as spec
  009 T062 decides; fixing it is separate work.
- The stale `tools/gen-*.py` references in generated-file banners are out of scope.
- Rule 1's third exception covers the `test_OOJSSound.cpp` include, as spec 009's T063 classifies
  it (*covered*); if Jon rules otherwise, that row becomes *reported* and Story 1 stops before
  `OOEntityStatus`.
- This work lands on `develop` only. It is not added to the upstream PR series (`series/*`,
  `seriesb/*`), whose tables stay byte-identical to upstream's.

## Notes and decisions

Decisions taken without Jon, each with its default and reason (hard rule 8):

1. **This spec takes over spec 009's US5 P8 (T060–T063).** Default: deliver the ten tables here, as
   a small feature that can land before spec 009's late enum milestone, using the same design and
   the same acceptance commands, so that whichever lands first leaves 009's tasks passing. Reason:
   the request is specifically the `.tbl` files, and 009's P8 is blocked behind its P1–P7 for no
   technical reason. Spec 009's files are not edited; its T060–T063 will find their checks already
   pass. If Jon prefers to keep P8 inside 009, Stories 1 and 2 move back and this spec keeps only
   Story 3.
2. **`OOOpenGLStates.tbl` is in scope (Story 3), at the lowest priority.** This reverses the
   2026-11-07 decision to keep it, because today's request names all `.tbl` files. It is
   independent: if Jon re-affirms keeping it until the OpenGL 3.3 Core work, drop Story 3 and
   FR-011 and change SC-001 to "one `.tbl` file".
3. **No call-site rename.** The old names stay as marked temporary aliases (FR-009); the
   `kPascalCase` sweep stays in spec 009, which owns the naming rule and its test-ledger questions.
4. **Ledger.** This feature keeps its own `test-ledger.md` (one row expected) rather than writing
   into spec 009's.
