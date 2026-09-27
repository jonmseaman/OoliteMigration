# ADR-0039 — `oo::str::Scanner` and `CharacterSet`: NSScanner's rules, GNUstep's tables

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.12, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** the `NSCharacterSet` / `NSScanner` family of [ADR-0029](0029-objc-floor-without-foundation.md)
Decision 5 in `upstream/oolite/src/oofnd/Scanner.hpp`, beside [ADR-0034](0034-oofnd-strings.md)'s
`oo::str`. Tested by `tests/unit/oofnd/test_scanner.cpp`. Exemplars: `src/Core/OOColor.mm`,
`src/Core/OORoleSet.mm`, `src/Core/OOStringParsing.mm`; `NSScannerOOExtensions` is deleted.

## Context

`NSScanner` reads colours, role probabilities, vectors, quaternions, seeds, cargo counts and mesh
files; `NSCharacterSet` trims and filters strings in ~20 files. Their answers are not obvious and
several are visible (a role that parses differently changes which ships spawn).

### Measured (gnustep-base 1.31.1; throwaway probes, 30,000 generated scripts, 0 differences)

1. **Tables.** `whitespaceCharacterSet` includes U+2028/U+2029 but no newline;
   `newlineCharacterSet` is U+000A–U+000D and U+0085; `decimalDigitCharacterSet` (37 BMP runs) and
   `alphanumericCharacterSet` (439 BMP runs) are GNUstep's own Unicode tables.
2. **Skipping and failure locations.** Every scan skips whitespace and newlines first. When that
   reaches the end, `scanString:`, `scanUpToString:` and `scanUpToCharactersFromSet:` fail with the
   location **past** the skipped characters, `scanCharactersFromSet:` and the number scans restore
   it; `scanString:` also leaves it past them when the target is longer than what is left, and
   restores it on a mismatch. `isAtEnd` never moves it.
3. **Matching is case-insensitive** (NSScanner's default) by GNUstep's lower-case table, which
   makes U+0130 match `i` and U+212A KELVIN SIGN match `k` — but only as the first unit of the
   target — and a match that a combining unit follows is part of a longer composed sequence (also
   past the end of `scanString:`'s range). A search that starts inside a composed sequence cannot
   match at the first unit after it.
4. **Numbers.** `scanInt:` saturates (overflow flagged once the magnitude reaches `UINT_MAX / 10`);
   `scanDouble:` is the routine `oo::PList` already ports (ADR-0031); `scanFloat:` narrows it.
5. `[NSScanner scannerWithString:nil]` scans as an empty string and logs "Scanner initialised with
   nil string" through `NSLog`, which Oolite's output handler writes to `Latest.log` as a
   `[gnustep]` line. Callers can reach it only with malformed data (a HUD `background_rgba`, a
   `random_seed` that is not a string); neither blessed golden does.

## Decision

1. **`oo::str::CharacterSet`** is a small value (a named table, or a sorted list of units, plus an
   inverted flag) answering `contains(char16_t)` exactly as `-characterIsMember:`.
   **`oo::str::Scanner`** holds the UTF-16 units of a UTF-8 string and reproduces measurements
   2–4; `trim` / `findFirstOf` / `findLastOf` / `splitByCharacters` are
   `-stringByTrimmingCharactersInSet:`, `-rangeOfCharacterFromSet:` (forwards and backwards) and
   `-componentsSeparatedByCharactersInSet:`. NSScannerOOExtensions' two methods are
   `scanCharactersFromSetNoSkip` / `scanUpToCharactersFromSetNoSkip`.
2. **Not reproduced**, each absent from the game and named in the header: a non-ASCII target
   matched case-insensitively or by canonical equivalence against different non-ASCII text; a
   target that starts with a combining unit (GNUstep raises); `setCharactersToBeSkipped:` and
   `setCaseSensitive:` (never called); a location set past the end (clamped; GNUstep raised).
3. **The nil-string diagnostic of measurement 5 is dropped.** It is gnustep-base's internal
   `NSLog`, whose capture goes with gnustep-base (oo-3rb.64); the scan result is unchanged.
4. Call sites migrate per call through `OOStringBridge.h` (recipe: `src/oofnd/README.md`,
   "Migrating NSScanner / NSCharacterSet calls"), one ≤ 8-file chunk bead at a time.

## Consequences

- ~450 lines of header, of which ~100 are generated tables; one test file (≈ 3 s to compile).
- `PListGet.hpp`'s `scanDouble` gains a from-a-location form (`scanDoubleAt`); behaviour unchanged.
- A malformed HUD colour or seed no longer writes the `[gnustep]` "Scanner initialised with nil
  string" line to `Latest.log`; everything else it wrote is unchanged.

## Alternatives considered

- **`std::from_chars` / `strtod` for the numbers.** Different rounding for long mantissas and a
  different notion of what a number is (`inf`, hex); the ported GNUstep routine is exact.
- **Reproduce the nil diagnostic** as an `OO_LOG("gnustep", ...)`. The original line carried
  NSLog's date, process name, pid and thread id; an imitation would be a new format, and the line
  has no reader.
