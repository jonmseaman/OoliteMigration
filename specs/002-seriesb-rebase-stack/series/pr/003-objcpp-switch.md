# Compile the game as Objective-C++, keeping #768's QuickJS-ng binding

**Series:** step 3 of 24 · base `seriesb/002-safety-net` · next `seriesb/004-oofnd-core` **(gen)**

**Replays:** `series/005-quickjs-switch` (old 3, 4, 5 of the master-based series) · 864 src, 0 tests, 2.1k other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

The game compiles as Objective-C++. Every Objective-C source file in `src/` is renamed from `.m`
to `.mm` (247 renames, including #768's `poc/` harness), and the build declares the `objcpp`
language (`meson.build`, `clang.ini`). `src/meson/meson.build` gives Objective-C++ the same
exception flags as Objective-C and, for Clang off macOS, the same GNUstep-runtime flags. Every
`meson.build` source list names the `.mm` files. 285 files change, +1695/−1306; no file is added
or deleted.

133 renames are byte-identical. The other 114, and 26 headers, get the edits that C++ requires:

- identifiers that are C++ keywords are renamed: `this` → `thisObj` in #768's binding (the
  `OOJS_GETTER_ARGS`/`OOJS_SETTER_ARGS` macros and every callback), `class` → `klass`, `new` →
  `newValue`, `export`, `mutable`, `template`, `private` and `operator` likewise;
- explicit casts where C converts implicitly: `void *` results (`malloc`, `-bytes`,
  `JS_GetOpaque`, `pointerValue`) and integers assigned to enums;
- variable-length arrays become `std::vector`;
- `extern "C"` guards in the headers that declare C functions;
- a few C-only constructs get C++ equivalents: `OO_CAST_PARAMETER` in `OOStringExpander.h` picks
  its helper by overloading, where C uses `__builtin_choose_expr`; `OOOpenGLStateManager.mm`'s
  state table moves above its first use and lists its entries and fields in declaration order;
  declarations that a `goto` or `case` would jump over get their own block or lose their
  initialiser to a separate assignment; `OOJSPropID.h`'s `OOJSID` macro puts a space between
  `""` and its argument.

#768's QuickJS-ng binding stays the scripting layer, here and in every later step; only the edits
above touch it. `oolite-quickjs-compat.js`, the QuickJS-ng wrap and its patch, and upstream's
`tools/js-parity/` and `tools/oxp-upgrade/` are unchanged.

`ShellScripts/common/post_build.sh` now copies the Windows DLLs that the game's DLLs depend on as
well as the game's own: it runs `ldd` over each newly copied DLL until no new one appears
(`staged_dlls`). For example, `libtre-5.dll` needs `libsystre-0.dll`, which the game does not
link directly.

## Why

Step 4 adds `oofnd`, a C++20 library that the game's Objective-C files include, and later steps
put C++ types inside Objective-C classes before converting each class to C++. All of that needs
Objective-C++. Renaming every file in one step keeps the later diffs to real changes. Each edit
here is the smallest one the compiler requires, made on upstream's code, so upstream's recent
changes (#742, #748, #749, #780 among them) stay as they are.

## Behaviour changes

None. The edits are renames, casts and declarations. The arrays that became `std::vector` are
now zero-initialised and on the heap rather than the stack. `OOOpenGLStateManager.mm`'s state
table has the same five states with the same values. The step-2 component and GUI tiers run
against this step unchanged.

## How to review

1. See only the files whose content changed (114 edited renames, 38 modified files):

       git diff -M --name-status seriesb/002-safety-net seriesb/003-objcpp-switch | grep -v '^R100'

2. Read the edits without the re-indentation that the new blocks cause:

       git diff -M -w seriesb/002-safety-net seriesb/003-objcpp-switch -- src ':!*meson.build'

   Most hunks are one of the kinds listed above. The ones that need a real read are
   `OOStringExpander.h` (the overloads must classify each type as the C branch does), the moved
   state table in `OOOpenGLStateManager.mm`, and the new blocks in
   `OOPlanetTextureGenerator.mm` and `OOStandaloneAtmosphereGenerator.mm`.
3. Check the build files: `meson.build`, `clang.ini`, `src/meson/meson.build`, and
   `ShellScripts/common/post_build.sh`.
4. Check that upstream's code is kept: `git diff -M --diff-filter=AD --name-only
   seriesb/002-safety-net seriesb/003-objcpp-switch` prints nothing; the joystick files
   (#742, #749) are `R100`; `src/Core/OOOpenGLOnly.h` (#748) is unchanged; and
   `git grep -n playerWillSaveGame seriesb/003-objcpp-switch -- src` still shows #780's
   `doScriptEvent:` calls.

## Verified **(gen)**

Not verified at this branch's tip (`768166d647`) yet: the last record is for `a6e785314d` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
