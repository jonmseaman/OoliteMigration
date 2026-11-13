# Retire the remaining Foundation selectors and their bridge callers

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 8/28. Replays `series/010-selector-families`.

## What this changes

- Each selector family (one selector declared by several classes, e.g. `-cacheKey`, `-hasRole:`)
  takes C++ types, every declaration and caller in one change; callers move to the `cxx_` APIs.
- Deletes all 35 `X+FoundationBridge` bridges and `NSUserDefaults+OODefaultsBridge`. #768's callers
  (`OOJSScript.mm` script cache, `OOJSConsole.mm` settings) move too; its `RewriteLegacyConst()`
  cache becomes a `std::unordered_map` keyed by source, filled only on rewriter success.
- Deletes the last Foundation helpers (three categories, `OODeepCopy`, `OOFilteringEnumerator`,
  `OOFoundationException`, `SDL/Comparison`, `OOEnumerationShuffle`). Replacements:
  `Core/OODescription.h`, `oofnd/PListDescription.hpp`, `Core/OOObjCPList.h`,
  `Core/OOCallByName.h` (replaces `-performSelector:withObject:`), `Core/OOPListGameTypes.h`.
- `meson.build` makes Clang's `objc-method-access` an error, so a send nothing implements fails
  the build. The verifier schema reads `allowOthers` with `get<bool>`.

## Why

gnustep-base can be unlinked only when no game code calls it; these were the last callers.

## Behaviour changes

None intended. Description text matches gnustep-base: pinned by `test_objc_description.mm`,
`test_plist_description.cpp`, `test_plist_game_tuples.cpp`; call-by-name by
`test_objc_call_by_name.mm`; plist objects by `test_objc_plist.mm` (all `tests/unit/oofnd`).

## How to review

Start with the new headers (each opens with a table of what it replaces), then follow one family,
e.g. `-cacheKey` across the texture and generator classes: every declaration changes, no caller is
left on `id` or a bridge. Most of the 398 files are mechanical (`oo::NSStringOrNil([x foo])` ->
`[x cxx_foo]`). Check a deleted bridge: `git grep` its selectors on `seriesb/008-selector-families`
finds only the `cxx_` form.

Test edits (no other test removed):
- `tests/unit/game/test_defaults_bridge.mm`: deleted with the preferences bridge and `game-unit`.
- `tests/unit/test_enumeration_shuffle.c`: deleted with the debug shuffle.

Trap: the unregistered `tests/unit/expander` stub still declares the `NSString`
`OOJSReportWarningWithArguments`, so it would not build here; nothing builds it.

## Verified

Not verified at `b4bfdeb596`.
