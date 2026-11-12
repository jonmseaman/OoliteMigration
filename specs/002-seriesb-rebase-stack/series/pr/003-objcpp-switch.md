# Compile the game as Objective-C++, keeping #768's QuickJS-ng binding

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 3 of 28, stacked on upstream #768's branch, so not independent of #767 and #768. Replays `series/005-quickjs-switch` (old 3, 4, 5).

## What this changes

The game compiles as Objective-C++. Every Objective-C source file in `src/` is renamed from `.m`
to `.mm` (247 renames, including #768's `poc/` harness), and the build declares the `objcpp`
language (`meson.build`, `clang.ini`). `src/meson/meson.build` gives Objective-C++ the same
exception flags as Objective-C and, for Clang off macOS, the same GNUstep-runtime flags. Every
`meson.build` source list names the `.mm` files. 288 files change, +1738/−1334; no file is added
or deleted.

131 renames are byte-identical. The other 116, and 29 headers, get the edits that C++ requires:

- identifiers that are C++ keywords are renamed: `this` → `thisObj` in #768's binding (the
  `OOJS_GETTER_ARGS`/`OOJS_SETTER_ARGS` macros and every callback), `class` → `klass`, `new` →
  `newValue`, `export`, `mutable`, `template`, `private` and `operator` likewise;
- explicit casts where C converts implicitly: `void *` results (`malloc`, `alloca`, `dlsym`,
  `-bytes`, `JS_GetOpaque`, `pointerValue`) and integers assigned to enums;
- variable-length arrays become `std::vector`;
- `extern "C"` guards in the headers that declare C functions;
- a few C-only constructs get C++ equivalents: `OO_CAST_PARAMETER` in `OOStringExpander.h` picks
  its helper by overloading, where C uses `__builtin_choose_expr`; `OOOpenGLStateManager.mm`'s
  state table moves above its first use and lists its entries and fields in declaration order;
  declarations that a `goto` or `case` would jump over get their own block or lose their
  initialiser to a separate assignment; `OOJSPropID.h`'s `OOJSID` macro puts a space between
  `""` and its argument;
- `OOFoundation.h` adds `OOSortFunction()`, used at the `sortedArrayUsingFunction:` and
  `sortUsingFunction:` call sites. With Apple's Foundation it casts the sort function to the
  `NSInteger` signature the SDK declares; with GNUstep, whose declaration already takes
  `NSComparisonResult`, it passes the function as it is. `OONSOperation.h`'s priority names become
  typed constants, and `OOMaths.h` includes `<tgmath.h>` before its `extern "C"` block, because
  libc++ declares templates there.

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

1. See only the files whose content changed (116 edited renames, 41 modified files):

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

Windows x64, `e8b7c8d6d9`, 2026-11-11. macOS and Linux are not verified.

| Check | Result |
|---|---|
| build_clang | pass |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships (1 earlier attempt(s) failed; see the log) |
| no_facade | pass |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | fail: src/Core/Scripting/poc/OOJavaScriptEnginePoc.mm: #pragma clang diagnostic ignored "-Wincomplete-implementatio |
| smoke | pass |
| tests_untouched | fail: tests/component/README.md, tests/component/conftest.py, tests/component/console.py, tests/gui/test_g2_exit_via_keyboard.py, tests/gui/test_g5_screen_round_trips.py, tests/gui/test_g6_window_lifecycle.py, tests/gui/test_g8_scenario_screen_back_out.py, tests/gui/test_g9_post_exit_hygiene.py |
| warnings_clang | pass: 0 new warnings (6 inherited from the parent) |

Not applicable here: build_gcc, poc, unit.
