#!/usr/bin/env python3
"""Generate and verify the Tier 2 and Tier 3 OXP corpus lists (bead oo-4z6).

TIER 3 IS EASY AND TIER 2 IS THE ONE THAT NEEDS JUSTIFYING.

Tier 3 is "all of them": every unique expansion identifier in the cached
corpus, in deterministic identifier order.  The corpus manifest holds 818 URLs,
all fetched ok; 814 of those archives contain a top-level manifest.plist that
parses, and those 814 collapse to 813 unique identifiers (the catalogue carries
two versions of one expansion - the newest wins, exactly as oo-het's Tier 1
generator does, so a prolific re-releaser cannot be counted twice).  The 4
archives with no readable top-level manifest are listed explicitly in the
generated file under "excluded" rather than silently dropped: an expansion the
selector cannot read is a fact about the corpus, not a rounding error.

TIER 2 IS "~150 CHOSEN FOR CATEGORY COVERAGE", AND THE DATA SUPPORTS IT.
oo-het had to reach for a proxy because the bead asked for "most-installed"
and THERE IS NO POPULARITY SIGNAL ANYWHERE IN THE DATA (no download count, no
rating, no install count - see tools/oxp_tier1.py).  That is not the situation
here.  "Category" is a real, declared field: MEASURED over the corpus, 814 of
814 readable manifests declare a non-empty `category`, and they fall into
exactly 13 values:

    Ambience 169   Ships 134   Equipment 132   Mechanics 93   Retextures 77
    Miscellaneous 46   HUDs 41   Missions 34   Dockables 32   Activities 25
    Weapons 20   Systems 10   Cheats 1

So Tier 2 uses the corpus's OWN partition, and no taxonomy is invented.

THE ALLOCATION RULE (deterministic, reproducible, byte-stable):

  1. FLOOR.  Every category gets min(len(category), FLOOR=4) slots, so the tail
     categories cannot be rounded out of existence.  Cheats has exactly ONE
     expansion in the whole corpus; proportional allocation alone would give it
     0.04 slots and a nightly run would never touch that loader path.
  2. PROPORTIONAL REMAINDER.  The remaining slots are handed out by the
     largest-remainder (Hare) method over the categories' residual populations,
     ties broken by category name, so a bigger category still gets more of the
     budget.
  3. WITHIN A CATEGORY, order by (-indegree, size, identifier):
       * -indegree first: the dependency in-degree proxy oo-het documented
         (how many other corpus manifests name this identifier in requires_oxps
         / optional_oxps) is the only breadth signal in the data, so within a
         category the hubs go first.
       * then size ascending: a nightly gate should not pay 80 MB to exercise a
         code path a 40 kB expansion exercises identically.  This is an explicit
         cost bias, stated so it can be argued with.
       * then identifier, so the order is total and machine-independent.

BIASES, WRITTEN DOWN RATHER THAN HIDDEN:
  * `category` is self-declared by the expansion author and is not validated by
    anything; "Miscellaneous" (46) is a real bucket of things that did not fit.
  * Category says what an expansion is FOR, not which loader code paths it
    exercises.  It is a proxy for coverage, not a measurement of it.
  * The smallest-first rule inside a category systematically excludes the large
    content packs from Tier 2.  Tier 3 is what covers those.

Usage:
    python3 tools/oxp_tier23.py generate [--tier2 OUT] [--tier3 OUT]
    python3 tools/oxp_tier23.py check    [--tier2 OUT] [--tier3 OUT]
    python3 tools/oxp_tier23.py show --tier2 tools/oxp-corpus/tier2.json
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import oxp_tier1 as t1  # noqa: E402

TIER2_JSON = REPO_ROOT / "tools" / "oxp-corpus" / "tier2.json"
TIER3_JSON = REPO_ROOT / "tools" / "oxp-corpus" / "tier3.json"

#: "~150" from the bead.
TARGET_TIER2 = 150
#: minimum slots per declared category - see rule 1 above
FLOOR_PER_CATEGORY = 4


def allocate(sizes: dict[str, int], target: int, floor: int) -> dict[str, int]:
    """Floor + largest-remainder allocation of `target` slots over categories."""
    quota = {c: min(n, floor) for c, n in sizes.items()}
    left = target - sum(quota.values())
    if left <= 0:
        return quota
    residual = {c: sizes[c] - quota[c] for c in sizes}
    pool = sum(residual.values())
    if pool <= 0:
        return quota
    exact = {c: left * residual[c] / pool for c in sizes}
    for c in sizes:
        take = min(int(exact[c]), residual[c])
        quota[c] += take
        left -= take
    # largest remainder, ties by category name so the result is byte-stable
    order = sorted(sizes, key=lambda c: (-(exact[c] - int(exact[c])), c))
    i = 0
    while left > 0 and any(sizes[c] - quota[c] > 0 for c in sizes):
        c = order[i % len(order)]
        i += 1
        if sizes[c] - quota[c] > 0:
            quota[c] += 1
            left -= 1
    return quota


def corpus():
    """(by_id, indegree, excluded) for the whole cached corpus."""
    records = list(t1.read_manifests())
    by_id, indegree, _edges = t1.build_graph(records)
    seen = {u for u, _e, _m in records}
    entries = json.loads(t1.MANIFEST.read_text(encoding="utf-8"))["entries"]
    excluded = sorted(u for u, e in entries.items()
                      if e.get("status") == "ok" and u not in seen)
    return by_id, indegree, excluded


def _emit(rec, indegree, extra=None):
    out = {
        "identifier": rec["identifier"],
        "title": rec["title"],
        "version": rec["version"],
        "category": rec["category"],
        "url": rec["url"],
        "sha256": rec["sha256"],
        "size": rec["size"],
        "indegree": indegree[rec["identifier"]],
        "requires": sorted(set(rec["requires"])),
    }
    if extra:
        out.update(extra)
    return out


def select_tier2(by_id, indegree, target=TARGET_TIER2, floor=FLOOR_PER_CATEGORY):
    buckets = collections.defaultdict(list)
    for ident in sorted(by_id):
        buckets[by_id[ident]["category"]].append(ident)
    for cat in buckets:
        buckets[cat].sort(key=lambda i: (-indegree[i], by_id[i]["size"], i))
    sizes = {c: len(v) for c, v in buckets.items()}
    quota = allocate(sizes, target, floor)
    chosen = []
    for cat in sorted(buckets):
        chosen.extend(buckets[cat][:quota[cat]])
    # emit in category order then in-bucket rank order; stable and auditable
    return chosen, quota, sizes


def generate():
    by_id, indegree, excluded = corpus()
    chosen, quota, sizes = select_tier2(by_id, indegree)
    tier2 = {
        "schema": 1,
        "generator": "tools/oxp_tier23.py",
        "tier": 2,
        "criterion": "declared manifest `category` (13 values, present on 814/814 "
                     "readable manifests): floor of %d per category, remainder by "
                     "largest-remainder proportional allocation; within a category "
                     "ranked by (-dependency in-degree, size ascending, identifier)"
                     % FLOOR_PER_CATEGORY,
        "corpus_size": len(by_id),
        "target": TARGET_TIER2,
        "floor_per_category": FLOOR_PER_CATEGORY,
        "category_population": dict(sorted(sizes.items())),
        "category_quota": dict(sorted(quota.items())),
        "entries": [_emit(by_id[i], indegree) for i in chosen],
    }
    tier3 = {
        "schema": 1,
        "generator": "tools/oxp_tier23.py",
        "tier": 3,
        "criterion": "every unique expansion identifier in the cached corpus, "
                     "newest version per identifier, in identifier order",
        "corpus_size": len(by_id),
        "excluded_no_readable_manifest": excluded,
        "entries": [_emit(by_id[i], indegree) for i in sorted(by_id)],
    }
    return tier2, tier3


def _text(d):
    return json.dumps(d, indent=2, sort_keys=False) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["generate", "check", "show"])
    ap.add_argument("--tier2", default=str(TIER2_JSON))
    ap.add_argument("--tier3", default=str(TIER3_JSON))
    args = ap.parse_args(argv)

    if args.command == "show":
        d = json.loads(Path(args.tier2).read_text(encoding="utf-8"))
        for e in d["entries"]:
            print("%-14s in=%-3d %9d  %-44s %s"
                  % (e["category"], e["indegree"], e["size"], e["identifier"], e["title"]))
        print("entries=%d over %d categories" % (len(d["entries"]), len(d["category_quota"])))
        return 0

    fresh2, fresh3 = generate()
    t2, t3 = _text(fresh2), _text(fresh3)

    if args.command == "generate":
        # Write LF explicitly. .gitattributes declares *.json eol=lf, so a fresh
        # checkout has LF; letting Python's default newline translation write CRLF
        # here would leave the worktree permanently "modified" and would make this
        # file's line endings depend on which OS last ran the generator.
        Path(args.tier2).write_text(t2, encoding="utf-8", newline="\n")
        Path(args.tier3).write_text(t3, encoding="utf-8", newline="\n")
        print("wrote %s (%d entries) and %s (%d entries)"
              % (args.tier2, len(fresh2["entries"]), args.tier3, len(fresh3["entries"])))
        return 0

    rc = 0
    for path, want, label in ((args.tier2, t2, "tier2"), (args.tier3, t3, "tier3")):
        have = Path(path).read_text(encoding="utf-8") if Path(path).exists() else ""
        if have != want:
            sys.stderr.write(
                "%s is STALE: regenerating from the corpus produces different bytes "
                "(committed %d bytes, fresh %d bytes).\n"
                "Run: python3 tools/oxp_tier23.py generate\n" % (label, len(have), len(want)))
            rc = 1
    if rc:
        return rc
    # A byte-compare alone cannot tell a correct list from a list generated by a
    # selector that ignores its own criterion, so assert the stated properties too.
    d2 = json.loads(t2)
    cats = collections.Counter(e["category"] for e in d2["entries"])
    assert len(d2["entries"]) == TARGET_TIER2, len(d2["entries"])
    assert set(cats) == set(d2["category_population"]), \
        "tier2 does not cover every declared category: missing %s" % (
            sorted(set(d2["category_population"]) - set(cats)),)
    for c, n in cats.items():
        assert n >= min(FLOOR_PER_CATEGORY, d2["category_population"][c]), \
            "category %s got %d slots, below the floor" % (c, n)
    # within a category the emitted order must follow the stated rank
    for c in cats:
        got = [(-e["indegree"], e["size"], e["identifier"])
               for e in d2["entries"] if e["category"] == c]
        assert got == sorted(got), "category %s is not in (-indegree, size, id) order" % c
    d3 = json.loads(t3)
    assert len(d3["entries"]) == d3["corpus_size"], "tier3 is not the whole corpus"
    ids = [e["identifier"] for e in d3["entries"]]
    assert ids == sorted(set(ids)), "tier3 has duplicates or is unordered"
    assert set(e["identifier"] for e in d2["entries"]) <= set(ids), \
        "tier2 contains an identifier that is not in the corpus"
    print("tier2.json (%d entries, %d categories, floor %d) and tier3.json (%d entries) "
          "match a fresh regeneration and satisfy the stated criterion"
          % (len(d2["entries"]), len(cats), FLOOR_PER_CATEGORY, len(d3["entries"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
