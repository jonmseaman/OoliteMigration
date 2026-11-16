# One by-name table built from member pointers

Status: **Prepare**. The two test edits are signed off (Jon, 2026-11-15; see the ledger).

## Why

Upstream called entity methods by a name held in data, using the Objective-C runtime. The C++ port
froze that into three hand-kept tables, about 4,850 lines, that mostly restate what the compiler
already knows:

| File | Lines | Contents |
|---|---:|---|
| `src/Core/Entities/OOEntityCalledByNameTable.h` | 3,006 | 965 names. For each, a wrapper `ByName_N(Entity*, …)` and a row: name, `OOByName` applies-to flags, `oo::kValueType<T>` of the result, `OOEntityByNameArgument`, and two adaptor pointers to the wrapper. 947 of the 949 wrapper bodies are "find the part, call its member, else return a default". |
| `src/Core/Scripting/OOJSCallEntityMethods.h` | 1,054 | 1,002 rows: how the debug console's `callObjC()` may call each name (`OOJSCallEntityMethodForm` plus the result's `ValueType`). 913 are by-name rows restated. The rest come from `OOEntityCalledByName.cpp`'s 89 facade rows. |
| `src/Core/Entities/OOEntityObjectNamesTable.h` | 793 | Every other method name of the old Objective-C classes. It exists only so an uncallable name logs upstream's exact text ("does not respond", or "has no signature … (type encoding v24@0:8@16)"). |

**Who calls by name:**
- AI state machines (`AI.cpp`), limited to `whitelist.plist`'s `ai_methods` and
  `ai_and_action_methods`;
- legacy plist scripts (`PlayerEntityLegacyScriptEngine.cpp`);
- `[selector]` keys in description text (`OOStringExpander.cpp`);
- deferred calls (`OOCallByName.h`);
- the debug console's `callObjC()` (`Scripting/OOJSCall.cpp`).

Expansion JavaScript doesn't use these tables. Only **318** of the 965 names are on the whitelist.
The rest are reachable only from `callObjC()`.

Shader bindings (`EntityShaderBindings.cpp`) and HUD dials have their own tables and are out of
scope.

## Design

**One table, one line per name, in `namespace oo`.**

```cpp
// src/Core/Entities/EntityByName.h (new) — the row and the Call<> template
namespace oo {
struct EntityByNameRow {
  std::string_view name;
  ByNameTargets targets;          // which parts answer (was OOByName)
  ValueType result;               // from the member's return type
  ByNameArgument argument;        // none / std::string / oo::PList, from its parameter
  PList (*call)(Entity*, const std::string*, const PList*);
  void (*typed)(Entity*, EntityByNameValue&);   // no-argument members only, else null
};
template <auto... Members> consteval EntityByNameRow Call(std::string_view name);
}

// src/Core/Entities/EntityByNameTable.cpp (new) — the table
inline constexpr oo::EntityByNameRow kEntityByNameRows[] = {
    oo::Call<&ShipEntity::subIdx>("subIdx"),
    oo::Call<&OOVisualEffectEntity::setUpSubEntities, &ShipEntity::setUpSubEntities>("setUpSubEntities"),
    oo::Call<&ShipEntity::setUpCargoType>("setUpCargoType:"),
    …
};
```

**What `Call<Members...>` works out from each member pointer:**
- **The part:** which class the member belongs to gives the `Part()` getter (`ShipPart`,
  `PlayerEntityPart`, `StationPart`, `DockPart`, `EffectPart`, `ProxyPart`) and the target flag.
  With several members, the first part that answers wins. That's today's order: in every
  two-member body, the effect is tried before the ship.
- **The result:** `ValueType` from the return type.
- **The argument kind:** none, `const std::string&` or `const oo::PList&`, from the parameter.
- **The default** when no part answers: `T{}`, except that `Quaternion` gives
  `kIdentityQuaternion`. `ShipEntity::subEntityRotationalVelocity` does that today, and it's the only
  non-`T{}` default (`kZeroVector`, `kZeroHPVector` and `NSMakePoint(0, 0)` all equal `T{}`). Put
  it in one `oo::ByNameDefault<T>()` trait.

**Exceptions:**
- The 2 bodies that aren't a plain member call (the player's deferred update via
  `oo::ScheduleEntityCall`, and the dock-or-station launch-queue count) keep a lambda:
  `oo::CallWith<Result, Argument>("name", targets, [](Entity*, …) { … })`.
- Names whose selector differs from the member's spelling keep the selector, colon included, as
  the row's `name`, because the data spells them that way.

**`callObjC()` reads the same rows.** Its form (`kVoidVoid`, `kVoidString`, `kPListString`,
`kPListVoid`, `kTyped`) is worked out by a `constexpr` function of `row.argument` and `row.result`.
`OOJSCallEntityMethods.h` goes. The 89 facade rows in `OOEntityCalledByName.cpp` move into the same
table as `Call<&Entity::…>` rows.

**Unknown names** log a single "`<Class>` does not respond to `<name>`" (`callByName.unknownSelector`,
which already exists). `OOEntityObjectNamesTable.h` and the "has no signature … (type encoding …)"
lines go.

## Steps

1. Add `EntityByName.h` with the row, `Call<>`, `CallWith<>` and `ByNameDefault<>`.
   - New test `tests/unit/core/test_EntityByName.cpp`, written first:
     - `static_assert`s that `Call<&ShipEntity::subIdx>` has `ValueType::kULongLong`
       (`std::size_t` on Windows) and `ByNameArgument::kNone`;
     - that a two-member row tries the effect first;
     - that a missing part gives the trait's default, with `Quaternion` giving identity.
2. Convert the table: write the rows with a script from today's `kOOEntityByNameRows` and
   `ByName_N` bodies, one per area (ship, player, station/dock, effect, proxy). Each body names
   its member call, which gives the member pointer. Check that every converted row's `result`,
   `argument` and `targets` equal the old row's. A one-off check program, not kept, compares the
   two tables row by row before the old one is deleted.
3. Point `OOEntityCalledByName.cpp`'s look-up (`EntityByNameRowNamed`, `CallRow`, `ResultKind`) and
   `OOJSCall.cpp`'s `MethodTypeOfRow` at the new rows. Delete `OOEntityCalledByNameTable.h`.
4. Work out `callObjC()`'s form from the row, and delete `OOJSCallEntityMethods.h`.
5. Delete `OOEntityObjectNamesTable.h` and the frame-offset "type encoding" log path. Unknown names
   log "does not respond".
6. Run clang-format 22 on the new and changed `src/` files. The new table can be formatted
   normally (one call per line), so it needs no `clang-format off`.

## Done check

From `oolite-dev`, this exits nonzero before and zero after:

```bash
! test -e src/Core/Entities/OOEntityCalledByNameTable.h && ! test -e src/Core/Scripting/OOJSCallEntityMethods.h && ! test -e src/Core/Entities/OOEntityObjectNamesTable.h && ! git grep -qE '\bByName_[0-9]+\b' -- src
```

Also run `./mk.sh build dev` (no new warnings), `tests/run.sh unit` and
`tests/run.sh component --cpp`. The AI-driven component scenarios (S1–S8) exercise by-name calls
end to end.

## Test-change ledger (signed off: Jon, 2026-11-15)

| File | Edit | Assertion meaning |
|---|---|---|
| `tests/unit/core/test_OOEntityCalledByName.cpp:143-168` | The lines that pin "has no signature a by-name call can use (type encoding v24@0:8@16)" and the like for unlisted names become "does not respond to …" | **Changed:** the log text for uncallable names. Which names are callable, and every call's result, stay pinned unchanged. |
| `tests/unit/core/test_OOJSCallEntityMethods.cpp` | It checks that the two tables agree, and there's now one. Rewrite it to check the worked-out `callObjC()` form for every row against the same oracle (`Oracle(row)`, lines 55-75) | Same: the form each name is called with |
| any test naming `kOOEntityByNameRows`, `OOEntityByNameRow`, `OOByName` or `ByName_N` | Rename to the `oo::` names | Same |

## Decisions (defaults taken)

- **Keep all 965 names.** Trimming to the 318 whitelisted names plus what `callObjC()` needs would
  remove debug-console reach. That's Jon's call, and it's one line per name to drop later.
- **Log text for uncallable names may change** (Jon, 2026-11-15: log names needn't match upstream).
  Which names are callable doesn't change.
- **Not C++26 reflection.** Static reflection could generate the rows from the classes, but neither
  Clang nor GCC supports it yet. Revisit when they do.
- **Naming:** the new types and files are `oo::EntityByNameRow`, `oo::Call`, `EntityByName.h`, with
  no `OO` prefix.
- **Order:** after `ValueType.h` (done). It sits alongside the `drop-oo-prefix` plan, which renames
  the remaining `OO` types.
