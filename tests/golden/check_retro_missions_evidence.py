"""Offline checks on a scenario-012-retro-missions dump: does it prove the EXPANSION went LIVE?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation, floats rounded to whole numbers). All of that is about the COMPARISON.

It cannot answer the other half of the vacuity problem, which is about the RUN: a scenario that
crashed during display init and dumped a near-empty world reproduces byte-for-byte perfectly and
proves nothing. Two runs of a dead scenario agree. So this file checks the CONTENT.

WHAT COUNTS AS EVIDENCE HERE, AND WHY A DEAD RUN CANNOT PRODUCE IT
------------------------------------------------------------------
`evidence.oxp_world_scripts` lists the world scripts present in the RUNNING game that a stock
game does not have. Measured on this box: a control run with nothing staged
(`retro_missions.py --no-oxp --probe-world-scripts`) has 16 world scripts; the staged run has 22,
the six extra being

    ahruman-reaper, cloaking-device, constrictor_hunt, nova, thargoid_plans, trumbles

Those names exist only if RetroMissions' `Config/world-scripts.plist` was MERGED into the game's
world-script list and each named script was found, compiled and INSTANTIATED. Being named in
`[searchPaths.dumpAll]` proves only that a directory was accepted; this proves the content was
parsed and executed. A run that died before expansion parsing has an empty list; a run that loaded
the OXP but failed to build its scripts has an empty list; neither can pass.

`evidence.oxp_script_versions` carries a PROPERTY read off each name that resolves to a live JS
object. MEASURED: only one of the six does - `ahruman-reaper`, the expansion's own .js world
script, reading `version == "1"`. The other five come from `Scripts/oolite-legacy-scripts.plist`
and enumerate as KEYS of `worldScripts` without being addressable as JS objects; they are recorded
separately as `evidence.oxp_key_only_scripts` rather than being quietly folded in.

Both halves are required and they prove different things. The NAMES prove the expansion's
`Config/world-scripts.plist` was merged into the game's world-script list. The VERSION READ proves
a script FILE was found, compiled by the JS engine and instantiated as a live object. A checker
that accepted key enumeration alone would pass on a merge with no script behind it.

THE MISSING manifest.plist IS PINNED, NOT MUTED (bead oo-kcrw)
--------------------------------------------------------------
RetroMissions predates the manifest format and emits exactly TWO
`[oxp-standards.error]: OXP ... has no manifest.plist` lines per load. oo-kcrw's NOMANIF state is
honest because it is gated on positive proof of loading AND on the errors being EXCLUSIVELY that
message at that exact count. This checker holds the same line:

  * the count must be EXACTLY `EXPECTED_STANDARDS_ERRORS` (2) - not "at most", not "at least";
  * every signature must be in `ALLOWED_STANDARDS_ERROR_SIGNATURES`, compared verbatim after the
    volatile staged path is replaced by the OXP basename at capture time.

A third line, or a different error, fails. That exactness is what makes it a tolerance rather than
a suppression - and it earned its keep: it caught a staging directory named `addons` colliding
case-insensitively with the game's own `../AddOns` root, which loaded the expansion TWICE and
produced four lines.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry, with the value a REAL staged run produces. Listed as
# a table rather than as inline ifs so the set is readable and so a future scenario cannot quietly
# drop one of them.
REQUIRED_TRUE = ("oxp_staged", "tick_budget_met")
REQUIRED_POSITIVE = ("ticks",)

# The six world scripts RetroMissions contributes, MEASURED against a control run that staged
# nothing (see the module docstring). Pinned as a set, not as a floor, so a run that loads a
# DIFFERENT expansion cannot satisfy this checker.
EXPECTED_OXP_WORLD_SCRIPTS = frozenset((
    "ahruman-reaper",
    "cloaking-device",
    "constrictor_hunt",
    "nova",
    "thargoid_plans",
    "trumbles",
))

# The one expansion world script that resolves to a LIVE JS object, and the value read off it.
# Everything else RetroMissions contributes is a legacy plist script that enumerates as a key
# only. Measured; see the module docstring.
EXPECTED_LIVE_SCRIPT_VERSIONS = {"ahruman-reaper": "1"}
EXPECTED_KEY_ONLY_SCRIPTS = frozenset((
    "cloaking-device", "constrictor_hunt", "nova", "thargoid_plans", "trumbles",
))

# Bead oo-kcrw's NOMANIF allowance, stated exactly.
EXPECTED_STANDARDS_ERRORS = 2
ALLOWED_STANDARDS_ERROR_SIGNATURES = frozenset((
    "OXP RetroMissions.oxp has no manifest.plist",
))

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared. This scenario spawns no cast and switches
# the populator off, so the entities are the system's own fixed furniture.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove the expansion went live."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that RetroMissions "
            "was ever loaded, and two such dumps agreeing proves only that the same nothing "
            "happened twice." % label)

    for field in REQUIRED_TRUE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif ev[field] is not True:
            problems.append("evidence.%s is %r, expected True" % (field, ev[field]))

    for field in REQUIRED_POSITIVE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif not isinstance(ev[field], int) or ev[field] < 1:
            problems.append("evidence.%s is %r, expected an integer >= 1" % (field, ev[field]))

    if "populators_suppressed" not in ev:
        problems.append("evidence.populators_suppressed is ABSENT: this dump predates the "
                        "populator suppression and may have been taken in a world the system "
                        "was still adding traffic to")

    # --- DEFENCE 1: the expansion's world scripts are LIVE in the running game -----------------
    live = ev.get("oxp_world_scripts")
    if not isinstance(live, list) or not live:
        problems.append(
            "evidence.oxp_world_scripts is %r: the running game had no world script a stock game "
            "lacks, so RetroMissions' Config/world-scripts.plist was never merged and its scripts "
            "were never instantiated. Being on the search path is not being live." % (live,))
    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:
        missing = sorted(EXPECTED_OXP_WORLD_SCRIPTS - set(live))
        extra = sorted(set(live) - EXPECTED_OXP_WORLD_SCRIPTS)
        problems.append(
            "evidence.oxp_world_scripts is %r, which is not RetroMissions' measured set "
            "(missing %r, unexpected %r). A dump taken with a different expansion loaded is not "
            "this scenario." % (sorted(live), missing, extra))

    # --- DEFENCE 2: a PROPERTY was read off each live script object ----------------------------
    versions = ev.get("oxp_script_versions")
    if not isinstance(versions, dict) or not versions:
        problems.append(
            "evidence.oxp_script_versions is %r: no property was read off any expansion script "
            "object, so the names above are unbacked keys rather than live scripts"
            % (versions,))
    elif versions != EXPECTED_LIVE_SCRIPT_VERSIONS:
        problems.append(
            "evidence.oxp_script_versions is %r but the measured value is %r. This is the read "
            "that proves a script FILE was found, compiled and instantiated; a name in "
            "oxp_world_scripts only proves the world-scripts list was merged."
            % (versions, EXPECTED_LIVE_SCRIPT_VERSIONS))
    key_only = ev.get("oxp_key_only_scripts")
    if not isinstance(key_only, list) or sorted(key_only) != sorted(EXPECTED_KEY_ONLY_SCRIPTS):
        problems.append(
            "evidence.oxp_key_only_scripts is %r but the measured value is %r; these are the "
            "expansion's legacy plist scripts, which enumerate as keys without resolving to JS "
            "objects, and the split between them and the live script is itself the evidence"
            % (key_only, sorted(EXPECTED_KEY_ONLY_SCRIPTS)))

    # --- DEFENCE 3: the NOMANIF allowance, held EXACTLY ----------------------------------------
    count = ev.get("oxp_standards_errors")
    if count != EXPECTED_STANDARDS_ERRORS:
        problems.append(
            "evidence.oxp_standards_errors is %r but exactly %d is allowed (bead oo-kcrw: "
            "RetroMissions is NOMANIF and emits exactly that many "
            "'[oxp-standards.error]: OXP ... has no manifest.plist' lines). Fewer means the "
            "expansion was not parsed; more means a NEW problem. Widening this to make a run pass "
            "is forbidden." % (count, EXPECTED_STANDARDS_ERRORS))
    sigs = ev.get("oxp_standards_error_signatures")
    if not isinstance(sigs, list):
        problems.append("evidence.oxp_standards_error_signatures is %r, expected a list" % (sigs,))
    else:
        unexpected = [s for s in sigs if s not in ALLOWED_STANDARDS_ERROR_SIGNATURES]
        if unexpected:
            problems.append(
                "the run emitted an [oxp-standards.error] line that is NOT the known "
                "missing-manifest message: %r. The allow-list is %r and is deliberately exact - a "
                "different error is a finding, not noise."
                % (unexpected, sorted(ALLOWED_STANDARDS_ERROR_SIGNATURES)))
        if not sigs:
            problems.append(
                "evidence.oxp_standards_error_signatures is empty: the known missing-manifest "
                "line was never emitted, so this dump was not taken with RetroMissions staged")

    # --- the dump's own shape ------------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market "
                        "is missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))
    if not (data.get("player") or {}).get("ship"):
        problems.append("player.ship is absent: the dump is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove a RetroMissions run:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: RetroMissions live - %d expansion world script name(s) merged (%s), %d of them "
            "resolve to a live JS object with a version read off it (%s), %d are legacy plist "
            "keys; exactly %d known missing-manifest error(s) and no others; ran %d ticks; "
            "%d entities, %d market goods"
            % (label, len(live), ", ".join(sorted(live)), len(versions),
               ", ".join("%s=%s" % kv for kv in sorted(versions.items())),
               len(key_only), EXPECTED_STANDARDS_ERRORS, ev["ticks"], len(ents), len(market)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    label = args.label or args.dump

    if not os.path.isfile(args.dump):
        sys.stderr.write("USAGE: no such dump: %s\n" % args.dump)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as exc:
        sys.stderr.write("USAGE: %s is not valid JSON: %s\n" % (label, exc))
        return 2

    try:
        print(check(data, label))
    except EvidenceError as exc:
        sys.stderr.write("NO EVIDENCE: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
