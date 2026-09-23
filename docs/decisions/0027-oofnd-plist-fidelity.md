# ADR-0027 — `oo::PList`: representation, and where it may differ from GNUstep

**Status:** Proposed — default in effect (Claude Code, frontier agent, beads oo-075 / oo-6ft /
oo-6rj / oo-gxv / oo-pig, 2026-09-23; ADR-0013). Jon may override.
**Date:** 2026-09-23
**Refines** the `PList` row of [Phase 2](../phases/2-oofnd.md) and architecture §3.4. Implemented in
`upstream/oolite/src/oofnd/PList*.hpp`.

## Context

Oolite reads every plist through `OOPropertyListFromData` (`src/Core/OOPListParsing.m`), which is
`ChangeDTDIfApplicable` + GNUstep's `+[NSPropertyListSerialization propertyListFromData:...]`
(`NSPropertyList.m`, the old-style scanner `parsePlItem` and the `GSXMLPListParser` delegate over
`GSSloppyXMLParser`), and writes them through `OldSchoolPropertyListWriting.m` and GNUstep's XML
writer (`OAppend`). The Phase 2 exit gate (contract C1) is *zero divergences from GNUstep on the
corpus*, so the default is to reproduce GNUstep quirk-for-quirk, including the odd ones (an
unquoted token may be empty; `"\u12"` at the end of a quoted string is dropped; an XML plist with
anything before `<?xml` fails; text between container tags is glued onto the next key). The unit
tests pin each quirk against output captured from the GNUstep 1.31.1 build the game links today.

That leaves the cases where reproducing GNUstep is impossible or undefined, and the
representation choices ADR-0013 did not make.

## Decision

1. **Representation.** `oo::PList` is a value type over null / bool / integer / real / string /
   data / date / array / dict. Strings are UTF-8 `std::string` (ADR-0013 decision 4); a lone
   UTF-16 surrogate that an escape can produce is kept as WTF-8, so nothing parsed is lost.
   Integers keep NSNumber's signedness (GNUstep stores a non-negative `<integer>` as `unsigned long
   long`; the writers print `%llu`/`%lld`). Data is `oo::Data` (ADR-0028). Dates are seconds
   since 2001-01-01Z. Like every oofnd header a game file includes, the PList headers suspend
   OOCocoa.h's `true`/`false` macros and restore them (ADR-0028). Dicts iterate in
   byte order of the key (NSDictionary's hash order was unspecified; the writers sort as GNUstep
   does, so no output depends on it). `==` is structural and type-strict.
2. **Dictionary keys are strings.** GNUstep's old-style scanner accepts any item as a key
   (`{ (a) = b; }`, `{ <00> = b; }`). oofnd rejects a non-string key with the error
   `non-string key in dictionary`. No game or catalogue plist can use one: every consumer looks
   keys up by string.
3. **Binary plists are not parsed.** Data starting `bplist00`, or with a first byte 0 or 1
   (GNUstep's serializer format), fails with `binary property lists are not supported by oofnd`.
   Game data is text. `OOCacheManager` writes its cache in GNUstep binary format; when it moves to
   oofnd it writes XML instead (the cache is regenerated when unreadable, so no migration).
4. **Undefined behaviour in GNUstep becomes an error or the evident intent.** Where GNUstep reads
   past the end of the buffer (a hex-data `<...` whose `//` comment runs to end of input) oofnd
   reports `unexpected character (wanted '>')`. Where `OldSchoolPropertyListWriting` sizes its
   NSData buffer too small (5-7, 9-15, ... bytes: the closing `>` is written past the end and the
   string is cut, or uninitialised bytes are included) or loops forever (more than 32 bytes at
   indentation 0), oofnd writes the evidently intended `<0A0B0C0D 0E>` form. For every length
   where GNUstep is well-defined the output is byte-identical.
5. **Old-style writer: non-ASCII and case-equal keys.** GNUstep leaves a string unquoted when every character is in
   `+alphanumericCharacterSet` (Unicode letters, marks, digits), so `café` is written bare; neither
   GNUstep's scanner nor oofnd's can read that back (bytes >= 0x80 end an unquoted token). oofnd
   quotes any string containing a non-ASCII character. ASCII strings are identical.
   Keys that are equal ignoring case (`aB`, `AB`) are ordered by their UTF-16 units; GNUstep's
   order for them follows the dictionary's hash order and is not reproducible. Every other
   quirk of the old-style writer is kept, including that it leaves out the text between two
   escaped characters (`"a\"b\\c"` is written `"a\"\\c"`).
6. **XML input encodings.** UTF-8, with GNUstep's fallback to ISO-8859-1 when the bytes are not
   valid UTF-8 or the declaration names ISO-8859-1/Latin-1. UTF-16/UTF-32 XML plists (which
   GNUstep would transcode) fail. The game ships none.
7. **Dates** are read in the two `NSCalendarDate` formats GNUstep's plist code asks for
   (`%Y-%m-%dT%H:%M:%SZ`; `%Y-%m-%d %H:%M:%S %z`) with `NSCalendarDate`'s own leniency (short
   fields, rollover, trailing junk). GNUstep reads the `...Z` form in the machine's *local* time
   zone (it has no `%z`), so its result depends on where it runs; oofnd reads it as UTC. Where
   GNUstep's date is nil, oofnd follows it (old-style: the whole plist is nil, no error; XML at
   top level: nil), except inside an XML container, where GNUstep raises
   `NSInvalidArgumentException` out of the parser and oofnd returns an error instead.
8. **GNUstep defaults.** Behaviour is that of the game's GNUstep defaults: `GSMacOSXCompatible` is
   NO (so a missing `;` before `}` is accepted, and the XML writer escapes control characters as
   `\Uxxxx`). GNUstep's `NSWarnFLog` for the missing `;` is not reproduced.
9. **Errors.** A failed parse returns `oo::Expected<PList, PListError>`; `PListError::message` is
   GNUstep's inner text (`Parse failed at line 3 (char 41) - unexpected character (wanted '=')`,
   `failed to parse as XML property list`) and `description()` wraps it as `-[NSError
   description]` did, so log lines keep their wording. A parse that GNUstep completes with nil and
   no error (an empty `<plist/>`) returns a null `PList`, not an error.

## Consequences

- The fuzz bead (oo-g2k) compares against GNUstep with items 2-7 as its known, allowed
  differences; any other divergence is a bug in oofnd.
- A binary or UTF-16 plist inside an expansion now fails to load where it used to load. If the
  corpus scan finds one, a follow-up adds that reader; the decision here is only the default.

## History

Written with bead oo-075 (the value type) from a reading of GNUstep base 1.31.1
(`NSPropertyList.m`, `NSXMLParser.m`, `GSMime.m`) and Oolite's `OOPListParsing.m` /
`OldSchoolPropertyListWriting.m`; items 2-9 are exercised by the parser and writer beads.

Bead oo-g2k (2026-09-23) ran the GNUstep differential harness (`tools/plist_fuzz.py`,
[report](../phases/2-plist-fuzz-report.md)) over every plist in the Tier-3 corpus and over
mutants of the unit-test inputs. The decisions above are unchanged; the fuzzer found cases that
fall under them which the text did not spell out, and the harness classifies them so:

- **Item 4** also covers GNUstep *never returning* (an `<!ATTLIST` whose unquoted default runs
  to the end of the data), GNUstep raising `NSMallocException` (a `<` or `</` as the last byte:
  a string of length -1), and `&#;` / `&#x;` (GNUstep uses an uninitialised value). oofnd fails
  the parse in each.
- **Item 5** also covers dictionary keys containing characters from U+00C0 up, in both writers:
  GNUstep's `-compare:` and `-caseInsensitiveCompare:` order them by GNUstep's own canonical
  decomposition (`GSeq_normalize`: `õ` sorts as `o` + U+0303, so before `s`), which needs its
  Unicode decomposition and combining-class tables; oofnd orders them by UTF-16 units. The
  dictionary read back is the same; only the order of lines in the file differs. No corpus plist
  is affected; a follow-up bead may port the tables if a consumer ever depends on the order.
- **Item 6** also covers XML plists that *declare* a single-byte encoding other than
  UTF-8/Latin-1/ASCII (`windows-1252`, `iso-8859-2`, ...): GNUstep transcodes them, oofnd reads
  them as UTF-8 with the Latin-1 fallback. The corpus has none.
- **Item 7**: a `%z` offset beyond 18 hours is read in the local zone by GNUstep (UTC in oofnd).
  An XML `<date>` is parsed from `[text cString]`, GNUstep's default C-string encoding
  (ISO-8859-1 in the game's Windows build; it depends on the locale elsewhere): oofnd reads it
  as ISO-8859-1 up to the first NUL, and a character beyond U+00FF, for which GNUstep raises
  `NSCharacterConversionException` out of the parser (at top level too), is an error in oofnd,
  as `NSInvalidArgumentException` already was.
