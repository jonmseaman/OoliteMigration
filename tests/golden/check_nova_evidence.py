"""Offline checks on a scenario-014-nova dump: does it prove THIS save was LOADED?

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

2. `evidence.mission_variable_keys` - the save carries five mission variables. A fresh commander's
   dictionary is EMPTY (PlayerEntity.m:1986-1987 allocates a new empty NSMutableDictionary), so a
   non-empty key set is save-specific by construction. Checked as a KEY SET first, because a
   mission variable whose value is the EMPTY STRING reads identically to an absent one - the trap
   scenario 015 was built around, where `mission_trumbles` was ''.
   THIS FIXTURE CAN DO BETTER, AND DOES: `mission_novacount` - one of the two variables the bead
   names - holds the NON-EMPTY value '3', so it is ALSO checked BY VALUE. A value check is
   strictly stronger where a value exists and worthless where it does not; both are applied where
   they apply. `mission_nova`, the other variable the bead names, is ABSENT from this fixture,
   and that absence is asserted too: the nova mission sets it when it runs, so its appearance
   would mean the loaded game is not this save, and an unasserted mention is how a claim becomes
   decoration.

3. THE SAVE-FORMAT CONTRACT, IN TWO INDEPENDENT HALVES.
   (a) SHAPE. `save_written_by_version` must be EMPTY. The bead's story calls this fixture
       1.75-era; measured, it is OLDER - `written_by_version` is written by every 1.75 save and
       this file has no such key, along with four more keys the 1.75 Trumbles fixture carries,
       while three legacy-only keys are present. Both sets are pinned so a fixture swap to a
       NEWER file - the easy mistake - goes red instead of quietly weakening the contract.
   (b) MIGRATION. This save carries `has_energy_bomb`, an item Oolite REMOVED.
       PlayerEntity.m:1730-1746 tries to replace it with a Quirium cascade mine, finds all four
       pylons already holding EQ_HARDENED_MISSILEs, and falls through to `credits += 9000`
       (deci-credits = 900 Cr), logging on the `load.upgrade` channel. `legacy_upgrades` requires
       that log line, and the credits census field independently predicts the ARITHMETIC
       (933068 in the plist -> 94206.8 live, exactly 900 Cr more). TWO WITNESSES OF ONE ENGINE
       BEHAVIOUR: a checker holding only the number would pass for a coincidence, and one holding
       only the log line would not notice a changed amount.

4. `evidence.galaxy_number` == 3. A new commander starts in galaxy 0; reaching galaxy 3 takes
   three galactic hyperdrive jumps. No default game is there.

5. `evidence.round_trip_ok` over `census_fields` - nine fields read out of the FILE by Python's
   plist parser and out of the LIVE GAME by the JS API, in two different OS processes sharing no
   code. Commander 'Tester', 93306.8 saved credits, 1634 kills: none is a default.

6. The dump's own shape - entities and market floors, so a truncated or half-written dump is
   rejected here rather than silently compared.

THE FRAME IS NOT CHECKED HERE. It cannot be: llvmpipe is not bit-reproducible (bead oo-ae9
measured 0 of 3 same-scene pairs byte-identical), so the rendered frame is compared against a
stored reference grid by `nova_load.py --compare-frame`, never by byte equality.

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
# NONE. Pinned as a SET, not a floor, so a run that loaded a DIFFERENT save cannot satisfy this.
EXPECTED_MISSION_VARIABLE_KEYS = frozenset((
    "TL_FOR_EQ_NAVAL_ENERGY_UNIT", "conhunt", "novacount", "thargplans", "trumbles",
))
MISSION_NOVACOUNT_KEY = "novacount"
EXPECTED_MISSION_NOVACOUNT_VALUE = "3"
# The OTHER variable the bead names, and it is ABSENT from this fixture. Asserted, not assumed.
MISSION_NOVA_KEY = "nova"

# EMPTY, and deliberately: this fixture predates the 1.75 saves that write the key.
EXPECTED_SAVE_VERSION = ""
EXPECTED_SAVE_FORMAT_KEYS_PRESENT = ("has_energy_bomb", "ootunes_on", "reducedDetail", "saved")
EXPECTED_SAVE_FORMAT_KEYS_ABSENT = ("current_system_name", "entity_personality",
                                    "fuel_charge_rate", "ship_name", "written_by_version")
EXPECTED_LEGACY_UPGRADES = ("Compensated legacy energy bomb with 900 credits.",)
EXPECTED_GALAXY_NUMBER = 3
EXPECTED_CENSUS_FIELDS = 9

REQUIRED_TRUE = ("round_trip_ok", "world_at_rest", "world_reached_fixed_point", "tick_budget_met")
REQUIRED_FALSE = ("mission_nova_present",)
REQUIRED_POSITIVE = ("ticks", "census_fields", "populators_suppressed", "stations_quieted",
                     "mission_variable_count", "save_bytes", "save_top_level_keys")

# Floors on the dump's own shape, under what a real run produces.
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
    for field in REQUIRED_FALSE:
        if ev.get(field) is not False:
            raise EvidenceError("%s: evidence.%s is %r, expected False"
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
    # SECOND, INDEPENDENT DEFENCE on the same property, and it is deliberate redundancy rather
    # than duplication: bead oo-jor's survivor showed a critical property held by exactly one line
    # is one refactor away from being held by none. These clauses name the COUNT and the FIRST and
    # LAST stage, so each alone rejects both the dead run (empty list) and the half-load (prefix).
    # Each defence is pinned behaviourally by test_nova_load.py, which deletes it from a THROWAWAY
    # copy and asserts the copy still rejects a known-bad dump.
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
    keys = set(ev.get("mission_variable_keys") or ())
    if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):
        raise EvidenceError(
            "%s: evidence.mission_variable_keys is %r, not the save's %r. A DEFAULT NEW GAME HAS "
            "NO MISSION VARIABLES AT ALL (PlayerEntity.m:1986-1987), which is exactly why this "
            "check cannot be satisfied by a run that never loaded the save."
            % (label, sorted(keys), sorted(EXPECTED_MISSION_VARIABLE_KEYS)))
    if MISSION_NOVACOUNT_KEY not in keys:
        raise EvidenceError(
            "%s: missionVariables carries no %r key - one of the two mission variables this bead "
            "names." % (label, MISSION_NOVACOUNT_KEY))
    if ev.get("mission_novacount_value") != EXPECTED_MISSION_NOVACOUNT_VALUE:
        raise EvidenceError(
            "%s: missionVariables.%s is %r, expected %r. This variable is NON-EMPTY in this "
            "fixture, so unlike scenario 015's mission_trumbles it can be checked BY VALUE as "
            "well as by presence - and a value check is strictly stronger where a value exists."
            % (label, MISSION_NOVACOUNT_KEY, ev.get("mission_novacount_value"),
               EXPECTED_MISSION_NOVACOUNT_VALUE))
    if MISSION_NOVA_KEY in keys:
        raise EvidenceError(
            "%s: missionVariables carries a %r key, which this fixture does NOT have. The nova "
            "mission sets it when it runs, so its presence means the loaded game is not this "
            "save. The bead names mission_nova; asserting its ABSENCE is what keeps that from "
            "being an unchecked mention." % (label, MISSION_NOVA_KEY))

    # --- defence 3: the save-format contract, shape AND migration ------------------------------
    if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:
        raise EvidenceError(
            "%s: evidence.save_written_by_version is %r, expected %r. The EMPTY expectation is "
            "not an oversight: every Oolite 1.75 save writes this key and this fixture has no "
            "such key, so it predates that era and pins a STRICTLY OLDER compatibility contract. "
            "A fixture that acquired the key would be a newer file."
            % (label, ev.get("save_written_by_version"), EXPECTED_SAVE_VERSION))
    if list(ev.get("save_format_keys_present") or []) != sorted(EXPECTED_SAVE_FORMAT_KEYS_PRESENT):
        raise EvidenceError(
            "%s: evidence.save_format_keys_present is %r, expected %r - the legacy-only keys this "
            "fixture carries."
            % (label, ev.get("save_format_keys_present"),
               sorted(EXPECTED_SAVE_FORMAT_KEYS_PRESENT)))
    if list(ev.get("save_format_keys_absent") or []) != sorted(EXPECTED_SAVE_FORMAT_KEYS_ABSENT):
        raise EvidenceError(
            "%s: evidence.save_format_keys_absent is %r, expected %r - the keys a 1.75-era save "
            "carries and this older one does not."
            % (label, ev.get("save_format_keys_absent"), sorted(EXPECTED_SAVE_FORMAT_KEYS_ABSENT)))
    if list(ev.get("legacy_upgrades") or []) != sorted(EXPECTED_LEGACY_UPGRADES):
        raise EvidenceError(
            "%s: evidence.legacy_upgrades is %r, expected %r. This fixture carries "
            "has_energy_bomb - an item Oolite REMOVED - and PlayerEntity.m:1730-1746 compensates "
            "it with 900 Cr because all four pylons already hold hardened missiles. That log line "
            "is the ENGINE's own witness of the migration; the credits census field predicts its "
            "arithmetic independently. Both must hold, or the loader has changed how it treats "
            "pre-1.75 saves."
            % (label, ev.get("legacy_upgrades"), sorted(EXPECTED_LEGACY_UPGRADES)))

    # --- defence 4: galaxy 3, three galactic jumps from a new commander ------------------------
    if ev.get("galaxy_number") != EXPECTED_GALAXY_NUMBER:
        raise EvidenceError(
            "%s: evidence.galaxy_number is %r, expected %d. A DEFAULT NEW GAME IS IN GALAXY 0."
            % (label, ev.get("galaxy_number"), EXPECTED_GALAXY_NUMBER))

    # --- defence 5: the census, read by two independent readers --------------------------------
    if ev.get("census_fields") != EXPECTED_CENSUS_FIELDS:
        raise EvidenceError(
            "%s: evidence.census_fields is %r, expected %d. A shrinking census is the empty-state "
            "vacuity route wearing a smaller hat."
            % (label, ev.get("census_fields"), EXPECTED_CENSUS_FIELDS))
    if ev.get("round_trip_fields_equal") != ev.get("census_fields"):
        raise EvidenceError(
            "%s: only %r of %r census field(s) agree between the save file and the loaded game"
            % (label, ev.get("round_trip_fields_equal"), ev.get("census_fields")))
    # SECOND, INDEPENDENT DEFENCE on non-vacuity of the census: a census of zeros and empty
    # strings compares equal to any other empty census, so a FIELD COUNT alone is not enough.
    populated = ev.get("census_populated")
    if not isinstance(populated, int) or populated < EXPECTED_CENSUS_FIELDS // 2:
        raise EvidenceError(
            "%s: only %r of %r census field(s) carry a non-empty value. A census of zeros and "
            "empty strings compares equal to any other empty census."
            % (label, populated, ev.get("census_fields")))

    # --- the fourth traffic source, which only this scenario's system has ----------------------
    # Every station whose launch schedule was switched off must ALSO have had its own AI
    # silenced. hasNPCTraffic gates the ordinary trader schedule; a rock hermit's rockHermitAI
    # calls launchMiner on its own 20 s cycle (StationEntity.m:1736-1776) and is untouched by it.
    # MEASURED before that suppression existed: 10 runs, FOUR distinct dump digests, three of them
    # carrying an extra Mining Transporter entity. A dump taken without it is a race, and the race
    # is invisible in the dump unless this is checked.
    silenced = ev.get("station_ais_silenced")
    if not isinstance(silenced, list) or len(silenced) != ev.get("stations_quieted"):
        raise EvidenceError(
            "%s: evidence.station_ais_silenced is %r for %r station(s) whose launch schedule was "
            "switched off. A station left with its own AI running launches traffic no "
            "hasNPCTraffic flag gates, and the resulting dump depends on when the harness looked."
            % (label, silenced, ev.get("stations_quieted")))

    # --- defence 6: the dump's own shape -------------------------------------------------------
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
        "mission_variables": sorted(keys),
        "novacount": ev["mission_novacount_value"],
        "galaxy_number": ev["galaxy_number"],
        "census_fields": ev["census_fields"],
        "legacy_upgrades": list(ev["legacy_upgrades"]),
        "save_written_by_version": ev["save_written_by_version"],
        "entities": len(entities),
        "market_goods": len(market),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_nova_evidence.py",
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
          "save's %d mission variable(s) %s with novacount=%r and no `nova` key, sits in galaxy "
          "%d, round-trips on all %d census field(s), and the pre-1.75 save-format contract holds "
          "(written_by_version=%r, engine-logged migration %r). %d entities, %d market goods."
          % (label, summary["load_stages"], len(summary["mission_variables"]),
             summary["mission_variables"], summary["novacount"], summary["galaxy_number"],
             summary["census_fields"], summary["save_written_by_version"],
             summary["legacy_upgrades"], summary["entities"], summary["market_goods"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
