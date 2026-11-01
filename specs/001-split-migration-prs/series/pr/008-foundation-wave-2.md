# Move Foundation usage to oofnd, part 2

**Series:** step 8 of 25 · base `series/007-foundation-wave-1` · next `series/009-selector-families` **(gen)**

**Chapter:** P2 · 2.3 Foundation sweeps, OOLog, NSAssert and NSUserDefaults gaps · history `5faa477a34`..`fa9cbc6c24` (240 merges) · 48.3k src, 2.9k tests, 39 other changed lines; 1.7k lines in deleted files **(gen)**

## What this changes

This step finishes the per-file Foundation sweep over the large files (`PlayerEntity`, `ShipEntity`,
`Universe`, `GameController`, the OXZ manager) and fills the gaps it found. It adds 15 more
transitional bridges for the large classes and deletes 5 whose callers have all moved. The Foundation
categories (`NSStringOOExtensions`, `NSDictionaryOOExtensions`, `NSScannerOOExtensions`,
`NSNumberOOExtensions` and the others) and `OldSchoolPropertyListWriting` are deleted, their callers
moved to `oo::str` and the `oo::PList` writers. `oofnd` gains the remaining Foundation replacements,
each written against gnustep-base's observed behaviour:
- `oo::str::Scanner` and `CharacterSet` (`NSScanner`, `NSCharacterSet`);
- `oo::log::FileWriter` (the Latest.log writer behind `OOLogOutputHandler`);
- `oo::http::Download` (the OXZ manager's `NSURLConnection`, over WinHTTP on Windows);
- `OOAssert` and friends (`NSAssert`, `NSParameterAssert` and their C forms).

A transitional `NSUserDefaults+OODefaultsBridge` points the game's standard `NSUserDefaults` at
`oo::Defaults`, so both APIs share one preferences store while callers move over.

## Why

These are the files and Foundation families that step 7's recipe couldn't handle with a type swap:
they needed new `oofnd` components first (scanning, the log file, HTTP, assertions) or were too big
to convert in one change. Step 9 can only delete the bridges and retire the shared selectors after
every class has its C++ API, and that's done here.

## Behaviour changes

- OXZ manager downloads go through `oo::http::Download`. On Windows it uses WinHTTP and delivers the
  same callbacks `NSURLConnection` did. A few malformed-URL cases now fail at once where
  `NSURLConnection` never called back, and a relative redirect is followed. Pinned by
  `tests/unit/oofnd/test_http.cpp`, which replays the captured exchanges against a loopback server.
  On other platforms every http(s) download fails with an error until a non-Windows backend exists
  (`file:` URLs work). That path is not built or verified here.
- A failed assertion in a debug build logs one line in message class `gnustep` without `NSLog`'s
  date and process prefix, then raises `OOInternalInconsistencyException` with Foundation's reason
  text. Pinned by `tests/unit/oofnd/test_objc_assert.mm`. Release builds compile assertions out, as
  before.
- The system-description localisation tools (`--export-sysdesc`, `--compile-sysdesc`, in
  `OOConvertSystemDescriptions.mm`) now visit dictionaries in key order, where Foundation used hash
  order. That decides the slot an unknown key gets, the order of the "Assigning key" log lines and
  the key order of the dictionaries they write. `tests/unit/sysdesc/test_sysdesc_tools.mm` pins the
  new output (its digests come from the ported tool, not from the original). It isn't registered
  in meson, so `tests/run.sh` does not run it.
- QuickJS-ng is now built at `-O2`. Before, its wrap's `buildtype=release` gave an effective `-O3`
  despite the parent's options. The fix is a patch on the wrap's `meson.build`
  (`subprojects/packagefiles/quickjs-ng-o2.patch`) plus an explicit `optimization=2` in
  `src/meson.build`. No test in `tests/` pins the level.

## How to review

Start with the new `oofnd` headers, because the callers only make sense against them. Each header
opens with a table mapping Foundation to its replacement and lists what was captured from
gnustep-base:
- `src/oofnd/Scanner.hpp`, pinned by `tests/unit/oofnd/test_scanner.cpp`;
- `src/oofnd/LogFile.hpp`, pinned by `test_logfile.cpp`;
- `src/oofnd/Http.hpp`, pinned by `test_http.cpp`;
- `src/oofnd/objc/OOAssert.h`, pinned by `test_objc_assert.mm`.

Then read `src/Core/NSUserDefaults+OODefaultsBridge.h`. Its header comment explains how one store
serves both APIs, and `tests/unit/game/test_defaults_bridge.mm` tests it. Both are deleted in step 9.

The file sweeps follow step 7's recipe. Spot-check them the same way: compare a header on the base
and here, and check that the caller hunks are conversions at the call. The deleted Foundation
categories have no callers left. `git grep` for any selector they declared should find nothing
outside comments. `tests/unit/expander/test_string_expander.mm` is a differential test: its digests were recorded
from the original Foundation `OOStringExpander.mm`, with stubs for the game classes, and the swept
engine must reproduce them. Like the sysdesc test, it isn't registered in meson.
`src/Core/OODataFromOXZFile.mm` is the one function of `NSDataOOExtensions.mm` that survives,
renamed. The two-line change in `tools/fonttexgen` follows `StringFromEncoding`, which now returns
a C string.

## Verified **(gen)**

Not verified yet.

macOS (Phase 5: not converted) and Linux are not verified by this series.
