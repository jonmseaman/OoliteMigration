"""ELEVEN MORE checker mutants for scenario 016's evidence checker (bead oo-xy0o).

WHAT THIS ADDS TO WHAT IS ALREADY THERE
---------------------------------------
tests/golden/test_cloaking_load.py (bead oo-ghhw) is the in-repo REFERENCE for checker-weakening
mutation and it already pins FOUR of check_cloaking_evidence.py's clauses: the closed-pair
exact-set comparison, the mission-variable key-set presence clause, the engine-testimony clause
for the credit compensation, and the equipment containment clause. That file is not touched here.

Surveying the same checker for bead oo-xy0o found that the OTHER 22 `if` clauses were unpinned -
including the save-file identity clause, the format-era clause, the declared-migration DELTA, the
census size, the equipment count and the frame-digest exclusion. Each of the eleven below was
MEASURED individually: the unmutated checker refuses the input, and a throwaway copy with that one
clause replaced by `if False:` accepts it. No miskills were found in this set.

The pattern is bead oo-ghhw's, deliberately: two assertions per defence, and the second - the
MUTATED checker going GREEN - is what proves the kill belongs to that clause and not a neighbour.

Nothing in the repo is written to. The checker resolves spec.json relative to its own __file__, so
each mutant is written into a throwaway tree that mirrors the paths it needs; a mutant dropped
anywhere else exits 2 for a reason unrelated to the mutation, and an rc!=0 assertion would read
that as a kill.
"""

import copy
import json
import os
import shutil
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "016-cloaking-save"

CHECKER = os.path.join(HERE, "check_cloaking_evidence.py")
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s for %s; searched %r" % (what, SCENARIO, candidates))


def golden_path():
    return _first(GOLDEN_CANDIDATES, "state.json")


def spec_path():
    return _first(SPEC_CANDIDATES, "spec.json")


@pytest.fixture(scope="module")
def golden():
    with open(golden_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def run_checker(tmp_path, dump, checker=CHECKER, name="dump.json"):
    path = tmp_path / name
    path.write_text(json.dumps(dump, sort_keys=True), encoding="utf-8")
    return subprocess.run([sys.executable, checker, str(path), "--label", "mutant"],
                          cwd=REPO_ROOT, capture_output=True, text=True)


def mutated_checker(tmp_path, clauses, name="chk"):
    with open(CHECKER, "r", encoding="utf-8") as handle:
        src = handle.read()
    for clause in clauses:
        count = src.count(clause)
        assert count == 1, (
            "the clause %r matches the checker %d time(s), not once: it was refactored and this "
            "mutant is stale. A stale mutant silently stops testing anything." % (clause, count))
        src = src.replace(clause, "if False:")
    root = tmp_path / name
    staged = root / "tests" / "golden" / "pending" / SCENARIO
    staged.mkdir(parents=True, exist_ok=True)
    shutil.copy(spec_path(), str(staged / "spec.json"))
    target = root / "tests" / "golden" / "check_cloaking_evidence.py"
    target.write_text(src, encoding="utf-8", newline="\n")
    return str(target)


def assert_kill(tmp_path, clause_name, clauses, bad):
    baseline = run_checker(tmp_path, bad)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject; rc=2 is "
        "a structural error rather than a verdict and the mutant below would register a false "
        "kill (bead oo-4vdc).\n%s%s" % (clause_name, baseline.stdout, baseline.stderr))
    mutated = run_checker(tmp_path, bad, checker=mutated_checker(tmp_path, clauses))
    assert mutated.returncode == 0, (
        "MISKILL: weakening %s did NOT make the checker accept the input it exists to reject, so "
        "that clause is not what rejects it - the mutant is EQUIVALENT or the property has a "
        "second, unpinned defence (bead oo-jor).\n%s%s"
        % (clause_name, mutated.stdout, mutated.stderr))


def ev(golden, **changes):
    dump = copy.deepcopy(golden)
    dump["evidence"].update(changes)
    return dump


# ============================================================================================
# BASELINE
# ============================================================================================

def test_the_blessed_golden_passes_its_own_checker():
    result = subprocess.run([sys.executable, CHECKER, golden_path(), "--label", "golden"],
                            cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path, golden):
    assert run_checker(tmp_path, golden, checker=mutated_checker(tmp_path, ())).returncode == 0


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if a_refactor_deleted_this:",))
    assert "stale" in str(exc.value)


# ============================================================================================
# THE ELEVEN, ALL MEASURED AS KILLS
# ============================================================================================

def test_the_save_file_identity_clause_is_load_bearing(tmp_path, golden):
    """A run that loaded the WRONG FIXTURE answers every other probe perfectly well."""
    assert_kill(tmp_path, "the save_file identity clause",
                ('if ev["save_file"] != want_save:',),
                ev(golden, save_file="Trumbles.oolite-save"))


def test_the_save_format_era_clause_is_load_bearing(tmp_path, golden):
    """THE COMPATIBILITY CONTRACT. A fixture silently replaced by a modern save makes every other
    clause pass while the 1.75 deserialisation path goes untested."""
    assert_kill(tmp_path, "the save-format-era clause",
                ('if str(ev["save_written_by_version"]) != str(spec["save_format_version"]):',),
                ev(golden, save_written_by_version="1.90"))


def test_the_save_size_floor_clause_is_load_bearing(tmp_path, golden):
    """A ten-byte save is a stub, and a stub round-trips trivially."""
    assert_kill(tmp_path, "the save_bytes floor clause", ('if int(ev["save_bytes"]) < 1024:',),
                ev(golden, save_bytes=10))


def test_the_declared_migration_delta_clause_is_load_bearing(tmp_path, golden):
    """A migration declared with the WRONG MAGNITUDE accepts ANY change to that field: without
    this clause `credits` becomes a field the checker has stopped watching entirely."""
    bad = copy.deepcopy(golden)
    detail = bad["evidence"]["census_detail"]["credits"]
    detail["in_engine"] = float(detail["in_file"]) + 1.0
    assert_kill(tmp_path, "the declared-migration delta clause",
                ('if delta != round(float(rule["delta"]), 3):',), bad)


def test_the_declared_removal_that_stopped_clause_is_load_bearing(tmp_path, golden):
    """THE OTHER DIRECTION OF THE CLOSED PAIR: a gate that only caught NEW differences would let
    the declared equipment removal quietly stop without anything going red."""
    assert_kill(tmp_path, "the declared-removal-stopped clause", ("if still:",),
                ev(golden, equipment_missing_in_engine=[]))


def test_the_census_size_clause_is_load_bearing(tmp_path, golden):
    """A shrinking census is the empty-state vacuity route wearing a smaller hat."""
    assert_kill(tmp_path, "the census size clause",
                ('if int(ev["census_fields"]) != len(spec["census"]):',),
                ev(golden, census_fields=3))


def test_the_census_agreement_floor_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the census agreement floor",
                ('if int(ev["census_equal_count"]) < '
                 'int(spec["min_census_fields_round_tripped"]):',),
                ev(golden, census_equal_count=0))


def test_the_mission_variable_agreement_floor_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the mission-variable agreement floor",
                ('if int(ev["mission_variables_equal_count"]) < '
                 'int(spec["min_mission_variables_round_tripped"]):',),
                ev(golden, mission_variables_equal_count=0))


def test_the_equipment_count_clause_is_load_bearing(tmp_path, golden):
    """The equipment census is what carries the energy-bomb migration; a census of one item makes
    that whole defence unevaluable."""
    assert_kill(tmp_path, "the equipment count clause",
                ('if int(ev["equipment_saved_count"]) != int(spec["expected_equipment_count"]):',),
                ev(golden, equipment_saved_count=1))


def test_the_frame_digest_exclusion_clause_is_load_bearing(tmp_path, golden):
    """THE DELIBERATE ASYMMETRY. llvmpipe is not bit-reproducible - this scenario's own sweep
    produced ten DISTINCT frame-grid digests over ten BYTE-IDENTICAL dumps - so a frame hash
    inside state.json would make the golden comparison flake on renderer noise. With this clause
    gone, a future harness could add one and nothing would say so."""
    bad = copy.deepcopy(golden)
    bad["frame_hash"] = "deadbeef"
    assert_kill(tmp_path, "the frame-digest exclusion clause",
                ('if "frame_hash" in blob or "frame_grid" in blob:',), bad)


def test_the_settled_world_clause_is_load_bearing(tmp_path, golden):
    """A world still moving makes the dump a function of how many frames this box rendered."""
    assert_kill(tmp_path, "the settled-world clause", ("if not ev[key]:",),
                ev(golden, world_at_rest=False))
