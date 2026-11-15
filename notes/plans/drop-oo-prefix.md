# Drop the `OO` prefix from `src/` names (a new `seriesb` branch)

Status: **Tasks** (ready; last in the list). Jon wants this eventually (2026-11-15).

## Goal

Rename the `OO`-prefixed names in `oolite-dev/src`, **except `src/Core/Scripting/`**, to unprefixed
names in `namespace oo`: `OOColor` → `oo::Color`, `kOOFoo` → `oo::kFoo`. Files follow:
`OOColor.h` → `Color.h`. This matches the rule for new code (see the planner instructions in
`0_AI_Tasks.md`).

The work goes on its own branch at the top of the stack:
`git town append seriesb/0NN-drop-oo-prefix` in `oolite-dev`, using the next free `seriesb`
number (032 is `seriesb/032-cleanup`).

## Size (2026-11-15, `src/` without `src/Core/Scripting/`)

| What | Count |
|---|---:|
| Files named `OO*` | 327 (another 106 in `Core/Scripting`, which stay) |
| Types (`class`/`struct`/`union`/`enum`/`using`) named `OO*` | 301 |
| `kOO*` constants | 332 |
| Distinct `OO*` identifiers of any kind | 1,317 |
| Occurrences of `OO*`/`kOO*` identifiers in that part of `src/` | 29,706 |
| `#define OO*` macros | 192 |
| `tests/` occurrences of `OO*`/`kOO*` names | 12,591 in 242 files |

- **Collisions:** none found. No `OO*` file in scope collides with an existing file once `OO` is
  dropped. No type's stripped name already exists as a type in `src/`.
- **Exact counts by kind:** these come from the clang-tidy name inventory in `notes/naming/`
  (functions, methods, variables and constants as declared, not grep matches). Use that inventory
  as the rename list.

## Scope rules

- **Renamed:** declarations outside `src/Core/Scripting/`. **Their uses are renamed everywhere,
  including inside `Core/Scripting/`**, or it wouldn't build. `Core/Scripting/`'s own `OO*` names
  (`OOJS*`, `OOJavaScriptEngine` …) stay.
- **Macros stay.** A macro can't live in a namespace, so it needs some prefix, and many are already
  being removed by the idiom plan (I4–I8). Rename the survivors in a later pass, if ever.
- **Save files: nothing to convert.** A saved game is a property list of strings, numbers, arrays
  and dictionaries. No C++ type name is ever written into one: the plist writer names a class only
  in its "does not support OldSchoolPropertyListWriting" error, `PListWriting.hpp:161`. What a save
  does hold are string literals: plist keys, equipment keys, and enum value names such as
  `"OOLRC_MODE_UNKNOWN"` (`Tables/OOLongRangeChartMode.h:36`). Several of those start with `OO`, so:
  - The rename script replaces **identifiers only**. It skips string literals and comments, or
    matches whole C++ tokens through the compile database. A plain text replace could rewrite
    `"OOLRC_…"`-style strings and break loading old saves.
  - Gate: `test_SaveEnumValues` and `test_PlayerEntity` (which round-trip save data) pass
    unedited, and an existing save written before the rename loads after it.
- **Log and description text may change** (Jon, 2026-11-15: log names don't need to match). A
  demangled class name (`OODemangle(typeid(*this).name())` at `OOMaterial.cpp:64`,
  `OOALSound.cpp:167`, `OOTextureLoader.cpp:231`) would start printing `oo::Texture`, and that's
  fine. Literal `className()` strings (`"OOTexture"`) may stay or change. The exception is text a
  test pins (`<ClassName 0x…>` descriptions in the `test_OO*` files, `test_log`): keep that text
  as it is, or it becomes a test edit.
- **Nothing visible to JS or OXPs changes.** That means the by-name table's method names,
  `callObjC` names, plist keys and log message classes. Those are strings, not identifiers, so a
  rename can't touch them. The OXP/JS surface is mostly in `Core/Scripting/`, which is excluded
  anyway.

## How

1. Take the rename list from the clang-tidy inventory: every declaration whose name starts `OO` or
   `kOO`, outside `Core/Scripting/`. For each, write `old → new` (`OOFoo` → `oo::Foo`, `kOOFoo` →
   `oo::kFoo`, files `OOFoo.*` → `Foo.*`).
   - Free functions named `OOFoo` → `oo::Foo`.
   - Methods have no prefix to drop, so they're out of scope here. Their case (6,131
     camelCase-vs-CamelCase findings) is a separate decision.
2. Apply it one area at a time, as one commit per area: Core top level, Entities, Materials,
   OXPVerifier, Debug, SDL. Within an area:
   - Move the declarations into `namespace oo` and rename them.
   - Update uses tree-wide with whole-word replacement, run by a script, longest name first so
     `OOColorFoo` isn't half-replaced by `OOColor`.
   - `git mv` the files and fix the `#include`s and the `meson.build` source lists.
3. After each area: run `./mk.sh build dev` and `tests/run.sh unit`, run clang-format 22 on the
   changed `src/` files only (never `tests/`), and commit.

## Tests (decided: A, signed off by Jon 2026-11-15)

The tests name these types and constants 12,591 times in 242 files, so renaming them is a test
edit. No rule-1 exception covers it: it isn't a standard equivalent or upstream parity. Measured
2026-11-15, the tests depend on the names in five ways:

| Dependence | Count | Example |
|---|---:|---|
| `#include "OOFoo.h"` of a renamed header | 618 lines, 186 headers, 199 files | `#include "OOColor.h"` |
| Plain uses of a type or constant | most of the 12,591 | `OOColor c = …;`, `kOOFoo` |
| Stub definitions of real members, which the test links in place of game `.cpp` files | 869 lines in 72 files (22 of them constructors) | `OOMusicController::OOMusicController() { … }` (`test_OOJSMission.cpp:488`) |
| Stand-in classes with the real name | 55 | `class OOJavaScriptEngine { … }` (`test_OOCheckJSSyntaxVerifierStage.cpp:58`) |
| Forward declarations | 10 | `class OOScript;` (`test_OOCommodities.cpp:95`) |

**A. Rename the tests with the source (needs Jon's sign-off).** The same identifier-only script runs
over `tests/` in each area's commit, using the same rename list, and touches no string literals
and no assertion. One ledger row per area: "every name in `rename-map-<area>.tsv` replaced; includes
updated; assertions unchanged". Every kind of dependence above is handled, and nothing is left
behind to clean up.

**B. Keep the old names working for the tests, with no test edits.** This only partly works:
- *Includes:* a forwarding header for each renamed one (`OOColor.h` → `#include "Color.h"` plus
  the aliases below), 186 stub files kept in `src/`.
- *Types and constants:* `using OOColor = oo::Color;` and
  `inline constexpr auto& kOOFoo = oo::kFoo;`. Free functions need forwarding functions, because
  `using` can't rename a function and overloads can't be aliased.
- *Stub member definitions* (`void OOFoo::bar() {}`) compile through an alias, because a type
  alias may name the class in an out-of-class definition. **Constructors don't**: you can't write
  `OOFoo::OOFoo()` through an alias. That's 22 places that would fail.
- *Stand-in classes and forward declarations* **fail**. A test that declares its own
  `class OOScript;` clashes with the alias `using OOScript = oo::Script;`. A stand-in
  `class OOJavaScriptEngine` defines symbols the renamed game code no longer looks for, so the link
  fails or the stand-in silently stops replacing the real class. That's 65 places.

So B still forces about 90 test edits (constructors, stand-ins, forward declarations), and it
leaves about 186 forwarding headers plus about 630 aliases in `src/` until a later clean-up, which
is itself a test edit. B doesn't avoid the sign-off; it only splits it and adds work.

**Decision: A** (Jon, 2026-11-15). The tests are renamed along with the source in each area's
commit, with one ledger row per area. B is not used, and there are no forwarding headers or
aliases.

**Keep the test-access names.** `*TestAccess` structs (for example
`OOBreakPatternEntityTestAccess`, `OOOXPVerifierTestAccess`) are declared by the tests and named as
`friend` in `src/` headers. Leave them out of the rename list, so the `friend` lines still match.

## Test-change ledger (signed off: Jon, 2026-11-15)

One row per area, filled in as each area lands. The rename map is the area's
`rename-map-<area>.tsv`, kept beside this plan.

| Area | Test files | Edit | Assertions | Commit |
|---|---|---|---|---|
| _(each area)_ | | every `OO`/`kOO` name in the map replaced; `#include`s updated; identifiers only, no string literal touched | unchanged | |

## Done check

From `oolite-dev`, this exits nonzero before and zero after:

```bash
! git grep -nE '^\s*(class|struct|union|enum( class)?)\s+OO[A-Z]|\busing\s+OO[A-Z]\w*\s*=|\bkOO[A-Z]' -- src ':!src/Core/Scripting'
```

Also `git ls-files src ':!src/Core/Scripting' | grep -E '/OO[A-Z][^/]*$'` finds nothing, and
`./mk.sh build dev`, `tests/run.sh unit` and `component --cpp` pass with the printed text
unchanged.

## Costs to weigh before starting

- **Upstream merges.** Upstream names 416 files `OO*`. After this, every upstream change to a
  renamed file or type conflicts by name, so the `seriesb` stack's comparability with upstream gets
  much worse. Doing it last, once the series has gone upstream or the fork has stopped tracking
  upstream closely, keeps that cost down.
- **Ordering.** Land the idiom plan's macro work (I4–I8) and the `OOTypeEncodings.h` deletion first,
  so fewer names have to move.
