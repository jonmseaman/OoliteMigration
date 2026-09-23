#!/usr/bin/env python3
"""tools/js_api_surface_compare.py -- does a JS API snapshot keep Oolite's own API surface?
(Phase 1 bead oo-1gc.6, ADR-0024.)

    python3 tools/js_api_surface_compare.py <baseline.json> <candidate.json>

oxp-contract/js-api-1.93.json records EVERYTHING the SpiderMonkey 1.8.5 game exposed, including
the ECMAScript library of a 2011 engine. Under QuickJS-ng that library is ES2023 and cannot
reproduce byte for byte; what expansions are written against -- and what the migration promises
to keep (contract C4, architecture §5) -- is the surface Oolite itself installs. This compares
exactly that:

  * every Oolite global in the baseline exists in the candidate, with the same type and class name;
  * every member (own, prototype, static) of it exists, with the same kind -- a data property and
    an accessor are the same kind here, since both engines implement Oolite's native properties
    through a getter hook and only the descriptor representation differs -- and the same
    writability, enumerability and (for methods) arity.

The engine's own function properties (arguments, arity, caller) and the ECMAScript globals are
out of scope; their changes are the documented language-level changes in
docs/EXPANSION_MIGRATION.md. Additions in the candidate are reported but do not fail.

Exit codes follow the repo convention: 0 = the Oolite surface is kept, 1 = a real difference,
2 = refused (an input is missing or unreadable).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from js_api_snapshot import ECMA_GLOBALS  # noqa: E402

ENGINE_FUNCTION_PROPS = {"arguments", "arity", "caller"}
# SpiderMonkey's Object.prototype watchpoints: engine-provided on every plain object, removed with
# the engine (docs/EXPANSION_MIGRATION.md); no Oolite object defines them.
ENGINE_OBJECT_PROTO_EXTENSIONS = {"watch", "unwatch"}


def load(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))["globals"]
    except (OSError, ValueError, KeyError) as e:
        print(f"js_api_surface_compare: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)


def norm_kind(kind):
    return "property" if kind in ("property", "accessor") else kind


def member_problems(where, a, b):
    out = []
    if norm_kind(a.get("kind")) != norm_kind(b.get("kind")):
        out.append(f"{where}: kind {a.get('kind')} -> {b.get('kind')}")
        return out
    for field in ("writable", "enumerable"):
        if field in a and field in b and a[field] != b[field]:
            out.append(f"{where}: {field} {a[field]} -> {b[field]}")
    if a.get("kind") == "method" and a.get("arity") != b.get("arity"):
        out.append(f"{where}: arity {a.get('arity')} -> {b.get('arity')}")
    return out


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    base, cand = load(argv[1]), load(argv[2])
    problems, added = [], []
    for name in sorted(base):
        if name in ECMA_GLOBALS:
            continue
        if name not in cand:
            problems.append(f"{name}: missing")
            continue
        a, b = base[name], cand[name]
        for field in ("type", "class_name", "is_class"):
            if a.get(field) != b.get(field):
                problems.append(f"{name}: {field} {a.get(field)!r} -> {b.get(field)!r}")
        for section in ("own_members", "prototype_members", "statics"):
            am, bm = a.get(section) or {}, b.get(section) or {}
            if name == "global" and section == "prototype_members":
                # Object.prototype's ECMAScript builtins (the QuickJS-ng build interposes its
                # scope-chain fallback there, ADR-0022/oo-1gc.4): not Oolite's surface.
                continue
            for member in sorted(am):
                if member in ENGINE_FUNCTION_PROPS or (section == "statics" and member in ("length", "name")):
                    continue
                if member in ENGINE_OBJECT_PROTO_EXTENSIONS and section == "prototype_members":
                    continue
                if name == "global" and section == "own_members" and member in ECMA_GLOBALS:
                    continue   # the engine's language-level globals, listed again as own members of `global`
                if am[member].get("kind") == "native-opaque":
                    # The baseline engine could not describe it (its getter threw on the bare
                    # prototype): presence is all there is to compare.
                    if member not in bm:
                        problems.append(f"{name}.{section}.{member}: missing")
                    continue
                if member not in bm:
                    problems.append(f"{name}.{section}.{member}: missing")
                    continue
                problems += member_problems(f"{name}.{section}.{member}", am[member], bm[member])
            added += [f"{name}.{section}.{m}" for m in sorted(bm) if m not in am and m not in ENGINE_FUNCTION_PROPS]
    added += [n for n in sorted(cand) if n not in base and n not in ECMA_GLOBALS]
    for p in problems:
        print(f"DIFF  {p}")
    for a in added:
        print(f"added {a}")
    print(f"js_api_surface_compare: {len(problems)} difference(s) in the Oolite API surface, {len(added)} addition(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
