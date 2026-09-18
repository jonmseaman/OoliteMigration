"""Offline checks on a scenario-015-trumbles dump: does it prove a SAVE was LOADED?

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

2. `evidence.mission_variable_keys` - the save carries five mission variables including
   `mission_trumbles`, the field the bead names. A fresh commander's dictionary is EMPTY
   (PlayerEntity.m:1986-1987 allocates a new empty NSMutableDictionary), so a non-empty key set is
   save-specific by construction. Checked as a KEY SET, never by value: this fixture's
   `mission_trumbles` is the EMPTY STRING and an absent mission variable also reads as empty, so
   value equality would be satisfied by a game that had never heard of the mission.

3. `evidence.save_written_by_version` == "1.75". The fixture is a 1.75-era file, so this scenario
   also pins the save-format compatibility contract: the field is copied out of the plist the
   engine actually loaded.

4. `evidence.round_trip_ok` over `census_fields` - eleven fields read out of the FILE by Python's
   plist parser and out of the LIVE GAME by the JS API, in two different OS processes sharing no
   code. Commander "Trumbles", credits 6553.4, the 1.75 ship clock: none of them is a default.

5. THE TRUMBLE POPULATION, BOTH HALVES.
   `saved_trumble_count` is the population the save's own anti-cheat checksum authorises. The
   fixture's `trumbles` value is [0, 20936, [24 dicts]]; recomputing munge_checksum
   (legacy_random.c:48-57) over this commander's name, credits and kills yields 20936 for n=0 and
   for NO other n in 0..23, so the loader accepts 0 and cannot silently substitute another count
   via its search at PlayerEntity.m:12112-12125. `checksum_authorises_stored_count` records that
   uniqueness and `cheat_messages` must be empty - the engine logs "POSSIBLE CHEAT DETECTED" when
   the checksum disagrees, so an empty list here is meaningful only BECAUSE the channels were on
   (defence 1 proves they were).
   `trumble_award_series` is the LIVE population grown by awards, and it must be exactly
   [1, 2, ..., N] for N = PLAYER_MAX_TRUMBLES/6 = 4. That is the measured deterministic prefix of
   PlayerEntity.m:11531's award gate; the fifth award onwards is a RANROT draw whose outcome
   MEASURABLY differs between runs at the same seed. A checker that accepted any series, or a
   spec that raised N, would be trading a real property for a flaky golden.

6. `trumble_count_stable_across_ticks` - the population did not move across the tick budget.
   Breeding needs `trumbleAppetiteAccumulator > 10.0` from eating CARGO PODS (OOTrumble.m:585-627)
   and a docked player has none, so this is the assertion that the golden's count is a fixed point
   rather than a stopwatch reading. If a future engine breeds inside the budget, this goes red.

THE FRAME IS NOT CHECKED HERE. It cannot be: llvmpipe is not bit-reproducible (bead oo-ae9
measured 0 of 3 same-scene pairs byte-identical), so the rendered frame is compared with a
MEASURED TOLERANCE against a stored reference grid by `trumbles_load.py --compare-frame`, never by
byte equality. Two artifacts, two comparison rules, each matched to what its data can support.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found); 2 a usage error - the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# PlayerEntity.h:312, and the constant that makes 4 the deterministic prefix rather than a
# convenient number: the award gate's unconditional branch is `trumbleCount < MAX/6`.
PLAYER_MAX_TRUMBLES = 24
DETERMINISTIC_AWARD_PREFIX = PLAYER_MAX_TRUMBLES // 6

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
    "CT_thargonCount", "snoopers_CRCNews", "snoopers_dateCheck", "snoopers_usedSlots", "trumbles",
))
MISSION_TRUMBLES_KEY = "trumbles"

EXPECTED_SAVE_VERSION = "1.75"
EXPECTED_SAVED_TRUMBLE_COUNT = 0
EXPECTED_TRUMBLE_CHECKSUM = 20936
EXPECTED_CENSUS_FIELDS = 11

REQUIRED_TRUE = ("round_trip_ok", "world_at_rest", "world_reached_fixed_point", "tick_budget_met",
                 "checksum_authorises_stored_count", "trumble_count_stable_across_ticks")
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
    # SECOND, INDEPENDENT DEFENCE on the same property. Measured: with the sequence comparison
    # above removed, a dump carrying NO load stages was ACCEPTED (rc=0) - the property was held by
    # one line and one line only, which is precisely bead oo-jor's "the data was protected but the
    # checker was not". These clauses name the FIRST and LAST stage and the count, so each defence
    # alone rejects both the dead run (empty list) and the half-load (a prefix). Deliberate
    # redundancy on a critical property, pinned behaviourally by test_trumbles_load.py.
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
    if ev.get("cheat_messages"):
        raise EvidenceError(
            "%s: the engine logged anti-cheat message(s) restoring the trumble population: %r. "
            "PlayerEntity.m:12106-12128 emits those when the save's checksum does not authorise "
            "its stored count, and the loader then searches for a count that does."
            % (label, ev["cheat_messages"]))

    # --- defence 2: mission variables, which a fresh commander does not have -------------------
    keys = set(ev.get("mission_variable_keys") or ())
    if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):
        raise EvidenceError(
            "%s: evidence.mission_variable_keys is %r, not the save's %r. A DEFAULT NEW GAME HAS "
            "NO MISSION VARIABLES AT ALL (PlayerEntity.m:1986-1987), which is exactly why this "
            "check cannot be satisfied by a run that never loaded the save."
            % (label, sorted(keys), sorted(EXPECTED_MISSION_VARIABLE_KEYS)))
    if MISSION_TRUMBLES_KEY not in keys:
        raise EvidenceError(
            "%s: missionVariables carries no %r key - the mission variable this scenario is named "
            "for. Its VALUE is the empty string in this fixture, so only its PRESENCE can carry "
            "evidence, and a value comparison here would pass against a game that had never heard "
            "of the mission." % (label, MISSION_TRUMBLES_KEY))

    # --- defence 3: the 1.75 save-format contract ----------------------------------------------
    if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:
        raise EvidenceError(
            "%s: evidence.save_written_by_version is %r, expected %r. This scenario exists partly "
            "to pin the 1.75-era save-format compatibility contract; a different fixture does not "
            "pin it." % (label, ev.get("save_written_by_version"), EXPECTED_SAVE_VERSION))

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

    # --- defence 5: the population, both halves ------------------------------------------------
    if ev.get("saved_trumble_count") != EXPECTED_SAVED_TRUMBLE_COUNT:
        raise EvidenceError(
            "%s: evidence.saved_trumble_count is %r, expected %d - the count this fixture's "
            "anti-cheat checksum uniquely authorises."
            % (label, ev.get("saved_trumble_count"), EXPECTED_SAVED_TRUMBLE_COUNT))
    if ev.get("saved_trumble_checksum") != EXPECTED_TRUMBLE_CHECKSUM:
        raise EvidenceError(
            "%s: evidence.saved_trumble_checksum is %r, expected %d (the value in the fixture's "
            "own `trumbles` triple). A different checksum means a different save file."
            % (label, ev.get("saved_trumble_checksum"), EXPECTED_TRUMBLE_CHECKSUM))
    if list(ev.get("counts_matching_checksum") or []) != [EXPECTED_SAVED_TRUMBLE_COUNT]:
        raise EvidenceError(
            "%s: the checksum authorises counts %r, not exactly [%d]. If more than one count "
            "matched, the loader's search (PlayerEntity.m:12112-12125) could settle on either and "
            "the loaded population would not be pinned by the file."
            % (label, ev.get("counts_matching_checksum"), EXPECTED_SAVED_TRUMBLE_COUNT))
    # SECOND, INDEPENDENT DEFENCE. Measured: relaxing the equality above to a membership test
    # accepted a checksum authorising THREE different counts (rc=0). UNIQUENESS is the property -
    # the loader searches for the FIRST count whose checksum matches, so an ambiguous checksum
    # means the loaded population is whichever the search reaches first, not the file's.
    if len(ev.get("counts_matching_checksum") or ()) != 1:
        raise EvidenceError(
            "%s: %d count(s) satisfy this save's trumble checksum (%r). Exactly one must, or the "
            "population the engine loads is not uniquely determined by the file."
            % (label, len(ev.get("counts_matching_checksum") or ()),
               ev.get("counts_matching_checksum")))

    awards = ev.get("trumble_awards")
    if awards != DETERMINISTIC_AWARD_PREFIX:
        raise EvidenceError(
            "%s: evidence.trumble_awards is %r, expected %d = PLAYER_MAX_TRUMBLES/6. That is the "
            "MEASURED deterministic prefix of PlayerEntity.m:11531's award gate: the first %d "
            "awards take the unconditional left branch, and the next one consults ranrot_rand(), "
            "whose position in the stream depends on how many frames the run has burned (the "
            "shape bead oo-izi measured for system.addShips). Three runs at the same seed gave "
            "1 2 3 4 5 6 6 ... / 1 2 3 4 5 5 6 ... / 1 2 3 4 5 5 6 ... - identical through four, "
            "divergent at five."
            % (label, awards, DETERMINISTIC_AWARD_PREFIX, DETERMINISTIC_AWARD_PREFIX))
    series = list(ev.get("trumble_award_series") or [])
    if series != list(range(1, awards + 1)):
        raise EvidenceError(
            "%s: evidence.trumble_award_series is %r, expected %r. Each award inside the "
            "deterministic prefix must add exactly one trumble; a divergence here means the award "
            "gate's thresholds have changed."
            % (label, series, list(range(1, awards + 1))))
    if ev.get("trumble_count") != awards:
        raise EvidenceError(
            "%s: evidence.trumble_count is %r after %r award(s), expected %r"
            % (label, ev.get("trumble_count"), awards, awards))
    # SECOND, INDEPENDENT DEFENCE. Measured: relaxing the equality above to a None check accepted
    # a population of 99 after 4 awards (rc=0). The series is the other witness of the same
    # property - its LAST element is the count the awards actually produced - so tying the
    # reported count to it rejects a fabricated number even with the direct check gone.
    if series and ev.get("trumble_count") != series[-1]:
        raise EvidenceError(
            "%s: evidence.trumble_count is %r but the award series ends at %r. The two describe "
            "the same population and cannot disagree; one of them was written by hand."
            % (label, ev.get("trumble_count"), series[-1]))
    if ev.get("trumble_count") != len(series):
        raise EvidenceError(
            "%s: evidence.trumble_count is %r but %d award(s) were recorded, each of which adds "
            "exactly one trumble inside the deterministic prefix."
            % (label, ev.get("trumble_count"), len(series)))
    if ev.get("trumble_count_before_ticks") != ev.get("trumble_count"):
        raise EvidenceError(
            "%s: the population moved from %r to %r across the tick budget. Breeding needs "
            "trumbleAppetiteAccumulator > 10.0 from eating cargo pods (OOTrumble.m:585-627) and a "
            "docked player has none, so a change here is a FINDING about the engine."
            % (label, ev.get("trumble_count_before_ticks"), ev.get("trumble_count")))

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
        "mission_variables": sorted(keys),
        "saved_trumble_count": ev["saved_trumble_count"],
        "trumble_count": ev["trumble_count"],
        "trumble_awards": awards,
        "census_fields": ev["census_fields"],
        "save_written_by_version": ev["save_written_by_version"],
        "entities": len(entities),
        "market_goods": len(market),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_trumbles_evidence.py",
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
          "save's %d mission variable(s) %s, the %s-era save round-trips on all %d census "
          "field(s), and the trumble population went %d (from the save, uniquely checksum-"
          "authorised) -> %d after %d award(s) and did NOT move across the tick budget. "
          "%d entities, %d market goods."
          % (label, summary["load_stages"], len(summary["mission_variables"]),
             summary["mission_variables"], summary["save_written_by_version"],
             summary["census_fields"], summary["saved_trumble_count"], summary["trumble_count"],
             summary["trumble_awards"], summary["entities"], summary["market_goods"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
