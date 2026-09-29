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
