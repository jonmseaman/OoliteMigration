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

## Amendment (bead oo-ykoy): a binding's category on the class it wraps, and its test

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSWormhole.h/.mm`,
  `OOJSWormhole+ObjCBridge.mm`, `tests/unit/core/test_OOJSWormhole.mm`.

**Context.** Most binding files that wrap a game object carry a category on its class
(`WormholeEntity (OOJavaScriptExtensions)`, `OOSound (OOJavaScriptExtentions)`) whose methods the
engine sends by selector: `-getJSClass:andPrototype:`, `-cxx_oo_jsClassName`,
`-isVisibleToScripts`, `-oo_jsValueInContext:`, `-cxx_oo_jsDescription`. Amendment oo-ppc, item 3
covers a category, but every binding implements the same selectors, several binding headers
declare the category's `@interface` (so the binding's grep cannot pass while it stays there), and
the classes the category extends drag the whole game into a test's link.

**Decision (recommended defaults).**

1. **The free function is named after the binding file and the selector's first keyword**, less
   the Phase 2 `cxx_` and the `oo_` prefixes: `OOJSWormholeGetJSClass(outClass, outPrototype)`,
   `OOJSWormholeJSClassName()`, `OOJSWormholeIsVisibleToScripts()`,
   `OOJSSoundJSValueInContext(sound, context)`. A plain selector name would be defined once per
   binding and clash at link time. A method that used `self` takes the object as its first
   parameter, named after the class (`sound`), and `self` in the body becomes that name.
2. **The category's `@interface`, if the binding header declared it, moves verbatim into
   `X+ObjCBridge.mm`**, above the `@implementation` it declares. Nothing else needs it: the
   selectors are declared by `Entity (OOJavaScriptExtensions)` and `OOObject (OOJavaScript)`, which
   is how the engine sends them. `X.h` keeps its `@class` line and declares the free functions.
3. **The bridge's deletion bead depends on the conversion bead of the class the category extends**
   (`WormholeEntity`: oo-z55j), as amendment oo-ppc, item 3 says; one "Delete X+ObjCBridge" bead per
   binding.
4. **The test stands in for the wrapped class** (amendment oo-z1s4, item 4): it declares
   `@interface`s of the real names (`Entity`, `WormholeEntity`) answering only the selectors the
   binding sends, and imports neither their headers nor `OOJavaScriptEngine.h`, which imports
   them. The engine functions the binding links against are defined in the test with that
   header's linkage (`extern "C"` for `OOJS_EXTERN_C`); the object getter checks the JS subclass
   table and the Objective-C class as the engine's does. A JS object for an entity is made as
   `-oo_jsValueInContext:` makes it: the class and prototype that `-getJSClass:andPrototype:`
   names, with the object in the private slot. The test sends the category's selectors through a
   test-side `@interface`, so the same file runs on the Objective-C binding and on the converted one,
   and covers the forwarders.

**Consequences.** Each entity binding bead adds a bridge of three or four one-line methods and a
deletion bead, and needs no whole-game link. The bridges go when the entity classes convert.

## Amendment (bead oo-puw9): a subclass of `OOWeakRefObject`, a deferred call to a class method, and an initialiser that hands `self` out

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/AI.h/.mm`,
  `AI+ObjCBridge.h/.mm`, `tests/unit/core/test_AI.mm`.

**Context.** `AI` derives from `OOWeakRefObject`, which stays Objective-C until its subclasses
(`Entity`'s facade, `Universe`, `OOTexture` and others) are C++ (amendment oo-3kqi item 5). Ships
keep it and weak references to it. It schedules deferred calls with `OOScheduleDeferredCall` on a
class method of its own (`+deferredCallTrampolineWithInfo:`), passing an Objective-C holder object
and naming the target selector with `@selector`. `-cxx_initWithStateMachine:andState:` loads a
state machine and logs `self` while doing it. Its bodies `@try`/`@catch (OOException *)` and
`@try`/`@finally`.

**Decision (recommended defaults).**

1. **A subclass of `OOWeakRefObject` converts as a subclass of an Objective-C class** (amendment
   oo-o89 item 2): the facade keeps the superclass, makes and owns the C++ object in `-init`, and
   `oo::ToObjC` answers the live facade or nil. The weak references callers hold are to the facade,
   so the identity they rely on does not move.
2. **A deferred call stays a deferred call to the facade.** The holder class and the class method it
   targets move, bodies unchanged, into the bridge files (amendment oo-rmd7 item 1); the holder's
   `@interface` and its struct go in the bridge header so `X.mm` can fill one. `X.mm` schedules
   `[::X class]` with `OOSelectorFromName("…")`, and retains `oo::ToObjC(this)` where it retained
   `self`, so a pending call still keeps the object alive. A private method that a deferred call
   reaches by name (`-deferredSetState:`) stays on the facade as a one-line forwarder in a private
   category.
3. **An initialiser with arguments whose body hands `self` to Objective-C** (logs it, or reaches
   code that calls `oo::ToObjC(this)`) is a member run by the facade after it is the object's peer
   (`initWithStateMachine(…)`), not a constructor, where `oo::ToObjC(this)` would answer nil
   (amendment oo-vl43 item 2 for the same reason with virtual calls).
4. **`@try`/`@catch (OOException *)` and `@try`/`@finally` stay verbatim** in the converted members
   (amendment oo-bj8 item 8); the gate's grep does not cover them, and Phase 4 replaces them with the
   rest of the Objective-C exception sites.
5. **A selector the class compared or asked about by a literal** (`respondsToSelector:@selector(interpretAIMessage:)`)
   becomes `OOSelectorFromName("interpretAIMessage:")` (amendment oo-3lj8 item 2); the message to the
   Objective-C owner stays.
6. **The test** defines the classes and functions the AI reaches that would link the game
   (`ResourceManager`, `OOCacheManager`, `cxx_OOPropertyListFromFile`, `OOScheduleDeferredCall`, the
   `OOLog*Indent` functions), each answering from a table, and an owner of its own derived from
   `OOWeakRefObject` that records the actions it is sent. It pins whitelisting and aliases, the
   state-machine stack and its limit, message queueing and its limit, recursion, deferred calls and
   their retain of the AI, and the logged lines.

**Consequences.** No caller changed. One facade and one deletion bead, which depends on the
callers (`ShipEntity*`, `PlayerEntity`) and on `OOWeakRefObject`'s retirement.

## Amendment (bead oo-kq7): the Debug module, and a singleton whose superclass is Objective-C

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Debug/OODebugMonitor.h/.mm`
  (`cxx::OODebugMonitor`), `OODebugMonitor+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OODebugMonitor.mm`. This is the Debug module's pattern seam: the other
  `Core/Debug` beads copy it.

**Context.** `OODebugMonitor` is the singleton that connects a debugger (the TCP console client,
which the golden harness drives the game through) to the game. Its superclass, `OOWeakRefObject`,
is Objective-C and keeps state (the object's weak reference, which the console's JavaScript object
holds). It has the canonical singleton boilerplate (`+allocWithZone:` answers nil after the first;
`-retain`/`-release` do nothing), so its `-dealloc` never ran. `OODebugMonitor.h` declares the
`OODebugMonitorInterface` protocol that the class adopts, and the class also adopts the JavaScript
engine's `OOJavaScriptEngineMonitor` in a private category. The whole file is `#ifndef NDEBUG`.

**Decision (recommended defaults).**

1. **The C++ class owns the singleton** (amendment oo-r7m0 item 1): `static X *sharedX()`,
   recorded before its `init()` runs (amendment oo-z1s4 item 2). The façade is not the owner, as
   amendment oo-o89 would make it, because converted code must reach the monitor without messaging
   Objective-C.
2. **Its façade is made once and lives as long as the process.** The façade keeps the singleton
   boilerplate (it is the Objective-C object's retain and release), so once `oo::ToObjC` makes it
   it is never deallocated. `oo::ToObjC` answers that one façade (`sSingleton`, recorded by
   `+allocWithZone:`) with no peer table, and so never makes a second object with fresh
   superclass state, which is the point of amendment oo-o89 item 2. `+sharedX` is
   `oo::ToObjC(X::sharedX())`. The façade's superclass stays the Objective-C one, and the façade's
   deletion bead depends on that superclass's conversion as well as on the callers'.
3. **A `-dealloc` that never ran** (because `-release` did nothing) is not translated. A comment
   stands where it was.
4. **A protocol that the class adopts and that `X.h` declares** moves to `X+ObjCBridge.h`, before
   the façade (amendment oo-jpd8 item 1). **A protocol from another module's header**
   (`OOJavaScriptEngineMonitor`) is adopted by a category declared in `X+ObjCBridge.mm`, which
   imports that header. `X+ObjCBridge.h` does not import it, so a test can stand in for that
   module. The C++ class hands its façade to an API typed `id<P>` through a typed local
   (`id monitor = oo::ToObjC(this);`, as amendment oo-vl43 item 6 does).
5. **A struct private to the file that a private method takes** (`EntityDumpState`) becomes a
   private nested `struct X::EntityDumpState;`, declared in the class and defined in `X.mm` where
   it stood. That keeps the method a member and its body verbatim.
6. **An observer registration that captured `self`** observes as `this` and captures `this`.
   **`id x = _ivar; _ivar = nil; [x release];`** on an `oo::ObjCRef` (amendment oo-862e item 4) is
   `_ivar = nullptr;`, which clears the ivar before it releases the object, as before.
7. **A file that is `#ifndef NDEBUG`** keeps the guard in `X.mm`, and its bridge `.mm` has the same
   guard.
8. **The test** stands in for everything the monitor reaches (the resource manager, the JavaScript
   engine, the console script and its JS wrapper, the time limiter, the textures and the universe),
   with a real QuickJS context for the heap statistics. It drives a test debugger through the
   façade. Because `OOCocoa.h` defines `true` and `false` as `1` and `0`, a test that builds a Bool
   `oo::PList` node uses a `bool` constant (`kTrue`), not the literal. The golden gate is this
   module's end-to-end proof, because the harness talks to the game through the debug console.

**Consequences.** One façade and one deletion bead (`OODebugMonitor+ObjCBridge`). The deletion
bead waits for the TCP console client, the JavaScript console, the debug support,
`PlayerEntityControls` and `GameController`, and for `OOWeakRefObject`'s replacement. No caller
changed.

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

## Amendment (bead oo-0otc): an entity intermediate class with Objective-C subclasses that read its ivars

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OOLightParticleEntity.h/.mm`,
  `OOLightParticleEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_OOLightParticleEntity.mm`; its
  converted leaves `OOSparkEntity` (oo-c2dk) and `OOPlasmaBurstEntity` (oo-l2s5).

**Context.** `OOLightParticleEntity` is the first entity class under `Entity` to convert while
Objective-C classes still derive from it (`OOFlashEffectEntity`, `OOFlasherEntity`,
`OOPlasmaShotEntity`), like `OOEntityWithDrawable` (amendment oo-bj8 item 5), but unlike it the
class adds members its subclasses override (`-texture`, `-drawSubEntityImmediate:translucent:`),
its subclasses read two `@protected` ivars by name (`_colorComponents`, `_diameter`), and it has
class methods and a file-static texture whose graphics reset client is the class object.

**Decision (recommended defaults).**

1. **The entity adapter is not `final`.** An intermediate entity class that adds virtual members
   derives its own adapter from `oo::ObjCEntity<cxx::X>` in its bridge `.mm`, one override per
   added member that messages the Objective-C object, as amendment oo-vl43 item 1 does for the
   materials. The façade's method for such a member calls the class's own member, qualified
   (`part->cxx::X::texture()`), on an Objective-C subclass instance, and the virtual member
   otherwise. Its `-init` makes that adapter; `-initWithX:` is `[self init]` and then the C++
   initialiser (no subclass overrides `-init`).
2. **An Objective-C subclass reads an ivar that moved to an intermediate class through the typed
   crossing:** `oo::ToCxx(self)->_colorComponents`. The root's `_cxxEntity->` (amendment oo-bj8
   item 2) is typed as the root and cannot name it; the typed `oo::ToCxx` of the class's bridge
   header can. The edit is mechanical, as there, and deleting `oo::ToCxx(self)->` gives the
   subclass's body back when it converts.
3. **Class methods become static members, and a file-static object they keep stays file-static**
   (`sBlobTexture`, retained by hand as before). The graphics reset client stays the façade class:
   the converted body registers `[::X class]` with the C++ manager
   (`OOGraphicsResetManager::sharedManager()->registerClient(...)`), and the façade's
   `+resetGraphicsState` forwards to the static member. The client is still an Objective-C object,
   so amendment oo-jpd8 item 3's C++ client interface is not needed yet.
4. **An initialiser that calls members a subclass overrides** is a public member with its name,
   run once after construction (amendment oo-vl43 item 2). A converted leaf's own initialiser calls
   it first, as it called `[super initWithDiameter:]`, and its static factory is `makeRef` plus
   its initialiser; the code that made it hands the result to `oo::NewEntityFacade`, whose chain
   gains the class's line, so a C++ leaf's façade is the intermediate class's.

**Consequences.** One façade and deletion bead (`OOLightParticleEntity+ObjCBridge`), which waits
for the three Objective-C subclasses and for the universe and `OOParticleSystem`, which message the
class. Nine reads in the subclasses changed by item 2. The root's adapter lost `final`; no other
root file changed but `oo::NewEntityFacade`'s chain.

## Amendment (bead oo-0mxi): an entity leaf with a façade, made by its callers or its class method

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/DustEntity.h/.mm`,
  `DustEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_DustEntity.mm`; with a class method,
  `OOLaserShotEntity` (oo-5zpq) and `OOBreakPatternEntity` (oo-a014).

**Context.** Amendment oo-bj8 item 12 keeps a façade for a leaf that unconverted code messages by
its own selectors. `DustEntity` is also made by its callers (`[[DustEntity alloc] init]` in the
universe, which then finds it with `-isKindOfClass:`), its `-init` hands `self` to the graphics
reset manager, and its shader's uniforms are bound to it by selector (`-warpVector`,
`-offsetPlayerPosition`). `OOLaserShotEntity` and `OOBreakPatternEntity` are made by class methods
that callers send, and the test reads their private vertex and colour arrays.

**Decision (recommended defaults).**

1. **The leaf is `cxx::X`, and its façade `@interface X : Entity` has no ivars** (amendment oo-up4b
   item 3), with the selectors the header declared, copied exactly, and its typed
   `oo::ToCxx`/`oo::ToObjC`. `oo::NewEntityFacade`'s chain gains the class's line.
2. **When callers allocate it,** the façade's `-init` makes the C++ object, stores it with the
   root's `-initWithCxxEntity:`, and then runs the C++ `init()`, the body after `[super init]`
   (the constructor ran `Entity`'s). The body runs once the façade holds the object, so a body
   that hands `self` to Objective-C hands `oo::ToObjC(this)`, the façade (amendment oo-8kx7 item
   3). An entity sent `-init` again keeps its part and runs the body again, as before.
3. **What Objective-C sends the object by selector, the façade answers:** the uniforms' bound
   getters forward to the members, and `-resetGraphicsState` too, the façade being the client it
   registered. A `@selector` in the body is `OOSelectorFromName` (amendment oo-8kx7 item 4). A
   `-dealloc` that unregistered `self` stays in the façade (amendment oo-bj8 item 7); the rest of
   it was releases, which the members now do.
4. **When a class method makes it,** the C++ class has the static factory and the façade's class
   method is `oo::NewEntityFacade(cxx::X::factory(...))`, so callers do not change.
5. **A private array the test reads** goes through a test access struct the class befriends
   (amendment oo-862e item 2); before the conversion the struct read the ivars by offset.
6. **An ivar with the name of a method** keeps its name and the method becomes `get` + the name
   (`shader`, `getShader()`; amendment oo-862e item 1).

**Consequences.** One façade and deletion bead per such leaf (`DustEntity`, `OOLaserShotEntity`,
`OOBreakPatternEntity`), each waiting for the callers that make and message it (the universe,
`ShipEntity`, `PlayerEntity`). No caller changed.

## Amendment (bead oo-2c6g): a façade-less leaf that overrode a category method, and `Entity` in a global leaf

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OOQuiriumCascadeEntity.h/.mm`,
  `OOQuiriumCascadeEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_OOQuiriumCascadeEntity.mm`;
  `OOSparkEntity` (oo-c2dk), `OOPlasmaBurstEntity` (oo-l2s5).

**Context.** `OOQuiriumCascadeEntity` converts with no façade (amendment oo-bj8 item 12): its one
selector, `+quiriumCascadeFromShip:`, is sent from two lines of `ShipEntity`. But its header also
declared a category of `Entity`, `-isCascadeWeapon`, which answered NO and which the class
overrode to answer YES; with no façade there is no Objective-C class left to override it. Its
initialiser answered nil for a nil ship. And in the body of a global class derived from
`cxx::Entity`, the name `Entity` is the base's injected class name, so a local `Entity *e` that
meant the Objective-C object now names the C++ class.

**Decision (recommended defaults).**

1. **The category moves to `X+ObjCBridge.h/.mm`** (amendment oo-ppc item 3), and its method answers
   for a C++ object of the class by asking it: `dynamic_cast<X *>(oo::ToCxx(self))`, then the
   class's member, else the old answer. Objective-C classes that override the method still do.
2. **The leaf's factory replaces `alloc`/`init…` at the call sites**, which hand the result to
   `oo::NewEntityFacade` (whose object is the nearest façade's: `Entity`, or
   `OOLightParticleEntity` for the sparks); an `alloc`/`release` pair becomes that autoreleased
   object. An initialiser that answered nil for its input is a `bool` member and the factory
   answers null (amendment oo-novu); `oo::NewEntityFacade` of null is nil, as before.
3. **In a global leaf's bodies, an `Entity *` that held an Objective-C object is written
   `::Entity *`**, and `[super m]` is the base's member (`cxx::Entity::update(delta_t)`). A local
   that shadows a member function it is initialised from calls it as `this->owner()`.

**Consequences.** One bridge file pair with no façade class; it goes with the `Entity` façade's
deletion bead (oo-9ht.39), which also removes the category. The test's nil case could not run on
the class before its conversion: releasing an entity whose `-init` never ran crashes in the
`Entity` façade's `-dealloc` (filed as its own bead).

## Amendment (bead oo-f9zg): a cache of unretained objects that remove themselves

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOShaderProgram.h/.mm`,
  `OOShaderProgram+ObjCBridge.h/.mm`, `tests/unit/core/test_OOShaderProgram.mm`.

**Context.** `OOShaderProgram` keeps a cache of programs by key that does not retain them; a program
erases itself in `-dealloc`, and the class methods return an autoreleased program (cached or new).
It also keeps the program in use retained in a file static.

**Decision (recommended defaults).**

1. **The cache holds raw C++ pointers** in an anonymous namespace inside `namespace cxx`, and the
   destructor erases the entry, as `-dealloc` did. The factories return `oo::Ref<X>` (a cache hit
   is retained into the `Ref`); a failed initialiser is a `bool` member and the factory answers
   null. The façade's class methods answer `oo::ToObjC(factory(...))`, whose autorelease keeps the
   program until the pool drains, as the autoreleased program was kept (amendment oo-ct7c item 2);
   a cache hit whose façade is alive answers that façade.
2. **The retained file static** (`sActiveProgram`) is a never-destroyed holder (`ActiveProgram()`,
   amendment oo-smy item 3) that keeps **the façade**, `oo::ObjCRef<::X *>(oo::ToObjC(this))`, as
   the current material does (amendment oo-smy item 4), not an `oo::Ref<X>`: the façade owns the
   C++ program and is the object `sActiveProgram` retained, so a façade in use stays alive and
   stays the program's one façade (`test_OOShaderProgram` pins the retain on the façade). The
   assignment sits in an `@autoreleasepool` so that `oo::ToObjC`'s autorelease drains at once and
   the program in use carries only the slot's retain, as `[program retain]` did. The destructor's
   imbalance check stays under `#ifndef NDEBUG` for fidelity (it cannot fire while the slot owns
   the façade), and drops the reference without releasing it. The slot changes to `oo::Ref<X>`
   in the façade's deletion bead.
3. **An ivar that shares its name with its getter** (`program`) takes the leading underscore
   (amendment oo-rdfh item 1).
4. **A converted C++ class that messages a converted façade's collaborator** (`[[UNIVERSE gameView]
   getOpenGLMatrixManager]`, a façade over the C++ matrix manager) crosses once with `oo::ToCxx`
   and null-guards each call with what the message to nil answered (`kZeroMatrix`, a null list;
   amendment oo-vt0o item 3).

## Amendment (bead oo-9fwb): a category of a converted class in a file of its own

- Date: 2026-09-30. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOMaterialConvenienceCreators.h/.mm`,
  `OOMaterialConvenienceCreators+ObjCBridge.h/.mm`, the creators in `OOMaterial.h`,
  `tests/unit/core/test_OOMaterialConvenienceCreators.mm`.

**Context.** `OOMaterialConvenienceCreators` is the category `OOMaterial (OOConvenienceCreators)`:
class methods that pick and make a material, and two private class methods of their own; its
file also holds C++ helper functions (the shader-configuration synthesis) that are already C++.
The root converted first (oo-smy), and its only outside caller (`OOMesh`) is still Objective-C.

**Decision (recommended defaults).**

1. **The category's class methods become static members of the converted class** (amendment oo-o89
   item 4), declared in the class's header under a comment naming the category, and defined in the
   category's own file, which keeps its name. Its private class methods are private static
   members. `[self m]` in them is a plain call.
2. **The category's `@interface` moves, unchanged, to `X+ObjCBridge.h`** of the category's file,
   imported as its header's last line, and its `@implementation` is one-line forwarders in
   `X+ObjCBridge.mm` that answer `oo::ToObjC(result)`. It goes with its own deletion bead, which
   depends on the callers' beads.
3. **The creators make materials with the C++ factories** (`OOShaderMaterial::shaderMaterialWithName`,
   `OOBasicMaterial::materialWithName`, …), since every material class is converted; a class whose
   test stubs its Objective-C collaborator (`OOCacheManager`, `OOTexture`) keeps the message to
   `::X` (amendment oo-rmd7 item 3).
4. **`+initialize` that set a file static** (compiled out here: the new-synthesizer branch) becomes a
   function-local static read on first use, which is when `+initialize` ran.

## Amendment (bead oo-peql): the effect leaves (entities that nothing messages by their own selectors)

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OORingEffectEntity.h/.mm`
  (factories over a failable initialiser), `OOECMBlastEntity.h/.mm` with `OOECMBlastEntity+ObjCBridge.h/.mm`
  (an initialiser-named factory, a category of `Entity` the class overrode), `OOParticleSystem.h/.mm` and
  `OOExplosionCloudEntity.h/.mm` (beads oo-cenx and oo-ui7h: a hierarchy converted whole),
  `tests/unit/core/test_OORingEffectEntity.mm`, `test_OOECMBlastEntity.mm`, `test_OOParticleSystem.mm`.

**Context.** These are the first leaves of amendment oo-bj8 item 12. The effects are made in two or
three places (`ShipEntity`'s explosion and `-fireECM`, `Universe`'s witchspace and laser-hit effects),
handed to `-[Universe addEntity:]`, and after that reached only through `Entity`'s selectors. Their
initialisers can answer nil (no source, no texture), one class sets up a table in `+initialize`, one
file declares a category of `Entity` that its class overrode (`-isECMBlast`), and `OOParticleSystem`
has three subclasses, all of which are in reach.

**Decision (recommended defaults).**

1. **No façade.** The class is global, `X : public cxx::Entity` (item 12). Its factories keep the
   Objective-C names and arguments (`explosionCloudFromEntity(entity, size, settings)`), and the other
   entity they take stays the Objective-C object, `::Entity *` (item 4), so the bodies' messages to it
   (`[entity position]`, `[sourceEntity collisionRadius]`, nil-safe as before) are verbatim. A caller
   writes `[UNIVERSE addEntity:oo::NewEntityFacade(X::factory(self))]`; one that set something first
   keeps the `oo::Ref<X>`, null-guards the call (it was a message to nil), and passes the reference.
   `NewEntityFacade(nullptr)` is nil, which `-addEntity:` already refused.
2. **Failable initialisers** follow amendments oo-bhb9 and oo-novu: where the class had factories
   (`+ringFromEntity:`) the initialiser is a private `bool initX(…)` they call after `makeRef`; where
   callers sent `[[X alloc] initX:]` (`-initFromShip:`) it becomes the static factory of that name over
   a private constructor, whose virtual calls are the base's own, qualified (amendment oo-bj8 item 6).
   An initialiser that cannot fail is `void`, and a subclass keeps the statements its
   `if ((self = [super init…]))` guarded in a plain block.
3. **`+initialize`** becomes a private static member with a run-once guard, called by the factory
   before the first object is made (the first message to the class was what ran it).
4. **A category of `Entity` that the class overrode** moves to `X+ObjCBridge.h/.mm` (item 12), and its
   method answers for both kinds of entity from the C++ part:
   `dynamic_cast<X *>(_cxxEntity.get())`, then the member. Its deletion bead makes it a member of
   `cxx::Entity` once its callers (none today) are C++.
5. **A class whose subclasses are all in reach converts with them** (amendment oo-kdyh item 1), so no
   intermediate façade or adapter is written to be deleted: `OOParticleSystem`, its two fragment
   bursts and `OOExplosionCloudEntity` are one bead (oo-cenx); the subclass's bead (oo-ui7h) carries
   an honest acceptance over the same files and an empty proof commit. Its `-init` that answered nil
   (only the subclasses' initialisers made one) is a protected constructor, and its protected ivars
   are protected members.
6. **`OOColor` at file scope is the Objective-C façade** (entity headers `@class` it), so a global
   class names the C++ colour `cxx::OOColor`. Retained Objective-C objects the class owned are
   `oo::ObjCRef` (the texture; `-dealloc` goes); one the class never released (`OOECMBlastEntity`'s
   weak reference to its ship) stays a raw pointer, still never released.
7. **The tests** link the whole game (amendment oo-44gg) and make the entity through one block of
   helpers, the only lines the conversion ported (`[X factory:…]` became
   `oo::NewEntityFacade(X::factory(…))`); the rest reads the entity through `Entity`'s selectors.
   `UNIVERSE` is a subclass of `Universe` made with `class_createInstance` that records
   `-removeEntity:` (and the range searches); the RNG is seeded with `ranrot_srand`, as the game seeds
   it (unseeded, `OORandomUnitVector()` never returns); a texture loader is replaced with
   `method_setImplementation` so a test can say "found" or "not found". The cases where an
   initialiser answers nil could not run on the Objective-C classes: `-[Entity dealloc]` of an entity
   whose `-init` never ran crashes since oo-bj8 (bead oo-s6ic6); they ran after the conversion,
   where no façade is made.

**Consequences.** One façade-less class per effect, no deletion bead except the category's
(`OOECMBlastEntity+ObjCBridge`, oo-9ht.75). `ShipEntity.mm` and `Universe.mm` change only at the lines that make
the effects. A failed initialiser no longer reaches `-[Entity dealloc]`, so the crash of oo-s6ic6 is
gone for these classes (the explosion cloud without its texture was a game path).

## Amendment (bead oo-4nhg): a class that implements a protocol another class holds it by, and the C functions that drive it

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Debug/OODebugTCPConsoleClient.h/.mm`
  (`cxx::OODebugTCPConsoleClient`), `OODebugTCPConsoleClient+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OODebugTCPConsoleClient.mm`. Follows amendment oo-kq7 (the Debug module).

**Context.** The TCP console client is the debugger the golden harness drives the game through. The
debug monitor (already `cxx::OODebugMonitor`) holds it as `id<OODebuggerInterface>`, a protocol
that Mac plug-in debuggers also implement, and sends it the protocol's messages with the monitor's
façade as their first argument. The debug support makes it with a failable
`-initWithAddress:port:`. C functions in the same file (the frame loop's
`OODebugTCPConsoleIsWaitingForInput`/`ServiceInput`) and the stream decoder's C callbacks, which
get the client as `void *`, call its private methods. One private method takes `fd_set *`.

**Decision (recommended defaults).**

1. **The façade adopts the protocol; the C++ class has the protocol's members** (first keyword,
   overloads for the shared `debugMonitor:` keyword), taking the converted class where the protocol
   passes its façade (`cxx::OODebugMonitor *`). The façade's forwarders cross with `oo::ToCxx`. The
   protocol stays Objective-C until the debugger interface converts with its other implementers.
   A protocol parameter a member does not use keeps its name as a comment
   (`OODebugMonitor * /*debugMonitor*/`).
2. **A failable public initialiser** is amendment oo-bhb9's: a private `bool initWithX(...)`, body
   verbatim, behind a public static factory named after the class (`clientWithAddress`), which the
   façade's initialiser calls.
3. **C functions in the file that call private members are friends** of the class
   (`friend bool ::OODebugTCPConsoleIsWaitingForInput(void);`, declared before the class);
   **C callbacks that get the object as `void *`** become private static members (amendment oo-44gg
   item 4), so `this` is the callback's info, as `self` was.
4. **A platform type in a private member's signature** (`fd_set`) is forward-declared where the
   platform's header tags it (`struct fd_set;` on Windows) and included where it does not
   (`<sys/select.h>`); the `.mm` still includes the socket headers. A member whose name is a C
   library function (`socket()`) makes the body call the C function as `::socket(...)` (amendment
   oo-novu item 4).
5. **A `-dealloc` message that could never act is not translated** (amendment oo-kq7 item 3): the
   client told its monitor to disconnect it, but the monitor retains its debugger while connected,
   so the client was never released then. A comment stands where it was.
6. **The test plays the other end for real** (a loopback socket) and stands in for the converted
   class the code calls by defining that class's members it uses, in the test
   (`cxx::OODebugMonitor::sharedDebugMonitor()` and four more), plus the `oo::ToCxx` the forwarders
   make, mapping a token object that stands for the monitor's façade. It was written against an
   Objective-C stand-in of the monitor and run on the Objective-C client first; at conversion only
   that stand-in block changed.

**Consequences.** One façade and one deletion bead, which waits for the debug support's conversion
(its only maker) and for the debugger interface's. The goldens are the end-to-end check.

## Amendment (bead oo-y0gz): the rest of the Audio module (the decoder, the sounds, the channels, the mixer, the sources, the pool, the music controller)

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: amendment oo-2en's root, and its
  batch: `src/Core/OOALSoundDecoder.*` (a cluster with a private concrete class),
  `OOALBufferedSound.*`/`OOALStreamedSound.*`/`OOALMusic.*` (subclasses of the root with façades of
  their own), `OOALSoundChannel.*` (a delegate told of `self` from `-dealloc`), `OOALSoundMixer.*`
  and `OOMusicController.*` (singletons), `OOSoundSource.*` (an object that keeps itself alive while
  it plays), `OOSoundSourcePool.*` (overloads told apart by `bool` and `float`), each with
  `X+ObjCBridge.h/.mm` and `tests/unit/core/test_X.mm`. Beads oo-y0gz, oo-2wpb, oo-03g7, oo-nwbw,
  oo-5vp8, oo-6g4z, oo-zoj3, oo-d2y9 and oo-lfkq, one class each, in that order.

**Context.** After the root (`OOSound`, oo-2en) the module has nine classes that all talk to each
other, and every one of them is made or messaged by unconverted code (the resource manager, the
player, the universe, the JS bindings) or stubbed by name in a test that links a converted one
(`test_OOSound.mm` stubs the decoder, the two concrete sounds and the mixer). They convert in nine
beads that must each build on their own, in any order of merging after the root.

**Decision (recommended defaults).**

1. **Every class of the module keeps a façade while anything outside its bead messages it, and
   is `cxx::X`.** No caller file changes, so each bead is the class's files, its bridge, its test
   and the registrations.
2. **Converted code keeps its messages to the module's other classes, written `::X`** (amendment
   oo-rmd7 item 3), whether or not that class has converted, because the tests stub them by name:
   the root's cluster still sends `[[::OOALSoundDecoder alloc] cxx_initWithPath:]` and
   `[[::OOALBufferedSound alloc] initWithDecoder:]`, the mixer `[[::OOSoundChannel alloc] init]`,
   the sources `[::OOSoundMixer sharedMixer]`. The one exception is the root, converted before the
   batch: a class that keeps or plays sounds holds `oo::ObjCRef<::OOSound *>` (amendment oo-smy
   item 4) and calls them through `oo::ToCxx`. Each façade's deletion bead turns the sends to its
   class into C++ calls. A converted class names the others `::X` even before they convert, so the
   nine beads merge in any order.
3. **A converted subclass of the root that its callers make by alloc/init** (the buffered and the
   streamed sound, which the cluster makes; the music, which the resource manager makes) has a
   façade of its own, `@interface X : OOSound` with the old interface and no ivars (amendment
   oo-up4b item 3). Its failable initialiser is a static factory with the initialiser's name
   (amendment oo-novu item 1; the music's hides the root's, amendment oo-2en item 3), and the
   façade's initialiser adopts the result through the root façade's `-initWithNewCxxSound:`, public
   in the category `OOSound (OOObjCBridge)` (as amendment oo-vl43 item 2's material). The root's
   `oo::ToObjC` picks the façade class by the C++ class's name (`cxx::OOMusic` is an `OOMusic`), and
   a global C++ sound is an `OOSound`. The first such bead (oo-2wpb) adds both to the root's bridge.
4. **A cluster whose one concrete class is private to its file** (the Vorbis codec) converts with
   it, in an anonymous namespace (amendment oo-x2wy item 3); its failable `-cxx_initWithPath:` is
   a private `bool initWithPath()` behind a private static `createWithPath()` (amendment oo-fg7i
   item 1). Its `@public` ivar, which the file's C read callback used, is private and the callback
   is a `friend` (amendment oo-bwrq item 3). The façade's `-cxx_description` prints the C++
   class's name without its namespace, so the codec still describes itself as
   `<OOALSoundVorbisCodec 0x…>{…}`.
5. **A `-dealloc` that tells a delegate about `self`** (the channel's `[self hasStopped]`, whose
   delegate may be the source class, which pushes the channel back to the mixer) stays in the
   façade's `-dealloc` (amendment oo-smy item 3), because no peer lookup answers a façade that is
   being deallocated. The C++ member takes the Objective-C channel to report:
   `hasStopped(oo::ToObjC(this))` elsewhere, `hasStopped(self)` from the façade. The C++ destructor
   keeps the rest of `-dealloc` (deleting the OpenAL source).
6. **An object that retains itself while it works** (a playing sound source's `[self retain]`)
   retains its façade, `objc_retain(oo::ToObjC(this))`, and the façade is also what it hands the
   channel as delegate and keeps in the playing set (amendment oo-kdyh item 2). While it plays its
   façade is alive, so `stop()` gets the same one back; the destructor never reaches that branch.
   `[_sound autorelease]` of an Objective-C ivar is `objc_autorelease(_sound.leakRef())`, so the
   old sound still lives until the pool drains.
7. **An ivar that no method read or wrote is not kept** (`OOALStreamedSound`'s `_size`,
   `OOSoundChannel`'s `_playing`, `OOSoundMixer`'s `_maxChannels` and `_playMask`): a private data
   member nothing uses is a `-Wunused-private-field` warning, which the gate forbids silencing. A
   comment in the class says so.
8. **Overloads told apart only by `float` and `bool`** (the pool's `playSoundWithKey:priority:`
   and `playSoundWithKey:overlap:`) are called with arguments of exactly those types: `1.0f` for
   a priority, and a `bool` value for an overlap, because game code sees `OOCocoa.h`'s `true` and
   `false`, which are the integers 1 and 0, and an integer or a double literal is ambiguous. The
   façade casts `BOOL` with `static_cast<bool>`.
9. **A singleton whose failed `-init` left the static pointing at a freed object** (the mixer's
   `[super release]`) leaves it null instead, and the next call asks again (amendment oo-r7m0
   item 2); the old dangling pointer was undefined behaviour, not a behaviour to keep.
10. **A class method whose first keyword an instance method already has** (`+channel:
    didFinishPlayingSound:`, the stopped source's delegate) is a static member named for its role
    (`channelOfStoppedSource`): a static and an instance member cannot overload.
11. **The tests** decode the game's own `Resources/Sounds/boop.ogg` and `Resources/Music/OoliteTheme.ogg`,
    found from the test file's `__FILE__`, so the decoder and the sounds are tested on real data;
    OpenAL runs on the null backend with a scratch `HOMEPATH` (amendment oo-2en item 7). The
    channel test waits, at most two seconds, for a short sound to end. A test that links a class
    stubs the module classes it does not link (amendment oo-z1s4 item 4).

**Consequences.** Nine façades and nine deletion beads. The deletion beads of the decoder, the
concrete sounds, the channel and the mixer also turn the module's own sends to them into C++ calls;
the music's, the source's, the pool's and the controller's wait for the resource manager, the
player, the universe and the JS bindings. No caller file changed.

## Amendment (bead oo-vnts): a file of free functions that makes converted objects, and a selector only an unknown object may answer

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Debug/OODebugSupport.mm`,
  `OODebugSupport+ObjCBridge.h/.mm`, `tests/unit/core/test_OODebugSupport.mm`.

**Context.** `OOInitDebugSupport()` has no class. It makes the TCP console client
(`[[X alloc] initWith…]`, then `autorelease`) and hands it to the monitor, both converted
(amendments oo-kq7, oo-4nhg), and it asks the Mac debug plug-in's controller, an object of no
known class, whether it answers `-setUpDebugger`, a selector declared by a category on `OOObject`
in the file.

**Decision (recommended defaults).**

1. **Converted classes are reached as `cxx::`**: `[[X alloc] initWith…]` plus `autorelease` is
   `oo::ToObjC(cxx::X::factory(...).get())` where the result goes on to Objective-C (here
   `id<OODebuggerInterface>`): the peer table makes the façade, autoreleased, and it owns the
   object; nil for null, as before. Messages to classes that are not converted stay messages,
   their `BOOL` arguments included.
2. **A selector that only an object of unknown class may answer** (a plug-in's) moves, with the
   category that declares it and the `respondsToSelector:` test, to `X+ObjCBridge.mm`, behind C++
   functions declared in `X+ObjCBridge.h` (`OODebugPlugInControllerCanSetUpDebugger`,
   `…SetUpDebugger`), which `X.mm` imports; `X.h` does not change. This is amendment oo-rmd7
   item 1 (Objective-C that exists for the runtime moves to the bridge) for a file with no class.
   Its deletion bead waits for the debugger interface's conversion.
3. **The test stands in for converted classes by defining the members the file calls**
   (amendment oo-4nhg item 6), including the static factory, the destructor and `oo::ToObjC` of a
   class whose private constructor a stand-in factory can still call, being a member.

**Consequences.** One bridge with no façade, and its deletion bead.

## Amendment (bead oo-6ia4): a binding's own helper class, a category on a converted class's façade, and the rest of the batch

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSSystemInfo.h/.mm`,
  `OOJSSystemInfo+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJSSystemInfo.mm`; the same batch
  converted `OOJSPlanet`, `OOJSVisualEffect`, `OOJSShipGroup`, `OOJSManifest` (oo-7ixd, oo-s1wq,
  oo-n64m, oo-7nfv), and `OOJSGlobal` and `OOJSStation` (oo-3dj2, oo-3oxq) if they land.

**Context.** Amendments oo-ppc and oo-ykoy cover a binding whose only Objective-C class is a
category on the game class it wraps. This batch met four other shapes: a helper class private to
the binding (`OOSystemInfo`) that the JS object's private slot holds and the engine messages; a
category on a class that has already converted (`OOShipGroup (OOJavaScriptExtensions)`, which
owns the façade's `_jsSelf`, amendment oo-bwrq item 1); a binding whose natives send a selector
that only the category's `@interface` in the binding header declared (`-subEntitiesForScript` to
an `OOVisualEffectEntity`); and a helper class that nothing makes (`OOManifest`).

**Decision (recommended defaults).**

1. **A binding's own helper class is a `cxx::` class declared in the binding header** (its members
   defined in `X.mm`, where the JS class tables are), **with the default façade** in
   `X+ObjCBridge.h/.mm` imported at the end of `X.h` (amendment oo-kdyh item 3: the engine
   messages it by selector, so it keeps one even with no outside caller). The private slot keeps
   holding the façade, retained (amendment oo-ppc item 5): `oo_jsValueInContext` sets
   `[oo::ToObjC(this) retain]`. A failable initialiser that only the binding sent is a factory with
   its name (amendment oo-novu item 1), and the binding makes the object as
   `oo::ToObjC(cxx::X::initWithY(...).get())`, autoreleased and nil for null, as
   alloc/init/autorelease was. `-isEqual:`/`-hash` follow amendment oo-bhb9 item 4.
2. **The natives reach a converted class as `cxx::`** (amendment oo-ppc item 4, as `OOJSFlasher`
   does for `OOColor`): the object getter still yields the façade, which the native crosses with
   one `oo::ToCxx`, and every use is null-guarded to answer what a message to nil answered (0, the
   zero point, `nullopt`, an empty vector). Where one native has many such uses, file-local helpers
   (`GalaxyOf(info)`, `SystemOf(info)`) carry the guard.
3. **A category on a converted class's façade** becomes free functions (amendment oo-ykoy) that
   take the façade and, where the category read a façade ivar, **that ivar by reference**
   (`OOJSShipGroupJSValueInContext(group, jsSelf, context)`); the forwarders in `X+ObjCBridge.mm`
   pass `_jsSelf`. The ivar stays on the façade while the private slot holds the façade (amendment
   oo-bwrq item 1, oo-ppc item 5); it moves into the C++ class with the façade's deletion, which
   then also deletes `X+ObjCBridge.mm` (the façade's deletion bead depends on the binding bridge's).
4. **A native that sent a category selector whose only declaration moved to the bridge** calls the
   free function that holds the body (`OOJSVisualEffectSubEntitiesForScript(thisEnt)`), with a
   comment; the method stays, for the engine and other senders.
5. **A helper class that nothing makes goes, with a comment where it stood** (amendment oo-kdyh
   item 5): `OOManifest` was never allocated; both Manifest objects are defined with no private
   object, and no other file names the class.
6. **A category `@interface` on another class that a binding declared only to type one send**
   (`OOJavaScriptEngine (OOMonitorSupportInternal)` in `OOJSGlobal.mm`) moves verbatim into
   `X+ObjCBridge.mm` with the one send, as a free function declared in `X.h` (amendment
   oo-9ht.66); it goes when the class it extends declares the method again or converts.
7. **The test stands in for what the converted classes reach**, as their own tests do, and links
   those classes for real (`OOCommodities`, `OOCommodityMarket`, `OOSystemDescriptionManager`,
   `OOShipGroup`, `OOColor`), so that the same file runs on the Objective-C binding (which
   messaged their façades) and on the converted one (which calls their C++ members). The engine's
   native-object conversion in the test asks the object for `-oo_jsValueInContext:`, as the
   engine does, so the category's or class's own JS object is what the script sees.

**Consequences.** Each binding with a helper class adds a façade pair and a deletion bead that
waits for the engine's object wrappers (oo-k4nu, the last `OOJavaScriptEngine.mm` slice);
`OOJSShipGroup+ObjCBridge.mm` goes with the `OOShipGroup` façade (oo-9ht.19). No caller outside
the binding files changed.

## Amendment (bead oo-jy98): a binding whose JS objects hold a converted class's façade

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Debug/OOJSConsole.mm`,
  `OOJSConsole+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJSConsole.mm`. Follows amendments
  oo-ppc (bindings), oo-kq7 (the Debug module) and oo-vnts.

**Context.** The debug console's JS objects (`Console`, `ConsoleSettings`) hold the debug
monitor, which is `cxx::OODebugMonitor` behind a façade whose superclass, `OOWeakRefObject`, is
still Objective-C: the private slot holds the façade's weak reference (`-weakRetain`). The natives
read the slot as `id`, check it with `isKindOfClass:[OODebugMonitor class]`, and message it. The
binding also reads the converted OpenGL extension manager, and asks an entity for `-inspect`,
which only the Mac debug OXP's inspector adds.

**Decision (recommended defaults).**

1. **The private slot keeps the façade's weak reference** (amendment oo-ppc item 5): the console
   object is still made with `[monitor weakRetain]` (the façade's Objective-C superclass, whose
   state the weak reference is), and the natives keep their `isKindOfClass:` checks and error
   text. What they do with the monitor is `oo::ToCxx(monitor)->member(...)`; the local that holds
   the slot's object is typed as the façade (`OODebugMonitor *monitor`) instead of `id`, so the
   crossing's overload resolves. The singleton is `cxx::OODebugMonitor::sharedDebugMonitor()`, and
   `oo::ToObjC(...)` of it where an Objective-C object is wanted (`OOJSValueFromNativeObject`).
2. **An Objective-C-only selector an object of a game class may answer** (`-inspect`) moves with
   its category and `respondsToSelector:` test to `X+ObjCBridge.mm` behind a C++ function
   (`OOJSConsoleInspect(entity)`, in `X+ObjCBridge.h`), as amendment oo-vnts item 2 does. Its
   deletion bead waits for the class's façade deletion.
3. **The test links the real façade of a converted class the binding holds** (here
   `OODebugMonitor+ObjCBridge.mm`, with `OOWeakReference`) over stand-ins of all of that class's
   C++ members, so the same expectations run before and after the conversion: before, the binding
   messages the façade, which forwards to the stand-ins; after, it calls them. A converted class
   the binding only calls (the extension manager) has an Objective-C stand-in before and C++
   member stand-ins after (amendment oo-4nhg item 6); a stand-in of a class with a virtual
   destructor defines that destructor, which carries the vtable.
4. **Natives that compile only in other flavours** (`#if OO_DEBUG`, `#if DEBUG`) are converted too
   and checked with `-fsyntax-only` and those defines from the test flavour's compile command, as
   bead oo-5q8h did for `DEBUG_GRAPHVIZ`. The profiler (`#if OOJS_PROFILE`) does compile in the test
   flavour, so the test links the real `OOJSEngineTimeManagement`.
5. A `static` function whose line the conversion touches (`DoWeDefineAllDebugFlags`, `BOOL` to
   `bool`) moves into an anonymous namespace with its attribute unchanged (amendment oo-q9q4
   item 4).

**Consequences.** One bridge (no façade) and its deletion bead. The binding keeps two kinds of
Objective-C, both on the façade's superclass and slot, until the monitor's façade is deleted:
`-weakRetain` and the class check.

## Amendment (bead oo-whzh): a root façade whose superclass is `OOWeakRefObject`, caches of a hierarchy, and retain tracing

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOTexture.h/.mm`,
  `OOTexture+ObjCBridge.h/.mm`, `tests/unit/core/test_OOTexture.mm`. Follows amendments oo-smy
  and oo-2en (the root of a module, a class cluster's factories).

**Context.** `OOTexture` is the root of the textures (`OOConcreteTexture`, `OONullTexture`,
`OOEnvironmentCubeMap`, Objective-C, in their own files). Its superclass is `OOWeakRefObject`,
which stays Objective-C (amendment oo-3kqi item 5). It keeps three caches: the live textures by
key and every live texture (unretained), and the recent textures (retained, an `OOCache` of
objects). Its subclasses reach the caches from their `-init` and `-dealloc` through
`OOTextureInternal.h`'s categories, and `OOConcreteTexture` reads the root's `@protected` debug
ivar `_trace`, which switches on logging of the Objective-C object's own retains and releases.

**Decision (recommended defaults).**

1. **The root façade keeps its Objective-C superclass** (`@interface OOTexture: OOWeakRefObject`)
   and is otherwise amendment oo-2en's: an adapter (`ObjCTexture`) for an Objective-C subclass
   instance, `oo::ObjCPeers` for a C++ texture's façade. Nothing weakly references a texture, so a
   C++ texture's façade being made again after the old one died changes nothing. A converted
   subclass whose objects are weakly referenced would follow amendment oo-puw9 instead.
2. **Caches keep what they kept, through the crossing.** An unretained cache holds the C++ part
   (`cxx::OOTexture *`; an Objective-C texture's is its adapter, which lives as long as it does).
   A retaining cache holds the Objective-C object, `oo::ToObjC(this)` (amendment oo-smy item 4).
   A lookup that answered the unretained object answers the borrowed C++ pointer (amendment
   oo-6bux item 5). The façade's method answers an Objective-C texture unretained, as before (a
   caller may have no autorelease pool), and a C++ texture's façade through `oo::ToObjC`.
3. **A member that an Objective-C subclass reaches from its `-dealloc`** (`removeFromCaches`) does
   not call `oo::ToObjC(this)`, which would retain and autorelease an object being deallocated. It
   compares a cached object with `oo::ToCxx(object) == this`.
4. **Retain tracing stays in the façade, but not its `-retain`/`-release`/`-autorelease`
   overrides.** `-setTrace:` and the `@protected` ivar the Objective-C subclass reads are about the
   Objective-C object's reference count (amendment oo-3kqi item 3), and stay. The traced overrides
   (debug builds only; nothing calls `-setTrace:`) are dropped: libobjc2 cannot weakly reference an
   object whose class overrides `-retain`/`-release` (its weak store falls back to a raw pointer,
   and the next `objc_loadWeakRetained` crashes), and `oo::ObjCPeers` holds a C++ object's façade
   weakly. A root façade that overrides them for any other reason has the same conflict; the
   default is to drop the override and say so in the bead. The cache code's trace-context
   assignments stay verbatim, now unread.
5. **Categories that an internal header declares on the root** (`OOTextureInternal.h`:
   `SubclassInterface`, `SubclassResponsibilities`, `SubclassOptional`) stay in that header as the
   façade's categories (amendment 1 item 2); the bridge `.mm` implements the one with methods of
   its own. Their methods are public members of the C++ class under an "Internal" comment.
6. **The test** links the whole game (`['*']`) on the GL test context, stands in for the concrete
   textures with Objective-C subclasses, and keeps the resource manager out of reach (a named
   texture is found by its cache key; the generator's `-enqueue` is the test's). `+clearCache`
   autoreleases a C++ cache, so the test clears inside an `oo::AutoreleaseScope`.

**Consequences.** One façade and one deletion bead (`OOTexture+ObjCBridge`), which depends on the
three subclass beads and on the beads of the files that message textures. No caller changed.

## Amendment (bead oo-wue8): entity leaves with a façade under a converted intermediate class, and the rest of the batch

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OOFlashEffectEntity.h/.mm`
  and `OOFlasherEntity.h/.mm` with their `+ObjCBridge.h/.mm` (leaves under `OOLightParticleEntity`),
  `OOWaypointEntity.h/.mm`, `SkyEntity.h/.mm` and `OOExhaustPlumeEntity.h/.mm` with theirs (beads
  oo-bn5j, oo-zsid, oo-sxgm and oo-y86f), and `tests/unit/core/test_X.mm` for each.

**Context.** Amendment oo-0mxi keeps a façade for a leaf that unconverted code makes or messages
by its own selectors. This batch met that for every class: the ships make the flashers and plumes
and message them as subentities, the universe makes the sky and the waypoints and messages them,
and the scripting bindings find them by class. Two of them are leaves of
`OOLightParticleEntity`, which is converted with a façade of its own (amendment oo-0otc); two
headers declared a category of `Entity` that the class overrode (`-isFlasher`, `-isExhaust`); the
waypoint holds other beacons as `Entity <OOBeaconEntity> *`; and the sky's initialiser reassigns
its colour arguments through out-parameters.

**Decision (recommended defaults).**

1. **A leaf under a converted intermediate class with a façade** is `cxx::X : public
   cxx::OOLightParticleEntity`, and its façade is `@interface X : OOLightParticleEntity` (the
   intermediate façade, not `Entity`), with no ivars. `oo::NewEntityFacade`'s chain gains its line
   after the intermediate class's, so the most derived façade wins. The intermediate façade's
   methods for the members the leaf overrides (`-texture`, `-drawSubEntityImmediate:translucent:`)
   already call the virtual member on a C++ object, so the leaf's façade does not repeat them. Its
   `[super m]` is the intermediate class's member, qualified; its reads of the intermediate class's
   ivars lose `oo::ToCxx(self)->` (amendment oo-0otc item 2).
2. **A category of `Entity` that the header declared and the class overrode** moves to
   `X+ObjCBridge.h/.mm` and answers from the C++ part, as amendment oo-2c6g item 1 says; with a
   façade the method is still the category's, not an override on the façade, so it answers the same
   for an entity made either way.
3. **An initialiser the header declared, sent by no caller today** (`-cxx_initWithDictionary:`,
   `-initForShip:withDefinition:andScale:`), stays on the façade as amendment oo-0mxi item 2 makes
   it: the façade makes the C++ part (or keeps it on a second `-init…`) and runs the C++ body; one
   that failed releases the façade and answers nil. The class method callers send is
   `oo::NewEntityFacade(cxx::X::factory(…))` (amendment oo-0mxi item 4), nil where the factory
   answered null.
4. **An Objective-C type with a protocol list** (`Entity <OOBeaconEntity> *`) cannot be written
   after the qualified name `::Entity` inside `namespace cxx`. The header names it once at file
   scope, before the namespace (`typedef Entity <OOBeaconEntity> OOBeaconEntityObject;`), and the
   class's members use the name. The other beacons stay Objective-C objects (amendment oo-bj8
   item 4), held weakly as the façade's `OOWeakReference` (amendment oo-cc8a item 2); the beacon
   icon, another converted class's façade or an Objective-C icon, is `oo::ObjCRef<id <P>>`.
5. **Autoreleased objects a body reassigned** (the sky's colours, which `-readColor1:…` replaced
   through `OOColor **`) are owned by the body: a borrowed parameter the body reassigns is copied
   into a local `oo::Ref<T>` of the old name (`col1In`, then `oo::Ref<OOColor> col1(col1In)`), an
   out-parameter is `oo::Ref<T> *`, and a chained message to a result that could be nil is a
   file-local helper that carries the null guard (`PremultipliedColorWithDescription`, amendment
   oo-6ia4 item 2). `-copy` of an immutable colour is the colour.
6. **The tests** stand in for what the entity reaches as the effect leaves' do (amendment oo-peql
   item 7): `UNIVERSE` a subclass of `Universe` made with `class_createInstance` that records what
   the entity sets, `PLAYER` an entity that answers the viewpoint, the owner ship an entity that
   answers the `ShipEntity` selectors the plume sends, the texture loader replaced with
   `method_setImplementation`, and a private method of an unconverted collaborator replaced the same
   way (`-[OOSkyDrawable setUpStarsWithColor1:color2:]`, which needs the game's star textures),
   so that the sky's colours are observed where they are passed. A value that depends on the RNG
   (the plume's measured size) is pinned with the RNG seeded, as the Objective-C class computed it.

**Consequences.** One façade and deletion bead per class (five), each waiting for the callers that
make and message it; the bindings' category bridges (oo-9ht.48, .49 and .50) move their forwarders
onto the façade before it goes. No caller changed.

## Amendment (bead oo-qa7c): a leaf whose factory makes its façade, and lookups that answered +0

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOConcreteTexture.h/.mm`,
  `OOConcreteTexture+ObjCBridge.h/.mm`, `oo::ObjCPeers::livePeer` (`oofnd/objc/OOObjCPeer.h`),
  `tests/unit/core/test_OOConcreteTexture.mm`. Follows amendment oo-whzh.

**Context.** `OOConcreteTexture` is the textures' working leaf. Its initialisers fail for want of a
loader, and the texture caches itself under its key on the way out, which (amendment oo-whzh item
2) makes its façade before the initialiser returns. It read the root's `@protected` `_trace`, and
it answered a short description of its own. The root's `+cxx_existingTextureForKey:` answered its
texture unretained, and a caller that keeps no autorelease pool (a test, a worker thread) relied on
that. The test also found that an Objective-C texture released by its own initialiser before it
reached `-[OOTexture init]` ran the façade's `-removeFromCaches` with no C++ part.

**Decision (recommended defaults).**

1. **The leaf is `cxx::X : public cxx::Root` with a façade `@interface X : Root` of no ivars**
   (amendment oo-up4b item 3) while code tests for the class (`isKindOfClass:[X class]`). Its
   failable initialisers are static factories (amendment oo-novu item 1); a step of the old body
   that calls a virtual member (`addToCaches`, which reads `cacheKey()`) runs in the factory after
   construction, not in the constructor (amendment oo-vl43 item 2). The façade's initialisers
   release the receiver and answer `[oo::ToObjC(made) retain]`: the factory already made the
   façade the peer table answers, and the receiver would be a second one. The root's factories
   call the leaf's factories, not `alloc`/`init`.
2. **Root state that a converted subclass reads moves into the C++ root** as a `protected` member
   (`_trace`), and the root façade's method for it forwards; the façade's ivar goes when no
   Objective-C subclass reads it any more.
3. **A description the leaf answered on the Objective-C side** (`-cxx_shortDescriptionComponents`)
   becomes a virtual member of the root, which the adapter forwards and the root façade answers
   for a C++ object, as `descriptionComponents()` is (amendment oo-smy item 2).
4. **A façade method that answered an object it did not own answers it +0:** an Objective-C
   object as it is, a C++ object's live façade through `oo::ObjCPeers::livePeer` (no retain, no
   autorelease), and only a C++ object with no live façade gets a new, autoreleased one. Plain
   `oo::ToObjC` would autorelease, which leaks where no pool is.
5. **A root façade method that a subclass's `-dealloc` sends** checks for a C++ part: an
   Objective-C subclass instance released by its own initialiser before it reached the root's
   `-init` has none, and the old method did nothing for it.

**Consequences.** One more façade and deletion bead (`OOConcreteTexture+ObjCBridge`), done with the
root's. `OOObjCPeer.h` gained one member, with its test in `test_objc_peer.mm`.

## Amendment (bead oo-ubjo): the sun and the wormhole (leaves with a façade that many callers message)

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OOSunEntity.h/.mm` and
  `WormholeEntity.h/.mm` with their `+ObjCBridge.h/.mm` (beads oo-ubjo and oo-z55j),
  `tests/unit/core/test_OOSunEntity.mm`, `test_WormholeEntity.mm`. Follows amendment oo-wue8.

**Context.** The sun and the wormholes are made by the universe, the player and the ships with
`alloc`/`-init…`, kept in typed containers (`oo::ObjCRef<WormholeEntity *>`) and messaged by about
fifteen unconverted files, two of them converted classes inside `namespace cxx` that named the
class. The sun's `-init` only asserted; the wormhole's private `-init` was the body both public
initialisers ran first; three getters had their ivars' names; and the wormhole reached the
converted system description manager through the universe.

**Decision (recommended defaults).**

1. **The façade keeps every selector the header declared,** each a one-line forwarder, and its
   initialisers make the C++ part and run the C++ body (amendment oo-0mxi item 2). An Objective-C
   `-init` that only asserted stays in the façade, under the same `#ifndef NDEBUG`.
2. **A private `-init` that the public initialisers sent first** is `void init()` (as
   `DustEntity`'s), which they call first, as they sent `[self init]`.
3. **A converted class inside `namespace cxx` that named the class** names its façade `::X`
   (`CollisionRegion`'s `::OOSunEntity *the_sun`, `OODebugMonitor`'s `oo::ObjCRef<::WormholeEntity *>`),
   as amendment oo-bj8 item 9 says for `Entity`: those are the only caller lines that changed.
4. **A converted collaborator the body reached through the universe** (`[[UNIVERSE systemManager]
   getCoordinatesForSystem:inGalaxy:]`) is crossed once with `oo::ToCxx` in a file-local helper that
   carries the null guard (amendment oo-6ia4 item 2); the universe stays Objective-C. The test makes
   a real C++ manager (its coordinates set and cached) and hands the universe its façade, so the
   same expectations run on the Objective-C class, which messaged the façade, and on the converted
   one, which calls the member.
5. **`descriptionComponents() const`** reads the members its getters read, and calls the
   non-const members it must through one `const_cast` local, as `Entity`'s does.

**Consequences.** Two façades and deletion beads; the scripting bindings' category bridges
(oo-9ht.51 for the sun, the wormhole's own binding oo-ykoy) stay on the façades until they go.

## Amendment (bead oo-nge8): bindings of the player, the mission and the engine's helpers

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSMission.h/.mm`,
  `tests/unit/core/test_OOJSMission.mm`; the same batch converted `OOJSPlayer`,
  `OOJSMissionVariables`, `OOJSOolite`, `OOJSEntity` and `OOJSEquipmentInfo` (oo-5rva, oo-s4ns,
  oo-whvg, oo-tq53, oo-supk) if they land.

**Context.** Amendments oo-ppc and oo-6ia4 cover these bindings, which are `BOOL`s, a few crossings
to converted classes and, for `OOJSEquipmentInfo`, a category on a converted class's façade. The
batch met five smaller questions: a `BOOL *` out-parameter in a binding's C API; an `@try`/`@catch
(OOException *)` in a binding's C function that is not a native; a test that, run on the
Objective-C file first, found a defect; natives that succeed without setting a result; and a
binding whose objects are entities, whose root (`Entity`) is converted but whose subclasses are not.

**Decision (recommended defaults).**

1. **A `BOOL *` out-parameter in a binding's C API stays `BOOL *`** (`JSValueToEquipmentKeyRelaxed`):
   its callers pass the address of a `BOOL` of their own, so changing it would edit callers outside
   the bead. The body's local is `bool`, assigned through the pointer. Return types and by-value
   parameters become `bool` as amendment oo-ppc item 2 says (callers compile unchanged).
2. **`@try`/`@catch (OOException *)` in a binding's C function that is not a native**
   (`MissionRunCallback()`, which squashes and logs an exception from the mission screen's callback)
   **stays verbatim**, as amendment oo-puw9 item 4 keeps it in converted members; Phase 4 replaces it
   with the rest of the Objective-C exception sites. That bead's acceptance greps for
   `@implementation|@interface|@selector|@protocol` only.
3. **A test that finds a defect in the Objective-C file pins the correct behaviour**, and the
   conversion fixes the defect the smallest way with a comment (amendment oo-ppc item 2). Here
   `mission.markedSystems` read the player's destinations through a pointer into a temporary
   `oo::PList` that died at the end of an `if`'s initialiser; the same defect in a landed file
   (`OOJSSystemInfo.mm`) is a bead of its own (oo-f4241). A fault of the façade backend, not of the
   binding, is a bead too (oo-f1yi3: assigning to a mission variable the object already reports
   bypasses the class's setter), and the test leaves that path alone rather than pin it.
4. **A native that succeeds without setting a result** (`setPlayerRole()`,
   `setEscapePodDestination()`) is tested by what it did, not by what the call gives: the backend's
   result slot then holds whatever was there, and nothing in the game reads it.
5. **A binding whose objects are entities messages the Objective-C `Entity`**, the façade every
   entity is while its subclasses are Objective-C (amendment oo-bj8 item 3), as `OOJSSun.mm` and
   `OOJSStation.mm` do; its test stands in for `Entity` and its subclasses by name. The crossing to
   `cxx::Entity` comes with the leaves' conversions, not with the binding's.
6. **Many crossings in one hook** (the 37 EquipmentInfo properties) cross once
   (`cxx::OOEquipmentType *type = oo::ToCxx(eqType)`), and a file-local `Ask(type, &C::member)`
   answers the member's value-initialised result where a message to nil answered zero (amendment
   oo-6ia4 item 2): 0, false, nullopt, a null `oo::PList`, an empty vector or a null `oo::Ref`.

**Consequences.** One bridge with a deletion bead (oo-9ht.102, which oo-9ht.28, the
`OOEquipmentType` façade's deletion, now waits for); two bug beads. `OOJSScript` (oo-u61e), a class
whose superclass is still Objective-C with a category on that superclass, did not fit the sizing
checks in this batch and is left for a bead of its own.

## Amendment (bead oo-dqxj): slice beads, and `+[OOException raise:format:]` in a converted unit

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/OOTextureScaling.mm` (slice 1 of
  `docs/phases/3-slices/OOTextureScaling.md`), `OORaiseException()` in `oofnd/objc/OOException.h/.mm`,
  `tests/unit/core/test_OOTextureScaling.mm`.

**Context.** A slice bead (`sweep:slices`, `tools/gen-stories.py`) converts the units one slice of a
pre-split plan assigns, and its gate is `tools/check-slice-plan.py --slice-done <id> <plan>`. That
check counts *any* message send or `@`-keyword in a unit as Objective-C, not only the four
`@`-keywords of item 8's grep. Converted members have so far kept `[OOException raise:… format:…]`
verbatim (`OOProbabilitySet`, `Octree`), which item 8's grep does not see and the slice check does.
Slice 1 of `OOTextureScaling.mm` is three plain-C dispatch functions whose only Objective-C is that
raise, in an arm no valid pixmap reaches.

**Decision (recommended defaults).**

1. **A raise in a converted unit becomes `OORaiseException(name, format, ...)`,** the function form
   of `+[OOException raise:format:]`: same arguments in the same order, printf format, never
   returns. It throws the same `OOException` object with the same name and reason, so every
   `@catch (OOException *)` and `@catch (id)` that caught the message send catches it unchanged.
   A slice bead must use it (the slice check fails on the message send); a whole-class bead may.
   `[e raise]`, `@throw e` and `@try`/`@catch` are not covered here; they stay as earlier amendments
   say (oo-puw9 item 4), and a slice unit that holds them is reported by its bead.
2. **A slice bead converts only its plan's units.** The plan file is not edited; the slice is done
   when `--slice-done` says so. Its unit test is `tests/unit/core/test_<File>.mm` like a class's,
   added by the file's first slice bead that has observable behaviour to pin, and extended by later
   slices. File-static units are tested through the file's public functions.
3. **Acceptance of a slice bead** is the fast proof (`--slice-done`, the ObjC-syntax grep over any
   file the slice made fully C++, the checks.txt line) plus guardrails; the build, the file's core
   test, Tier A and the goldens run by hand before queueing and nightly from `tests/nightly/checks.txt`.

**Consequences.** One new oofnd function, with no Objective-C type in its signature (its header is
still Objective-C++). Phase 4 replaces it with a C++ exception together with the `@catch` sites.

## Amendment (bead oo-zl36): a root that is a work-manager task, whose state its subclasses read

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOTextureLoader.h/.mm`,
  `OOTextureLoader+ObjCBridge.h/.mm`, `tests/unit/core/test_OOTextureLoader.mm`. Follows amendments
  oo-bj8 (the state), oo-whzh (the adapter) and oo-2en (factories that answer Objective-C objects).

**Context.** `OOTextureLoader` is the root of the texture loaders: `OOPNGTextureLoader`,
`OOPixMapTextureLoader` and `OOTextureGenerator` (with the planet, atmosphere and emission-map
generators under it), Objective-C, in their own files and beads. They write the root's
`@protected` ivars (`_data`, `_width`, `_format`, …) from their `-loadTexture`, on a work thread.
A loader is also a task of the converted work manager, which holds and messages it as an
Objective-C object (`-performAsyncTask`, `-completeAsyncTask`, `waitForTaskToComplete`).

**Decision (recommended defaults).**

1. **The state moves to the C++ root as public members** (amendment oo-bj8 item 1), bit fields
   with `= 0`, and the Objective-C subclasses read and write it through the façade's `@protected`
   `_cxxLoader` (item 2): `_cxxLoader->_width`. The edit is mechanical and touches the subclasses'
   files, whatever bead owns them; a check that no bare name is left proves it. A test subclass's
   lines that read the state are ported the same way (item 11).
2. **The façade keeps the task protocol.** It conforms to `OOAsyncWorkTask` and forwards
   `-performAsyncTask`/`-completeAsyncTask` to the C++ members, whose bodies (`@try`/`@catch`
   included, amendment oo-puw9 item 4) are the old ones; the virtual `loadTexture()` reaches an
   Objective-C subclass's override through the adapter, on the work thread as before. C++ code
   hands the work manager the Objective-C object: `addTask(result.get(), …)` for a loader the
   factory made, `waitForTaskToComplete(oo::ToObjC(this))` from a member.
3. **The designated initialiser `-cxx_initWithPath:options:`** is `bool initWithPath(path,
   options)`, the body after `[super init]`, run by the façade's initialiser on the adapter it
   made; `false` makes the façade release itself and answer nil, as before.
4. **A clang-tidy finding on a line the mechanical edit touched** is fixed with the check's own
   fix, not left: `bugprone-implicit-widening-of-multiplication-result` on
   `malloc(4 * _cxxLoader->_width * _cxxLoader->_height)` widens an operand
   (`4 * static_cast<size_t>(_cxxLoader->_width) * …`); the sizes are a texture's, far from 32-bit
   overflow, so the value is the same.

**Consequences.** One façade and one deletion bead (`OOTextureLoader+ObjCBridge`), which depends on
every loader bead (PNG, pixmap, generator, planet, atmosphere, emission map) and on the textures and
the verifier that call the factories. Five subclass files changed only by item 1 (105 lines).

## Amendment (bead oo-rr2x): an intermediate class whose subclasses initialise through a designated initialiser with arguments

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOTextureGenerator.h/.mm`,
  `OOTextureGenerator+ObjCBridge.h/.mm`, `oo::ObjCTextureLoader<Base>` in
  `OOTextureLoader+ObjCBridge.h`, `tests/unit/core/test_OOTextureGenerator.mm`. Follows amendments
  oo-up4b items 1-2, oo-vl43 items 1 and 4, and oo-zl36.

**Context.** `OOTextureGenerator` sits between the loaders' root and Objective-C classes in other
files (`OOPixMapTextureLoader`, the planet, atmosphere and emission-map generators), which override
the members it adds (`-textureOptions`, `-anisotropy`, `-lodBias`, `-enqueue`) and the root's. They
are made with the root's designated initialiser `-cxx_initWithPath:options:`, not `-init`.

**Decision (recommended defaults).**

1. **The root's adapter becomes the template `oo::ObjCTextureLoader<Base>` with the link
   `oo::ObjCTextureLoaderLink`** in the root's bridge header (amendment oo-up4b item 1); the root
   façade's methods answer an Objective-C loader through the link's `super…()`. The intermediate
   class derives its own adapter from `oo::ObjCTextureLoader<cxx::Mid>` in its bridge `.mm` for
   the members it adds (amendment oo-vl43 item 1); its façade's methods for them call
   `cxx::Mid::m()`, qualified, on an Objective-C subclass instance.
2. **The C++ part is chosen by the designated initialiser.** The root façade gains
   `-cxx_initWithCxxLoader:path:options:` (the old body on a given C++ part), its own
   `-cxx_initWithPath:options:` passes the root's adapter, and the intermediate façade overrides
   `-cxx_initWithPath:options:` to pass its adapter. A subclass's `[super cxx_initWithPath:…]`
   reaches the nearest façade's override, so it gets the right adapter whatever its depth.
3. **A C++ object's façade class walks its C++ bases** to the nearest `cxx::` class with an
   Objective-C class of its name (amendment oo-vl43 item 4), so a global C++ generator is an
   `OOTextureGenerator` to Objective-C, which the texture factory takes.
4. **A converted caller calls the intermediate class's C++ members** (`OOTexture.mm`'s
   `textureWithGenerator`, through `oo::ToCxx(generator)`); the parameter stays the Objective-C
   type while Objective-C callers pass one.

**Consequences.** One more façade and deletion bead (`OOTextureGenerator+ObjCBridge`), done before
the loaders' root bridge's (oo-9ht.114), which depends on it. The root's bridge changed shape
(template adapter, initialiser, base walk) without any caller or test changing.

## Amendment (bead oo-pni4): a class-shell slice, with the class's other slices still Objective-C

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/OXPVerifier/OOPListSchemaVerifier.h/.mm`
  (slice 1 of `docs/phases/3-slices/OOPListSchemaVerifier.md`), `OOPListSchemaVerifier+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOPListSchemaVerifier.mm`.

**Context.** A plan's first slice carries the class shell: every method of the class becomes a
member of `cxx::X`, while the units of the other slices (here the four `Verify_*` functions) stay
Objective-C until their own beads, and they message the class, including its private category.
The private category took a type private to the `.mm` (`BackLinkChain`) by value.

**Decision (recommended defaults).**

1. **The class gets its façade in the shell slice** (item 5): the unconverted units of the other
   slices are outside the bead, like any caller. The façade also keeps the private category those
   units message, declared in `X+ObjCBridge.h` and forwarding like the rest (amendment oo-up4b
   item 4); its members are public on `cxx::X` under an "Internal" comment (Amendment 1 item 2).
2. **A file-private type that the forwarded category takes by value** moves, unchanged, from the
   `.mm` to `X.h`, with a comment saying why. Nothing else of the preamble moves.
3. **The converted core hands `oo::ToObjC(this)` to an unconverted unit** that took `self`
   (`Verify_##T(oo::ToObjC(this), …)`), and to an Objective-C delegate (`[_delegate verifier:oo::ToObjC(this) …]`),
   so both see the façade the caller registered with. `respondsToSelector:@selector(x)` becomes
   `OOSelectorFromName("x")` (amendment oo-puw9 item 5); `@try`/`@catch` stay (oo-puw9 item 4).
4. **An out-parameter the unconverted units pass through stays its type** (`BOOL *outStop`), so they
   compile unchanged; by-value `BOOL` parameters and results become `bool`.
5. **The gate is `--slice-done`.** The plain plan check then reports the converted members as
   verbatim units that contain Objective-C (they fall to `verbatim: *`); that is the checker's
   gap, recorded as oo-9ht.117 for a decision, not a defect of the slice.

**Consequences.** One façade (deletion bead oo-9ht.119, after slice 2 and the caller convert).
Slice 2 converts its four functions with no bridge change, then calls the members directly.

## Amendment (bead oo-3bgz): a class-shell slice whose later slices are a category of the class

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/OOShipRegistry.h/.mm` (slice 1 of
  `docs/phases/3-slices/OOShipRegistry.md`), `OOShipRegistry+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOShipRegistry.mm`. Follows amendments oo-pni4 and oo-r7m0.

**Context.** The later slices of `OOShipRegistry.mm` are not free functions (as in oo-pni4) but the
class's own `OODataLoader` category, about 1,350 lines that read and write the ivars directly. The
singleton's `-init` sends that category's loaders to `self`.

**Decision (recommended defaults).**

1. **A later slice's methods stay an Objective-C category of the façade, in place in `X.mm`,**
   unchanged except that each ivar they touch is `oo::ToCxx(self)->_ivar` (a scripted, word-bounded
   rewrite). The C++ members they need are public under an "Internal" comment (oo-pni4 item 1).
   Their slice bead turns them into members and the rewrite disappears with the category.
2. **A converted member that sent one of those methods to `self`** sends it to `oo::ToObjC(this)`,
   the façade the peer table already holds for it.
3. **An `-init` that sends them** cannot be the constructor (no façade exists until the object is
   owned). It is a private `void init()` that the factory runs right after `oo::makeRef<X>()`
   (`sharedX()` for a singleton, which has set `sSingleton` first, so a re-entrant `sharedX()` answers
   the object being loaded, as the old `+allocWithZone:` did). A log line the singleton boilerplate
   wrote moves to the factory, in the same order.

**Consequences.** No change to any caller or to the category's logic; the façade (deletion bead
oo-9ht.122) waits for slices 2 and 3 as well as for the callers.

## Amendment (bead oo-z889): a leaf that only its root's factory makes, and C callbacks that held it

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOPNGTextureLoader.h/.mm`,
  `loaderWithPath` in `OOTextureLoader.mm`, `tests/unit/core/test_OOPNGTextureLoader.mm`. Follows
  amendments oo-bj8 item 12, oo-vl43 item 4 and oo-zl36.

**Context.** `OOPNGTextureLoader` is a leaf of the texture loaders that no code outside the loaders'
own factory names: `cxx::OOTextureLoader::loaderWithPath` made it with `+alloc`/`-cxx_initWithPath:`
and queued it on the work manager. libpng holds it as a `void *` (the I/O pointer) and calls back
file-static C functions that messaged it.

**Decision (recommended defaults).**

1. **Such a leaf converts with no façade of its own** (amendment oo-bj8 item 12): a global class over
   the C++ root, its private methods private members. The factory makes it (`makeRef` plus
   `initWithPath`) and answers its façade, `oo::ObjCRef(oo::ToObjC(loader))`: the root's façade
   (amendment oo-vl43 item 4), which owns it and which the work manager holds. The factory's
   result type does not change.
2. **A C library's context pointer is `this`,** and its C callbacks `static_cast` it back and call
   members. A callback that libpng can call before the pointer is set (its error and warning
   handlers) checks for null and answers what messaging nil did (`"(null)"` for the path). A
   method that was private but a callback calls is a public member marked "Internal".

**Consequences.** No façade and no deletion bead. The test is written against the factory (the
only way the class was made), so it ran unchanged before and after; one more test pins the C++ API.

## Amendment (bead oo-1v2w): a converted class that is an Objective-C object's delegate

- Date: 2026-09-30. Status: Proposed, as above. Exemplar:
  `src/Core/OXPVerifier/OOCheckShipDataPListVerifierStage.h/.mm`,
  `OOCheckShipDataPListVerifierStage+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOCheckShipDataPListVerifierStage.mm`.

**Context.** The ship data stage is the delegate of an `OOPListSchemaVerifier`, which is still
Objective-C and messages its delegate through an informal protocol (a category on `OOObject`).
A C++ object cannot be that delegate. Both delegate selectors start with `verifier:`, and a member
named `verifier` would hide the base's `verifier()`.

**Decision (recommended defaults).**

1. **The delegate is a helper that stays Objective-C,** as amendment oo-rmd7 item 1 does for a
   formal protocol: `XDelegate`-style class (here `OOCheckShipDataPListVerifierStageSchemaDelegate`)
   in `X+ObjCBridge.h/.mm`, holding a borrowed `X *`. The C++ class makes it where it set itself as
   delegate, keeps it in an `oo::ObjCRef<id>` member (the Objective-C object held its delegate
   unretained), and passes it to `-setDelegate:`. The helper forwards each delegate method in one
   line to a public member of the class, commented with the caller. The bridge's deletion bead
   waits for the delegating class's conversion.
2. **A selector whose first keyword would hide an inherited member** (`verifier:…`) takes its
   distinguishing keyword as well, as amendment oo-fn2f item 5 does for a clash:
   `verifierTestProperty(...)`, `verifierFailedForProperty(...)`. Parameters the body does not use
   are unnamed.
3. **Inside a member of a class derived from `cxx::OOOXPVerifierStage`**, the Objective-C façade
   type in a cast is written `::OOOXPVerifierStage` (amendment 1 item 4).

## Amendment (bead oo-aeev): a category reached only by selector, in a file the build did not compile

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/EntityShaderBindings.mm`,
  `EntityShaderBindings+ObjCBridge.mm`, the members under "The category ShaderBindings" in `Entity.h`,
  `tests/unit/core/test_EntityShaderBindings.mm`.

**Context.** `Entity (ShaderBindings)` is eight getters (the clock, the system's "flavour" numbers
and attributes, all read from `PLAYER`) that the shader uniforms find by selector on any entity;
`shader-uniform-bindings.plist` whitelists them for entities. No header declares the category, and
no `meson.build` listed the file: the game this repository builds never compiled it, so a shader
that bound `clock` or `systemEconomy` got no value. Its test, written against the Objective-C
category, failed for that reason before anything was converted.

**Decision (recommended defaults).**

1. **A source file of the game's that no `meson.build` lists, and that the upstream sources define
   for the runtime to find, is added to the build in its conversion bead**, in the commit that adds
   its test, and the test runs on the Objective-C file first. That is the one behaviour change: the
   whitelisted uniforms now have values. A file that is dead upstream too would be deleted instead,
   with a bead for Jon; this one is not (its selectors are whitelisted).
2. **The category's methods are members of the converted class** (amendment oo-9fwb item 1),
   declared in `Entity.h` under a comment that names the category and defined in the category's
   own file. A member named like a C library function (`clock()`) hides it only inside the class
   and its subclasses, none of which calls the C function.
3. **The category stays, as one-line forwarders in `X+ObjCBridge.mm` with no header** (amendment
   oo-ppc item 3): the uniforms find the methods by selector and read their return types from the
   runtime (`OOShaderUniformTypeFromMethod`), so the forwarders keep the exact return types, and the
   test pins each method's type encoding. The bridge goes with the `Entity` façade's deletion, when
   the uniforms bind C++ members.
4. **The test declares the category itself** (a test-side `@interface`, as amendment oo-ykoy item 4
   does for a binding's category) and sends its selectors to a real `Entity`; `PLAYER` is an entity
   that answers the selectors the category sends.

**Consequences.** One bridge (no façade class) that goes with the `Entity` façade (oo-9ht.39). A
bug bead for Jon records the build-list omission (the default is in effect: the file is built).

## Amendment (bead oo-g223): two categories in one file, on classes the file does not wrap

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Scripting/EntityOOJavaScriptExtensions.h/.mm`,
  `EntityOOJavaScriptExtensions+ObjCBridge.h/.mm`, `tests/unit/core/test_EntityOOJavaScriptExtensions.mm`.

**Context.** `EntityOOJavaScriptExtensions` has no class and no JS class of its own. It holds the
categories `Entity (OOJavaScriptExtensions)` and `ShipEntity (OOJavaScriptExtensions)`, which the
engine sends by selector (`-isVisibleToScripts`, `-getJSClass:andPrototype:`,
`-oo_jsValueInContext:`, `-cxx_oo_jsClassName`, `-deleteJSSelf`) and which the entity subclasses
override, and the scripts' `-subEntitiesForScript` and `-setTargetForScript:`. Its header declares
both categories and `PlayerEntity (OOJavaScriptExtensions)`, whose method `PlayerEntity.mm`
implements, and sixteen files import it to send those selectors.

**Decision (recommended defaults).**

1. **The bodies are free functions** (amendments oo-ppc item 3 and oo-ykoy item 1), declared in
   `X.h`. With two categories in one file the name is the class the category extends plus the
   selector's first keyword, less `cxx_`/`oo_` (`EntityJSValueInContext(entity, context)`,
   `ShipEntityJSSetTargetForScript(ship, target)`); a body that used `self` takes the object, named
   after the class, and its messages to it stay messages, because the subclasses that override
   them are Objective-C.
2. **The categories' `@interface`s move, copied exactly, to `X+ObjCBridge.h`, imported as the last
   line of `X.h`**, not into the bridge `.mm` as amendment oo-ykoy item 2 does: other files send
   these selectors through `X.h`. The `@implementation`s are one-line forwarders in
   `X+ObjCBridge.mm`. The category whose methods another file implements (`PlayerEntity`'s) moves
   with them unchanged.
3. **The test** links the whole game (`['*']`) because the bodies reach the `Entity` façade's C++
   part (`_jsSelf`). A ship is the test's subclass of `ShipEntity` made with `class_createInstance`
   (never initialised, never released) that answers the selectors the category sends; a JS object
   the entity already has is a plain object of a runtime the test makes. Making a new JS object
   needs the engine's shared instance, so that path is left to the goldens.

**Consequences.** One bridge pair and its deletion bead, which waits for `Entity`, `ShipEntity` and
`PlayerEntity` to be C++.

## Amendment (bead oo-mw4u): a subclass of a converted root whose one caller is adapted

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/OOPlanetDrawable.h/.mm`, its caller
  `src/Core/Entities/OOPlanetEntity.h/.mm`, `tests/unit/core/test_OOPlanetDrawable.mm`.

**Context.** `OOPlanetDrawable` derives from `OODrawable`, a converted root with a façade (amendment
oo-smy), and has one caller, `OOPlanetEntity`, which keeps four of them in ivars, copies them for
its miniature and messages them by their own selectors. The drawable keeps a material, swaps it
with `[_material autorelease]`, and is copied with `-copy` (`OOCopying`).

**Decision (recommended defaults).**

1. **No façade** (amendment oo-zffj item 1): the class is global, `OOPlanetDrawable : public
   cxx::OODrawable`, with `override` on the root's virtual members; the caller's ivars are
   `oo::Ref<OOPlanetDrawable>` (`class OOPlanetDrawable;` in its header), its sends are member
   calls, null-guarded where the drawable may be absent (the atmosphere's: a message to nil did
   nothing, and `[nil radius]` was 0), and `DESTROY` is `= nullptr`. Nothing hands the drawable to
   Objective-C, so the root façade's class lookup is not needed.
2. **`-copyWithZone:` that callers reach as `-copy` is `oo::Ref<X> copy()`**: a new object of the
   class (`[[self class] alloc]`, and the class has no subclass) with the copied state.
3. **`-initAsAtmosphere`, sent only by the class's factory, is a static factory of that name**
   (amendment oo-peql item 2); `-init` is the constructor.
4. **The material stays the Objective-C object** (amendment oo-smy item 4), `oo::ObjCRef<OOMaterial *>`,
   and the bodies cross once with `oo::ToCxx`, null-guarded. `[_material autorelease]` before a new
   one is `objc_autorelease(_material.leakRef())` (amendment oo-y0gz item 6); a material it makes
   comes from the C++ factory and is kept as `oo::ToObjC` of it.
5. **The test** makes and reads the drawable through one block of helpers, the only lines the
   conversion ported (they sent messages before and call members after); the universe answers the
   detail setting and a game view of the test's size.

**Consequences.** No façade and no deletion bead. `OOPlanetEntity.h/.mm` changed at the drawable's
lines only; the planet's own conversion (oo-mp0d) keeps them.

## Amendment (bead oo-mp0d): the planet (a leaf with a façade that is a shader binding target)

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/Entities/OOPlanetEntity.h/.mm`,
  `OOPlanetEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_OOPlanetEntity.mm`. Follows amendments
  oo-0mxi and oo-ubjo.

**Context.** The universe and the legacy scripts make planets with `alloc` and two initialisers, a
test sends plain `-init`, and about fifteen files message planets. The planet is also the binding
target of its shader materials (the uniforms read its air colour and terminator by selector), puts
its colours into the planet info as `PList::Object` nodes and reads them back, takes textures from
the texture loader and the generators, and makes a miniature copy of itself with a private
initialiser.

**Decision (recommended defaults).**

1. **The façade overrides `-init`** to make a `cxx::OOPlanetEntity` (or keep the part it has), and
   its initialisers send `[self init]` and run the C++ body, as the Objective-C ones did; without
   the override, `Entity`'s `-init` would make an Objective-C entity's adapter and the forwarders'
   typed `oo::ToCxx` would be wrong.
2. **What Objective-C keeps or binds is the façade:** the shader materials' binding target, the
   graphics reset client and the nearest-ship search's entity are `oo::ToObjC(this)`; the colours
   the planet puts into the planet info are `oo::ToObjC` of the C++ colours, and the colours it
   reads back cross with `oo::ToCxx((::OOColor *)ObjectForKey(...))` (the node holds `id`,
   amendment oo-vl43 item 6).
3. **Textures stay the Objective-C objects** the loader and the generators answer through their
   out-parameters (`::OOTexture *`); the test replaces the loader's class method, so the body keeps
   that message (amendment oo-rmd7 item 3), and calls the converted texture through `oo::ToCxx`.
   Materials are made with the C++ factories and handed to the drawables as their façades.
4. **A private initialiser that the class's own method sends to a new object**
   (`-initAsMiniatureVersionOfPlanet:` from `-miniatureVersion`) is a private `bool` member, and
   the method is a factory over it (amendment oo-novu); the façade's method answers
   `oo::NewEntityFacade` of its result.
5. **An out-parameter a message to nil left unwritten** (`-airColorAsVector` of a planet with no
   air colour, which returned whatever the stack held) is zero-initialised (the decision, item 4).

**Consequences.** One façade and its deletion bead; the planet binding's category bridge
(oo-9ht.92) stays on the façade until it goes.

## Amendment (bead oo-kvqq): a generator leaf that one Objective-C caller makes, with an initialiser that fails

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOPixMapTextureLoader.h/.mm`,
  its two callers in `src/Core/Entities/PlanetEntity.mm`, `tests/unit/core/test_OOPixMapTextureLoader.mm`.
  Follows amendments oo-bj8 item 12, oo-2c6g item 2, oo-novu, oo-rr2x item 3 and oo-z889.

**Context.** `OOPixMapTextureLoader` is a leaf under the converted `cxx::OOTextureGenerator`. Its one
caller (`PlanetEntity`, still Objective-C) made it with `alloc`/`-initWithPixMap:textureOptions:freeWhenDone:`
and handed it to `+[OOTexture textureWithGenerator:]`; no test stubs it, and nothing else names it.
Its initialiser answered nil for a pixmap that is not valid (`DESTROY(self)`).

**Decision (recommended defaults).**

1. **It converts with no façade of its own** (amendment oo-bj8 item 12): a global class over
   `cxx::OOTextureGenerator`, with `override` on the members it overrode. The initialiser is a
   `bool` member and a static factory (`loaderWithPixMap`) answers null where it answered nil
   (amendment oo-novu); the destructor frees the pixmap, as `DESTROY(self)`'s `-dealloc` did.
2. **The caller calls the factory and hands on `oo::ToObjC(loader.get())`** (amendment oo-2c6g
   item 2): the generator façade (amendment oo-rr2x item 3), which owns the loader, autoreleased,
   as `[loader autorelease]` was. The typed overload for `cxx::OOTextureGenerator *` is the best
   match for a derived pointer, so no cast is written.
3. **A quirk of the old initialiser is kept** (it duplicated its own empty pixmap instead of the
   one it was given when `freeWhenDone` was NO, so it answered nil); the test pins it.
4. **The transitional comments that list the loaders still Objective-C** (in the roots' headers
   and bridges) are left to the bridges' deletion beads, so the sibling beads do not conflict.

**Consequences.** No façade and no deletion bead. The test's maker helper is the only line it
ported; one more test pins the C++ API.

## Amendment (bead oo-604l): a hierarchy root whose subclasses are an Objective-C class and an oo-o89 façade, and class methods that make subclass instances

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOScript.h/.mm`,
  `OOScript+ObjCBridge.h/.mm`, `tests/unit/core/test_OOScript.mm`.

**Context.** `OOScript` is the abstract root of the scripts. One subclass, `OOJSScript`, is still
Objective-C; the other, `OOPListScript`, converted first (amendment oo-q9q4), so its façade
subclasses the Objective-C root and owns its own C++ part in an ivar named `_cxxScript`. The root's
class methods load scripts and answer the subclasses' Objective-C objects; converted callers in
`namespace cxx` (`OOCommodities`, `OOCharacter`, `OOEquipmentType`) name the Objective-C class.

**Decision (recommended defaults).**

1. **The root converts as amendment oo-6bux says**: a private adapter (`ObjCScript`) is the C++
   part of every Objective-C subclass instance, including an oo-o89 façade, whose own C++ part is
   unrelated to the root's. Neither subclass changes. The methods subclasses override, including
   `-cxx_descriptionComponents` (which `OOJSScript` overrides and calls `super` on), are virtual.
2. **The root façade's ivar is named so it cannot clash with a subclass façade's** (`_cxxRootScript`,
   not `_cxxScript`), and the bridge header says why.
3. **Class methods that make subclass instances are static members that still message the
   subclasses' Objective-C classes** (`[OOJSScript scriptWithPath:…]`, and
   `[::OOPListScript scriptsInPListFile:…]` where a `cxx::` class of that name exists), answering
   `oo::ObjCRef<::X *>` (or `id`) as before; `[self m…]` on the class becomes a static call. They
   become C++ factories when the subclasses convert.
4. **Converted callers in `namespace cxx` that named the root's Objective-C class write `::X`**
   (amendment oo-q9q4 item 5), in the same bead, because `X` now names the C++ root there.

**Consequences.** One façade with a deletion bead that waits for `OOJSScript`'s conversion
(oo-u61e.4) and `OOPListScript`'s façade deletion (oo-9ht.57). Converting `OOJSScript` now makes it
a plain C++ subclass of `cxx::OOScript` instead of an oo-o89 façade.

## Amendment (bead oo-kyje): a generator with private helper generators in its file, and overloads that would collide

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOPlanetTextureGenerator.h/.mm`,
  its caller in `src/Core/Entities/OOPlanetEntity.mm`, `tests/unit/core/test_OOPlanetTextureGenerator.mm`.
  Follows amendments oo-fn2f, oo-kvqq and oo-y3dd.

**Context.** `OOPlanetTextureGenerator` makes, besides its own texture, a normal map and an atmosphere
through two Objective-C generators private to its file (`OOPlanetNormalMapGenerator`,
`OOPlanetAtmosphereGenerator`), which it holds and which the atmosphere's generator holds back (a
retain cycle). Its class methods include `+generatePlanetTexture:andAtmosphere:withInfo:seed:` and
`+generatePlanetTexture:secondaryTexture:withInfo:seed:`, whose arguments have the same types.

**Decision (recommended defaults).**

1. **The private helpers convert with the class, as global C++ classes defined in its `.mm`**
   (amendment oo-fn2f), forward-declared in its header for its `oo::Ref` members, which hold them;
   the cycle is kept as it was. Not in an anonymous namespace: their descriptions name the class.
2. **Two class methods whose converted signatures would be the same get different names**: the
   later-declared one that took an atmosphere is `generatePlanetTextureAndAtmosphere`. The others
   are overloads of `generatePlanetTexture`.
3. **`[super enqueue]` from a helper is the base's member, qualified** (`cxx::OOTextureGenerator::enqueue()`),
   and a real override of the root's `getResult` keeps `override`.

**Consequences.** No façade and no deletion bead; amendment oo-y3dd's out-parameters and its
non-overriding `getResultFormatWidthHeight` apply here too.

## Amendment (bead oo-y3dd): class methods that wrote Objective-C objects through pointers, and a method that only looked like an override

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOStandaloneAtmosphereGenerator.h/.mm`,
  its caller in `src/Core/Entities/OOPlanetEntity.mm`, `tests/unit/core/test_OOStandaloneAtmosphereGenerator.mm`.
  Follows amendments oo-bj8 item 12, oo-2en item 2, oo-novu and oo-kvqq.

**Context.** `OOStandaloneAtmosphereGenerator` is a leaf under `cxx::OOTextureGenerator` that no test
stubs; its one caller (`OOPlanetEntity`, Objective-C) sends it a class method,
`+generateAtmosphereTexture:withInfo:seed:`, which wrote an autoreleased `OOTexture *` through an
`OOTexture **`. It also declared `-getResult:format:width:height:`, whose keywords differ from the
root's `-getResult:format:originalWidth:originalHeight:`: it never overrode it, and nothing sends it.

**Decision (recommended defaults).**

1. **No façade** (amendment oo-kvqq): a global class, its initialiser a `bool` member behind a static
   factory, and its class methods static members.
2. **An `X **` out-parameter that received an autoreleased object becomes `oo::ObjCRef<X *> *`**,
   and a class method that answered one answers `oo::ObjCRef<X *>` (amendment oo-2en item 2). The
   caller declares the `ObjCRef` where its old local lived and reads `.get()` into that local, so
   the object lives at least as long as the local is used.
3. **A method whose selector only resembled an inherited one keeps a name that does not override
   it** (`getResultFormatWidthHeight`), with a comment; converting it to the inherited name would
   make it an override and change what runs.
4. **`oo::DescriptionOf(self)` in a log is `oo::DescriptionOf(oo::ToObjC(this))`** (amendment oo-n99o
   item 4): the facade the work manager already holds, so the text is the same.

**Consequences.** No façade and no deletion bead. The test's helpers that made the generator and sent
the class methods are the lines it ported.

## Amendment (bead oo-e6xa): a generator leaf whose caller's test stubs it by name, and colours it holds

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OOCombinedEmissionMapGenerator.h/.mm`,
  `OOCombinedEmissionMapGenerator+ObjCBridge.h/.mm`, `tests/unit/core/test_OOCombinedEmissionMapGenerator.mm`.
  Follows amendments oo-qa7c, oo-rmd7 item 3, oo-n99o item 3, oo-novu and oo-rr2x.

**Context.** `OOCombinedEmissionMapGenerator` is a leaf under the converted `cxx::OOTextureGenerator`.
Its one caller, the converted `cxx::OOMultiTextureMaterial`, makes it with `alloc` and one of two
initialisers, and that caller's test (`test_OOMultiTextureMaterial.mm`) stubs the class by name to
record which initialiser was sent. It holds the diffuse map (an `OOTexture`) and two `OOColor`s.

**Decision (recommended defaults).**

1. **It is `cxx::OOCombinedEmissionMapGenerator` with a façade of its own** (amendment oo-qa7c):
   `@interface OOCombinedEmissionMapGenerator : OOTextureGenerator`, no ivars, the two old
   initialisers, each making the C++ object with its factory, releasing the receiver and answering
   the C++ object's façade (`nil` where the factory answers null). The caller keeps its messages,
   written `::OOCombinedEmissionMapGenerator` inside `namespace cxx` (amendments oo-rmd7 item 3,
   oo-n99o item 3), so its test's stub is still what it makes. The façade's deletion bead turns the
   messages into the factories; the caller's test then links the real class instead of its stub,
   a test change that bead must have approved (ADR-0049).
2. **The two public initialisers are two static factories; the shared private designated
   initialiser is a `bool` member** (amendments oo-novu, oo-n99o item 1).
3. **A colour it keeps is `oo::Ref<cxx::OOColor>`** and its arguments are `cxx::OOColor *` (the
   façade passes `oo::ToCxx(colour)`); a message to a nil colour is a null check (`-isWhite` of nil
   was NO). **A texture it keeps is `oo::ObjCRef<::OOTexture *>`** (amendment oo-smy item 4), read
   through `oo::ToCxx(texture)`, with a null check where nil answered nil. A loader it makes with
   the root's factory is held as the factory answers it (`oo::ObjCRef<::OOTextureLoader *>`) for
   the scope that used it.

**Consequences.** One façade (`OOCombinedEmissionMapGenerator+ObjCBridge`) and its deletion bead.

## Amendment (bead oo-bm1q): a class private to its file, and stages dispatched by selector

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OODefaultShaderSynthesizer.h/.mm`
  (slice 1 of `docs/phases/3-slices/OODefaultShaderSynthesizer.md`), `OODefaultShaderSynthesizer+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OODefaultShaderSynthesizer.mm`.

**Context.** `OODefaultShaderSynthesizer` was declared and defined only in its `.mm`; its one caller
is the file's own entry point `OOSynthesizeMaterialShader()`. Item 5's last rule would give it no
façade, but its shader stages (slice 2) stay Objective-C until their bead, and a façade
`@implementation OODefaultShaderSynthesizer` in the `.mm` would be read by `--slice-done 1` as the
plan's `@OODefaultShaderSynthesizer` block still being Objective-C. The stages are dispatched by
selector through a macro (`REQUIRE_STAGE`, `-performStage:` with `-performSelector:`), and
`-dealloc` sent a stage-slice method.

**Decision (recommended defaults).**

1. **A class private to its file gets the house-style files in its shell slice** when later
   slices stay Objective-C: `cxx::X` is declared in `X.h` (the class is no longer private; the
   header's includers do not use it), and the façade in `X+ObjCBridge.h/.mm` as amendment oo-pni4
   says. The later slices' methods are a category on the façade in `X.mm`, declared in the bridge
   header. A method the stages sent without a declaration (it was defined above them) is declared
   in an `OOPrivate` category there. The façade and its deletion bead go when the last slice lands.
2. **A dispatch macro has two forms while its targets are Objective-C:** the old name for the
   category methods (`self` is the façade, the flags are `oo::ToCxx(self)->…`) and a `_CXX_` form for
   the members (`[oo::ToObjC(this) NAME]`, or `performStage(…)` in a debug build). Both name the
   selector with `OOSelectorFromName(#NAME)`, so a recursion check keyed by `SEL` sees one pointer
   per stage from either side (a literal `@selector` need not equal it, `OORuntime.h`). The stage
   slice makes the stages members and keeps one form.
3. **A `-dealloc` that only sent a later-slice method which empties members** has no destructor
   body: the implicit destructor destroys them, and a destructor must not make a façade.
4. **An `@autoreleasepool` in a converted function** becomes `objc_autoreleasePoolPush()` /
   `objc_autoreleasePoolPop()` (`<objc/objc-arc.h>`, as `OOMesh.mm` does), while the Objective-C
   code it calls still autoreleases (here the façade the stages are run on).

**Consequences.** One façade and deletion bead for a class nothing outside its file names; slice 2
deletes the `REQUIRE_STAGE` Objective-C form, the Stages category and, with the façade, its
bridge files.

## Amendment (bead oo-4jjl): a drawable with no façade that is a graphics reset client, and a test seam for a private step

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/OOSkyDrawable.h/.mm`, its caller
  `src/Core/Entities/SkyEntity.mm`, `src/Core/OOGraphicsResetManager.h/.mm`,
  `tests/unit/core/test_OOSkyDrawable.mm`, `tests/unit/core/test_SkyEntity.mm`.

**Context.** `OOSkyDrawable` derives from the converted root `OODrawable` and has one caller,
`SkyEntity` (already C++), so it converts with no façade (amendments oo-zffj item 1 and oo-mw4u).
It registered itself with `OOGraphicsResetManager` as an `<OOGraphicsResetClient>`, which takes
only an Objective-C `id`; and `test_SkyEntity` replaced its private star set-up (which needs the
game's star textures) with `method_setImplementation`, which has nothing to hook once the class
is C++.

**Decision (recommended defaults).**

1. **The first C++ graphics reset client adds the C++ client interface** that amendment oo-jpd8
   item 3 foresaw: `cxx::OOGraphicsResetClient` (the protocol's `-resetGraphicsState` as a pure
   virtual) in `OOGraphicsResetManager.h`, and `registerCxxClient()`/`unregisterCxxClient()`
   (distinct names, so `registerClient(nil)` stays unambiguous). The manager tells its C++
   clients after its Objective-C ones, from a snapshot, with the same exception handling. The
   client derives from the interface as well as its root and registers `this` in its constructor
   and unregisters in its destructor, as `-init`/`-dealloc` did.
2. **The entity holds the drawable's root façade.** `OOEntityWithDrawable` keeps an Objective-C
   `OODrawable *`, so the caller makes the C++ drawable with `oo::makeRef` and passes
   `oo::ToObjC(drawable.get())`; the façade keeps the C++ object alive.
3. **A test that replaced a private Objective-C method gets a static stand-in hook**, declared
   private in the class and set only through its `friend struct XTestAccess` (amendment oo-zffj
   item 3): the member checks the hook first and returns after calling it, as the replaced
   method did. In the game the hook is null. Porting an existing test's stand-in to it is a test
   edit (CLAUDE.md rule 2): it needs Jon's decision (here oo-jsx0h), with every expectation kept.
4. **A file-private helper class** (`OOSkyQuadSet`) converts in the same bead, global, no façade
   (amendment oo-vt0o item 2); its failable initialiser is a static returning null (amendment
   oo-novu). A malloc()ed array of structs that held autoreleased colours becomes a
   `std::vector` of structs holding `oo::Ref`, since a C++ colour must be owned.
5. **An argument expression with a side effect in a message to a possibly-nil receiver is
   evaluated first** (`const float fraction = randf();`), so the random stream is the same when
   the receiver is null-guarded.

## Amendment (bead oo-9ht.139): a slice's free function that messages a class it does not wait for

- Date: 2026-10-05. Status: Proposed, as above (recommended default, CLAUDE.md rule 10). Plans:
  `docs/phases/3-slices/OOJSShip.md`, `docs/phases/3-slices/HeadUpDisplay.md`. Follows amendments
  oo-ppc items 4-5, oo-6ia4 items 2 and 6, oo-vnts item 2, oo-jy98 item 2 and oo-dqxj.

**Context.** A slice story is done when `tools/check-slice-plan.py --slice-done` finds no
Objective-C in its units. A converted method is an out-of-line C++ member, and a member may keep
messages to classes that are still Objective-C (amendment oo-ppc item 4; the checker exempts it,
oo-9ht.117). A *free function* gets no such exemption: any message send in it fails the check.
That is every native of a binding file (`OOJSShip`, `OOJSSystem`, `OOJSPlayerShip`) and the
file-scope drawing helpers of a class (`hudDrawReticleOnTarget()` in `HeadUpDisplay.mm`). Their
sends go to three kinds of class: converted ones (`OOColor`, `OOShipGroup`, `Entity`); the class
the file is about (`ShipEntity` for `OOJSShip`), which the slices can wait for; and classes that
convert only after the file, because their own conversion waits for it (`Universe`, oo-pas,
depends on every binding bead) or is far off (`PlayerEntity`, oo-a70). Waiting for the last kind
is a dependency cycle or a stall, and a slice cannot be done while it sends to them.

**Decision (recommended defaults).**

1. **A converted class is reached as `cxx::`** through `oo::ToCxx`/`oo::ToObjC`, nil-guarded
   (amendment oo-6ia4 item 2).
2. **The class the file is about is waited for.** The slice beads depend on that class's
   conversion (for `OOJSShip`: `ShipEntity`, oo-k8a, then the `ShipEntity` slices that own the
   members a slice calls once its plan files them), and the sends become member calls.
3. **Any other send to a class that is still Objective-C when the slice is worked** moves behind a
   one-line C++ function in `X+ObjCBridge.mm`, declared in `X+ObjCBridge.h` and imported by
   `X.mm` (the shape of amendments oo-vnts item 2, oo-jy98 item 2 and oo-6ia4 item 6). One function
   per distinct send, named after the file and the selector (amendment oo-ykoy item 1):
   `OOJSShipUniverseSun()`, `OOJSShipPlayerAlertCondition()`; a send to an object passes it first.
   The body is the send, verbatim, with `BOOL` results returned as `bool`. A class file that already
   has a façade bridge (`HeadUpDisplay+ObjCBridge.mm`) puts them there.
4. **The bridge's deletion bead** ("Delete X+ObjCBridge", `sweep:objc-bridge`) depends on the
   conversion beads of the classes its functions message; each of those beads turns the callers
   into direct `cxx::` calls and deletes its functions.
5. **This applies to slice stories filed before it** (`OOJSSystem` oo-luhd and slice 2,
   `OOJSPlayerShip` oo-ft5n and slices 2-3): their natives' `[UNIVERSE …]` / `[PLAYER …]` sends
   take item 3; their beads are not changed.

**Consequences.** A binding gets a bridge of free functions (no façade) and a deletion bead that
waits for `Universe` and `PlayerEntity`. Behaviour is unchanged: the same message is sent, from one
more call frame. `--slice-done` stays as strict as it is.

## Amendment (bead oo-2g51): a class-shell slice whose later slices are methods of the class's own `@interface`

- Date: 2026-10-05. Status: Proposed, as above (recommended default, CLAUDE.md rule 10). Exemplar:
  `src/Core/GuiDisplayGen.h/.mm` (slice 1 of `docs/phases/3-slices/GuiDisplayGen.md`),
  `GuiDisplayGen+ObjCBridge.h/.mm`, `tests/unit/core/test_GuiDisplayGen.mm`; also
  `src/Core/ResourceManager.*` (bead oo-jfno). Follows amendments oo-pni4 and oo-3bgz.

**Context.** In `OOShipRegistry` (oo-3bgz) the later slices were already a category with its own
`@interface`. In `GuiDisplayGen` and `ResourceManager` they are methods of the class itself,
declared in its one `@interface` and defined in its one `@implementation`, interleaved with the
shell slice's methods. `GuiDisplayGen`'s later slices also retain and autorelease two ivars
(`backgroundSprite`, `foregroundSprite`) and read three that the shell slice sets with
retain/release (`textColor`, `textCommsColor`, `backgroundColor`). `ResourceManager` is class
methods over file-scope state and is never made.

**Decision (recommended defaults).**

1. **The façade header declares the later slices' selectors in a named category,**
   `X (OOXUnconverted)`, copied exactly from the old `@interface`, and `X.mm` implements them as
   `@implementation X (OOXUnconverted)`; the façade's own `@interface` keeps only the shell slice's
   selectors, each forwarded by `X+ObjCBridge.mm`. (Amendment oo-bwjb item 1, written in parallel,
   says the same with the name `XSlices`; either name is the category's, and the slice beads empty
   it.) A shell-slice method that sat among the later
   ones (`-rowAtVirtualJoystickPosition:`) moves, verbatim, into the C++ block. Each later slice's
   bead moves its methods from the category to the class and adds their forwarders.
2. **An Objective-C object ivar whose retains the later slices make** (`[backgroundSprite
   autorelease]; backgroundSprite = New…()`) stays a raw `+1` pointer member, released by the
   destructor (the old `-dealloc` body), so the category's code needs only the oo-3bgz rewrite; it
   becomes an `oo::ObjCRef` in the slice that converts those methods. An object ivar whose
   memory management is all in the shell slice is an `oo::ObjCRef` (amendment oo-862e item 4), and
   the category reads it as `oo::ToCxx(self)->x.get()`. `GuiDisplayGen`'s colours stay façades
   (`oo::ObjCRef<::OOColor *>`), unlike the HUD's (amendment oo-engam item 4), because the rows
   already hold façades (`rowColor`, a Phase 2 type that stays) and every caller passes and reads
   `OOColor *`; a later slice or the deletion bead may move all of them to `oo::Ref<cxx::OOColor>` at
   once.
3. **A getter named like its ivar** follows amendment oo-862e (`getTitle()`, `getSelectedRow()`,
   `getTextColor()`, `getDrawPosition()`, `getSelectableRange()`), so the bodies, and the
   category's rewritten ivar reads, stay verbatim.
4. **A class of class methods only** (`ResourceManager`) is `cxx::X` with static members and a
   deleted constructor, and no `oo::ToObjC`/`oo::ToCxx` (nothing crosses). Its file-scope state stays
   file-scope, so the later slices' category needs no rewrite; a shell member that sends one of
   their methods sends it to the façade class, `[::X …]`. A converted collaborator (`OOCacheManager`)
   is called as C++ (`OOCacheManager::sharedCache()->…`) inside the members.
5. **A unit test that selects a row** (`-setSelectedRow:` reports it with `OOJSID(…)`) starts the
   JavaScript engine once in a scratch home and game folder, as `test_OOJSScript` does; `PLAYER` stays
   nil, so nothing is sent.

**Consequences.** Two façades with deletion beads that wait for the later slices as well as for the
callers. The category's ivar reads cost one `oo::ToCxx` call each until their slice converts.

## Amendment (bead oo-6dvw): a later slice that owns sprites of a converted class, and its file-scope helpers

- Date: 2026-10-05. Status: Proposed, as above (recommended default). Exemplar: `src/Core/GuiDisplayGen.h/.mm`
  (slice 2 of `docs/phases/3-slices/GuiDisplayGen.md`). Follows amendments oo-2g51 and oo-9ht.139.

**Decision (recommended defaults).**

1. **The raw `+1` sprite ivars of amendment oo-2g51 item 2 become `oo::Ref<cxx::OOTextureSprite>`** in
   the slice that converts their `-autorelease`/replace code, because `OOTextureSprite` is C++: the
   factory is `cxx::OOTextureSprite::initWithTexture(texture, size)` (null where the façade's
   initialiser answered nil), the destructor's releases go, and the assignment releases the old
   sprite at once rather than at the pool's drain (amendment oo-862e item 4). The later slices'
   category still reads them through `oo::ToCxx(self)`; its two blits become member calls
   (`->blitCentredToX(x, y, z, a)`), the only lines of the category that change beyond the rewrite.
2. **A file-scope helper of the slice that messaged the universe** (`TextureForGUITexture`'s
   `[UNIVERSE useShaders]`) calls a one-line bridge function in `X+ObjCBridge.mm`
   (`GuiDisplayGenUniverseUseShaders()`, amendment oo-9ht.139 item 3); its message to a converted
   class becomes the C++ call (`cxx::OOTexture::textureWithName`, `oo::ToCxx(texture)->originalDimensions()`),
   and a result it handed out autoreleased is returned as `oo::ObjCRef`.
## Amendment (bead oo-bwjb): a class-shell slice whose later slices hold public methods, and a filter called through its selector

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/OOOXZManager.h/.mm` (slice 1 of
  `docs/phases/3-slices/OOOXZManager.md`), `OOOXZManager+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOOXZManager.mm`.

**Context.** `OOOXZManager` is a singleton (amendment oo-r7m0) whose slice plan gives slice 1 the
class shell, the paths, the filters, the manifests and the download plumbing, and slices 2 to 4
the installing, the GUI page and the option pages. Unlike `OOPListSchemaVerifier` (amendment
oo-pni4), whose later slice was free functions, here the later slices are methods, and eleven of
them are public: the old `@interface` declares `-gui`, `-processSelection`, `-showInstallOptions`
and the rest, which `PlayerEntity` and `PlayerEntityControls` send. Kept in the façade's
`@interface` and implemented by a category in `X.mm`, they would leave the façade's own
`@implementation` (in `X+ObjCBridge.mm`) incomplete, which `-Wincomplete-implementation` reports.
The slice also calls its filters through `-methodForSelector:` with a selector chosen from the
filter text.

**Decision (recommended defaults).**

1. **The old `@interface` is split in `X+ObjCBridge.h`, unchanged otherwise:** the façade's
   `@interface` keeps the shell slice's selectors (each forwarded in one line), and a category
   right after it (`@interface X (XSlices)`) declares, verbatim and in their old order, the public
   selectors of the later slices. `X.mm` implements that category: the later slices' methods, in
   place, become `@implementation X (XSlices)` (one block when they are contiguous). Callers see
   the same selectors with the same types, and both `@implementation`s are complete.
2. **The private category is split the same way:** the later slices' private selectors stay
   declared in `X.mm` (`@interface X (OOPrivate)`, implemented by the `XSlices` category); the shell
   slice's private selectors that the later slices still send are declared in the bridge header
   by a category of their own (`(OOPrivateForwarded)`) and forwarded by the bridge; the rest are
   C++ members only. The shell's members are public under an "Internal" comment while any later
   slice reads them (amendment oo-pni4 item 1), except state that no later slice touches.
3. **A converted unit that sends a later slice's selector sends it to `oo::ToObjC(this)`**
   (`[oo::ToObjC(this) gui]`); for a singleton that is the façade `+sharedX` keeps, so the later
   slice sees the object its callers message.
4. **A method called through a selector chosen at run time becomes a pointer to a member
   function** chosen the same way (item 4's "explicit table of its candidates", for a closed set
   of the class's own methods): the selectors' one- and two-argument IMP typedefs become
   `bool (X::*)(...)` typedefs, and the arity test that compared selectors becomes "which pointer
   is set". An unused parameter of such a member keeps its type and loses its name.
5. **The unit test reaches the private API before the conversion through a test-only category**
   that declares the private selectors it calls, behind one helper function each; the port
   replaces the helpers' bodies with the C++ members and leaves the expectations alone.

**Consequences.** The shell's façade has three categories in flight (the later slices, the
forwarded private units, the bridge's own initialiser), each deleted by the slice that empties it;
the deletion bead deletes what is left. Slices 2 to 4 convert their methods into `cxx::X` members
and delete their declarations from `XSlices` and `OOPrivate`, and the forwards from
`OOPrivateForwarded` that no longer have a sender.

## Amendment (bead oo-u61e.4): a subclass of a converted root whose façade is the object's identity

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSScript.h/.mm`,
  `OOJSScript+ObjCBridge.h/.mm`, `tests/unit/core/test_OOJSScript.mm`.

**Context.** `OOJSScript` converts after its root (`OOScript`, amendment oo-604l), so it is a plain
C++ subclass. But the Objective-C object is what everything holds: its JS object's private slot
holds a weak reference to it, the stack of running scripts holds it, timers and definitions keep
weak references to it, and `-initWithPath:properties:` hands it to all of these while it runs.
Converted callers inside `namespace cxx` named the Objective-C class unqualified.

**Decision (recommended defaults).**

1. **`cxx::X : public cxx::Root`, and the façade `@interface X : Root` has no ivars** (amendment
   oo-up4b item 3); the root façade's ivar holds the C++ object. The root's forwarders for the
   virtual members reach `X`'s overrides, so the façade does not repeat them.
2. **The façade is the identity, as amendment oo-3kqi's is: it makes and owns its C++ object.** The
   root façade gets a public initialiser in its `OOObjCBridge` category (`-initWithCxxRootScript:`)
   that stores the object and records the façade as its peer; the subclass façade's initialiser
   calls it with `oo::makeRef<cxx::X>()`. Converted code does not make a `cxx::X`.
3. **The old initialiser's body is a `bool` member run by the façade once it is the peer**
   (amendment oo-puw9 item 3); `self` in it is `oo::ToObjC(this)`. Where it destroyed `self` on
   failure it answers `false`, and the façade releases itself. **The part of `-dealloc` before
   `[super dealloc]` is a member (`willDealloc()`) that the façade's `-dealloc` runs**, and it must
   not call `oo::ToObjC(this)`: the peer table already reads the dying façade as dead.
4. **Ivars named like the members that answer them take a leading underscore** (`_name`,
   `_version`), as amendment oo-862e says for a getter with its ivar's name.
5. **Callers in `namespace cxx` that name the Objective-C class are qualified `::X` in a bead of
   their own before the conversion** (oo-u61e.5) when they would push the conversion past the
   eight-file budget.
6. **A category on the root that the class's header declared** (`OOScript (JavaScriptEvents)`)
   moves with its `@interface` to `X+ObjCBridge.h/.mm` (amendment oo-up4b item 4).

**Consequences.** One façade with its deletion bead (oo-9ht.137), which the root's (oo-9ht.133)
now waits for. The root bridge gained one initialiser.

## Amendment (bead oo-bhxc): stages dispatched by selector become member-function pointers

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Materials/OODefaultShaderSynthesizer.h/.mm`
  (slice 2 of `docs/phases/3-slices/OODefaultShaderSynthesizer.md`), `tests/unit/core/test_OODefaultShaderSynthesizer.mm`.

**Context.** The synthesizer's stages were pulled in by a macro that sent `-performStage:` with a
selector, which checked a hash table of selectors for recursion and sent `-performSelector:`. Once
the stages are members there is no selector to send.

**Decision (recommended defaults).**

1. **A stage named by selector becomes its name and a member-function pointer:**
   `performStage(#NAME, &X::NAME)` (`using Stage = void (X::*)();`), which calls `(this->*stage)()`.
   The recursion set holds the names (`std::unordered_set<std::string_view>`; each name is the
   macro's string literal, so it outlives the set), and the log line prints the name where it printed
   `OOSelectorName(stage)`. The release form calls `NAME()` directly, as it sent `[self NAME]`.
2. **The stage slice keeps the shell slice's façade** when its only sender left is the test's
   façade-contract case: the façade loses the internal methods and categories that no longer have a
   sender, keeps the public interface, and goes in its deletion bead, which retires that test case
   under the standing approval oo-9n5p9. The class's internals become private.
3. **Converted code reads a converted class's façade that an unconverted function answers through
   its C++ object** (`oo::Ref<cxx::OOColor>(oo::ToCxx(cxx_OOMaterialDiffuseColor(…)))`), and calls
   its members; a message to an unconverted class (`[ResourceManager cxx_shaderBindingTypesDictionary]`)
   stays (oo-9ht.117).

**Consequences.** `OODefaultShaderSynthesizer.mm` has no Objective-C method left; its façade and
`cxx::` go with oo-9ht.134.

## Amendment (bead oo-engam): a class shell whose dials are called by name, and colours it held as façades

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/HeadUpDisplay.h/.mm` (slice 1 of
  `docs/phases/3-slices/HeadUpDisplay.md`), `HeadUpDisplay+ObjCBridge.h/.mm`,
  `tests/unit/core/test_HeadUpDisplay.mm`. Follows amendments oo-pni4, oo-bm1q and oo-9ht.139.

**Context.** The HUD's class shell converts while its drawing (slices 2-6, about 3,500 lines) stays
Objective-C. The drawing is the dials, which `drawHUDItem:` sends by name to the object (ADR-0055
item 5) and `addDial:` checks with `respondsToSelector:`; the initialiser, which converts, both
checks the dials and reads a crosshair file through `-cxx_setCrosshairDefinition:`, which slice 2
owns. The old interface declared slice 2's `-renderHUD` and `-cxx_setCrosshairDefinition:` with the
class, and nine getters share their ivar's name. The colours were `OOColor *` ivars.

**Decision (recommended defaults).**

1. **The drawing becomes the façade's `Private` category, in place in `X.mm`** (as `OODefaultShaderSynthesizer`'s
   stages): `@implementation X (Private)` after the members, its `@interface` moved from the `.mm` to
   `X+ObjCBridge.h`, with the old interface's methods that a later slice owns (`-renderHUD`) moved into it,
   so the façade's main `@implementation` is complete. A selector the `.mm` declared and nothing
   implemented (`-drawPrimedEquipmentText:`) is replaced by the one implemented (`-drawPrimedEquipment:`).
   The drawing reads the state as `oo::ToCxx(self)->ivar`, a mechanical rewrite of each use.
2. **An initialiser that hands the object to the drawing is a member run after the façade is the
   peer** (amendment oo-8kx7 item 2, oo-6bux): the façade's `-cxx_initWithDictionary:inFile:` makes
   the C++ object with its default constructor, registers itself, then calls
   `initWithDictionary(...)`, whose `[self respondsToSelector:]` and slice 2's send are
   `[oo::ToObjC(this) …]`, so they see the façade the caller holds.
3. **Getters with their ivar's name are `get` + the name** (amendment oo-862e item 1:
   `getHudName()`, `getOverallAlpha()`, `getLineWidth()`, …), because the drawing uses the ivars on
   every line; ivars keep their names.
4. **A converted class's colours are held as `oo::Ref<cxx::OOColor>`**, made with `cxx::OOColor`'s
   factories; the façade answers `oo::ToObjC(...)`, so a colour set through the façade reads back as
   the same object. A drawing unit that reads one still messages its façade, through
   `oo::ToObjC(...)` at the read, until its own slice.

**Consequences.** One façade (deletion bead oo-mwd58) whose deletion waits for the HUD's
callers and the drawing slices; the slice beads 2-6 turn the category's methods into members and
leave one forwarder per dial.

## Amendment (bead oo-tsa4): the OXPVerifier manager, a class whose façade other objects keep unretained

- Date: 2026-10-01. Status: Proposed, as above. Exemplar: `src/Core/OXPVerifier/OOOXPVerifier.h/.mm`,
  `OOOXPVerifier+ObjCBridge.h/.mm`, `tests/unit/core/test_OOOXPVerifier.mm`. Follows Amendment 1
  (oo-cwz), amendments oo-up4b, oo-94qk, oo-smy, oo-novu and oo-fg7i, and human bead oo-4amcj.

**Context.** `OOOXPVerifier` drives the stage hierarchy, which still has Objective-C subclasses
(`OOCheckShipDataPListVerifierStage`, `OOModelVerifierStage`). Every stage keeps its verifier as
an unretained `OOOXPVerifier *` (`cxx::OOOXPVerifierStage::verifier()`) and messages it; the
verifier was made by `+runVerificationIfRequested` and lived for the whole run. The stage tests
link a test double instead of the verifier (oo-9ht.65), an `@implementation OOOXPVerifier` with
ivars of its own.

**Decision (recommended defaults).**

1. **A C++ object whose façade other objects keep unretained keeps that façade alive itself** for
   the span the Objective-C object lived: `run()` opens with
   `const oo::ObjCRef<::OOOXPVerifier *> facade(oo::ToObjC(this));`, so every stage registered
   during the run sees one façade. The C++ object never retains its façade beyond that span (no
   cycle); a stage registered outside a run sees the façade of the moment, as `ToObjC` makes it.
2. **Converted code that drives a hierarchy with Objective-C subclasses keeps the objects as
   their Objective-C objects** (`oo::ObjCRef<::OOOXPVerifierStage *>`, amendment oo-smy) and calls
   their C++ part, `oo::ToCxx(stage)->name()`: an adapter's virtual members message the subclass,
   so its overrides answer as before. Where the old code exposed the Objective-C pointer (the
   graphviz node names), the C++ objects it gets back cross with `oo::ToObjC` so the same pointer
   is printed.
3. **A failing initialiser becomes `createWithX()` + `bool initWithX()`** (amendment oo-fg7i);
   the class method that made and ran the object is a `static` member that holds it in an
   `oo::Ref`.
4. **Categories that other files add to the class stay on the façade** (`-fileScannerStage`,
   `-textureVerifierStage`, `-modelVerifierStage`) until those files' deletion beads; the façade's
   own interface is the old one, so the stage tests' double, an `@implementation` of the façade
   class with ivars of its own, compiles unchanged and does not link the bridge.
5. **Once the class is `cxx::X`, code inside `namespace cxx` that keeps the façade names it `::X`**
   (`::OOOXPVerifier *verifier()`, `oo::ObjCRef<::OOOXPVerifierStage *>`): unqualified, `X` there is
   now the C++ class. The stages' `verifier()`/`setVerifier()` and the `nameFor…ForVerifier()`
   helpers changed only in that spelling; global leaves need no change.

**Consequences.** One façade and its deletion bead (oo-9ht.130). No caller's behaviour and no test
expectation changed: the stages changed only in spelling (item 5), and the two stage tests that
had pasted the old double moved to the shared one first (oo-9ht.141). The
verifier no longer messages the `OOCacheManager` façade (it calls `cxx::OOCacheManager`), which the
cache manager's deletion bead (oo-9ht.31) waited on.

## Amendment (bead oo-dnbf): the class-shell slice of a converted root's subclass

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/OOMesh.h/.mm` (slice 1 of
  `docs/phases/3-slices/OOMesh.md`), `OOMesh+ObjCBridge.h/.mm`, the façade class lookup in
  `OODrawable+ObjCBridge.mm`, `tests/unit/core/test_OOMesh.mm`. Follows amendments oo-up4b item 3,
  oo-smy, oo-pni4 and the sub-brief's slice rules.

**Context.** `OOMesh` is an Objective-C subclass of the converted root `OODrawable`, which its
callers message by its own selectors, and its file is split into four slices. Slice 1 makes the
class shell C++, so the mesh becomes the first C++ drawable while its loading (2), geometry (3)
and rendering (4) stay Objective-C. Those slices implement two of the root's virtual members
(`-renderOpaqueParts`, `-boundingBox`), the designated initialiser, a bitwise
`-mutableCopyWithZone:`, and the graphics-reset client that the loader registers (`self`).

**Decision (recommended defaults).**

1. **The subclass is `cxx::X : public cxx::Root`, with a façade `@interface X : Root` and no ivars**
   (amendment oo-up4b item 3). The root's `oo::ToObjC` picks the façade class by the C++ class's
   name, walking its bases, as `OOMaterial+ObjCBridge.mm` does; the root's bridge gains the public
   `-initWithNewCxxDrawable:` (amendment oo-862e item 3) for the façade's `-init`. Typed
   `oo::ToObjC`/`oo::ToCxx` `static_cast` to and from the root's.
2. **Later-slice units of the primary `@implementation` become in-place categories named after
   their slice** (`OOMesh (OOMeshRendering)`, `OOMesh (OOMeshGeometry)`); the `Private` category
   stays as it was. Their public selectors move from the façade's `@interface` to matching
   category interfaces in `X+ObjCBridge.h`, so the façade's own `@implementation` is complete (no
   `-Wincomplete-implementation`). This is amendment oo-bwjb item 1, which landed alongside; the
   blocks here are not contiguous, so each gets its own category name (a category cannot be
   implemented twice in one file). The ivar rewrite `oo::ToCxx(self)->ivar` is scripted; selector
   positions and signatures are left alone.
3. **A root virtual member that a later slice implements gets a C++ trampoline**,
   `void renderOpaqueParts() override { [oo::ToObjC(this) renderOpaqueParts]; }`, so a converted
   caller that calls it through `cxx::Root *` reaches the slice's method, which is the façade's
   category override. The slice that converts the method replaces the trampoline with the body.
4. **Members whose names clash:** an ivar named like an overridden virtual getter takes a leading
   underscore (`_collisionRadius`, `_maxDrawDistance`, `_boundingBox`; amendment oo-rdfh item 1); a
   non-virtual getter named like its ivar becomes `get` + name (`getVertexCount()`,
   `getFaceCount()`, `getMaterials()`; amendment oo-862e item 1). Inside `namespace cxx` the
   Objective-C types of members are written `::OOMaterial *`, `::Octree *`.
5. **`-init` is the constructor, and a later slice's designated initialiser sends `[self init]`**
   where it sent `[super init]`, since `[super init]` would now make the root's Objective-C
   adapter. The constructor's defaults are overwritten by a successful load or die with a failed
   one, so nothing observable changes.
6. **A bitwise copy of the object** (`class_createInstance` + `memcpy`, then each C++ ivar
   constructed afresh) cannot copy a façade's C++ part. It becomes the C++ copy constructor
   (`= default`: member by member, which is the old "construct afresh" list) and a new façade; the
   raw Objective-C members are retained after, as before. The root's
   `oo::ConstructCxxPartOfCopy` keeps its test but has no caller left.
7. **What `-dealloc` sent to `self`** (`[self deleteDisplayLists]`, a later slice's method, and
   `-unregisterClient:self` to the converted graphics reset manager, whose client is the façade
   the loader registered) stays in the façade's `-dealloc`, before `[super dealloc]`; the
   destructor does the C++ teardown. `oo::ToObjC(this)` is never called from a destructor.
8. **A category on another converted class in the file** (`OOCacheManager (OOMesh)`,
   `OOCacheManager (Octree)`) becomes free functions named class + selector
   (`OOCacheManagerOctreeForModel`, `OOCacheManagerSetOctree`), on the C++ classes: in an
   anonymous namespace where only the file sends them (`misc-use-anonymous-namespace`), else
   declared where the category was (`OOMesh.h`). Their
   Objective-C senders in later slices cross with `oo::ToObjC`/`oo::ToCxx`.
9. **`-oo_objectSize` of a façade or Objective-C object** in a converted debug body is its
   definition, `class_getInstanceSize(object_getClass(object))` (0 for nil).

**Consequences.** One façade (`OOMesh+ObjCBridge`) and its deletion bead, which waits for slices
2-4 and the callers. A C++ subclass of a root is now visible to Objective-C as its own façade
class, through the root's bridge. Slices 2-4 each delete their category and trampolines as they
convert, and slice 2 replaces `[self init]` and the façade-level copy with C++ members.

## Amendment (bead oo-9ht.86): a delegate protocol between two façades, and a singleton's members

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: bead oo-9ht.86 (`OOALSoundChannel+ObjCBridge`):
  `src/Core/OOALSoundChannel.h/.mm`, `OOALSoundMixer.h/.mm`, `OOSoundSource.h/.mm`,
  `OOSoundSource+ObjCBridge.mm`, `tests/unit/core/test_OOSoundChannel.mm`; approval lines landed by
  oo-9ht.149.

**Context.** The channel called its delegate, an `id` answering `-channel:didFinishPlayingSound:`
(the informal `OOObject (OOSoundChannelDelegate)` category in the channel's bridge header), and
the delegate was another class's façade (a playing `OOSoundSource`) or that class itself (a
stopped source's channel). Neither façade could go first while the other answered or sent the
selector. The mixer, a never-destroyed singleton (amendment oo-r7m0), retained its channels.

**Decision (recommended defaults).**

1. **An informal delegate protocol becomes a C++ interface in the sender's header**
   (`class OOSoundChannelDelegate` with the selector's first keyword as a pure virtual member and a
   protected non-virtual destructor), held unretained as the `id` was. The converted class that
   answered it implements it (`cxx::OOSoundSource : public oo::RefCounted, public
   ::OOSoundChannelDelegate`); a class method that answered it becomes a file-local object
   implementing it that calls the static member. The receiver façade's forwarding methods for the
   selector go in the sender's deletion bead, which owns the protocol; the receiver's own façade
   deletion is not a dependency.
2. **What the façade's `-dealloc` sent goes into the destructor**, guarded by what made the façade
   (a channel whose `init()` failed never had one).
3. **A never-destroyed singleton keeps converted objects as the +1 raw pointers alloc/init gave**
   (released where it released them), not `oo::Ref` members: an `oo::Ref<Y>` member needs the
   complete `Y` in every includer of the singleton's header, and importing `Y`'s header there can
   change overload resolution in unrelated tests (it brought the vector bridge's `oo::ToCxx` into
   `test_OOSound.mm`).
4. **Test stand-ins of a class with private state** keep what the stub's extra ivars held in a map
   keyed by the object, and reach private members through the class's test-access friend.

**Consequences.** The sound source keeps its façade for its other callers (oo-9ht.88); the
channel's delegate no longer depends on it.

## Amendment (bead oo-0tx6c): the rest of a class-shell plan's slices, when the dials are its façade's methods

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/HeadUpDisplay.h/.mm` and
  `HeadUpDisplay+ObjCBridge.h/.mm` after slices 2-6 of `docs/phases/3-slices/HeadUpDisplay.md`
  (beads oo-8fiz9, oo-8j1y2, oo-2p1ug, oo-kdrc6, oo-0tx6c). Follows amendment oo-engam.

**Decision (recommended defaults).**

1. **A slice moves its methods out of the façade's in-place category into the member section** of
   `X.mm`, bodies verbatim but for `oo::ToCxx(self)->` (dropped) and `[self m]` (a member call). A
   method the slice's own callers still send through the façade (`-renderHUD`) returns to the
   façade's main interface as a forwarder; a dial (sent by name) moves to an `OODials` category,
   one forwarder each. When the last slice lands, the in-place category and its `@interface` are
   deleted, and `X.mm` has no Objective-C left.
2. **A member that calls a slice still on the façade** sends `[oo::ToObjC(this) m]` until that
   slice lands, which turns it into a member call. A file-scope helper a moved member now calls
   before its definition gets a declaration with the file's other prototypes.
3. **A category on a converted class's façade in the file** (`OOPolygonSprite (OOHUDBeaconIcon)`)
   becomes a free function on the C++ class, declared in `X.h`, and its `@implementation` forwards
   from `X+ObjCBridge.mm` (amendments oo-6ia4 item 3, oo-9fwb). **A small class the entities hold by
   a protocol** (`OOHUDBeaconCodeIcon`) becomes `cxx::` with its own façade in the same bridge, and
   the protocol moves verbatim to the bridge header (amendments oo-jpd8, oo-4nhg).
4. **An enum a member's signature needs from a header that `X.h` cannot import** (an import cycle:
   `OOMissileStatus` in `PlayerEntity.h`) is passed as `int` in that one private member, with a
   comment naming the enum; the body's `switch` is unchanged.
5. **A singleton made by its façade's class method** (`+[OOJoystickManager sharedStickHandler]`,
   which picks the platform subclass, amendment oo-6bux) is still asked for through the façade, and
   used through `oo::ToCxx`.

**Consequences.** The HUD's façade serves only its callers and the dial dispatch; its deletion
(oo-mwd58) replaces `OOCallByName` with a table of member pointers.

## Amendment (bead oo-9z7x): a later slice of a converted subclass, whose units sat in the private category between other slices' units

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: slice 3 of `docs/phases/3-slices/OOMesh.md`
  in `src/Core/OOMesh.h/.mm`, `OOMesh+ObjCBridge.h/.mm`, `tests/unit/core/test_OOMesh.mm`. Follows
  amendments oo-dnbf, oo-bwjb and oo-pni4.

**Decision (recommended defaults).**

1. **A later slice's units that sit inside the private category, between units of slices still
   Objective-C, move to just after that category's `@end`** as `cxx::X` members, with the
   file-static C functions they call. An `@implementation` of one category cannot be closed and
   reopened in a file, and a second category name would leave the private `@interface` without
   its methods (`-Wincomplete-implementation`). Their declarations leave the private
   `@interface`; their Objective-C senders in the slices still Objective-C call
   `oo::ToCxx(self)->m(...)`, and the selectors the façade's callers send move from the slice's
   category in `X+ObjCBridge.h` back to the façade's `@interface`, forwarded in one line.
2. **A member that held a converted class's façade by hand** (`::Octree *octree`, retained) becomes
   `oo::Ref<cxx::Y>` when its slice converts: the destructor's `DESTROY`, the copy's `-retain` and
   the size's crossing go, and the façade method answers `oo::ToObjC(member)`.
3. **`@autoreleasepool { ... }` in a converted member** is `objc_autoreleasePoolPush()` /
   `objc_autoreleasePoolPop(pool)` around the same block, as the file's loader already did.
4. **A trampoline (amendment oo-dnbf item 3) is deleted by the slice that converts its method**;
   the member is then the body.

## Amendment (bead oo-9ht.12): deleting a façade

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: the first façade deletion, bead oo-9ht.12
  (`OORegExpMatcher+ObjCBridge`): `src/Core/OORegExpMatcher.h/.mm`, its one caller
  `src/Core/OOOpenGLExtensionManager.mm`, `tests/unit/core/test_OORegExpMatcher.mm` and the
  stand-ins in eleven other core tests; approval lines landed by oo-9ht.145.

**Context.** Item 5 says a deletion bead "moves the class to the global namespace and deletes `cxx::`
at every use, one mechanical replacement". The first one showed what else it takes: a caller whose
deps were wrong, converted code that still messages the façade, tests that stub the Objective-C
class, façade-contract test cases (CLAUDE.md rule 2), and a lifetime the façade carried.

**Decision (recommended defaults).** A "Delete X+ObjCBridge" bead does this, in this order:

1. **Check readiness first, with the bead's grep and one wider one:** `\[X |\[\[X |\bX \*|ObjCRef<X\b`
   and `\[::X ` outside `X*` files. An unconverted Objective-C file that still messages, makes,
   declares or answers `X` means the deps are wrong: `bd dep add` the caller's conversion bead (or
   its slices, or its own façade's deletion bead), note the lines in the bead, and skip it. Do not
   convert the caller in a deletion bead. A converted file (C++ class, `namespace cxx`) that still
   messages the façade (`[::X ...]`, `oo::ObjCRef<::X *>`, `oo::ToCxx(...)` of it) is adapted in the
   deletion bead: it calls the C++ class directly.
2. **List the test cases and stand-ins that go, and land their approval lines first.** Under the
   standing approval oo-9n5p9 only the façade's own cases go: its selectors, `oo::ToObjC`/`oo::ToCxx`
   crossings, `-dealloc`, its autorelease-pool lifetime. A case that asked a question through a
   selector keeps its name and every expectation and asks the C++ class instead. A test that stubs
   the Objective-C class (an `@interface X` stand-in, because the code it links messaged the façade)
   gets a C++ stand-in with the same answers: definitions of the members that code now calls (and the
   virtual destructor, for the vtable), after `#import "X.h"`. One path line per changed test file in
   `tools/retire-test-approvals.txt`, reason `oo-9n5p9: <deletion bead> deletes the X façade - ONLY
   ...`, landed by a separate small bead the deletion bead depends on, because a change may not
   approve its own retirement. One approvals bead may carry the lines of several deletion beads.
3. **Delete the bridge**: `git rm X+ObjCBridge.h/.mm`, the `#import` at the end of `X.h` with its
   comment, the meson line in the module, and the bridge in each core test's meson entry.
4. **Move the class to the global namespace**: drop `namespace cxx {` / `}` around the class in
   `X.h` and `X.mm`, and replace `cxx::X` with `X` everywhere (sources and tests). Code that stays in
   `namespace cxx` may keep `::X`; it now names the C++ class. Rewrite comments that described the
   façade (the header banner says which bead deleted it).
   **Leaving `namespace cxx` changes what an unqualified name means.** Inside a member function an
   unqualified base name still finds the C++ base (the injected class name), but any other class
   that is still `cxx::Y` with a façade `Y` now names the Objective-C façade: qualify it
   (`cxx::OOOpenGLExtensionManager::sharedManager()`, `cxx::OOColor *` in a signature, the base in
   `class X : public cxx::Base`). List the candidates before building: every class declared in a
   `namespace cxx { }` block, used unqualified in the moved files.
5. **Keep what the façade kept.** A façade's autoreleased object lived until the pool drained
   (amendment oo-ct7c); a converted caller that made several calls in one pass now holds one
   `oo::Ref<X>` across them (taken on first use if the old code took it lazily, so nothing new is
   made when no call happens), and a test counts what is made per pass.
6. **A subclass façade's objects cross as the nearest façade left.** Once `X+ObjCBridge` (a subclass
   façade, `@interface X : Root`) is gone, the root's `oo::ToObjC` gives an object of the nearest
   Objective-C façade class still standing (the root's, or an intermediate's). Its description
   still names the C++ class where the root prints `ClassName` of the C++ object. Code and tests
   that asked `-isKindOfClass:[X class]` / `-isMemberOfClass:` ask `dynamic_cast<X *>(oo::ToCxx(o))`
   / `typeid` instead; a test adds one case that pins the new crossing (the façade class it now
   gets, identity, `ToCxx`). Where the deleted façade kept an object for the process (a
   singleton's `+shared...`), the C++ caller that answers it keeps the root façade the same way.
   Deletion beads of one hierarchy that touch the same tests are stacked: each branch is made from
   the previous one and queued after it.
7. **Gates and acceptance**: build (`tools/build-windows.sh test`, no new warning), `check-core-tests`
   for the class's test and every test whose stand-in changed, tier-a on the changed sources, goldens,
   guardrails, all through `buildslot.sh`. The bead's acceptance is the fast proof: `! test -e` both
   bridge files, `! git grep -n 'ObjCBridge'` over `X.h` and the module's meson, `! git grep -nw
   'cxx::X'` over `src` and `tests`, `grep -qF '[<id>] ' tests/nightly/checks.txt`, guardrails; the
   nightly line runs the build, those core tests and the goldens.

**Consequences.** Every deletion bead is two beads (approval lines, then deletion) unless it retires
no test case and changes no stand-in. Deletion beads whose readiness check fails gain the missing
deps instead of growing into conversions.

## Amendment (bead oo-ukxy8): an entity leaf's class-shell slice whose later slice answers a protocol

- Date: 2026-10-06. Status: Proposed, as above (recommended default, CLAUDE.md rule 10). Exemplar:
  `src/Core/Entities/OOVisualEffectEntity.h/.mm` (slice 1 of
  `docs/phases/3-slices/OOVisualEffectEntity.md`), `OOVisualEffectEntity+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOVisualEffectEntity.mm`. Follows amendments oo-dnbf, oo-0mxi and oo-ubjo.

**Decision (recommended defaults).**

1. **The shell slice's members are one `namespace cxx { }` block before the later slice's in-place
   category** (`OOVisualEffectEntity (OOVisualEffectEntityScripting)`), moved there from between that
   slice's methods (amendment oo-zkpmt item 2), so the category is one block.
2. **A protocol whose methods are all the later slice's** (`OOBeaconEntity`) is adopted by that
   category's interface in `X+ObjCBridge.h`, not by the façade's `@interface`, so the façade's own
   `@implementation` is complete; static conformance (`Entity<OOBeaconEntity> *`) is unchanged.
   A protocol the shell answers (`OOSubEntity`) stays on the façade, forwarded in one line each.
3. **A protocol-qualified Objective-C type named inside `namespace cxx`** (`Entity<OOSubEntity> *`,
   where `::Entity<…>` parses as a template) gets a global typedef in `X.h`
   (`typedef Entity<OOSubEntity> OOVisualEffectSubEntity;`).
4. **A file-local helper of the slice that asked an entity `-isVisualEffect`** asks the converted
   root (`oo::ToCxx((::Entity *)e)->getIsVisualEffect()`), which answers for Objective-C subclasses
   through their adapters (amendment oo-9ht.139 item 1).
5. **An initialiser that released itself on failure** is a `bool` member the façade's initialiser
   runs after making the C++ part; on false the façade releases itself and answers nil.
## Amendment (bead oo-zkpmt): a class-shell slice whose later slices are the class's own `@X` block

- Date: 2026-10-06. Status: Proposed, as above (recommended default, CLAUDE.md rule 10). Exemplar:
  `src/Core/GameController.h/.mm` (slice 1 of `docs/phases/3-slices/GameController.md`),
  `GameController+ObjCBridge.h/.mm`, `SDL/GameController+SDLFullScreen.mm`,
  `tests/unit/core/test_GameController.mm`. Follows amendments oo-r7m0, oo-bj8 item 2 and oo-bwjb.

**Context.** Amendment oo-bwjb item 1 keeps the shell slice's selectors in the façade's
`@interface` (forwarded by `X+ObjCBridge.mm`'s `@implementation X`) and moves the later slices'
methods into a category `X (XSlices)` in `X.mm`. That works when the plan names the later slices'
methods one by one. `GameController.md` gives slice 3 the whole block (`@GameController`), and
`tools/check-slice-plan.py` matches an `@X` entry against the block's name: renamed to
`GameController(GameControllerSlices)`, slice 3's eighteen methods became unassigned (the plan
check fails) and `--slice-done 3` passed with nothing converted. The plan may not be edited by the
slice bead.

**Decision (recommended defaults).**

1. **The later slices keep the class's `@implementation X` in `X.mm`, under its name, in place;**
   the façade's own methods go in a category: `X+ObjCBridge.h` declares the old `@interface` with
   the later slices' selectors (old order, unchanged) and the shell slice's selectors in
   `@interface X (OOObjCBridge)`, which `X+ObjCBridge.mm` implements in one-line forwarders, with
   the crossings, `-initWithCxxX:` and `-dealloc`. Both `@implementation`s are complete, callers see
   the same selectors with the same types, and the plan's `@X` entry still finds the later slices.
2. **The shell slice's members are defined in one `namespace cxx { }` block before the
   `@implementation`,** moved there from their places in the block (here `-finishedLaunching` and
   `-suppressClangStuff`), because one class may have only one `@implementation` per file.
3. **The later slices and the class's other categories read the state through the façade's
   `@public _cxxController`** (amendment oo-bj8 item 2's scripted, word-bounded rewrite, string
   literals excluded); an ivar named like its getter takes a leading underscore (`_gameView`,
   amendment oo-rdfh item 1). A shell member that told an Objective-C object of `self` hands it
   `oo::ToObjC(this)` (`[_gameView setGameController:oo::ToObjC(this)]`), the façade
   `+sharedController` keeps.
4. **Header macros that message the class name the façade `::X`** (`OO_DEBUG_PROGRESS`), so a
   caller inside `namespace cxx` still reaches the Objective-C class.
5. **A singleton that callers also `alloc`/`init`** (`main.mm` makes the application's controller
   that way, apart from `+sharedController`'s) keeps `-init` on the façade: it makes a new C++ object
   (the constructor is the old `-init` body, raising where it raised, after releasing the receiver)
   and becomes its peer. Converted senders name the façade `[::X sharedX]` (amendment oo-jfno item 2).
6. **A Mac-only declaration with a Foundation type** (`-snapshotsURLCreatingIfNeeded:`) is not
   copied into the new bridge header when only the fenced Mac category sends it: the type would be a
   new deny-list hit in a new file (the guardrails' file-split limitation).

**Consequences.** One façade and its deletion bead, which waits for slices 2 and 3 and the
`FullScreen` category (oo-qinv); each later slice turns its methods into members and deletes their
declarations from the façade's `@interface`.

## Amendment (bead oo-zmix): the rendering slice of a converted subclass, and a façade that stays a protocol client

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: slice 4 of `docs/phases/3-slices/OOMesh.md`
  in `src/Core/OOMesh.h/.mm`, `OOMesh+ObjCBridge.h/.mm`, `tests/unit/core/test_OOMesh.mm`. Follows
  amendments oo-dnbf and oo-9z7x.

**Decision (recommended defaults).**

1. **A protocol method that a manager sends to the façade** (`-resetGraphicsState`, the
   `OOGraphicsResetClient` the loader registers with `registerClient:self`) becomes a member that
   the façade forwards in one line. The conformance moves from the private category in `X.mm`
   (whose `@implementation` no longer has the method) to an empty category of the façade in
   `X+ObjCBridge.h` (`@interface OOMesh (OOMeshGraphicsReset) <OOGraphicsResetClient>`), so the
   still-Objective-C loader's `registerClient:self` keeps its type. The client becomes the C++
   object (`cxx::OOGraphicsResetClient`) only when the loader converts and registers `this`.
2. **A member array of a converted class's Objective-C objects** (`::OOMaterial *materials[]`,
   retained) stays one while code outside the slice (the copy) retains its elements; the converted
   members cross per element (`oo::ToCxx(materials[i])->apply()`), null-guarded as a message to nil
   was, and store `[oo::ToObjC(material.get()) retain]` where they made one with the C++ factory.
3. **`@try`/`@catch (OOException *)` in a converted member stays** (amendment oo-puw9 item 4); the
   slice check accepts it in a converted unit (oo-9ht.117).
4. **The last trampoline goes with its slice** (amendment oo-9z7x item 4): `renderOpaqueParts()` is
   the body, reached by the root façade's forwarder and by C++ callers alike.

## Amendment (bead oo-jfno): a class with only class methods, and the senders it gains in namespace cxx

- Date: 2026-10-05. Status: Proposed, as above (recommended default). Exemplar: slice 1 of
  `docs/phases/3-slices/ResourceManager.md` (`src/Core/ResourceManager.h/.mm`,
  `ResourceManager+ObjCBridge.h/.mm`, `tests/unit/core/test_ResourceManager.mm`).

**Decision (recommended defaults).**

1. **A class that has only class methods** (`ResourceManager`) becomes `cxx::X` with static members and
   a deleted constructor; its façade is an `OOObject` subclass with class methods only, each forwarding
   to the static member in one line. It has no peer table and no `oo::ToObjC`/`oo::ToCxx`.
2. **Converting a class makes its bare name, inside namespace cxx, the C++ class** (measurement 1 above),
   so every send to the class from converted code (`[ResourceManager cxx_paths]` in a member of
   `cxx::OOShipRegistry`) stops compiling. The bead that introduces `cxx::X` qualifies each of those sends
   as `[::X …]`, one token per line, in every file that has one (18 files for `ResourceManager`); that
   edit is outside the story's 8-file budget by necessity and changes nothing else. A send from
   Objective-C code is left as it is.

## Amendment (bead oo-6rb6): a class-shell slice whose class has a category in another file, a failable `-init` that sends that category, and a window a unit test may not open

- Date: 2026-10-05. Status: Proposed, as above (recommended default). Exemplar: `src/SDL/MyOpenGLView.h/.mm`
  (slice 1 of `docs/phases/3-slices/MyOpenGLView.md`), `MyOpenGLView+ObjCBridge.h/.mm`,
  `MyOpenGLView+Input.mm`, `tests/unit/core/test_MyOpenGLView.mm`. Follows amendments oo-o89, oo-3bgz
  and oo-2g51.

**Decision (recommended defaults).**

1. **A category of the class in a file of its own that no slice of the plan owns** (`MyOpenGLView+Input.mm`,
   bead oo-0806) takes the same mechanical rewrite as the plan's later slices: each ivar it touches is
   `oo::ToCxx(self)->ivar`, and nothing else in it changes. Amendment oo-o89 item 4 (its methods become
   members of `cxx::X`) applies when its own bead converts it.
2. **A failable `-init` that sends the façade's other methods** (`-initKeyMappingData`,
   `-populateFullScreenModelist`, `-loadWindowSize`) is `bool init()`, run by the façade's `-init` after it
   has made the empty C++ object (`X() = default`) and become its peer (amendment oo-3bgz item 3); where it
   answered nil after `[self dealloc]`, it returns false and the façade releases itself, so the destructor
   (the old `-dealloc` body) runs as before.
3. **Bool ivars become `bool`** (item 3), including the key-state array, and assignments of `YES`/`NO`
   stay verbatim. A converted collaborator ivar (`OOOpenGLMatrixManager *matrixManager`) is an
   `oo::Ref<cxx::X>`; a later slice's getter that answered it answers `oo::ToObjC(...)` of it, the one
   line that changes beyond the rewrite.
4. **Units that open the game's window** (`-createWindowWithSize:`, `-initSplashScreen`,
   `-endSplashScreen`, `-initialiseGLWithSize:`, `-updateScreen`) are not run by the unit test: a test may
   not show a window on the desktop (CLAUDE.md, `tools/gui-lock`). The test pins what the slice computes
   without one (the state `-init` leaves in a scratch home, the display and its native size, the projection
   `-updateGLSize:` sets in a hidden test context), and the goldens, which launch the game, run the rest.

## Amendment (bead oo-72cz): a later slice of a class-shell class, with platform arms and a converted-collaborator getter

- Date: 2026-10-05. Status: Proposed, as above (recommended default). Exemplar: slice 2 of
  `docs/phases/3-slices/MyOpenGLView.md` (`src/SDL/MyOpenGLView.h/.mm`, `MyOpenGLView+ObjCBridge.h/.mm`,
  `tests/unit/core/test_MyOpenGLView.mm`). Follows amendments oo-3bgz and oo-6rb6.

**Decision (recommended defaults).**

1. **A method defined in both arms of `#if OOLITE_WINDOWS … #else`** (the Windows display / HDR block and
   its stubs) is one member; each arm's definition stays in its arm, and the declaration and the façade's
   forwarder follow the old `@interface`'s arms (unconditional where it was, inside `#if OOLITE_WINDOWS`
   where it was). A definition under a build guard (`#ifdef GNUSTEP_BASE_LIBRARY`) keeps the guard.
2. **A getter named like its ivar is `get<Name>`** (amendment oo-862e), including one the old header never
   declared (`-bounds`, now `getBounds()`); its façade forwarder is kept so the selector still answers.
3. **The getter that answered a converted collaborator's façade** (`-getOpenGLMatrixManager`, amendment
   oo-6rb6 item 3) answers the borrowed C++ object as a member; the façade's forwarder wraps it in
   `oo::ToObjC`.
4. **A class method is a static member** (`+pollShiftKey`), and a `cxx_` selector's member drops the prefix
   (`stringToClipboard`). Slice 1's sends of this slice's selectors (`[oo::ToObjC(this) loadWindowSize]`)
   become member calls; its sends to the Input category stay as they are.

## Amendment (bead oo-rdwg): the last slice of a converted subclass, its designated initialiser, and a client that becomes C++

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: slice 2 of `docs/phases/3-slices/OOMesh.md`
  in `src/Core/OOMesh.h/.mm`, `OOMesh+ObjCBridge.h/.mm`, `tests/unit/core/test_OOMesh.mm`. Follows
  amendments oo-dnbf, oo-9z7x and oo-zmix.

**Decision (recommended defaults).**

1. **The designated initialiser is a private `bool` member with its first keyword's name**
   (`initWithName(...)`, amendments oo-zl36 item 3 and oo-u61e.4 item 3) run on a new object by
   the class's factories: `oo::makeRef<X>()`, then the member, and null when it answers `false`
   (where it sent `[self release]; self = nil`). Its `@autoreleasepool` is
   `objc_autoreleasePoolPush`/`Pop` (amendment oo-9z7x item 3). The façade keeps `-init` (a new
   C++ object) for `[[X alloc] init]`.
2. **A copy that the façade made** is the member `mutableCopyWithZone(OOZone *)`, answering
   `oo::Ref<X>` (the copy constructor, then what the old body did to the copy); the façade's
   `-mutableCopyWithZone:` forwards and answers `[oo::ToObjC(copy) retain]`, and the members that
   sent `-mutableCopy` to the façade call it directly.
3. **When the code that registered `self` with a manager converts, the C++ object becomes the
   client** (`cxx::OOGraphicsResetClient`, `registerCxxClient(this)`), and its destructor
   unregisters it; what the façade's `-dealloc` did for the client moves into the destructor. The
   façade keeps its forwarder and conformance (amendment oo-zmix item 1) for any Objective-C sender,
   but is no longer registered, so a C++ holder with no façade alive is still reset.
4. **With its last slice, `X.mm` has no Objective-C class code**: the ObjC-syntax gate of item 8
   applies to `X.mm` and `X.h` from this bead on; what remains Objective-C is the façade and its
   deletion bead.

## Amendment (bead oo-60fwo): a giant class converted slice by slice, whose state moves first (ShipEntity)

- Date: 2026-10-05. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/ShipEntity.md` "Slice 1". Exemplar: `src/Core/Entities/ShipEntity.h`,
  `ShipEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_ShipEntity.mm`. Follows amendment oo-bj8
  (the entities) and oo-9ht.140 (the slice plan).

**Context.** `ShipEntity` (15,000 lines, ~640 methods, 197 ivars) converts in 34 slices, each a
story that moves its methods into `cxx::ShipEntity`. Slice 1 moves the state first, so that every
later slice has a C++ class to move into. Amendment oo-bj8 moved a root's ivars and gave the
unconverted code one `@public` facade ivar, `_cxxEntity`, to reach them by. A ship is not a root:
its `_cxxEntity` is a `cxx::Entity`, and the ship's members need a `cxx::ShipEntity`. Its methods
also read the ivars it declared `@private`, and they stay Objective-C until their slice.

**Decision (recommended defaults).**

1. **The facade carries one `@public`, non-owning, typed alias of the root's part:**
   `cxx::ShipEntity *_cxxShip`, set by the facade's override of the root's designated initialiser
   (`-initWithCxxEntity:`, a checked `dynamic_cast` of `_cxxEntity`) and never released: the root's
   `_cxxEntity` owns the part. Unconverted code reads the ship's members through it by the old
   names, `_cxxShip->fuel` in a method of the facade, its categories or an Objective-C subclass,
   and `ship->_cxxShip->fuel` from another class. The rewrite is amendment oo-bj8 item 2's,
   compiler-guided, with the same poison-ivar proof; each slice deletes `_cxxShip->` from the
   bodies it moves and gets them back verbatim. `oo::ToCxx(::ShipEntity *)` is the root's
   crossing, typed (amendment oo-up4b item 3), not a read of `_cxxShip`: overload resolution picks
   it for every `PlayerEntity *`, and the unit tests' stand-in `PLAYER` is a plain entity.
2. **The `@private` ivars are public members while the class is half converted**, marked so in
   the class: the facade's unconverted methods read them, and an Objective-C class cannot be a C++
   friend. The facade's deletion bead makes them private again.
3. **Every member is zero-initialised** (amendment oo-bj8 item 1), and keeps its type: Objective-C
   object pointers stay raw pointers, retained and released by hand where the bodies did
   (`DESTROY(_cxxShip->shipAI)` in the facade's `-dealloc`); they become `oo::ObjCRef` or
   `oo::Ref` in the slices that own them. Inside `namespace cxx` an Objective-C class whose name
   has a C++ twin is named `::X` (`::ShipEntity *scanned_ships[]`, `::OOWeakReference *`).
4. **The initialisers.** The facade's `-init`, `-initBypassForPlayer` and
   `-cxx_initWithKey:definition:` make the ship's adapter, `oo::ObjCEntity<cxx::ShipEntity>`,
   where they sent `[super init]` (one private `-initShipPart`, which keeps the part of a ship
   sent the initialiser again, as `PlayerEntity`'s `-deferredInit` does). The initialiser's body
   between `[super init]` and the set-up is `cxx::ShipEntity::initWithKey()`; the set-up, which may
   release the object and answer nil, and the top-speed check stay in the facade.
5. **`-dealloc` stays in the facade** (amendment oo-bj8 item 7), with the root's guard (oo-s6ic6):
   a ship released before its initialiser ran has no part and skips the body.
6. **The slice checker sees a slice done when its units leave the file:** a unit that needs the
   Objective-C object as self (an initialiser, `-dealloc`) moves to a category of the facade in
   the facade's `.mm` (`ShipEntity (OOObjCBridge)`), because the class's `@implementation` stays
   in `ShipEntity.mm` until the last slice; a declared selector it implements
   (`-cxx_initWithKey:definition:`, `OO_RETURNS_RETAINED` as the house's other `cxx_init...` are)
   moves to that category's `@interface` in the bridge header, so the primary `@implementation`
   stays complete. The other units become members (`isShipWithSubEntityShip()`, whose category
   method on the facade forwards), and a category of `Entity` in the file moves to the facade's
   `.mm` (amendment oo-bj8 item 12).

**Consequences.** One more load per member read from unconverted code, as for `_cxxEntity`. The
subclasses (`StationEntity`, `DockEntity`, `PlayerEntity`, `ProxyPlayerEntity`), the three
category files and every reader of a ship's ivars changed only by item 1. The facade's deletion
bead removes every `_cxxShip->`, makes the item 2 members private and depends on the umbrella
oo-k8a.

## Amendment (bead oo-luhd): a binding's slice beads, whose natives message the universe and the player

- Date: 2026-10-05. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSSystem.mm` and
  `OOJSSystem+ObjCBridge.h/.mm` after slices 1-2 of `docs/phases/3-slices/OOJSSystem.md` (beads
  oo-luhd, oo-yqoa), `tests/unit/core/test_OOJSSystem.mm`. Follows amendments oo-ppc, oo-6ia4,
  oo-nge8, oo-dqxj and oo-9ht.139, which says these sends go behind one-line functions.

**Context.** `OOJSSystem.mm` is the first binding converted slice by slice. It has no class of its
own: its slices are natives and helpers, almost every line of which messages the universe or the
player, and a few of which message a converted class (`OOJSScript`, `Entity`, the populator
definition) or send a category selector that each entity class answers (`-isVisibleToScripts`).
Its natives need the real engine to run, and the old test style (amendment oo-ppc item 6) would
stand in for half of the game.

**Decision (recommended defaults).**

1. **A binding with no class gets `X+ObjCBridge.h/.mm` of one-line send functions only** (amendment
   oo-9ht.139 item 3), with no façade. `X.mm` imports the bridge header; `X.h` does not, so the
   binding's callers see nothing new. `meson.build` lists `X+ObjCBridge.mm` after `X.mm`. A send
   repeated in several units is one function; the functions are grouped in the header by the
   class they message.
2. **A send to a converted class becomes a `cxx::` call, nil-guarded** (amendment oo-6ia4 item 2):
   `cxx::OOJSScript::currentlyRunningScript()` then `oo::ToCxx(script)->propertyNamed(...)`, null for
   no script; `[entity isPlayer]` is `oo::ToCxx(entity)->getIsPlayer()`.
3. **A category selector that entity classes answer each in their own way** (`-isVisibleToScripts`,
   implemented by the `OOJS*` bindings' categories) stays a message, in a bridge function
   (`OOJSSystemEntityIsVisibleToScripts(entity)`), even when the receiver's root is converted: the
   answer depends on the receiver's class.
4. **A converted class whose façade only alloc/init may make** (amendment oo-o89 item 2:
   `OOJSPopulatorDefinition`) is made by a bridge function that returns the façade retained
   (`OOJSSystemNewPopulatorDefinition()`, `OO_RETURNS_RETAINED`), held in
   `oo::ObjCRef` by `oo::adoptObjC` and used through `oo::ToCxx`; the reference is dropped where
   `-release` was.
5. **A slice converts only its units' bodies and the prototypes their signatures need** (a helper's
   `BOOL isGroup` parameter becomes `bool` with its prototype). Callers outside the slice that pass
   `YES`/`NO` compile unchanged.
6. **The binding's test runs the real engine**, linking the whole game but `main` (meson entry
   `['*']`, as `test_OOJSScript` does): `[OOJavaScriptEngine sharedEngine]` defines the binding's
   objects in the engine's own context, and the test evaluates JS there. The universe and the player
   are stand-in classes of other names (`FakeUniverse`, `FakePlayer`) stored in `gSharedUniverse`
   and `gOOPlayer` after the engine exists; they answer only the selectors the slices send and log
   what they are told. Entities are real `Entity` objects (a test subclass that is visible to
   scripts), so the engine's predicates, wrappers and `JSValueToEntity()` run unchanged. The same
   file runs on the Objective-C binding and on each converted slice; each slice adds its tests.

**Consequences.** One bridge file per binding, with a deletion bead that waits for `Universe` and
`PlayerEntity` (and, for a binding that wraps one, the entity class); no caller changes. The bridge
functions are the binding's list of what it still needs from unconverted classes.

## Amendment (bead oo-ft5n): a binding's category on a class that is still Objective-C, in a slice plan

- Date: 2026-10-06. Status: Proposed, as above. Exemplar: `src/Core/Scripting/OOJSPlayerShip.h/.mm` and
  `OOJSPlayerShip+ObjCBridge.h/.mm` after slices 1-3 of `docs/phases/3-slices/OOJSPlayerShip.md` (beads
  oo-ft5n, oo-9t14, oo-1qr5), `tests/unit/core/test_OOJSPlayerShip.mm`. Follows amendments oo-ykoy and
  oo-luhd.

**Decision (recommended defaults).**

1. **The category's methods become free functions in the plan's first slice** (amendment oo-ykoy
   item 1: `OOJSPlayerShipJSClassName()`, `OOJSPlayerShipSetJSSelf(player, ...)`,
   `OOJSPlayerShipJavaScriptEngineWillReset(player, ...)`), declared in `X.h` outside its
   `extern "C"` block, and the `@implementation` forwards to them from the same `X+ObjCBridge.mm`
   that holds the slices' send functions. `self->_ivar` in a body is `player->_cxxEntity->_ivar`.
2. **A body that sent another method of the same category, or a converted unit that sent one**
   (`[self javaScriptEngineWillReset:]` from the observer block, `[player setJSSelf:context:]` from
   `InitOOJSPlayerShip()`), calls its free function directly, with a comment: the receiver's class
   has no subclass that overrides the method, so dispatch picked that body anyway.
3. **A converted class the binding reaches through an unconverted one** (`[player hud]`, a
   `cxx::HeadUpDisplay`) is asked for by a bridge function and crossed with `oo::ToCxx`; many
   reads go through one file-local helper that answers the value-initialised result for a player
   with no HUD (`AskHud(player, &cxx::HeadUpDisplay::member)`, amendment oo-nge8 item 6), and a
   setter is `if (cxx::HeadUpDisplay *hud = HudOf(player))  hud->...;`. A setter that answered the
   HUD's `BOOL` answers `hud != nullptr && ...`.
4. **A helper of the slice whose parameter was a converted class's façade** and whose callers are
   all in the slice (`NormalizedColorComponents(OOColor *)`) takes the C++ class
   (`cxx::OOColor *`); a façade from an unconverted class crosses with `oo::ToCxx` at the call.
5. **A send function shared by several slices is added by the first slice that needs it**; later
   slices reuse it.

**Consequences.** The binding's bridge holds the category until `PlayerEntity` converts (its
deletion bead waits for oo-a70 as well as `Universe`, `GuiDisplayGen` and the engine's slices). The
test runs the real engine and the real `player.ship`, with stand-ins for what `PLAYER` and
`UNIVERSE` answer and a real HUD in a hidden GL context.

## Amendment (bead oo-riqmz): the class shell of a giant singleton that is not an entity (Universe)

- Date: 2026-10-06. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/Universe.md` "Slice 1". Exemplar: `src/Core/Universe.h/.mm`,
  `Universe+ObjCBridge.h/.mm`, `tests/unit/core/test_Universe.mm`. Follows amendments oo-bj8 items
  2, 4, 6 and 7 and oo-60fwo (the state moves first, the methods follow slice by slice).

**Context.** `Universe` (11,800 lines, ~390 methods, 122 ivars) converts in 26 slices. Slice 1 moves
its state into `cxx::Universe` so every later slice has a class to move its methods into. Unlike
`ShipEntity` it is no entity: no root owns its part, its superclass `OOWeakRefObject` keeps state,
and the Objective-C object is the game's one universe, `gSharedUniverse`, which about 150 files
message through `UNIVERSE`. Ten other files read its `@public` ivars (`n_entities`,
`sortedEntities`, the collision list heads, `cursor_row`, `stars_ambient`), and the unit tests of
the entities use a Universe that was never initialised (`class_createInstance`).

**Decision (recommended defaults).**

1. **The facade owns the part:** one `@public` ivar, `oo::Ref<cxx::Universe> _cxxUniverse`, and
   `cxx::Universe` is `oo::RefCounted` (the house's ownership, not a raw owning pointer). The part
   keeps a borrowed `_objcOwner`, so `oo::ToObjC(cxx::Universe *)` answers the object (a converted
   slice sends an unconverted method to it) and `oo::ToCxx(::Universe *)` answers `_cxxUniverse`.
   Every member keeps its ivar's name and type and is zero-initialised; the `@private` ones are public
   while the class is half converted (amendment oo-60fwo items 2 and 3).
2. **The rewrite is amendment oo-bj8 item 2's**, compiler-guided: `_cxxUniverse->` in the facade's
   unconverted methods and in the plain functions of `Universe.mm` that took the object
   (`uni->_cxxUniverse->x_list_start`), and `UNIVERSE->_cxxUniverse->n_entities` in the other
   files; proved by a poison-ivar syntax check of every TU that includes the header.
3. **The initialiser and `-dealloc` are a category of the facade in `Universe+ObjCBridge.mm`**
   (amendment oo-60fwo item 6), and their bodies are members: `-initWithGameView:` makes the part
   *first*, then does the one-universe check, `[super init]` and `_cxxUniverse->initWithGameView()`;
   `-dealloc` sends `_cxxUniverse->dealloc()`, releases the part and sends `[super dealloc]`. The
   member bodies stay in `Universe.mm` beside the private category they message, naming the object
   once (`::Universe *self = oo::ToObjC(this);`, amendment oo-bj8 item 4), so they are verbatim but
   for the Objective-C classes that now have a C++ twin, named `::X`. Making the part before the
   check keeps a refused second universe's teardown (its `[self release]` ran the whole `-dealloc`)
   as it was; a universe released with no part (allocated, never initialised) skips the body
   (oo-s6ic6). The part's remaining members (the property lists) are released when the facade
   releases it, just before `[super dealloc]`, as the runtime released the ivars then.
4. **`UNIVERSE`, `OOGetUniverse()` and `gSharedUniverse` stay the facade** (`@class Universe` before
   the C++ class in `Universe.h`); so do the `OOSound` / `OOSoundSource` category interfaces.
5. **A test's never-initialised Universe gets a part:** `class_createInstance` does not send
   `-initWithGameView:`, so the tests that ask such a universe for its state set
   `u->_cxxUniverse = oo::makeRef<cxx::Universe>(u)` where they made it, and read its members
   through it (amendment oo-bj8 item 11): a set-up line, no expectation changed. In this bead that
   was the set-up of the 22 entity tests that make one (`test_DustEntity` ... `test_WormholeEntity`,
   each crashed on a null part without it) and, in `test_Entity`, its ivar helper (by name, now the
   members) and its reads of the list heads and `n_entities` (`sUniverse->_cxxUniverse->`). Tests
   that stub `Universe` with their own `@interface` (they do not import `Universe.h`) are untouched.
6. **The deletion bead** "Delete Universe+ObjCBridge" waits on the umbrella oo-pas; it removes every
   `_cxxUniverse->`, makes the item 1 members private, and turns the members that hold Objective-C
   objects into `oo::Ref`/`oo::ObjCRef` as their classes convert.

**Consequences.** One more load per member read from unconverted code. Slices 2-26 each move their
methods into `cxx::Universe`, leave a forwarder on the facade and delete `_cxxUniverse->` from the
moved bodies.
## Amendment (bead oo-10qz): the JavaScript engine, whose later slice is the class's own block, and the file's categories on other classes

- Date: 2026-10-05. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Exemplar:
  `src/Core/Scripting/OOJavaScriptEngine.h/.mm`, `OOJavaScriptEngine+ObjCBridge.h/.mm`,
  `tests/unit/core/test_OOJavaScriptEngine.mm` after the four slices of
  `docs/phases/3-slices/OOJavaScriptEngine.md` (beads oo-10qz, oo-903c, oo-elta, oo-k4nu). Follows
  amendments oo-r7m0, oo-kq7, oo-ppc, oo-3bgz, oo-bwjb, oo-9ht.139 and oo-dqxj.

**Context.** `OOJavaScriptEngine` is the singleton that owns the JS runtime; about thirty files
message `[OOJavaScriptEngine sharedEngine]`, observe its reset notifications with the engine as the
sender, or adopt its monitor protocol. Its plan gives slice 1 the shell by named methods
(`-[OOJavaScriptEngine init]`, ...) and slice 2 the rest of the class by its block
(`@OOJavaScriptEngine`), the reverse of `OOOXZManager`'s plan, so amendment oo-bwjb's in-place
category would take slice 2's methods out of the block the plan names. The same file holds a
category on the root class (`OOObject (OOJavaScriptConversion)`, overridden by every scriptable
class), one on a converted class's façade (`OONativeVector`), two small classes whose instances
live in Objective-C collections (`OONull`, `OOJSValue`), free functions that send to entities,
weak references and the resource manager, and a stack dump inside `@autoreleasepool` with
`@catch (OOException *)`.

**Decision (recommended defaults).**

1. **When the plan names the later slice by the class's block, the bwjb split is mirrored.** The
   later slice's methods stay where they are, in the façade's primary `@implementation X` in `X.mm`,
   reading the C++ state through `oo::ToCxx(self)->` (amendment oo-3bgz item 1); the bridge header's
   main `@interface X` declares their selectors. The shell's selectors are declared by a category
   `@interface X (XShell)` in the bridge header and implemented, with `oo::ToObjC`/`oo::ToCxx`,
   `-initWithCxxX:` and `-dealloc`, by `@implementation X (XShell)` in `X+ObjCBridge.mm` (a
   category of the class reaches its private ivar). Both implementations are complete. The later
   slice moves its methods into `cxx::X` and the category becomes the façade's primary
   `@implementation`, with one forwarder per selector, in the old interface's order.
2. **A singleton that is a notification sender posts as its façade.** Observers filter on the
   object they got from `+sharedEngine`, so `reset()` posts with `oo::ToObjC(this)`, and a converted
   observer (`cxx::OOJSValue`) filters on `oo::ToObjC(cxx::OOJavaScriptEngine::sharedEngine())`.
   Calls that handed `self` to Objective-C (`OOJSTimeManagementInit`, the monitor's `-jsEngine:…`)
   hand the façade. `+sharedEngine` keeps one façade (amendment oo-r7m0 item 5); `sharedEngine()`
   records the engine before `init()` runs (amendment oo-3bgz item 3), as `-init` set
   `sSharedEngine = self` before it built the context.
3. **The monitor protocol and the `OOMonitorSupport` category move to the bridge header**
   (amendment oo-kq7 item 4); `X.h` keeps a forward `@protocol` for the member
   `oo::ObjCRef<id<OOJavaScriptEngineMonitor>> _monitor`. `[_monitor autorelease]; _monitor =
   [m retain];` is `[_monitor.leakRef() autorelease]; _monitor = oo::ObjCRef<…>(m);`. The private
   category another file declares only to type one send (`OOMonitorSupportInternal` in
   `OOJSGlobal+ObjCBridge.mm`, amendment oo-6ia4 item 6) is implemented by forwarders in
   `X+ObjCBridge.mm`, which declares it again for its own translation unit (a declaration in the
   bridge header would be a duplicate category in that file's).
4. **A category in the file on the root class or on a converted class's façade** follows amendment
   oo-ppc item 3: the bodies are free functions in `X.mm` named class + selector
   (`OOObjectJSDescription(id)`, `OONativeVectorJSValueInContext(cxx::OONativeVector *, …)`),
   declared in `X.h`, and the category's `@implementation` forwards to them from `X+ObjCBridge.mm`.
   A body that messaged `self` (`[self cxx_oo_jsClassName]`, `[self class]`, overridden by
   subclasses) sends through one-line bridges that take `id` (amendment oo-9ht.139 item 3), so the
   dynamic dispatch is unchanged. The root category's forwarders stay until the root class goes
   (Phase 4); the bridge's deletion bead says so.
5. **A small class whose instances are compared by identity in Objective-C collections**
   (`OONull`) is a `cxx::` singleton whose one façade lives as long as the process: `oo::ToObjC`
   answers that façade without a peer table (amendment oo-kq7 item 2), so `[OONull null]` and
   `oo::ToObjC(cxx::OONull::null())` are the same object. `-copyWithZone:` (`[self retain]`) is the
   façade's. **A value holder that callers make with `+alloc`** (`OOJSValue`) follows amendment
   oo-bhb9 items 1-3: `cxx::OOJSValue` with factories and a private `init…`, its façade's
   initialisers adopting the factory's result; the notification observer is `this` (amendment
   oo-kq7 item 6).
6. **`@catch (OOException *e)` in a converted free function** is `catch (...)` whose handler asks a
   one-line bridge, `XCaughtOOException(name, reason)`, which rethrows inside an Objective-C++
   `try` and answers whether the exception is an `OOException` (`-isKindOfClass:`, as `@catch` with
   a class matched); if not, the handler rethrows with `throw;`, as an unmatched `@catch` let it
   go on up. `[e name]`/`[e reason]` are the bridge's out-parameters. `@autoreleasepool` around it
   is `objc_autoreleasePoolPush`/`Pop` (amendment oo-bm1q item 4), skipped by a rethrow as the pool
   was. `@try`/`@catch (id)` that only squashed errors is `try`/`catch (...)` (amendment oo-ja7y
   item 4).
7. **Sends to an entity in a converted free function** go through one-line bridges on `Entity *`
   (amendment oo-nge8 item 5: entities are messaged as the Objective-C `Entity` while their
   subclasses are Objective-C); a converted leaf the code casts to (`OOPlanetEntity`) is reached
   with `oo::ToCxx`.
8. **The test is a whole-game test** (`['*']`, as `test_OOJSScript`'s): the real engine, a scratch
   home, the log captured through `oo::log::logger().setSink`, and a test monitor; it pins the
   engine's API, the log text of errors and warnings, the stack dump of a `debugger` statement,
   value descriptions, the value holders and converters, the object wrapper and the predicates.

**Consequences.** One bridge pair (`OOJavaScriptEngine+ObjCBridge.h/.mm`) holds the engine,
`OONull` and `OOJSValue` façades, the root and `OONativeVector` categories and the one-line
bridges; its deletion bead waits for the engine's callers (the player, the universe, the debug
support, the bindings), the classes the bridges message, and, for the root category, Phase 4.
Converted classes that message the engine from inside `namespace cxx` (`OODebugMonitor`,
`OOJSScript`, `OOJSTimer`, `OOJSFunction`, the GUI/interface/populator definitions,
`OORegExpMatcher`) now name the façade `::OOJavaScriptEngine`, since `cxx::OOJavaScriptEngine`
hides it there (and later `::OONull`, `::OOJSValue`); no other caller changed: every selector,
type and sender is the same. The test pins the reporter's guard of a report with no `linebuf`
(which the QuickJS backend never sets; bead oo-9ht.142), found again by this test.

## Amendment (bead oo-mvzmb): ShipEntity's later slices, members an Objective-C subclass overrides, and the ship's adapter

- Date: 2026-10-06. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/ShipEntity.md` slices 2-12. Exemplar: `src/Core/Entities/ShipEntity.h/.mm`,
  `ShipEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_ShipEntity.mm`. Follows amendments oo-60fwo
  (the class shell), oo-vl43 (an intermediate class's adapter) and oo-72cz (a later slice).

**Context.** Each later slice of `ShipEntity.mm` moves its methods into `cxx::ShipEntity` while the
class's `@implementation` stays in the file for the slices still to come, and three workers convert
slices of the file at once. `StationEntity`, `DockEntity`, `PlayerEntity` and the unit tests'
ships are Objective-C subclasses that override some of the moved selectors
(`-setUpShipFromDictionary:`, `-setUpSubEntities`, `-update:`, ...), and the façade's adapter was
the root's template, which messages only the root's virtual members.

**Decision (recommended defaults).**

1. **A slice's members are a `namespace cxx` block of their own after the `@implementation`**, in
   the file's order, under a comment naming the slice and its bead; their declarations are a block
   in `cxx::ShipEntity` under the same comment. The façade's forwarders are a category per slice,
   `ShipEntity (OOSliceN)`, in `ShipEntity+ObjCBridge.mm`, and each forwarded declaration moves from
   the primary `@interface` to that category's `@interface` in the bridge header (amendment oo-60fwo
   item 6: the primary `@implementation` stays complete). A selector the class did not declare in
   its interface (its private category, a protocol's, a root's) is declared in the slice's
   category. One block per slice keeps the workers' merges to adjacent, independent hunks.
2. **A member an Objective-C subclass overrides is `virtual`, and the ship's adapter gets its
   line.** The adapter is `ObjCShipEntity`, private to `ShipEntity+ObjCBridge.mm`, derived from
   `oo::ObjCEntity<cxx::ShipEntity>` (as `ObjCLightParticleEntity` is, amendment oo-vl43) and made
   by the façade's `-initShipPart`; each slice that makes a member virtual adds its override, which
   messages the Objective-C object. A member that overrides a virtual member of `cxx::Entity`
   (`frustumRadius()`, `descriptionComponents()`, `update()`) is `override`, and the root's
   template already has its line.
3. **The forwarder of such a member calls `cxx::ShipEntity`'s own member**,
   `_cxxShip->cxx::ShipEntity::setUpShipFromDictionary(dict)`, which is what `[super ...]` from a
   subclass (or not overriding) reached; a call through the virtual would come back to the
   subclass. Every ship has the adapter, so no `oo::AsObjCEntity` test is needed.
4. **Sends to `self` in a moved body stay sends** to the façade (`::ShipEntity *self =
   oo::ToObjC(this)` at the top, as slice 1's member does), so a subclass's override still runs and
   a selector of a slice not yet landed still answers. `[super x]` becomes the base class's member,
   qualified (`OOEntityWithDrawable::descriptionComponents()`); in a `const` member `self` is
   `oo::ToObjC(const_cast<ShipEntity *>(this))`.
5. **A parameter or result typed `Entity<OOSubEntity> *` is `::Entity *` in the member**: C++
   takes no protocol qualifier after a qualified name. The façade's forwarder keeps the Objective-C
   signature (and casts a result back to the qualified type).
6. **A protocol the ship adopts whose methods a slice forwards** (`<OOBeaconEntity>`, slice 5) is
   adopted by a category with no `@implementation`, `ShipEntity (OOBeaconEntity)`, instead of the
   class's interface: a category that implements a method of a protocol the class itself adopts is
   warned about as one the class will implement (`-Wobjc-protocol-method-implementation`), and a
   warning is not silenced (CLAUDE.md rule 3). The ship conforms as before.
7. **Tests:** each slice adds its cases to `test_ShipEntity.mm` under a comment naming the slice,
   written against the façade and run on the unconverted class first; a ship that keeps
   `ShipEntity`'s own set-up is a subclass with no overrides (`PlainShip`).

**Consequences.** One adapter class for the ship, one category per slice on the façade; the
façade's deletion bead (oo-9ht.144) removes them with the forwarders.

## Amendment (bead oo-xmajv): ShipEntity slices 13-23, beyond amendment oo-mvzmb

- Date: 2026-10-06. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/ShipEntity.md` slices 13-23 (beads oo-xmajv … oo-xmrgd), stacked on slices
  2-12. Exemplar: `src/Core/Entities/ShipEntity.h/.mm`, `ShipEntity+ObjCBridge.h/.mm`,
  `tests/unit/core/test_ShipEntity.mm`. Follows amendment oo-mvzmb, whose seven items these slices
  keep (a block and a category per slice, `ObjCShipEntity`, sends to `self` stay sends).

**Decision (recommended defaults).**

1. **A parameter the moved body never reads is named in a comment** (`double /*delta_t*/`), as the
   debug monitor's members are: `-Wunused-parameter` (in `-Wextra`) warns about a C++ function's
   unused parameter and never did about an Objective-C method's, and a warning is not silenced
   (CLAUDE.md rule 3).
2. **The ship's other protocol, `<OOSubEntity>`, is adopted by a category with no
   `@implementation` once a slice forwards one of its methods** (slice 16,
   `-drawSubEntityImmediate:translucent:`), for amendment oo-mvzmb item 6's reason.
3. **A method that overrides one of `Entity`'s and takes an Objective-C object** (`-setOwner:`)
   becomes the `override` of the root's virtual with the root's C++ types (`cxx::Entity *`); the
   façade's forwarder converts (`oo::ToCxx(who)`), as slice 6's `-checkCloseCollisionWith:` does.
4. **The tests** set a ship's target through the helper `SetPrimaryTarget()`, not `-addTarget:`,
   which tells the ship's scripts (the unit tests' ships have no JavaScript object).

## Amendment (bead oo-zd80m): ShipEntity slices 24-34, a block converted beside the others

- Date: 2026-10-06. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/ShipEntity.md` slices 24-34 (beads oo-zd80m, oo-k6wuw, oo-v92af, oo-pnfyp,
  oo-40ocf, oo-g900k, oo-ogoct, oo-gx86h, oo-5e0ny, oo-tz2ra, oo-nkyn3). Exemplar:
  `src/Core/Entities/ShipEntity.h/.mm`, `ShipEntity+ObjCBridge.h/.mm`,
  `tests/unit/core/test_ShipEntity.mm`. Follows amendment oo-60fwo (the class shell) and the
  conventions of amendment oo-mvzmb (slices 2-12), which this block repeats in short so that it
  stands whichever block lands first.

**Context.** Three workers convert slices of `ShipEntity.mm` at once (2-12, 13-23, 24-34), each
block stacked on `main` and on nothing of the others'. The later slices move the ship's target
memory, tracking, weapons, missiles, collisions, damage, docking, comms and script events; the
Objective-C subclasses (`PlayerEntity`, `StationEntity`, `DockEntity`, `ProxyPlayerEntity`)
override a good part of them.

**Decision (recommended defaults).**

1. **As amendment oo-mvzmb items 1-5 and 7:** a slice's members are a `namespace cxx` block of
   their own after the `@implementation`, under a comment naming the slice and its bead, declared
   in a block of `cxx::ShipEntity` under the same comment; the façade forwards each selector from
   a category `ShipEntity (OOSliceN)` in `ShipEntity+ObjCBridge.mm`, and the selector's declaration
   moves to that category's `@interface` in the bridge header (one the class did not declare is
   declared there). Sends to `self` in a moved body stay sends (`::ShipEntity *self =
   oo::ToObjC(this)`), so a subclass's override still runs and a selector of a slice not yet
   landed still answers. Each slice adds its `OO_TEST(sliceN...)` cases to `test_ShipEntity.mm`,
   written against the façade and run on the unconverted class first.
2. **A member an Objective-C subclass overrides is `virtual` and gets a line in the ship's adapter
   `ObjCShipEntity`** (private to `ShipEntity+ObjCBridge.mm`, derived from
   `oo::ObjCEntity<cxx::ShipEntity>`, made by `-initShipPart`), which messages the Objective-C
   object; its forwarder calls `cxx::ShipEntity`'s own member (`_cxxShip->cxx::ShipEntity::m()`),
   which is what `[super ...]` reached. A member that overrides a virtual member of `cxx::Entity`
   (`throwSparks()`, `getVelocity()`, `takeEnergyDamage()`, `dumpSelfState()`,
   `descriptionForObjDump()`) is `override`; the root's template already has its line. The block
   that lands first adds the adapter class; a merge with another block keeps one class and every
   block's lines, each under its slice's comment.
3. **Every Objective-C class named in a member is written `::X`**, whether or not a `cxx::X`
   exists yet (`::StationEntity *`, `[::OOColor ...]`): classes are converting under the block,
   and a bare name that a later `cxx::X` captures breaks the build on a merge (p3-resume note of
   2026-10-06 03:00). Protocol qualifiers drop after `::X` (oo-mvzmb item 5).
4. **A member whose selector names a data member is `getX`** (`-behaviour` is `getBehaviour()`,
   `-coordinates` `getCoordinates()`, `-isDemoShip` `getIsDemoShip()`), as slice 11's `getThrust()`;
   `-velocity` is `getVelocity()`, the root's virtual.
5. **The forwarder keeps the Objective-C signature**; a result the member answers as a plainer
   type (`::Entity *` for `Entity<OOSubEntity> *`) is cast back in the forwarder.

6. **A unit inside a preprocessor condition keeps it** around its member, declaration and
   forwarder (`#if OO_SALVAGE_SUPPORT` for the salvage methods, `#ifndef NDEBUG` for
   `dumpSelfState()` and `descriptionForObjDump()`, as `cxx::Entity` declares them).
7. **A `[super x]` that still reaches the root after a slice makes `x` a `cxx::ShipEntity`
   override** is pointed at the root's member by name in the unconverted method
   (`_cxxShip->cxx::OOEntityWithDrawable::getVelocity()` in `-update:`, slice 30): the root's
   `-velocity` answers `superGetVelocity()`, which is now the ship's.
8. **A C function the plan assigns to a slice loses its messages without a new interface**
   (`--slice-done` counts any Objective-C syntax in it): `AuthorityPredicate()` (slice 33) gets
   the two answers it messaged for in its parameter, read once by its only caller;
   the shader and weapon-range helpers (slice 34) call `cxx::ResourceManager`,
   `cxx::OOEquipmentType` and the entity's C++ part, and ask the runtime for the binding target's
   class (`-isPlayerLikeShip` is YES for exactly `PlayerEntity` and `ProxyPlayerEntity`).

**Consequences.** One adapter class for the ship whichever block lands first; the façade's
deletion bead removes the categories, the forwarders and the adapter's lines.

## Amendment (bead oo-64ako): the class shell of an Objective-C subclass of the half-converted ShipEntity (StationEntity)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/StationEntity.md` slice 1. Exemplar: `src/Core/Entities/StationEntity.h/.mm`,
  `StationEntity+ObjCBridge.h/.mm`, `ShipEntity+ObjCAdapter.h`, `tests/unit/core/test_StationEntity.mm`.
  Follows amendments oo-60fwo (ShipEntity's class shell) and oo-mvzmb / oo-zd80m (its later slices).

**Context.** `StationEntity` is the first subclass of `ShipEntity` to convert. The ship's C++ part
is made by the ship's façade (`-initShipPart`) as the adapter `ObjCShipEntity`, private to
`ShipEntity+ObjCBridge.mm`, over `cxx::ShipEntity`; a station's part must be a
`cxx::StationEntity` and still carry every line of that adapter, since the station's unconverted
methods and the Objective-C ship methods it overrides are reached from C++ through them.

**Decision (recommended defaults).**

1. **The subclass shell is amendment oo-60fwo's, one level down:** `cxx::StationEntity :
   cxx::ShipEntity` holds the ivars as public, zero-initialised members with their names, and the
   façade `@interface StationEntity : ShipEntity` carries one `@public`, borrowed, typed alias,
   `cxx::StationEntity *_cxxStation`, set by its override of `-initWithCxxEntity:` (a checked
   `dynamic_cast`). Unconverted station code reads its ivars as `_cxxStation->alertLevel` (the
   compiler-guided rewrite of oo-60fwo item 1); typed `oo::ToCxx(::StationEntity *)` and
   `oo::ToObjC(cxx::StationEntity *)` are the root's crossings, `static_cast`.
2. **The ship's adapter becomes a template, `oo::ObjCShipEntity<Base>`,** moved unchanged (each
   line's `_objcOwner` is `this->_objcOwner`, the base being dependent) to the private header
   `ShipEntity+ObjCAdapter.h` with the façade's private `-initShipPart`. The ship's façade makes
   `ObjCShipEntity<cxx::ShipEntity>`; the station's façade overrides `-initShipPart` to make
   `ObjCShipEntity<cxx::StationEntity>`. Every later ship slice still adds its lines in one place;
   `PlayerEntity` and `DockEntity` take the same route when they convert.
3. **Slice 1's units are members of `cxx::StationEntity`** in one `namespace cxx` block after the
   `@implementation`, forwarded by the category `StationEntity (OOSlice1)` in the bridge `.mm`,
   whose `@interface` in the bridge header takes their declarations from the primary interface
   (amendment oo-mvzmb item 1). The initialiser (`-cxx_initWithKey:definition:`, three assignments
   after `[super ...]`) and `-dealloc` (with the root's no-part guard) are the façade's category
   `StationEntity (OOObjCBridge)`, as oo-60fwo item 6. Members that override the ship's
   (`isUnpiloted`, `setUpShipFromDictionary`, `setUpSubEntities`, `descriptionComponents`,
   `dumpSelfState`) are `override`; their forwarders call `cxx::StationEntity`'s own member and a
   `[super x]` in a moved body is `ShipEntity::x()`. Getters named like a member take `get`
   (amendment oo-zd80m item 4: `getEquivalentTechLevel()`, `getPlanet()`, `getHasNPCTraffic()`).
4. **Tests:** `test_StationEntity.mm` (['*'], as `test_ShipEntity`), against the façade, run on the
   unconverted class first; its station is a subclass whose only override is the virtual dock's
   `-cxx_setUpOneStandardSubentity:asTurret:` (the dock is a shipdata entry).

**Consequences.** One more façade (`StationEntity+ObjCBridge`, deletion bead filed with this one);
`ShipEntity+ObjCBridge`'s deletion bead also deletes `ShipEntity+ObjCAdapter.h`. Slices 2-4 each
move their units into `cxx::StationEntity` and drop `_cxxStation->` from them.

## Amendment (bead oo-42dr): ShipEntity's category files, after the class's last slice

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Exemplar:
  `src/Core/Entities/ShipEntityScriptMethods.h/.mm` (bead oo-42dr), `ShipEntityLoadRestore.h/.mm`
  (bead oo-kw44), the blocks of `ShipEntity.h` and `ShipEntity+ObjCBridge.h/.mm` naming them,
  `tests/unit/core/test_ShipEntity.mm`. Follows amendments oo-o89 item 4, oo-9fwb and oo-mvzmb.

**Context.** `ShipEntityScriptMethods.mm` and `ShipEntityLoadRestore.mm` are categories of
`ShipEntity` in files of their own, converted after the 34 slices of `ShipEntity.mm`. Their
callers are Objective-C (`OOJSShip`, the legacy script engine) or C++ that still messages the
façade (`cxx::WormholeEntity`, `cxx::ShipEntity::spawn()`).

**Decision (recommended defaults).**

1. **The category's methods become members of `cxx::ShipEntity`, defined in the category's own
   file** in a `namespace cxx` block, and declared in a block of `cxx::ShipEntity` under a comment
   naming the category and its bead (amendment oo-o89 item 4). A class method is a static member
   (`shipRestoredFromDictionary()`, which answers `::ShipEntity *` where it answered `id`); a
   method of a private category of the file (`LoadRestoreInternal`) is a member like the others,
   public while the class is half converted (amendment oo-60fwo item 2). Sends to `self` stay sends
   to the façade (amendment oo-mvzmb item 4).
2. **The category's `@interface` moves to `ShipEntity+ObjCBridge.h`, and its forwarders to
   `ShipEntity+ObjCBridge.mm`**, under the category's own name, not to bridge files of the
   category's file (amendment oo-9fwb item 2): the façade is the ship's, and its deletion bead
   (oo-9ht.144) removes every forwarding category at once.
3. **The category's header stays**, for the files that import it, with what it declared that is
   not the category (`OOShipSaveContext`); `ShipEntity.h` forward-declares such a type for its
   members.
4. **The tests** pin the cases that reach neither the uninitialised universe nor the ship
   registry (whose data the unit test does not load: it would scan for add-ons); the goldens run
   the rest.

**Consequences.** No `@implementation` is left in the ship's category files; their callers are
unchanged and reach the members through the façade until their own conversion.

## Amendment (bead oo-iebuz): ShipEntityAI.mm, a category file converted slice by slice

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/ShipEntityAI.md` (beads oo-iebuz, oo-xurzn, oo-wc9o3, oo-lqyhf). Exemplar:
  `src/Core/Entities/ShipEntityAI.h/.mm`, the blocks of `ShipEntity.h`, `StationEntity.h` and the
  two façades' bridge files naming them, `tests/unit/core/test_ShipEntityAI.mm`. Follows amendments
  oo-42dr (the ship's category files), oo-mvzmb (later slices) and oo-64ako (the station's shell).

**Context.** `ShipEntityAI.mm` holds four categories of `ShipEntity` (`AI`, `PureAI`,
`OOAIPrivate`, the macro-generated `OOAIStationStubs`) and one of `StationEntity`
(`OOAIPrivate`), in four slices; `PureAI` alone spans slices 2-4.

**Decision (recommended defaults).**

1. **Amendment oo-42dr per slice:** the slice's methods are `cxx::ShipEntity` members defined in a
   `namespace cxx` block at the end of `ShipEntityAI.mm`, declared in a block of `cxx::ShipEntity`
   naming the slice. A category the slice empties (`AI`, `OOAIPrivate`; `PureAI` at slice 4) keeps
   its name: its `@interface` moves whole to `ShipEntity+ObjCBridge.h` and its forwarders to
   `ShipEntity+ObjCBridge.mm`. A category the slice only thins (`PureAI` at slices 2 and 3)
   forwards from `ShipEntity (OOAISliceN)`, whose `@interface` takes the moved declarations from
   the private one, so the category's remaining `@implementation` stays complete. A selector no
   interface declared (`-performBuoyTumble`) is declared with its category's.
2. **The station's unit is a member of `cxx::StationEntity`** (`acceptDistressMessageFrom()`,
   `override` of the ship's, which is `virtual` and has its line in `oo::ObjCShipEntity`); its
   category's `@interface` and forwarder move to `StationEntity+ObjCBridge.h/.mm`.
3. **The macro-generated stubs are written out as members** (`increaseAlertLevel()` …
   `abortAllDockings()`), each logging through one file-local function, and forwarded by an
   implementation-only `ShipEntity (OOAIStationStubs)` in the bridge `.mm`, as the macros made it:
   `StationEntity` declares the selectors with its own return types. They are not virtual: nothing
   calls them from C++, AI plists send them by name, and the station's `-launchDefenseShip` answers
   a ship where the stub answered nothing, which no C++ override can.
4. **`ShipEntity.h` repeats `Universe.h`'s `EntityFilterPredicate` typedef** for the scans'
   members (amendment oo-42dr item 3).

**Consequences.** `ShipEntityAI.h` keeps only its imports for the files that import it; the
ship's façade deletion bead (oo-9ht.144) removes the forwarding categories with the others.

## Amendment (bead oo-18mg2): a binding's slices over an entity whose class is C++ behind its façade (OOJSShip)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/OOJSShip.md` (beads oo-18mg2, oo-chjz4, oo-08plt, oo-hqe5l, oo-qzn25,
  oo-ljuy1). Exemplar: `src/Core/Scripting/OOJSShip.mm` and `OOJSShip+ObjCBridge.h/.mm` after slice
  1, `tests/unit/core/test_OOJSShip.mm`. Follows amendments oo-luhd, oo-ft5n and oo-9ht.139, whose
  item 2 says the sends to the wrapped class become member calls once it is C++.

**Decision (recommended defaults).**

1. **A native takes the façade from its JS object as before and crosses once**:
   `cxx::ShipEntity *ship = oo::ToCxx(entity);` after the stale-entity check, so it is not null.
   A send to the ship becomes the member its façade forwarder calls (`-fuel` is `getFuel()`,
   `-isFrangible` is `getIsFrangible()`; the forwarder in `ShipEntity+ObjCBridge.mm` is the
   table). A forwarder that calls the member qualified (`_cxxShip->cxx::ShipEntity::getBounty()`)
   marks a member an Objective-C subclass overrides: it is `virtual` with its line in
   `oo::ObjCShipEntity`, so the native calls it unqualified and the player's override still answers.
   A selector a subclass overrides whose member is not virtual stays a bridge send (amendment
   oo-9ht.139 item 3) until the ship's slices make it so.
2. **A selector of the player alone** (`-availableFacings`, `-fleeingStatus`, after an `isPlayer`
   test) is a bridge function taking the cast façade, `OOJSShipPlayerAvailableFacings(pent)`.
3. **What the ship hands out that is converted** (`AI`, `OORoleSet`, `OOShipGroup`, `OOColor`) is
   crossed with `oo::ToCxx` at the use and null-guarded; repeated reads through one (the AI's name,
   state, suspended machines) go through one file-local helper each, as `AskHud()` does (amendment
   oo-ft5n item 3). A box the native made as an Objective-C object for JavaScript
   (`OONativeVector`) is made as its C++ class and handed over as `oo::ToObjC(box)`.
4. **A category method on the wrapped class that no subclass overrides and that forwards to a free
   function** (`-subEntitiesForScript`, `ShipEntityJSSubEntitiesForScript()`) is that function,
   called with the façade (amendment oo-ft5n item 2).
5. **The test** makes a real ship with `ShipEntity`'s own set-up (`PlainShip`, a definition in the
   test) in a never-initialised `Universe` with a plain entity as `PLAYER` (test_ShipEntity.mm's
   set-up), next to the real engine (test_OOJSPlayerShip.mm's), and binds the ship's JS object to a
   global; the player branches read the engine's own player with its class swapped for a test
   subclass that answers the player's selectors. Each later slice adds its natives' cases.

**Consequences.** `OOJSShip+ObjCBridge.mm` holds only sends to the player and the universe (and
other unconverted classes); its deletion bead waits for oo-pas and oo-a70.

## Amendment (bead oo-27jxj): Universe slices 2-13, a singleton's later slices

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/Universe.md` slices 2-13 (beads oo-27jxj, oo-ef6rc, oo-ni9u8, oo-d0i7y,
  oo-15e3o, oo-49wmm, oo-m0rz6, oo-hkvet, oo-e9enf, oo-8rsqz, oo-9lucq, oo-0uz9w), one stacked
  chain on `main`; slices 14-26 are another worker's block on the same terms. Exemplar:
  `src/Core/Universe.h/.mm`, `Universe+ObjCBridge.h/.mm`, `tests/unit/core/test_Universe.mm`.
  Follows amendments oo-riqmz (the class shell) and oo-zd80m (ShipEntity's later slices).

**Context.** Slice 1 moved the universe's state into `cxx::Universe`; its ~390 methods stay in the
facade's `@implementation` in `Universe.mm` until their slice. `Universe` has no subclasses, so
none of ShipEntity's adapter or `virtual` machinery applies.

**Decision (recommended defaults).**

1. **As amendment oo-zd80m item 1:** a slice's members are a `namespace cxx` block of their own
   after the facade's `@implementation` (before slices 14-26's blocks, in slice order), under
   a comment naming the slice and its bead, declared in a block of `cxx::Universe` under the same
   comment. The facade forwards each selector from a category `Universe (OOSliceN)` in
   `Universe+ObjCBridge.mm`, and the selector's declaration moves to that category's `@interface`
   in `Universe+ObjCBridge.h` (with a comment that headed only moved declarations): from the
   facade's `@interface`, or from the private category `Universe (OOPrivate)` in `Universe.mm`,
   which loses it. The bodies are verbatim but for the deleted `_cxxUniverse->`.
2. **Sends to `self` stay sends** to the facade (`::Universe *self = oo::ToObjC(this);` at the
   top), so a selector of a slice not yet landed still answers. Every Objective-C class named in a
   member is `::X` (amendment oo-zd80m item 3); a member's signature takes no protocol qualifier
   (`::Entity *` for `Entity <OOBeaconEntity> *`), and its forwarder casts the result back;
   the beacon members of slice 9, whose bodies message the beacon protocol, take and answer
   `OOBeaconEntityObject *` instead, the file-scope typedef `OOWaypointEntity.h` has, repeated in
   `Universe.h`.
3. **A member whose name would be a data member's is `getX`** (`-doProcedurallyTexturedPlanets`
   is `getDoProcedurallyTexturedPlanets()`, `-cxx_useAddOns` `getUseAddOns()`), as amendment
   oo-zd80m item 4; `cxx_` drops as usual. Two selectors whose first keywords and parameter types
   are the same get the keyword that tells them apart (`-cxx_addShips:withRole:atPosition:...` is
   `addShipsAtPosition()`, the two `...nearPosition:...` forms are `addShipsNearPosition()`
   overloads); different parameter types stay overloads (`addShipWithRole()`).
4. **A unit inside a preprocessor condition keeps it** around its member, declaration, category
   declaration and forwarder (`#ifndef NDEBUG` for `-debugDumpEntities` and `-cxx_entityList`).
5. **Tests:** `test_Universe.mm` gains an `OO_TEST(sliceN...)` per slice under one comment, for the
   units a universe that was never initialised can answer, written against the facade and run on
   the unconverted class first. A slice none of whose units runs without the player, the GUI or
   the game controller (slice 3: pausing, quitting, the set-up from a station or witchspace) adds
   none; the goldens pin it.

6. **A parameter the moved body never reads is named in a comment** (`::StationEntity * /*carrier*/`
   in `carryPlayerOn()`, slice 3), as amendment oo-xmajv item 1: `-Wunused-parameter` and
   clang-tidy's `misc-unused-parameters` flag a C++ function's unused parameter and never did an
   Objective-C method's. Two moved lines whose text changed only by the rewrite carry clang-tidy
   findings the old lines had (tier-a counts a changed line's findings as new): their expressions
   are restated with the same behaviour (`-cxx_shipClassForShipDictionary:`'s class choice as an
   `if`, slice 9; `-drawWatermarkString:`'s integer halves named first, slice 13).

**Consequences.** One category per slice on the facade; the facade's deletion bead (oo-ql9rn)
removes them with the forwarders.

## Amendment (bead oo-7jhs5): Universe slices 14-26, the universe's methods moved slice by slice

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/Universe.md` slices 14-26 (beads oo-7jhs5, oo-dg9d1, oo-focfo, oo-gr7a2,
  oo-tail0, oo-z3u03, oo-lftoq, oo-enek8, oo-05ow5, oo-ni1hw, oo-jxitg, oo-wmc72, oo-32kcu),
  stacked on `main`. Exemplar: `src/Core/Universe.h/.mm`, `Universe+ObjCBridge.h/.mm`,
  `tests/unit/core/test_Universe.mm`. Follows amendment oo-riqmz (the class shell) and the
  conventions of amendments oo-mvzmb and oo-zd80m (ShipEntity's later slices), repeated here in
  short so that they stand whichever block of Universe slices lands first.

**Decision (recommended defaults).**

1. **As amendment oo-mvzmb item 1:** a slice's members are a `namespace cxx` block of their own at
   the end of `Universe.mm`, under a comment naming the slice and its bead, declared in a block at
   the end of `cxx::Universe` under the same comment; `_cxxUniverse->` is deleted from the moved
   bodies. The facade forwards each selector from a category `Universe (OOSliceN)` in
   `Universe+ObjCBridge.mm`, and the selector's declaration moves, comment and all, from the
   primary `@interface` (or the private category in `Universe.mm`) to that category's `@interface`
   in the bridge header; a selector nothing declared is declared there. `Universe` has no
   subclasses, so no member is virtual and no adapter is needed.
2. **Sends to `self` stay sends** (`::Universe *self = oo::ToObjC(this);` first in the member), so
   a selector of a slice not yet landed still answers; every Objective-C or converted class named
   in a member is written `::X` (amendment oo-zd80m item 3).
3. **Names:** a member is its selector's first keyword without `cxx_`, overloaded where selectors
   share it (`addMessage()`, `countShipsWithRole()`); a getter whose selector names a data member
   is `getX()` (`getViewDirection()`, `getTimeAccelerationFactor()`, `getECMVisualFXEnabled()`,
   amendment oo-zd80m item 4). `BOOL` parameters and results are `bool`; `id` results stay `id`.
4. **A unit inside a preprocessor condition keeps it** (the two arms of the time-acceleration
   accessors, amendment oo-zd80m item 6); a parameter one arm never reads is named in a comment
   (amendment oo-xmajv item 1).
5. **A C function the plan assigns to a slice loses its Objective-C without a new interface**:
   `AutoreleaseAll()` (slice 17) hands each element to the pool with the runtime's
   `objc_autorelease()`, which is what `-autorelease` did for these classes (none overrides it).
6. **The file's private holder class `OOUniverseDelayedMessage`** is forward-declared in
   `Universe.h` (`@class`) for the member and the category declaration of `-addDelayedMessage:`
   (slice 16).
7. **Tests:** each slice adds `OO_TEST(sliceN...)` cases to `test_Universe.mm` under a comment
   naming the slice and bead, written against the facade and run on the unconverted class first;
   the entities they need sit in the universe's lists by hand (`SetSortedEntities()`,
   `LinkLists()`), set-up lines through `_cxxUniverse` as amendment oo-riqmz item 5's.

**Consequences.** One category per slice on the facade; the facade's deletion bead (oo-ql9rn)
removes the categories and forwarders with the rest.

## Amendment (bead oo-9ht.107): deleting an entity subclass's façade while the root's stands

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Exemplar:
  the first entity-subclass façade deletions, beads oo-9ht.107 (`OOFlasherEntity+ObjCBridge`) and
  oo-9ht.110 (`OOExhaustPlumeEntity+ObjCBridge`): `src/Core/Entities/Entity.h/.mm`,
  `src/Core/Scripting/EntityOOJavaScriptExtensions+ObjCBridge.mm`, `OOFlasherEntity.h/.mm`,
  `OOJSFlasher.h/.mm`, `ShipEntity.h/.mm`, `OOVisualEffectEntity.h/.mm` and their bridge files,
  `tests/unit/core/test_OOFlasherEntity.mm`, `test_OOJSFlasher.mm`,
  `test_EntityOOJavaScriptExtensions.mm`. Follows amendment oo-9ht.12 (deleting a façade).

**Context.** A converted entity leaf's object is the façade `oo::NewEntityFacade` picks. Once its
own façade is gone (amendment oo-9ht.12 item 6) the object is the nearest façade left
(`OOLightParticleEntity`'s for a flasher, the root `Entity`'s for a plume), and the selectors the
deleted façade alone answered have no receiver: the engine's JS questions
(`-getJSClass:andPrototype:`, `-cxx_oo_jsClassName`, `-isVisibleToScripts`, moved onto the leaf
façades by oo-9ht.49/oo-9ht.48) and the protocol `OOSubEntity` that owners send their subentities
(`-rescaleBy:`, `-rescaleBy:writeToCache:`, `-drawSubEntityImmediate:translucent:`). The root's own
façade stays until oo-9ht.39, so the engine still asks by selector.

**Decision (recommended defaults).**

1. **The root category's JS class questions ask the C++ part.** `cxx::Entity` has three virtual
   members, `getJSClass(ooscript::ClassDef **, ooscript::Object *)`, `jsClassName()` and
   `isVisibleToScripts()`, whose defaults call the category's bodies (`EntityJSGetJSClass`,
   `EntityJSClassName`, `EntityJSIsVisibleToScripts`). `Entity (OOJavaScriptExtensions)` forwards
   its three methods to `_cxxEntity`. An Objective-C class or façade that implements the selectors
   (`ShipEntity (OOJavaScriptExtensions)`, `PlayerEntity`, the planet, sun, wormhole and waypoint
   façades) still answers first by Objective-C dispatch, so nothing else changes.
   **`oo::ObjCEntity` does not forward them**: the category reaches the C++ part only for an
   Objective-C entity with no override of its own, and a forwarding adapter would send the
   selector back to the category, which would call the adapter again. The header says so.
2. **A deleted leaf façade's JS forwarders become `override`s on the C++ class** that call the
   binding's functions that held the bodies (`OOJSFlasherGetJSClass` …). The leaf test's
   `jsExtensions` case keeps its expectations and now sends the selectors to the object the
   callers get; `test_EntityOOJavaScriptExtensions` gains a case pinning the root path (a plain
   C++ entity answers the defaults, a C++ subclass its overrides, an Objective-C override first).
3. **`OOSubEntity` gets a C++ interface for façade-less subentities,** `cxx::OOSubEntityInterface`
   in `Entity.h` (its three methods as pure virtuals; not named `OOSubEntity`, because inside
   `namespace cxx` the protocol-qualified type `Entity<OOSubEntity>` would then read a class as
   its argument). A converted leaf whose façade goes adopts it as a second base. Each owner that
   sent a subentity one of the protocol's selectors asks first
   (`if (OOSubEntityInterface *cxxSub = dynamic_cast<OOSubEntityInterface *>(oo::ToCxx(se)))
   cxxSub->rescaleBy(f); else [se rescaleBy:f];`), so a ship or visual-effect subentity, whose
   façade answers, is unchanged. The protocol itself goes with the last façade that adopts it.
4. **Lists of a deleted leaf's objects keep the objects, typed as the root façade.** An enumerator
   the scripting bindings turn into JS values (`-flasherEnumerator`, `-cxx_exhausts`, read by
   `OOJSShip`'s `PListFromObjects`) answers `std::vector<oo::ObjCRef<::Entity *>>`, filtered by
   `dynamic_cast<X *>(oo::ToCxx(e))`; C++ callers that need the leaf cast the same way. This is
   the most conservative shape: the JS side, the owners' subentity lists and the tests keep the
   same objects, and only the element's static type changes. The root façade, not the nearest
   intermediate one, is used because the intermediate's own deletion bead comes next.
5. **A leaf's maker becomes the C++ factory plus `oo::NewEntityFacade`** where the caller needs the
   object (to add it as a subentity), and a selector that took the leaf (`-removeFlasher:`) takes
   the C++ class: the bridge header's parameter type keeps its spelling and now names the C++ class.
   The Entity category the leaf's bridge declared (`-isFlasher`, `-isExhaust`) goes with it;
   callers ask `dynamic_cast`. A leaf that was a graphics reset client through its façade class
   registers a C++ `OOGraphicsResetClient` instead (oo-9ht.110).
6. **A binding test that stood in for the leaf's Objective-C class** gets a C++ stand-in (amendment
   oo-9ht.12 item 2): the leaf class and its C++ bases declared with the game headers' names and
   member signatures but not their classes (the headers pull in the game), as `test_OOJSGlobal.mm`
   stands in for the engine; the stand-in root `Entity` gains the `_cxxEntity` ivar `oo::ToCxx`
   reads, and its JS category asks the stand-in C++ part, as the game's does. Every case and
   expectation stays; the approval line names the stand-in.

**Consequences.** The root's façade deletion (oo-9ht.39) inherits one JS path (the C++ virtuals)
instead of a selector per leaf, and `cxx::OOSubEntityInterface` is where the remaining
`OOSubEntity` adopters (ships, visual effects) land when their façades go.

## Amendment (bead oo-jx5np): the class shell of a giant's subclass whose state moves first (PlayerEntity)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/PlayerEntity.md` "Slice 1". Exemplar: `src/Core/Entities/PlayerEntity.h`,
  `PlayerEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_PlayerEntity.mm`. Follows amendments
  oo-60fwo (the ship's class shell) and oo-64ako (the station's, the first subclass of the ship),
  which it applies to the ship's player subclass.

**Context.** `PlayerEntity` (13,900 lines and nine category files, 328 ivars, all `@private`) is a
subclass of `ShipEntity`, whose state is already `cxx::ShipEntity` behind the facade's `_cxxShip`.
It converts in 28 slices and the category beads; slice 1 moves its state. Its object is made in two
steps: `-init` (by `+sharedPlayer`, before there is ship data) makes the ship the player's way, and
`-deferredInit` sends the ship's initialiser to the same object again.

**Decision (recommended defaults).**

1. **Amendment oo-60fwo, one level down.** `cxx::PlayerEntity : cxx::ShipEntity` holds the ivars as
   public members by the same names, zero-initialised (bit-fields `: 1 = 0`), marked private once
   the class is converted (oo-a70). The facade `@interface PlayerEntity : ShipEntity` (the ship's
   facade) carries one `@public` borrowed alias, `cxx::PlayerEntity *_cxxPlayer`, set beside
   `_cxxShip` by its override of the root's `-initWithCxxEntity:` (a checked `dynamic_cast`).
   Unconverted code reads `_cxxPlayer->hud`, or `player->_cxxPlayer->hud`; inherited ship members
   stay `_cxxShip->fuel`. `oo::ToCxx(::PlayerEntity *)` is the ship's crossing, typed.
2. **The part is made the station's way (amendment oo-64ako item 2).** The player's façade
   overrides the ship's private `-initShipPart` to make `oo::ObjCShipEntity<cxx::PlayerEntity>`
   (`ShipEntity+ObjCAdapter.h`), so the player's part carries every line of the ship's adapter and
   the ship's members that the player overrides (`-setUpShipFromDictionary:`, `-doesHitLine:...`)
   still reach its Objective-C methods from C++. `-init` still sends `[super initBypassForPlayer]`;
   `-deferredInit` still sends `-[ShipEntity cxx_initWithKey:definition:]`, whose `-initShipPart`
   keeps the part that is there, so the ship's body (`cxx::ShipEntity::initWithKey`) runs again
   over the same object and the player's members keep their values (the oo-bj8 double-`-init`
   case). The second `-init` is counted again by the debug entity count, as it was.
3. **`+sharedPlayer`, `gOOPlayer`, `-init`, `-deferredInit` and `-dealloc` are the facade's**
   (amendment oo-bj8 item 7), in `PlayerEntity+ObjCBridge.mm`; `+sharedPlayer` and `-deferredInit`
   are declared by the facade's `(OOObjCBridge)` category. `-dealloc` has the root's guard
   (oo-s6ic6): a player released before its initialiser ran has no part and skips the body.
4. **A debug-only method that only names ivars becomes a member under the same `#ifndef NDEBUG`**
   (`suppressClangStuff()`), defined in `namespace cxx` after the file's `@implementation`.
5. **C++ code names the Objective-C class `::PlayerEntity`** (amendment oo-bj8 item 9), on the
   lines the compiler reports once `cxx::PlayerEntity` exists.

**Consequences.** As amendment oo-60fwo's. The facade's deletion bead removes every `_cxxPlayer->`,
makes the members private and depends on the umbrella oo-a70.

## Amendment (bead oo-6symp): a JS private slot that holds a C++ object (amendment oo-ppc item 5)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Exemplar:
  `src/Core/Scripting/OOJSPrivateObject.h/.cpp`, its first user `src/Core/Scripting/OOJSTimer.h/.mm`,
  `tests/unit/core/test_OOJSPrivateObject.mm` and `test_OOJSTimer.mm`. Carries out amendment oo-ppc
  item 5; seam for the deletion beads oo-9ht.37, .63, .94, .95 and .102.

**Context.** Amendment oo-ppc item 5 left every JS private slot holding a retained Objective-C object,
so the engine could keep reaching it by selector: `-oo_jsValueInContext:` to wrap it,
`-oo_clearJSSelf:` from `OOJSObjectWrapperFinalize`, `-cxx_oo_jsDescription` from
`OOJSObjectWrapperToString`, `-isKindOfClass:` in `DEFINE_JS_OBJECT_GETTER`. A binding whose wrapped
class has converted cannot lose its façade while the slot holds it, and its `_jsSelf` stays a façade
ivar (amendment oo-bwrq item 1). Item 5 said the change "lands with the first façade deletion of a
wrapped class"; each deletion bead found it missing and stopped.

**Decision (recommended defaults).**

1. **The protocol is a C++ interface, `OOJSPrivateObject`** (`OOJSPrivateObject.h`, plain C++), with
   the selectors as virtual members: `jsValueInContext(context)`, `clearJSSelf(selfVal)` and
   `jsDescription()` (default nullopt). A converted class implements it beside its `oo::RefCounted`
   base (`class X : public Base, public ::OOJSPrivateObject`); no class changes its base.
2. **The slot holds the object as an `oo::RefCounted *` with one retain.** The engine glue
   (`OOJSPrivateObject.cpp`, beside `OOJavaScriptEngine.mm`'s Objective-C versions, each the
   counterpart of one) is: `OOJSSetCxxPrivate` (retain + `setPrivate`), `OOJSGetCxxPrivate<T>` (the
   getter: `DEFINE_JS_OBJECT_GETTER`'s JS class check with `OOJSIsSubclass` and the same error text,
   then the slot `static_cast` to `T`; the JS class fixes the slot's type, so no Objective-C class
   check is left), `OOJSCxxObjectWrapperFinalize` (the class's finalize hook: `clearJSSelf` through
   `dynamic_cast<OOJSPrivateObject *>`, then `release`), `OOJSCxxObjectWrapperToString(context, args,
   jsClass)` (called from a one-line native that names the class: `jsDescription()`, else `[object
   <JS class name>]`; a `this` of another class goes to `OOJSObjectWrapperToString` as before) and
   `OOJSValueFromCxxObject` (null for null, else `jsValueInContext`). The Objective-C path stays for
   every slot that still holds an Objective-C object; one JS class uses one path.
3. **The slot changes per binding, in a bead of its own or in the class's deletion bead, and
   `_jsSelf` moves with it.** Once the JS object no longer retains the façade, the façade can die and
   be made again, so the JS object must live in the C++ object (a member read by
   `jsValueInContext`/`clearJSSelf`) or one object would get two wrappers. The façade's
   `-oo_jsValueInContext:` (and `-oo_clearJSSelf:`) become one-line forwarders to the members, kept
   while Objective-C code still sends them.
4. **What the façade's selectors answered is kept.** `jsDescription()` returns what the façade's
   `-cxx_oo_jsDescription` did (`[<jsClassName> <components>]`, `OOObject (OOJavaScriptConversion)`'s
   format); a finalizer's warning moves into `clearJSSelf`, described from the live façade
   (`oo::LiveObjC`) where the old text named it. While the façade exists the class's converter
   (`OOJSRegisterObjectConverter`) answers it (`oo::PListObject(oo::ToObjC(x))`), so Objective-C
   callers of `OOJSNativeObjectFromJSValue`/`OfClass` get what they got; the façade's deletion bead
   moves those callers to the binding's C++ getter.
5. **Where the class's file and its binding are different files** (`OOShipGroup.mm` and
   `OOJSShipGroup.mm`), the three members are declared in the class's header and defined in the
   binding file (amendment oo-ppc item 3: the category's bodies were already free functions there). A
   core test that links the class's file without its binding defines them as stand-ins that answer
   `undefined` and do nothing (its objects never reach JS), because the vtable names them (amendment
   oo-9ht.12 item 2's C++ stand-ins, with an approval line under oo-9n5p9).
6. **Tests.** `test_OOJSPrivateObject` pins the glue on the test's own class (one wrapper per object,
   null for null, the slot's retain, the getter's class check and error with a registered subclass,
   the finalizer's `clearJSSelf` and release, toString's description, fallbacks and a native's
   exception). A binding whose slot changes keeps every expectation; a case that checked the slot
   held the façade checks it holds the C++ object, and the engine stand-ins it no longer reaches are
   replaced by linking `OOJSPrivateObject.cpp` (with an `OOJSIsSubclass` stand-in).

**Consequences.** This bead moves the Timer (its `_jsSelf` was already C++): its slot holds the
`cxx::OOJSTimer`, the finalizer is the engine's (its warning in `clearJSSelf`), toString() is
`OOJSCxxObjectWrapperToString`. ShipGroup (oo-9ht.94), SystemInfo (oo-9ht.95) and EquipmentInfo
(oo-9ht.102) move in child beads of oo-6symp, each before its deletion bead. `OOTimeProfile` has no
private slot (its JS value is a fresh plain object), so oo-9ht.63 needs nothing more from this seam.

## Amendment (bead oo-ao2d): the class shell of a second Objective-C subclass of ShipEntity (DockEntity)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/DockEntity.md` slice 1. Exemplar: `src/Core/Entities/DockEntity.h/.mm`,
  `DockEntity+ObjCBridge.h/.mm`, `tests/unit/core/test_DockEntity.mm`. Follows amendment oo-64ako,
  whose item 2 names `DockEntity`.

**Context.** `DockEntity` (1,337 lines) is over the story budget, had no slice plan, and is the
second subclass of `ShipEntity` to convert. `StationEntity` messages its docks by selector; no
other class reads a dock's ivars.

**Decision (recommended defaults).**

1. **Amendment oo-64ako applies unchanged, one subclass over:** `cxx::DockEntity :
   cxx::ShipEntity` with the ivars as public members, the façade's typed alias `_cxxDock`, the
   override of `-initShipPart` making `oo::ObjCShipEntity<cxx::DockEntity>`, and slice 1's units
   forwarded by `DockEntity (OOSlice1)`. The plan was written by this bead (no separate pre-split
   bead) and the bead converts slice 1; slices 2 and 3 have beads of their own (oo-9ht.178,
   oo-9ht.179).
2. **The private category's methods of slice 1** (`-clearIdLocks:`, `-clearAllIdLocks`) are
   declared in the `OOSlice1` interface of the bridge header, so the unconverted slices keep
   sending them to `self`; a private method of a later slice that a slice 1 member sends
   (`-abortAllLaunches`) is declared in the `.mm`'s private category.
3. **A getter of the root's `boundingBox` ivar** is `getBoundingBox()` (amendment oo-862e item 1);
   the queue counts and the flags keep their names, which no ivar shares.

**Consequences.** One more façade (`DockEntity+ObjCBridge`, deletion bead oo-9ht.180, on which the
ship's façade deletion oo-9ht.144 now waits); `ShipEntity+ObjCAdapter.h` is private to three files.

## Amendment (bead oo-zn1vy): PlayerEntity slices 2-28 in one change

- Date: 2026-10-08. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plan:
  `docs/phases/3-slices/PlayerEntity.md` slices 2-28 (beads oo-m4tfc ... oo-zn1vy). Exemplar:
  `src/Core/Entities/PlayerEntity.h/.mm`, `PlayerEntity+ObjCBridge.h/.mm`,
  `tests/unit/core/test_PlayerEntity.mm`. Follows amendments oo-mvzmb and oo-zd80m (the ship's
  later slices), which these slices repeat one level down, and oo-jx5np (the player's shell).

**Context.** Jon asked for the player's 27 later slices as one commit, verified once and merged
once, to compare batching with one bead at a time. Each slice keeps its own `namespace cxx`
block, declaration block and `PlayerEntity (OOSliceN)` category, so the result reads as 27
slices; the beads close together on the one merge.

**Decision (recommended defaults).**

1. **As amendments oo-mvzmb and oo-zd80m**, with `cxx::PlayerEntity` for `cxx::ShipEntity`: a
   member that overrides one of the ship's virtual members is `override`, and its forwarder calls
   `_cxxPlayer->cxx::PlayerEntity::m()`; the ship's adapter `oo::ObjCShipEntity<cxx::PlayerEntity>`
   already sends the selector back to the façade. `[super m]` is `ShipEntity::m()`, qualified.
2. **An override of the root's `takeEnergyDamage()` takes the root's types** (`cxx::Entity *`) and
   names the Objective-C objects `ent` / `other` at the top, as the ship's does; the forwarder
   converts with `oo::ToCxx()`. A selector with unnamed labels (`-doesHitLine:: :`) keeps every
   parameter.
3. **A player member that hides other overloads of the ship's name** gets a `using ShipEntity::m;`
   beside it (`doesHitLine`, `enterWormhole`, `hasOneEquipmentItem`, `doScriptEvent`), as slice
   10's `applyRoll` did, so C++ callers still reach the ship's other overloads.
4. **A method compiled under a macro the header does not see** (`-fuelChargeRate` under
   `MASS_DEPENDENT_FUEL_PRICES`, defined in `Universe.h`) is declared and forwarded
   unconditionally, and its member keeps the condition inside its body, answering the ship's rate
   (what the inherited method answered) when the macro is off.
5. **A macro that names the façade's `_cxxEntity`** (`SHIP_ENERGY_DAMAGE_TO_HEAT_FACTOR`) is
   written out in the member with a comment naming it, as `cxx::ShipEntity::takeEnergyDamage()`
   does.
6. **The plan's C functions with messages** (amendment oo-zd80m item 8): the market sorters
   (slice 23) take `cxx::OOCommodityMarket *` and read its members, the caller converting with
   `oo::ToCxx()`; `InterfaceForKey()` (slice 21) takes `cxx::StationEntity *` and reads its
   `localInterfaces`. A null part answers as a message to nil did (no name, 0, no interface).
7. **The last slice leaves the `@implementation` empty**; it moves to `PlayerEntity+ObjCBridge.mm`
   beside the categories, as `ShipEntity`'s did, and `PlayerEntity.mm` holds only C++ and the
   verbatim C helpers.
8. **Tests:** slices 14-28 add one case each (slice 19 none: every unit reads the GUI, the ship
   registry or the game's data, which the goldens cover), run on the unconverted class first. A
   `RecordingPlayer` subclass overrides the selectors a short form sends to itself, which records
   what the slice's own body sent, before and after the move (sends to `self` stay sends).
   `test_Universe.mm` declares `gOOPlayer` before its first use (main failed to compile it after
   oo-3cmlg moved a case above the declaration).

**Consequences.** `PlayerEntity.mm` has no Objective-C method left; the category files
(`PlayerEntityControls.mm` and the rest) and the façade's deletion stay with their own beads under
the umbrella oo-a70.

## Amendment (bead oo-amwj): a whole small subclass of the half-converted ShipEntity (ProxyPlayerEntity)

- Date: 2026-10-07. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Exemplar:
  `src/Core/Entities/ProxyPlayerEntity.h/.mm`, `ProxyPlayerEntity+ObjCBridge.h/.mm`,
  `tests/unit/core/test_ProxyPlayerEntity.mm`. Follows amendments oo-64ako (the station's shell)
  and oo-jx5np (the player's).

**Context.** `ProxyPlayerEntity` (230 lines, no slice plan) is a subclass of `ShipEntity` that
stands in for the player's ship and answers the player's dials to the shader bindings, which
message it by selector. It converts in one bead, so nothing of it stays Objective-C but the façade.

**Decision (recommended defaults).**

1. **The class is `cxx::ProxyPlayerEntity : cxx::ShipEntity`**, its ivars private members,
   zero-initialised, its methods members by their selectors' names (the members are named with a
   leading underscore, so no `get` is needed, amendment oo-zd80m item 4). A method that overrides
   a virtual member of the ship (`alertCondition()`) is `override`, and its forwarder calls the
   proxy's own member by name (amendment oo-mvzmb item 3).
2. **The façade is amendment oo-64ako's:** `@interface ProxyPlayerEntity : ShipEntity` with one
   `@public` borrowed alias, `_cxxProxyPlayer`, set by its `-initWithCxxEntity:` override; its
   `-initShipPart` override makes `oo::ObjCShipEntity<cxx::ProxyPlayerEntity>`. The initialiser
   stays the façade's (amendment oo-bj8 item 6) and runs the member `initProxyDefaults()` after
   the ship's set-up. Every other selector forwards. The class has no Objective-C object to
   release, so no `-dealloc`.
3. **The file's categories on other classes** (`Entity (ProxyPlayer)`, `PlayerEntity
   (ProxyPlayer)`, `-isPlayerLikeShip`) move, interface and implementation, to the bridge files
   (amendment oo-bj8 item 12): the class's own files keep no `@interface` or `@implementation`.

**Consequences.** One more façade (`ProxyPlayerEntity+ObjCBridge`, deletion bead filed with this
one), which goes when the universe and the player make the proxy in C++.

## Amendment (bead oo-lmdi8): the player's category files, the binding's later slices and main.mm in one change

- Date: 2026-10-08. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Plans:
  `docs/phases/3-slices/PlayerEntityControls.md`, `PlayerEntityKeyMapper.md`,
  `PlayerEntityLegacyScriptEngine.md`, `PlayerEntityContracts.md`, `PlayerEntityLoadSave.md` and
  `OOJSShip.md` slices 2-6. Exemplar: `src/Core/Entities/PlayerEntityControls.mm` (and the other
  category files), the blocks of `PlayerEntity.h` and `PlayerEntity+ObjCBridge.h/.mm` naming them,
  `tests/unit/core/test_PlayerEntity.mm`. Follows amendments oo-42dr and oo-iebuz (the ship's
  category files), oo-zn1vy (the player's slices in one change) and oo-xowh's `PlayerEntitySound.mm`.

**Context.** Jon asked for every remaining Convert-to-C++20 bead (29) on one branch, verified once
and merged once: the player's category files (`PlayerEntitySound`, `StickMapper`, `StickProfile`,
`Controls` slices 1-7, `KeyMapper` 1-3, `LegacyScriptEngine` 1-4, `Contracts` 1-3, `LoadSave` 1-2),
`ProxyPlayerEntity` (amendment oo-amwj), `OOJSShip.mm` slices 2-6 (amendment oo-18mg2) and
`SDL/main.mm`. Every slice of each category file lands in this change, so no category is left
half converted.

**Decision (recommended defaults).**

1. **A category file converted whole is converted in place.** Each method becomes an out-of-line
   member, `Ret cxx::PlayerEntity::m(params)`, where the method stood (the shape oo-xowh gave
   `PlayerEntitySound.mm`), so the file keeps its order and its file-scope helpers stay where they
   were; the `@implementation` and `@end` lines go. Names, `BOOL` and `::X` follow amendments
   oo-mvzmb and oo-zd80m; sends to `self` stay sends to the facade (`::PlayerEntity *self =
   oo::ToObjC(this);`). The members are declared in `PlayerEntity.h` in one block per file, marked
   by slice where the file has a plan.
2. **Each category's `@interface` moves whole to `PlayerEntity+ObjCBridge.h` under its own name**,
   from the file's header and from the file's private categories (`OOControlsPrivate`,
   `KeyMapperInternal`, `ScriptingPrivate`, ...); a method no interface declared is declared with
   its category. The forwarders are in `PlayerEntity+ObjCBridge.mm` under the implementing
   category's name, wrapped in the method's own preprocessor condition. The file's header keeps
   only what is not the category. The load / save macros (`OO_USE_CUSTOM_LOAD_SAVE` and the three
   it is made from) move from `PlayerEntityLoadSave.h` to `PlayerEntity.h`, which needs them for the
   declarations.
3. **A file-scope variable named like a new member is written `::x`** in the members
   (`::scriptTarget` in `PlayerEntityLegacyScriptEngine.mm`, now that `scriptTarget()` is a
   member).
4. **Two selectors with one first keyword and the same parameter types** take a name each:
   `-checkKeyPress:ignore_ctrl:` is `checkKeyPressIgnoreCtrl()` (beside `checkKeyPress(key,
   fKey_only)`); `-cxx_addPlanet:` and `-cxx_addMoon:`, which answer the entity, are
   `addPlanetEntity()` and `addMoonEntity()` beside the script actions `addPlanet()` and
   `addMoon()`. `-commsMessage:` and `-commsMessageByUnpiloted:` override the ship's virtual
   members, with `using ShipEntity::commsMessage;` for the ship's two-argument form (amendment
   oo-zn1vy item 3).
5. **A plan's C function with messages reads C++ parts** (amendment oo-zn1vy item 6):
   `ClickedGUIRow()`, `ShipyardLabelsRow()`, `MissionTextForKey()`, `CurrentSystemDataValue()`
   (left outside any block when its `@implementation` went), `TestScriptConditions()` and
   `PerformActionStatment()` cross with `oo::ToCxx()` and call the members the facades' forwarders
   call; a null part answers as a message to nil did. `-respondsToSelector:`, as `OOObject` answers
   it and no entity overrides, is `class_respondsToSelector(object_getClass(target), selector)`.
6. **A category of another converted class's facade in the file** (`MyOpenGLView
   (OOLoadSaveExtensions)`, one method) becomes a file-local function over the facade,
   `IsCommandModifierKeyDown(::MyOpenGLView *)`, reading the view's C++ part. Its plan entry then
   matches nothing; `--slice-done 2` passes, while the plan's full check reports slice 2 empty (its
   landed rule looks for `cxx::MyOpenGLView` members in the file). The plan is not edited.
7. **Selectors the game still passes by name stay `@selector(...)` in the members** (the stick
   mapper's joystick callback, the full-screen pause, the legacy query table), as in
   `PlayerEntity.mm`; the facade's deletion bead removes them with the facade.
8. **`main.mm` holds the controller as `oo::Ref<cxx::GameController>`** and calls its members; its
   `@try`/`@catch` stays (no class: rule 9).
9. **Tests.** `test_PlayerEntity.mm` gains one case per bead whose units a player in a
   never-initialised universe can answer, written against the Objective-C categories and run on
   them first (54 of 54 passed); slices that only poll the keyboard, the GUI or the files have none.
   `CategoryPlayer` records the sends a unit makes to itself. The unit universe cannot expand a
   description (expanding one exits the process), so a case keeps clear of units that would.
   `test_OOJSShip.mm`'s new slice 2-6 cases, which had never run, were run on the Objective-C
   natives and their expectations set to what those answered (bead oo-lk92s), before the
   conversion: no expectation that exists on `main` changed.

10. **Moved lines that tier-a now counts as new** (amendment oo-27jxj item 6) are restated with the
    same behaviour: a `BOOL` stored in a one-bit member is compared with `NO`
    (`hyperspeed_locked`, `keyboardRollOverride`), the trade-in value's integer quotient is named
    before `cunningFee()` takes it, and the save path's directory is passed as the engaged optional.

**Consequences.** `PlayerEntity`'s `@implementation`s are all in `PlayerEntity+ObjCBridge.mm`;
no category file holds Objective-C methods. The facade's deletion bead (under oo-a70) removes the
forwarding categories, the moved interfaces and the `::PlayerEntity *self` lines with it.

## Amendment (bead oo-pas): the last of the giants' Objective-C, and the ship's JS class answers

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch A
  (one branch, as oo-zn1vy and oo-lmdi8): beads oo-pas, oo-a70, oo-e1d, oo-e4i, oo-tt7l1.
  Exemplar: oo-k8a (`ShipEntity.mm`'s last `@implementation`), `src/Core/Universe.mm`,
  `Universe+ObjCBridge.h/.mm`, `src/Core/Entities/PlayerEntity.mm`,
  `src/Core/Scripting/EntityOOJavaScriptExtensions+ObjCBridge.mm`,
  `src/Core/Entities/StationEntity+ObjCBridge.mm`, `tests/unit/core/test_StationEntity.mm`.

**Decision (recommended defaults).**

1. **A giant's last `@implementation` that holds no method goes, as oo-k8a did.** Every Universe
   method is a `cxx::Universe` member (slices 1-26). `@implementation Universe` in `Universe.mm`
   held only file-scope statics, anonymous namespaces and plain-C helpers, kept verbatim as
   file-scope C++ (rule 9), and the Mac speech arms. The facade's primary `@implementation` moves
   to `Universe+ObjCBridge.mm`, empty but for those arms, which stay Objective-C behind
   `#if OOLITE_MAC_OS_X` (Mac-only code is not adapted in Phase 3, amendment oo-bgmb item 2); they
   read the synthesiser through `_cxxUniverse->speechSynthesizer`, where it now lives. Not compiled
   on the fleet's platform.
2. **An Objective-C holder a deferred call retains lives with the facade.**
   `OOUniverseDelayedMessage` (its `@interface` in `Universe+ObjCBridge.h`, its empty
   `@implementation` in `Universe+ObjCBridge.mm`), as `OOAIDeferredCallTrampolineInfoHolder` is
   in `AI+ObjCBridge.h/.mm`.
3. **A private category interface that declares nothing implemented is deleted**
   (`Universe (OOPrivate)`'s `-setShaderEffectsLevelDirectly:`, `PlayerEntity (OOPrivate)`'s
   `-setExtraEquipmentFromFlags`: neither had a definition or a sender).
4. **`ShipEntity (OOJavaScriptExtensions)` answers ShipEntity's own JS class with the bodies**
   (`ShipEntityJSGetJSClass`, `ShipEntityJSClassName`), as amendment oo-9ht.107 item 1 has it, and
   the facade of each C++ subclass that overrides `getJSClass` / `jsClassName` overrides the two
   selectors and asks its C++ part (`DockEntity`'s already did; `StationEntity`'s does now).
   oo-9ht.97 had made the ship category ask `_cxxEntity`, which a ship facade without a C++ part
   (`test_EntityOOJavaScriptExtensions`'s never-initialised ship) dereferenced as null: the
   segfault of oo-tt7l1. `cxx::ShipEntity`'s and `cxx::StationEntity`'s virtuals are unchanged, so
   C++ callers and the root path get the same answers. `test_StationEntity` pins the station's
   answers through the facade and from its C++ part (run on `main` first).

**Consequences.** `Universe.mm`, `PlayerEntity*.mm` (but the bridge), `PlayerEntityControls.mm` and
`OOJSShip.mm` have no Objective-C class syntax; every `@implementation` of the three giants is in
their `+ObjCBridge.mm`, which their facade-deletion beads (oo-ql9rn, oo-9ht.177, oo-9ht.181) remove.

## Amendment (bead oo-9ht.68): the audio facades and two OOWeakRefObject facades in one change

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch C
  (one branch, as batch B): beads oo-9ht.68 (OOSound), oo-9ht.88 (OOSoundSource), oo-9ht.82
  (OOALSoundDecoder), oo-9ht.52 and oo-9ht.53 (their JS category forwarders), oo-9ht.61
  (OOJSInterfaceDefinition), oo-9ht.62 (OOJSGuiScreenKeyDefinition). Exemplar: `src/Core/OOALSound.h/.mm`,
  `OOSoundSource.h/.mm`, `Scripting/OOJSSound.mm`, `Scripting/OOJSSoundSource.mm`,
  `Entities/PlayerEntitySound.mm`, `tests/unit/core/test_OOSound.mm`, `test_OOJSSoundSource.mm`.

**Decision (recommended defaults).**

1. **A class cluster's root and its concrete classes go together.** Once the root's facade
   (`OOSound`) and the decoder's are gone, the cluster's factory answers `oo::Ref<Root>`
   (`OOSound::initWithContentsOfFile`), the subclasses take the C++ decoder, and a subclass that
   overrode the initialiser (`OOMusic`) hides the factory as before (amendment oo-2en item 3).
   The facade's `-cxx_description` becomes a non-virtual `description()` on the root (the C++
   class's name, its address and components), which the sound source's components print.
2. **A JS class whose `-oo_jsValueInContext:` made a new object on every call** (Sound,
   SoundSource: no `_jsSelf`) puts a small holder in the slot (amendment oo-6symp item 2): a
   `final` `oo::RefCounted` + `OOJSPrivateObject` in the binding's file that retains the C++
   object and answers its `toString()`; `clearJSSelf` does nothing. The class itself does not
   implement `OOJSPrivateObject`, so the audio tests that link it without its binding need no
   stand-ins (item 5). Its converter answers null (no Objective-C object is left to hand over);
   the binding's own readers (`SoundFromJSValue`) read the holder.
3. **An object that kept itself alive through its facade** (a playing sound source's `[self
   retain]`) calls `retain()` / `release()`; nothing touches the object after the last
   `release()`. A set of such objects holds `oo::Ref`.
4. **A static that held an alloc/init'd facade for the process** holds the +1 of
   `oo::makeRef<X>().leakRef()` (and `oo::release` where `DESTROY` was), and each use is
   null-checked where a message to nil was harmless (batch B's lesson: CollisionRegion before
   creation).
5. **A category on a converted class's facade that lives in another facade's file**
   (`Universe+ObjCBridge.mm`'s `OOSound (OOCustomSounds)` / `OOSoundSource (OOCustomSounds)`) goes
   with the facade; its free-function bodies (`OOSoundWithCustomSoundKey()`,
   `OOSoundSourcePlayCustomSoundWithKey()`, null-safe) are called directly. A facade selector of a
   facade that stays (`+[ResourceManager cxx_ooSoundNamed:inFolder:]`) is retyped to the C++
   class; the resource manager's cache holds `oo::Ref`.
6. **A subclass of `OOWeakRefObject` whose holders only retained it** (the interface and GUI-key
   definitions: no `-weakRetain` of them existed) becomes a plain `oo::RefCounted` held as
   `oo::Ref`; amendment oo-o89 item 3's `oo::WeakRef` is not needed. A header that keeps one in a
   member includes its header (a forward declaration does not destroy an `oo::Ref`).
7. **Tests** (standing approval oo-9n5p9): a C++ stand-in replaces each Objective-C stand-in with
   the same answers; a test that relied on an autoreleased object's lifetime uses an
   `oo::AutoreleaseScope` where it had `@autoreleasepool`; the facade's `"%@"` checks ask
   `description()` / `descriptionComponents()`; a binding test that stood in for the engine's
   Objective-C getter, finalizer and `toString()` stands in for the C++ glue the same way.

**Consequences.** The Audio module has no Objective-C class; `PlayerEntitySound.mm`, `OOTrumble.mm`,
`OOSoundSourcePool.mm`, `OOALMusic.mm` and the two sound bindings call it directly. The
`OOWeakRefObject` deletion (oo-9ht.22) no longer waits for the two definitions.

## Amendment (bead oo-9ht.1): the colour, the GUI and the HUD facades in one change

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch D
  (one branch, as batches B and C): beads oo-9ht.1 (OOColor), oo-9ht.143 (GuiDisplayGen), oo-mwd58
  (HeadUpDisplay). Exemplar: `src/Core/OOColor.h/.mm`, `GuiDisplayGen.h/.mm`, `HeadUpDisplay.h/.mm`,
  `OOHUDBeaconCodeIcon+ObjCBridge.h/.mm`, `Materials/OOShaderUniform.mm`,
  `tests/unit/core/test_OOOXZManager.mm`, `test_OOJSPlayerShip.mm`, `test_OOJSGlobal.mm`.

**Context.** The three facades were the widest left: about 500 Objective-C colour sites in 70 files,
the GUI's 92 and the HUD's dial dispatch. The converted callers sent the facades' selectors; the
deletion turned every such send into a member call with a codemod driven by the compiler's
`-Wreceiver-expr` diagnostics and a selector map read from the facades' own forwarders, then fixed
the `oo::Ref`/pointer fallout the same way.

**Decision (recommended defaults).**

1. **A colour is its own `PList::Object` payload.** `OOColor` derives from `oo::PListForeign` (as
   `OONativeVector` does, amendment oo-9ht.5) and answers `className()` "OOColor" and
   `description()` "<OOColor 0x...>{components}", what the facade's node printed. `OOColor.h` adds
   `OOColorObjectNode()` and `OOColorInObjectNode()` for the planet info, the GUI settings and the
   equipment rows that carried colours in Object nodes; `colorWithDescription()` of such a node
   answers the colour itself (the decision bead oo-9ht.1's item 3 asked for). An Object node's
   colour reaches JavaScript as `undefined`, as the facade did.
2. **Borrowed or owned, as the facade made it.** A facade selector that answered a colour its
   object keeps (`-laserColor`, `-displayColor`, `-fogUniform`, `-airColor`, ...) answers the C++
   `OOColor *`, borrowed; one that answered a new colour (`-weaponColor`,
   `-cxx_dialCustomColor:`) answers `oo::Ref<OOColor>`. A local that held an autoreleased colour is
   `oo::Ref<OOColor>`; a temporary passed on is `.get()` for the call only. Retained `OOColor *`
   members (the ship's seven colours) and the universe's GUIs and the player's HUD are `oo::Ref`.
3. **Nil stays harmless where it was.** A member call on a colour, GUI or HUD that may be null where
   the message to nil answered zero or did nothing is null-guarded (row colours, a sky's colour,
   the exhaust colour, the material specifier's white/black tests, the texture generators'
   colours, the universe's HUD draw, the big-GUI checks, the manifest row macro). The player's own
   HUD in its in-flight members is not guarded: it is set when the ship is set up and only replaced.
4. **The universe keeps the GUIs `setUpSettings()` replaces until it replaces them again**
   (`replacedGuis`): they were autoreleased, and a caller of the reinitialisation may still hold one
   in the same pass.
5. **The HUD's dials by name are a table of member pointers** (`kDials` in `HeadUpDisplay.mm`):
   exactly the 36 selectors the facade's `OODials` category answered, so a whitelisted name the
   facade did not answer is still "not implemented" and is ignored with the same log. The widget
   keeps the member pointer where it kept the `SEL`.
6. **What else was in a deleted bridge moves, verbatim.** The one-line sends of the HUD's and GUI's
   free functions (amendment oo-9ht.139) move into `HeadUpDisplay.mm`/`GuiDisplayGen.mm` with their
   declarations in the headers; the beacon code icon's facade and the `OOHUDBeaconIcon` protocol the
   entities hold it by move to `OOHUDBeaconCodeIcon+ObjCBridge.h/.mm`, still imported last by
   `HeadUpDisplay.h`, until the entities hold their beacon drawables as C++ objects.
7. **A colour shader binding is its own uniform type.** `kOOShaderUniformTypeColor` (before
   `kOOShaderUniformTypeObject`, so `OOJSCall`'s method types after it keep their values) is a method
   answering `OOColor *`; `kOOShaderUniformTypeObject` stays `id` and sets nothing, as an object that
   was not a colour did. Both describe as "object-binding". `OOJSCall` answers a colour method's
   result as its Object node.
8. **Tests that link the whole game (`['*']`) and stood in for the GUI's facade** (an Objective-C
   class answering its selectors, test_OOOXZManager's recording screen and test_OOJSPlayerShip's
   message GUI) cannot define the GUI's members again: the members those stand-ins answered are
   `virtual` in `GuiDisplayGen` (seventeen; the game makes no subclass), and the stand-ins are C++
   subclasses overriding them with the same answers. A test that links its own sources defines the
   members the code it links calls, and never-run definitions of the other virtual members (the
   vtable needs them). Every expectation is kept (standing approval oo-9n5p9).

**Consequences.** No Objective-C `OOColor`, `GuiDisplayGen` or `HeadUpDisplay` is left;
`OODebugGLDrawing` takes the C++ colour and waits only for the OOMaterial facade (oo-9ht.8) to become
the `.cpp` rename of oo-hrcs. The beacon code icon's facade is the HUD's last Objective-C.

## Amendment (bead oo-9ht.21): the planetinfo, commodity, market and character facades in one change

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch E
  (one branch, as batches B-D): beads oo-9ht.32 (OOSystemDescriptionManager), oo-9ht.25
  (OOCommodities), oo-9ht.21 (OOCommodityMarket), oo-9ht.10 (OOCharacter). Exemplar:
  `src/Core/OOCharacter.h/.mm`, `Universe.h/.mm`, `Entities/PlayerEntity.mm`,
  `tests/unit/core/test_OOCommodities.mm`, `test_OOCharacter.mm`.

**Decision (recommended defaults).**

1. **Members of the giants that retained one of these facades are `oo::Ref`** (the universe's
   commodities, main market, system manager and character pool, the player's manifest, a station's
   market, a ship's crew); the giants' getters and the facades' selectors that answered them answer
   the C++ object borrowed. A facade selector that answered a new object
   (`+[ResourceManager systemDescriptionManager]`) answers `oo::Ref` (amendment oo-9ht.1 item 2).
   `DESTROY(x); x = [[maker ...] retain];` is one assignment.
2. **What the universe replaced while it was autoreleased is kept until the next replacement**
   (`replacedCommodities`, `replacedSystemManager`, `replacedCharacterPool`), as amendment oo-9ht.1
   item 4 keeps the GUIs; a screen that made a blank market for its pass holds it in a local
   `oo::Ref`.
3. **A character is its own `PList::Object` payload** (`oo::PListForeign`, as `OOColor` is), so its
   script's `"character"` property still carries it; it reaches JavaScript as `undefined`, as the
   facade did (the root class's glue). Its `className()`/`description()` answer what the facade's
   node printed. The facade's `oo::SendIntValue` (an `-intValue` send to an Object node's object)
   becomes a file-scope helper in `OOCharacter.mm` that calls the method's implementation with the
   type Foundation declared, through the runtime's C API (no Objective-C syntax).
4. **Nil stays harmless where it was** (amendment oo-9ht.1 item 3). The universe's system manager,
   commodities and main market are null until `setUpSettings()` makes them (the ship registry
   loads first) and in the tests' bare universes; the player's manifest is null when
   `-deferredInit` first empties the hold; a station's market is null when there are no
   commodities. Every member call through them is guarded and answers what the message to nil
   answered (zero, false, `UNITS_TONS`, a null PList, an empty list, a zero seed, a null market),
   and a statement call is skipped. The string expander's seed (`OOStringExpander+ObjCBridge.mm`)
   answers a zero seed. A crew's characters are not guarded: the factories never answer null. The
   bindings that already guarded a null (`OOJSManifest`, `OOJSStation`, `OOJSSystemInfo`,
   `WormholeEntity`) keep their guards and drop the `oo::ToCxx` crossing.
5. **Tests** (standing approval oo-9n5p9): the facade-contract cases go (nil crossings and messages
   to nil, `oo::ToObjC(oo::ToCxx())` identity, a C++ object's one facade); the cases that asked
   through selectors ask the C++ class, holding the factories' `oo::Ref` where the autoreleased
   facade was; stand-ins that held a facade in an ivar hold `oo::Ref` and answer it borrowed.

**Consequences.** No Objective-C `OOSystemDescriptionManager`, `OOCommodities`, `OOCommodityMarket`
or `OOCharacter` is left. The ship registry's, the equipment type's, the ship group's and the
scripts' facades are the data-model facades still standing.

## Amendment (bead oo-9ht.19): the ship group and equipment type facades in one change

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch F
  (one branch, as batches B-E): beads oo-9ht.19 (OOShipGroup) and oo-9ht.28 (OOEquipmentType).
  Exemplar: `src/Core/OOShipGroup.h/.mm`, `OOEquipmentType.h/.mm`, `Entities/ShipEntity.mm`,
  `Scripting/OOJSShipGroup.mm`, `Scripting/OOJSEquipmentInfo.mm`, `tests/unit/core/test_OOShipGroup.mm`,
  `test_OOJSShipGroup.mm`.

**Decision (recommended defaults).**

1. **A class whose objects travel in plist data and reach JavaScript is its own `PList::Object`
   payload and its own JS glue** (`class X : public oo::PListForeign, public ::OOJSPrivateObject`,
   as `OOSystemInfo` is). `X.h` adds `XObjectNode()` / `XInObjectNode()` (and, for lists,
   `XObjectNodes()`), which replace `oo::PListObject(facade)` / `oo::ObjectIn()` /
   `oo::PListFromObjects()`; `className()` / `description()` answer what the facade's node printed.
   The binding's converter answers the object's node, so a reader that asked
   `OOJSNativeObjectOfClassFromJSValue(..., [X class])` asks `XInObjectNode(cxx_OOJSPListFromJSValue())`
   (a value of any other class gives null, as the class check did); a native that returned
   `OOJS_RETURN_OBJECT(oo::ToObjC(x))` returns `OOJSValueFromCxxObject()`, holding a new object in
   a local `oo::Ref` until the JS object holds it.
2. **Members that retained the facade are `oo::Ref`** (a ship's group and escort group, the
   save context's groups); the giants' getters and the facades' selectors answer the C++ object
   borrowed. Lists of registered types (`missilesList()`, `equipmentListForScripting()`) are
   `std::vector<oo::Ref<X>>`. A registered type is still kept by its registry only; ships keep
   weapon and missile types unretained (`OOWeaponType` is `OOEquipmentType *`, null: no weapon), as
   they kept the pinned facades. A facade that was leaked on purpose (`ShipGroupAddShip`'s
   `[[OOShipGroup alloc] initWithName:]`) is `.leakRef()`.
3. **Every converted send keeps what the message to nil answered** (amendments oo-9ht.1 item 3,
   oo-9ht.21 item 4): the codemod (driven by `-Wreceiver-expr` and the facades' forwarders, as in
   batches D and E) writes `(r != nullptr ? r->m() : <zero>)` for a value and
   `if (r != nullptr)  r->m();` for a statement, for every instance receiver, before the first
   build. Receivers that cannot be null (a type from `allEquipmentTypes()`, a group just made) are
   guarded all the same: the guard is cheap and the proof is not. A pure lookup used as a receiver
   (`equipmentTypeWithIdentifier(k).get()`, `[self weaponTypeForFacing:...]`) is evaluated twice.
   Tests convert without guards.
4. **Tests** (standing approval oo-9n5p9): the facade-contract cases go; stand-ins that held a
   facade hold `oo::Ref` and answer it borrowed; an engine stand-in that turned Object nodes into
   JS values gains the engine's C++ glue path (`OOJSValueFromCxxObject` of an `OOJSPrivateObject`
   payload); each class gains an `objectNode` case pinning the node round trip and description.

**Consequences.** No Objective-C `OOShipGroup` or `OOEquipmentType` is left. The ship registry's
and the scripts' facades are the data-model facades still standing.

## Amendment (bead oo-9ht.23): the graphics-reset group and two entity leaves in one change

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch G
  (one branch, as batches B-F): beads oo-9ht.23 (OOGraphicsResetManager and the
  OOGraphicsResetClient protocol), oo-9ht.30 (OOPolygonSprite), oo-7ae4p (OOHUDBeaconCodeIcon and
  the OOHUDBeaconIcon protocol), oo-9ht.111 (OOSunEntity), oo-9ht.112 (WormholeEntity). Exemplar:
  `src/Core/OOGraphicsResetManager.h/.mm`, `OOPolygonSprite.h/.mm`, `HeadUpDisplay.h/.mm`,
  `Entities/OOSunEntity.h/.mm`, `Entities/OOStellarBody.h`, `Entities/WormholeEntity.h/.mm`,
  `Scripting/OOJSSun.mm`, `Scripting/OOJSWormhole.mm`, `tests/unit/core/test_OOGraphicsResetManager.mm`,
  `test_OOJSSun.mm`, `test_WormholeEntity.mm`. Follows amendments oo-9ht.12 and oo-9ht.107.

**Decision (recommended defaults).**

1. **Every graphics reset client is C++.** The manager's client set holds `OOGraphicsResetClient *`
   only (`registerCxxClient` / `unregisterCxxClient`; the `id` overloads went with the protocol).
   A facade class that was the client of a static texture (`OOFlashEffectEntity`,
   `OOLightParticleEntity`) is replaced by a file-local client object registered once, as
   `OOLaserShotEntity`'s; a converted class whose facade was the client derives from
   `OOGraphicsResetClient`, registers itself where its initialiser did and unregisters in its
   destructor (the planet, whose facade otherwise still stands; the polygon sprite, so a sprite
   with no facade, such as the HUD's missile icons, is a client again as before oo-4111). The
   facades' `-resetGraphicsState` forwarders go.
2. **A protocol the entities hold a drawable by becomes a C++ interface** (`OOHUDBeaconIcon` in
   `OOPolygonSprite.h`: an `oo::RefCounted` with the protocol's method as a pure virtual). Both
   implementers derive from it; the entities hold `oo::Ref<OOHUDBeaconIcon>` and answer it
   borrowed; the root's `-beaconDrawable` selector is retyped; the one sender null-guards it, as
   the message to nil did. A facade's `"%@"` that a test pinned becomes `description()`.
3. **Deleting a leaf entity's facade whose objects other code holds** (amendment oo-9ht.107 item
   5, extended): the class's name now means the C++ class, so every `X *` holder and facade
   selector parameter retypes itself; `@class X` becomes `class X;`. Lists that retained the
   objects hold `oo::ObjCRef<::Entity *>` (the root facade) and cast with `static_cast<X *>(oo::ToCxx())`
   where the list holds only Xs; a raw pointer that held a retained object keeps the C++ pointer
   and retains its Objective-C object (`[oo::ToObjC(x) retain]` / `release`). A maker is
   `oo::makeRef<X>()`, then `oo::NewEntityFacade()` (retained where `+alloc` gave +1), then the
   initialiser's body, the facade's order. Code that needs the object (universe lists,
   `-addEntity:`, targets, script events, Object nodes) passes `oo::ToObjC(x)`.
4. **Selectors only the deleted facade answered, sent through a looser type, are asked of the C++
   part:** `-respondsToSelector:@selector(identFromShip:)` asks `dynamic_cast<WormholeEntity *>`
   first; the debug monitor's `-shipsInTransit` is `WormholeEntityShipsInTransit()`. The
   `OOStellarBody` protocol's `-radius` / `-planetType` sent to a body that may be the sun are
   `OOStellarBodyRadius()` / `OOStellarBodyPlanetType()` (`OOStellarBody.h`): the C++ sun, else the
   selector (the planet's facade) until oo-9ht.129.
5. **A binding's object getter whose class check named the facade** checks the JS class only
   (`DEFINE_JS_OBJECT_GETTER` over `Entity`) and answers `dynamic_cast` of the object's C++ part,
   null for a stale entity (`JSSunGetSunEntity`, `JSWormholeGetWormholeEntity`); the leaf's JS
   forwarders become `override`s (amendment oo-9ht.107 item 2).
6. **Every converted send keeps what the message to nil answered** (amendment oo-9ht.19 item 3;
   the codemod's selector map adds the root `Entity` facade's one-line forwarders, so a leaf's
   `-position` is `getPosition()`). Tests convert without guards; their C++ stand-ins follow
   amendment oo-9ht.107 item 6.

**Consequences.** No Objective-C `OOGraphicsResetManager`, `OOPolygonSprite`, `OOHUDBeaconCodeIcon`,
`OOSunEntity` or `WormholeEntity` is left, nor the `OOGraphicsResetClient` and `OOHUDBeaconIcon`
protocols. The planet's facade (oo-9ht.129) is the stellar body facade still standing: its
shader uniforms bind to it by selector, which the root's facade must answer for a planet's C++
part (and only for one) when it goes.

## Amendment (bead oo-9ht.129): the planet's facade, and selectors the root's facade answers for one leaf

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch H
  (one branch, as batches B-G): bead oo-9ht.129 (OOPlanetEntity). Exemplar:
  `src/Core/Entities/OOPlanetEntity.h/.mm`, `Entities/Entity+ObjCBridge.mm`, `Entities/OOSunEntity.mm`
  (`OOStellarBodyRadius()`), `Scripting/OOJSPlanet.mm`, `Universe.h/.mm`,
  `Entities/PlayerEntityLegacyScriptEngine.mm`, `tests/unit/core/test_OOPlanetEntity.mm`,
  `test_OOJSPlanet.mm`. Follows amendments oo-9ht.12, oo-9ht.107 and oo-9ht.23 (whose item 3 it
  applies unchanged: the universe's planet list holds `oo::ObjCRef<::Entity *>`, the makers are
  `oo::makeRef` + `oo::NewEntityFacade` + the initialiser's body, holders take the C++ planet).

**Context.** The planet's materials bind shader uniforms to the planet's Objective-C object by
selector (`material-defaults.plist` `planet-material` and `atmosphere`: `airColorAsVector`,
`illuminationColorAsVector`, `airColorMixRatio`, `airDensity`, `terminatorThresholdVector`; the
uniform asks `-respondsToSelector:`, then takes the implementation and its type from the runtime).
Once the planet's facade goes its object is the root `Entity`'s facade, which does not answer them,
so the planet's shaders would lose five uniforms.

**Decision (recommended defaults).**

1. **Selectors that only a deleted leaf's facade answered, and that are found by the runtime (not
   sent by converted code), go on the root's facade as a category whose methods ask the C++ part**
   (`Entity (OOPlanetShaderBindings)` in `Entity+ObjCBridge.mm`: each method `dynamic_cast`s
   `_cxxEntity` to the leaf and answers zero for any other entity), **and `-[Entity
   respondsToSelector:]` answers those selectors for the leaf's C++ part only**, so every other
   entity (a ship, whose material may name the same uniform) still fails to bind them, as before.
   The category is not declared in a header: nothing sends the selectors.
2. **`OOStellarBodyRadius()` / `OOStellarBodyPlanetType()` ask the C++ planet as they ask the C++
   sun**; every dynamic `-radius` / `-planetType` of a stellar body already went through them.
3. **A binding whose test stands in for the entity classes keeps the root's selectors for the
   entity's C++ virtual members** (`[oo::ToObjC(planet) normalOrientation]`, `-setOrientation:`):
   the root's facade forwards them to the virtual member, so the planet's override runs, the
   message to nil keeps the nil answer, and the binding's test (which cannot link a C++ entity
   vtable) stands in for `oo::ToObjC` instead (a back pointer on its stand-in `cxx::Entity`).
   Non-virtual members are called directly, null-guarded (amendment oo-9ht.19 item 3).
4. **A getter that answered an object of any class typed as the planet** (`-[StationEntity planet]`
   from a universal ID, a landing ship's target) answers `dynamic_cast` of the entity's C++ part:
   null for any other entity, whose `-isPlanet` was NO.

**Consequences.** No Objective-C `OOPlanetEntity` is left; the `OOStellarBody` protocol has no
adopter (its selectors are still sent through `OOStellarBodyRadius()`'s fallback). The root's
facade deletion (oo-9ht.39) inherits the shader-binding category; the member-pointer table of
oo-9ht.158 replaces it.

## Amendment (bead oo-9ht.137): a subclass facade that was the object's identity (OOJSScript)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch H,
  after oo-9ht.129. Exemplar: `src/Core/Scripting/OOJSScript.h/.mm`, `OOScript+ObjCBridge.h/.mm`,
  `OOJSSystemInfo.mm`, `tests/unit/core/test_OOJSScript.mm`, `test_OOJSSystemInfo.mm`,
  `test_OOJSTimer.mm`. Applies amendment oo-9ht.12 item 6 to a facade that was the script's
  identity (amendments oo-3kqi, oo-u61e.4).

**Context.** The Objective-C `OOJSScript` made and owned its C++ script, and was what everything held:
the JS object's private slot (a weak reference to it), the stack of running scripts, the weak
references of the timers and definitions, and the retained holders (ships, visual effects,
characters, the player's equipment scripts, the universe's condition scripts, the debug console).
Moving that identity into C++ (`oo::Ref`/`oo::WeakRef`, the JS-private glue of amendment oo-6symp)
is the root's deletion (oo-9ht.133).

**Decision (recommended defaults).**

1. **The nearest facade left becomes the identity.** A JS script's object is an instance of the
   root's facade `OOScript`, made once by `OOJSScript::scriptWithPath()` (the old
   `+scriptWithPath:properties:`: `oo::makeRef`, then `-initWithCxxRootScript:`, which records the
   peer, autoreleased, then `initWithPath()`; nil when the script cannot be loaded, and releasing the
   object runs `willDealloc()`, as `DESTROY(self)` did). Every holder typed `OOJSScript *` holds
   `::OOScript *`, still the retained (or weakly referenced) Objective-C object, so lifetimes and the
   JS private slot are unchanged.
2. **The root's facade answers what the deleted facade alone answered, for a JS script's C++ part
   only** (as amendment oo-9ht.129 item 1): `OOScript (JavaScriptEvents)`'s `-callMethod:...`
   (moved into `OOScript+ObjCBridge.h/.mm`; NO for any other script, as before), the weak reference
   support (`-weakRetain`, nil for any other script, and `-weakRefDied:`), the JS glue
   (`-oo_jsValueInContext:`, `-cxx_oo_jsClassName`; the root's defaults otherwise) and `-dealloc`'s
   `willDealloc()` first. So the ~25 `-callMethod:` senders stay sends.
3. **The deleted facade's class methods are the C++ class's statics, typed with the object**:
   `OOJSScript::currentlyRunningScript()`, `scriptStack()`, `pushScript()`, `popScript()` take and
   answer `::OOScript *`. Code that needs the running script's C++ part asks
   `static_cast<OOJSScript *>(oo::ToCxx([OOJSScript::currentlyRunningScript() weakRefUnderlyingObject]))`,
   null-guarded with the nil answer: the stack holds JS scripts' objects, nil, or the weak
   references the timers and definitions push (an `OOWeakReference`, whose `oo::ToCxx` would read
   the wrong ivar; a message to it was forwarded to its referent, which the unwrap keeps). The two
   C++ callers that already asked `oo::ToCxx` of the running script (the JS error reporter's script
   name, `System`'s manifest) unwrap the same way.
4. **Tests.** A test that stood in for the Objective-C `OOJSScript` stands in for the root's facade
   (an `@interface OOScript` with the same superclass and instance methods) and for the statics it
   reaches (a `class OOJSScript` declared with the header's static signatures); a binding that asks
   the C++ script gets `oo::ToCxx` and the member stood in for as well. The facade-contract
   crossing case is rewritten for the new crossing (standing approval oo-9n5p9).

**Consequences.** No Objective-C `OOJSScript` is left. oo-9ht.133 moves the identity (the weak
references and the JS private slot) into `cxx::OOScript` and deletes the root's facade, with the
selectors of item 2.

## Amendment (bead oo-9ht.133): the last script facade, and an identity that moves into C++

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch I
  (one branch, as batches B-H). Exemplar: `src/Core/Scripting/OOScript.h/.mm`, `OOJSScript.h/.mm`,
  `OOJSTimer.mm`, `OOJSMission.mm`, `Entities/ShipEntity.mm`, `tests/unit/core/test_OOScript.mm`,
  `test_OOJSScript.mm`, `test_OOJSInterfaceDefinition.mm`. Carries out what amendment oo-9ht.137
  left: the identity, the weak references and the JS private slot of a JS script move into C++.

**Context.** Since oo-9ht.137 the root's facade `OOScript` was every script's object: the holders
retained it (or a weak reference to it), the stack of running scripts held it (or a timer's or
definition's `OOWeakReference`), and a Script JS object's private slot held its `OOWeakReference`.
Deleting it means all of these hold the C++ script, with lifetimes and nil answers unchanged.

**Decision (recommended defaults).**

1. **`OOScript` is global C++ and is its own plist payload and JS glue**
   (`class OOScript : public oo::PListForeign, public ::OOJSPrivateObject`, amendment oo-9ht.19
   item 1). What the facade answered for every script is a member: `callMethod()` (virtual, false;
   `OOJSScript` overrides it, so the ~25 `-callMethod:` senders call it null-guarded, amendment
   oo-9ht.19 item 3), `className()`/`description()` (`<C++ class 0x...>{components}`, the address
   now the script's), `jsValueInContext()` (undefined, as `OOObject` answered; a JS script's Script
   object), `clearJSSelf()` (nothing). `OOScriptObjectNode()`/`OOScriptInObjectNode()` replace
   `oo::PListObject()`/`oo::ObjectIn()`, so the ship's and visual effect's `script` properties and
   the console's `scriptStack()` reach JS through the node.
2. **Holders hold `oo::Ref<OOScript>`** (ships' script and AI script, visual effects, characters, the
   player's world, commodity and equipment scripts, the universe's condition scripts, the debug
   console's script); getters and the giants' facade selectors answer it borrowed; the loaders
   answer `oo::Ref` (null where they answered nil). A header whose class holds one includes
   `OOScript.h` (a plain header) rather than declaring the class, so every unit that makes or
   destroys the holder sees a complete type (an `oo::Ref<OOJSScript>` member would need the engine's
   header there).
3. **`[script autorelease]` is `OOScriptAutorelease()`**: a file-private Objective-C keeper in
   `OOScript.mm` holds the `oo::Ref` and is autoreleased, so a script a holder replaces or drops
   (`setShipScript`, `setAIScript`, `removeScript`, the player's and effects' scripts) and a script a
   caller does not keep (the global prefix, the locale functions, the equipment check) dies when
   the pool drains, as its facade did. Where the facade was released at once (`DESTROY`, an
   `ObjCRef` replaced, a failed load's `DESTROY(self)`) the `oo::Ref` is dropped at once.
4. **Weak holders hold `oo::WeakRef<OOJSScript>`** (timers, the interface, populator and GUI-key
   definitions), taken from `currentlyRunningScript()` where `-weakRetain` was sent. The running
   stack holds an `oo::WeakRef<OOJSScript>` per entry: `pushScript(OOJSScript *)` (null: a
   script-less push) and `pushScript(const oo::WeakRef<OOJSScript> &)` for a weak holder;
   `currentlyRunningScript()` answers `OOJSScript *`, null once a weakly pushed script has gone (a
   dead `OOWeakReference`, which answered every message as nil, so the unwrap of amendment
   oo-9ht.137 item 3 is gone). `scriptStack()` answers `std::vector<oo::Ref<OOJSScript>>`, still
   raising on a script-less push; a gone weak entry is a null entry (the console lists it as null
   where the dead reference converted to undefined). The mission callback's script is a raw
   `OOJSScript *` retained and released by hand, as before.
5. **The Script object's private slot holds a file-private `ScriptPrivate`** (an `oo::RefCounted`
   with an `oo::WeakRef<OOJSScript>`, no JS glue of its own), as it held the script's
   `OOWeakReference`: the JS object does not keep the script, the finalizer is
   `OOJSCxxObjectWrapperFinalize`, the converter answers the script's node (null once it has gone),
   and toString() is the class's own native, `OOJSCxxObjectWrapperToString`'s logic asking the
   script's `jsDescription()` (`[Script <components>]`, or `[object Script]` once it has gone).
   `~OOJSScript()` is the old `-dealloc`'s body (the facade ran it as `willDealloc()`);
   `scriptWithPath()` answers `oo::Ref<OOJSScript>`.
6. **Tests** (standing approval oo-9n5p9, lines on main first): the facade's crossing cases go
   (`test_OOScript` crossingObjCSubclass, adapterOutlivesOwner and crossingCxxSubclass's identity
   checks; `test_OOPListScript` plistScriptCrossesAsTheRootFacade, replaced by a C++ identity case;
   `test_OOJSScript` crossing, rewritten to pin the weak stack entry and the weak private slot); the
   cases that asked through selectors ask the C++ class with every expectation kept (an Objective-C
   test subclass becomes a C++ one). A test that stood in for the Objective-C `OOScript` and
   `OOJSScript` stands in for `class OOJSScript : public OOScript` with the statics the code calls
   and, where it makes scripts, the definitions of `OOScript`'s virtual members (the vtable).

**Consequences.** No Objective-C script class is left; `OOScriptAutoreleaseKeeper` is the one
Objective-C object the scripts still use, for the pool's timing, until the pool itself goes.

## Amendment (bead oo-9ht.15): a selector called by name that becomes a C++ member (callObjC's table)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch J
  (one branch with oo-9ht.37). Exemplar: `src/Core/Scripting/OOJSCall.mm` (`kPlayerMethods`),
  `Entities/PlayerEntity.h/.mm`, `tests/unit/core/test_OOJSCall.mm`. Carries out item 4 of the
  decision (a selector called by name becomes an explicit table) for the first such selectors.

**Context.** The debug console reads the JS vector and quaternion conversion statistics by name
(`PS.callObjC("reportJSVectorStatistics")`): `PlayerEntity (JSVectorStatistics)` and
`(JSQuaternionStatistics)`, debug-build categories on the player's Objective-C facade, were all
that was left in `OOJSVector+ObjCBridge.mm` / `OOJSQuaternion+ObjCBridge.mm`. `callObjC()` still
dispatches every other name by Objective-C selector (the entity facades stand), so the template
class of `OOJSCall+ObjCBridge` stays (oo-9ht.44).

**Decision (recommended defaults).**

1. **A by-name method whose category goes becomes a member of the C++ class, and `callObjC()`
   reaches it through a name table** (`kPlayerMethods` in `OOJSCall.mm`, `#if OO_DEBUG` as the
   categories were): exactly the four selectors the categories answered, each with the signature
   it had (`oo::PList` result, or void), looked up before the selector, for the player only (an
   object that is not the player still "does not respond"). A property-list result reaches JS as
   the `kMethodTypePListVoid` case gave it; a void method leaves the result alone; the player is
   still made its own script target first.
2. **A member that reads no state of the object is `static`** (`cxx::PlayerEntity::
   reportJSVectorStatistics()` etc., one-line forwarders to the free functions that hold the
   bodies), so the table needs no C++ object from the facade; when the player's facade goes
   (oo-9ht.177) the receiver check becomes a check of the C++ class.
3. **Tests.** A test that links `OOJSCall.mm` alone defines the table's members as stand-ins
   (a `cxx::PlayerEntity` with the header's static signatures) and adds a case that calls each
   name on the player and on a non-player; no expectation changes.

**Consequences.** No Objective-C category on the player is left in the scripting bindings. The
table is where the rest of `callObjC()`'s names go once the entity facades are deleted (oo-9ht.44).

## Amendment (bead oo-9ht.37): a leaf facade whose only selectors were the JS glue (OOJSTimer)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch J,
  with oo-9ht.15. Exemplar: `src/Core/Scripting/OOJSTimer.h/.mm`, `OOScriptTimer.h`,
  `OOScriptTimer+ObjCBridge.h/.mm`. Applies amendment oo-9ht.137 items 1-2 to a timer.

**Context.** The Objective-C `OOJSTimer`, a no-ivar subclass of the `OOScriptTimer` facade, answered
only `-oo_jsValueInContext:` and `-cxx_oo_jsClassName` for a JS timer (its private slot holds the
C++ timer since oo-6symp). The timer queue still holds `OOScriptTimer` facades (oo-9ht.35), and
the Timer converter still answers the facade, so the root's facade stays.

**Decision (recommended defaults).**

1. **The root's facade is every timer's facade and answers the deleted leaf's selectors for a
   timer whose C++ part has JS glue** (`dynamic_cast` to `OOJSPrivateObject`): its
   `jsValueInContext()` and a new virtual `cxx::OOScriptTimer::oo_jsClassName()` ("Timer"); the
   root's defaults for any other timer. (`OOScriptTimer+ObjCBridge.mm` cannot name `OOJSTimer`:
   the root's test links it without the subclass.)
2. **Descriptions keep the deleted class's name.** A virtual `className()` ("OOScriptTimer",
   "OOJSTimer") names the facade in `-cxx_description` / `-cxx_shortDescription` and in
   `oo::TimerDescriptionWithComponents()` (the unrooted-timer warning's
   `DescriptionWithComponents` of the live facade), so every log and error still prints
   `<OOJSTimer 0x...>` for a JS timer, as test_OOJSTimer pins.
3. **`OOJSTimer` is global C++** (`class OOJSTimer : public cxx::OOScriptTimer, public
   ::OOJSPrivateObject`); `oo::ToObjC`/`oo::ToCxx` of it are the root's, through the base pointer.
   `oo::ToObjC` always makes an `OOScriptTimer`: the by-name facade class lookup is gone.

**Consequences.** No Objective-C subclass of `OOScriptTimer` is left. oo-9ht.35 deletes the root's
facade once the queue holds C++ timers; the glue then moves into the Timer converter's node.


## Amendment (bead oo-9ht.177): deleting a giant subclass's facade while the ship's stands (PlayerEntity)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch K
  (one branch, as batches B-J). Exemplar: `src/Core/Entities/PlayerEntity.h/.mm` (`sharedPlayer()`,
  `deferredInit()`, `willDealloc()`), `Entities/ShipEntity+ObjCBridge.mm` (`SHIP_PART`, the
  category `ShipEntity (OOPlayerSelectorsCalledByName)`), `Scripting/EntityOOJavaScriptExtensions+ObjCBridge.mm`,
  `Entities/PlayerEntityLegacyScriptEngine.mm`, `OOCallByName.mm`, `Scripting/OOJSCall.mm`,
  `tests/unit/core/test_PlayerEntity.mm`. Follows amendments oo-9ht.12, oo-9ht.107, oo-9ht.23,
  oo-9ht.129 (whose item 1 it applies to a subclass of the ship) and oo-9ht.15.

**Context.** The Objective-C `PlayerEntity` was a subclass of the ship's facade, the player's
identity (`gOOPlayer`), the receiver of ~3,800 sends, and the object the game still finds selectors
on by name: legacy-script actions and queries, AI actions, `ship.call()`/`callObjC()`, the string
expander's keys, shader bindings (the HUD's and the ship's dials), deferred calls and the joystick
callback. Its C++ part was the ship's adapter over the player (`oo::ObjCShipEntity<PlayerEntity>`),
so the ship's virtual members reached the player's overrides through the facade.

**Decision (recommended defaults).**

1. **The player is made in C++ and its object is the ship's facade** (amendment oo-9ht.12 item 6).
   `PlayerEntity::newPlayerObject()` (the old `[[PlayerEntity alloc] init]`) makes the C++ player
   with `oo::makeRef` and answers its Objective-C object, the ship's facade (`oo::NewEntityFacade`),
   retained (+1) as `+alloc`'s object was; `PlayerEntity::sharedPlayer()` (the old `+sharedPlayer`)
   keeps the first for the process. `gOOPlayer` and `PLAYER` are the C++ player; the class is
   global (`class PlayerEntity : public cxx::ShipEntity`), as the entity leaves' are.
   `deferredInit()` sends the ship's initialiser to that object again (the oo-bj8 double-`-init`,
   unchanged). The facade's `-dealloc` body is `willDealloc()`, which `-[ShipEntity dealloc]` calls
   first for a player's part, as the subclass's `-dealloc` ran before its superclass's.
2. **The ship's facade calls a C++ part's override when the part is not the ship's adapter.** Its
   forwarders of members a subclass overrides called `cxx::ShipEntity`'s own member (what
   `[super ...]` reached for an Objective-C subclass); `SHIP_PART(call)` keeps that for an adapter
   and calls the member virtually for any other part, so a send through a ship-typed pointer still
   reaches the player's override. Three of the facade's overrides answered a getter named for an
   ivar (`-alertCondition`, `-legalStatus`, `-suppressTargetLost`); the ivars are renamed
   (`alertConditionLevel`, `legalStatusValue`, `suppressTargetLostFlag`) so the player overrides
   the ship's virtual members with those getters, and `jsClassName()` answers "PlayerShip" as the
   facade's JS category did. The ship's JS category asks the C++ part for a ship made in C++.
3. **Selectors found by name on the player: the ship's facade answers them for the player only**
   (amendment oo-9ht.129 item 1, for a subclass). The category
   `ShipEntity (OOPlayerSelectorsCalledByName)` holds exactly the selectors only the player's facade
   answered whose signature a by-name dispatcher can call (`OOCallByName.h`, `callObjC()`,
   `OOShaderUniformTypeFromMethod()`): no argument, or one `std::string` / `oo::PList` argument,
   and a void, property-list, scalar, vector, quaternion, matrix, point or object result (496
   selectors, generated from the facade's forwarders). Each asks the player's C++ part and answers
   zero for any other ship; `-[ShipEntity respondsToSelector:]` answers them for the player's part
   only (a subclass facade that implements one itself, the proxy's dials, still answers). The
   dispatchers that looked a method up by class ask the object: the legacy-script runner sends
   `-respondsToSelector:` to its target (it asked `class_respondsToSelector`), and `OOCallByName`
   logs an unknown selector when the receiver does not respond. `callObjC()`'s table (amendment
   oo-9ht.15) checks the C++ class; the shader whitelist's player check is `dynamic_cast`.
4. **Sends become member calls, converted by compiler diagnostics** (the batch F/I converter) with
   the facade's own forwarders as the map (the player's, then the ship's and the root's), keeping
   the message to nil's answer for every receiver but `self`. Inside the player's members `[self
   ...]` is a member call; `self` stays `oo::ToObjC(this)` only where the Objective-C object is
   passed on. An Objective-C cast to the player (`(PlayerEntity *)entity` after `-isPlayer`) is
   `static_cast<PlayerEntity *>(oo::ToCxx(entity))`.
5. **Tests.** Under the standing approval oo-9n5p9 only the facade's own cases go (listed in the
   approval lines); every other case asks the C++ class with its expectations kept. A whole-game
   test's Objective-C subclass of the player (or of a stand-in player) is a C++ subclass overriding
   the members the Objective-C one overrode; those members of `PlayerEntity` (and a few of the
   ship's: `primaryTarget()`, `noteLostTarget()`, `nextBeacon()`, two `doScriptEvent()` overloads,
   ...) are `virtual`, the test seams amendment oo-9ht.107 item 6 allows. A narrow test that stood
   in for the Objective-C player (an `@interface PlayerEntity`) stands in for the C++ class: a
   `class PlayerEntity` with the header's member signatures and the same answers, as amendment
   oo-9ht.107 item 6 does for entity leaves. Such a stand-in has no vtable, so a binding a narrow
   test links calls a virtual member of the player by its final overrider
   (`player->PlayerEntity::clockTime()`, `PLAYER->cxx::ShipEntity::doScriptEvent(...)`), which
   is the call the Objective-C send made for the one player class the game has. Where a whole-game
   test also overrides the member and sees the binding's call (`OOPlayerForScripting()`'s
   `setScriptTarget()`, which test_OOJSShip logs), the binding calls a non-virtual member of the
   player that makes the virtual call (`setScriptTargetToSelf()`), which the narrow test stands
   in for.
6. **Left as they were (follow-up).** The player's data members stay public (the tests and the
   whole-game stand-ins read and set them) and its raw retained Objective-C pointers
   (`missile_entity[]`, `compassTarget`, `wormhole`'s object, ...) stay retained by hand: the
   bead's "private again" and `oo::ObjCRef` steps are each a change of their own, filed as a
   follow-up, not part of deleting the facade.

**Consequences.** No Objective-C `PlayerEntity` is left; the ship's facade carries the player's
by-name selectors until it is deleted (oo-9ht.39's family), when they join the C++ name tables.
`ProxyPlayerEntity`'s facade (oo-9ht.183) still waits for a C++ ship-construction path.

## Amendment (bead oo-9ht.35): a root facade whose last holder was a queue of Objective-C elements (OOScriptTimer)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch L
  (one branch). Exemplar: `src/Core/Scripting/OOScriptTimer.h/.mm`, `OOJSTimer.mm`,
  `src/Core/OOPriorityQueue.h` (`OOPriorityQueueOf`), `tests/unit/core/test_OOScriptTimer.mm`,
  `test_OOPriorityQueue.mm`. Finishes what amendment oo-9ht.37 left.

**Context.** After oo-9ht.37 the Objective-C `OOScriptTimer` was held only by the timer queue
(`OOPriorityQueue`, whose elements are Objective-C objects ordered by a selector), by the Timer
converter (which answered it as plist data) and messaged by the player (`+updateTimers`,
`+noteGameReset`).

**Decision (recommended defaults).**

1. **A queue of Objective-C elements gets a C++ twin, not a rewrite.** `OOPriorityQueueOf<T>`
   (header-only, beside `OOPriorityQueue`) holds `oo::Ref<T>` and orders by a comparator function;
   its heap is `OOPriorityQueue`'s step for step (bubble up on insertion, last element into the
   removed slot and bubble down, the identity search going on past a match), so equal elements
   come out in the same order, which a test pins against the Objective-C queue. `OOPriorityQueue`
   and its test stay unchanged (no game caller is left; it goes with the runtime, Phase 4).
2. **What the queue autoreleased, the caller now holds for the step.** `removeNextObject()` answers
   the `oo::Ref`; `updateTimers()` holds the fired timer for its iteration (fire, then reschedule),
   and `noteGameReset()` holds the emptied queue's timers to its end, where the autoreleased
   facades lived until the pool drained. Only a timer nothing else holds (its Timer object already
   collected) dies earlier; its destructor only unregisters.
3. **The timer is its own plist payload** (`class OOScriptTimer : public oo::PListForeign`, as
   amendment oo-9ht.133 item 1 did for scripts): `className()` (already "OOScriptTimer" /
   "OOJSTimer") and `description()`, the facade's `<name 0x...>{components}` with the timer's
   address; `descriptionWithComponents()` replaces `oo::TimerDescriptionWithComponents()`. The
   Timer converter answers an Object node of the timer, which converts back to its Timer object
   (the engine's `OOJSPrivateObject` case).
4. **Tests** (standing approval oo-9n5p9, lines on main first): the facade case goes; the cases
   that used the facade's initialisers and selectors call the C++ factories and members with
   every expected value kept.

**Consequences.** No Objective-C timer class is left; the queue's C++ twin is the pattern for any
other container of Objective-C elements a facade deletion meets.

## Amendment (beads oo-hahfg, oo-9ht.132, oo-9ht.9): the drawable family's facades, deleted together

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch L
  (one branch for the seam and both deletions). Exemplar: `src/Core/OODrawable.h/.mm`,
  `OOMesh.h/.mm`, `Entities/OOEntityWithDrawable.h/.mm`, `Entities/ShipEntity.mm` (`mesh()`,
  `setMesh()`), `Scripting/OOJSVisualEffect.mm`, `tests/unit/core/test_OODrawable.mm`,
  `test_OOMesh.mm`, `test_OOJSVisualEffect.mm`.

**Context.** Every drawable was already C++ (OOMesh's four slices, OOPlanetDrawable, OOSkyDrawable);
the facades `OODrawable` and `OOMesh` remained for the holders: the entities kept an
`oo::ObjCRef<OODrawable *>`, the ship and visual effect made meshes with `+meshWithName:...` and
their `-mesh`/`-setMesh:` and the entity's `-drawable`/`-setDrawable:` were typed with the facades.
The seam (moving the holders) and the two deletions are one change: once the holders are C++ no
Objective-C caller is left for either facade.

**Decision (recommended defaults).**

1. **The entity holds `oo::Ref<OODrawable>`**, and its header includes `OODrawable.h` (amendment
   oo-9ht.133 item 2). `[drawable autorelease]` on replacement is `OODrawableAutorelease()`, a
   file-private keeper as `OOScriptAutorelease()` (amendment oo-9ht.133 item 3).
2. **An entity facade's selectors that answered a deleted facade answer the C++ object**: the
   entity's `-drawable`/`-setDrawable:`, the ship's and visual effect's `-mesh`/`-setMesh:` are
   kept and typed with the C++ classes (`class OOMesh;` replaces `@class OOMesh`), so their
   senders compile unchanged; a send to the result (`[[self mesh] rebindMaterials]`) becomes a
   member call guarded for null with the zero a message to nil answered (`BoundingBox{}`, a null
   `oo::PList`).
3. **The classes move to the global namespace** (`OODrawable`, `OOMesh`); names that are still
   `cxx::` classes behind a facade (`cxx::OOMaterial`, `cxx::OOOpenGLExtensionManager`) are
   qualified where the code was inside namespace cxx.
4. **The debug size is the C++ object's**: `totalSize()` starts from a virtual `objectSize()`
   (`sizeof *this`, each drawable answering its own) where it was the facade's instance size;
   `description()` is the facade's `<Class 0x...>{components}` with the drawable's address.
5. **Tests** (standing approval oo-9n5p9, lines on main first): the facades' crossing cases go
   (identity, nil, an Objective-C subclass's adapter, the bitwise copy, facade classes); an
   Objective-C test drawable is a C++ subclass with the same answers; a narrow test that stood in
   for the Objective-C `OOMesh` stands in for the C++ class (amendment oo-9ht.177 item 5).

**Consequences.** No Objective-C drawable class is left. `NSObjectOOExtensions` still has senders
(the Entity facade, the debug monitor's entity and texture sizes, OOWeakReference), so oo-6e1.1
stays open; the compiled-out `PRELOAD` block of `OOShipRegistry.mm` still names a `+meshWithName:`
form no class has had since oo-dnbf.

## Amendment (bead oo-5q11i): a converted class's hand-retained Objective-C members (PlayerEntity)

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch L.
  Exemplar: `src/Core/Entities/PlayerEntity.h/.mm` (`missile_entity[]`, `demoShip`,
  `compassTarget`, `_dockedStation`, `wormholeObject`), `PlayerEntityControls.mm`. Carries out
  item 6's second half of amendment oo-9ht.177.

**Decision (recommended defaults).**

1. **A member the class retained and released by hand is an `oo::ObjCRef`**: `[x release]; x = nil;`
   and `DESTROY(x)` are `x = nullptr`; an assignment of a +1 object (`+new...`, `-weakRetain`) is
   `oo::adoptObjC(...)`, of a borrowed one with `[y retain]` is `oo::ObjCRef<T>(y)`; sends read
   `.get()`. A copy between slots (the missile pylons' tidy-up, which moved a pointer and cleared
   the source without a release) is an ordinary copy: each slot now holds its own retain, and the
   counts end where they did.
2. **A raw pointer dropped without a release keeps doing so**: an assignment of nil that leaked the
   old object (the demo ship on loading a commander, a wormhole replaced on entering another) is
   `(void)ref.leakRef()`, with a comment, so no object is freed that was not freed before.
3. **A C++ object whose Objective-C object was retained** (the wormhole, amendment oo-9ht.112)
   keeps its C++ pointer and gains a companion `oo::ObjCRef<::Entity *>` holding that object; each
   assignment sets both. A member that was never retained (`targetDockStation`) stays a raw pointer.
4. **Tests**: a test that set such a member to `[x retain]` sets it to `oo::adoptObjC([x retain])`,
   with every expectation kept.

**Consequences.** The player's members are still public (the first half of amendment oo-9ht.177
item 6), split into a bead of its own: making them private needs a test-access friend for the ~56
members test_PlayerEntity reads and sets.

## Amendment (bead oo-4yscj): a converted class's data members private again, with a test-access friend

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch L
  (split from oo-5q11i). Exemplar: `src/Core/Entities/PlayerEntity.h`,
  `tests/unit/core/test_PlayerEntity.mm` (`PlayerEntityTestAccess`). Carries out the first half of
  amendment oo-9ht.177 item 6.

**Decision (recommended defaults).**

1. **Members that were `@private` in Objective-C are `private`** once no facade reads them; the
   class declares `friend struct PlayerEntityTestAccess;` (one friend, defined by the test only).
2. **The test reaches them through that friend, one accessor per member**, answering a reference
   (`PlayerEntityTestAccess::credits(player)` where it read `player->credits`), so each check reads
   and writes exactly what it did; a one-bit member, which has no reference, answers a proxy that
   reads as its value and assigns through. No expectation changes.
3. Game code outside the class's own members reads none of them (checked by a survey and the
   compiler); a test's C++ subclass that declares a member of the same name keeps its own.


## Amendment (beads oo-9ht.106, oo-9ht.76, oo-9ht.109, oo-9ht.108): the entity leaves' last facades, and a protocol the root's facade answers for one leaf

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch M
  (one branch). Exemplar: `src/Core/Entities/OOLightParticleEntity.h/.mm`,
  `OOFlashEffectEntity.h/.mm`, `SkyEntity.h/.mm`, `OOWaypointEntity.h/.mm`,
  `Entities/Entity+ObjCBridge.mm` (the category `Entity (OOWaypointBeacon)`),
  `Scripting/OOJSWaypoint.h/.mm`, `Universe.h/.mm`, `HeadUpDisplay.mm`,
  `tests/unit/core/test_OOLightParticleEntity.mm`, `test_OOWaypointEntity.mm`,
  `test_OOJSWaypoint.mm`. Applies amendments oo-9ht.107, oo-9ht.23 and oo-9ht.129 to the last
  facades over entity leaves that are not ships or visual effects.

**Context.** Four facades over converted entity leaves remained: `OOLightParticleEntity` (an
intermediate facade, the object of every particle, and the adapter of Objective-C subclasses, of
which none was left in the game), `OOFlashEffectEntity` (whose class methods the ship and the
universe sent), `SkyEntity` (made with `+alloc`/`-initWithColors::andSystemInfo:` and found by
`-isKindOfClass:`) and `OOWaypointEntity`, which is also a beacon: the universe's beacon list holds
ships, visual effects and waypoints as `Entity <OOBeaconEntity> *` and messages them by the protocol.

**Decision (recommended defaults).**

1. **Deleted together, in the established way** (amendments oo-9ht.107 items 1-6, oo-9ht.23 item 3):
   the classes are global C++ (`class OOLightParticleEntity : public cxx::Entity`,
   `class SkyEntity : public cxx::OOEntityWithDrawable`, ...); makers are the C++ factory or
   `oo::makeRef` + `oo::NewEntityFacade` (retained where `+alloc` gave +1) + the initialiser's body;
   a class send (`+setUpTexture`, `+defaultParticleTexture`) is the static member; a send of a
   deleted facade's selector is a member call on `dynamic_cast` of the object's C++ part (the sky
   is found that way where `-isKindOfClass:` found it); the light particle's Objective-C-subclass
   adapter goes with its facade (no game subclass was left). The objects are the nearest facade
   left: the root `Entity`'s for particles, flashes and waypoints, `OOEntityWithDrawable`'s for the
   sky. Their descriptions are unchanged (the root's names the C++ class).
2. **A protocol whose adopters are mixed answers for the deleted leaf on the root's facade.** The
   `OOBeaconEntity` selectors (the beacon list's links, codes, labels, icon and jamming) are a
   category `Entity (OOWaypointBeacon)` on the root's facade whose methods ask a waypoint's C++
   part and answer zero (a message to nil's answer) for any other entity's; the ship's and the
   visual effect's facades implement them themselves, so their objects never reach the category.
   `-[Entity respondsToSelector:]` answers a protocol selector for a waypoint's part, and for any
   other object only when its class implements it itself (not the root's category), so every
   answer is as before. The beacon list, the player's compass and the HUD keep their sends; the
   universe's waypoint map and the binding's object are typed `Entity *` / `OOBeaconEntityObject *`.
   This is amendment oo-9ht.129 item 1 applied to a protocol; the protocol and the category go with
   the ship's and the visual effect's facades (oo-9ht.144, oo-9ht.165), when the beacon list
   becomes C++.
3. **A binding's getter answers the C++ part and the object** (`JSWaypointGetWaypointEntity`, as
   `OOJSFlasher`'s): the leaf's own members (`getOriented()`, `size()`, `setSize()`) are member
   calls, and the root's and the protocol's selectors are still sent to the object. A nil or
   non-waypoint object still fails the getter, as `-isKindOfClass:` did.
4. **Tests** (standing approval oo-9n5p9, lines on main first): the facade-class checks and the
   Objective-C-subclass adapter case go; an Objective-C test subclass is a C++ subclass with the
   same answers; the cases call the factories and members, send the root's selectors to the
   object, and keep every expected value. Narrow tests that stood in for a deleted class stand in
   for the C++ class (amendment oo-9ht.107 item 6), with the stand-in root object holding the C++
   part. A new case pins item 2.

**Consequences.** The facades still standing over entities are the root's, `OOEntityWithDrawable`,
the ship family's (ship, station, dock, proxy player), the visual effect's and the quirium
cascade's category; `oo::NewEntityFacade`'s chain names only those. The root's facade now carries
two leaf categories (the planet's shader bindings, the waypoint's beacon selectors) that its own
deletion (oo-9ht.39) turns into C++ (oo-9ht.158 for the shader bindings, a C++ beacon interface for
the list).


## Amendment (bead oo-9ht.183): a ship made in C++, and the proxy's facade

- Date: 2026-10-09. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch M
  (a second one-commit branch, after the leaves). Exemplar: `src/Core/Entities/ProxyPlayerEntity.h/.mm`
  (`newProxyObject()`), `Entities/ShipEntity+ObjCBridge.h/.mm` (`oo::NewShipObject()`,
  `-cxx_initWithShipPart:key:definition:`, the proxy's dials in
  `ShipEntity (OOPlayerSelectorsCalledByName)`), `Universe.mm` (`-cxx_newShipWithName:...`, the
  shipyard), `Entities/PlayerEntity.mm` (the ship-model view, `createDoppelganger()`),
  `tests/unit/core/test_ProxyPlayerEntity.mm`. Follows amendment oo-9ht.177 (the player).

**Context.** Every ship was made by its facade's `-cxx_initWithKey:definition:` (the class picked by
`-cxx_shipClassForShipDictionary:`, or `ProxyPlayerEntity` for the shipyard's and the
doppelganger's ships). The proxy's facade was a subclass of the ship's whose C++ part was an
adapter, and it answered the player's dials to the shaders by name. No C++ path made a ship from a
definition, so the proxy's facade could not go.

**Decision (recommended defaults).**

1. **A ship is made in C++ with `oo::NewShipObject(ship, key, dict)`**: a new ship's facade holding
   the C++ ship, set up from the definition by the same body as `-cxx_initWithKey:definition:` (the
   body after `[super init]` is `-initShipSetUpWithKey:definition:`; the initialiser that takes a part,
   `-cxx_initWithShipPart:key:definition:`, stores it once, so the root's `-init` body runs once, as
   the adapter's construction did), retained (+1) as `+alloc`/`-init`'s object was, nil when the
   set-up fails. The player keeps its own path (it is made before ship data is loaded).
2. **The proxy is made by `ProxyPlayerEntity::newProxyObject(key, dict)`**: `oo::NewShipObject`,
   then the proxy's defaults, as the facade's initialiser did after `[super ...]`. The universe's
   `-cxx_newShipWithName:usePlayerProxy:` makes it where it picked the proxy's class (a flag, not
   a class, inside the `@try`); the shipyard and the ship-model view call it directly.
   `createDoppelganger()` answers the object (`::ShipEntity *`) and copies the player's values into
   the proxy's C++ part when the made ship is a proxy (a ship of another class did not answer
   `-copyValuesFromPlayer:`).
3. **The proxy's dials by name**: the ship's facade's category of the player's by-name selectors
   answers the eleven the proxy's facade implemented (`fuelLeakRate`, `massLocked`,
   `atHyperspeed`, `dialForwardShield`, `dialAftShield`, `dialMissileStatus`,
   `dialFuelScoopStatus`, `compassMode`, `dialIdentEngaged`, `trumbleCount`, `tradeInFactor`) from a
   proxy's part first, and `-respondsToSelector:` answers them for a proxy's part; `-alertCondition`
   already reaches the proxy's override (`SHIP_PART`, amendment oo-9ht.177 item 2). The shader
   whitelist's player-ship check is `dynamic_cast` for both classes. The proxy's setters and
   `-copyValuesFromPlayer:` had no by-name callers; they are member calls.
4. **`-isPlayerLikeShip` goes with the facade** (`Entity (ProxyPlayer)` and the proxy's): nothing
   sends it; the proxy's member stays.
5. **Tests** (standing approval oo-9n5p9, lines on main first): the adapter crossing checks and the
   category's answers for the player, a plain ship and a plain entity go; the cases make the proxy
   with `newProxyObject()` and call its members with every expected value kept; a new case pins
   item 3.

**Consequences.** No Objective-C subclass of the ship's facade but the station's and the dock's
remains; `oo::NewShipObject` is the C++ ship-construction path their facade deletions (oo-9ht.175,
oo-9ht.180) and the ship's (oo-9ht.144) can use for `-cxx_newShipWithName:` itself.


## Amendment (bead oo-9ht.175): the station's facade, the last giant subclass of the ship's

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch N
  (one branch). Exemplar: `src/Core/Entities/StationEntity.h/.mm` (`newStationObject()`,
  `initStationDefaults()`, `willDealloc()`, `oo::ToStation()`), `Entities/ShipEntity+ObjCBridge.mm`
  (`StationPart()`, the categories `ShipEntity (OOAIStationStubs)` and
  `ShipEntity (OOStationSelectorsCalledByName)`), `Universe.mm` (`-cxx_newShipWithName:...`,
  `isStationShipDictionary()`, `setUpSpace()`), `Entities/ShipEntityLoadRestore.mm`,
  `Scripting/OOJSStation.mm`, `tests/unit/core/test_StationEntity.mm`, `test_OOJSStation.mm`.
  Applies amendments oo-9ht.177 (the player) and oo-9ht.183 (a ship made in C++) to the station.

**Context.** The Objective-C `StationEntity` was a subclass of the ship's facade whose every method
forwarded to `cxx::StationEntity` (114 forwarders after slices 1-4). It was the class
`-cxx_shipClassForShipDictionary:` picked for a station or carrier, the object of every station
(the universe's station list, the player's docked and target stations, a ship's target station),
and the receiver of the station's AI actions (`launchDefenseShip`, `increaseAlertLevel`, ...),
which the game sends by name.

**Decision (recommended defaults).**

1. **The station is made in C++ and its object is the ship's facade.** `class StationEntity :
   public cxx::ShipEntity` is global; `StationEntity::newStationObject(key, dict)` is
   `oo::NewShipObject(oo::makeRef<StationEntity>(), key, dict)` followed by the facade's initialiser
   body after `[super ...]` (`initStationDefaults()`), +1 as `+alloc` gave. The universe's
   `-cxx_newShipWithName:...` and the ship loader make a station where the class was picked:
   `Universe::shipClassForShipDictionary()` (and its `cxx_` selector) became
   `isStationShipDictionary()`, which answers the same test. The facade's `-dealloc` body is
   `willDealloc()`, which `-[ShipEntity dealloc]` calls first for a station's part, as the
   player's (amendment oo-9ht.177 item 1). `oo::NewEntityFacade`'s chain loses its station line.
   **`isVisibleToScripts()` is overridden** to answer the ship's answer: the ship's JS category asks
   a C++ part, and a ship made in C++ that does not override it answers the root's NO, which would
   hide the station from scripts (`system.mainStation` null); the facade inherited the ship's YES.
2. **`StationEntity *` names the C++ class.** Members, selectors and bridge functions that took or
   answered a station keep their spelling and now pass the C++ station; where the Objective-C
   object is wanted it is `oo::ToObjC(station)` (the ship's facade), and an object is a station's
   by `oo::ToStation(entity)` (`dynamic_cast` of its C++ part; nullptr for nil or another entity),
   which replaces every cast `(StationEntity *)object` and `-isKindOfClass:[StationEntity class]`.
   Lists of stations keep the objects (`std::vector<oo::ObjCRef<::ShipEntity *>>`: the universe's
   station list and its snapshots, the JS bindings' bridge functions; amendment oo-9ht.107 item 4).
   Three answers keep the object rather than the station because they held other entities too:
   the main station's object for the JS bindings' bridges, `setUpSpace()`'s candidate (a rolled
   non-station is logged and released as before), and **`ShipEntity::targetStation()`**, which
   answers `::Entity *`: an escort's target station is its mother, which need not be a station.
3. **Sends become member calls, converted by compiler diagnostics** (the batch F/I converter, nil
   guards for every receiver but `self`), with the facades' forwarders as the map: the station's,
   then the ship's and the root's. Inside the station's members `[self ...]` is a member call and
   `self` is `oo::ToObjC(this)` only where the object is passed on.
4. **Selectors found by name on a station: the ship's facade answers them for a station's part**
   (amendment oo-9ht.177 item 3). `ShipEntity (OOStationSelectorsCalledByName)` holds exactly the
   41 selectors only the station's facade answered whose signature a by-name dispatcher can call;
   each answers the station's member, zero for any other ship (`alertLevel` green: its enum has no
   zero), and `-respondsToSelector:` answers them for a station's part only, so the dispatchers
   never ask another ship. The selectors both facades answered: those the ship's facade
   forwarded through `SHIP_PART` already reach the station's override; the AI stubs
   `ShipEntity (OOAIStationStubs)` (`increaseAlertLevel`, `decreaseAlertLevel`, `abortAllDockings`,
   `launchShipWithRole:`, `launchPolice` and the seven `launch...` launchers) ask a station's part
   first, with the station's signatures (a launcher answers the ship launched, nil for a ship
   that is not a station, which still logs). For `callObjC("launchPatrol")` on a ship that is not
   a station that is null where it was `false`; nothing else that is observable changes. The
   player's by-name `dockedStation` and `getTargetDockStation` keep answering the station's object
   (a C++ result could not be called by name). A send of
   a station-only selector to an object typed as another class (`[[self owner]
   addShipToLaunchQueue:...]` for a docked escort) asks `oo::ToStation()` first and sends as
   before otherwise (a dock answers it itself).
5. **Tests** (standing approval oo-9n5p9, lines on main first): the facade's own cases go (listed
   in the approval lines); every other case asks the C++ class with its expectations kept. A
   whole-game test's Objective-C subclass of the station is a C++ subclass made as
   `newStationObject()` makes a station; `cxx::ShipEntity::setUpOneStandardSubentity()`, which they
   override, is virtual (the test seam amendment oo-9ht.107 item 6 allows). A
   narrow test that stood in for the Objective-C station (an `@interface StationEntity`) stands in
   for the C++ class with the header's member signatures and the same answers (amendment
   oo-9ht.107 item 6); the binding calls the station's virtual members it shares with the ship by
   their final overrider (`station->cxx::ShipEntity::alertCondition()`), which is the call the
   send made for the one station class the game has (amendment oo-9ht.177 item 5).
6. **Left as they were (follow-up), as for the player:** the station's data members stay public
   and its raw retained Objective-C pointers (`player_reserved_dock`, ...) stay as they were.

**Consequences.** No Objective-C subclass of the ship's facade but the dock's remains; the ship's
facade carries the station's by-name selectors until it is deleted (oo-9ht.144), when they join
the C++ name tables. The dock's facade (oo-9ht.180) can use `oo::NewShipObject` the same way.


## Amendment (bead oo-9ht.180): the dock's facade, the last subclass of the ship's

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch N
  (a second one-commit branch, after the station). Exemplar: `src/Core/Entities/DockEntity.h/.mm`
  (`newDockObject()`, `initDockDefaults()`, `willDealloc()`, `oo::ToDock()`),
  `Entities/ShipEntity+ObjCBridge.mm` (`DockPart()`, `ShipEntity (OODockSelectorsCalledByName)`),
  `Universe.mm` (`newDockWithName()`), `Scripting/OOJSDock.mm`, `tests/unit/core/test_DockEntity.mm`,
  `test_OOJSDock.mm`. Applies amendment oo-9ht.175 to the dock.

**Context.** The Objective-C `DockEntity` was the last subclass of the ship's facade: every method
forwarded to `cxx::DockEntity` (46 forwarders after slices 1-3), the universe's
`newDockWithName()` made it with `+alloc`, and the station's dock lists held its objects.

**Decision (recommended defaults).** As for the station (amendment oo-9ht.175 items 1-5):

1. `class DockEntity : public cxx::ShipEntity` is global; `DockEntity::newDockObject(key, dict)` is
   `oo::NewShipObject(oo::makeRef<DockEntity>(), key, dict)` and the facade's initialiser body
   (`initDockDefaults()`), +1; `Universe::newDockWithName()` (and its `cxx_` selector) answers that
   object, `::ShipEntity *`, as the ship set-up that adds it as a subentity holds it. The facade's
   `-dealloc` body (`clearIdLocks(nil)`) is `willDealloc()`, called first by `-[ShipEntity dealloc]`.
   `isVisibleToScripts()` answers the ship's answer, which the facade inherited.
2. `DockEntity *` names the C++ class; an object is a dock's by `oo::ToDock(entity)`; the station's
   dock lists keep the objects (`std::vector<oo::ObjCRef<::ShipEntity *>>`). The ship's adapter has
   no other `Base` left than `cxx::ShipEntity`.
3. Sends become member calls by the converter (the dock's, the ship's and the root's forwarders).
4. **By name:** `ShipEntity (OODockSelectorsCalledByName)` answers the ten selectors only the dock's
   facade answered whose signature a by-name dispatcher can call, for a dock's part only; the five
   both the station's and the dock's facades answered (`clear`, `autoDockShipsOnApproach`,
   `dockingCorridorIsEmpty`, `clearDockingCorridor`, `countOfShipsInLaunchQueueWithPrimaryRole:`)
   and `abortAllDockings` ask a dock's part after a station's, and `-respondsToSelector:` answers
   each for the part whose facade answered it. The two station selectors answering a dock
   (`playerReservedDock`, `selectDockForDocking`) answer the dock's object, as they did. A docked
   escort's `addShipToLaunchQueue:` goes to its owner's station or dock part (no other owner
   answered the selector).
5. **Tests** (oo-9n5p9, lines on main first): the facade's own cases (`dockReleasedBeforeInit`,
   `dockWithoutPart`, the alias checks of `objCDockPartIsADock`) go; the narrow binding test stands
   in for the C++ dock; every other case calls the members with every expected value kept.

**Consequences.** No Objective-C subclass of the ship's facade is left; its deletion (oo-9ht.144)
turns the player's, the proxy's, the station's and the dock's by-name categories into C++ name
tables and `oo::NewShipObject` into a plain C++ factory.


## Amendment (bead oo-9ht.144): the ship's facade, and the ship family's selectors found by name

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch O
  (one branch). Exemplar: `src/Core/Entities/ShipEntity.h/.mm` (`oo::NewShipObject()`,
  `initShipSetUp()`, `shipWillDealloc()`, `oo::ToShip()`, the `ShipScriptEvent` macros),
  `Entities/Entity+ObjCBridge.mm` (`-dealloc`, `-respondsToSelector:`, the categories
  `Entity (OOShipSelectorsCalledByName)`, `(OOPlayerSelectorsCalledByName)`,
  `(OOStationSelectorsCalledByName)`, `(OODockSelectorsCalledByName)`, `(OOWaypointBeacon)`,
  `(SubEntityRelationship)`), `Entities/PlayerEntity.mm` (`newPlayerObject()`, `deferredInit()`),
  `Universe.mm`, `OOShipGroup.mm`, `Scripting/OOJSShip.mm`, `tests/unit/core/test_ShipEntity.mm`,
  `test_ShipEntityAI.mm`, `test_OOShipGroup.mm`. Applies amendments oo-9ht.107, oo-9ht.177,
  oo-9ht.183, oo-9ht.175 and oo-9ht.180 to the ship itself.

**Context.** Once the station's and the dock's facades went (oo-9ht.175, oo-9ht.180) every ship was
C++: the player, the proxy, the station and the dock made in C++ with the ship's facade as their
object, and every other ship an Objective-C `ShipEntity` facade over the ship's adapter
(`oo::ObjCShipEntity`). The facade forwarded ~780 selectors to `cxx::ShipEntity`, ran the ship's
`-dealloc` body, answered the AI's, the legacy scripts', the shaders' and `ship.call()`'s
selectors by name, and carried the player's, the proxy's, the station's and the dock's by-name
categories. About 2,000 sends to ships and 800 places that named the Objective-C class remained.

**Decision (recommended defaults).**

1. **The ship is the global C++ class and every ship is made in C++.** `class ShipEntity : public
   cxx::OOEntityWithDrawable, public cxx::OOSubEntityInterface` (amendment oo-9ht.107 item 3: owners
   reach a ship subentity's `rescaleBy()` / `drawSubEntityImmediate()` through the interface).
   `oo::NewShipObject(ship, key, dict)` is the plain factory every maker uses
   (`[[ShipEntity alloc] cxx_initWithKey:definition:]` before): OOEntityWithDrawable's facade
   holding the ship (`-initWithCxxEntity:`, +1 as `+alloc` gave), then `initShipSetUp()` (the
   facade's `-initShipSetUpWithKey:definition:` body), releasing the object when the set-up fails.
   A ship's object is therefore the drawable's facade, `::Entity *` where it is typed (amendment
   oo-9ht.107 item 4); `oo::ToShip(object)` is the cast that `(ShipEntity *)object` and
   `-isKindOfClass:[ShipEntity class]` were (nullptr for nil or another entity); for an `id`, which
   may be no entity at all (`callObjC()`'s target, a weak reference's object), `oo::ToShip(id)`
   asks `-isKindOfClass:[Entity class]` first, as `-isKindOfClass:[ShipEntity class]` answered NO
   for any other object.
   `PlayerEntity::deferredInit()` sends the root's `-initWithCxxEntity:` again and runs
   `initShipSetUp()`, which is what the double `-init` reached.
2. **The facade's `-dealloc` body runs from the root's `-dealloc`, first, for a ship's part:** the
   player's, a station's or a dock's `willDealloc()`, then the weak reference's drop (an ivar of
   the root), then `ShipEntity::shipWillDealloc()`, the rest of the body. The order is the
   facades' order.
3. **`ShipEntity *` names the C++ class everywhere.** Members, selectors and bridge functions that
   took or answered a ship keep their spelling and now pass the C++ ship; where the Objective-C
   object is wanted it is `oo::ToObjC(ship)`. Factories named `new...` keep the +1 on the ship's
   object (their comments say so; `OO_RETURNS_RETAINED` no longer applies to a C++ result, except
   on the `new...Object()` makers, which answer the object). Lists of ships keep the objects
   (`std::vector<oo::ObjCRef<::Entity *>>`), as do the weak references, the groups' members and
   the AI's owner. A member whose `ShipEntity *` was the type and not the answer keeps answering the
   object: `Entity::parentEntity()` (a visual effect's subentity's parent is the effect) and
   `rootShipEntity()` (an entity marked as a ship), `::Entity *` since this bead. Where a local
   typed `ShipEntity *` held any entity and only the root's members were asked of it (a target
   that may be a wormhole: `enterTargetWormhole()`, the player's lost-target check, the HUD's
   secondary reticles) it is the root (`cxx::Entity *`) or the object, not `oo::ToShip()`.
   A C-style cast between a C++ pointer and an Objective-C pointer compiles silently (it
   reinterprets); every one in the files this bead touches is an `oo::ToObjC()`/`oo::ToCxx()` or
   a `static_cast` of the C++ part, including the wormhole casts left by bead oo-9ht.112
   (`enterWormhole()`, the HUD's wormhole scan, `ship.enterWormhole()`), found from clang's AST
   (`CPointerToObjCPointerCast` and its reverse).
4. **Sends become member calls, converted by compiler diagnostics** (the batch F/I converter with
   nil guards for every receiver but `self`), with the ship facade's forwarders as the map, then
   the drawable's and the root's; NSObject's lifetime selectors go to the object. Inside the
   ship's members `[self ...]` is a member call; `self` is `oo::ToObjC(this)` only where the object
   is passed on.
5. **Selectors found by name on a ship: the root's facade answers them for a ship's part**
   (amendment oo-9ht.177 item 3, oo-9ht.106 item 2). `Entity (OOShipSelectorsCalledByName)` holds
   exactly the selectors the ship's facade answered, and the root's and the drawable's facades do
   not, whose signature a by-name dispatcher can call (408, generated from the forwarders, bodies
   unchanged but for the receiver); each answers the ship's member, zero for any other entity, and
   an object result is the object. The player's, the proxy's, the station's and the dock's
   categories move from the ship's facade to the root's unchanged but for the receiver.
   `-[Entity respondsToSelector:]` answers each set for its class's part only, and for an object
   whose class implements the selector itself (the visual effect's facade), so every answer is as
   before. The `OOBeaconEntity` selectors (`Entity (OOWaypointBeacon)`) and `Entity
   (SubEntityRelationship)` ask a ship's part as well as a waypoint's. The JS questions
   (`-isVisibleToScripts`, `-getJSClass:andPrototype:`, `-cxx_oo_jsClassName`) are the root's
   category asking the C++ part, whose ship overrides answer (oo-ak1km); `ShipEntity
   (OOJavaScriptExtensions)` goes (nothing sent its other two selectors).
6. **Tests** (standing approval oo-9n5p9, lines on main first): the facade's own cases go (listed
   in the approval lines); every other case makes its ships with `oo::NewShipObject()` and calls
   their members, with every expected value kept. A whole-game test's Objective-C subclass of the
   ship is a C++ subclass overriding the members the Objective-C one overrode. A narrow test that
   stood in for the Objective-C ship stands in for the C++ class (amendment oo-9ht.107 item 6): a
   global `ShipEntity` declared with the header's names and signatures under a stand-in root
   object holding it in `_cxxEntity`, the test's own `oo::ToObjC()`, and the expectations that
   compared a ship object compare the ship. Where the code under test calls a virtual member whose
   final overrider is ShipEntity's on a ship that is not final, the call is qualified
   (`ship->ShipEntity::setOwner(ship)` in `OOShipGroup::removeShip()`), as amendments oo-9ht.177
   and oo-9ht.175 qualified the player's and the station's, so the stand-in links.
7. **Left as they were (follow-up), as for the player and the station:** the ship's data members
   stay public and its raw retained Objective-C pointers (`shipAI`, the weak references) stay
   retained by hand; each is a change of its own.

**Consequences.** No Objective-C class of the ship family is left. The root's facade carries the
ship family's by-name categories until it is deleted (oo-9ht.39), when they become C++ name
tables; the drawable's facade (oo-9ht.40) is now the object of every ship.

## Amendment (bead oo-tzd3n): a C-style cast between a C++ and an Objective-C pointer is a gate failure

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch P.
  Files: `tools/objc-cast-scan.sh`, `tools/objc-cast-scan.query`, `tools/objc-cast-scan-selftest`,
  `tools/tier-a.sh` (step 4), `tools/guardrails.sh` (`check_castscan`), `tests/nightly/checks.txt`.

**Context.** Amendment oo-9ht.144 item 3 recorded that an explicit cast between a C++ record
pointer and an Objective-C object pointer compiles without a diagnostic and reinterprets the
pointer, and that three such casts (bead oo-9ht.112's wormhole casts) had already shipped. Batch O
found them with a throwaway AST scanner; nothing stopped the next one.

**Decision (recommended defaults).**

1. **The gate is clang's AST, not a grep.** `tools/objc-cast-scan.query` is a clang-query matcher:
   an explicit cast (C-style, `static_cast`, `reinterpret_cast`, functional) whose destination is
   an Objective-C object pointer (`id`, `Class`, `id<P>`, `Foo *`) and whose operand is a pointer
   to a record, or the reverse. It runs with each TU's own compile command, so a name's world
   (`cxx::Entity` or `::Entity`, a global C++ `ShipEntity`) is the compiler's answer, not a list.
   A finding in the TU or in a project header (`src/`, `tests/`) fails.
2. **Absolute, no baseline, no suppression comment.** The tree has no such cast (scanned whole on
   adoption), so any finding is new. A cast that really must cross says so through `void *`
   (`(Foo *)(void *)p`), which the matcher leaves alone, as it leaves Core Foundation bridging
   (`struct __CF*`/`__CG*`) and the runtime's `objc_object`/`objc_class`. The right conversion is
   `oo::ToCxx()` / `oo::ToObjC()` / `oo::ToShip()` or a `static_cast` of the C++ part.
3. **Where it runs.** Per file in `tools/tier-a.sh` as step 4 (~3 s on `ShipEntity.mm`, inside the
   30 s budget); the whole tree nightly (`tools/objc-cast-scan.sh --all`, two TUs at a time).
   Not in `tools/guardrails.sh`, which is offline in < 5 s and has no compile database: the guard
   there is on the scanner itself (`check_castscan`): a change that touches the matcher, the
   script, its selftest or `tier-a.sh` must leave `tools/objc-cast-scan-selftest` passing (seven
   planted casts found, ten look-alikes passed, a project header's cast reported at the header, an
   unparsable TU a failed scan rather than a pass). `tools/guardrails-selftest` proves that check
   fails on a neutered matcher and on a deleted selftest.

## Amendment (bead oo-9ht.165): the visual effect's facade, the last subclass of the drawable's

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch P
  (one branch). Exemplar: `src/Core/Entities/OOVisualEffectEntity.h/.mm`
  (`oo::NewVisualEffectObject()`, `oo::ToEffect()`, the JS overrides), `Entities/Entity+ObjCBridge.mm`
  (`EffectPart()`, `Entity (OOVisualEffectSelectorsCalledByName)`, the effect branches of
  `(OOWaypointBeacon)`, `(SubEntityRelationship)` and the ship category's shared selectors,
  `-respondsToSelector:`), `Universe.mm`, `HeadUpDisplay.mm`, `Scripting/OOJSVisualEffect.mm`,
  `tests/unit/core/test_OOVisualEffectEntity.mm`, `test_OOJSVisualEffect.mm`. Applies amendment
  oo-9ht.144 to the effect.

**Context.** `cxx::OOVisualEffectEntity` (slices oo-ukxy8, oo-xkf6c) sat behind an Objective-C
`OOVisualEffectEntity : OOEntityWithDrawable` facade that the universe allocated, that answered the
beacon and subentity protocols, the shader bindings' selectors and the binding's JS category, and
that the universe, the HUD and the bindings messaged. It was the last Objective-C subclass of the
drawable's facade.

**Decision (recommended defaults).**

1. **The effect is the global C++ class**, `class OOVisualEffectEntity : public
   cxx::OOEntityWithDrawable, public cxx::OOSubEntityInterface` (owners reach an effect
   subentity's `rescaleBy()` / `drawSubEntityImmediate()` through the interface, as a ship's).
   `oo::NewVisualEffectObject(key, dict)` replaces `[[OOVisualEffectEntity alloc]
   cxx_initWithKey:definition:]`: the drawable's facade holding a new effect (+1, as `+alloc`
   gave), then `initWithKey()`, releasing the object when it fails. An effect's object is therefore
   `::Entity *` where it is typed (the universe's `newVisualEffectWithName()` /
   `addVisualEffectAt()` and their bridge selectors, `system.addVisualEffect()`); lists of effect
   subentities keep the objects (`std::vector<oo::ObjCRef<::Entity *>>`). `oo::ToEffect(object)` is
   the cast that `(OOVisualEffectEntity *)object` and `-isKindOfClass:[OOVisualEffectEntity class]`
   were (nullptr for nil or another entity). The facade line of `oo::NewEntityFacade()` goes (the
   drawable's facade is the effect's).
2. **Sends become member calls** (the batch O converter with nil guards); where an object is
   wanted (the beacon list, the mesh's owner, a subentity's owner) it is `oo::ToObjC(effect)`.
3. **Selectors found by name on an effect: the root's facade answers them for an effect's part**
   (amendment oo-9ht.144 item 5). `Entity (OOVisualEffectSelectorsCalledByName)` holds exactly the
   selectors the effect's facade answered and the root's and the drawable's facades (with the
   ship's category) did not, whose signature a by-name dispatcher can call (15: the scales, the
   break-pattern flag, the shader uniforms, `effectInfoDictionary`, `remove`, ...); the ship's
   category answers the eight it shares with the effect (`clearSubEntities`, `setUpSubEntities`,
   `subEntityCount`, the orientation vectors, `scriptInfo`, `hullHeatLevel`) for an effect's part
   too; `Entity (OOWaypointBeacon)` and `Entity (SubEntityRelationship)` ask an effect's part as well
   as a ship's and a waypoint's. `-[Entity respondsToSelector:]` answers each for an effect's part,
   so every answer is as before (the shader uniforms ask it before they bind). The JS questions are
   the C++ effect's `getJSClass()` / `jsClassName()` / `isVisibleToScripts()` overrides (the
   binding's functions), which the root's category asks; `-subEntitiesForScript` goes (nothing sent
   it; its body `OOJSVisualEffectSubEntitiesForScript()` stays).
4. **Tests** (standing approval oo-9n5p9, lines on main first): `test_OOVisualEffectEntity` makes
   effects with `oo::NewVisualEffectObject()` and calls their members, its `facadeContract` case
   losing only the facade-class check and asking `oo::ToEffect()`/`oo::ToObjC()` for the crossings;
   the binding tests (`test_OOJSVisualEffect`, `test_OOJSFlasher`) stand in for the C++ class under a
   stand-in root object, as for the ship; every expected value kept.

**Consequences.** No Objective-C subclass of `OOEntityWithDrawable` is left: the drawable's facade
(oo-9ht.40) is the object of every ship and effect, and goes with them into the root's when it is
deleted. The effect's by-name category joins the ship family's on the root's facade until
oo-9ht.39.

## Amendment (bead oo-9ht.40): the drawable's facade

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch P.
  Exemplar: `src/Core/Entities/OOEntityWithDrawable.h/.mm`, `Entity+ObjCBridge.h` (the
  `OOSubEntity` protocol), `Debug/OODebugMonitor.mm`, `tests/unit/core/test_OOEntityWithDrawable.mm`.

**Context.** After oo-9ht.165 no Objective-C class derived from `OOEntityWithDrawable`'s facade:
it was only the object of every ship, sky and visual effect, answering `-drawable`/`-setDrawable:`
and declaring the `OOSubEntity` protocol.

**Decision (recommended defaults).**

1. **The class is global** (`class OOEntityWithDrawable : public cxx::Entity`; every
   `cxx::OOEntityWithDrawable` is now `OOEntityWithDrawable`), and the facade, its file pair, its
   meson line and its `oo::NewEntityFacade()` line go: a ship's, a sky's or an effect's object is
   the root's facade (`oo::NewShipObject()` and `oo::NewVisualEffectObject()` allocate `::Entity`).
   The drawable member was already `oo::Ref<OODrawable>` (oo-hahfg).
2. **`-drawable` / `-setDrawable:`** are the members `getDrawable()` / `setDrawable()`; the debug
   monitor's `-isKindOfClass:[OOEntityWithDrawable class]` is a `dynamic_cast` of the C++ part of an
   object that is an entity.
3. **The `OOSubEntity` protocol** moves to `Entity+ObjCBridge.h` unchanged: no Objective-C class
   adopts it (its adopters answer through `cxx::OOSubEntityInterface`), but `Entity<OOSubEntity> *`
   stays a type until the root's facade goes (oo-9ht.39).
4. **Tests** (standing approval oo-9n5p9, lines on main first): the Objective-C subclasses of the
   facade and `objCSubclassPartIsTheIntermediateClass` go, as does `cxxSubclassFacade`'s
   facade-class check; the other cases make C++ entities under the root's facade and call the
   drawable members, every expected value kept. `test_SkyEntity` holds the sky's object as
   `Entity *` and asks `-isKindOfClass:[OOEntityWithDrawable class]` as a `dynamic_cast`.

**Consequences.** Only the root's facade is left of the entity classes' Objective-C side (oo-9ht.39).

## Amendment (beads oo-9ht.158, oo-9ht.127): shader uniforms bound to C++ members, and the shader bindings' forwarders

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10; oo-9ht.158's
  own recommended default, taken as written). Batch P. Exemplar:
  `src/Core/Materials/OOShaderUniformMethodType.h/.mm` (`OOShaderMemberBinding`,
  `OOShaderUniformTypeFromEncoding()`, `OOShaderUniformBindMethod()`), `OOShaderUniform.mm`
  (`setBindingTarget()`, `applyBinding()`), `Entities/Entity+ObjCBridge.mm`
  (`kEntityShaderBindings`), `tests/unit/core/test_EntityShaderBindings.mm`.

**Context.** A shader uniform bound to a property name found the method on its target by selector
(`class_getInstanceMethod`, the IMP, the return type's encoding). Every entity name in
`shader-uniform-bindings.plist` is answered by the root's facade (its own methods and the ship
family's by-name categories) and `EntityShaderBindings+ObjCBridge.mm` (the clock, the flavour
numbers and the system attributes) existed only to answer seven of them. A material may bind a
uniform to any method without arguments, not only the listed names (oo-9ht.158's notes).

**Decision (recommended defaults).**

1. **A member table for the listed names, the selector path kept as the fallback.** The entities'
   table (`kEntityShaderBindings`, in the root's bridge beside the parts it asks) has one row per
   plist name an entity answered (64; `laserColor` has no method today and stays unbound): the
   name, `@encode()` of the replaced method's return type, whether the row applies to this
   entity (the predicate `-respondsToSelector:` used for it: any entity, a ship's / an effect's /
   a waypoint's part, a player's or a proxy's), and the getter (the method's body, the receiver
   the C++ part). `OOShaderUniform::setBindingTarget()` asks the registered lookup first
   (`OOShaderMemberBindingFor`); the entities register theirs from `Entity+ObjCBridge.mm`, so the
   uniform still links alone (`test_OOShaderUniform`). A row is used only for an object of the root
   facade's own class (a subclass's object may override the method), and only where it applies and
   its type is bindable; otherwise the uniform binds by selector exactly as before
   (`OOShaderUniformBindMethod()`, the old body moved to `OOShaderUniformMethodType.mm`), so a name
   that failed still fails with the same log line. The uniform type is
   `OOShaderUniformTypeFromEncoding()` of the row's encoding: the type the selector path read
   (including the `NSUInteger` names, whose `Q` encoding has no template and stays unbound).
2. **`applyBinding()` reads a member binding once** into `OOShaderBindingValue` (integers, booleans
   and enums widened to `long long`, floats to `double`, as `OOCallIntegerMethod` /
   `OOCallFloatMethod` widened them), then converts and uploads exactly as before.
3. **oo-9ht.127: `EntityShaderBindings+ObjCBridge.mm` goes** (and its meson line); its seven names
   are rows. `test_EntityShaderBindings` asks the binding a uniform makes for each name and pins the
   row's uniform type (`'f'` is `kOOShaderUniformTypeFloat`, `'I'` `kOOShaderUniformTypeUnsignedInt`)
   with every expected value kept (standing approval oo-9n5p9, line on main first).
4. **Not decided here:** restricting bindings to the listed names (the fallback goes when a proposed
   ADR restricts the set or the last target is C++), and the planet's five names (`Entity
   (OOPlanetShaderBindings)`, not in the plist): they stay on the selector path until oo-9ht.39
   gives the planet its own table.

## Amendment (bead oo-9ht.128): the root's JS category moves to the root's facade

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch P.

**Context.** `EntityOOJavaScriptExtensions+ObjCBridge.h/.mm` held only `Entity
(OOJavaScriptExtensions)` (ShipEntity's went with oo-9ht.144, PlayerEntity's with oo-9ht.177):
`-isVisibleToScripts`, `-cxx_oo_jsClassName`, `-getJSClass:andPrototype:` and `-deleteJSSelf`
asking the C++ part or the function holding the body, and the `-oo_jsValueInContext:` override by
which the engine wraps any object. Since oo-9ht.165 and oo-9ht.40 every entity's object is the
root's facade, and the engine still wraps objects by selector until that facade goes.

**Decision (recommended default).** The category moves unchanged to the root's facade
(`Entity+ObjCBridge.h/.mm`, as amendment oo-9ht.144 item 5 moved the ship family's by-name
categories), and the bridge pair and its meson line go. The C++ side was already the classes'
virtual members (`getJSClass()`, `jsClassName()`, `isVisibleToScripts()`, overridden by every
leaf); the selectors are what the engine and the bindings send to objects, so they stay where the
objects are until oo-9ht.39 makes the engine take C++ entities (amendment oo-ppc item 5).
`test_EntityOOJavaScriptExtensions` still sends them to entities' objects and is unchanged.

## Amendment (beads oo-9ht.181, oo-9ht.169, oo-9ht.170, oo-9ht.96): a binding's send functions inlined while the universe and the root entity facade are still Objective-C

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch Q
  (one branch). Exemplar: `src/Core/Scripting/OOJSShip.mm`, `OOJSSystem.mm`, `OOJSPlayerShip.mm`,
  `src/Core/Debug/OOJSConsole.mm`.
  Follows amendments oo-luhd, oo-ft5n and oo-18mg2, and the precedent of `OOJSStation.mm`
  (oo-qps.62, oo-9ht.97).

**Context.** `OOJSShip+ObjCBridge`, `OOJSSystem+ObjCBridge` and `OOJSPlayerShip+ObjCBridge` held
one-line functions for the bindings' sends to classes that were Objective-C when the slices ran.
Since then the player (oo-a70, oo-9ht.177), the ship family (oo-9ht.144) and the GUI (oo-9ht.143)
are C++, so most bodies were already nil-guarded member calls; the rest message the universe
(`UNIVERSE`, still the facade over `cxx::Universe`, oo-pas), the engine's facade
(`+sharedEngine`), `OONull`, a weak reference, a deferred call by selector (`-dumpCargo`) and an
entity's `-isVisibleToScripts`. The PlayerEntity JS category the PlayerShip bridge once held went
with the player's facade (oo-9ht.177).

**Decision (recommended defaults).**

1. **Each function is inlined at its call and the bridge pair, its meson line and its import go**
   (generated, `.agent-tmp/cc/batchQ/inline.py`, then read): a body `return E;` becomes `E`
   (parenthesised where an operator needs it), a void body `if (p != nullptr)  p->m(...);` stays a
   statement, the parameters replaced by the arguments. The nil guard is kept wherever the
   function had one, so a null player answers the same value-initialised result. Where an
   argument with an effect would have been evaluated twice (`OOPlayerForScripting()`,
   `oo::ToShip(ships[0].get())`) it is a local first.
2. **A send to a class that is still Objective-C stays a message, written in the binding**, as
   `OOJSStation.mm` and every converted entity class already send `[UNIVERSE ...]`: it is the same
   message the bridge sent, so each binding test's `FakeUniverse` and the engine's stand-ins answer
   unchanged. It becomes a member call with the universe's conversion (oo-pas) or with the root
   entity facade's deletion (oo-9ht.39: `-isVisibleToScripts`, `-dumpCargo` by selector), not
   here. The bindings therefore contain Objective-C message syntax again; their files' notes say
   so.
3. **oo-9ht.96: the console's `-inspect` the same way.** `OOJSConsole+ObjCBridge` held only
   `OOJSConsoleInspect()`: `-inspect` (added to `Entity` by the Mac debug OXP's inspector, never
   built today) sent to an entity that answers it. Its bead waited for the root facade's deletion or
   for the inspector to be dropped; dropping it would change `test_OOJSConsole`'s `inspectEntity`
   expectation (an entity that answers `-inspect` is asked once), so instead the category
   declaration and the `-respondsToSelector:` test move into `OOJSConsole.mm` unchanged (it already
   messages objects: `-cxx_oo_jsClassName` for `callObjC()`), and the bridge pair, its meson line
   and its `test_OOJSConsole` link entry go. When the root facade goes (oo-9ht.39) the send becomes
   the C++ entity's inspector hook, or nothing, with that bead's note.
4. **No test expectation changes.** The binding tests link the whole game and never named the bridge
   functions (`test_OOJSConsole`'s meson entry only stops linking the deleted file); no test file
   changes, and every expectation and the js-api-contract are unchanged.

**Consequences.** Four bridge pairs fewer; the bindings' and the console's remaining Objective-C is
exactly their sends to the universe, the engine's facade and the root entity facade, which go with
those classes.

## Amendment (bead oo-9ht.39.3): an entity's JS object holds the C++ entity (oo-9ht.39 step 2)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch R
  (one branch). Exemplar: `src/Core/Scripting/OOJSEntityHolder.h`, `OOJSEntity.h/.mm`,
  `EntityOOJavaScriptExtensions.h/.mm`, `src/Core/Entities/Entity.h/.mm`, `OOJSShip.mm`,
  `tests/unit/core/test_OOJSWormhole.mm`. Applies amendment oo-6symp to the entities; step (2) of
  the oo-9ht.39 plan (batch P's notes on oo-9ht.39).

**Context.** Every entity's JS object held, in its private slot, the root facade's weak reference
(`-weakRetain`); the engine made it by `-oo_jsValueInContext:` on the facade, finalized it with
`OOJSObjectWrapperFinalize` and described it with `OOJSObjectWrapperToString`, and every binding
unwrapped it with a `DEFINE_JS_OBJECT_GETTER(..., Entity)` getter that answered the facade, then took
its C++ part with `oo::ToCxx`/`oo::ToShip`/`oo::ToStation`. The facade cannot go while the JS side
holds and answers it.

**Decision (recommended defaults).**

1. **The slot holds an `OOJSEntityHolder`** (`OOJSEntityHolder.h`): an `oo::RefCounted` and
   `OOJSPrivateObject` holding `oo::WeakRef<cxx::Entity>`, so the JS object does not keep the entity
   alive and reads as stale (null) once it has gone, as the facade's weak reference did (the facade
   owns the C++ entity, so both die together). One holder per JS object, set with
   `OOJSSetCxxPrivate`, released by `OOJSCxxObjectWrapperFinalize`; its glue (`jsValueInContext`,
   `clearJSSelf`, `jsDescription`) is defined in `OOJSEntity.mm` and asks the entity while it lives
   (a narrow binding test defines the three as stand-ins, amendment oo-6symp item 5).
2. **`cxx::Entity` implements `OOJSPrivateObject`.** `jsValueInContext()` is
   `EntityJSValueInContext()`'s body on the C++ entity (the JS class, prototype and visibility its
   virtual members answer, the GC root, the engine-reset observer keyed by the C++ entity);
   `clearJSSelf()` does nothing (OOObject's `-oo_clearJSSelf:`, which the facade did not override);
   `jsDescription()` is what the facade's `-cxx_oo_jsDescription` answered (`[<jsClassName>
   <components>]`, `[object <jsClassName>]` without components, the facade's class name "Entity"
   with no JS class name); `deleteJSSelf()` is `-deleteJSSelf`'s body. An Objective-C entity (an
   `oo::ObjCEntity` adapter: the tests' subclasses only) is still asked those class questions and
   its description by selector, so its own overrides answer first as before.
3. **The facade's JS selectors stay, as forwarders, while anything sends them.** The facade's JS
   value selector and `-deleteJSSelf` call the C++ members; `-isVisibleToScripts`,
   `-cxx_oo_jsClassName` and `-getJSClass:andPrototype:` stay as they were. The engine still sends
   them to an entity's object where it holds one (`OOJSValueFromNativeObject()`, a property list's
   Object node made by `oo::PListFromObjects`, `OOWeakReference`, the console's `callObjC()` class
   name, `OOJSSystem`'s visibility filter); they go when the entity lists hold C++ entities
   (oo-9ht.39 step 3), not here. Plan item 3's "Object nodes as foreign nodes" is left to that step
   for the same reason: a node holds the object until the lists do not.
4. **Getters answer the C++ entity.** `OOJSEntityGetEntity()` and `OOJSEntityGetEntityOfClass()`
   (the Ship, Planet and Sun classes' getters) are `OOJSGetCxxPrivate`'s JS class check and error,
   then the holder's entity; `JSValueToEntity()` and `EntityFromArgumentList()` take
   `cxx::Entity **`. The bindings' own getters cast the C++ entity (`oo::ToShip`, `oo::ToStation`,
   `oo::ToDock` and `oo::ToEffect` gained `cxx::Entity *` overloads; `dynamic_cast` for the leaves)
   and drop their `oo::ToCxx`. The JS class fixes what the slot holds, so the debug build's
   Objective-C class check goes. Where a binding still messages the entity's object (the Entity
   class's property natives, the plume's, flasher's and waypoint's natives' object, the system's
   `relativeTo`, the console's `-inspect`, the compass target, the vector and quaternion
   conversions through `OOJSEntityObjectFromJSObject()`), it takes `oo::ToObjC()` of the C++
   entity: the same object, until those sends become member calls with the facade's deletion
   (oo-9ht.39 step 4). `OOIsStaleEntity()` gains a `cxx::Entity *` form (the stale player is still
   the global object).
5. **`OOJSNativeObjectOfClassFromJSValue(context, v, [::Entity class])` becomes
   `OOJSEntityFromJSValue(context, v)`**, not `JSValueToEntity()` as the plan said: it answers the
   C++ entity of an entity's JS object, else null, with no error (another value, another object, a
   stale entity), as that answered nil; `JSValueToEntity()` reports an error for an object of
   another class, which these callers (the player ship's autopilot and docking natives, ShipGroup)
   never did.
6. **The entity classes' converter is `OOJSEntityObjectConverter`**: the entity's object as an
   Object node (null once it has gone), as `OOJSBasicPrivateObjectConverter` answered the weak
   reference's object, so `OOJSNativeObjectFromJSValue()` callers (script arguments, timers,
   `callObjC()`'s `this`) get what they got (amendment oo-6symp item 4). Finalize is
   `OOJSCxxObjectWrapperFinalize` for the twelve entity classes; `toString()` is
   `OOJSEntityToString`, `OOJSCxxObjectWrapperToString` for the Entity class and its registered
   subclasses (the same text).
7. **Direct wraps of a C++ entity call `OOJSValueFromCxxObject()`**: the ship itself in ShipEntity's
   equipment-award and kill events, StationEntity's and DockEntity's dock events, `OOECMBlastEntity`
   and the universe's equipment check. The result is the one the facade's selector gave (it now
   forwards to the same member). Where the value is an entity's object from a list or a caller
   (ShipEntity's damage and death events' other entity, the engine's `JSFunctionPredicate`), the
   message stays: an Objective-C entity's own override answers first (`test_OOJavaScriptEngine`'s
   `entityPredicates` pins it), until the lists hold C++ entities (step 3). Also left as messages:
   `OOJSMission`'s `displayModel` and `OOCommodities`' station argument, whose narrow tests stand in
   for the object's JS value (the same message, the same value).
8. **callObjC() is unchanged** (plan item 4 moves to oo-9ht.44): its `this` is still the entity's
   object (item 6), and it still dispatches by selector. See oo-9ht.44's notes for why a name
   table covering exactly today's reachable names is more than the facade's selectors.
9. **Tests** (standing approval oo-9n5p9, lines on main first): the narrow binding tests' stand-in
   slot set-ups hold a holder of the entity's C++ part (a plain stand-in part for an entity made
   without one); they link `OOJSPrivateObject.cpp` (the engine's getter, finalizer and slot) in
   place of their Objective-C getter and finalizer stand-ins, define the holder's glue and the
   entity converter as stand-ins, and those whose binding now asks `oo::ToObjC` answer it from the
   parts they wrapped. `test_OOJSEntity` stands in for the C++ slot glue as it stood in for the
   Objective-C glue (the same error, the same toString()) and its `cFunctions` checks compare the
   object of the entity the C functions answer with the ship, as before. `test_OOJSShipGroup` and
   `test_OOJSConsole` stand in for `OOJSEntityFromJSValue()` and the C++ `JSValueToEntity()`;
   `test_OOJSVector` and `test_OOJSQuaternion` for `OOJSEntityObjectFromJSObject()`. Every OO_TEST
   case and expected value is kept, and the js-api-contract reproduces exactly.

**Consequences.** No entity's JS object holds or answers an Objective-C object; the bindings take
C++ entities. The root facade's JS selectors are forwarders kept for the engine's generic paths,
which go with the entity lists (oo-9ht.39 step 3); the bindings' remaining sends to an entity's
object go with step 4.

## Amendment (bead oo-9ht.39.4): the universe's and the collision regions' borrowed entity lists hold C++ entities (oo-9ht.39 step 3a)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch S
  (one branch). Exemplar: `src/Core/Entities/Entity.mm` (the linked lists), `src/Core/CollisionRegion.h/.mm`,
  `Universe::filterSortedLists()`. Step (3) of the oo-9ht.39 plan, split: (3a) the lists, here;
  (3b) the engine's generic paths (oo-9ht.39.5).

**Context.** The universe kept its sorted list (`sortedEntities`), the axis lists' heads
(`x/y/z_list_start`) and its id table (`entity_for_uid`) as raw pointers to the entities' Objective-C
objects; every entity linked its neighbours (`x/y/z_previous/next`), its collision chain and its
collider the same way; a collision region listed objects (`entity_array`). Every reader took
`->_cxxEntity->` to reach the state. The facade cannot go while the lists hold it.

**Decision (recommended defaults).**

1. **The borrowed lists hold C++ entities**, raw `cxx::Entity *` where they held a raw `::Entity *`:
   `Universe::sortedEntities`, `x/y/z_list_start`, `entity_for_uid`; `cxx::Entity`'s
   `x/y/z_previous/next`, `collision_chain` and `collider`; `CollisionRegion::entity_array`, with
   `addEntity()`, `checkEntity()` and `shadowAtPointOcclusionToValue()` taking `cxx::Entity *`. They
   never owned (no retain), and still do not.
2. **The owning lists keep the objects** (`oo::ObjCRef<::Entity *>`): `entities`, `allPlanets`,
   `allStations`, `activeWormholes`, `entitiesDeadThisUpdate`, `waypoints`, `cargoPods`, and an
   entity's `collidingEntities`. The Objective-C object owns its C++ part (amendment oo-bj8), so a
   list of `oo::Ref<cxx::Entity>` would keep the part but let the object die under its peer map and
   its callers; ownership turns round with the facade's deletion (oo-9ht.39 step 4). The borrowed
   lists' entries are therefore alive exactly as long as before.
3. **Readers take the part directly or cross by `oo::ToObjC()`.** State reads drop `->_cxxEntity->`
   (the same member). A message to a listed entity becomes a message to `oo::ToObjC(part)`, the same
   object (an Objective-C entity's adapter answers its owner), so an Objective-C subclass's override
   still answers first; a local that is handed on as an object (the draw list, retained copies,
   `entityForUniversalID:`'s answer, the removal checks) is `oo::ToObjC()` of the entry, and a store
   is `oo::ToCxx()` of the object. `oo::ToShip()`/`oo::ToStation()` take the part (their
   `cxx::Entity *` overloads, the same `dynamic_cast`). Debug log descriptions describe
   `oo::ToObjC()` of the entry, the same text.
4. **Behaviour identical, by construction**: every pointer stored is the part of the object that was
   stored, and `oo::ToObjC(oo::ToCxx(o)) == o`; no entity's lifetime changes (item 2).
5. **Tests** (standing approval oo-9n5p9, lines on main first): `test_Entity`, `test_Universe`,
   `test_CollisionRegion` and `test_ShipEntity` cross at the list members (`oo::ToObjC()` of a read
   entry, `oo::ToCxx()` of a stored object); every OO_TEST case and expected value is kept.

**Consequences.** No universe or region list borrows an Objective-C entity. Left for oo-9ht.39.5:
`OOJSValueFromNativeObject()`, property-list Object nodes of entities, `OOWeakReference` of
entities, `OOJSSystem`'s visibility filter, the console's `callObjC()`/`-inspect` and the entity
converter; for step 4: the owning lists (item 2) and the remaining `oo::ToObjC()` crossings.
## Amendment (bead oo-9ht.91): the debug plug-in controller's branch is dropped

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch S.
  Exemplar: `src/Core/Debug/OODebugSupport.mm`.

**Context.** `OOInitDebugSupport()` loaded the Mac debug plug-in (`LoadDebugPlugIn()`) and, when it
answered `-setUpDebugger`, used its debugger instead of the TCP client; `OODebugSupport+ObjCBridge`
hid that selector (amendment oo-vnts item 2). `LoadDebugPlugIn()` answers nil on every platform
(a macro on the platforms built; on the Mac a stub that logs and answers nil since ADR-0017), so the
controller is always nil and the branch never runs.

**Decision (recommended default).** The plug-in branch, `LoadDebugPlugIn()`, the controller static
and `OODebugSupport+ObjCBridge.h/.mm` are deleted; the TCP client is the debugger whenever the debug
OXP is present, and `setUsingPlugInController(false)` is still sent as before. Behaviour identical
on every platform built (the Mac stub's log line goes with the Mac branch). A plug-in debugger, if
one is ever wanted, implements the C++ debugger interface (amendment oo-9ht.81). `test_OODebugSupport`
is unchanged but for its meson entry, which no longer links the bridge.

## Amendment (bead oo-9ht.81): the debugger interface is C++; the TCP console client's facade is deleted

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch S.
  Exemplar: `src/Core/Debug/OODebuggerInterface.h`, `OODebugTCPConsoleClient.h/.mm`,
  `OODebugMonitor.mm` (`setDebugger()` and the sends to the debugger),
  `tests/unit/core/test_OODebugTCPConsoleClient.mm`. Step 1 of oo-9ht.74's plan (the debugger
  half), done before the monitor's facade so the TCP client's facade could go.

**Context.** The monitor held its debugger as `id<OODebuggerInterface>` (an Objective-C protocol)
and messaged it, handing it the monitor's facade; the only debugger built is the TCP console
client (the golden harness's), a C++ class whose Objective-C facade adopted the protocol and
crossed the monitor back with `oo::ToCxx`.

**Decision (recommended defaults).**

1. **`OODebuggerInterface` is a C++ interface** (`OODebuggerInterface.h`): an `oo::RefCounted`
   with one pure virtual member per protocol message, the same names and parameters, taking the
   C++ monitor; plus `description()`, what the monitor's two log lines print for a debugger (the
   facade's `%@`, `<OODebugTCPConsoleClient 0x...>`).
2. **The monitor keeps `oo::Ref<OODebuggerInterface>`** (it retained the object) and calls the
   members with `this`. A message to a nil debugger did nothing; each call is guarded by
   `_debugger != nullptr`. The `@try`/`@catch` around each call stays (a debugger may raise, as the
   test's does). The facade's `-setDebugger:` and `-disconnectDebugger:message:` (and the
   `OODebugMonitorInterface` protocol's) take `OODebuggerInterface *`; they go with the facade
   (oo-9ht.74).
3. **The TCP client implements the interface and leaves namespace cxx** (`OODebugTCPConsoleClient`,
   bead step 2); its facade (`OODebugTCPConsoleClient+ObjCBridge.h/.mm`) and both meson lines are
   deleted. The debug support keeps the client in an `oo::Ref` (it kept the autoreleased facade):
   the client lives while the monitor holds it, and a client that fails to connect is released at
   the end of `OOInitDebugSupport()` rather than at the pool's drain.
4. **Tests** (standing approval oo-9n5p9, lines on main first): `test_OODebugTCPConsoleClient`
   drives the C++ client through the interface members as it drove the facade (every case and
   expected value kept) and retires only `cxxClientAndItsFacade`'s facade-contract checks;
   `test_OODebugMonitor`'s debugger is a C++ `TestDebugger` with the same records;
   `test_OODebugSupport` and `test_OOJSConsole` adapt their stand-ins' signatures.

**Consequences.** Nothing names `id<OODebuggerInterface>` or the Objective-C TCP client. Left for
oo-9ht.74: the engine's monitor protocol (`OOJavaScriptEngineMonitor`, adopted by the monitor's
facade), the console's JS objects (`console`, `console.settings`), which hold the facade's weak
reference and `callObjC()` it (oo-9ht.44), `OODebugMonitorInterface`, and the facade itself.

## Amendment (bead oo-9ht.74.1): the JavaScript engine's monitor is a C++ interface (oo-9ht.74 step 2)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch S.
  Exemplar: `src/Core/Scripting/OOJavaScriptEngineMonitor.h`, `OOJavaScriptEngine.mm`
  (`setMonitor()`, the two sends), `src/Core/Debug/OODebugMonitor.h`.

**Context.** The engine kept its monitor as `id<OOJavaScriptEngineMonitor>` (retained) and sent it
errors and log messages after `-respondsToSelector:`; the only monitor in the game is the debug
monitor, whose facade adopted the protocol in a category and forwarded to the C++ members.

**Decision (recommended defaults).**

1. **`OOJavaScriptEngineMonitor` is a C++ interface** in its own header (so the debug monitor
   does not import the engine's): the protocol's two messages as pure virtual members of the same
   names and parameters (the engine is still handed as its Objective-C object). The protocol and
   the facade's category are deleted.
2. **The engine borrows its monitor** (`OOJavaScriptEngineMonitor *`), where it retained the
   object: the debug monitor lives as long as the process (its facade never died), and a test
   keeps its monitor alive while it is set. The delayed release (`-autorelease` of the old
   monitor) goes with the retain.
3. **The sends need no `-respondsToSelector:`**: an interface implements both members, as the
   only monitor answered both. A null monitor sends nothing, as nil did.
4. **`cxx::OODebugMonitor` implements the interface** (its `jsEngine()` members are the
   overrides) and hands the engine `this`, not its facade.
5. **Tests** (standing approval oo-9n5p9, lines on main first): `test_OOJavaScriptEngine`'s
   `TestMonitor` is a C++ implementation with the same records; `test_OODebugMonitor`'s engine
   stand-in holds the interface, its engine-monitor check compares with the C++ monitor, and its
   two kinds of monitor sends call the members. No expected value changes.

**Record.** Verified with oo-9ht.91 and oo-9ht.81 as one stack (eaf5948da: build, core tests,
goldens, js-api-contract, guardrails); its commit reached main inside oo-9ht.81's merge (f13a39e89),
because the accept pre-merge ran in the shared worktree on this bead's branch.

**Consequences.** What keeps the debug monitor's facade (oo-9ht.74): the console's JS objects
(`console`, `console.settings`), which hold the facade's weak reference and are the `this` of
`callObjC()` (oo-9ht.44), the console script's `console` property (an Object node of the facade),
`OODebugMonitorInterface`, and the tests that drive the monitor through the facade.

## Amendment (bead oo-9ht.74): the debug monitor's facade is deleted; callObjC() on the console is a name table

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch T.
  Exemplar: `src/Core/Debug/OODebugMonitor.h/.mm`, `src/Core/Debug/OOJSConsole.mm` (the console
  objects' slot, `ConsoleConverter`, `kMonitorMethods`), `tests/unit/core/test_OODebugMonitor.mm`.
  The rest of oo-9ht.74's plan after amendments oo-9ht.81 and oo-9ht.74.1.

**Context.** After oo-9ht.81 and oo-9ht.74.1 the debug monitor's facade (`OODebugMonitor+ObjCBridge`)
was held by: the console's JS objects (`console`, `console.settings`: the facade's weak reference in
their private slot, unwrapped by `OOJSBasicPrivateObjectConverter` and checked with
`isKindOfClass:[OODebugMonitor class]`), the console script's `console` property (an Object node of
the facade), the profiler's default `this` (`OOJSValueFromNativeObject()` of the facade), the
player's debug-console key and the game controller's exit (facade sends), `OODebugMonitorInterface`
(adopted by the facade only), and `test_OODebugMonitor`, which drove the monitor through it.

**Decision (recommended defaults).**

1. **The facade, `OODebugMonitorInterface` and namespace cxx go**: `OODebugMonitor` is the C++ class
   (`cxx::OODebugMonitor` renamed everywhere, mechanically). The player's controls and the game
   controller call the members (`::OODebugMonitor::sharedDebugMonitor()->...`).
2. **The monitor is its own JS glue and Object node payload**: it implements `OOJSPrivateObject`
   (`jsValueInContext()` is `-oo_jsValueInContext:`'s body; `clearJSSelf()` does nothing, as
   OOObject's did for the facade) and `oo::PListForeign` (`className()` "OODebugMonitor",
   `description()` `<OODebugMonitor 0x...>`, the facade's `%@`). The console script's `console`
   property is an Object node of the monitor, whose JS value is the console object, as the facade's
   node's was.
3. **The console objects' slot holds the C++ monitor**, with one retain released by the console's
   finalizer (the slot held the facade's weak reference; the monitor is never released, as the
   facade never was, so nothing lives longer). The natives take it from the slot of a `Console` or
   `ConsoleSettings` object (`MonitorFromJSObject`, a JS class check where the facade's was an
   Objective-C class check); their internal error for another `this` describes what it described
   (the class of the object the engine converts `this` to; "(null)" for a plain object). The
   converter (`ConsoleConverter`) answers the monitor's Object node. `console.settings` and the
   console stay one monitor's.
4. **callObjC() on the console objects is a name table (`kMonitorMethods`, debug builds only)**,
   applying oo-9ht.44's default to the monitor ahead of it. The facade answered any selector whose
   signature `OOJSCallObjCObjectMethod()` matched; the table is exactly the facade's own selectors
   without arguments (`clearJSConsole`, `showJSConsole`, `dumpMemoryStatistics`,
   `applicationWillTerminate` on GNUstep; `debuggerConnected`, `TCPIgnoresDroppedPackets`,
   `usingPlugInController`, `dumpJSMemoryStatistics` as scalars; `configurationKeys`, which matched
   no signature) and the two that take the joined string (`performJSConsoleCommand:`,
   `configurationValueForKey:`). Each row calls the member the selector forwarded to and gives the
   result the selector path gave: a scalar row keeps `@encode()` of the facade's return type and is
   read through `OOShaderUniformTypeFromEncoding()`, as the selector's encoding was (so
   `dumpJSMemoryStatistics`, a `size_t` that matched no template on Windows, still answers "cannot
   be called from JavaScript", as does `configurationKeys`); a string row without its argument is
   "requires a parameter". **Behaviour change:** every other name on the console objects answers
   "does not respond to method": the root classes' selectors (`weakRetain`, `retain`, `release`,
   `autorelease`, `copy`, `init`, `dealloc`, `self`, `description`, `isKindOfClass:`,
   `respondsToSelector:`, ...: lifetime and NSObject-protocol calls, or called with their arguments
   missing), the scalar selectors with arguments (`setDebugger:`, which callObjC() called with its
   argument missing: undefined behaviour), and the facade's other selectors with arguments, which
   answered "cannot be called from JavaScript". Nothing in the game, the harness or the goldens
   calls `callObjC()` on the console. The test flavour does not compile `callObjC()` (no `OO_DEBUG`),
   so the table is syntax-checked with `-DOO_DEBUG` and is not run by a unit test.
5. **Tests** (standing approval oo-9n5p9, lines on main first): `test_OODebugMonitor` calls the C++
   members where it sent the facade's selectors, with every expected value kept; it retires only
   `sharedMonitorIsSetUpOnce`'s singleton-boilerplate checks and `cxxMonitorAndItsFacade`'s
   facade-contract checks (that case keeps its C++ checks and checks the monitor's description).
   `test_OOJSConsole` stands in for the monitor's `jsValueInContext()` where it stood in for
   `OOJSValueFromNativeObject()` of the facade (the same console object), and every case and
   expected value is kept (the two internal-error texts included). `test_OODebugTCPConsoleClient`
   and `test_OODebugSupport` rename the class and add no-op stand-ins for its new virtual members.

**Consequences.** Nothing names an Objective-C debug monitor; the Debug module has no facade left.
callObjC()'s other receivers (the entities' objects, through `OOJSEntityObjectConverter`) are
oo-9ht.39.5's and oo-9ht.44's; this amendment's table is the pattern oo-9ht.44 extends.

## Amendment (bead oo-9ht.39.5.1): the system's planets filter and callObjC()'s class name ask the C++ entity (oo-9ht.39 step 3b, part a)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch U.
  Exemplar: `src/Core/Scripting/EntityOOJavaScriptExtensions.h/.mm` (`OOJSEntityIsVisibleToScripts()`,
  `OOJSEntityJSClassName()`), `OOJSSystem.mm` (`system.planets`), `src/Core/Debug/OOJSConsole.mm`
  (`ConsoleCallObjCMethod`). oo-9ht.39.5 is split in three (batch T's recommendation): (a) here,
  (b) weak references of entities (oo-9ht.39.5.2), (c) Object nodes of entities and the entity
  converter (oo-9ht.39.5.3, which blocks oo-9ht.44).

**Context.** Two of the engine's generic paths asked an entity's object a class question by
selector: `system.planets` sent `-isVisibleToScripts` to each planet's object, and the console's
`callObjC()` sent `-cxx_oo_jsClassName` to its `this` for the class name of its error texts. The
root facade's selectors forward to the C++ entity's virtual members; an Objective-C entity (a test
subclass, through its `oo::ObjCEntity` adapter) overrides them.

**Decision (recommended defaults).**

1. **The entity's JS value's two class helpers are exported**: `OOJSEntityIsVisibleToScripts()`
   (the anonymous helper amendment oo-9ht.39.3 made) and `OOJSEntityJSClassName()`, both taking the
   C++ entity: an Objective-C entity's own selector answers first, a C++ entity's member otherwise,
   as the facade's JS value selector asked.
2. **`system.planets` filters with `OOJSEntityIsVisibleToScripts(oo::ToCxx(planet))`**; the list
   is still of the planets' objects (the owning list, amendment oo-9ht.39.4 item 2).
3. **`callObjC()`'s class name of an entity is `OOJSEntityJSClassName()` of its C++ part**; any
   other object is still asked `-cxx_oo_jsClassName` (its `this` is still the converter's object,
   amendment oo-9ht.39.3 item 8, until oo-9ht.39.5.3 and oo-9ht.44).
4. **The console's `inspectEntity()` is left as it is**: `-inspect` is the Mac debug OXP inspector's
   category on the Objective-C class, so only an object can answer it; it is one of the bindings'
   sends to `oo::ToObjC()` that go with the facade's deletion (amendment oo-9ht.39.3 item 4, step 4),
   and `test_OOJSConsole`'s `inspectEntity` case pins it.
5. **Behaviour identical**: the same members answer, through the same overrides. No test changes.

**Consequences.** The root facade's `-isVisibleToScripts` and `-cxx_oo_jsClassName` are sent only
by the helpers, to Objective-C entities. Left for oo-9ht.39.5.2/.3: weak references, Object nodes,
`OOJSValueFromNativeObject()` of an entity and the converter.

## Amendment (bead oo-9ht.39.5.2): weak references of entities hold the C++ entity (oo-9ht.39 step 3b, part b)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch U.
  Exemplar: `src/Core/Entities/ShipEntity.h/.mm` (the targets), `Entity+ObjCBridge.h`
  (`oo::WeakEntityRef()`), `Entity+ObjCBridge.mm` (the facade's `-dealloc`), `oofnd/Ref.hpp`
  (`RefCounted::dropWeakReferences()`), `PlayerEntity.mm` (the target memory).

**Context.** C++ holders kept weak references to entities as the root facade's `OOWeakReference`
(`-weakRetain`, read with `-weakRefUnderlyingObject`): a ship's targets, aggressor, target station,
found/escort/thanked/remembered ships, proximity alert, damaged subentity, aegis lock, laser hit and
beacon links; `Entity::_owner`; a dock's `id_lock`; the ECM blast's ship; the visual effects', the
waypoints' and the universe's beacon links; the player's docked station, compass target and target
memory. The facade drops its weak reference (`weakSelf`) at the start of a ship's `-dealloc`
(before `shipWillDealloc()`) and at the end of any other entity's (`OOWeakRefObject`'s `-dealloc`).

**Decision (recommended defaults).**

1. **They are `oo::WeakRef<cxx::Entity>` of the entity's C++ part** (an Objective-C test entity's
   adapter part). Stored with `oo::WeakEntityRef(object)` (`oo::ToCxx`, empty for nil) or from the
   C++ entity; read with `oo::WeakEntityObject(ref)`, so every getter answers the same object (nil
   once it has gone) and keeps its type. That reader answers the object +0, as the proxy's
   `-weakRefUnderlyingObject` did: `oo::ToObjC()` loads the peer retained and autoreleased, which
   would keep a released entity alive to the end of the pool and make its weak references read it
   after its last release (`test_OOWaypointEntity`'s `neighbours` case caught exactly that). `DESTROY(x)` is `x = nullptr`; the hand `-release`s go (the
   members release themselves; the ship's never released most of them, a leak of the proxies).
2. **The part's weak references die with the object's, at the same points**: `RefCounted` gains
   `dropWeakReferences()` (protected; `cxx::Entity` makes it public), which zeroes them while the
   object lives (`oofnd` test `dropWeakReferencesZeroesThemWhileTheObjectLives`). The facade's
   `-dealloc` calls it where it dropped `weakSelf` for a ship and, for every entity, just before it
   lets go of the part (where `OOWeakRefObject`'s `-dealloc` dropped it), so a weak reference reads
   null exactly when the object's did even if something else still holds the part. A weak reference
   made afterwards is a new identity, as a `-weakRetain` after `-weakRefDrop` was a new proxy.
   `OOJSEntityHolder` (amendment oo-9ht.39.3 item 1) shares this: an entity's JS object reads stale
   from the same point as when its slot held the facade's weak reference.
3. **Identity**: the target memory compared proxies (`[entity weakSelf]`) by identity; it compares
   `WeakRef`s (`==` is the control block's identity, which survives the object's death), an empty
   ref is an empty slot and a non-empty ref is what `-isProxy` was (the HUD's and
   `moveTargetMemoryBy()`'s test). `targetMemory()` answers `std::vector<oo::WeakRef<cxx::Entity>>`.
4. **`-weakSelf` was answered because these members had made it**: the proximity alert's saved
   condition stored `[primaryTarget() weakSelf]` in an Object node; it stores the target's
   `-weakRetain` (autoreleased; the same proxy, made if missing), and `resumePostProximityAlert()`
   reads the node's object back as the target.
5. **Left as they are**: Object nodes holding an entity's weak reference (the proximity condition,
   `StationEntity`'s script accessor's `station`, `ShipEntityAI`'s reader of it) are oo-9ht.39.5.3's
   (Object nodes of entities); the facade's own `weakSelf` stays for its other holders (ship groups,
   AI, shader bindings, `OOWeakSet`). **oo-9ht.22 is not cleared**: materials, shaders, meshes, AI,
   `OOWeakSet`, `OOShipGroup`, the JS definitions and `OOJSScript` still use `OOWeakReference`.
6. **Behaviour identical**: every read answers null at exactly the point it did before (item 2), and
   every getter the same object. Tests (standing approval oo-9n5p9, lines on main first):
   `test_ShipEntity`, `test_ShipEntityAI`, `test_StationEntity` store `oo::WeakEntityRef()` of the
   same entity in their target set-ups; `test_PlayerEntity` reads the empty compass target with
   `.get() == nullptr`. No OO_TEST case or expected value changes.

**Consequences.** No C++ holder in the entities or the universe keeps an entity's `OOWeakReference`.

## Amendment (bead oo-9ht.39.5.3): an entity's property-list Object node answers the C++ entity; the entity converter makes it (oo-9ht.39 step 3b, part c)

- Date: 2026-10-10. Status: Proposed, as above (recommended defaults, CLAUDE.md rule 10). Batch V.
  Exemplar: `src/Core/Entities/Entity+ObjCBridge.h` (`oo::EntityPListForeign`,
  `oo::EntityObjectNode()`, `oo::EntityIn()`, `oo::EntityNodesFrom()`, `oo::EntitiesIn()`),
  `src/Core/Scripting/OOJSEntity.mm` (`OOJSEntityObjectConverter`), `src/Core/Debug/OOJSConsole.mm`
  (`ConsoleCallObjCMethod`).

**Context.** Entities travelled through plist data (script event arguments, script properties,
JS property and method results, the converter's result for an entity's JS object) as
`oo::PListObject(oo::ToObjC(entity))`: an `ObjCPListForeign` holding the root facade, which the
engine turned into JS by `-oo_jsValueInContext:`. The bead asked for `cxx::Entity` to be the node's
payload; batch U found it cannot be (it already derives `oo::RefCounted`, so a second base through
`PListForeign` gives two counts), and that an Object node kept the entity alive through its object,
which owns the part (amendment oo-9ht.39.4 item 2).

**Decision (recommended defaults, batch U's).**

1. **A wrapper payload, `oo::EntityPListForeign`**: an `ObjCPListForeign` (no longer `final`) that
   holds the entity's object, retained, exactly as the old node did (lifetime unchanged), and
   answers its C++ part (`entity()`). Because it is an `ObjCPListForeign`, its class name, its
   description ("%@" of the object), its identity, `oo::ObjectIn()` and its JS value (the object's
   `-oo_jsValueInContext:`, which forwards to the part's glue) are what they were, so every reader
   of the object (the tests' stand-ins of `OOJSValueFromPList()` included) is unchanged. It is
   deliberately **not** an `OOJSPrivateObject` yet: batch V made it one first, and
   `test_OOJSShipGroup` crashed, because the engine (and that test's stand-in of it) asks a payload
   that is its own JS glue before the object, and the test's stand-in C++ entity has no glue (only
   its stand-in object answers `-oo_jsValueInContext:`). With the facade's deletion (oo-9ht.39 step
   4) the payload holds `oo::Ref<cxx::Entity>`, is the part's glue, and `oo::ObjectIn()` of it
   answers nil; the stand-ins get the glue then.
2. **Producers** make it: `oo::EntityObjectNode(entity)` (a C++ entity, a `Ref`, or an entity's
   object; null for none) where they made `oo::PListObject(oo::ToObjC(...))` or `oo::PListObject()`
   of an entity's object (the 19 sites of batch U's audit, plus the compass target and its event
   argument, a ship's found target, aggressor, primary target and proximity alert, the wormhole's
   ships in transit, `system.waypoints`), and `oo::EntityNodesFrom(objects)` where they made
   `oo::PListFromObjects()` of entities (the 32 callers). The one non-entity site the acceptance grep
   matched (`[OONull null]` for a null array element) takes the null's object into a local first.
3. **The entity converter answers the entity node** (`OOJSEntityObjectConverter`): script arguments,
   timers' `this`, `OOJSFunction` arguments and `callObjC()`'s `this` convert to it.
4. **Readers that want the entity take the part**: `oo::EntityIn(node)` (and `oo::EntitiesIn(array)`)
   answer the C++ entity of an entity node, and also of a plain Object node of an entity's object
   (still made by Objective-C callers and the tests' stand-ins), until the facade goes. Moved:
   `OOJSStation` (`launchShipWithRole`, `launchPolice`: the array is rebuilt from the entities, in
   order), `OOJSSystem` (the add-ships group), `OODebugMonitor` (the wormhole dump), and
   `callObjC()`, whose `this` is now the C++ entity (its class name `OOJSEntityJSClassName()` of it);
   the call itself still reaches the entity through its object until oo-9ht.44.
5. **Left as they are**: readers that take any object (`OOJSTimer`'s `this` description,
   `OOJSPlayer`'s dock target, `callObjC()`'s object result, `OOJSObjectWrapperToString`) keep
   `oo::ObjectIn()`, which answers the same object; the weak-reference Object nodes (the proximity
   condition's target, `StationEntity`'s accessor `station` and `ShipEntityAI`'s reader of it) keep
   the object's `-weakRetain`, because `test_StationEntity`'s expectation reads the node's object's
   `-weakRefUnderlyingObject` (they go with `OOWeakReference`, oo-9ht.22, or with the facade).
6. **Behaviour identical**: the same JS values, descriptions, class names and lifetimes. No existing
   test or expected value changes; `test_EntityOOJavaScriptExtensions` adds
   `entityObjectNodeHoldsTheEntity` (the node's object, part, class name, description and JS value;
   a plain node's entity; arrays).

**Consequences.** No code makes an Object node of an entity's object but the weak-reference nodes of
item 5; every entity node answers its C++ entity. oo-9ht.44 can dispatch `callObjC()` on the C++
entity. Left for step 4: the node's JS value still comes through the object (item 1).
