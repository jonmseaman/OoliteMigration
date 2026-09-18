"""Offline checks on a scenario-001-launch-dock dump: does it prove the ship LAUNCHED and DOCKED?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation, floats rounded to whole numbers). All of that is about the COMPARISON.

It cannot answer the other half of the vacuity problem, which is about the RUN: a scenario that
crashed on tick 3 and dumped a near-empty world reproduces byte-for-byte perfectly and proves
nothing at all. Two runs of a dead scenario agree. So this file checks the CONTENT: that the dump
in front of it carries positive evidence of a launch and a dock, produced by the engine.

WHAT COUNTS AS EVIDENCE, AND WHY
--------------------------------
`evidence.launch_events` and `evidence.dock_events` count dispatches of
`shipWillLaunchFromStation` (DockEntity.m:935) and `shipDockedWithStation`
(PlayerEntity.m:7206), delivered to a world script by PlayerEntity.m:12889-12893. The harness
cannot increment them: it installs the handlers and never calls them. A run that skipped the
flight has zeroes here, and a zero is a FIELD IN THE STORED GOLDEN, so every future comparison
re-checks it rather than trusting that the capture-time assertion once passed.

`evidence.undocked_seen` is the state transition: docked -> NOT docked -> docked. A scenario that
never left the station cannot set it.

The dump's own shape is checked too (entities, market, player, a docked player at the end), so a
truncated or half-written dump is rejected here rather than silently compared.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry, with the value a REAL launch-and-dock run produces.
# Listed as a table rather than as inline ifs so the set is readable and so a future scenario
# cannot quietly drop one of them.
REQUIRED_TRUE = ("docked_at_start", "undocked_seen", "docked_at_end", "tick_budget_met")
REQUIRED_POSITIVE = ("launch_events", "dock_events", "ticks")

# A dump of this scenario carries the player block, the station market, and the system's own
# fixed entities (the main station and the rock hermit). These floors are under what a real run
# produces, so they catch "the dump collapsed" without re-pinning the scenario's exact content,
# which is the golden's job.
#
# MIN_ENTITIES is 2, not 4: this scenario deliberately spawns NO cast. The populator is switched
# off (system.setPopulator(key, null)) and the traffic is removed, because a spawned ship under
# thrust reports a velocity that no JS write can clear (ShipEntity.m:12830-12833) and whose value
# tracks the frame count. A golden wants the smallest reproducible world, not a busy one. The
# floor still bites: a dump with one entity or none is refused.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove the scenario ran."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that the ship ever "
            "launched or docked, and two such dumps agreeing proves only that the same nothing "
            "happened twice." % label)

    for field in REQUIRED_TRUE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif ev[field] is not True:
            problems.append("evidence.%s is %r, expected True" % (field, ev[field]))

    # populators_suppressed may legitimately be 0 (a system defining none), so it is reported
    # rather than required - but it must be PRESENT, so a dump produced before the suppression
    # existed cannot pass as if it had been taken with the populator off.
    if "populators_suppressed" not in ev:
        problems.append("evidence.populators_suppressed is ABSENT: this dump predates the "
                        "populator suppression and may have been taken in a world the system "
                        "was still adding traffic to")

    for field in REQUIRED_POSITIVE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif not isinstance(ev[field], int) or ev[field] < 1:
            problems.append("evidence.%s is %r, expected an integer >= 1" % (field, ev[field]))

    # The two halves of the bead's title, stated as their own failures so the message says which
    # half is missing rather than "some counter is zero".
    if ev.get("launch_events", 0) < 1:
        problems.append(
            "the ship never LAUNCHED: evidence.launch_events is %r, so the engine never "
            "dispatched shipWillLaunchFromStation (DockEntity.m:935)" % ev.get("launch_events"))
    if ev.get("dock_events", 0) < 1:
        problems.append(
            "the ship never DOCKED: evidence.dock_events is %r, so the engine never dispatched "
            "shipDockedWithStation (PlayerEntity.m:7206)" % ev.get("dock_events"))

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
    ship = player.get("ship") or {}
    if ship.get("docked") is not True:
        problems.append("player.ship.docked is %r: the scenario does not END docked, so it did "
                        "not complete its second half" % ship.get("docked"))

    if problems:
        raise EvidenceError("%s does not prove a launch-and-dock run:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: launched (%d engine event(s)), flew %d ticks, docked (%d engine event(s)); "
            "%d entities, %d market goods, ends docked"
            % (label, ev["launch_events"], ev["ticks"], ev["dock_events"], len(ents), len(market)))


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
