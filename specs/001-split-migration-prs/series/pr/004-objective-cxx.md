# Compile the game as Objective-C++

**Series:** step 3 of 25 · base `series/002-js-facade` · next `series/004-quickjs-switch` **(gen)**

**Chapter:** P2 · 2.1 the .m -> .mm switch · history `c9c0525383`..`c9c0525383` (1 merges) · 745 src, 0 tests, 1.9k other changed lines; 290 lines in deleted files **(gen)**

## What this changes

Every remaining Objective-C source file in `src/` is renamed from `.m` to `.mm`, so the whole game
now compiles as Objective-C++. The `meson.build` lists change with them. 126 of the 203 renames are
byte-identical. The others contain only the edits C++ needs to accept C that Objective-C accepted:
- explicit casts from `void *` (`malloc` results, buffer pointers) and from integers to enums;
- casts on comparisons with `NO_TARGET`;
- parameters named `new` or `class` renamed;
- `{ }` scopes added where a `goto` or `switch` would jump over an initialisation;
- `extern "C"` guards on C headers (`OOOpenGL.h`, `legacy_random.h`);
- an overload-based `OO_CAST_PARAMETER` in `OOStringExpander.h`, because C++ has no
  `__builtin_choose_expr`/`__builtin_types_compatible_p`.

`OOOpenGLStateManager.mm` moves its state table above its first use, because C++ cannot
forward-declare a `static const` object.

## Why

Later steps adopt C++ types (the JavaScript façade's handles, then the `oofnd` library) directly
inside Objective-C classes, and that needs Objective-C++ everywhere. Step 2 converted only the
script bindings it had to. This step converts the rest in one rename-only pass with no logic
changes, so the edits needed to compile cleanly are reviewed apart from anything that changes
behaviour. It comes before step 4 because step 4's binding and engine changes touch files, such as
`OOJSShip`, that are still `.m` at step 2.

## Behaviour changes

None intended. The step-1 component and GUI tiers (`tests/component/`, `tests/gui/`) run against it
unchanged.

## How to review

Most of the diff is renames. List the files that actually changed:

    git diff -M --name-status series/003-objective-cxx^ series/003-objective-cxx | grep -v '^R100'

Those are 77 renames under 100% similarity plus 13 modified headers and `meson.build` files.
In each one, check that every hunk is one of the kinds listed above: a cast, a rename, an added
scope or an `extern "C"` block. The ones that deserve a real read:
- `src/Core/OOStringExpander.h`: the C++ overload set must classify the same types the C
  `__builtin_choose_expr` branch does.
- `src/Core/OOOpenGLStateManager.mm`: the moved table; it should be identical to the old one at
  the bottom of the file.
- `src/Core/Materials/OOPlanetTextureGenerator.mm` and `OOStandaloneAtmosphereGenerator.mm`: the
  added scopes. Only the indentation should change.
- `src/Core/OOJoystickManager.mm`: it gains `-decodeAxisEvent:`, `-decodeButtonEvent:` and
  `-decodeHatEvent:`, which upstream moved into `OOSDLJoystickManager`. This series keeps them in
  the base class, as the rest of the migration does. Steps 3 to 6 carry both copies, and step 7
  takes the SDL joystick manager over whole. The SDL subclass still dispatches to its own copies.

## Verified **(gen)**

Windows x64, `74de248ea4`, 2026-11-02.

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
| unit | n/a: the tree has no unit suites |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
