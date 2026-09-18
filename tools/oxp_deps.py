#!/usr/bin/env python3
"""Dependency closure + per-expansion error attribution for the OXP corpus (bead oo-kcrw).

WHY THIS FILE EXISTS
--------------------
bead oo-het measured that `tools/corpus.sh tier1` is honestly RED: 7 of 36
expansions came back NOTLOADED, absent from the `[searchPaths.dumpAll]` block,
and the correlation with a non-empty `requires_oxps` was perfect.

That diagnosis was RE-VERIFIED here, from scratch, before any code was written.
Two launches of the SAME expansion on the SAME build, differing only in whether
its declared dependency was staged next to it:

    === solo: staged ['oolite.oxp.Svengali.GNN'] ; primary=oolite.oxp.Svengali.GNN
        rc=0 wall=10.4s verdict=NOTLOADED
        'oolite.oxp.Svengali.GNN.oxz' is ABSENT from the [searchPaths.dumpAll]
        Resource paths block ... (block listed 5 path(s): Resources, AddOns,
        AddOns, oo-het-sentinel.oxp, Basic-debug.oxp)
        LOG> [oxp.requirementMissing]: OXP oolite.oxp.Svengali.GNN.oxz had unmet
             requirements and was removed from the loading list

    === closure: staged ['oolite.oxp.Svengali.GNN', 'oolite.oxp.Svengali.Library']
        rc=0 wall=14.8s verdict=PASS
        loaded (named in searchPaths.dumpAll), reached shipData.load.begin and
        startup.complete, 91 log lines, 0 ERROR lines

So the fix is composition, not a weaker predicate: stage each expansion together
with the TRANSITIVE closure of its `requires_oxps`.

THE FOUR HAZARDS THIS MODULE IS BUILT AROUND
--------------------------------------------
1. `requires_oxps` names an IDENTIFIER, never a filename, and the byte cache is
   content-addressed (no filenames at all).  So a closure walk is impossible
   without an identifier -> cached-blob index, built by reading the top-level
   manifest.plist out of every cached OXZ.  `build_index()` does that in ~1.2 s
   for 814 expansions, which is cheap enough for an acceptance line.
2. A dependency may be ABSENT from the corpus entirely.  That is NOT a load
   failure and must never be reported as one - the expansion never got a chance
   to load.  `closure()` returns those separately as `missing`, and the runner
   reports the group UNSATISFIABLE without launching the game.
3. The dependency graph MAY CONTAIN CYCLES (A requires B requires A).  A naive
   recursive walk hangs or blows the stack.  The walk here is iterative with a
   visited set, so a cycle terminates and yields each node exactly once.
4. Loading a SET changes what a failure means.  If A loads fine but its
   dependency B emits an error, saying "A FAILED" sends the next reader to audit
   the wrong expansion.  `attribute_errors()` assigns every error line to the
   expansion that owns it, and the runner reports DEPERRORS (still a failure,
   never green) naming B rather than ERRORS naming A.

Usage:
    python3 tools/oxp_deps.py index   [--out FILE]      # identifier -> record
    python3 tools/oxp_deps.py closure IDENT [IDENT ...] # print the closure
    python3 tools/oxp_deps.py tier1                     # closure of every tier1 entry
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import oxp_corpus as oc  # noqa: E402
import oxp_tier1 as t1  # noqa: E402

MANIFEST = REPO_ROOT / "tools" / "oxp-corpus" / "manifest.json"
TIER1_JSON = REPO_ROOT / "tools" / "oxp-corpus" / "tier1.json"
COMPANIONS_JSON = REPO_ROOT / "tools" / "oxp-corpus" / "companions.json"

#: the label used for an error line no staged expansion claims. It is NEVER
#: silently folded into the primary: an error nobody owns is a finding about the
#: harness or the engine and must be visible as such.
UNATTRIBUTED = "(unattributed)"


# ------------------------------------------------------------------ the index


def build_index(manifest_path: Path = MANIFEST, cache: Path | None = None) -> dict:
    """identifier -> record, over every cached corpus expansion.

    Newest version wins when the catalogue carries several versions of one
    identifier - the same rule oxp_tier1.build_graph uses, for the same reason
    (a prolific re-releaser must not get several nodes).
    """
    index: dict[str, dict] = {}
    for url, entry, man in t1.read_manifests(manifest_path, cache):
        ident = str(man["identifier"]).strip()
        version = str(man.get("version", ""))
        rec = {
            "identifier": ident,
            "title": str(man.get("title", ident)),
            "version": version,
            "url": url,
            "size": int(entry.get("size") or 0),
            "sha256": entry.get("sha256", ""),
            "requires": t1._dep_ids(man, "requires_oxps"),
            "optional": t1._dep_ids(man, "optional_oxps"),
        }
        prev = index.get(ident)
        if prev is None or t1._vkey(version) > t1._vkey(prev["version"]):
            index[ident] = rec
    return index


def blob_for(index: dict, ident: str, cache: Path | None = None) -> Path:
    """The cached blob holding `ident`. The cache is content-addressed, so the
    file on disk has no name; the caller stages it under `<identifier>.oxz`
    because Oolite dispatches on the EXTENSION (ResourceManager.m:290-310)."""
    cache = cache or t1.cache_dir()
    return oc.blob_path(cache, index[ident]["url"])


# ---------------------------------------------------------------- the closure


def closure(index: dict, root: str, companions: dict | None = None,
            follow_optional: bool = False) -> tuple[list[str], list[str]]:
    """Transitive `requires_oxps` closure of `root`.

    Returns (order, missing):
      order   - `root` first, then every transitively required identifier that
                EXISTS in the index, in deterministic discovery order.
      missing - identifiers named as requirements that are NOT in the corpus,
                deduplicated and sorted. These are UNSATISFIABLE, which is a
                different fact from "failed to load" and is reported as such.

    CYCLE SAFETY. The walk is iterative over an explicit stack with a `seen`
    set consulted BEFORE a node is expanded, so A->B->A terminates and yields
    A and B exactly once. There is no recursion, so a long chain cannot blow the
    stack either. `tools/test_oxp_deps.py` pins both a 2-cycle and a 3-cycle and
    a self-edge.

    `companions` is the curated non-declared-dependency table (companions.json):
    a documented, per-identifier list of expansions that an OXP genuinely needs
    but does not declare in requires_oxps. It participates in the walk exactly
    like a declared requirement, so a companion's own requirements are followed
    too. It is data with a written reason, not a silenced error.
    """
    companions = companions or {}
    order: list[str] = []
    missing: set[str] = set()
    seen: set[str] = set()
    stack = [root]
    # TWO CYCLE BRAKES, and they are not redundant - each covers a case the
    # other does not, and the mutation harness removes BOTH to make a cycle
    # actually hang (removing either alone still terminates, which is exactly
    # why a one-sided mutant would have been a false proof):
    #   (a) the POP-time check below: a node queued twice before it is expanded
    #       (the diamond A->B,C->D) is expanded once, so D is staged once and
    #       cannot collide with itself in the AddOns dir;
    #   (b) the APPEND-time check at the bottom: an already-expanded node is
    #       never re-queued, which is what stops A<->B looping forever.
    while stack:
        ident = stack.pop(0)
        if ident in seen:
            continue                      # <- cycle brake (a), pop-time
        seen.add(ident)
        rec = index.get(ident)
        if rec is None:
            if ident == root:
                # The ROOT itself is not in the corpus: the caller asked for
                # something we do not have. Report it as missing, not as a
                # loadable group.
                missing.add(ident)
                continue
            missing.add(ident)
            continue
        order.append(ident)
        deps = list(rec["requires"])
        if follow_optional:
            deps += list(rec["optional"])
        deps += list(companions.get(ident, {}).get("requires", []))
        for dep in deps:
            if dep and dep != ident and dep not in seen:
                stack.append(dep)         # <- cycle brake (b), append-time
    return order, sorted(missing)


def load_companions(path: Path = COMPANIONS_JSON) -> dict:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return data.get("companions", {})


# ------------------------------------------------------------- attribution


def owner_tokens(rec: dict, staged_name: str) -> list[str]:
    """The strings an Oolite log line uses to name this expansion.

    Read off the three shapes the product actually emits:
      * a PATH containing the staged filename, e.g.
        "[plist.parse.failed]: Failed to parse .../<staged>.oxz/Config/..."
      * the IDENTIFIER, e.g. "[oxp.requirementMissing]: OXP <staged> ..."
      * the TITLE plus version, e.g.
        "[script.javaScript.exception.notDefined]: ... (oo-het-broken 1.0): ..."
    """
    toks = [staged_name]
    for key in ("identifier", "title"):
        v = str((rec or {}).get(key) or "").strip()
        if v and v not in toks:
            toks.append(v)
    return [t for t in toks if t]


def attribute_errors(lines, owners) -> dict:
    """Assign each error line to the expansion that owns it.

    `owners` is an ordered list of {"label": str, "tokens": [str, ...]}.
    Returns {label: [lines]}, plus UNATTRIBUTED for lines no owner claims.

    LONGEST TOKEN WINS. "Xenon UI" is a substring of "Xenon UI Resources Pack A",
    so a first-match-wins scan would credit every resource-pack error to XenonUI
    and quietly mis-attribute exactly the case this bead exists to get right.
    Matching is case-insensitive because the log renders paths in whatever case
    the filesystem gave it.
    """
    out = {UNATTRIBUTED: []}
    for o in owners:
        out.setdefault(o["label"], [])
    for line in lines:
        low = line.lower()
        best_label, best_len = None, 0
        for o in owners:
            for tok in o["tokens"]:
                if tok and tok.lower() in low and len(tok) > best_len:
                    best_label, best_len = o["label"], len(tok)
        out[best_label if best_label else UNATTRIBUTED].append(line)
    return out


# -------------------------------------------------------------------- plan


def tier1_groups(tier1_path: Path = TIER1_JSON, index: dict | None = None,
                 companions: dict | None = None, cache: Path | None = None) -> list[dict]:
    """One group per Tier 1 catalogue entry: primary + its closure.

    Test-oxps are in-tree directories with no manifest and no dependencies; they
    are emitted as single-member groups so the tier still checks them and still
    reports their real (currently failing) verdict.
    """
    index = build_index(cache=cache) if index is None else index
    companions = load_companions() if companions is None else companions
    cache = cache or t1.cache_dir()
    data = json.loads(Path(tier1_path).read_text(encoding="utf-8"))
    groups = []
    for e in data["catalogue"]:
        ident = e["identifier"]
        order, missing = closure(index, ident, companions)
        members = []
        for dep in order:
            members.append({
                "identifier": dep,
                "staged_as": dep + ".oxz",
                "path": str(blob_for(index, dep, cache)).replace("\\", "/"),
                "title": index[dep]["title"],
                "role": "primary" if dep == ident else "dependency",
            })
        groups.append({
            "name": ident,
            "primary": ident,
            "members": members,
            "missing": missing,
            "companions": companions.get(ident, {}).get("requires", []),
            "companion_reason": companions.get(ident, {}).get("reason", ""),
        })
    for t in data.get("test_oxps", []):
        groups.append({
            "name": t["name"],
            "primary": t["name"],
            "members": [{
                "identifier": t["name"], "staged_as": t["name"],
                "path": str((REPO_ROOT / t["path"])).replace("\\", "/"),
                "title": t["name"], "role": "primary",
            }],
            "missing": [], "companions": [], "companion_reason": "",
        })
    return groups


# --------------------------------------------------------------------- CLI


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("index"); p.add_argument("--out", default="")
    p = sub.add_parser("closure"); p.add_argument("ident", nargs="+")
    p = sub.add_parser("tier1"); p.add_argument("--json", default="")
    args = ap.parse_args(argv)

    if args.cmd == "index":
        idx = build_index()
        if args.out:
            Path(args.out).write_text(json.dumps(idx, indent=1), encoding="utf-8")
        print("index: %d identifiers, %d with requires_oxps"
              % (len(idx), sum(1 for r in idx.values() if r["requires"])))
        return 0

    if args.cmd == "closure":
        idx = build_index()
        comp = load_companions()
        for ident in args.ident:
            order, missing = closure(idx, ident, comp)
            print("%s:" % ident)
            for d in order:
                print("    %-9s %s" % ("primary" if d == ident else "dep", d))
            for m in missing:
                print("    MISSING   %s  (not in the 818-expansion corpus)" % m)
        return 0

    groups = tier1_groups()
    unsat = [g for g in groups if g["missing"]]
    if args.json:
        Path(args.json).write_text(json.dumps(groups, indent=2) + "\n", encoding="utf-8")
    for g in groups:
        deps = [m["identifier"] for m in g["members"] if m["role"] == "dependency"]
        print("%-52s members=%d deps=%s%s"
              % (g["name"], len(g["members"]), len(deps),
                 ("  UNSATISFIABLE: " + ", ".join(g["missing"])) if g["missing"] else ""))
    print("--- %d group(s), %d with unsatisfiable requirements ---"
          % (len(groups), len(unsat)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
