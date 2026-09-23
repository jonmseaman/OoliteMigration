# ADR-0034 — `oo::str`: GNUstep's string behaviour over UTF-8 `std::string`, bridged per call

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-dps, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** seam 2.5b of [Phase 2](../phases/2-oofnd.md) ("String utilities: retires the
`NSString` categories, `OOStringParsing`, `OOStringExpander`, `OOEncodingConverter`") in
`upstream/oolite/src/oofnd/String.hpp` and `Encoding.hpp`; bridge `src/Core/OOStringBridge.h`;
exemplar `src/Core/OOOXZManager.mm`. Decision 4 (`std::string`) was confirmed by bead oo-lvj
([2-string-benchmark.md](../phases/2-string-benchmark.md)).

## Context

Oolite's string code leans on `NSString` answers that are not "obvious": which characters are
whitespace, how `-capitalizedString` breaks words, what `-pathExtension` of `"C:.b"` is, how a
Windows code page receives a character it lacks. Many of them are visible in golden output (HUD
text through `OOEncodingConverter`, expanded descriptions, names). The replacement must give the
same answers, and the sweeps that adopt it are done by smaller models, so the adoption shape must
be mechanical.

### Measured (gnustep-base 1.31.1, this toolchain; throwaway probes)

1. **Case mapping is one unit to one unit**, from tables older than current Unicode (no Glagolitic,
   no Cherokee; `ß` has no capital; `İ` lowercases to `i`). 706 upper and 696 lower mappings.
2. **Composed sequences.** Non-literal searches (`-rangeOfString:`, `-pathExtension`'s dot,
   `-replaceOccurrencesOfString:...options:0`) reject a match that a "sequence-extending" unit
   follows: 229 BMP ranges (combining and spacing marks, modifier letters, variation selectors,
   low surrogates). A target that *starts* with such a unit raises `NSRangeException`.
   `-hasPrefix:`/`-hasSuffix:` and `NSLiteralSearch` are literal. No canonical equivalence:
   `e` + U+0301 does not match `é`.
3. **`-caseInsensitiveCompare:` against ASCII** is equal exactly when the other string is ASCII and
   equal ignoring ASCII case (no non-ASCII unit, alone or in context, equals any printable ASCII
   character; none is ignored). Between two non-ASCII strings it decomposes (`e`+U+0301 == `é`).
4. **`-pathExtension`** treats `/` and `\` as separators, `X:` and `~user/` as roots, a leading dot
   as no extension, and trailing separators as absent.
5. **`-stringWithFormat:` without `%@` equals C `snprintf`** for 2,102 of 2,183 captured
   (conversion, value) pairs. The 81 that differ: `%s` of non-ASCII bytes (GNUstep decodes them as
   Latin-1), `%c`/`%lc` above 0x7F, `%p`, `%hhd`, and `%f` of magnitudes ≳ 1e22 (GNUstep truncates
   the digits).
6. **Lossy conversion to a Windows code page goes through libiconv with transliteration**:
   native byte, else the first of the character's transliterations that the page can encode
   (`Ć` is `´C` in CP1252 and `'C` in CP1251; U+1F600 is `:-D`; 2,175 code points have one), else
   `?` per UTF-16 unit; a string ending in a lone high surrogate converts to nil.
7. **Creating an `NSString`** from UTF-16 units with `-stringWithCharacters:` drops a leading U+FEFF
   and byte-swaps after a leading U+FFFE; `-initWithBytes:length:encoding:` with
   `NSUTF16LittleEndianStringEncoding` keeps every unit. `-UTF8String` turns a lone surrogate
   into U+FFFD.

## Decision

1. **`oo::str` is free functions over UTF-8 `std::string`** (WTF-8 for a lone surrogate, as
   `oo::PList` already holds strings). Where GNUstep's answer depends on UTF-16 (case, character
   sets, lengths, indices, composed sequences), the function works on the UTF-16 units exactly as
   `NSString` does and converts back. Tables are generated from the probes and pinned by digests
   over the whole captured output (BMP sweeps and generated corpora), so the tests fail on any
   single character that differs. Header-only, no exceptions.
2. **Faithful where it is cheap, documented where it is not.** Reproduced: measurements 1–4, 6, and
   the literal/composed search split. Not reproduced, each named in the header: the exception for
   a target starting with a combining mark; canonical-equivalence comparison of two non-ASCII
   strings (`equalsIgnoringCaseAscii` takes an ASCII side, which is every game call site); the
   `%f`/`%s`/`%c`/`%p`/`%hhd` format differences (`oo::str::format` is `vsnprintf`: a sweep that
   turns `%@` into `%s` must keep UTF-8, which GNUstep's own `%s` would have garbled).
3. **The bridge is per call, not per file** (`src/Core/OOStringBridge.h`): `oo::StdString(NSString*)`
   and `oo::NSStringFrom(std::string_view)` are exact both ways (measurement 7), and
   `oo::StringMap(s, f)` keeps messaging-nil semantics for `NSString -> NSString` methods. A file
   keeps its `NSString`s and replaces category calls one for one (recipe in `src/oofnd/README.md`,
   "Migrating NSString category calls"); verified against the real category over 20,000 corpus
   strings with leading BOMs and lone surrogates, 0 differences.
4. **What "retires" means, component by component.**
   - `NSStringOOExtensions`, `NSString (OOUtilities)`, `ScanTokensFromString`,
     `ComponentsFromVersionString`/`CompareVersions`: replaced by `oo::str` now; the categories go
     when their last call site migrates.
   - `OOEncodingConverter`: its conversion is `oo::str::convertForFont` now; the class (an `OOCache`
     in front of it) stays game-side until HeadUpDisplay is swept. Substitutions are applied in the
     order the caller passes, i.e. the `NSDictionary`'s enumeration order: order matters only for
     overlapping substitutions, and the shipped font has none.
   - `OOStringParsing`'s vector/quaternion/seed scanners use `NSScanner` and go with the scanning
     helpers (oo-3rb.12). `OOStringFromDeciCredits` (JavaScript), `ClockToString` (descriptions),
     `OOPadStringToEms` (font metrics) are game logic, not Foundation: they are converted in place
     by the Foundation sweep, on `oo::str`.
   - `OOStringExpander` is game logic too (Universe, PlayerEntity, JavaScript, descriptions). Every
     Foundation primitive it uses now exists and is pinned (`capitalized`, `format` for
     `precision`/`multiply`/`add`, `split`, `replaceOccurrences(..., Search::literal)` for `%R`,
     `hasPrefix`/`hasSuffix`, the number readers). Converting its engine onto them is its own bead
     (oo-3rb.61), because its output is golden-visible and needs its own differential harness.
5. **Performance rule** (oo-lvj): where Objective-C retained a string, C++ takes
   `std::string_view` / `const std::string&` or moves; a string is copied only where Objective-C
   copied.

## Consequences

- Two headers (≈ 1,180 lines, of which ≈ 450 are generated tables) and two test files (≈ 5 s and
  3 s to compile, about a second each to run) in `tools/check-oofnd.sh`.
- The digest tests cannot say *which* character differs; the probe programs that produced them
  are described in the test files so a failure can be re-captured.
- The bridge assumes a little-endian host (every Phase 2–5 target is).
- Found on the way, filed separately: `+stringWithContentsOfUnicodeFile:` passes `length + 3`
  instead of `length - 3` after a UTF-8 BOM, reading six bytes past the file's buffer.

## Follow-up beads

- oo-3rb.61: `OOStringExpander` engine onto `oo::str`, with a differential harness that compiles the real
  `OOStringExpander.mm` against stubbed `Universe`/`PlayerEntity`/JS and the shipped
  `descriptions.plist`.
- oo-3rb.62: `+stringWithContentsOfUnicodeFile:` UTF-8 BOM over-read (upstream bug; decide fix vs. reproduce).
- oo-3rb.63: sweep the remaining `NSStringOOExtensions` / `OOUtilities` call sites, one file per story.

## Alternatives considered

- **`std::u16string` as the string type.** Matches `NSString` indices, but decision 4 is
  `std::string`, and UTF-8 is what files, plists, JavaScript and logs hold.
- **ICU for case, normalisation and transliteration.** A large dependency whose tables are newer
  than GNUstep's, so it would change output (measurement 1); oofnd takes no third-party code
  without an ADR, and the captured tables are smaller.
- **`std::format` for `-stringWithFormat:`.** Different syntax at every call site; `%`-formats move
  over unchanged with `vsnprintf`, which matches GNUstep on the conversions the game uses.
  Logging (oo-qpb) decides its own formatter.
