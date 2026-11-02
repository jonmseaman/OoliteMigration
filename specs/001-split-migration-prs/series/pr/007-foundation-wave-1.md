# Move Foundation usage to oofnd, part 1

**Series:** step 7 of 25 · base `series/006-typed-accessors` · next `series/008-foundation-wave-2` **(gen)**

**Chapter:** P2 · 2.3 Foundation -> oofnd, per file · history `931bee60e9`..`ecfafab479` (210 merges) · 35.3k src, 1.2k tests, 0 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

This is the first half of moving the game's own code off Foundation and onto `oofnd`, the C++20
library added in step 5. File by file, the `NSString`, `NSArray`, `NSDictionary`, `NSSet`,
`NSNumber` and `NSData` values inside a class become `std::string`, `std::vector`, `std::map`,
`std::optional`, `oo::PList` and `oo::Data`. The classes themselves are still Objective-C. A
selector that only one class declares takes and returns the C++ types, and its callers change at the
call expression only. A selector that several classes declare (a "shared" selector) keeps `id` at its
boundary for now and converts on the inside. Where a class has too many callers to adapt in the same
change, it gets a `cxx_`-prefixed C++ API, and a transitional `X+FoundationBridge.h/.mm` category
keeps its old Foundation-typed selectors working by forwarding to that API. This step adds 25 of
these bridges; steps 8 and 9 delete them. `oofnd` also gains what the sweep needed, most of it in
`oo::str` (`String.hpp`: path components, GNUstep's `%p` text, run-time format strings with `%@` and
positional arguments, Unicode file decoding), and `oo::PList` can now carry live objects and
single-precision reals.

## Why

Foundation (gnustep-base) can't be unlinked while game code still names its types, and the classes
can't become C++ (steps 10–14) while their interfaces are Foundation-typed. Changing the types first,
inside Objective-C, keeps each change small enough to check against the game's behaviour. The order
follows dependencies: maths and Core leaf utilities, then Materials, the OXP verifier, scripting,
entities and `Universe`. This step comes right after step 6, because many of these files had to stop
using the `oo_*ForKey:` extractors before their collections could become `oo::PList`.

## Behaviour changes

None intended. Every new `oo::str` and `oo::PList` helper reproduces gnustep-base 1.31.1's answers,
captured from the real library and pinned in `tests/unit/oofnd/test_string_sweep.cpp`,
`tests/unit/oofnd/test_string_format_runtime.cpp`, `tests/unit/oofnd/test_unicode_file.cpp`,
`tests/unit/oofnd/test_unicode_file_decode.cpp` and `tests/unit/oofnd/test_plist_carrier.cpp`.

- macOS only, not built or verified here: upstream's `builtInPath` under `OOLITE_MAC_COCOA_UI`
  (#766) is not in this step, because the path code now goes through `oo::ResourcePaths`. Step 23
  restores it. No test pins it.

## How to review

Start with `src/oofnd/README.md`, section "Migrating Foundation usage". Its type table (which C++
type replaces which Foundation type, and why a method never returns a bare `std::string` to a
possibly-nil receiver) is the rule every file follows. Then read one example per kind:
`src/Core/OORoleSet.mm/.h` (collections, unique and shared selectors, four callers adapted),
`src/Core/Materials/OOBasicMaterial.mm` (every selector shared, `id` at the boundary) and
`src/Core/OOColor.h` with `OOColor+FoundationBridge.h/.mm` (the `cxx_` API and its bridge).

The rest is the same pattern, file by file. To spot-check a file, compare its header on the base and
here: each NS type should map to the table's C++ type, and each caller hunk should be just a
conversion at the call (`oo::StdString(s)`, `oo::NSStringOrNil(...)`). Things to look for:

- a test against nil that became a test against an empty string where the two behaved differently
  (the README says to use `std::optional` there);
- a loop over a former `NSDictionary` or `NSSet` that now runs in `std::map` key order or in
  insertion order, where the order matters (first match wins, a random pick, text output);
- formatted strings that are no longer byte-identical.

The bridge files are boilerplate and forward one line per method. The new `oofnd` code is in
`src/oofnd/String.hpp`, `PList.hpp` and `PListWriting.hpp`. `tests/source_paths.py` and the
`tests/gui` edits let the source-text guards find a file by its stem whatever its suffix
(`.m`, `.mm`, `.cpp`), so later renames don't break them. `tests/component/steps/world_steps.py`
spawns a fixed hull for each role so the component scenarios don't depend on a random ship draw.

## Verified **(gen)**

Windows x64, `dfa465e94a`, 2026-11-02.

| Check | Result |
|---|---|
| build_clang | pass |
| build_gcc | n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too) |
| clang_format | pass |
| component | pass: s1_police_kills_pirate, s2_pirate_attacks_target_registers_attacker, s3_hostile_spawn_drives_ship_into_attack, s4_missile_armed_ship_kills_by_missile, s5_escorts_converge_on_their_mother, s6_damaged_ship_flees, s7_neutral_traffic_is_quiet, s8_destroyed_ships_leave_allships |
| no_new_spidermonkey_or_gnustep | pass |
| no_new_suppressions | pass |
| smoke | pass |
| tests_untouched | pass |
| unit | pass: oofnd |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
