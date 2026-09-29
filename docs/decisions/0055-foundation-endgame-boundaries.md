# ADR-0055: The last Foundation boundary: what replaces each bridge helper, and what is left at Phase 2 exit

- Status: Proposed. The default is in effect until Jon decides (CLAUDE.md rule 10).
- Date: 2026-09-29
- Beads: oo-qps.30 (this ADR); seams oo-qps.31..45; chunks oo-qps.46..71; oo-qps.72 (retire the
  transitional forms); roll-ups oo-qps.11..15; then oo-qps.16 (delete the three bridge headers),
  oo-3rb.4, oo-qps.17..19. The bead map is at the end.

## Context

oo-qps.11..15 ("drop OOStringBridge / OOFoundationBridge / OOPListView uses", one per directory) all
stopped on 2026-09-29. The gate census (ADR-0054) could not see the problem because it exempts the
helper spellings at `--stage sweeps`: the helpers still *manufacture* Foundation objects at run time
and hand them to `id`-typed Objective-C APIs. Inventory on phase-2 d0269b244 (Core + SDL, minus the
three headers; scripts in `.agent-tmp/cc/qpsdrop/` and `.agent-tmp/cc/endgame/`):

| Kind | Lines | What it is |
|---|---:|---|
| `oo::StdString(KEY)` of an `@"..."` key constant | 562 | 122 constants in 15 headers (`KEY_*`, `GUI_KEY_*`, `kOO*`) |
| bridge `#include`/`#import` | 280 | 3 headers in 190 files |
| `oo::DescriptionOf(x)` where `x` is an object | 326 | `%@` text of `-description`; the call itself can stay |
| inside `-descriptionComponents` / `-shortDescriptionComponents` / `-description` overrides | 62 | 60 overrides return an `NSString` as `id` |
| Mac-fenced (`OOLITE_MAC_OS_X`) | 35 | AppKit / Apple Foundation code, Phase 5 (ADR-0043 item 18(b)) |
| everything else | 984 | Foundation values built for, or read back from, an `id` API |

The 984 "everything else" lines sort into a small number of boundaries:

- **Plist data handed to `id` consumers** (`ObjectFromPList`, `PListFrom`): `+[OOColor colorWithDescription:]`
  and its two siblings (34 lines), the cache manager's `cxx_objectForKey:` / `cxx_setObject:` (34),
  `OOProbabilitySet`'s `id` elements, script-event arguments, JS return values, `-objectForKey:` /
  `-intValue` / `-isEqual:` / `-writeToFile:` sent to a freshly built dictionary.
- **JavaScript slots** (`Core/Scripting`, 307 lines): `OOJS_RETURN_OBJECT(oo::NSStringFrom(...))`,
  `OOJSValueFromNativeObject(context, oo::ObjectFromPList(...))`, `NSArrayFromObjects` of entities,
  `doScriptEvent:withArgument:` with a boxed number or string (112 lines across the tree).
- **Selectors called by name** (164 lines): AI actions (`AI.mm`, 70 in `ShipEntityAI.mm`), legacy
  script actions and `_string`/`_number`/`_bool` queries (92 in `PlayerEntityLegacyScriptEngine.mm`),
  `ship.call()` (`OOJSCall.mm`), 74 HUD dials, joystick callbacks, deferred AI calls. ADR-0043
  item 21 kept them `id` because the dispatcher passes objects (`performSelector:withObject:`).
- **Legacy wrappers beside `cxx_` twins** (40 lines, 42 methods in 24 files): the Foundation-shared
  families (`-name`, `-setName:`, `-initWithName:`, `-title`, `-version`, `-state`, `-function`,
  `-dependencies`, `-initWithDictionary:`, `-initWithPath:`, `-initWithContentsOfFile:`) that
  `docs/phases/2-selector-families.md` left "to retire with oo-qps", plus the `hasEquipmentItem:`
  family (string or collection in one `id`).
- Unique selectors and C functions still typed `id` where an `NSString` or `NSDictionary` flows.

Phase 2's exit gate is "`libgnustep-base` absent from the link line; deny-list enforces it"
(docs/phases/2-oofnd.md). Once it is absent, no `NSString`/`NSArray`/`NSDictionary`/`NSNumber` object
can exist, so every boundary above must carry a C++ value instead. The decisions below pick the
C++ form that Phase 3 keeps (it converts `[x cxx_foo]` to `x->foo()` and drops the prefix, ADR-0043
item 6), so none of this is redone there.

## Decision (recommended defaults)

1. **`-description` and `%@` become C++ text on the root.** A new Foundation-free
   `Core/OODescription.h/.mm`, imported by `OOCocoa.h`, owns the family:
   - `OOObject (OODescription)`: `-cxx_descriptionComponents`, `-cxx_shortDescriptionComponents`,
     `-cxx_description`, `-cxx_shortDescription`, all `std::optional<std::string>` (zero-valid on a
     nil receiver, ADR-0043 fact 1); `-cxx_description` is `<ClassName 0xnnnnnnnn>{components}`
     exactly as `DescriptionWithComponents` builds it today. `OOConstantString` describes itself as
     its text.
   - `std::string oo::DescriptionOf(id)` keeps its name and meaning (nil gives `(null)`), so the 326
     call sites on objects do not change; `oo::ShortDescriptionOf(id)` is its short twin. An overload
     `oo::DescriptionOf(const oo::PList &)` gives exactly what `-[NSObject description]` gave for
     `oo::ObjectFromPList` of that value (strings as themselves, numbers as NSNumber printed them,
     arrays and dictionaries in GNUstep's `-descriptionWithLocale:indent:` layout, Object nodes as
     their object's description). It lives in oofnd (`oo::describe`), pinned by a unit test against
     output **captured from gnustep-base while it is still linked**, so it must land before oo-qps.18.
   - Transition: the root's `-cxx_descriptionComponents` default forwards to a legacy override
     while one exists, and `oo::DescriptionOf` falls back to `[[obj description] UTF8String]` for a
     non-`OOObject` receiver. The 60 overrides then flip in **one codemod commit**
     (`tools/codemods/description-family.py`), because a converted superclass would hide an
     unconverted subclass's override: the family cannot be flipped file by file. The same commit
     deletes the legacy root `-description` family from `OOCocoa.h/.mm`. The fallback goes in oo-qps.72.
   - Phase 3: `virtual std::optional<std::string> descriptionComponents() const`, the same signature.
2. **Plist data crosses as `oo::PList`; live objects inside it as Object nodes.** Every consumer
   that received `ObjectFromPList(...)` takes `const oo::PList &`; every producer that was
   `PListFrom(...)`'d returns `oo::PList`. `oo::PListObject(id)`, `oo::ObjectIn(plist)` and the
   Object-node class move unchanged out of `OOFoundationBridge.h` into a Foundation-free
   `Core/OOObjCPList.h`, which also gets `oo::PListFromObjects(vector<ObjCRef<T>>)` /
   `oo::ObjCRefsIn<T>(plist)` for arrays of objects (what `NSArrayFromObjects` / `ObjCRefsFrom` did).
   The consumers, each a seam that adds a `cxx_` twin and keeps the `id` form forwarding until oo-qps.72:
   - `+[OOColor cxx_colorWithDescription:]`, `+cxx_brightColorWithDescription:`,
     `+cxx_colorWithDescription:saturationFactor:` over `const oo::PList &` (a string, an array of
     components, a dictionary, or an Object node holding an OOColor, as the `id` form accepted);
   - `OOCacheManager -cxx_pListForKey:inCache:` / `-cxx_setPList:forKey:inCache:` (every cached
     value is plist data: AIs, shader configs, ship data, paths, condition scripts); `OOCache` stores
     `oo::PList`;
   - `OOProbabilitySet` elements are `oo::PList` (ship keys are strings; Object nodes for anything
     else); its `id` element API goes in the same bead with its two callers;
   - the `hasEquipmentItem:` / `hasAllEquipment:` family takes `const oo::PList &` (a string or an
     array/set of strings, exactly the "string or collection" it accepted), one family flip.
   Unique selectors and C functions (`Universe -cxx_setSystemDataKey:value:fromManifest:`,
   `OOJSScript -defineProperty:named:` / `-setProperty:named:`, `+[OOCharacter characterWithDictionary:]`,
   `-addEquipmentFromCollection:`, material `configuration:`, ...) change type in the chunk that
   removes their last bridge call, with their callers (ADR-0043 item 2). A lookup on a built
   dictionary becomes `PList::get<T>` / `at<T>` only where the conversion is the same (`get<T>` is
   `OOCollectionExtractors`'; `-intValue` of a string is not `get<int>`: keep the old semantics or
   stop); `-isEqual:` of two plists is `==`; `-writeToFile:` is `oo::writeXMLPList` /
   `OOWriteXMLPListToFile` (ADR-0043 item 15).
3. **Legacy wrappers are deleted, not renamed.** Every method marked
   `retires with oo-qps` (the Foundation-shared families' `id` forms) is deleted in one codemod
   commit (`tools/codemods/retire-legacy-wrappers.py`), and each caller moves to the `cxx_` twin;
   `-Werror=objc-method-access` (ADR-0050) finds every caller a deletion leaves behind. A split by
   file would leave `[obj name]` dispatching at run time to a class that no longer answers it, which
   aborts (ADR-0029). The `cxx_` prefix stays: Phase 3 drops it as it converts each call, so renaming
   now would change every call twice.
4. **JavaScript slots are PList (ADR-0051's path, finished).** Native to JS is
   `OOJSValueFromPList`: `OOJavaScriptEngine.h` adds `OOJS_RETURN_PLIST(plist)` and
   `OOJS_RETURN_STRING_OR_NULL(optional)` (null for nullopt, as `NSStringOrNil` gave); arrays of
   entities are `oo::PListFromObjects`. Script events take
   `-cxx_doScriptEvent:withPListArguments:(const std::vector<oo::PList> &)` on ShipEntity, with
   `oo::PListObject(entity)` for an object argument. The `id` forms `doScriptEvent:withArgument:` /
   `andArgument:` stay for OOObject arguments (not Foundation; Phase 3 converts them). JS to native is
   already `cxx_OOJSPListFromJSValue`; the `id` native-value family (`OOJSNativeObjectFromJSValue` & co.,
   which return `ObjectFromPList` of it) and `OOJSValueFromNativeObject`'s non-`OOObject` branch are
   deleted in oo-qps.72.
5. **A selector called by name has a C++ signature fixed by its dispatcher.** A new
   `Core/OOCallByName.h/.mm` calls a method by name through its IMP with one of these typed
   signatures, and every dispatcher uses it instead of `performSelector:withObject:`:

   | Dispatcher | Argument | Result |
   |---|---|---|
   | AI actions and deferred AI calls (`AI.mm`), legacy-script actions, `ship.call()` (`OOJSCall.mm`) | none, or `const std::string &` | `void` or `oo::PList` |
   | legacy-script queries (`*_string`, `*_number`, `*_bool`), expander `[selector]` keys | none | `oo::PList` (a string or number, as the `NSString`/`NSNumber` was) |
   | HUD dials (`HeadUpDisplay.mm`), joystick callbacks (`OOJoystickManager.mm`) | `const oo::PList &` | `void` |

   The helper reads the method's type encoding: a method still typed `id` is called with the bridged
   object (the one transitional bridge use, deleted in oo-qps.72), so the ~260 selectors flip file by file.
   `tools/check-selector-types.py --check` accepts a called-by-name selector only in its dispatcher's
   C++ signature or the transitional `id` form; `--strict-called-by-name` (in oo-qps.72 and oo-qps.16)
   rejects the `id` form. Phase 3 replaces the IMP lookup with the `unordered_map<string, handler>`
   of its recipe; the signatures stay. A boxed string class (`OOString : OOObject`) was rejected: it
   keeps every signature `id`, which Phase 3 would then retype, and adds a class Phase 3 deletes.
6. **Key constants become C++ constants in one codemod commit** (`tools/codemods/key-constants.py`):
   `#define KEY_X @"x"` and `NSString *const kX = @"x"` become `inline constexpr std::string_view`
   (oo-qps.8's form for `kOOManifest*`), `oo::StdString(KEY_X)` becomes `std::string(KEY_X)`, and the
   ~50 other uses are adapted by hand.
7. **Mac-fenced code is left as it is.** The 35 fenced lines keep their helper calls; the three
   headers are deleted anyway (oo-qps.16), and the Phase 5 Mac port restores the few helpers it needs
   (`git show <oo-qps.16>^:upstream/oolite/src/Core/OOFoundationBridge.h`; they are correct as written
   on Apple Foundation). No fenced copy of the bridge is kept: it could not be compiled or tested
   before Phase 5. The census treats helper calls on fenced lines like fenced NS tokens (information
   only), and the bridge includes are deleted tree-wide by oo-qps.16, not by the chunks.
8. **A codemod bead is sized by what its worker writes.** Items 1, 3 and 6 are mechanical
   tree-wide rewrites whose correctness is the script's (`--selftest`, `--check`), as oo-qps.10's
   `at-literals.py` was. Their beads may touch more than 8 files; the script and the hand-written
   residue stay within 400 lines, and a residue over that stops the bead for a split.
9. **Chunks, then roll-ups.** Every other line is removed by fleet chunk beads (<= 8 files each,
   stacked where they share a file). Each chunk's acceptance is
   `bash tools/check-foundation-free.sh --stage source --kind helper --paths <its files>` (the census
   gains `--paths` and `--kind`, reports every helper call qualified `oo::` at the source stage, and
   skips fenced lines). oo-qps.11..15 keep their directories and become roll-ups: the same check over
   the directory, depending on their chunks. Includes are not the chunks' business.

### What is left at Phase 2 exit

- **The floor** (ADR-0029): `OOObject` on libobjc2's count, `OOCopying`/`OOZone`, `OOException`,
  `OOAssert`, `oo::ObjCRef`, `@autoreleasepool`, `OOConstantString`/`OOTinyString` behind whatever
  `@"..."` literals remain (the flip is oo-3rb.4, unchanged), and `OOFoundationTypes.h`'s C types.
- **Game-side, Foundation-free**: `OODescription` (item 1), `OOObjCPList` (item 2),
  `OOCallByName` (item 5).
- **Names**: no Foundation class name (`NSString`, `NSArray`, `NSDictionary`, `NSNumber`, `NSObject`,
  ...) remains in unfenced source, because nothing declares one once `OOCocoa.h` stops importing
  Foundation (oo-qps.17 `#error`s beside it). No alias, typedef or shim class keeps one alive
  (ADR-0043 item 3). The only `NS`-prefixed names left are `OOFoundationTypes.h`'s allow-list (plain C
  types, kept by ADR-0029 decision 5) and Mac-fenced code (Phase 5). The link line is the gate; the
  names vanishing is its consequence, checked by the census and, per changed file, the deny-list.

## Consequences

- 15 seam beads (3 frontier: the description family, the PList description, the call-by-name ABI),
  26 chunks and one retirement bead; oo-qps.11..15 become roll-ups. The chain before the chunks is
  about seven waves deep, because the codemods touch most files and must not race the seams that
  share them.
- Description text, JS values, cache contents and dispatch results are meant to be byte-identical;
  the goldens decide, and a differing golden stops the bead. Item 1's PList description is the one
  place a new implementation replaces GNUstep text, so it is pinned by captured output.
- The capture for item 1 needs gnustep-base: it must land before oo-qps.18 unlinks it.
- `tools/check-string-expander.sh` (ADR-0052/0054) compiles the fenced `OO_EXPANDER_TEST_SURFACE`
  functions, which call `oo::NSStringOrNil`/`StdString`. oo-qps.16 must inline those conversions
  inside the fence (Foundation calls, compiled only by that harness). The harness still needs
  gnustep-base installed after oo-qps.18 (already recorded in ADR-0054).

## Alternatives considered

- **Flip the description family file by file.** A converted superclass hides an unconverted
  subclass's override, or an unconverted subclass's `[super descriptionComponents]` finds nothing;
  ordering leaves-first across ~48 files is fragile and silently wrong when mistaken.
- **Keep `id` on called-by-name selectors with a boxed `OOString`.** See item 5.
- **Keep a Mac-only copy of the bridge.** See item 7.
- **Keep NS names as aliases of oofnd types.** Would hide Foundation values from the census and the
  deny-list, which ADR-0043 item 3 forbids, and gives no behaviour.

## Bead map

Bead descriptions name seams by key. Frontier: S1, S3, S5; the rest are fleet.

| Key | Bead | What | Waits for |
|---|---|---|---|
| S1 | oo-qps.31 | `OODescription`: root `cxx_description*`, `DescriptionOf(id)`, codemod script (item 1) | - |
| S3 | oo-qps.32 | `oo::describe(PList)` pinned by captured gnustep-base output; `DescriptionOf(PList)` (item 1) | S1 |
| S4 | oo-qps.33 | `OOObjCPList.h`: Object nodes, `PListFromObjects`, `ObjCRefsIn` (item 2) | S1 |
| S5 | oo-qps.34 | `OOCallByName` and the selector-check rule; AI.mm dispatch (item 5) | S1 |
| S6 | oo-qps.35 | the other dispatchers onto `OOCallByName` (item 5) | S5, S3, S13 |
| S7 | oo-qps.36 | `OOCache` std::string -> PList; cache-manager PList API (item 2) | S4, S15 |
| S8 | oo-qps.37 | `+cxx_colorWithDescription:` family over PList (item 2) | S4 |
| S9 | oo-qps.38 | `OOJS_RETURN_PLIST`, `OOJS_RETURN_STRING_OR_NULL` (item 4) | S4 |
| S10 | oo-qps.39 | `-cxx_doScriptEvent:withPListArguments:` (item 4) | S4, S2 |
| S11 | oo-qps.40 | `OOProbabilitySet` elements are PList (item 2) | - |
| S12 | oo-qps.41 | `hasEquipmentItem:` family over PList (item 2) | S10, S6 |
| S13 | oo-qps.42 | key-constants codemod (item 6) | S11 |
| S2 | oo-qps.43 | description codemod applied; legacy root family deleted (item 1) | S1, S4, S5, S7, S8, S9, S11, S13 |
| S14 | oo-qps.44 | legacy-wrapper retirement codemod (item 3) | S2, S6, S10, S12 |
| S15 | oo-qps.45 | census `--paths`, `--kind helper`, fence-aware (items 7, 9) | - |
| C11.1..C15.4 | oo-qps.46..71 | 26 chunks (item 9): .11 -> .46-.47, .12 -> .48-.53, .13 -> .54-.60, .14 -> .61-.67, .15 -> .68-.71 | S14, S15, S4 and the seams their files use |
| R | oo-qps.72 | retire the transitional id forms (items 1, 2, 4, 5) | every chunk |

oo-qps.11..15 wait for their chunks (.12 and .14 also for R); oo-qps.16 waits for them, R and S3.

## History

- 2026-09-29: proposed by the frontier planner after oo-qps.11..15 stopped; default in effect.
- 2026-09-29, Amendment 1 (oo-qps.43, item 1): the codemod flipped the 60 overrides and the legacy
  root family is gone from `OOCocoa.h/.mm`, but OODescription.mm's forwarding to a legacy override
  stays until oo-qps.72: `tests/unit/oofnd/test_objc_description.mm` pins it, and it is dead in the
  game (no class declares the legacy family; it is called through the IMP). Two consequences of the
  deletion were fixed in the same commit: `oo::ShortDescriptionOf` of a Foundation value, which no
  longer answers `-shortDescription`, prints `<ClassName 0xnnnnnnnn>` as the NSObject default did;
  and `oo::DescriptionOf(oo::ObjectFromPList(p))` is `oo::DescriptionOf(p)` tree-wide (and
  `NSArrayFromObjects` in a description is `PListFromObjects`), because GNUstep describing a
  collection sends `-description` to each element, which an OOObject no longer answers.
