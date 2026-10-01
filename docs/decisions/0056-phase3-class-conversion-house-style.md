# ADR-0056: How a class is converted in Phase 3: the C++ class, its Objective-C façade, and the checklist

- Status: Proposed. The default is in effect until Jon decides (CLAUDE.md rule 10).
- Date: 2026-09-29
- Bead: oo-11m (the `OOColor` house-style exemplar). Refines the per-file recipe of
  [Phase 3](../phases/3-cpp-conversion.md); builds on [ADR-0003](0003-intrusive-refcount.md),
  [ADR-0012](0012-c-stays-c.md), [ADR-0026](0026-oofnd-ref-semantics.md),
  [ADR-0029](0029-objc-floor-without-foundation.md), [ADR-0043](0043-foundation-sweep-recipe.md) and
  [ADR-0055](0055-foundation-endgame-boundaries.md).

## Context

The Phase 3 recipe maps each Objective-C construct to C++, but it does not say how a converted class
stays usable by the code that still messages it. Phase 3 converts leaves inward, so a leaf's callers
are, by construction, not converted yet. `OOColor` is typical: about 90 files name it (800 lines),
several of them giant files that other beads will convert slice by slice. Those callers:

- send it messages (`[OOColor redColor]`, `[c redComponent]`);
- keep `OOColor *` ivars with `retain`/`release`, or `oo::ObjCRef<OOColor *>` in containers;
- pass it through `id`: `PList::Object` nodes (`oo::PListObject(color)`), shader uniforms, and
  `isKindOfClass:[OOColor class]` checks.

None of that compiles against a C++ class. Fleet stories are sized at 8 files and 400 written lines,
and most leaves have more callers than that, so "convert the class and all its callers" cannot be the
rule. Two other questions were open: the seam table named `src/Core/OOColor.hpp/.cpp` while the phase
doc says files stay `.mm` until Phase 4, and nothing fixed naming, `const`, nil handling or where a
converted class's tests live.

Measured on this toolchain (clang 22, libobjc2, `-fobjc-runtime=gnustep-2.2`, probes in bead
oo-11m):

1. An Objective-C class `OOColor` and a C++ class `cxx::OOColor` coexist in one translation unit.
   Inside `namespace cxx` the unqualified name is the C++ class, and `[::OOColor class]` names the
   Objective-C one.
2. libobjc2's weak references (`objc_initWeak`, `objc_loadWeakRetained`) work on `OOObject`
   subclasses and read nil before `-dealloc` runs, so a table of weak peers never returns an object
   that is being deallocated.

## Decision (recommended defaults)

1. **Files keep their names: `X.h` and `X.mm`.** The C++ class is declared in `X.h` and defined in
   `X.mm`, which stays Objective-C++ (`.mm` becomes `.cpp` in Phase 4). The header's includers do not
   change. This supersedes the seam table's `OOColor.hpp/.cpp`.
2. **The class is `class X : public oo::RefCounted`** (or `: public Y` once `Y` is C++). Ivars become
   private data members with the same names, zero-initialised (`= {}`) as `class_createInstance`
   zeroed them. A private category becomes private member functions.
3. **Names and types are translated, not redesigned.**
   - The member name is the selector's first keyword: `colorWithRed:green:blue:alpha:` is
     `colorWithRed(r, g, b, a)`. Selectors that share a first keyword become overloads. Phase 2's
     `cxx_` prefix is dropped (ADR-0043 item 6), on free functions too when every caller is inside
     the bead (`cxx_OORGBAComponentsDescription` becomes `OORGBAComponentsDescription`).
   - A class method becomes `static`. A result that was `X *` (autoreleased) is `oo::Ref<X>` by
     value; a parameter that was `X *` is `X *` (borrowed). `BOOL` becomes `bool`.
     `[[X alloc] init]` becomes `oo::makeRef<X>()`, `[[self retain] autorelease]` becomes
     `oo::Ref<X>(this)`, `nil` becomes `nullptr`.
   - Types that Phase 2 already made C++ stay exactly as they are, including
     `std::optional<std::string>`; Phase 6 tidies them.
   - No `const` on member functions, except where a decision fixes the signature
     (`descriptionComponents() const`, ADR-0055 item 1). Const-correctness is Phase 6 work.
4. **Bodies stay verbatim except for the message syntax** (ADR-0012). `[self foo]` becomes `foo()`,
   and `[X foo]` inside `X` becomes `foo()`.
   - A message to an object that may be nil becomes a null-guarded call that does what nil did:
     nothing, 0, or `nullptr`.
   - An out-parameter that a nil message left unwritten is zero-initialised. It was indeterminate,
     and the analyser rejects the read.
   - `OOAssert`/`OOParameterAssert` become `OOCAssert`/`OOCParameterAssert`. There is no `self` or
     `_cmd` any more, so the failure text names the function.
   - A selector the class calls by name becomes an explicit table of its candidates, as the recipe's
     `NSSelectorFromString` row says. Exemplar: `kNamedColors`.
   - `-cxx_descriptionComponents` becomes `std::optional<std::string> descriptionComponents() const`.
5. **While anything outside the bead still messages the class, it keeps an Objective-C façade, and
   the C++ class is `cxx::X`.**
   - `X+ObjCBridge.h` holds the old `@interface`, copied exactly (same selectors, same types, same
     root). Its one ivar is `oo::Ref<cxx::X>`. `X+ObjCBridge.mm` forwards every method in one line.
   - Objective-C objects cross the boundary through two overloaded functions:
     `oo::ToObjC(cxx::X *)` gives an autoreleased façade, nil for null, and
     `oo::ToCxx(X *)` gives a borrowed pointer, null for nil.
   - `oo::ObjCPeers` (`oofnd/objc/OOObjCPeer.h`) keeps at most one live façade per C++ object and
     holds it weakly, so identity survives the crossing. That keeps `==`, `-isEqual:`, Object nodes,
     "returns itself" and "copy is retain" exact.
   - `X.h` imports the bridge header as its last line. `meson.build` lists `X+ObjCBridge.mm` after
     `X.mm`. Callers compile unchanged.
   - Converted code never messages the façade. It holds `oo::Ref<cxx::X>` and crosses with
     `ToObjC`/`ToCxx` when it calls unconverted code.
   - The C++ class is in `namespace cxx` because the Objective-C name is taken. The bridge's
     deletion bead moves the class to the global namespace and deletes `cxx::` at every use, one
     mechanical replacement. A class with no façade (every caller adapted in the bead) is global from
     the start.
6. **Every façade has a deletion bead,** filed when the façade is made. The bead's acceptance
   requires that the bridge files are gone and that no `cxx::X` is left. The Phase 3 exit gate
   (zero `@implementation`) cannot pass while any façade exists.
7. **A converted class has a unit test: `tests/unit/core/test_X.mm`.**
   - The test links the game's own objects for the class, its bridge and what they need: one entry
     in `tests/unit/core/meson.build`, extracted from the `oolite` target.
   - It runs with `bash tools/check-core-tests.sh`, which is `meson test --suite core` plus an
     inventory check.
   - It pins what the class computed before the conversion. Write the expectations against the
     Objective-C API, run them on the unconverted class, then port them.
   - It also covers the façade's contract: the same answers, nil stays nil, and identity.
8. **Gates for a conversion bead:**
   - `! grep -nE '@implementation|@interface|@selector|@protocol'` over `X.mm` and `X.h`;
   - `tools/build-windows.sh test` with no new warning;
   - `tools/tier-a.sh` on `X.mm` and on `X+ObjCBridge.mm` (`OOLITE_TIER_A_BUDGET=120`, as the
     Phase 2 recipe allows);
   - `bash tools/check-core-tests.sh`;
   - `bash tools/tier-c.sh --only goldens` (`2 blessed verified`);
   - `bash tools/guardrails.sh`.

## Consequences

- A leaf converts in one bead of about four files, whatever its fan-out. Its callers then convert in
  their own beads, in any order, and each one's façade crossings disappear as it converts. OOColor's
  bead touched 0 caller files.
- Each façade costs one forwarding method per selector, plus one weak-table lookup per crossing and
  per façade creation. It exists only until its deletion bead.
- `cxx::` appears in converted code for a while, and a later mechanical commit per class removes it.
  This is the Phase 2 `cxx_` idea again: scaffolding named so that it can be found and deleted.
- Identity is preserved at the crossing. Mutable classes are the ones where identity matters most:
  two façades for one object would break `==` and collection membership.
- After gnustep-base is unlinked (oo-qps.18), the core tests link libobjc2 alone with no change,
  because they use the game's own dependency list.

## Alternatives considered

- **Convert every caller in the same bead (a codemod).** 90 files for `OOColor`, including giant
  files other beads are slicing. It fails the sizing rule for most leaves, and the receiver's type
  cannot be known without semantic tooling.
- **The C++ class takes the name `OOColor` and the façade is renamed.** Every Objective-C caller
  would change at conversion time. That is the same fan-out as the codemod.
- **A new façade object per crossing, with no peer table.** Simpler, but a C++ object that crosses
  twice becomes two Objective-C objects. That breaks `==`, `-isEqual:`, `containsObject:` and
  "returns itself".
- **A back-pointer to the façade inside the C++ object.** It keeps Objective-C state inside the
  converted class, and every deletion bead would have to edit the class again. A side table keeps the
  class clean.
- **`X.hpp`/`X.cpp` now.** 90 includers change, and `.cpp` cannot hold the message sends that
  converted code still makes to unconverted classes. Phase 4 renames.
- **Tests under `tests/unit/oofnd`.** Game classes are not oofnd, and on phase-3 their headers still
  reach Foundation, which the oofnd objc tests forbid.

## Amendment 1 (2026-09-30, bead oo-cwz): class hierarchies

- Status: Proposed. The default is in effect until Jon decides (CLAUDE.md rule 10).
- Exemplar: `src/Core/OXPVerifier/OOOXPVerifierStage.h/.mm` (the base, `cxx::OOOXPVerifierStage`),
  `OOOXPVerifierStage+ObjCBridge.h/.mm` (its façade and the adapter), `OOListUnusedFilesStage` in
  `OOFileScannerVerifierStage.h/.mm` (a converted subclass), `tests/unit/core/test_OOOXPVerifierStage.mm`.

**Context.** The decision above covers a class whose callers message it. A base class is also
*subclassed*, in other files, by Objective-C classes that other beads convert. A C++ class cannot
derive from an Objective-C class, and an Objective-C class cannot derive from a C++ class. So a
hierarchy converts root first, and both kinds of subclass live under one root until the last
subclass converts. `OOOXPVerifierStage` has 12 Objective-C subclasses in 8 files, including 2
Objective-C intermediate classes (`OOFileHandlingVerifierStage`, `OOTextureHandlingStage`). It also
has an Objective-C driver (`OOOXPVerifier`) that holds and messages stages, and creates them from
class names.

**Decision (recommended defaults).**

1. **A class converts after its superclass.** Its bead depends on the bead that converts
   its superclass's file. In OXPVerifier the leaf stages depend on `oo-up4b`, which holds
   `OOFileHandlingVerifierStage`. `OOCheckShipDataPListVerifierStage` and `OOModelVerifierStage`
   also depend on `oo-tuq8`, which holds `OOTextureHandlingStage`. One class of a file with
   several classes may convert before the rest of the file, when that class is the smallest step
   that exercises the pattern. The rest of the file stays Objective-C until its own bead.
2. **Overriding becomes virtual dispatch.** The methods that subclasses override (the "subclass
   responsibilities") are public `virtual` members of the C++ base. `RefCounted`'s destructor is
   already virtual. A C++ subclass declares its overrides with `override` and does not repeat
   `virtual`. A method that no subclass overrides stays non-virtual. An internal category shared
   by two classes (`OOInternal`) becomes public members under an "Internal" comment. Its
   Objective-C header stays until the façade is deleted, as the façade's category.
3. **The root's façade is also the base of the Objective-C subclasses.** The one Objective-C class
   has two kinds of instance, and what `_cxxX` holds tells them apart:
   - **An Objective-C subclass instance** (`[[Sub alloc] init]`). The façade's `-init` makes its
     C++ part, an *adapter*: `ObjCStage final : public cxx::X`, private to the bridge `.mm`. The
     adapter's virtual members message the Objective-C object, so when C++ calls them the
     subclass's overrides run. The Objective-C object owns the adapter (`oo::Ref`). The adapter's
     back pointer is not retained, and `-dealloc` clears it; after that, a call answers what a
     message to nil answered. `oo::ToObjC(adapter)` returns the Objective-C object itself, and
     there is no peer-table entry.
   - **The façade of a C++ subclass** (`oo::ToObjC(cxxObject)`). Each C++ object has at most one
     live façade, through `oo::ObjCPeers`, as in item 5.
   - A façade method for a virtual member behaves differently for the two kinds. On an
     Objective-C subclass instance it calls the base's own member, qualified
     (`_cxxStage->cxx::X::run()`). That is what `[super run]`, or a subclass that did not
     override, reached before. Calling the virtual member here would loop back into the
     subclass. On a C++ object's façade it calls the virtual member.
4. **A converted subclass with no outside callers has no façade and is global** (the last rule of
   item 5). Unconverted code sees it as the root's façade. `[[Sub alloc] init]` followed by
   registration becomes `oo::makeRef<Sub>()` and `oo::ToObjC(sub.get())`. Inside a member of a
   class derived from `cxx::X`, the unqualified name `X` is the injected C++ base; write the
   Objective-C façade as `::X`.
5. **Class names.** `[obj class]` on a C++ object's façade returns the façade class. So the façade
   overrides `-cxx_description` to print the C++ class's name: the demangled `typeid` name, with
   `cxx::` dropped. Two debug-only texts in the Objective-C verifier still print
   `OOOXPVerifierStage` for a C++ stage until `oo-tsa4` converts the verifier:
   `DescriptionOf([stage class])` in the Graphviz dump, and the exception fallback.
6. **A class created by name from data** (the `verifyOXP.plist` `stages` list, read through
   `OOClassFromName`) needs an explicit table once it converts. The code that creates it looks in
   the table before calling `OOClassFromName`. An entry is `{ "OOCheckDemoShipsPListVerifierStage",
   [] { return oo::makeRef<OOCheckDemoShipsPListVerifierStage>(); } }`, following item 4's
   `kNamedColors` rule. The first bead that converts such a stage adds the table to
   `OOOXPVerifier.mm`, and each later bead adds its line.
7. **An intermediate class that converts while Objective-C classes still derive from it** gets
   its own façade: `@interface Mid : Root`, with the old interface. Its Objective-C subclasses
   need an adapter derived from `cxx::Mid`. So the adapter becomes a class template over its C++
   base, in the root's bridge. The root façade gets an initialiser that takes the C++ part, and
   the intermediate façade's `-init` calls it. The first bead that needs this (`oo-up4b`) makes
   it.
8. **The test** subclasses the root on both sides, with an Objective-C test subclass and a C++
   one. It pins the pre-conversion answers through the Objective-C API. Then it checks the
   crossing in both directions:
   - C++ virtual calls reach the Objective-C overrides;
   - the façade reaches the C++ overrides;
   - `[super ...]` reaches the base;
   - a dependency graph that mixes both kinds;
   - identity and nil;
   - the adapter outliving its owner.

   The root may need link-time dependencies that the test cannot link. Here that is
   `OOLogging.mm`, which reaches the resource manager. The test replaces such a function with its
   own definition, which counts calls.

**Consequences.** Each hierarchy root has one façade and one deletion bead. So does each
converted intermediate class that still has Objective-C subclasses. An Objective-C subclass costs
one adapter object, and each façade call costs one `dynamic_cast`. The Phase 3 bead graph gains
edges that order each superclass before its subclasses.

## Amendment (bead oo-up4b): intermediate classes, subclass façades, and categories left in a file

- Date: 2026-09-30. Status: Proposed, as above.
- Exemplar: `src/Core/OXPVerifier/OOFileScannerVerifierStage.h/.mm` (`cxx::OOFileScannerVerifierStage`,
  the intermediate `cxx::OOFileHandlingVerifierStage`), `OOFileScannerVerifierStage+ObjCBridge.h/.mm`
  (their façades), `oo::ObjCStage<Base>` in `OOOXPVerifierStage+ObjCBridge.h`,
  `tests/unit/core/test_OOFileScannerVerifierStage.mm`.

**Context.** Amendment 1 left two defaults to this bead: the adapter template with the root
façade's initialiser (its item 7), and the factory table for stages created by name (its item 6).
The file also holds a class that the unconverted stages message by its own selectors
(`OOFileScannerVerifierStage`, through the verifier's `-fileScannerStage`), and that category of
the Objective-C verifier.

**Decision (recommended defaults).**

1. **The adapter is `oo::ObjCStage<Base>`,** in the root's bridge header. It derives from `Base`,
   the C++ class of its Objective-C stage's nearest converted superclass, and from a non-template
   `oo::ObjCStageLink`, which holds the owner and pure virtual `super…()` members. `ObjCStage`
   implements each `superM()` as `Base::m()`. On an Objective-C stage, the root façade's method for
   a virtual member calls `superM()` through the link, not the root's qualified `cxx::Root::m()`.
   So a subclass that does not override a method, or calls `[super m]`, reaches the nearest C++
   superclass's own member at any depth. This refines Amendment 1 item 3.
   `oo::AsObjCStage(stage)` is the `dynamic_cast` to the link.
2. **An intermediate class's façade** is `@interface Mid : Root`, with the old interface. Here that
   interface is empty. It has no ivars, because the root's `_cxxStage` holds its C++ part. It
   implements `-init` as
   `[super initWithCxxStage:oo::makeRef<oo::ObjCStage<cxx::Mid>>(self).get()]`. The root façade's
   `-initWithCxxStage:` becomes public for this, in the category `OOObjCBridge` of the root bridge
   header. The Objective-C subclasses of `Mid` compile unchanged.
3. **A converted class that callers message by its own selectors** is `cxx::X`. Its façade is
   `@interface X : Root`, with the old interface, and it has no ivars. Each method forwards through
   `oo::ToCxx(self)`. Typed `oo::ToObjC`/`oo::ToCxx` overloads `static_cast` to and from the root's.
   The root's `oo::ToObjC` picks the façade class from the C++ class's name. For `cxx::X` it is the
   Objective-C class `X`, if that class is a subclass of the root, and otherwise the root. Item 5
   gives the two classes the same name, so a crossing gets the right façade however the pointer
   is typed. A global C++ class has no façade, and Objective-C sees it as the root. On such a
   façade, `[[X alloc] init]` makes a new C++ `X` and returns its façade, as a class cluster does.
4. **A category of a class that is still Objective-C** moves from `X.mm` to `X+ObjCBridge.mm` if it
   was in `X.mm`, and its declaration moves to `X+ObjCBridge.h`. The ObjC-syntax gate covers
   `X.h/.mm`. Here that is `-[OOOXPVerifier fileScannerStage]`. A constant it needs becomes a
   static member (`cxx::OOFileScannerVerifierStage::kName`). It is deleted with the bridge. If the
   verifier converts first (oo-tsa4), it moves into the verifier instead.
5. **The factory table** (Amendment 1 item 6) is not made here. No stage in this file is created by
   name, because `verifyOXP.plist` lists only leaf stages. The first leaf bead adds the table to
   `OOOXPVerifier.mm`, with the exact shape
   `{ "OOCheckDemoShipsPListVerifierStage", [] { return oo::Ref<cxx::OOOXPVerifierStage>(oo::makeRef<OOCheckDemoShipsPListVerifierStage>()); } }`.
   The verifier looks up the table before `OOClassFromName` and registers
   `oo::ToObjC(stage.get())`. The table is needed because a converted leaf is global and has no
   Objective-C class, so `OOClassFromName` finds nothing.
6. **Converting a leaf of `OOFileHandlingVerifierStage`** (oo-94qk, oo-kdnm, oo-uw42, oo-tuq8,
   oo-z2wr, oo-si5w, oo-li7k) needs no bridge change, so each bead converts on its own.
   - The leaf is a global class `: public cxx::OOFileHandlingVerifierStage` and declares its
     overrides with `override`.
   - It reaches the scanner as
     `cxx::OOFileScannerVerifierStage *fileScanner = oo::ToCxx([verifier() fileScannerStage]);`
     and calls its members (`fileExists`, `pathForFile`, `plistNamed`, …).
   - It adds its line to the factory table (item 5).
   - `OOTextureHandlingStage` (oo-tuq8) is itself an intermediate class with Objective-C
     subclasses. It follows item 2 with `oo::ObjCStage<cxx::OOTextureHandlingStage>`.
7. **The test replaces the Objective-C classes that it cannot link.** Here those are the verifier
   and the resource manager, which reach the whole game. The test defines each class itself. The
   verifier implements its full interface against the ivars in its header, so the scanner runs on
   a real directory that the test writes. The test pins the answers through the Objective-C API
   (44 checks, run on the unconverted classes first) and then checks the crossing:
   - an Objective-C subclass of the intermediate class behind a C++ pointer;
   - `[super dependents]`;
   - a C++ subclass of it behind the façade;
   - the scanner's own façade class, from either pointer type;
   - identity, nil, and the adapter outliving its owner.

**Consequences.** `OOFileScannerVerifierStage+ObjCBridge.*` is one more façade, with its own
deletion bead. The root bridge's adapter is a template in a header, so every file that includes
the stage headers sees it. Its method bodies are one message send each. Looking up the façade
class costs one demangle and one class lookup when a façade is created, and nothing on later
crossings while that façade lives.

## Amendment (bead oo-o89): platform (SDL/) code, and a subclass of an Objective-C class

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/SDL/OOSDLJoystickManager.h/.mm`,
  `OOSDLJoystickManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOSDLJoystickManager.mm`.

**Context.** Of the `SDL/` files, `MyOpenGLView.mm` is being pre-split, `MyOpenGLView+Input.mm`
and `GameController+SDLFullScreen.mm` are categories of classes defined elsewhere, and `main.mm`
has no `@implementation` (rule 9: not a class conversion). The representative leaf is
`OOSDLJoystickManager`. Its superclass, `Core/OOJoystickManager`, is still Objective-C: it creates
its subclass by `Class` (`+setStickHandlerClass:`, `+sharedStickHandler`), messages its overrides
(`joystickCount`, `nameOfJoystick:`, `getAxisWithStick:axis:`), and keeps its own state (button,
axis and hat tables), which the subclass fills by calling the superclass's decoders. A C++ class
cannot derive from an Objective-C one, so item 5's thin façade does not fit as is.

**Decision (recommended defaults).**

1. **Platform code converts like Core code.** SDL and GL calls are C and stay verbatim (ADR-0012).
   SDL types (`SDL_Event *`, `SDL_Joystick *`, `SDL_JoystickID`) and the typedefs over them
   (`JoyAxisEvent`) are kept, as are `NSInteger`/`NSUInteger` in signatures (item 3: translated,
   not redesigned). The test is `tests/unit/core/test_X.mm` like any other. It initialises only the
   SDL subsystem it needs, with no window, and simulates the device (`SDL_AttachVirtualJoystick`)
   with the hardware drivers hinted off, so the machine's own devices cannot change the answers.
2. **A class whose superclass is still Objective-C** becomes `cxx::X : public oo::RefCounted`,
   holding only its own ivars and methods. `X+ObjCBridge.h` keeps the old `@interface` with the
   old superclass, and differs from item 5 in four ways:
   - **The façade makes and owns the C++ object** in its `-init`. The C++ constructor is the old
     `-init` body up to `[super init]`, and the façade calls `[super init]` after it. `-init`
     then records itself as the peer: `Peers().peerFor(cxx, [self] { return [self retain]; })`
     inside an `@autoreleasepool`.
   - **Overrides of superclass methods** are forwarded like any other method. The superclass's
     dynamic dispatch reaches the façade, and the façade reaches the C++ class.
   - **A message to `self` (or `super`) that the superclass implements** becomes
     `[oo::ToObjC(this) selector]`, because the superclass's state lives in the façade.
   - **`oo::ToObjC` gives the live façade or nil. It never makes a new one**, because a new
     façade would have fresh superclass state. Until the superclass converts, the C++ object is
     made only by its façade, and converted code does not `makeRef` it.
3. **The façade's deletion bead depends on the superclass's conversion bead.** When the
   superclass is C++, `cxx::X` derives from it (item 2), the forwarded overrides become `override`,
   `[oo::ToObjC(this) …]` becomes a plain call, and the bridge files go.
4. **A category file on a class that is not converted** (`GameController+SDLFullScreen.mm`,
   `MyOpenGLView+Input.mm`) is not a separate conversion. Its methods become members of `cxx::X`
   in the bead that converts `X` (or a slice of it). The members stay defined in the category's
   file, so no body moves. Until then, its bead is blocked on `X`'s.

**Consequences.** The subclass converts before its superclass, and its callers
(`MyOpenGLView.mm` registers the class, `MyOpenGLView+Input.mm` sends it `handleSDLEvent:`) stay
unchanged. The bead touched no caller. The cost is a façade that carries state, and so cannot be
deleted before the superclass converts. Converting the superclass first needs none of this and
is the better order when both are in reach. This amendment is the default when the leaf is
reached first.

## Amendment (bead oo-x2wy): a protocol declared with the class, and subclasses private to its file

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOAsyncWorkManager.h/.mm`,
  `OOAsyncWorkManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOAsyncWorkManager.mm`. Its
  singleton follows amendment oo-r7m0, and its selector constant amendment oo-3lj8 item 2.

**Context.** `OOAsyncWorkManager.h` declares, besides the class, the `OOAsyncWorkTask` protocol
that Objective-C classes in other files adopt (`OOTextureLoader`, `OOTextureGenerator`,
`OOAsyncCacheWriter`), and the manager takes, queues and messages those task objects. The public
class is abstract: `OOAsyncWorkManager.mm` defines three subclasses that no other file names (an
internal base and two concrete managers, one of which `+sharedAsyncWorkManager` picks). The gate's
grep forbids `@protocol` in `X.h`, forward declarations included.

**Decision (recommended defaults).**

1. **A protocol that Objective-C classes adopt moves, unchanged, into `X+ObjCBridge.h`,** after
   the façade's `@interface`. The C++ class takes and stores the conforming objects as `id`
   (its declaration comes before the bridge's `@protocol`), and its bodies message them as before;
   a local may stay `id<P>`. The header comment on the C++ class names the protocol.
2. **The protocol becomes a C++ interface in the façade's deletion bead,** which therefore also
   depends on the conversion beads of the protocol's adopters, not only of the class's callers.
3. **Subclasses that no other file names convert with the class, in the same bead.** They become
   C++ classes in an anonymous namespace in `X.mm`, derived from `cxx::X`. The class definitions
   stand where the `@interface` blocks stood, and the member definitions where the
   `@implementation` bodies stood, so the bodies do not move. The methods they override are
   `virtual` in the base (amendment oo-cwz item 2). `[super m]` to a method the subclass does not
   override becomes a plain call. Only the root has a façade: no caller can tell the subclasses
   apart.
4. **An `-init` failure branch that `oo::makeRef` cannot take** (`if (_queue == nil) { [self
   release]; return nil; }` right after the ivar was made) is dropped, with a comment saying so.
   An `-init` that can fail for another reason follows amendment oo-r7m0 item 2.
5. **A logged `[self class]` of an object whose concrete class is private** becomes the class
   name as a literal, chosen where the object is made.

**Consequences.** The manager and its three subclasses converted in one bead (the class's two
files, the two bridge files and the test), and none of its five caller files changed. The protocol and the façade remain until the texture
loaders and the cache writer are C++.

## Amendment (bead oo-3kqi): a class whose façade is the object's identity (weak references)

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOWeakReference.h/.mm`,
  `OOWeakReference+ObjCBridge.h/.mm`, `tests/unit/core/test_OOWeakReference.mm`.

**Context.** `OOWeakReference` is a proxy: an Objective-C object that forwards every message to
the object it refers to, and answers like nil once that object has gone. Its identity is what its
callers use. The referred object keeps an unretained pointer to its one reference (`weakSelf`,
compared in `-weakRefDied:`), 37 files hold references in ivars and `ObjCRef` vectors and compare
them by pointer, and `-hash` is the reference's address. Item 5's façade has no state of its own,
so a C++ object may outlive its façade and later get a new one. Here that would be a second
reference to the same object. The referred object would not know about it, and its `weakSelf`
would dangle. The forwarding itself (`-forwardingTargetForSelector:`, `-class`,
`-respondsToSelector:`, the nil target) is Objective-C runtime behaviour. `oo::WeakRef`
(`oofnd/Ref.hpp`) already replaces all of this for objects that are C++.

**Decision (recommended defaults).**

1. **The façade is the reference, so it makes and owns its C++ object** (as amendment oo-o89 item
   2 does for another reason). Its `-init` makes the C++ object and records itself as the one
   peer. `oo::ToObjC` answers the live façade or nil and never makes one. Converted code that
   holds an Objective-C object weakly keeps the façade (`oo::ObjCRef<OOWeakReference *>`) and
   calls through `oo::ToCxx(ref)->…`. It never keeps the C++ object alone: the reference dies
   for the object when the façade does.
2. **The C++ class holds the state and every forwarding decision.** The methods the runtime
   calls on the façade (`-class`, `-respondsToSelector:`, `-forwardingTargetForSelector:`,
   `-hash`, `-isKindOfClass:` and the rest) forward in one line to members whose bodies are the
   old ones. A selector that is a C++ keyword takes a trailing underscore (`-class` is
   `class_()`). A message to `self` that must reach the façade (`-retain`, the address in `-hash`
   and in the description) is `[oo::ToObjC(this) …]`, as in amendment oo-o89.
3. **What needs the façade as `self` stays in the façade:** `-dealloc`'s `-weakRefDied:self` (the
   peer table already reads the façade as dead there), and `+weakRefWithObject:`'s nil check and
   allocation. The constructor takes the object.
4. **`@selector` comparisons become `OOSelectorsEqual(sel, OOSelectorFromName("name"))`.**
   libobjc2 selectors are typed (`oofnd/objc/OORuntime.h`), so `==` against an untyped selector
   would be wrong.
5. **Helpers that must stay Objective-C move into the bridge unchanged:** the protocol, a
   category on an Objective-C root, a base class whose subclasses are Objective-C
   (`OOWeakRefObject`: `Entity`, `Universe`, `AI`, `OOTexture` and others), and a private helper
   class (`OOWeakReferenceNilTarget`, now declared in the bridge header because both `.mm` files
   use it). So do the header's usage notes, which quote Objective-C code.
6. **The deletion bead deletes the class.** A converted class that is held weakly derives from
   `oo::RefCounted` and is held with `oo::WeakRef`, so no C++ code needs `cxx::OOWeakReference`
   once the last Objective-C holder and the last `OOWeakRefObject` subclass have converted.

**Consequences.** No caller changed, and the reference keeps its identity, its hash and its
lifetime. Every façade creation takes the peer table's mutex, and `-weakRetain` and `-hash` on a
reference take it again. The bridge lasts until the entity classes are C++, which is the end of
Phase 3.

## Amendment (bead oo-cc8a): `@protocol(...)` in a body, and holding another class's façade

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOWeakSet.h/.mm`,
  `OOWeakSet+ObjCBridge.h/.mm`, `tests/unit/core/test_OOWeakSet.mm`.

**Decision (recommended defaults).**

1. **`@protocol(P)` in a converted body becomes `objc_getProtocol("P")`,** as `@selector` becomes
   `OOSelectorFromName` (amendment oo-3lj8 item 2); the gate's grep forbids both spellings. The
   protocol is registered by the Objective-C classes that adopt it, which the body's callers are.
2. **A converted class that holds weak references to Objective-C objects** holds the
   `OOWeakReference` façades (`oo::ObjCRef<::OOWeakReference *>`) and reaches them with
   `oo::ToCxx(ref)->…` (amendment oo-3kqi item 1). Inside `namespace cxx` the unqualified name is
   the C++ class, so the façade is written `::X` (as amendment oo-cwz item 4 says for a base).
3. **`oo::ToCxx` is overloaded once per façade, so an `id` argument is ambiguous.** A façade method
   that took `id` (`-isEqual:`) converts it with `oo::ToCxx(static_cast<X *>(other))` after its
   `-isKindOfClass:` test.

## Amendment (bead oo-smy): a module's roots, global state, keeping objects, bitwise copies

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOMaterial.h/.mm`
  and `OOMaterial+ObjCBridge.h/.mm`, `src/Core/OODrawable.h/.mm` and `OODrawable+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOMaterial.mm`, `tests/unit/core/test_OODrawable.mm`.

**Context.** Materials is a module of hierarchies: `OOMaterial` → `OOBasicMaterial` →
`OOSingleTextureMaterial`/`OOMultiTextureMaterial`/`OOShaderMaterial`, and `OODrawable` →
`OOMesh`/`OOPlanetDrawable`/`OOSkyDrawable`, about 22 beads. Both roots are abstract and compute
little, so each converts as Amendment 1 says: public virtual members, and a façade that is also the
base of the Objective-C subclasses, with an adapter as their C++ part. Three things Amendment 1 did
not meet: `OOMaterial` keeps global state (the current material, retained, and class methods over
it); some code *keeps* materials and drawables rather than calling them, and an adapter does not
retain its Objective-C owner, so a C++ reference alone lets the owner be deallocated; and `OOMesh`
copies itself bitwise, which copies the façade's reference to its C++ part.

**Decision (recommended defaults).**

1. **A module converts root first, one bead for its roots,** then each class after its
   superclass (Amendment 1 item 1). The subclass beads depend on the roots' bead, and on the bead
   of their direct superclass when that is not the root (`OOSingleTextureMaterial`,
   `OOMultiTextureMaterial` and `OOShaderMaterial` on `OOBasicMaterial`'s). A root's own
   per-file conversion bead is superseded by the module bead.
2. **Every method a subclass overrides is virtual, `-cxx_descriptionComponents` included:**
   `virtual std::optional<std::string> descriptionComponents() const`. A root that had no
   components answers `std::nullopt`, as `OOObject` did. The adapter forwards it to
   `-cxx_descriptionComponents`, and a C++ object's façade prints the C++ class's name with the
   components (Amendment 1 item 5). A default body whose parameter is unused leaves the name in a
   comment, `setBindingTarget(id<OOWeakReferenceSupport> /*target*/)`: that is the fix
   `misc-unused-parameters` offers, not a suppression.
3. **Class methods and file statics.** A class method is a `static` member, and the façade's class
   method forwards to it. A file-static object reference becomes a function returning a
   never-destroyed static (`ActiveMaterial()`, as `Peers()` is), because the old static was
   never released at exit. A root's `-dealloc` body (`[self willDealloc]`) stays in the façade's
   `-dealloc` for an Objective-C subclass instance, whose `-dealloc` it is. It has no C++
   destructor: it guards against being deallocated while current, which cannot happen to a C++
   object that the current-material slot retains. The analyser also rejects its virtual call
   (`unapplyWithNext`) during destruction, which would not reach the subclass anyway.
4. **Converted code that keeps an object of a hierarchy with Objective-C subclasses keeps the
   Objective-C object:** `oo::ObjCRef<::X *>(oo::ToObjC(p))`, and calls through
   `oo::ToCxx(ref.get())`. That object owns the whole of either kind: an Objective-C subclass
   instance owns its adapter, and a façade owns its C++ object. An `oo::Ref<cxx::X>` to an adapter
   keeps only the adapter, which answers as nil once its owner is gone. A borrowed `cxx::X *` for
   the length of a call is fine. The keeping code changes to `oo::Ref<X>` in the façade's deletion
   bead. Exemplar: the current material, which `test_OOMaterial.mm` checks stays alive whichever
   side made it current. This is an exception to step 7 of the phase checklist while the
   hierarchy has Objective-C subclasses. For the same reason a class that keeps materials or
   drawables (`OOMesh`, `OOEntityWithDrawable`) is better converted after the subclasses it keeps;
   when it converts first, it follows this item.
5. **A subclass that copies itself bitwise** (`OOMesh`'s `-mutableCopyWithZone:`, the
   `NSCopyObject` replacement) calls `oo::ConstructCxxPartOfCopy(copy)`, declared in the root's
   bridge, where it constructs its own C++ ivars afresh. The copy gets its own adapter, and the
   copied reference is dropped, not released. That one line is the only edit to a subclass's file.
6. **A body that messages `self` with a method of an unconverted category** (`-oo_objectSize`
   from `NSObjectOOExtensions`) sends it to `oo::ToObjC(this)` (amendment oo-o89, item 2). For an
   Objective-C subclass instance that is the instance itself, so the answer is unchanged.
7. **The test** follows Amendment 1 item 8 for each root. It also checks the global state across
   the crossing (a C++ material told an Objective-C one comes next, and the other way round),
   that the kept object stays alive, and the bitwise copy. A root's test links what the root's
   file needs (`OOVector.mm` and `legacy_random.c` for `kZeroBoundingBox`).

**Consequences.** Each root has one façade and one deletion bead. The deletion bead depends on
every subclass bead and on the beads of the classes that message or keep the root's objects. Until
then `ActiveMaterial()` holds an Objective-C object, and item 4's `ObjCRef` appears in converted
code that keeps materials or drawables. `OOMesh.mm` gained one line.

## Amendment (bead oo-r7m0): singletons, and an `-init` that can fail

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/OOOpenALController.h/.mm`
  and `tests/unit/core/test_OOOpenALController.mm`.

**Context.** The GL/AL managers (`OOOpenALController`, `OOOpenGLExtensionManager`,
`OOGraphicsResetManager`) are singletons: `+sharedX` makes the one instance on first use and keeps
it for the life of the process, often with the "canonical singleton boilerplate" category
(`+allocWithZone:` answers nil after the first, `-retain`/`-release`/`-autorelease` do nothing).
`OOOpenALController`'s `-init` can also fail (`[self release]; return nil;`), and `+sharedController`
then asks again on the next call. Item 3 maps an autoreleased `X *` result to `oo::Ref<X>`; a
singleton's result was neither autoreleased nor owned by the caller.

**Decision (recommended defaults).**

1. **`+sharedX` becomes `static X *sharedX()`, a borrowed pointer.** The instance is held in a
   file-static `X *sSingleton`, made with `oo::makeRef<X>().leakRef()`: the one +1 is never
   released, as the retained `sSingleton` never was. The singleton category is not translated:
   with no other creator and no release there is nothing for it to do. `-dealloc`'s
   `if (sSingleton == self) sSingleton = nil;` stays, in the destructor.
2. **An `-init` that can fail becomes `bool init()`,** called by the factory right after
   `oo::makeRef<X>()`: `[self release]; return nil;` is `return false;` and the factory drops the
   `Ref`, which frees the object as the release did. The constructor stays trivial (the zeroed
   ivars). Nothing that the failing `-init` left open is closed, because the release did not close
   it either.
3. **A class whose few callers are adapted in the bead** has no façade (item 5). Adapting a caller
   is the null-guarded translation of its sends and nothing more: `[[X sharedX] foo]` becomes
   `if (X *x = X::sharedX()) x->foo();`, and a nil receiver's 0 is written out
   (`x != nullptr ? x->volume() : 0.0f`).
4. **A send that resolved only through the converted class's own declaration** (the receiver
   typed `id`, the selector declared on no other interface) gets its declaration added to the
   receiver's `@interface`. `OOOpenALController.h` had declared the `-shutdown` that
   `[[OOSoundMixer sharedMixer] shutdown]` resolved to; `OOALSoundMixer.h` now declares it.
5. **A singleton's façade** (when it has one) keeps one façade for the life of the process:
   `+sharedX` returns `oo::ToObjC(X::sharedX())` retained once and cached, so
   `[X sharedX] == [X sharedX]` still holds.

**Consequences.** Converted code calls `X::sharedX()->...` (or `cxx::X::` while a façade
exists) with no crossing. The failing-init factory keeps the "ask again next time" behaviour
exactly, including the log line each failed attempt writes.

## Amendment (bead oo-bwrq): a façade ivar that a category in another file owns, and a C++ helper that took the Objective-C class

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOShipGroup.h/.mm`,
  `OOShipGroup+ObjCBridge.h/.mm`, `tests/unit/core/test_OOShipGroup.mm`.

**Context.** `OOShipGroup`'s ivar `_jsSelf` is its JavaScript wrapper. The class itself never
uses it; the category `OOShipGroup (OOJavaScriptExtensions)` in `OOJSShipGroup.mm` makes it, stores
it, clears it, and gives the wrapper a retain of `self`. That is state of the Objective-C object,
not of the group, and the category writes it, so amendment oo-86ek item 4 (a getter in place of
the read) does not fit. `OOShipGroupCursor`, a C++ class in the same header, took an
`OOShipGroup *` and read the group's ivars from a function defined inside the `@implementation`.

**Decision (recommended defaults).**

1. **An ivar that only a category in another file uses, and that belongs to the Objective-C
   object** (a JavaScript wrapper that retains that object) **stays an ivar of the façade,**
   next to the `oo::Ref`. The category compiles unchanged, and the one-façade-per-object rule
   keeps one wrapper per C++ object while the wrapper keeps its façade alive. It moves when the
   category's file converts, and the façade's deletion bead depends on that file's bead.
2. **A C++ helper in the header that took the Objective-C class** takes the C++ class
   (`explicit OOShipGroupCursor(cxx::OOShipGroup *)`, holding `oo::Ref<cxx::X>`). A second,
   transitional constructor from the façade (`explicit OOShipGroupCursor(OOShipGroup *)`, with
   `@class OOShipGroup;` in the header) is defined in the bridge `.mm` as
   `: OOShipGroupCursor(oo::ToCxx(group)) {}`, so unconverted callers compile unchanged; it goes
   with the façade.
3. **Code that read the ivars from inside the `@implementation`** (the cursor's `next()`, the
   range-for's batch fill) becomes a `friend` of the C++ class. No accessor is added.

## Amendment (bead oo-z1s4): name clashes, GL tests, and stubbed collaborators

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/OOOpenGLExtensionManager.h/.mm`,
  `OOOpenGLExtensionManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOOpenGLExtensionManager.mm`,
  `tests/unit/core/oo_gl_test_context.hpp`. The singleton rules it follows are amendment oo-r7m0's
  (written in bead oo-r7m0; until that merges, this bead's files are their example too).

**Decision (recommended defaults).**

1. **An ivar that shares its name with a member function gets the suffix `_`.** Objective-C
   kept ivars and methods apart (`usePointSmoothing` was both); C++ does not. The same goes for a
   member of `oo::RefCounted` (`release`, `retain`, `retainCount`): an ivar `release` hides
   `RefCounted::release()` and `oo::Ref` stops compiling. Only the clashing ivars are renamed,
   and every use of them in the bodies with them; the suffix is oofnd's own (`mutex_`).
2. **A singleton made before `-init` ran** (the singleton category's `+allocWithZone:` recorded
   the instance, then `-init` did the work) is recorded first and initialised after:
   `sSingleton = oo::makeRef<X>().leakRef(); sSingleton->reset();`. A re-entrant `sharedX()` and
   an exception out of the initialisation leave the same `sSingleton` as before.
3. **A GL class's test runs on a real context.** `tests/unit/core/oo_gl_test_context.hpp` makes
   one hidden 16x16 SDL window with a compatibility context and keeps it current; the window is
   never shown, so the test does not take the foreground and needs no gui-lock. Answers that
   depend on the driver are checked against what the test reads from OpenGL itself
   (`glGetString`, `glGetIntegerv`), never against constants.
4. **A collaborator that would drag the game into the test's link is stubbed in the test file**
   (the cwz amendment's rule for functions, extended to classes): an Objective-C class the class
   under test messages is given a minimal `@interface`/`@implementation` of the same name in the
   test, declaring only the selectors used, and a C++ free function a definition. The test must
   not import the real header. The stub is the place to pin inputs (`gpu-settings.plist` comes
   from a `ResourceManager` stub) and to count calls (`+cxx_paths`, `-[OOSoundMixer shutdown]`).

## Amendment (bead oo-zffj): a class with one caller, a test that cannot link the game, private state

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOCrosshairs.h/.mm`, its caller
  `HeadUpDisplay.h/.mm`, `tests/unit/core/test_OOCrosshairs.mm`.

**Context.** `OOCrosshairs` has one caller, `HeadUpDisplay`, which keeps it in an ivar. Its only
output is what `render()` hands to OpenGL, and `render()` reaches `UNIVERSE`, the GL state and matrix
managers and the GL error checker, whose objects link the whole game. So the test cannot link what
the class references, and what the class computes is in private members.

**Decision (recommended defaults).**

1. **A class whose callers all fit in the bead has no façade** (item 5's last rule). The caller's
   ivar `X *` becomes `oo::Ref<X>`, with `class X;` in place of `@class X`. `[[X alloc] init…]`
   becomes `oo::makeRef<X>(…)`, `DESTROY(x)` and `[x release]; x = nil;` become `x = nullptr;`.
   An Objective-C argument crosses with `oo::ToCxx` (`oo::ToCxx(_crosshairColor)`). A `-init…`
   with arguments is the constructor, and `-dealloc`'s body is the destructor.
2. **Link stubs.** When the class's objects reference code whose objects would link the game, and
   the test never runs that code, the test defines those functions (and variables) itself, in one
   block headed as link stubs. Each stub function calls `std::abort()`, so a test that reached one
   fails instead of passing on a fake. The `meson.build` entry then lists only the class and what
   the tested paths need. (oo-cwz's amendment replaces a function with one that counts calls; that
   is for code the test does run.)
3. **Private state the test pins** is read through `friend struct XTestAccess;`, declared in the
   class and defined only in the test. Before the conversion the test reads the same ivars through
   the runtime (`ivar_getOffset(class_getInstanceVariable(...))`), so the expectations run on the
   unconverted class first. No accessor is added for this.

## Amendment (bead oo-vt0o): a façade that callers allocate, and free functions in the file

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/OOOpenGLMatrixManager.h/.mm`,
  `OOOpenGLMatrixManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOOpenGLMatrixManager.mm`.

**Decision (recommended defaults).**

1. **When unconverted code makes the object (`[[X alloc] init]`),** the façade's `-init` makes
   the C++ object (`oo::makeRef<cxx::X>()`) and records itself as its peer, as amendment oo-o89's
   façade does (`Peers().peerFor(cxx, [self] { return [self retain]; })` in an
   `@autoreleasepool`). `-initWithCxxX:` stays for `oo::ToObjC`. With no Objective-C superclass
   state, `oo::ToObjC` may make a new façade once the old one is gone (item 5).
2. **A second class in the file with no caller outside it** (`OOOpenGLMatrixStack`) converts in
   the same bead, global, with no façade. An `-init`/`-dealloc` that only called `super` becomes
   the implicit constructor and destructor; a `-dealloc` that released ivars now held as
   `oo::Ref` disappears.
3. **Free functions in the converted file that reach the object through unconverted code**
   (`[[UNIVERSE gameView] getOpenGLMatrixManager]`) take the C++ object with one `oo::ToCxx`
   and null-guard every call. A struct-returning message to nil answered a zeroed struct (clang
   zeroes it for this runtime; the test pins it), so the guard answers the zero value
   (`kZeroMatrix`).
4. **A test that needs unconverted game state reached through a global** (`UNIVERSE`) defines the
   global itself (`Universe *gSharedUniverse`) and points it at stub objects that answer only the
   selectors used (amendment oo-z1s4 item 4).

## Amendment (bead oo-jpd8): a protocol declared with the class

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/OOGraphicsResetManager.h/.mm`,
  `OOGraphicsResetManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOGraphicsResetManager.mm`.

**Context.** `OOGraphicsResetManager.h` also declared `@protocol OOGraphicsResetClient`, which
about fifteen Objective-C classes in other files adopt; the manager holds them as
`id<OOGraphicsResetClient>` and sends them `-resetGraphicsState`. The item 8 grep forbids
`@protocol` in the converted header, and no client is C++ yet.

**Decision (recommended defaults).**

1. **The protocol moves, verbatim, to `X+ObjCBridge.h`,** before the façade's `@interface`.
   `X.h` still imports the bridge last, so every adopter sees it unchanged.
2. **The C++ class takes and holds the clients as `id`** (the protocol is not visible above the
   class, and a forward `@protocol` would fail the grep). Its body sends the protocol's selector
   to them as before; the façade keeps `id<P>` in its signatures.
3. **When the first client converts,** its bead adds a C++ interface (an abstract class with the
   protocol's methods as pure virtuals) and a second registration path; the protocol goes with
   the façade's deletion bead once no Objective-C client is left. Until then nothing about the
   clients changes.

## Amendment (bead oo-8kx7): initialisers, `self` handed to Objective-C, and a fake `UNIVERSE`

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOCharacter.h/.mm`,
  `OOCharacter+ObjCBridge.h/.mm`, `tests/unit/core/test_OOCharacter.mm`.

**Context.** `OOCharacter` has public and private initialisers that chain (`-initWithRole:…` calls
`-initWithGenSeed:…`), a caller-visible `+alloc`/`-init`, an Objective-C ivar (`OOJSScript *`), a
`@selector` it asks an arbitrary object about, overrides of `OOObject` category methods
(`-cxx_descriptionComponents`, `-cxx_oo_jsClassName`), and it passes `self` to a script. Its bodies
ask `UNIVERSE`, the string expander and JavaScript.

**Decision (recommended defaults).**

1. **Initialisers are constructors.** A private `-init…` is a private constructor, and the class's
   own factories reach it with `oo::adopt(new X(…))`, because `oo::makeRef` cannot. An `-init…`
   that called another is a delegating constructor; statements it ran before the call move into a
   helper that computes the argument (`PseudoRandomSeed()`). Plain `-init` is `X() = default`.
2. **A public initialiser stays on the façade.** The façade's `-init…` makes the C++ object, stores
   it, and registers itself as the peer, `Peers().peerFor(cxx, [self] { return [self retain]; })`
   inside an `@autoreleasepool` (as amendment oo-o89 does). Plain `-init` gets the same override,
   so `[[X alloc] init]` still gives a working object.
3. **`self` handed to Objective-C** (a script property, a PList Object node) becomes
   `oo::ToObjC(this)`, so the Objective-C side sees the same façade the callers hold.
4. **An Objective-C ivar** is `oo::ObjCRef<T *>`; `[x autorelease]; x = [… retain];` becomes one
   assignment. **`@selector(sel)`** asked of an arbitrary `id` becomes
   `OOSelectorFromName("sel")` (`oofnd/objc/OORuntime.h`); the message to that `id` stays.
5. **Overrides of `OOObject` category methods** become C++ members named by item 3 of the decision
   (`oo_jsClassName()`), and the façade forwards its selector to them, as it does
   `descriptionComponents() const`. A `const` member reads the ivars its getters returned.
6. **The test keeps its Objective-C half.** The expectations written against the Objective-C API
   before the conversion stay as they are and now run through the façade, which is its forwarding
   test. The C++ API and the façade's contract are added after them.
7. **A fake `UNIVERSE`.** A class that messages `UNIVERSE` is tested against a class named
   `Universe` defined in the test, answering the selectors the class sends from a table, with
   `Universe *gSharedUniverse` defined beside it. The test must then not import `Universe.h`, or
   anything that does (`OOJavaScriptEngine.h`); it declares what it needs from them itself. Game
   functions the tested paths call (the string expander, `OO_DESC`) are replaced by definitions that
   return text recording their arguments; those it never calls are amendment oo-zffj's aborting
   link stubs.

## Amendment (bead oo-862e): a getter with its ivar's name, and a test friend of a `cxx::` class

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOTrumble.h/.mm`,
  `OOTrumble+ObjCBridge.h/.mm`, `tests/unit/core/test_OOTrumble.mm`.

**Context.** `OOTrumble`'s getters are named after their ivars (`-size` returns `size`), which
Objective-C allows and C++ does not: a data member and a member function cannot share a name. Its
bodies use the ivars on nearly every line.

**Decision (recommended defaults).**

1. **The ivar keeps its name and the getter becomes `get` + the name** (`-size` is `getSize()`,
   `-digram` is `getDigram()`), so the bodies stay verbatim (item 4). The façade keeps the old
   selectors and forwards `-size` to `getSize()`. Phase 6 may rename both.
2. **A test friend of a class in `namespace cxx`** is declared at global scope before the
   namespace (`struct XTestAccess;`) and befriended as `friend struct ::XTestAccess;`; an
   unqualified friend declaration would name `cxx::XTestAccess` (amendment oo-zffj item 3).
3. **Several public initialisers** share one private façade initialiser,
   `-initWithNewCxxX:(const oo::Ref<cxx::X> &)`, which stores the new C++ object and registers the
   façade as its peer (amendment oo-8kx7 item 2); each public one is one line.
4. **An Objective-C object the class retained by hand** (`texture = [... retain]` with a
   `[texture release]` in `-dealloc`) is an `oo::ObjCRef`. Where the Objective-C code overwrote the
   ivar without releasing the old object (a leak), the `oo::ObjCRef` assignment releases it; that
   is the only behaviour it changes.

## Amendment (bead oo-fg7i): a failable initialiser, a registry of objects, a category's ivar

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOEquipmentType.h/.mm`,
  `OOEquipmentType+ObjCBridge.h/.mm`, `tests/unit/core/test_OOEquipmentType.mm`.

**Context.** `OOEquipmentType` is made by a failable `-initWithInfo:` (it releases `self` and
returns nil for a bad entry), and it keeps class-level registries that own every type. Callers keep
types unretained (`ShipEntity`'s weapon types and missile list), relying on the registries to keep
them alive. A category in another file (`OOJSEquipmentInfo.mm`) reads and writes the ivar `_jsSelf`.

**Decision (recommended defaults).**

1. **A failable initialiser** becomes a private `bool initWithInfo(...)` whose body is the old
   one, ending `return OK;` where it released `self`. A private static `createWithInfo(...)` runs
   it on a new object (`oo::adopt(new X)`) and returns null when it fails. The constructor is
   private and defaulted.
2. **Registries become C++:** `std::vector<oo::Ref<X>>` and friends, in an anonymous namespace
   inside `namespace cxx`, and the class methods that read them become `static` members.
3. **The façade pins what the registries own.** A façade is otherwise held weakly, so a
   registered type's façade would die with the autorelease pool and the callers' unretained
   pointers would dangle. The bridge keeps `oo::ObjCRef`s to the façades of every registered
   object, and the façade's class methods that change a registry (`+loadEquipment`,
   `+cxx_addEquipmentWithInfo:`) re-pin after forwarding, dropping the old pins as the old
   registry dropped its objects. Converted code that changes a registry directly leaves the new
   objects unpinned until the next re-pin; the façade's deletion bead removes the pins.
4. **An ivar a category in another file uses** (a JavaScript wrapper, `_jsSelf`) is the
   Objective-C object's state, not the class's: it stays in the façade's ivar block, with the
   method that exists to keep it from being reported unused.
5. **Header imports.** `X.h` imports only what the C++ declaration needs; what the bodies need
   (`Universe.h`, `OOScript.h`) moves to `X.mm`. That also lets the test define its own fake
   `Universe` (amendment oo-8kx7 item 7).

## Amendment (bead oo-3lj8): a container of Objective-C objects, with no façade

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOPriorityQueue.h/.mm`
  (and its one caller, `src/Core/Scripting/OOScriptTimer.mm`), `tests/unit/core/test_OOPriorityQueue.mm`.

**Context.** `OOPriorityQueue` has one caller (`OOScriptTimer`, six sends), so item 5's last rule
applies: adapt the caller in the bead, no façade, and the class is global. But its elements are
Objective-C objects that it retains, releases and orders by a comparator *selector* the caller
supplies, and its bodies spell selectors with `@selector`, which the gate's grep forbids.

**Decision (recommended defaults).**

1. **The elements stay Objective-C.** The C++ class keeps `id` elements and the `SEL`
   comparator, and messages the elements (`retain`, `autorelease`, `isEqual:`, `hash`) exactly as
   before. It changes when its callers' elements convert, not before.
2. **A constant selector inside the class becomes `OOSelectorFromName("name:")`**
   (`oofnd/objc/OORuntime.h`, `sel_registerName`), so the body stays verbatim. The caller keeps its
   own `@selector(...)` while it is Objective-C.
3. **An unconverted caller of a class with no façade** holds a raw `X *` or an `oo::Ref<X>` and
   calls with `->`. A message that could reach nil becomes a null-guarded call (item 4). A static
   that was `[[X alloc] init…]` and never released stays a raw pointer, filled with
   `X::factory(…).leakRef()`, so no static destructor runs at exit.
4. **`-cxx_description` (the whole text, not components) becomes
   `std::optional<std::string> description()`.** `DescriptionOf([self class])` of a class with no
   subclass is the class name as a literal.
5. **With no façade, the test is ported, not kept.** Its expectations are written against the
   Objective-C API and run on the unconverted class (a commit of its own), then the same
   expectations are rewritten as C++ calls. Checks that only the Objective-C API could express
   (`[[X alloc] initWith…:NULL]`, `-isEqual:` with an object of another class) go with that API,
   and the commit message says so.

## Amendment (bead oo-rdfh): an ivar named like its getter, and `-init` with no factory

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOCache.h/.mm` (callers
  `Materials/OOTexture.mm` and `OOEncodingConverter.h/.mm`, adapted in the bead; no façade).

**Decision (recommended defaults).**

1. **An ivar that shares its name with a method** (`pruneThreshold`, `autoPrune`, `dirty` next to
   `-pruneThreshold`, `-autoPrune`, `-dirty`) cannot keep it: a C++ class cannot have a data
   member and a member function of one name. The data member takes a leading underscore
   (`_pruneThreshold`), and the rest of item 2 holds. Other ivars keep their names.
2. **`[[X alloc] init]` whose `-init` only forwards to another initialiser**
   (`-init` = `[self cxx_initWithPList:oo::PList()]`) becomes that initialiser's factory with the
   same argument (`OOCache::cacheWithPList(oo::PList())`), not a second factory.
3. **A setter's local that shadows a method** (`BOOL prune` in `-setAutoPrune:`, which then sent
   `[self prune]`) stays; the call becomes `this->prune()`.
4. **An Objective-C forward declaration of the class** (`@class X;` in another header) becomes
   `class X;`, and a caller's `X *` ivar stays a raw pointer holding the same +1:
   `X::factory(…).leakRef()` to fill it, `oo::release(p)` where it sent `-release`,
   `oo::autorelease(p)` where it sent `-autorelease`. `DESTROY(p)` becomes the same three steps
   it expanded to (copy, clear, `oo::release`), because a release can reach code that reads `p`.

## Amendment (bead oo-bhb9): initialisers, alloc/init from Objective-C, and -isEqual:/-hash

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OORoleSet.h/.mm`,
  `OORoleSet+ObjCBridge.h/.mm`, `tests/unit/core/test_OORoleSet.mm`.

**Context.** `OOColor` has only factories. Many leaves also have public `-initWith…:` methods that
unconverted callers send after `+alloc` (`[[OORoleSet alloc] initWithRoleString:…]` in
`ShipEntity`), and those initialisers can fail: they release `self` and return nil (no roles, a
negative probability). A C++ constructor cannot return null. Such classes also override
`-isEqual:` and `-hash`, which Foundation-free containers and `==` checks in callers rely on.

**Decision (recommended defaults).**

1. **An initialiser becomes a private member `bool initWithX(...)`** whose body is the old one
   verbatim, with `return self` → `return true`, `return nil` → `return false`, `[self release]`
   dropped, and `[super init]` dropped (the object is already constructed). `[self initWithY:…]`
   inside it is a plain call.
2. **`[[X alloc] initWithX:…]` becomes a static factory** that `makeRef`s the object, calls the
   initialiser, and returns null when it returned false. Where the class already had the
   factory (`+roleSetWithString:` is alloc + `-initWithRoleString:`), that is the one; a private
   initialiser with no factory (`[[[self class] alloc] initWithRolesAndProbabilities:]`) gets a
   private one named `xWithY` after it.
3. **The façade keeps the public initialisers.** Each calls the factory and then a private
   `-initWithNewCxxX:` that adopts the result: it releases `self` and returns nil for null (as
   before), else stores the ivar and records itself as the peer
   (`Peers().peerFor(cxx, [self] { return [self retain]; })` inside an `@autoreleasepool`, as the
   oo-o89 amendment does). This is separate from `ToObjC`'s `-initWithCxxX:`, which runs under the
   peer table's lock and only stores the ivar.
4. **`-isEqual:` and `-hash` become `bool isEqual(X *other)` and `NSUInteger hash()`** with the
   same bodies. The `isKindOfClass:` test moves to the façade's `-isEqual:`, which converts the
   argument with `oo::ToCxx`; the C++ member treats null as "not equal".
5. **`-cxx_descriptionComponents` that reads a lazily built cache** keeps its fixed `const`
   signature (ADR-0055 item 1) and reaches the non-const getter through `const_cast`. The object
   is never const-constructed, and the cache only ever holds the same text; Phase 6 may make the
   cache `mutable`.
6. **A log line that printed `self` with `%@`** prints `oo::DescriptionOf(oo::ToObjC(this))`
   while the façade exists (the address is the façade's, not the C++ object's).

**Consequences.** Callers that alloc/init keep compiling unchanged and keep identity (the façade
they made is the one `ToObjC` returns). A failed init still hands back nil.

## Amendment (bead oo-44gg): a class whose object needs the game graph, and initialisers a constructor cannot mirror

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/CollisionRegion.h/.mm`,
  `CollisionRegion+ObjCBridge.h/.mm`, `tests/unit/core/test_CollisionRegion.mm`.

**Context.** `CollisionRegion` reads `Entity` and `Universe` ivars directly (`ent->position`,
`UNIVERSE->sortedEntities`), so its object cannot link without theirs, and theirs pull in the whole
game. Its designated `-init` could fail (`malloc`) and return nil; it has two initialisers with no
arguments (`-init`, `-initAsUniverse`); and three file-static C functions read its private ivars.

**Decision (recommended defaults).**

1. **Its unit test links every game object but `SDL/main.mm`**: the entry in
   `tests/unit/core/meson.build` is `'test_X': ['*']`. The test defines the globals `main.mm`
   defined that the game references (today `gDebugFlags`, under `#ifndef NDEBUG`). The test drives
   the class with plain objects of the classes it reads (`[[Entity alloc] init]`, `UNIVERSE` nil)
   and pins what they make observable. The cost is one more whole-game link per build (about 30 s).
2. **An argumentless initialiser other than `-init` becomes a constructor taking an empty tag
   struct named after the selector** (`-initAsUniverse` becomes `CollisionRegion(AsUniverse)`),
   because two argumentless constructors cannot coexist. `[self init]` inside an initialiser
   becomes a delegating constructor (`: CollisionRegion()`), and the designated `-init`, when no
   caller outside the class used it, becomes a private constructor.
3. **An initialiser's failure return (nil after `[self release]`) becomes a raise of the class's
   existing exception for that failure** (`OOMallocException`, as `-addEntity:` raises when the
   list cannot grow), because a constructor cannot return null. Only out-of-memory paths are
   affected.
4. **A file-static function that reads the class's private ivars becomes a private static
   member**, body verbatim, so no `friend` and no public accessor is added.
5. **The façade's initialisers make and own the C++ object** as in amendment oo-86ek, through one
   private `-adoptCxxX:` that stores the new object and records the façade as its peer.

## Amendment (bead oo-489v): a class cluster converted whole

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOProbabilitySet.h/.mm`
  (callers `OOShipRegistry.h/.mm` and `Universe.mm`, adapted in the bead; no façade).

**Context.** `OOProbabilitySet` is a class cluster: two abstract public classes (immutable and
mutable) whose `+alloc`/`-init…` hand back one of four private concrete classes, an immortal
empty-set singleton (retain/release overridden), and "subclass responsibility" methods that raise.
Every class lives in the one file, so the hierarchy converts in one bead (unlike the oo-cwz
amendment, where subclasses live in other files).

**Decision (recommended defaults).**

1. **The public abstract classes stay public; the concrete ones become `final` classes in an
   anonymous namespace in `X.mm`.** A method that raised "abstract class" becomes pure virtual
   (`= 0`); the raising helper goes, since nothing can instantiate the abstract class any more.
2. **The cluster's `[[X alloc] initWith…]` becomes static factories on each public class**, with
   the dispatching body of the abstract `-initWith…` (count 0 → the singleton, 1 → the one-object
   class, else the general one). A subclass's factory of the same name hides the base's, as
   `+probabilitySet` on the mutable class did via `self`. A concrete `-initWith…` is a `bool`
   member (the oo-bhb9 amendment) or `void` where it cannot fail.
3. **An immortal singleton** (overridden `-retain`/`-release`/`+allocWithZone:`) becomes a static
   raw pointer made with `new` and never released: its count never reaches zero, so the
   boilerplate category goes. The factory returns `oo::Ref<X>(singleton)`.
4. **`-copyWithZone:`/`-mutableCopyWithZone:`** become `virtual oo::Ref<X> copy()` and
   `virtual oo::Ref<MutableX> mutableCopy()`; the zone test (always the same zone) goes.
5. **Behaviour is kept, bugs included**: the mutable set's `weightForObject()` still subtracts the
   previous entry's weight, and its `mutableCopy()` still asserts the sum is known. The test pins
   both. `__PRETTY_FUNCTION__` in a log line now prints the C++ name.

## Amendment (bead oo-novu): initialisers that fail on their input, and a second class with one caller

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/Octree.h/.mm` (`Octree`,
  `OOOctreeBuilder`), `Octree+ObjCBridge.h/.mm`, `tests/unit/core/test_Octree.mm`.

**Context.** `Octree`'s initialisers answer nil for bad input, not only for lack of memory:
`-cxx_initWithDictionary:` for a cache entry with no or ragged data, `-initWithData:radius:` for
empty data. A constructor cannot answer null, and amendment oo-44gg's raise would turn a bad cache
entry into an exception. `Octree.h` also declares `OOOctreeBuilder`, whose only user is
`OOMeshToOctreeConverter.mm` (a few message sends in one method and one C function).

**Decision (recommended defaults).**

1. **An initialiser that can answer nil for its input becomes a static factory with the
   initialiser's name** (first keyword, `cxx_` dropped: `-cxx_initWithDictionary:` becomes
   `static oo::Ref<Octree> initWithDictionary(const oo::PList &)`), returning null where it
   answered nil. The part of the body that cannot fail becomes a private constructor, and the
   factory makes the object with `oo::adopt(new X(...))`, then applies the old failure test.
   Amendment oo-44gg item 3 (raise) stays the rule for out-of-memory-only failures.
2. **The façade keeps the initialiser.** It calls the factory, answers nil after
   `[self release]` when it gives null, and otherwise owns the object and records itself as its
   peer (amendment oo-86ek). An `-init` that raised stays in the façade and still raises.
3. **A second class in the file whose callers all fit in the bead has no façade and is global**
   (item 5's "no outside caller" case): its callers are adapted in the bead
   (`OOMeshToOctreeConverter.mm`: `oo::makeRef<OOOctreeBuilder>()`, `builder->writeSolid()`, and
   `oo::ToObjC(...)` where it hands the result to Objective-C). A C function that took the
   class's pointer keeps the same parameter, now a C++ pointer.
4. **A member function whose name matches a file-static C function** (`isHitByLine`,
   `isHitByOctree`) calls the C function as `::name(...)`, since member lookup finds the member
   first. File-static functions stay outside `namespace cxx`.
5. **`[self oo_objectSize]`** (a memory statistic) becomes `sizeof *this`.

## Amendment (bead oo-ppc): the scripting bindings (`OOJS*` files)

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSVector.h/.mm`,
  `OOJSVector+ObjCBridge.mm`, `OOJSEngineNativeWrappers.h/.mm`,
  `tests/unit/core/test_OOJSVector.mm`.

**Context.** About 42 beads convert the `OOJS*` binding files. A binding file has no class of its
own: its JS class (the `ooscript::ClassDef`, the `PropertySpec`/`FunctionSpec` tables, the
get/set/finalize hooks, the natives and the prototype from `initClass`) has been C++ on the
`ooscript` façade since Phase 1 (bead oo-sdz). What is left of Objective-C is:

- `OOJS_NATIVE_ENTER`/`EXIT` (295 natives in 35 files), `OOJS_PROFILE_ENTER`/`EXIT` and
  `OOJS_BEGIN`/`END_FULL_NATIVE`, which expand to `@try`/`@catch (id)`/`@finally`;
- a category on the game class the file wraps (`ShipEntity (OOJavaScriptExtensions)`, with
  `-oo_jsValueInContext:` and `-oo_clearJSSelf:`, which the engine sends by selector) or a
  debug-only one (`PlayerEntity (JSVectorStatistics)`, reached by `PS.callObjC("…")`);
- messages to game classes that are still Objective-C (`[entity position]`, `[UNIVERSE …]`);
- `BOOL`/`YES`/`NO`, and a JS private slot that holds a retained Objective-C object (usually an
  `OOWeakReference`).

Measured on this toolchain (clang 22, libobjc2, `-fobjc-runtime=gnustep-2.2`, probe in bead oo-ppc):
a C++ `catch (...)`, even in a TU that is plain C++, catches an Objective-C `@throw`; inside it an
Objective-C++ `try { throw; } catch (id e)` gets the object back, and `catch (id)` does not match
a C++ exception. An Objective-C `@catch (id)` does not catch a C++ exception: the process ends in
`std::terminate` (ADR-0029 measurement 10).

**Decision (recommended defaults).**

1. **The exception mapping is made once, in `OOJSEngineNativeWrappers.h`, for every binding.**
   `OOJS_NATIVE_ENTER`/`EXIT` are a C++ `try` and a `catch (...)` that calls
   `OOJSReportCurrentException(cx)` and returns `false`. `OOJS_PROFILE_*` and
   `OOJS_BEGIN`/`END_FULL_NATIVE` are scope guards (`OOJSProfileScope`, `OOJSFullNativeScope`)
   that do what `@finally` did, in the same order. `OOJSReportCurrentException` lives in
   `OOJSEngineNativeWrappers.mm`, the one Objective-C++ file that tells the two kinds apart:
   - an Objective-C exception is reported exactly as before: `Native exception: <reason>` for an
     `OOException`, `Unidentified native exception` for anything else;
   - a C++ exception, which used to terminate the game, is now reported too:
     `Native exception: <what()>` for a `std::exception`, `Unidentified native exception`
     otherwise;
   - a pending JS exception is left to propagate, as before.
   So a binding bead does not touch its natives for exceptions. When Phase 3 turns a raise site
   into a C++ `throw` (ADR-0029 item 4), it throws a type derived from `std::exception` whose
   `what()` is the old reason, and JS reads the same text.
2. **A binding file converts in place.** `X.h`/`X.mm` keep their names. The JS tables, hooks and
   natives stay as they are. `BOOL`/`YES`/`NO` become `bool`/`true`/`false` in the file's code and
   in its C API in `X.h` (callers compile unchanged). Bodies stay verbatim otherwise (item 4), and
   the Objective-C header imports go only where nothing uses them. The analyser follows paths it
   did not follow inside an Objective-C `@try`, so `tier-a` can report a defect that was always
   there. Fix it in the smallest way, with a comment, as item 4 does for unwritten out-parameters.
   The exemplar's case: `VectorConstruct` leaked its private data when `newObject` failed.
3. **A category on a game class that lives in the binding file** is that class's code
   (amendment oo-o89, item 4), but it moves out of the binding file:
   - each method's body becomes a free C++ function in `X.mm`, named after the selector's first
     keyword (`reportJSVectorStatistics()`), declared in `X.h`. A method that used `self` takes the
     object as its first parameter;
   - the `@implementation` stays, with one-line forwarders, in `X+ObjCBridge.mm`, listed after
     `X.mm` in `meson.build`. It has no header of its own: the category's `@interface`, if any,
     stays where it is;
   - its deletion bead ("Delete X+ObjCBridge", `sweep:objc-bridge`) depends on the conversion bead
     of the class the category extends. That bead turns the forwarders into members of the C++
     class, which call the same functions.
4. **Messages to game classes that are still Objective-C stay messages.** A class that has
   converted is reached as `cxx::C` through `oo::ToCxx`/`oo::ToObjC` (item 5). The binding stays
   `.mm` until Phase 4.
5. **The JS private slot does not change while the wrapped class has an Objective-C face.**
   It keeps holding what it holds now: a retained Objective-C object, usually an `OOWeakReference`
   to it. A converted binding reads it with `OOJSNativeObjectFromJSObject` (or `getPrivate`) and
   crosses with `oo::ToCxx`. It wraps a `cxx::C` with `oo::ToObjC(c)`, so the peer table
   (`oo::ObjCPeers`) keeps one façade, and so one JS object, per game object. When `C`'s façade is
   deleted, the slot holds a heap `oo::WeakRef<cxx::C>` (what an `OOWeakReference` wrapper
   becomes) or a `cxx::C *` with one retain, released by the class's own finalize hook instead of
   `OOJSObjectWrapperFinalize`. `getInstancePrivate` with the class check replaces
   `-isKindOfClass:`. That change is in the engine's generic wrapper code, so it lands with the
   first façade deletion of a wrapped class, not in a binding bead.
6. **The test runs the JS class in a real context.** `tests/unit/core/test_X.mm` links `X.mm`,
   its bridge, `OOJSEngineNativeWrappers.mm`, the façade backend (`ooscript/JSEngine_quickjs.cpp`)
   and the maths it calls. What the rest of the engine provides (the error reporters, argument and
   string helpers, other bindings' converters, the universe) is defined in the test as the smallest
   stand-in that does the same thing (amendment oo-z1s4, item 4). The test evaluates JS and pins
   the JS-visible results, including the error text and what a native's exception becomes. Write
   it against the Objective-C file and run it there first, as item 7 says. One difference from
   amendment oo-8kx7, item 7: a binding's test needs `OOJavaScriptEngine.h` (the `OOJS_*` macros
   and the declarations it defines), which imports `Universe.h`, so its universe is a stand-in
   class with another name (`FakeUniverse`), assigned to `gSharedUniverse` and answering only the
   selectors the binding sends.
7. **Gates for a binding bead:** item 8's gates, with the grep over `X.mm` and `X.h`, `tier-a` on
   `X.mm` and on `X+ObjCBridge.mm` if there is one, and `bash tools/js-api-contract.sh`.

**Consequences.** A binding bead is `BOOL`s, a category moved behind forwarders, and a test; it
never edits its natives for exceptions. Every binding with a category on an entity gets a bridge
whose deletion waits for that entity's conversion. A binding with no category
(`OOJSFont`, `OOJSWorldScripts`, `OOJSSpecialFunctions`) needs no bridge, but it cannot become
`.cpp` until its includes are free of Objective-C: `OOJavaScriptEngine.h` declares
`@interface`s and imports `Universe.h`/`PlayerEntity.h`, and `OOCocoa.h` is Objective-C. That
header split belongs to the `OOJavaScriptEngine.mm` slices, not to the bindings. The one change in
behaviour: a C++ exception thrown under a native becomes a JS error instead of ending the game.
No golden reaches that path.

## Amendment (bead oo-4111): an Objective-C registry that holds its clients unretained

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOPolygonSprite.h/.mm`,
  `OOPolygonSprite+ObjCBridge.h/.mm`, `tests/unit/core/test_OOPolygonSprite.mm`.

**Context.** `OOPolygonSprite` registered itself with `OOGraphicsResetManager` (an
`std::unordered_set<id>` of unretained `<OOGraphicsResetClient>` objects) in its initialiser and
unregistered in `-dealloc`, so the manager could tell it to drop its VBOs. The manager is still
Objective-C and takes only an `id`. The HUD adds a category to the class (`OOHUDBeaconIcon`), and the
header declared that category's protocol conformance.

**Decision (recommended defaults).**

1. **The façade is the registry's client.** Every façade (made by the initialiser or by
   `oo::ToObjC`) registers itself when it is made, unregisters in `-dealloc`, and forwards the
   protocol method (`-resetGraphicsState`) to the C++ member of the same name. The C++ class keeps
   the method public and does not register.
2. **Converted code that makes the object keeps its façade alive while the object needs the
   registry** (`oo::ObjCRef<X *>(oo::ToObjC(x))`), until the registry is C++. The façade's deletion
   bead depends on the registry's conversion bead, which gives C++ clients a way to register.
3. **A category's protocol-conformance declaration in the header moves to the bridge header**,
   with the import it needs (`HeadUpDisplay.h`), since it names the Objective-C class.
4. A failable initialiser follows amendment oo-novu (`OOPolygonSprite::initWithDataArray` returns
   null where the initialiser answered nil).

## Amendment (bead oo-86ek): initialisers with arguments, a class in a C-linkage header, and a category that reads an ivar

- Date: 2026-09-29. Status: Proposed, as above. Exemplar: `src/Core/OOVector.h/.mm` (`OONativeVector`),
  `OOVector+ObjCBridge.h/.mm`, `tests/unit/core/test_OOVector.mm`.

**Context.** `OONativeVector` boxes a `Vector` for Objective-C collections. Its callers make it with
`[[OONativeVector alloc] initWithVector:v]`, which item 5's façade (made only by `oo::ToObjC`) does not
cover. It is declared in `OOVector.h`, which `OOMaths.h` includes inside `extern "C"`. A category in
another file (`OONativeVector (OOJavaScriptConversion)` in `OOJavaScriptEngine.mm`) read its ivar `v`.

**Decision (recommended defaults).**

1. **`-initWithX:` becomes a constructor with the same parameters** (`explicit` for one), its body the
   old one after `[super init]`. Converted code writes `oo::makeRef<X>(args)`.
2. **The façade keeps the initialiser, and its `-initWithX:` makes and owns the C++ object** with
   `oo::makeRef`, then records itself as the peer, as the oo-o89 amendment's `-init` does:
   `Peers().peerFor(cxx, [self] { return [self retain]; })` inside an `@autoreleasepool`. Unlike that
   amendment, `oo::ToObjC` still makes a new façade (a private `-initWithCxxX:`) for a C++ object
   that has none, because the class has no Objective-C superclass state.
3. **A class declared in a header that is included inside `extern "C"`** is declared inside the
   header's existing `extern "C++" { }` block, and the bridge import at the end of the header is
   wrapped the same way (`#if __OBJC__` / `extern "C++" { #import "X+ObjCBridge.h" }`), so
   `oo::ToObjC`/`oo::ToCxx` keep C++ linkage and overload with the other classes'.
4. **A category of the converted class in another file** stays a category of the façade. If it read
   an ivar, the read becomes the matching getter (`v` becomes `[self getVector]`): one line in the
   caller, and the category converts with its own file.

## Amendment (bead oo-bgmb): a Mac-only class the fleet never compiled

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOFullScreenController.h/.mm`,
  `tests/unit/core/test_OOFullScreenController.mm`.

**Context.** `OOFullScreenController` is the abstract base of the Mac full-screen controllers. Its
subclasses are Mac-only and are not in this tree; its only callers (`GameController`, under
`OO_USE_FULLSCREEN_CONTROLLER`, which is `OOLITE_MAC_OS_X`) are never compiled here, and its `.mm`
was not in the build at all. Only its header was compiled, for the display-mode key constants.
ADR-0009 moves the macOS port after the runtime is gone, so the Mac platform layer is written again
in C++ in Phase 5; nothing Objective-C has to keep working on the Mac.

**Decision (recommended defaults).**

1. **A platform-neutral class whose `.mm` the fleet did not compile joins the build** (one line in
   its `meson.build`), so that its test can link the game's own object and the conversion is
   checked like any other. Its first commit adds it with the test on the Objective-C class.
2. **Callers that only the Mac compiles are not adapted.** They are Mac code that the fleet never
   compiles (ADR-0043 item 18(b)); Phase 5 writes that layer again. Only what this build compiles
   changes: a forward `@class X` in a compiled header becomes `class X;` (amendment oo-rdfh item 4).
   The class has no façade (no compiled caller) and is global.
3. **"Subclass responsibility" methods** (a body that logs `OOLogGenericSubclassResponsibility()`
   and answers a default) become `virtual` with the same body, so the default still logs; they are
   not pure virtual, because the base can still be made and asked. The test overrides them with a
   C++ subclass where it had an Objective-C one.

## Amendment (bead oo-rmd7): a helper that adopts an Objective-C protocol, and a converted caller inside `namespace cxx`

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOCacheManager.h/.mm`,
  `OOCacheManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOCacheManager.mm`.

**Context.** `OOCacheManager` (a singleton, amendments oo-r7m0 and oo-z1s4) writes its file through
a helper class private to its file, `OOAsyncCacheWriter`, an Objective-C object that adopts
`OOAsyncWorkTask` so that `OOAsyncWorkManager` (Objective-C, or a façade over C++ after oo-x2wy)
can queue and message it. The helper cannot become C++ while the protocol is Objective-C
(amendment oo-x2wy item 2), and the gate's grep forbids its `@interface`/`@implementation` in `X.mm`.
The helper calls a private method of the class (`-writeDict:`). Separately, `OOEquipmentType.mm`,
converted earlier into `namespace cxx`, sent `[OOCacheManager sharedCache]`; once `cxx::OOCacheManager`
exists that name finds the C++ class.

**Decision (recommended defaults).**

1. **A helper that must stay Objective-C because it adopts an Objective-C protocol moves, body
   unchanged, into `X+ObjCBridge.mm`.** Its `@interface` goes in `X+ObjCBridge.h` without the
   protocol, so that `X.mm` can make it; the conformance is a class extension in the bridge `.mm`
   (`@interface Helper () <P> @end`), so the bridge header does not import the protocol's header.
   `X.mm` still makes it and hands it to the Objective-C API as before. It becomes C++ in the bead
   that turns the protocol into a C++ interface (oo-9ht.14 here), and moves back into `X.mm` then.
2. **A private method that such a helper calls** becomes a public member with a comment naming the
   caller. The helper calls the C++ class directly (`cxx::X::sharedX()->m()`), not the façade.
3. **A caller already converted into `namespace cxx` that messages the class being converted**
   names the façade `::X` (`[[::OOCacheManager sharedCache] …]`), as `OOColor.mm` names
   `[::OOColor class]`. Its message is kept, not turned into a C++ call, so a test that stubs the
   Objective-C class for that caller (`test_OOEquipmentType.mm`) keeps its link and its
   expectations. It becomes a C++ call in the façade's deletion bead.
4. **A test of a class that reads and writes files under the user's directories** points them at a
   scratch folder before the first use (`HOMEPATH` and the current directory, which
   `oo::ResourcePaths` reads at call time), and removes it at the end.

## Amendment (bead oo-ct7c): a pseudo-singleton that lives until the autorelease pool drains

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OORegExpMatcher.h/.mm`,
  `OORegExpMatcher+ObjCBridge.h/.mm`, `tests/unit/core/test_OORegExpMatcher.mm`.

**Context.** `+regExpMatcher` kept an unretained `sActiveInstance` and made it
`[[[self alloc] init] autorelease]` when it was nil; `-dealloc` cleared it. So every call inside
one autorelease pool got the same matcher (and its compiled JavaScript tester), and the pool's
drain freed it. That is neither amendment oo-r7m0's process-lifetime singleton nor a plain
autoreleased factory: C++ has no pool, so a `Ref` returned by value dies at the end of the
caller's expression.

**Decision (recommended defaults).**

1. **The static stays a borrowed pointer** (`static X *sActiveInstance`), set by the factory and
   cleared by the destructor, as before. The factory returns `oo::Ref<X>`: the live one while
   anything holds it, else a new one (`makeRef`, then the failing `-init` as `bool init()`,
   oo-r7m0 item 2).
2. **The façade keeps the pool lifetime.** `+x` is `oo::ToObjC(X::x())`: the autoreleased façade
   retains the C++ object until the pool drains, and `oo::ObjCPeers` hands the same façade to
   every call meanwhile. Unconverted callers see exactly the old behaviour.
3. **Converted callers hold the `Ref` for as long as they want one instance** (for example across
   a loop). The façade's deletion bead must say so, and its test counts instances made, because
   that is where the lifetime would silently shrink to one expression.

## Amendment (bead oo-fn2f): a whole hierarchy in one file, copies, and a private helper class

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOJoystickProfile.h/.mm`,
  `OOJoystickProfile+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJoystickProfile.mm`.

**Context.** `OOJoystickAxisProfile` and both its subclasses are in one file, with no Objective-C
subclass anywhere else, so the adapter of amendment 1 (oo-cwz) is not needed. The unconverted
callers (the joystick manager, the stick-profile screen) `alloc`/`init` the subclasses, test them
with `isKindOfClass:`, and `copy` them. The file also has a private class
(`OOJoystickSplineSegment`) that nothing outside it names, and two initialisers of that class
whose selectors differ only after the first keyword but take the same argument types.

**Decision (recommended defaults).**

1. **The hierarchy converts in one bead,** root first in the file. Overridden methods are virtual
   (amendment 1 item 2). Each Objective-C class keeps a façade with its old superclass: the root's
   holds the `oo::Ref`, a subclass façade has no ivars and forwards through `oo::ToCxx(self)`
   (amendment oo-up4b item 3). `oo::ToObjC` picks the façade class from the C++ object's dynamic
   type; for a closed set in one file that is a `dynamic_cast` chain, most derived first.
2. **`-init` on each façade class makes that class's C++ object** through one shared private
   root initialiser that stores it and records the façade as its peer (amendment oo-bhb9 item 3).
   A subclass façade's `-init` does not call the root's `-init`.
3. **`-copyWithZone:` becomes `virtual oo::Ref<Root> copy()`;** an override returns the root's
   `Ref` (a `Ref` result cannot be covariant). The façade's `-copyWithZone:` returns
   `[oo::ToObjC(cxx->copy()) retain]`, a +1 façade of the copy's own class. The bodies stay
   verbatim, including what they did not copy.
4. **A class private to the `.mm` with no outside user** is a global C++ class defined in the
   `.mm`; the header forward-declares it (`class X;`) at global scope for the members that hold it.
5. **Two selectors with the same first keyword and the same argument types** cannot be overloads.
   The first keeps the plain name; the other appends its distinguishing keyword in camel case
   (`+segmentWithData:right:gradientright:` is `segmentWithDataGradientRight(...)`).

**Consequences.** One façade pair of files and one deletion bead per hierarchy. The façade's
deletion bead depends on every caller's conversion bead.

## Amendment (bead oo-94qk): a leaf stage that one Objective-C stage messages, and the stage table

- Date: 2026-09-30. Status: Proposed, as above. Exemplar:
  `src/Core/OXPVerifier/OOAIStateMachineVerifierStage.h/.mm`, `kCxxStages` in `OOOXPVerifier.mm`,
  `tests/unit/core/test_OOAIStateMachineVerifierStage.mm`.

**Context.** `OOAIStateMachineVerifierStage` is a leaf of `OOFileHandlingVerifierStage` (amendment
oo-up4b item 6), but one Objective-C stage, `OOCheckShipDataPListVerifierStage`, messages it by its
own selectors: `+nameForReverseDependencyForVerifier:` and `-stateMachineNamed:usedByShip:`, on a
stage it looks up by name and keeps unretained. Amendment oo-up4b item 3 would give it a façade
for that one caller.

**Decision (recommended defaults).**

1. **A leaf with one Objective-C caller has no façade; the bead adapts the caller** (as amendment
   oo-novu adapts `OOOctreeBuilder`'s few callers). The leaf is global. The caller calls its
   `static` members directly, and holds the stage as a borrowed C++ pointer where it held the
   Objective-C one: `static_cast<Leaf *>(oo::ToCxx(static_cast<OOOXPVerifierStage *>([verifier
   cxx_stageWithName:…])))`, since the verifier registered that name for that class only. A
   message to it that could go to nil becomes a null-guarded call. The caller's own bead
   (oo-1v2w) then holds it the same way.
2. **The stage table is `constexpr`** (`constexpr CxxStage kCxxStages[]`, `{ name, make }`, with
   `make` a captureless lambda), so clang-tidy's `bugprone-throwing-static-initialization` holds.
   The verifier's `-registerBaseStages` looks it up before `OOClassFromName` and registers
   `oo::ToObjC(entry.make().get())`. Each later leaf bead adds one line and includes its header.
3. **The test captures the log** (`oo::log::logger().setInitialized(true)` and `setSink`), because
   a verifier stage reports only there, and pins the lines the unconverted stage wrote,
   indentation included.

## Amendment (bead oo-bj8): a hierarchy root whose ivars its subclasses and callers read directly (the entities)

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Entities/Entity.h/.mm`,
  `Entity+ObjCBridge.h/.mm` (the root, its facade and the adapter), `OOEntityWithDrawable.h/.mm`
  and `OOEntityWithDrawable+ObjCBridge.h/.mm` (a converted intermediate class),
  `tests/unit/core/test_Entity.mm`, `tests/unit/core/test_OOEntityWithDrawable.mm`. This is the
  Entities module's pattern seam: the entity leaves (about 56 beads) copy it.

**Context.** `Entity` is the root of about twenty Objective-C classes (`ShipEntity`, 15,000
lines; `PlayerEntity`, `StationEntity`, the planets, the effects), and `OOEntityWithDrawable` sits
between it and `ShipEntity`, `SkyEntity` and `OOVisualEffectEntity`. The roots of amendments oo-cwz
and oo-smy had no ivars that anyone else read. `Entity` has 50, and the code reads them directly:
the subclasses by name in their methods (`position`, `orientation`, `energy`, `isShip`), and other
classes through the pointer (`ent->position` in `Universe`, `CollisionRegion`, the HUD and the
scripting bindings). The Objective-C object is also each entity's identity: the universe's arrays
and its three position-sorted linked lists, the weak references, and the JavaScript wrappers all
hold it, and its superclass, `OOWeakRefObject`, keeps state (its weak reference).

**Decision (recommended defaults).**

1. **The state moves to the C++ class.** Ivars that were `@public` or `@protected` are public
   data members with the same names, because an Objective-C subclass cannot be granted protected
   access to a C++ class; `@private` ones stay private. Every member is zero-initialised, bit
   fields too (`isShip: 1 = 0`), and so is a type that is a pointer behind a typedef
   (`ooscript::Object _jsSelf = {}`): the runtime zeroed the ivar, a C++ member without an
   initialiser is garbage, and here that crashed `-dealloc`. A getter named like its ivar is
   `get` + the name (amendment oo-862e item 1): `-position` is `getPosition()`, `-isShip` is
   `getIsShip()`, so the bodies and the subclasses keep the names.
2. **Unconverted code reads the members through the facade's one `@public` ivar, by the same
   name:** `ent->_cxxEntity->position`, and `_cxxEntity->position` in an Objective-C subclass's
   method or in a category of `Entity`. The edit is mechanical and compiler-guided: with the ivars
   gone, insert `_cxxEntity->` at every "use of undeclared identifier" or "does not have a member
   named" error that names one of them (a macro that read one, `SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR`,
   gets it in its body). Then prove that no bare use bound silently to another declaration: build
   once with poison ivars of the old names on the facade and see no error. In this bead that was
   1,270 sites in 30 files, and nothing else in those files changed. When a file converts,
   deleting `_cxxEntity->` gives its bodies back verbatim.
3. **The Objective-C object is the entity's identity, and it owns the C++ part in both cases**
   (amendments oo-o89 and oo-3kqi). `oo::ToObjC(cxx::Entity *)` answers it borrowed, not
   autoreleased, because it lives while its C++ part does, and never makes one. A C++ entity's
   facade is made once, where the entity is made: `oo::NewEntityFacade(ref)`, whose class is the
   facade of the nearest converted class (a `dynamic_cast` chain, most derived first, amendment
   oo-fn2f item 1). Converted code that keeps an entity keeps that object (amendment oo-smy
   item 4).
4. **Pointers to other entities stay the Objective-C object** (`::Entity *x_next`, `collider`,
   `collision_chain`), including the ones the class's own bodies follow. The unconverted code that
   walks the lists (the universe's collision filter, `ShipEntity`'s scans, `CollisionRegion`)
   then changes only by item 2. The class's bodies read another entity as
   `x_next->_cxxEntity->position`, and a body that used `self` often names the object once,
   `::Entity *self = oo::ToObjC(this);`, so `x_next->x_previous = self` is verbatim. The members
   become C++ pointers in the facade's deletion bead.
5. **The adapter is amendment oo-up4b's template,** `oo::ObjCEntity<Base>` with its non-template
   half `oo::ObjCEntityLink`. Its members are `objcOwner()`/`_objcOwner`, because `owner()` and
   `_owner` are the entity's own. Every method that an entity subclass overrides is virtual (45,
   found by listing the methods of every `@implementation` of a class under `Entity`, categories
   included). `OOEntityWithDrawable` is a converted intermediate class with Objective-C
   subclasses: its facade is `@interface OOEntityWithDrawable : Entity` with no ivars, and its
   `-init` makes `oo::ObjCEntity<cxx::OOEntityWithDrawable>`.
6. **Initialisers.** The `-init` body is `void init()`, which the constructor calls. Its
   `[self setStatus:…]` is the base's own, qualified (`Entity::setStatus`), because the analyser
   rejects a virtual call during construction; `ShipEntity`'s override does the same for that
   status. The facade's designated `-initWithCxxEntity:` stores the part and counts the
   entity (`gLiveEntityCount`, and the Objective-C instance's size). **An entity that is sent
   `-init` again keeps its C++ part, and `init()` runs again on it**: `PlayerEntity`'s
   `-deferredInit` does this through `[super cxx_initWithKey:…]`, and a new part lost the
   player's script object and crashed the game at start-up (the goldens caught it; the test pins
   it). Both facades' `-init` check `_cxxEntity` first.
7. **`-dealloc` stays in the facade**, because it tells the universe, the script and the owner
   about the Objective-C object. `DESTROY(x)` becomes `[self setX:nil]`. It releases the C++ part
   before `[super dealloc]`, so what the part owns (the drawable, the collision region, the fog
   colour) is released at the end of the root's `-dealloc`, not in the subclass's: only the order
   of those releases changed.
8. **Objective-C literals in a body become C++ strings** (`@"self"` in the dump). The dump now
   prints the owner line and the ones after it; the Objective-C body could raise on a tiny
   string's `-description` there, and `-dumpState`'s `@catch` ended the dump silently. The
   `@try`/`@catch (id)` itself stays verbatim (as in `OOAsyncWorkManager.mm`): a C++
   `catch (...) {}` is an empty catch to the analyser.
9. **A converted class in `namespace cxx` that named `Entity`** names `::Entity`
   (`CollisionRegion`), since the unqualified name is now the C++ class.
10. **Categories of `Entity` in other files** (`EntityOOJavaScriptExtensions`, `ShaderBindings`,
    `SubEntityRelationship`, the effects' factories) stay categories of the facade, and the
    protocols the headers declared (`OOBeaconEntity`, `OOSubEntity`) move to the bridge headers
    unchanged.
11. **The test** links the whole game but `main` (amendment oo-44gg). `UNIVERSE` is a `Universe`
    that was never initialised (`class_createInstance`, ivars set by offset where a case needs
    them), `PLAYER` is an entity subclass that answers `-viewpointPosition`, and the log is
    captured with `oo::log::logger().setSink`. The ivars a test reads directly go through one
    block of helpers, the only lines the conversion ported.
12. **A leaf entity's bead** (the effects, the planets, `ShipEntity`'s categories) makes the
    class `X : public cxx::Entity` (or `cxx::OOEntityWithDrawable`), global, with `override`.
    Its bodies are verbatim: a bare ivar name is the inherited member, and a read of another
    entity stays `e->_cxxEntity->x`. What made it (`[[X alloc] init…]`) calls a factory and then
    `oo::NewEntityFacade`; if unconverted code still messages the class by its own selectors, it
    keeps a facade `@interface X : Entity` with no ivars (amendment oo-up4b item 3), and
    `NewEntityFacade`'s chain gains its line. A category of `Entity` in its file moves to
    `X+ObjCBridge.mm` (amendment oo-ppc item 3).

**Consequences.** `Entity` and `OOEntityWithDrawable` converted with two facades and two deletion
beads, and 30 caller files changed only by item 2. Reading an entity's member from unconverted code
costs one more load. A virtual call from C++ to an Objective-C entity costs a message, and a
facade method for a virtual member one `dynamic_cast`. The deletion beads remove every
`_cxxEntity->` (one mechanical replacement) and depend on every entity class and every file that
has one.

## Amendment (bead oo-41vj): an Objective-C class that exists only to be introspected

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOShaderUniformMethodType.mm`,
  `tests/unit/core/test_OOShaderUniformMethodType.mm`.

**Context.** `OOShaderUniformMethodType.mm` is C functions (item 9 of CLAUDE.md: they stay C) plus a
private Objective-C class, `OOShaderUniformTypeMethodSignatureTemplateClass`, with one method per
return type and no state and no caller. It exists so that the runtime reports each method's
return-type encoding, which `OOShaderUniformTypeFromMethod()` compares with the encoding of a bound
method. There is nothing to convert into a C++ class, and the gate's grep forbids its
`@interface`/`@implementation` and the `@selector`s that looked its methods up.

**Decision (recommended defaults).**

1. **The class goes, and the table is filled with `@encode(T)` of each type,** which is the encoding
   the compiler records for a method returning `T`, so the table holds the same strings. The macro
   and the table stay; only its argument changes from a selector to a type. `@encode` is kept while
   the file is Objective-C++ (it is not in the gate's grep); Phase 4 replaces it with the literal
   strings when the file becomes C++.
2. **The test pins the answers against a class of the test's own** with one method per return type
   (including those the table has not: `long long`, `void`, another struct, `BOOL`), run on the file
   with its template class first. No façade, no deletion bead.

## Amendment (bead oo-vl43): an intermediate class that adds virtual members, and initialisers that dispatch

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOBasicMaterial.h/.mm`,
  `OOBasicMaterial+ObjCBridge.h/.mm`, the adapter in `OOMaterial+ObjCBridge.h`,
  `tests/unit/core/test_OOBasicMaterial.mm`.

**Context.** `OOBasicMaterial` is the first class under the Materials root (amendment oo-smy) to
convert while Objective-C classes still derive from it (`OOSingleTextureMaterial`,
`OOMultiTextureMaterial`, `OOShaderMaterial`). Unlike the verifier's intermediate class (amendment
oo-up4b), it has callers that make it (`[[OOBasicMaterial alloc] initWithName:configuration:]` in
`OOMesh` and the convenience creators), selectors of its own, and a method its subclasses override
that its own initialiser calls (`-permitSpecular`, which `OOShaderMaterial` overrides). It also
tests `-isMemberOfClass:` and `-isKindOfClass:` on itself.

**Decision (recommended defaults).**

1. **The root's adapter becomes `oo::ObjCMaterial<Base>` with `oo::ObjCMaterialLink`,** in the
   root's bridge header, as amendment oo-up4b item 1 made `oo::ObjCStage<Base>`. The root façade's
   overridable methods answer an Objective-C material with the link's `super…()` members. The
   template is not `final`: an intermediate class that adds a virtual member derives its own
   adapter from it in its bridge `.mm` (`ObjCBasicMaterial`, which forwards `permitSpecular()`),
   and its façade's method for that member calls the class's own member, qualified, on an
   Objective-C subclass instance.
2. **Initialisers that call a virtual member are not constructors.** They are public members with
   the initialiser's name (`initWithName(name)`, `initWithName(name, configuration)`), run once
   right after construction, so the call reaches a subclass's override (in the constructor it
   would reach the base's). The class's static factories (`materialWithName`) are `makeRef` plus
   the initialiser; a converted subclass's initialiser calls the base's; the façade runs it on the
   C++ part it made. The façade's `-init…` makes that part itself: a new C++ object with the
   façade as its peer (`-initWithNewCxxMaterial:`, public on the root façade) when `[self class]`
   is exactly the façade class, else the subclass's adapter (`-initWithCxxMaterial:`). Plain
   `-init` does the same without an initialiser, as before.
3. **`-isMemberOfClass:[X class]` on `self` is `typeid(*this) == typeid(X)`,** and
   `-isKindOfClass:` of an argument is `dynamic_cast<X *>(p) != nullptr`. An Objective-C
   subclass's C++ part is its adapter, which is not exactly `X` and does derive from it, so both
   answer as before for every kind of object, nil included.
4. **A C++ object's façade class is found by walking its C++ base classes** (the Itanium ABI's
   type information) to the nearest `cxx::` class that has an Objective-C class of its name, then
   the root. A global C++ subclass of `cxx::OOBasicMaterial` is therefore an `OOBasicMaterial` to
   Objective-C, and the typed `oo::ToObjC(cxx::OOBasicMaterial *)` can `static_cast`. This
   refines amendment oo-up4b item 3 ("a global class is the root") for hierarchies with more than
   one façade.
5. **A file-static object the class made and never released** (`sDefaultMaterial`) is a raw
   pointer in an anonymous namespace filled with `factory(…).leakRef()` (amendment oo-3lj8 item 3).
   It holds the C++ object, not its façade: it is exactly the converted class, so a C++ reference
   owns all of it (amendment oo-smy item 4 does not apply).
6. **An `id` argument to `oo::ToCxx`** is ambiguous once a hierarchy has two façades (amendment
   oo-cc8a item 3): an initialiser's result (`id`) is assigned to a typed local first.

**Consequences.** One more façade and deletion bead (`OOBasicMaterial+ObjCBridge`), which depends
on the three subclass beads and on `OOMesh` and `OOMaterialConvenienceCreators`. The root's bridge
changed shape (template adapter, façade-class walk) without any caller or test changing. Each
subclass bead now converts on its own: it derives from `cxx::OOBasicMaterial`, calls
`OOBasicMaterial::initWithName(…)` from its own initialiser, and gets its façade by name.

## Amendment (bead oo-lh0x): a subclass that overrides a method the root made non-virtual

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOMultiTextureMaterial.h/.mm`,
  `apply()` in `OOMaterial.h` and the adapter in `OOMaterial+ObjCBridge.h`,
  `tests/unit/core/test_OOMultiTextureMaterial.mm`.

**Context.** Amendment 1 (oo-cwz) item 2 makes virtual only what a subclass overrides, and the
Materials root (oo-smy) left `apply()` non-virtual because no converted class overrode it. The
Objective-C `OOMultiTextureMaterial` did override `-apply`, which reached it by dynamic dispatch;
once the subclass is C++ that override is only reached if the member is virtual.

**Decision (recommended defaults).**

1. **The subclass bead makes the root's member virtual** (a one-word edit to the root's header),
   and adds it to the adapter like every other virtual member: the adapter's override messages the
   Objective-C object, its `super…()` member calls `Base::m()`, and the root façade's method takes
   the link's `super…()` for an Objective-C subclass instance and the virtual call otherwise. The
   root's tests pass unchanged: an Objective-C material that does not override it reaches the base
   member through the façade, as before.
2. **A converted class's `[super m]`** is `Base::m()`, qualified, as for any other overridden member.
3. **An initialiser whose `[super init…]` could not fail** keeps the statements that were guarded by
   `if (self != nil)` in a plain block with a comment, so the body does not move.
4. **A `cxx_init…` initialiser of an Objective-C class that converted code sends** is declared
   `OO_RETURNS_RETAINED` in its header if it is not already (as `-[AI cxx_initWithStateMachine:…]`
   is): the analyser, which follows the body once it is out of an `@implementation`, otherwise takes
   the selector for a +0 getter and reports the `autorelease` that balances it.

**Consequences.** The root gains one virtual member and one adapter pair per such override. The
root's façade deletion bead is unaffected.

## Amendment (bead oo-kdyh): a root and its one subclass, a container of façades, and a binding's own class

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOScriptTimer.h/.mm`,
  `OOScriptTimer+ObjCBridge.h/.mm`, `OOJSTimer.h/.mm`, `OOJSTimer+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOScriptTimer.mm`, `tests/unit/core/test_OOJSTimer.mm`.

**Context.** `OOScriptTimer` is an abstract base whose only subclass, `OOJSTimer`, is a JS binding
class in another file, with its own bead (oo-3m3l). The timer queue, `OOPriorityQueue` (converted
without a façade, amendment oo-3lj8), keeps Objective-C elements ordered by a selector. The Timer
JS object's private slot holds the timer, and the engine sends it the JS glue selectors
(`-oo_jsValueInContext:`, `-cxx_oo_jsClassName`). Both initialisers can answer nil, and the
subclass's calls the superclass's.

**Decision (recommended defaults).**

1. **A root whose only subclasses are in reach converts with them, in the root's bead,** so no
   adapter (amendment 1 item 3) is written only to be deleted. The subclass's bead then carries an
   honest acceptance over the same files and an empty proof commit.
2. **A container that keeps Objective-C objects keeps the façade.** The queue holds
   `oo::ToObjC(this)`, and while queued that façade keeps the C++ object alive, as the queue kept
   the old object. The façade's selector (`-compareByNextFireTime:`) forwards to the member. Removal
   uses `oo::LiveObjC(this)`, the live façade or nil, which never makes one: a queued object's
   façade is alive, so no façade means not queued, and the call is safe from a destructor, where
   making a façade would retain a dying object.
3. **A binding class that the engine messages by selector keeps a façade of its own** even with no
   outside caller: `@interface OOJSTimer : OOScriptTimer` with no ivars (amendment oo-up4b item 3),
   picked by `oo::ToObjC` from the C++ class's name. It forwards only the glue selectors; the
   root's façade forwards the rest to the virtual members. The private slot holds that façade,
   retained (amendment oo-ppc item 5); the natives get it with the `DEFINE_JS_OBJECT_GETTER`
   getter and cross with `oo::ToCxx`, null-guarded where the prototype (no private) answered 0.
   The finalizer drops the slot's retain with `objc_release`.
4. **Failable initialisers in a hierarchy** are `protected` `bool initWith…()` members (amendment
   oo-bhb9 item 1), so the subclass's initialiser calls the root's as it called `super`; each class
   has public static factories (`timerWithNextTime`, `oneShotTimerWithDelay`, `timerWithDelay`).
5. **A handler that can no longer fire goes, with a comment.** `-compareByNextFireTime:` read
   `[other nextTime]` inside `@try`/`@catch (OOException *)`; the C++ getter cannot throw.
6. **The test's engine stand-ins** (amendment oo-ppc item 6) include the classes the binding
   messages (`OOJavaScriptEngine`, `OOJSScript`), defined in the test with only the selectors
   used, and `OOObject`'s JS glue category as the engine defines it; the test imports neither
   class's header (amendment oo-z1s4 item 4). Its `Eval` drains an autorelease pool, as the game's
   frame loop does. A running timer that is garbage-collected is not tested: its finalizer
   describes it for a warning, which calls back into the engine during the collection, and on
   QuickJS that corrupted the heap (a crash at exit about one run in six, on the Objective-C file
   too). That is a bug of its own, filed as a bead.

**Consequences.** Two façades with two deletion beads: the root's waits for `PlayerEntity` and for
a timer queue of C++ timers; `OOJSTimer`'s waits for the engine's object wrappers to hold C++
objects. No caller changed.

## Amendment (bead oo-cn4o): a category only its own file sends, result classes behind a C function, and the definitions' deletion order

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSEngineTimeManagement.h/.mm`,
  `OOJSEngineTimeManagement+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJSEngineTimeManagement.mm`.

**Context.** `OOJSEngineTimeManagement` is a binding file (amendment oo-ppc) that also held a
category on the engine (`-watchdogTimerThread`, sent only by `OOJSTimeManagementInit()` in the same
file) and two small classes, `OOTimeProfile` and `OOTimeProfileEntry`, that the profiler makes and
hands out through a C function (`OOJSEndProfiling()`, +1) to the debug console, which is still
Objective-C.

**Decision (recommended defaults).**

1. **A category method that only its own file sends becomes a file-local free function** (in an
   anonymous namespace) taking what it read from `self` as arguments (here the runtime, which the
   caller already had). It gets no forwarder: nothing else sends it. A category sent from other
   files keeps the oo-ppc rule (free functions plus `X+ObjCBridge` forwarders).
2. **Result classes made only by C++ code** are plain `cxx::` classes (`oo::RefCounted`) held by
   `oo::Ref`; their façades follow the default ADR-0056 shape (`oo::ToObjC` makes one when asked,
   through `oo::ObjCPeers`), not amendment oo-o89, because their superclass is `OOObject`. A C
   function that returned one +1 to Objective-C keeps its signature and returns
   `[oo::ToObjC(result.get()) retain]`.
3. **A test that stands in for a class whose ivar the code under test reads** declares that ivar
   in its stand-in with the game's name and type, so the Objective-C-first run links.

**Consequences.** One bridge with a deletion bead (oo-9ht.63) that waits for the debug console and
the engine's object conversion. The three definition classes of amendment oo-q9q4 are deleted
when their holders are C++ and hold them with `oo::WeakRef` (oo-9ht.60, .61, .62); the retirement
of `OOWeakRefObject` (oo-9ht.22) comes after them, not before. No caller changed.

## Amendment (bead oo-6bux): a root whose one subclass is already a façade, a factory by `Class`, and a state array handed out by pointer

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOJoystickManager.h/.mm`,
  `OOJoystickManager+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJoystickManager.mm`.

**Context.** `OOJoystickManager` is the root of a hierarchy whose one subclass,
`OOSDLJoystickManager`, converted first (amendment oo-o89): its Objective-C façade still subclasses
the Objective-C root, keeps the root's state in it, and reaches the root's decoders with
`[oo::ToObjC(this) decodeAxisEvent:…]`. The root makes its shared instance from a registered
`Class` (`+setStickHandlerClass:`, `+sharedStickHandler`), its `-init` calls the methods the
subclass overrides, and it hands its callers a pointer into a `BOOL` array (`-getAllButtonStates`).

**Decision (recommended defaults).**

1. **The root converts as Amendment 1 says, and the subclass's façade does not change.** Its
   `-init` still makes its own C++ object and then calls `[super init]`, which is now the root
   façade's: that makes the adapter (`ObjCJoystickManager final : public cxx::OOJoystickManager`,
   private to the bridge `.mm`, overriding the three members the subclass overrides) and runs the
   old `-init` body on it. Its `[oo::ToObjC(this) decode…]` reaches the root façade's forwarders,
   which reach the adapter, which holds the state. With one Objective-C subclass and no
   intermediate class, the adapter is not a template; the root façade's methods for the virtual
   members call the base's member, qualified, on a subclass instance (Amendment 1 item 3).
2. **An `-init` body that calls overridden members is `void init()`, run by whoever made the
   object, once, right after construction** (amendments oo-vl43 item 2 and oo-bj8 item 6): the
   root façade's `-init` after it made the C++ part (so the subclass's overrides run during it, as
   before), converted code after `oo::makeRef`. The façade's `-init` makes a C++ object with
   itself as peer when `[self class]` is exactly the root, else the adapter.
3. **A factory that makes an instance of a registered `Class`** (`+sharedStickHandler`,
   `+setStickHandlerClass:` and their two file statics) stays in the façade, verbatim: the class it
   makes is an Objective-C class. It becomes C++ in the façade's deletion bead, when the subclass is
   C++ and the registration is a factory function.
4. **A member array whose address the class hands to unconverted code** keeps its element type
   (`BOOL butstate[BUTTON_end]`, returned as `const BOOL *`), with a comment; the other `BOOL` ivars
   become `bool`. Changing it would change every caller's pointer type.
5. **A getter that returned an ivar unretained** (`-getProfileForAxis:`) returns a borrowed raw
   pointer to the C++ object (`cxx::X *`), not an `oo::Ref`; the façade answers `oo::ToObjC(...)`
   of it, which keeps identity through the peer table.
6. **The test** pins the root through its Objective-C API with an Objective-C test subclass that
   overrides the hardware methods (also reached from `-init`, through saved settings), and points
   the user defaults at a scratch home (`HOMEPATH`) before they are first read (amendment oo-rmd7
   item 4). After the conversion it checks the crossing both ways, the subclass's C++ part
   reaching its overrides, and that part outliving its owner as nil. The subclass's own test
   (`test_OOSDLJoystickManager`) passes unchanged.

**Consequences.** One façade and one deletion bead, which depends on this bead's callers
(`PlayerEntity*`, `GameController`, `HeadUpDisplay`, `Universe`, `MyOpenGLView*`) and is done
together with `oo-9ht.2`, which re-parents `cxx::OOSDLJoystickManager` onto `cxx::OOJoystickManager`.

## Amendment (bead oo-2en): the Audio module, and a hierarchy root that is a class cluster

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/OOALSound.h/.mm`
  (`cxx::OOSound`), `OOALSound+ObjCBridge.h/.mm`, `tests/unit/core/test_OOSound.mm`. This is the
  Audio module's pattern seam: the other `OOAL*`/`OOSound*`/`OOMusic*` beads copy it.

**Context.** `OOSound` is the root of the sounds: `OOALBufferedSound`, `OOALStreamedSound` and
`OOMusic` derive from it in their own files. It keeps the sound system's global state (set up,
sound OK, the master volume) in class methods, and its designated initialiser
`-cxx_initWithContentsOfFile:` is a class cluster's: it releases the receiver and answers a
buffered or a streamed sound, which are Objective-C subclasses. `OOMusic` overrides that
initialiser. The other audio classes (the sources, the pool, the mixer, the channels, the decoder,
the music controller) are not sounds.

**Decision (recommended defaults).**

1. **The module converts root first** (amendment oo-smy item 1): `OOSound` in this bead, with
   amendment oo-smy's root façade and an adapter (`ObjCSound`, as `OODrawable`'s, since no
   intermediate class exists). The per-file bead of `OOALSound.mm` is superseded by this one. The
   three subclass beads depend on it; each derives from `cxx::OOSound`. The classes that are not
   sounds follow the decision above, and amendment oo-r7m0 for the singletons (the mixer, the
   music controller).
2. **A class-cluster initialiser whose answers are Objective-C subclass instances** becomes a
   static factory with the initialiser's name (amendment oo-novu item 1) that returns the
   Objective-C object retained, `oo::ObjCRef<::X *>`, because an Objective-C object's C++ part does
   not keep it alive (amendment oo-smy item 4). Null where it answered nil. The body stays in
   `X.mm`; its `[[Sub alloc] init…]` sends are messages to unconverted classes. The façade's
   initialiser keeps what concerns the receiver (`[self release]`, and the early `return nil`
   that leaked it) and returns `factory(…).leakRef()`. The factory becomes `oo::Ref<X>` in the
   façade's deletion bead.
3. **A subclass that overrides the cluster's initialiser** (`OOMusic`) keeps overriding the
   façade's method while it is Objective-C. When it converts it gets a static factory of the same
   name, which hides the root's (amendment oo-489v item 2).
4. **A root's `-init` side effect** (`[OOSound setUp]`) is the C++ constructor. The façade's
   `-init` makes the adapter, which runs it, so `[[Sub alloc] init]` still sets sound up.
5. **An initialiser that only the subclasses declare** (`-initWithDecoder:`, which answered nil on
   the root) stays in the façade unchanged. It is not part of the C++ class.
6. **A file-static of plain type whose line changes** (`static BOOL sIsSetUp` becoming `bool`)
   moves into an anonymous namespace, which is what clang-tidy's `misc-use-anonymous-namespace`
   asks of a changed line. Unchanged statics stay as they are.
7. **The test** runs OpenAL on OpenAL Soft's null backend (`ALSOFT_DRIVERS=null`) and points
   `HOMEPATH` at a scratch folder before the first use, so neither the machine's sound hardware
   nor the user's saved volume changes the answers. The global state is per process, so the test
   that sets sound up runs first. The decoder, the mixer and the two concrete sounds are stubs
   in the test (amendment oo-z1s4 item 4); the concrete sounds are Objective-C subclasses, so the
   class cluster's answers also exercise the adapter.

**Consequences.** One façade and one deletion bead (`OOALSound+ObjCBridge`), which depends on the
three subclass beads and on the beads of the files that message sounds. No caller changed.

## Amendment (bead oo-9ht.66): a message whose selector no header declares

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `oo::SendClassName` in
  `src/Core/OOWeakReference+ObjCBridge.h/.mm`, `oo::SendIntValue` in `OOCharacter+ObjCBridge.h/.mm`.

**Context.** A converted body sends a selector (`-className`, `-intValue`) to an `id` that may
answer it, but no visible header declares the method any more, so the send needs a local
`@protocol` to type it. The item 8 grep forbids `@protocol` in `X.mm`.

**Decision (recommended default).** The protocol and the one send move, verbatim, into a free
function in `X+ObjCBridge.mm` (`id oo::SendClassName(id object)`), declared in `X+ObjCBridge.h`
beside `oo::ToObjC`/`oo::ToCxx`; the C++ body calls the function where it sent the message. The
function goes with the façade's deletion bead, or earlier once a header declares the method again.

## Amendment (bead oo-q9q4): scripting classes whose superclass is still Objective-C, and the rest of the batch

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOPListScript.h/.mm`,
  `OOPListScript+ObjCBridge.h/.mm`, `tests/unit/core/test_OOPListScript.mm`; the same shape in
  `OOJSPopulatorDefinition`, `OOJSInterfaceDefinition` and `OOJSGuiScreenKeyDefinition` (oo-1h0h,
  oo-8fpc, oo-xg7g, superclass `OOWeakRefObject`).

**Context.** Several scripting classes derive from classes that are still Objective-C: `OOPListScript`
from `OOScript`, the three JS definition classes from `OOWeakRefObject` (whose instances are weakly
referenced). Their callers `alloc`/`init` them, and `OOPListScript`'s own class methods make its
instances. The rest of the batch (oo-3smy, oo-81hy, oo-n041, oo-lzsb) met smaller questions.

**Decision (recommended defaults).**

1. **They follow amendment oo-o89.** The façade keeps the old superclass, makes and owns the C++
   object in its initialiser, forwards every method, and `oo::ToObjC` answers the live façade or nil.
   A class method that makes instances becomes a static member that makes them through the façade
   (`[[::OOPListScript alloc] initWithName:…]`, as `[[self alloc] …]` did): until the superclass
   converts, an instance is its façade. The initialiser that only those factories used is declared
   in the bridge header's category `OOObjCBridge`.
2. **A header that imports another class's header only for an ivar type** names it with `@class`
   and the `.mm` imports it (amendment oo-fg7i item 5), in the commit that adds the test, so that the
   test can stand in for that class (`OOJSScript`) without importing its header.
3. **A class whose only other link is the engine's by-selector glue gets the stand-ins of amendment
   oo-ppc item 6 in its test,** including the engine object and `OOJSScript`, which the test defines
   itself; a test that needs the cache manager, the sanitizer and the player links the whole game
   (amendment oo-44gg) and reads its scripts from the cache.
4. **A scripting file with no class** (`OOJSFrameCallbacks`) converts as a binding (amendment oo-ppc
   item 2); a static whose line that touches moves into an anonymous namespace, as the others were,
   because tier-a counts an edited line's old finding as new. **One with no Objective-C left**
   (`OOJSEngineDebuggerHelpers`) gets an honest acceptance and an empty proof commit (CLAUDE.md rule 9).
   **Objective-C that exists to be read by the runtime** (the method-signature template class of
   `OOJSCall`) moves unchanged to the bridge (amendment oo-rmd7 item 1) until nothing is called by
   name.
5. **A converted class in `namespace cxx` that messages the class being converted** names its façade
   `::X`, in its header's ivar too (`OORegExpMatcher`'s `::OOJSFunction *_tester`), as amendment
   oo-rmd7 item 3 says.

**Consequences.** Each of these classes has a façade with a deletion bead that waits for its
superclass (oo-604l for `OOScript`; the retirement of `OOWeakRefObject`). No caller changed but the
two `::OOJSFunction` lines.

## Amendment (bead oo-ja7y): categories on the root that a class's header declares, and `self` as a value

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOShaderMaterial.h/.mm`,
  `OOShaderMaterial+ObjCBridge.h/.mm`, `tests/unit/core/test_OOShaderMaterial.mm`.

**Decision (recommended defaults).**

1. **Informal protocols declared in the class's header as categories of `OOObject`**
   (`ShaderBindingHierarchy`, `OOShaderMaterialTargetOptional`), which other classes implement and
   the class only asks about, move unchanged to the bridge header, as amendment oo-3kqi item 5
   moves a category on an Objective-C root. The C declarations and constants of the header stay.
   The body asks with `OOSelectorFromName("…")` (amendment oo-3lj8 item 2).
2. **`self`'s address used as a value** (the random seed `(uint32_t)(uintptr_t)self` when the
   binding target has none) becomes `this`'s. Either is an arbitrary heap address, so no answer
   that could be pinned changes; the façade's address is not used, because a C++ object made by
   its factory has no façade until something crosses.
3. **A class's C++ uniform setters whose selectors share the first keyword** (`setUniform:intValue:`,
   `…floatValue:`, `…vectorValue:`, `…vectorObjectValue:`, `…quaternionValue:asMatrix:`) are
   overloads, each commented with its second keyword; the test checks that each makes what its
   selector made.
4. **`@try { … } @catch (id) {}` around messages** is `try { … } catch (...)` (amendment oo-ppc:
   a C++ `catch (...)` catches an Objective-C exception). The handler is not left empty
   (`bugprone-empty-catch`): it does in so many words what falling out of the empty `@catch` did,
   here `return true;`, with a comment.

## Amendment (bead oo-n99o): failable initialisers that share a first keyword, and a union of ivars

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOShaderUniform.h/.mm`,
  `OOShaderUniform+ObjCBridge.h/.mm`, `tests/unit/core/test_OOShaderUniform.mm`.

**Decision (recommended defaults).**

1. **Seven failable initialisers that share `initWithName:shaderProgram:`** become seven overloads of
   one static factory named after them (amendment oo-novu item 1), told apart by the third
   argument's type and each commented with its keyword. Each body is the old one with `self` as the
   new object (`result->`), and the shared private designated initialiser is a `bool` member.
   A factory that fails before making the object (a nil colour) answers null without making one.
2. **A union of ivars, bit-fields included, stays as it is** (its members are C), with `= {}`; the
   factories make the object with `new X()`, which zero-initialises the whole of it first, as
   `class_createInstance` did.
3. **A converted class in `namespace cxx` that makes the converted class's Objective-C objects**
   (`cxx::OOShaderMaterial` makes `OOShaderUniform`s) names the façade `::X` and keeps its
   messages (amendment oo-rmd7 item 3), so the stub its test defines is still what it makes. The
   façade's deletion bead turns them into C++ calls.
4. **`-cxx_description` that printed `[self class]` and `self`** prints the class name as a literal
   and the façade's address, `oo::ToObjC(this)` (amendments oo-3lj8 item 4, oo-bhb9 item 6).
