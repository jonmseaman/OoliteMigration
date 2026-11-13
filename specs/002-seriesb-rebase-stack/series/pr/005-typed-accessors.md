# Move most oo_*ForKey dictionary accessors to typed PListView::get

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 5/28. Replays `series/007-typed-accessors`.

## What this changes

- ~1,180 `oo_<type>ForKey:`/`oo_<type>AtIndex:` calls in 73 files become
  `oo::PListView(dict).get<T>(key, fallback)`/`.at<T>(index, fallback)`, same receiver, key,
  fallback and conversion; `oo_boolForKey:` → `get<bool>` (~100 sites; no `BOOL` row). Not done
  yet: `PlayerEntity.mm`, `Universe.mm`, `ShipEntity.mm`, `HeadUpDisplay.mm` and ~12 smaller
  files; `OOCollectionExtractors` stays.
- 83 classes rerooted from `NSObject` onto `OOObject`; the game's `NSObject` categories get
  `OOObject` twins, and GNUstep's `NSObject` methods come from `OOObjectGNUstepBridge`.
- Six `oofnd` components with tests: `String`, `Encoding`, `Log` (behind `OOLogging.mm`), `Date`,
  `Notification`, `StdLib`; plus `objc/OOObjCRef.h`. `PList`'s date and XML readers match GNUstep
  in more edge cases (unused by the game yet).
- `OOLogOutputHandler.mm` moves to `std::mutex`/`condition_variable`; the JS reset notifications
  also post on `oo::NotificationCenter`, which `OOJSTimer` observes. Bridge headers:
  `OOStringBridge.h`, `OOFoundationBridge.h`, `OOObjectGNUstepBridge.h`.

## Why

Through `PListView`, the later switch to `oo::PList` is `x.get<T>(k)` with nothing else to edit;
the reroots and components are what steps 6 and 7 build on.

## Behaviour changes

None intended:
- Typed lookups convert as the `oo_*ForKey:` they replace (`nil` receiver gives zero/nil/NO, not
  the fallback; `"yes"` is true). Pinned by `tests/unit/oofnd/test_plist_get.cpp`; call sites not
  pinned.
- `oo::log` reproduces the Objective-C `OOLogging.mm` transcript line for line. Pinned by
  `test_log.cpp`.
- Strings and encodings match GNUstep. Pinned by `test_string.cpp`, `test_string_compare.cpp`,
  `test_encoding.cpp`.
- Notifications. Pinned by `test_notification.cpp`.
- `OOJSTimer` releases its JS values at shutdown via the `oo` reset from `-shutDown` (was via
  `NSNotificationCenter`; without it timers leak). Not pinned.
- Rerooted classes keep `-description`, `+description`, `-className`,
  `-methodSignatureForSelector:`, `-performSelector:withObject:afterDelay:`. Floor pinned by
  `test_objc_floor.mm`, `OOObjCRef` by `test_objc_ref.mm`; the reroots are not pinned.

The step-2 tiers also run.

## How to review

Start with "Migrating oo_*ForKey" in `src/oofnd/README.md` (rewrite rule, `<type>` → `T` table),
then `src/Core/OOPListView.h`. Rule: each removed `oo_*ForKey:`/`oo_*AtIndex:` line has an added
`PListView` line with the same receiver, key and fallback:

    git diff -U0 seriesb/004-oofnd-core seriesb/005-typed-accessors -- src/Core/OOShipRegistry.mm \
      | grep -E '^[-+].*(oo_[a-zA-Z]+(ForKey|AtIndex)|PListView)'

Reroots: `: NSObject` → `: OOObject`, `<NSCopying>` → `<OOCopying>`. Real reads: `Log.hpp` with
`OOLogging.mm`; `OOLogOutputHandler.mm`'s threading; `String.hpp`/`Encoding.hpp` (~3k lines);
`OOObjectGNUstepBridge.mm` and the twins; `OOJavaScriptEngine.mm` `-reset`/`-shutDown` with
`OOJSTimer.mm`; the bridge headers' banners (`nil`, lone surrogates).

## Verified

Not verified at `71752bcbde`.
