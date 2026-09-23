# ADR-0033 — The frame loop runs on steady-clock deadlines; the run loop is pumped until its last clients go

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.8, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** [ADR-0029](0029-objc-floor-without-foundation.md) Decision 5 ("the frame loop's timer +
run loop → an explicit steady-clock loop at the same tick interval") for bead oo-3rb.8, and
**narrows oo-3rb.8's acceptance** (below). Implemented in `Core/GameController.{h,mm}`,
`Core/OOLogOutputHandler.{h,mm}`, `Core/OOEncodingConverter.mm`, `Core/OOOXZManager.mm`.

## Context

The game tick was a repeating Foundation timer (interval `animation_timer_interval`, default
`MINIMUM_ANIMATION_TICK` = 1/240 s) on the main run loop, which `-applicationDidFinishLaunching:`
then ran for ever. oo-3rb.8 asked for an explicit loop at the same interval, with one-shot timers
as deadlines, and "anything the run loop pumped ... pumped explicitly from the tick until its own
family bead replaces it", accepted by a grep with no run-loop symbol left anywhere in `src/`.

That grep cannot pass faithfully in this bead, because three things still need a *running*
Foundation run loop and none of them is this bead's to replace:

1. **The debug console's streams** (`Core/Debug/OODebugTCPConsoleClient.mm`, `NSStream` scheduled
   on the run loop; delegate callbacks come from it). This is the **golden transport**: the golden
   harness drives the game over that socket. Replacing it is oo-3rb.14 (plain sockets).
2. **OXZ downloads** (`NSURLConnection` delivers on the run loop; `OOOXZManager` even pumps it
   re-entrantly from `-connection:didReceiveData:` so the game keeps ticking during large downloads
   on MinGW, upstream issue #95). Replacing it is oo-3rb.13 (HTTP client).
3. **`performSelector:withObject:afterDelay:`** — a gnustep-base `NSObject` method that schedules a
   run-loop timer — at five call sites outside this bead (AI deferred state changes, cargo dumping,
   delayed messages, a sound swap). No bead covered it.

oo-3rb.13 and oo-3rb.14 were filed as *blocked by* oo-3rb.8; the dependency runs the other way for
the last step (removing the run loop).

### Measurements (gnustep-base 1.31, libobjc2, MSYS2 UCRT64, this machine)

A repeating timer at 5 ms whose callback overruns, printing the fire date during and after firing:

- first fire date = creation time + interval;
- the fire date is advanced **after** the callback returns, from a `now` sampled **before** the
  callback: `next = old + interval; while (next <= now) next += interval` — a late tick skips
  missed intervals, it never bursts (e.g. fired at 0.043 with date 0.030 → next 0.045; fired at
  0.060 with date 0.045 → next 0.065);
- an interval ≤ 0 is 0.0001 s (GNUstep's NSTimer initialiser clamp; read, not measured).

Order inside one run-loop pass: due timers fire in the run loop's array order; a performer added
*during* the tick fires in the same pass after the tick; a performer added before the frame timer
existed fires before it. `-runMode:beforeDate:` with nothing else scheduled still waits to its
limit date and returns YES.

## Decision

1. **The tick is a deadline on `std::chrono::steady_clock`,** created and advanced by exactly the
   measured rule: start sets `now + interval`; a pass fires the tick when `now >= deadline`,
   computing the next deadline *before* calling the tick from the `now` it sampled (so a
   `stopAnimationTimer`/`startAnimationTimer` inside the tick — the save/load critical section —
   replaces the deadline, as a new timer did). The per-tick autorelease pool is unchanged.
2. **One frame loop, `-[GameController runFrameLoop]`, replaces running the run loop for ever.**
   Each pass (in its own autorelease pool, as a run-loop pass had): fire the due deadlines (the
   tick, then the log flush), then **pump the run loop once** with `-runMode:beforeDate:` limited to
   the next tick deadline — which fires its own due timers (performers) and waits for input
   (console streams, downloads) until the earliest of its timers and the tick, exactly the wait the
   run loop computed when the tick was one of its timers.
3. **Re-entrant pumps that existed to let the game tick keep doing so:** `OOOXZManager`'s
   `limitDateForMode:` becomes `-[GameController fireDueTimers]` (due deadlines, then the run
   loop's own due timers) — the #95 fix is kept.
4. **One-shot and secondary timers are deadlines:** the log flush (`OOLogOutputHandler`, 2 s after
   the first unflushed message) is an atomic deadline checked by the frame loop; its old quirk is
   kept — the timer was scheduled on the *calling* thread's run loop and only the main thread's
   runs, so a flush first requested off the main thread never fired and blocked later ones. The
   encoding converter's 5 s profile report (compiled out, `PROFILE_ENCODING_CONVERTER 0`) is a
   deadline checked on each conversion.
5. **Run-loop use is confined** to the frame loop's pump in `GameController.mm` and to
   `OODebugTCPConsoleClient.mm` (untouched until oo-3rb.14). Follow-ups, both blocking oo-qps:
   **oo-3rb.57** replaces `performSelector:afterDelay:` with a frame-loop deadline queue;
   **oo-3rb.58** (after oo-3rb.57, .13, .14) deletes the pump and carries oo-3rb.8's original grep.

### oo-3rb.8's acceptance (narrowed)

```
! grep -rnE --include='*.mm' --include='*.m' --include='*.h' --exclude-dir=oofnd '\bNSTimer\b|NSEventTrackingRunLoopMode' upstream/oolite/src
test "$(grep -rlE --include='*.mm' --include='*.m' --include='*.h' --exclude-dir=oofnd '\bNSRunLoop\b|NSDefaultRunLoopMode' upstream/oolite/src | sort | tr '\n' ' ')" = "upstream/oolite/src/Core/Debug/OODebugTCPConsoleClient.mm upstream/oolite/src/Core/GameController.mm "
tools/build-windows.sh test
bash tools/guardrails.sh
```

## Consequences

- Tick cadence is the timer's: same interval, same first fire, same skip-not-burst advance, same
  wait. Both blessed goldens MATCH (they run paused over the debug console, so they also prove the
  console streams are still serviced by the pump).
- **Known, deliberate differences** (none reachable by the goldens):
  - Within one pass the tick now always fires before the run loop's own timers. Before, a
    `performSelector:afterDelay:` performer scheduled *before* the frame timer was (re)started —
    only possible across start-up or the save/load restart — fired before the tick in that pass.
    These performers are wall-clock timers whose pass is already frame-timing dependent.
  - The debug console's own nested run-loop calls (the 3 s connect wait, the 8/16 ms send retries)
    no longer run the game tick re-entrantly inside a console send, nor the log flush; the pump
    services them as before. oo-3rb.14 removes those calls.
  - The macOS Cocoa branch (not built by this fork, ADR-0017) lost its timer; whoever revives it
    drives `-fireDueTimers` from its own run loop or display link.
- The same interval default keeps the loop polling at 240 Hz when frames are fast; frame pacing is
  still the swap interval's, as before.

## History

- 2026-09-23 — proposed by bead oo-3rb.8 (default in effect).
