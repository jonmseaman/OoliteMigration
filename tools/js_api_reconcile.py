#!/usr/bin/env python3
"""tools/js_api_reconcile.py -- cross-check the SOURCE-derived JS API snapshot against the
RUNTIME-derived one (bead oo-j4u).

WHY BOTH EXIST, AND WHY THIS IS NOT A DUPLICATE
-----------------------------------------------
oxp-contract/js-api-1.93.json is produced by tools/js-api-snapshot.sh by ENUMERATING A LIVE
INTERPRETER. It proves what actually resolves in a running game. It needs a build, a desktop lock
and ~30 s.

oxp-contract/js-api-source.json is produced by tools/js_api_source_snapshot.py by PARSING THE
DECLARATIVE TABLES in upstream/oolite/src/**/OOJS*.m, e.g.

    { "speed",    kShip_speed,    OOJS_PROP_READONLY_CB  },
    { "velocity", kShip_velocity, OOJS_PROP_READWRITE_CB },

It proves what the engine INTENDS, it is offline, and it takes under a second.

A NOTE ON A CLAIM WORTH CORRECTING, BECAUSE IT CHANGES THE DESIGN
-----------------------------------------------------------------
It is natural to assume the runtime artifact cannot answer mutability questions -- searching it for
"readonly"/"READONLY" finds nothing, and "Ship" is a constructor rather than a global instance.
Both observations are true and the conclusion drawn from them is not. The runtime artifact records
mutability under the ECMAScript property-descriptor name, `writable`, inside each class's
`prototype_members`, and `Ship` IS present in `globals` as a class object. Verified on the
committed artifact:

    globals.Ship.prototype_members.speed     -> {"kind": "property", "writable": false, ...}
    globals.Ship.prototype_members.velocity  -> {"kind": "property", "writable": true,  ...}

which is exactly the OOJS_PROP_READONLY_CB / OOJS_PROP_READWRITE_CB distinction that makes bead
oo-jou1 real. So the two snapshots ARE directly comparable, and this file is that comparison
rather than a workaround for its absence.

WHAT A DISAGREEMENT MEANS
-------------------------
  source-only  a property the engine declares that the live interpreter did not expose. Either the
               table is not registered on the class, or it is gated behind a build flag, or the
               runtime snapshot was taken from a different version.
  runtime-only a property that resolves at runtime with no declarative table entry -- typically
               inherited, a JS-side addition, or defined by a mechanism this parser does not model.
  mutability   the engine declares READONLY and the interpreter reports writable, or vice versa.
               This is the most interesting class of finding: it is the one an OXP author can be
               actively misled by, and the reason bead oo-jou1 exists.

Exit codes follow the repo convention (bead oo-jor): 0 = verified, 1 = a real discrepancy against
the committed expectation, 2 = REFUSED (an input is missing or unreadable). A refusal is never a
pass.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
SOURCE_SNAPSHOT = REPO / "oxp-contract" / "js-api-source.json"
RUNTIME_SNAPSHOT = REPO / "oxp-contract" / "js-api-1.93.json"
BASELINE = REPO / "oxp-contract" / "js-api-reconciliation.json"

# ANTI-VACUITY. A reconciliation that compared nothing would agree perfectly. These are the minimum
# numbers of things that must actually have been compared for the verdict to mean anything; they
# are below today's observed values so that adding a class or property never requires editing this.
MIN_CLASSES_COMPARED = 20
MIN_PROPS_COMPARED = 250


def refuse(msg: str) -> "NoReturn":  # type: ignore[valid-type]
    print(f"js-api-reconcile: REFUSED: {msg}", file=sys.stderr)
    sys.exit(2)


def load(path: Path, what: str) -> dict:
    if not path.is_file():
        refuse(f"the {what} snapshot {path} does not exist; a reconciliation with one side missing "
               f"would compare nothing and agree perfectly")
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        refuse(f"the {what} snapshot {path} is not valid JSON: {exc}")
    if not isinstance(doc, dict) or not doc:
        refuse(f"the {what} snapshot {path} is empty or not an object")
    return doc


def runtime_properties(runtime: dict, cls: str) -> tuple[dict[str, bool], set[str]] | None:
    """Return ({property_name: writable}, {opaque_names}) for a class in the runtime snapshot, or
    None if the class is not present there at all.

    THE `native-opaque` CASE IS THE WHOLE POINT OF THE SOURCE SNAPSHOT, so it is classified
    separately rather than being lumped in with "absent". The live enumerator records

        Dock.allowsDocking -> {"kind": "native-opaque"}

    for a native property whose descriptor it could not read: the name resolves, but its
    WRITABILITY is unknown to the runtime snapshot. Counting those as "declared in source but
    missing at runtime" would be wrong twice over -- the property is not missing, and the
    disagreement is a limitation of the runtime enumerator rather than a discrepancy in the engine.

    These are exactly the properties for which the source-derived snapshot is the ONLY available
    answer, which is the concrete justification for maintaining both.
    """
    entry = runtime.get("globals", {}).get(cls)
    if not isinstance(entry, dict):
        return None
    members = entry.get("prototype_members")
    if not isinstance(members, dict):
        return None
    out: dict[str, bool] = {}
    opaque: set[str] = set()
    for name, desc in members.items():
        if not isinstance(desc, dict):
            continue
        kind = desc.get("kind")
        if kind == "native-opaque":
            opaque.add(name)
            continue
        # Only real properties. Methods are a separate population and are compared by NAME
        # elsewhere; conflating them here would report every method as a mutability mismatch.
        if kind != "property":
            continue
        out[name] = bool(desc.get("writable", False))
    return out, opaque


def reconcile(source: dict, runtime: dict) -> dict:
    report: dict = {
        "classes_compared": 0,
        "properties_compared": 0,
        "classes_source_only": [],
        "classes_runtime_only": [],
        "properties_source_only": {},
        "properties_runtime_only": {},
        "mutability_mismatch": {},
        # Properties the live enumerator saw but could not describe. The source snapshot is the
        # only place their READONLY/READWRITE status is recorded, so this number is the measured
        # value of keeping both snapshots.
        "runtime_opaque_resolved_from_source": {},
    }

    src_classes = source.get("classes", {})
    rt_globals = runtime.get("globals", {})
    rt_class_names = {
        k for k, v in rt_globals.items()
        if isinstance(v, dict) and isinstance(v.get("prototype_members"), dict)
    }

    for cls in sorted(set(src_classes) - rt_class_names):
        report["classes_source_only"].append(cls)
    for cls in sorted(rt_class_names - set(src_classes)):
        report["classes_runtime_only"].append(cls)

    for cls in sorted(set(src_classes) & rt_class_names):
        rt = runtime_properties(runtime, cls)
        if rt is None:
            continue
        rt_props, rt_opaque = rt
        src_props = src_classes[cls].get("properties", {})
        if not isinstance(src_props, dict):
            continue
        report["classes_compared"] += 1

        # A source property that the runtime saw as native-opaque is NOT missing at runtime; the
        # runtime simply could not read its descriptor. Record it as value added by the source
        # snapshot rather than as a discrepancy.
        resolved = sorted(set(src_props) & rt_opaque)
        if resolved:
            report["runtime_opaque_resolved_from_source"][cls] = resolved

        only_src = sorted(set(src_props) - set(rt_props) - rt_opaque)
        only_rt = sorted(set(rt_props) - set(src_props))
        if only_src:
            report["properties_source_only"][cls] = only_src
        if only_rt:
            report["properties_runtime_only"][cls] = only_rt

        for name in sorted(set(src_props) & set(rt_props)):
            report["properties_compared"] += 1
            src_access = src_props[name].get("access")
            src_writable = (src_access == "readwrite")
            rt_writable = rt_props[name]
            if src_writable != rt_writable:
                report["mutability_mismatch"].setdefault(cls, {})[name] = {
                    "source": src_access,
                    "runtime": "readwrite" if rt_writable else "readonly",
                }
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source", type=Path, default=SOURCE_SNAPSHOT)
    ap.add_argument("--runtime", type=Path, default=RUNTIME_SNAPSHOT)
    ap.add_argument("--baseline", type=Path, default=BASELINE)
    ap.add_argument("--write-baseline", action="store_true",
                    help="record the current reconciliation as the accepted baseline")
    ap.add_argument("--json", action="store_true", help="print the full report as JSON")
    args = ap.parse_args()

    source = load(args.source, "source-derived")
    runtime = load(args.runtime, "runtime-derived")
    report = reconcile(source, runtime)

    # THE ANTI-VACUITY GATE. Without this, a source snapshot whose class names stopped matching the
    # runtime's would produce "0 mismatches" and look like perfect agreement.
    if report["classes_compared"] < MIN_CLASSES_COMPARED:
        refuse(f"only {report['classes_compared']} class(es) could be compared, fewer than the "
               f"floor of {MIN_CLASSES_COMPARED}. The two snapshots are not describing the same "
               f"engine, and 'no disagreements' would be meaningless.")
    if report["properties_compared"] < MIN_PROPS_COMPARED:
        refuse(f"only {report['properties_compared']} propert(ies) could be compared, fewer than "
               f"the floor of {MIN_PROPS_COMPARED}; a comparison this thin proves nothing")

    # THE LOAD-BEARING SPOT CHECK. Ship.AI is READONLY and Ship.velocity is READWRITE. If the
    # reconciliation cannot still see that, it has stopped modelling the thing other beads consult
    # it for -- and a count check would not notice. (Was Ship.speed until oo-jou1 made speed
    # writable; retargeted by Jon in oo-xa5h, as oo-w9rq did for js_api_source_snapshot.py.)
    src_ship = source.get("classes", {}).get("Ship", {}).get("properties", {})
    _rt = runtime_properties(runtime, "Ship")
    rt_ship = _rt[0] if _rt else {}
    for name, want_writable in (("AI", False), ("velocity", True)):
        if name not in src_ship:
            refuse(f"Ship.{name} is missing from the source snapshot; the parser has stopped "
                   f"reading OOJSShip.m's property table")
        if name not in rt_ship:
            refuse(f"Ship.{name} is missing from the runtime snapshot's prototype_members")
        src_rw = src_ship[name].get("access") == "readwrite"
        if src_rw != want_writable or rt_ship[name] != want_writable:
            print(f"js-api-reconcile: FAIL: Ship.{name} should be "
                  f"{'READWRITE' if want_writable else 'READONLY'} in both snapshots, but source "
                  f"says {src_ship[name].get('access')} and runtime says "
                  f"{'readwrite' if rt_ship[name] else 'readonly'}; the spot check can no longer "
                  f"tell READONLY from READWRITE.",
                  file=sys.stderr)
            return 1

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))

    if args.write_baseline:
        args.baseline.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                 encoding="utf-8")
        print(f"js-api-reconcile: baseline written to {args.baseline}")
        return 0

    if not args.baseline.is_file():
        refuse(f"no accepted baseline at {args.baseline}; run with --write-baseline once, review "
               f"the discrepancies it records, and commit it. Without a baseline every discrepancy "
               f"is either always-red or always-ignored, and neither is a gate.")
    accepted = json.loads(args.baseline.read_text(encoding="utf-8"))

    # Compare the DISCREPANCY SETS, not the counts. New disagreement is the signal; the counts
    # moving for an unrelated reason is not. This is the oo-9w5 lesson applied: the committed
    # baseline is a CONTENT expectation, not a number.
    problems: list[str] = []
    for key in ("classes_source_only", "classes_runtime_only"):
        new = sorted(set(report[key]) - set(accepted.get(key, [])))
        if new:
            problems.append(f"{key}: NEW {new}")
    for key in ("properties_source_only", "properties_runtime_only"):
        for cls, names in sorted(report[key].items()):
            new = sorted(set(names) - set(accepted.get(key, {}).get(cls, [])))
            if new:
                problems.append(f"{key}[{cls}]: NEW {new}")
    for cls, names in sorted(report["mutability_mismatch"].items()):
        acc = accepted.get("mutability_mismatch", {}).get(cls, {})
        new = sorted(set(names) - set(acc))
        if new:
            problems.append(
                f"MUTABILITY[{cls}]: NEW {new} -- the engine's declared access and the live "
                f"interpreter's writability disagree, which is the class of defect bead oo-jou1 "
                f"was filed for")

    if problems:
        print(f"js-api-reconcile: FAIL -- {len(problems)} NEW discrepanc(ies) between the "
              f"source-derived and runtime-derived JS API snapshots:\n", file=sys.stderr)
        for p in problems:
            print(f"  * {p}", file=sys.stderr)
        print("\nIf these are expected, review them and re-record with --write-baseline.",
              file=sys.stderr)
        return 1

    print(f"js-api-reconcile: OK -- {report['classes_compared']} class(es) and "
          f"{report['properties_compared']} propert(ies) compared against the live-interpreter "
          f"snapshot; no NEW discrepancies beyond the committed baseline "
          f"({len(report['mutability_mismatch'])} class(es) with known mutability differences, "
          f"{len(report['properties_source_only'])} with source-only properties)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
