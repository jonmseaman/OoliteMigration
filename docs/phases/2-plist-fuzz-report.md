# oofnd PList vs GNUstep: differential fuzz report (contract C1)

Bead oo-g2k, 2026-09-23. Evidence for the Phase 2 exit-gate line "`oofnd` old-style **and** XML
plist parser/writer fuzzed against GNUstep with zero divergences on the corpus". Differences that
[ADR-0027](../decisions/0027-oofnd-plist-fidelity.md) declares intentional are classified by item
number and not counted; everything else is an unexplained divergence and fails the run.

Unexplained divergences on the Tier-3 corpus: 0

## Harness

`tools/plist_fuzz.py` builds two programs on demand and runs both over the same files:

| Side | Program | What it runs |
|---|---|---|
| reference | `tools/plist-fuzz/gnustep_oracle.mm`, linked against the installed GNUstep base 1.31 with the game's own `OldSchoolPropertyListWriting.mm` | `OOPropertyListFromData` (`ChangeDTDIfApplicable` + `NSPropertyListSerialization`), `-oldSchoolPListFormatWithErrorDescription:`, GNUstep's XML writer |
| oofnd | `tools/plist-fuzz/oofnd_plist.cpp` | `oo::parsePropertyList`, `oo::writeOldStylePList`, `oo::writeXMLPList` |

The oracle is a test utility, never linked into the game (it is the one file exempt from the
deny-list scan in `tools/guardrails.sh`, for that reason). Both print each parse in the canonical
one-line form of `tests/unit/oofnd/plist_dump.hpp` (the form the unit tests pin), or the error text
`OOPropertyListFromData` logged. Per file the comparator checks five stages:

| Stage | Passes when |
|---|---|
| `parse` | same tree and format, or the same error message, or both nil |
| `old` | old-style writer bytes identical (or the same error) |
| `xml` | XML writer bytes identical (or the same error) |
| `rt-old`, `rt-xml` | oofnd's output, re-parsed **by GNUstep**, gives back the original tree; where it does not but GNUstep's own writer wrote the same bytes, the loss is GNUstep's (`lossy-in-gnustep`: e.g. old-style numbers come back as strings) |

A crash or hang of either program is charged to the file it was processing; oofnd crashing or
hanging is always a divergence. The oracle pins its time zone to UTC (ADR-0027 item 7) and skips
GNUstep's old-style data writer where it overruns its buffer or never returns (item 4).

**Rule 6.** In corpus mode the tool opens the cached archives but prints only counts; a
divergence is reported as the expansion identifier, a hash of the member path, the stage, a
structural path whose dictionary steps are key *indices*, and node types or value hashes. No key,
value or error text from an expansion is ever printed.

**Fuzzer.** `fuzz` mutates 48 synthetic seeds taken from the oofnd unit-test inputs (no expansion
content): byte flips, token insertion (plist and XML syntax, escapes, BOMs, invalid UTF-8,
dates, numbers), deletion, duplication, truncation and splicing. It is deterministic per seed.

```sh
python3 tools/plist_fuzz.py selftest                  # the comparator catches planted divergences
python3 tools/plist_fuzz.py fuzz --seed 1 --count 5000
python3 tools/plist_fuzz.py corpus                    # every .plist in tools/oxp-corpus/tier3.json
```

The accept block runs `selftest` and the seed-1 fuzz (about 20 s). The full corpus and a
100,000-mutant fuzz with a date-derived seed run nightly (`tests/nightly/checks.txt`, `[oo-g2k]`).

## Tier-3 corpus

813 archives (all cached), 4,350 `.plist` members: 4,136 old-style, 210 XML, 4 rejected by both.

| Stage | MATCH | Intentional (ADR-0027) | lossy-in-gnustep | Unexplained |
|---|---|---|---|---|
| parse | 4,346 (+4 both reject) | 0 | - | 0 |
| old-style writer | 4,339 | 7 (item 5: 2 bare non-ASCII, 3 case-equal keys, 2 both) | - | 0 |
| XML writer | 4,346 | 0 | - | 0 |
| rt-old | 4,109 | 3 (item 5) | 234 | 0 |
| rt-xml | 4,346 | 0 | 0 | 0 |

The parser matched GNUstep on every corpus file before any fix in this bead; the fixes below
came from the fuzzer.

## Fuzz

Seeds 8-15, 40,000 mutants each plus the 48 seeds (320,384 inputs), after the fixes:

| Stage | Result |
|---|---|
| parse | 39,125 MATCH, 266,652 both reject, 8,675 both nil; intentional: item 2 418, item 3 724, item 4 1,093, item 6 50, item 7 3,647 |
| old-style writer | 37,033 MATCH; intentional: item 4 497, item 5 1,595 |
| XML writer | 39,118 MATCH; intentional: item 5 7 (non-ASCII key order) |
| round trips | rt-old 33,659 MATCH / 3,941 lossy-in-gnustep / 7 item 4; rt-xml 37,827 MATCH / 1,298 lossy-in-gnustep |
| **unexplained** | **0** |

Seeds 1-7 (40,000 each) were also clean on the final code.

## Fixes to oofnd (each with a new unit test)

| Found | Fix | Test |
|---|---|---|
| A tag, declaration word, attribute or text run that reaches the end of the data loses its last byte (`cget()` does not advance); cut inside a UTF-8 character GNUstep's `NewUTF8STR` is nil and the parse fails. oofnd accepted it. | `PListXML.hpp`: the same check at every `NewUTF8STR` site | `test_plist_xml.cpp` `aTokenCutAtTheEndOfTheDataMustBeUtf8` |
| `<!ATTLIST x a b c` at the end of the data: oofnd looped forever (as GNUstep does). | fails the parse (item 4) | `whereGNUstepNeverReturnsOofndFails_ADR0027` |
| Tag, declaration and attribute names lose a leading BOM as NSStrings do (`<﻿array>` is an array). | strip it | `namesLoseALeadingBomAsNSStringsDo` |
| `encoding=""` (or an unknown name) is read as UTF-8 by GNUstep; oofnd refused it (`""` was its "UTF-16" sentinel). | read as UTF-8 | `anEmptyOrUnknownEncodingNameReadsAsUtf8` |
| XML `<date>` text is parsed as a Latin-1 C string, cut at a NUL; a character beyond U+00FF makes GNUstep raise. | same conversion; error (item 7) | `dateTextIsReadAsACStringInLatin1` |
| Dates: a day or month of 0 makes `NSCalendarDate` nil; a `%z` offset beyond 18 hours is ignored (local zone). | `PList.hpp` `parseCalendarDate` | `test_plist_oldstyle_structures.cpp` `dateFieldsNSCalendarDateRejects`, `dateZoneBeyondEighteenHoursIsUtc_ADR0027` |

Cases the fuzzer found that fall under ADR-0027 without the text naming them (GNUstep hanging or
raising `NSMallocException`, `&#;`, declared single-byte encodings, non-ASCII key order in the
writers, date conversion exceptions) are listed in the ADR's History section.
