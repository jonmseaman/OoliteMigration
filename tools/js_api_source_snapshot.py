#!/usr/bin/env python3
"""Derive the Oolite JavaScript API surface from the ENGINE SOURCE and emit a deterministic snapshot.

    tools/js_api_source_snapshot.py --out oxp-contract/js-api-source.json
    tools/js_api_source_snapshot.py --check oxp-contract/js-api-source.json   # byte-compare

WHY A SECOND SNAPSHOT, BESIDE tools/js_api_snapshot.py
------------------------------------------------------
tools/js_api_snapshot.py interrogates a LIVE game over the debug console.  It is authoritative
about what SpiderMonkey really installed, but it costs a game launch, it takes the interactive
desktop lock, and -- the reason this file exists -- it CANNOT SEE WRITABILITY FOR NATIVE
PROPERTIES.  Measured on the committed oxp-contract/js-api-1.93.json: Ship.prototype.speed is
recorded with "writable": true, because a native JSPropertySpec with no setter still presents a
writable-looking descriptor through the shim the console sees.  The engine source says the
opposite and the source is right:

    { "speed",  kShip_speed,  OOJS_PROP_READONLY_CB }

That distinction is load-bearing, not cosmetic: bead oo-jou1 exists precisely because `speed` is
READONLY and a scenario tried to assign to it.  A snapshot that reports every property as writable
cannot answer the question those beads ask.

So this snapshot is generated from the declarative property/function tables in
upstream/oolite/src/**/OOJS*.m.  It is offline (no build, no launch, ~1 s), it is exact about
READONLY vs READWRITE, and it records method ARITY from the same tables.  The two snapshots are
complementary and Tier C carries both: the live one for "does the runtime really install this",
this one for "is it writable, and what is its arity".

WHAT IS PARSED, AND WHY IT IS SAFE TO PARSE
-------------------------------------------
The tables are machine-generated-looking C initialisers with a fixed shape:

    static JSClass sShipClass = { "Ship", ... };
    static JSPropertySpec sShipProperties[] = { { "speed", kShip_speed, OOJS_PROP_READONLY_CB }, ... };
    static JSFunctionSpec sShipMethods[]    = { { "canAwardEquipment", ShipCanAwardEquipment, 1 }, ... };

Class NAME comes from the JSClass initialiser's first string, never from the C identifier, so a
rename of the C variable cannot silently rename a JS class in the snapshot.  Tables are bound to
a class by their C identifier prefix (sShipProperties -> sShipClass); a table whose prefix matches
no JSClass in the same file is recorded under a synthetic owner and COUNTED, so it cannot vanish
unnoticed.

ANTI-VACUITY
------------
A regex scraper's characteristic failure is finding nothing and reporting a clean, empty, stable
document -- which byte-compares equal to itself forever.  --check therefore enforces floors
(classes, properties, methods, and the presence of both flag kinds) before it compares anything,
and refuses rather than passing when the fresh scrape is implausibly small.  See FLOORS.
"""

import argparse
import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)
SRC_ROOT = os.path.join(_REPO, "upstream", "oolite", "src")

# Floors: the counts observed on this tree. They are FLOORS, not equalities -- adding an engine
# property must not require editing this file -- but a scrape that finds fewer has broken, and a
# broken scrape that emits a small tidy document is the failure this guards.
FLOORS = {
    "class_count": 28,
    "property_count": 440,
    "method_count": 260,
    "readonly_properties": 250,
    "readwrite_properties": 180,
}

# The property-table flag vocabulary, mapped to the only thing callers care about.
# OOJS_PROP_HIDDEN_READWRITE_CB is writable but not enumerable; recorded distinctly so a future
# change from hidden to visible is a diff rather than a silent equivalence.
_FLAG_ACCESS = {
    "OOJS_PROP_READONLY_CB": ("readonly", True),
    "OOJS_PROP_READWRITE_CB": ("readwrite", True),
    "OOJS_PROP_HIDDEN_READWRITE_CB": ("readwrite", False),
    "OOJS_PROP_READONLY": ("readonly", True),
}

_CLASS_RE = re.compile(
    r"(?:static\s+)?JSClass\s+(?P<ident>\w+)\s*=\s*\{\s*\"(?P<name>[A-Za-z_][\w.]*)\"", re.S)
# The AUTHORITATIVE binding. JS_InitClass names, in order: context, global, parent_proto,
# &clazz, constructor, nargs, ps, fs, static_ps, static_fs. Reading the registration call rather
# than guessing from an identifier prefix means a table that is DEFINED but never REGISTERED is
# not silently promoted into the API, and a class whose C variable is named nothing like its
# tables (gOOEntityJSClass / sEntityProperties) still binds correctly.
_INITCLASS_RE = re.compile(
    r"JS_InitClass\s*\(\s*(?P<args>[^;]*?)\)\s*;", re.S)
_DEFINE_RE = re.compile(
    r"JS_Define(?P<kind>Properties|Functions)\s*\(\s*[^,]+,\s*(?P<target>\w+)\s*,\s*(?P<table>\w+)\s*\)\s*;", re.S)
_TABLE_RE = re.compile(
    r"static\s+JS(?P<kind>PropertySpec|FunctionSpec)\s+(?P<ident>\w+)\s*\[\s*\]\s*=\s*\{(?P<body>.*?)\r?\n\};",
    re.S)
_PROP_ROW_RE = re.compile(
    r"\{\s*\"(?P<name>[^\"]+)\"\s*,\s*(?P<id>[\w+\-]+)\s*,\s*(?P<flags>OOJS_PROP_\w+)\s*\}")
_FUNC_ROW_RE = re.compile(
    r"\{\s*\"(?P<name>[^\"]+)\"\s*,\s*(?P<fn>\w+)\s*,\s*(?P<arity>\d+)\s*(?:,[^}]*)?\}")


def _read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def _iter_sources(root):
    """Every .m and .mm under src/. os.walk deliberately: the repo's grep/search tooling silently returns
    zero matches for upstream/oolite/src, so a search-tool-based scraper here would find nothing
    and report a clean empty snapshot."""
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            if name.endswith((".m", ".mm")):
                yield os.path.join(dirpath, name)


def _split_args(args):
    """Split a C argument list on top-level commas (the arguments here contain calls such as
    JSEntityPrototype(), so a naive split would mis-align every later position)."""
    out, depth, cur = [], 0, []
    for ch in args:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur).strip())
    return out


def _parse_prop_table(body):
    props = {}
    for pm in _PROP_ROW_RE.finditer(body):
        flags = pm.group("flags")
        access, enumerable = _FLAG_ACCESS.get(flags, ("unknown", True))
        props[pm.group("name")] = {
            "access": access,
            "enumerable": enumerable,
            "flags": flags,
            "id": pm.group("id"),
        }
    return props


def _parse_func_table(body):
    return {fm.group("name"): {"arity": int(fm.group("arity")), "native": fm.group("fn")}
            for fm in _FUNC_ROW_RE.finditer(body)}


def scrape(src_root=SRC_ROOT):
    """Walk every .m, then bind tables to classes through their REGISTRATION call sites.

    Two registration shapes exist in this engine and both are handled:
      JS_InitClass(cx, global, parent_proto, &clazz, ctor, nargs, ps, fs, static_ps, static_fs)
      JS_DefineProperties/JS_DefineFunctions(cx, target, table)   -- used for the true global
    A table that is defined but registered by NEITHER is reported as `unregistered_tables` and
    kept out of the API surface, because it is not part of the API."""
    classes = {}           # JS class name -> record
    unregistered = []
    files_with_tables = 0

    for path in _iter_sources(src_root):
        text = _read(path)
        if "JSPropertySpec" not in text and "JSFunctionSpec" not in text:
            continue
        rel = os.path.relpath(path, _REPO).replace(os.sep, "/")
        files_with_tables += 1

        class_names = {m.group("ident"): m.group("name") for m in _CLASS_RE.finditer(text)}
        tables = {}
        for tm in _TABLE_RE.finditer(text):
            kind = tm.group("kind")
            body = tm.group("body")
            tables[tm.group("ident")] = (
                kind, _parse_prop_table(body) if kind == "PropertySpec" else _parse_func_table(body))
        used = set()

        def slot_for(name, parent=None):
            rec = classes.setdefault(name, {
                "source": rel, "prototype_of": parent,
                "properties": {}, "methods": {},
                "static_properties": {}, "static_methods": {}})
            if parent and not rec.get("prototype_of"):
                rec["prototype_of"] = parent
            return rec

        for im in _INITCLASS_RE.finditer(text):
            a = _split_args(im.group("args"))
            if len(a) < 10:
                continue
            cls_ident = a[3].lstrip("&").strip()
            name = class_names.get(cls_ident)
            if name is None:
                continue
            # parent_proto is JSEntityPrototype() / JSShipPrototype() / NULL. Recorded, because
            # "Station inherits Ship's properties" is exactly the question a scenario author asks.
            parent = None
            pm = re.match(r"JS(\w+)Prototype\s*\(", a[2])
            if pm:
                parent = pm.group(1)
            rec = slot_for(name, parent)
            for idx, field in ((6, "properties"), (7, "methods"),
                               (8, "static_properties"), (9, "static_methods")):
                ident = a[idx]
                if ident in ("NULL", "0", "nil"):
                    continue
                entry = tables.get(ident)
                if entry is None:
                    continue
                used.add(ident)
                rec[field].update(entry[1])

        for dm in _DEFINE_RE.finditer(text):
            ident = dm.group("table")
            entry = tables.get(ident)
            if entry is None:
                continue
            used.add(ident)
            # JS_DefineProperties/Functions install onto an existing object, named by the C
            # variable: `global` is the true JS global, `special` is Oolite's SpecialFunctions.
            target = {"global": "<global>"}.get(dm.group("target"), dm.group("target"))
            rec = slot_for(target)
            rec["properties" if entry[0] == "PropertySpec" else "methods"].update(entry[1])

        for ident in sorted(set(tables) - used):
            unregistered.append("%s:%s" % (rel, ident))

    out = {}
    n_props = n_meths = n_ro = n_rw = n_sprops = n_smeths = 0
    for name in sorted(classes):
        e = classes[name]
        rec = {"source": e["source"]}
        if e.get("prototype_of"):
            rec["inherits"] = e["prototype_of"]
        for field in ("properties", "methods", "static_properties", "static_methods"):
            rec[field] = {k: e[field][k] for k in sorted(e[field])}
        n_props += len(rec["properties"])
        n_meths += len(rec["methods"])
        n_sprops += len(rec["static_properties"])
        n_smeths += len(rec["static_methods"])
        n_ro += sum(1 for v in rec["properties"].values() if v["access"] == "readonly")
        n_rw += sum(1 for v in rec["properties"].values() if v["access"] == "readwrite")
        rec["property_count"] = len(rec["properties"])
        rec["method_count"] = len(rec["methods"])
        out[name] = rec

    return {
        "schema": "oolite-js-api-source/1",
        "generator": "tools/js_api_source_snapshot.py",
        "source_root": "upstream/oolite/src",
        "classes": out,
        "summary": {
            "class_count": len(out),
            "files_with_tables": files_with_tables,
            "unregistered_tables": sorted(unregistered),
            "property_count": n_props,
            "method_count": n_meths,
            "static_property_count": n_sprops,
            "static_method_count": n_smeths,
            "readonly_properties": n_ro,
            "readwrite_properties": n_rw,
        },
    }


def serialise(doc):
    """One canonical byte sequence. sort_keys + a fixed separator + a trailing newline, so a
    regeneration on any machine produces the same bytes and a byte-compare is meaningful."""
    return json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def check_floors(doc, out=sys.stderr):
    """Return a list of failure strings. A scrape that found nothing must NOT be allowed to
    byte-compare equal to a committed empty document and call that green.

    Each check below names the SPECIFIC defect it detects, because a count floor is not a content
    check (bead oo-9w5: a floor of 3 cannot tell 5 clauses from 4, and the clause that gets
    dropped is always the awkward one)."""
    s = doc["summary"]
    classes = doc.get("classes", {})
    bad = []
    for key, floor in sorted(FLOORS.items()):
        got = s.get(key)
        if got is None:
            bad.append("summary.%s is missing entirely; the floor cannot be evaluated, which is "
                       "not the same as passing it" % key)
        elif got < floor:
            bad.append("%s: %d, below the floor of %d -- the scraper found less than this tree "
                       "contains, so the snapshot is not a description of the engine" % (key, got, floor))

    # DEFECT: a table defined in the source but registered nowhere would silently either vanish
    # from, or be invented into, the API. Non-empty means the two halves have drifted.
    unreg = s.get("unregistered_tables")
    if unreg is None:
        bad.append("summary.unregistered_tables is missing; the registration audit did not run, "
                   "so a table the engine never installs could be reported as API")
    elif unreg:
        bad.append("%d JSPropertySpec/JSFunctionSpec table(s) are defined but registered by no "
                   "JS_InitClass/JS_DefineProperties call: %s -- either the engine changed how it "
                   "installs them or the parser stopped seeing the registration"
                   % (len(unreg), ", ".join(unreg[:5])))

    # DEFECT: the READONLY/READWRITE distinction collapses. A scraper that mapped every flag to
    # one value passes every count floor above and destroys the only thing this snapshot knows
    # that the live-console snapshot does not.
    ship = classes.get("Ship", {})
    for name, want, why in (
            ("speed", "readonly",
             "bead oo-jou1 exists precisely because Ship.speed is OOJS_PROP_READONLY_CB"),
            ("velocity", "readwrite",
             "it is the canonical OOJS_PROP_READWRITE_CB counterpart to speed"),
    ):
        got = ship.get("properties", {}).get(name)
        if got is None:
            bad.append("Ship.%s is absent; %s, so its disappearance means the Ship property table "
                       "was not parsed" % (name, why))
        elif got["access"] != want:
            bad.append("Ship.%s is recorded as '%s' but the engine declares it %s (%s)"
                       % (name, got["access"], want, why))

    # DEFECT: both access kinds must really appear across the whole document, not just on Ship.
    kinds = {v["access"] for c in classes.values() for v in c.get("properties", {}).values()}
    for want in ("readonly", "readwrite"):
        if want not in kinds:
            bad.append("no property anywhere in the snapshot is '%s'; the flag mapping has "
                       "collapsed to a single value" % want)
    if "unknown" in kinds:
        n = sum(1 for c in classes.values() for v in c.get("properties", {}).values()
                if v["access"] == "unknown")
        bad.append("%d propert(ies) carry access 'unknown': the engine uses an OOJS_PROP_* flag "
                   "this parser does not know, so their writability is unrecorded" % n)

    # DEFECT: prototype inheritance is dropped. Station/PlayerShip inherit Ship's whole surface;
    # a snapshot that loses the link cannot answer "does Station have Ship.velocity".
    for child, parent in (("Station", "Ship"), ("PlayerShip", "Ship"), ("Sun", "Entity")):
        got = classes.get(child, {}).get("inherits")
        if got != parent:
            bad.append("%s.inherits is %r, expected %r; JS_InitClass passes JS%sPrototype() as the "
                       "parent and losing it hides every inherited member"
                       % (child, got, parent, parent))

    # DEFECT: method arity is dropped or zeroed. A snapshot in which every method takes 0
    # arguments passes the method-count floor and is useless for checking a call site.
    arities = [m["arity"] for c in classes.values() for m in c.get("methods", {}).values()]
    if arities and max(arities) < 2:
        bad.append("no method in the snapshot declares an arity of 2 or more (max %d); the arity "
                   "column of the JSFunctionSpec tables is not being read" % max(arities))
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", help="write the snapshot here")
    ap.add_argument("--check", help="byte-compare this committed snapshot against a fresh scrape")
    ap.add_argument("--src-root", default=SRC_ROOT)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not args.out and not args.check:
        ap.error("one of --out or --check is required")

    if not os.path.isdir(args.src_root):
        print("js-api-source: no engine source at %s" % args.src_root, file=sys.stderr)
        return 2

    doc = scrape(args.src_root)
    fresh = serialise(doc)
    bad = check_floors(doc)

    if args.out:
        if bad:
            for b in bad:
                print("js-api-source: REFUSED to write: %s" % b, file=sys.stderr)
            return 2
        with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(fresh)
        if not args.quiet:
            s = doc["summary"]
            print("js-api-source: wrote %s (%d bytes): %d classes, %d properties "
                  "(%d readonly / %d readwrite), %d methods"
                  % (args.out, len(fresh), s["class_count"], s["property_count"],
                     s["readonly_properties"], s["readwrite_properties"], s["method_count"]))
        return 0

    # --check
    if bad:
        for b in bad:
            print("js-api-source: REFUSED (rc=2, 'I cannot tell you'): %s" % b, file=sys.stderr)
        return 2
    if not os.path.isfile(args.check):
        print("js-api-source: REFUSED (rc=2): no committed snapshot at %s" % args.check,
              file=sys.stderr)
        return 2
    with open(args.check, "r", encoding="utf-8", newline="") as fh:
        committed = fh.read()
    if committed != fresh:
        print("js-api-source: STALE -- the committed snapshot does not match a fresh scrape of "
              "the engine source: committed %d bytes, fresh %d bytes"
              % (len(committed), len(fresh)), file=sys.stderr)
        try:
            cdoc = json.loads(committed)
        except Exception:
            print("js-api-source: the committed file is not even valid JSON", file=sys.stderr)
            return 1
        cc, fc = cdoc.get("classes", {}), doc["classes"]
        for name in sorted(set(cc) ^ set(fc)):
            print("  class only in %s: %s" % ("committed" if name in cc else "source", name),
                  file=sys.stderr)
        shown = 0
        for name in sorted(set(cc) & set(fc)):
            for kind in ("properties", "methods"):
                a, b = cc[name].get(kind, {}), fc[name].get(kind, {})
                for k in sorted(set(a) ^ set(b)):
                    print("  %s.%s only in %s" % (name, k, "committed" if k in a else "source"),
                          file=sys.stderr)
                    shown += 1
                for k in sorted(set(a) & set(b)):
                    if a[k] != b[k]:
                        print("  %s.%s changed: %s -> %s" % (name, k, a[k], b[k]), file=sys.stderr)
                        shown += 1
                    if shown > 40:
                        print("  ... (truncated)", file=sys.stderr)
                        return 1
        return 1
    if not args.quiet:
        s = doc["summary"]
        print("js-api-source: OK, committed snapshot is byte-identical to a fresh scrape "
              "(%d bytes, %d classes, %d properties [%d readonly / %d readwrite], %d methods)"
              % (len(fresh), s["class_count"], s["property_count"], s["readonly_properties"],
                 s["readwrite_properties"], s["method_count"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
