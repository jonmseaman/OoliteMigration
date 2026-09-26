# ADR-0042 — The Latest.log writer on oofnd, byte for byte

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.64, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Completes** [ADR-0035](0035-oofnd-logging.md) decision 4 (the output handler). Implemented in
`upstream/oolite/src/oofnd/LogFile.hpp` (`oo::log::FileWriter`, `logFileBytes`, `consoleBytes`,
`rotateToPrevious`), used by `src/Core/OOLogOutputHandler.mm`; tested by
`tests/unit/oofnd/test_logfile.cpp`.

## Context

`Latest.log` is read by the golden harness's evidence checks and by every OXP author. After
oo-qpb the line layout was oofnd's, but the writer was still Foundation: `OOAsyncQueue` and an
`NSConditionLock` around a writer thread, `NSFileHandle`, `NSFileManager` rotation to
`Previous.log`, `-componentsSeparatedByString:` for CRLF, `-dataUsingEncoding:`, `NSDate` for the
postamble, `NSUserDefaults` for `logging-echo-to-stderr`, and real `NSLog` for its own setup
failures. `OOLogHeader.mm` built the header with `NSString`.

### Measured (gnustep-base 1.31.1, throwaway probes)

- The CRLF conversion is a non-literal `-componentsSeparatedByString:@"\n"`: a `"\n"` that a
  sequence-extending unit (a combining mark, a low surrogate) follows is not a separator and
  stays a bare LF; an existing `"\r\n"` becomes `"\r\r\n"`.
- `-dataUsingEncoding:NSUTF8StringEncoding` answers nil for a string with a lone surrogate, and
  the queue drops nil: such a line never reached the file, although the stderr echo
  (`-UTF8String`) printed it with U+FFFD.
- `-stringByAppendingPathComponent:` drops trailing `/` and `\` except a root's.

## Decision

1. **`oo::log::FileWriter` is OOAsyncLogger**: create the file empty, write unbuffered from one
   thread in queue order, synchronise on flush, replace the write that crosses 1 GiB with the
   truncation notice and accept nothing more for the rest of the process, end with the
   `"\nClosing log at <NSDate description>."` postamble. `logFileBytes`/`consoleBytes` reproduce
   the measurements above, including dropping a line with a lone surrogate from the file.
2. **The handler keeps its API and policy**: rotation only at start (`-changeFile` does not
   rotate), `OO_LOGSDIR` taken as given, otherwise `<home>/Logs` created as before
   (`oo::ResourcePaths`), `logging-echo-to-stderr` read through `oo::Defaults`, the ADR-0033 flush
   deadline unchanged. The sink hands lines over as UTF-8 (`OOLogOutputHandlerPrintLine`); no
   `NSString` is made per line any more.
3. **The last real `NSLog` calls become `OO_LOG("unclassified", ...)`**, the class the `NSLog`
   hijack in `OOLogging.h` already gave every other `NSLog`: `ShipEntityAI.mm`,
   `NSBundle+Override.mm`, the (compiled-out) `FAIL` of `OOIsNumberLiteral.mm`, and the four
   setup-failure messages in the handler. **Visible difference, failure paths only:** those four
   printed to stderr in NSLog's format (date, process, thread id); they now print to stderr in the
   log's own line format (the handler is not yet writing a file when they fire). No golden reaches
   them.
4. **`OOLogHeader` builds the header as `std::string`** (`OO_LOG("log.header", ...)`): same text.
5. **Kept until oo-qps**: the `_NSLog_printf_handler` hook that brings gnustep-base's own `NSLog`
   output into the log as `[gnustep]` lines. It goes with gnustep-base.

## Consequences

- Both blessed golden runs' `Latest.log` are byte-identical before and after once run-varying
  text is masked (time prefix, header date and free memory, run directories, load duration).
- `OOAsyncQueue` loses its logging user (the async work manager still uses it).
- A UNC `OO_LOGSDIR` is spelled as given, where GNUstep normalised the separator after the server
  name in the paths it returned; only the returned string differs, not the file.
