# ADR-0061: Phase 3 exit-gate scope

- Status: Proposed (default in effect until Jon ratifies or supersedes it; hard rule 10)
- Date: 2026-10-18
- Beads: oo-sqzbw (this decision lands with it), oo-o8x (the Phase 3 exit gate whose acceptance
  uses it), oo-4aq6a (moved to Phase 4 by item 2), oo-cpztk / [ADR-0060](0060-vendored-code-and-the-wextra-gate.md)

## Context

The Phase 3 exit gate ([3-cpp-conversion.md](../phases/3-cpp-conversion.md), bead oo-o8x) says
"zero `@implementation` in `src/` (`grep -rc '@implementation' src` is 0)". Read literally, that
grep counts four things that are not Phase 3 work:

1. **Mac-only code the fleet never compiles.** `src/Core/GameController+FullScreen.mm` and the
   `#if OOLITE_MAC_OS_X` block in `src/Core/GameController.mm` holding
   `@implementation GameController (MacOSX)`. Neither is built on Windows; Phase 5 rewrites the
   Mac layer ([ADR-0009](0009-apple-silicon-after-runtime-removal.md), [Phase 5](../phases/5-apple-silicon.md)). Moving the block verbatim into the
   already-excepted `GameController+FullScreen.mm` (the first default on oo-sqzbw) is refused by
   `tools/guardrails.sh`'s per-file deny-list ratchet (its `NSURL` lines are new hits in the
   target file), and deleting it ahead of Phase 5 throws away the only Mac reference.
2. **The Objective-C runtime support layer.** `src/oofnd/objc/` (`OOObject`, `OOException`,
   `OOConstantString`/`OOTinyString`, `OOObjCPeer.h`) is the floor every remaining Objective-C
   object stands on (`@"..."` literals, `@throw`, autorelease pools). It can only go when no
   Objective-C object is made, which is exactly Phase 4's job: oo-dbz drops libobjc2 and the
   floor with it ([4-remove-objc-runtime.md](../phases/4-remove-objc-runtime.md)).
3. **Vendored third-party code** in the `-Wall -Wextra` box, already settled by ADR-0060.
4. **Comments that mention the word.** `OOObjCPeer.h` ("zero @implementation"),
   `OOJSCallEntityMethods.h` (generated-file banner), `OOWeakReference+ObjCBridge.mm` (an
   indented comment) are not class definitions.

## Decision (default in effect)

1. **Mac-only exception, exactly two places:** the whole of
   `src/Core/GameController+FullScreen.mm`, and in `src/Core/GameController.mm` exactly the line
   `@implementation GameController (MacOSX)` (matched by content, not line number). Any other
   `@implementation` in `GameController.mm` counts. Both stay as they are until Phase 5 converts
   them. The nightly line `[oo-sqzbw]` proves every `@implementation` in the two files is still
   inside an `#if OOLITE_MAC_OS_X` arm, so the exception cannot quietly cover built code.
2. **`src/oofnd/objc/` is out of the Phase 3 count.** It is Phase 4 scope; its removal is
   oo-4aq6a, now a child of the Phase 4 epic oo-6e1 and a blocker of oo-dbz. Categories *on* the
   root that live outside that directory (`NSObjectOOExtensions.mm`, `OODescription.mm`,
   `OOObject+OOJavaScript.mm`, `OOWeakReference+ObjCBridge.*`, `OOCallByName.mm`) are first-party
   `@implementation`s and still count: their beads stay on the Phase 3 gate.
3. **Vendored paths** for the warning box are those of ADR-0060, enumerated there and nowhere else.
4. **Only definitions count:** the grep is anchored at line start, `^@implementation`. A comment
   line that begins with the word at column 0 (the `ThingWatcher`/`Thing` usage example in
   `OOWeakReference+ObjCBridge.h`) still counts; it goes with its file (oo-9ht.22).

The gate's `@implementation` check is therefore, run from the repository root:

```bash
left=$(grep -r '^@implementation' upstream/oolite/src | tr -d '\r' \
  | grep -v '^upstream/oolite/src/oofnd/objc/' \
  | grep -v '^upstream/oolite/src/Core/GameController+FullScreen\.mm:' \
  | grep -vxF 'upstream/oolite/src/Core/GameController.mm:@implementation GameController (MacOSX)' || true)
[ -z "$left" ] || { printf '@implementation left in:\n%s\n' "$left"; exit 1; }
```

Nothing else is excluded. Widening the list needs a new ADR.

## Alternatives

- **Keep the literal grep** and make the root classes the last Phase 3 bead (oo-4aq6a's first
  default). Rejected: it pulls the runtime removal (no `@"..."`, no `@throw`, no pools) into
  Phase 3 and leaves Phase 4 with nothing to remove.
- **Delete the Mac block** (precedent oo-9hoy9/oo-9wpwn deleted compiled-out code). Rejected as
  the default: those were dead on every platform; this is live Mac code Phase 5 needs.
- **Move the Mac block into the excepted file.** Refused by the deny-list ratchet (above).

## Consequences

- oo-o8x's acceptance uses the check above in place of its `grep -rl` line; its other lines
  (no `.m`, `-Wextra` per ADR-0060, test build + core tests, `tier-c --only asan,goldens`, the
  `[oo-o8x]` nightly line, guardrails) are unchanged.
- oo-4aq6a no longer blocks oo-o8x. oo-6e1.1 (NSObjectOOExtensions) and oo-9ht.22
  (OOWeakReference) block oo-o8x directly, since they were linked to it only through oo-4aq6a.
- The phase doc's exit-gate box points here.
- Phase 4's exit (zero Objective-C) is unaffected: everything excluded here is removed there or
  in Phase 5.
