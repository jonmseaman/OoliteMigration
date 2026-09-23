# ADR-0043 — The Foundation sweep: one file at a time, C++ types inside, `id` on shared selectors, conversion at the call site

**Status:** Proposed — default in effect (Claude Code, frontier agent, beads oo-g7k5 / oo-hi38 /
oo-ro7q, 2026-09-23; ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** work item 3 of [Phase 2](../phases/2-oofnd.md) ("migrate usage sites from Foundation
to `oofnd`, still inside Objective-C classes") for the 212 `sweep:foundation` beads. Recipe:
`upstream/oolite/src/oofnd/README.md`, "Migrating Foundation usage (sweep:foundation)". Exemplars:
`src/Core/OOVector.mm` (oomath), `src/Core/OORoleSet.mm` (Core leaf),
`src/Core/Materials/OOBasicMaterial.mm` (Materials). Infrastructure: `src/oofnd/objc/OOObjCRef.h`,
`src/Core/OOFoundationBridge.h`, `oo::str::compare`/`caseInsensitiveCompare`,
`tools/check-selector-types.py`.

## Context

Each sweep bead is one file: "replace NSString/NSArray/NSDictionary/NSSet/NSNumber/NSData usage in
`<file>` with oofnd types, the class still Objective-C"; acceptance is
`! grep -nE '\bNS(String|Array|Dictionary|Set|Number|Data|Enumerator|Mutable[A-Za-z]+)\b'` over the
`.mm` and its `.h`, a full build, Tier A and the guardrails. Smaller models do them from a written
recipe, so every choice must be mechanical, and the tree must build and play identically after each
bead while most of its neighbours still hold Foundation objects. Three facts measured on this
toolchain (clang 22, libobjc2, gnustep-base 1.31.1) shape the answer:

1. **A message to nil returns zero-filled storage for a C++ class result.** On the GNUstep runtime
   clang emits a nil check and a `memset` for an sret return; the method never runs. Zero bytes are
   a valid `std::vector`, `std::optional` (disengaged), `oo::ObjCRef`, `oo::PList` (null),
   `std::string_view`. They are **not** a valid libstdc++ `std::string` (NULL `data()`; copying it
   segfaults, measured) nor a `std::map`/`std::set` (self-pointing header).
   `tests/unit/oofnd/test_objc_ref.mm` pins the valid cases.
2. **Selectors are shared across classes, and the runtime dispatches by name.** 56 selectors carrying
   NS types are declared by two or more classes (`-name` by 36 and by Foundation, `-allTextures` by
   14, `-descriptionComponents` by 38). A message compiled against one class's declaration and
   delivered to another's implementation with a different C++ type is an ABI mismatch (a pointer
   read as an sret buffer). Clang warns (`-Wobjc-multiple-method-names`) only when one translation
   unit sees both declarations and the receiver is `id`; otherwise it is silent.
3. **GNUstep orders what it can.** `-compare:` and `-caseInsensitiveCompare:` are UTF-16 unit
   orders (the latter folding to lower case: `_` sorts before `B`); `-[NSDictionary hash]` is its
   count; `%p` prints `0x` and the low 32 bits of the pointer, `(null)` for NULL. NSDictionary /
   NSSet enumeration order is hash order and cannot be reproduced by a std container.

## Decision

1. **Inside the file, everything is std/oofnd.** Ivars, locals, statics and file-static functions
   take the C++ types of the recipe's table: `std::string` (or `std::optional<std::string>` where
   nil and `@""` behave differently), `std::vector`, `std::map<std::string, V, std::less<>>`,
   `oo::PList` for property-list data, `oo::Data`, plain scalars for `NSNumber`, and
   `oo::ObjCRef<T *>` for Objective-C objects held in a container (new, `src/oofnd/objc/OOObjCRef.h`:
   `objc_retain`/`objc_release`, the count both roots use; `Ref<T>`'s API, so Phase 3 renames it).
2. **A selector no other class declares, and a C function, change their types**: parameters take
   `const std::string&` / `const std::vector<...>&` / scalars; results follow fact 1 — an
   Objective-C method returns only zero-valid types (`std::optional<std::string>` for what was an
   `NSString *`, `std::optional<std::map>` for a dictionary, `std::vector` for an array or set,
   `oo::PList`), a C function may return `std::string`/`std::map` directly. No method returns a
   reference.
3. **A shared selector keeps an Objective-C object type, spelled `id`,** in every parameter or
   result that was an NS type, and converts inside with the bridge. "Shared" is decided by
   `tools/check-selector-types.py <header>`, which attributes declarations to their `@interface` /
   `@protocol` (in the tree and in gnustep-base's headers). The root-class protocol selectors
   (`-description`, `-descriptionComponents`, `-copyWithZone:`, `-isEqual:`, `-hash`, JavaScript
   glue) are shared by construction. The whole family changes to C++ types later in one **family
   bead**, which edits every declaration and caller at once; `check-selector-types.py --check`
   fails the tree if a family's members ever disagree on a C++ type. `id` is only for this: a
   worker may not use `id`, `@[]`, `@{}`, `@()`, a typedef or a macro to keep a Foundation value
   the grep cannot see.
4. **Conversion happens at the call site, and the migrating bead does it.** Calls from the file
   into code that still speaks Foundation, and calls from direct callers into the file's changed
   API, are adapted where they are made, with `src/Core/OOStringBridge.h` (strings) and
   `src/Core/OOFoundationBridge.h` (new: nil-able strings, kind tests, string and object
   collections, `oo::PList` <-> property-list objects, `%@` text). A direct caller changes only the
   call expression (and an import); a caller that is already migrated calls with C++ types. The
   bridges are deleted with gnustep-base (oo-qps); every call to them is by then a family or
   caller bead's job. If the direct callers do not fit the sizing rule (8 files, 400 lines), the
   bead stops and reports the fan-out; the orchestrator splits it.
5. **Behaviour is preserved where it is defined and made deterministic where it was not.** Output
   text goes through the same formatter (`oo::str::format` for `-stringWithFormat:` without `%@`;
   `OOLog` calls keep `%@` with a bridged string argument). Where the old code iterated a
   dictionary or set, the new code iterates the std container (byte order of the key, or
   insertion order); the commit message names each order-sensitive loop (a first match, a weighted
   pick, a float sum), and the goldens decide. A golden that differs stops the bead; nobody
   re-blesses or re-sorts to match.

## Consequences

- Each bead edits its file, its header and the call expressions of its direct callers; the build is
  green after every accept (the acceptance builds the whole `test` flavour).
- Shared selectors accumulate as `id` until their family beads. That debt is listed, not hidden:
  `check-selector-types.py <header>` prints each family with its members, and a follow-up bead plans
  the family flips before oo-qps.
- `id` loses static typing at those boundaries for a while; nothing is lost at run time (the values
  are the same Foundation objects as before).
- Enumeration order changes are expected at order-sensitive loops. The three exemplars change
  `OORoleSet`'s weighted pick, missile-role search and probability sum to byte order; both blessed
  goldens verify unchanged.
- The recipe adds a Tier-A-sized check (`check-selector-types.py`, < 1 s) and the goldens to the
  worker's own checks; the bead acceptance lines are unchanged.

## Alternatives considered

- **Keep NS types in the header and migrate only the body.** Fails the acceptance grep, and the
  header is where the next file's bead needs C++ types.
- **Give every string-returning method `std::string`.** Crashes on the nil-receiver idiom (fact 1).
- **Change shared selectors in one class only.** Silent ABI mismatches (fact 2).
- **Rename a shared selector to a new, unique one.** An API redesign in a conversion bead, and every
  caller of the old name changes twice.
- **Convert whole dictionaries to `oo::PList` at every boundary.** Configuration dictionaries also
  carry non-plist objects (colours, textures) that a PList cannot hold; the round trip would drop
  them. `oo::PListFrom` is for data read from a plist, and a file that must edit a mixed dictionary
  waits for its callee.
- **Reproduce GNUstep's hash order.** It depends on the hash table's growth history; the project
  decided in Phase 0 §0.1 that order dependence is a defect to make deterministic, not a behaviour
  to keep.

## History

Designed with the three exemplar beads, each built with `tools/build-windows.sh test`, Tier A and
the guardrails passing, and `tools/tier-c.sh --only goldens` reporting both blessed goldens
verified. Probes (throwaway, linked against gnustep-base): nil-message returns, `-compare:` /
`-caseInsensitiveCompare:` digests (now `test_string_compare.cpp`), `-[NSDictionary hash]`,
NSScanner role parsing, `%p`, and the bridge's round trips.
