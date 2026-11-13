# Contract: the OpenGL state items

`src/Core/OOOpenGLStateManager.cpp` after `OOOpenGLStates.tbl` is deleted. Research: R2. OpenGL
receives the same calls in the same order, and the debug verifier logs the same lines.

## The record

`OOOpenGLState` stays a struct with `std::string_view name`, then one field per item in the
`.tbl`'s order and type (`StateFlag` for flags, `bool` for client-array flags, the `ITEM_SPECIAL`
type for specials, `GLint` for integers), then `BLEND_SRC` and `BLEND_DST`. The field names stay
the GL enumerant names without `GL_`, so `kStandardStates`' designated initialisers do not change.

## The item table

```cpp
namespace {

// One tracked state item and what each step does with it.
struct StateItem {
  std::string_view name;  // the GL enumerant without GL_, as the verifier logs it
  GLenum cap;             // what glIsEnabled/glEnable/glGetIntegerv take; 0 for specials
#if OO_GL_STATE_VERIFICATION
  void (*read)(const StateItem&, OOOpenGLState&);
  bool (*equal)(const OOOpenGLState&, const OOOpenGLState&);
  // true, with the expected and current values as the log shows them, if the
  // verifier reports this item.
  bool (*mismatch)(const OOOpenGLState& expected, const OOOpenGLState& current,
                   std::string& shouldBe, std::string& is);
#endif
  void (*write)(const StateItem&, const OOOpenGLState& source, const OOOpenGLState& target);
};

// One builder per kind. Each takes, as template arguments, every function its
// kind needs, so an item cannot be listed without its field, read or write.
template <StateFlag OOOpenGLState::*Field> constexpr StateItem StateFlagItem(std::string_view, GLenum);
template <bool OOOpenGLState::*Field> constexpr StateItem ClientStateFlagItem(std::string_view, GLenum);
template <auto Field, auto Get, auto Set> constexpr StateItem SpecialItem(std::string_view);
template <GLint OOOpenGLState::*Field, auto Set> constexpr StateItem IntItem(std::string_view, GLenum);

// The 30 items, in OOOpenGLStates.tbl's order.
constexpr StateItem kStateItems[] = {
    StateFlagItem<&OOOpenGLState::LIGHTING>("LIGHTING", GL_LIGHTING),
    // …
    IntItem<&OOOpenGLState::FRONT_FACE, SetState_FRONT_FACE>("FRONT_FACE", GL_FRONT_FACE),
};

// The record is the name, one field per item, and the two blend fields.
static_assert(AggregateFieldCount<OOOpenGLState>() == 1 + std::size(kStateItems) + 2);

}  // namespace
```

`AggregateFieldCount` is local to this file. The `SetState_*` macros become functions with the
signatures the builders take. The `GetState_*` functions are compiled in every build, because
`SpecialItem` names them, and are called only under `OO_GL_STATE_VERIFICATION`.

## Behaviour (unchanged)

| step | flag | client-array flag | special | integer |
|---|---|---|---|---|
| read (debug) | `glIsEnabled` → `StateFlag` | `glIsEnabled` | `GetState_<NAME>()` | `glGetIntegerv` |
| equal (debug) | differ and neither is `kMaybe` | differ | differ | differ |
| log (debug) | if expected is not `kMaybe` and they differ: `GL_<NAME> should be {} but is {}.`, `ENABLED`/`disabled` | differ, `OOGLFlagToString` | differ, **`OOGLFlagToString`** (the quirk) | differ, `OOGLEnumToString` |
| write | differ and neither `kMaybe`: `glEnable`/`glDisable` | differ: `glEnableClientState`/`glDisableClientState` | differ: `SetState_<NAME>` | differ: `SetState_<NAME>` |

The blend function stays outside the table in every step:
- **Read:** two `glGetIntegerv` calls.
- **Compare and log:** one comparison, logged after the items as
  `GL blend mode should be {}, {} but is {}, {}.`
- **Write:** `glBlendFunc`, when either value differs or the source state's `BLEND` is
  `StateFlag::kFalse`.
