# Data model: Modern C++ on the standard library

The records this feature keeps, from the spec's *Key Entities*. Two are files created in M0 in this
directory (`exceptions.md`, `test-ledger.md`); the others are tables kept in those files or in this
one as the work proceeds.

## Converted category

A pattern the feature removes. One row per category, kept here and updated at each milestone gate.

| Field | Meaning |
|---|---|
| id | `alloc`, `ownership`, `thread`, `oofnd`, `enum`, `macro-set`, `tbl`, `naming` |
| search | the command that counts it (below); fails a bead's acceptance before, passes after |
| guard | the clang-tidy check, or "definition deleted" ([contracts/guards.md](contracts/guards.md)) |
| before | the search's line count on the base, `518520d43`, measured 2026-11-11 |
| now | the count at the last gate |
| state | `open` → `zero` (search finds only exceptions) → `fatal` (guard in `WarningsAsErrors`, or definition deleted) |

Searches, run from `oolite-dev` (`SRC` = `src/Core src/SDL src/oofnd`, excluding vendored code):

```bash
EXCL=(--glob '!src/Core/MiniZip/**' --glob '!src/SDL/EXRSnapshotSupport/**' --glob '!**/stb_*')
rg -n -P '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(' src "${EXCL[@]}"                  # alloc
rg -n -P '\b(RefCounted|oo::Ref\b|oo::WeakRef|makeRef|leakRef|adopt\s*\()' src "${EXCL[@]}"          # ownership
rg -n 'oo::thread::(detach|isMainThread)' src                                                         # thread
rg -n -P 'oo::(Expected|Unexpected)\b|\bNS(U?Integer|NotFound|TimeInterval)\b|\bCGFloat\b|oofnd/StdLib\.hpp' src \
   --glob '!src/Core/OOTypeEncodings.h' --glob '!src/Core/Entities/OOEntityObjectNamesTable.h'        # oofnd
rg -n -P '^\s*(typedef\s+)?enum\b(?!\s+class\b)' src "${EXCL[@]}"                                     # enum
ls src/Core/Tables/*.tbl                                                                             # tbl: only OOOpenGLStates.tbl
./mk.sh tidy 2>&1 | grep -c 'google-readability-casting'                                              # cast
rg -n -P '\b(str(n?cpy|n?cat|n?cmp|casecmp|len|dup|r?chr|str|tok)|v?s?n?printf|ato[if]|strto[ld])\s*\(' src "${EXCL[@]}"   # cstring calls
rg -n -P '\bconst\s+char\s*\*|\bchar\s+\w+\s*\[' src "${EXCL[@]}"                                       # cstring types (tracked)
```

Macro sets (research R8 §5), each with its own negated search once converted: the GUI row sets in
`PlayerEntityKeyMapper.h:42-65`, `PlayerEntityContracts.h:59`, `PlayerEntityStickMapper.h:40-51`,
`PlayerEntityStickProfile.cpp:38` and `PlayerEntityLoadSave.h:42-52`; `CUBE_FACE_*`
(`OOVoxel.h:37-42`); `HW_AXIS`/`HW_BUTTON` (`OOJoystickManager.h:157`); `STICKPROFILE_TYPE_*`
(`OOJoystickProfile.h:44`); `DEBUG_ALL` and `VALID_WEAPON_FACINGS` with their flag enums. The 23
`kOOTCPPacket_*` string defines are strings, not an enumeration, and stay.

The two excluded files in the `oofnd` search hold frozen type-encoding strings that contain those
names as text (research R7); they are data and are not changed.

| id | before | guard | fatal at |
|---|---:|---|---|
| alloc | 135 lines | `cppcoreguidelines-no-malloc` | M1 |
| ownership | 2,007 lines | definition deleted | M7 |
| thread | 7 lines (5 calls, 2 definitions) | definition deleted | M2 |
| oofnd | 1,505 lines (including `oofnd`'s own definitions) | definition deleted | M3 |
| enum | 179 lines | `cppcoreguidelines-use-enum-class` | M4 |
| macro-set | about 10 sets (listed below) | one search per set | M4 |
| tbl | 11 files | (file count) | M4 |
| naming | 0 converted | `readability-identifier-naming` | M8 |
| cast | the `google-readability-casting` count in M0's `./mk.sh tidy` (regex: about 690 lines) | `google-readability-casting`; `-Wold-style-cast` | M5 |
| cstring | 66 call lines by the search (2026-11-11); 815 `const char*` and `char[N]` lines tracked | `bugprone-unsafe-functions.CustomFunctions` | M6 |

## Exceptions list (`exceptions.md`)

The places a converted pattern may remain (FR-022).

| Field | Meaning |
|---|---|
| file:line | where it is |
| category | a converted-category id |
| construct | what stays (`free` in the demangling deleter, an immortal singleton, a QuickJS flag constant, …) |
| required by | the interface or rule that forces it (`abi::__cxa_demangle` returns `malloc` memory; FR-005; QuickJS `prop_flags` is `uint8_t`; tested by `#if`) |
| owner / release | for ownership crossings: who owns it and where it is released |
| commit | the commit that added the row |

Rules: a row is added in the same commit as the code it permits. A row whose construct the guard
flags is a conflict to record here, never a suppression. Expected rows (research): the demangling
helper; about 25 `oo::Immortal` singletons; the script slot's heap `shared_ptr`; JS vector and
quaternion data under their finaliser (if kept as `new`/`delete`); `OOJS_PROP_*`; the debug
protocol numbers if D5 keeps them; `GameViewKeys` and `OOPixMapFormat` if D5 keeps them as
constants; feature macros tested by `#if`.

## Test-change ledger (`test-ledger.md`)

Every test file edited, in the commit that edits it (FR-015).

| Field | Meaning |
|---|---|
| test file | path under `tests/` |
| lines | the edited lines, or "throughout" with a count |
| forced by | the replaced name, header or construction form (`oo::Ref<T>` → `std::shared_ptr<T>`, `retainCount()` → `use_count()`, `#include "oofnd/Ref.hpp"` → `<memory>` and `oofnd/Object.hpp`, `CLASS_NEUTRAL` → `OOScanClass::kNeutral`) |
| assertions | `unchanged`, or `changed: <what>` |
| coverage | `covered` (rule 1's third exception), `borderline` (construction form), `needs sign-off` (an assertion's meaning changes, or a rename the exception does not plainly cover) |
| commit | the commit |
| signed | Jon's sign-off date, for `borderline` and `needs sign-off` rows |

State of a row: `committed` (for `covered`); `waiting` → `signed` or `declined` (for the others).
A `needs sign-off` row is written *before* its change and the change waits (plan.md *Notes*). A
`declined` row means the change it belongs to is replanned; the test is never edited further.

Rows known now (research R9): `test_ref.cpp:514` (*needs sign-off*); the stack and static
instances in `test_OOShaderMaterial.cpp:309,501,588`, `test_OODebugMonitor.cpp:780`,
`test_ref.cpp:35` (*borderline*); the P10 renames of existing `enum class` enumerators (*needs
sign-off*); `test_stdlib` and any `test_foundation_types` assertion with no counterpart
(*reported*, no edit).

## External names and values

Every name or number that leaves the program, written down before its enum or format is changed
(FR-018, research R8 and R7). Kept in `external-values.md` in this directory, created at the start
of M4.

| Field | Meaning |
|---|---|
| enum or format | the type or the call |
| value | the program's value today (from the code, not a `.tbl` column) |
| external form | the exact string or number |
| where visible | script, property list, saved game, preferences, description key, shader, wire, log, console |
| pin | the `static_assert` or test that fails if it changes |

## Surviving `oofnd` component

What stays in `oofnd`, kept in `src/oofnd/README.md` (FR-014).

| Field | Meaning |
|---|---|
| component | header and the functions that stay |
| reason | no standard equivalent, or the named difference in answers (for example "`hasPrefix("")` is false; `starts_with("")` is true") |
| pinned by | the test that checks the difference |

From research R7: `Data`, `String` helpers, the GNUstep parts of `FileSystem` and `Date`,
`Exception` and `Finally`, `NSRange`/`NSPoint`/`NSSize`/`NSRect`, `PrintfFormat.h` and the printf
path, `Notification`, `Scanner`, `Process`, `Log`/`LogFile`, `Http`, `Defaults`, `ResourcePaths`,
`Encoding`, `PList*`, `OOAssert`, `Thread`'s naming and priority, `AutoreleaseScope`, `WeakSet`,
`Object`.

## Disposal reader

Code that reads a weak reference to an entity while it is being disposed (FR-007, research R5).
Found by design step D2, kept in this file.

| Field | Meaning |
|---|---|
| function | the reader (`Universe::clearBeacon`, …) |
| reached from | the `willDispose`/`willDealloc` path that calls it |
| reads | the weak reference and what it compares or dereferences |
| test | the test that pins its effect, passing on the base before the bridge |
| fix | `before release` (the work moves to the owner's removal path) or `identity` (the field keeps its identity pointer beside the `std::weak_ptr`) |

Known before D2: `ensureEntityReallyRemoved` → `clearBeacon` (`firstBeacon() == beacon`); the
Player, Station and Dock `willDealloc` paths (`Entity.cpp:96-137`, including the two
`dropWeakReferences()` calls at `:111,136`). Open: whether any script event is sent from
`willDispose()`.
