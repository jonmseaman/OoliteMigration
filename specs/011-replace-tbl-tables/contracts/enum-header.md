# Contract: a named-enum header (Stories 1 and 2)

What each of the ten `src/Core/Tables/OO<Type>.h` headers contains, and the one addition to
`src/Core/OOEnumTable.h`. Research: R1–R4, R6. The shape is spec 009's
([contracts/enums.md](../../009-modern-cpp-std/contracts/enums.md), *The shape of a converted enum
header*), narrowed to these ten and to C++20.

## `src/Core/OOEnumTable.h`

The file is spec 009 T046's text (`310cd4480`) unchanged, with `#include <type_traits>` added and
this function appended inside `namespace oo`. Tested on Clang 23.1 and GCC 15.2 (C++20): an
eight-member table builds; a 1,010-value range builds; two values with one name fail to compile;
a missing switch case fails under `-Werror=switch`.

```cpp
// Every value in [Lo, Hi] that E's OOEnumName names, ascending by value.
// Fails to compile if two values share a name. With an exhaustive OOEnumName
// switch this is the whole enum, with no second list of members to keep.
template <class E, std::underlying_type_t<E> Lo, std::underlying_type_t<E> Hi>
consteval auto MakeEnumTableInRange() {
  static_assert(Lo <= Hi);
  constexpr std::size_t kCount = [] {
    std::size_t count = 0;
    for (long long v = Lo; v <= Hi; ++v) {
      if (!OOEnumName(static_cast<E>(v)).empty()) ++count;
    }
    return count;
  }();
  EnumTable<E, kCount> table{};
  std::size_t filled = 0;
  for (long long v = Lo; v <= Hi; ++v) {
    const E value = static_cast<E>(v);
    const std::string_view name = OOEnumName(value);
    if (name.empty()) continue;
    for (std::size_t i = 0; i < filled; ++i) {
      if (table.entries[i].second == name) throw "two values share a name";
    }
    table.entries[filled++] = {value, name};
  }
  return table;
}
```

## Header shape, worked: `src/Core/Tables/OOViewID.h`

```cpp
/*	OOViewID.h
	The player's view directions. (GPL banner as in the other headers.)
*/

#pragma once

#include <cstdint>
#include <string_view>

#include "OOEnumTable.h"

/*	std::int32_t: OOTypeEncodings.h encodes this type as "i", and the frozen
	ShipEntity/PlayerEntity layout encoding has 32-bit slots for it. The values
	would fit in less.

	The values are the ordinals the game has always used. OOViewID.tbl wrote
	other numbers (VIEW_CUSTOM 7, VIEW_NONE -1, …) that its macro discarded;
	the static_asserts below pin the real ones.
*/
enum class OOViewID : std::int32_t {
  kForward,
  kAft,
  kPort,
  kStarboard,
  kCustom,
  kNone,
  kGuiDisplay,
  kBreakPattern,
};

// What an unknown name becomes.
inline constexpr OOViewID kOOViewIDDefault = OOViewID::kNone;

/*	The one list of names: what scripts see (viewDirection). Written out, never
	derived from the identifier. No default, so -Wswitch reports a member added
	without a name, and the table below is derived from this function.
*/
constexpr std::string_view OOEnumName(OOViewID value) noexcept {
  switch (value) {
    case OOViewID::kForward:      return "VIEW_FORWARD";
    case OOViewID::kAft:          return "VIEW_AFT";
    case OOViewID::kPort:         return "VIEW_PORT";
    case OOViewID::kStarboard:    return "VIEW_STARBOARD";
    case OOViewID::kCustom:       return "VIEW_CUSTOM";
    case OOViewID::kNone:         return "VIEW_NONE";
    case OOViewID::kGuiDisplay:   return "VIEW_GUI_DISPLAY";
    case OOViewID::kBreakPattern: return "VIEW_BREAK_PATTERN";
  }
  return {};  // not a member
}

inline constexpr auto kOOViewIDTable =
    oo::MakeEnumTableInRange<OOViewID, 0, 7>();
static_assert(kOOViewIDTable.entries.size() == 8);

// Every number that leaves the program (external-values.md), pinned.
static_assert(static_cast<std::int32_t>(OOViewID::kForward) == 0);
// … one per member …
static_assert(static_cast<std::int32_t>(OOViewID::kBreakPattern) == 7);

/*	Compatibility: today's names, while call sites still use them. Temporary:
	spec 009's naming milestone qualifies the uses and deletes this block.
*/
inline constexpr OOViewID VIEW_FORWARD = OOViewID::kForward;
// … one per member …
inline constexpr OOViewID VIEW_BREAK_PATTERN = OOViewID::kBreakPattern;
```

(The aligned `case` lines are illustrative; the committed file is whatever clang-format 22 makes of
it.)

## Rules for all ten

- **One header per type**, named after it, in `src/Core/Tables` (already on the include path for the
  game and the unit tests; no build-file change). Includes: `<cstdint>`, `<string_view>`,
  `OOEnumTable.h`, nothing else. Self-contained.
- **Underlying type** `std::int32_t`, with the comment above.
- **Members** in the `.tbl` file's order, named by research R4's rule. A member whose `.tbl` value
  is honoured today keeps it written (`kInFlight = 100`); an ordinal type writes none.
- **Commented-out rows** (`GUI_SCREEN_CONTRACTS`, `kOOLegalStatusReasonThereCanBeOnlyOne`) stay
  commented out, as a commented member and a commented `case`.
- **Default**: `inline constexpr OO<Type> kOO<Type>Default = …;` with today's value, for the nine
  types that define one today (all but `OOBehaviour`, which has none and gets none).
- **`OOEnumName`**: exhaustive, no `default`, literal names equal to today's byte for byte: the
  stringified label for eight types; for `OOGalacticHyperspaceBehaviour`, the `.tbl` label without
  the pasted prefix (`"BEHAVIOUR_STANDARD"`); for `OOLegalStatusReason` and `OOShipDamageType`, the
  prose column (`"attacked police"`, `"scrape damage"`).
- **Table**: `inline constexpr auto kOO<Type>Table = oo::MakeEnumTableInRange<OO<Type>, Lo, Hi>();`
  with research R3's range, and a `static_assert` of its size.
- **Pins**: one `static_assert` per member's value; every row of
  `specs/009-modern-cpp-std/external-values.md` for the type is covered.
- **Extra constants** become typed `inline constexpr` beside the enum, not members:
  `GALACTIC_HYPERSPACE_MAX` (= `kFixedCoordinates`), with a comment naming its use
  (`PlayerEntity.cpp`'s range check).
- **Compatibility block**: one `inline constexpr` per old name, after everything else, under the
  comment above. Old names that the `.tbl` macro built by pasting
  (`GALACTIC_HYPERSPACE_BEHAVIOUR_STANDARD`) are spelled out.
- **Naming check**: the header passes `tools/check-enum-headers.sh` (research R6).

## Consumers

| file | today | after |
|---|---|---|
| `OOTypes.h`, `OOEntityEnums.h`, `ShipEntity.h` | `#define ENTRY …` + `typedef enum { #include …tbl }` + `enum { kOO…Default = … }` | `#include "OO<Type>.h"`; `OOEntityEnums.h` stays as a short umbrella of its five |
| `OOConstToString.cpp` | `switch` / `if` chains from `#include …tbl` | value-to-name: `name = kOO<Type>Table.name(value)`, `""` → the function's own fallback; name-to-value: `kOO<Type>Table.value(string).value_or(kOO<Type>Default)`; the `BEHAVIOR_` retry kept verbatim; the 9 + 6 signatures unchanged; the `ENTRY`/`GALACTIC_HYPERSPACE_ENTRY`/`DIFF_STRING_ENTRY` macros go |
| `OOConstToJSString.cpp`, `.h` | see [js-const-tables.md](js-const-tables.md) | |
| the ~61 lines research R2 lists | implicit `int` conversion | the variable, parameter or key takes the enum's type, or one explicit `static_cast` where a number is meant; meaning unchanged |
| `tests/unit/core/test_OOJSSound.cpp:33-40` | rebuilds `OOEntityStatus` from the `.tbl` | `#include "OOEntityStatus.h"` (ledger row) |
