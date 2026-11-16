---
status: Ready
parent: seriesb/032-cleanup
---
# Shrink oofnd onto std / SDL3 / ICU / curl

## Context

`src/oofnd` (about 11,400 lines) was written to give GNUstep 1.31.1's answers byte for byte. On
`seriesb/032-cleanup`, Jon allows answers that aren't byte-exact (2026-11-15). The aim is to delete
the emulation and keep only what no linked library does. Already done elsewhere: ownership moved to
`shared_ptr` and `Ref.hpp` was deleted (spec 009), case mapping moved to ICU (spec 015), and a JSON5
reader and writer exist on the unmerged `seriesb/030-json5-data-files`.


## Lines that stay (what players, expansions and saves can see)

- **Saves:** the save-game XML must stay valid Apple plist XML that upstream can load. Whitespace and
  escaping style are free to change. The reader must still accept upstream and Apple-DTD saves.
  Dates stay seconds since 2001.
- **Save checksum:** `PlayerEntity.cpp:1524-1531` checksums `oo::str::length(DescriptionOf(...))`, a
  UTF-16 count. That count and the scalar DescriptionOf text stay exactly as they are.
- **Expansion data:** the old-style plist parser stays, apart from small quirk trims. The basic
  `PList::get<T>` coercions on strings stay: fallback on a missing or wrong-kind value, yes/true/on,
  plain number parsing.
- **Text and logs:** `formatRuntime` (`%@` and positional DESC strings) stays. The Logger, the
  logcontrol class inheritance and the `***** ERROR: ` prefix and `[class]` layout stay, because the
  component and GUI tests grep Latest.log for them.
- **Locations:** where saves, logs, ManagedAddOns and defaults live stays the same. See Wave 5.

## Test edits

Jon's 2026-11-15 allowance covers editing the tests that pin GNUstep-only answers. That needs his
date recorded under hard rule 1, so confirm it at approval. Every edit goes in
`notes/kanban/oofnd-shrink-test-ledger.md`: file, old form, new form, and whether the assertion's
meaning is kept. GNUstep-captured rows become std/ICU answers computed at run time, never a new
captured digest (spec 015 FR-003: ICU differs between CI distros).

The base done check for every task: `./mk.sh build dev` and `tests/run.sh unit` pass with no new
warnings. Each task below adds its own grep check, which fails before the work and passes after.

## Wave 1: dead code and forwarding headers (S, no test edits)

1. **Delete code nothing in `src/` calls.**
   - In `String.hpp`: `decodeUnicodeFile` (a duplicate of `Encoding.hpp`'s `decodeUnicodeText`),
     `utf16Data`, `tabString`, `appendLine`, `trimTrailingWhitespaceAndNewlines`.
   - In `Scanner.hpp`: `decimalDigit`, `fromCharacters`, `inverted`, `findFirstOf`, `findLastOf`,
     `splitByCharacters`.
   - In `Process.hpp`: `oo::env` and `processorCount`.
   - Their tests go too, which is a test deletion. It needs the ledger, or Jon's OK if the allowance
     doesn't cover deleting.
   - Done when `git grep -qE 'decodeUnicodeFile|splitByCharacters|processorCount' -- src` exits
     nonzero.
2. **Delete the forwarding headers `oofnd/objc/OOException.h` and `oofnd/objc/OOObject.h`.**
   - Point their includes (about 75 lines) at `oofnd/Exception.hpp`.
   - Drop the `OOZone` parameter from `OOMesh::copyWithZone` (`OOMesh.h:132`, `OOMesh.cpp:287,814`).
   - Done when `git grep -qE 'objc/OO(Exception|Object)\.h|OOZone' -- src tests` exits nonzero.
3. **Clean up `OOFoundation`.**
   - Delete the empty `src/Core/OOFoundation.cpp` and the dead `NS_BLOCK_ASSERTIONS` (`OOFoundation.h:46`).
   - Fold away `OOLITE_SDL`, which is always 1 (23 sites in 11 files).
   - Done when `git grep -qE 'OOLITE_SDL|NS_BLOCK_ASSERTIONS' -- src` exits nonzero.

## Wave 2: swap straight to std or SDL (S)

4. **`hasPrefix`/`hasSuffix` become `starts_with`/`ends_with`** (186 sites).
   - One behaviour difference: today an empty prefix never matches. Check every call site whose
     prefix is a variable.
   - Then delete both functions.
   - Done when `git grep -qE 'str::has(Prefix|Suffix)' -- src` exits nonzero.
5. **`pointerDescription(p)` becomes `std::format("{}", static_cast<const void*>(p))`** (58 log-only
   sites). Done when `git grep -q pointerDescription -- src` exits nonzero.
6. **The 12 `oo::str::format` callers move to `std::format`.** Keep `vformat` for the `va_list` JS and
   verifier reporters. Done when `git grep -qE 'str::format\(' -- src` exits nonzero.
7. **`WeakSet<T>` becomes a plain vector.**
   - Use `std::vector<std::weak_ptr<T>>` with `std::erase_if(expired)`. Keep `forEach`'s snapshot
     behaviour, because callbacks change the set.
   - It has 3 members: `ShipEntity.h:1556,1559` and `StationEntity.h:231`.
   - Delete `WeakSet.hpp` and `test_weakset.cpp`; the ledger records the deletion.
8. **`Date` uses the standard clocks.**
   - `monotonicSeconds` becomes `std::chrono::steady_clock`.
   - `description()` builds its text from `SDL_GetCurrentTime` + `SDL_TimeToDateTime`. The tz
     database isn't reliable in MinGW libstdc++.
   - Keep `kReferenceDateSince1970`.
9. **`Defaults` drops its private OpenStep writer.** Replace `writeOpenStepPList`
   (`Defaults.hpp:218-384`) with `oo::writeOldStylePList`. This changes the defaults file's text but
   not its values.
10. **`OOAssert` drops GNUstep's form.**
    - Use `std::source_location` instead of `__PRETTY_FUNCTION__`, and `std::format`.
    - Rename the "gnustep" log class to "assert".
    - Keep the assertions live under `NDEBUG`, because some conditions have side effects
      (`OOAssert.h:13-15`).

## Wave 3: text on bytes, not UTF-16 (M)

11. **Rewrite `Scanner` as a byte cursor.**
    - It becomes about 80 lines: a `std::string_view` cursor that skips ASCII whitespace, reads
      numbers with `std::from_chars` (strip a leading `+` by hand), and matches with an ASCII
      case-insensitive prefix.
    - It replaces `Scanner.hpp` (574 lines) and its BMP tables. The users are `OOStringParsing.cpp`,
      `OOColor.cpp:254`, `ShipEntity.cpp:992` and the `OOMesh` .dat parser, which gets faster.
    - The one `CharacterSet::alphanumeric` caller (`OOJSGlobal.cpp:829`) uses ICU `u_isalnum`.
    - `test_scanner.cpp` is mostly rewritten (ledger).
12. **`PList::get<T>` and `str::intValue`/`doubleValue` parse with `std::from_chars`.**
    - They currently go through the NSScanner port in `PListGet.hpp:118-323`.
    - Out-of-range values saturate. Drop the 20-character cap and the rule that an unsigned value
      reads as a sign-extended `intValue`.
    - The edge rows in `test_plist_get.cpp` are rewritten (ledger).
    - Do task 11 first, since both use the same helper.
13. **`tokens` and `trim` work on bytes.** Whitespace means ASCII whitespace plus U+00A0. Drop the
    composed-sequence rule from `replaceOccurrences`.
14. **Simpler path functions.**
    - Write about 80 lines of `/`-only byte functions: `appendingPathComponent`, `lastPathComponent`,
      `pathExtension`, and so on.
    - Drop the UNC, `~user` and trailing-slash rules, and `kSequenceExtenders` (`String.hpp:408-480`).
    - Don't use `std::filesystem::path`: it treats `"a/"` and drive roots differently.
    - `test_string_sweep.cpp` and `test_string_path_extension.cpp` are re-expressed (ledger).
15. **`LogFile` converts bytes only.**
    - On Windows, write `\n` as `\r\n`; replace invalid UTF-8 with U+FFFD (`u_strFromUTF8WithSub`).
    - Drop the lone-surrogate line dropping and the extender rule (`LogFile.hpp:82-129`).
    - Do task 14 first: this removes the last user of `extendsSequence` outside String.hpp.
16. **`Encoding` uses ICU `ucnv`.**
    - Encode with `ucnv_open("windows-125x")`, the substitute callback and `ucnv_setFallback(true)`,
      plus an ICU `Transliterator("Any-Latin; Latin-ASCII")` pass for characters that still have no
      byte. That deletes about 1,100 lines of libiconv tables from `Encoding.hpp`.
    - `decodeUnicodeText` uses real BOM detection, then strict UTF-8, then falls back to windows-1252.
    - `SDL_iconv` won't do: it has no CP125x code pages on Windows or macOS.
    - `test_encoding.cpp` and `test_unicode_file*.cpp` are rewritten against ICU (ledger).
17. **Simplify `formatRuntime` but keep it.**
    - Count `%@` width in code points and print `%p` through `std::format`.
    - Keep the `UTF-16 length` helper that the save checksum uses, renamed `utf16Length`, with a test
      pinning the checksum over a fixed save.

## Wave 4: simpler plist output and error handling (M)

18. **Simplify the plist writers.**
    - The XML writer indents with one tab and escapes correctly every time
      (`PListWriting.hpp:335-547`).
    - Fix the old-style writer bug instead of reproducing it (`PListWriting.hpp:20`).
    - `test_plist_writers.cpp` is regenerated, and the debug-console and OXZ tests are rechecked.
    - Add a test that round-trips a save through the reader.
19. **Collection descriptions become simple.** Arrays and dicts in `DescriptionOf` use a plain
    `(a, b)` / `{k = v; }` form with no NFD key sort and no octal escapes. Scalars are unchanged: the
    string expander, the legacy script conditions and the save checksum use them.
20. **A smaller XML plist reader.**
    - Write a plist-only reader of about 400 lines in place of the GSSloppyXMLParser port
      (`PListXML.hpp`, 916 lines).
    - It handles CDATA, tolerates a leading BOM or whitespace, and keeps accepting the Apple DTD.
    - Don't add libxml2 or expat.
    - Gate: every `.plist` save under `tests/` reads back to the same tree it did before.
21. **Exceptions are caught by type.**
    - Each `catch(...) { if (!CurrentOOException()) throw; }` (51 sites in 24 files) becomes
      `catch (const oo::Exception& e)`.
    - Then delete `CurrentOOException`. Keep the `NS*Exception` names, since JS error and log text
      shows them.
22. **`Notification` becomes signals.** Replace it with `oo::Signal<>` members: the JS engine's
    `willReset`/`didReset` and the debug monitor's terminate. That covers 3 names, 4 posts and about 14
    observers. Removal during a post must keep working.
23. **`Http` uses more of curl.**
    - Use `curl_url` for URL checks and `CURLINFO_RESPONSE_CODE` / `CONTENT_LENGTH_DOWNLOAD_T` instead
      of parsing headers by hand.
    - Use `std::jthread` with a stop token.
    - `OOOXZManager` owns the download through `std::unique_ptr`.
24. **`NSPoint`/`NSSize`/`NSRect`/`NSRange` become `oo::Point`/`Size`/`Rect`/`Range`.**
    - Add aliases first, then sweep the 625 sites. The fields stay `double`.
    - Keep the value of `oo::kNotFound`.

## Wave 5: needs Jon; default is don't do it

- **Locations on `SDL_GetBasePath`/`SDL_GetPrefPath`.** `ResourcePaths` and `Defaults` would move
  there, with a one-time migration from `GNUstep/…` and `oolite-saves`. That moves saves, logs and
  settings, which players see and installers rely on. Default: keep the paths, but replace the
  `HOMEPATH` `setenv` hack in `SDL/main.cpp:138-150` with `SDL_GetBasePath` for the built-in
  Resources lookup only.
- **Remove `AutoreleaseScope`** (35 autorelease sites, 62 scopes). It decides when entities are freed
  within a frame. Wait until spec 009 T099's ASan run is clean; it becomes its own spec.
- **Defaults as JSON5.** This needs `seriesb/030` merged first.

## Keep as is

`Object.hpp`, `Thread.hpp` (SDL3 can't name the current thread), the old-style plist parser, the
Logger, `FileWriter`, `PrintfFormat.h`, `localizedCompare`, `compareVersions`, `Data.hpp` (a thin
vector already; renaming 176 sites gains nothing), and `fs::pathFromUTF8` and `writeFile`.

## Decisions (defaults taken)

- **The paths of saves, logs and settings don't move.** Moving them is player-visible and needs a
  migration.
- **The save checksum and scalar descriptions stay byte-exact.** Otherwise existing saves would fail
  their integrity check.
- **No new dependencies.** The XML reader and the transliteration use code we already have or ICU.
- **Each task is its own commit,** so a regression bisects to a single swap.

## Verification

- Each task: its grep check, `./mk.sh build dev`, then `tests/run.sh unit`.
- After each wave: `tests/run.sh component` and `tests/run.sh smoke`.
- After Wave 4: load an upstream save and a save written before the changes, save again, and diff the
  trees with the plist round-trip test.
- Measure the size: `wc -l src/oofnd/*.hpp` is about 11,400 lines now; the target after Waves 1–4 is
  under 6,000.
