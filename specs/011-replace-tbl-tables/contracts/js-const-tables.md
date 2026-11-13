# Contract: the script engine's name tables (Story 1)

`src/Core/Scripting/OOConstToJSString.cpp` and `.h` after the change, on
`seriesb/026-migration-completion` (QuickJS-ng API). Research: R5. Scripts see the same strings
and numbers as on the base.

## Data

```cpp
// One row the script side sees: the value as a plain int32_t, so one ConstTable
// type serves every enum.
struct ConstRow {
  std::int32_t value;
  std::string_view name;  // from the enum's OOEnumName
};

struct ConstTable {
  std::span<const ConstRow> rows;  // ascending by value, constexpr
  std::span<JSAtom> atoms;         // rows[i]'s atom, filled by InitTable() once per process
};
```

For each of the nine enums that have a table today (`OOCompassMode`, `OOEntityStatus`,
`OOGalacticHyperspaceBehaviour`, `OOGUIScreenID`, `OOScanClass`, `OOViewID`, `OOShipDamageType`,
`OOLegalStatusReason`, `OOLongRangeChartMode`):

```cpp
constexpr auto kOOScanClassRows = ToConstRows(kOOScanClassTable);   // std::array<ConstRow, N>
static_assert(IsAscending(kOOScanClassRows));
std::array<JSAtom, kOOScanClassRows.size()> sOOScanClassAtoms;
ConstTable gOOScanClassConstTable{kOOScanClassRows, sOOScanClassAtoms};
```

`ToConstRows` and `IsAscending` are `constexpr` helpers local to the `.cpp`. The global names
`gOO<Type>ConstTable` are unchanged, so the header's `extern` declarations stand.
`gOOLongRangeChartModeConstTable` is built and interned but has no accessor, as today; a comment
says so.

Until a type's conversion group lands (data-model.md), its rows come from a temporary
`constexpr std::array<ConstRow, N>` written beside it from today's `.tbl` with the program's
values, deleted by that group.

## Behaviour

- `InitTable(context, table)` sets `atoms[i] = JS_NewAtomLen(context, rows[i].name.data(),
  rows[i].name.size())` for every row. No sort: the rows are ascending by construction, and the
  `static_assert` holds it.
- `OOConstToJSStringInit`/`Destroy`, `sInited`, `sAtomsInterned` (intern once per process),
  `sUndefinedAtom` and the init order are unchanged.
- `OOJSValueFromConstantPRIVATE` keeps its signed binary search, reading `rows[mid].value` and
  returning `JS_AtomToString(context, atoms[mid])`, or the `UNDEFINED` atom's string.
- `OOConstantFromJSValuePRIVATE` keeps its logic: not a string → default; `JS_ValueToAtom`, on
  failure clear the exception and return the default; scan `atoms` for an equal atom and return
  `rows[i].value`; `JS_FreeAtom` the looked-up atom.
- The private functions keep their `NSInteger`/`NSUInteger` signatures. The inline wrappers in
  `OOConstToJSString.h` convert explicitly: `static_cast<NSInteger>(value)` going in,
  `static_cast<OO<Type>>(…)` coming out, and the default passed as
  `static_cast<NSInteger>(kOO<Type>Default)`.
- The `ENTRY`/`GALACTIC_HYPERSPACE_ENTRY`/`DIFF_STRING_ENTRY` macros, `TableEntry`, `TABLE`,
  `CompareEntries` and the `qsort` call are removed.
