#!/usr/bin/env python3
"""Offline tests for the OXP corpus fetcher/cache (bead oo-425).

Every test here runs WITHOUT NETWORK ACCESS.  818 remote URLs cannot be re-fetched
inside an acceptance gate: it would be slow, flaky, and would go red whenever a
remote host is down, which is not evidence about this code.  What is testable
offline - and what actually matters - is the CACHE CONTRACT:

  * the catalog parses to exactly the documented set of unique URLs;
  * every manifest entry carries a URL, a byte size and a checksum of the
    documented form (64-char lowercase hex sha256) plus a fetch timestamp;
  * the verifier DETECTS a corrupted cache entry (proved against a committed
    fixture whose blob was corrupted after its checksum was recorded, with the
    size preserved so only the checksum can catch it);
  * re-running the fetcher over an already-populated cache downloads NOTHING,
    and - so that claim is not vacuous - it DOES reach for the network the
    moment a cached blob goes missing or stops verifying.

Run:  python3 -m pytest tools/test_oxp_corpus.py -q
"""
from __future__ import annotations

import importlib.util
import json
import shutil
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent
REPO_ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("oxp_corpus", TOOLS / "oxp_corpus.py")
oc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oc)

FIXTURE = TOOLS / "oxp-corpus" / "fixtures"
FIXTURE_MANIFEST = FIXTURE / "manifest.json"
FIXTURE_CACHE = FIXTURE / "cache"
REAL_MANIFEST = TOOLS / "oxp-corpus" / "manifest.json"

GOOD_URL = "https://example.invalid/fixtures/Good_Expansion_1.0.oxz"
CORRUPT_URL = "https://example.invalid/fixtures/Corrupt_Expansion_1.0.oxz"
MISSING_URL = "https://example.invalid/fixtures/Missing_Expansion_1.0.oxz"

#: the catalog size this bead was scoped against (upstream/oolite-expansion-catalog)
EXPECTED_UNIQUE_URLS = 818


class RecordingOpener(oc.RecordingOpener):
    """See oxp_corpus.RecordingOpener - re-exported so the tests read locally."""


# ------------------------------------------------------------------ catalog parsing


def test_catalog_parses_to_the_documented_unique_url_count():
    urls = oc.load_catalog()
    assert len(urls) == EXPECTED_UNIQUE_URLS, (
        f"catalog yields {len(urls)} unique URLs, expected {EXPECTED_UNIQUE_URLS}"
    )
    assert len(set(urls)) == len(urls), "load_catalog returned duplicates"
    bad = [u for u in urls if not u.startswith(("http://", "https://"))]
    assert not bad, f"non-http entries survived catalog parsing: {bad[:3]}"
    assert not [u for u in urls if u.startswith("#")], "comment lines survived parsing"


def test_catalog_parser_drops_comments_blanks_and_duplicates(tmp_path):
    p = tmp_path / "expansionUrls.txt"
    p.write_text(
        "# a comment\n"
        "\n"
        "   \n"
        "https://example.invalid/a.oxz\n"
        "https://example.invalid/b.oxz\n"
        "https://example.invalid/a.oxz\n"
        "# https://example.invalid/commented-out.oxz\n",
        encoding="utf-8",
    )
    assert oc.load_catalog(p) == [
        "https://example.invalid/a.oxz",
        "https://example.invalid/b.oxz",
    ]


# ----------------------------------------------------------------- manifest schema


def test_fixture_manifest_passes_the_schema_check():
    manifest = oc.load_manifest(FIXTURE_MANIFEST)
    assert oc.check_manifest_schema(manifest) == []


@pytest.mark.parametrize(
    "mutation,needle",
    [
        ({"sha256": "NOTAHEXDIGEST"}, "not a 64-character lowercase hex digest"),
        ({"sha256": "ABCD" * 16}, "not a 64-character lowercase hex digest"),
        ({"size": "12"}, "is not a non-negative integer"),
        ({"fetched_at": ""}, "no 'fetched_at' provenance timestamp"),
    ],
)
def test_schema_check_rejects_a_malformed_entry(mutation, needle):
    manifest = json.loads(FIXTURE_MANIFEST.read_text(encoding="utf-8"))
    manifest["entries"][GOOD_URL].update(mutation)
    problems = oc.check_manifest_schema(manifest)
    assert any(needle in p for p in problems), (
        f"schema check did not reject {mutation}; problems={problems}"
    )


def test_schema_check_rejects_a_dropped_checksum():
    manifest = json.loads(FIXTURE_MANIFEST.read_text(encoding="utf-8"))
    del manifest["entries"][GOOD_URL]["sha256"]
    assert oc.check_manifest_schema(manifest), "an entry with NO checksum was accepted"


# ------------------------------------------------------- checksum verification


def test_verifier_accepts_an_intact_cache_entry():
    manifest = oc.load_manifest(FIXTURE_MANIFEST)
    ok, reason = oc.verify_entry(manifest["entries"][GOOD_URL], FIXTURE_CACHE)
    assert ok, reason


def test_verifier_detects_the_corrupted_fixture_entry():
    """The committed corrupt fixture differs by ONE BYTE at the SAME LENGTH.

    A size-only check passes it; only the sha256 comparison catches it.
    """
    manifest = oc.load_manifest(FIXTURE_MANIFEST)
    entry = manifest["entries"][CORRUPT_URL]
    on_disk = oc.blob_path(FIXTURE_CACHE, CORRUPT_URL)
    assert on_disk.stat().st_size == entry["size"], (
        "the corrupt fixture no longer has the manifest's size, so this test would "
        "pass for the wrong reason (size mismatch instead of checksum mismatch)"
    )
    ok, reason = oc.verify_entry(entry, FIXTURE_CACHE)
    assert not ok, "the verifier ACCEPTED a cache blob that does not match its sha256"
    assert "sha256" in reason and "CORRUPT" in reason, reason


def test_verifier_detects_a_missing_cache_entry():
    manifest = oc.load_manifest(FIXTURE_MANIFEST)
    ok, reason = oc.verify_entry(manifest["entries"][MISSING_URL], FIXTURE_CACHE)
    assert not ok and "MISSING" in reason, reason


def test_verify_all_reports_exactly_the_two_broken_fixture_entries():
    manifest = oc.load_manifest(FIXTURE_MANIFEST)
    bad = oc.verify_all(manifest, FIXTURE_CACHE)
    assert len(bad) == 2, f"expected 2 broken entries, got {len(bad)}: {bad}"
    assert any(CORRUPT_URL in b for b in bad) and any(MISSING_URL in b for b in bad), bad


# ----------------------------------------------------- resumability / idempotence


def _populated(tmp_path):
    """A private copy of the fixture whose two broken entries have been made good."""
    cache = tmp_path / "cache"
    shutil.copytree(FIXTURE_CACHE, cache)
    manifest = json.loads(FIXTURE_MANIFEST.read_text(encoding="utf-8"))
    for url in (CORRUPT_URL, MISSING_URL):
        del manifest["entries"][url]
    return cache, manifest


def test_second_run_over_a_populated_cache_downloads_nothing(tmp_path):
    cache, manifest = _populated(tmp_path)
    net = RecordingOpener()
    stats = oc.fetch_all([GOOD_URL], cache, manifest, opener=net, rate_limit=0)
    assert net.attempts == [], (
        f"a second run over a populated cache touched the network: {net.attempts}"
    )
    assert (stats.downloaded, stats.failed) == (0, 0), str(stats)
    assert stats.skipped == 1, str(stats)


def test_a_missing_blob_makes_the_fetcher_reach_for_the_network(tmp_path):
    """Guards the previous test against becoming vacuous.

    If `fetch_all` skipped unconditionally, the no-op test would pass while the
    fetcher was in fact broken.  Deleting the cached blob must make it try.
    """
    cache, manifest = _populated(tmp_path)
    oc.blob_path(cache, GOOD_URL).unlink()
    net = RecordingOpener()
    stats = oc.fetch_all([GOOD_URL], cache, manifest, opener=net, rate_limit=0)
    assert net.attempts == [GOOD_URL], (
        "the fetcher SKIPPED an entry whose cached blob is gone; attempts="
        f"{net.attempts}"
    )
    assert stats.skipped == 0, str(stats)


def test_a_corrupted_blob_makes_the_fetcher_re_download(tmp_path):
    cache, manifest = _populated(tmp_path)
    blob = oc.blob_path(cache, GOOD_URL)
    data = bytearray(blob.read_bytes())
    data[0] ^= 0xFF  # same length, different content
    blob.write_bytes(bytes(data))
    net = RecordingOpener()
    oc.fetch_all([GOOD_URL], cache, manifest, opener=net, rate_limit=0)
    assert net.attempts == [GOOD_URL], (
        "the fetcher SKIPPED an entry whose cached blob no longer matches its "
        f"recorded sha256; attempts={net.attempts}"
    )


def test_an_unfetched_url_makes_the_fetcher_reach_for_the_network(tmp_path):
    cache, manifest = _populated(tmp_path)
    fresh = "https://example.invalid/fixtures/Never_Seen.oxz"
    net = RecordingOpener()
    oc.fetch_all([fresh], cache, manifest, opener=net, rate_limit=0)
    assert net.attempts == [fresh], (
        f"a URL with no manifest entry was not fetched; attempts={net.attempts}"
    )


# ------------------------------------------------- error handling and provenance


class _FakeResponse:
    def __init__(self, data: bytes, url: str, status: int = 200):
        self._data = data
        self._url = url
        self.status = status
        self._pos = 0

    def read(self, n=-1):
        chunk = self._data[self._pos:] if n in (-1, None) else self._data[self._pos:self._pos + n]
        self._pos += len(chunk)
        return chunk

    def geturl(self):
        return self._url

    def getcode(self):
        return self.status

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def test_a_download_records_full_provenance_and_verifies(tmp_path):
    payload = b"synthetic expansion bytes\n" * 4
    url = "https://example.invalid/fixtures/New_Expansion_2.0.oxz"
    final = url + "?redirected=1"
    manifest = {"version": oc.MANIFEST_VERSION, "entries": {}}
    stats = oc.fetch_all(
        [url],
        tmp_path / "cache",
        manifest,
        opener=lambda req, timeout=None: _FakeResponse(payload, final),
        rate_limit=0,
    )
    assert stats.downloaded == 1, str(stats)
    entry = manifest["entries"][url]
    assert entry["size"] == len(payload)
    assert oc.SHA256_RE.match(entry["sha256"])
    assert entry["final_url"] == final, "the redirect target was not recorded"
    assert entry["fetched_at"].endswith("Z")
    assert oc.check_manifest_schema(manifest) == []
    ok, reason = oc.verify_entry(entry, tmp_path / "cache")
    assert ok, reason
    # and now it is a no-op
    stats2 = oc.fetch_all(
        [url], tmp_path / "cache", manifest, opener=RecordingOpener(), rate_limit=0
    )
    assert (stats2.downloaded, stats2.skipped) == (0, 1), str(stats2)


def test_a_404_is_recorded_as_an_error_entry_and_does_not_abort_the_run(tmp_path):
    import urllib.error

    bad = "https://example.invalid/fixtures/Gone.oxz"
    good = "https://example.invalid/fixtures/Present.oxz"
    payload = b"present\n"

    def opener(req, timeout=None):
        if req.full_url == bad:
            raise urllib.error.HTTPError(bad, 404, "Not Found", {}, None)
        return _FakeResponse(payload, good)

    manifest = {"version": oc.MANIFEST_VERSION, "entries": {}}
    stats = oc.fetch_all([bad, good], tmp_path / "c", manifest, opener=opener, rate_limit=0)
    assert (stats.downloaded, stats.failed) == (1, 1), str(stats)
    assert manifest["entries"][bad]["status"] == "error"
    assert "404" in manifest["entries"][bad]["error"]
    assert manifest["entries"][good]["status"] == "ok"
    assert oc.check_manifest_schema(manifest) == []


def test_a_failed_download_leaves_no_blob_at_the_cache_path(tmp_path):
    """A killed or failed transfer must not leave a truncated blob that later verifies."""
    url = "https://example.invalid/fixtures/Truncated.oxz"

    class _Exploding(_FakeResponse):
        def read(self, n=-1):
            raise OSError("connection reset mid-transfer")

    manifest = {"version": oc.MANIFEST_VERSION, "entries": {}}
    oc.fetch_all(
        [url],
        tmp_path / "c",
        manifest,
        opener=lambda req, timeout=None: _Exploding(b"", url),
        rate_limit=0,
    )
    assert not oc.blob_path(tmp_path / "c", url).exists(), (
        "a failed transfer left a blob at the final cache path"
    )
    assert manifest["entries"][url]["status"] == "error"


def test_the_fetcher_identifies_itself_and_rate_limits():
    assert "oo-425" in oc.USER_AGENT and "OoliteMigration" in oc.USER_AGENT
    assert oc.RATE_LIMIT_SECONDS > 0


# ------------------------------------------------------- politeness to the origin


class _FakeConn:
    """Scripted http.client-like connection used to exercise KeepAliveOpener offline."""

    instances: list["_FakeConn"] = []

    def __init__(self, netloc, timeout=None):
        self.netloc = netloc
        self.requests: list[tuple[str, str]] = []
        self.script: list = []
        self.closed = False
        _FakeConn.instances.append(self)

    def request(self, method, target, headers=None):
        self.requests.append((method, target))
        self.headers = headers or {}

    def getresponse(self):
        return self.script.pop(0)

    def close(self):
        self.closed = True


class _FakeHTTPResponse:
    def __init__(self, status, body=b"", headers=None, reason="OK"):
        self.status = status
        self.reason = reason
        self._body = body
        self.headers = headers or {}

    def read(self, n=-1):
        b, self._body = self._body, b""
        return b

    def getheader(self, name, default=None):
        for k, v in self.headers.items():
            if k.lower() == name.lower():
                return v
        return default


@pytest.fixture
def fake_http(monkeypatch):
    import http.client

    _FakeConn.instances = []
    monkeypatch.setattr(http.client, "HTTPSConnection", _FakeConn)
    monkeypatch.setattr(http.client, "HTTPConnection", _FakeConn)
    return _FakeConn


def test_keepalive_opener_reuses_one_connection_per_host(fake_http):
    """Throughput must come from keep-alive on ONE connection, never from more processes."""
    net = oc.KeepAliveOpener()
    conn = _FakeConn("wiki.example.invalid")
    fake_http.instances = [conn]  # the only connection that may ever exist
    net._conns[("https", "wiki.example.invalid")] = conn
    conn.script = [_FakeHTTPResponse(200, b"body") for _ in range(4)]
    for i in range(4):
        net(oc.urllib.request.Request(f"https://wiki.example.invalid/a/{i}.oxz")).read()
    assert len(fake_http.instances) == 1, (
        f"{len(fake_http.instances)} connections opened for one host; keep-alive is not "
        "being used, which means one TCP+TLS handshake per request"
    )
    assert net.requests_per_host["wiki.example.invalid"] == 4, net.requests_per_host
    assert len(conn.requests) == 4, conn.requests


def test_keepalive_opener_creates_one_connection_per_distinct_host(fake_http):
    """A pool keyed by host: alioth and a different origin must not share a socket."""
    net = oc.KeepAliveOpener()
    for host in ("a.example.invalid", "b.example.invalid"):
        conn = _FakeConn(host)
        net._conns[("https", host)] = conn
        conn.script = [_FakeHTTPResponse(200, b"x")]
        net(oc.urllib.request.Request(f"https://{host}/f.oxz")).read()
    assert set(net.requests_per_host) == {"a.example.invalid", "b.example.invalid"}


def test_a_429_with_retry_after_is_honoured_rather_than_retried_blind(fake_http):
    slept: list[float] = []
    net = oc.KeepAliveOpener(sleep=slept.append)
    req = oc.urllib.request.Request("https://wiki.example.invalid/a/x.oxz")
    net._connection  # noqa: B018 - touch so the attribute exists
    # prime the connection, then script: 429 (Retry-After 7) -> 200
    conn = _FakeConn("wiki.example.invalid")
    net._conns[("https", "wiki.example.invalid")] = conn
    conn.script = [
        _FakeHTTPResponse(429, b"", {"Retry-After": "7"}, "Too Many Requests"),
        _FakeHTTPResponse(200, b"payload"),
    ]
    resp = net(req)
    assert resp.read() == b"payload"
    assert slept == [7.0], (
        f"a 429 carrying 'Retry-After: 7' was not honoured; slept={slept}"
    )


def test_a_429_without_retry_after_backs_off_exponentially_and_gives_up(fake_http):
    slept: list[float] = []
    net = oc.KeepAliveOpener(sleep=slept.append, max_retries=2)
    conn = _FakeConn("wiki.example.invalid")
    net._conns[("https", "wiki.example.invalid")] = conn
    conn.script = [_FakeHTTPResponse(429, b"", {}, "Too Many Requests") for _ in range(4)]
    with pytest.raises(oc.urllib.error.HTTPError) as exc:
        net(oc.urllib.request.Request("https://wiki.example.invalid/a/x.oxz"))
    assert exc.value.code == 429
    assert slept == [5.0, 10.0], f"backoff schedule was {slept}, expected [5.0, 10.0]"


def test_backoff_is_bounded():
    net = oc.KeepAliveOpener(max_backoff=30.0)
    assert net._retry_after("999999", 0) == 30.0
    assert net._retry_after(None, 10) == 30.0
    assert net._retry_after("not-a-number", 0) == 5.0  # HTTP-date form -> schedule


def test_a_redirect_is_followed_and_the_final_url_recorded(fake_http):
    net = oc.KeepAliveOpener()
    conn = _FakeConn("wiki.example.invalid")
    net._conns[("https", "wiki.example.invalid")] = conn
    conn.script = [
        _FakeHTTPResponse(302, b"", {"Location": "/moved/final.oxz"}, "Found"),
        _FakeHTTPResponse(200, b"payload"),
    ]
    resp = net(oc.urllib.request.Request("https://wiki.example.invalid/a/x.oxz"))
    assert resp.geturl().endswith("/moved/final.oxz"), resp.geturl()
    assert resp.read() == b"payload"


def test_a_404_raises_an_httperror_the_fetcher_records(fake_http):
    net = oc.KeepAliveOpener()
    conn = _FakeConn("wiki.example.invalid")
    net._conns[("https", "wiki.example.invalid")] = conn
    conn.script = [_FakeHTTPResponse(404, b"", {}, "Not Found")]
    with pytest.raises(oc.urllib.error.HTTPError) as exc:
        net(oc.urllib.request.Request("https://wiki.example.invalid/a/gone.oxz"))
    assert exc.value.code == 404


def test_rate_limit_sleeps_between_requests_but_not_before_the_first(tmp_path):
    slept = []
    urls = [f"https://example.invalid/fixtures/r{i}.oxz" for i in range(3)]
    oc.fetch_all(
        urls,
        tmp_path / "c",
        {"version": oc.MANIFEST_VERSION, "entries": {}},
        opener=lambda req, timeout=None: _FakeResponse(b"x", req.full_url),
        rate_limit=0.25,
        sleep=slept.append,
    )
    assert slept == [0.25, 0.25], slept


# ---------------------------------------------------------- the committed manifest


@pytest.mark.skipif(not REAL_MANIFEST.exists(), reason="corpus manifest not yet built")
def test_the_committed_corpus_manifest_is_well_formed_and_covers_the_catalog():
    manifest = oc.load_manifest(REAL_MANIFEST)
    assert oc.check_manifest_schema(manifest) == []
    catalog = set(oc.load_catalog())
    covered = set(manifest["entries"])
    missing = catalog - covered
    assert not missing, f"{len(missing)} catalog URLs absent from the manifest, e.g. {sorted(missing)[:3]}"
    assert not (covered - catalog), "manifest lists URLs that are not in the catalog"
    ok = [e for e in manifest["entries"].values() if e.get("status") == "ok"]
    assert len(ok) >= 1, "the manifest records no successful fetch at all"
