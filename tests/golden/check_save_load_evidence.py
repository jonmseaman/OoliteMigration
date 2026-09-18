"""Offline checks on a scenario-006-save-load dump: does it prove a save was really LOADED and
that the round-trip comparison was really PERFORMED?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses the ways that question can be asked
vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy quantisation).
All of that is about the COMPARISON of two dumps.

It cannot answer the question this scenario turns on, which is whether the RUN that produced the
dump did the thing the scenario is named after. A game that ignored `-load` still boots, still
answers every probe, and still produces a perfectly reproducible dump of the wrong world. Two
runs of that agree with each other forever. So this file checks the CONTENT: that the dump in
front of it carries positive evidence that a save file existed, was non-trivial, was loaded, and
that a census comparison with a real number of fields came out equal.

THE FOUR VACUITY ROUTES, AND THE FIELD THAT CLOSES EACH
------------------------------------------------------
  the state is EMPTY              -> census_fields >= MIN_CENSUS_FIELDS and
                                     census_populated >= MIN_POPULATED. A census of zeros and
                                     empty strings compares equal to any other empty census.
  the SAVE did not happen         -> save_bytes >= MIN_SAVE_BYTES and save_file is named. A
                                     missing or stub save cannot produce these.
  the LOAD did not happen         -> load_verified is true AND the three independent load
                                     signals are present and consistent: the save's own system
                                     name, its own commander name, and clock_at_or_past_save.
  compared something to ITSELF    -> round_trip_fields_equal must EQUAL census_fields, and both
                                     must be >= the floor. A self-comparison reports equality on
                                     zero fields as readily as on eleven, so the COUNT is the
                                     discriminator, not the boolean.

TWO INDEPENDENT DEFENCES ON THE CRITICAL PROPERTY
-------------------------------------------------
The critical property is "a save was really loaded". Following scenario 001's shape, it is
enforced TWICE by design, through defences that do not share a code path:

  (1) REQUIRED_TRUE carries `load_verified` and `clock_at_or_past_save` as a table.
  (2) `check_load_signals()` is a dedicated clause that independently re-derives the same
      conclusion from the NAMED values - it requires system_name and commander_name to be
      present and non-empty, and requires saved_ship_clock to be positive.

This redundancy is deliberate and is pinned behaviourally by
test_save_load.py::test_each_load_defence_independently_rejects_an_unloaded_dump, which removes
each defence in a COPY of this module and asserts the copy STILL rejects a dump from a game that
never loaded. So the redundancy cannot be silently collapsed by a later refactor, and a mutation
that removes only one defence is an EQUIVALENT mutant rather than a hole.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found); 2 a usage error - the same convention golden_diff.py uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every evidence field that must read exactly True in a real run, as a table rather than inline
# ifs so the set is readable and a future scenario cannot quietly drop one.
REQUIRED_TRUE = ("round_trip_ok", "load_verified", "clock_at_or_past_save")

# Every evidence field that must be a positive integer.
REQUIRED_POSITIVE = ("save_bytes", "census_fields", "census_populated",
                     "round_trip_fields_equal")

# Floors. Mirrored from save_load.py on purpose: the point of a guard is that it disagrees
# loudly if someone edits one of them. They are well under what a real run produces, so they
# catch "the dump collapsed" without re-pinning the scenario's exact content (the golden's job).
MIN_SAVE_BYTES = 1024
MIN_CENSUS_FIELDS = 8
MIN_POPULATED = 4

# A dump of this scenario carries the player block, the station market and the system's own
# fixed entities.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove a save was loaded and round-tripped."""


def check_load_signals(ev, problems):
    """DEFENCE 2: re-derive "a save was really loaded" from the named values.

    Independent of the REQUIRED_TRUE table above: that table asks whether booleans the harness
    wrote are true, this asks whether the VALUES those booleans were derived from are present and
    sane. A dump from a game that never loaded a save has no system_name, no commander_name and
    no positive saved_ship_clock, so it fails here even if the booleans were forced true.
    """
    if not ev.get("system_name"):
        problems.append(
            "evidence.system_name is %r: the dump does not record which system the loaded save "
            "put the player in, so there is no evidence the save's own system was adopted"
            % ev.get("system_name"))
    if not ev.get("commander_name"):
        problems.append(
            "evidence.commander_name is %r: no evidence the save's own commander was adopted"
            % ev.get("commander_name"))
    clock = ev.get("saved_ship_clock")
    if not isinstance(clock, (int, float)) or clock <= 0:
        problems.append(
            "evidence.saved_ship_clock is %r, expected a positive game time: without it the "
            "clock signal proves nothing, because any clock is >= 0" % clock)


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that a save was ever "
            "loaded, and two such dumps agreeing proves only that the same nothing happened "
            "twice." % label)

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

    # DEFENCE 2 on the critical property.
    check_load_signals(ev, problems)

    # populators_suppressed may legitimately be 0 (a system defining none), so it is reported
    # rather than required - but it must be PRESENT, so a dump produced before the suppression
    # existed cannot pass as if it had been taken in a world that stopped adding traffic.
    if "populators_suppressed" not in ev:
        problems.append("evidence.populators_suppressed is ABSENT: this dump predates the "
                        "populator suppression and may have been taken in a world the system "
                        "was still adding traffic to")

    if not ev.get("save_file"):
        problems.append("evidence.save_file is %r: the dump does not name the save file it "
                        "round-tripped" % ev.get("save_file"))
    if ev.get("save_bytes", 0) < MIN_SAVE_BYTES:
        problems.append(
            "the save file was TRIVIAL: evidence.save_bytes is %r, under the %d-byte floor. A "
            "stub save parses to few or no keys and a comparison against it is vacuous however "
            "green it comes out." % (ev.get("save_bytes"), MIN_SAVE_BYTES))

    # THE CENSUS MUST BE BIG ENOUGH AND FULL ENOUGH TO BE WORTH COMPARING.
    if ev.get("census_fields", 0) < MIN_CENSUS_FIELDS:
        problems.append(
            "the census was TOO SMALL: evidence.census_fields is %r, under the %d minimum. Two "
            "states agreeing on a handful of fields is not evidence that a save round-tripped."
            % (ev.get("census_fields"), MIN_CENSUS_FIELDS))
    if ev.get("census_populated", 0) < MIN_POPULATED:
        problems.append(
            "the census was EMPTY: evidence.census_populated is %r, under the %d minimum; a "
            "census of zeros and empty strings compares equal to any other empty census"
            % (ev.get("census_populated"), MIN_POPULATED))

    # THE COUNT, NOT THE BOOLEAN, is what distinguishes a real comparison from a self-comparison:
    # `round_trip_ok` is true whenever nothing differed, including when nothing was compared.
    equal = ev.get("round_trip_fields_equal")
    total = ev.get("census_fields")
    if isinstance(equal, int) and isinstance(total, int) and equal != total:
        problems.append(
            "evidence.round_trip_fields_equal is %r but census_fields is %r: the run reported a "
            "successful round trip while %d field(s) did not match" % (equal, total, total - equal))

    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market "
                        "is missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))
    player = data.get("player") or {}
    if not player:
        problems.append("the dump carries no player block, so it is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove a save/load round-trip:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: loaded %s (%d bytes) as commander %r in %s; %d/%d census field(s) round-tripped "
            "equal (%d populated); %d entities, %d market goods"
            % (label, ev["save_file"], ev["save_bytes"], ev["commander_name"], ev["system_name"],
               ev["round_trip_fields_equal"], ev["census_fields"], ev["census_populated"],
               len(ents), len(market)))


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
