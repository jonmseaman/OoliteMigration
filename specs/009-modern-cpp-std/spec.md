# Feature Specification: Modern C++ on the standard library

**Feature Branch**: `seriesb/027-modern-cpp` (in `oolite-dev`); spec directory `009-modern-cpp-std`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "I want to use modern c++. I already have some notes on it in this
repo. Some things to improve: Use new/delete/std::unique_ptr/std::shared_ptr/std::weak_ptr instead
of oo:WeakRef, malloc, calloc. Use std::thread instead of oo::Thread. Replacing other oofnd
libraries with c++ std libraries directly. Using enum class instead of typedef enum, enum, or list
of macros"

## Purpose

The game is C++ now, but much of it still reads as C plus Objective-C: memory from `malloc`, object
lifetimes through an Objective-C-style retain/release library, threads through an `NSThread`
stand-in, and constants as unscoped C enums or lists of macros. This feature moves that code onto
the C++ standard library and its idioms directly, so that a C++ developer reading the game meets
the types they already know, and so that the compiler and the project's static checks can catch
mistakes the old forms hide. Nothing a player, an expansion author or a saved game can observe
changes.

## Context

What the tree is today (counts from `oolite-dev/src`, first-party code, 2026-11-11; regex counts,
±10%):

- **Ownership.** `oofnd/Ref.hpp` (578 lines) implements Objective-C retain/release:
  `oo::RefCounted`, `oo::Ref<T>` (about 1,560 lines in 261 files), `oo::WeakRef<T>` (107 lines,
  37 files), `oo::AutoreleaseScope` (about 160 lines, 51 files) and `leakRef`/`adopt` for handing
  ownership across C interfaces (about 100 lines). `oofnd/WeakSet.hpp` adds `oo::WeakSet<T>`.
  Entities are owned through `oo::EntityHold` (about 400 lines, 54 files), whose last release runs
  the entity's `willDispose()`. The standard smart pointers are almost unused: 12 lines of
  `std::unique_ptr`, 4 of `std::shared_ptr`.
- **C allocation.** About 50 `malloc`, 6 `calloc`, 10 `realloc` and 73 `free` lines in about 45
  files (textures, meshes, octrees, collision regions, sound, JavaScript bindings, the OpenGL
  view). One comment admits a leak when `realloc` fails.
- **Threads.** `oofnd/Thread.hpp` already sits on `std::thread`; game code calls
  `oo::thread::detach`, `isMainThread`, `setCurrentName` and `setCurrentPriority` (12 lines,
  5 files). Mutexes are already `std::mutex`.
- **Other `oofnd` stand-ins with a standard equivalent.** `oo::Expected` (a 1,262-line polyfill of
  C++23 `std::expected`, 52 lines of use), `oo::Data` (`NSData`, 175 lines of use), `oo::date`
  (`NSDate` over `std::chrono`), the `NSInteger`/`NSUInteger`/`NSRange`/`NSNotFound`/
  `NSTimeInterval`/`CGFloat` aliases (about 1,150 lines), the `StdLib.hpp` umbrella that game code
  includes instead of standard headers, printf-style `oo::str::format` beside `std::format`, string
  helpers named after `NSString` methods, and `oo::Exception`, which is deliberately not a
  `std::exception`.
- **`oofnd` parts with no standard equivalent.** The property-list family (values, both parsers,
  both writers, descriptions), `Encoding`, `Scanner`/`CharacterSet` (GNUstep's character tables),
  the GNUstep-exact parts of `String` (case tables, composed sequences, runtime `%@` formatting),
  `Log`/`LogFile`, `Http`, `Defaults`, `ResourcePaths`, `Process` (captured arguments, the OS
  version string), `Notification`, `Finally`, `OOAssert`, and thread naming and priority. Many of
  these reproduce GNUstep 1.31.1's answers byte for byte, and tests pin those answers.
- **Enums and macro lists.** 51 `typedef enum` and about 120 other unscoped `enum` definitions in
  about 90 files, against 19 `enum class`. Many constant sets are lists of `#define`s. Ten of the
  eleven `.tbl` X-macro tables in `src/Core/Tables` define an enum and its name table; the eleventh,
  `OOOpenGLStates.tbl`, generates struct fields and code. The names of many of these constants are
  visible outside the program: scripts compare them as strings (`"CLASS_NEUTRAL"`,
  `"STATUS_IN_FLIGHT"`), ship data and other property lists spell them, and the log prints them.
  Some numeric values are written into saved games: `OOLongRangeChartMode`'s ordinal is saved as
  `chart_colour_mode`, and its `.tbl` value column is not the value the program uses
  (`notes/2026-11-07 Enum Tables from tbl X-Macros.md`).
- **Tests.** 205 test files use the `oofnd` types this feature replaces, about 2,000 lines on
  `oo::Ref` and friends alone. `tests/unit/oofnd` has a test per component, including `test_ref`,
  `test_weakset`, `test_thread`, `test_expected`, `test_data` and `test_date`.
- **Build.** The game and `oofnd` build as C++20 (`src/meson.build`, `src/oofnd/meson.build`).
  `std::expected` and some other replacements need C++23. The tree builds on Windows x64 (Clang and
  GCC) and macOS; Linux builds in CI.
- **Earlier decisions this spec builds on.** Jon's decisions of 2026-10-28
  (`notes/2026-10-28 Modern C++ Idiom Review.md`): no `malloc`/`calloc`/`realloc`/`free`; use the
  standard library wherever possible; Google-style `kPascalCase` enumerators; class design stays
  close to upstream (§2.1 is out). His decisions of 2026-11-07 (the `.tbl` note): convert ten
  tables to `enum class`, keep `OOOpenGLStates.tbl`, and reword hard rule 1 rather than work around
  it. This spec changes one 2026-10-28 decision: `oo::Ref` was to be re-implemented over
  `std::shared_ptr` under the same names; the request now is to use the standard types directly.

## User Scenarios & Testing *(mandatory)*

The users are Jon and the agents working through Spec Kit tasks (who read, change and review the
code), upstream Oolite maintainers (who decide whether to take the port and judge it by how it
reads), and players and expansion authors, for whom nothing may change.

### User Story 1 - Memory comes from C++ containers and smart pointers, not C allocation (Priority: P1)

A developer reading any first-party C++ file finds buffers held in standard containers or smart
pointers, never obtained with `malloc`, `calloc` or `realloc` and released with `free`. Where an
object really must be created with `new`, a smart pointer owns it at once. The only C allocation
left is where a C library's contract requires it (memory the library itself frees, or that it hands
back to be freed), and each such place is on a short written list with its reason.

**Why this priority**: It is the most self-contained part of the request, it removes a class of
leak and overflow bugs (including the known `realloc` leak), and it needs few or no test changes,
so it can land first.

**Independent Test**: Before: a search of first-party C++ for C allocation calls finds about 140
lines. After: it finds only the lines on the exceptions list, the static checks flag any new one,
and every test tier passes with the same results as before.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** first-party C++ is searched for `malloc`, `calloc`,
   `realloc` and `free`, **Then** every hit is on the exceptions list, and the list gives the C
   interface that requires it.
2. **Given** a change that adds a C allocation call to first-party C++ outside the list, **When**
   the static checks run, **Then** they fail and name the file and line.
3. **Given** the converted tree, **When** the unit suites run under the address sanitizer, **Then**
   they report no error that the base commit does not also report, and leak checks (where the
   platform has them) report no new leak.
4. **Given** code that grew a buffer with `realloc`, **When** growth fails for lack of memory,
   **Then** nothing already held is leaked.

---

### User Story 2 - Object lifetimes use the standard smart pointers (Priority: P2)

A developer sees shared ownership expressed as `std::shared_ptr`, non-owning observation as
`std::weak_ptr`, and exclusive ownership as `std::unique_ptr` or a plain member. The Objective-C
lifetime machinery is gone: no reference-counted base class, no `oo::Ref`/`oo::WeakRef`/
`oo::WeakSet`, no autorelease scopes and no manual `leakRef`/`adopt`. An entity is still disposed
of at the same moment as before, and objects handed to the script engine still live exactly as
long as they did.

**Why this priority**: It is the largest and most visible change, touching about 260 files, and it
is what the request names first. It comes after Story 1 because it needs test edits (see FR-015)
and carries the most behavioural risk: destruction order drives script events and disposal.

**Independent Test**: Before: `oofnd/Ref.hpp` and `oofnd/WeakSet.hpp` exist and about 1,900 lines
use them. After: both headers are gone, no first-party code names their types, every test tier
passes with the same results, the expansion corpus and script API snapshot do not regress, and a
scripted session that kills, docks and jumps away from ships produces the same sequence of script
events and log lines as the base.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** first-party code is searched for `RefCounted`, `oo::Ref`,
   `oo::WeakRef`, `oo::WeakSet`, `AutoreleaseScope`, `leakRef` and `adopt`, **Then** nothing is
   found, and the headers that defined them are deleted.
2. **Given** an entity whose last owner lets go of it, **When** that happens, **Then** its
   disposal hook runs once, at the same point relative to other game events as on the base, and
   any non-owning reference to it reads as empty before its destructor runs.
3. **Given** a script object that refers to a native object, **When** the script engine collects
   the script object, **Then** the native object is released then and not before, as on the base.
4. **Given** an object that used to be returned autoreleased, **When** its caller keeps the
   result, **Then** the object stays alive for as long as the caller holds it, with no pool.
5. **Given** a session on the base and on the branch with the same seed and inputs, **When** the
   component scenarios and the smoke tier run, **Then** they pass and the logged script events
   appear in the same order.

---

### User Story 3 - Threads are standard threads (Priority: P3)

A developer finds background work started with the standard thread types, joined or stopped by
whoever owns it, and the main thread identified with the standard thread identifier. Only what the
standard library cannot do (naming a thread for debuggers, setting its priority) remains as two
small helpers.

**Why this priority**: The change is small (about 12 lines in 5 files) and contained, but it
touches shutdown and the asynchronous work manager, so it must be shown not to hang or race.

**Independent Test**: Before: game code calls `oo::thread::detach` and `oo::thread::isMainThread`.
After: neither exists, background threads have owners, every test tier passes, and quitting the
game during a download or while textures load in the background takes no longer than on the base.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** it is searched for `oo::thread::detach` and
   `oo::thread::isMainThread`, **Then** nothing is found.
2. **Given** a background task in progress (an expansion download, background texture or planet
   generation), **When** the player quits, **Then** the game exits within the time it does on the
   base, with no crash and no hang.
3. **Given** the converted tree, **When** the unit suites run under the thread sanitizer where the
   platform has one, **Then** it reports no race that the base does not also report.
4. **Given** a named background thread, **When** a debugger lists threads, **Then** it shows the
   same name as on the base.

---

### User Story 4 - `oofnd` keeps only what the standard library lacks (Priority: P4)

A developer uses `std::expected`, `std::vector<std::byte>` and `std::span`, `std::chrono`,
`std::filesystem`, `std::format`, the standard integer types and the standard headers directly. An
`oofnd` component survives only where the standard library has no equivalent or gives different
answers from the ones the game depends on, and each survivor says so in one line.

**Why this priority**: It is the broadest "use std directly" item, but each component is
independent, so it can be done piece by piece once the C++23 switch is in.

**Independent Test**: Before: `Expected.hpp`, `Data.hpp`, `Date.hpp`, `StdLib.hpp` and
`PrintfFormat.h` exist and game code includes them. After: they are deleted or reduced to the
documented remainder, no first-party code uses the replaced names, `oofnd`'s README lists each
remaining component with its reason, and every test tier passes with the same results.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** it is searched for `oo::Expected`, `oo::Unexpected`,
   `oo::Data`, `NSInteger`, `NSUInteger`, `NSRange`, `NSNotFound`, `NSTimeInterval`, `CGFloat` and
   `#include "oofnd/StdLib.hpp"`, **Then** nothing is found.
2. **Given** an `oofnd` helper whose standard equivalent gives the same answer for every input the
   tests and the game use, **When** the feature is done, **Then** callers use the standard
   facility and the helper is gone.
3. **Given** an `oofnd` helper whose standard equivalent gives a different answer for some input
   the game depends on (for example GNUstep's case mapping or whitespace set), **When** the feature
   is done, **Then** the helper stays, its README line names the difference, and a test pins it.
4. **Given** `oo::Exception`, **When** game code catches standard exceptions, **Then** it also
   catches the game's own, and the message text is unchanged.

---

### User Story 5 - Constants are scoped enums (Priority: P5)

A developer finds each related set of constants declared once as an `enum class` with an explicit
underlying type and `kPascalCase` enumerators, bit flags combined with type-safe operators, and the
name of each value (where the game needs one) beside the enum in an ordinary header rather than in
an X-macro table that means different things wherever it is included. Every name and number that
leaves the program (in scripts, property lists, saved games, the debug console and the log) is
exactly what it was.

**Why this priority**: It is the highest-volume change (about 170 enums and the macro lists) and
diverges most from upstream's spelling, so it goes last, after the ownership and library work has
settled.

**Independent Test**: Before: first-party C++ has about 170 unscoped enum definitions and ten
`.tbl` enum tables. After: it has none outside the exceptions list; `OOOpenGLStates.tbl` is the
only `.tbl` file; the static checks fail on a new unscoped enum or a non-`kPascalCase` enumerator;
a game saved on the base loads on the branch with every setting intact (the long-range chart
colour mode included); and the script API snapshot and expansion corpus do not regress.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** first-party C++ is searched for `typedef enum` and
   unscoped `enum` definitions, **Then** every hit is on the exceptions list (C headers shared with
   C sources, constants a C interface requires, values tested by the preprocessor).
2. **Given** a script or property list that names a constant (`"CLASS_NEUTRAL"`,
   `"STATUS_IN_FLIGHT"`, `"VIEW_FORWARD"`), **When** the game reads it, **Then** it maps to the
   same value as on the base, and when the game writes or reports that value, the text is the same.
3. **Given** a saved game written by the base, **When** the branch loads it and saves it again
   without play, **Then** every enum-valued entry is the same in both files.
4. **Given** an unrecognised constant name in data, **When** the game reads it, **Then** it falls
   back to the same default and logs the same message as on the base.
5. **Given** a set of bit flags, **When** code combines, tests or clears flags, **Then** it does so
   with the enum's own operators, and mixing flags of two different sets does not compile.

### Edge Cases

- **Objects that hand themselves to an owner.** Code that today makes an owning reference from
  `this` (possible with intrusive counting, not with standard shared ownership) must get its owner
  another way; it cannot do this during construction.
- **Stack and member instances.** Some reference-counted classes are also created on the stack or
  as members (tests do this). Converting must not force them onto the heap where the base did not.
- **Reference cycles.** A cycle that the base broke by an explicit release, an autorelease or
  disposal must still be broken; the leak check is the judge.
- **Ownership across C interfaces.** Native objects stored in script-engine objects and in C
  library callbacks pass through `void*`. Each such crossing keeps the object alive exactly as long
  as it does now and has one documented owner.
- **Shared-ownership cost.** Standard shared ownership counts atomically and may allocate a control
  block; entity-heavy scenes must not become measurably slower (SC-008).
- **Joining at shutdown.** An owned thread is joined when its owner goes away; a worker blocked in
  a network call must not stall quit longer than now.
- **Values that are not just ordinals.** Enums whose values are used as array indices, iterated
  with `++`, compared with `<`, terminated by a `_COUNT`/`_END` sentinel, stored in a narrower
  integer, or written as numbers to saves or the debug console must keep those values.
- **The `.tbl` value columns.** Three tables' written values are not the values the program uses;
  the program's values win wherever they are observable (`notes/2026-11-07 Enum Tables from tbl
  X-Macros.md`).
- **Macros the preprocessor tests.** A constant tested by `#if` cannot become an enumerator and
  stays a macro.
- **Platforms not built here.** Linux-only and Windows-only code must still compile on its
  platform; CI is the judge for the platforms the session cannot build.

## Requirements *(mandatory)*

### Functional Requirements

**Behaviour**

- **FR-001**: Every change MUST leave observable behaviour unchanged: game play, script-visible
  names and values, property-list and saved-game contents, log text, debug-console output and
  expansion compatibility. The test tiers, the sanitizers, the script API snapshot and the
  expansion corpus decide; a difference from the base commit is a defect unless it fixes a recorded
  bug, and then it is listed with that bug.
- **FR-002**: Every test tier MUST pass at the end of each user story with the same results as the
  base commit on every toolchain CI builds, apart from failures the base also has (today
  `test_http` and `test_OOOXZManager` on Windows), which MUST not grow.
- **FR-003**: No change MAY silence a warning, add a static-check suppression, modify vendored code,
  or rewrite a plain-C source file (hard rules 2 and 7).

**Memory (Story 1)**

- **FR-004**: First-party C++ MUST NOT call `malloc`, `calloc`, `realloc` or `free`, except where a
  C library's contract requires that allocator; each exception MUST be on the exceptions list with
  the interface that requires it.
- **FR-005**: An object created with `new` MUST be owned by a smart pointer or a container
  immediately, except where ownership passes to a C interface through `void*`; each such crossing
  MUST be on the exceptions list with its owner and release point. Leaked singletons MUST get an
  owner or be function-local statics.

**Ownership (Story 2)**

- **FR-006**: Shared ownership MUST be `std::shared_ptr`, non-owning references that must detect
  expiry MUST be `std::weak_ptr`, and exclusive ownership MUST be `std::unique_ptr` or a value
  member. `oo::RefCounted`, `oo::Ref`, `oo::WeakRef`, `oo::WeakSet`, `oo::AutoreleaseScope`,
  `leakRef` and `adopt` MUST be removed, with the headers that define them.
- **FR-007**: An entity's disposal hook MUST run exactly once, when its last owner releases it, and
  before then every non-owning reference to it MUST still resolve; once disposal starts, none may.
- **FR-008**: Objects referred to by script-engine objects MUST be released when the engine
  finalises those objects, as on the base.
- **FR-009**: Exclusive ownership MUST NOT be widened to shared ownership just to fit the new
  types; where the base had one owner, the converted code has `std::unique_ptr` or a value.

**Threads (Story 3)**

- **FR-010**: Threads MUST be the standard thread types, each owned by an object that joins or
  stops it; the main thread MUST be identified by its standard thread identifier.
  `oo::thread::detach` and `oo::thread::isMainThread` MUST be removed.
- **FR-011**: Naming a thread and setting its priority MAY remain as helpers because the standard
  library cannot do either; they MUST keep their current platform behaviour.

**`oofnd` (Story 4)**

- **FR-012**: The build MUST move to C++23 on every toolchain CI builds, as a prerequisite of the
  replacements that need it. If a toolchain lacks a needed facility, the `oofnd` piece it would
  replace stays, and the gap is recorded.
- **FR-013**: Where the standard library gives the same answer as an `oofnd` component for every
  input the game and tests use, callers MUST use the standard facility directly and the component
  MUST be removed. This covers at least `Expected` (to `std::expected`), `Data` (to a byte vector
  and spans), the date helpers (to `std::chrono`, keeping any text format the standard cannot
  produce), the Foundation integer and range aliases (to standard types and an optional index),
  the `StdLib.hpp` umbrella (to direct standard includes), printf-style formatting of literal
  formats (to `std::format`), and the string and file helpers whose standard counterparts agree.
- **FR-014**: An `oofnd` component or helper that stays MUST be listed in `oofnd`'s README with the
  reason (no standard equivalent, or a named difference in answers), and a test MUST pin each named
  difference. The game's own exception type MUST derive from the standard exception hierarchy.

**Tests**

- **FR-015**: Test edits MUST be limited to changes forced by a replaced type, function or
  enumerator name, header or construction form, with every assertion's meaning unchanged; each
  edited test MUST be listed in a test-change ledger in this spec's directory with the reason.
  Hard rule 1's third exception (Jon, 2026-11-11) allows exactly these edits. It does not allow
  deleting a test: a test of a removed `oofnd` component MUST be ported to the standard facility,
  keeping its assertions, and a test that cannot be ported is reported to Jon, not deleted.
- **FR-016**: Every behaviour this feature must preserve that no existing test covers (disposal
  order, release on script finalisation, shutdown with a background task, save-game enum values,
  unknown-name fallbacks) MUST get a test that passes on the base before the change it guards.

**Enums (Story 5)**

- **FR-017**: Each related set of integer constants in first-party C++ MUST be an `enum class` with
  an explicit underlying type and `kPascalCase` enumerators, except a set that a C source shares, a
  C interface requires, or the preprocessor tests; each exception MUST be on the exceptions list.
- **FR-018**: Every name and number of a constant that is visible outside the program MUST stay
  byte-identical, including the numeric values the program actually uses today where a `.tbl`
  column says otherwise.
- **FR-019**: Bit-flag sets MUST have type-safe combining operators defined once for the whole
  tree; flags of different sets MUST NOT combine without an explicit conversion.
- **FR-020**: The ten enum `.tbl` tables MUST become ordinary headers with the enum, its default
  and its name table, and their `.tbl` files MUST be deleted; `OOOpenGLStates.tbl` stays.

**Guards and records**

- **FR-021**: Each converted category (C allocation, the removed `oofnd` types, unscoped enums,
  enumerator naming) MUST be guarded by a check that fails when the category comes back, run with
  the project's existing static checks, without suppressions.
- **FR-022**: The exceptions list and the test-change ledger MUST live in this spec's directory;
  each entry gives the file, the reason and, for exceptions, the interface that requires it.
- **FR-023**: The docs that disagree with this feature MUST be updated as part of it: the Phase 4p
  doc (which puts these sweeps in Phase 6), the Phase 6 doc, the idiom review's "keep the `.tbl`
  tables" and "`Ref` over `shared_ptr` with the same names" lines, and `oofnd`'s README.

### Key Entities

- **Converted category**: a pattern this feature removes (C allocation, a replaced `oofnd` type, an
  unscoped enum), with its search, its guard and its count before and after.
- **Exceptions list**: the places a converted pattern may remain, each with its file, the C
  interface or preprocessor use that requires it, and, for ownership crossings, the owner and the
  release point.
- **Test-change ledger**: every test file edited or retired, the replaced name or form that forced
  it, and confirmation that its assertions are unchanged; Jon signs it off.
- **External name or value**: a constant's spelling or number that leaves the program (scripts,
  property lists, saves, the console, the log), which the conversion must keep exactly.
- **Surviving `oofnd` component**: a component that stays, with its reason and, where its answers
  differ from the standard library, the test that pins the difference.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: First-party C++ has zero C allocation calls outside the exceptions list, down from
  about 140 lines in about 45 files.
- **SC-002**: First-party code has zero uses of the Objective-C-style ownership types, down from
  about 1,900 lines in about 260 files, and `Ref.hpp` and `WeakSet.hpp` no longer exist.
- **SC-003**: First-party C++ has zero unscoped enum definitions outside the exceptions list, down
  from about 170, and one `.tbl` file remains, down from eleven.
- **SC-004**: `oofnd` is at least 2,000 lines smaller (of its 13,300), and every component left in it has a
  one-line reason in its README.
- **SC-005**: Every test tier passes on every CI toolchain with no failure the base commit does not
  have, and the address sanitizer (and the leak and thread sanitizers where the platform has them)
  report nothing new.
- **SC-006**: A game saved on the base and loaded and re-saved on the branch without play produces
  the same entries; the script API snapshot and the expansion corpus results are unchanged.
- **SC-007**: Reintroducing any converted category in a single line fails the static checks on the
  next run, naming the file and line.
- **SC-008**: Entity-heavy scenes and game loading are no slower than the base beyond the noise
  tolerance of the project's performance measurements (spec 006), and quitting with a background
  task in flight takes no longer than on the base.
- **SC-009**: Of 20 heap allocations in first-party C++ picked at random, every one's owner can be
  read from the declaration that holds it (a smart pointer, a container or a value member) or is on
  the exceptions list.

## Assumptions

- The work lands in `oolite-dev` on `seriesb/027-modern-cpp`, which Jon created at the tip of
  `seriesb/026-migration-completion` with no commits of its own; Jon merges it.
- "First-party C++" means `oolite-dev/src/Core`, `src/SDL` and `src/oofnd`, excluding vendored code
  (`MiniZip`, `EXRSnapshotSupport`, `stb`, the QuickJS-ng subproject) and plain-C sources.
- `new`/`delete` are acceptable in the sense the request gives them: `new` is fine when a smart
  pointer owns the result at once; a bare `delete` is not needed anywhere a smart pointer owns.
- `std::thread` in the request includes `std::jthread`, its joining form.
- `oo::EntityHold` is game code, not `oofnd`. It may stay as the entity-specific holder that runs
  the disposal hook, rebuilt on `std::shared_ptr`; the plan decides whether it stays or goes.
- Upstream's spellings of enum types are kept where they are type names; only enumerators move to
  `kPascalCase`, and only inside the program.
- `NSPoint`/`NSSize`/`NSRect` have no standard equivalent and are out of scope here.
- Class design stays as it is (idiom review §2.1 stays out): no constructor rewrites, no splitting
  of `Universe`, `PlayerEntity` or `ShipEntity`, and `UNIVERSE`/`PLAYER` stay.

## Decisions and notes

Decisions taken here without Jon (hard rule 8), each the conservative option; `/speckit-clarify` or
Jon can override any of them:

1. **Placement: now, on `seriesb/027-modern-cpp`, not Phase 6.** The Phase 4p doc puts these
   sweeps after upstream has seen the faithful port; Jon's request and his creating
   `seriesb/027-modern-cpp` at the stack's tip say he wants them now. They go on that branch, after
   026, so the faithful steps before it stay comparable line for line. FR-023 updates the docs.
2. **Standard types directly, not `oo::Ref` over `shared_ptr`.** The 2026-10-28 plan kept the
   `oo::Ref` names over `std::shared_ptr`. The request names `std::shared_ptr` and `std::weak_ptr`
   instead of `oo::WeakRef`, and "std libraries directly", so the names go too.
3. **Test edits: settled (Jon, 2026-11-11).** About 205 test files name the replaced types, so
   Stories 2 to 5 cannot finish without test edits (`test_thread` alone names `oo::thread` 21
   times). Jon approved the proposed amendment, now hard rule 1's third exception in CLAUDE.md:
   "a test may be edited where a type, function, enumerator or header it names is replaced by its
   standard equivalent, keeping every assertion's meaning, and each edit is listed in the feature's
   test-change ledger." FR-015 applies it. It covers edits only, so deleting a test still needs
   Jon's sign-off. Story 1 still goes first because it needs the fewest test edits.
4. **C++23 is in scope**, as the prerequisite for `std::expected`; it was Phase 6's first step.
5. **`std::jthread` by default** for threads with an owner; detached threads only where the base
   detaches and nothing can own the thread, each on the exceptions list.
6. **`kPascalCase` enumerators**, as decided on 2026-10-28 and 2026-11-07. Externally visible
   strings come from the name tables, not the enumerator spelling, so scripts and data see no
   change.
7. **Template resolution.** `resolve-template.ps1` could not run on this Mac (no PowerShell). The
   repository has no template overrides, presets or extensions, so the resolved template is the
   core `.specify/templates/spec-template.md`, which this spec follows. A "Purpose", "Context" and
   this section are added, as in specs 006 and 008.
