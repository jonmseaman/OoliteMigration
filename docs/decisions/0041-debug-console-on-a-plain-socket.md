# ADR-0041 — The debug console client is one non-blocking socket that emulates the Foundation streams it replaces; the frame loop waits on it

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.14, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** [ADR-0029](0029-objc-floor-without-foundation.md) Decision 5 (`NSStream`/`NSHost` →
sockets) and [ADR-0033](0033-frame-loop-deadlines-and-the-run-loop-pump.md) (the console was one of
the pump's clients). Implemented in `Core/Debug/OODebugTCPConsoleClient.{h,mm}` and
`Core/GameController.mm` (`-runFrameLoop`). The wire protocol (`OOTCPStreamDecoder`, plain C) is
untouched (ADR-0012).

## Context

The debug console client (the golden harness's and the component tier's transport) looked the host
up with `NSHost`, talked through an `NSInputStream`/`NSOutputStream` pair scheduled on the run loop,
and received data from stream events the run loop delivered while it waited. Its failure paths write
lines to `Latest.log` whose text includes the streams' status numbers and error descriptions.

### Measured (gnustep-base 1.31 on Windows; throwaway probes, plus `Latest.log` of both blessed golden runs before and after)

- `NSHost` resolves IPv4 only; an unknown name logs `Host '<name>' not found - perhaps the hostname
  is wrong or networking is not set up on your machine` through `NSLog` and gives nil.
- After `-open` both streams are "opening" (1), then "open" (2). A refused connection takes ~2 s on
  Windows and raises the error event on the **input** stream first (in 7, out 1); its description
  is the system's text for the Winsock code, trailing CRLF included.
- **The "wait up to 3 seconds" loop never timed out**: a run-loop pass whose limit date has passed
  still returns YES, so the loop spun until the connect completed or failed (21 s against an
  address that never answers).
- Reads: data, then -1 with the input stream "reading" (3); the peer's close gives an end event on
  the input stream (status 5) and reads return 0. A reset seen by a read is an end of stream for
  both streams, not an error.
- Writes: the first write after the peer's close succeeds; a write the system then aborts
  (`WSAECONNABORTED`) returns 0 and leaves both streams at end (5), and later writes return 0; a
  reset seen by a write (`WSAECONNRESET`) returns -1 with the output stream in error (7) and raises
  no event. Both golden runs end this way: `quit` is echoed after the harness closed, so each
  `Latest.log` has "Error sending packet body, retrying." / "could not be sent" / "'bad stream.'
  (outStream status: 5, inStream status: 5)".
- A run-loop wait rounds its timeout up to whole milliseconds; `std::this_thread::sleep_*` on this
  toolchain sleeps in 15.6 ms steps even at 1 ms timer resolution (select and `Sleep` do not).

## Decision

1. **One non-blocking IPv4 TCP socket** (Winsock on Windows, BSD sockets elsewhere; `ws2_32` is
   already linked; the client calls `WSAStartup` itself, which gnustep-base used to do). The client
   keeps the two streams' status numbers and error codes and reproduces every measured behaviour
   above, so its protocol handling and all its log lines are unchanged, including the failure
   messages' text and numbers.
2. **The connect wait waits on the socket until the connection opens or fails**, which is what the
   run-loop loop did; the dead three-second limit is documented, not revived.
3. **Events arrive only through waits**, as stream events came only from the run loop:
   `OODebugTCPConsoleServiceInput(timeout)` waits (select, whole milliseconds rounded up) for the
   socket to become readable or fail and handles what arrived; the send retries' 8 ms and 16 ms
   run-loop runs become waits of the same length on the socket (a plain `Sleep` when there is
   nothing to wait on), still handling incoming packets re-entrantly as before.
4. **The frame loop waits on the console socket.** While a console socket can still deliver
   something, each pass runs the run loop once without waiting (its own timers and ready input, i.e.
   OXZ downloads) and then waits on the socket until the next deadline, handling input as it
   arrives, before the next tick, as the run loop did when the streams were its sources. Otherwise
   the pass is unchanged (the run loop waits to the next deadline).

## Consequences

- Both blessed goldens MATCH, with the same durations; the console lines in both runs' `Latest.log`
  are the same lines as before (connect, and the end-of-run send failure with statuses 5/5).
- **Known, deliberate differences** (none reachable by the goldens):
  - While the console is connected, OXZ download events are handled once per frame-loop pass (at
    the tick rate) instead of waking the wait.
  - The send retries' nested runs no longer run the rest of the run loop (OXZ downloads, run-loop
    timers); ADR-0033 had already taken the tick and ADR-0040 the deferred calls out of them.
  - `NSHost -name` returned the name it was asked for in every probe; the client keeps that name
    rather than a canonical one for the "Connected ... at <host>" message.
- `NSStream`/`NSHost` leave the game; the pump now serves only OXZ downloads until oo-3rb.13, and
  oo-3rb.58 then deletes it.

## Alternatives considered

- **Poll the socket once per pass without waiting on it.** Simpler, but a console command arriving
  between ticks would be handled after the next tick instead of before it, which reorders console
  commands against ticks.
- **A blocking socket on a reader thread.** Changes which thread dispatches console commands into
  the game; the run loop dispatched them on the main thread.

## History

- 2026-09-23 — proposed by bead oo-3rb.14 (default in effect).
