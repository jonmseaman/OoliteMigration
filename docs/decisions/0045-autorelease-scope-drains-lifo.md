# ADR-0045 — `oo::AutoreleaseScope` drains last-in-first-out, as the game's pool does

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.22,
2026-09-23; ADR-0013, CLAUDE.md rule 10). Jon may override. The test-assertion change it entails
was made under Jon's 2026-09-23 authorisation to resolve `human` beads by best judgement.
**Date:** 2026-09-23
**Supersedes** [ADR-0026](0026-oofnd-ref-semantics.md) point 4's drain order (only that clause;
the rest of point 4 stands).

## Context

ADR-0026 point 4 made `oo::AutoreleaseScope` "GNUstep's pool" and, believing GNUstep drains in
insertion order, specified FIFO. [ADR-0029](0029-objc-floor-without-foundation.md) measurement 3
then measured the pool the game actually runs on: on this toolchain gnustep-base's
`NSAutoreleasePool` is libobjc2's, and it releases last-in-first-out (3, 2, 1). So the scope
drained in the opposite order to the thing it replaces. Harmless while nothing C++ is
autoreleased; wrong the moment a Phase 3 class's teardown order depends on it, and the goldens
would then be the first to notice, far from the cause.

## Decision

1. **`AutoreleaseScope::drain()` (and the scope's end) release newest first.** An object
   autoreleased *during* the drain (by a destructor) is pushed on top and so is released next,
   before the older objects still pending — exactly libobjc2's `emptyPool`, which pops
   `insert--` until it reaches the stop marker. The rest of ADR-0026 point 4 is unchanged:
   per-thread, nested, innermost receives, `drain()` keeps the scope open, no-scope autorelease
   leaks and is counted, non-LIFO scope destruction aborts, stack-only.
2. **The order is pinned against the runtime, not only against a list.**
   `test_objc_floor.mm`'s `autoreleaseScopeDrainsInTheRuntimePoolsOrder` runs the same sequence
   (three objects, the middle one autoreleasing a fourth from its destructor) through
   `objc_autoreleasePoolPush`/`Pop` and through a scope, and requires identical death orders,
   plus the spelled-out LIFO order. It fails against the old FIFO drain (measured).
3. **`test_ref.cpp`'s three order assertions now state LIFO** (`autoreleaseScopesNest`,
   `drainReleasesInOrderAndKeepsTheScopeOpen`, `drainingCascades`); test names are unchanged.

## Consequences

- A translated `NSAutoreleasePool` / `@autoreleasepool` site keeps the order it has in the game
  today, so no golden can move because of the pool.
- If the runtime ever changes its drain order, the floor test goes red and this ADR is the one to
  revisit; the scope must follow the game, not the other way round.
- ADR-0029's "ADR-0026 and `oo::AutoreleaseScope` ... do not match the game" is resolved by this
  record.

## History

- 2026-09-23: proposed with the change (bead oo-3rb.22).
