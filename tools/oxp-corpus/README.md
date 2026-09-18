# OXP corpus cache (bead oo-425)

A local, resumable, checksum-verified cache of every expansion listed in
`upstream/oolite-expansion-catalog/expansionUrls.txt` (818 unique URLs).

## What is committed, and what is not

| artefact | location | committed? |
| --- | --- | --- |
| the manifest (url, size, sha256, http status, final url, fetch time) | `tools/oxp-corpus/manifest.json` | **yes** |
| the downloaded bytes (~15 GB of OXZ archives) | `%LOCALAPPDATA%/OoliteMigration/oxp-cache` | **no** |
| a miniature synthetic fixture cache used by the offline tests | `tools/oxp-corpus/fixtures/` | yes (≈1 KB) |

The corpus is roughly 15 GB — a single sampled expansion is 82 MB. Git is the
wrong store for that, so the **bytes live outside the repository** and only the
manifest plus checksums are versioned. That is enough to re-derive the cache on
any machine and to prove afterwards that the derived cache is byte-identical to
the one this bead measured. Acceptance line 5 enforces the split: it fails if any
tracked file under `tools/oxp-corpus/` exceeds 3 MiB.

Override the cache location with `OXP_CACHE_DIR`. The default falls back to
`~/.cache/oolite-migration/oxp-cache` where `LOCALAPPDATA` is unset.

## Usage

```sh
python3 tools/oxp_corpus.py fetch     # populate/extend the cache (resumable)
python3 tools/oxp_corpus.py verify    # re-check every cached blob against its sha256
python3 tools/oxp_corpus.py probe     # HEAD only; sizes without bodies
```

Useful flags: `--cache-dir`, `--manifest`, `--catalog`, `--limit N`,
`--rate-limit SECONDS`.

## Design notes

* **Content-addressed layout.** A blob is stored at `<cache>/<k[:2]>/<k>` where
  `k = sha256(url)`. URL-derived filenames would collide and would break on the
  percent-escapes that appear in several catalog entries.
* **Resumable and idempotent.** An entry already in the manifest whose blob still
  matches its recorded size *and* sha256 is skipped with **no network call**. A
  run killed halfway costs nothing next time, and the manifest is checkpointed
  every ten transfers.
* **Atomic writes.** Each download lands in `<blob>.part` and is renamed on
  success, so an interrupted transfer can never leave a truncated blob that a
  later run would mistake for a complete one.
* **Good-citizen fetching.** One request at a time on a **single process**, a ≥1 s
  delay between requests, HTTP keep-alive so 818 requests cost one TCP+TLS
  handshake rather than 818, and a descriptive `User-Agent` naming the project
  and this bead.
* **Never shard this fetch across processes.** 811 of the 818 URLs are on one
  volunteer-run community wiki (`wiki.alioth.net`). `--rate-limit` is enforced
  *per process* and cannot see its siblings, so running N fetchers in parallel
  silently multiplies the request rate against that host by N. This was done
  once during development (6 shards × 1 s ≈ 6 req/s against alioth) and was
  wrong; the correct way to recover throughput is keep-alive on one connection,
  and any extra concurrency must be against *different* hosts only.
* **429/503 are honoured, not retried blind.** `KeepAliveOpener` reads
  `Retry-After` and waits exactly that long (bounded at 60 s); with no header it
  backs off 5 s, 10 s, 20 s and then records the entry as an error.
* **404s are data, not failures.** An HTTP error is recorded as an `error` entry
  with its reason and moves on; one dead link must not throw away the other 817.
* **Provenance per entry.** `url`, `final_url` (after redirects), `http_status`,
  `size`, `sha256`, `fetched_at` (UTC) and `cache_key`, so a later agent can tell
  a stale entry from a fresh one and re-fetch selectively.
* **No expansion content is ever read.** Downloads are opaque bytes; nothing here
  opens, unzips or parses an OXZ (repo rule).

## Why the acceptance gate does not use the network

818 remote URLs cannot be re-fetched inside `accept.sh` in a clean checkout: it
would take hours and would go red whenever `wiki.alioth.net` is down — which is
not evidence about this code. The gate therefore tests the **cache contract**
offline, against the committed fixture:

1. `tools/test_oxp_corpus.py` — 22 offline unit tests.
2. the committed manifest parses, covers all 818 catalog URLs and carries a
   well-formed size + sha256 on every `ok` entry.
3. the verifier accepts the intact fixture blob and **rejects** the deliberately
   corrupted one. The corruption preserves the byte length, so a size-only check
   would miss it and only the checksum can catch it.
4. a second run over a populated cache makes **zero** network attempts — and,
   so that claim cannot go vacuous, deleting the cached blob makes it attempt
   exactly one.
5. no large blob is tracked under `tools/oxp-corpus/`.

Regenerate the fixture with `python3 tools/oxp-corpus/make_fixture.py`.
`tools/oxp-corpus/acceptance.txt` is a byte-identical copy of the block stored in
the bead, kept in-tree so the gate can be read and replayed without `bd`.
