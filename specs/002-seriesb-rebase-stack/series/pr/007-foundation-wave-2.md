# Move Foundation usage to oofnd, part 2

**Series:** step 7 of 24 · base `seriesb/006-foundation-wave-1` · next `seriesb/008-selector-families` **(gen)**

**Replays:** `series/009-foundation-wave-2` (old 9 of the master-based series) · 48.2k src, 2.9k tests, 34 other changed lines; 1.7k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

This step finishes the per-file Foundation sweep over the large files (`PlayerEntity`, `ShipEntity`,
`Universe`, `GameController`, the OXZ manager) and #768's binding files, and fills the gaps it found.
It adds 15 more bridges for the large classes (`Entity+FoundationBridge` is a header only) and
deletes 5 whose callers have all moved, leaving 35. The Foundation categories
(`NSStringOOExtensions`, `NSDictionaryOOExtensions`, `NSMutableDictionaryOOExtensions`,
`NSScannerOOExtensions`, `NSNumberOOExtensions`, `NSDataOOExtensions`), `OOExcludeObjectEnumerator`
and `OldSchoolPropertyListWriting` are deleted, their callers moved to `oo::str` and the
`oo::PList` writers. `oofnd` gains the remaining Foundation replacements, each written against
gnustep-base's observed behaviour:
- `oo::str::Scanner` and `CharacterSet` (`NSScanner`, `NSCharacterSet`);
- `oo::log::FileWriter` (the Latest.log writer behind `OOLogOutputHandler`);
- `oo::http::Download` (the OXZ manager's `NSURLConnection`, over WinHTTP on Windows);
- `OOAssert` and friends (`NSAssert`, `NSParameterAssert` and their C forms);
- `oo::str::localizedCompare` (`-localizedCompare:`, over ICU), for the OXZ list and the saved
  commanders.

Two more Foundation services get game-side replacements:
- `OOScheduleDeferredCall()` (`GameController.h`) replaces `-performSelector:withObject:afterDelay:`
  for most callers, including #768's `quitGame()`;
- the JavaScript engine posts its reset notifications only on `oo::NotificationCenter`; it posted
  them on `NSNotificationCenter` as well, and the last observer there (`OOJSFunction`) moves over.

A transitional `NSUserDefaults+OODefaultsBridge` points the game's standard `NSUserDefaults` at
`oo::Defaults`, so both APIs share one preferences store while callers move over.

Build changes:
- QuickJS-ng is built at `-O2` with `NDEBUG`: the `default_options` of #768's
  `dependency('quickjs-ng')` in `src/meson/meson.build` now set `buildtype=debugoptimized`,
  `optimization=2` and `b_ndebug=true`. Before, its own `buildtype=release` gave `-O3`.
- On Windows, the `threads` dependency is overridden with the same `-pthread` compile flag and no
  link flag (`src/meson/meson.build`). The MinGW Clang driver ignores `-pthread` when linking and
  warned about it on every link that pulls in QuickJS-ng. From this step the Clang build prints only
  QuickJS-ng's 4 `-Wpedantic` warnings, down from 7.
- The game links `winhttp`, and `oofnd` links ICU (`icu-uc`, `icu-i18n`; gnustep-base already
  links the same ICU). `ShellScripts/Windows/install_deps.sh` installs it.
- A new meson option `deployment_unit_tests` builds the oofnd suite under the deployment flavour's
  macros, and a new `game-unit` suite (`tests/unit/game`, Windows, not in deployment) holds the
  preferences bridge's test.

## Why

These are the files and Foundation families that step 6's recipe couldn't handle with a type swap:
they needed new `oofnd` components first (scanning, the log file, HTTP, assertions, deferred calls)
or were too big to convert in one change. Step 8 can only delete the bridges and retire the shared
selectors after every class has its C++ API, and that's done here.

## Behaviour changes

- OXZ manager downloads go through `oo::http::Download`. On Windows it uses WinHTTP and delivers the
  same callbacks `NSURLConnection` did. A few malformed-URL cases now fail at once where
  `NSURLConnection` never called back, and a relative redirect is followed. Pinned by
  `tests/unit/oofnd/test_http.cpp`, which replays the captured exchanges against a loopback server.
  On other platforms every http(s) download fails with an error until a non-Windows backend exists
  (`file:` URLs work). That path is not built or verified here.
- A failed assertion logs one line in message class `gnustep` without `NSLog`'s date and process
  prefix, then raises `OOInternalInconsistencyException` with Foundation's reason text. Pinned by
  `tests/unit/oofnd/test_objc_assert.mm`. `OOAssert` stays live in every flavour, deployment
  (`NDEBUG`) included, as Foundation's assertions were: upstream's `NS_BLOCK_ASSERTIONS` came too
  late to block them, and `PlayerEntity`'s `-deferredInit` relies on the side effect inside its
  assertion. Pinned by `tests/unit/oofnd/test_objc_assert_ndebug.mm`, which compiles the header with
  `NDEBUG` and fails against a header that compiles assertions out.
- The system-description localisation tools (`--export-sysdesc`, `--compile-sysdesc`, in
  `OOConvertSystemDescriptions.mm`) now visit dictionaries in key order, where Foundation used hash
  order. That decides the slot an unknown key gets, the order of the "Assigning key" log lines and
  the key order of the dictionaries they write. Not pinned by a test that runs:
  `tests/unit/sysdesc/test_sysdesc_tools.mm` records the new output (its digests come from the
  ported tool, not from the original), but it is not registered in meson, and the script its header
  names is not in the tree, so nothing builds or runs it.
- QuickJS-ng's code is compiled at `-O2` instead of `-O3`, with `NDEBUG` as before. Not pinned by a
  test.

`OOScheduleDeferredCall()` is meant to fire calls as the run loop did (in the order scheduled, at
most two per frame, main thread only); no test pins that.

## How to review

Start with the new `oofnd` headers, because the callers only make sense against them. Each header
opens with a table mapping Foundation to its replacement and lists what was captured from
gnustep-base:
- `src/oofnd/Scanner.hpp`, pinned by `tests/unit/oofnd/test_scanner.cpp`;
- `src/oofnd/LogFile.hpp`, pinned by `test_logfile.cpp`;
- `src/oofnd/Http.hpp`, pinned by `test_http.cpp`;
- `src/oofnd/objc/OOAssert.h`, pinned by `test_objc_assert.mm` and `test_objc_assert_ndebug.mm`;
- `oo::str::localizedCompare` in `src/oofnd/String.hpp`, pinned by `test_localized_compare.cpp`
  against a table captured from gnustep-base.

Then read `OOScheduleDeferredCall()` in `src/Core/GameController.h/.mm`, and
`src/Core/NSUserDefaults+OODefaultsBridge.h`. The bridge's header comment explains how one store
serves both APIs, and `tests/unit/game/test_defaults_bridge.mm` tests it. Both are deleted in
step 8. `src/Core/Debug/OOTCPStreamDecoderFormat.hpp` is the debug console decoder's formatter,
moved into a header so `test_tcp_stream_format.cpp` can test it.

The file sweeps follow step 6's recipe. Spot-check them the same way: compare a file with
`git diff seriesb/006-foundation-wave-1 seriesb/007-foundation-wave-2 -- <file>` and check that the
caller hunks are conversions at the call. The deleted Foundation categories have no callers left:
`git grep` for any selector they declared should find nothing outside comments.
`src/Core/OODataFromOXZFile.mm` is the one function of `NSDataOOExtensions.mm` that survives,
renamed. The two-line change in `tools/fonttexgen` follows `StringFromEncoding`, which now returns
a C string.

Upstream guards are kept where the swept code has them: #756's `OO_DEBUG_MONITOR_ENABLED` (not
`NDEBUG`) around the debug console client and its wait in `GameController.mm`, and around
`Universe+FoundationBridge`'s `-entityList`; #766's `keymappings_mac.plist` under
`OOLITE_MAC_COCOA_UI` in `PlayerEntityKeyMapper.mm`. The deployment flavour compiles.

`tests/unit/expander/test_string_expander.mm` is a differential test: its digests were recorded
from the original Foundation `OOStringExpander.mm`, with stubs for the game classes, and the swept
engine must reproduce them. Like the sysdesc test it is not registered in meson and its build script
is not in the tree, so in practice it does not pin the expander either.

## Verified **(gen)**

Not verified at this branch's tip (`0ffa5f13ed`) yet: the last record is for `7add964f14` (2026-11-02), an earlier build of this step.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
