# Move most oo_*ForKey dictionary accessors to typed PListView::get

**Series:** step 6 of 25 · base `series/005-oofnd-core` · next `series/007-foundation-wave-1` **(gen)**

**Chapter:** P2 · 2.2 typed accessors, first sweep · history `b73f2cd400`..`bc9a02ca7b` (108 merges) · 11.1k src, 2.1k tests, 43 other changed lines; 0 lines in deleted files **(gen)**

## What this changes

About a thousand `oo_<type>ForKey:` and `oo_<type>AtIndex:` calls (OOCollectionExtractors) in 73
files become `oo::PListView(dict).get<T>(key, fallback)` / `.at<T>(index, fallback)`. The receiver,
key and fallback are unchanged, and the conversion function is the same one, so the result is the
same. This is not yet the whole sweep. `PlayerEntity.mm`, `ShipEntity.mm`, `Universe.mm`,
`HeadUpDisplay.mm` and a few smaller files still use the old calls, and `OOCollectionExtractors`
stays.

About 80 game classes are rerooted from `NSObject` onto the
Foundation-free `OOObject` from step 5. Six new `oofnd` components arrive with their tests:
- `String` and `Encoding`: string operations and text encodings matching GNUstep's;
- `Log`, which `OOLogging.mm` now delegates to;
- `Date`, `Notification` and `StdLib`.

`OOLogOutputHandler.mm` swaps its Foundation lock and timer for `std::mutex`, `std::condition_variable`
and a `steady_clock` deadline. Three temporary bridge headers let migrated code talk to code that
still holds Foundation objects: `OOStringBridge.h`, `OOFoundationBridge.h` and
`OOObjectGNUstepBridge.h`.

## Why

Typed lookups are the widest Foundation dependency in the game. Routing them through
`oo::PListView` now means that when a file's containers later become `oo::PList`, each call
changes from `oo::PListView(x).get<T>(k)` to `x.get<T>(k)` with nothing else to edit. The reroots,
the logging port and the new components are the next layer that the later Foundation steps need:
they stop classes depending on `NSObject`, and give string, log and notification code something
to move to. They come after step 5, because they build on `OOObject`, `PList` and `Thread`, and
before the bulk Foundation steps (7 and 8), which use them.

## Behaviour changes

None intended:
- **Typed lookups.** `PListView` uses the same lookup and conversion as the method it replaces,
  including a `nil` receiver returning zero/nil/NO rather than the fallback. The C++ form of those
  conversions is tested by `tests/unit/oofnd/test_plist_get.cpp`.
- **Log output.** `oo::log` must produce, line for line, the transcript of the Objective-C
  `OOLogging.mm` it replaces. `tests/unit/oofnd/test_log.cpp` checks this against a transcript
  captured from the original.
- **Strings and encodings** are tested against GNUstep by `tests/unit/oofnd/test_string.cpp`,
  `test_string_compare.cpp` and `test_encoding.cpp`.
- **Notifications** are tested by `tests/unit/oofnd/test_notification.cpp`.
  `OOJavaScriptEngine -reset` posts its notifications to both `oo::NotificationCenter` and
  `NSNotificationCenter` (the `oo` one first) until every observer has moved.
- **Rerooted classes** keep `NSObject`'s `-description` text through `OOObjectGNUstepBridge`.
  `tests/unit/oofnd/test_objc_ref.mm` tests the `OOObjCRef` holder.

The step-1 tiers (`tests/component/`, `tests/gui/`) also run against this step.

## How to review

Start with the "Migrating oo_*ForKey" section of `src/oofnd/README.md`: it gives the rewrite rule
and the `<type>` → `T` table. Then read `src/Core/OOPListView.h`. The call-site rewrite is
mechanical. To spot-check a file, confirm that each removed `oo_*ForKey:`/`oo_*AtIndex:` line has
a matching added `PListView` line with the same receiver, key and fallback:

    git diff -U0 series/006-typed-accessors^ series/006-typed-accessors -- src/Core/OOShipRegistry.mm \
      | grep -E '^[-+].*(oo_[a-zA-Z]+(ForKey|AtIndex)|PListView)'

The reroots are also mechanical: an `@interface X : NSObject` becomes `: OOObject`, an
`<NSCopying>` becomes `<OOCopying>`, and the file imports `oofnd/objc/OOObject.h`.

These need a real read:
- `src/oofnd/Log.hpp` with `src/Core/OOLogging.mm`;
- `src/Core/OOLogOutputHandler.mm`: the threading changes;
- `src/oofnd/String.hpp` and `Encoding.hpp` (about 3k lines), next to their tests;
- `src/Core/OOStringBridge.h` and `OOFoundationBridge.h`. Each header's banner states how exact
  the bridge is, including the `nil` and lone-surrogate cases.

## Verified **(gen)**

Windows x64, `ef3196aaa5`, 2026-11-02.

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
