# ADR-0051: Values crossing the JavaScript boundary are oo::PList; plain-object integer keys become strings

- Status: Proposed. The default is in effect until Jon decides.
- Date: 2026-09-29
- Beads: oo-k1y8 (and its children); oo-vp0y (deletes the bridge this makes unnecessary)

## Context

`OOJavaScriptEngine+FoundationBridge` holds the last Foundation code in the JavaScript engine:

- categories on NSObject, NSString, NSArray, NSDictionary and NSNumber that implement
  `-oo_jsValueInContext:` (native to JS) and the `-oo_js*` description methods;
- the converter for plain JS objects, `OOJSDictionaryFromJSObject`. For JS to native, it builds
  an `NSMutableDictionary`.

The engine's own JS-to-native converters also build Foundation objects. These are the
`OOJSNativeObjectFromJSValue` family and the array, string, number and boolean converters.
The rest of the game sends them Foundation objects in two ways:

- 19 `OOJSValueFromNativeObject` calls pass `oo::NSStringFrom(...)` or `oo::ObjectFromPList(...)`.
- About a dozen `-oo_jsValueInContext:` sends go to objects that may be Foundation objects.

The family has 65 call sites in 21 files.

The Foundation plain-object converter keeps an int32 property id, such as `{1: "a"}`, as an
`NSNumber` key. Its comment (CIM, 15/2/13) says this breaks native code that expects string
keys, for example `mission.runScreen` choices. `oo::PListFrom` cannot represent a number key,
so every PList consumer already receives a null PList for such an object. The PList converter
`cxx_OOJSDictionaryFromJSObject` does the same on purpose.

## Decision (recommended default)

1. **JS to native is `oo::PList`.**
   - `cxx_OOJSPListFromJSValue` and `cxx_OOJSPListFromJSObject` return exactly what
     `oo::PListFrom(OOJSNativeObjectFromJSValue(...))` returned:
     - int32 becomes a signed integer, and a double becomes a real;
     - a boolean becomes a bool, and a string becomes a string;
     - a JS array becomes an array, with a null or undefined element as a `PList::Object`
       holding `[OONull null]`;
     - a plain object becomes a dictionary;
     - an object of a class with a registered private-object converter becomes a
       `PList::Object` node holding that object.
   - The id family now returns `oo::ObjectFromPList` of the PList form, so it produces the
     same objects as before.
   - The engine no longer has a Foundation converter. Call sites move to the PList form where
     their consumer takes a PList. A call site whose consumer takes an `id`, such as
     `+[OOColor colorWithDescription:]` or `+[OOCharacter characterWithDictionary:]`, keeps the
     id form until that consumer has a PList form.
2. **Plain-object integer keys become strings.**
   - An int32 property id is keyed by its decimal text: `{1: "a"}` gives `{"1": "a"}`. JS
     property names are strings, and a script cannot tell `o[1]` from `o["1"]`.
   - This replaces two behaviours: the `NSNumber` key that no consumer could look up by
     string, and the null result `cxx_OOJSDictionaryFromJSObject` gave.
   - Plain-object results are no longer mutable. No consumer mutated one.
3. **Native to JS takes a PList, and Foundation objects are converted through it.**
   - `OOJSValueFromPList(context, plist)` returns what
     `OOJSValueFromNativeObject(context, oo::ObjectFromPList(plist))` returned:
     - a bool becomes the number 1 or 0, which is what an `NSNumber` bool gave JS;
     - an integer within int32 range becomes an int32, and anything else becomes a double;
     - a single-precision real becomes the double of its float;
     - data and dates become undefined;
     - null array elements and null dictionary values are dropped, as `ObjectFromPList`
       dropped them;
     - empty dictionary keys are skipped;
     - a `PList::Object` node converts its object.
   - `OOJSValueFromNativeObject` converts an object whose root class is not `OOObject`
     through `oo::PListFrom`. A non-plist Foundation object becomes undefined, as the NSObject
     category gave.
   - Direct `-oo_jsValueInContext:` sends to objects that may be Foundation objects become
     `OOJSValueFromNativeObject` calls.
   - After these changes, only OOObject-rooted classes answer the `-oo_js*` selectors. The
     bridge's categories are then deleted with the bridge (oo-vp0y).

## Consequences

- A JS object with an index-like key reaches native code as a dictionary with string keys,
  where it was a null PList (or an unreachable `NSNumber` key). Golden-visible only if a
  script passes such an object. The goldens decide; a differing golden stops the bead.
- An `NSDictionary` handed to JS was converted in its hash order. Its PList form converts in
  key (byte) order, so a script's `for...in` over such an object may see keys in a different
  order. An `NSNumber`-keyed dictionary handed to JS (none is known) would become null.
- `OOJSValueFromNativeObject` is no longer inline. It costs one root-class walk per call.
- The remaining `oo::PListFrom` / `oo::ObjectFromPList` uses in the engine are Foundation
  boundary helpers from `OOFoundationBridge.h`. They go with oo-qps.14. By then, no id caller
  may hand the engine a Foundation object; the family's id forms keep only private objects.

## Alternatives

- Keep `NSNumber` keys: impossible without Foundation.
- Keep the null result for integer keys: this silently drops data a script passed, which is
  the defect the 2013 comment describes.

## History

- 2026-09-29: proposed by the oo-k1y8 sweep worker at the orchestrator's request (integer-key default from the oo-vp0y notes).
