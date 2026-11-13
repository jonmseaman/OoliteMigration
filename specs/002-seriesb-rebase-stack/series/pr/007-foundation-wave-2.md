# Move Foundation usage to oofnd, part 2

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 7/28. Replays `series/009-foundation-wave-2`.

## What this changes

- Finishes the sweep over the large files (`PlayerEntity`, `ShipEntity`, `Universe`,
  `GameController`, the OXZ manager) and #768's binding files; remaining `oo_*ForKey:` →
  `PListView` (`get<bool>`/`at<bool>`). 15 bridges added (`Entity+FoundationBridge` header only),
  5 deleted, 35 left.
- Deleted: the six `NS*OOExtensions` categories (String, Dictionary, MutableDictionary, Scanner,
  Number, Data), `OOExcludeObjectEnumerator`, `OldSchoolPropertyListWriting`; callers use `oo::str`
  and the `oo::PList` writers.
- New `oofnd`: `oo::str::Scanner`/`CharacterSet`, `oo::log::FileWriter`, `oo::http::Download`
  (WinHTTP), `OOAssert`, `oo::str::localizedCompare` (ICU). Game side: `OOScheduleDeferredCall()`
  replaces most `-performSelector:withObject:afterDelay:` (incl. #768's `quitGame()`);
  `NSUserDefaults+OODefaultsBridge` shares one store with `oo::Defaults`; JS reset notifications
  post only on `oo::NotificationCenter`. #768's two error-report fixes are kept (frame location
  from the first `(`; only warnings dropped when their log class is off).
- Build: QuickJS-ng `optimization=2`, `b_ndebug=true`; Windows `threads` drops the link-time
  `-pthread` (Clang warnings 7 → 4); links `winhttp` and ICU; option `deployment_unit_tests`; new
  suite `game-unit` (`tests/unit/game`, Windows, not deployment).

## Why

Step 8 deletes the bridges, which needs every class's C++ API and these new `oofnd` components.

## Behaviour changes

- OXZ downloads use `oo::http::Download` with `NSURLConnection`'s callbacks; some malformed URLs
  fail at once (never called back) and relative redirects are followed. Pinned by
  `tests/unit/oofnd/test_http.cpp` (loopback replay).
- Non-Windows: every http(s) download fails (`file:` works) until a backend exists. Not built or
  verified here.
- A failed assertion logs one `gnustep`-class line without `NSLog`'s date/process prefix, then
  raises `OOInternalInconsistencyException` with Foundation's reason. Pinned by `test_objc_assert.mm`.
- `OOAssert` stays live under `NDEBUG`, as Foundation's did (`-deferredInit` relies on an
  assertion's side effect). Pinned by `test_objc_assert_ndebug.mm`.
- `--export-sysdesc`/`--compile-sysdesc` visit dictionaries in key order (was hash order): unknown
  keys' slots, "Assigning key" log order, output key order. Not pinned:
  `tests/unit/sysdesc/test_sysdesc_tools.mm` records the new output but is not in meson and its
  build script is not in the tree.
- QuickJS-ng compiles at `-O2` (was `-O3`), `NDEBUG` as before. Not pinned.
- `OOScheduleDeferredCall()` fires in scheduled order, at most two per frame, main thread only
  (was the run loop). Not pinned.

## How to review

Start with the new headers (`Scanner.hpp`, `LogFile.hpp`, `Http.hpp`, `objc/OOAssert.h`,
`localizedCompare` in `String.hpp`), each opening with a Foundation → replacement table, next to
its `tests/unit/oofnd/` test (`test_scanner`, `test_logfile`, `test_http`, `test_objc_assert*`;
`test_localized_compare` checks against a table captured from gnustep-base). Then `OOScheduleDeferredCall()` in `GameController.mm` and
`NSUserDefaults+OODefaultsBridge.h` (`tests/unit/game/test_defaults_bridge.mm`), both deleted in
step 8. `Debug/OOTCPStreamDecoderFormat.hpp` is the console formatter, moved out for
`test_tcp_stream_format.cpp`.

Rule: step 6's recipe, caller hunks only conversions; a deleted category's selectors `git grep` to
nothing outside comments.

    git diff seriesb/006-foundation-wave-1 seriesb/007-foundation-wave-2 -- <file>

Upstream guards kept: #756's `OO_DEBUG_MONITOR_ENABLED` around the console client and
`Universe+FoundationBridge`'s `-entityList`; #766's `keymappings_mac.plist` under
`OOLITE_MAC_COCOA_UI`. Deployment compiles.

Trap: `tests/unit/expander/test_string_expander.mm` (digests from the original expander) is not in
meson and has no build script in the tree, so it does not pin the expander.

## Verified

Not verified at `65c6efa3b5`.
