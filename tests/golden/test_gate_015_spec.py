"""Mutation self-test for tests/golden/gate_015_spec.py. No game, no build.

WHY THIS FILE EXISTS
--------------------
`gate_015_spec.py` is the line that catches a determinism knob drifting away from the golden it
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
SCENARIO = "015-trumbles"

GATE = os.path.join(HERE, "gate_015_spec.py")


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

    shutil.copy(GATE, root / "tests" / "golden" / "gate_015_spec.py")
    shutil.copy(os.path.join(HERE, "trumbles_load.py"), root / "tests" / "golden" / "trumbles_load.py")
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
        edit_text(root / "tests" / "golden" / "gate_015_spec.py", gate_edit)
    if scenario_edit:
        edit_text(root / "tests" / "golden" / "trumbles_load.py", scenario_edit)
    if spec_edit:
        edit_json(staged / "spec.json", spec_edit)
    if prov_edit:
        edit_json(staged / "provenance.json", prov_edit)

    return subprocess.run([sys.executable, str(root / "tests" / "golden" / "gate_015_spec.py")],
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
    assert sep, "trumbles_load.py has no run(); this mutation is stale"
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


def test_raising_the_award_count_past_the_deterministic_prefix_is_caught(tmp_path):
    """PLAYER_MAX_TRUMBLES/6 = 4 is a MEASURED boundary: the fifth award consults ranrot_rand()
    and three runs at this seed diverged there. Raising it makes the golden unreproducible."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(trumble_awards=8))
    assert result.returncode == 1, _out(result)
    assert "deterministic prefix" in _out(result)


def test_a_population_arithmetic_that_does_not_close_is_caught(tmp_path):
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(expected_trumble_count=9))
    assert result.returncode == 1, _out(result)
    assert "arithmetic does not close" in _out(result)


def test_pointing_the_scenario_at_a_different_save_is_caught(tmp_path):
    """This scenario exists to load the 1.75-era checklist Trumbles save; aimed elsewhere it is a
    different scenario wearing this one's golden."""
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(
        load_save="Resources/Scenarios/oolite-standard.oolite-save"))
    assert result.returncode == 1, _out(result)
    assert "Trumbles.oolite-save" in _out(result)


def test_dropping_the_load_progress_channel_is_caught(tmp_path):
    """load.progress is OFF by default; without it the engine's own proof that -load was honoured
    never reaches the dump and the cheat-message check becomes vacuous."""
    def drop(s):
        s["log_channels"] = [c for c in s["log_channels"] if c != "load.progress"]
    result = _gate_tree(tmp_path, spec_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "load.progress" in _out(result)


def test_a_truncated_load_stage_sequence_is_caught(tmp_path):
    def truncate(s):
        s["load_progress_stages"] = s["load_progress_stages"][:6]
    result = _gate_tree(tmp_path, spec_edit=truncate)
    assert result.returncode == 1, _out(result)
    assert "load.progress stage" in _out(result)


def test_dropping_the_trumbles_mission_variable_from_the_key_set_is_caught(tmp_path):
    """The bead names mission_trumbles as the field the dump must carry."""
    def drop(s):
        s["expected_mission_variable_keys"] = [k for k in s["expected_mission_variable_keys"]
                                               if k != s["mission_trumbles_key"]]
    result = _gate_tree(tmp_path, spec_edit=drop)
    assert result.returncode == 1, _out(result)
    assert "mission_trumbles_key" in _out(result)


def test_coarsening_the_quantisation_is_caught(tmp_path):
    result = _gate_tree(tmp_path, spec_edit=lambda s: s.update(quant_decimals=1))
    assert result.returncode == 1, _out(result)
    assert "storage policy is 3" in _out(result)


def test_a_stability_sweep_with_unaccounted_runs_is_caught(tmp_path):
    """A REFUSAL is not a DIFFERENCE, but neither may a run simply vanish from the tally."""
    def hide(p):
        p["stability"]["refused"] = 0
    result = _gate_tree(tmp_path, prov_edit=hide)
    assert result.returncode == 1, _out(result)
    assert "every run's outcome must be recorded" in _out(result)


def test_a_sweep_with_two_distinct_digests_is_caught(tmp_path):
    def split(p):
        p["stability"]["distinct_dump_digests"] = ["a" * 64, "b" * 64]
    result = _gate_tree(tmp_path, prov_edit=split)
    assert result.returncode == 1, _out(result)
    assert "distinct dump digest" in _out(result)


def test_asserting_the_rejected_frame_tolerance_is_caught(tmp_path):
    """The tolerance was MEASURED and REJECTED for this scenario (the animated trumble HUD puts
    same-scene pairs above it and a zero-trumble control inside the same band). Flipping it back
    on is how a future agent re-derives the flake."""
    def flip(p):
        p["frame_tolerance"]["asserted"] = True
    result = _gate_tree(tmp_path, prov_edit=flip)
    assert result.returncode == 1, _out(result)
    assert "measured and REJECTED" in _out(result)


def test_dropping_the_frame_liveness_assertion_is_caught(tmp_path):
    """Liveness is the one frame property the measurements DO support; without it the frame
    artifact is entirely unpinned and a run that died before drawing passes."""
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


def test_a_missing_provenance_is_a_refusal_not_a_verdict(tmp_path):
    """rc=2 means 'I cannot tell you', never 'they match' - the repo's rc convention."""
    def wipe(p):
        p.clear()
    root = tmp_path / "t"
    result = _gate_tree(tmp_path)
    assert result.returncode == 0
    os.remove(root / "tests" / "golden" / "pending" / SCENARIO / "provenance.json")
    again = subprocess.run([sys.executable, str(root / "tests" / "golden" / "gate_015_spec.py")],
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
    assert red.returncode == 1, "baseline: the unmutated gate did NOT reject the bad input: %s" % _out(red)
    green = _gate_tree(tmp_path / "green", gate_edit=gate_edit, spec_edit=spec_edit,
                       prov_edit=prov_edit, scenario_edit=scenario_edit)
    assert green.returncode == 0, (
        "MISKILL: with this defence removed the bad input was STILL rejected, so some other check "
        "caught it and this defence is not what defends the property: %s" % _out(green))


def test_the_award_prefix_predicate_is_load_bearing(tmp_path):
    """Raise the awards CONSISTENTLY in the spec AND in provenance - i.e. a deliberate re-bless
    at a non-deterministic award count. The drift check is satisfied and the arithmetic closes,
    so only the measured-prefix predicate stands between that and a green."""
    def spec_edit(s):
        s["trumble_awards"] = 8
        s["expected_trumble_count"] = s["expected_saved_trumble_count"] + 8

    def prov_edit(p):
        p["scenario_knobs"]["trumble_awards"] = 8
        p["scenario_knobs"]["expected_trumble_count"] = (
            p["scenario_knobs"]["expected_saved_trumble_count"] + 8)

    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("if awards != DETERMINISTIC_AWARD_PREFIX:", "if False:", 1),
        spec_edit=spec_edit, prov_edit=prov_edit)


def test_the_provenance_drift_predicate_is_load_bearing(tmp_path):
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            "drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}",
            "drift = {}", 1),
        spec_edit=lambda s: s.update(seed=31337))


def test_the_log_channel_predicate_is_load_bearing(tmp_path):
    def drop(s):
        s["log_channels"] = [c for c in s["log_channels"] if c != "load.progress"]
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("if REQUIRED_LOG_CHANNEL not in channels:",
                                      "if False:", 1),
        spec_edit=drop)


def test_the_stability_accounting_predicate_is_load_bearing(tmp_path):
    def hide(p):
        p["stability"]["refused"] = 0
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("if dumped + refused != runs:", "if False:", 1),
        prov_edit=hide)


def test_the_frame_tolerance_predicate_is_load_bearing(tmp_path):
    def flip(p):
        p["frame_tolerance"]["asserted"] = True
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace('if tolerance.get("asserted") is not False:',
                                      "if False:", 1),
        prov_edit=flip)


def test_the_ast_read_site_predicate_is_load_bearing(tmp_path):
    """Removing the AST check must let the hardcoded-in-run() mutant through, proving the plain
    substring scan above it is NOT what catches that mutant."""
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace("        if not reads:", "        if False:", 1),
        scenario_edit=_hardcode_ticks_in_run)


def test_the_load_save_predicate_is_load_bearing(tmp_path):
    """Point the scenario at the stock save CONSISTENTLY in spec and provenance, so the drift
    check is satisfied and only the load_save predicate objects."""
    other = "Resources/Scenarios/oolite-standard.oolite-save"
    _defence_is_load_bearing(
        tmp_path,
        gate_edit=lambda t: t.replace(
            'if not str(spec["load_save"]).replace("\\\\", "/").endswith(SAVE_SUFFIX):',
            "if False:", 1),
        spec_edit=lambda s: s.update(load_save=other),
        prov_edit=lambda p: p["scenario_knobs"].update(load_save=other))
