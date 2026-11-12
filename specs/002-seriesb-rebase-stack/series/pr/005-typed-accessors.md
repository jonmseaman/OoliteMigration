# Move most oo_*ForKey dictionary accessors to typed PListView::get

**Series:** step 5 of 26 · base `seriesb/004-oofnd-core` · next `seriesb/006-foundation-wave-1` **(gen)**

**Replays:** `series/007-typed-accessors` (old 7 of the master-based series) · 11.0k src, 2.0k tests, 15 other changed lines; 0 lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

About 1,180 `oo_<type>ForKey:` and `oo_<type>AtIndex:` calls (OOCollectionExtractors) in 73 files
become `oo::PListView(dict).get<T>(key, fallback)` / `.at<T>(index, fallback)`. The receiver, key
and fallback are unchanged, and the conversion function is the same one, so the result is the same.
`oo_boolForKey:` becomes `get<bool>` (about 100 sites): `PListView` has no `BOOL` row, and `BOOL`
would be read as a number outside Windows. This is not yet the whole sweep: `PlayerEntity.mm`,
`Universe.mm`, `ShipEntity.mm`, `HeadUpDisplay.mm` and about a dozen smaller files still use the old
calls, and `OOCollectionExtractors` stays.

83 game classes are rerooted from `NSObject` onto the Foundation-free `OOObject` from step 4. What
the game's own `NSObject` categories gave them gets an `OOObject` twin next to each category
(`OODescriptionComponents` in `OOFoundation.mm`, `OODeepCopy`, `OOWeakReference`, the JavaScript
conversion, and `OOExtensions`' size methods for the debug monitor). What GNUstep's `NSObject`
gave them comes from `OOObjectGNUstepBridge` until the code that uses it is converted.

Six new `oofnd` components arrive with their tests:
- `String` and `Encoding`: string operations and text encodings matching GNUstep's;
- `Log`, which `OOLogging.mm` now delegates to;
- `Date`, `Notification` and `StdLib`.

`oofnd/objc/OOObjCRef.h` adds an owning holder for Objective-C objects. `PList`'s date reader and
`PListXML`'s encoding and UTF-8 handling are corrected to match GNUstep in more edge cases (a day
or month of 0, a zone offset beyond 18 hours, an empty or unknown encoding name, text cut inside a
UTF-8 character); the game does not use these readers yet.

`OOLogOutputHandler.mm` swaps its Foundation lock and timer for `std::mutex`,
`std::condition_variable` and a `steady_clock` deadline. `OOJavaScriptEngine` posts its
will-reset and did-reset notifications on `oo::NotificationCenter` as well as
`NSNotificationCenter` (the `oo` one first), from `-reset` and from `-shutDown`; `OOJSTimer` now
observes the `oo` one. Three temporary bridge headers let migrated code talk to code that still
holds Foundation objects: `OOStringBridge.h`, `OOFoundationBridge.h` and
`OOObjectGNUstepBridge.h`.

## Why

Typed lookups are the widest Foundation dependency in the game. Routing them through
`oo::PListView` now means that when a file's containers later become `oo::PList`, each call
changes from `oo::PListView(x).get<T>(k)` to `x.get<T>(k)` with nothing else to edit. The reroots,
the logging port and the new components are the next layer that the later Foundation steps need:
they stop classes depending on `NSObject`, and give string, log and notification code something
to move to. They come after step 4, because they build on `OOObject`, `PList` and `Thread`, and
before the bulk Foundation steps (6 and 7), which use them.

## Behaviour changes

None intended:
- **Typed lookups.** `PListView` uses the same lookup and conversion as the method it replaces,
  including a `nil` receiver returning zero/nil/NO rather than the fallback. Booleans go through
  the `bool` row, which converts as `oo_boolForKey:` does (so `"yes"` is true). The C++ form of
  those conversions is tested by `tests/unit/oofnd/test_plist_get.cpp`; the `PListView` call
  sites are not pinned by a test of their own.
- **Log output.** `oo::log` must produce, line for line, the transcript of the Objective-C
  `OOLogging.mm` it replaces. `tests/unit/oofnd/test_log.cpp` checks this against a transcript
  captured from the original.
- **Strings and encodings** are tested against GNUstep by `tests/unit/oofnd/test_string.cpp`,
  `test_string_compare.cpp` and `test_encoding.cpp`.
- **Notifications** are tested by `tests/unit/oofnd/test_notification.cpp`. Posting the reset
  notification from `-shutDown` on the `oo` centre keeps `OOJSTimer` releasing its JavaScript
  values at shutdown, as it did when it observed `NSNotificationCenter`; without it the timers
  leak. That is not pinned by a test at this step.
- **Rerooted classes** keep their `-description` text through `OOObject (OODescriptionComponents)`,
  and NSObject's `+description`, `-className`, `-methodSignatureForSelector:` and
  `-performSelector:withObject:afterDelay:` through `OOObjectGNUstepBridge`. The floor's
  allocation, copying and hashing are tested by `tests/unit/oofnd/test_objc_floor.mm`, and the
  `OOObjCRef` holder by `test_objc_ref.mm`; the reroots themselves are not pinned by a test.

The step-2 tiers (`tests/component/`, `tests/gui/`) also run against this step.

## How to review

Start with the "Migrating oo_*ForKey" section of `src/oofnd/README.md`: it gives the rewrite rule
and the `<type>` → `T` table. Then read `src/Core/OOPListView.h`. The call-site rewrite is
mechanical. To spot-check a file, confirm that each removed `oo_*ForKey:`/`oo_*AtIndex:` line has
a matching added `PListView` line with the same receiver, key and fallback:

    git diff -U0 seriesb/004-oofnd-core seriesb/005-typed-accessors -- src/Core/OOShipRegistry.mm \
      | grep -E '^[-+].*(oo_[a-zA-Z]+(ForKey|AtIndex)|PListView)'

The reroots are also mechanical: an `@interface X : NSObject` becomes `: OOObject`, an
`<NSCopying>` becomes `<OOCopying>`, and the file imports `oofnd/objc/OOObject.h`.

These need a real read:
- `src/oofnd/Log.hpp` with `src/Core/OOLogging.mm`;
- `src/Core/OOLogOutputHandler.mm`: the threading changes;
- `src/oofnd/String.hpp` and `Encoding.hpp` (about 3k lines), next to their tests;
- `src/Core/OOObjectGNUstepBridge.mm` and the `OOObject` twins in `OOFoundation.mm`,
  `OODeepCopy.mm`, `OOWeakReference.mm`, `NSObjectOOExtensions.mm` and `OOJavaScriptEngine.mm`;
- `src/Core/Scripting/OOJavaScriptEngine.mm` (`-reset`, `-shutDown`) with `OOJSTimer.mm`;
- `src/Core/OOStringBridge.h` and `OOFoundationBridge.h`. Each header's banner states how exact
  the bridge is, including the `nil` and lone-surrogate cases.

## Verified **(gen)**

Not verified at this branch's tip (`71752bcbde`) yet: the last record is for `39f37df90b` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
