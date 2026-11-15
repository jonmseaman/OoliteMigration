# Naming check against the proposed Google-style rules (2026-11-15)

The rules checked are the ones in `notes/0_TODO.md`:

```yaml
readability-identifier-naming.ClassCase:           CamelCase
readability-identifier-naming.FunctionCase:        CamelCase
readability-identifier-naming.VariableCase:        lower_case
readability-identifier-naming.PrivateMemberSuffix: _
readability-identifier-naming.ConstantCase:        CamelCase
readability-identifier-naming.ConstantPrefix:      k
readability-identifier-naming.EnumConstantCase:    CamelCase
readability-identifier-naming.EnumConstantPrefix:  k
```

**Files:**
- [2026-11-15-violations.tsv](2026-11-15-violations.tsv): every name that breaks the rules, with
  file, line, column and name.
- [2026-11-15-all-names.tsv](2026-11-15-all-names.tsv): every declared name with its kind, used
  for the `OO` counts.

## How

- **Tool:** clang-tidy 23.1.4's `readability-identifier-naming`, with only the rules above. The
  config is `.agent-tmp/naming-tidy.yaml`.
- **Command:** `run-clang-tidy -p . -config-file=… 'src.(Core|SDL|oofnd).*\.cpp$'`, over the dev
  build's compile database (`oolite-dev` `df5869f9d` plus the working tree): 228 translation units.
- **Headers:** headers under `src/Core`, `src/SDL` and `src/oofnd` are included. Each finding is
  counted once, however many translation units report it.
- **The `OO` counts:** a second pass set a dummy prefix for every kind of name, so clang-tidy lists
  every declaration with its kind (`.agent-tmp/naming-inventory.yaml`). Names starting `OO` or
  `kOO` were then counted.

**What this misses:**
- code compiled only on Linux or macOS;
- `tests/`;
- headers that no `.cpp` includes.

It also includes the hand-laid table `OOEntityCalledByNameTable.h` (969 findings: its
`ByName_N` adaptor functions).

## 1. Names that break the rules: 14,186

| Rule broken | Count | Typical case |
|---|---:|---|
| Function or method not `CamelCase` | 6,131 | `setUpShip`, `isPlayer`, `getSystemName`: upstream's Objective-C `lowerCamel` selectors |
| Variable not `lower_case` | 3,961 | `shipKey`, `missionVars`, `targetSystemID` (camelCase locals and parameters) |
| Constant not `kCamelCase` | 2,879 | `MAX_ENTITY_UID`, `GUI_ROW_*`, constants written `ALL_CAPS` or with no `k` |
| Private member without the `_` suffix | 1,209 | `_channel`, `cachedStation` (upstream uses a leading `_` or none) |
| Class not `CamelCase` | 6 | — |
| Enum constant | 0 | all already `kCamelCase` (spec 009) |

Only 46 of the 14,186 start with `OO`: 36 constants and 10 functions. The `OO` prefix is legal
`CamelCase`, so the case rules don't object to it.

**Worst files:**

| File | Findings |
|---|---:|
| `Entities/PlayerEntity.h` | 1,222 |
| `Entities/OOEntityCalledByNameTable.h` | 969 |
| `Entities/ShipEntity.h` | 792 |
| `Entities/PlayerEntity.cpp` | 575 |
| `Universe.cpp` | 355 |
| `Entities/ShipEntity.cpp` | 338 |
| `Universe.h` | 336 |
| `ResourceManager.cpp` | 224 |
| `Entities/PlayerEntityControls.cpp` | 210 |
| `SDL/MyOpenGLView.h` | 207 |
| `Entities/PlayerEntityLegacyScriptEngine.cpp` | 174 |
| `AI.h` | 165 |

**Merge cost:** most of the 6,131 function findings are method names that upstream uses too, and
renaming them would touch nearly every upstream change. The same "class design stays
upstream-shaped" reasoning that kept §2.1 out applies here.

## 2. Names that start with `OO` instead of having no prefix

Out of 31,783 declarations in all:

| Kind | Distinct names | Starting `OO`/`kOO` | Outside `Core/Scripting` (declarations) |
|---|---:|---:|---:|
| Class | 206 | 155 | 166 |
| Struct | 112 | 42 | 42 |
| Enum | 105 | 55 | 54 |
| Type alias | 97 | 56 | 54 |
| Free function | 3,460 | 573 | 449 |
| Global constant | 1,103 | 334 | 330 |
| Macro | 908 | 249 | 206 |
| Namespace | 15 | 1 | 1 |
| Variables, members, methods, enum constants | 13,000+ | 0 | 0 |

So about **308 types, 573 free functions, 334 constants and 249 macros** carry the prefix. Methods,
members, variables and enumerators never do.

The plan to drop it (outside `Core/Scripting`) is
[plans/drop-oo-prefix.md](../plans/drop-oo-prefix.md). Its rename list should come from
`2026-11-15-all-names.tsv`.
