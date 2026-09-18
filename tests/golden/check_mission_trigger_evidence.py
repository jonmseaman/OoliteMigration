"""Offline checks on a scenario-005-mission-trigger dump: did a MISSION SCRIPT ACTUALLY FIRE?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation). All of that is about the COMPARISON. It cannot answer the other half of the vacuity
problem, which is about the RUN: a scenario that crashed during display init and dumped a
near-empty world reproduces byte-for-byte perfectly and proves nothing. Two runs of a dead
scenario agree. So this file checks the CONTENT.

AND FOR A MISSION-TRIGGER GOLDEN THERE IS A SHARPER VACUITY: a dump proving only that "a save was
loaded" cannot distinguish state the DESERIALISER COPIED from state a MISSION SCRIPT WROTE. Every
clause below was chosen because a measured control arm FAILS it.

THE THREE ARMS, MEASURED ON THIS BOX (see the README for the full table)
-----------------------------------------------------------------------
                            commander       galaxy  cloakcounter        populator  asp-cloaked
  subject  CloakingDevice   CloakingDevice  4       6 on disk -> 7      yes        1
  control  Constrictor      Constrictor     1       absent              no         0
  control  no -load         Jameson         0       absent (no script)  no         0

THE CORE ASSERTION: engine == file + 1
--------------------------------------
`oolite-cloaking-device-mission.js:62` runs `missionVariables.cloakcounter++` inside the
`systemWillPopulate` handler. The fixture holds 6 on disk. A value the deserialiser merely copied
would read 6; only the mission script's own increment produces 7. The dump therefore carries BOTH
numbers - `mission_counter_in_file` (parsed from the .oolite-save) and `mission_counter_in_engine`
(read from the running game) - and this checker asserts the relation, not two constants, so the
clause remains a statement about the TRIGGER rather than a pair of magic values.

That is backed by the two other consequences of the SAME `if` block, because a counter is a single
witness:
  * DEFENCE B: `oolite-cloaking-device-mission` is registered in `system.populatorSettings` - a key
    created by that block's `system.setPopulator()` call (:71) and by nothing else;
  * DEFENCE C: the ambush exists - 1 `asp-cloaked` and 2 `asp-pirate` (:77-80).
The Constrictor control arm fails all three while still being a fully loaded, fully alive game.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and both
values). A usage error is 2 - "I cannot tell you", never "they match" - the convention golden_diff
established.
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry as True, with the value a REAL triggered run produces.
REQUIRED_TRUE = ("clock_at_or_past_save", "docked", "tick_budget_met", "mission_script_loaded",
                 "mission_counter_present", "ambush_populator_registered")
REQUIRED_POSITIVE = ("ticks", "score", "save_bytes")

# THE IDENTITY OF THE SAVE. A run that ignored -load is Jameson in Lave; a run of a DIFFERENT
# checklist save is a different commander in a different system. Pinned as equalities, not floors.
EXPECTED_COMMANDER = "CloakingDevice"
EXPECTED_SYSTEM_NAME = "Atdice"
EXPECTED_SYSTEM_ID = 80

# The trigger's own guard is `galaxyNumber === 4` (oolite-cloaking-device-mission.js:50). In any
# other galaxy the handler returns immediately and the scenario measures nothing, so this is a
# precondition of the whole file, not decoration.
EXPECTED_GALAXY = 4
EXPECTED_SCORE = 1661

# The 1.75-era save-format contract this fixture also pins.
EXPECTED_SAVE_FORMAT = "1.75"
EXPECTED_SAVE_FILE = "CloakingDevice.oolite-save"

# --- DEFENCE A: the counter the mission script INCREMENTED --------------------------------------
# Asserted as a RELATION (engine == file + 1) and, separately, as the two measured values, so that
# neither a dump which lost the file-side number nor one which lost the increment can pass.
EXPECTED_COUNTER_KEY = "cloakcounter"
EXPECTED_COUNTER_IN_FILE = 6
EXPECTED_COUNTER_IN_ENGINE = 7

# --- DEFENCE B: the populator the SAME `if` block registered ------------------------------------
EXPECTED_POPULATOR = "oolite-cloaking-device-mission"

# --- DEFENCE C: the ambush that populator's callback spawned ------------------------------------
EXPECTED_SPAWNED_ROLES = {"asp-cloaked": 1, "asp-pirate": 2}

# --- the script object itself --------------------------------------------------------------------
EXPECTED_MISSION_SCRIPT = "oolite-cloaking-device"
EXPECTED_LIVE_HANDLERS = ("startUp", "systemWillPopulate")

# The measured post-trigger mission variables. Pinned as an exact mapping, not a subset: a run that
# loaded a different save has a different set and a fresh game has an EMPTY one.
EXPECTED_MISSION_VARIABLES = {
    "CT_thargonCount": 0,
    "TL_FOR_EQ_NAVAL_ENERGY_UNIT": 13,
    "cloakcounter": 7,
    "conhunt": "MISSION_COMPLETE",
    "nova": "NOVA_HERO",
    "novacount": 4,
    "snoopers_CRCNews": "|",
    "snoopers_usedSlots": 0,
    "thargplans": "MISSION_COMPLETE",
    "trumbles": "NOT_NOW",
}

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared.
MIN_ENTITIES = 1
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove a mission script fired from a world-script event."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that any mission "
            "script ever ran, and two such dumps agreeing proves only that the same nothing "
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
                        ("save_format_version", EXPECTED_SAVE_FORMAT),
                        ("save_file", EXPECTED_SAVE_FILE),
                        ("score", EXPECTED_SCORE)):
        if ev.get(field) != want:
            problems.append(
                "evidence.%s is %r but this scenario loads %s, whose value is %r. A run that "
                "ignored -load reads commander 'Jameson' in 'Lave' (ID 7, galaxy 0); a run of a "
                "different checklist save reads that save's own values."
                % (field, ev.get(field), EXPECTED_SAVE_FILE, want))

    if ev.get("galaxy_number") != EXPECTED_GALAXY:
        problems.append(
            "evidence.galaxy_number is %r, expected %r. This is a PRECONDITION of everything "
            "below: oolite-cloaking-device-mission.js:50 guards the whole handler with "
            "`galaxyNumber === 4`, so in any other galaxy the trigger cannot fire and the dump "
            "records a mission script that did nothing." % (ev.get("galaxy_number"), EXPECTED_GALAXY))

    # --- DEFENCE A: the increment -------------------------------------------------------------
    if ev.get("mission_counter_key") != EXPECTED_COUNTER_KEY:
        problems.append("evidence.mission_counter_key is %r, expected %r"
                        % (ev.get("mission_counter_key"), EXPECTED_COUNTER_KEY))

    in_file = ev.get("mission_counter_in_file")
    in_engine = ev.get("mission_counter_in_engine")
    if in_file != EXPECTED_COUNTER_IN_FILE:
        problems.append(
            "evidence.mission_counter_in_file is %r, expected %r. That EXACT fixture value is "
            "load-bearing: the mission script spawns the ambush only once the INCREMENTED counter "
            "exceeds 6 (oolite-cloaking-device-mission.js:66), so a different value on disk would "
            "change whether defences B and C below mean anything."
            % (in_file, EXPECTED_COUNTER_IN_FILE))
    if in_engine != EXPECTED_COUNTER_IN_ENGINE:
        problems.append(
            "evidence.mission_counter_in_engine is %r, expected %r"
            % (in_engine, EXPECTED_COUNTER_IN_ENGINE))
    if not isinstance(in_file, int) or not isinstance(in_engine, int):
        problems.append(
            "evidence.mission_counter_in_file/%r and mission_counter_in_engine/%r must both be "
            "integers: the relation this scenario exists to assert cannot be evaluated otherwise"
            % (in_file, in_engine))
    elif in_engine != in_file + 1:
        problems.append(
            "evidence.mission_counter_in_engine is %r but the save file holds %r, so the expected "
            "post-trigger value is %r. THIS IS THE ASSERTION THE SCENARIO EXISTS FOR: a value the "
            "deserialiser merely COPIED out of the save reads the file's value; only the mission "
            "script's own `missionVariables.cloakcounter++` (oolite-cloaking-device-mission.js:62) "
            "produces file+1. An equal pair means the save was loaded and the WORLD-SCRIPT EVENT "
            "never ran the handler." % (in_engine, in_file, in_file + 1))

    # --- DEFENCE B: the populator the same `if` block registered -------------------------------
    if ev.get("ambush_populator") != EXPECTED_POPULATOR:
        problems.append("evidence.ambush_populator is %r, expected %r"
                        % (ev.get("ambush_populator"), EXPECTED_POPULATOR))
    if ev.get("ambush_populator_registered") is not True:
        problems.append(
            "evidence.ambush_populator_registered is %r: %r was not among the system's populator "
            "settings. The mission script creates that key with system.setPopulator() inside the "
            "SAME `if` block as the counter increment (oolite-cloaking-device-mission.js:71-89), "
            "so its absence means the block did not run. This is the second, independent witness "
            "to the trigger, and the Constrictor control arm fails it."
            % (ev.get("ambush_populator_registered"), EXPECTED_POPULATOR))

    # --- DEFENCE C: the ships that populator's callback spawned --------------------------------
    counts = ev.get("spawned_role_counts")
    if not isinstance(counts, dict):
        problems.append(
            "evidence.spawned_role_counts is %r, expected an object. Without it the dump has no "
            "record that the ambush was ever in the world." % (counts,))
    elif counts != EXPECTED_SPAWNED_ROLES:
        problems.append(
            "evidence.spawned_role_counts is %r but the measured set is %r. These ships are what "
            "the ambush populator's callback spawns (1 asp-cloaked, 2 asp-pirate, literals at "
            "oolite-cloaking-device-mission.js:77-80). Their identities are a RANROT role draw and "
            "are deliberately NOT pinned; their COUNT is fixed by the script. Both controls read "
            "zero asp-cloaked." % (counts, EXPECTED_SPAWNED_ROLES))

    # --- the live script object ----------------------------------------------------------------
    if ev.get("mission_script") != EXPECTED_MISSION_SCRIPT:
        problems.append("evidence.mission_script is %r, expected %r"
                        % (ev.get("mission_script"), EXPECTED_MISSION_SCRIPT))
    handlers = ev.get("live_mission_handlers")
    if not isinstance(handlers, list) or not handlers:
        problems.append(
            "evidence.live_mission_handlers is %r: no event handler of %s was live in the running "
            "game. A game with no commander loaded has not built the script at all, so an empty "
            "list is the dead-run and fresh-game signature." % (handlers, EXPECTED_MISSION_SCRIPT))
    elif sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS):
        problems.append(
            "evidence.live_mission_handlers is %r but the measured set is %r. These are `typeof` "
            "reads off a LIVE JS object inside the engine: systemWillPopulate must still be a "
            "function, because `startUp` deletes it when the mission is already resolved "
            "(oolite-cloaking-device-mission.js:38-45) and a script without the handler cannot "
            "have been the thing that fired."
            % (sorted(handlers), sorted(EXPECTED_LIVE_HANDLERS)))

    # --- the restored mission variables --------------------------------------------------------
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
            "evidence.mission_variables is %r but this save's measured POST-TRIGGER set is %r "
            "(missing %r, unexpected %r, wrong value %r). Note cloakcounter is 7 here, not the "
            "file's 6. A DEFAULT NEW GAME's missionVariables is EMPTY, so this clause alone "
            "rejects a run that never loaded a save."
            % (mv, EXPECTED_MISSION_VARIABLES, missing, extra, wrong))

    # The bead names the mission variables as a required part of the DUMP, not only of the evidence
    # block, and a consumer should not need the evidence schema to find them. Both copies must agree.
    top = data.get("mission_variables")
    if not isinstance(top, dict):
        problems.append(
            "the dump has no top-level `mission_variables`; the bead requires the canonical dump "
            "itself to carry the mission state, not only the evidence block")
    elif top != mv:
        problems.append(
            "the dump's top-level mission_variables %r disagrees with evidence.mission_variables "
            "%r; one of the two was edited alone" % (top, mv))

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
        raise EvidenceError("%s does not prove a mission script fired from a world-script event:"
                            "\n  %s" % (label, "\n  ".join(problems)))

    return ("%s: MISSION TRIGGER FIRED - %s loaded (commander %r in %s, ID %d, galaxy %d, %s-era "
            "save, score %d); the systemWillPopulate world-script event ran %s, which incremented "
            "missionVariables.%s from %d ON DISK to %d IN THE ENGINE, registered the %r populator "
            "and spawned the ambush (%s); %d mission variable(s) restored; %d live handler(s) "
            "(%s); ran %d ticks; %d entities, %d market goods"
            % (label, EXPECTED_SAVE_FILE, ev["commander_name"], ev["system_name"], ev["system_id"],
               ev["galaxy_number"], ev["save_format_version"], ev["score"],
               EXPECTED_MISSION_SCRIPT, EXPECTED_COUNTER_KEY, in_file, in_engine,
               EXPECTED_POPULATOR,
               ", ".join("%s=%d" % kv for kv in sorted(counts.items())), len(mv),
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
