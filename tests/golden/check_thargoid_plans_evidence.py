"""Offline checks on a scenario-017-thargoid-plans dump: does it prove a 1.75 SAVE was LOADED?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation). All of that is about the COMPARISON. It cannot answer the other half of the
vacuity problem, which is about the RUN - and for a SAVE-LOAD scenario that half is unusually
sharp, because a run that ignored `-load` entirely still starts, still answers every JS probe,
still exits 0 and still writes a clean log. rc=0 and an absence of ERROR lines are BOTH
satisfiable by a dead run; bead oo-het's guard caught seven expansions exactly that way.

So every check below is POSITIVE, and every one names state a DEFAULT NEW GAME CANNOT HAVE.

THE SIX DEFENCES, AND WHY A FRESH COMMANDER FAILS EACH
------------------------------------------------------
1. `evidence.load_stages` - ENGINE-EMITTED, NOT INFERRED BY THE HARNESS, and the strongest check
   here. PlayerEntityLoadSave.m:620-811 logs a fixed 14-stage sequence from "Reading file" to
   "Loading complete" on the `load.progress` channel. Those OOLog calls exist ONLY inside
   `-loadPlayerFromFile:`. A game started with no `-load` argument never enters that function and
   emits NONE of them; a load that died at "Creating player ship" emits a PREFIX. The WHOLE
   ORDERED SEQUENCE is required, so both failures are caught by name rather than by a count.

2. `evidence.mission_variables` - the full five-entry KEY->VALUE MAP. This fixture's values are
   all NON-EMPTY strings (checked BEFORE the assertion was designed), which is what lets this
   scenario assert values where scenario 015's fixture - whose `mission_trumbles` is the EMPTY
   STRING, indistinguishable over the JS bridge from an absent variable - could only assert a key
   set. A fresh commander's dictionary is EMPTY (PlayerEntity.m:1986-1987), so any non-empty map
   is save-specific by construction; the map additionally pins `conhunt == MISSION_COMPLETE`,
   the flag that arms the Thargoid Plans mission.

3. THE 1.75 SAVE-FORMAT CONTRACT, IN TWO INDEPENDENT PLACES. `save_written_by_version` == "1.75"
   says which era the fixture is from. `load_upgrade_messages` proves the loader actually
   MIGRATED it: this save carries a legacy EQ_ENERGY_BOMB, equipment that no longer exists, and
   PlayerEntity.m:1731-1746 compensates it with 9000 decicredits (900 credits) when no pylon is
   free for the EQ_QC_MINE replacement - logging "Compensated legacy energy bomb with 900
   credits." MEASURED: the first live run of this scenario went red with
   `credits: 99454.7 (saved) != 100354.7 (loaded)`, which is this migration and nothing else.
   `census_fields_migrated` records that the census added the same delta on the FILE side, so the
   round trip stays an EXACT equality instead of being loosened to a tolerance that would have
   hidden any credit bug under 900 credits.

4. `evidence.round_trip_ok` over `census_fields` - eleven fields read out of the FILE by Python's
   plist parser and out of the LIVE GAME by the JS API, in two different OS processes sharing no
   code. Commander "ThargoidPlans", 1281 kills, system Quedle: none of them is a default.

5. `evidence.thargplans_preconditions` - the Thargoid Plans mission's own arming clauses
   (oolite-thargoid-plans-mission.js:77-90), read live through the same JS the mission script
   uses. FOUR hold and ONE DOES NOT, and the false one is asserted too: JS `galaxyNumber` is
   `[player currentGalaxyID]` (OOJSGlobal.m:190-191), the SAME 0-based index the plist stores, so
   this save sits in galaxy 1 while the mission runs in galaxy 2 - one GALACTIC jump short, which
   is the step the checklist asks a human tester to perform. A first draft assumed the JS field
   was 1-based and asserted `galaxy_is_two: true`; the live run disproved it. The clause map is
   the MEASURED state, so an engine that moved the fixture's galaxy, cleared `conhunt` or rounded
   the kill score across 1280 goes red BY CLAUSE NAME.

6. `mission_variables_stable_across_ticks` - the map did not move across the tick budget, MEASURED
   both before and after. This fixture sits BEFORE the mission starts; if a future engine starts
   it inside this budget the golden goes red instead of drifting.

THE FRAME IS NOT CHECKED HERE. It cannot be: llvmpipe is not bit-reproducible (this scenario's own
sweep produced 10 distinct grid digests over 10 BYTE-IDENTICAL dumps), so the rendered frame is
compared with a MEASURED TOLERANCE against a stored reference grid by
`thargoid_plans_load.py --compare-frame`, never by byte equality. Two artifacts, two comparison
rules, each matched to what its data can support.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found); 2 a usage error - the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# The engine's own load trace, verbatim and in order (PlayerEntityLoadSave.m:620-811).
EXPECTED_LOAD_STAGES = (
    "Reading file",
    "Restricting scenario",
    "Creating player ship",
    "Initialising player entity",
    "Loading commander data",
    "Recording save path",
    "Creating system",
    "Resetting player flight variables",
    "Loading system market",
    "Setting scenario key",
    "Starting JS engine",
    "Populating initial system",
    "Completing JS startup",
    "Loading complete",
)

# The five mission variables this fixture carries, prefix stripped for JS. A fresh commander has
# NONE. Pinned as a MAP, not a key set: every value here is a NON-EMPTY string, unlike scenario
# 015's fixture where an empty value made value equality satisfiable by a game that never loaded.
EXPECTED_MISSION_VARIABLES = {
    "CT_thargonCount": "0",
    "conhunt": "MISSION_COMPLETE",
    "snoopers_CRCNews": "|",
    "snoopers_usedSlots": "0",
    "trumbles": "NOT_NOW",
}
# The variable the bead names. ABSENT from this fixture by construction - the save sits BEFORE the
# mission starts - so its absence is asserted rather than its value.
THARGPLANS_KEY = "thargplans"

# oolite-thargoid-plans-mission.js:77-90, MEASURED live. The false clause is part of the claim.
EXPECTED_PRECONDITIONS = {
    "conhunt_complete": True,
    "galaxy_is_two": False,
    "has_galactic_hyperdrive": True,
    "not_in_system_83": True,
    "score_over_1280": True,
    "thargplans_unset": True,
}

EXPECTED_SAVE_VERSION = "1.75"
# PlayerEntity.m:1731-1746. The engine's OWN record of the 1.75 migration.
EXPECTED_UPGRADE_MESSAGES = ("Compensated legacy energy bomb with 900 credits.",)
EXPECTED_MIGRATED_CENSUS_FIELDS = ("credits",)
EXPECTED_CENSUS_FIELDS = 11

REQUIRED_TRUE = ("round_trip_ok", "world_at_rest", "world_reached_fixed_point", "tick_budget_met",
                 "mission_variables_stable_across_ticks")
REQUIRED_POSITIVE = ("ticks", "census_fields", "populators_suppressed", "stations_quieted",
                     "mission_variable_count", "save_bytes")

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared.
MIN_ENTITIES = 1
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove a save was loaded."""


def check(state, label="dump"):
    """Raise EvidenceError naming the field and the value found, or return a summary dict."""
    if not isinstance(state, dict):
        raise EvidenceError("%s is %r, not a mapping" % (label, type(state)))
    ev = state.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` block. Without it the dump records a world with no claim "
            "about how that world came to be, and a comparison against it cannot distinguish a "
            "loaded save from a game that ignored -load." % label)

    for field in REQUIRED_TRUE:
        if ev.get(field) is not True:
            raise EvidenceError("%s: evidence.%s is %r, expected True"
                                % (label, field, ev.get(field)))
    for field in REQUIRED_POSITIVE:
        value = ev.get(field)
        if not isinstance(value, int) or value < 1:
            raise EvidenceError("%s: evidence.%s is %r, expected a positive integer"
                                % (label, field, value))

    # --- defence 1: the ENGINE's own load trace ------------------------------------------------
    stages = ev.get("load_stages")
    if list(stages or []) != list(EXPECTED_LOAD_STAGES):
        raise EvidenceError(
            "%s: evidence.load_stages is %r, not the %d-stage sequence PlayerEntityLoadSave.m:"
            "620-811 emits for a COMPLETED load. Those lines exist only inside "
            "-loadPlayerFromFile:, so a run that ignored -load emits none of them and a load that "
            "died partway emits a prefix; this is the one check here the engine makes rather than "
            "the harness." % (label, stages, len(EXPECTED_LOAD_STAGES)))
    # SECOND, INDEPENDENT DEFENCE on the same property. Measured on scenario 015: with the
    # sequence comparison above removed, a dump carrying NO load stages was ACCEPTED (rc=0) - the
    # property was held by one line and one line only. These clauses name the FIRST and LAST stage
    # and the count, so each defence alone rejects both the dead run (empty list) and the
    # half-load (a prefix). Deliberate redundancy, pinned behaviourally by test_thargoid_plans_load.
    if len(stages or []) != len(EXPECTED_LOAD_STAGES):
        raise EvidenceError(
            "%s: the engine logged %d load stage(s), not the %d PlayerEntityLoadSave.m emits for "
            "a completed load. An empty list is a run that never entered -loadPlayerFromFile:; a "
            "short list is a load that died partway."
            % (label, len(stages or []), len(EXPECTED_LOAD_STAGES)))
    bounds_ok = bool(stages) and stages[0] == EXPECTED_LOAD_STAGES[0] \
        and stages[-1] == EXPECTED_LOAD_STAGES[-1]
    if not bounds_ok:
        raise EvidenceError(
            "%s: the engine's load trace does not run from %r to %r (it reads %r). "
            "\"Loading complete\" is logged at PlayerEntityLoadSave.m:811, AFTER the deserialiser "
            "has finished, so its absence means the load did not complete."
            % (label, EXPECTED_LOAD_STAGES[0], EXPECTED_LOAD_STAGES[-1], stages))
    if ev.get("load_failures"):
        raise EvidenceError("%s: the engine logged load failure(s): %r"
                            % (label, ev["load_failures"]))

    # --- defence 2: mission variables, which a fresh commander does not have -------------------
    mv = ev.get("mission_variables")
    if not isinstance(mv, dict) or mv != EXPECTED_MISSION_VARIABLES:
        raise EvidenceError(
            "%s: evidence.mission_variables is %r, not the save's %r. A DEFAULT NEW GAME HAS NO "
            "MISSION VARIABLES AT ALL (PlayerEntity.m:1986-1987), which is exactly why this check "
            "cannot be satisfied by a run that never loaded the save. Compared as a KEY->VALUE "
            "MAP because every value in THIS fixture is a non-empty string - scenario 015's "
            "fixture had an empty one and could only compare keys."
            % (label, mv, EXPECTED_MISSION_VARIABLES))
    # SECOND, INDEPENDENT DEFENCE on the same property: name the single most load-bearing entry.
    # `conhunt == MISSION_COMPLETE` is the flag that ARMS the Thargoid Plans mission, and it is
    # the one value a save from any other point in the campaign would not have.
    if mv.get("conhunt") != "MISSION_COMPLETE":
        raise EvidenceError(
            "%s: missionVariables.conhunt is %r, not 'MISSION_COMPLETE'. That flag is the clause "
            "oolite-thargoid-plans-mission.js:78 tests to arm this mission; without it the "
            "fixture is not positioned where this scenario says it is."
            % (label, mv.get("conhunt")))
    if THARGPLANS_KEY in mv:
        raise EvidenceError(
            "%s: missionVariables carries a %r key (%r). This fixture sits BEFORE the Thargoid "
            "Plans mission starts and the variable is ABSENT by construction; an engine that "
            "started the mission inside this scenario's budget is a FINDING about the mission "
            "script, not a value to record quietly." % (label, THARGPLANS_KEY, mv[THARGPLANS_KEY]))
    if ev.get("thargplans_present") is not False:
        raise EvidenceError(
            "%s: evidence.thargplans_present is %r, expected False - the fixture predates the "
            "mission." % (label, ev.get("thargplans_present")))

    # --- defence 3: the 1.75 save-format contract, in TWO independent places --------------------
    if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:
        raise EvidenceError(
            "%s: evidence.save_written_by_version is %r, expected %r. This scenario exists partly "
            "to pin the 1.75-era save-format compatibility contract; a different fixture does not "
            "pin it." % (label, ev.get("save_written_by_version"), EXPECTED_SAVE_VERSION))
    upgrades = list(ev.get("load_upgrade_messages") or [])
    if upgrades != list(EXPECTED_UPGRADE_MESSAGES):
        raise EvidenceError(
            "%s: evidence.load_upgrade_messages is %r, not %r. This save carries a legacy "
            "EQ_ENERGY_BOMB - equipment that no longer exists - and PlayerEntity.m:1731-1746 "
            "compensates it with 9000 decicredits on load, SAYING SO on the "
            "load.upgrade.replacedEnergyBomb channel. The census adds that same delta on the file "
            "side, so without the engine's own line the adjusted arithmetic would be an "
            "unfalsifiable fudge factor. THE VERSION STRING ALONE IS NOT ENOUGH: it is copied out "
            "of the plist by the harness, whereas this line is emitted by the loader actually "
            "performing the migration." % (label, upgrades, list(EXPECTED_UPGRADE_MESSAGES)))
    migrated = sorted(ev.get("census_fields_migrated") or [])
    if migrated != sorted(EXPECTED_MIGRATED_CENSUS_FIELDS):
        raise EvidenceError(
            "%s: evidence.census_fields_migrated is %r, expected %r. If the migration stopped "
            "being applied to the file side while the engine kept performing it, the round trip "
            "would go red on a CORRECT engine; if it were applied while the engine stopped, the "
            "round trip would go red the other way. Both are caught by name here."
            % (label, migrated, sorted(EXPECTED_MIGRATED_CENSUS_FIELDS)))

    # --- defence 4: the census, read by two independent readers --------------------------------
    if ev.get("census_fields") != EXPECTED_CENSUS_FIELDS:
        raise EvidenceError(
            "%s: evidence.census_fields is %r, expected %d. A shrinking census is the empty-state "
            "vacuity route wearing a smaller hat."
            % (label, ev.get("census_fields"), EXPECTED_CENSUS_FIELDS))
    if ev.get("round_trip_fields_equal") != ev.get("census_fields"):
        raise EvidenceError(
            "%s: only %r of %r census field(s) agree between the save file and the loaded game"
            % (label, ev.get("round_trip_fields_equal"), ev.get("census_fields")))

    # --- defence 5: the mission's own arming clauses, MEASURED ---------------------------------
    pre = ev.get("thargplans_preconditions")
    if not isinstance(pre, dict) or pre != EXPECTED_PRECONDITIONS:
        raise EvidenceError(
            "%s: evidence.thargplans_preconditions is %r, not the MEASURED %r. These are "
            "oolite-thargoid-plans-mission.js:77-90's own clauses read live. THE FALSE ONE IS "
            "PART OF THE CLAIM: JS galaxyNumber is [player currentGalaxyID] (OOJSGlobal.m:"
            "190-191), the same 0-based index the plist stores, so this save is in galaxy 1 while "
            "the mission runs in galaxy 2 - one GALACTIC jump short, which is the step the "
            "checklist asks a human tester to perform. A first draft of this scenario asserted "
            "galaxy_is_two=true on the assumption that JS was 1-based, and the live run disproved "
            "it." % (label, pre, EXPECTED_PRECONDITIONS))
    # SECOND, INDEPENDENT DEFENCE: the kill score clause is the one a rounding or reset bug in the
    # loader would break, and 1281 is ONE over the threshold, so it has no margin at all.
    if pre.get("score_over_1280") is not True:
        raise EvidenceError(
            "%s: the loaded commander does not have more than 1280 kills. The save stores 1281 - "
            "ONE over oolite-thargoid-plans-mission.js:80's threshold - so a loader that reset or "
            "rounded the score disarms the mission, and this fixture is built with no margin "
            "precisely to catch that." % label)

    # --- the dump's own shape ------------------------------------------------------------------
    entities = state.get("entities")
    if not isinstance(entities, list) or len(entities) < MIN_ENTITIES:
        raise EvidenceError(
            "%s: %r entities, fewer than the %d minimum. A dump with no world in it compares "
            "equal to any other empty world."
            % (label, len(entities) if isinstance(entities, list) else entities, MIN_ENTITIES))
    market = state.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        raise EvidenceError(
            "%s: the market carries %r good(s), fewer than the %d minimum; the save's own market "
            "was not loaded."
            % (label, len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))

    return {
        "load_stages": len(stages),
        "mission_variables": mv,
        "upgrade_messages": upgrades,
        "migrated_fields": migrated,
        "preconditions": pre,
        "census_fields": ev["census_fields"],
        "save_written_by_version": ev["save_written_by_version"],
        "entities": len(entities),
        "market_goods": len(market),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_thargoid_plans_evidence.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)

    label = args.label or args.dump
    if not os.path.isfile(args.dump):
        sys.stderr.write("USAGE ERROR: no such dump: %s\n" % args.dump)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            state = json.load(handle)
    except ValueError as exc:
        sys.stderr.write("USAGE ERROR: %s is not readable JSON: %s\n" % (args.dump, exc))
        return 2

    try:
        summary = check(state, label)
    except EvidenceError as exc:
        sys.stderr.write("NO EVIDENCE: %s\n" % exc)
        return 1
    print("EVIDENCE OK (%s): the engine logged all %d load stages, the loaded game carries the "
          "save's %d mission variable(s) %r with conhunt=MISSION_COMPLETE and NO thargplans, the "
          "%s-era save was MIGRATED by the loader (%r, census field(s) %r adjusted by the same "
          "delta) and round-trips on all %d census field(s), and the mission's arming clauses "
          "read %r. %d entities, %d market goods."
          % (label, summary["load_stages"], len(summary["mission_variables"]),
             summary["mission_variables"], summary["save_written_by_version"],
             summary["upgrade_messages"], summary["migrated_fields"], summary["census_fields"],
             summary["preconditions"], summary["entities"], summary["market_goods"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
