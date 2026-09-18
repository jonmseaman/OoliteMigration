"""CHECKER-WEAKENING mutants for scenario 015's evidence checker (bead oo-xy0o).

WHY THIS MODULE EXISTS, AND WHY IT IS SEPARATE FROM test_trumbles_load.py
------------------------------------------------------------------------
test_trumbles_load.py mutates the DATA: it corrupts state.json and asserts the checker says NO.
That proves the checker WORKS TODAY. It cannot prove the checker CANNOT BE SILENTLY WEAKENED
TOMORROW, because nothing in it mutates the checker's own text - and a reviewer measured exactly
that hole on the sibling scenarios: six clauses of check_trade_cycle_evidence.py could each be
replaced with `if False:` and the suite still reported "47 passed".

So every arm here does the complementary thing (the pattern bead oo-ghhw landed in
test_cloaking_load.py, copied deliberately):

  1. run the UNMUTATED checker on an input that the clause exists to reject - it must REFUSE
     (rc=1). Without this the mutant below registers a false kill against an already-red checker
     (bead oo-4vdc);
  2. copy the checker to a THROWAWAY dir, replace exactly ONE clause with `if False:`, and run it
     on the SAME input - it must now ACCEPT (rc=0).

Step 2 is what proves the kill belongs to THAT clause and not to a neighbour. Where a clause turns
out to be redundantly defended, this file says so in a MISKILL arm rather than banking a kill that
never happened - a miskill recorded honestly is worth more than a fake one.

NOTHING IN THE REPO IS EVER WRITTEN TO. The checker is READ and mutated into a temp tree, because
restore-on-exit does not run when a worker is killed at its timeout and the orchestrator can
harvest-and-commit a worktree at any instant - which is how bead oo-dto committed `if False:` in
place of the one predicate its scenario was named for.

THE INPUTS ARE RESHAPED, NOT WEAKENED. Several arms feed a bad dump whose OTHER fields have been
kept self-consistent (e.g. a shrunken census whose agreement count shrank with it). That is not
making the test easier: it is the only way to isolate one clause when a neighbour would otherwise
fire first, and it is also what a real regression looks like - a maintainer's edit is consistent
with itself.
"""

import copy
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "015-trumbles"

CHECKER = os.path.join(HERE, "check_trumbles_evidence.py")
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)


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


def write_dump(tmp_path, dump, name="dump.json"):
    path = tmp_path / name
    path.write_text(json.dumps(dump, sort_keys=True), encoding="utf-8")
    return str(path)


def run_checker(dump_path, checker=CHECKER):
    return subprocess.run([sys.executable, checker, dump_path, "--label", "mutant"],
                          capture_output=True, text=True)


def mutated_checker(tmp_path, clauses):
    """A THROWAWAY copy of the checker with each named clause replaced by `if False:`.

    Replacing the CONDITION (not deleting the block) keeps the body syntactically valid, so the
    only difference between the two runs is whether that one guard can fire.
    """
    with open(CHECKER, "r", encoding="utf-8") as handle:
        src = handle.read()
    for clause in clauses:
        count = src.count(clause)
        assert count == 1, (
            "the clause %r matches the checker %d time(s), not once: the checker was refactored "
            "and this mutant is stale. A stale mutant silently stops testing anything."
            % (clause, count))
        src = src.replace(clause, "if False:")
    target = tmp_path / "mutated_check_trumbles_evidence.py"
    target.write_text(src, encoding="utf-8", newline="\n")
    return str(target)


def assert_kill(tmp_path, golden, clause_name, clauses, bad):
    """The two-sided assertion. BOTH halves are required (see the module docstring)."""
    path = write_dump(tmp_path, bad)
    baseline = run_checker(path)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject. rc=2 is "
        "a structural error rather than a verdict, and the mutant below would then register a "
        "false kill against an already-red checker (bead oo-4vdc).\n%s%s"
        % (clause_name, baseline.stdout, baseline.stderr))

    mutated = run_checker(path, checker=mutated_checker(tmp_path, clauses))
    assert mutated.returncode == 0, (
        "MISKILL: weakening %s did NOT make the checker accept the input it exists to reject, so "
        "that clause is not what rejects it. Either the mutant is EQUIVALENT or the property has "
        "a second, unpinned defence (bead oo-jor's third cause for a survivor). Investigate "
        "before trusting the kill.\n%s%s" % (clause_name, mutated.stdout, mutated.stderr))


def ev(golden, **changes):
    dump = copy.deepcopy(golden)
    dump["evidence"].update(changes)
    return dump


# ============================================================================================
# BASELINE - every arm below is meaningless without this
# ============================================================================================

def test_the_blessed_golden_passes_its_own_checker():
    result = run_checker(golden_path())
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path):
    """The copy machinery itself must not change the verdict, or every arm below would be
    measuring the copy rather than the mutation."""
    unmutated = mutated_checker(tmp_path, ())
    assert run_checker(golden_path(), checker=unmutated).returncode == 0


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    """The mutation harness must refuse a clause that no longer exists. A mutant that silently
    matches nothing is a test that passes while testing nothing (bead oo-jor's instrument
    defect)."""
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if this_clause_was_deleted_by_a_refactor:",))
    assert "stale" in str(exc.value)


# ============================================================================================
# CHECKER MUTANTS - one clause each, all MEASURED as kills
# ============================================================================================

def test_the_saved_trumble_count_clause_is_load_bearing(tmp_path, golden):
    """The population the save's own anti-cheat checksum authorises. With this clause gone a dump
    claiming SEVEN saved trumbles - a count this fixture's checksum does not authorise - passes."""
    assert_kill(tmp_path, golden, "the saved_trumble_count clause",
                ('if ev.get("saved_trumble_count") != EXPECTED_SAVED_TRUMBLE_COUNT:',),
                ev(golden, saved_trumble_count=7))


def test_the_saved_checksum_clause_is_load_bearing(tmp_path, golden):
    """A different checksum means a DIFFERENT SAVE FILE, which is the substitution this whole
    scenario would otherwise not notice."""
    assert_kill(tmp_path, golden, "the saved_trumble_checksum clause",
                ('if ev.get("saved_trumble_checksum") != EXPECTED_TRUMBLE_CHECKSUM:',),
                ev(golden, saved_trumble_checksum=1))


def test_the_mission_variable_key_set_clause_is_load_bearing(tmp_path, golden):
    """THE INPUT IS RESHAPED ON PURPOSE. An EMPTY key set is also caught by the named-key clause
    below it ("missionVariables carries no 'trumbles' key"), so an empty set cannot isolate this
    one - measured, it is a MISKILL. A key set from ANOTHER SAVE that still contains `trumbles`
    keeps the named-key clause satisfied, so only the exact-set clause can fire: the failure mode
    is a run that loaded the wrong save, which is precisely what an exact set exists to catch."""
    assert_kill(tmp_path, golden, "the mission-variable exact-key-set clause",
                ("if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",),
                ev(golden, mission_variable_keys=["trumbles", "novacount", "conhunt"]))


def test_the_save_format_version_clause_is_load_bearing(tmp_path, golden):
    """The 1.75-era compatibility contract: a fixture silently replaced by a modern save makes
    every other clause pass while the 1.75 deserialisation path goes untested."""
    assert_kill(tmp_path, golden, "the save_written_by_version clause",
                ('if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:',),
                ev(golden, save_written_by_version="1.90"))


def test_the_census_size_clause_is_load_bearing(tmp_path, golden):
    """A SHRINKING CENSUS is the empty-state vacuity route wearing a smaller hat. The agreement
    count is shrunk WITH it, because a census of 2 fields where 11 agree trips the agreement
    clause first (measured: MISKILL) and says nothing about the size clause. Two fields that agree
    with each other is exactly the consistent-looking artifact a maintainer would produce."""
    assert_kill(tmp_path, golden, "the census_fields size clause",
                ('if ev.get("census_fields") != EXPECTED_CENSUS_FIELDS:',),
                ev(golden, census_fields=2, round_trip_fields_equal=2))


def test_the_census_agreement_clause_is_load_bearing(tmp_path, golden):
    """The other half of the census pair: the right NUMBER of fields, but they disagreed."""
    assert_kill(tmp_path, golden, "the round_trip_fields_equal clause",
                ('if ev.get("round_trip_fields_equal") != ev.get("census_fields"):',),
                ev(golden, round_trip_fields_equal=3))


def test_the_deterministic_award_prefix_clause_is_load_bearing(tmp_path, golden):
    """PLAYER_MAX_TRUMBLES/6 = 4 is the MEASURED deterministic prefix; the fifth award onwards is
    a RANROT draw that differs between runs at the same seed. With this clause gone a golden
    pinned at SIX awards - a flaky number - is accepted, which trades a real property for a
    golden that fails on a slow box."""
    assert_kill(tmp_path, golden, "the deterministic-award-prefix clause",
                ("if awards != DETERMINISTIC_AWARD_PREFIX:",),
                ev(golden, trumble_awards=6, trumble_award_series=[1, 2, 3, 4, 5, 6],
                   trumble_count=6, trumble_count_before_ticks=6))


def test_the_award_series_identity_clause_is_load_bearing(tmp_path, golden):
    """Each award inside the deterministic prefix adds EXACTLY ONE trumble, so the series must be
    [1..N]. The mutant series [1, 1, 2, 4] keeps the LENGTH and the LAST ELEMENT, because the two
    neighbouring consistency clauses (count == len(series), count == series[-1]) both fire on a
    series that changes either - measured, [2,3,4,5] is a MISKILL. What survives is a population
    that did not grow one at a time, i.e. the award gate's thresholds changed."""
    assert_kill(tmp_path, golden, "the award-series identity clause",
                ("if series != list(range(1, awards + 1)):",),
                ev(golden, trumble_award_series=[1, 1, 2, 4]))


def test_the_population_stability_clause_is_load_bearing(tmp_path, golden):
    """Breeding needs trumbleAppetiteAccumulator > 10.0 from eating cargo pods and a docked player
    has none, so a population that MOVED across the tick budget is a FINDING about the engine -
    and with this clause gone the golden becomes a stopwatch reading instead of a fixed point."""
    assert_kill(tmp_path, golden, "the trumble_count_before_ticks stability clause",
                ('if ev.get("trumble_count_before_ticks") != ev.get("trumble_count"):',),
                ev(golden, trumble_count_before_ticks=9))


def test_the_anticheat_message_clause_is_load_bearing(tmp_path, golden):
    """"POSSIBLE CHEAT DETECTED" is the engine restoring a population the file did not authorise.
    An empty list is meaningful ONLY because the log channels were on; with the clause gone the
    dump can carry the engine's own confession and still pass."""
    assert_kill(tmp_path, golden, "the cheat_messages clause",
                ('if ev.get("cheat_messages"):',),
                ev(golden, cheat_messages=["POSSIBLE CHEAT DETECTED - trumbles"]))


def test_the_load_failure_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, golden, "the load_failures clause",
                ('if ev.get("load_failures"):',),
                ev(golden, load_failures=["[load.failed] could not read commander data"]))


def test_the_market_floor_clause_is_load_bearing(tmp_path, golden):
    """A dump whose market is empty compares equal to any other empty market."""
    bad = copy.deepcopy(golden)
    bad["market"] = {}
    assert_kill(tmp_path, golden, "the market floor clause",
                ("if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:",), bad)


def test_the_entity_floor_clause_is_load_bearing(tmp_path, golden):
    bad = copy.deepcopy(golden)
    bad["entities"] = []
    assert_kill(tmp_path, golden, "the entity floor clause",
                ("if not isinstance(entities, list) or len(entities) < MIN_ENTITIES:",), bad)


# ============================================================================================
# THE MISKILLS, RECORDED RATHER THAN HIDDEN
# ============================================================================================

def test_the_named_trumbles_key_clause_redundantly_defends_the_empty_key_set(tmp_path, golden):
    """MEASURED MISKILL, kept as a test so the redundancy is PINNED rather than assumed.

    An empty mission-variable key set is rejected by TWO clauses: the exact-set comparison and the
    dedicated `trumbles`-by-name clause. Deleting the exact-set clause alone therefore does NOT
    let an empty set through - which is the correct outcome for a critical property, and exactly
    the deliberate redundancy check_trumbles_evidence.py documents at the `trumbles` key.

    This arm asserts the redundancy REALLY HOLDS. If a future refactor made the named-key clause
    conditional, this test goes red and tells the maintainer the empty-set defence just became a
    single line - the failure mode bead oo-jor measured.
    """
    path = write_dump(tmp_path, ev(golden, mission_variable_keys=[]))
    weakened = run_checker(path, checker=mutated_checker(
        tmp_path, ("if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",)))
    assert weakened.returncode == 1, (
        "the empty-key-set property is now held by the exact-set clause ALONE: with it removed a "
        "dump carrying NO mission variables - a fresh commander's state - was ACCEPTED. Restore a "
        "second defence.\n%s%s" % (weakened.stdout, weakened.stderr))
    assert "trumbles" in weakened.stderr

    both = run_checker(path, checker=mutated_checker(tmp_path, (
        "if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",
        "if MISSION_TRUMBLES_KEY not in keys:")))
    assert both.returncode == 0, (
        "with BOTH mission-variable clauses removed the fresh-commander dump was still rejected, "
        "so something else is doing the work and neither clause is pinned by this pair.\n%s%s"
        % (both.stdout, both.stderr))
