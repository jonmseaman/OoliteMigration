# OXP corpus Tier 2 (nightly) and Tier 3 (weekly) — bead oo-4z6

Tier 1 (bead oo-het) is the ~36-expansion per-commit gate. This document covers
the two larger tiers and the report they produce.

```sh
tools/corpus.sh list2         # print the Tier 2 selection (offline)
tools/corpus.sh regen2        # regenerate tier2.json and tier3.json
tools/corpus.sh check-list2   # assert both committed lists match a fresh regen
tools/corpus.sh selftest2     # OFFLINE proof of the clustering + state machine
tools/corpus.sh tier2 --state DIR   # nightly: 150 expansions, ~34 min
tools/corpus.sh tier3 --state DIR   # weekly: 813 expansions, ~3 h — SHARD IT
tools/corpus.sh report --results DIR_OR_FILE
```

## The arithmetic, which dictates the whole design

oo-het **measured** the cost of one solo expansion load on this host: 493 s for
36 expansions, i.e. ~13.5 s each, on a box shared with four other agents.

| tier | entries | serialised wall time |
| --- | --- | --- |
| Tier 1 | 36 | ~8 min |
| Tier 2 | 150 | **~34 min** |
| Tier 3 | 813 | **~3 h** |

A three-hour sequence of game launches cannot be a stored acceptance line, and a
34-minute one is not an edit loop either. Three consequences, all load-bearing:

1. **Resumable.** `--state DIR` accumulates one JSON record per expansion the
   moment it is judged. A re-run reads the directory and runs only what is
   missing, so a sweep killed at minute 90 costs 90 minutes once, not twice.
   Acceptance line 4 proves this with two real launches and a real re-run.
2. **Shardable.** `--shard K/N` partitions the list deterministically, so a
   weekly Tier 3 can be spread over several nights. Shard state directories
   union cleanly. **Sharding here multiplies LOCAL game launches only** — the
   the corpus is read from the content-addressed cache and this code never touches
   the network. (Bead oo-425 records what happens when sharding is applied to a
   rate-limited remote fetch: 6× the agreed request rate against a volunteer
   host.)
3. **The logic worth arguing about is offline-testable.** Selection lives in
   `tools/oxp_tier23.py`, clustering and classification in `tools/oxp_report.py`;
   both are exercised against committed fixtures with no game launch at all.

### What has actually been run, and what has not

**No full Tier 3 run has been performed and none is claimed.** The largest real
run to date is a **12-expansion Tier 2 sample**, measured on this host while four
sibling agents were active:

```
tools/corpus.sh tier2 --limit 12 --state ...
12 checked, 1 failing (7 pass, 4 unmet-deps not counted)   wall 192s  rc=1
```

That is **16.0 s per expansion**, slightly above oo-het's 13.5 s — contention,
as expected — which puts Tier 2 at ~40 min and Tier 3 at ~3.6 h. The sample
produced four of the seven states from real game launches: 7 `PASS`, 4
`NOTLOADED_DEPS`, 1 `ERRORS` (XenonUI, clustered). Note that the oo-kcrw
correlation held perfectly again: **every** rejected expansion in the sample
declared `requires_oxps`, and `NOTLOADED` (rejected with no declared
dependencies) was **zero**.

Acceptance line 4 is the only stored line that launches the game; it uses two
expansions (~40 s) and exists to prove the launch path and the resume, not to
cover the corpus. Everything else in the gate is fixture-driven and offline.

## Tier 2 selection: the corpus's own `category` field

oo-het had to reach for a proxy because the bead asked for "most-installed" and
**there is no popularity signal anywhere in the data** — no download count, no
rating, no install count (see `tools/oxp_tier1.py`). That is not the situation
here. `category` is a real, declared field. Measured over the cache: **814 of
814 readable manifests declare a non-empty `category`**, in exactly 13 values.

| category | corpus | Tier 2 slots |
| --- | ---: | ---: |
| Ambience | 169 | 26 |
| Ships | 134 | 21 |
| Equipment | 132 | 21 |
| Mechanics | 93 | 16 |
| Retextures | 77 | 13 |
| Miscellaneous | 46 | 9 |
| HUDs | 41 | 9 |
| Missions | 34 | 8 |
| Dockables | 32 | 8 |
| Activities | 25 | 7 |
| Weapons | 20 | 6 |
| Systems | 10 | 5 |
| Cheats | 1 | 1 |

(regenerate with `tools/corpus.sh regen2`; the exact quota lives in
`tier2.json` under `category_quota`.)

The allocation rule, deterministic and byte-stable:

1. **Floor.** Every category gets `min(population, 4)` slots, so the tail cannot
   be rounded out of existence. `Cheats` has exactly **one** expansion in the
   whole corpus; proportional allocation alone gives it 0.04 slots and a nightly
   run would never touch that loader path.
2. **Proportional remainder** by the largest-remainder (Hare) method, ties broken
   by category name.
3. **Within a category, rank by `(-indegree, size, identifier)`** — the
   dependency in-degree proxy oo-het documented first (hubs before leaves), then
   size ascending, because a nightly gate should not pay 80 MB to exercise a code
   path a 40 kB expansion exercises identically, then identifier for totality.

### Biases, stated rather than hidden

* `category` is self-declared by the author and validated by nothing;
  `Miscellaneous` (46) is a real bucket of things that did not fit.
* Category says what an expansion is *for*, not which loader code paths it
  exercises. It is a proxy for coverage, not a measurement of it.
* Smallest-first inside a category systematically excludes the large content
  packs from Tier 2. Tier 3 is what covers those.

`check-list2` byte-compares both committed lists against a fresh regeneration
**and** re-asserts the stated properties (every category present, floor
respected, within-category order correct, Tier 2 ⊆ Tier 3), so neither the list
nor the selector can drift without the gate noticing.

Tier 3 is every unique identifier in the cache: 818 URLs → 814 archives with a
readable top-level `manifest.plist` → **813 unique identifiers** (newest version
per identifier wins, as in Tier 1). The 4 archives with no readable manifest are
listed explicitly under `excluded_no_readable_manifest` rather than dropped.

## Clustering: why "group by first error line" is not enough

The bead's definition of done is "a report grouping failures by first error
line". Taken literally that gives N groups for N failures. Every Oolite error
line carries volatile parts — a timestamp, the per-run work directory, the
expansion's own name, sometimes a hex address or a version number:

```
03:35:59.439 [plist.parse.failed]: Failed to parse
  C:/.../runs/Foo_1.2/AddOns/Foo.oxz/Config/shipdata.plist as a property list.
```

So the same defect in fifty expansions yields fifty distinct first error lines.
`oxp_report.normalise()` strips, in order: the leading timestamp; the
expansion's identifier/title/staged name and any `*.oxz`/`*.oxp` path component
(→ `<OXP>`); `0x…` (→ `<HEX>`); paths (→ `<PATH>`); bare numbers and dotted
versions (→ `<N>`); runs of whitespace. **Nothing else is touched** — the
channel name, the message wording and the sentence structure all survive, and
that is what keeps genuinely different failures apart.

`selftest2` case 1 proves this in **both directions** against
`tools/oxp-corpus/fixtures/results-mixed.jsonl`:

* 4 `plist.parse.failed` rows differing only in timestamp, work directory (three
  different drive/root shapes) and expansion name → **1 cluster**;
* 3 JS-exception rows differing only in name, version and hex address → **1
  cluster** (a version-shape check had to be added: `1.9.2` and `0.14` normalise
  to different token counts and split the cluster until dotted runs collapse);
* the 9 error rows as a whole → **exactly 4 clusters**, one per genuine failure
  kind. Over-normalising would fuse these and is caught.

## The seven reported states — only one is a pass

Both the human output and the JSON distinguish:

| state | meaning | counts as failure? |
| --- | --- | --- |
| `STAGEFAIL` | the harness could not copy it into the private AddOns dir | **yes, and LOUD** |
| `HARNESS` | LAUNCH/LOG/NOSHIPDATA/STARTUP/NOSENTINEL — the game did not run far enough to judge | yes |
| `NOTCACHED` | absent from the corpus cache; no verdict possible | yes |
| `ERRORS` | loaded, then logged errors — **these are clustered** | yes |
| `NOTLOADED` | rejected, and declares **no** dependencies | yes |
| `NOTLOADED_DEPS` | rejected, and declares `requires_oxps` that were not staged | **no — see below** |
| `PASS` | loaded clean | — |

`STAGEFAIL` is loud and says "HARNESS BUG" because an earlier unchecked `cp` in
a staging loop surfaced twenty lines later as a bogus "missing expansion" and
sent an agent hunting the corpus cache.

`NOTLOADED_DEPS` is the known open finding owned by **bead oo-kcrw**: in Tier 1
all 7 NOTLOADED expansions had a non-empty `requires_oxps` and every PASS had
none — solo loading is structurally wrong for a dependency-bearing expansion.
At Tier 2/3 scale this is expected in bulk, so it is reported separately and not
counted as a real failure. It is **not** green either: it has its own line in the
summary table, its own named block in the output, and it is excluded from the
pass count. Do not "fix" it here.
