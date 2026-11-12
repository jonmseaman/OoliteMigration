# Contract: enums (US5, M4 and M8)

The helpers design step D3 adds, and the shape every converted enum header takes. Research: R8.

## `src/Core/OOEnumFlags.h`

```cpp
#pragma once
#include <concepts>
#include <type_traits>
#include <utility>

namespace oo {

template <class E>
  requires std::is_enum_v<E>
constexpr std::underlying_type_t<E> ToUnderlying(E e) noexcept {
  return static_cast<std::underlying_type_t<E>>(e);
}

// A flag enum opts in by declaring, in its own namespace:
//   constexpr std::true_type OOEnableFlagOperators(MyFlags);
template <class E>
concept FlagEnum = std::is_enum_v<E> && requires(E e) {
  { OOEnableFlagOperators(e) } -> std::same_as<std::true_type>;
};

template <FlagEnum E>
constexpr bool Any(E v) noexcept { return ToUnderlying(v) != 0; }

}  // namespace oo

template <oo::FlagEnum E> constexpr E operator|(E a, E b) noexcept { return static_cast<E>(oo::ToUnderlying(a) | oo::ToUnderlying(b)); }
template <oo::FlagEnum E> constexpr E operator&(E a, E b) noexcept { return static_cast<E>(oo::ToUnderlying(a) & oo::ToUnderlying(b)); }
template <oo::FlagEnum E> constexpr E operator^(E a, E b) noexcept { return static_cast<E>(oo::ToUnderlying(a) ^ oo::ToUnderlying(b)); }
template <oo::FlagEnum E> constexpr E operator~(E a) noexcept { return static_cast<E>(~oo::ToUnderlying(a)); }
template <oo::FlagEnum E> constexpr E& operator|=(E& a, E b) noexcept { return a = a | b; }
template <oo::FlagEnum E> constexpr E& operator&=(E& a, E b) noexcept { return a = a & b; }
template <oo::FlagEnum E> constexpr E& operator^=(E& a, E b) noexcept { return a = a ^ b; }
```

D3 checked the risk that global operator templates are not found from inside `namespace oo`
(R8). Answer: for a flag enum declared in the global namespace (every game enum) they are always
found, because argument-dependent lookup searches the enum's own namespace, the global one, even
where `namespace oo` declares an unrelated `operator|`. `tests/unit/core/test_OOEnumFlags.cpp`
pins this with a `constexpr` `|` inside `namespace oo` beside such an operator. A flag enum
declared inside a namespace would be found only by ordinary lookup, which stops at the first
enclosing namespace that declares that operator; that namespace adds `using ::operator|;` and the
others.

## `src/Core/OOEnumTable.h`

The name table for an enum that has external names, following `notes/2026-11-07 Enum Tables from
tbl X-Macros.md`:

```cpp
namespace oo {

template <class E, std::size_t N>
struct EnumTable {
  std::array<std::pair<E, std::string_view>, N> entries;
  constexpr std::string_view name(E e) const noexcept;               // "" if absent
  constexpr std::optional<E> value(std::string_view name) const noexcept;  // exact, case-sensitive
};

// Builds the table from an enum's OOEnumName switch over the listed values.
template <class E, E... Values>
constexpr EnumTable<E, sizeof...(Values)> MakeEnumTable() noexcept;

}  // namespace oo
```

## The shape of a converted enum header

Exemplar: `src/Core/Debug/OODebugFlags.h` (D3). A flag enum's bit test reads through a named
helper where that is clearer (`OODebugFlagIsOn(OODebugFlags::kCollisions)`). Every converted named enum follows it:

```cpp
enum class OODebugFlags : std::uint32_t {
  kNone = 0,
  kLinkedLists = 0x1,
  // …
  kMisc = 0x10000000,
  kAll = 0xffffffff,
};
constexpr std::true_type OOEnableFlagOperators(OODebugFlags);   // flag enums only

// The external spelling, written out: never derived from the identifier.
constexpr std::string_view OOEnumName(OODebugFlags f) noexcept {
  switch (f) {
    case OODebugFlags::kLinkedLists: return "DEBUG_LINKED_LISTS";
    // …
    case OODebugFlags::kNone:
    case OODebugFlags::kAll: return {};
  }
  return {};
}

// Every number that leaves the program, pinned.
static_assert(oo::ToUnderlying(OODebugFlags::kLinkedLists) == 0x1);
static_assert(oo::ToUnderlying(OODebugFlags::kMisc) == 0x10000000);
```

Rules:

- The underlying type is explicit. Types listed in `OOTypeEncodings.h:83-127` (the `"i"`
  encodings) use `std::int32_t`. Others use the narrowest type their storage already uses
  (`OOWeaponFacingSet` `std::uint8_t`, `OOAlertFlags` `std::uint16_t`, …).
- Enumerators are `kPascalCase`. The type name stays upstream's.
- A value enum with external names has an `OOEnumName` switch and, if it is read back, an
  `oo::MakeEnumTable`. The `.tbl` value column is ignored where it is fiction (`OOViewID`,
  `OOLongRangeChartMode`, `OOGUIScreenID`); the program's ordinals win and are `static_assert`ed.
- A default value (`kOOViewIDDefault` and similar) is a `constexpr` of the enum type beside it.
- Sentinels (`_COUNT`, `_END`, `_MAX`) become `constexpr std::size_t kFooCount` beside the enum, not
  enumerators, and arrays indexed by the enum are `std::array<T, kFooCount>` indexed through
  `oo::ToUnderlying`.
- A lone constant in an anonymous enum becomes `inline constexpr` of its natural type (FR-017):
  `inline constexpr` in a header, `constexpr` in a `.cpp` or a block, `static constexpr` in a class.
  The natural type is the one its uses need: `int` where it meets ints, the stored type where it is
  stored, the enum type for a default. A constant used only under a guard is declared under it.
- Test stand-ins that redeclare a production enum change in the same commit as it.

## External values

Every name and number in research R8's visibility table is listed in `data-model.md` *External
names and values* before its enum is converted, with the test or `static_assert` that pins it.
