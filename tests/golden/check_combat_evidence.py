"""Offline checks on a scenario-003-combat dump: does it prove a COMBAT ENCOUNTER really happened?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, an off-policy quantisation, floats rounded
to whole numbers). All of that is about the COMPARISON.

It cannot answer the other half, which is about the RUN. This is the sharpest case of that in the
suite so far: a combat scenario in which the combat never happens - the ships spawn out of range,
the AI never engages, the target is invulnerable - produces a clean log, a quiet world, and a
dump that reproduces byte-for-byte across every run. Two runs of a dead encounter agree perfectly.
So this file checks the CONTENT: that the dump carries positive evidence, produced by the ENGINE,
that damage was dealt and a ship died.

WHAT COUNTS AS EVIDENCE, AND WHY A DEAD RUN CANNOT PRODUCE IT
-------------------------------------------------------------
Four ENGINE dispatches, hooked onto the two ships' own script objects the way the stock content
does it (Resources/Scripts/oolite-tutorial.js:860). The harness installs the handlers and never
calls them, so nothing outside the engine can increment these:

  damage_events  shipTakingDamage on the VICTIM      ShipEntity.m:8983, from -takeEnergyDamage:
  damage_total   the engine's own `amount` argument, summed - a strike that landed for 0 damage
                 cannot inflate it
  death_events   shipDied on the VICTIM              ShipEntity.m:9020, from -noteKilledBy:
  kill_events    shipKilledOther on the ATTACKER     ShipEntity.m:9024 - the engine's OWN
                 attribution of the kill. This is the clause a proximity accident, an
                 overheating death or a ship the station launched cannot satisfy: the engine
                 dispatches it to `whom`, and `whom` is this scenario's attacker handle.

Two handle-scoped structural facts, which are deliberately NOT role counts. A role count cannot
distinguish a ship the scenario spawned from one the system populator or the station's own
traffic timer wandered in (bead oo-qwk5 was parked on exactly that), and a combat scenario is the
worst case because combat means ships and ships mean role counts:

  cast_alive_before == 2 and cast_alive_after == 1
  victim_destroyed true, attacker_survived true

DEATH_EVENTS IS PINNED TO EXACTLY 1, NOT >= 1, on purpose. The counter is hung on ONE ship's
script object and the engine dispatches shipDied once per destruction, so 0 means the victim
survived and >1 means the handle is not the single ship the scenario spawned - both are defects
and both must be named as such.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Fields that must be present and exactly True. Listed as a table rather than as inline ifs so
# the set is readable and a future scenario cannot quietly drop one.
REQUIRED_TRUE = ("victim_destroyed", "attacker_survived", "tick_budget_met")

# Fields that must be present integers >= 1.
REQUIRED_POSITIVE = ("damage_events", "kill_events", "strikes_delivered", "ticks")

# Fields that must be present at all, so a dump produced before a defence existed cannot pass as
# though it had been taken with that defence in place.
REQUIRED_PRESENT = ("populators_suppressed", "cast_identity", "attacker_key", "victim_key",
                    "strike_damage", "strike_range", "seed", "system_id")

# EXACTLY one death: see the module docstring.
EXPECTED_DEATH_EVENTS = 1

# The scenario removes every non-station ship before dumping (a ship under thrust cannot be
# frozen from JS - ShipEntity.m:12830-12833), so the dump carries the system's own fixed
# furniture plus the player. The floor still bites: a dump with one entity or none is refused.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove a combat encounter occurred."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that any damage was "
            "ever dealt or that any ship died, and two such dumps agreeing proves only that the "
            "same nothing happened twice." % label)

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

    for field in REQUIRED_PRESENT:
        if field not in ev:
            problems.append("evidence.%s is ABSENT: this dump predates a defence the scenario "
                            "now carries and cannot be compared as though it had it" % field)

    # --- the four engine-dispatch clauses, each named separately ---------------------------
    #
    # Deliberately NOT collapsed into the loops above: the reader of a failure must be told which
    # half of "a combat encounter" is missing, not that "some counter is zero".
    if ev.get("damage_events", 0) < 1:
        problems.append(
            "NO DAMAGE WAS DEALT: evidence.damage_events is %r, so the engine never dispatched "
            "shipTakingDamage on the victim (ShipEntity.m:8983). Nothing hit anything."
            % ev.get("damage_events"))
    total = ev.get("damage_total")
    if not isinstance(total, (int, float)) or total <= 0:
        problems.append(
            "evidence.damage_total is %r, expected a positive number: the engine's own summed "
            "`amount` argument. A strike that was delivered but landed for zero damage cannot "
            "satisfy this." % total)
    if ev.get("death_events") != EXPECTED_DEATH_EVENTS:
        problems.append(
            "NO SHIP DIED: evidence.death_events is %r, expected exactly %d. The engine "
            "dispatches shipDied once per destruction (ShipEntity.m:9020); 0 means the victim "
            "survived the encounter, and more than 1 means the counter is not scoped to the "
            "single ship this scenario spawned."
            % (ev.get("death_events"), EXPECTED_DEATH_EVENTS))
    if ev.get("kill_events", 0) < 1:
        problems.append(
            "THE KILL IS NOT ATTRIBUTED TO THE ATTACKER: evidence.kill_events is %r, so the "
            "engine never dispatched shipKilledOther on this scenario's attacker "
            "(ShipEntity.m:9024). The victim may have died of something the scenario did not do."
            % ev.get("kill_events"))

    # --- the handle-scoped structural clause -----------------------------------------------
    before, after = ev.get("cast_alive_before"), ev.get("cast_alive_after")
    if before != 2 or after != 1:
        problems.append(
            "evidence.cast_alive went %r -> %r, expected 2 -> 1. These count THIS SCENARIO'S own "
            "two ship handles, not ships with a role: a role count cannot tell a spawned ship "
            "from one the populator or the station's traffic timer added (bead oo-qwk5)."
            % (before, after))

    # A strike that was requested but never delivered is a dead run wearing a live run's shape.
    delivered, requested = ev.get("strikes_delivered"), ev.get("strikes_requested")
    if isinstance(delivered, int) and isinstance(requested, int) and delivered > requested:
        problems.append("evidence.strikes_delivered is %r but only %r were requested; the dump "
                        "claims more shots than the spec permits" % (delivered, requested))

    # --- the dump's own shape ----------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market "
                        "is missing, so the dump is truncated"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))

    if problems:
        raise EvidenceError("%s does not prove a combat encounter:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: %d engine damage event(s) totalling %s, 1 engine death, %d engine kill(s) "
            "attributed to the attacker; cast 2 -> 1 (%s); %d entities, %d market goods"
            % (label, ev["damage_events"], ev["damage_total"], ev["kill_events"],
               ev.get("cast_identity", "?"), len(ents), len(market)))


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
