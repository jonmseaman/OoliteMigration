# Fetch http(s) with libcurl on every platform

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 25/28.

## What this changes

- `src/oofnd/Http.hpp`: `oo::http::Download` uses libcurl on every platform, replacing the
  Windows-only WinHTTP backend. Contract unchanged: only `User-Agent`/`Host` sent, up to 20 http(s)
  redirects, 60 s timeouts, `cancel()` ends stalled transfers. `file:` URLs still bypass libcurl.
- Build: `dependency('libcurl')` in `oofnd_dep`, `winhttp` dropped; Linux package scripts install
  the libcurl dev package (MSYS2 and the macOS SDK already have it).
- `tests/unit/oofnd/test_http.cpp`: the loopback server also runs on BSD sockets, so the HTTP
  tests run everywhere; its accept loop waits in 20 ms `select()` slices.
- `src/oofnd/README.md`'s `Http.hpp` row says libcurl.

## Why

On macOS and Linux every OXZ manager download failed, and libcurl serves every platform with one
backend.

## Behaviour changes

- macOS/Linux: http(s) downloads work, so the OXZ manager fetches its list and expansions (was
  "no HTTP client in this build"). Pinned by `test_http` (status, length, header, redirect,
  cut-short body, cancel), now run there.
- Windows: downloads go through libcurl with the same contract; a failure's text is libcurl's,
  `libcurl error N (...)` (was WinHTTP's). Pinned by `refused_connection_fails`.
- Windows HTTPS trusts the Windows certificate store, as WinHTTP did. Not pinned (the loopback
  server is plain HTTP).
- `file:///C:/...` on Windows still reads `C:/...`. Pinned by `parse_file_urls` and
  `file_url_delivers_the_file`.

## How to review

Read `Http.hpp` from `class Download` down: `runCurl()` sets the contract's options, `onHeader()`
picks the response block (skipping informational statuses and followed redirects), `onData()`
chunks the body, `onProgress()` honours `cancel()`. `parseUrl()` gains only the drive-letter case.
Not verified: an installed Windows build needs MSYS2's `libcurl-4.dll` and its dependencies
beside the game; packaging is unchanged here.

Test edits:
- `test_http.cpp`: socket portability; refused-connection test expects `libcurl error 7` (was
  WinHTTP 12029). Other assertions unchanged.
- `tests/unit/oofnd/meson.build`: drops `winhttp`.

## Test changes

Existing test files changed (ledger `test-changes.md`):

- `tests/unit/oofnd/meson.build`
- `tests/unit/oofnd/test_http.cpp`

## Verified

Not verified yet.
