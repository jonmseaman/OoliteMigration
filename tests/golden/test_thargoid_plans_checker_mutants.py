"""CHECKER-WEAKENING mutants for scenario 017's evidence checker (bead oo-xy0o).

WHAT WAS FOUND, AND WHY THIS MODULE EXISTS
------------------------------------------
Bead oo-xy0o's scope named scenarios 004, 014 and 015. Surveying the two SIBLINGS the bead asked
about turned up a real gap: of the 23 `if` clauses in check_thargoid_plans_evidence.py, exactly
THREE are named by test_thargoid_plans_load.py - and all three are the load-stage clauses. Every
other defence in that checker (the mission-variable map, the thargplans absence, the mission
preconditions, the 1.75 migration testimony, the census, the world floors) could be replaced with
`if False:` and nothing in the suite would notice. That is the same hole the reviewer measured on
scenario 004, on a checker that has ALREADY LANDED.

(The other sibling, check_cloaking_evidence.py, already carries four checker mutants from bead
oo-ghhw. Eleven more of its clauses were measured as individually load-bearing and are pinned in
test_cloaking_checker_mutants.py, not here.)

Each arm is bead oo-ghhw's two-sided pattern:

  1. the UNMUTATED checker must REFUSE (rc=1) the input the clause exists to reject - otherwise
     the mutant registers a false kill against an already-red checker (bead oo-4vdc);
  2. a THROWAWAY copy with exactly ONE clause weakened must now ACCEPT it (rc=0).

THREE ARMS ALSO WIDEN AN EXPECTED CONSTANT. That is not making the test easier: where a broad map
comparison sits above a dedicated clause, the map fires first and the dedicated clause can never
be isolated by data alone (measured: MISKILL). Widening the map is exactly what a FIXTURE CHANGE
that legitimises the new value looks like, and it is the case that matters - a maintainer who
re-blesses the map must not thereby disarm the dedicated assertion underneath it. Each such arm
says which constant it widened and why.

Nothing in the repo is written to; sources are read and mutated into pytest's tmp_path.
"""

import copy
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "017-thargoid-plans"

CHECKER = os.path.join(HERE, "check_thargoid_plans_evidence.py")
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)

# Constants the checker declares as literal lines. Widening one is how a re-blessed fixture looks.
SCORE_LINE = '    "score_over_1280": True,'
TRUMBLES_LINE = '    "trumbles": "NOT_NOW",'


def golden_path():
    for path in GOLDEN_CANDIDATES:
        if os.path.isfile(path):
            return path
    raise AssertionError("no blessed state.json for %s; searched %r"
                         % (SCENARIO, GOLDEN_CANDIDATES))


@pytest.fixture(scope="module")
def golden():
    with open(golden_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def run_checker(tmp_path, dump, checker=CHECKER, name="dump.json"):
    path = tmp_path / name
    path.write_text(json.dumps(dump, sort_keys=True), encoding="utf-8")
    return subprocess.run([sys.executable, checker, str(path), "--label", "mutant"],
                          capture_output=True, text=True)


def mutated_checker(tmp_path, clauses, widen=None, name="mutated_checker.py"):
    with open(CHECKER, "r", encoding="utf-8") as handle:
        src = handle.read()
    if widen is not None:
        old, new = widen
        assert src.count(old) == 1, (
            "the constant line %r is no longer unique in the checker; this fixture-widening "
            "mutant is stale" % old)
        src = src.replace(old, new)
    for clause in clauses:
        count = src.count(clause)
        assert count == 1, (
            "the clause %r matches the checker %d time(s), not once: it was refactored and this "
            "mutant is stale. A stale mutant silently stops testing anything." % (clause, count))
        src = src.replace(clause, "if False:")
    target = tmp_path / name
    target.write_text(src, encoding="utf-8", newline="\n")
    return str(target)


def assert_kill(tmp_path, clause_name, clauses, bad, widen=None):
    baseline_checker = (mutated_checker(tmp_path, (), widen=widen, name="widened_baseline.py")
                        if widen else CHECKER)
    baseline = run_checker(tmp_path, bad, checker=baseline_checker)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject; rc=2 is "
        "a structural error rather than a verdict and the mutant below would register a false "
        "kill (bead oo-4vdc).\n%s%s" % (clause_name, baseline.stdout, baseline.stderr))
    mutated = run_checker(tmp_path, bad,
                          checker=mutated_checker(tmp_path, clauses, widen=widen))
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
                            capture_output=True, text=True)
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path, golden):
    assert run_checker(tmp_path, golden, checker=mutated_checker(tmp_path, ())).returncode == 0


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if a_refactor_deleted_this:",))
    assert "stale" in str(exc.value)


# ============================================================================================
# CHECKER MUTANTS - every one MEASURED as a kill
# ============================================================================================

def test_the_mission_variable_map_clause_is_load_bearing(tmp_path, golden):
    """THE INPUT IS RESHAPED. An EMPTY map is also caught by the dedicated conhunt clause below
    it (measured: MISKILL), so it cannot isolate the map. Changing ONE value while leaving conhunt
    correct and thargplans absent leaves only the map comparison to fire - and a single changed
    value is exactly what a run that loaded a save from a different point in the campaign
    produces. Compared as a KEY->VALUE MAP, not a key set, because every value in THIS fixture is
    a non-empty string."""
    mv = dict(golden["evidence"]["mission_variables"])
    mv["trumbles"] = "OK_LETS_GO"
    assert_kill(tmp_path, "the mission-variable map clause",
                ("if not isinstance(mv, dict) or mv != EXPECTED_MISSION_VARIABLES:",),
                ev(golden, mission_variables=mv))


def test_the_thargplans_absence_clause_is_load_bearing(tmp_path, golden):
    """THE VARIABLE THE BEAD IS NAMED FOR, and it is ABSENT from this fixture by construction:
    the save sits BEFORE the mission starts. A dump that acquired the key is caught by the map
    comparison first, so this arm ALSO widens EXPECTED_MISSION_VARIABLES to legitimise it - the
    fixture-change case - and then requires the dedicated clause to be what rejects it."""
    mv = dict(golden["evidence"]["mission_variables"])
    mv["thargplans"] = "PRELUDE"
    assert_kill(tmp_path, "the thargplans-absence clause", ("if THARGPLANS_KEY in mv:",),
                ev(golden, mission_variables=mv),
                widen=(TRUMBLES_LINE, TRUMBLES_LINE + '\n    "thargplans": "PRELUDE",'))


def test_the_thargplans_present_flag_clause_is_load_bearing(tmp_path, golden):
    """The second witness of the same property, reported by the harness rather than read out of
    the map: if the live game says the variable IS set, the save is not where this scenario
    claims."""
    assert_kill(tmp_path, "the thargplans_present clause",
                ('if ev.get("thargplans_present") is not False:',),
                ev(golden, thargplans_present=True))


def test_the_precondition_map_clause_is_load_bearing(tmp_path, golden):
    """oolite-thargoid-plans-mission.js:77-90, MEASURED live - AND THE FALSE CLAUSE IS PART OF THE
    CLAIM. An all-true precondition map is what a harness that fabricated the probe would emit."""
    all_true = {k: True for k in golden["evidence"]["thargplans_preconditions"]}
    assert_kill(tmp_path, "the precondition map clause",
                ("if not isinstance(pre, dict) or pre != EXPECTED_PRECONDITIONS:",),
                ev(golden, thargplans_preconditions=all_true))


def test_the_score_precondition_clause_is_load_bearing(tmp_path, golden):
    """The dedicated clause on the ONE precondition a save from earlier in the campaign would
    fail. Isolated by widening EXPECTED_PRECONDITIONS to accept a False score - i.e. a maintainer
    re-blessing the measured map - after which only this clause stands between the scenario and a
    fixture that never reached the kill threshold."""
    pre = dict(golden["evidence"]["thargplans_preconditions"])
    pre["score_over_1280"] = False
    assert_kill(tmp_path, "the score_over_1280 clause",
                ('if pre.get("score_over_1280") is not True:',),
                ev(golden, thargplans_preconditions=pre),
                widen=(SCORE_LINE, '    "score_over_1280": False,'))


def test_the_save_format_version_clause_is_load_bearing(tmp_path, golden):
    """The 1.75-era compatibility contract: a fixture silently replaced by a modern save makes
    every other clause pass while the 1.75 deserialisation path goes untested."""
    assert_kill(tmp_path, "the save_written_by_version clause",
                ('if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:',),
                ev(golden, save_written_by_version="1.90"))


def test_the_migration_testimony_clause_is_load_bearing(tmp_path, golden):
    """THE ENGINE'S OWN RECORD of the 1.75 energy-bomb migration (PlayerEntity.m:1731-1746).
    Without the log line the credit delta is arithmetic that happens to add up."""
    assert_kill(tmp_path, "the load_upgrade_messages clause",
                ("if upgrades != list(EXPECTED_UPGRADE_MESSAGES):",),
                ev(golden, load_upgrade_messages=[]))


def test_the_migrated_census_field_clause_is_load_bearing(tmp_path, golden):
    """THE CLOSED PAIR on the migration: exactly `credits` may differ between file and engine. A
    census migrated on a field NOBODY DECLARED is a loader change wearing a migration's clothes."""
    assert_kill(tmp_path, "the census_fields_migrated clause",
                ("if migrated != sorted(EXPECTED_MIGRATED_CENSUS_FIELDS):",),
                ev(golden, census_fields_migrated=["fuel"]))


def test_the_census_size_clause_is_load_bearing(tmp_path, golden):
    """A shrinking census is the empty-state vacuity route wearing a smaller hat. The agreement
    count moves WITH it, because a census of 2 where 9 agree trips the agreement clause first."""
    assert_kill(tmp_path, "the census_fields size clause",
                ('if ev.get("census_fields") != EXPECTED_CENSUS_FIELDS:',),
                ev(golden, census_fields=2, round_trip_fields_equal=2))


def test_the_census_agreement_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the round_trip_fields_equal clause",
                ('if ev.get("round_trip_fields_equal") != ev.get("census_fields"):',),
                ev(golden, round_trip_fields_equal=3))


def test_the_required_true_loop_is_load_bearing(tmp_path, golden):
    """The loop that requires every REQUIRED_TRUE flag - here driven with round_trip_ok=False,
    i.e. the save file and the loaded game disagreed and the run said so."""
    assert_kill(tmp_path, "the REQUIRED_TRUE loop", ("if ev.get(field) is not True:",),
                ev(golden, round_trip_ok=False))


def test_the_required_positive_loop_is_load_bearing(tmp_path, golden):
    """A dump claiming a ZERO-BYTE save file is a run that read nothing."""
    assert_kill(tmp_path, "the REQUIRED_POSITIVE loop",
                ("if not isinstance(value, int) or value < 1:",), ev(golden, save_bytes=0))


def test_the_load_failure_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the load_failures clause", ('if ev.get("load_failures"):',),
                ev(golden, load_failures=["[load.failed] could not read commander data"]))


def test_the_market_floor_clause_is_load_bearing(tmp_path, golden):
    """A dump whose market is empty compares equal to any other empty market."""
    bad = copy.deepcopy(golden)
    bad["market"] = {}
    assert_kill(tmp_path, "the market floor clause",
                ("if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:",), bad)


def test_the_entity_floor_clause_is_load_bearing(tmp_path, golden):
    bad = copy.deepcopy(golden)
    bad["entities"] = []
    assert_kill(tmp_path, "the entity floor clause",
                ("if not isinstance(entities, list) or len(entities) < MIN_ENTITIES:",), bad)


# ============================================================================================
# THE MISKILLS, RECORDED RATHER THAN HIDDEN
# ============================================================================================

def test_the_conhunt_clause_redundantly_defends_an_empty_mission_variable_map(tmp_path, golden):
    """MEASURED MISKILL, kept so the redundancy is PINNED rather than assumed.

    An EMPTY mission-variable map - a fresh commander's state - is rejected by TWO clauses: the
    map comparison and the dedicated `conhunt == MISSION_COMPLETE` clause. Deleting the map
    comparison alone does not let it through, so no kill is claimed for it with that input; the
    arm above isolates the map with a different one. What this asserts is that the redundancy is
    REAL - if a refactor made the conhunt clause conditional, the fresh-commander defence would
    silently become a single line and this test goes red.
    """
    bad = ev(golden, mission_variables={})
    weakened = run_checker(tmp_path, bad, checker=mutated_checker(
        tmp_path, ("if not isinstance(mv, dict) or mv != EXPECTED_MISSION_VARIABLES:",)))
    assert weakened.returncode == 1, (
        "the empty-map property is now held by the map comparison ALONE: with it removed a dump "
        "carrying NO mission variables was ACCEPTED. Restore a second defence.\n%s%s"
        % (weakened.stdout, weakened.stderr))
    assert "conhunt" in weakened.stderr

    both = run_checker(tmp_path, bad, checker=mutated_checker(tmp_path, (
        "if not isinstance(mv, dict) or mv != EXPECTED_MISSION_VARIABLES:",
        'if mv.get("conhunt") != "MISSION_COMPLETE":'), name="both.py"))
    assert both.returncode == 0, (
        "with BOTH mission-variable clauses removed the fresh-commander dump was still rejected, "
        "so neither clause is pinned by this pair.\n%s%s" % (both.stdout, both.stderr))
