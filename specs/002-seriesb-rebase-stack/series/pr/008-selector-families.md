# Retire the remaining Foundation selectors and their bridge callers

**Series:** step 8 of 24 · base `seriesb/007-foundation-wave-2` · next `seriesb/009-leaf-conversions` **(gen)**

**Replays:** `series/010-selector-families` (old 10 of the master-based series) · 18.6k src, 1.1k tests, 14 other changed lines; 10.4k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step removes the last Foundation-typed interfaces between game classes. Steps 6 and 7 left
these as `id` or behind a bridge. Each "selector family" (a selector that more than one class or
protocol declares, such as `-cacheKey`, `-hasRole:` or `-initWithKey:definition:`) now takes C++
types in one change that edits every declaration and every caller. The callers of the bridges move to
the `cxx_` APIs, so all 35 `X+FoundationBridge` bridges are deleted (34 header and source pairs, and
`Entity+FoundationBridge.h`), along with `NSUserDefaults+OODefaultsBridge` and its test. #768's own
binding code still called some of these bridges, for example the compiled-script cache in
`OOJSScript.mm` (through `OOCacheManager`) and the debug console's settings in `OOJSConsole.mm`; it
moves to the `cxx_` APIs the same way as the rest.

The remaining Foundation helpers also go: the `NSBundle`, `NSUserDefaults` and `NSFileManager`
categories, `OODeepCopy`, `OOFilteringEnumerator`, `OOFoundationException`, `SDL/Comparison`, and
the debug-only `OOEnumerationShuffle` that step 2 added. Their replacements are Foundation-free:
- `Core/OODescription.h`: `-description` as C++ text on the Objective-C root;
- `oofnd/PListDescription.hpp`: what `%@` printed for a property list;
- `Core/OOObjCPList.h`: live objects inside an `oo::PList`;
- `Core/OOCallByName.h`: calling a method named at run time with C++ arguments, which replaces
  `-performSelector:withObject:` for AI, legacy-script, HUD-dial and deferred calls;
- `Core/OOPListGameTypes.h`: vectors, quaternions and the fuzzy boolean read from plists.

The build is stricter: `meson.build` makes Clang's `objc-method-access` warning an error. While
categories are being deleted, that warning is the only compile-time sign that something still sends
a selector nothing implements, which would otherwise be an "unrecognized selector" exception at run
time.

## Why

gnustep-base can be unlinked only when no game code calls into it. The bridges and the `id`-typed
shared selectors were the last places that still did. They could only go after every class had its
C++ API (steps 6–7), and each family has to flip in one change, because its classes and callers
must agree on one signature. The last few Foundation boundary headers (`OOFoundationBridge.h`,
`OOStringBridge.h`, `OOPListView.h`, `OOCollectionExtractors`) and the `gnustep-base` entry on the
Windows link line are removed in step 9, together with the constant-string switch.

## Behaviour changes

None intended. The description text that game and JavaScript code prints is reproduced from
gnustep-base, pinned by `tests/unit/oofnd/test_objc_description.mm`,
`tests/unit/oofnd/test_plist_description.cpp` (captured output in `plist_description_captured.inc`)
and `tests/unit/oofnd/test_plist_game_tuples.cpp`. Call-by-name dispatch is pinned by
`tests/unit/oofnd/test_objc_call_by_name.mm`, and objects inside plists by
`tests/unit/oofnd/test_objc_plist.mm`.

## How to review

Start with the new headers listed above. Each opens with a table of what it replaces. Then pick a
family and follow it, for example `-cacheKey` across the texture and generator classes: every
declaration should change in this step, and no caller should be left using `id` or a bridge
conversion. A quick check that a bridge was safe to delete: `git grep` for each selector its header
declared, on `seriesb/008-selector-families`, finds only the `cxx_` form.

Most of the 398 files are mechanical. A caller's `oo::NSStringOrNil([x foo])` becomes
`[x cxx_foo]`, and `#import "X+FoundationBridge.h"` lines go. Two test files are deleted with the
code they tested: `tests/unit/game/test_defaults_bridge.mm` (the preferences bridge, with the
`game-unit` suite that held it) and `tests/unit/test_enumeration_shuffle.c` (the debug shuffle). No
other test is removed. `src/oofnd/README.md` has a new section, "The last Foundation boundaries",
that documents the replacements.

The deployment flavour builds and launches here. `PlayerEntity`'s `-deferredInit` now uses
`OOAssert` around its ship set-up, which is why step 7 keeps `OOAssert` live under `NDEBUG`.

The unregistered `tests/unit/expander` test is unchanged here. Its stub still declares the
`NSString` form of `OOJSReportWarningWithArguments`, while the expander now calls the `cxx_` form, so
it would not build against this tree; nothing builds it.

## Verified **(gen)**

Not verified at this branch's tip (`0fd950db16`) yet: the last record is for `741729301a` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
