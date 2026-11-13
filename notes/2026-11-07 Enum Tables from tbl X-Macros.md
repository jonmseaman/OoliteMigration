# Replace the `.tbl` X-macro tables with Google-style `enum class` + compile-time tables

**Status:** done, by [spec 009](../specs/009-modern-cpp-std/spec.md) User Story 5 on
`seriesb/027-modern-cpp` · **Written:** 2026-11-07

This plan was adopted as spec 009's US5; the tables are `enum class` headers with name lookups, and
only `OOOpenGLStates.tbl` remains (its own pattern, not an enumeration). The gates in the work
order below name `tests/idiom_check.py` and `tools/check-test-changes.py`, which do not exist (the
first was retired 2026-11-10): spec 009's `check.sh tbl` and `check.sh naming`, and its test-change
ledger, took their place. Read the work order as the record of the approach.

**Decisions this plan records (Jon, 2026-11-07):** de-macro *and* scope the enums in one piece of
work; Google-style `kPascalCase` enumerators enforced by clang-tidy; land it in Phase 6 rather than
on the `seriesb` stack; and hard rule 1 is to be reworded rather than exception-ed around.

**Three findings worth acting on independently of this plan:** the value column in
`OOViewID.tbl`, `OOLongRangeChartMode.tbl` and `OOGUIScreenID.tbl` is fiction and one of the three
is save-game-visible; `HeadUpDisplay.cpp:4657` omits `VIEW_CUSTOM`, so the scanner grid draws
nothing in custom view; and all three `tools/gen-*.py` generators that four files cite with a
byte-for-byte `--check` are absent from the tree.

## Context

`oolite-dev/src/Core/Tables/` holds 11 `.tbl` files: fragments of C that are not valid on their own
and whose meaning depends on whichever `#define` happens to be in scope where they are included.
They are `#include`d **40 times from 7 files**, and each site redefines the macros to produce
something different — an enum body, a `switch`, an `if`-chain, a struct initialiser list. Reading
one tells you nothing about what it produces.

Ten are enums with a name table, which modern C++ can express directly. The goal: each enum becomes
one self-contained, readable header — the `enum class`, its default, its name switch and its table —
with no preprocessor contract, and with Google-style `kPascalCase` enumerators enforced by
clang-tidy.

**Answering the original question: no, not all of them can become enums.** `OOOpenGLStates.tbl` is a
struct-field and code generator — four macros (`ITEM_STATEFLAG`, `ITEM_CLIENTSTATEFLAG`,
`ITEM_SPECIAL`, `ITEM_INT`) token-pasted into `GL_##NAME` / `GetState_##NAME` / `SetState_##NAME`
and expanded five times in `src/Core/OOOpenGLStateManager.cpp:68,482,516,566,644` to declare the
state struct, read GL, compare, log and write it. It has no enum/string duality, and the
fixed-function GL around it is replaced by the GL 3.3 Core work in the same phase. **It stays.**

This also closes a live hazard: because `ENTRY` has two incompatible expansions in the tree, three
tables' numeric columns are fiction, and nothing in the files says so.

## Scope and placement

- **10 enum tables** → `enum class Foo : std::int32_t` + one header each, replacing the `.tbl` in
  place (`OOScanClass.tbl` → `OOScanClass.h`). `OOOpenGLStates.tbl` is out of scope.
- **Phase 6**, folded into `docs/phases/6-modernise.md` step 5 ("Enums"), not the current `seriesb`
  stack, so upstream still reviews a tree whose tables are byte-identical to theirs
  (`docs/parity/c-and-tables.md:16`) and Phase 4p's exit gate stays intact.
- Amend the two recorded decisions that currently forbid this:
  `notes/2026-10-28 Modern C++ Idiom Review.md:66` ("Keep: the 11 X-macro `.tbl` tables are a
  defensible pattern") and `:222` (§4 "What not to change"). Both become "10 converted in Phase 6;
  `OOOpenGLStates.tbl` kept, with the reason".

## The numeric trap — the single biggest risk

`ENTRY(label, value)` is expanded two incompatible ways and the `.tbl` files do not record which:

- `label = value,` — value honoured: `OOEntityEnums.h:37`, `OOTypes.h:139`, `ShipEntity.h:170`.
- `label,` — **value discarded, ordinals used**: `OOTypes.h:49`, `OOEntityEnums.h:61`.

So for `OOViewID`, `OOLongRangeChartMode` and `OOGUIScreenID` the written column is wrong:

| Constant | `.tbl` says | Actually is |
|---|---:|---:|
| `VIEW_CUSTOM` | 7 | **4** |
| `VIEW_NONE` (= `kOOViewIDDefault`) | −1 | **5** |
| `VIEW_GUI_DISPLAY` | 10 | **6** |
| `VIEW_BREAK_PATTERN` | 20 | **7** |
| `OOLRC_MODE_UNKNOWN` | −1 | **0** |
| `OOLRC_MODE_TECHLEVEL` | 3 | **4** |
| all 29 `GUI_SCREEN_*` | −1 | **0 … 28** |

`git log -S` dates the `label,` form to upstream 2011 (`9c9984871`), so it is original, not a
conversion regression. Three independent confirmations, not just the macro text:

- **`OOLongRangeChartMode`'s ordinals are in save games.** `PlayerEntity.cpp:1203` writes
  `oo::PList::signedInteger((int)longRangeChartMode)` as `chart_colour_mode`, read back at
  `:1616-1619`. Honouring the written column silently re-points every existing player's chart mode.
  **This is the hardest numeric constraint in the job.**
- `OOJSGlobal.cpp:510-511` comments "gui will be 0 for invalid screen id's as well as
  GUI_SCREEN_MAIN" and tests `gui == 0`, so `GUI_SCREEN_MAIN` is 0.
- Honouring `OOGUIScreenID`'s 29 `-1`s would collapse them onto one value and break the binary
  search at `OOConstToJSString.cpp:194-218`.

Ordinal *arithmetic* also depends on the numbering: `PlayerEntityControls.cpp:2240-2245` cycles with
`(OOLongRangeChartMode)(mode + 1)`; `OOJSPlayerShip.cpp:880` tests `chartMode > OOLRC_MODE_UNKNOWN`;
`PlayerEntity.cpp:13404-13406` range-checks `GALACTIC_HYPERSPACE_MAX`.

**Mitigation:** each of the three headers carries a `static_assert` pinning the real values, with a
comment pointing at the save-game site — fiction made unfakeable rather than merely documented.

## Compatibility constraints

**The API strings are frozen.** `Resources/Schemata/shipdataEntrySchema.plist:253-269` validates the
`CLASS_*` names as a plist enumeration; save games store `scan_class` as a name
(`ShipEntityLoadRestore.cpp:106` → `ShipEntity.cpp:916-924`); `Resources/Scripts/oolite-priorityai.js`
and friends compare them as strings; JS events carry them; `OOJSPlayerShip.cpp:718-722` compares
`cxx_OOStringFromCompassMode(...) == "COMPASS_MODE_BASIC"`. The `DIFF_STRING_ENTRY` prose strings are
API too (`PlayerEntity.cpp:6792-6798` → `setBounty`, exposed at `OOJSShip.cpp:3180-3200`).

**The numeric values are frozen.** `OOCompassMode` is shader-visible
(`EntityShaderBindings.cpp:637-645`); `callObjC` returns raw ints for status, behaviour, compassMode
and galacticHyperspaceBehaviour (`OOJSCallEntityMethods.h:94,322,624,714`).

**The underlying type must stay 32-bit.** `OOTypeEncodings.h:85,89,95,101,103,105,113` encode these
as `"i"`, and `:118` onward carries a frozen byte-for-byte `ShipEntity`/`PlayerEntity` layout
encoding with `i` in the slots these enum members occupy. All 152 values would fit in `int16_t`, and
`performance-enum-size` will say so — it is already in `.clang-tidy`'s non-error list, so it reports
without failing. Keep `std::int32_t` and say why in a comment.

**Nothing is actually generated — verified.** `OOTypeEncodings.h:1`, `OOJSCallEntityMethods.h:1`,
`OOEntityCalledByNameTable.h:1` and `tests/check_headers_standalone.py:34` all cite
`tools/gen-type-encodings.py`, `gen-callobjc-entity-table.py` or `gen-entity-by-name-table.py` with
a `--check` that "compares the file byte for byte". `find . -name 'gen-*'` finds **none of them**,
and `tools/type-encodings.tsv` is absent too. So those three `--check` guards are dead references,
codegen is **not** an available house pattern, and the `"i"` encoding must be held by hand. (Worth
fixing or deleting those banners as separate hygiene work — they currently promise a gate that does
not exist.)

**The C++ identifiers, however, are free.** Today every API string is `#label` stringification
(`OOConstToString.cpp:40-41`, `OOConstToJSString.cpp:77-78`), which welds identifier to string. Once
each table states its string explicitly, the two decouple — which is what makes the renaming below
possible at no compatibility cost.

## Design

### Google-style naming

Enumerators become `k` + UpperCamelCase, scoped, with the redundant prefix dropped:

```cpp
enum class OOEntityStatus : std::int32_t { kStartGame = -10, …, kInFlight = 100, … };
//  STATUS_IN_FLIGHT  ->  OOEntityStatus::kInFlight,  string still "STATUS_IN_FLIGHT"
```

Verified against the project's clang-tidy (`/opt/homebrew/opt/llvm@22/bin/clang-tidy`, LLVM 22.1.8):

- `ScopedEnumConstantCase: CamelCase` + `ScopedEnumConstantPrefix: k` is recognised and fires
  correctly on `enum class` constants.
- `CamelCase` **permits consecutive capitals**, so `kGUIDisplay` and `kOXZManager` pass with no
  ignore-regexp. (Confirmed by running the check with no prefix over `oofnd`: `PList`, `XML` and
  `GNUstepBinary` all pass on case.)
- **Use `ScopedEnumConstant*`, not `EnumConstant*`.** `notes/1_TODO.md`'s own clang-tidy sketch uses
  `EnumConstantCase`/`EnumConstantPrefix`, which covers scoped **and** unscoped constants (it just
  labels the scoped ones "enum constant" rather than "scoped enum constant" — measured). That would
  put all 175 unscoped enums in scope at once. `ScopedEnumConstant*` confines the policy to
  `enum class`, which is what lets this land incrementally.

`readability-identifier-naming` is not currently enabled. Follow the policy `.clang-tidy` documents
for itself ("a check that still has findings is enabled but does not fail a run; when its sweep has
cleared it, delete its `-name` line"):

- Root `.clang-tidy`: add `readability-identifier-naming` to `Checks` with only the two
  `ScopedEnumConstant*` options set, **not** in `WarningsAsErrors`. It will report the pre-existing
  non-conforming `enum class`es (`PList::Type::Null`, `PListFormat::OpenStep`,
  `OOEntityByNameArgument::None`, … — measured: 12+ in `oofnd` alone); those are a separate sweep.
- New `src/Core/Tables/.clang-tidy` putting it in `WarningsAsErrors`, so the ten new headers are
  held to the style from day one. This is already the house pattern — the root file's closing
  comment describes the per-directory `.clang-tidy` files in `src/Core/MiniZip` and
  `src/SDL/EXRSnapshotSupport`.

### The switch is the single source; the table is derived

Writing the enum body and a separate entry table would name everything twice and lose the
`-Wswitch` exhaustiveness that is **the only completeness check the X-macro form has today**.
Instead:

- the `enum class` body names each enumerator once;
- one `constexpr` **no-`default`** `switch`, `OOEnumName(E)`, returns the API string — `-Wswitch`
  ties it to the enum body, preserving today's guarantee exactly;
- the table is built by a `consteval` scan over the enum's value range calling that switch, so
  there is no second list to drift.

This is *stronger* than today, where `OOConstToJSString.cpp:85-119` is a genuinely separate list the
compiler never cross-checks against `OOConstToString.cpp`'s switch. It also collapses all three
macro shapes into one: `ENTRY`, `GALACTIC_HYPERSPACE_ENTRY` and `DIFF_STRING_ENTRY` differ only in
what string a label maps to, and once the switch returns a literal, prefix-stripping and the prose
column are just what you type.

### Worked header — prefix stripping, negative sentinel, `_MAX`, renaming

```cpp
// src/Core/Tables/OOGalacticHyperspaceBehaviour.h     (GPL banner kept verbatim)
#pragma once

#include <cstdint>
#include <string_view>

#include "OOEnumTable.h"

/*      The galactic hyperspace behaviours. int32_t because callObjC encodes
        this type as "i" (OOTypeEncodings.h); the values fit in less.
*/
enum class OOGalacticHyperspaceBehaviour : std::int32_t {
  kStandard = 0,
  kAllSystemsReachable = 1,
  kFixedCoordinates = 2,
  kUnknown = -1,
};

// The largest behaviour setGalacticHyperspaceBehaviour() accepts
// (PlayerEntity.cpp:13404). An alias, so it takes no switch case and no row.
inline constexpr OOGalacticHyperspaceBehaviour kOOGalacticHyperspaceBehaviourMax =
    OOGalacticHyperspaceBehaviour::kFixedCoordinates;

// What cxx_OOGalacticHyperspaceBehaviourFromString() answers for an unknown string.
inline constexpr OOGalacticHyperspaceBehaviour kOOGalacticHyperspaceBehaviourDefault =
    OOGalacticHyperspaceBehaviour::kUnknown;

/*      The one list: every behaviour and the string planetinfo.plist and JS
        name it by. The strings keep the BEHAVIOUR_ spelling the .tbl's macro
        pasted a GALACTIC_HYPERSPACE_ prefix onto; they are public API and the
        constants' own names no longer have to match them. No default, so
        -Wswitch reports a behaviour added without a name, and the table below
        is derived from this function.
*/
constexpr std::string_view OOEnumName(OOGalacticHyperspaceBehaviour value) {
  switch (value) {
    case OOGalacticHyperspaceBehaviour::kStandard:
      return "BEHAVIOUR_STANDARD";
    case OOGalacticHyperspaceBehaviour::kAllSystemsReachable:
      return "BEHAVIOUR_ALL_SYSTEMS_REACHABLE";
    case OOGalacticHyperspaceBehaviour::kFixedCoordinates:
      return "BEHAVIOUR_FIXED_COORDINATES";
    case OOGalacticHyperspaceBehaviour::kUnknown:
      return "BEHAVIOUR_UNKNOWN";
  }
  return {};  // not a tabled behaviour
}

inline constexpr auto kOOGalacticHyperspaceBehaviourTable =
    oo::MakeEnumTable<OOGalacticHyperspaceBehaviour, &OOEnumName, -1, 2>();
static_assert(kOOGalacticHyperspaceBehaviourTable.size() == 4);
```

`OOLegalStatusReason` and `OOShipDamageType` are the same with prose strings
(`case OOShipDamageType::kScrape: return "scrape damage";`) and ordinal values. The commented-out
entries (`GUI_SCREEN_CONTRACTS`, `kOOLegalStatusReasonThereCanBeOnlyOne`) survive as a commented
enumerator *and* a commented case — two places rather than one, a screen apart, which is the price
of dropping the macro.

### Value decision, per table — to be transcribed exactly

| header (was `.tbl`) | values | scan range | rows |
|---|---|---|---:|
| `OOEntityStatus.h` | **written** −10…999 | `-10, 999` | 20 |
| `OOScanClass.h` | **written** −1…999 | `-1, 999` | 16 |
| `OOCompassMode.h` | **written** −1…6 (no 2); shader-visible | `-1, 6` | 7 |
| `OOBehaviour.h` | **written** 0…811 (`0U` → `0`) | `0, 811` | 39 |
| `OOGalacticHyperspaceBehaviour.h` | **written** −1…2 | `-1, 2` | 4 |
| `OOViewID.h` | **ORDINAL 0…7** — discard the column | `0, 7` | 8 |
| `OOLongRangeChartMode.h` | **ORDINAL 0…4** — discard; **in save games** | `0, 4` | 5 |
| `OOGUIScreenID.h` | **ORDINAL 0…28** — discard the 29 `-1`s | `0, 28` | 29 |
| `OOLegalStatusReason.h` | **ORDINAL 0…16** | `0, 16` | 17 |
| `OOShipDamageType.h` | **ORDINAL 0…6** | `0, 6` | 7 |

The three wide scans cost ~0.07 s in total — free. If a full build disagrees, write those rows
explicitly as an `oo::EnumRow` array and keep `OOEnumName` purely as the `-Wswitch` canary; the
machinery accepts either.

### Shared machinery — `src/Core/Tables/OOEnumTable.h`, namespace `oo`

Not `src/oofnd/`: `src/oofnd/README.md:5` defines oofnd as the GNUstep Foundation replacement, and
an enum table has no Foundation counterpart. `src/Core/Tables/` is already on the include path
(`src/Core/Tables/meson.build:3`) for both the game and the unit tests
(`tests/unit/core/meson.build:265`), so **no build-file change is needed anywhere** — nothing lists
`.tbl` files. Standard headers only (`<array> <cstdint> <optional> <span> <string_view>`), no
`StdLib.hpp` umbrella (the `stdlib-hpp` idiom check is retiring it), nothing Foundation- or `JS_*`-
dependent, because `OOConstToJSString.cpp:26` defines `OO_PLAIN_CPP_UNIT` and reaches these headers
through `OOTypes.h`.

```cpp
namespace oo {

// One tabled enumerator: the value as plain int32_t, so the JS side can take a
// span of these without knowing the enumeration.
struct EnumRow {
  std::int32_t value;
  std::string_view name;
};

/*      The lookups for one enumeration, derived at compile time from its
        OOEnumName() switch. rows() is sorted by value, which is what the JS
        side's runtime qsort() used to produce.
*/
template <class E, std::string_view (*Name)(E), std::size_t N>
class EnumTable {
 public:
  constexpr explicit EnumTable(std::array<EnumRow, N> rows);
  constexpr std::span<const EnumRow> rows() const;
  static constexpr std::size_t size() { return N; }
  static constexpr std::string_view name(E value) { return Name(value); }
  constexpr std::optional<E> value(std::string_view name) const;  // linear, ≤39
 private:
  std::array<EnumRow, N> rows_;
};

// Every value in [Lo, Hi] that Name() names, ascending. Fails to compile if two
// enumerators share a name.
template <class E, std::string_view (*Name)(E), std::int32_t Lo, std::int32_t Hi>
consteval auto MakeEnumTable();

}  // namespace oo
```

Two-step (`consteval` count, then fill), as C++20 requires. `Name` is a template parameter, not a
stored pointer, so `name()` is a direct call with no runtime indirection. Checks, all free:
name uniqueness (a `consteval`-only `throw`, which emits no code), values unique and ascending (true
by construction), non-empty names (the scan's predicate), exhaustiveness (`-Wswitch`), and the one
hand-maintained number — the per-header `static_assert` on `size()`, which catches an enumerator
whose value falls outside `[Lo, Hi]`.

### How the four consumers change

**1. Enum bodies.** The `#define`/`#undef` scaffolding and `typedef enum` blocks in
`OOTypes.h:49-62,139-155`, `OOEntityEnums.h:36-93` and `ShipEntity.h:170-176` become ten
`#include`s. `OOEntityEnums.h` survives as a short umbrella (14 files include it). Each
`enum { kOO…Default = … }` block becomes a typed `inline constexpr`, which deletes the 5 C casts at
`OOConstToString.cpp:132,138,152,158,164` for free. The `DIFF_STRING_ENTRY` that
`OOConstToString.cpp:45` defines and never `#undef`s stops leaking.

**2. Forward `enum → std::string`** (9 functions, `OOConstToString.cpp:33-116`):

```cpp
std::string cxx_OOStringFromScanClass(OOScanClass value) {
  const std::string_view name = kOOScanClassTable.name(value);
  return name.empty() ? "UNDEFINED" : std::string(name);
}
```

Each keeps **its own** fallback: `cxx_OOStringFromBehaviour` returns `"** BEHAVIOUR UNKNOWN **"`
(`:60`), the other eight `"UNDEFINED"`.

**3. Reverse `string → enum`** (6 functions, `:118-175`) becomes
`kOOScanClassTable.value(string).value_or(kOOScanClassDefault)`. The six stay six — do not add
reverse lookups for `OOBehaviour`, `OOShipDamageType` or `OOLegalStatusReason`, which are one-way
today. `cxx_OOGalacticHyperspaceBehaviourFromString` keeps its `BEHAVIOR_` → `BEHAVIOUR_` recursion
(`:144-149`) verbatim.

**4. The QuickJS atom tables** (`OOConstToJSString.cpp:50-190`) — **the runtime `qsort`
disappears.** The brief's obstacle (a `constexpr` table can host neither a mutable `JSAtom` nor an
in-place sort) dissolves: the table is already sorted at compile time, and the atoms move to a
parallel mutable array indexed by row position.

```cpp
struct ConstTable {
  std::span<const oo::EnumRow> rows;  // ascending by value, constexpr
  std::span<JSAtom> atoms;            // one per row, filled by InitTable()
};
std::array<JSAtom, kOOScanClassTable.size()> sOOScanClassAtoms;
ConstTable gOOScanClassConstTable{kOOScanClassTable.rows(), sOOScanClassAtoms};
```

The binary search at `:194-218` becomes `std::ranges::lower_bound` over the sorted rows returning
`atoms[index]`; the reverse scan at `:237-244` walks `atoms`. `CompareEntries` (`:172-179`) and the
`TABLE` macro go, and `InitTable` only interns. Keep `sAtomsInterned`'s idempotence across engine
resets (`:146-161`); prefer `JS_NewAtomLen` if QuickJS-ng exposes it, to avoid a temporary
`std::string`. Afterwards **nothing in a table is mutable** — the only writable state is 152
`JSAtom`s in nine small arrays. Side benefit: `idiom_check.py c-array` loses 9 hits and `c-string`
1, in this file alone. `OOLongRangeChartMode` has a `ConstTable` that is initialised (`:135,158`)
but has no accessor pair — carry it across as-is with a comment; removing it is a separate question.

### Staging the rename: compat aliases, not `using enum`

~1,900 unqualified enumerator uses across `src/` and `tests/` (`STATUS_` 564, `BEHAVIOUR_` 346,
`GUI_SCREEN_` 326, `CLASS_` 322, `VIEW_` 142, `COMPASS_MODE_` 97, `kOOLegalStatusReason` 55,
`GALACTIC_HYPERSPACE_` 28, `OOLRC_MODE_` 24, `kOODamageType` 15).

`using enum` is **not** usable here: with the prefixes dropped, it would inject `kUnknown`,
`kActive`, `kNone`, `kTest` … into the global namespace, and `kUnknown` alone occurs in three of the
ten enums. Instead each new header carries a clearly marked, temporary compat block:

```cpp
// Compatibility: the pre-Phase-6 names, while call sites are converted. Deleted
// in the commit that qualifies this enum's uses.
inline constexpr OOScanClass CLASS_NOT_SET = OOScanClass::kNotSet;
```

152 lines in total, removed enum by enum. So each conversion commit changes no call site, and each
rename commit is one enum's worth of mechanical requalification.

**The rename needs a literal-aware tool,** because the old names also appear in string literals that
must *not* change (`OO_CHECK_EVAL("ship.status", "STATUS_IN_FLIGHT")`, and `Resources/` must not be
touched at all). `tests/idiom_check.py` already has `strip_comments_and_literals`; add
`tools/rename-enum-constant.py` that reuses it to locate replacement offsets, replaces only those,
and refuses to run on `Resources/`.

## Prerequisite: reword hard rule 1 (`/Users/jonms/OoliteMigration/CLAUDE.md`)

The rename sweep edits ~423 constant uses across 43 test files, which rule 1 currently reads as
forbidding outright.

**Why the wording misfires.** "Never modify or delete a test *to make it pass*" tests a motive, and
motive is not visible in a diff. An agent cannot audit its own intent, so to stay safe it reads the
rule as absolute. Replace the motive test with a property of the diff.

**The repo already has the right phrase**, buried in the FR-015 exception rather than in the rule:
`specs/002-seriesb-rebase-stack/spec.md:334` and the header of
`specs/002-seriesb-rebase-stack/series/test-changes.md` both say *"A changed test keeps what it
asserts."* Promote that:

> 1. **Never weaken a test.** What a test asserts — its expected values and the behaviour they pin
>    — is the parity signal. Never delete, relax, skip or `#if`-out an assertion, never change an
>    expected value, and never narrow what a test covers. Adding tests is expected.
>    A test MAY be edited to follow a deliberate change in the code it calls — an include, a type
>    or constant name, a stand-in's signature, a helper's plumbing — **as long as it keeps what it
>    asserts.** List every such edit in the spec's test-change ledger: path, what changed, why.
>    If a test looks wrong, or keeping what it asserts is impossible, leave it failing, record what
>    you observe and why it differs, and carry on with the rest of the work. Never edit an
>    assertion to settle that question yourself.

This keeps both failure modes that matter banned outright (a lost assertion; a silently re-baselined
expected value), stops rule 1 colliding with rule 8 ("never wait for Jon") by giving a way to
proceed, and keeps the ledger as the audit trail.

**Make it enforceable.** `tests/unit/` holds ~12,900 assertions in a closed macro set (`OO_CHECK`
8,971, `OO_CHECK_EQ` 2,106, `OO_CHECK_EVAL` 1,750, plus `OO_CHECK_LOG`, `_TEXT`, `_PAGE`, `_CALLS`,
`_GL_HEAVY`). A new `tools/check-test-changes.py` over `git diff <base>` fails when the count of
assertion macros in a `tests/` file falls, or when a string or numeric **literal** inside an
assertion changes, unless that path and reason are in the ledger. Identifiers may change freely —
exactly what an API-following edit does and an assertion-weakening edit does not:

```
-  OO_CHECK(entity->status() == STATUS_IN_FLIGHT);                 // identifier: allowed
+  OO_CHECK(entity->status() == OOEntityStatus::kInFlight);
   OO_CHECK_EVAL("ship.status", "STATUS_IN_FLIGHT");               // literal: frozen, untouched
```

## Work order

`./mk.sh build test` must pass at every commit. Per-enum granularity works because converting enum
*X* touches only *X*'s sites.

| # | Commit | Gate (fails before, passes after) |
|---|---|---|
| C0 | Reword rule 1; add `tools/check-test-changes.py` + a ledger section; amend the idiom review `:66,:222` and `docs/phases/6-modernise.md` step 5. | `python3 -I tools/check-test-changes.py --self-test` |
| C1 | Add the `tbl-include` idiom check: `r'#\s*include\s*"OO(?!OpenGLStates)\w*\.tbl"'`, **`raw=True`** (as `stdlib-hpp` at `idiom_check.py:120-123` — the stripper blanks include paths), plus the `--self-test` sample that every regex check needs. | `python3 -I tests/idiom_check.py tbl-include` — exit 2 (unknown check) before, exit 1 with **34** hits after |
| C2 | `src/Core/Tables/OOEnumTable.h` + `tests/unit/core/test_OOEnumTable.cpp` (a local 3-enumerator enum: sparse, ordinal, duplicate prose; `static_assert`s for sorting, round-trip, unknown name/value). Register in `tests/unit/core/meson.build`. Add `src/Core/Tables/.clang-tidy` and the root-`.clang-tidy` entry. | `meson test --suite core test_OOEnumTable` — absent before, passes after |
| C3–C12 | One enum each: new header (`enum class` kPascalCase + switch + table + compat block + value `static_assert`s), delete the `.tbl`, repoint the enum-body include, convert that enum's `OOConstToString.cpp` and `OOConstToJSString.cpp` sites, fix the casts the compiler names. **No call site renamed yet.** | `python3 -I tests/idiom_check.py tbl-include \| grep OOScanClass.tbl` — N lines before, 0 after; `test ! -e src/Core/Tables/OOScanClass.tbl` |
| C13 | Drop the `qsort`, `CompareEntries` and the `TABLE` macro; atoms to parallel arrays; `lower_bound`. | `tests/run.sh unit`, then `component` |
| C14–C23 | One enum each: delete its compat block, requalify its uses in `src/` and `tests/` with `tools/rename-enum-constant.py`, ledger the test edits. | `src/Core/Tables/.clang-tidy` clean for that header; `check-test-changes.py` clean |
| C24 | Fix the `.tbl` references in the `OOConstToString.h:103` comment and `src/Core/Tables/meson.build`'s banner; update `docs/parity/c-and-tables.md:16`, `headers.md:12`, `gamedata.md:374`. | `python3 -I tests/idiom_check.py tbl-include` — **0**, exit 0 |

Order for C3–C12, cheapest first. The cost driver is **not** the call sites — it is the 34 `.tbl`
include sites and the shared X-macro definitions in `OOConstToString.cpp` (3 → ~15, since each
`case label:` becomes `case OOFoo::label:` and the macro must be redefined per table) and
`OOConstToJSString.cpp` (3 → ~9). Nine of the ten enums touch those two files, so C3 and C4
establish the pattern once and the rest is qualification work.

| # | enum | refs src / tests | why this slot |
|---|---|---|---|
| C3 | `OOShipDamageType` | 14 / 1 | No switches outside the X-macro, no `case` labels, a pure pass-through parameter type. **The pilot** — exercises the whole recipe on the smallest surface. 2 breakages. |
| C4 | `OOLegalStatusReason` | 47 / 8 | Identically shaped: no switches, no arithmetic, prose strings, a commented-out entry. Mechanically free after C3. |
| C5 | `OOGalacticHyperspaceBehaviour` | 10 / 6 | Fewest refs. Prefix stripping, `_MAX`, the `BEHAVIOR_` fallback. Its range check at `PlayerEntity.cpp:13404-13405` is same-type and needs **no** cast. |
| C6 | `OOLongRangeChartMode` | 18 / 6 | **The save-game one.** Two interesting breakages: the `mode + 1` ordinal walk (`PlayerEntityControls.cpp:2240`) and the `get<int>(…, OOLRC_MODE_SUNCOLOR)` **default argument** (`PlayerEntity.cpp:1617`). Settle the cast helper here. |
| C7 | `OOCompassMode` | 80 / 17 | 35 `case` labels across five exhaustive no-`default` switches, but only one breakage — the shader path is already `static_cast`-based. Tedious, not risky. Rewrite `OOJSPlayerShip.cpp:718-722`'s string comparison as `getCompassMode() == OOCompassMode::kBasic`. |
| C8 | `OOBehaviour` | 223 / 118 | Highest churn-to-risk ratio: 58 `case` labels but only 2 `.tbl` sites (no JS table), and the plist round-trip at `ShipEntity.cpp:6694-6726,7163-7164` is already explicitly cast. `ShipEntity.cpp:445`'s `return 100 < behaviour && behaviour < 120;` is **unreachable** (the switch above returns on every arm including `default:`) — delete it rather than cast it. |
| C9 | `OOViewID` | 113 / 29 | Two structural fixes: the `int v_dir` plumbing (`HeadUpDisplay.cpp:263,4548`, call at `:1425`, switch at `:4657`) and `static int saved_view_direction` (`PlayerEntityControls.cpp:176,2111,2123`). **Typing `v_dir` surfaces a latent bug** — see below. |
| C10 | `OOScanClass` | 237 / 84 | Public-API names (plist schema, save games, `oolite-priorityai.js`). Three independent `int` carriers, one crossing a header boundary (`PlayerEntity.h:461` `int theirClass`), plus `int drawClass` in the scanner hot loop (`HeadUpDisplay.cpp:1433-1465`) and `int e_class` (`PlayerEntityLegacyScriptEngine.cpp:2369-2371`). Drop the vestigial `OO_SCANCLASS_TYPE` guard (`OOEntityEnums.h:43`, `Universe.h:79`). |
| C11 | `OOEntityStatus` | 405 / 131 | Largest by volume, **88 files**, and the most widely included of the ten, so a mistake in the declaration breaks the whole tree. Three `int` carriers (`Universe.cpp:5241,5281,5645`, `GuiDisplayGen.cpp:1434`, `ShipEntity.cpp:2323`). **The rule-1 exception lands here:** `tests/unit/core/test_OOJSSound.cpp:33-39`'s hand-rolled `typedef enum` becomes `#include "OOEntityStatus.h"`, hand-edited in the file's tab style (`tests/` is never reformatted). |
| C12 | `OOGUIScreenID` | 284 / 42 | Most expensive. **89 `case` labels**, including a 1070-line switch (`PlayerEntityControls.cpp:2186-3255`) and a 396-line one (`:5260-5656`); the `std::map<int, …> extraGuiScreenKeys` key type touching `PlayerEntity.h:1874`, `.cpp:13742,13784,13827` and `PlayerEntityControls.cpp:3258`; and the two semantic sites below. Save it for last. |

### Two things that are decisions, not mechanical edits

- **A latent bug, surfaced by C9.** `HeadUpDisplay.cpp:4657` `switch (v_dir)` covers seven view IDs
  but **omits `VIEW_CUSTOM`**, so the scanner grid draws nothing in custom view. Because the subject
  is `int v_dir`, `-Wswitch` has never seen it. Typing the parameter `OOViewID` makes the compiler
  report it — then decide whether custom view should draw the grid. Check against upstream 1.93
  first and note whether it is upstream's bug too.
- **`OOGUIScreenID` as a truth value.** `OOJSGlobal.cpp:429` `if (!gui)` (contextual conversion to
  `bool`, unavailable for a scoped enum) and `:511` `gui == 0`, whose own comment admits it
  conflates an invalid screen name with `GUI_SCREEN_MAIN`. Scoping forces the intent to be spelled
  out, and what the script-facing API returns for a bad screen name is **observable to OXPs**.
  Default: preserve today's behaviour exactly (`gui == OOGUIScreenID::kMain`) and record that the
  conflation is deliberate and unchanged.

Formatting: `clang-format -i` on each commit's changed files only — never `./mk.sh format`, which
rewrites all of `src/`. `mk.sh:418` pins clang-format **22**
(`/opt/homebrew/opt/llvm@22/bin/clang-format`); the `clang-format` on PATH here is 23 and wraps
long `case` lines differently. Never on `tests/`.

## Verification

In order of cost:

1. `./mk.sh build test`, Clang and GCC (`--native-file=gcc.ini`). No `-Wno-*`, no
   `#pragma diagnostic`, no unused-attribute (hard rule 2).
2. `clang-format` on changed files, then `./mk.sh format-check`; `clang-tidy -p .` on each new
   header (the `src/Core/Tables/.clang-tidy` makes a naming slip an error).
3. `python3 -I tests/idiom_check.py --self-test`, then `--all tbl-include unscoped-enum c-array
   c-string`. `tbl-include` 34 → 0; `unscoped-enum` **187 → 174** (the 13 removed:
   `OOEntityEnums.h:39,47,53,63,70,79,87`, `OOTypes.h:51,57,141,145,149`, `ShipEntity.h:172`).
4. `python3 -I tests/check_headers_standalone.py` — the ten new headers are self-contained, so they
   are picked up automatically. Do **not** add them to its `FRAGMENTS` list.
5. `tests/run.sh unit` (oofnd, core, headers).
6. **`tools/js-parity/compare.sh`** — the best existing gate for this change: its baseline already
   pins `compassMode = "COMPASS_MODE_BASIC"`, `scanClass = "CLASS_PLAYER"`,
   `status = "STATUS_DOCKED"`, `viewDirection = "VIEW_GUI_DISPLAY"` and the station/spawned
   equivalents. Costs nothing to run.
7. `tests/run.sh component` — `oolite-priorityai.js`'s `CLASS_*` comparisons in anger (s1–s8), plus
   `t1_tutorial_walkthrough` for the GUI-screen and view paths. Then `smoke`, then `gui` (one at a
   time; GUI tests own the desktop).
8. By hand, for what no test covers: load a **pre-change** save and read back `chart_colour_mode`
   and a stored ship's `scan_class`; set `galactic_hyperspace_behaviour` from planetinfo
   (`PlayerEntity.cpp:2688-2693`); confirm a compass-mode shader binding reads the same int; run
   `callObjC("status")` and `callObjC("behaviour")` from the debug console.

**Method for the int conversions: convert one enum, build, fix what the compiler names, repeat.** Do
not try to find them all by grep first.

### What actually breaks, and what does not — measured

**Does not break, no edit beyond qualification:**

- **`kOOTypeEncoding<>` and the ~2,600-row by-name table.** Both dispatchers already branch on
  `std::is_enum_v` and go through an explicit cast: `OOEntityCalledByName.cpp:138`
  (`static_cast<long long>(Function(entity))`) and `EntityShaderBindings.cpp:142`
  (`out.i = static_cast<long long>(value);  // integers and enums`). `kOOTypeEncoding<OOBehaviour>`
  is a template argument, and `OOBehaviour{}` value-init stays legal. **Nothing** in
  `OOTypeEncodings.h`, `OOJSCallEntityMethods.h` or `OOEntityCalledByNameTable.h` needs editing, and
  the compassMode shader row (`EntityShaderBindings.cpp:637-648`) is safe for the same reason.
- **Relational operators between two values of the same scoped enum**, which is ordinary C++. So
  `chartMode > OOLRC_MODE_UNKNOWN` (`OOJSPlayerShip.cpp:880`), the `GALACTIC_HYPERSPACE_MAX` range
  check (`PlayerEntity.cpp:13404-13405`), `chart_mode <= OOLRC_MODE_TECHLEVEL`
  (`GuiDisplayGen.cpp:2309`) and the five `… <= VIEW_STARBOARD` tests all compile unchanged.
- **`-Wswitch` itself.** It is already live (meson `warning_level=1` → `-Wall`), and scoping does not
  change it. Nine game switches already carry comments like *"no default, so that we get notified by
  the compiler if something is missing"* (`PlayerEntity.cpp:13517`, `ShipEntity.cpp:3003,12343`,
  `Universe.cpp:5045`, …), so the house already relies on this property. It is preserved for free.
- **`++`/`--`, bitwise ops and array subscripting**: none exist on any of the ten types.
- **Tests**: the 442 constant references are almost all same-type comparison or assignment; the
  numeric ones already use `static_cast<int>` or `(double)`. Tests cost qualification only.

**Breaks — about 56 sites, concentrated:**

- **9 mixed enum/int arithmetic or literal comparisons**: `PlayerEntityControls.cpp:2240`
  (`mode + 1`), `OOJSGlobal.cpp:429` (`if (!gui)`), `:511` (`gui == 0`), `ShipEntity.cpp:445` (dead
  code), plus the int-carrier comparisons.
- **~7 `int` carriers** that should simply be retyped, each fixing several sites at once:
  `saved_view_direction` / `saved_gui_screen` (`PlayerEntityControls.cpp:176,178`), `int playerStatus`
  (`GuiDisplayGen.cpp:1434`), `int v_status` (`Universe.cpp:5241`), `int drawClass`
  (`HeadUpDisplay.cpp:1433`), `int v_dir` (`HeadUpDisplay.cpp:263,4548`), `int theirClass`
  (`PlayerEntity.h:461`), `int e_class` (`PlayerEntityLegacyScriptEngine.cpp:2369`), and the
  `std::map<int, …> extraGuiScreenKeys` key (`PlayerEntity.h:1874`).
- **The 5 companion defaults that live in *separate anonymous* enums** —
  `OOEntityEnums.h:55,56,81,82` and `OOTypes.h:145` — stop compiling, because an anonymous
  enumerator needs an integral constant expression and a scoped enum value is not one. Replacing
  them with `inline constexpr OOFoo kOOFooDefault = …` is better typing but then changes the
  `NSInteger defaultValue` arguments at `OOConstToJSString.h:75,92,111,130,151`. You pay once either
  way, in that header. (The five defaults declared *inside* their enum are structurally fine and
  need only qualification. Note `OOBehaviour` has **no** companion default at all.)
- **9 sites in `OOConstToJSString.h`** pass an enum straight into
  `OOJSValueFromConstantPRIVATE`'s `NSInteger value` parameter (`:67,85,103,122,142,161,167,177,188`),
  plus 6 C-style casts at `:74,91,110,129,149,166` that become `static_cast`.
- **17 C-style casts to these types**, 5 of which disappear when the defaults become typed
  (`OOConstToString.cpp:132,138,152,158,164`). Note `tests/idiom_check.py`'s `c-cast` check
  (`:146-150`) does **not** match `(OOEntityStatus)`-style casts, so none of the 17 is currently
  reported — converting them improves nothing in that count but is the consistent move.

**`std::to_underlying` is C++23 and the project is C++20** (`src/meson.build:25`). Use
`static_cast<std::int32_t>`, or add a small `oo::to_underlying` helper — decide at C6, the first
commit that needs it, and use it consistently thereafter.

## Open points, with the default taken

- **`magic_enum`-style `__PRETTY_FUNCTION__` reflection: no.** Compiler-formatting-dependent, and
  `src/oofnd/README.md:13` forbids third-party code without a recorded decision — a hand-rolled copy
  is the same decision with worse provenance. The no-`default` switch is the house shape for this
  (`oofnd/PList.hpp:353-377`).
- **`-Werror=switch`**: upgrading the exhaustiveness check from warning to error is what "never
  silence a warning" implies, but it needs a full build to confirm nothing else warns. Default: its
  own commit, after C24, not bundled.
- **`enum class` for the other 165 unscoped enums, and `kPascalCase` for the 31 existing
  `enum class`es** (`PList::Type::Null`, `PListFormat::OpenStep`, …): out of scope here, enabled
  non-fatally by C2's root `.clang-tidy` entry so the backlog is visible. They are Phase 6 step 5's
  remaining work.
- **`OOViewID`'s `kOOViewIDDefault` is an enumerator *inside* the enum**, duplicating `VIEW_NONE`'s
  value (`OOTypes.h:54`); same for `kOOLongRangeChartModeDefault` and `kOOShipDamageTypeDefault`.
  Default: move them out to typed `inline constexpr` so no switch or table sees a duplicate. Values
  unchanged, which the `static_assert`s confirm.
