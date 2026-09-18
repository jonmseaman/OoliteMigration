#!/usr/bin/env python3
"""OXP corpus fetcher/cache (bead oo-425).

Downloads every expansion listed in upstream/oolite-expansion-catalog/expansionUrls.txt
into a content cache that lives OUTSIDE the repository, and records per-entry
provenance (url, final url, http status, byte size, sha256, fetch time) in a JSON
manifest that IS committed.

Why the cache is outside the repo: the corpus is hundreds of multi-megabyte OXZ
archives (one sampled entry alone is 82 MB).  Git is the wrong store for that.
The manifest + checksums are what make the cache reproducible and auditable, so
those are versioned and the bytes are not.  Override the location with the
environment variable OXP_CACHE_DIR; the default is
%LOCALAPPDATA%/OoliteMigration/oxp-cache (or ~/.cache/oolite-migration/oxp-cache).

The fetcher is RESUMABLE: an entry already present in the manifest whose cached
blob still verifies against its recorded size and sha256 is skipped without any
network traffic at all.  A partial run therefore costs nothing on the next run.

This module never opens, unzips or otherwise reads the CONTENT of an expansion.
It treats every download as opaque bytes (that restriction is a repo rule).

Usage:
    python3 tools/oxp_corpus.py fetch   [--manifest P] [--cache-dir D] [--limit N]
    python3 tools/oxp_corpus.py verify  [--manifest P] [--cache-dir D]
    python3 tools/oxp_corpus.py probe   [--limit N]      # HEAD only, no bodies
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG = REPO_ROOT / "upstream" / "oolite-expansion-catalog" / "expansionUrls.txt"
MANIFEST = REPO_ROOT / "tools" / "oxp-corpus" / "manifest.json"

USER_AGENT = (
    "OoliteMigration-oxp-corpus/1.0 (+bead oo-425; "
    "Oolite ObjC->C++ migration corpus fetcher; one request at a time)"
)
#: seconds to wait between two network requests to the same run (be a good citizen)
RATE_LIMIT_SECONDS = 1.0
#: the documented checksum form: lowercase hex sha256
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

MANIFEST_VERSION = 1


# --------------------------------------------------------------------------- catalog


def load_catalog(path: os.PathLike | str = CATALOG) -> list[str]:
    """Return the unique expansion URLs from the catalog, in first-seen order.

    Catalog rules (upstream/oolite-expansion-catalog/README.md): one URL per line,
    '#' lines are comments, blank/whitespace lines are ignored.
    """
    seen: set[str] = set()
    urls: list[str] = []
    for raw in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            continue
        seen.add(line)
        urls.append(line)
    return urls


# ----------------------------------------------------------------------------- cache


def default_cache_dir() -> Path:
    env = os.environ.get("OXP_CACHE_DIR")
    if env:
        return Path(env)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return Path(local) / "OoliteMigration" / "oxp-cache"
    return Path.home() / ".cache" / "oolite-migration" / "oxp-cache"


def cache_key(url: str) -> str:
    """Stable, filesystem-safe cache key for a URL (its sha256, hex)."""
    return hashlib.sha256(url.encode("utf-8")).hexdigest()


def blob_path(cache_dir: os.PathLike | str, url: str) -> Path:
    key = cache_key(url)
    return Path(cache_dir) / key[:2] / key


def sha256_file(path: os.PathLike | str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# -------------------------------------------------------------------------- manifest


def load_manifest(path: os.PathLike | str = MANIFEST) -> dict:
    p = Path(path)
    if not p.exists():
        return {"version": MANIFEST_VERSION, "entries": {}}
    data = json.loads(p.read_text(encoding="utf-8"))
    if "entries" not in data:
        raise ValueError(f"{p}: manifest has no 'entries' object")
    return data


def save_manifest(manifest: dict, path: os.PathLike | str = MANIFEST) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(
        json.dumps(manifest, indent=1, sort_keys=True) + "\n", encoding="utf-8"
    )
    tmp.replace(p)


def check_manifest_schema(manifest: dict) -> list[str]:
    """Return a list of human-readable schema problems ([] when the manifest is well formed).

    Every successfully-fetched entry must carry a url, a byte size and a checksum
    of the documented form (lowercase hex sha256).
    """
    problems: list[str] = []
    entries = manifest.get("entries")
    if not isinstance(entries, dict):
        return ["manifest 'entries' is not an object"]
    for url, e in entries.items():
        if not isinstance(e, dict):
            problems.append(f"{url}: entry is not an object")
            continue
        if e.get("url") != url:
            problems.append(f"{url}: entry 'url' field is {e.get('url')!r}, not its own key")
        status = e.get("status")
        if status not in ("ok", "error"):
            problems.append(f"{url}: status {status!r} is neither 'ok' nor 'error'")
        if status != "ok":
            if not e.get("error"):
                problems.append(f"{url}: status 'error' but no 'error' text")
            continue
        sha = e.get("sha256")
        if not isinstance(sha, str) or not SHA256_RE.match(sha):
            problems.append(
                f"{url}: sha256 {sha!r} is not a 64-character lowercase hex digest"
            )
        size = e.get("size")
        if not isinstance(size, int) or size < 0:
            problems.append(f"{url}: size {size!r} is not a non-negative integer")
        if not e.get("fetched_at"):
            problems.append(f"{url}: no 'fetched_at' provenance timestamp")
    return problems


def verify_entry(entry: dict, cache_dir: os.PathLike | str) -> tuple[bool, str]:
    """Verify one cached blob against its recorded size and checksum.

    Returns (ok, reason).  reason names the concrete failure when ok is False.
    """
    url = entry.get("url", "<no url>")
    if entry.get("status") != "ok":
        return False, f"{url}: entry status is {entry.get('status')!r}, not 'ok'"
    path = blob_path(cache_dir, url)
    if not path.exists():
        return False, f"{url}: cached blob MISSING at {path}"
    actual_size = path.stat().st_size
    if actual_size != entry.get("size"):
        return (
            False,
            f"{url}: cache CORRUPT - size {actual_size} != manifest size {entry.get('size')}",
        )
    actual_sha = sha256_file(path)
    if actual_sha != entry.get("sha256"):
        return (
            False,
            f"{url}: cache CORRUPT - sha256 {actual_sha} != manifest sha256 {entry.get('sha256')}",
        )
    return True, "ok"


def verify_all(manifest: dict, cache_dir: os.PathLike | str) -> list[str]:
    """Verify every 'ok' entry; return the list of failure reasons ([] when all good)."""
    bad: list[str] = []
    for entry in manifest.get("entries", {}).values():
        if entry.get("status") != "ok":
            continue
        ok, reason = verify_entry(entry, cache_dir)
        if not ok:
            bad.append(reason)
    return bad


# --------------------------------------------------------------------------- fetching


class RecordingOpener:
    """Testing aid: an `opener` that records every attempted URL and serves none.

    `fetch_all` deliberately RECORDS a failed transfer instead of aborting the run
    (a 404 in the middle of 818 URLs must not throw away the other 817), so an
    opener that raises cannot be observed by catching an exception - the list of
    attempted URLs is the observable.  Pass an instance as `opener` and assert on
    `.attempts` to prove whether a run reached for the network at all.
    """

    def __init__(self) -> None:
        self.attempts: list[str] = []

    def __call__(self, req, timeout=None):
        self.attempts.append(getattr(req, "full_url", req))
        raise OSError("RecordingOpener: network access is not available in this run")


class KeepAliveOpener:
    """A urlopen-compatible opener that reuses ONE connection per host.

    Why this exists: the catalog is 811/818 URLs on a single volunteer-run wiki.
    Throughput must come from HTTP keep-alive on a SINGLE serial connection, never
    from running several fetchers at once - a per-process delay cannot see the
    other processes, so sharding by process silently multiplies the request rate
    against that host by the shard count.  This class keeps the fetch serial while
    avoiding a fresh TCP+TLS handshake for every one of the 818 requests.

    It also honours 429/503 `Retry-After` with a bounded backoff instead of
    retrying blind, and follows redirects explicitly so `final_url` is real.
    """

    def __init__(self, *, sleep=time.sleep, max_retries: int = 3, max_backoff: float = 60.0):
        self._conns: dict[tuple[str, str], object] = {}
        self._sleep = sleep
        self.max_retries = max_retries
        self.max_backoff = max_backoff
        #: per-host count of requests actually put on the wire (for rate reporting)
        self.requests_per_host: dict[str, int] = {}

    # -- connection management -------------------------------------------------
    def _connection(self, parts):
        import http.client

        key = (parts.scheme, parts.netloc)
        conn = self._conns.get(key)
        if conn is None:
            cls = http.client.HTTPSConnection if parts.scheme == "https" else http.client.HTTPConnection
            conn = cls(parts.netloc, timeout=120)
            self._conns[key] = conn
        return conn

    def _drop(self, parts) -> None:
        conn = self._conns.pop((parts.scheme, parts.netloc), None)
        if conn is not None:
            try:
                conn.close()
            except Exception:  # noqa: BLE001
                pass

    def close(self) -> None:
        for key in list(self._conns):
            conn = self._conns.pop(key)
            try:
                conn.close()
            except Exception:  # noqa: BLE001
                pass

    # -- the urlopen-compatible entry point -----------------------------------
    def __call__(self, req, timeout=None):
        import urllib.parse

        url = getattr(req, "full_url", req)
        headers = dict(getattr(req, "headers", {}) or {})
        headers.setdefault("User-Agent", USER_AGENT)
        headers["Connection"] = "keep-alive"
        method = getattr(req, "method", None) or "GET"
        return self._request(url, method, headers, redirects_left=5, attempt=0)

    def _request(self, url, method, headers, *, redirects_left, attempt):
        import urllib.parse

        parts = urllib.parse.urlsplit(url)
        target = urllib.parse.urlunsplit(("", "", parts.path or "/", parts.query, ""))
        conn = self._connection(parts)
        self.requests_per_host[parts.netloc] = self.requests_per_host.get(parts.netloc, 0) + 1
        try:
            conn.request(method, target, headers=headers)
            resp = conn.getresponse()
        except Exception:
            # A pooled connection the server already closed: rebuild it once.
            self._drop(parts)
            if attempt >= 1:
                raise
            return self._request(
                url, method, headers, redirects_left=redirects_left, attempt=attempt + 1
            )

        if resp.status in (301, 302, 303, 307, 308):
            location = resp.getheader("Location")
            resp.read()
            if not location or redirects_left <= 0:
                raise urllib.error.HTTPError(
                    url, resp.status, "redirect without a usable Location", resp.headers, None
                )
            return self._request(
                urllib.parse.urljoin(url, location),
                method,
                headers,
                redirects_left=redirects_left - 1,
                attempt=0,
            )

        if resp.status in (429, 503):
            delay = self._retry_after(resp.getheader("Retry-After"), attempt)
            resp.read()
            if attempt >= self.max_retries:
                raise urllib.error.HTTPError(
                    url,
                    resp.status,
                    f"still throttled after {attempt} backoffs",
                    resp.headers,
                    None,
                )
            self._sleep(delay)
            return self._request(
                url, method, headers, redirects_left=redirects_left, attempt=attempt + 1
            )

        if resp.status >= 400:
            resp.read()
            raise urllib.error.HTTPError(url, resp.status, resp.reason, resp.headers, None)

        return _PooledResponse(resp, url)

    def _retry_after(self, header, attempt) -> float:
        """Honour an explicit Retry-After; otherwise exponential backoff."""
        if header:
            try:
                return min(float(header.strip()), self.max_backoff)
            except ValueError:
                pass  # HTTP-date form: fall through to the backoff schedule
        return min(2.0 ** attempt * 5.0, self.max_backoff)


class _PooledResponse:
    """Minimal read/geturl/context-manager wrapper over an http.client response."""

    def __init__(self, resp, url):
        self._resp = resp
        self._url = url
        self.status = resp.status
        self.headers = resp.headers

    def read(self, n=-1):
        return self._resp.read() if n in (-1, None) else self._resp.read(n)

    def geturl(self):
        return self._url

    def getcode(self):
        return self.status

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self._resp.read()  # drain so the connection stays reusable
        return False


class FetchStats:
    def __init__(self) -> None:
        self.downloaded = 0
        self.skipped = 0
        self.failed = 0

    def __str__(self) -> str:
        return (
            f"downloaded={self.downloaded} skipped={self.skipped} failed={self.failed}"
        )


def _download(url: str, dest: Path, opener=None) -> dict:
    """Fetch one URL to dest atomically.  Returns the provenance record."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    open_url = opener or urllib.request.urlopen
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".part")
    h = hashlib.sha256()
    size = 0
    with open_url(req, timeout=120) as resp, open(tmp, "wb") as out:
        final_url = resp.geturl()
        status = getattr(resp, "status", None) or resp.getcode()
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
            h.update(chunk)
            size += len(chunk)
    tmp.replace(dest)  # atomic: a killed run never leaves a truncated blob in place
    return {
        "url": url,
        "status": "ok",
        "http_status": status,
        "final_url": final_url,
        "size": size,
        "sha256": h.hexdigest(),
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cache_key": cache_key(url),
    }


def fetch_all(
    urls,
    cache_dir,
    manifest,
    *,
    opener=None,
    rate_limit=RATE_LIMIT_SECONDS,
    sleep=time.sleep,
    log=lambda msg: None,
    save=None,
) -> FetchStats:
    """Fetch every URL that is not already cached-and-verified.  Resumable + idempotent.

    An entry whose manifest record still verifies is SKIPPED with no network call,
    so a second run over a populated cache downloads nothing.  Pass `opener` to
    substitute the network (tests pass one that raises).
    """
    stats = FetchStats()
    entries = manifest.setdefault("entries", {})
    cache_dir = Path(cache_dir)
    first = True
    for url in urls:
        existing = entries.get(url)
        if existing is not None and existing.get("status") == "ok":
            ok, _reason = verify_entry(existing, cache_dir)
            if ok:
                stats.skipped += 1
                continue
        if not first and rate_limit:
            sleep(rate_limit)
        first = False
        try:
            record = _download(url, blob_path(cache_dir, url), opener=opener)
            entries[url] = record
            stats.downloaded += 1
            log(f"ok    {record['size']:>10}  {record['sha256'][:12]}  {url}")
        except urllib.error.HTTPError as exc:  # 404 and friends: recorded, not fatal
            entries[url] = _error_record(url, f"HTTP {exc.code} {exc.reason}")
            stats.failed += 1
            log(f"HTTP{exc.code:<4}                              {url}")
        except Exception as exc:  # noqa: BLE001 - network is hostile; record and move on
            entries[url] = _error_record(url, f"{type(exc).__name__}: {exc}")
            stats.failed += 1
            log(f"fail                                     {url}  ({exc})")
        if save is not None and (stats.downloaded + stats.failed) % 10 == 0:
            save(manifest)
    return stats


def _error_record(url: str, error: str) -> dict:
    return {
        "url": url,
        "status": "error",
        "error": error,
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cache_key": cache_key(url),
    }


# -------------------------------------------------------------------------------- cli


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("command", choices=("fetch", "verify", "probe"))
    ap.add_argument("--catalog", default=str(CATALOG))
    ap.add_argument("--manifest", default=str(MANIFEST))
    ap.add_argument("--cache-dir", default=None)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--rate-limit", type=float, default=RATE_LIMIT_SECONDS)
    args = ap.parse_args(argv)

    cache_dir = Path(args.cache_dir) if args.cache_dir else default_cache_dir()
    urls = load_catalog(args.catalog)
    if args.limit:
        urls = urls[: args.limit]

    if args.command == "verify":
        manifest = load_manifest(args.manifest)
        problems = check_manifest_schema(manifest)
        bad = verify_all(manifest, cache_dir)
        for p in problems + bad:
            print("FAIL " + p)
        n_ok = sum(
            1 for e in manifest["entries"].values() if e.get("status") == "ok"
        )
        print(f"verified {n_ok - len(bad)}/{n_ok} ok entries against {cache_dir}")
        return 1 if (problems or bad) else 0

    if args.command == "probe":
        for url in urls:
            req = urllib.request.Request(
                url, headers={"User-Agent": USER_AGENT}, method="HEAD"
            )
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    print(f"{r.status}\t{r.headers.get('Content-Length','?')}\t{url}")
            except Exception as exc:  # noqa: BLE001
                print(f"ERR\t{type(exc).__name__}\t{url}")
            time.sleep(args.rate_limit)
        return 0

    manifest = load_manifest(args.manifest)
    print(f"catalog: {len(urls)} unique URLs\ncache:   {cache_dir}\nmanifest:{args.manifest}")
    net = KeepAliveOpener()
    started = time.time()
    try:
        stats = fetch_all(
            urls,
            cache_dir,
            manifest,
            opener=net,
            rate_limit=args.rate_limit,
            log=lambda m: print(m, flush=True),
            save=lambda m: save_manifest(m, args.manifest),
        )
    finally:
        net.close()
        save_manifest(manifest, args.manifest)
    elapsed = max(time.time() - started, 1e-9)
    print(f"done: {stats} in {elapsed:.0f}s")
    for host, n in sorted(net.requests_per_host.items()):
        print(f"  rate: {host}: {n} requests, {n / elapsed:.3f} req/s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
