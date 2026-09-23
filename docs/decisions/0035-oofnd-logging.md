# ADR-0035 — `oo::log`: OOLogging's engine in oofnd, one logger behind both call styles

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-qpb, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** the `Logging` component of seam 2.8 of [Phase 2](../phases/2-oofnd.md) ("retires
`OOLogging`") in `upstream/oolite/src/oofnd/Log.hpp`; Objective-C shell `src/Core/OOLogging.mm`;
exemplar `src/SDL/OOSDLJoystickManager.mm`. Builds on [ADR-0034](0034-oofnd-strings.md) (the
`NSString` bridge).

## Context

`OOLogging` decides, per message class, whether a line is written (`logcontrol.plist`, with
inheritance along the dotted class, `$metaclasses`, `_default` and `_override`), and lays the line
out (`[class]`, function, `file:line`, time, indentation) before `OOLogOutputHandler` writes it to
`Latest.log`. Its state was Foundation (`NSDictionary`, `NSLock`, `NSDate`, `NSString` formatting),
and its ~1,080 call sites use `NSString` formats with `%@`. `Latest.log` is read by the golden
harness's evidence checks and by every OXP author, so its lines must not change.

### Measured

A throwaway probe linked the **original** `OOLogging.mm` against gnustep-base 1.31.1, with
`ResourceManager`, the output handler and the log header stubbed, and recorded every line it
emitted and every class decision over a deliberately awkward `logcontrol` (every spelling of
yes/no/inherit, numbers, bad values, metaclass chains, an undefined metaclass, `_default` and
`_override` as metaclasses, repeated reloads), all 8 show-flag combinations, indentation to 35
levels with push/pop and underflow, prefixes, markers and a pinned clock:

- the class decision, the diagnostics OOLogging prints about its own settings (text, function
  names, order — the dictionary's enumeration order), and `_default`/`_override` keeping their
  previous values across a reload unless set again;
- layout: `[class]: ` alone, `[class] ` before a function or `file:line`, function `(null)` when
  NULL, indentation of two spaces a level capped at 64 and placed **before** the time;
- `%F` in the time stamp is milliseconds **truncated**, local time.

## Decision

1. **The engine is `oo::log` in oofnd** (header-only): settings table and resolution with its
   cache, the diagnostics, per-thread indentation, `composeLine`, `timeStamp`, and one process-wide
   `Logger`. Its unit test replays the probe's call sequence and must reproduce the probe's
   transcript byte for byte (only the pinned time text is fed in rather than read from the clock).
2. **`OOLogging.mm` becomes the Objective-C shell over it**, keeping every public function: it
   reads the `logging-show-*` defaults and `logcontrol.plist` (handing the dictionary to
   `oo::log` in enumeration order), formats `%@` messages with `NSString` for the call sites not
   yet converted, and installs the sink that feeds `OOLogOutputHandler`. The same probe relinked
   against the new `OOLogging.mm` printed the same transcript; `Latest.log` from both blessed
   golden scenarios is byte-identical before and after once the run-varying text (times, dates,
   free memory, run directories, load duration) is masked.
3. **New and converted call sites use `OO_LOG("class", "{}...", args)`** (std::format), with
   `OO_LOG_ERR` / `OO_LOG_WARN`. The macros pass `__FUNCTION__`/`__FILE__`/`__LINE__` as `OOLog`
   does and evaluate their arguments only when the class shows. Recipe: `src/oofnd/README.md`,
   "Migrating OOLog calls". std::format rather than `%`-formats because it is type-checked at
   compile time and cannot misread an argument; the recipe spells out the few conversions whose
   output differs (`%u`/`%x` of a signed value, `%c`, `%@` of nil, `%s` of NULL).
4. **The output handler is not part of this seam.** `OOLogOutputHandler` (the writer thread,
   `Latest.log`/`Previous.log`, CRLF, the 1 GiB cap, the flush deadline of ADR-0033) keeps its
   Foundation types until the Foundation sweep reaches it; `oo::log` hands it finished lines
   through a sink. Before `OOLoggingInit()` installs that sink, lines go to stderr, which is what
   the handler did before its own init.
5. **One deliberate difference:** a `$metaclass` cycle recursed until the stack overflowed; it now
   falls back to `_default`.

## Consequences

- `OOLogWillDisplayMessagesInClass` (on every `OOLog`) reads the class into a stack buffer and
  looks it up without allocating; the settings are behind one `std::mutex` as they were behind an
  `NSLock`.
- `OOLogAbbreviatedFileName` returns the same text but no longer caches its `NSString`s; its
  callers outside the file:line prefix are diagnostics (OpenGL error checks, JavaScript
  engine bug reports), not per-frame paths.
- `%@`-formatted call sites keep working unchanged; they migrate file by file (`OO_LOG`), and the
  `%@` of non-string objects waits for their classes' own conversions.
- `tools/check-oofnd.sh` grows one test file (≈ 2 s to compile).

## Alternatives considered

- **Keep `%`-formats (`oo::str::format`) for the new front end.** One less thing to learn, but
  unchecked varargs; the bead named std::format and the call-site conversion is mechanical.
- **Port the output handler now.** It is Foundation-heavy, recently reworked for the frame loop
  (ADR-0033), and not needed for the line format to be exact; it belongs to the Foundation sweep.
- **A second, independent C++ logger.** Two sets of settings and indentation would drift between
  converted and unconverted call sites mid-migration.
