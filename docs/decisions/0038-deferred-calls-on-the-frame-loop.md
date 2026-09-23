# ADR-0038 — Deferred calls (`performSelector:withObject:afterDelay:`) become a frame-loop queue with the run loop's firing order

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.57, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** [ADR-0033](0033-frame-loop-deadlines-and-the-run-loop-pump.md) Decision 5 (the
`performSelector:afterDelay:` follow-up). Implemented in `Core/GameController.{h,mm}`
(`OOScheduleDeferredCall`), call sites in `Core/AI.mm`, `Core/Entities/ShipEntityAI.mm`,
`Core/Scripting/OOJSShip.mm`, `Core/Universe.mm`, `Core/Entities/PlayerEntitySound.mm`.

## Context

Five call sites used gnustep-base's `-performSelector:withObject:afterDelay:`, which adds a
one-shot timer (a "timed performer") to the calling thread's run loop. After ADR-0033 the frame
loop pumps the run loop once per pass partly for them. The bead asked for a game-side deadline
queue with "the same delay semantics".

### Measured (gnustep-base 1.31, libobjc2, MSYS2 UCRT64; throwaway probes)

- The fire date is now + delay; a delay <= 0 becomes 0.0001 s (the timer initialiser's clamp).
- **Firing order is the run loop's timer array, not the fire date.** Six performers scheduled
  with delays 0.05, 0.01, 0.03, 0.01, 0, 0.02 and all overdue fired in exactly that
  (scheduling) order. A performer scheduled while another fires goes to the back.
- **Each `-limitDateForMode:` fires one due timer** (the first due one in array order), and
  **each `-runMode:beforeDate:` fires two** (its own `-limitDateForMode:` and the one inside
  `-acceptInputForMode:beforeDate:`), both before it waits; none fire after the wait. A backlog
  of six took three passes, two per pass.
- The performer retains target and argument and releases them after the call. An `NSException`
  raised by the call is caught by `NSTimer` and logged through `NSLog` as
  `*** NSTimer ignoring exception '<name>' (reason '<reason>') raised during posting of timer with
  target <address> and selector 'fire'`; the performer is then never removed, so target and
  argument stay retained for ever. Anything else thrown (`@throw` of a non-`NSException`)
  propagates out of the run loop.
- A performer scheduled on a thread whose run loop never runs never fires.

## Decision

1. **`OOScheduleDeferredCall(target, selector, argument, delay)`** (C function in
   `GameController.h`) replaces the five sends. Calls are held in scheduling order with a
   `std::chrono::steady_clock` deadline (the tick's clock, ADR-0033), target and argument
   retained.
2. **Firing reproduces the run loop's order:** a firing step runs the first due call in
   scheduling order. `-runFrameLoop` takes two steps per pass, after the tick and log flush
   (where the pump's two timer steps were), then pumps the run loop with its wait limited to the
   earlier of the next tick and the earliest pending call (the run loop computed that limit
   itself while the calls were its timers); if the run loop has nothing to wait on, the loop
   sleeps to that same instant. `-fireDueTimers` (the OXZ download's re-entrant pump) takes one
   step, where `-limitDateForMode:` took one.
3. **Exceptions as `NSTimer` had them:** an `NSException` is logged with `NSTimer`'s text through
   the real `NSLog` (so it still reaches `Latest.log` as a `gnustep` line) and its call's target
   and argument are not released; anything else propagates.
4. **Main thread only:** a call scheduled from another thread is dropped, as it never fired.
5. `OOObject`'s borrowed `-performSelector:withObject:afterDelay:` (`OOObjectGNUstepBridge`) goes:
   nothing sends it any more.

## Consequences

- Same delays, same order, same per-pass cadence and the same interleaving with the tick; both
  blessed goldens MATCH.
- **Known, deliberate differences** (none reachable by the goldens):
  - Deferred calls used a wall clock (`NSDate`); they now use the steady clock, so setting the
    system clock no longer makes them fire early or late.
  - The debug console's own nested run-loop runs (3 s connect wait, 8/16 ms send retries) no
    longer fire deferred calls; they already no longer ran the tick (ADR-0033). oo-3rb.14
    removes those runs.
  - In `-fireDueTimers`, a due deferred call and a due run-loop timer of the OXZ download now
    both fire in one call, where only the first in the run loop's array did.
- The pump now waits only for input (console streams, OXZ downloads); oo-3rb.58 removes it
  after oo-3rb.13 and oo-3rb.14.

## Alternatives considered

- **A deadline-ordered queue firing everything due each pass** (the bead's wording). Simpler, but
  it reorders overdue calls (for example a 0-delay AI state change behind an earlier-scheduled
  cargo dump) and fires a backlog within one pass; the measured order is cheap to keep.
- **Keep the calls on the run loop until oo-3rb.58.** Leaves a gnustep-base `NSObject` method in
  the game and keeps the pump for a reason the queue removes.

## History

- 2026-09-23 — proposed by bead oo-3rb.57 (default in effect).
