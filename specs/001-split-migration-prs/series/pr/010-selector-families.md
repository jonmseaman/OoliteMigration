# Retire the remaining Foundation selectors and their bridge callers

**Series:** step 9 of 25 · base `series/008-foundation-wave-2` · next `series/010-leaf-conversions` **(gen)**

**Chapter:** P2 · selector families, bridge callers · history `b75b5d1bc6`..`e0b9e24b22` (199 merges) · 18.6k src, 1.1k tests, 12 other changed lines; 10.5k lines in deleted files **(gen)**

## What this changes

This step removes the last Foundation-typed interfaces between game classes. Steps 7 and 8 left
these as `id` or behind a bridge. Each "selector family" (a selector that more than one class or
protocol declares, such as `-cacheKey`, `-hasRole:` or `-initWithKey:definition:`) now takes C++
types in one change that edits every declaration and every caller. The callers of the transitional
bridges move to the `cxx_` APIs, so 35 `X+FoundationBridge` pairs are deleted, along with
`NSUserDefaults+OODefaultsBridge` and its test. The remaining Foundation helpers also go: the
`NSBundle`, `NSUserDefaults` and `NSFileManager` categories, `OODeepCopy`, `OOFilteringEnumerator`,
`OOFoundationException`, `SDL/Comparison`, and the debug-only `OOEnumerationShuffle` that step 1
added. Their replacements are Foundation-free:
- `Core/OODescription.h`: `-description` as C++ text on the Objective-C root;
- `oofnd/PListDescription.hpp`: what `%@` printed for a property list;
- `Core/OOObjCPList.h`: live objects inside an `oo::PList`;
- `Core/OOCallByName.h`: calling a method named at run time with C++ arguments, which replaces
  `-performSelector:withObject:` for AI, legacy-script, HUD-dial and deferred calls;
- `Core/OOPListGameTypes.h`: vectors, quaternions and the fuzzy boolean read from plists.

## Why

gnustep-base can be unlinked only when no game code calls into it. The bridges and the `id`-typed
shared selectors were the last places that still did. They could only go after every class had its
C++ API (steps 7–8), and each family has to flip in one change, because its classes and callers
must agree on one signature. The last few Foundation boundary headers (`OOFoundationBridge.h`,
`OOStringBridge.h`, `OOPListView.h`, `OOCollectionExtractors`) and the `gnustep-base` entry on the
Windows link line are removed in step 10's first part, together with the constant-string switch.

## Behaviour changes

None intended. The description text that game and JavaScript code prints is reproduced from
gnustep-base, pinned by `tests/unit/oofnd/test_objc_description.mm`,
`tests/unit/oofnd/test_plist_description.cpp` (captured output in `plist_description_captured.inc`)
and `tests/unit/oofnd/test_plist_game_tuples.cpp`. Call-by-name dispatch is pinned by
`tests/unit/oofnd/test_objc_call_by_name.mm`, and objects inside plists by
`tests/unit/oofnd/test_objc_plist.mm`.

The build is stricter: `meson.build` makes clang's `objc-method-access` warning an error. While
categories are being deleted, that warning is the only compile-time sign that something still sends
a selector nothing implements, which would otherwise be an "unrecognized selector" exception at run
time.

## How to review

Start with the new headers listed above. Each opens with a table of what it replaces. Then pick a
family and follow it, for example `-cacheKey` across the texture and generator classes: every
declaration should change in this step, and no caller should be left using `id` or a bridge
conversion. A quick check that a bridge was safe to delete: `git grep` for each selector its header
declared, on this tree, finds only the `cxx_` form.

Most of the 397 files are mechanical. A caller's `oo::NSStringOrNil([x foo])` becomes
`[x cxx_foo]`, and `#import "X+FoundationBridge.h"` lines go. Two test files are deleted with the
code they tested: `tests/unit/game/test_defaults_bridge.mm` (the preferences bridge) and
`tests/unit/test_enumeration_shuffle.c` (the debug shuffle). No other test is removed.
`src/oofnd/README.md` has a new section, "The last Foundation boundaries", that documents the
replacements.

## Verified **(gen)**

Windows x64, `608d86cf38`, 2026-11-02.

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
| unit | pass: oofnd |
| warnings_clang | pass: 0 warnings |

macOS (its platform code is not converted yet) and Linux are not verified by this series.
