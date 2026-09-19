"""CHECKER-WEAKENING mutants for scenario 019's evidence checker.

WHY DATA MUTANTS ARE NOT ENOUGH
-------------------------------
`test_equipment_services.py` feeds the checker bad DUMPS and requires a rejection. That proves the
checker rejects those inputs TODAY. It does not prove any individual clause is load-bearing: if
two clauses overlap, either one could be deleted and every data mutant would still be caught by
the other, so the suite would go green over a checker that had quietly lost half its teeth. Bead
oo-xy0o measured exactly that hole on a checker that had ALREADY LANDED.

Each arm here is bead oo-ghhw's two-sided pattern, and BOTH sides are required:

  1. the UNMUTATED checker must REJECT (rc=1) the input the clause exists to reject - otherwise
     the mutant registers a FALSE KILL against an already-red checker (bead oo-4vdc);
  2. a THROWAWAY copy of the checker with exactly ONE clause weakened must now ACCEPT it (rc=0).

If side 2 still rejects, the clause is REDUNDANT - some other clause was doing the work - and the
arm says so by failing. That is the finding this file exists to produce.

Nothing in the repo is written to. Sources are read, mutated in memory, and written into pytest's
tmp_path; the checker is then run as a SUBPROCESS against the mutated copy, so a weakened module
can never leak into another test's import cache.
"""

import copy
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "019-equipment-and-station-services"

CHECKER = os.path.join(HERE, "check_equipment_evidence.py")
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)


def golden_path():
    for path in GOLDEN_CANDIDATES:
        if os.path.isfile(path):
            return path
    raise AssertionError("no blessed state.json for %s; searched %r"
                         % (SCENARIO, list(GOLDEN_CANDIDATES)))


@pytest.fixture(scope="module")
def golden():
    with open(golden_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def checker_source():
    with open(CHECKER, "r", encoding="utf-8") as handle:
        return handle.read()


def run_checker(module_path, dump_path):
    proc = subprocess.run([sys.executable, module_path, dump_path],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode, (proc.stdout + proc.stderr).decode("utf-8", "replace")


def write_dump(tmp_path, name, state):
    path = tmp_path / name
    path.write_text(json.dumps(state), encoding="utf-8")
    return str(path)


def weaken(tmp_path, source, old, new, name="mutant_checker.py"):
    """A throwaway copy of the checker with exactly ONE clause replaced.

    The substring must be UNIQUE, so a rename upstream turns this arm red instead of silently
    mutating nothing and reporting a kill it never made.
    """
    assert source.count(old) == 1, (
        "the clause %r appears %d times in check_equipment_evidence.py; a mutant that cannot "
        "name its clause uniquely may be mutating something else entirely"
        % (old, source.count(old)))
    path = tmp_path / name
    path.write_text(source.replace(old, new), encoding="utf-8")
    return str(path)


def two_sided(tmp_path, source, golden, clause_old, clause_new, evidence_fields=None,
              state_edit=None, expect_in_rejection=None):
    """Assert BOTH sides: unmutated REJECTS, one-clause-weakened ACCEPTS.

    Returns the rejection text so an arm can make a further claim about it.
    """
    state = copy.deepcopy(golden)
    if evidence_fields:
        state["evidence"].update(evidence_fields)
    if state_edit:
        state_edit(state)
    dump = write_dump(tmp_path, "bad.json", state)

    rc_real, out_real = run_checker(CHECKER, dump)
    assert rc_real == 1, (
        "FALSE KILL GUARD: the UNMUTATED checker exited %d on this input, so it was not rejecting "
        "it in the first place and weakening a clause cannot be shown to matter (bead oo-4vdc). "
        "Output: %s" % (rc_real, out_real[:600]))
    if expect_in_rejection:
        assert expect_in_rejection in out_real, (
            "the unmutated rejection does not mention %r, so this arm may be killing a DIFFERENT "
            "clause than it names. Output: %s" % (expect_in_rejection, out_real[:600]))

    mutant = weaken(tmp_path, source, clause_old, clause_new)
    rc_mut, out_mut = run_checker(mutant, dump)
    assert rc_mut == 0, (
        "REDUNDANT CLAUSE: with this clause weakened the checker STILL rejected the input (rc=%d), "
        "so some other clause was doing the work and this one is not individually load-bearing. "
        "That is a finding about the checker, not a reason to loosen the test. Output: %s"
        % (rc_mut, out_mut[:600]))
    return out_real


# --- the three engine refusals ------------------------------------------------------------------


def test_the_duplicate_award_refusal_clause_is_load_bearing(tmp_path, checker_source, golden):
    """The single boolean separating the real engine from an accept-everything stub."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    for key in REQUIRED_TRUE:',
        clause_new='    for key in [k for k in REQUIRED_TRUE if k != "duplicate_award_refused"]:',
        evidence_fields={"duplicate_award_refused": False},
        expect_in_rejection="duplicate_award_refused")


def test_the_undamageable_refusal_clause_is_load_bearing(tmp_path, checker_source, golden):
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    for key in REQUIRED_FALSE:',
        clause_new='    for key in [k for k in REQUIRED_FALSE '
                   'if k != "undamageable_damage_accepted"]:',
        evidence_fields={"undamageable_damage_accepted": True},
        expect_in_rejection="undamageable_damage_accepted")


def test_the_status_read_back_clause_is_load_bearing(tmp_path, checker_source, golden):
    """The OTHER half of the damage refusal - the half a single-sided checker cannot see.

    The stored BOOLEAN is left at its blessed False, so only the clause that reads the STATUS back
    can reject this input. If that clause is weakened and the checker still refuses, the boolean
    clause was silently covering for it.
    """
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if _require(evidence, "undamageable_status_after", label) '
                   '!= EQUIPMENT_OK:',
        clause_new='    if False:',
        evidence_fields={"undamageable_status_after": "EQUIPMENT_DAMAGED"},
        expect_in_rejection="REFUSED damage write")


# --- the state machine and the delta --------------------------------------------------------------


def test_the_status_transition_clause_is_load_bearing(tmp_path, checker_source, golden):
    """A collapsed state machine reports EQUIPMENT_OK twice; only the PAIR comparison sees it."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if transition != EXPECTED_TRANSITION:',
        clause_new='    if False:',
        evidence_fields={"status_transition": ["EQUIPMENT_OK", "EQUIPMENT_OK"]},
        expect_in_rejection="status machine")


def test_the_count_delta_clause_is_load_bearing(tmp_path, checker_source, golden):
    """The state delta the harness physically cannot write: Ship.equipment is read-only in JS."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if _require(evidence, "equipment_count_delta", label) != 1:',
        clause_new='    if False:',
        evidence_fields={"equipment_count_delta": 0},
        expect_in_rejection="equipment_count_delta")


def test_the_empty_starting_array_clause_is_load_bearing(tmp_path, checker_source, golden):
    """What makes the measured growth ATTRIBUTABLE to this scenario's own award."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if _require(evidence, "count_before_award", label) != '
                   'EXPECTED_COUNT_BEFORE_AWARD:',
        clause_new='    if False:',
        evidence_fields={"count_before_award": 3, "count_after_remove": 3},
        expect_in_rejection="item(s) of equipment")


# --- pricing ---------------------------------------------------------------------------------------


def test_the_price_times_factor_clause_is_load_bearing(tmp_path, checker_source, golden):
    """The checker RE-DERIVES the arithmetic; without this clause it would trust the stored charge."""
    ev = golden["evidence"]
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if abs(charge - price * factor) > 1e-6:',
        clause_new='    if False:',
        evidence_fields={"purchase_charge": ev["purchase_charge"] + 1.0,
                         "credits_delta": ev["purchase_charge"] + 1.0,
                         "credits_after": ev["credits_before"] - (ev["purchase_charge"] + 1.0)},
        expect_in_rejection="times the station's factor")


def test_the_balance_correspondence_clause_is_load_bearing(tmp_path, checker_source, golden):
    """Storing the numbers apart is what makes a balance that drifted from the price visible."""
    ev = golden["evidence"]
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if abs((before - after) - charge) > 1e-6:',
        clause_new='    if False:',
        evidence_fields={"credits_after": ev["credits_after"] - 500.0},
        expect_in_rejection="do not correspond")


def test_the_expected_price_literal_is_load_bearing(tmp_path, checker_source, golden):
    """WIDENING A CONSTANT, which is exactly what a re-blessed fixture looks like.

    The mutant does not delete the clause: it changes the expected price to the wrong value the
    dump carries. A maintainer who re-blesses a price must not thereby disarm the assertion, so
    this arm proves the literal - not some neighbouring clause - is what catches a silent pricing
    change.
    """
    ev = golden["evidence"]
    factor = ev["equipment_price_factor"]
    two_sided(
        tmp_path, checker_source, golden,
        clause_old="EXPECTED_PURCHASE_PRICE = 6000.0",
        clause_new="EXPECTED_PURCHASE_PRICE = 1.0",
        evidence_fields={"purchase_price": 1.0, "purchase_charge": 1.0 * factor,
                         "credits_delta": 1.0 * factor,
                         "credits_after": ev["credits_before"] - 1.0 * factor},
        expect_in_rejection="equipment.plist gives")


def test_the_price_factor_literal_is_load_bearing(tmp_path, checker_source, golden):
    ev = golden["evidence"]
    price = ev["purchase_price"]
    two_sided(
        tmp_path, checker_source, golden,
        clause_old="EXPECTED_PRICE_FACTOR = 1.0",
        clause_new="EXPECTED_PRICE_FACTOR = 0.5",
        evidence_fields={"equipment_price_factor": 0.5, "purchase_charge": price * 0.5,
                         "credits_delta": price * 0.5,
                         "credits_after": ev["credits_before"] - price * 0.5},
        expect_in_rejection="equipmentPriceFactor")


# --- the tech-level straddle --------------------------------------------------------------------------


def test_the_straddle_clause_is_load_bearing(tmp_path, checker_source, golden):
    """`within <= tech < above` is the two-sided predicate a degenerate tech level fails.

    The dump's own boolean `tech_level_above_unavailable` is left TRUE, so a permissive dump that
    merely ASSERTS the control was unavailable passes every other clause; only the straddle
    arithmetic catches it.
    """
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if not within <= tech < above:',
        clause_new='    if False:',
        evidence_fields={"tech_level_above": 1},
        expect_in_rejection="straddle")


def test_the_station_tech_level_literal_is_load_bearing(tmp_path, checker_source, golden):
    """A station whose tech level silently changed is the reading the literal exists to catch.

    ISOLATION NOTE (measured): the obvious input - a station reporting 0 - is caught FIRST by the
    REQUIRED_POSITIVE sweep, so the literal could be deleted and a degenerate 0 would still be
    rejected. Using tech level 1 instead (positive, self-consistent, and still straddled by
    within=1 < above=9) walks past every neighbouring clause, so ONLY the literal can reject it.
    That is the case that matters anyway: a wrong-but-plausible tech level, not an obvious zero.
    """
    two_sided(
        tmp_path, checker_source, golden,
        clause_old="EXPECTED_STATION_TECH_LEVEL = 4",
        clause_new="EXPECTED_STATION_TECH_LEVEL = 1",
        evidence_fields={"station_tech_level": 1, "system_tech_level": 1, "tech_level_within": 1},
        expect_in_rejection="equivalentTechLevel")


# --- ordering ------------------------------------------------------------------------------------------


def test_the_registry_floor_clause_is_load_bearing(tmp_path, checker_source, golden):
    """An order pinned over a handful of entries cannot see the reordering item 0.1 names.

    ISOLATION NOTE (measured): a two-key registry is caught FIRST by the clause requiring this
    scenario's own four keys to be present in the enumeration, so the floor could be deleted and a
    two-key registry would still be rejected - for the wrong reason. This input therefore keeps
    ALL FOUR scenario keys and pads to 10 real keys, which is self-consistent in every other
    respect and under the floor only.
    """
    ev = golden["evidence"]
    needed = [ev["award_key"], ev["undamageable_key"], ev["purchase_key"],
              ev["tech_level_above_key"]]
    short = needed + [k for k in ev["registry_order"] if k not in needed][:6]
    assert len(short) == 10 and len(set(short)) == 10
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if len(order) < MIN_REGISTRY_ENTRIES:',
        clause_new='    if False:',
        evidence_fields={"registry_order": short, "registry_entries": len(short)},
        state_edit=lambda s: s["equipment"].update(
            {"registry_order": short, "registry_entries": len(short)}),
        expect_in_rejection="registry key(s), under the")


def test_the_registry_duplicate_clause_is_load_bearing(tmp_path, checker_source, golden):
    """A duplicated entry HIDES A MISSING ONE when the order is compared."""
    order = list(golden["evidence"]["registry_order"])
    order[-1] = order[0]
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if len(set(order)) != len(order):',
        clause_new='    if False:',
        evidence_fields={"registry_order": order},
        state_edit=lambda s: s["equipment"].update({"registry_order": order}),
        expect_in_rejection="duplicate keys")


def test_the_two_copies_of_the_order_must_agree_clause_is_load_bearing(
        tmp_path, checker_source, golden):
    """Hand-editing one copy of the order is what re-blessing by file edit looks like."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if block.get("registry_order") != order:',
        clause_new='    if False:',
        state_edit=lambda s: s["equipment"].__setitem__(
            "registry_order", list(reversed(s["equipment"]["registry_order"]))),
        expect_in_rejection="edited by hand")


def test_the_final_array_must_hold_the_purchase_clause_is_load_bearing(
        tmp_path, checker_source, golden):
    """The item that was PAID for must still be on the ship at the dump.

    ISOLATION NOTE (measured): simply DELETING the purchased key leaves one item, which the
    MIN_FINAL_EQUIPMENT floor rejects first. The purchased key is therefore SUBSTITUTED for
    another real registry key, so the array is still two items long and self-consistent and only
    the 'holds the purchase' clause can object - which is also the realistic failure: a purchase
    that installed the WRONG item.
    """
    ev = golden["evidence"]
    substitute = next(k for k in ev["registry_order"]
                      if k not in ev["equipment_keys_final"] and k != ev["award_key"])
    final = [substitute if k == ev["purchase_key"] else k for k in ev["equipment_keys_final"]]
    assert len(final) == len(ev["equipment_keys_final"]) and ev["purchase_key"] not in final
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if evidence["purchase_key"] not in final:',
        clause_new='    if False:',
        evidence_fields={"equipment_keys_final": final},
        state_edit=lambda s: s["equipment"].update(
            {"player_equipment": final,
             "player_equipment_status": {k: "EQUIPMENT_OK" for k in final}}),
        expect_in_rejection="does not hold the purchased")


# --- the world -------------------------------------------------------------------------------------------


def test_the_undocked_clause_is_load_bearing(tmp_path, checker_source, golden):
    """undocked_seen is recorded as an explicit FALSE precisely so a launch fails BY NAME."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    for key in REQUIRED_FALSE:',
        clause_new='    for key in [k for k in REQUIRED_FALSE if k != "undocked_seen"]:',
        evidence_fields={"undocked_seen": True},
        expect_in_rejection="undocked_seen")


def test_the_empty_market_clause_is_load_bearing(tmp_path, checker_source, golden):
    """An empty market means the STATION'S SERVICES did not initialise - this scenario's subject."""
    two_sided(
        tmp_path, checker_source, golden,
        clause_old='    if not state["market"]:',
        clause_new='    if False:',
        state_edit=lambda s: s.__setitem__("market", {}),
        expect_in_rejection="EMPTY market")


# --- the guard on the guards -------------------------------------------------------------------------------


def test_the_blessed_dump_is_accepted_by_the_unmutated_checker():
    """The CONTROL for this whole file.

    Every arm above asserts 'unmutated rejects'. If the checker rejected EVERYTHING, all of them
    would pass while proving nothing. This arm is what makes the rc=1 assertions meaningful.
    """
    rc, out = run_checker(CHECKER, golden_path())
    assert rc == 0, "the unmutated checker rejects its own blessed dump: %s" % out[:800]
    assert "PASS" in out


def test_a_mutant_whose_clause_is_missing_fails_loudly(tmp_path, checker_source):
    """The weaken() uniqueness guard itself.

    A mutant that silently replaces nothing would run the UNMUTATED checker and report whatever it
    reports - a kill that never happened. This arm proves the guard fires.
    """
    with pytest.raises(AssertionError) as exc:
        weaken(tmp_path, checker_source, "if this_clause_does_not_exist:", "if False:")
    assert "appears 0 times" in str(exc.value)
