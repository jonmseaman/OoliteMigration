# Drop gnustep-base, then convert the first classes to C++: maths, leaf utilities, OXP verifier

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 9/28. Replays `series/011-leaf-conversions`.

## What this changes

- Removes gnustep-base: `@"..."` literals are `OOConstantString`; Windows links only libobjc2;
  the last bridge headers are deleted. `poc/` now builds on Windows (new
  `poc/tests/primitive_property.js`).
- Converts the maths, ~20 leaf utilities, the OXP verifier stages, the Materials roots and four
  JS binding files to C++ (`oo::Ref`), each behind an `X+ObjCBridge` forwarder (34 pairs);
  `oo::ObjCPeers` keeps one bridge per object.
- New meson suite `core`: 57 tests, one per converted class, plus `test_OoliteEquipmentControlScript`
  (pins #369's fix). Built on Windows, non-release only.

## Why

Finishes the Foundation removal (steps 6-8) and sets the conversion style steps 10-13 follow.

## Behaviour changes

- A C++ exception in a JS native is a script error (was a process abort). Pinned by
  `test_OOJSVector.mm`, `test_OOJSQuaternion.mm`, `test_OOJSClock.mm`.
- Windows: a reversed `OOHighResTimeDeltaInSeconds` is negative (was ~49.7 days). Pinned by
  `test_OOProfilingStopwatch.mm`.
- `"\x7F"` at the end of a string no longer asserts. Pinned by `test_string_expander.mm` (not
  built by meson).
- A bad expansion-override warning prints the value, not `<Class 0x…>`. Not pinned.

## How to review

Start with `OOColor.*`, `OOColor+ObjCBridge.*` and `test_OOColor.mm`. Rule: bodies verbatim
except message syntax (`[x foo:a]` -> `x->foo(a)`, alloc/init -> `oo::makeRef`, `BOOL` -> `bool`,
nil messages -> null-guarded). Spot-check a class against its `@implementation` on
`seriesb/008-selector-families`.

Test edits:
- `test_objc_description.mm`: drops cases for deleted code.
- `tests/gui` g2/g6/g8/g9: guards also accept the C++ spelling.
- expander/sysdesc: local copies of deleted conversions; plist digests re-captured (#747).

## Verified

Not verified at `cd191bf28f`.
