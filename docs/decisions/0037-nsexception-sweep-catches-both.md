# ADR-0037 — The NSException sweep: handlers catch both until oo-qps, through one alias

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.27, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** [ADR-0029](0029-objc-floor-without-foundation.md) Decision 4 for the sweep beads
oo-3rb.27/.29/.31/.32/.34 (NSException → `OOException`, chunks 1–5). Implemented in
`upstream/oolite/src/Core/OOFoundationException.h`; first applied in chunk 1 (bead oo-3rb.27).

## Context

The chunk beads say two things that cannot both hold literally. Their task text: a handler that
catches exceptions gnustep-base itself raises (collection range errors, plist parsing) must catch
both `OOException` and `NSException` until oo-qps, because `@catch (NSException *)` does not catch
an `OOException` and vice versa. Their acceptance: `! grep -nE '\bNSException\b' <files>`.
Nearly every handler in the game is of the first kind (the controls, the frame loop, the script
runners, startup, `main`'s root handler).

Two consequences of the thrown class changing were also measured (throwaway probe against
gnustep-base 1.31, `OOObject.mm` + `OOException.mm`):

1. An `OOException` caught by `@catch (id)` and sent `-callStackSymbols` (what
   `-[GameController doPerformGameTick]`'s handler sends every exception) does not answer it:
   gnustep-base's forwarding raises `NSInvalidArgumentException` ("does not respond to
   forwardInvocation: for 'callStackSymbols'") out of the handler. The frame loop's handler, which
   logged a backtrace and kept the game running, would take the game down instead.
2. `[e name]`/`[e reason]` are `const char *` (UTF-8) on `OOException`. `OOLog`'s `%s` decodes
   bytes as Latin-1 (ADR-0034 measurement 5), so `%@` → `%s` would garble a non-ASCII reason
   (a commander, ship or file name).

## Decision

1. **A handler that catches exceptions from anywhere has two clauses, the converted one first:**
   `@catch (OOException *e)` and then `@catch (OOFoundationException *e)`. The second keeps the
   handler's original text, so what gnustep-base raises is handled exactly as before.
   `OOFoundationException` is a `typedef` of gnustep-base's class in the game-side header
   `Core/OOFoundationException.h`, the one place game code names it. oo-qps deletes the header;
   every clause still using it then fails to compile, and that list is the list of clauses to
   delete. A handler that can only see the game's own exceptions gets the first clause alone.
2. **The `OOException` clause logs name and reason through `oo::NSStringFrom`** (the exact UTF-8 →
   `NSString` bridge of ADR-0034) into the handler's unchanged `%@` format, so its line is byte for
   byte the line the `NSException` clause writes. The logging sweep later turns both into `OO_LOG`.
3. **`%@` in a raise format** becomes `%s` of `[s UTF8String]` for a string and of
   `[[o description] UTF8String]` for an object (the text `%@` printed); `nil` prints `(null)`
   either way.
4. **The frame loop's `@catch (id)`** stays `@catch (id)`; for an `OOException` it logs
   `name : reason` under the same class (`exception.backtrace`) instead of sending
   `-callStackSymbols`. Least-visible default: one log line where there was one, and the game keeps
   running as it did.
5. **Oolite's own exception names** (`@"OoliteException"`, `OOLITE_EXCEPTION_*`) keep their text as
   `const char *`; only Foundation's names map to the `OO*Exception` constants.
6. **The chunks are stacked** (each depends on the one before) because a raise and the handlers
   that expect it are in different chunks. Until the last chunk lands, a game-raised
   `OOException` can pass a not-yet-converted `@catch (NSException *)` in a later chunk's file;
   that is an error path only (the goldens do not reach it), and it closes when the chunks land.

## Consequences

- Handlers are duplicated for the length of Phase 2; the duplicate is the old text and disappears
  mechanically at oo-qps.
- A reviewer can check each clause pair by eye: the formats are identical, only the arguments of
  the first clause are bridged.

## Alternatives considered

- **Narrow to `@catch (OOException *)` only.** Changes what the game survives: a gnustep-base range
  error in the controls or a script would escape to `main`'s root handler and end the game.
- **Widen to `@catch (id)` with a class test.** Messaging `name` on `id` is ambiguous between
  `NSString *` and `const char *` returns, so every body needs casts, and a typed handler would
  start catching objects it did not catch before.
- **`%s` instead of the bridge.** Garbles non-ASCII reasons (measurement 2 above).
- **`OO_LOG` now.** Needs a nil test for every other `%@` argument (`oo::StdString(nil)` is `""`,
  `%@` printed `(null)`); that is the logging sweep's recipe, not this one's.

## History

- 2026-09-23 Proposed with bead oo-3rb.27.
