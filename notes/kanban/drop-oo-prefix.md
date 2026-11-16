---
status: Review
spec-kit-status: Implementation
branch: seriesb/033-drop-oo-prefix
parent: seriesb/032-cleanup
---
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

**Decisions taken while renaming** (conservative defaults, rule 8):
- *Gate tests.* Option B is not used, so `test_SaveEnumValues` and `test_PlayerEntity` must name the renamed types. "Unedited" is read as: no string literal and no assertion changed, only type names, and each edit is in the ledger.
- *`OOEnumName` keeps its name.* It is an ADL customisation point: `oo::MakeEnumTable` calls it unqualified, so each overload must live in its enum's namespace, and some enums stay global for good (`WORMHOLE_SCANINFO`). Overloads for enums that move into `oo` move with them.
- *Name clashes in `oo`.* Where a stripped name meets an existing `oo` name, the existing function gets a new name, not the type: `oo::EntityStatus(Entity*)` → `oo::EntityStatusOf`.
- *Comments.* Old names in comments are left alone, like string literals.
- *Names a macro shares keep their spelling.* `OOSetOpenGLState`, `OOGLNoteCurrentFunction`, `OOGetHighResTime`, `OODumpPixMap`, `OOInitDebugSupport` and the `OODebugDraw*` family are functions in one configuration and macros of the same name in another (`NDEBUG`, `OO_DEBUG_MONITOR_ENABLED`, platform), so a caller must spell the macro. Any name that is also `#define`d stays.
- *Block-scope `extern` in a function that moves into `oo`* would name `oo::gFoo`; `gOOPlayer` and `gSharedUniverse` are declared at namespace scope instead and read as `::gFoo`.
- *Friends.* A class now in `oo` that befriends a test's `*TestAccess` struct names it `::FooTestAccess`, after a global forward declaration (the `BreakPatternEntity.h` pattern).
- *Test names.* An `OO_TEST(OOFoo)` argument is the registered test name (`#name`), not a reference, so it keeps its spelling and the test list stays the same.
- *Tables included inside an anonymous namespace* (`EntityObjectNamesTable.h` in `EntityCalledByName.cpp`) stay file-local, not in `oo`.
- *Formatting of renamed files.* The per-area formatting skipped renamed files at first; oolite-dev `d21dd01d1` formats the lines the branch changed in them, and each area since formats them itself.
- *Observed flake.* Over nine `core` runs after the Entities area, `test_MyOpenGLView` failed once (exit 1) and `test_OOSoundMixer` timed out once (61 s; 0.02 s alone). Both are the `core+openal` tests, both pass alone, and four later full runs were clean. Not yet seen to reproduce.
- *`src/SDL/OOResourcesWin/` keeps its file names.* They are resource-compiler inputs, not C++, and a separate task moves them to `installers/win32/` as they are.
- *File names that would shadow a system header.* A renamed file in a directory on the `-I` path must not match a C, C++ or POSIX header case-insensitively (`Math.h` would shadow `<math.h>` on Windows and macOS). Such a file gets a longer name, recorded in its area's ledger row.
- *Flag enums in `oo`.* `OOEnableFlagOperators` is kept like `OOEnumName`, and moves with its enum. `OOEnumFlags.h` adds `using ::operator|;` (and the other six) inside namespace oo, so a flag enum in `oo` finds the global operator templates past any other `oo` operator of the same name.

**Where it stands** (worker, 2026-11-15; branch `seriesb/033-drop-oo-prefix`, tip oolite-dev `8440ffe7d`, pushed). All eight areas are renamed. The done check's grep still matches 217 lines, and none of them is a name the rename should have taken: macros (177), comments (40, block comments included), `*TestAccess` (10), names defined in `Core/Scripting/` (9) and one `extern "C"` name. `.agent-tmp/cc/donecheck.py` sorts them. The only `OO*` files left outside Scripting are `src/SDL/OOResourcesWin/`'s. The dev build, `tests/run.sh unit` and `tests/run.sh component` pass (component as before: census 127 passed, 6 failed, 8 expected; 24 of 24). Every game translation unit (229) also compiles `-fsyntax-only` with the deployment flavour's defines (`-UOO_DEBUG -DNDEBUG ...`), which is how the macro-pair breakage was found. Not checked here: macOS and Linux branches (CI covers them), and the debug build.

## Test-change ledger (signed off: Jon, 2026-11-15)

One row per area, filled in as each area lands. The rename map is the area's
`rename-map-<area>.tsv`, kept beside this plan.

| Area | Test files | Edit | Assertions | Commit |
|---|---|---|---|---|
| _(each area)_ | | every `OO`/`kOO` name in the map replaced; `#include`s updated; identifiers only, no string literal touched | unchanged | |
| OXPVerifier | `tests/unit/core/`: `OOOXPVerifierTestDouble.h`, `meson.build`, the 13 `test_OO*VerifierStage.cpp`/`test_OOOXPVerifier*.cpp`/`test_OOPListSchemaVerifier.cpp` (file names kept) | the 22 names in `rename-map-Core-OXPVerifier.tsv` replaced; `#include`s updated; identifiers only, no string literal touched | unchanged; `"<OOFoo 0x"` text kept by `oo::DescriptionClassName` | oolite-dev `2864d628d` |
| Tables | 51 files under `tests/unit/core/` and `tests/component-cpp/` that name a table enum, including the gates `test_SaveEnumValues.cpp` and `test_PlayerEntity.cpp` (type names only) | the 30 names in `rename-map-Core-Tables.tsv` replaced; `#include`s updated; identifiers only, no string literal touched | unchanged | oolite-dev `27cbff850` |
| Debug | 16 files: `tests/unit/core/meson.build`, `test_Entity`, `test_OOConstToString`, `test_OODebugMonitor`, `test_OODebugStandards`, `test_OODebugSupport`, `test_OODebugTCPConsoleClient`, `test_OOEnumFlags`, `test_OOEquipmentType`, `test_OOJSClock`, `test_OOJSConsole`, `test_OOJSEquipmentInfo`, `test_OOJSMission`, `test_OOJSStation`, `test_OOShipRegistry`, `tests/unit/oofnd/test_tcp_stream_format` | the 59 names in `rename-map-Core-Debug.tsv` replaced; `#include`s updated; identifiers only, no string literal touched | unchanged. `test_OOEnumFlags`' comment still speaks of a global flag enum; its checks now run on `oo::DebugFlags` through `OOEnumFlags.h`'s using-declarations | oolite-dev `3913f9b44` |
| SDL | 7 files: `tests/unit/core/meson.build`, `test_EnumNameFallbacks`, `test_MyOpenGLView`, `test_OOJSOolite`, `test_OOJoystickDecoding`, `test_OOJoystickManager`, `test_OOSDLJoystickManager` | the 5 names in `rename-map-SDL.tsv` replaced; `#include`s updated; identifiers only, no string literal touched | unchanged | oolite-dev `d1fec6a63` |
| oofnd | 42 files under `tests/` that include `oofnd/objc/OOAssert.h`/`OOException.h` or name the exceptions | the 9 names in `rename-map-oofnd.tsv` replaced; `#include`s updated; identifiers only, no string literal touched | unchanged | oolite-dev `6eb071db3` |
| Entities | 52 files under `tests/` (`unit/core/meson.build` and the tests naming an entity class: `tests/component-cpp/component_census`, `tests/component-cpp/oo_component`, `test_CollisionRegion`, `test_EntityDisposalReaders`, `test_EntityScriptEvents`, `test_EntityShaderBindings`, `test_EnumNameFallbacks`, `test_OOBreakPatternEntity`, `test_OOConstToString`, `test_OODebugMonitor`, `test_OOECMBlastEntity`, `test_OOEntityCalledByName`, `test_OOEntityWithDrawable`, `test_OOExhaustPlumeEntity`, `test_OOFlashEffectEntity`, `test_OOFlasherEntity`, `test_OOJSCall`, `test_OOJSCallEntityMethods`, `test_OOJSExhaustPlume`, `test_OOJSFlasher`, `test_OOJSMission`, `test_OOJSPlanet`, `test_OOJSPlayer`, `test_OOJSShip`, `test_OOJSStation`, `test_OOJSSun`, `test_OOJSSystem`, `test_OOJSSystemInfo`, `test_OOJSVisualEffect`, `test_OOJSWaypoint`, `test_OOLaserShotEntity`, `test_OOLightParticleEntity`, `test_OOParticleSystem`, `test_OOPlanetEntity`, `test_OOPlasmaBurstEntity`, `test_OOPlasmaShotEntity`) | the 124 names in `rename-map-Core-Entities.tsv` replaced; `#include`s updated; identifiers only, no string literal touched; `OO_TEST(...)` names kept | unchanged | oolite-dev `d090bfc6e` |
| Materials | 42 files under `tests/` (`unit/core/meson.build` and the material, shader and texture tests) | the 185 names in `rename-map-Core-Materials.tsv` replaced; `#include`s updated; identifiers only, no string literal touched; `OO_TEST(...)` names kept | unchanged; `"<OOFoo 0x"` text kept by `oo::DescriptionClassName` | oolite-dev `2d4d0d962` |
| Debug, Materials (fix) | `tests/unit/core/test_OODebugSupport.cpp`: back to `OOInitDebugSupport()` as before the rename | `oo::InitDebugSupport`/`oo::DumpPixMap` restored to `OOInitDebugSupport`/`OODumpPixMap`, names a no-op macro shares | unchanged | oolite-dev `279386ced` |
| Core | 187 files under `tests/` (`unit/core/meson.build`, `component-cpp`, and every test naming a Core type) | the 492 names in `rename-map-Core.tsv` replaced; `#include`s updated; identifiers only, no string literal touched; `OO_TEST(...)` names kept | unchanged | oolite-dev `5216ec427` |

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
