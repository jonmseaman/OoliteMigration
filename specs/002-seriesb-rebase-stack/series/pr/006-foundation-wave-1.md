# Move Foundation usage to oofnd, part 1

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 6/28. Replays `series/008-foundation-wave-1`.

## What this changes

- First half of the per-file move off Foundation: values inside classes become `std::string`,
  `std::vector`, `std::map`, `std::optional`, `oo::PList`, `oo::Data`. Classes stay Objective-C;
  #768's binding files included.
- Unique selectors take and return C++ types (callers change at the call only); shared selectors
  keep `id` at the boundary. Remaining `oo_*ForKey:` calls move to `PListView` (`get<bool>`/`at<bool>`).
- 25 `X+FoundationBridge.h/.mm` bridges forward old selectors to new `cxx_` APIs (step 7 deletes
  5, step 8 the rest). `Core/OOFoundationException.h` catches both `OOException` and the
  `NSException`s gnustep-base still raises.
- `oofnd`: `oo::str` gains path, `%@`/positional format and Unicode file helpers; `oo::PList`
  carries live objects and `float`s; `oo::AutoreleaseScope` drains newest first.

## Why

gnustep-base can't be unlinked, nor classes become C++ (steps 9–13), while interfaces name
Foundation types.

## Behaviour changes

- New `oo::str`/`oo::PList` helpers give gnustep-base 1.31.1's answers; none in the game changes.
  Pinned by `tests/unit/oofnd/test_string_sweep.cpp`, `test_string_format_runtime.cpp`,
  `test_unicode_file.cpp`, `test_unicode_file_decode.cpp`, `test_plist_carrier.cpp`.
- `oo::AutoreleaseScope` releases LIFO like libobjc2's pool (was insertion order); no game code
  uses it yet. Pinned by `test_objc_floor.mm` (`autoreleaseScopeDrainsInTheRuntimePoolsOrder`, new)
  and `test_ref.cpp` (`autoreleaseScopesNest`, `drainReleasesInOrderAndKeepsTheScopeOpen`,
  `drainingCascades`).
- macOS only, not built or verified: `+builtInPath` (now `+cxx_builtInPath` plus bridge) goes
  through `oo::ResourcePaths`, with no `OOLITE_MAC_COCOA_UI` branch (was the main bundle's resource
  path). Not pinned.

## How to review

Start with "Migrating Foundation usage" in `src/oofnd/README.md`: its type table is the rule
(no bare `std::string` to a possibly-nil receiver). Examples: `OOMesh.mm` (unique selectors),
`OOPlanetEntity.mm` (shared), `OOColor+FoundationBridge.mm` (bridge). Caller hunks should be only
conversions (`oo::StdString(s)`, `oo::NSStringOrNil(...)`):

    git diff seriesb/005-typed-accessors seriesb/006-foundation-wave-1 -- <file>

Watch for:
- nil tests turned into empty-string tests where the two differed;
- loops over a former `NSDictionary`/`NSSet` now in key or insertion order where order matters
  (first match, random pick, text output);
- formatted strings no longer byte-identical;
- #756's `OO_DEBUG_MONITOR_ENABLED` (not `NDEBUG`) around `AI.mm`'s `debugContext` and the texture
  bridge's `+cachedTexturesByAge`/`+allTextures`, and `Universe.mm` importing `OOFoundationBridge.h`
  in every flavour; `./mk.sh build deployment` compiles.

Test edits:
- `tests/unit/oofnd/test_ref.cpp`: the three tests above expect LIFO (was insertion order).
- `tests/source_paths.py`, `tests/gui`: source-text guards find a file by stem, any suffix.
- `tests/component/steps/world_steps.py`: a fixed hull per role, not a random ship draw.
- `tests/unit/oofnd/test_thread.cpp`: waits unbounded for its detached thread (the bounded wait
  could return while the thread used the test's stack frame).

## Verified

Not verified at `d9c3adfe40`.
