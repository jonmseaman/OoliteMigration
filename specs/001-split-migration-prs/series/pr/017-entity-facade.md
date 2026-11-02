# Delete the root Entity facade

**Series:** step 17 of 26 · base `series/016-facade-deletions` · next `series/018-objc-runtime-out` **(gen)**

**Chapter:** P3 · the root Entity facade · history `d012b77f21`..`473facf469` (70 merges) · 29.7k src, 17.1k tests, 59 other changed lines; 17.8k lines in deleted files **(gen)**

## What this changes

The root `Entity` facade goes, and with it the last Objective-C objects in the entity graph:
`cxx::Entity` becomes `Entity`, an `oo::RefCounted` C++ object that owns itself, and the universe
and the entities' own lists (sub-entities, cargo, collisions, the player's missiles) hold entities
through `oo::EntityHold` (`src/Core/Entities/OOEntityHold.h`); ships' and stations' weak sets
become `oo::WeakSet`. The methods AI scripts and shader bindings call by name, and the JS
`callObjC()` names, are now explicit C++ tables (`OOEntityCalledByNameTable.h`,
`OOJSCallEntityMethods.h`) instead of selector look-ups. The other remaining facades go too:
`Universe`, `GameController`, `MyOpenGLView`, the JS engine and its special functions, `OOJSCall`,
`AI`, the debug monitor and console client, the texture, texture loader, texture generator and
material roots, the cache, resource, ship-registry and async-work managers, the joystick managers
and `OOStringExpander`. Alongside, the build's `-Wall -Wextra` warnings are fixed in the code (none
silenced) and the remaining C variable-length arrays become `std::vector`.

## Why

`Entity` is the root of every in-game object, so its facade could only go after every entity
subclass and every caller of entities was C++ (steps 14 to 16). Once it is gone nothing in the game
needs an Objective-C object for an entity, which is what makes step 18, removing the Objective-C
runtime, possible.

## Behaviour changes

- `OORoundUpToPowerOf2_32/_64` (`src/Core/OOFastArithmetic.h`) had undefined results for 0, 1 and
  values above the high bit. They now return what the optimised x86-64 build always returned
  (2 for 1; 1 for 0 and above the high bit), so debug and release builds agree; every other input
  is unchanged. Pinned by `tests/unit/core/test_OOFastArithmetic.mm`.
- `OOTextureScaling`'s vertical stretch copied its last output row from one row past the last
  source row, reading past the buffer when the height more than doubles, and the horizontal
  stretch read one pixel past the row with zero weight. The last row is now the last source row.
  The bug is in upstream too. Pinned by `stretchesVerticallyAndKeepsTheEdges` in
  `tests/unit/core/test_OOTextureScaling.mm`.
- Loading a saved game at launch no longer reads the save path after the add-on reset has
  cleared it (a use-after-free in the converted `GameController`). Pinned by
  `playerFileToLoadFromItsOwnValue` in `tests/unit/core/test_GameController.mm`.

## How to review

Start with `src/Core/Entities/Entity.h` (the class now global, reference-counted, with
`hasObject()`), then `OOEntityHold.h` and `EntityVirtualMembers.h`. The entity's last release now
runs what the facade's `-dealloc` ran, and an `oo::EntityHold` counts as the facade's retain did
(`OOEntityHold.h`'s header comment explains the mapping).

`OOEntityCalledByNameTable.h` (6,000 lines) and `OOJSCallEntityMethods.h` are generated, one row
per method that was called by selector name, with the same names; review a sample of rows against
the member each calls, and use `tests/unit/core/test_OOEntityCalledByName.mm`, which checks the
table's names. The generator is not part of this tree.

The rest is mechanical: deleting `Entity+ObjCBridge.*` and the other facades
(`git diff --stat --diff-filter=D series/016-facade-deletions series/017-entity-facade`), and
callers changing from an Objective-C entity pointer and `oo::ToCxx`/`oo::ToObjC` crossings to the
C++ entity. Test changes follow the same pattern as step 16: facade cases removed, Objective-C
stand-ins rewritten as C++. The three fixes above are small and stand alone:
`OOFastArithmetic.h`, `OOTextureScaling.mm` and `GameController.mm`'s `loadPlayerIfRequired`.

## Verified **(gen)**

Windows x64, `c95a488c3e`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | n/a: no component scenario touched |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd, core |
| warnings_clang | pass: 0 warnings outside the history's tests (1 listed in test-warnings.md) |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
