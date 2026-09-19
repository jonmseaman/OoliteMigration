"""Falsifiability suite for scenario 018: DATA mutants AND CHECKER mutants.

WHY BOTH KINDS, AND WHY A DATA-MUTANT-ONLY SUITE IS NOT ENOUGH
--------------------------------------------------------------
Bead oo-zv2 measured a 28-mutant suite that mutated only state.json and spec.json. An INTACT
checker correctly killed every one - so the suite proved the checker WORKS TODAY while proving
nothing about it being WEAKENED TOMORROW. Replacing a single clause with `if False:` still
reported "47 passed". Bead oo-jor made the same point from the other direction: a gate can protect
its data and leave its VALIDATOR unprotected.

So every load-bearing property here is pinned TWICE:

  * a DATA mutant - corrupt the evidence field and assert the unmutated checker REFUSES it;
  * a CHECKER mutant - copy the checker to a throwaway tree, weaken exactly ONE clause, and assert
    the mutated copy now ACCEPTS the very input the unmutated one rejected.

The second assertion is what proves the kill belongs to THAT clause rather than to a neighbour. A
mutant that does not flip the verdict is reported as a MISKILL and fails, rather than being banked
as a fake kill (bead oo-ghhw's honest shape).

NOTHING IN THE REPOSITORY IS WRITTEN TO. Every mutant is a throwaway copy under pytest's tmp_path.
A harness that mutates in place is one timeout away from committing a sabotaged gate (bead oo-dto
was harvested mid-mutation with `if False:` standing where its one named predicate belonged).
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
SCENARIO = "018-expansion-closure-and-manifestless"

CHECKER = os.path.join(HERE, "check_018_evidence.py")
HARNESS = os.path.join(HERE, "expansion_closure.py")
GATE = os.path.join(HERE, "gate_018_spec.py")

GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
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
    return subprocess.run([sys.executable, checker, str(path)],
                          cwd=REPO_ROOT, capture_output=True, text=True)


def mutated_checker(tmp_path, clauses, name="chk"):
    """A THROWAWAY copy of the checker with each named clause replaced by `if False:`.

    The checker resolves spec.json relative to its own __file__, so the mutant is written into a
    tree that mirrors the paths it needs; a mutant dropped anywhere else exits 2 for a reason
    unrelated to the mutation, and an rc!=0 assertion would misread that as a kill.
    """
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
    target = root / "tests" / "golden" / "check_018_evidence.py"
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
# BASELINE - every later mutant is meaningless if these are not green first (bead oo-4vdc)
# ============================================================================================

def test_the_blessed_golden_passes_its_own_checker():
    result = subprocess.run([sys.executable, CHECKER, golden_path()],
                            cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path, golden):
    assert run_checker(tmp_path, golden, checker=mutated_checker(tmp_path, ())).returncode == 0


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if a_refactor_deleted_this:",))
    assert "stale" in str(exc.value)


def test_the_spec_gate_passes_on_the_committed_tree():
    result = subprocess.run([sys.executable, GATE], cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 0, "gate_018_spec is RED:\n%s%s" % (result.stdout, result.stderr)


def test_the_blessed_frame_is_live():
    result = subprocess.run(
        [sys.executable, HARNESS, "--check-frame", _first(FRAME_CANDIDATES, "frame.grid")],
        cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 0, "the blessed frame fails its own liveness floor:\n%s%s" % (
        result.stdout, result.stderr)


# ============================================================================================
# DATA MUTANTS, each paired with the CHECKER mutant that proves which clause killed it
# ============================================================================================

def test_the_closure_arm_load_clause_is_load_bearing(tmp_path, golden):
    """A run whose primary never reached the search paths has no positive arm at all."""
    assert_kill(tmp_path, "the primary_in_search_paths clause",
                ('if evidence.get("primary_in_search_paths") is False:',),
                ev(golden, primary_in_search_paths=False))


def test_the_dependency_load_clause_is_load_bearing(tmp_path, golden):
    """The primary alone loading does not prove a CLOSURE was composed."""
    assert_kill(tmp_path, "the dependency_in_search_paths clause",
                ('if evidence.get("dependency_in_search_paths") is False:',),
                ev(golden, dependency_in_search_paths=False))


def test_the_negative_control_clause_is_load_bearing(tmp_path, golden):
    """THE clause this scenario exists for: the control run must NOT have loaded the primary.

    If requirement resolution stops enforcing requires_oxps, expansions load with unmet
    dependencies and break silently for every user - and a checker that only ever asserts truth
    cannot express "this must not have happened".
    """
    assert_kill(tmp_path, "the control_primary_in_search_paths NEGATIVE clause",
                ('if evidence.get("control_primary_in_search_paths") is not False:',),
                ev(golden, control_primary_in_search_paths=True))


def test_the_requirement_missing_diagnostic_clause_is_load_bearing(tmp_path, golden):
    """Absence from the search paths cannot distinguish a refusal from a staging bug."""
    assert_kill(tmp_path, "the control_requirement_missing_lines attribution clause",
                ("if not any(primary and primary in ln for ln in lines):",),
                ev(golden, control_requirement_missing_lines=[]))


def test_a_requirement_missing_line_about_something_else_is_refused(tmp_path, golden):
    """The refusal must NAME the primary; a line about another expansion proves nothing here."""
    assert_kill(tmp_path, "the control_requirement_missing_lines attribution clause",
                ("if not any(primary and primary in ln for ln in lines):",),
                ev(golden, control_requirement_missing_lines=[
                    "OXP some.other.expansion.oxz had unmet requirements and was removed from "
                    "the loading list"]))


def test_a_requirement_missing_line_in_BOTH_arms_is_refused(tmp_path, golden):
    """If both arms emit it, the control proves nothing about the closure."""
    assert_kill(tmp_path, "the closure_requirement_missing_lines exclusivity clause",
                ('if evidence.get("closure_requirement_missing_lines"):',),
                ev(golden, closure_requirement_missing_lines=[
                    "OXP oolite.oxp.Svengali.GNN.oxz had unmet requirements and was removed from "
                    "the loading list"]))


def test_the_startup_complete_clause_is_load_bearing(tmp_path, golden):
    """oo-het's exit-87 corpse has the banner, [process.args] and zero ERROR lines."""
    assert_kill(tmp_path, "the startup_complete_both_runs clause",
                ('if evidence.get("startup_complete_both_runs") is False:',),
                ev(golden, startup_complete_both_runs=False))


def test_the_nomanif_count_clause_is_load_bearing(tmp_path, golden):
    """A count of 4 is what staging under a doubly-reachable root produced in scenario 012."""
    assert_kill(tmp_path, "the exact standards-error count clause",
                ("if got != allowed:",),
                ev(golden, closure_nomanif_standards_errors=4))


def test_a_zero_nomanif_count_is_refused(tmp_path, golden):
    """Complaints being LOST is as much a finding as new complaints appearing."""
    assert_kill(tmp_path, "the exact standards-error count clause",
                ("if got != allowed:",),
                ev(golden, control_nomanif_standards_errors=0))


def test_the_nomanif_signature_allowlist_clause_is_load_bearing(tmp_path, golden):
    """A different complaint at the same count must not be absorbed by the allowance."""
    assert_kill(tmp_path, "the standards-error signature allow-list clause",
                ("if sig not in allowed_sigs:",),
                ev(golden, closure_nomanif_standards_error_signatures=[
                    "OXP RetroMissions.oxp failed to parse Config/shipdata.plist"]))


def test_the_unattributed_standards_error_clause_is_load_bearing(tmp_path, golden):
    """An error nobody owns is a finding about the harness or the engine, never noise."""
    assert_kill(tmp_path, "the unattributed standards-error clause",
                ("if unowned:",),
                ev(golden, control_unattributed_standards_errors=[
                    "OXP something.nobody.staged.oxz has no manifest.plist"]))


def test_the_manifestless_still_loads_clause_is_load_bearing(tmp_path, golden):
    """If the fixture stopped loading, load BEHAVIOUR changed, not logging."""
    assert_kill(tmp_path, "the manifestless_in_search_paths_both_runs clause",
                ('if evidence.get("manifestless_in_search_paths_both_runs") is False:',),
                ev(golden, manifestless_in_search_paths_both_runs=False))


def test_the_recomputed_closure_agreement_clause_is_load_bearing(tmp_path, golden):
    """A stale or hand-edited closure list differs from a fresh walk BY NAME."""
    assert_kill(tmp_path, "the staged-vs-recomputed closure clause",
                ("elif staged != recomputed:",),
                ev(golden, recomputed_closure=["oolite.oxp.Svengali.GNN",
                                               "oolite.oxp.SomeoneElse.Library"]))


def test_a_one_member_closure_is_refused(tmp_path, golden):
    """With one member there is no dependency to withhold and no differential to measure."""
    one = ["oolite.oxp.Svengali.GNN"]
    # The control arm is left staged as the closure arm was, so ONLY the size clause differs
    # from the blessed dump; otherwise the identical-staging clause would co-reject the input
    # and the mutant would register as a MISKILL against a clause that is in fact fine.
    assert_kill(tmp_path, "the closure-size clause",
                ("elif len(staged) < 2:",),
                ev(golden, staged_identifiers=one, recomputed_closure=one,
                   control_staged_identifiers=["oolite.oxp.Svengali.Library"]))


def test_identically_staged_arms_are_refused(tmp_path, golden):
    """Two launches staged the same way are not a differential, whatever else they agree on."""
    assert_kill(tmp_path, "the control_staged_identifiers difference clause",
                ('if evidence.get("control_staged_identifiers") == staged:',),
                ev(golden, control_staged_identifiers=list(
                    golden["evidence"]["staged_identifiers"])))


def test_identical_search_path_blocks_are_refused(tmp_path, golden):
    """The clause that catches a staging difference that never reached the engine."""
    same = list(golden["evidence"]["closure_search_path_names"])
    assert_kill(tmp_path, "the search-path block difference clause",
                ('if evidence.get("closure_search_path_names") == evidence.get('
                 '"control_search_path_names"):',),
                ev(golden, control_search_path_names=same))


def test_a_dump_with_no_evidence_block_is_refused(tmp_path, golden):
    """World state alone proves the game ran; it cannot prove which expansions loaded."""
    dump = copy.deepcopy(golden)
    dump.pop("evidence")
    result = run_checker(tmp_path, dump)
    assert result.returncode == 1
    assert "no evidence block" in (result.stdout + result.stderr)


def test_a_dump_from_another_scenario_is_refused(tmp_path, golden):
    assert_kill(tmp_path, "the scenario-identity clause",
                ('if evidence.get("scenario") != SCENARIO:',),
                ev(golden, scenario="012-retro-missions"))


def test_a_missing_field_is_refused_as_MISSING_not_judged_as_false(tmp_path, golden):
    """A MISSING field and a FALSE field are different failures and must read differently.

    `evidence.get(...) is False` cannot see a field that is absent, so the presence sweep is a
    separate clause; without it a future dump-format change would silently drop a defence and the
    checker would report nothing at all.
    """
    dump = copy.deepcopy(golden)
    dump["evidence"].pop("primary_in_search_paths")
    baseline = run_checker(tmp_path, dump)
    assert baseline.returncode == 1, "a dump missing a judged field was ACCEPTED:\n%s%s" % (
        baseline.stdout, baseline.stderr)
    assert "is MISSING" in (baseline.stdout + baseline.stderr)
    mutated = run_checker(tmp_path, dump,
                          checker=mutated_checker(tmp_path, ("if key not in evidence:",)))
    assert mutated.returncode == 0, (
        "MISKILL: weakening the presence sweep did not make the checker accept a dump that is "
        "missing a judged field.\n%s%s" % (mutated.stdout, mutated.stderr))


# ============================================================================================
# ARTIFACT-LEVEL: the witness that lives OUTSIDE the file it defends (bead oo-gxp)
# ============================================================================================

def test_provenance_witnesses_the_golden_byte_for_byte():
    """A golden cannot witness itself: a one-quantised-unit edit moves BOTH sides of any
    golden-vs-copy comparison, and only a digest recorded in a SEPARATE file can see it."""
    import hashlib
    with open(_first(PROVENANCE_CANDIDATES, "provenance.json"), "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    blob = open(golden_path(), "rb").read()
    rec = (prov.get("artifacts") or {}).get("state.json")
    assert rec, "provenance records no artifacts.state.json digest"
    assert len(blob) == rec["bytes"], (
        "state.json is %d bytes but provenance witnesses %d" % (len(blob), rec["bytes"]))
    assert hashlib.sha256(blob).hexdigest() == rec["sha256"], (
        "state.json hashes to %s but provenance witnesses %s; ONE quantised unit on one float "
        "does this and a golden-vs-copy comparison cannot see it"
        % (hashlib.sha256(blob).hexdigest(), rec["sha256"]))


def test_an_all_zero_grid_is_refused_for_its_luminance_not_its_size(tmp_path):
    """The liveness floor must fail an UNDRAWN frame, not merely a wrong-sized file."""
    grid = tmp_path / "zero.grid"
    grid.write_bytes(bytes(4096))
    result = subprocess.run([sys.executable, HARNESS, "--check-frame", str(grid)],
                            cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 1, "an all-zero 4096-byte grid was not REFUSED:\n%s%s" % (
        result.stdout, result.stderr)
    assert "below the liveness floor" in (result.stdout + result.stderr), (
        "the all-zero grid was refused for the wrong reason; it must fail because the frame is "
        "UNIFORM, not because the file is the wrong size:\n%s%s" % (result.stdout, result.stderr))


def test_a_wrong_sized_grid_is_refused_with_rc2_not_a_verdict(tmp_path):
    """rc=2 means 'I cannot tell you'; it must never be confused with a liveness verdict."""
    grid = tmp_path / "short.grid"
    grid.write_bytes(bytes(100))
    result = subprocess.run([sys.executable, HARNESS, "--check-frame", str(grid)],
                            cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 2, "a 100-byte grid did not produce rc=2:\n%s%s" % (
        result.stdout, result.stderr)
