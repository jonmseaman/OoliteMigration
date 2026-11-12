# Fetch http(s) with libcurl on every platform

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 25 of 28, stacked on upstream #768's branch, so not independent of #767 and #768.

## What this changes

- **`src/oofnd/Http.hpp`.** `oo::http::Download` fetches http(s) URLs with libcurl on every
  platform, in place of its WinHTTP backend, which was Windows-only. Elsewhere every http(s)
  download failed with "no HTTP client in this build". The header's contract is unchanged:
  one GET on its own thread, its response/data/finish/failure events taken in order on the
  main thread; every status is a response; `Content-Length` or -1; only `User-Agent` and `Host`
  are sent (libcurl's `Accept:` is removed, and no cookies, `Accept-Encoding` or credentials go
  out); the fragment is not sent; redirects are followed (up to 20, http and https only) and only
  the final response is delivered; a body cut short by the server finishes with what arrived.
  Timeouts are `NSURLRequest`'s 60 seconds, to connect and without a byte. `cancel()` also ends a
  stalled transfer, through libcurl's progress callback. On Windows libcurl trusts the Windows
  certificate store (`CURLSSLOPT_NATIVE_CA`). `file:` URLs are still read from disk without
  libcurl, and on Windows `file:///C:/dir/file` names `C:/dir/file`. A failure's text is
  libcurl's (`request failed: libcurl error N (...)`).
- **Build.** `src/oofnd/meson.build` adds `dependency('libcurl')` to `oofnd_dep`;
  `src/meson/windows/meson.build` and `tests/unit/oofnd/meson.build` drop `winhttp`. The Linux
  package scripts install the libcurl development package (`curl-dev`: `libcurl4-openssl-dev`,
  `libcurl-devel`, `curl`). MSYS2's `curl` is already in the Windows dependencies, and the macOS
  SDK ships libcurl.
- **`tests/unit/oofnd/test_http.cpp`.** The loopback server runs on BSD sockets as well as
  winsock, so the HTTP tests run on every platform rather than on Windows only. Its accept loop
  waits in 20 ms `select()` slices, since closing a listening socket does not wake `accept()`
  everywhere. The refused-connection test looks for `libcurl error 7` (could not connect) where
  it looked for WinHTTP's error 12029.
- `src/oofnd/README.md`'s `Http.hpp` row says libcurl.

## Why

On macOS and Linux the OXZ manager's downloads all failed, so the expansion list never updated.
libcurl is on every platform the game builds on (MSYS2, the macOS SDK, the Linux distributions'
packages), so one backend serves them all instead of a native client per platform.

## Behaviour changes

- macOS and Linux: http(s) downloads work, so the OXZ manager can fetch its list and
  expansions. Pinned by `test_http`, which now runs on those platforms: the status, length,
  header, redirect, cut-short body and cancel cases against its loopback server.
- Windows: downloads go through libcurl instead of WinHTTP, with the same contract. A failure's
  message is libcurl's text instead of WinHTTP's; `refused_connection_fails` pins the
  could-not-connect case. HTTPS trusts the Windows certificate store, as WinHTTP did. Not
  pinned by a test (the loopback server is plain HTTP).
- `file:///C:/...` URLs on Windows read `C:/...`, as before. Pinned by `test_http`'s
  `parse_file_urls` and `file_url_delivers_the_file`.

## How to review

Read `src/oofnd/Http.hpp` from `class Download` down: `runCurl()` sets the options that carry the
contract, `onHeader()` decides which header block is the response (not an informational status,
nor a redirect that is followed), `onData()` splits the body into chunks, and `onProgress()`
honours `cancel()`. `parseUrl()` gains only the Windows drive-letter case. The test's changes are
the socket portability and the one error string; its other assertions are unchanged. Windows
packaging is not changed here: an installed build needs MSYS2's `libcurl-4.dll` and its
dependencies next to the game, and this series does not verify that.

## Test changes

Existing test files this step changes (test ledger: `test-changes.md`):

- `tests/unit/oofnd/meson.build`
- `tests/unit/oofnd/test_http.cpp`

## Verified **(gen)**

Not verified yet.
