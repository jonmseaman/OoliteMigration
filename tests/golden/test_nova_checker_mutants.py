"""CHECKER-WEAKENING mutants for scenario 014's evidence checker (bead oo-xy0o).

test_nova_load.py mutates the DATA and asserts the checker says NO, which proves the checker WORKS
TODAY. It also carries a small per-defence arm (`test_each_defence_alone_rejects`) which asserts
the OPPOSITE thing: that deleting one clause leaves the property still defended. Both are useful
and neither answers the question this module exists for - CAN A CLAUSE BE DELETED WITHOUT ANYTHING
GOING RED? A reviewer measured that on the sibling scenarios it can: six clauses of
check_trade_cycle_evidence.py each replaced by `if False:` still gave "47 passed".

So every arm here follows bead oo-ghhw's pattern (tests/golden/test_cloaking_load.py):

  1. the UNMUTATED checker must REFUSE (rc=1) the input the clause exists to reject - otherwise
     the mutant registers a false kill against an already-red checker (bead oo-4vdc);
  2. a THROWAWAY copy with exactly ONE clause replaced by `if False:` must now ACCEPT it (rc=0),
     which is what proves the kill belongs to THAT clause and not to a neighbour.

Where a clause is redundantly defended, this file records the MISKILL rather than banking a kill
that never happened. Nothing in the repo is written to: the checker is read and mutated into
pytest's tmp_path, because restore-on-exit does not run when a worker is killed at its timeout.
"""

import copy
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "014-nova"

CHECKER = os.path.join(HERE, "check_nova_evidence.py")
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)

# The line the checker declares its expected mission-variable key set on. Widening it is how a
# FIXTURE CHANGE that legitimises a new key would look, and it is the only way to isolate the
# dedicated `nova`-absence clause (see the arm that uses it).
KEY_SET_LINE = '    "TL_FOR_EQ_NAVAL_ENERGY_UNIT", "conhunt", "novacount", "thargplans", "trumbles",'


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


def mutated_checker(tmp_path, clauses, widen_key_set=False, name="mutated_check_nova.py"):
    with open(CHECKER, "r", encoding="utf-8") as handle:
        src = handle.read()
    if widen_key_set:
        assert src.count(KEY_SET_LINE) == 1, (
            "the expected mission-variable key set is no longer a single literal line; this "
            "fixture-widening mutant is stale")
        src = src.replace(KEY_SET_LINE, KEY_SET_LINE + '\n    "nova",')
    for clause in clauses:
        count = src.count(clause)
        assert count == 1, (
            "the clause %r matches the checker %d time(s), not once: the checker was refactored "
            "and this mutant is stale. A stale mutant silently stops testing anything."
            % (clause, count))
        src = src.replace(clause, "if False:")
    target = tmp_path / name
    target.write_text(src, encoding="utf-8", newline="\n")
    return str(target)


def assert_kill(tmp_path, clause_name, clauses, bad, widen_key_set=False):
    path = write_dump(tmp_path, bad)
    baseline_checker = (mutated_checker(tmp_path, (), widen_key_set=True, name="widened.py")
                        if widen_key_set else CHECKER)
    baseline = run_checker(path, checker=baseline_checker)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject; rc=2 is "
        "a structural error rather than a verdict and the mutant below would register a false "
        "kill (bead oo-4vdc).\n%s%s" % (clause_name, baseline.stdout, baseline.stderr))
    mutated = run_checker(path, checker=mutated_checker(tmp_path, clauses,
                                                        widen_key_set=widen_key_set))
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
    result = run_checker(golden_path())
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path):
    assert run_checker(golden_path(), checker=mutated_checker(tmp_path, ())).returncode == 0


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if a_refactor_deleted_this:",))
    assert "stale" in str(exc.value)


# ============================================================================================
# CHECKER MUTANTS - one clause each, every one MEASURED as a kill
# ============================================================================================

def test_the_novacount_by_value_clause_is_load_bearing(tmp_path, golden):
    """This fixture's `novacount` is the NON-EMPTY string '3', so unlike scenario 015's
    mission_trumbles it can be checked BY VALUE. An empty value reads identically to an absent
    mission variable, which is exactly the state a run that ignored -load is in."""
    assert_kill(tmp_path, "the novacount by-VALUE clause",
                ('if ev.get("mission_novacount_value") != EXPECTED_MISSION_NOVACOUNT_VALUE:',),
                ev(golden, mission_novacount_value=""))


def test_the_mission_variable_key_set_clause_is_load_bearing(tmp_path, golden):
    """THE INPUT IS RESHAPED. An EMPTY key set is also caught by the named-`novacount` clause
    below it (measured: MISKILL), so it cannot isolate this one. A key set from a DIFFERENT SAVE
    that still contains `novacount` satisfies the named-key clause, leaving only the exact-set
    comparison to reject a run that loaded the wrong file."""
    assert_kill(tmp_path, "the mission-variable exact-key-set clause",
                ("if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",),
                ev(golden, mission_variable_keys=["novacount", "trumbles"]))


def test_the_mission_nova_absence_clause_is_load_bearing(tmp_path, golden):
    """THE DEDICATED ABSENCE CLAUSE, ISOLATED BY WIDENING THE FIXTURE'S DECLARED KEY SET.

    A dump that acquired a `nova` key is caught by the exact-set comparison first (measured:
    MISKILL against the unmodified checker). That is correct but says nothing about the dedicated
    clause. So this arm ALSO widens the checker's EXPECTED key set to include `nova` - which is
    exactly what a future fixture change that legitimises the key would do - and then requires the
    dedicated clause to be what still rejects it. This is the case that matters: a maintainer who
    re-blesses the key set must not thereby disarm the assertion that THIS fixture sits BEFORE the
    nova mission ran.
    """
    bad = ev(golden, mission_variable_keys=sorted(
        set(golden["evidence"]["mission_variable_keys"]) | {"nova"}))
    assert_kill(tmp_path, "the mission_nova absence clause", ("if MISSION_NOVA_KEY in keys:",),
                bad, widen_key_set=True)


def test_the_pre_1_75_save_version_clause_is_load_bearing(tmp_path, golden):
    """The EMPTY expectation is not an oversight: every 1.75 save writes written_by_version and
    this fixture has no such key, so it pins a STRICTLY OLDER contract. With the clause gone, a
    fixture swapped for a NEWER file - the easy mistake - passes."""
    assert_kill(tmp_path, "the save_written_by_version clause",
                ('if ev.get("save_written_by_version") != EXPECTED_SAVE_VERSION:',),
                ev(golden, save_written_by_version="1.75"))


def test_the_legacy_keys_present_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the save_format_keys_present clause",
                ('if list(ev.get("save_format_keys_present") or []) != '
                 'sorted(EXPECTED_SAVE_FORMAT_KEYS_PRESENT):',),
                ev(golden, save_format_keys_present=[]))


def test_the_modern_keys_absent_clause_is_load_bearing(tmp_path, golden):
    """The other half of the format contract: the keys a 1.75-era save carries and this older one
    does not. Checking only what is PRESENT would accept a file that grew modern keys."""
    assert_kill(tmp_path, "the save_format_keys_absent clause",
                ('if list(ev.get("save_format_keys_absent") or []) != '
                 'sorted(EXPECTED_SAVE_FORMAT_KEYS_ABSENT):',),
                ev(golden, save_format_keys_absent=[]))


def test_the_legacy_upgrade_testimony_clause_is_load_bearing(tmp_path, golden):
    """THE ENGINE'S OWN WITNESS of the energy-bomb migration. Without the [load.upgrade] line the
    +900 Cr is arithmetic that happens to add up - it could equally be a save whose credits were
    corrupted by exactly that amount."""
    assert_kill(tmp_path, "the legacy_upgrades testimony clause",
                ('if list(ev.get("legacy_upgrades") or []) != sorted(EXPECTED_LEGACY_UPGRADES):',),
                ev(golden, legacy_upgrades=[]))


def test_the_legacy_upgrade_clause_also_pins_the_OTHER_branch(tmp_path, golden):
    """PlayerEntity.m:1730-1746 has two outcomes: replace the bomb with a Quirium cascade mine
    (a free pylon) or fall through to credits += 9000. This fixture takes the SECOND, and the
    credits census field predicts its arithmetic - so the OTHER branch's log line must be rejected
    too, or the migration's amount could change without anything going red."""
    assert_kill(tmp_path, "the legacy_upgrades testimony clause (wrong branch)",
                ('if list(ev.get("legacy_upgrades") or []) != sorted(EXPECTED_LEGACY_UPGRADES):',),
                ev(golden, legacy_upgrades=[
                    "Replaced legacy energy bomb with Quirium cascade mine."]))


def test_the_galaxy_number_clause_is_load_bearing(tmp_path, golden):
    """A new commander starts in GALAXY 0; reaching galaxy 3 takes three galactic hyperdrive
    jumps, so galaxy 3 is state no default game is in."""
    assert_kill(tmp_path, "the galaxy_number clause",
                ('if ev.get("galaxy_number") != EXPECTED_GALAXY_NUMBER:',),
                ev(golden, galaxy_number=0))


def test_the_census_size_clause_is_load_bearing(tmp_path, golden):
    """A shrinking census is the empty-state vacuity route wearing a smaller hat. The agreement
    count moves WITH it, because a census of 2 where 9 agree trips the agreement clause first
    (measured: MISKILL) - and a self-consistent pair is what a real edit looks like."""
    assert_kill(tmp_path, "the census_fields size clause",
                ('if ev.get("census_fields") != EXPECTED_CENSUS_FIELDS:',),
                ev(golden, census_fields=2, round_trip_fields_equal=2))


def test_the_census_agreement_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the round_trip_fields_equal clause",
                ('if ev.get("round_trip_fields_equal") != ev.get("census_fields"):',),
                ev(golden, round_trip_fields_equal=3))


def test_the_census_non_vacuity_clause_is_load_bearing(tmp_path, golden):
    """A CENSUS OF ZEROS AND EMPTY STRINGS COMPARES EQUAL TO ANY OTHER EMPTY CENSUS, so the field
    COUNT alone is not enough and this clause is the only thing requiring the fields to carry
    values."""
    assert_kill(tmp_path, "the census_populated clause",
                ("if not isinstance(populated, int) or populated < EXPECTED_CENSUS_FIELDS // 2:",),
                ev(golden, census_populated=1))


def test_the_station_ai_silencing_clause_is_load_bearing(tmp_path, golden):
    """THE FOURTH TRAFFIC SOURCE. hasNPCTraffic gates the ordinary trader schedule; a rock
    hermit's rockHermitAI launches a miner on its own 20 s cycle and is untouched by it. Measured
    before the suppression existed: 10 runs, FOUR distinct dump digests. With this clause gone the
    dump is a race and the race is invisible."""
    assert_kill(tmp_path, "the station_ais_silenced clause",
                ('if not isinstance(silenced, list) or len(silenced) != ev.get("stations_quieted"):',),
                ev(golden, station_ais_silenced=[]))


def test_the_load_failure_clause_is_load_bearing(tmp_path, golden):
    assert_kill(tmp_path, "the load_failures clause", ('if ev.get("load_failures"):',),
                ev(golden, load_failures=["[load.failed] could not read commander data"]))


def test_the_market_floor_clause_is_load_bearing(tmp_path, golden):
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

def test_the_novacount_named_key_clause_redundantly_defends_the_empty_key_set(tmp_path, golden):
    """MEASURED MISKILL, kept so the redundancy is PINNED rather than assumed.

    An EMPTY mission-variable key set - a fresh commander's state - is rejected by TWO clauses:
    the exact-set comparison and the dedicated `novacount`-by-name clause. Deleting the first
    alone does not let it through, so no kill is reported for it here; the arm above isolates the
    exact-set clause with a DIFFERENT input instead. What this test asserts is that the redundancy
    is real: if a refactor made the named-key clause conditional, the fresh-commander defence
    would silently become a single line and this test would go red.
    """
    path = write_dump(tmp_path, ev(golden, mission_variable_keys=[]))
    weakened = run_checker(path, checker=mutated_checker(
        tmp_path, ("if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",)))
    assert weakened.returncode == 1, (
        "the empty-key-set property is now held by the exact-set clause ALONE: with it removed a "
        "dump carrying NO mission variables was ACCEPTED. Restore a second defence.\n%s%s"
        % (weakened.stdout, weakened.stderr))
    assert "novacount" in weakened.stderr

    both = run_checker(path, checker=mutated_checker(tmp_path, (
        "if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",
        "if MISSION_NOVACOUNT_KEY not in keys:"), name="both.py"))
    assert both.returncode == 0, (
        "with BOTH mission-variable key clauses removed the fresh-commander dump was still "
        "rejected, so neither clause is pinned by this pair.\n%s%s" % (both.stdout, both.stderr))
