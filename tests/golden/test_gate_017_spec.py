"""Mutation self-test for tests/golden/gate_017_spec.py. No game, no build.

WHY THIS FILE EXISTS
--------------------
`gate_017_spec.py` is the line that catches a determinism knob drifting away from the golden it
was blessed with - the one failure a fresh-run-vs-golden comparison is structurally incapable of
seeing, because changing a knob changes BOTH sides of that comparison (beads oo-3ya, oo-gxp).
A gate with that job must itself be proven load-bearing: bead oo-jor's rule is two mutants per
property, one that corrupts the DATA and one that weakens the CHECKER, because only the second
catches a validator nobody validates.

Each test below builds a THROWAWAY TREE under pytest's tmp_path - the real gate, spec and
provenance are never written to. That is deliberate and not merely tidy: restore-on-exit does not
run when a worker is killed at its timeout, and the orchestrator's gc can harvest-and-commit a
worktree at any instant, which is exactly how bead oo-dto committed `if False:` in place of the
one predicate its scenario was named for.

THE SHAPE OF EACH TEST
----------------------
  DATA mutant:    break one input, assert the UNMUTATED gate returns 1 and NAMES the knob.
  CHECKER mutant: remove one defence, feed it the input that defence exists to reject, and assert
                  the mutated gate returns 0 - i.e. prove the defence is what does the rejecting
                  and not a neighbour (bead oo-9w5's MISKILL concept).

`test_gate_tree_helper_is_green_unmutated` is the baseline the rest depend on: a helper that is
already red registers a false kill for every mutant run against it (bead oo-4vdc).
"""

import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "017-thargoid-plans"

GATE = os.path.join(HERE, "gate_017_spec.py")


def _golden_dir():
    for candidate in (os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
                      os.path.join(HERE, "pending", SCENARIO)):
        if os.path.isfile(os.path.join(candidate, "provenance.json")):
            return candidate
    raise AssertionError("no provenance.json for %s in either the guarded or the staged location"
                         % SCENARIO)


def _gate_tree(tmp_path, gate_edit=None, spec_edit=None, prov_edit=None, scenario_edit=None):
    """Run a THROWAWAY copy of the gate over throwaway copies of its inputs.

    Returns the CompletedProcess. Nothing under the repo is written.
    """
    root = tmp_path / "t"
    staged = root / "tests" / "golden" / "pending" / SCENARIO
    staged.mkdir(parents=True)
    (root / "upstream" / "oolite" / "tests" / "component").mkdir(parents=True)

    shutil.copy(GATE, root / "tests" / "golden" / "gate_017_spec.py")
    shutil.copy(os.path.join(HERE, "thargoid_plans_load.py"),
                root / "tests" / "golden" / "thargoid_plans_load.py")
    gdir = _golden_dir()
    for name in os.listdir(gdir):
        src = os.path.join(gdir, name)
        if os.path.isfile(src):
            shutil.copy(src, staged / name)
    # The spec may already be staged beside the golden; if it lives under scenarios/ take it there.
    spec_src = os.path.join(HERE, "scenarios", SCENARIO, "spec.json")
    if os.path.isfile(spec_src):
        shutil.copy(spec_src, staged / "spec.json")
    shutil.copy(os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py"),
                root / "upstream" / "oolite" / "tests" / "component" / "console.py")

    def edit_text(path, fn):
        path.write_text(fn(path.read_text(encoding="utf-8")), encoding="utf-8", newline="\n")

    def edit_json(path, fn):
        data = json.loads(path.read_text(encoding="utf-8"))
        fn(data)
        path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8", newline="\n")

    if gate_edit:
        edit_text(root / "tests" / "golden" / "gate_017_spec.py", gate_edit)
    if scenario_edit:
        edit_text(root / "tests" / "golden" / "thargoid_plans_load.py", scenario_edit)
    if spec_edit:
        edit_json(staged / "spec.json", spec_edit)
    if prov_edit:
        edit_json(staged / "provenance.json", prov_edit)

    return subprocess.run([sys.executable, str(root / "tests" / "golden" / "gate_017_spec.py")],
                          capture_output=True, text=True, cwd=str(root))


def _out(result):
    return result.stdout + result.stderr


def _hardcode_ticks_in_run(text):
    """THE MUTANT A SUBSTRING-ONLY GATE SURVIVES.

    Replace the behavioural read of `spec["ticks"]` inside run() with a literal, then leave the
    knob's NAME in the file in a comment - exactly what happens when a knob is read only to be
    copied into the evidence block. A text scan still finds `spec["ticks"]`; the behaviour now
    runs on 24 regardless of what the spec says.
    """
    marker = "def run("
    head, sep, tail = text.partition(marker)
    assert sep, "thargoid_plans_load.py has no run(); this mutation is stale"
    mutated = head + sep + tail.replace('spec["ticks"]', "24")
    return mutated + '\n# the evidence block records spec["ticks"] for provenance\n'


# --- baseline ----------------------------------------------------------------------------------

def test_gate_tree_helper_is_green_unmutated(tmp_path):
    result = _gate_tree(tmp_path)
    assert result.returncode == 0, _out(result)
    assert "PASS:" in result.stdout


def test_the_real_gate_passes_on_the_real_tree():
    """The gate as committed, against the artifacts as committed."""
    result = subprocess.run([sys.executable, GATE], capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, _out(result)


# --- DATA mutants: break one input, the gate must go red naming it -----------------------------

def test_a_seed_that_drifts_from_provenance_is_caught(tmp_path):
    """The failure a fresh-run-vs-golden comparison CANNOT see: changing the seed changes both
    sides of it. Only agreement with provenance catches this (bead oo-3ya's survivor)."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(seed=31337))
    assert result.returncode == 1, _out(result)
    assert "disagrees with the knobs this golden was blessed with" in _out(result)
    assert "seed" in _out(result)


def test_dropping_the_energy_bomb_migration_is_caught(tmp_path):
    """Without the declared migration the census compares RAW saved credits against MIGRATED
    loaded credits - red on a CORRECT engine. This is the 1.75 contract the bead names."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(load_migrations=[]))
    assert result.returncode == 1, _out(result)
    assert "energy-bomb compensation" in _out(result) or "load_migrations" in _out(result)


def test_a_migration_delta_that_is_not_the_engines_is_caught(tmp_path):
    """The delta changes what 'the loaded credits are correct' MEANS. PlayerEntity.m:1743 adds
    9000 decicredits; any other number silently redefines the assertion."""
    def bend(s):
        s["load_migrations"][0]["delta"] = 12345
    result = _gate_tree(tmp_path, spec_edit=bend)
    assert result.returncode == 1, _out(result)
    assert "9000" in _out(result)


def test_dropping_the_upgrade_message_evidence_is_caught(tmp_path):
    """A migration applied without the engine's OWN record of performing it is an unfalsifiable
    fudge factor."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(expected_upgrade_messages=[]))
    assert result.returncode == 1, _out(result)
    assert "fudge factor" in _out(result)


def test_an_empty_valued_mission_variable_is_caught(tmp_path):
    """THE LESSON FROM SCENARIO 015, ENFORCED. An ABSENT mission variable reads identically to an
    empty one over the JS bridge, so an expectation of "" is satisfied by a game that never
    loaded the save - silently. This fixture's values are all non-empty, which is why the whole
    map can be asserted; downgrading one to empty removes the strength, not the check."""
    def blank(s):
        s["expected_mission_variables"]["conhunt"] = ""
    result = _gate_tree(tmp_path, spec_edit=blank)
    assert result.returncode == 1, _out(result)
    assert "EMPTY STRING" in _out(result)


def test_an_all_true_precondition_map_is_caught(tmp_path):
    """galaxy_is_two is FALSE here: JS galaxyNumber is the same 0-based index the plist stores
    (OOJSGlobal.m:190-191), so this save sits one galactic jump short of the mission. A first
    draft assumed otherwise and the live run disproved it; an all-true map means the assumption
    came back."""
    def flip(s):
        s["expected_thargplans_preconditions"]["galaxy_is_two"] = True
    result = _gate_tree(tmp_path, spec_edit=flip)
    assert result.returncode == 1, _out(result)
    assert "ONE GALACTIC JUMP SHORT" in _out(result)


def test_expecting_thargplans_present_is_caught(tmp_path):
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(thargplans_expected=True))
    assert result.returncode == 1, _out(result)
    assert "thargplans_expected" in _out(result)


def test_pointing_the_scenario_at_a_different_save_is_caught(tmp_path):
    """This scenario exists to load the 1.75-era checklist ThargoidPlans save; aimed elsewhere it
    is a different scenario wearing this one's golden."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(
        load_save="upstream/oolite-tests/Checklist-files/Missions/Trumbles.oolite-save"))
    assert result.returncode == 1, _out(result)
    assert "ThargoidPlans.oolite-save" in _out(result)


def test_dropping_the_load_progress_channel_is_caught(tmp_path):
    """load.progress is OFF by default; without it the engine's own proof that -load was honoured
    never reaches the dump."""
    def drop(s):
        s["log_channels"] = [c for c in s["log_channels"] if c != "load.progress"]
    result = _gate_tree(tmp_path, spec_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "load.progress" in _out(result)


def test_dropping_the_upgrade_channel_is_caught(tmp_path):
    """The channel the migration logs on. Without it evidence.load_upgrade_messages is empty for a
    reason about the logging configuration rather than about the loader."""
    def drop(s):
        s["log_channels"] = [c for c in s["log_channels"]
                             if c != "load.upgrade.replacedEnergyBomb"]
    result = _gate_tree(tmp_path, spec_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "load.upgrade.replacedEnergyBomb" in _out(result)


def test_a_truncated_load_stage_sequence_is_caught(tmp_path):
    def truncate(s):
        s["load_progress_stages"] = s["load_progress_stages"][:6]
    result = _gate_tree(tmp_path, spec_edit=truncate)
    assert result.returncode == 1, _out(result)
    assert "load.progress stage" in _out(result)


def test_coarsening_the_quantisation_is_caught(tmp_path):
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(quant_decimals=1))
    assert result.returncode == 1, _out(result)
    assert "storage policy is 3" in _out(result)


def test_a_stability_sweep_with_unaccounted_runs_is_caught(tmp_path):
    """A REFUSAL is not a DIFFERENCE, but neither may a run simply vanish from the tally."""
    def hide(p):
        p["stability"]["dumps_written"] = 8
    result = _gate_tree(tmp_path, prov_edit=hide)
    assert result.returncode == 1, _out(result)
    assert "every run's outcome must be recorded" in _out(result)


def test_a_sweep_with_two_distinct_digests_is_caught(tmp_path):
    def split(p):
        p["stability"]["distinct_dump_digests"] = ["a" * 64, "b" * 64]
    result = _gate_tree(tmp_path, prov_edit=split)
    assert result.returncode == 1, _out(result)
    assert "distinct dump digest" in _out(result)


def test_downgrading_the_frame_tolerance_to_liveness_only_is_caught(tmp_path):
    """Unlike scenario 015 this scene is static and the tolerance IS assertable (separation 16).
    Dropping it would discard a real property without measuring anything."""
    def flip(p):
        p["frame_tolerance"]["asserted"] = False
    result = _gate_tree(tmp_path, prov_edit=flip)
    assert result.returncode == 1, _out(result)
    assert "separation ratio of 16" in _out(result)


def test_asserting_a_tolerance_with_no_separation_is_caught(tmp_path):
    """The tolerance may be asserted only where the wrong-scene distance exceeds same-scene
    noise. Scenario 015 measured 0.25 and correctly did NOT assert it."""
    def collapse(p):
        p["frame_measurements"]["separation_ratio"] = 0.25
    result = _gate_tree(tmp_path, prov_edit=collapse)
    assert result.returncode == 1, _out(result)
    assert "coin toss" in _out(result)


def test_dropping_the_frame_liveness_assertion_is_caught(tmp_path):
    """Liveness is checked against an ABSOLUTE, so it survives a reference frame that was itself
    black - which the tolerance does not."""
    def drop(p):
        p["frame_liveness"]["asserted"] = False
    result = _gate_tree(tmp_path, prov_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "all-black grid" in _out(result)


def test_a_provenance_with_no_state_digest_is_caught(tmp_path):
    """Without a witness OUTSIDE the golden, editing the golden moves both sides of every
    self-comparison (bead oo-gxp's D3 survivor)."""
    def drop(p):
        p["artifacts"].pop("state.json", None)
    result = _gate_tree(tmp_path, prov_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "witness OUTSIDE" in _out(result)


def test_a_knob_the_scenario_never_reads_is_caught(tmp_path):
    """A knob no code consults is decoration: changing it changes nothing and no line goes red."""
    result = _gate_tree(tmp_path, scenario_edit=lambda t: t.replace('spec["ticks"]', "24"))
    assert result.returncode == 1, _out(result)
    assert "never reads spec['ticks']" in _out(result)


def test_a_knob_read_only_where_it_is_recorded_is_caught(tmp_path):
    """The mutant a substring-only gate survives: the knob is still NAMED in the file, but the
    function that ACTS on it now runs on a literal. Caught by AST, not by text."""
    result = _gate_tree(tmp_path, scenario_edit=_hardcode_ticks_in_run)
    assert result.returncode == 1, _out(result)
    assert "NOT inside run()" in _out(result)


def test_a_scenario_that_stops_passing_load_save_is_caught(tmp_path):
    """Without load_save= the game starts a FRESH COMMANDER and every check about 'the loaded
    save' measures a default game."""
    result = _gate_tree(tmp_path, scenario_edit=lambda t: t.replace("load_save=save", "load_save=None"))
    assert result.returncode == 1, _out(result)
    assert "FRESH COMMANDER" in _out(result)


def test_a_missing_provenance_is_a_refusal_not_a_verdict(tmp_path):
    """rc=2 means 'I cannot tell you', never 'they match' - the repo's rc convention."""
    root = tmp_path / "t"
    result = _gate_tree(tmp_path)
    assert result.returncode == 0
    os.remove(root / "tests" / "golden" / "pending" / SCENARIO / "provenance.json")
    again = subprocess.run([sys.executable, str(root / "tests" / "golden" / "gate_017_spec.py")],
                           capture_output=True, text=True, cwd=str(root))
    assert again.returncode == 2, _out(again)
    assert "REFUSED" in _out(again)


# --- CHECKER mutants: remove one defence, the known-bad input must now be ACCEPTED --------------
#
# Each of these proves the named defence is the thing that does the rejecting. If a mutant still
# comes back red, some NEIGHBOURING check caught the input instead and the defence under test is
# either redundant or blind - bead oo-9w5 calls that a MISKILL and it is a failure, not a pass.

def _defence_is_load_bearing(tmp_path, gate_edit, spec_edit=None, prov_edit=None,
                             scenario_edit=None):
    red = _gate_tree(tmp_path / "red", spec_edit=spec_edit, prov_edit=prov_edit,
                     scenario_edit=scenario_edit)
    assert red.returncode == 1, \
        "baseline: the unmutated gate did NOT reject the bad input: %s" % _out(red)
    green = _gate_tree(tmp_path / "green", gate_edit=gate_edit, spec_edit=spec_edit,
                       prov_edit=prov_edit, scenario_edit=scenario_edit)
    assert green.returncode == 0, (
        "MISKILL: with this defence removed the bad input was STILL rejected, so some other check "
        "caught it and this defence is not what defends the property: %s" % _out(green))


def test_the_migration_delta_predicate_is_load_bearing(tmp_path):
    """Change the delta CONSISTENTLY in the spec AND in provenance - i.e. a deliberate re-bless at
    a wrong delta, so the spec-vs-provenance agreement check is satisfied.

    THE ENGINE'S 9000 IS GUARDED TWICE, ON PURPOSE, and this test measured that. Removing only the
    SPEC-side predicate left the input still rejected - by the PROVENANCE-side one, which compares
    the same constant. That is a MISKILL for a single-predicate mutant and a correct result for the
    property: two independent witnesses of the engine's own number, so neither file can be edited
    alone. The mutant therefore removes BOTH, which is what it takes to make a wrong delta pass,
    and the surviving spec-vs-provenance agreement check cannot catch it because both sides moved
    together.
    """
    def spec_edit(s):
        s["load_migrations"][0]["delta"] = 12345

    def prov_edit(p):
        p["save_format_contract"]["credits_delta_decicredits"] = 12345

    def gate_edit(t):
        t = t.replace('if migration["delta"] != ENERGY_BOMB_COMPENSATION_DECICREDITS:',
                      "if False:", 1)
        return t.replace(
            'if contract.get("credits_delta_decicredits") != ENERGY_BOMB_COMPENSATION_DECICREDITS:',
            "if False:", 1)

    _defence_is_load_bearing(tmp_path, gate_edit=gate_edit, spec_edit=spec_edit,
                             prov_edit=prov_edit)


def test_the_empty_mission_value_predicate_is_load_bearing(tmp_path):
    def blank(s):
        s["expected_mission_variables"]["conhunt"] = ""
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("    if empty:", "    if False:", 1),
        spec_edit=blank)


def test_the_false_precondition_predicate_is_load_bearing(tmp_path):
    def flip(s):
        s["expected_thargplans_preconditions"]["galaxy_is_two"] = True
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            "if not any(v is False for v in expected_pre.values()):", "if False:", 1),
        spec_edit=flip)


def test_the_provenance_drift_predicate_is_load_bearing(tmp_path):
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            "drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}",
            "drift = {}", 1),
        spec_edit=lambda s: s.update(seed=31337))


def test_the_upgrade_channel_predicate_is_load_bearing(tmp_path):
    def drop(s):
        s["log_channels"] = [c for c in s["log_channels"]
                             if c != "load.upgrade.replacedEnergyBomb"]
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            'if REQUIRED_UPGRADE_CHANNEL not in spec["log_channels"]:', "if False:", 1),
        spec_edit=drop)


def test_the_stability_accounting_predicate_is_load_bearing(tmp_path):
    def hide(p):
        p["stability"]["dumps_written"] = 8
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("if dumped + refused != runs:", "if False:", 1),
        prov_edit=hide)


def test_the_frame_separation_predicate_is_load_bearing(tmp_path):
    def collapse(p):
        p["frame_measurements"]["separation_ratio"] = 0.25
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            "if not isinstance(ratio, (int, float)) or ratio <= 1:", "if False:", 1),
        prov_edit=collapse)


def test_the_ast_read_site_predicate_is_load_bearing(tmp_path):
    """Removing the AST check must let the hardcoded-in-run() mutant through, proving the plain
    substring scan above it is NOT what catches that mutant."""
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("        if not reads:", "        if False:", 1),
        scenario_edit=_hardcode_ticks_in_run)


def test_the_load_save_predicate_is_load_bearing(tmp_path):
    """Point the scenario at the sibling Trumbles save CONSISTENTLY in spec and provenance, so the
    drift check is satisfied and only the load_save predicate objects."""
    other = "upstream/oolite-tests/Checklist-files/Missions/Trumbles.oolite-save"
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            'if not str(spec["load_save"]).replace("\\\\", "/").endswith(SAVE_SUFFIX):',
            "if False:", 1),
        spec_edit=lambda s: s.update(load_save=other),
        prov_edit=lambda p: p["scenario_knobs"].update(load_save=other))
