"""Offline checks on a scenario-013-constrictor dump: does it prove THIS SAVE'S MISSION STATE?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation). All of that is about the COMPARISON. It cannot answer the other half of the
vacuity problem, which is about the RUN: a scenario that crashed during display init and dumped a
near-empty world reproduces byte-for-byte perfectly and proves nothing. Two runs of a dead
scenario agree. So this file checks the CONTENT.

AND FOR A SAVE-LOAD GOLDEN THERE IS A SECOND, SHARPER VACUITY: a dump proving only that "the game
started" would pass just as well against a DEFAULT NEW COMMANDER with no mission at all. Every
clause below was chosen because a measured control arm FAILS it.

THE THREE ARMS, MEASURED ON THIS BOX (see the README for the full table)
-----------------------------------------------------------------------
                          commander      system        conhunt            live handlers
  subject  Constrictor    Constrictor    Esgebi (240)  <absent>           3
  control  ThargoidPlans  ThargoidPlans  Quedle (147)  MISSION_COMPLETE   0
  control  no -load       Jameson        Lave (7)      <absent>           0 (script not built)

WHY conhunt IS ABSENT AND WHY THAT IS THE RIGHT ASSERTION
---------------------------------------------------------
`oolite-constrictor-hunt-mission.js:117` sets `missionVariables.conhunt = "STAGE_1"` only when
`galaxyNumber < 2 && !missionVariables.conhunt && player.score > 255`. This commander's ship_kills
is EXACTLY 255, so the fixture is the state one kill before the hunt is offered and conhunt is
legitimately unset. Absence alone would be a weak assertion - a fresh game is also absent - so it
is required TOGETHER WITH the three live event handlers. The same script deletes those three in
`_cleanUp()` (:35-41) as soon as conhunt reaches MISSION_COMPLETE, and a game with no commander
loaded has not built the script at all. "conhunt absent AND all three handlers live AND commander
Constrictor AND system Esgebi AND exactly these four mission variables" is a conjunction no other
checklist save and no default new game satisfies.

THE HANDLER READ IS NOT A FIELD COPIED OUT OF THE FILE. It is `typeof worldScripts[...][name]`
evaluated inside the running engine, so it proves the save's mission state reached the JS layer
and changed what the mission script IS - not merely that some bytes were parsed.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and both
values). A usage error is 2 - "I cannot tell you", never "they match" - the convention golden_diff
established.
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry as True, with the value a REAL loaded run produces.
REQUIRED_TRUE = ("clock_at_or_past_save", "docked", "tick_budget_met", "mission_script_loaded")
REQUIRED_POSITIVE = ("ticks", "score", "save_bytes")

# THE IDENTITY OF THE SAVE. A run that ignored -load is Jameson in Lave; a run of a DIFFERENT
# checklist save is a different commander in a different system. Pinned as equalities, not floors.
EXPECTED_COMMANDER = "Constrictor"
EXPECTED_SYSTEM_NAME = "Esgebi"
EXPECTED_SYSTEM_ID = 240
EXPECTED_GALAXY = 1

# ship_kills is load-bearing, not decoration: the mission script's own threshold is `> 255`, so
# this exact value is WHY conhunt is absent below. Change it and the mission-state assertion means
# something else.
EXPECTED_SCORE = 255

# The 1.75-era save-format contract this fixture also pins.
EXPECTED_SAVE_FORMAT = "1.75"
EXPECTED_SAVE_FILE = "Constrictor.oolite-save"

# --- DEFENCE 1: the mission variables the deserialiser restored -------------------------------
# Pinned as an exact mapping, not a subset: a run that loaded a different save has a different
# set, and a fresh game has an EMPTY one.
EXPECTED_MISSION_VARIABLES = {
    "CT_thargonCount": 0,
    "snoopers_CRCNews": "|",
    "snoopers_usedSlots": 0,
    "trumbles": "NOT_NOW",
}

# --- DEFENCE 2: mission_conhunt specifically ---------------------------------------------------
EXPECTED_CONHUNT = None
EXPECTED_CONHUNT_PRESENT = False

# --- DEFENCE 3: the BEHAVIOURAL consequence, read off the live script object --------------------
EXPECTED_MISSION_SCRIPT = "oolite-constrictor-hunt"
EXPECTED_LIVE_HANDLERS = ("guiScreenChanged", "missionScreenOpportunity", "systemWillPopulate")

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared.
MIN_ENTITIES = 1
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove this save's mission state was loaded."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that the Constrictor "
            "save was ever loaded, and two such dumps agreeing proves only that the same nothing "
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
                        "populator suppression and may have been taken in a world the system was "
                        "still adding traffic to")

    # --- the identity of the loaded save ------------------------------------------------------
    for field, want in (("commander_name", EXPECTED_COMMANDER),
                        ("system_name", EXPECTED_SYSTEM_NAME),
                        ("system_id", EXPECTED_SYSTEM_ID),
                        ("galaxy_number", EXPECTED_GALAXY),
                        ("save_format_version", EXPECTED_SAVE_FORMAT),
                        ("save_file", EXPECTED_SAVE_FILE)):
        if ev.get(field) != want:
            problems.append(
                "evidence.%s is %r but this scenario loads %s, whose value is %r. A run that "
                "ignored -load reads commander 'Jameson' in 'Lave' (ID 7, galaxy 0); a run of a "
                "different checklist save reads that save's own values."
                % (field, ev.get(field), EXPECTED_SAVE_FILE, want))

    if ev.get("score") != EXPECTED_SCORE:
        problems.append(
            "evidence.score is %r, expected %r. This is not decoration: "
            "oolite-constrictor-hunt-mission.js offers the mission only when player.score > 255, "
            "so this EXACT value is the reason mission_conhunt is legitimately absent below. A "
            "different score makes the mission-state assertion mean something else."
            % (ev.get("score"), EXPECTED_SCORE))

    # --- DEFENCE 1: mission_variables ----------------------------------------------------------
    mv = ev.get("mission_variables")
    if not isinstance(mv, dict):
        problems.append(
            "evidence.mission_variables is %r, expected an object. Without it this scenario has no "
            "mission state at all and is indistinguishable from a bare launch." % (mv,))
    elif mv != EXPECTED_MISSION_VARIABLES:
        missing = sorted(set(EXPECTED_MISSION_VARIABLES) - set(mv))
        extra = sorted(set(mv) - set(EXPECTED_MISSION_VARIABLES))
        wrong = sorted(k for k in set(mv) & set(EXPECTED_MISSION_VARIABLES)
                       if mv[k] != EXPECTED_MISSION_VARIABLES[k])
        problems.append(
            "evidence.mission_variables is %r but this save's measured set is %r (missing %r, "
            "unexpected %r, wrong value %r). A DEFAULT NEW GAME's missionVariables is EMPTY, so "
            "this clause alone rejects a run that never loaded a save."
            % (mv, EXPECTED_MISSION_VARIABLES, missing, extra, wrong))

    # The bead names mission_variables as a required part of the DUMP, not only of the evidence
    # block, and a consumer should not need the evidence schema to find it. Both copies must agree.
    top = data.get("mission_variables")
    if not isinstance(top, dict):
        problems.append(
            "the dump has no top-level `mission_variables`; the bead requires the canonical dump "
            "itself to carry the mission state, not only the evidence block")
    elif top != mv:
        problems.append(
            "the dump's top-level mission_variables %r disagrees with evidence.mission_variables "
            "%r; one of the two was edited alone" % (top, mv))

    # --- DEFENCE 2: mission_conhunt, held as an EXPLICIT absence -------------------------------
    if "mission_conhunt_present" not in ev:
        problems.append(
            "evidence.mission_conhunt_present is ABSENT. The bead names mission_conhunt, and an "
            "assertion that a key is absent is only meaningful if the run RECORDED having looked.")
    elif ev["mission_conhunt_present"] != EXPECTED_CONHUNT_PRESENT:
        problems.append(
            "evidence.mission_conhunt_present is %r, expected %r. This fixture is PRE-mission "
            "(ship_kills exactly 255), while CloakingDevice, Nova and ThargoidPlans all carry "
            "mission_conhunt=MISSION_COMPLETE - so a dump taken from one of those saves fails here."
            % (ev["mission_conhunt_present"], EXPECTED_CONHUNT_PRESENT))
    if ev.get("mission_conhunt", "<absent>") != EXPECTED_CONHUNT:
        problems.append("evidence.mission_conhunt is %r, expected %r"
                        % (ev.get("mission_conhunt", "<absent>"), EXPECTED_CONHUNT))

    # --- DEFENCE 3: the live mission script and its handlers -----------------------------------
    if ev.get("mission_script") != EXPECTED_MISSION_SCRIPT:
        problems.append("evidence.mission_script is %r, expected %r"
                        % (ev.get("mission_script"), EXPECTED_MISSION_SCRIPT))
    handlers = ev.get("live_mission_handlers")
    if not isinstance(handlers, list) or not handlers:
        problems.append(
            "evidence.live_mission_handlers is %r: no event handler of %s was live in the running "
            "game. A completed-mission save reads [] here because the script deletes them in "
            "_cleanUp(), and a game with no commander loaded has not built the script at all - so "
            "an empty list is exactly the wrong-save and dead-run signature."
            % (handlers, EXPECTED_MISSION_SCRIPT))
    elif sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS):
        problems.append(
            "evidence.live_mission_handlers is %r but the measured set for a PRE-mission "
            "Constrictor save is %r. These are `typeof` reads off a LIVE JS object inside the "
            "engine, so this is the positive half of the mission-state assertion: the mission "
            "variable's absence changed what the mission script IS."
            % (sorted(handlers), sorted(EXPECTED_LIVE_HANDLERS)))

    # --- the dump's own shape -------------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market is "
                        "missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))
    if not (data.get("player") or {}).get("ship"):
        problems.append("player.ship is absent: the dump is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove the Constrictor save's mission state:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: Constrictor save LOADED - commander %r in %s (ID %d, galaxy %d), %s-era save, "
            "score %d; %d mission variable(s) restored (%s); mission_conhunt ABSENT as measured "
            "for this pre-mission fixture; %s still has %d live handler(s) (%s), which a "
            "MISSION_COMPLETE save and a default new game both lack; ran %d ticks; %d entities, "
            "%d market goods"
            % (label, ev["commander_name"], ev["system_name"], ev["system_id"],
               ev["galaxy_number"], ev["save_format_version"], ev["score"], len(mv),
               ", ".join("%s=%r" % kv for kv in sorted(mv.items())), EXPECTED_MISSION_SCRIPT,
               len(handlers), ", ".join(sorted(handlers)), ev["ticks"], len(ents), len(market)))


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
