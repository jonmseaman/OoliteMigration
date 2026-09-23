# ADR-0031 — `PList::get<T>` retires `oo_*ForKey`; sweeps reach it through a zero-copy `oo::PListView`

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-u77, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** seam 2.4 of [Phase 2](../phases/2-oofnd.md) ("typed accessor `PList::get<T>` and one
fully migrated consumer"); refines [architecture §2.5 and §3.4](../architecture.md). Implemented in
`upstream/oolite/src/oofnd/PListGet.hpp` (declared in `PList.hpp`) and
`upstream/oolite/src/Core/OOPListView.h`; exemplar `upstream/oolite/src/Core/Entities/OOWaypointEntity.mm`.

## Context

`OOCollectionExtractors` gives every `NSDictionary`/`NSArray` (and `NSUserDefaults`) ~70
`-oo_<type>ForKey:defaultValue:` / `-oo_<type>AtIndex:defaultValue:` methods; ~1,800 call sites
use them. Each is a lookup plus an `OO<Type>FromObject()` conversion whose behaviour is GNUstep's:
`NSString -longLongValue` (20-character buffer, saturating), `-intValue` (what the *unsigned*
64-bit reading of a string uses, because `NSString` answers no unsigned selector), NSScanner's own
`-doubleValue` (18 digits, excess integer digits dropped without rescaling, exponent > 511 is no
number), `IsZeroString` (whose "optional minus" tests for a space, so `"-0"` is not zero),
x86-64 `cvttsd2si` for out-of-range reals, and `nil` receivers returning zero rather than the
fallback. 83 sweep beads (`sweep:extractors`) will each retire one file's calls, done by smaller
models, so the shape must be mechanical and the result behaviour-identical by construction.

The obstacle is that game code still holds Foundation collections (from `ResourceManager`,
`OOPropertyListFromData`, JavaScript conversion, `NSUserDefaults`), and will until the Foundation
sweep turns them into `oo::PList`. A sweep bead cannot convert a file's containers as well.

## Decision

1. **`oo::PList` gets `get<T>(key[, fallback])` and `at<T>(index[, fallback])`**, one template per
   shape, with a `oo::PListGet<T>` trait per requested type (Result, Fallback, the no-fallback
   default, the conversion). Supported: every integer type (dispatch by size and signedness: 64-bit
   signed = `OOLongLongFromObject`, 64-bit unsigned = `OOUnsignedLongLongFromObject`, narrower =
   clamp of the long long reading, exact on Windows/LLP64), `bool`, `float`, `double`,
   `oo::NonNegative<float|double>`, `std::string` (a number gives its `-stringValue`), `oo::PList`
   (any value), and `PList::Array`/`Dict`/`Data`/`Date` (kind-checked; these return the
   `const PList*` node so `get`/`at` chain). A game type (vectors, quaternions) joins later by
   specialising `oo::PListGet<T>`; `NSSet` and the fuzzy boolean have no PList counterpart yet.
   The semantics are GNUstep's, ported from GNUstep base 1.31.1 source (`NSScanner.m`,
   `GSString.m`) and pinned by `tests/unit/oofnd/test_plist_get.cpp`: 262 inputs × 16 conversions,
   every expected line captured from `OOCollectionExtractors.mm` compiled at `-O2` and run against
   the gnustep-base the game links. A null `PList` receiver returns the zero of the result type
   (messaging nil), not the fallback.
2. **The bridge is a zero-copy view, not conversion at load.** `oo::PListView(id)` (game header
   `src/Core/OOPListView.h`, Objective-C++, deleted with gnustep-base) wraps whatever the call site
   already holds and offers the same `get<T>(key[, fallback])` / `at<T>(index[, fallback])`. Each
   `get<T>` does the lookup the category method did (`-objectForKey:`; `-objectAtIndex:` guarded by
   `-count`) and calls **the same** `OO<Type>FromObject` function the category called (for
   `NSString *`/`NSSet *`, the same three lines of the category's static helper). So a sweep is
   behaviour-preserving by construction, not by testing; a throwaway GNUstep-linked harness
   compared view and categories over 24 values × 37 accessors plus a nil receiver: 1,813 checks,
   0 differences. Keys stay `id` (`@"..."`, `#define`d literals and `NSString *` constants move
   over untouched). The type map for the sweep is in `src/oofnd/README.md`, "Migrating oo_*ForKey".
3. **The Foundation sweep finishes the job**: when a file's collections become `oo::PList`,
   `oo::PListView(x).get<T>(K, D)` becomes `x.get<T>("k", D)` with `NSString *` → `std::string`,
   `NSArray *` → `PList::Array`, `NSDictionary *` → `PList::Dict`, `id` → `oo::PList`. The
   `OO<Type>FromObject` functions and `OOCollectionExtractors.mm` go with gnustep-base (oo-qps); the
   categories become dead code as soon as the 83 sweeps land (bead oo-m5u9 retires the file).

## Consequences

- The per-file sweep is a mechanical rewrite with a closed type table; an unsupported `T` does not
  compile, and `! grep -nE 'oo_[a-zA-Z]+ForKey' <file>` proves completion.
- `PList::get` itself is not exercised by the game until the Foundation sweep; its fidelity rests
  on the captured table. Known, documented edges: `get<std::string>` without a fallback returns
  `""` where Objective-C returned nil (use `get<PList>` to test presence); on LP64 (Phase 5) the
  `unsigned long` accessor aliased the signed reading, which type dispatch cannot see.
- `fmax(-0, +0)` has an unspecified sign: `-O0` builds of the extractors keep `-0`, the game's
  `-O2` build gives `+0`. oofnd spells out the `-O2` result.
- `tools/check-oofnd.sh` grows one test file (≈2 s to compile, plain and ASan).

## Alternatives considered

- **Convert NSDictionary → `oo::PList` at load (ResourceManager).** Touches every producer at
  once, deep-copies on every access path that still wants Foundation objects, and fails on the
  non-plist objects JavaScript and the game put into dictionaries. Not per-file.
- **A view that re-implements the conversions over `NSString -UTF8String`** (so the game runs the
  oofnd code today). Tiny/constant strings and `NSNumber` subclasses take other paths in GNUstep;
  exactness would rest on testing instead of construction. Rejected for the bridge; it is what the
  Foundation sweep does, with the captured table as the oracle.
- **A free function `oo::get<T>(container, key, fallback)` overloaded on `id` and `PList`**, so
  call sites never change again. Shorter, but not the `PList::get` shape the phase plan and
  architecture name, and a bare `oo::get` beside `std::get` invites confusion. The view's second
  touch is a mechanical `oo::PListView(x).` → `x.`.
- **Keys as `std::string_view` in the view.** Would create an `NSString` per lookup and change the
  key expression at 1,800 sites twice. Keys stay as written until the containers change.
