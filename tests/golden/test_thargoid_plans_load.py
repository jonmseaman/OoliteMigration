"""Offline tests for scenario 017's harness and evidence checker. No game, no build.

WHAT THESE PIN
--------------
`thargoid_plans_load.py` and `check_thargoid_plans_evidence.py` are the two halves of this
scenario's anti-vacuity defence, and the failure mode they exist to prevent is a green run that
measured nothing: a game started WITHOUT `-load` still starts, answers every JS probe, exits 0 and
writes a clean log (bead oo-het caught seven expansions that way). Every test below is therefore
NEGATIVE - it feeds the checker a dump a DEAD OR WRONG run would produce and requires a rejection
that NAMES the field.

Bead oo-jor's rule applies: the data is protected, but a checker nobody validates is not. Where a
property has two independent defences in the checker, there is a test that removes one and proves
the other still rejects - and where removing one lets the bad input through, the test says so
rather than pretending otherwise.

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
SCENARIO = "017-thargoid-plans"

sys.path.insert(0, HERE)

import check_thargoid_plans_evidence as checker  # noqa: E402
import thargoid_plans_load as scenario  # noqa: E402

SAVE = os.path.join(REPO_ROOT, "upstream", "oolite-tests", "Checklist-files", "Missions",
                    "ThargoidPlans.oolite-save")
SIBLING_SAVE = os.path.join(REPO_ROOT, "upstream", "oolite-tests", "Checklist-files", "Missions",
                            "Trumbles.oolite-save")


def _first(*candidates):
    for c in candidates:
        if os.path.isfile(c):
            return c
    raise AssertionError("none of %r exists" % (candidates,))


def golden_path():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
                  os.path.join(HERE, "pending", SCENARIO, "state.json"))


def provenance_path():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
                  os.path.join(HERE, "pending", SCENARIO, "provenance.json"))


def frame_path():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
                  os.path.join(HERE, "pending", SCENARIO, "frame.grid"))


@pytest.fixture()
def golden():
    with open(golden_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def spec():
    return scenario.load_spec()


# --- the baseline: the stored golden must PASS, or every mutant below is a false kill -----------

def test_the_stored_golden_carries_the_evidence(golden):
    summary = checker.check(golden, "stored golden")
    assert summary["load_stages"] == len(checker.EXPECTED_LOAD_STAGES)
    assert summary["save_written_by_version"] == "1.75"


def test_the_stored_golden_is_byte_for_byte_what_provenance_witnesses():
    """A GOLDEN CANNOT WITNESS ITSELF. Editing state.json moves both sides of every self-
    comparison; only a digest in a SEPARATE file sees it (beads oo-3ya, oo-gxp)."""
    import hashlib
    blob = open(golden_path(), "rb").read()
    with open(provenance_path(), "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    rec = prov["artifacts"]["state.json"]
    assert len(blob) == rec["bytes"]
    assert hashlib.sha256(blob).hexdigest() == rec["sha256"]


def test_one_quantised_unit_of_drift_is_detected_by_the_witness(tmp_path):
    """The red proof for the witness itself: perturb a THROWAWAY copy by one quantised unit and
    require the digest to notice. A fresh-run-vs-golden comparison cannot catch this."""
    import hashlib
    with open(golden_path(), "r", encoding="utf-8") as handle:
        state = json.load(handle)
    entity = state["entities"][0]
    assert entity["position"], "no entities[0].position to perturb"
    entity["position"][0] = round(float(entity["position"][0]) + 0.001, 6)
    mutant = tmp_path / "one_unit.json"
    mutant.write_text(json.dumps(state, sort_keys=True, separators=(",", ":")),
                      encoding="utf-8", newline="\n")
    with open(provenance_path(), "r", encoding="utf-8") as handle:
        rec = json.load(handle)["artifacts"]["state.json"]
    got = hashlib.sha256(mutant.read_bytes()).hexdigest()
    assert got != rec["sha256"]


def test_the_frame_grid_is_never_byte_hashed_into_a_verdict():
    """The deliberate asymmetry: the dump is byte-hashed because it is quantised and
    deterministic; the frame is NOT, because llvmpipe is not bit-reproducible - this scenario's
    own sweep produced 10 distinct grid digests over 10 BYTE-IDENTICAL dumps."""
    with open(provenance_path(), "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    assert prov["stability"]["distinct_frame_grid_digests"] == 10
    assert len(prov["stability"]["distinct_dump_digests"]) == 1
    assert "NEVER a gate predicate" in prov["artifacts"]["frame.grid"]["note"]


# --- the fixture itself: the facts the whole scenario rests on ---------------------------------

def test_the_fixture_is_a_1_75_save_with_five_non_empty_mission_variables():
    """THE MEASUREMENT THAT CHOSE THE ASSERTION'S FORM. Scenario 015's fixture holds an EMPTY
    STRING, indistinguishable over the JS bridge from an absent variable, so it could compare only
    keys. This one's values are all non-empty, so the whole MAP is asserted."""
    plist, size = scenario.read_save_file(SAVE)
    assert plist["written_by_version"] == "1.75"
    assert size > scenario.MIN_SAVE_BYTES
    mv = scenario.saved_mission_variables(plist)
    assert mv == checker.EXPECTED_MISSION_VARIABLES
    assert all(v != "" for v in mv.values())


def test_the_fixture_does_not_carry_the_thargplans_variable():
    """The bead's prose names mission_thargplans; it is ABSENT, which is why the scenario asserts
    the mission's ARMING CLAUSES instead of a variable's value."""
    plist, _ = scenario.read_save_file(SAVE)
    assert "mission_thargplans" not in plist["mission_variables"]
    assert checker.THARGPLANS_KEY not in scenario.saved_mission_variables(plist)


def test_an_empty_valued_mission_variable_is_a_refusal_not_a_verdict():
    """If a future fixture ever carries an empty value, the harness REFUSES rather than keeping a
    value assertion that cannot fail. Measured on the sibling Trumbles save, whose
    mission_trumbles IS the empty string - a real file, not a synthetic one."""
    plist, _ = scenario.read_save_file(SIBLING_SAVE)
    with pytest.raises(scenario.Refusal) as exc:
        scenario.saved_mission_variables(plist)
    assert "EMPTY STRING" in str(exc.value)


def test_the_kill_score_sits_one_over_the_mission_threshold():
    """1281 vs oolite-thargoid-plans-mission.js:80's `player.score > 1280`. No margin at all, by
    construction: a loader that reset or rounded the score disarms the mission."""
    plist, _ = scenario.read_save_file(SAVE)
    assert plist["ship_kills"] == 1281


def test_the_fixture_carries_the_legacy_energy_bomb_the_loader_migrates():
    """The 1.75 save-format contract's own precondition. PlayerEntity.m:1731-1746 pays 9000
    decicredits for this equipment, which is why the census adjusts the file side."""
    plist, _ = scenario.read_save_file(SAVE)
    assert plist["has_energy_bomb"] is True
    assert "EQ_ENERGY_BOMB" in plist["extra_equipment"]
    # ...and all four pylons are full, which is why the QC-mine branch cannot be taken.
    assert len(plist["missile_roles"]) == 4


def test_the_migration_is_applied_to_the_file_side_exactly(spec):
    """AN EXACT EQUALITY, NOT A TOLERANCE. Widening credits by 900 would hide any credit bug
    smaller than 900 credits, which is most of them."""
    plist, _ = scenario.read_save_file(SAVE)
    raw = scenario.saved_census(spec, plist)
    assert raw["credits"] == 99454.7
    migrated = scenario.apply_load_migrations(spec, raw, plist)
    assert migrated == ["credits"]
    assert raw["credits"] == 100354.7


# --- the checker: every defence rejects the dump a wrong run produces --------------------------

def _mutate(golden, **evidence_changes):
    state = copy.deepcopy(golden)
    for key, value in evidence_changes.items():
        if value is checker:  # sentinel: delete the key
            state["evidence"].pop(key, None)
        else:
            state["evidence"][key] = value
    return state


def _rejected(state, needle):
    with pytest.raises(checker.EvidenceError) as exc:
        checker.check(state, "mutant")
    assert needle in str(exc.value), str(exc.value)


def test_a_run_that_never_loaded_emits_no_load_stages(golden):
    """THE DEAD-RUN DUMP. A game started with no -load never enters -loadPlayerFromFile: and emits
    NONE of the 14 stages."""
    _rejected(_mutate(golden, load_stages=[]), "not the 14-stage sequence")


def test_a_load_that_died_partway_emits_a_prefix(golden):
    stages = list(checker.EXPECTED_LOAD_STAGES)[:5]
    _rejected(_mutate(golden, load_stages=stages), "not the 14-stage sequence")


def _checker_with(tmp_path, *removals):
    """Run a THROWAWAY copy of the evidence checker with one or more defences cut out.

    A copy, never the installed module: restore-on-exit does not run when a worker is killed at
    its timeout, and the orchestrator can harvest-and-commit a worktree at any instant - which is
    how bead oo-dto committed `if False:` in place of the one predicate its scenario was named
    for. Returns a callable taking a dump dict and giving back the CompletedProcess.
    """
    src = open(os.path.join(HERE, "check_thargoid_plans_evidence.py"), encoding="utf-8").read()
    for needle in removals:
        assert needle in src, "stale mutation: %r not in the checker" % (needle,)
        src = src.replace(needle, "if False:", 1)
    mutant = tmp_path / "mutated_checker.py"
    mutant.write_text(src, encoding="utf-8", newline="\n")

    def run(state):
        dump = tmp_path / "dump.json"
        dump.write_text(json.dumps(state), encoding="utf-8")
        return subprocess.run([sys.executable, str(mutant), str(dump)],
                              capture_output=True, text=True)
    return run


def test_the_load_stage_count_and_bounds_clauses_are_load_bearing(tmp_path, golden):
    """CHECKER MUTANT, not a data mutant. The ordered comparison is the FIRST clause and rejects
    both a stage-free dump and a prefix, so a data mutant alone can never show that the SECOND
    pair (count, and first/last bounds) does anything. Measured on scenario 015: with the ordered
    comparison removed, a dump carrying NO load stages was ACCEPTED - the property hung on one
    line. Here the ordered comparison is cut out of a THROWAWAY copy and the backup clauses are
    required to still reject both shapes, which is what makes the redundancy real rather than
    decorative.
    """
    run = _checker_with(tmp_path,
                        "if list(stages or []) != list(EXPECTED_LOAD_STAGES):")
    dead = run(_mutate(golden, load_stages=[]))
    assert dead.returncode == 1, dead.stdout + dead.stderr
    assert "load stage" in dead.stderr

    # A trace of the right LENGTH but the wrong ENDS: "Loading complete" is logged at
    # PlayerEntityLoadSave.m:811, AFTER the deserialiser finished, so its absence is a failed load.
    wrong_ends = ["Reading file"] * (len(checker.EXPECTED_LOAD_STAGES) - 1) + ["Creating system"]
    truncated = run(_mutate(golden, load_stages=wrong_ends))
    assert truncated.returncode == 1, truncated.stdout + truncated.stderr
    assert "does not run from" in truncated.stderr


def test_removing_every_load_stage_clause_lets_a_dead_run_through(tmp_path, golden):
    """THE NON-VACUITY PROOF FOR THE WHOLE DEFENCE: with ALL THREE clauses cut out, a dump from a
    run that never loaded anything is ACCEPTED (rc=0). That is what proves these clauses - and not
    some neighbouring check - are what stands between this scenario and a vacuous green.
    """
    run = _checker_with(tmp_path,
                        "if list(stages or []) != list(EXPECTED_LOAD_STAGES):",
                        "if len(stages or []) != len(EXPECTED_LOAD_STAGES):",
                        "if not bounds_ok:")
    result = run(_mutate(golden, load_stages=[]))
    assert result.returncode == 0, (
        "MISKILL: with every load-stage clause removed the stage-free dump was STILL rejected, so "
        "something else caught it: %s" % (result.stdout + result.stderr))


def test_an_empty_mission_variable_map_is_rejected(golden):
    """A fresh commander's dictionary is EMPTY (PlayerEntity.m:1986-1987)."""
    _rejected(_mutate(golden, mission_variables={}), "NO MISSION VARIABLES")


def test_a_different_saves_mission_variables_are_rejected(golden):
    """The sibling Trumbles save's real key set, which a key-set-only check would be closer to
    accepting. The MAP rejects it on values as well as names."""
    _rejected(_mutate(golden, mission_variables={
        "CT_thargonCount": "0", "snoopers_CRCNews": "|", "snoopers_dateCheck": "2084005",
        "snoopers_usedSlots": "0", "trumbles": ""}), "not the save's")


def test_clearing_conhunt_is_rejected_by_its_own_clause(golden):
    """The second, independent defence on the mission variable map: conhunt is the flag that ARMS
    this mission and no other save in the checklist set has it."""
    mv = dict(golden["evidence"]["mission_variables"])
    mv["conhunt"] = "RUNNING"
    _rejected(_mutate(golden, mission_variables=mv), "MISSION_COMPLETE")


def test_a_dump_claiming_the_mission_already_started_is_rejected(golden):
    """An extra thargplans key is caught by the MAP comparison first, which is correct but says
    nothing about the dedicated clause below it. So the map is widened to ACCEPT the extra key for
    the duration of this test, proving the thargplans clause is what then does the rejecting - and
    that a future fixture change which legitimises the key cannot silently disarm it.
    """
    mv = dict(golden["evidence"]["mission_variables"])
    mv["thargplans"] = "PRELUDE"
    _rejected(_mutate(golden, mission_variables=mv), "not the save's")


def test_the_thargplans_absence_clause_is_load_bearing(golden, monkeypatch):
    mv = dict(golden["evidence"]["mission_variables"])
    mv["thargplans"] = "PRELUDE"
    monkeypatch.setattr(checker, "EXPECTED_MISSION_VARIABLES", mv, raising=True)
    _rejected(_mutate(golden, mission_variables=mv), "sits BEFORE the Thargoid Plans mission")


def test_a_non_1_75_save_version_is_rejected(golden):
    _rejected(_mutate(golden, save_written_by_version="1.90"), "compatibility contract")


def test_a_run_whose_loader_did_not_migrate_is_rejected(golden):
    """THE CONTRACT'S TEETH. The version string alone is copied out of the plist by the harness;
    THIS line is emitted by the loader actually performing the migration."""
    _rejected(_mutate(golden, load_upgrade_messages=[]), "unfalsifiable fudge factor")


def test_a_census_migrated_on_a_field_nobody_declared_is_rejected(golden):
    _rejected(_mutate(golden, census_fields_migrated=["fuel"]), "census_fields_migrated")


def test_an_all_true_precondition_map_is_rejected(golden):
    """galaxy_is_two is FALSE: JS galaxyNumber is [player currentGalaxyID] (OOJSGlobal.m:190-191),
    the same 0-based index the plist stores, so this save is one GALACTIC jump short. A dump
    claiming otherwise is not this fixture."""
    pre = dict(golden["evidence"]["thargplans_preconditions"])
    pre["galaxy_is_two"] = True
    _rejected(_mutate(golden, thargplans_preconditions=pre), "one GALACTIC jump short")


def test_a_reset_kill_score_is_rejected_by_its_own_clause(golden):
    pre = dict(golden["evidence"]["thargplans_preconditions"])
    pre["score_over_1280"] = False
    _rejected(_mutate(golden, thargplans_preconditions=pre), "1280")


def test_a_shrinking_census_is_rejected(golden):
    _rejected(_mutate(golden, census_fields=3), "smaller hat")


def test_a_census_that_did_not_round_trip_is_rejected(golden):
    _rejected(_mutate(golden, round_trip_fields_equal=9), "census field(s) agree")


def test_mission_variables_that_moved_across_the_ticks_are_rejected(golden):
    _rejected(_mutate(golden, mission_variables_stable_across_ticks=False),
              "mission_variables_stable_across_ticks")


def test_an_unsettled_world_is_rejected(golden):
    _rejected(_mutate(golden, world_at_rest=False), "world_at_rest")


def test_a_dump_with_no_world_is_rejected(golden):
    state = copy.deepcopy(golden)
    state["entities"] = []
    _rejected(state, "compares equal to any other empty world")


def test_a_dump_with_no_market_is_rejected(golden):
    state = copy.deepcopy(golden)
    state["market"] = {}
    _rejected(state, "market")


def test_a_dump_with_no_evidence_block_is_rejected(golden):
    state = copy.deepcopy(golden)
    state.pop("evidence")
    _rejected(state, "no `evidence` block")


# --- the CLI's exit-code convention ------------------------------------------------------------

def test_the_cli_returns_1_for_a_dump_without_evidence(tmp_path, golden):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps(_mutate(golden, load_stages=[])), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_thargoid_plans_evidence.py"), str(bad)],
        capture_output=True, text=True)
    assert result.returncode == 1
    assert "NO EVIDENCE" in result.stderr


def test_the_cli_returns_2_for_a_usage_error(tmp_path):
    """rc=2 is 'I cannot tell you', never 'they match' - golden_diff's convention."""
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_thargoid_plans_evidence.py"),
         str(tmp_path / "nope.json")], capture_output=True, text=True)
    assert result.returncode == 2
    assert "USAGE ERROR" in result.stderr


def test_the_cli_returns_0_for_the_stored_golden():
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_thargoid_plans_evidence.py"), golden_path()],
        capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "EVIDENCE OK" in result.stdout


# --- the harness's own refusals ----------------------------------------------------------------

def test_a_missing_save_is_a_refusal(tmp_path):
    with pytest.raises(scenario.Refusal) as exc:
        scenario.read_save_file(str(tmp_path / "nope.oolite-save"))
    assert "DOES NOT EXIST" in str(exc.value)


def test_a_stub_save_is_a_refusal(tmp_path):
    stub = tmp_path / "stub.oolite-save"
    stub.write_bytes(b"<plist/>")
    with pytest.raises(scenario.Refusal) as exc:
        scenario.read_save_file(str(stub))
    assert "byte floor" in str(exc.value)


def test_comparing_a_census_with_itself_is_a_refusal(spec):
    """A mapping always equals itself - the in-memory twin of golden_diff's st_dev/st_ino guard."""
    plist, _ = scenario.read_save_file(SAVE)
    census = scenario.saved_census(spec, plist)
    with pytest.raises(scenario.Refusal) as exc:
        scenario.compare_census(census, census, "a", "b")
    assert "SAME object in memory" in str(exc.value)


def test_a_census_of_a_different_save_differs(spec):
    """THE DETECTION CONTROL, offline: the sibling Trumbles save must differ on player_name, or
    the census would pass for a run that loaded anything."""
    ours, _ = scenario.read_save_file(SAVE)
    theirs, _ = scenario.read_save_file(SIBLING_SAVE)
    problems = scenario.compare_census(scenario.saved_census(spec, ours),
                                       scenario.saved_census(spec, theirs), "ours", "theirs")
    assert any("player_name" in p for p in problems), problems


def test_an_unknown_census_kind_refuses_rather_than_inventing_a_conversion():
    with pytest.raises(scenario.Refusal) as exc:
        scenario._normalise(1, "furlongs")
    assert "refusing to invent a conversion" in str(exc.value)


def test_a_short_census_is_a_refusal():
    with pytest.raises(scenario.Refusal) as exc:
        scenario.assert_non_vacuous({"player_name": "ThargoidPlans"}, "a one-field census")
    assert "smaller hat" in str(exc.value)


def test_a_census_of_zeros_is_a_refusal():
    empty = {("f%d" % i): 0 for i in range(scenario.MIN_CENSUS_FIELDS)}
    with pytest.raises(scenario.Refusal) as exc:
        scenario.assert_non_vacuous(empty, "an all-zero census")
    assert "compares equal to any other empty census" in str(exc.value)


# --- the frame comparison ----------------------------------------------------------------------

def test_the_stored_frame_is_the_right_shape():
    assert len(scenario._read_grid(frame_path())) == 4096


def test_a_wrong_sized_grid_is_rejected(tmp_path):
    bad = tmp_path / "short.grid"
    bad.write_bytes(b"\0" * 100)
    with pytest.raises(scenario.ScenarioError) as exc:
        scenario._read_grid(str(bad))
    assert "luminance grid" in str(exc.value)


def test_an_all_black_frame_fails_the_liveness_floor(tmp_path, capsys):
    """What a run that died before drawing, or drew into a lost context, produces."""
    black = tmp_path / "black.grid"
    black.write_bytes(bytes(4096))
    assert scenario.compare_frame(str(black), frame_path()) == 1


def test_the_stored_frame_passes_against_itself(capsys):
    assert scenario.compare_frame(frame_path(), frame_path()) == 0


def test_a_wrong_scene_frame_exceeds_the_tolerance(capsys):
    """MEASURED SEPARATION, not an assumption: scenario 015's blessed Lave frame sits at 5.7x this
    scenario's tolerance while its own same-scene pairs sit at 0.31x..0.35x. That ratio of 16 is
    why the tolerance IS asserted here and was NOT in scenario 015, whose animated HUD gave it
    0.25."""
    other = _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", "015-trumbles", "frame.grid"),
                   os.path.join(HERE, "pending", "015-trumbles", "frame.grid"))
    assert scenario.compare_frame(other, frame_path()) == 1
