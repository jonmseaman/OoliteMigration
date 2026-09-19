"""Offline evidence check for golden 019 (equipment-and-station-services).

WHY A SEPARATE CHECKER EXISTS AT ALL
====================================
`golden_diff.py` compares a fresh dump with the stored one BYTE FOR BYTE. That is the right
comparison and it is not enough on its own, because it is satisfied by two dumps that agree on
being WRONG: re-bless a degenerate dump and every future run matches it forever. This file asks
the question the byte comparison cannot - IS THIS DUMP EVIDENCE THAT THE EQUIPMENT MODEL RAN? - of
the STORED artifact, offline, with no game.

It is deliberately a SECOND IMPLEMENTATION of the predicates in equipment_services.assert_ran,
with its own thresholds derived here from first principles. A checker that imported the harness's
own assertions would go green on exactly the dumps the harness was willing to write, which is the
definition of a circular gate.

WHAT A DEAD RUN LOOKS LIKE, AND WHY EVERY CLAUSE IS POSITIVE
============================================================
Bead oo-het captured a real corpse: exit 87 in display setup, rc=0, ZERO ERROR lines. On a shared
box a sibling worker's console can also quit a game four seconds in while it still exits 0. So
"rc=0" and "no errors" are both worthless here, and every clause below names something that had
to HAPPEN:

  * an equipment array that GREW by exactly one on award and shrank back on remove;
  * a status that moved EQUIPMENT_OK -> EQUIPMENT_DAMAGED, with both readings stored;
  * THREE ENGINE REFUSALS a permissive stub cannot fake (duplicate award, damage of an
    undamageable item, and a control item above the station's tech level);
  * a credit balance that moved by exactly price x factor, with all three numbers stored apart;
  * an ordered registry enumeration long enough for a reordering to be visible in it.

THE NUMBERS BELOW ARE DERIVED, NOT COPIED
=========================================
Every constant carries where it comes from. A threshold with no derivation is a number someone can
lower until the suite passes, which is how a golden suite rots into decoration.
"""

import argparse
import json
import os
import sys

EQUIPMENT_OK = "EQUIPMENT_OK"
EQUIPMENT_DAMAGED = "EQUIPMENT_DAMAGED"
EQUIPMENT_UNAVAILABLE = "EQUIPMENT_UNAVAILABLE"

# OOJSShip.m:2900-2930 exposes exactly these three states to scripts; anything else in a status
# field means the dump was produced by something that is not this engine.
VALID_STATUSES = frozenset((EQUIPMENT_OK, EQUIPMENT_DAMAGED, EQUIPMENT_UNAVAILABLE))

# The transition the scenario is named for. Stored as a PAIR so a COLLAPSED state machine reports
# the same value twice instead of dropping a field.
EXPECTED_TRANSITION = [EQUIPMENT_OK, EQUIPMENT_DAMAGED]

# Lave's Coriolis. Both are read from the ENGINE at run time (StationEntity.m:696-697 for the
# factor, PlayerEntity.m:9300-9308 for the tech level); pinned here so a silent pricing change is
# a red line rather than a quietly re-blessed number.
EXPECTED_STATION_TECH_LEVEL = 4
EXPECTED_PRICE_FACTOR = 1.0

# equipment.plist's price for EQ_ECM. NOT read from the plist by this checker: the dump carries
# what the engine's loaded registry said, and comparing that against a literal here is what makes
# a registry that silently stopped loading prices visible.
EXPECTED_PURCHASE_PRICE = 6000.0

# MEASURED on this build: EquipmentInfo.allEquipment enumerates 41 keys. The floor is set well
# under that because OXZ-free stock content is the contract, not the exact count; but an order
# pinned over a handful of entries cannot see the reordering item 0.1 names, so a short registry
# must REFUSE rather than compare.
MIN_REGISTRY_ENTRIES = 20

# The scenario ends holding the purchased item plus the undamageable control. Fewer than two and
# there is no ORDER in the player's own array to pin at all.
MIN_FINAL_EQUIPMENT = 2

# The starting ship in oolite-standard.oolite-save carries NO equipment (measured). That is what
# makes "the array grew by one" attributable: every member of the final array was put there by
# this scenario.
EXPECTED_COUNT_BEFORE_AWARD = 0

# dump_state.js always emits these; their absence means the dump is not a golden dump at all.
REQUIRED_STATE_BLOCKS = ("entities", "market", "player", "equipment", "evidence")

REQUIRED_TRUE = (
    "docked", "station_is_main", "awarded_key_present", "duplicate_award_refused",
    "damage_refused_for_undamageable", "tech_level_within_available",
    "tech_level_above_unavailable", "tick_budget_met", "world_at_rest",
    "world_reached_fixed_point", "clock_frozen_across_dump", "can_award_before",
    "award_returned",
)

# undocked_seen is the ONE field that must be FALSE. It is recorded rather than omitted precisely
# so a run that launched fails by name instead of silently measuring a different world.
REQUIRED_FALSE = ("undocked_seen", "undamageable_can_be_damaged", "undamageable_damage_accepted")

REQUIRED_POSITIVE = ("ticks", "registry_entries", "populators_suppressed", "stations_quieted",
                     "station_tech_level", "purchase_price", "credits_delta")


class EvidenceError(Exception):
    """The stored dump does not prove the equipment model ran."""


def _require(evidence, key, label):
    if key not in evidence:
        raise EvidenceError("%s's evidence block has no %r field; a dump that does not record it "
                            "cannot be distinguished from one where it never happened"
                            % (label, key))
    return evidence[key]


def check(state, label="dump"):
    """Return a one-line summary, or raise EvidenceError. NEVER returns quietly on a bad dump."""
    missing_blocks = [b for b in REQUIRED_STATE_BLOCKS if b not in state]
    if missing_blocks:
        raise EvidenceError(
            "%s is missing the %s block(s). 'equipment' and 'evidence' are this scenario's own "
            "additions (the shared dump_state.js carries neither, and is not modified to add them "
            "because it is shared by every landed golden); the rest are the canonical dump."
            % (label, missing_blocks))

    evidence = state["evidence"]
    if not isinstance(evidence, dict):
        raise EvidenceError("%s's evidence block is %s, not an object"
                            % (label, type(evidence).__name__))

    for key in REQUIRED_TRUE:
        if _require(evidence, key, label) is not True:
            raise EvidenceError("%s records %s=%r, expected True. Every clause in this checker is "
                                "POSITIVE because rc=0 and an absence of ERROR lines are both "
                                "satisfiable by a game that died in display setup (bead oo-het)."
                                % (label, key, evidence[key]))
    for key in REQUIRED_FALSE:
        if _require(evidence, key, label) is not False:
            raise EvidenceError("%s records %s=%r, expected False" % (label, key, evidence[key]))
    for key in REQUIRED_POSITIVE:
        value = _require(evidence, key, label)
        if not isinstance(value, (int, float)) or value <= 0:
            raise EvidenceError("%s records %s=%r, expected a positive number"
                                % (label, key, value))

    # --- the award / query / damage / remove cycle -------------------------------------------
    if _require(evidence, "count_before_award", label) != EXPECTED_COUNT_BEFORE_AWARD:
        raise EvidenceError(
            "%s starts with %r item(s) of equipment; the standard save's ship carries %d "
            "(measured). A non-empty starting array would mean the growth this scenario records "
            "is not attributable to its own award."
            % (label, evidence["count_before_award"], EXPECTED_COUNT_BEFORE_AWARD))
    if _require(evidence, "equipment_count_delta", label) != 1:
        raise EvidenceError(
            "%s records an equipment_count_delta of %r, not exactly 1. Ship.equipment is READ-ONLY "
            "in the JS API snapshot, so this number came from the engine: an unchanged array after "
            "a successful award means equipment can be bought and silently not installed."
            % (label, evidence["equipment_count_delta"]))
    if _require(evidence, "count_after_remove", label) != evidence["count_before_award"]:
        raise EvidenceError(
            "%s holds %r item(s) after the remove but %r before the award; award and remove are "
            "not inverses on the awarded key"
            % (label, evidence["count_after_remove"], evidence["count_before_award"]))
    if _require(evidence, "status_after_remove", label) != EQUIPMENT_UNAVAILABLE:
        raise EvidenceError(
            "%s reads %r after removeEquipment, not %r; the removal path did not take the item off "
            "the ship" % (label, evidence["status_after_remove"], EQUIPMENT_UNAVAILABLE))

    transition = _require(evidence, "status_transition", label)
    if transition != EXPECTED_TRANSITION:
        raise EvidenceError(
            "%s records the status machine going %r, not %r. BOTH readings are stored precisely "
            "so a COLLAPSED machine shows up as the same value twice: EQUIPMENT_OK after a damage "
            "write means damaged equipment keeps working." % (label, transition,
                                                              EXPECTED_TRANSITION))
    for status in transition:
        if status not in VALID_STATUSES:
            raise EvidenceError(
                "%s records the status %r, which OOJSShip.m:2900-2930 does not define; a dump "
                "carrying an undefined status was not produced by this engine"
                % (label, status))

    # --- the refusal on the undamageable item -------------------------------------------------
    if _require(evidence, "undamageable_status_after", label) != EQUIPMENT_OK:
        raise EvidenceError(
            "%s records %r as %r after a REFUSED damage write, not %r. The boolean and the status "
            "are BOTH checked: a checker reading only the boolean would accept an engine that "
            "returned false while damaging the item anyway."
            % (label, evidence.get("undamageable_key"), evidence["undamageable_status_after"],
               EQUIPMENT_OK))
    if evidence.get("undamageable_key") == evidence.get("award_key"):
        raise EvidenceError(
            "%s uses %r as BOTH the damageable and the undamageable key; one item cannot be both, "
            "so one of the two refusal arms is asserting nothing"
            % (label, evidence.get("award_key")))

    # --- pricing, re-derived here rather than trusted ------------------------------------------
    price = float(_require(evidence, "purchase_price", label))
    factor = float(_require(evidence, "equipment_price_factor", label))
    charge = float(_require(evidence, "purchase_charge", label))
    delta = float(_require(evidence, "credits_delta", label))
    before = float(_require(evidence, "credits_before", label))
    after = float(_require(evidence, "credits_after", label))
    if abs(charge - price * factor) > 1e-6:
        raise EvidenceError(
            "%s records a charge of %r, but the engine's price %r times the station's factor %r is "
            "%r. The three numbers are stored SEPARATELY exactly so a pricing change makes them "
            "disagree BY NAME instead of all sliding together."
            % (label, charge, price, factor, price * factor))
    if abs((before - after) - charge) > 1e-6:
        raise EvidenceError(
            "%s records credits going %r -> %r (a move of %r) for a charge of %r; the balance and "
            "the price do not correspond" % (label, before, after, before - after, charge))
    if abs(delta - charge) > 1e-6:
        raise EvidenceError("%s records credits_delta=%r against a charge of %r"
                            % (label, delta, charge))
    if price != EXPECTED_PURCHASE_PRICE:
        raise EvidenceError(
            "%s records the engine pricing %r at %r; equipment.plist gives %r. This is the "
            "tech-level-derived pricing the scenario exists to pin - investigate before "
            "re-blessing." % (label, evidence.get("purchase_key"), price, EXPECTED_PURCHASE_PRICE))
    if factor != EXPECTED_PRICE_FACTOR:
        raise EvidenceError(
            "%s records equipmentPriceFactor %r at %r; the blessed value is %r "
            "(StationEntity.m:696-697 floors it at 0.5 and Lave's main station declares none)"
            % (label, factor, evidence.get("station_name"), EXPECTED_PRICE_FACTOR))
    if _require(evidence, "purchase_status", label) != EQUIPMENT_OK:
        raise EvidenceError("%s records the purchased item as %r, not %r, after being paid for"
                            % (label, evidence["purchase_status"], EQUIPMENT_OK))

    # --- the tech-level gate, two-sided -------------------------------------------------------
    tech = int(_require(evidence, "station_tech_level", label))
    within = int(_require(evidence, "tech_level_within", label))
    above = int(_require(evidence, "tech_level_above", label))
    if tech != EXPECTED_STATION_TECH_LEVEL:
        raise EvidenceError("%s records the station at equivalentTechLevel %r; the blessed value "
                            "is %r" % (label, tech, EXPECTED_STATION_TECH_LEVEL))
    if not within <= tech < above:
        raise EvidenceError(
            "%s records the purchased item at TL %r and the control at TL %r against a station at "
            "TL %r, so the two keys do NOT straddle the station's level. One key on one side of a "
            "threshold passes against any constant, including a station reporting 0 or NSNotFound; "
            "the straddle is what makes the number discriminate." % (label, within, above, tech))
    if evidence.get("tech_level_within_key") == evidence.get("tech_level_above_key"):
        raise EvidenceError("%s uses the same key on both sides of the tech-level gate"
                            % label)
    if int(_require(evidence, "system_tech_level", label)) != tech:
        raise EvidenceError(
            "%s records the system at TL %r and the station at TL %r. Both are stored because "
            "PlayerEntity.m:9300-8 prefers the STATION's value when it declares one; a divergence "
            "is a real finding about this station and must not be absorbed silently."
            % (label, evidence["system_tech_level"], tech))

    # --- ordering: the failure class item 0.1 names --------------------------------------------
    order = _require(evidence, "registry_order", label)
    if not isinstance(order, list):
        raise EvidenceError("%s's registry_order is %s, not a list"
                            % (label, type(order).__name__))
    if len(order) < MIN_REGISTRY_ENTRIES:
        raise EvidenceError(
            "%s enumerates %d registry key(s), under the %d floor. A short registry means "
            "equipment.plist did not load, and an order pinned over a handful of entries cannot "
            "see the reordering this scenario exists to catch."
            % (label, len(order), MIN_REGISTRY_ENTRIES))
    if len(set(order)) != len(order):
        raise EvidenceError("%s's registry_order contains duplicate keys; a duplicate hides a "
                            "missing entry when the order is compared" % label)
    if evidence.get("registry_entries") != len(order):
        raise EvidenceError("%s records registry_entries=%r against a %d-key order"
                            % (label, evidence.get("registry_entries"), len(order)))
    for field in ("award_key", "purchase_key", "undamageable_key", "tech_level_above_key"):
        key = _require(evidence, field, label)
        if key not in order:
            raise EvidenceError(
                "%s's %s=%r is not in the enumerated registry, so this scenario's own keys are "
                "not the keys the engine knows about" % (label, field, key))

    final = _require(evidence, "equipment_keys_final", label)
    if len(final) < MIN_FINAL_EQUIPMENT:
        raise EvidenceError(
            "%s ends holding %d item(s); with fewer than %d there is no ORDER in the player's own "
            "array to pin, and equipment ordering is the regression class item 0.1 names."
            % (label, len(final), MIN_FINAL_EQUIPMENT))
    if evidence["award_key"] in final:
        raise EvidenceError(
            "%s still holds %r at the dump, but the scenario REMOVES it after damaging it. A "
            "final array that still carries it means removeEquipment did not take."
            % (label, evidence["award_key"]))
    if evidence["purchase_key"] not in final:
        raise EvidenceError("%s does not hold the purchased %r at the dump"
                            % (label, evidence["purchase_key"]))

    # --- the equipment block, cross-checked against the evidence block -------------------------
    block = state["equipment"]
    if block.get("registry_order") != order:
        raise EvidenceError(
            "%s's equipment.registry_order disagrees with evidence.registry_order. The two are "
            "written from the same reading, so a divergence means one of them was edited by hand."
            % label)
    if block.get("player_equipment") != final:
        raise EvidenceError("%s's equipment.player_equipment disagrees with "
                            "evidence.equipment_keys_final" % label)
    statuses = block.get("player_equipment_status") or {}
    if sorted(statuses) != sorted(final):
        raise EvidenceError("%s reports statuses for %r but holds %r"
                            % (label, sorted(statuses), sorted(final)))
    for key, status in sorted(statuses.items()):
        if status not in VALID_STATUSES:
            raise EvidenceError("%s reports %r as %r, which is not a defined equipment status"
                                % (label, key, status))
    station = block.get("station") or {}
    for field in ("station_name", "equipment_price_factor", "equivalent_tech_level",
                  "system_tech_level", "service_level"):
        if field not in station:
            raise EvidenceError(
                "%s's equipment.station block does not record %r; the station's pricing inputs "
                "are what the credit balance is derived from, and an unrecorded input cannot be "
                "seen to change" % (label, field))

    # --- the world the measurement was taken in ------------------------------------------------
    if not state["market"]:
        raise EvidenceError(
            "%s carries an EMPTY market. The player is docked at a main station for the whole "
            "run, so an empty commodity market means the station's services did not initialise - "
            "the very subsystem whose tech-level-derived pricing this scenario measures." % label)
    if not state["entities"]:
        raise EvidenceError("%s carries no entities at all; the world did not load" % label)

    return ("%s proves the equipment model ran: %r awarded (array %d -> %d) then damaged "
            "(%s) and removed (-> %s); duplicate award REFUSED; damage REFUSED for %r; %r bought "
            "for %g credits (price %g x factor %g) at %s TL %d, with %r (TL %d) above it; %d "
            "registry entries pinned in order; %d item(s) held at the dump."
            % (label, evidence["award_key"], evidence["count_before_award"],
               evidence["count_before_award"] + evidence["equipment_count_delta"],
               " -> ".join(transition), evidence["status_after_remove"],
               evidence["undamageable_key"], evidence["purchase_key"], delta, price, factor,
               evidence.get("station_name"), tech, evidence["tech_level_above_key"], above,
               len(order), len(final)))


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="tests/golden/check_equipment_evidence.py",
        description="Assert that a stored 019 dump is evidence the equipment model ran.")
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)

    if not os.path.isfile(args.dump):
        sys.stderr.write("REFUSED: no dump at %s\n" % args.dump)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            state = json.load(handle)
    except ValueError as exc:
        sys.stderr.write("REFUSED: %s is not readable JSON: %s\n" % (args.dump, exc))
        return 2
    label = args.label or args.dump
    try:
        print("PASS: %s" % check(state, label))
    except EvidenceError as exc:
        sys.stderr.write("FAIL: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
