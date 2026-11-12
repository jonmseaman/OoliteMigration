# Contract: the OpenGL state items (Story 3)

`src/Core/OOOpenGLStateManager.cpp` after `OOOpenGLStates.tbl` is deleted. Research: R7. OpenGL
receives the same calls in the same order, and the debug verifier logs the same lines.

## The record

`OOOpenGLState` stays a struct with `const char* name`, one field per item in today's order and
type (`StateFlag` for flags, `bool` for client-array flags, the `ITEM_SPECIAL` type for specials,
`GLint` for integers), then `BLEND_SRC` and `BLEND_DST`. The field names stay the GL enumerant
names without `GL_` (`LIGHTING`, `DEPTH_WRITEMASK`), so `kStandardStates`' designated initialisers
are unchanged, line for line.

## The item table

```cpp
namespace {

enum class ItemKind { kStateFlag, kClientStateFlag, kSpecial, kInt };

// One tracked state item. Built only through the four functions below, which
// take every argument their kind needs, so an item cannot be listed without
// its read or its write.
struct StateItem { /* kind, log name, GL enumerant, field, and per kind: getter, setter */ };

constexpr StateItem StateFlagItem(const char* name, GLenum cap, StateFlag OOOpenGLState::*field);
constexpr StateItem ClientStateFlagItem(const char* name, GLenum array, bool OOOpenGLState::*field);
constexpr StateItem IntItem(const char* name, GLenum query, GLint OOOpenGLState::*field,
                            void (*set)(GLint));
template <class T>
constexpr StateItem SpecialItem(const char* name, T OOOpenGLState::*field,
                                T (*get)(), void (*set)(T));

// The 30 items, in OOOpenGLStates.tbl's order. The log prints mismatches in
// this order.
constexpr StateItem kStateItems[] = {
    StateFlagItem("LIGHTING", GL_LIGHTING, &OOOpenGLState::LIGHTING),
    // …
    IntItem("FRONT_FACE", GL_FRONT_FACE, &OOOpenGLState::FRONT_FACE, SetState_FRONT_FACE),
};

// A field without an item, or an item without a field, fails here:
// the record is the name, one field per item, and the two blend fields.
static_assert(AggregateFieldCount<OOOpenGLState>() == 1 + std::size(kStateItems) + 2);

}  // namespace
```

How `StateItem` stores its field pointer and functions across kinds (a `std::variant` of
per-kind structs, or per-kind arrays) is the implementer's choice, provided the four builders, the
order and the `static_assert` hold. `AggregateFieldCount` is the aggregate-initialisation count
(research R7), local to this file. The `SetState_*` macros become functions with the signatures
the builders take; `GetState_*` stay debug-only, and the getter argument is passed only under
`OO_GL_STATE_VERIFICATION`.

## Behaviour (unchanged)

| step | flag | client-array flag | special | integer |
|---|---|---|---|---|
| read (debug) | `glIsEnabled` → `StateFlag` | `glIsEnabled` | `GetState_<NAME>()` | `glGetIntegerv` |
| equal (debug) | differ and neither is `kStateMaybe` | differ | differ | differ |
| log (debug) | if expected is not maybe: `GL_<NAME> should be {} but is {}.` via `OOGLFlagToString` | same, `OOGLFlagToString` | same, **`OOGLFlagToString`** (today's quirk: the `.tbl`'s display column is ignored) | same, `OOGLEnumToString` |
| write | differ and neither maybe: `glEnable`/`glDisable` | differ: `glEnableClientState`/`glDisableClientState` | differ: `SetState_<NAME>` | differ: `SetState_<NAME>` |

The blend function stays outside the table in every step: read with two `glGetIntegerv`, compared
and logged as `GL blend mode should be {}, {} but is {}, {}.`, and written with `glBlendFunc` when
either value differs or the source state's `BLEND` is `kStateFalse` (`!sourceState->BLEND`; a
`kStateMaybe` source does not force it). The design-notes comment
at the top of the file is rewritten to describe the table instead of the `.tbl`.
