# ADR-0043 — The OXZ manager's HTTP client: `oo::http::Download` on WinHTTP

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-3rb.13, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
Implemented in `upstream/oolite/src/oofnd/Http.hpp` (`oo::http::Download`, `parseUrl`), with
`oo::fs::createFileForWriting` / `synchronizeFile` in `oofnd/FileSystem.hpp`; used by
`src/Core/OOOXZManager.{h,mm}` and drained from `-[GameController runFrameLoop]`; tested by
`tests/unit/oofnd/test_http.cpp` against its own loopback server.

## Context

The in-game expansion manager (`OOOXZManager`) was the game's only network client: an
`NSURLConnection` with an `NSMutableURLRequest` (User-Agent `Oolite/<CFBundleVersion>`, cookies
off) whose delegate callbacks the run loop delivered on the main thread, writing through an
`NSFileHandle`. Phase 2 removes gnustep-base, so the game needs an HTTP client of its own. The bead
allowed a library already in the MSYS2 environment. `pacman -Q` on the fleet machine: the UCRT64
prefix has **no libcurl** (only the MSYS-runtime `curl`/`libcurl`, which links `msys-2.0.dll` and
cannot go into a native UCRT64 binary). Installing `mingw-w64-ucrt-x86_64-curl` would be a new
download. `libwinhttp.a` ships with the toolchain and WinHTTP is part of Windows.

### Measured (gnustep-base 1.31.1, throwaway probe against a loopback server)

- Every HTTP status is a response: a 404 or 500 delivers its body and finishes; only transport
  errors (refused, reset before the response) fail.
- `expectedContentLength` is the Content-Length, or -1 without one (chunked, connection-close
  body, 204). The OXZ manager stores it in an `NSUInteger`, so -1 shows as a huge size.
- The request carries `User-Agent` and `Host` only: no `Accept-Encoding` (a gzip body is
  delivered undecoded), no cookies, no credentials from `user:password@`. The fragment is not
  sent; the query is.
- An absolute redirect is followed and only the final response is delivered. A **relative**
  redirect (`Location: /ok`) never calls back at all.
- A body cut short by the server closing the connection *finishes* with what arrived.
- A URL `+[NSURL URLWithString:]` rejects (spaces, non-ASCII, empty) gives a nil URL, and the
  connection then never calls back; so does an upper-case scheme (`HTTP://`). `file:` URLs are
  read from disk. An empty or unresolvable host connected somewhere else (a local port-80 server
  answered). `ftp:` logged stream noise and never completed.

## Decision

1. **`oo::http::Download(url, userAgent)`** (header-only oofnd) runs one GET on its own thread
   and queues `response` (status, expected length), `data`, `finished` and `failed` events. The
   owner takes them in order with `nextEvent()` on the main thread. `cancel()` (and the
   destructor, which joins the thread) stops it: nothing more is answered, even what was already
   queued, as `-[NSURLConnection cancel]` delivered nothing more.
2. **Windows backend: WinHTTP**, synchronous, no proxy (`WINHTTP_ACCESS_TYPE_NO_PROXY`, as
   GNUstep's stack used none), cookies disabled, redirects always followed, no decompression,
   60 s resolve/connect/send/receive timeouts (NSURLRequest's default interval), certificates
   verified against the Windows store (WinHTTP's default). Each read takes what has arrived
   (`WinHttpQueryDataAvailable`), so progress is reported as it comes. **Elsewhere** there is no
   backend yet: an http(s) download fails with a clear message; the Phase 5 POSIX builds get
   libcurl behind the same class. `file:` URLs are read with `oo::fs` on every platform.
3. **Delivery point:** `-[OOOXZManager processDownloadEvents]` is called by
   `-[GameController runFrameLoop]` once per pass just before it pumps the run loop, which is where
   `NSURLConnection` callbacks arrived. It re-reads the current download after every event, so a
   callback that cancels or replaces it stops the drain. The `-fireDueTimers` call in the data
   callback stays (ADR-0033): a burst of queued chunks still lets the game tick between them.
4. **The OXZ manager keeps its state machine and log lines.** `_currentDownload` is an owned
   `oo::http::Download *`; `-cancelUpdate` cancels it and leaves it set until the next download
   replaces it (as the cancelled connection was left). `_fileWriter` is a `FILE *` from
   `oo::fs::createFileForWriting` (create-empty-then-open, as `-createFileAtPath:` +
   `+fileHandleForWritingAtPath:`), synchronised with `oo::fs::synchronizeFile` on finish.
5. **The other `NSURL` users:** the SDL `-snapshotsURLCreatingIfNeeded:` (no SDL caller) is removed
   and its declaration is Mac-only; the DEBUG_GRAPHVIZ writers of `OOCache` and
   `OOPriorityQueue` write through `oo::fs::writeFile(..., atomic)` and lose their uncalled
   `-writeGraphVizToURL:`. `NSURL` stays only in Mac-only code (AppKit panels, `NSWorkspace`,
   Sparkle, the plug-in URL in `OODebugSupport`, Time Machine exclusion), which ADR-0017 does not
   build. No game code used `NSTask` or `NSPipe`.

## Consequences

- A well-formed http(s) URL behaves as before: same request headers (WinHTTP adds its own
  `Connection: Keep-Alive`), same callbacks in the same order, error statuses as bodies,
  Content-Length or -1, undecoded bodies, no cookies. The two blessed goldens do not touch the
  network and still MATCH.
- The download no longer blocks the frame loop (GNUstep's MinGW sockets were blocking, which is
  why `fireDueTimers` was added in 2014); callbacks now arrive once per frame-loop pass instead of
  mid-wait, a delay of at most one tick.
- **Deliberate differences, failure paths only:** a URL NSURL rejected, an empty host and a
  scheme other than http/https/file fail at once with `Error downloading file: unsupported URL
  "<url>"`, where the manager waited for ever (the user had to cancel); an upper-case scheme and
  a relative redirect now work; an unresolvable host fails instead of reaching an unrelated
  server. A failure's log text is WinHTTP's (`... failed: WinHTTP error 12029 (could not connect
  to the server)`) instead of `NSError`'s description. A write error on the download file is no
  longer an uncaught `NSFileHandle` exception; the short file then fails processing instead.
- `-lwinhttp` joins the Windows link line; `tools/check-oofnd.sh` links a test's
  `// oofnd-link-windows:` libraries.

## Alternatives considered

- **libcurl (UCRT64 package).** One implementation for every platform, but a new download the
  bead asked not to add silently, plus its dependency tree (OpenSSL or Schannel, nghttp2,
  libpsl, zstd, brotli) in the Windows distribution. Deferred to Phase 5, where POSIX needs it.
- **Asynchronous WinHTTP with a status callback.** No worker thread, but callbacks arrive on
  WinHTTP's pool threads anyway, so a queue is still needed; the synchronous form is shorter and
  cancellable by closing the request handle.
- **Reproducing the hangs** (never calling back for a rejected URL or a relative redirect).
  Faithful, but it reproduces a defect whose only visible effect is a download screen stuck at
  zero until the player cancels.
