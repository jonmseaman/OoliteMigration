#!/usr/bin/env python3
"""Classify and CLUSTER the results of a Tier 2/Tier 3 corpus load run (bead oo-4z6).

WHY "GROUP BY FIRST ERROR LINE" IS NOT ENOUGH ON ITS OWN
-------------------------------------------------------
The bead's definition of done is "a report grouping failures by first error
line".  Taken literally that produces N groups for N failures and is not a
report, it is a list with extra ceremony.  Every error line Oolite writes
carries at least one volatile part:

    03:35:59.439 [plist.parse.failed]: Failed to parse
        C:/Users/jon/AppData/Local/Temp/oo-4z6.9184/runs/Foo_1.2/AddOns/Foo.oxz/
        Config/shipdata.plist as a property list.

The timestamp differs per line, the work directory differs per RUN, and the
expansion name differs per EXPANSION - so the same defect in fifty expansions
yields fifty distinct "first error lines".  Grouping must therefore happen on a
NORMALISED key, in the same spirit as the enumeration-order detector on main.

WHAT IS NORMALISED, AND WHY EACH ONE
------------------------------------
  TIME    leading "HH:MM:SS.mmm"            -> dropped         (per line)
  NAME    the expansion's own identifier,   -> <OXP>           (per expansion)
          title and staged filename, and
          any *.oxz / *.oxp path component
  PATH    anything that looks like a path   -> <PATH>          (per run/machine)
  HEX     0x…                               -> <HEX>           (per process)
  NUM     bare integers and decimals        -> <N>             (per run)
  WS      runs of whitespace                -> one space

NOTHING ELSE IS TOUCHED.  The channel name, the message wording and the
grammatical structure all survive, which is what keeps genuinely different
failures in genuinely different clusters.  The two-directional property is
asserted by tools/corpus.sh selftest2 against committed fixtures:

  * failures differing ONLY in timestamp, path, address, number and expansion
    name collapse into ONE cluster;
  * failures differing in channel or in message wording stay SEPARATE.

THE SIX REPORTED STATES.  Only the last is a pass, and the middle four are all
different things that a naive runner would conflate:

  NOTCACHED      the expansion is not in the content-addressed cache.  Not a
                 verdict about the expansion: the corpus is incomplete.
  STAGEFAIL      the harness could not copy it into the private AddOns dir.
                 THIS IS A HARNESS BUG AND IT IS LOUD.  An earlier unchecked cp
                 in a staging loop surfaced twenty lines later as a bogus
                 "missing expansion" and sent an agent hunting the cache.
  NOTLOADED_DEPS the game rejected it AND its manifest declares requires_oxps
                 that were not staged alongside it.  This is the known open
                 finding owned by bead oo-kcrw: solo loading is structurally
                 wrong for a dependency-bearing expansion.  Expected at scale,
                 reported separately, NEVER silently green and never counted as
                 a real failure.
  NOTLOADED      the game rejected it and it declares NO dependencies, so the
                 dependency explanation does not apply.  A real finding.
  ERRORS         it loaded and then logged errors.  These are the ones that get
                 clustered.
  PASS           loaded clean.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

# ------------------------------------------------------------------- states
NOTCACHED = "NOTCACHED"
STAGEFAIL = "STAGEFAIL"
NOTLOADED_DEPS = "NOTLOADED_DEPS"
NOTLOADED = "NOTLOADED"
ERRORS = "ERRORS"
PASS = "PASS"
#: everything the load check can say that is neither of the above: LAUNCH, LOG,
#: NOSHIPDATA, STARTUP, NOSENTINEL.  All harness/environment failures.
HARNESS = "HARNESS"

STATE_ORDER = [STAGEFAIL, HARNESS, NOTCACHED, ERRORS, NOTLOADED, NOTLOADED_DEPS, PASS]

STATE_HELP = {
    NOTCACHED: "NOT CACHED - absent from the corpus cache; no verdict is possible",
    STAGEFAIL: "FAILED TO STAGE - a HARNESS BUG; the run is not trustworthy",
    HARNESS: "HARNESS/ENVIRONMENT - the game did not run far enough to judge",
    NOTLOADED_DEPS: "NOTLOADED, UNMET DEPENDENCIES - known finding, bead oo-kcrw",
    NOTLOADED: "NOTLOADED, no declared dependencies - a real rejection",
    ERRORS: "LOADED WITH ERRORS - clustered below",
    PASS: "LOADED CLEAN",
}

#: these states make the run fail
FAILING = {STAGEFAIL, HARNESS, NOTCACHED, ERRORS, NOTLOADED}

# --------------------------------------------------------------- normalise
_TIME_RE = re.compile(r"^\s*\d\d:\d\d:\d\d\.\d+\s*")
_HEX_RE = re.compile(r"\b0x[0-9a-fA-F]+\b")
# A path: a drive letter or a leading slash, or any token containing a slash and
# a dot.  Deliberately greedy about slashes so a whole path collapses to one token.
_PATH_RE = re.compile(r"(?:[A-Za-z]:)?[\\/][^\s,;:\"')\]]*")
_OXPPATH_RE = re.compile(r"\S*\.ox[zp]\b", re.I)
_NUM_RE = re.compile(r"(?<![<\w])\d+(?:\.\d+)?(?![\w>])")
#: A dotted version ("1.9.2" vs "0.14") normalises to <N>.<N>.<N> vs <N>.<N> and
#: would otherwise split one defect into one cluster per version SHAPE. Collapse
#: any run of dotted numbers to a single <N>.
_VERSION_RE = re.compile(r"(?:<N>\.)+<N>")
_WS_RE = re.compile(r"\s+")


def normalise(line: str, names=()) -> str:
    """Reduce an error line to its volatile-free shape (see the module docstring)."""
    s = _TIME_RE.sub("", line.rstrip())
    # Expansion-specific tokens go FIRST: an identifier can contain dots and
    # would otherwise be half-eaten by the path rule and land in its own cluster.
    for name in sorted({n for n in names if n}, key=len, reverse=True):
        if len(name) >= 3:
            s = re.sub(re.escape(name), "<OXP>", s, flags=re.I)
    s = _OXPPATH_RE.sub("<OXP>", s)
    s = _HEX_RE.sub("<HEX>", s)
    s = _PATH_RE.sub("<PATH>", s)
    s = _NUM_RE.sub("<N>", s)
    s = _VERSION_RE.sub("<N>", s)
    return _WS_RE.sub(" ", s).strip()


def names_of(rec: dict) -> list:
    """Volatile per-expansion tokens to blank out of that expansion's error lines."""
    out = []
    for key in ("identifier", "name", "staged_as", "title"):
        v = rec.get(key)
        if isinstance(v, str) and v:
            out.append(v)
            out.append(re.sub(r"\.ox[zp]$", "", v, flags=re.I))
    return out


# --------------------------------------------------------------- classify
def classify(rec: dict) -> str:
    """Map one raw result record onto one of the six reported states."""
    v = str(rec.get("verdict", "")).upper()
    if v in (NOTCACHED, "MISSING"):
        return NOTCACHED
    if v in (STAGEFAIL, "STAGEFAIL"):
        return STAGEFAIL
    if v == "PASS":
        return PASS
    if v == "ERRORS":
        return ERRORS
    if v == "NOTLOADED":
        # THE oo-kcrw SPLIT.  A rejected expansion that declares dependencies it
        # was not given is a different animal from one that declares none.
        return NOTLOADED_DEPS if rec.get("requires") else NOTLOADED
    return HARNESS


def first_error(rec: dict) -> str:
    errs = rec.get("errors") or []
    return errs[0] if errs else (rec.get("detail") or "")


def build(records: list) -> dict:
    by_state = OrderedDict((s, []) for s in STATE_ORDER)
    for rec in records:
        by_state[classify(rec)].append(rec)

    clusters = {}
    for rec in by_state[ERRORS]:
        key = normalise(first_error(rec), names_of(rec))
        c = clusters.setdefault(key, {"key": key, "count": 0, "members": [],
                                      "sample": first_error(rec)})
        c["count"] += 1
        c["members"].append(rec.get("identifier") or rec.get("name") or "?")
    ordered = sorted(clusters.values(), key=lambda c: (-c["count"], c["key"]))
    for c in ordered:
        c["members"].sort()
    return {
        "total": len(records),
        "counts": {s: len(by_state[s]) for s in STATE_ORDER},
        "states": {s: [r.get("identifier") or r.get("name") or "?" for r in by_state[s]]
                   for s in STATE_ORDER},
        "clusters": ordered,
        "failing": sum(len(by_state[s]) for s in FAILING),
    }


def render(report: dict, details: dict | None = None) -> str:
    out = []
    out.append("=== OXP corpus load report: %d expansion(s) ===" % report["total"])
    out.append("")
    for s in STATE_ORDER:
        n = report["counts"][s]
        out.append("%-16s %5d   %s" % (s, n, STATE_HELP[s]))
    out.append("")
    if report["counts"][STAGEFAIL]:
        out.append("!! %d STAGEFAIL: the harness could not stage these. This is a HARNESS BUG,"
                   % report["counts"][STAGEFAIL])
        out.append("!! not a fact about the expansions. Results below are not trustworthy.")
        for i in report["states"][STAGEFAIL]:
            out.append("   STAGEFAIL %s" % i)
        out.append("")
    if report["counts"][HARNESS]:
        for i in report["states"][HARNESS]:
            out.append("   HARNESS   %s" % i)
        out.append("")
    if report["counts"][NOTCACHED]:
        for i in report["states"][NOTCACHED]:
            out.append("   NOTCACHED %s" % i)
        out.append("")
    if report["counts"][NOTLOADED_DEPS]:
        out.append("-- %d NOTLOADED_DEPS (bead oo-kcrw: solo loading is structurally wrong for"
                   % report["counts"][NOTLOADED_DEPS])
        out.append("-- a dependency-bearing expansion). Reported, NOT counted as a real failure,")
        out.append("-- and NOT green: %s" % ", ".join(report["states"][NOTLOADED_DEPS][:8])
                   + (" ..." if report["counts"][NOTLOADED_DEPS] > 8 else ""))
        out.append("")
    if report["counts"][NOTLOADED]:
        out.append("-- %d NOTLOADED with NO declared dependencies - the dependency explanation"
                   % report["counts"][NOTLOADED])
        out.append("-- does not apply, so these are real rejections:")
        for i in report["states"][NOTLOADED]:
            out.append("   NOTLOADED %s" % i)
        out.append("")

    out.append("=== %d LOADED-WITH-ERRORS failure(s) in %d cluster(s), by normalised first "
               "error line ===" % (report["counts"][ERRORS], len(report["clusters"])))
    for n, c in enumerate(report["clusters"], 1):
        out.append("")
        out.append("cluster %d  x%d  %s" % (n, c["count"], c["key"]))
        out.append("  sample: %s" % c["sample"].strip())
        out.append("  members: %s" % ", ".join(c["members"][:12])
                   + (" ..." if len(c["members"]) > 12 else ""))
    out.append("")
    out.append("--- %d checked, %d failing (%d pass, %d unmet-deps not counted) ---"
               % (report["total"], report["failing"], report["counts"][PASS],
                  report["counts"][NOTLOADED_DEPS]))
    return "\n".join(out)


def load_results(path: Path) -> list:
    """Read either a JSON array (oxp_load_check --json) or a JSONL state stream."""
    text = path.read_text(encoding="utf-8", errors="replace").strip()
    if not text:
        return []
    if text.lstrip().startswith("["):
        return json.loads(text)
    return [json.loads(ln) for ln in text.splitlines() if ln.strip()]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", required=True,
                    help="results.json (array) or a state JSONL file/directory")
    ap.add_argument("--json", default="", help="also write the report as JSON here")
    args = ap.parse_args(argv)

    p = Path(args.results)
    if p.is_dir():
        records = []
        for f in sorted(p.glob("*.json")):
            records.extend(load_results(f))
    elif not p.exists():
        sys.stderr.write("no results at %s\n" % args.results)
        return 2
    else:
        records = load_results(p)
    if not records:
        sys.stderr.write("results set is EMPTY - refusing to report success on zero checks\n")
        return 2

    report = build(records)
    print(render(report))
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 1 if report["failing"] else 0


if __name__ == "__main__":
    sys.exit(main())
