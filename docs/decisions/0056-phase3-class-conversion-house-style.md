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
   the Objective-C header imports go only where nothing uses them.
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
   stand-in that does the same thing. The test evaluates JS and pins the JS-visible results,
   including the error text and what a native's exception becomes. Write it against the
   Objective-C file and run it there first, as item 7 says.
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
