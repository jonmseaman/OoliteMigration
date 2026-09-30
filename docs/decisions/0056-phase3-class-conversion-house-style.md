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
