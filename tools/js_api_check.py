"""Structural check for oxp-contract/js-api-1.93.json.

Run by tools/js-api-check.sh. It answers the question a clean checkout can answer without a game
binary: is the committed snapshot a well-formed, deterministic, non-empty description of the JS
API? The full "regenerate and diff" DoD lives in tools/js-api-check.sh --regen, which needs a
built oolite.app and is therefore not something CI or a bead acceptance can run.

Every assertion below is about the snapshot's SHAPE, never about a value that could drift between
runs of the game, because a check that depended on a session value would fail for the wrong reason.
"""

import json
import re
import sys

# Classes the engine cannot lose without the OXP contract being broken. Deliberately a small,
# uncontroversial core rather than the full list: the full list is the snapshot itself, and
# duplicating it here would turn every intentional API addition into two edits.
REQUIRED_CLASSES = ["Entity", "Player", "PlayerShip", "Quaternion", "Ship", "Station", "System",
                    "Vector3D"]

# Classes whose prototypes must carry real, callable methods. If a binding regressed to a bare
# constructor this is what notices.
REQUIRED_METHOD_CLASSES = ["Ship", "PlayerShip", "Station", "System", "Vector3D"]

# Singleton globals the scripting API is built around (OOJSGlobal.m and friends).
REQUIRED_OBJECTS = ["clock", "mission", "missionVariables", "oolite", "player", "system",
                    "worldScripts"]

# A snapshot that embeds any of these is not reproducible. The patterns match VALUES, never member
# names: the API legitimately contains globals and members called Date, Clock or host, and a
# pattern broad enough to catch those would fail on a perfectly deterministic file.
NON_DETERMINISTIC = [
    (re.compile(r"\b[A-Za-z]:[\\\\/]"), "a filesystem path"),
    (re.compile(r"\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}"), "an ISO timestamp"),
    (re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"), "an IP address"),
]

# Top-level keys that would make the document depend on the machine or the moment it was taken.
# Checked structurally rather than by regex, for the same reason.
FORBIDDEN_TOP_KEYS = {"generated_at", "timestamp", "date", "host", "port", "console_port", "pid",
                      "path", "app_dir", "cwd", "tmpdir", "user"}

KINDS = {"method", "property", "accessor", "opaque", "native-opaque"}

# Own data properties of an object global whose `type` is dropped (see
# js_api_snapshot.py:_strip_state_dependent_types) and which appear nowhere else in the document
# that a type could be read off instead - not on the class prototype, and not, for `global`, as a
# top-level global of their own. This is the exact, measured cost of dropping `type`, pinned here
# so it cannot quietly grow: an earlier revision asserted the cost was ZERO on the strength of four
# sampled globals and was wrong for the other thirteen.
TYPELESS_OWN_ONLY = {
    "console.script", "console.settings",
    "debugConsole.script", "debugConsole.settings",
    "player.ship",
}


def _member_signature(members):
    """Canonical form of a member map for the identical-bucket check below.

    Two normalisations, both required to see the fault this check exists for:

    * `type` is dropped. own_members never carries it (js_api_snapshot.py strips it) while
      prototype_members does, so a raw comparison would never match a fabricated own_members
      against the prototype it was copied from - which is precisely how the corruption survived
      review the first time.
    * `native-opaque` entries are dropped. They are synthesised Python-side from the name list and
      never pass through the JS accumulator, so a copied accumulator reproduces a target's
      describable members and nothing else. Comparing on that subset is what makes the copy
      visible; StopIteration's fabricated 21 members matched Station.prototype's 21 methods while
      excluding its 18 native-opaque ones.
    """
    normalised = {
        name: {k: v for k, v in entry.items() if k != "type"}
        for name, entry in members.items()
        if entry.get("kind") != "native-opaque"
    }
    return json.dumps(normalised, sort_keys=True)


# Two buckets legitimately holding byte-identical member maps in this build. Every one is a real
# aliasing fact about the runtime, verified by name: a singleton and its class share a prototype
# object (clock/Clock), the debug console is exposed twice under two names (console/debugConsole),
# the DOM-less builtins are their own prototype (JSON, Proxy), the typed arrays are generated from
# one template, and the plain error classes share a prototype shape. Anything NOT in this list that
# comes out identical is the signature of the stale-accumulator bug: a target with zero own
# property names used to be described with the PREVIOUS target's accumulator, which silently gave
# StopIteration a copy of Station.prototype, missionVariables a copy of Mission.prototype and
# worldScripts a copy of Array.prototype. That class of fault is invisible to every other check
# here, so it gets its own.
EXPECTED_IDENTICAL_BUCKETS = [
    # A singleton and its class share one prototype OBJECT, so both record it identically.
    {"clock.prototype_members", "Clock.prototype_members"},
    {"mission.prototype_members", "Mission.prototype_members"},
    {"system.prototype_members", "System.prototype_members"},
    {"player.prototype_members", "Player.prototype_members"},
    {"oolite.prototype_members", "Oolite.prototype_members"},
    {"manifest.prototype_members", "Manifest.prototype_members"},
    # `console` and `debugConsole` are the same live object under two global names.
    {"console.prototype_members", "debugConsole.prototype_members", "Console.prototype_members"},
    {"console.own_members", "debugConsole.own_members"},
    # Namespace-style builtins: the object IS its own prototype's member set.
    {"JSON.own_members", "JSON.prototype_members"},
    {"Proxy.own_members", "Proxy.prototype_members"},
    {"Math.own_members", "Math.prototype_members"},
    # `worldScriptNames` is a plain Array, so it shares Array.prototype.
    {"Array.prototype_members", "worldScriptNames.prototype_members"},
    # The nine typed-array constructors are generated from one template in SpiderMonkey, so their
    # prototypes carry the same eight members.
    {f"{n}.prototype_members" for n in
     ("Float32Array", "Float64Array", "Int8Array", "Int16Array", "Int32Array",
      "Uint8Array", "Uint8ClampedArray", "Uint16Array", "Uint32Array")},
    # The plain error classes all inherit the same five-member Error.prototype shape.
    {f"{n}.prototype_members" for n in
     ("EvalError", "InternalError", "RangeError", "ReferenceError", "SyntaxError", "TypeError",
      "URIError")},
    # Two of the seven uncatchable-getter classes. Every member of either prototype except
    # `constructor` and `remove` is native-opaque and therefore excluded from the comparison, and
    # those two really are the same shape on both. Verified by name against the full member lists,
    # which differ: ExhaustPlume has 3 members, Flasher 8.
    {"ExhaustPlume.prototype_members", "Flasher.prototype_members"},
]


def check_no_fabricated_buckets(globals_map):
    """Fail if two member maps are byte-identical without a declared reason.

    The cheap, general detector for a whole class of enumeration fault: any bug that hands one
    target's member list to another produces an exact duplicate, because the copy is made of
    already-serialised records rather than re-derived per target.

    Groups whose members are all plain `Object.prototype`-shaped or all empty are not interesting:
    an empty bucket carries no information to fabricate, and the shared builtin prototypes and the
    shared `statics` of every native constructor (the six Function statics, the five of a plain
    function) are structural, not per-class. Those are skipped generically rather than listed.
    """
    groups = {}
    for gname, entry in globals_map.items():
        for bucket, members in member_buckets(entry):
            if not members:
                continue
            groups.setdefault(_member_signature(members), set()).add(f"{gname}.{bucket}")

    allowed = [frozenset(group) for group in EXPECTED_IDENTICAL_BUCKETS]
    for signature, keys in sorted(groups.items(), key=lambda kv: sorted(kv[1])):
        if len(keys) < 2:
            continue
        members = json.loads(signature)
        # Shared structural shapes: `statics` is identical across every native constructor because
        # it is Function's own, and the builtin object prototypes are shared by construction.
        if all(key.endswith(".statics") for key in keys):
            continue
        if set(members) <= OBJECT_PROTOTYPE_MEMBERS:
            continue
        if any(keys == group for group in allowed):
            continue
        fail(f"{sorted(keys)} have byte-identical member maps ({len(members)} entries) with no "
             "declared reason. An enumeration that copies one target's members onto another "
             "produces exactly this; if the aliasing is real, add it to "
             "EXPECTED_IDENTICAL_BUCKETS with the reason")


# The 15 members every plain object inherits from Object.prototype in this SpiderMonkey. Objects
# whose prototype IS Object.prototype therefore all record the same 15, which is shared by
# construction and says nothing about any one of them.
OBJECT_PROTOTYPE_MEMBERS = frozenset([
    "__defineGetter__", "__defineSetter__", "__lookupGetter__", "__lookupSetter__", "callObjC",
    "constructor", "hasOwnProperty", "isPrototypeOf", "propertyIsEnumerable", "toLocaleString",
    "toSource", "toString", "unwatch", "valueOf", "watch",
])


def check_typeless_own_only(globals_map):
    """Pin the exact set of own data properties whose `type` is unrecoverable.

    js_api_snapshot.py drops `type` from an object global's own_members because a live singleton's
    typeof is session state. For most of those members the type is still in the document, on the
    class prototype - or, for `global`, on the global of the same name. For a few it is not, and
    THAT is the real cost of the decision. It is pinned rather than merely documented so a future
    change that widens the loss has to argue for it instead of landing silently: the original
    justification for dropping `type` claimed the cost was zero, having sampled four of seventeen
    object globals.
    """
    lost = set()
    for gname, entry in globals_map.items():
        if entry.get("type") != "object":
            continue
        proto = entry.get("prototype_members") or {}
        for mname, member in (entry.get("own_members") or {}).items():
            if member.get("kind") != "property" or mname in proto:
                continue
            if gname == "global" and mname in globals_map:
                continue  # `global.mission` is recoverable from the `mission` global itself.
            lost.add(f"{gname}.{mname}")
    if lost != TYPELESS_OWN_ONLY:
        added = sorted(lost - TYPELESS_OWN_ONLY)
        gone = sorted(TYPELESS_OWN_ONLY - lost)
        fail(f"the set of own data properties with an unrecoverable type has changed "
             f"(new: {added}, no longer present: {gone}). Dropping `type` from own_members is "
             "only defensible while this set is small and known; re-derive it and update "
             "TYPELESS_OWN_ONLY and js_api_snapshot.py's docstring together")


def fail(message):
    print(f"[!] {message}")
    sys.exit(1)


def member_buckets(entry):
    for bucket in ("statics", "prototype_members", "own_members"):
        members = entry.get(bucket)
        if isinstance(members, dict):
            yield bucket, members


def main(path):
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()

    try:
        doc = json.loads(text)
    except ValueError as exc:
        fail(f"{path} is not valid JSON: {exc}")

    # Determinism. The file must be exactly what write_snapshot() produces, so a regeneration can
    # only differ where the API differs.
    canonical = json.dumps(doc, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    if text != canonical:
        fail(f"{path} is not in canonical form (sorted keys, indent=2, ASCII, LF, final newline); "
             "regenerate it with tools/js-api-snapshot.sh")
    if "\r" in text:
        fail(f"{path} contains CR; it must use LF line endings")

    for pattern, what in NON_DETERMINISTIC:
        found = pattern.search(text)
        if found:
            fail(f"{path} embeds {what} ({found.group(0)!r}); the snapshot must not vary per run")

    stray = FORBIDDEN_TOP_KEYS & set(doc)
    if stray:
        fail(f"{path} has session-dependent top-level key(s) {sorted(stray)}")

    if doc.get("schema") != "oolite-js-api/1":
        fail(f"unexpected schema {doc.get('schema')!r}")
    if not isinstance(doc.get("oolite_version"), str) or not doc["oolite_version"]:
        fail("oolite_version is missing or empty")

    globals_map = doc.get("globals")
    if not isinstance(globals_map, dict) or not globals_map:
        fail("globals is missing or empty")

    summary = doc.get("summary")
    if not isinstance(summary, dict):
        fail("summary is missing")
    if summary.get("global_count") != len(globals_map):
        fail(f"summary.global_count {summary.get('global_count')} != "
             f"{len(globals_map)} entries in globals")

    oolite_globals = summary.get("oolite_globals")
    if not isinstance(oolite_globals, list) or oolite_globals != sorted(oolite_globals):
        fail("summary.oolite_globals is missing or not sorted")
    if summary.get("oolite_global_count") != len(oolite_globals):
        fail("summary.oolite_global_count disagrees with summary.oolite_globals")
    if len(oolite_globals) < 66:
        fail(f"only {len(oolite_globals)} Oolite globals; the enumeration did not complete")

    classes = summary.get("classes")
    if not isinstance(classes, list) or classes != sorted(classes):
        fail("summary.classes is missing or not sorted")
    if summary.get("class_count") != len(classes):
        fail("summary.class_count disagrees with summary.classes")

    # A native class is a constructor whose prototype carries real members. Every JS function owns
    # a .prototype, so without this the plain utility globals (consoleMessage, formatCredits,
    # formatInteger) would be counted as classes - which is exactly what an earlier snapshot did.
    for name in classes:
        members = globals_map.get(name, {}).get("prototype_members")
        if not isinstance(members, dict) or not set(members) - {"constructor"}:
            fail(f"{name} is listed as a native class but its prototype has only `constructor`; "
                 "it is a plain function, not a class")

    for name in REQUIRED_CLASSES:
        if name not in globals_map:
            fail(f"global {name} is missing from the snapshot")
        if name not in classes:
            fail(f"{name} is not recorded as a native class")
        entry = globals_map[name]
        if entry.get("type") != "function" or not entry.get("is_class"):
            fail(f"{name} is not a constructor in the snapshot")
        if not isinstance(entry.get("prototype_members"), dict) or not entry["prototype_members"]:
            fail(f"{name}.prototype has no recorded members")

    for name in REQUIRED_METHOD_CLASSES:
        members = globals_map[name]["prototype_members"]
        methods = [m for m, e in members.items() if e.get("kind") == "method"]
        if not methods:
            fail(f"{name}.prototype has no methods; the binding scan failed for it")

    for name in REQUIRED_OBJECTS:
        if name not in globals_map:
            fail(f"global {name} is missing from the snapshot")
        if globals_map[name].get("type") != "object":
            fail(f"global {name} is not an object in the snapshot")

    # Every member entry must be shaped the way js_api_snapshot.py writes them: a bad kind or a
    # method with no arity means the parser drifted from the emitter.
    members_seen = 0
    for gname, entry in globals_map.items():
        if not isinstance(entry.get("type"), str):
            fail(f"global {gname} has no type")
        for bucket, members in member_buckets(entry):
            for mname, member in members.items():
                members_seen += 1
                if mname.startswith("__oo"):
                    # The snapshot tool installs __ooScan/__ooAcc/__ooBuf/__ooIdx on the JS global
                    # to drive the enumeration. `global` self-references that object, so they can
                    # leak into its own_members. They are the harness, not Oolite's API.
                    fail(f"{gname}.{bucket}.{mname} is a snapshot-harness member; it must not "
                         "reach the contract")
                kind = member.get("kind")
                if kind not in KINDS:
                    fail(f"{gname}.{bucket}.{mname} has unknown kind {kind!r}")
                if kind == "method" and not isinstance(member.get("arity"), int):
                    fail(f"{gname}.{bucket}.{mname} is a method with no integer arity")
                if bucket == "own_members":
                    # A singleton's own data-property values are session state (mission.screenID
                    # is null or a string depending on whether a mission screen is up), so the
                    # snapshot must not record their typeof or a regeneration cannot reproduce.
                    if "type" in member:
                        fail(f"{gname}.own_members.{mname} records a type; typeof of a live "
                             "singleton value is session state, not API shape")
                elif kind == "property" and not isinstance(member.get("type"), str):
                    fail(f"{gname}.{bucket}.{mname} is a property with no type")
    if members_seen < 2300:
        fail(f"only {members_seen} members recorded; the enumeration did not complete")

    check_no_fabricated_buckets(globals_map)
    check_typeless_own_only(globals_map)

    print(f"[+] {path}: {len(globals_map)} globals "
          f"({summary['oolite_global_count']} Oolite, "
          f"{summary['ecmascript_global_count']} ECMAScript), "
          f"{len(classes)} native classes, {members_seen} members, "
          f"oolite {doc['oolite_version']}; canonical and deterministic")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: js_api_check.py <snapshot.json>")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
