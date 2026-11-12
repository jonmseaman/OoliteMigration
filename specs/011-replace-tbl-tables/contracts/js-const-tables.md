# Contract: the script engine's name tables (Story 1)

`src/Core/Scripting/OOConstToJSString.cpp` and `.h` after the change. Research: R5. Scripts see
the same strings and numbers as on `develop`.

## Data

```cpp
// One row the script side sees: the value as a plain int32_t, so one ConstTable
// type serves every enum.
struct ConstRow {
  std::int32_t value;
  std::string_view name;  // a string literal from the enum's OOEnumName: NUL-terminated
};

struct ConstTable {
  std::span<const ConstRow> rows;          // ascending by value
  std::span<ooscript::String> strings;     // rows[i]'s interned name, filled by InitTable()
};
```

For each of the nine enums that have a table today (`OOCompassMode`, `OOEntityStatus`,
`OOGalacticHyperspaceBehaviour`, `OOGUIScreenID`, `OOScanClass`, `OOViewID`, `OOShipDamageType`,
`OOLegalStatusReason`, `OOLongRangeChartMode`):

```cpp
constexpr auto kOOScanClassRows = ToConstRows(kOOScanClassTable);   // std::array<ConstRow, N>
static_assert(IsAscending(kOOScanClassRows));
std::array<ooscript::String, kOOScanClassRows.size()> sOOScanClassStrings;
ConstTable gOOScanClassConstTable{kOOScanClassRows, sOOScanClassStrings};
```

`ToConstRows` and `IsAscending` are `constexpr` helpers local to the `.cpp`. The global names
`gOO<Type>ConstTable` are unchanged, so the header's `extern` declarations stand.
`gOOLongRangeChartModeConstTable` is built and initialised but has no accessor, as today; a
comment says so.

## Behaviour

- `InitTable(context, table)` interns `rows[i].name.data()` into `strings[i]` for every row. No
  sort: the rows are ascending by construction, and the `static_assert` holds it.
- `OOConstToJSStringInit`/`Destroy`, `sInited`, `sUndefinedString` and the init order are
  unchanged; a reset re-interns, as now.
- `OOJSStringFromConstantPRIVATE` keeps its binary search, reading `rows[mid].value` and returning
  `strings[mid]`, or `"UNDEFINED"`. The search's unsigned-wrap fault for a value below the smallest
  (research R5) is left as it is and listed for Jon.
- `OOConstantFromJSStringPRIVATE` keeps both passes (pointer-equal, then string compare) over
  `strings`, returning `rows[i].value`, or the default.
- The private functions keep their `NSInteger`/`NSUInteger` signatures. The inline wrappers in
  `OOConstToJSString.h` convert explicitly: `static_cast<NSInteger>(value)` going in,
  `static_cast<OO<Type>>(…)` coming out, and the default passed as
  `static_cast<NSInteger>(kOO<Type>Default)`.
- The `ENTRY`/`GALACTIC_HYPERSPACE_ENTRY`/`DIFF_STRING_ENTRY` macros, `TableEntry`, `TABLE`,
  `CompareEntries` and the `qsort` call are removed.
