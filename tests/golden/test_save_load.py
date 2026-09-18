"""Offline falsifiability suite for golden scenario 006 (save/load round-trip).

No game, no build, no network. Every test here answers one question: CAN THE GATE GO RED? A
green test count proves nothing on its own, so each test feeds a KNOWN-BAD input to the real
checker and asserts it is REJECTED, rather than only feeding good input and asserting acceptance.

The three families:

  * the evidence checker rejects each vacuity route by name (empty census, missing/stub save,
    a load that did not happen, an equality reported over fewer fields than were compared);
  * the redundancy on the critical property "a save was really loaded" is pinned BEHAVIOURALLY -
    each defence is removed in a COPY of the checker and the copy must still reject the bad
    input, so the redundancy cannot be silently collapsed by a later refactor, and so a mutant
    that removes one defence is correctly read as EQUIVALENT rather than as a hole;
  * the comparison primitives refuse self-comparison and unknown conversions.
"""

import copy
import importlib.util
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_save_load_evidence as checker  # noqa: E402
import save_load  # noqa: E402

SPEC = save_load.load_spec()


def good_dump():
    """A dump shaped exactly like a real run of this scenario. Values are the MEASURED ones."""
    return {
        "entities": [{"id": "Coriolis Station", "position": [1.5, 2.5, 3.5]},
                     {"id": "Rock Hermit", "position": [4.5, 5.5, 6.5]}],
        "market": {("g%02d" % i): {"price": 1.5, "quantity": 2} for i in range(17)},
        "player": {"credits": 100.0, "ship": {"docked": True}},
        "evidence": {
            "census_fields": 11,
            "census_populated": 8,
            "clock_at_or_past_save": True,
            "commander_name": "Jameson",
            "load_verified": True,
            "populators_suppressed": 36,
            "round_trip_fields_equal": 11,
            "round_trip_ok": True,
            "save_bytes": 36652,
            "save_file": "oolite-standard.oolite-save",
            "saved_ship_clock": 180058018403.92,
            "scenario": "006-save-load",
            "seed": 20260918,
            "system_id": 7,
            "system_name": "Lave",
        },
    }


def reject_reason(dump):
    """Run the real checker and return its message, asserting it REJECTED the input."""
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(dump, "dump-under-test")
    return str(exc.value)


# --- the positive control ---------------------------------------------------------------------
# Without this, every rejection test below could be satisfied by a checker that rejects
# everything, which discriminates nothing.

def test_a_real_run_is_ACCEPTED_so_the_rejections_below_discriminate():
    summary = checker.check(good_dump(), "good")
    assert "11/11 census field(s) round-tripped equal" in summary
    assert "oolite-standard.oolite-save" in summary


# --- vacuity route 1: the state is EMPTY -------------------------------------------------------

def test_rejects_a_census_too_small_to_be_worth_comparing():
    d = good_dump()
    d["evidence"]["census_fields"] = 3
    d["evidence"]["round_trip_fields_equal"] = 3
    assert "TOO SMALL" in reject_reason(d)


def test_rejects_a_census_of_empty_values():
    d = good_dump()
    d["evidence"]["census_populated"] = 1
    assert "EMPTY" in reject_reason(d)


def test_save_load_refuses_an_empty_census_at_capture_time():
    with pytest.raises(save_load.Refusal) as exc:
        save_load.assert_non_vacuous({"a": 1, "b": 2}, "tiny census")
    assert "fewer than the %d minimum" % save_load.MIN_CENSUS_FIELDS in str(exc.value)


def test_save_load_refuses_a_census_of_zeros_and_empty_strings():
    census = {("f%d" % i): ("" if i % 2 else 0) for i in range(12)}
    with pytest.raises(save_load.Refusal) as exc:
        save_load.assert_non_vacuous(census, "all-empty census")
    assert "compares equal to any other empty census" in str(exc.value)


# --- vacuity route 2: the SAVE did not happen --------------------------------------------------

def test_rejects_a_trivially_small_save_file():
    d = good_dump()
    d["evidence"]["save_bytes"] = 12
    assert "TRIVIAL" in reject_reason(d)


def test_rejects_a_dump_that_does_not_name_its_save_file():
    d = good_dump()
    d["evidence"]["save_file"] = ""
    assert "does not name the save file" in reject_reason(d)


def test_save_load_refuses_a_missing_save_file(tmp_path):
    with pytest.raises(save_load.Refusal) as exc:
        save_load.read_save_file(str(tmp_path / "nope.oolite-save"))
    assert "DOES NOT EXIST" in str(exc.value)


def test_save_load_refuses_a_stub_save_file(tmp_path):
    stub = tmp_path / "stub.oolite-save"
    stub.write_bytes(b"x" * 10)
    with pytest.raises(save_load.Refusal) as exc:
        save_load.read_save_file(str(stub))
    assert "under the %d-byte floor" % save_load.MIN_SAVE_BYTES in str(exc.value)


def test_save_load_refuses_a_save_missing_census_keys():
    plist = {"credits": 1000.0}
    with pytest.raises(save_load.Refusal) as exc:
        save_load.saved_census(SPEC, plist)
    assert "missing" in str(exc.value)


# --- vacuity route 3: the LOAD did not happen --------------------------------------------------

def unloaded_dump():
    """A dump from a game that booted but never adopted a save: no system, no commander, no
    clock. This is the input every load defence must reject."""
    d = good_dump()
    d["evidence"]["load_verified"] = False
    d["evidence"]["clock_at_or_past_save"] = False
    d["evidence"]["system_name"] = ""
    d["evidence"]["commander_name"] = ""
    d["evidence"]["saved_ship_clock"] = 0
    return d


def test_rejects_a_dump_from_a_game_that_never_loaded_a_save():
    reason = reject_reason(unloaded_dump())
    assert "load_verified" in reason
    assert "system_name" in reason


def test_rejects_a_dump_predating_the_populator_suppression():
    d = good_dump()
    del d["evidence"]["populators_suppressed"]
    assert "predates the populator suppression" in reject_reason(d)


# --- vacuity route 4: compared something to ITSELF ---------------------------------------------

def test_rejects_an_equality_claimed_over_fewer_fields_than_were_compared():
    d = good_dump()
    d["evidence"]["round_trip_fields_equal"] = 9  # 2 fields did not match
    assert "did not match" in reject_reason(d)


def test_compare_census_refuses_a_mapping_against_ITSELF():
    census = {("f%d" % i): i + 1 for i in range(11)}
    with pytest.raises(save_load.Refusal) as exc:
        save_load.compare_census(census, census, "left", "right")
    assert "SAME object in memory" in str(exc.value)


def test_compare_census_does_NOT_refuse_two_equal_but_distinct_mappings():
    """The guard must be IDENTITY, never equality: refusing on equality would refuse every
    correct round-trip, which is the answer rather than the defect."""
    left = {("f%d" % i): i + 1 for i in range(11)}
    right = copy.deepcopy(left)
    assert save_load.compare_census(left, right, "left", "right") == []


def test_compare_census_reports_a_single_perturbed_field_by_name_with_both_values():
    left = {("f%d" % i): i + 1 for i in range(11)}
    right = copy.deepcopy(left)
    right["f3"] = 999
    problems = save_load.compare_census(left, right, "saved", "loaded")
    assert len(problems) == 1
    assert "f3" in problems[0] and "4" in problems[0] and "999" in problems[0]


# --- the conversion table cannot hide a mismatch -----------------------------------------------

def test_an_unknown_conversion_kind_is_REFUSED_not_silently_passed_through():
    """A catch-all branch in _normalise would be a place to hide a mismatch; there is none."""
    with pytest.raises(save_load.Refusal) as exc:
        save_load._normalise(1, "whatever_kind")
    assert "refusing to invent a conversion" in str(exc.value)


def test_the_tenths_conversion_is_applied_and_is_not_the_identity():
    assert save_load._normalise(1000.0, "float_tenths") == 100.0
    assert save_load._normalise(70, "float_tenths") == 7.0


# --- the spec itself ---------------------------------------------------------------------------

def test_the_census_is_substantial_and_every_field_is_justified():
    census = SPEC["census"]
    assert len(census) >= save_load.MIN_CENSUS_FIELDS, (
        "shrinking the census is how this gate becomes vacuous; the floor is pinned here and in "
        "save_load.MIN_CENSUS_FIELDS")
    for field in census:
        assert field["why"].strip(), "census field %s carries no justification" % field["plist"]
        assert field["kind"] in ("int", "str", "float_tenths")


def test_the_census_keys_are_unique():
    keys = [f["plist"] for f in SPEC["census"]]
    assert len(keys) == len(set(keys))


def test_the_floors_agree_between_the_scenario_and_its_checker():
    """Duplicated constants are the guard: editing one and not the other fails here."""
    assert checker.MIN_SAVE_BYTES == save_load.MIN_SAVE_BYTES
    assert checker.MIN_CENSUS_FIELDS == save_load.MIN_CENSUS_FIELDS


# --- the redundancy on the critical property, pinned BEHAVIOURALLY ------------------------------

def _load_checker_copy(tmp_path, transform, name):
    """Copy the evidence checker to a temp dir, apply `transform` to its SOURCE, and import the
    result as a separate module. Behavioural, not a string match on source text."""
    src = os.path.join(HERE, "check_save_load_evidence.py")
    with open(src, "r", encoding="utf-8") as handle:
        text = handle.read()
    mutated = transform(text)
    assert mutated != text, "the mutation did not change the checker's source"
    path = tmp_path / ("%s.py" % name)
    path.write_text(mutated, encoding="utf-8")
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_each_load_defence_independently_rejects_an_unloaded_dump(tmp_path):
    """THE REDUNDANCY PIN.

    "A save was really loaded" is enforced twice, by defences that share no code: the
    REQUIRED_TRUE table, and the dedicated check_load_signals() clause. Removing either one must
    leave the property FULLY enforced by the other - that is what makes a single-defence mutant
    EQUIVALENT rather than a hole, and what stops a later refactor collapsing the pair without
    anyone noticing.
    """
    bad = unloaded_dump()

    only_signals = _load_checker_copy(
        tmp_path,
        lambda t: t.replace(
            'REQUIRED_TRUE = ("round_trip_ok", "load_verified", "clock_at_or_past_save")',
            'REQUIRED_TRUE = ("round_trip_ok",)'),
        "checker_without_required_true")
    with pytest.raises(only_signals.EvidenceError) as exc:
        only_signals.check(bad, "bad")
    assert "system_name" in str(exc.value), (
        "with the REQUIRED_TRUE entries removed, check_load_signals() must still reject a dump "
        "from a game that never loaded a save")

    only_table = _load_checker_copy(
        tmp_path,
        lambda t: t.replace("    check_load_signals(ev, problems)\n", "    pass\n"),
        "checker_without_signal_clause")
    with pytest.raises(only_table.EvidenceError) as exc:
        only_table.check(bad, "bad")
    assert "load_verified" in str(exc.value), (
        "with check_load_signals() removed, the REQUIRED_TRUE table must still reject it")


def test_removing_BOTH_load_defences_does_let_the_bad_dump_through(tmp_path):
    """The control for the test above: the two defences really are the only things enforcing
    this property, so the pin is measuring what it claims to measure rather than being satisfied
    by some third check that would mask a genuine regression."""
    both_gone = _load_checker_copy(
        tmp_path,
        lambda t: t.replace(
            'REQUIRED_TRUE = ("round_trip_ok", "load_verified", "clock_at_or_past_save")',
            'REQUIRED_TRUE = ("round_trip_ok",)'
        ).replace("    check_load_signals(ev, problems)\n", "    pass\n"),
        "checker_without_either")
    both_gone.check(unloaded_dump(), "bad")  # no raise: the property is now unenforced


# --- the CLI contract ---------------------------------------------------------------------------

def test_cli_returns_1_for_a_dump_without_evidence(tmp_path, capsys):
    path = tmp_path / "noevidence.json"
    path.write_text(json.dumps({"entities": [], "market": {}, "player": {}}), encoding="utf-8")
    assert checker.main([str(path)]) == 1


def test_cli_returns_2_for_a_missing_file_not_0(tmp_path):
    """rc=2 is "I cannot tell you" and must never be readable as "the evidence is there"."""
    assert checker.main([str(tmp_path / "absent.json")]) == 2


def test_cli_returns_2_for_malformed_json(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not json", encoding="utf-8")
    assert checker.main([str(path)]) == 2


def test_cli_returns_0_for_a_real_dump(tmp_path):
    path = tmp_path / "good.json"
    path.write_text(json.dumps(good_dump()), encoding="utf-8")
    assert checker.main([str(path)]) == 0
