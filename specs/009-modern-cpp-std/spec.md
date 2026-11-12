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
stand-in, constants as unscoped C enums or lists of macros, conversions as C-style casts, and text
as `char` pointers and buffers handled with the C string functions. This feature moves that code onto
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
  view). The `realloc` leak the idiom review found is already fixed (`272aac108`); a new one was
  found while planning (`OOALSoundDecoder.cpp:442`, a buffer per OXZ Vorbis read).
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
- **C-style casts.** About 690 lines cast to a built-in type the C way (`(int)x`, `(GLfloat)y`,
  `(NSUInteger)z`); the idiom review's compiler pass (2026-10-28) counted about 1,600
  `-Wold-style-cast` warnings including pointer casts, against about 935 `static_cast`s. Worst:
  `PlayerEntity.cpp`, `ShipEntity.cpp`, `OOOpenGLExtensionManager.cpp`, `Universe.cpp`. No check
  flags them today.
- **C strings.** 717 lines with `const char*`, 99 `char name[N]` buffers, 36 `snprintf`/`sprintf`
  calls, 22 calls to `strcmp`, `strcpy`, `strcat`, `strlen` and the like (the exception names in
  `Universe.cpp` are compared with `strcmp`), and 6 `atoi`/`strtol`-style parses. Many
  `const char*` uses are legitimate: string literals, and the C interfaces of QuickJS, SDL, OpenGL,
  OpenAL, libpng and libcurl, which need a null-terminated pointer.
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
lifetime machinery is gone: no reference-counted base class, no `oo::Ref`/`oo::WeakRef` and no
manual `leakRef`/`adopt`. The deferred-release scope and the weak set stay, rebuilt on the standard
pointers, because the game's destruction order depends on them and the standard library has
neither. An entity is still disposed of at the same moment as before, and objects handed to the
script engine still live exactly as long as they did.

**Why this priority**: It is the largest and most visible change, touching about 260 files, and it
is what the request names first. It comes after Story 1 because it needs test edits (see FR-015)
and carries the most behavioural risk: destruction order drives script events and disposal.

**Independent Test**: Before: about 1,900 lines use `oo::RefCounted`, `oo::Ref` and `oo::WeakRef`.
After: those types are gone, no first-party code names them, every test tier
passes with the same results, the expansion corpus and script API snapshot do not regress, and a
scripted session that kills, docks and jumps away from ships produces the same sequence of script
events and log lines as the base.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** first-party code is searched for `RefCounted`, `oo::Ref`,
   `oo::WeakRef`, `oo::makeRef`, `leakRef` and `adopt`, **Then** nothing is found, and the code that
   defined them is deleted.
2. **Given** an entity whose last owner lets go of it, **When** that happens, **Then** its
   disposal hook runs once, at the same point relative to other game events as on the base, and
   what it does to beacons, docks, groups and scripts has the same effect as on the base.
3. **Given** a script object that refers to a native object, **When** the script engine collects
   the script object, **Then** the native object is released then and not before, as on the base.
4. **Given** an object that used to be returned autoreleased, **When** its caller keeps the
   result, **Then** the object stays alive for as long as the caller holds it, and an object nobody
   claims is released at the same drain point as on the base.
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
3. **Given** the converted tree, **When** it runs under the thread sanitizer (the unit suites
   where the platform has one, otherwise the smoke run), **Then** it reports no race that the base does not also report.
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

**Independent Test**: Before: game code includes `Expected.hpp` and `StdLib.hpp`, `Date.hpp` has
its own calendar arithmetic, and literal formats go through printf. After: `Expected.hpp` is
deleted, no game file includes `StdLib.hpp`, the rest are reduced to the documented remainder, no first-party code uses the replaced
names, `oofnd`'s README lists each
remaining component with its reason, and every test tier passes with the same results.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** it is searched for `oo::Expected`, `oo::Unexpected`,
   `NSInteger`, `NSUInteger`, `NSNotFound`, `NSTimeInterval`, `CGFloat` and
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

### User Story 6 - Conversions are C++ casts (Priority: P6)

A developer finds every type conversion in first-party C++ written as the C++ cast that says what
it does (`static_cast`, `const_cast`, `reinterpret_cast`, or `std::bit_cast` for reinterpreting
bytes), never as a C-style cast that may silently do any of them. Every conversion computes exactly
what it does today.

**Why this priority**: It is mechanical but wide (well over 1,000 casts), and it comes after the
enums because converting enums to `enum class` rewrites the casts to and from enum types anyway.

**Independent Test**: Before: about 690 lines (more counting pointer casts) use C-style casts, and
no check flags them. After: the static checks fail on any new C-style cast in first-party C++,
the build is clean with the compiler's old-style-cast warning on, and every test tier passes with
the same results.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** the static checks run, **Then** they report no C-style
   cast in first-party C++ outside the exceptions list (casts produced inside third-party macros).
2. **Given** a change that adds a C-style cast, **When** the static checks run, **Then** they fail
   and name the file and line.
3. **Given** a C-style cast that removed `const` or reinterpreted a pointer, **When** it is
   converted, **Then** the replacement names that operation (`const_cast`, `reinterpret_cast`),
   so the conversion's meaning is unchanged and visible.
4. **Given** a fixed seed and inputs, **When** the component scenarios and the smoke run execute,
   **Then** their results are the same as on the base (float-to-integer truncation and rounding
   unchanged).

---

### User Story 7 - Text is `std::string` and `std::string_view` (Priority: P7)

A developer finds owned text held in `std::string`, borrowed text passed as `std::string_view`,
formatted with `std::format`, and compared, searched and parsed with the string types' own
operations. A `char*` remains only where a C interface needs a null-terminated pointer, and there
it comes from a `std::string` (`c_str()`) at the call, never from a `std::string_view`.

**Why this priority**: It changes function signatures across the tree, and its formatting part
reuses the method US4 settles for `oo::str::format`, so it comes after US4 and US6.

**Independent Test**: Before: 717 `const char*` lines, 99 `char` buffers, 36 `printf`-family
formatting calls and 28 C string-function and parse calls. After: the C string functions and
`printf`-family formatting are gone from first-party C++ and the static checks fail on a new one;
every remaining `const char*` and `char` buffer is a string literal's type or on the exceptions
list with the C interface it serves; the save round trip, the log-capturing tests and every test
tier pass with the same results.

**Acceptance Scenarios**:

1. **Given** the converted tree, **When** first-party C++ is searched for `strcpy`, `strncpy`,
   `strcat`, `strncat`, `strcmp`, `strncmp`, `strcasecmp`, `strlen`, `strdup`, `strchr`,
   `strrchr`, `strstr`, `strtok`, `sprintf`, `snprintf`, `vsnprintf`, `atoi` and `atof`, **Then**
   nothing is found outside the exceptions list, and the static checks fail on a new one.
2. **Given** a function that takes or returns text, **When** the feature is done, **Then** it uses
   `std::string_view` for text it only reads, `std::string` for text it keeps or returns, and
   `std::optional` of either where "no text" differs from "empty text".
3. **Given** a call into a C interface that needs a null-terminated string, **When** it is made,
   **Then** the pointer comes from a `std::string`'s `c_str()` or a string literal, never from a
   `std::string_view`'s `data()`.
4. **Given** text that is formatted for the log, a saved game, the console or the screen, **When**
   the formatting call is converted, **Then** the output bytes are identical to the base's.
5. **Given** a number parsed from text with `atoi`/`strtol`-style calls, **When** it is converted,
   **Then** it gives the same result as the base for every input the tests use, including signs,
   leading spaces, trailing junk and overflow.

---

### Edge Cases

- **Objects that hand themselves to an owner.** Code that today makes an owning reference from
  `this` (possible with intrusive counting, not with standard shared ownership) must get its owner
  another way; it cannot do this during construction.
- **Stack and member instances.** Some reference-counted classes are also created on the stack or
  as members. None exist in first-party code; tests have a few, and those become shared-owned
  through *borderline* ledger rows (research R9).
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
- **Casts inside other people's macros.** A C-style cast that comes from expanding a third-party
  macro (OpenGL, SDL, QuickJS headers) cannot be rewritten here; it is an exceptions-list entry if
  the checks report it.
- **Casts that change meaning when spelled out.** A C-style cast may fall back to
  `reinterpret_cast` or drop `const` without saying so; spelled as `static_cast` it may not compile,
  which is the point. The replacement must keep the conversion, not "fix" it.
- **Null versus empty text.** A `const char*` can be null, meaning "no text", which a
  `std::string` cannot say. Where the code tells the two apart, the replacement is a
  `std::optional`, not an empty string.
- **`std::string_view` is not null-terminated.** Passing its `data()` to a C interface reads past
  the end. Every C call takes `c_str()` of a `std::string` or a literal.
- **Fixed buffers filled by C.** A `char` buffer that a C function fills (a path from the OS, a GL
  info log) stays a buffer, as `std::array<char, N>` or a sized `std::string`, at that call only.
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
  MUST be on the exceptions list with its owner and release point. A singleton that is
  deliberately never destroyed today MUST stay so, through one shared helper that holds it in a
  smart pointer that is never released, and MUST be on the exceptions list.

**Ownership (Story 2)**

- **FR-006**: Shared ownership MUST be `std::shared_ptr`, non-owning references that must detect
  expiry MUST be `std::weak_ptr`, and exclusive ownership MUST be `std::unique_ptr` or a value
  member. `oo::RefCounted`, `oo::Ref`, `oo::WeakRef`, `oo::makeRef`, `leakRef` and `adopt` MUST be
  removed. `oo::AutoreleaseScope` (deferred release, with today's drain points and order) and
  `oo::WeakSet` MUST stay, holding standard pointers, because the standard library has no
  equivalent and destruction order depends on them.
- **FR-007**: An entity's disposal hook MUST run exactly once, when its last owner releases it, and
  its effects MUST be the same as on the base. Non-owning references to it read as empty from the
  moment disposal starts (today they go empty after the hook, before the destructor); every piece
  of code that read such a reference during disposal MUST be found, covered by a test that passes
  on the base, and rewritten so the test still passes.
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
  MUST be removed. This covers at least `Expected` (to `std::expected`), the date helpers' calendar
  arithmetic (to `std::chrono`, keeping any text format and constant the standard cannot produce),
  the Foundation integer aliases (to standard types) and `NSNotFound` (to a named constant with the
  same value), the `StdLib.hpp` umbrella (to direct standard includes), printf-style formatting of
  literal formats (to `std::format`, converted call by call so the text stays identical), and the
  file helpers whose standard counterparts agree. `oo::Data` and `NSRange` stay: the standard
  types differ in behaviour the game uses, or have no equivalent.
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
  A lone constant held in an anonymous enum is not a set: it MUST become a typed `constexpr`
  constant instead.
- **FR-018**: Every name and number of a constant that is visible outside the program MUST stay
  byte-identical, including the numeric values the program actually uses today where a `.tbl`
  column says otherwise.
- **FR-019**: Bit-flag sets MUST have type-safe combining operators defined once for the whole
  tree; flags of different sets MUST NOT combine without an explicit conversion.
- **FR-020**: The ten enum `.tbl` tables MUST become ordinary headers with the enum, its default
  and its name table, and their `.tbl` files MUST be deleted; `OOOpenGLStates.tbl` stays.

**Casts (Story 6)**

- **FR-024**: First-party C++ MUST NOT contain C-style casts, except those produced by expanding a
  third-party macro, each on the exceptions list. Each replacement MUST perform the same conversion
  (`static_cast`, `const_cast`, `reinterpret_cast`, or `std::bit_cast` for byte reinterpretation).
- **FR-025**: Once the count is zero, the compiler's old-style-cast warning MUST be on for
  first-party C++ on every toolchain, with no new warnings.

**Strings (Story 7)**

- **FR-026**: First-party C++ MUST NOT call the C string functions or the `printf` family listed
  in Story 7's first acceptance scenario, except where a C interface's contract requires one
  (each on the exceptions list). Formatting MUST keep its output byte for byte, converted call by
  call by the method US4 uses.
- **FR-027**: Text MUST be `std::string` when owned and `std::string_view` when borrowed;
  `std::optional` of either where the code distinguishes "no text" from "empty". A `const char*` or
  `char` buffer MAY remain only as a string literal's type or at a C interface that needs it, and a
  pointer passed to C MUST come from a `std::string` or a literal.
- **FR-028**: Parsing numbers from text MUST give the same results as today for every input the
  game and tests use; where `std::from_chars` differs (leading spaces, `+`, overflow, the platform
  width of `long`), the parse keeps an `oofnd` helper that reproduces today's answer.

**Guards and records**

- **FR-021**: Each converted category (C allocation, the removed `oofnd` types, unscoped enums,
  enumerator naming, C-style casts, the C string functions and `printf`-family formatting) MUST be guarded by a check that fails when the category comes back, run with
  the project's existing static checks, without suppressions.
- **FR-022**: The exceptions list and the test-change ledger MUST live in this spec's directory;
  each entry gives the file, the reason and, for exceptions, the interface that requires it.
- **FR-023**: The docs that disagree with this feature MUST be updated as part of it: the Phase 4p
  doc (which puts these sweeps in Phase 6), the Phase 6 doc, the idiom review's "keep the `.tbl`
  tables" and "`Ref` over `shared_ptr` with the same names" lines, and `oofnd`'s README.

### Key Entities

- **Converted category**: a pattern this feature removes (C allocation, a C-style cast, a C string
  function, a replaced `oofnd` type, an
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
  about 1,900 lines in about 260 files, and `oo::RefCounted`, `oo::Ref` and `oo::WeakRef` no
  longer exist.
- **SC-003**: First-party C++ has zero unscoped enum definitions outside the exceptions list, down
  from about 170, and one `.tbl` file remains, down from eleven.
- **SC-004**: `oofnd` is at least 1,500 lines smaller (of its 13,300), and every component left in it has a
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

- **SC-010**: First-party C++ has zero C-style casts outside the exceptions list (down from well
  over 1,000), and the build is warning-free with the old-style-cast warning on.
- **SC-011**: First-party C++ has zero C string-function and `printf`-family calls outside the
  exceptions list (down from about 65), and every remaining `const char*` or `char` buffer is a literal's
  type or an exceptions-list entry (down from 717 and 99 lines).

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
- `NSPoint`/`NSSize`/`NSRect` and `NSRange` have no standard equivalent and are out of scope here.
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
8. **Planning changed six requirements (2026-11-11).** Research (`research.md` R15) showed the
   standard library cannot do what they asked without changing behaviour: the deferred-release
   scope and the weak set stay on standard pointers (FR-006); never-destroyed singletons stay so
   (FR-005); weak references to a dying entity go empty earlier, so the code that read them during
   disposal is rewritten under tests (FR-007); `oo::Data` and `NSRange` stay (FR-013); lone
   constants become `constexpr`, not enums (FR-017); SC-004 is 1,500 lines, not 2,000.
9. **Two sign-offs Jon owns.** The `test_ref` case that pins weak references as live during
   disposal (`test_ref.cpp:514`) cannot keep its meaning, and renaming the enumerators of the 20
   existing `enum class` types forces test edits the amended rule 1 does not plainly cover. Both
   are *needs sign-off* rows in the test-change ledger. The work they block (US2's bridge, and the
   last enum step) is scheduled after the work they don't, so nothing waits.
10. **Casts and C strings added (Jon, 2026-11-11).** The idiom review's §2.3 items Jon had already
   put in scope on 2026-10-28 ("Don't use C strings"; C-style casts) are Stories 6 and 7 of this
   spec rather than a spec of their own, because they share the branch, the guards, the ledger and
   the files. Out-parameters, the other §2.3 item, stay out: they were not asked for here.
