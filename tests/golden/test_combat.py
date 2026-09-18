"""Offline tests for golden scenario 003-combat. No game launch: everything here runs on the
staged artifacts and on synthetic dumps, in under two seconds.

THE POINT OF THIS FILE IS THAT THE EVIDENCE CHECKER IS ITSELF CHECKED. A gate that validates
data with a validator nobody validates is a hole one refactor wide (bead oo-jor shipped exactly
that: its stored golden's evidence was protected while the code judging it was not, so loosening
a threshold left 23 tests passing). So for every property check_combat_evidence defends there is
a test that feeds it a KNOWN-BAD dump and asserts it is REJECTED - not merely that the good dump
passes.

The per-defence tests are separate on purpose (bead oo-jor again): when a property is defended by
more than one clause, a mutant that removes one clause is an EQUIVALENT mutant rather than a
surviving hole, and the only way to tell those apart is to exercise each defence on its own.
"""

import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import check_combat_evidence as checker  # noqa: E402
import combat  # noqa: E402
import golden_diff  # noqa: E402

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", "003-combat", "spec.json"),
    os.path.join(HERE, "pending", "003-combat", "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", "003-combat"),
    os.path.join(HERE, "pending", "003-combat"),
)


def golden_dir():
    for candidate in GOLDEN_CANDIDATES:
        if os.path.isfile(os.path.join(candidate, "state.json")):
            return candidate
    raise AssertionError("no scenario 003 golden in any of %s" % (GOLDEN_CANDIDATES,))


@pytest.fixture(scope="module")
def spec():
    path = next((c for c in SPEC_CANDIDATES if os.path.isfile(c)), None)
    assert path, "no scenario 003 spec in any of %s" % (SPEC_CANDIDATES,)
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def golden():
    with open(os.path.join(golden_dir(), "state.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def provenance():
    with open(os.path.join(golden_dir(), "provenance.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


def mutate(golden, **overrides):
    """A THROWAWAY COPY of the golden with evidence fields overridden. The stored golden is never
    touched: hard rule 1 forbids it, and a test that edits its own fixture proves nothing."""
    copy = json.loads(json.dumps(golden))
    copy["evidence"].update(overrides)
    return copy


def rejects(data, reason_fragment):
    with pytest.raises(checker.EvidenceError) as excinfo:
        checker.check(data, "mutant")
    assert reason_fragment in str(excinfo.value), (
        "the checker rejected the mutant but not for the expected reason; got: %s"
        % excinfo.value)


# --- the staged artifacts are real and self-consistent -----------------------------------


def test_staged_golden_carries_combat_evidence(golden):
    summary = checker.check(golden, "staged golden")
    assert "engine damage event" in summary


def test_provenance_hash_matches_the_stored_state(provenance):
    import hashlib
    with open(os.path.join(golden_dir(), "state.json"), "rb") as handle:
        raw = handle.read()
    assert hashlib.sha256(raw).hexdigest() == provenance["state_sha256"], (
        "provenance.state_sha256 does not match the state.json beside it; one of them was edited "
        "without the other")
    assert len(raw) == provenance["state_bytes"]


def test_golden_survives_golden_diff_non_vacuity_guards(golden):
    """The stored golden must not be the kind of dump golden_diff refuses to compare: too few
    fields, no entities, or every float a whole number (which is what a coarsened quantisation
    looks like and would make it compare equal to almost anything)."""
    golden_diff.assert_non_vacuous(golden, "staged golden")
    floats, fractional = golden_diff.check_quantisation(golden, "staged golden", None)
    assert fractional > 0, ("every float in the golden is a whole number; the dump carries no "
                            "fractional detail and would compare equal to almost any other run")


# --- the spec knobs -----------------------------------------------------------------------


def test_every_knob_is_pinned_and_agrees_with_provenance():
    """The executable form of the gate, run here too so a broken knob fails in the fast tier."""
    result = subprocess.run([sys.executable, os.path.join(HERE, "gate_003_spec.py")],
                            capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, "gate_003_spec.py failed: %s%s" % (result.stdout, result.stderr)


def test_the_cast_is_pinned_by_ship_key_not_by_role(spec):
    """The finding the whole scenario rests on. A role name here reintroduces the RANROT
    ship-type draw (Universe.m:3948 -> OOShipRegistry.m:276-279) that changed the encounter's
    OUTCOME run to run at a fixed seed."""
    for knob in ("attacker_key", "victim_key"):
        assert spec[knob].startswith("[") and spec[knob].endswith("]"), (
            "spec[%r] = %r is a role, not a literal ship key" % (knob, spec[knob]))


def test_the_recorded_cast_identity_matches_the_pinned_keys(golden):
    """Belt and braces on the same property, from the other side: the identity string the ENGINE
    reported must name the two ships the keys select, so a spec key that silently resolved to a
    different ship is caught."""
    identity = golden["evidence"]["cast_identity"]
    assert "Viper" in identity and "Adder" in identity, (
        "the golden's engine-reported cast identity %r does not name the ships spec's "
        "attacker_key/victim_key select" % identity)


# --- the checker rejects each shape of dead run, one defence at a time ---------------------


def test_rejects_a_run_in_which_nothing_was_damaged(golden):
    rejects(mutate(golden, damage_events=0), "NO DAMAGE WAS DEALT")


def test_rejects_a_strike_that_landed_for_zero_damage(golden):
    """damage_events alone is not enough: -takeEnergyDamage: could be reached with an amount the
    engine summed to nothing. damage_total is the engine's own `amount` argument."""
    rejects(mutate(golden, damage_total=0.0), "evidence.damage_total is 0.0")


def test_rejects_a_run_in_which_nobody_died(golden):
    rejects(mutate(golden, death_events=0), "NO SHIP DIED")


def test_rejects_more_than_one_death(golden):
    """Pinned to exactly 1, not >= 1: the counter is hung on one ship's script object, so >1 means
    the handle is not the single ship the scenario spawned."""
    rejects(mutate(golden, death_events=2), "expected exactly 1")


def test_rejects_a_death_not_attributed_to_the_attacker(golden):
    """The clause a proximity accident or a station-launched ship cannot satisfy: the engine
    dispatches shipKilledOther to `whom`, and `whom` is this scenario's attacker handle."""
    rejects(mutate(golden, kill_events=0), "NOT ATTRIBUTED TO THE ATTACKER")


def test_rejects_a_victim_that_is_still_alive(golden):
    rejects(mutate(golden, victim_destroyed=False), "evidence.victim_destroyed is False")


def test_rejects_an_attacker_that_did_not_survive(golden):
    rejects(mutate(golden, attacker_survived=False), "evidence.attacker_survived is False")


def test_rejects_a_cast_count_that_did_not_fall_by_one(golden):
    """Handle-scoped, not a role count - bead oo-qwk5's blocker. A role count cannot distinguish
    a ship the scenario spawned from one the populator or the station wandered in."""
    rejects(mutate(golden, cast_alive_after=2), "expected 2 -> 1")


def test_rejects_a_cast_that_was_never_two_ships(golden):
    rejects(mutate(golden, cast_alive_before=1), "expected 2 -> 1")


def test_rejects_a_run_whose_clock_never_advanced(golden):
    rejects(mutate(golden, tick_budget_met=False), "evidence.tick_budget_met is False")


def test_rejects_a_dump_that_predates_the_populator_suppression(golden):
    copy = json.loads(json.dumps(golden))
    del copy["evidence"]["populators_suppressed"]
    rejects(copy, "evidence.populators_suppressed is ABSENT")


def test_rejects_a_dump_with_no_evidence_block_at_all(golden):
    copy = json.loads(json.dumps(golden))
    del copy["evidence"]
    with pytest.raises(checker.EvidenceError) as excinfo:
        checker.check(copy, "no-evidence")
    assert "the same nothing happened twice" in str(excinfo.value)


def test_rejects_a_collapsed_dump(golden):
    copy = json.loads(json.dumps(golden))
    copy["entities"] = []
    copy["market"] = {}
    with pytest.raises(checker.EvidenceError) as excinfo:
        checker.check(copy, "collapsed")
    text = str(excinfo.value)
    assert "entities has 0" in text and "market has 0" in text


def test_rejects_claiming_more_shots_than_the_spec_permits(golden):
    rejects(mutate(golden, strikes_delivered=99), "claims more shots than the spec permits")


# --- the CLI's exit codes, which the acceptance lines depend on ---------------------------


def test_cli_returns_1_for_a_dead_run(tmp_path, golden):
    dead = tmp_path / "dead.json"
    dead.write_text(json.dumps(mutate(golden, damage_events=0, death_events=0, kill_events=0)),
                    encoding="utf-8")
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_combat_evidence.py"), str(dead)],
        capture_output=True, text=True)
    assert result.returncode == 1, "a dead run must exit 1, got %d" % result.returncode
    assert "NO EVIDENCE" in result.stderr


def test_cli_returns_2_for_a_missing_dump(tmp_path):
    """rc=2 is 'I cannot tell you', never 'they match' - the convention golden_diff established."""
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_combat_evidence.py"),
         str(tmp_path / "nope.json")],
        capture_output=True, text=True)
    assert result.returncode == 2


def test_cli_returns_0_for_the_staged_golden():
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "check_combat_evidence.py"),
         os.path.join(golden_dir(), "state.json")],
        capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


# --- the scenario script's own structure ---------------------------------------------------


def test_scenario_refuses_a_run_with_no_damage(golden):
    """combat.py's own capture-time gate, exercised directly rather than by launching the game:
    the same assertion the --no-fire acceptance line proves end to end."""
    evidence = json.loads(json.dumps(golden["evidence"]))
    evidence["damage_events"] = 0
    with pytest.raises(combat.ScenarioError) as excinfo:
        combat.assert_fought(evidence)
    assert "never dispatched shipTakingDamage" in str(excinfo.value)


def test_scenario_refuses_a_run_where_the_victim_survived(golden):
    evidence = json.loads(json.dumps(golden["evidence"]))
    evidence["death_events"] = 0
    with pytest.raises(combat.ScenarioError) as excinfo:
        combat.assert_fought(evidence)
    assert "shipDied" in str(excinfo.value)


def test_scenario_accepts_the_golden_it_produced(golden):
    combat.assert_fought(golden["evidence"])


def test_the_motion_guard_calls_magnitude_rather_than_comparing_the_function(golden):
    """Scenario 001 shipped a guard reading `velocity.magnitude > 0.0005`, comparing a JS function
    object with a number: always false, so it passed on every run including ones whose dumps
    differed by 12 velocity fields. A guard that cannot fail is worse than none."""
    with open(os.path.join(HERE, "combat.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    assert "velocity.magnitude() > 0.0005" in source
    assert "velocity.magnitude >" not in source


def test_the_scenario_checks_pausegame_returned_true():
    """GlobalPauseGame (OOJSGlobal.m:831-856) returns NO without pausing on several screens. An
    unchecked pause leaves delta_t wall-clock (GameController.m:405) and turns the dump into a
    stopwatch reading."""
    with open(os.path.join(HERE, "combat.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    assert 'pauseGame()' in source and 'returned false' in source


# --- the GATE's own defences are pinned, one at a time ------------------------------------
#
# Bead oo-jor's lesson, applied to gate_003_spec.py rather than to the evidence checker: a
# defence that nothing exercises can be deleted by a refactor with every test still green. A
# mutation run on this scenario found exactly that - removing the "is this knob actually read"
# predicate left the whole suite passing, because nothing fed the gate a spec/scenario pair that
# only that predicate rejects.
#
# Each test below copies the gate and the staged artifacts to a temp tree, removes ONE defence,
# feeds it the input that defence exists to reject, and asserts the mutated gate returns 0 -
# i.e. it proves the defence is load-bearing. Behavioural, not a string match on source text, so
# renaming a variable does not break the pin.

def _gate_tree(tmp_path, gate_edit=None, spec_edit=None, scenario_edit=None):
    """A throwaway copy of the gate and its inputs, optionally mutated. Returns the rc of
    running gate_003_spec.py inside it."""
    import shutil
    root = tmp_path / "t"
    (root / "tests" / "golden" / "pending" / "003-combat").mkdir(parents=True)
    (root / "upstream" / "oolite" / "tests" / "component").mkdir(parents=True)
    for name in ("gate_003_spec.py", "combat.py", "golden_run.py"):
        shutil.copy(os.path.join(HERE, name), root / "tests" / "golden" / name)
    shutil.copytree(os.path.join(HERE, "dump"), root / "tests" / "golden" / "dump")
    for name in os.listdir(golden_dir()):
        shutil.copy(os.path.join(golden_dir(), name),
                    root / "tests" / "golden" / "pending" / "003-combat" / name)
    shutil.copy(os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py"),
                root / "upstream" / "oolite" / "tests" / "component" / "console.py")

    def edit(path, fn):
        text = path.read_text(encoding="utf-8")
        path.write_text(fn(text), encoding="utf-8", newline="\n")

    if gate_edit:
        edit(root / "tests" / "golden" / "gate_003_spec.py", gate_edit)
    if scenario_edit:
        edit(root / "tests" / "golden" / "combat.py", scenario_edit)
    if spec_edit:
        p = root / "tests" / "golden" / "pending" / "003-combat" / "spec.json"
        data = json.loads(p.read_text(encoding="utf-8"))
        spec_edit(data)
        p.write_text(json.dumps(data, indent=2), encoding="utf-8", newline="\n")

    return subprocess.run(
        [sys.executable, str(root / "tests" / "golden" / "gate_003_spec.py")],
        capture_output=True, text=True, cwd=str(root))


def test_gate_tree_helper_is_green_unmutated(tmp_path):
    """The baseline every test below depends on. A helper that is already red would register a
    false kill for every mutant run against it (bead oo-4vdc)."""
    result = _gate_tree(tmp_path)
    assert result.returncode == 0, "%s%s" % (result.stdout, result.stderr)


def test_the_knob_is_read_predicate_is_load_bearing(tmp_path):
    """Remove the 'is this knob read where it is acted on' defence and feed it a scenario whose
    strike amounts are hardcoded: the mutated gate must go GREEN, proving the real gate's RED is
    caused by that predicate and not by something else."""
    hardcode = lambda s: s.replace(  # noqa: E731
        'float(spec["strike_damage"]), float(spec["strike_range"])', "60.0, 2500.0")

    real = _gate_tree(tmp_path / "real", scenario_edit=hardcode)
    assert real.returncode == 1, (
        "hardcoding the strike amounts at combat.py's acting call site did not fail the gate; "
        "the knob-is-read defence is blind: %s%s" % (real.stdout, real.stderr))
    assert "acts on it" in real.stderr or "decoration" in real.stderr

    weakened = _gate_tree(
        tmp_path / "weak",
        gate_edit=lambda s: s.replace("        if not reads:", "        if False:"),
        scenario_edit=hardcode)
    assert weakened.returncode == 0, (
        "removing the knob-is-read defence did NOT make the hardcoded scenario pass, so that "
        "defence is not what rejects it and the pin is testing the wrong thing")


def test_the_provenance_drift_predicate_is_load_bearing(tmp_path):
    """oo-3ya's survivor: a seed that can be changed with the gate staying green."""
    change_seed = lambda d: d.__setitem__("seed", 31337)  # noqa: E731

    real = _gate_tree(tmp_path / "real", spec_edit=change_seed)
    assert real.returncode == 1, "changing the spec's seed did not fail the gate"
    assert "blessed with" in real.stderr

    weakened = _gate_tree(tmp_path / "weak",
                          gate_edit=lambda s: s.replace("    if drift:", "    if False:"),
                          spec_edit=change_seed)
    assert weakened.returncode == 0, (
        "removing the provenance-drift defence did not make a changed seed pass; the seed is "
        "being rejected by something else and the drift clause is untested")


def test_the_ship_key_predicate_is_load_bearing(tmp_path):
    """The cast must be pinned by ship key, not role - finding 1. Both the key predicate AND the
    drift clause are removed, because a role name in the spec also drifts from provenance: with
    only one removed this would be an EQUIVALENT mutant, not a proof."""
    to_role = lambda d: d.__setitem__("victim_key", "pirate")  # noqa: E731

    real = _gate_tree(tmp_path / "real", spec_edit=to_role)
    assert real.returncode == 1
    assert "literal ship key" in real.stderr

    weakened = _gate_tree(
        tmp_path / "weak",
        gate_edit=lambda s: s.replace(
            '        if not (isinstance(value, str) and value.startswith("[")'
            ' and value.endswith("]")\n                and len(value) > 2):',
            "        if False:").replace("    if drift:", "    if False:"),
        spec_edit=to_role)
    assert weakened.returncode == 0, (
        "removing BOTH the ship-key predicate and the drift clause did not let a role through; "
        "a third defence is rejecting it and this pin does not cover what it claims")


def test_the_quantisation_policy_predicate_is_load_bearing(tmp_path):
    """Coarsening quantisation is the standard way a golden suite rots into decoration. This is
    the one defence that must survive its own provenance being coarsened too, so both sides are
    mutated: there is no drift to find, and only the policy predicate can reject it."""
    def coarsen_both(root_specs):
        root_specs["quant_decimals"] = 0

    real = _gate_tree(tmp_path / "real", spec_edit=coarsen_both)
    assert real.returncode == 1
    assert "storage policy is 3" in real.stderr

    weakened = _gate_tree(
        tmp_path / "weak",
        gate_edit=lambda s: s.replace(
            '    if spec["quant_decimals"] != POLICY_QUANT_DECIMALS:', "    if False:"
        ).replace("    if drift:", "    if False:"),
        spec_edit=coarsen_both)
    assert weakened.returncode == 0, (
        "removing the quantisation-policy predicate did not let quant_decimals=0 through")
