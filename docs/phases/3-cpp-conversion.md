# Phase 3 — Objective-C → C++20 conversion

**Status:** not started · **Est.:** 12–24 eng-months · **Depends on:** [Phase 1](1-js-engine.md) and [Phase 2](2-oofnd.md)
**Runs in parallel with:** partly with itself (independent modules), under the freeze policy.

## Goal

The long grind: ~500 files, leaves inward, one module per merge batch, goldens green at every step.
Conservative **C++20** only ([ADR-0001](../decisions/0001-bridge-then-convert.md),
[ADR-0011](../decisions/0011-cpp20-then-cpp23.md)); the C++23 upgrade is Phase 6; intrusive refcounting
only ([ADR-0003](../decisions/0003-intrusive-refcount.md)); modernisation waits for Phase 6. This is
the largest fan-out phase and the least seam-bound, and it is the phase the meta-experiment
([I4 metrics](../infra/4-metrics.md)) is really about.

## Entry gate

- [ ] Phase 1 and Phase 2 exit gates green
- [ ] **Exemplars exist:** `OOColor` and `Core/OXPVerifier` converted by a frontier agent in an interactive session. They set the house style every generated story references. **Do not fan out before this.** Fanning out first yields 200 files in 200 styles and a review burden larger than the original work. (`oomath` is not the exemplar: it has no classes, [ADR-0012](../decisions/0012-c-stays-c.md).)
- [ ] Tier A measured < 30 s on a converted leaf file
- [ ] Freeze policy per module in force ([architecture §6.3](../architecture.md) item 5); `docs/UPSTREAM_DELTA.md` exists

## Exit gate

- [ ] Zero `@implementation` in `src/` (`grep -rc '@implementation' src` is 0)
- [ ] Every `.m` file that had no `@implementation` is now `.c`, byte-for-byte the same code ([ADR-0012](../decisions/0012-c-stays-c.md))
- [ ] All goldens reproduce; Tier-1 corpus green; ASan clean; Windows clean at `-Wall -Wextra`
- [ ] The six giant files converted (frontier + human; tracked individually in the status log)

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| `OOColor` conversion: the first class, establishes house style | `src/Core/OOColor.h/.mm` + `OOColor+ObjCBridge.h/.mm`, `tests/unit/core/test_OOColor.mm` ([ADR-0056](../decisions/0056-phase3-class-conversion-house-style.md); done, oo-11m) | Frontier agent, days |
| `Core/OXPVerifier` conversion (real class hierarchy pilot, 27 files, own test data) | `src/oxp/verifier/` | Frontier agent |
| Per-module pattern for each of: `Materials`, `ooaudio`, `ooscript` bindings, `ooentity` base | one converted file per module | Frontier agent |
| The six giant files (`ShipEntity` 14,945 · `PlayerEntity` 13,718 · `Universe` 11,297 · `PlayerEntityControls` 5,690 · `HeadUpDisplay` 4,497 · `OOJSShip` 4,399) | themselves | **Frontier agent, weeks each, category file by category file.** 200k+ token closures; not fleet work. |
| Pre-splitting files > 400 lines into story-sized slices (category files already do this for `PlayerEntity`) | a slice plan per file: `docs/phases/3-slices/<File>.md`, checked by `python3 tools/check-slice-plan.py <plan>` (every method/function in exactly one slice or verbatim; each slice reads < 1,500 lines) | frontier |

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| `.m` → `.c` renames (no `@implementation`) | one file | `grep -L '@implementation' $(find src -name '*.m')` | — | ~10 | first; mechanical |
| Leaf files ≤ 400 lines | one file | `grep -l '@implementation' $(find src -name '*.m' -size -20k)` | `oomath` / `OXPVerifier` files | ~138 at 1 each | module order below |
| Files 400–1,500 lines | one pre-split slice | slice plans | per-module exemplar | ~62 × 1.5 + 30 × 3 | after the module's pattern seam |
| Files 1,500–4,000 lines (19 files, 22% of lines) | frontier, one at a time | Appendix A | — | ~11 × 7 | real design content in each |

Total ≈ 400 stories, inside the 240–960 band from the effort estimate.

## Work items (module order)

Suggested order (dependency-driven, and it front-loads the pattern-setting work):

1. `oomath` — `OOVector`, `OOHPVector`, `OOMatrix`, `OOQuaternion`, `OOTriangle`: **rename to
   `.c`, do not convert** ([ADR-0012](../decisions/0012-c-stays-c.md)). `Octree` is a real class
   and joins step 3. House style is set by `OOColor` then `OXPVerifier`.
2. `Core/OXPVerifier` — 27 files, standalone, has its own test data. The ideal pilot for a *real*
   class hierarchy.
3. Leaf utilities — `OOColor`, `OOCache`, `OORoleSet`, `OOProbabilitySet`, `OOPriorityQueue`,
   `OOCommodities`, `OOEquipmentType`, `OOCharacter`.
4. `Materials` / `oorender` (47 files) — self-contained behind `OODrawable`/`OOMaterial`.
5. `ooaudio` — the `OOAL*` family; already a thin OpenAL wrapper.
6. `ooscript` — the ~45 JS binding classes. Voluminous but repetitive; the façade from Phase 1
   already isolates the engine.
7. `ooentity` — `Entity` → `OOEntityWithDrawable` → `ShipEntity` → `StationEntity`/`PlayerEntity`.
   **`ShipEntity` (14,945 lines, 186 ivars, 565 methods) and `PlayerEntity` (13,718 lines) are the
   hardest artefacts in the project.** Budget real time. The existing category split
   (`PlayerEntityControls`, `PlayerEntityContracts`, `PlayerEntityLoadSave`, …) translates directly
   to member functions defined across multiple `.cpp` files, so the file decomposition survives.
8. `Universe` (11,297 lines, 122 ivars, 302 methods) — last. Everything points at it.

### Per-file recipe

| Objective-C | C++20 |
|---|---|
| `@interface X : Y` + ivar block | `class X : public Y { … }` |
| `@interface X (Private)` in the `.m` | private member functions |
| `@interface X (Feature)` in its own file | member functions defined in `XFeature.cpp` |
| `@interface NSString (OOFoo)` | free functions in `namespace oo::str` |
| `- (T) foo` / `+ (T) foo` | member / `static` member function |
| `[obj msg:a with:b]` | `obj->msg(a, b)` |
| `[[X alloc] init…]` | `oo::make<X>(…)` returning `Ref<X>` |
| `[x retain]` / `[x release]` | `Ref<T>` assignment (usually just deleted) |
| `[x autorelease]` | return `Ref<T>` by value |
| `@protocol P` | abstract base class, or a concept where no dynamic dispatch is needed |
| `id<P>` | `P*` / `Ref<P>` |
| `[x isKindOfClass:[Y class]]` | `dynamic_cast<Y*>(x)` — **but review each: many want a virtual or a type tag** |
| `@try/@catch/@throw` | `try/catch/throw` |
| `NSAutoreleasePool` | scope exit / `Ref` |
| `@selector(foo)` + `performSelector:` | `&X::foo` or `std::function` |
| `NSSelectorFromString(s)` | explicit `unordered_map<string, handler>` — the 10 sites need individual design |
| `nil` / `NO` / `YES` | `nullptr` / `false` / `true` |
| `NSLog` / `OOLog` | `oo::log` (`std::format`-based) |

Files are `.mm` throughout this phase; `.mm` → `.cpp` is Phase 4.

### Converting a class: the house style ([ADR-0056](../decisions/0056-phase3-class-conversion-house-style.md))

Exemplar: `src/Core/OOColor.h` / `OOColor.mm` (the class), `OOColor+ObjCBridge.h` / `.mm` (its
façade), `tests/unit/core/test_OOColor.mm` (its test). Open them and do what they do.

1. **Files.** Keep `X.h` / `X.mm`: the C++ class is declared in `X.h`, defined in `X.mm`.
2. **Shell.** `class X : public oo::RefCounted` (or the converted superclass). Ivars become
   private members with the same names, `= {}`. Private-category methods become private members.
3. **Names.** Member = the selector's first keyword (`colorWithRed:green:blue:alpha:` →
   `colorWithRed(r, g, b, a)`); a shared first keyword → overloads; drop `cxx_`. Class methods →
   `static`.
4. **Types.** `X *` result → `oo::Ref<X>`; `X *` parameter → `X *`; `BOOL` → `bool`; Phase 2's
   C++ types stay exactly (`std::optional<std::string>` included). No `const` except
   `descriptionComponents() const`.
5. **Bodies verbatim** but for message syntax. `[[X alloc] init]` → `oo::makeRef<X>()`;
   `[[self retain] autorelease]` → `oo::Ref<X>(this)`. A message to something that may be nil →
   a null-guarded call doing what nil did. An out-parameter nil left unwritten → zero-initialised.
   `OOAssert`/`OOParameterAssert` → `OOCAssert`/`OOCParameterAssert`. A selector called by name →
   an explicit table (`kNamedColors`). `-cxx_descriptionComponents` →
   `descriptionComponents() const`.
6. **Façade, while any file outside the bead still messages `X`.** The class is `cxx::X`.
   - `X+ObjCBridge.h` holds the old `@interface` copied exactly, with one ivar
     `oo::Ref<cxx::X>`. Each method forwards in one line.
   - Crossings go through `oo::ToObjC(cxx::X *)` / `oo::ToCxx(X *)`. They keep one façade per
     object through `oo::ObjCPeers`, and the façade's `-dealloc` forgets it.
   - Import the bridge as the last line of `X.h`. Add `'X+ObjCBridge.mm'` after `'X.mm'` in
     `meson.build`.
   - File the deletion bead:
     `bd create "Delete X+ObjCBridge" -l fleet,phase:3,sweep:objc-bridge`. It removes the bridge
     files and moves `cxx::X` to the global namespace.
   - With no outside caller, there is no façade and the class is global.
   - **Object needs the game graph** (ADR-0056 amendment oo-44gg; exemplar
     `src/Core/CollisionRegion.*`): the test's meson entry is `['*']` (every game object but
     `main.mm`'s) and the test defines `gDebugFlags`. A second argumentless initialiser takes a
     tag struct (`CollisionRegion(AsUniverse)`); an initialiser that returned nil on failure
     raises; a file-static function reading private ivars becomes a private static member.
   - **An initialiser that answers nil for bad input** (ADR-0056 amendment oo-novu; exemplar
     `src/Core/Octree.*`) becomes a static factory of the same name returning null
     (`Octree::initWithDictionary`); a second class whose few callers are adapted in the bead
     (`OOOctreeBuilder`) has no façade.
   - **Client of an Objective-C registry that holds `id`s unretained** (ADR-0056 amendment
     oo-4111; exemplar `src/Core/OOPolygonSprite.*`): the façade registers while it lives and
     forwards the callback; the deletion bead waits for the registry's conversion.
   - **Superclass still Objective-C** (ADR-0056 amendment oo-o89; exemplar
     `src/SDL/OOSDLJoystickManager.*`): the façade keeps the old superclass, makes and owns the
     C++ object in `-init`, and forwards the overrides too. The C++ class reaches superclass
     methods with `[oo::ToObjC(this) …]`, and `ToObjC` never makes a new façade. The deletion bead
     depends on the superclass's conversion. A category of an unconverted class converts with that
     class. SDL/GL calls stay verbatim, and an SDL class's test simulates its device.
   - **The superclass of such a façade** (ADR-0056 amendment oo-6bux; exemplar
     `src/Core/OOJoystickManager.*`): convert it as a root (Amendment 1); the subclass's façade is
     unchanged and gets an adapter as its C++ part. An `-init` that calls overridden members is
     `init()`, run after the C++ part exists. A factory by registered `Class` stays in the façade.
   - **A JS binding file (`OOJS*`)** (ADR-0056 amendment oo-ppc; exemplar
     `src/Core/Scripting/OOJSVector.*`): it has no class, and its JS class is already C++. Do not
     touch `OOJS_NATIVE_*`/`OOJS_PROFILE_*`: they are C++ already, and an exception under a native
     reaches JS through `OOJSReportCurrentException`. Change `BOOL`/`YES`/`NO` to `bool`/`true`/`false`.
     Turn a category on a game class into free functions in `X.mm` and leave its `@implementation`, with
     one-line forwarders, in `X+ObjCBridge.mm`. Its deletion bead depends on that class's conversion.
     Messages to unconverted classes and the JS private slot stay as they are. The test runs the JS
     class in a real context (`tests/unit/core/test_OOJSVector.mm`). Also gate on
     `bash tools/js-api-contract.sh`.
   - **A binding with a class of its own, and its base** (ADR-0056 amendment oo-kdyh; exemplar
     `src/Core/Scripting/OOScriptTimer.*`, `OOJSTimer.*`): convert a root with its only subclass in
     the root's bead. A class the engine messages by selector keeps a no-ivar façade subclass that
     forwards the glue selectors; the JS private slot holds that façade. A container of
     Objective-C objects holds the façade, and removal uses `oo::LiveObjC`.
   - **A category only its own file sends** (ADR-0056 amendment oo-cn4o; exemplar
     `src/Core/Scripting/OOJSEngineTimeManagement.*`): it becomes a file-local free function that
     takes what it read from `self` as arguments, with no forwarder. Result classes that only C++
     makes are plain `cxx::` classes with default façades. A C function that returned one +1 keeps
     its signature and returns `[oo::ToObjC(p) retain]`.
   - **A module of hierarchies** (ADR-0056 amendment oo-smy; exemplar `OOMaterial`, `OODrawable`):
     roots first, in one bead. Class methods become `static` members, and file statics become
     never-destroyed function statics. Converted code that *keeps* an object while the hierarchy
     has Objective-C subclasses holds `oo::ObjCRef<::X *>(oo::ToObjC(p))`, because an adapter does
     not retain its owner. A subclass's bitwise copy calls `oo::ConstructCxxPartOfCopy`.
   - **A helper that adopts an Objective-C protocol** (ADR-0056 amendment oo-rmd7; exemplar
     `OOCacheManager`'s `OOAsyncCacheWriter`): it moves into the bridge files until the protocol is
     C++. A converted caller in `namespace cxx` names the façade `::X`.
   - **Made with `alloc`/`-initWithX:`** (ADR-0056 amendment oo-86ek; exemplar
     `src/Core/OOVector.*`, `OONativeVector`): the initialiser becomes a constructor; the façade's
     `-initWithX:` makes the C++ object and records itself as its peer. A header included inside
     `extern "C"` declares the class, and imports the bridge, inside `extern "C++"`.
   - **Mac-only, never compiled here** (ADR-0056 amendment oo-bgmb; exemplar
     `src/Core/OOFullScreenController.*`): add the `.mm` to the build so the test can link it; leave
     the callers only the Mac compiles as they are (Phase 5 writes the Mac layer again).
   - **A root whose ivars subclasses and callers read directly** (ADR-0056 amendment oo-bj8;
     exemplar `src/Core/Entities/Entity.*`, `OOEntityWithDrawable.*`): the state moves to the C++
     class (public members, same names, all `= {}`); unconverted code reads it through the façade's
     `@public` `_cxxEntity` (`ent->_cxxEntity->position`, inserted where the compiler reports a
     removed ivar). The Objective-C object stays the identity and owns the C++ part; a C++
     subclass's façade comes from `oo::NewEntityFacade`. An entity leaf's bead derives from
     `cxx::Entity` and keeps its bodies verbatim.
   - **An entity class with Objective-C subclasses, and the entity leaves** (ADR-0056 amendments
     oo-0otc, oo-0mxi and oo-2c6g; exemplars `src/Core/Entities/OOLightParticleEntity.*`,
     `DustEntity.*`, `OOQuiriumCascadeEntity.*`): an intermediate class derives its own adapter from
     `oo::ObjCEntity<cxx::X>` for the members it adds, and its Objective-C subclasses read its ivars
     as `oo::ToCxx(self)->x`. A leaf that callers make or message keeps a façade with no ivars,
     whose `-init` or class method makes the C++ object; a leaf with none is made by its factory
     and `oo::NewEntityFacade`, and a category method it overrode asks it with `dynamic_cast`.
   - **The Debug module: a singleton whose superclass is Objective-C** (ADR-0056 amendment
     oo-kq7; exemplar `src/Core/Debug/OODebugMonitor.*`): the C++ class owns the singleton, and
     its façade, made once by `oo::ToObjC`, keeps the singleton boilerplate and so lives as long
     as the process. A protocol from another module that the class adopts is declared in the
     bridge `.mm`. The golden gate proves the debug console still works end to end.
   - **The Audio module: a root that is a class cluster** (ADR-0056 amendment oo-2en; exemplar
     `src/Core/OOALSound.*`, `cxx::OOSound`): the root converts first with an `OODrawable`-style
     façade and adapter. Its cluster initialiser is a static factory returning the Objective-C
     subclass instance as `oo::ObjCRef<::X *>`; the façade's initialiser releases the receiver and
     returns `factory(…).leakRef()`. `-init`'s side effect is the constructor. The test runs OpenAL
     on the null backend with a scratch `HOMEPATH`.
7. **Callers you convert later** hold `oo::Ref<cxx::X>` (not `X *` or `oo::ObjCRef<X *>`), call
   with `->`, and cross with `ToObjC`/`ToCxx` only where they call unconverted code.
8. **Test.** Write `tests/unit/core/test_X.mm` and add one entry in `tests/unit/core/meson.build`
   (the game objects it links). Pin the pre-conversion answers: write them against the
   Objective-C API first, and run them on the unconverted class.
9. **Hierarchies** ([ADR-0056 Amendment 1](../decisions/0056-phase3-class-conversion-house-style.md#amendment-1-2026-09-30-bead-oo-cwz-class-hierarchies);
   exemplar `src/Core/OXPVerifier/OOOXPVerifierStage.*` and `OOListUnusedFilesStage`).
   - Superclass first: a subclass's bead depends on the bead that converts its superclass.
   - Overridden methods become public `virtual` members; C++ overrides say `override`.
   - The root's façade is also the base of the remaining Objective-C subclasses. Its `-init`
     makes an adapter (`ObjCStage`) whose virtual members message the subclass;
     `ToObjC(adapter)` is the subclass instance. A façade method for a virtual member calls the
     base's member qualified (`_cxx->cxx::X::m()`) on an Objective-C subclass, and the virtual
     member on a C++ object.
   - A converted subclass with no outside caller is global and has no façade. Objective-C code
     reaches it as the root's façade (`oo::ToObjC(sub.get())`). A class created by name from data
     gets an explicit factory table.
   - An intermediate class with Objective-C subclasses keeps a façade whose `-init` gives the
     root's `-initWithCxxStage:` an `oo::ObjCStage<cxx::Mid>`. A converted class that is still
     messaged by its own selectors is `cxx::X` with a façade `X : Root`, which `oo::ToObjC` picks
     by name. Categories of Objective-C classes move to the bridge
     ([amendment oo-up4b](../decisions/0056-phase3-class-conversion-house-style.md#amendment-bead-oo-up4b-intermediate-classes-subclass-façades-and-categories-left-in-a-file)).
   - A leaf that one Objective-C class messages has no façade: the bead adapts that caller to
     the global C++ class. A leaf created by name gets a line in `OOOXPVerifier.mm`'s `constexpr`
     `kCxxStages` (amendment oo-94qk; exemplar `OOAIStateMachineVerifierStage`).
10. **Check.**
   - `! grep -nE '@implementation|@interface|@selector|@protocol' X.mm X.h`
   - `tools/build-windows.sh test`, with no new warning
   - `OOLITE_TIER_A_BUDGET=120 tools/tier-a.sh` on `X.mm` and `X+ObjCBridge.mm`
   - `bash tools/check-core-tests.sh`
   - `bash tools/tier-c.sh --only goldens` (`2 blessed verified`)
   - `bash tools/guardrails.sh`

## Commands

From Phase 0. Every story's acceptance includes `tools/tier-a.sh <file>`; the wrapper runs Tier B.

## Open decisions

- **3** — how much modern C++ in translated code. Decided: conservative C++20 first ([ADR-0001](../decisions/0001-bridge-then-convert.md)).
- **6** — decided: faithful port of legacy AI and plist scripting (ADR-0013).
- **7** — decided: MinGW-clang (ADR-0013).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 3) and AI_EXECUTION_PLAN §1, §6, §15.
- 2026-09-29 — Slice-plan format and checker landed (`tools/check-slice-plan.py`, bead oo-4plo); first plan `3-slices/OOPListSchemaVerifier.md`. Plain-C free functions go in a checked `verbatim:` group and are never read by a slice (ADR-0012).
- 2026-09-29 — `OOColor` converted as the house-style exemplar (bead oo-11m, proposed ADR-0056):
  C++ `cxx::OOColor` in `OOColor.h/.mm`, Objective-C façade `OOColor+ObjCBridge.h/.mm` with
  identity kept by `oo::ObjCPeers`, unit test `tests/unit/core/test_OOColor.mm`
  (`tools/check-core-tests.sh`). No caller changed. Goldens: 2 blessed verified.
- 2026-09-30 — Intermediate classes (bead oo-up4b, proposed ADR-0056 amendment oo-up4b).
  `OOFileScannerVerifierStage.h/.mm` is C++. `cxx::OOFileHandlingVerifierStage` is the
  intermediate class, and its seven Objective-C leaf stages reach it through
  `oo::ObjCStage<cxx::OOFileHandlingVerifierStage>`. `cxx::OOFileScannerVerifierStage` keeps a
  façade for the stages that message it. Both façades and `-fileScannerStage` are in
  `OOFileScannerVerifierStage+ObjCBridge.*`. Unit test: `tests/unit/core/test_OOFileScannerVerifierStage.mm`.
  The leaf beads can now convert independently.
- 2026-09-30 — Class hierarchies (bead oo-cwz, proposed ADR-0056 Amendment 1). The OXPVerifier
  stage base is `cxx::OOOXPVerifierStage`, with virtual subclass responsibilities. Its façade
  `OOOXPVerifierStage+ObjCBridge.*` is also the base of the Objective-C stages, through an
  adapter. `OOListUnusedFilesStage` is the first C++ stage (global, no façade). Unit test:
  `tests/unit/core/test_OOOXPVerifierStage.mm`. Stage beads now depend superclass-first: the
  leaves on oo-up4b, ship data and model on oo-tuq8.
- 2026-09-29 — `tools/gen-stories.py` sweep `slices` (bead oo-k7u5): one fleet story per slice of every checked plan, titled `Convert to C++20: <File>.mm, slice <id>`, depending on the module's pattern seam, the pre-split bead and (after the first) the plan's first slice. Acceptance is `tools/check-slice-plan.py --slice-done <id> <plan>` (nonzero while any of the slice's units is still Objective-C) + `tools/tier-a.sh` + guardrails. `--dry-run --phase 3 --sweep slices` lists them; a landed slice is not re-filed.
- 2026-09-30 — Phase 2's endgame is in phase-3 (sync bead oo-qvprm). Foundation is gone:
  gnustep-base is unlinked, `OOCocoa.h` no longer imports Foundation, `@"..."` is
  `OOConstantString`, and `OOComparisonResult` is Oolite's own enum. The bridge headers are
  deleted: `OOStringBridge.h`, `OOFoundationBridge.h`, `OOPListView.h`, `OOCollectionExtractors`
  and `OOObjectGNUstepBridge`. Use the oofnd/ADR-0055 forms instead: `oo::PList`, `OOObjCPList.h`,
  `OODescription.h`, `oofnd/String.hpp` and `std::string`. The transitional id forms are gone too
  (oo-qps.72): OOColor `colorWithDescription:(id)`, the cache's `objectForKey`/`setObject`,
  OOProbabilitySet `allObjects`/`objectEnumerator`, OOPriorityQueue `addObjects`, and
  OOWeakSet `addObjectsByEnumerating`. `unichar` is `uint16_t`. The deny-list now names
  Foundation classes and functions, including in comments and string literals: `NSString`,
  `NSLog`, `NSSelectorFromString` and so on (oo-qps.19). New conversion code must pass
  `bash tools/check-foundation-free.sh --stage source` with 0 findings. A selector that no
  header declares any more is sent through a local protocol cast; see `OOCharacterIntValue`
  and `OOWeakReferenceClassName`. Merge phase-3 into your bead branch before you queue.
- 2026-10-01 — Debug module pattern seam (bead oo-kq7, ADR-0056 amendment oo-kq7):
  `OODebugMonitor` is `cxx::OODebugMonitor` behind `OODebugMonitor+ObjCBridge.h/.mm`, a singleton
  whose immortal façade keeps the `OOWeakRefObject` superclass and the engine-monitor protocol.
  Test: `tests/unit/core/test_OODebugMonitor.mm`. No caller changed; the goldens (driven through
  the debug console) are green.
- 2026-09-30 — Audio module pattern seam (bead oo-2en, ADR-0056 amendment oo-2en): `OOSound`
  (`OOALSound.h/.mm`) is `cxx::OOSound` behind `OOALSound+ObjCBridge.h/.mm`, the root of the three
  Objective-C sounds; its class-cluster initialiser is the static factory
  `cxx::OOSound::initWithContentsOfFile`, which answers the Objective-C sound it makes. Test:
  `tests/unit/core/test_OOSound.mm`. No caller changed.
- 2026-10-01 — Slice plans gain a `mac-only:` group (bead oo-q9l2w, first plan
  `3-slices/GameController.md`): units wholly inside an `OOLITE_MAC_OS_X` arm, which the fleet never
  compiles and does not convert (ADR-0056 amendment oo-bgmb item 2; Phase 5 writes the Mac layer
  again). `tools/check-slice-plan.py` proves each is fenced, no slice reads it, and
  `tools/gen-stories.py` files no story for it. A pre-split gathers a class's whole Mac-only
  methods into one fenced category at the end of the *same* file (a new file would read as new
  deny-list hits: the guardrails' file-split limitation).
- 2026-10-05 — `ShipEntity` pre-split (bead oo-9ht.140, plan `3-slices/ShipEntity.md`): 34 slices
  of `ShipEntity.mm`, slice 1 the frontier class shell (`cxx::ShipEntity`, the façade, the adapter
  and the compiler-guided `_cxxShip->` rewrite of the unconverted code), slices 2-34 fleet stories in
  file order. Slice plans gain `header-decls: per-slice`: a slice is charged the header less every
  method declaration, plus its own units' declarations, because `ShipEntity.h` (1,334 lines) charged
  whole leaves no slice under the budget. oo-k8a is now the umbrella over the slices, the
  `ShipEntityAI` slices, oo-42dr and oo-kw44; the subclasses wait on the slices they override.
- 2026-10-05 — `PlayerEntity` and `Universe` pre-splits (beads oo-9ht.154 and oo-9ht.155, plans
  `3-slices/PlayerEntity.md`, 28 slices, and `3-slices/Universe.md`, 26 slices), each slice 1 a
  frontier class shell (`_cxxPlayer->` / `_cxxUniverse->` rewrite), the rest fleet stories in file
  order. Slice plans gain `header-names: by-use`: a slice is charged the header's other declarations
  (ivars, macros, enums, constants, inline functions) only where its units name them, because
  `PlayerEntity.h`'s 451-line ivar block and ~340 lines of GUI constants left a 613-line method no
  slice under the budget. oo-a70 and oo-pas are the umbrellas; the player's slices wait on the
  `ShipEntity` slices they override, its category slices on its slice 1, and the façade-deletion
  beads on the slices that name the façade.
- 2026-10-01 — The rest of the Audio module (beads oo-y0gz, oo-2wpb, oo-03g7, oo-nwbw, oo-5vp8,
  oo-6g4z, oo-zoj3, oo-d2y9, oo-lfkq; ADR-0056 amendment oo-y0gz): each class is `cxx::X` behind
  `X+ObjCBridge.h/.mm`; converted code keeps its sends to the module's other classes as `::X`
  (their tests stub them), the concrete sounds and the music have façades of their own under the
  root's, and the channel tells its delegate of itself from the façade's `-dealloc`. Tests:
  `tests/unit/core/test_<Class>.mm`, on the game's own `.ogg` resources. No caller changed.
- 2026-10-06 — `NSObjectOOExtensions` (bead oo-eoi6) has nothing to convert in Phase 3: it is a
  debug-only category on the root `OOObject` (`+oo_instanceSize`, `-oo_objectSize`), Objective-C
  runtime reflection, and every remaining sender messages a façade or an `id` for its instance size
  (`Entity+ObjCBridge.mm`, `OODebugMonitor.mm`, `OODrawable::totalSize`, `OOWeakReference`). It goes
  with the façades and the runtime in Phase 4 (bead oo-6e1.1), where each sender takes the C++
  object's own size.
- 2026-10-06 — `HeadUpDisplay` fully converted (umbrella bead oo-xjm): all six slices of
  `3-slices/HeadUpDisplay.md` landed (oo-engam, oo-8fiz9, oo-8j1y2, oo-2p1ug, oo-kdrc6, oo-0tx6c) and
  each reports `--slice-done`; the frame-hash proof is the goldens, run nightly from the slices'
  `tests/nightly/checks.txt` lines.
