# Delete OOTypeEncodings.h

Status: **Tasks** (ready). Test edits signed off by Jon, 2026-11-15 (ledger below).

## Why

`oolite-dev/src/Core/OOTypeEncodings.h` (474 lines) is clang's Objective-C `@encode()` output, saved
on the last Objective-C++ build and kept by hand since. Upstream got these strings from the runtime
(`-[NSMethodSignature methodReturnType]`) to learn a method's return type. In the C++ port, the
by-name, `callObjC` and shader-binding tables carry them as type tags, and every consumer turns the
string straight back into a small enum. The pointer and container rows (`ShipEntity *`, `oo::PList`
and the others) spell out a class layout full of libstdc++ internals that is stale. Their only
visible effect is the text of a log line.

Replace the string tag with a compile-time enum, and delete the header.

## Done check

Run from `oolite-dev`. It exits nonzero before the change and zero after:

```bash
! test -e src/Core/OOTypeEncodings.h && ! git grep -qE 'kOOTypeEncoding|OOTypeEncodings\.h|OOShaderUniformTypeFromEncoding|OOObjCSelector' -- src tests
```

Also run `./mk.sh build dev`, `tests/run.sh unit` and `tests/run.sh component --cpp`. All must pass
with no new warnings.

## Design

### `src/Core/ValueType.h` (new, ~60 lines)

```cpp
namespace oo {

enum class ValueType : std::uint8_t {
  kVoid, kBool, kChar, kUChar, kShort, kUShort, kInt, kUInt, kLong, kULong,
  kLongLong, kULongLong, kFloat, kDouble,
  kVector, kHPVector, kQuaternion, kMatrix, kPoint, kRect, kBoundingBox,
  kColor,      // OOColor *
  kObject,     // the rows' "object result" (was keyed OOObjCId)
  kPList, kString, kOptionalString,
  kOther,      // any other pointer or container (ShipEntity *, std::vector<…> …)
};

struct ObjectResult;   // tag: a row whose result is an object (replaces OOObjCId)

template <class T> consteval ValueType ValueTypeOf();   // if constexpr chain
template <class T> inline constexpr ValueType kValueType = ValueTypeOf<T>();

}  // namespace oo
```

Rules for `oo::ValueTypeOf<T>`. They reproduce what the frozen strings did, so behaviour stays the
same:

- **Exact fundamental types:** match on the type itself, never on `sizeof`. `long long` is
  `kLongLong` on every platform.
- **Enums:** use the underlying type (`std::underlying_type_t`). Every game enum was encoded `"i"`,
  so it maps to `kInt`.
- **References and cv:** `const oo::PList &` maps to `kPList`, and `const std::string &` maps to
  `kString`.
- **Typedefs:** they resolve for free. `GLfloat` and `OOScalar` are `float`, `OOTimeDelta` is
  `double`, `size_t` is `unsigned long long` on Windows, and so on.
- **Pointers and containers:** `OOColor *` maps to `kColor`, `oo::ObjectResult` to `kObject`, and any
  other pointer or class type to `kOther`.
- **Unhandled types:** a type that hits none of these is a `static_assert` failure, the same
  "unmeasured type doesn't compile" rule as today.

### Consumers

| Where | Change |
|---|---|
| `Materials/OOShaderUniformMethodType.{h,cpp}` | Replace `OOShaderUniformTypeFromEncoding(const char*)` with `constexpr OOShaderUniformType oo::ShaderUniformTypeOf(oo::ValueType)`, a `switch`. `kBool` maps to Char (bool was `"c"`), `kObject` to Object, `kColor` to Color, `kLongLong`/`kULongLong`/`kRect`/`kOther`/`kVoid`/`kPList`/strings to Invalid. Delete `sTemplates`, `sInited`, `InitTemplates`. |
| `Entities/OOEntityCalledByName.h` | `OOEntityByNameRow::result`: `const char*` becomes `oo::ValueType`. |
| `Entities/OOEntityCalledByName.cpp` `ResultKind` | `switch` on `oo::ValueType`: void becomes kVoid, kPList becomes kPList, kObject becomes kObject, scalars (bool…double) become kVoid, everything else becomes kUnsupported. That is the same partition as today: the old scalar letter set `cCsSiIlLqQfdB` is exactly the fundamental arithmetic types. |
| `Entities/OOEntityCalledByName.cpp` `LogBadSignature` | Text becomes `"-[{} {}] has no signature a by-name call can use (returns {})."` with `oo::ValueTypeName(row.result)`. No test pins this tabled-row line. Line 856 (the unlisted-name path, `row->encoding` from `OOEntityObjectNamesTable.h`) is **unchanged**. Its short literals are pinned by `test_OOEntityCalledByName.cpp:143-162`. |
| `Scripting/OOJSCallEntityMethods.h` | The `encoding` field becomes `oo::ValueType type`. For non-Typed rows it is `kVoid`, where it used to be `nullptr`. |
| `Entities/EntityShaderBindings.cpp`, `Debug/OOJSConsole.cpp` | The row field becomes `oo::ValueType`. Pass it to `oo::ShaderUniformTypeOf`. |
| `Scripting/OOJSCall.cpp:107` | `oo::ShaderUniformTypeOf(row.type)`. |
| The table rows (~1,500) | Mechanical sed: `kOOTypeEncoding<OOObjCId>` becomes `oo::kValueType<oo::ObjectResult>`, then `kOOTypeEncoding<` becomes `oo::kValueType<`. Touch no other text in the rows. |
| `OOTypes.h:70,279`, `Tables/*.h` comments | `Encoded "i" (OOTypeEncodings.h)` becomes `an int to a by-name call (ValueType.h)`. |
| `meson.build` / header lists | Remove `OOTypeEncodings.h` if it is listed. Add `ValueType.h` to the headers self-containment test if there is one. |

Out of scope: deducing the type from each row's function with `decltype`, which would remove the
type column altogether. The 60 `OOObjCId` rows' functions return entity pointers, but the two
`ShipEntity *` rows are tagged `kOther`, so deducing would change behaviour. **Default:** keep the
declared column and list deduction as a follow-up.

## Steps

1. Add `ValueType.h` and `tests/unit/core/test_ValueType.cpp`. The test holds `static_assert`s
   for every type in the table below, plus a runtime check that `oo::ShaderUniformTypeOf` agrees with
   the old mapping. Write the test first: it fails to compile before the header exists. Register
   it in `tests/unit/meson.build`, following an existing core test.
2. Add `oo::ShaderUniformTypeOf(oo::ValueType)` next to the old function. Build.
3. Change the row struct field types, run the sed, and update the consumers. Build.
4. Edit the tests listed in the ledger. Run `tests/run.sh unit`.
5. Delete `OOTypeEncodings.h` and the old function. Fix the comments. Run the done check, the
   build, the unit tests and `component --cpp`.
6. Run clang-format 22 on the changed `src/` files only, never `tests/`. Commit in `oolite-dev` on a
   feature branch made with `git town append`.

Types the rows use today, which the `static_assert`s must cover: `void, bool, GLfloat, float,
double, int, unsigned, GLint, uint8_t, uint32_t, std::size_t, std::ptrdiff_t, Vector, HPVector,
Quaternion, OOMatrix, NSPoint, BoundingBox, OOColor *, oo::PList, std::optional<std::string>,
oo::ObjectResult, ShipEntity *, OOHUDBeaconIcon *, std::vector<oo::EntityHold> *,
std::vector<std::shared_ptr<OOTexture>>`, the `OO*Quantity`/`OO*ID` typedefs, and every game enum
listed in the old header.

## Test-change ledger (signed off: Jon, 2026-11-15)

Every edit keeps each assertion's meaning except where stated. Fill in the commit once it lands.

| File | Edit | Assertion meaning |
|---|---|---|
| `tests/unit/core/test_OOShaderUniformMethodType.cpp` | `TypeOf<T>()` becomes `oo::ShaderUniformTypeOf(oo::kValueType<T>)`. `TypeOf<OOObjCId>` becomes `TypeOf<oo::ObjectResult>`. Drop the `#include "OOTypeEncodings.h"` and add `#include "ValueType.h"`. Update the header comment. | Same, for all 21 type checks. |
| same | Remove `OO_CHECK(OOShaderUniformTypeFromEncoding(NULL) == kOOShaderUniformTypeInvalid)`. | **Removed:** a null string no longer exists. Replaced by `oo::ShaderUniformTypeOf(oo::ValueType::kOther) == kOOShaderUniformTypeInvalid`. |
| `tests/unit/core/test_OOJSCallEntityMethods.cpp:58-70,120,177` | Replace `strcmp(row.result, kOOTypeEncoding<void>)` with `row.result == oo::ValueType::kVoid`, and the PList comparison the same way. `OOShaderUniformTypeFromEncoding(x)` becomes `oo::ShaderUniformTypeOf(x)`. `entry.encoding` becomes `entry.type`. | Same. |
| `tests/unit/core/test_OOJSConsole.cpp:363` | The stub `OOShaderUniformTypeFromEncoding(const char*)` becomes a stub of `oo::ShaderUniformTypeOf(oo::ValueType)`, if the linker still needs one. Otherwise delete it. | Not an assertion. |

| `tests/unit/core/test_OOJSCallEntityMethods.cpp:149` | `(row.encoding != nullptr)` becomes `(row.type != oo::ValueType::kVoid)`. Not listed above; it reads the renamed field. No Typed row has a void type, so the two agree on every row. | Same. |

Commit: oolite-dev 5ae4cb9e0 (2026-11-15).

## Decisions (defaults taken)

- **Exact-type mapping, not `sizeof`.** This keeps `long long` mapping to Invalid, as the test pins.
  On Linux/macOS (LP64), `size_t` becomes `unsigned long`, so it maps to UnsignedLong where the
  frozen `"Q"` gave Invalid. That matches what upstream did on LP64, where `size_t` and
  `unsigned long` were both `"Q"`. Record this in the parity notes when the Linux port picks it up.
- **The tabled-row log line names the kind** instead of an encoding. It is the port's own line, not
  upstream's, and no test pins it.
- **`OOEntityObjectNamesTable.h`'s frame-offset literals stay.** They are separate, short and pinned.
- **The `OOJSConsole.cpp` ivar-encoding byte trick (test line 366) stays.** It is a separate
  mechanism.
- **No Spec Kit spec.** This is one `0_AI_Tasks` item. Promote it to `specs/016-…` if it grows past
  the steps above.
- **Enums map to `kInt`, not through their underlying type** (done, 5ae4cb9e0). The design above says to use
  `std::underlying_type_t`, but `OOWeaponFacing` is a `std::uint8_t` enum that was encoded `"i"`, so
  the underlying type would have moved it from Int to UnsignedChar. Every enum is `kInt`, as every
  enum's string was.
- **`tests/run.sh component --cpp` not run.** This branch (`seriesb/032-cleanup`) has no
  `tests/component-cpp` tier. The done check, the build (no warnings) and `tests/run.sh unit`
  (191 core tests, `test_ValueType` among them) passed.
- **Another session's uncommitted one-line edit to `OOTypeEncodings.h`** (it dropped the
  `// clang-format off` line) went with the file.
