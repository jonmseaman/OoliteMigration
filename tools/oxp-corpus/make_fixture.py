#!/usr/bin/env python3
"""Regenerate the committed offline fixture for tools/test_oxp_corpus.py (bead oo-425).

The fixture is a MINIATURE corpus cache: two tiny blobs plus a manifest that
describes them.  One blob matches its recorded checksum; the other has been
deliberately corrupted after the manifest was written, so the verifier has
something concrete to catch.  Everything here is synthetic - it contains no
expansion content and needs no network.

Run:  python3 tools/oxp-corpus/make_fixture.py
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import oxp_corpus as oc  # noqa: E402

FIXTURE = HERE / "fixtures"
CACHE = FIXTURE / "cache"

GOOD_URL = "https://example.invalid/fixtures/Good_Expansion_1.0.oxz"
CORRUPT_URL = "https://example.invalid/fixtures/Corrupt_Expansion_1.0.oxz"
MISSING_URL = "https://example.invalid/fixtures/Missing_Expansion_1.0.oxz"
ERROR_URL = "https://example.invalid/fixtures/Gone_Expansion_1.0.oxz"

GOOD_BYTES = b"oo-425 fixture: intact blob\n" * 8
# What the manifest CLAIMS the corrupt entry should be ...
CORRUPT_TRUE_BYTES = b"oo-425 fixture: this is what the manifest records\n" * 8
# ... and what is actually on disk (same length, one byte different, so a
# size-only check would pass and only the checksum catches it).
CORRUPT_ON_DISK = CORRUPT_TRUE_BYTES.replace(b"records", b"recordX", 1)

FETCHED_AT = "2026-09-18T00:00:00Z"


def _entry(url: str, data: bytes) -> dict:
    return {
        "url": url,
        "status": "ok",
        "http_status": 200,
        "final_url": url,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "fetched_at": FETCHED_AT,
        "cache_key": oc.cache_key(url),
    }


def main() -> int:
    assert len(CORRUPT_ON_DISK) == len(CORRUPT_TRUE_BYTES), "corruption must preserve size"
    for p in sorted(CACHE.rglob("*")) if CACHE.exists() else []:
        if p.is_file():
            p.unlink()
    manifest = {
        "version": oc.MANIFEST_VERSION,
        "generated_by": "tools/oxp-corpus/make_fixture.py",
        "entries": {
            GOOD_URL: _entry(GOOD_URL, GOOD_BYTES),
            CORRUPT_URL: _entry(CORRUPT_URL, CORRUPT_TRUE_BYTES),
            MISSING_URL: _entry(MISSING_URL, b"never written to the cache at all\n"),
            ERROR_URL: {
                "url": ERROR_URL,
                "status": "error",
                "error": "HTTP 404 Not Found",
                "fetched_at": FETCHED_AT,
                "cache_key": oc.cache_key(ERROR_URL),
            },
        },
    }
    for url, data in ((GOOD_URL, GOOD_BYTES), (CORRUPT_URL, CORRUPT_ON_DISK)):
        dest = oc.blob_path(CACHE, url)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    oc.save_manifest(manifest, FIXTURE / "manifest.json")
    print(f"wrote {FIXTURE/'manifest.json'} and {len(list(CACHE.rglob('*')))} cache paths")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
