#!/usr/bin/env python3
"""Select and regenerate the Tier 1 OXP corpus list (bead oo-het).

WHY THIS FILE EXISTS AT ALL
---------------------------
The bead asks for "~30 most-installed expansions".  THE CORPUS CONTAINS NO
INSTALL COUNT.  That is a measured fact, not an assumption: every one of the
818 cached expansions carries a top-level manifest.plist, and across all 818 the
complete set of keys that appear is

    identifier, version, title, required_oolite_version, category, author,
    license/licence, description, information_url, download_url, file_size,
    tags, requires_oxps/requires_oxp, optional_oxps, conflict_oxps,
    upload_date, maximum_version, maximum_oolite_version

There is no download count, no rating, no install count, no popularity rank.
The upstream catalogue (upstream/oolite-expansion-catalog/expansionUrls.txt) is
a bare list of URLs with no metadata at all.  Oolite's own expansion manager
downloads its catalogue from the network and does not publish counts either.
So "most-installed" CANNOT be read off the data we have, and inventing a list
of 30 famous names from memory would be an assertion, not a selection.

THE PROXY, AND WHY IT IS DEFENSIBLE
-----------------------------------
We rank by DEPENDENCY IN-DEGREE: the number of OTHER expansions in the corpus
that name this expansion's identifier in their manifest's `requires_oxps` (hard
dependency) or `optional_oxps` (soft dependency).

The proxy's logic is mechanical rather than aesthetic: if K distinct expansions
hard-require expansion X, then every user who installs any one of those K has X
installed as well.  In-degree is therefore a strict LOWER BOUND on install
breadth relative to the rest of the corpus - a library required by 60 other
OXPs is installed by at least the union of their user bases.  It is derived
from bytes we have, it is reproducible byte-for-byte from the committed
manifest + the content-addressed cache, and it is auditable: every edge can be
traced back to a named manifest.plist inside a sha256-pinned OXZ.

IT IS A PROXY AND IT HAS KNOWN BIASES.  Write them down rather than hide them:

  * It over-weights LIBRARIES and under-weights LEAF CONTENT.  A hugely popular
    standalone ship pack that nothing depends on scores 0.  So in-degree alone
    would select ~15 libraries and nothing else.
  * Only 177 of 818 manifests declare any dependency at all, so the graph is
    sparse and the tail of the ranking is all ties at 0.
  * requires_oxps is self-reported; an OXP that depends on another without
    declaring it contributes no edge.

Because of the first and second bias, in-degree alone is NOT the whole
criterion.  The selection is a documented two-band rule:

  BAND A - dependency hubs: every expansion with in-degree >= 1, taken in
           descending in-degree order.  These are the expansions the corpus
           itself says are most widely co-installed.
  BAND B - tie-break fill to reach the target size, over the in-degree-0
           remainder, ranked by a second signal that is also in the data:
           CATEGORY BREADTH.  We take the corpus's own `category` field and
           fill round-robin across categories, preferring within each category
           the expansion with the most distinct `tags` and then the smallest
           byte size.  Rationale: the purpose of Tier 1 is a fast per-commit
           smoke corpus, so once the hub band is exhausted the next most useful
           property is COVERAGE of different loader code paths (ships,
           equipment, missions, mechanics, sound, HUD...) at low wall-clock
           cost, and category is the corpus's own partition of that space.
           Smallest-size-first inside a category is an explicit cost bias: a
           per-commit gate should not pay 80 MB to exercise a code path a 40 kB
           OXP exercises identically.

Both bands are deterministic: ties are broken by (-score, identifier) so the
output is stable across runs and machines.

The 6 test-oxps from upstream/oolite-tests/test-oxps are appended
unconditionally - they are named explicitly by the bead and are not part of the
ranked corpus (they are source directories, not catalogue OXZs).

Usage:
    python3 tools/oxp_tier1.py generate [--out tools/oxp-corpus/tier1.json]
    python3 tools/oxp_tier1.py show
    python3 tools/oxp_tier1.py check     # regenerate and diff against committed
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import oxp_corpus as oc  # noqa: E402

MANIFEST = REPO_ROOT / "tools" / "oxp-corpus" / "manifest.json"
TIER1_JSON = REPO_ROOT / "tools" / "oxp-corpus" / "tier1.json"
TEST_OXP_DIR = REPO_ROOT / "upstream" / "oolite-tests" / "test-oxps"

#: how many CATALOGUE expansions Tier 1 holds ("~30" in the bead)
TARGET_CATALOGUE = 30


# --------------------------------------------------------------- OpenStep plist

class PlistError(ValueError):
    pass


def parse_openstep(text: str):
    """Parse the OpenStep (NeXT) plist dialect Oolite's manifest.plist files use.

    plistlib cannot read these: exactly 3 of the 818 corpus manifests are XML,
    the other 815 are OpenStep.  This parser covers the subset that actually
    occurs in manifests - dictionaries, arrays, bare and quoted strings, // and
    /* */ comments - and raises rather than guessing on anything else.
    """
    i = 0
    n = len(text)

    def skip():
        nonlocal i
        while i < n:
            c = text[i]
            if c in " \t\r\n":
                i += 1
            elif text.startswith("//", i):
                j = text.find("\n", i)
                i = n if j < 0 else j + 1
            elif text.startswith("/*", i):
                j = text.find("*/", i + 2)
                if j < 0:
                    raise PlistError("unterminated /* comment")
                i = j + 2
            else:
                return

    def quoted():
        nonlocal i
        i += 1  # opening quote
        out = []
        while i < n:
            c = text[i]
            if c == "\\":
                nxt = text[i + 1]
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
                i += 2
            elif c == '"':
                i += 1
                return "".join(out)
            else:
                out.append(c)
                i += 1
        raise PlistError("unterminated quoted string")

    BARE_STOP = set(' \t\r\n=;,(){}"')

    def bare():
        nonlocal i
        start = i
        while i < n and text[i] not in BARE_STOP:
            i += 1
        if i == start:
            raise PlistError("empty token at offset %d" % i)
        return text[start:i]

    def value():
        nonlocal i
        skip()
        if i >= n:
            raise PlistError("unexpected end of input")
        c = text[i]
        if c == "{":
            i += 1
            d = {}
            while True:
                skip()
                if i < n and text[i] == "}":
                    i += 1
                    return d
                k = quoted() if text[i] == '"' else bare()
                skip()
                if i >= n or text[i] != "=":
                    raise PlistError("expected '=' after key %r" % k)
                i += 1
                d[k] = value()
                skip()
                if i < n and text[i] == ";":
                    i += 1
        if c == "(":
            i += 1
            a = []
            while True:
                skip()
                if i < n and text[i] == ")":
                    i += 1
                    return a
                a.append(value())
                skip()
                if i < n and text[i] == ",":
                    i += 1
        if c == '"':
            return quoted()
        return bare()

    skip()
    # A leading XML prolog means this is one of the 3 XML manifests.
    if text.startswith("<?xml") or text.startswith("<plist"):
        import plistlib
        return plistlib.loads(text.encode("utf-8"))
    v = value()
    return v


# --------------------------------------------------------------- corpus reading


def cache_dir() -> Path:
    env = os.environ.get("OXP_CACHE_DIR")
    if env:
        return Path(env)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return Path(local) / "OoliteMigration" / "oxp-cache"
    return Path.home() / ".cache" / "oolite-migration" / "oxp-cache"


def read_manifests(manifest_path: Path = MANIFEST, cache: Path | None = None):
    """Yield (url, entry, manifest_dict) for every OK corpus entry, sorted by url."""
    cache = cache or cache_dir()
    entries = json.loads(manifest_path.read_text(encoding="utf-8"))["entries"]
    for url in sorted(entries):
        entry = entries[url]
        if entry.get("status") != "ok":
            continue
        blob = oc.blob_path(cache, url)
        if not blob.exists():
            raise SystemExit(
                "cached blob missing for %s at %s - run "
                "'python3 tools/oxp_corpus.py fetch' first" % (url, blob)
            )
        with zipfile.ZipFile(blob) as z:
            cand = [
                name for name in z.namelist()
                if name.lower().endswith("manifest.plist") and name.count("/") <= 1
            ]
            if not cand:
                continue
            raw = z.read(sorted(cand)[0]).decode("utf-8", "replace")
        try:
            man = parse_openstep(raw)
        except (PlistError, Exception):  # noqa: BLE001 - a broken manifest is data, not a crash
            continue
        if isinstance(man, dict) and man.get("identifier"):
            yield url, entry, man


def _dep_ids(man: dict, key: str) -> list[str]:
    """Identifiers named under `key`, tolerating both spellings and both shapes.

    requires_oxps is normally an array of dicts ({identifier=...; version=...;})
    but a handful of manifests give an array of bare identifier strings, and 26
    use the singular key `requires_oxp`.  All three forms are real in the corpus.
    """
    out = []
    for k in (key, key[:-1] if key.endswith("s") else key + "s"):
        val = man.get(k)
        if val is None:
            continue
        if isinstance(val, str):
            val = [val]
        if not isinstance(val, list):
            continue
        for item in val:
            if isinstance(item, str):
                out.append(item.strip())
            elif isinstance(item, dict) and isinstance(item.get("identifier"), str):
                out.append(item["identifier"].strip())
    return [x for x in out if x]


def build_graph(records):
    """Return (by_id, indegree, edges).

    by_id maps identifier -> the NEWEST-version record for that identifier (the
    catalogue lists several versions of some expansions; counting each version
    as a separate node would let a prolific re-releaser inflate its own rank).
    """
    by_id: dict[str, dict] = {}
    for url, entry, man in records:
        ident = man["identifier"].strip()
        version = str(man.get("version", ""))
        rec = {
            "identifier": ident,
            "title": str(man.get("title", ident)),
            "version": version,
            "category": str(man.get("category", "")).strip() or "Uncategorised",
            "tags": [t for t in (man.get("tags") or "").split(",") if t.strip()]
            if isinstance(man.get("tags"), str) else list(man.get("tags") or []),
            "url": url,
            "size": int(entry.get("size") or 0),
            "sha256": entry.get("sha256", ""),
            "requires": _dep_ids(man, "requires_oxps"),
            "optional": _dep_ids(man, "optional_oxps"),
        }
        prev = by_id.get(ident)
        if prev is None or _vkey(version) > _vkey(prev["version"]):
            by_id[ident] = rec

    indegree = collections.Counter()
    edges = collections.defaultdict(list)
    for rec in by_id.values():
        for dep in set(rec["requires"]) | set(rec["optional"]):
            if dep == rec["identifier"]:
                continue  # a self-edge is a manifest bug, not popularity
            if dep in by_id:
                indegree[dep] += 1
                edges[dep].append(rec["identifier"])
    for ident in by_id:
        indegree.setdefault(ident, 0)
    return by_id, indegree, {k: sorted(v) for k, v in edges.items()}


def _vkey(version: str):
    parts = []
    for chunk in str(version).replace("-", ".").split("."):
        parts.append((1, int(chunk)) if chunk.isdigit() else (0, 0))
    return parts


# ------------------------------------------------------------------- selection


def select(by_id, indegree, edges, target=TARGET_CATALOGUE):
    """The two-band rule documented in the module docstring. Deterministic."""
    hubs = sorted(
        (i for i, d in indegree.items() if d >= 1),
        key=lambda i: (-indegree[i], i),
    )
    band_a = hubs[:target]

    chosen = list(band_a)
    chosen_set = set(chosen)
    band_b = []
    if len(chosen) < target:
        rest = [i for i in sorted(by_id) if i not in chosen_set and indegree[i] == 0]
        buckets = collections.defaultdict(list)
        for ident in rest:
            buckets[by_id[ident]["category"]].append(ident)
        for cat in buckets:
            buckets[cat].sort(
                key=lambda i: (-len(by_id[i]["tags"]), by_id[i]["size"], i)
            )
        order = sorted(buckets)  # round-robin across categories, alphabetical
        pos = 0
        while len(chosen) + len(band_b) < target and any(buckets.values()):
            cat = order[pos % len(order)]
            pos += 1
            if buckets[cat]:
                band_b.append(buckets[cat].pop(0))
    return band_a, band_b


def test_oxps():
    """The 6 test-oxps, discovered from the tree rather than hardcoded."""
    if not TEST_OXP_DIR.is_dir():
        raise SystemExit("no test-oxps directory at %s" % TEST_OXP_DIR)
    out = []
    for d in sorted(TEST_OXP_DIR.iterdir()):
        if not d.is_dir():
            continue
        oxps = sorted(p for p in d.iterdir() if p.is_dir() and p.suffix == ".oxp")
        for oxp in oxps:
            out.append({
                # The .oxp BASENAME, not the containing directory's name. Oolite
                # dispatches on the extension (ResourceManager.m:290-310), so an
                # entry staged as "AI overflow test" with no .oxp suffix is not
                # an expansion at all and is silently ignored.
                "name": oxp.name,
                "dir": d.name,
                "path": str(oxp.relative_to(REPO_ROOT)).replace("\\", "/"),
            })
    return out


def generate():
    records = list(read_manifests())
    by_id, indegree, edges = build_graph(records)
    band_a, band_b = select(by_id, indegree, edges)

    def emit(ident, band):
        r = by_id[ident]
        return {
            "identifier": ident,
            "title": r["title"],
            "version": r["version"],
            "category": r["category"],
            "url": r["url"],
            "sha256": r["sha256"],
            "size": r["size"],
            "band": band,
            "indegree": indegree[ident],
            "required_by": edges.get(ident, []),
        }

    return {
        "schema": 1,
        "generator": "tools/oxp_tier1.py",
        "criterion": "dependency in-degree (requires_oxps + optional_oxps), "
                     "then category-breadth fill; see module docstring",
        "corpus_size": len(by_id),
        "target_catalogue": TARGET_CATALOGUE,
        "catalogue": [emit(i, "A-hub") for i in band_a]
                     + [emit(i, "B-breadth") for i in band_b],
        "test_oxps": test_oxps(),
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["generate", "show", "check"])
    ap.add_argument("--out", default=str(TIER1_JSON))
    args = ap.parse_args(argv)

    if args.command == "show":
        data = json.loads(Path(args.out).read_text(encoding="utf-8"))
        for e in data["catalogue"]:
            print("%-9s in=%-3d %-44s %s" % (e["band"], e["indegree"], e["identifier"], e["title"]))
        for t in data["test_oxps"]:
            print("%-9s          %-44s %s" % ("test-oxp", t["name"], t["path"]))
        print("catalogue=%d test_oxps=%d" % (len(data["catalogue"]), len(data["test_oxps"])))
        return 0

    fresh = generate()
    text = json.dumps(fresh, indent=2, sort_keys=False) + "\n"

    if args.command == "generate":
        Path(args.out).write_text(text, encoding="utf-8")
        print("wrote %s: %d catalogue + %d test-oxps"
              % (args.out, len(fresh["catalogue"]), len(fresh["test_oxps"])))
        return 0

    old = Path(args.out).read_text(encoding="utf-8")
    if old != text:
        sys.stderr.write(
            "tier1.json is STALE: regenerating from the corpus produces different bytes.\n"
            "Run: python3 tools/oxp_tier1.py generate\n"
        )
        return 1
    print("tier1.json matches a fresh regeneration (%d catalogue + %d test-oxps)"
          % (len(fresh["catalogue"]), len(fresh["test_oxps"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
