# Data model: Replace the `.tbl` tables

The things the plan moves around, their fields and the rules that hold for them. Contracts:
[enum-header.md](contracts/enum-header.md), [js-const-tables.md](contracts/js-const-tables.md),
[gl-state-items.md](contracts/gl-state-items.md).

## Named enum

| field | rule |
|---|---|
| type name | upstream's (`OOScanClass`), unchanged |
| underlying type | `std::int32_t` |
| members | the `.tbl` rows in order, named by research R4's rule |
| value per member | the program's value on `develop` (`external-values.md`), never a fictional `.tbl` column |
| name per member | today's string, byte for byte |
| default | today's `kOO<Type>Default`, typed; none for `OOBehaviour` |
| range | research R3's `[Lo, Hi]`, covering every value |
| directions | value → name for all ten; name → value only for the six that have it today |
| fallback (value → name) | `** BEHAVIOUR UNKNOWN **` for `OOBehaviour`, `UNDEFINED` for the rest |

Rules: every member has exactly one name (`-Wswitch`, and `-Werror=switch` in
`tools/check-enum-headers.sh`); no two members share a name (the table builder); the table's size
equals the member count (`static_assert`); every value that leaves the program is pinned
(`static_assert`).

## Conversion group (one change, one commit or a short series)

Groups follow spec 009's T060–T063 so that its acceptance commands apply unchanged.

| group | tables | consumers touched | R2 call-site lines |
|---|---|---|---:|
| G1 | `OOScanClass`, `OOEntityStatus`, `OOShipDamageType` | `OOEntityEnums.h`, `OOConstToString.cpp`, `OOConstToJSString.*`, `test_OOJSSound.cpp` | 34 |
| G2 | `OOBehaviour`, `OOGalacticHyperspaceBehaviour`, `OOLegalStatusReason` | `ShipEntity.h`, `OOEntityEnums.h`, `OOTypes.h`, `OOConstToString.cpp`, `OOConstToJSString.*` | 1 |
| G3 | `OOCompassMode`, `OOViewID` | `OOTypes.h`, `OOConstToString.cpp`, `OOConstToJSString.*` | 9 |
| G4 | `OOLongRangeChartMode`, `OOGUIScreenID` | `OOTypes.h`, `OOEntityEnums.h`, `OOConstToString.cpp`, `OOConstToJSString.*` | 17 |
| G5 | `OOOpenGLStates` | `OOOpenGLStateManager.cpp` | — |

The first group to touch `OOConstToJSString.*` moves the whole file to the
[js-const-tables.md](contracts/js-const-tables.md) shape; until a type's group lands, its rows
come from a temporary `constexpr` row array beside it, written from today's `.tbl` (the
program's values) and deleted by that type's group. Each group's lines outside its consumers are
exactly R2's list for its types, plus any a non-Windows build adds.

## Compatibility alias

`inline constexpr OO<Type> <OLD_NAME> = OO<Type>::k<New>;` one per old member name, in the
header's last block, marked temporary. Lifetime: until spec 009's naming milestone qualifies the
uses. Not a member: the naming check does not apply to it.

## OpenGL state item

| field | values |
|---|---|
| kind | flag, client-array flag, special, integer |
| log name | the GL enumerant without `GL_` |
| GL enumerant | flags, client flags and integers |
| field | a member of `OOOpenGLState` of the kind's type |
| getter | specials only, debug only |
| setter | specials and integers |

Rules: 30 items in today's order; the record has exactly `1 + 30 + 2` fields (`static_assert`);
flags may be `kStateMaybe` in a standard state, client flags may not.

## Test-change ledger (`test-ledger.md`, created in the commit that needs it)

Same columns as `specs/009-modern-cpp-std/test-ledger.md`:

| test file | lines | forced by | assertions | coverage | commit | signed |
|---|---|---|---|---|---|---|

Expected content: one row, `tests/unit/core/test_OOJSSound.cpp`, lines 37–42, forced by
`OOEntityStatus.tbl` → `OOEntityStatus.h`, assertions unchanged, coverage *covered* (rule 1's third
exception). Any other row stops the work that needs it and is reported.
