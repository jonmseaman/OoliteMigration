"""Offline tests for scenario 019's harness, evidence checker and knob gate. No game, no build.

WHAT THESE PIN
--------------
`equipment_services.py`, `check_equipment_evidence.py` and `gate_019_spec.py` are the three halves
of this scenario's anti-vacuity defence, and the failure mode they exist to prevent is a green run
that measured nothing: a game that died in display setup still exits 0 with no ERROR lines (bead
oo-het), and on a shared box a sibling worker's console can quit a game four seconds in while it
still exits 0.

Every test below is therefore NEGATIVE - it feeds the checker a dump that a DEAD, DEGENERATE or
PERMISSIVE run would produce and requires a rejection that NAMES the field. A checker nobody
validates is not protected merely because the data is (bead oo-jor), and the arms that matter most
here are the three ENGINE REFUSALS: a model that accepts every write produces a dump that is
POSITIVE in every other respect and differs only in those three booleans.

Nothing here launches the game, writes under the repo, or depends on a build.
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

sys.path.insert(0, HERE)

import check_equipment_evidence as checker  # noqa: E402
import equipment_services as scenario  # noqa: E402

GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)
GATE = os.path.join(HERE, "gate_019_spec.py")


def _first(paths, what):
    for path in paths:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s; searched %r" % (what, list(paths)))


@pytest.fixture(scope="module")
def spec():
    return scenario.load_spec()


@pytest.fixture(scope="module")
def golden():
    with open(_first(GOLDEN_CANDIDATES, "blessed state.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def provenance():
    with open(_first(PROVENANCE_CANDIDATES, "provenance.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


def mutate(golden, **evidence_fields):
    """A copy of the blessed dump with named evidence fields replaced. Never touches the repo."""
    state = copy.deepcopy(golden)
    state["evidence"].update(evidence_fields)
    return state


# --- the baseline. Without this, every rejection below could be a checker that rejects all ------


def test_the_blessed_dump_is_accepted(golden):
    """THE CONTROL. A checker that rejects everything 'passes' every negative test below.

    Bead oo-4vdc: a mutant that kills an already-red checker registers a FALSE KILL. This arm is
    what makes the rest of the file mean something.
    """
    summary = checker.check(golden, "blessed")
    assert "EQ_ECM" in summary
    assert "REFUSED" in summary


def test_the_blessed_dump_passes_the_harness_own_assertions(golden, spec):
    """The harness's assert_ran and the offline checker are SEPARATE implementations.

    They must agree on the blessed dump; if they ever diverge, one of them is measuring something
    the other is not, and the scenario's story has two different endings.
    """
    assert scenario.assert_ran(golden["evidence"], spec) is True


# --- the three ENGINE REFUSALS: what a permissive model cannot fake -----------------------------


def test_a_permissive_model_that_allows_duplicate_awards_is_rejected(golden):
    """The clause that separates 'the engine applied a rule' from 'the write was accepted'.

    A model that accepts every award returns TRUE from canAwardEquipment for a second award of a
    non-carry-multiple item, so this single boolean is the whole difference between the real
    engine and an accept-everything stub whose dump is positive in every other respect.
    """
    bad = mutate(golden, duplicate_award_refused=False)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "permissive")
    assert "duplicate_award_refused" in str(exc.value)


def test_a_model_that_damages_an_undamageable_item_is_rejected(golden):
    bad = mutate(golden, damage_refused_for_undamageable=False)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "damages-everything")
    assert "damage_refused_for_undamageable" in str(exc.value)


def test_the_damage_refusal_is_checked_on_BOTH_halves(golden):
    """The boolean AND the status read back afterwards.

    A checker that looked only at the boolean would accept an engine that returned false while
    damaging the item anyway; a checker that looked only at the status would accept one that
    returned true and silently did nothing. This arm holds the boolean at its blessed value and
    corrupts ONLY the status, which is the half a single-sided checker cannot see.
    """
    assert golden["evidence"]["undamageable_damage_accepted"] is False
    bad = mutate(golden, undamageable_status_after="EQUIPMENT_DAMAGED")
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "lying-refusal")
    assert "undamageable_status_after" in str(exc.value) or "REFUSED damage write" in str(exc.value)


def test_one_key_cannot_play_both_damage_roles(golden):
    """award_key == undamageable_key would make one of the two refusal arms vacuous."""
    bad = mutate(golden, undamageable_key=golden["evidence"]["award_key"])
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "same-key")
    assert "cannot be both" in str(exc.value)


# --- the status machine -------------------------------------------------------------------------


def test_a_collapsed_status_machine_is_rejected(golden):
    """BOTH readings are stored precisely so a collapsed machine reports the same value twice.

    EQUIPMENT_OK after a damage write means damaged equipment keeps working - the exact regression
    the OK/DAMAGED state machine exists to catch, and one that a dump storing only the FINAL
    status could not express.
    """
    bad = mutate(golden, status_transition=["EQUIPMENT_OK", "EQUIPMENT_OK"])
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "collapsed")
    assert "status machine" in str(exc.value)


def test_an_undefined_equipment_status_is_rejected(golden):
    """OOJSShip.m defines exactly three script-visible states."""
    bad = mutate(golden, status_transition=["EQUIPMENT_OK", "EQUIPMENT_SORT_OF_BROKEN"])
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "invented-status")
    assert "status" in str(exc.value)


def test_equipment_that_survives_removal_is_rejected(golden):
    bad = mutate(golden, status_after_remove="EQUIPMENT_OK")
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "unremovable")
    assert "removeEquipment" in str(exc.value)


# --- the state delta the harness cannot write ---------------------------------------------------


def test_an_award_that_did_not_install_anything_is_rejected(golden):
    """Ship.equipment is READ-ONLY in the JS API, so the delta comes from the engine.

    This is the exact condition the harness's own --break-equipment arm produces live.
    """
    bad = mutate(golden, equipment_count_delta=0)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "no-install")
    assert "equipment_count_delta" in str(exc.value)


def test_an_award_of_the_WRONG_item_is_rejected(golden):
    """The count alone cannot tell an award of the right item from an award of the wrong one."""
    bad = mutate(golden, awarded_key_present=False)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "wrong-item")
    assert "awarded_key_present" in str(exc.value)


def test_a_ship_that_started_with_equipment_is_rejected(golden):
    """The empty starting array is what makes the measured growth ATTRIBUTABLE.

    'The equipment array is non-empty' is explicitly NOT evidence in the catalogue, because the
    starting ship usually carries equipment. This scenario's save carries none.
    """
    bad = mutate(golden, count_before_award=3)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "pre-equipped")
    assert "count_before_award" in str(exc.value) or "item(s) of equipment" in str(exc.value)


# --- pricing: three numbers stored apart so they cannot slide together ---------------------------


def test_credits_that_did_not_move_are_rejected(golden):
    bad = mutate(golden, credits_delta=0.0)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "free-lunch")
    assert "credits_delta" in str(exc.value) or "positive" in str(exc.value)


def test_a_charge_that_does_not_match_price_times_factor_is_rejected(golden):
    """The checker RE-DERIVES the arithmetic rather than trusting the stored charge."""
    bad = mutate(golden, purchase_charge=golden["evidence"]["purchase_charge"] + 1.0)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "bad-arithmetic")
    assert "charge" in str(exc.value)


def test_a_balance_that_does_not_match_the_charge_is_rejected(golden):
    """Storing the numbers apart is what makes this detectable.

    If the dump carried only 'credits_after', a pricing change would move it and the stored golden
    together the moment anyone re-blessed. Here the balance and the price must CORRESPOND.
    """
    bad = mutate(golden, credits_after=golden["evidence"]["credits_after"] - 500.0)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "balance-drift")
    assert "credits" in str(exc.value)


def test_a_silently_changed_engine_price_is_rejected(golden):
    """The literal in the checker is what makes a registry that stopped loading prices visible."""
    ev = golden["evidence"]
    bad = mutate(golden, purchase_price=1.0, purchase_charge=1.0 * ev["equipment_price_factor"],
                 credits_delta=1.0 * ev["equipment_price_factor"],
                 credits_after=ev["credits_before"] - 1.0 * ev["equipment_price_factor"])
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "cheap-ecm")
    assert "pricing" in str(exc.value) or "equipment.plist" in str(exc.value)


def test_a_silently_changed_price_factor_is_rejected(golden):
    ev = golden["evidence"]
    factor = 0.5
    bad = mutate(golden, equipment_price_factor=factor,
                 purchase_charge=ev["purchase_price"] * factor,
                 credits_delta=ev["purchase_price"] * factor,
                 credits_after=ev["credits_before"] - ev["purchase_price"] * factor)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "half-price")
    assert "equipmentPriceFactor" in str(exc.value)


# --- the tech-level gate, two-sided --------------------------------------------------------------


def test_a_degenerate_station_tech_level_is_rejected(golden):
    """A station reporting 0 is exactly what the straddle exists to catch."""
    bad = mutate(golden, station_tech_level=0, system_tech_level=0)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "tl-zero")
    assert "TechLevel" in str(exc.value) or "tech" in str(exc.value).lower()


def test_both_keys_on_the_same_side_of_the_threshold_are_rejected(golden):
    """One key on one side of a threshold passes against ANY constant.

    Here the control is moved BELOW the station's level, so the pair no longer straddles it - the
    gate would then be satisfied by a station reporting anything at all.
    """
    bad = mutate(golden, tech_level_above=1, tech_level_above_unavailable=True)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "no-straddle")
    assert "straddle" in str(exc.value)


def test_the_same_key_on_both_sides_of_the_gate_is_rejected(golden):
    bad = mutate(golden, tech_level_above_key=golden["evidence"]["tech_level_within_key"])
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "one-key-gate")
    assert "same key" in str(exc.value)


# --- ordering: the regression class item 0.1 names ------------------------------------------------


def test_a_registry_that_did_not_load_is_rejected(golden):
    bad = mutate(golden, registry_order=["EQ_ECM", "EQ_CARGO_BAY"], registry_entries=2)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "short-registry")
    assert "registry" in str(exc.value)


def test_a_duplicated_registry_entry_is_rejected(golden):
    """A duplicate hides a MISSING entry when the order is compared."""
    order = list(golden["evidence"]["registry_order"])
    order[-1] = order[0]
    bad = mutate(golden, registry_order=order)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "dup-registry")
    assert "duplicate" in str(exc.value)


def test_a_key_the_registry_does_not_know_is_rejected(golden):
    bad = mutate(golden, purchase_key="EQ_IMAGINARY")
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "ghost-key")
    assert "registry" in str(exc.value)


def test_the_registry_order_is_stored_in_TWO_places_and_must_agree(golden):
    """equipment.registry_order and evidence.registry_order come from ONE reading.

    A divergence means one of them was hand-edited - which is precisely what re-blessing a golden
    by editing the file looks like.
    """
    bad = copy.deepcopy(golden)
    bad["equipment"]["registry_order"] = list(reversed(bad["equipment"]["registry_order"]))
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "hand-edited")
    assert "registry_order" in str(exc.value)


def test_a_registry_count_that_disagrees_with_the_order_is_rejected(golden):
    bad = mutate(golden, registry_entries=999)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "miscounted")
    assert "registry_entries" in str(exc.value)


# --- the world the measurement was taken in --------------------------------------------------------


def test_a_run_that_launched_is_rejected(golden):
    """undocked_seen is the ONE field that must be FALSE, recorded rather than omitted."""
    bad = mutate(golden, undocked_seen=True)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "flew-away")
    assert "undocked_seen" in str(exc.value)


def test_a_run_docked_at_a_rock_hermit_is_rejected(golden):
    """A non-main station prices differently, so the pinned factor would mean something else."""
    bad = mutate(golden, station_is_main=False)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "rock-hermit")
    assert "station_is_main" in str(exc.value)


def test_a_dump_taken_while_the_clock_ran_is_rejected(golden):
    bad = mutate(golden, clock_frozen_across_dump=False)
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "unfrozen")
    assert "clock_frozen_across_dump" in str(exc.value)


def test_a_dump_with_an_empty_market_is_rejected(golden):
    """The player is docked at a main station for the whole run.

    An empty commodity market means the station's SERVICES did not initialise - the very subsystem
    whose tech-level-derived pricing this scenario measures.
    """
    bad = copy.deepcopy(golden)
    bad["market"] = {}
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "no-market")
    assert "market" in str(exc.value)


def test_a_dump_with_no_evidence_block_is_rejected(golden):
    """A dump with no evidence compares equal to any other evidence-free dump."""
    bad = copy.deepcopy(golden)
    del bad["evidence"]
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "blank")
    assert "evidence" in str(exc.value)


def test_a_dump_with_no_equipment_block_is_rejected(golden):
    bad = copy.deepcopy(golden)
    del bad["equipment"]
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(bad, "no-equipment")
    assert "equipment" in str(exc.value)


# --- the shared dump must NOT have been edited ------------------------------------------------------


def test_the_shared_dump_state_js_carries_no_equipment(golden):
    """dump_state.js is shared by EVERY landed golden.

    Adding an equipment block there would move 002-017's stored dumps too, turning one new
    scenario into a re-bless of the whole suite. This scenario adds its blocks to its own state.
    """
    with open(os.path.join(HERE, "dump", "dump_state.js"), "r", encoding="utf-8") as handle:
        text = handle.read()
    for marker in ("equipmentKey", "allEquipment", "equipmentStatus"):
        assert marker not in text, (
            "the SHARED dump now mentions %r; every landed golden's dump would move" % marker)


def test_this_scenario_really_does_add_blocks_no_other_golden_has(golden):
    """The positive half of the same claim: 019's dump carries what the shared dump does not."""
    assert "equipment" in golden
    assert set(golden["equipment"]) >= {"registry_order", "player_equipment",
                                        "player_equipment_status", "station"}
    other = os.path.join(HERE, "pending", "015-trumbles", "state.json")
    if os.path.isfile(other):
        with open(other, "r", encoding="utf-8") as handle:
            assert "equipment" not in json.load(handle), (
                "a sibling golden now carries an equipment block; 019 is no longer the artifact "
                "that pins the equipment registry")


# --- the knob gate ------------------------------------------------------------------------------


def test_every_required_knob_is_read_inside_the_function_that_acts_on_it():
    """The AST claim, asserted here too so a refactor cannot silently disarm the gate."""
    import ast
    with open(os.path.join(HERE, "equipment_services.py"), "r", encoding="utf-8") as handle:
        tree = ast.parse(handle.read())
    functions = {n.name: n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)}
    sys.path.insert(0, HERE)
    import gate_019_spec as gate  # noqa: E402
    for knob, func_name in sorted(gate.READ_IN_FUNCTION.items()):
        func = functions[func_name]
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript) and isinstance(n.value, ast.Name)
                 and n.value.id == "spec" and isinstance(n.slice, ast.Constant)
                 and n.slice.value == knob]
        assert reads, "spec[%r] is not read inside %s()" % (knob, func_name)


def test_the_gate_passes_on_the_tree_as_committed():
    rc = subprocess.call([sys.executable, GATE], cwd=REPO_ROOT)
    assert rc == 0, "gate_019_spec.py does not pass on the committed tree"


def test_provenance_records_the_knobs_the_golden_was_blessed_with(provenance, spec):
    knobs = provenance["scenario_knobs"]
    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    assert not drift, "spec.json has drifted from the blessed knobs: %r" % drift


def test_provenance_frame_claims_carry_their_measurements(provenance):
    """An asserted threshold with no measurement behind it is a number someone can widen."""
    liveness = provenance["frame_liveness"]
    assert liveness["asserted"] is True
    assert liveness["floor"] > 0
    assert liveness["margin"]["reading"]

    tolerance = provenance["frame_tolerance"]
    assert tolerance["asserted"] is True
    m = tolerance["measurements"]
    within = max(m["within_bare"] + m["within_loaded"])
    assert m["between_min"] > within, (
        "the measured populations overlap, so the asserted tolerance cannot discriminate")
    assert m["separation_ratio"] > 1.0


def test_the_stability_sweep_accounts_for_every_run(provenance):
    """A REFUSAL is not a DIFFERENCE; collapsing the two is how a stability claim goes dishonest."""
    stability = provenance["stability"]
    assert stability["runs"] >= 10
    assert stability["dumps_written"] + stability["refused"] == stability["runs"]
    assert stability["errored"] == 0
    assert len(stability["distinct_dump_digests"]) == 1
    assert len(stability["per_run"]) == stability["runs"]


def test_the_blessed_artifacts_match_their_recorded_digests(provenance):
    """The witness lives OUTSIDE the artifact it defends (beads oo-3ya, oo-gxp)."""
    import hashlib
    golden_dir = os.path.dirname(_first(PROVENANCE_CANDIDATES, "provenance.json"))
    for name, meta in sorted(provenance["artifacts"].items()):
        path = os.path.join(golden_dir, name)
        assert os.path.isfile(path), "%s is missing" % name
        blob = open(path, "rb").read()
        assert len(blob) == meta["bytes"], "%s is %d bytes, provenance says %d" % (
            name, len(blob), meta["bytes"])
        assert hashlib.sha256(blob).hexdigest() == meta["sha256"], (
            "%s does not match its recorded digest; the artifact or the witness was edited alone"
            % name)


# --- the frame ------------------------------------------------------------------------------------


def test_an_all_black_frame_fails_the_liveness_floor():
    """The one frame property a dead run cannot satisfy."""
    import frame_hash
    black = bytes(frame_hash.GRID_CELLS)
    assert scenario._liveness(black) == 0.0
    floor, _ = scenario._blessed_liveness_floor()
    assert scenario._liveness(black) < floor


def test_the_blessed_frame_clears_the_liveness_floor():
    import frame_hash  # noqa: F401
    grid = open(_first((os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
                        os.path.join(HERE, "pending", SCENARIO, "frame.grid")),
                       "blessed frame.grid"), "rb").read()
    floor, source = scenario._blessed_liveness_floor()
    assert source is not None, "the liveness floor fell back to the in-code default"
    assert scenario._liveness(grid) >= floor


def test_a_wrong_sized_grid_is_refused(tmp_path):
    """The refusal text is formatted by frame_hash so the side-length cannot be mistyped here."""
    bad = tmp_path / "short.grid"
    bad.write_bytes(b"\x00" * 100)
    with pytest.raises(scenario.Refusal):
        scenario._read_grid(str(bad))
