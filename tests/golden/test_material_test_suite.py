"""Offline falsifiability tests for scenario 008-material-test-suite (bead oo-qd6). No game.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game. That is the only part able to observe
real engine behaviour, and it is the slowest thing on this box, so it is ONE acceptance line.
Everything falsifiable without a launch is falsified here, where it costs about a second and cannot
be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration.

TWO MUTANTS PER PROPERTY (bead oo-jor's lesson; bead oo-3ya went 13/15 -> 17/17 kills after
decomposing its defences and mutating each separately). For each anti-vacuity property this gate
exists for there is a test that corrupts the DATA and a test that weakens the CHECKER - because
only the second catches a gate that validates data with a validator nobody validates.

NOTHING HERE WRITES TO goldens/ OR TO THE STAGED GOLDEN, AND NOTHING MUTATES A REAL FILE IN PLACE.
The stored dump and the real checker are READ, copied to throwaway temp files, and mutated there.
Restore-on-exit does not run when a process is killed, so there is nothing to restore.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "008-material-test-suite"

# The golden and spec live under tests/golden/pending/ until Jon approves the protected-path
# addition (tools/guardrails.sh refuses a brand-new file under goldens/ without a line in
# tools/rebless-approvals.txt, and a worker may not write one). Both locations are searched so
# landing them is a pure `git mv` with no code change. See pending/008-material-test-suite/LANDING.md.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)

EVIDENCE = os.path.join(HERE, "check_material_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "material_test_suite.py")

sys.path.insert(0, HERE)


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s; looked in %s" % (what, candidates))


GOLDEN = _first(GOLDEN_CANDIDATES, "stored golden")
SPEC = _first(SPEC_CANDIDATES, "spec.json")
PROVENANCE = _first(PROVENANCE_CANDIDATES, "provenance.json")
FRAME = _first(FRAME_CANDIDATES, "frame.grid")


def run(script, *args):
    proc = subprocess.run([sys.executable, script] + list(args), capture_output=True, text=True,
                          cwd=REPO_ROOT)
    return proc.returncode, proc.stdout + proc.stderr


@pytest.fixture()
def golden():
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def spec():
    with open(SPEC, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def provenance():
    with open(PROVENANCE, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def tmpdump(tmp_path):
    """Write a mutated copy of the golden to a THROWAWAY path and return it."""
    def write(data, name="mutant.json"):
        path = tmp_path / name
        path.write_text(json.dumps(data, sort_keys=True, separators=(",", ":")), encoding="utf-8")
        return str(path)
    return write


# =================================================================================================
# The stored golden itself
# =================================================================================================

def test_golden_passes_its_own_evidence_checker():
    rc, out = run(EVIDENCE, GOLDEN, "--label", "stored golden")
    assert rc == 0, out
    assert "MATERIALS applied" in out


def test_golden_is_not_vacuous_against_a_copy(tmp_path):
    """golden_diff must ACCEPT the golden against an untouched copy and REFUSE a self-comparison."""
    copy = tmp_path / "copy.json"
    shutil.copyfile(GOLDEN, copy)
    rc, out = run(DIFF, GOLDEN, str(copy), "--label-left", "golden", "--label-right", "copy")
    assert rc == 0, out
    rc2, out2 = run(DIFF, GOLDEN, GOLDEN)
    assert rc2 == 2, ("golden_diff compared the golden with ITSELF and returned %d instead of "
                      "refusing; zero differences from a self-comparison is not evidence\n%s"
                      % (rc2, out2))


# =================================================================================================
# KNOB PROVENANCE. Bead oo-3ya found a seed that could change with the gate staying green because
# the spec PRINTED the seed but had no PREDICATE on it - and a fresh-run-vs-golden comparison
# cannot catch it, since changing the seed changes BOTH sides. So each knob is asserted equal to
# the value RECORDED IN THE GOLDEN'S PROVENANCE, and each is asserted to be READ by the runner.
# =================================================================================================

KNOBS = ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals")


def test_spec_knobs_equal_the_knobs_the_golden_was_blessed_with(spec, provenance):
    recorded = provenance.get("scenario_knobs")
    assert recorded, ("%s records no scenario_knobs; the seed/system/ticks the golden was BLESSED "
                      "with are unrecorded, so nothing can detect the spec drifting away from them"
                      % PROVENANCE)
    for knob in KNOBS:
        assert knob in recorded, "provenance scenario_knobs does not record %r" % knob
    drift = {k: (recorded[k], spec.get(k)) for k in recorded if spec.get(k) != recorded[k]}
    assert not drift, ("spec.json disagrees with the knobs this golden was blessed with "
                       "(blessed-vs-spec %r). Re-bless deliberately or restore the spec - do NOT "
                       "edit one side to match." % drift)


@pytest.mark.parametrize("knob", [
    "seed", "system_id", "ticks", "tick_seconds", "load_save", "oxp_source", "detail_level",
    "display_model_role", "expected_display_model_key", "expected_display_model_label",
    "backdrop_image", "expected_texture_keys", "expected_ihdr_dimensions",
    "expected_shipdata_keys", "material_sample_keys", "expected_material_sample",
    "expected_oxp_world_scripts", "expected_live_script_versions", "stock_world_scripts",
    "log_channels", "failure_log_channels", "repopulator_handlers",
    "allowed_oxp_standards_errors", "allowed_oxp_standards_error_signatures",
])
def test_every_spec_knob_is_actually_read_by_the_runner(knob, spec):
    """If someone changed this knob, which line goes red? If none, the knob is decoration."""
    assert knob in spec, "spec.json does not pin %r" % knob
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'spec["%s"]' % knob in src, (
        "material_test_suite.py never reads spec[%r]; the knob is decoration - if someone changed "
        "it, no line would go red" % knob)


def test_quantisation_is_the_policy_value(spec, provenance):
    assert spec["quant_decimals"] == 3
    assert provenance.get("quant_decimals") == 3


def test_provenance_names_this_scenarios_tools(provenance):
    assert provenance.get("dump_tool") == "tests/golden/material_test_suite.py"
    assert provenance.get("evidence_checker") == "tests/golden/check_material_evidence.py"


# =================================================================================================
# THE TOLERANCE IS MEASURED, NEVER ADJUSTED
# =================================================================================================

def test_tolerance_is_still_the_measured_value():
    import frame_hash
    tol = frame_hash.derive_tolerance()
    assert abs(tol - 0.004377268476873758) < 1e-12, (
        "frame_hash's derived tolerance has moved from the value bead oo-ae9 measured (now %r). "
        "Re-measure with calibrate.py and re-bless; do NOT adjust it to make a run pass." % tol)


def test_frame_control_is_recorded_and_separated(provenance):
    import frame_hash
    tol = frame_hash.derive_tolerance()
    fc = provenance.get("frame_control")
    assert fc, "provenance records no frame_control; the control arm is unrecorded"
    assert fc["same_scene_distance"] < tol, (
        "the recorded same-scene distance %r is NOT inside the measured tolerance %r; the "
        "instrument's own noise exceeds its threshold" % (fc["same_scene_distance"], tol))
    assert fc["no_model_distance"] / tol > 5, (
        "the recorded no-model distance %r is only %.2fx the measured tolerance; the frame does "
        "not discriminate a run whose material maps reached the screen from one where they did "
        "not" % (fc["no_model_distance"], fc["no_model_distance"] / tol))
    assert fc["tolerance"] == pytest.approx(tol, rel=0, abs=1e-12)


def test_frame_grid_is_the_right_size():
    import frame_hash
    assert os.path.getsize(FRAME) == frame_hash.GRID_CELLS


def test_stored_frame_matches_a_copy_of_itself(tmp_path):
    copy = tmp_path / "copy.grid"
    shutil.copyfile(FRAME, copy)
    rc, out = run(SCRIPT, "--compare-frame", str(copy), FRAME)
    assert rc == 0, out


def test_an_all_black_frame_is_rejected(tmp_path):
    """The artifact a run with nothing on screen produces must be BEYOND the tolerance."""
    black = tmp_path / "black.grid"
    import frame_hash
    black.write_bytes(b"\x00" * frame_hash.GRID_CELLS)
    rc, out = run(SCRIPT, "--compare-frame", str(black), FRAME)
    assert rc == 1, out
    assert '"within": false' in out


# =================================================================================================
# DATA MUTANTS - one per defence, each perturbing exactly one field
# =================================================================================================

def test_data_mutant_world_script_removed(golden, tmpdump):
    golden["evidence"]["oxp_world_scripts"] = []
    golden["evidence"]["oxp_script_versions"] = {}
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "oxp_world_scripts" in out


def test_data_mutant_script_version_changed(golden, tmpdump):
    golden["evidence"]["oxp_script_versions"] = {"oolite-material-test-suite": "9.9"}
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "oxp_script_versions" in out


def test_data_mutant_shipdata_count_off_by_one(golden, tmpdump):
    """ONE quantised unit: 24 -> 23. The smallest possible perturbation of this field."""
    before = golden["evidence"]["material_shipdata_entries"]
    golden["evidence"]["material_shipdata_entries"] = before - 1
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "material_shipdata_entries" in out
    assert str(before) in out and str(before - 1) in out


def test_data_mutant_material_dictionary_emptied(golden, tmpdump):
    """The entry still resolves; only its MATERIAL is gone. The silent half-failure."""
    key = "oolite_shader_test_suite_13"
    golden["evidence"]["material_map_sample"][key]["material_keys"] = []
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "material_map_sample" in out


def test_data_mutant_one_material_property_dropped(golden, tmpdump):
    """One property out of four - the narrowest corruption of the material dictionary."""
    key = "oolite_shader_test_suite_13"
    props = golden["evidence"]["material_map_sample"][key]["material_keys"]
    golden["evidence"]["material_map_sample"][key]["material_keys"] = props[:-1]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "material_map_sample" in out


def test_data_mutant_texture_uploads_emptied(golden, tmpdump):
    golden["evidence"]["material_texture_uploads"] = []
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "material_texture_uploads" in out


def test_data_mutant_specular_map_upload_removed(golden, tmpdump):
    """Only the SPECULAR map's upload is gone - the diffuse and backdrop still uploaded.

    This is the narrow case: a material whose maps PARTIALLY decoded. The gate must name the
    missing key rather than being satisfied by a non-empty list.
    """
    key = "Textures/oolite_shader_test_suite_13_specular.png"
    golden["evidence"]["material_texture_uploads"] = [
        u for u in golden["evidence"]["material_texture_uploads"] if u["key"] != key]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert key in out


def test_data_mutant_upload_dimension_off_by_one(golden, tmpdump):
    """ONE PIXEL. 512 -> 511. If the gate tolerates this it is not checking the image."""
    for upload in golden["evidence"]["material_texture_uploads"]:
        if upload["key"].endswith("13_specular.png"):
            upload["width"] = upload["width"] - 1
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "511" in out


def test_data_mutant_ihdr_record_changed(golden, tmpdump):
    golden["evidence"]["material_map_ihdr"][
        "Textures/oolite_shader_test_suite_13_specular.png"] = [256, 256]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "material_map_ihdr" in out


def test_data_mutant_display_model_absent(golden, tmpdump):
    """What a run that opened the screen with NO model produces."""
    golden["evidence"]["display_model_key"] = None
    golden["evidence"]["display_model_label"] = None
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "display_model_key" in out


def test_data_mutant_display_model_is_a_different_ship(golden, tmpdump):
    golden["evidence"]["display_model_key"] = "cobra3-player"
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "display_model_key" in out


def test_data_mutant_detail_level_fell_back(golden, tmpdump):
    golden["evidence"]["detail_level"] = "DETAIL_LEVEL_MINIMUM"
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "detail_level" in out


def test_data_mutant_log_channel_missing(golden, tmpdump):
    """Drop ONE channel: the empty-failures assertion becomes 'nobody was listening'."""
    golden["evidence"]["log_channels"] = [c for c in golden["evidence"]["log_channels"]
                                          if c != "texture.upload"]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "log_channels" in out


def test_data_mutant_texture_failure_present(golden, tmpdump):
    golden["evidence"]["texture_load_failures"] = [
        "[texture.load.png.failed]: Failed to load oolite_shader_test_suite_13_specular.png"]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "texture_load_failures" in out


def test_data_mutant_a_standards_error_appeared(golden, tmpdump):
    """This fixture HAS a manifest; one such line is a finding, not noise."""
    golden["evidence"]["oxp_standards_errors"] = 1
    golden["evidence"]["oxp_standards_error_signatures"] = [
        "OXP Material Test Suite.oxp has no manifest.plist"]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "oxp_standards_errors" in out


def test_data_mutant_repopulator_not_quieted(golden, tmpdump):
    golden["evidence"]["repopulator_handlers_quieted"] = []
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "repopulator_handlers_quieted" in out


def test_data_mutant_stations_not_quieted(golden, tmpdump):
    golden["evidence"]["stations_quieted"] = 0
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "stations_quieted" in out


def test_data_mutant_world_never_settled(golden, tmpdump):
    golden["evidence"]["world_reached_fixed_point"] = False
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "world_reached_fixed_point" in out


def test_data_mutant_tick_budget_unmet(golden, tmpdump):
    golden["evidence"]["tick_budget_met"] = False
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "tick_budget_met" in out


def test_data_mutant_evidence_block_removed(golden, tmpdump):
    del golden["evidence"]
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "evidence" in out


def test_data_mutant_market_collapsed(golden, tmpdump):
    golden["market"] = {}
    rc, out = run(EVIDENCE, tmpdump(golden))
    assert rc == 1
    assert "market" in out


# =================================================================================================
# CHECKER MUTANTS - a validator nobody validates is a hole one refactor wide (bead oo-jor shipped
# exactly that hole). Each writes a WEAKENED COPY of the real checker to a throwaway path and
# proves that copy now PASSES data the real checker rejects. The real file is never touched.
# =================================================================================================

def _weakened_checker(tmp_path, old, new, name="weak_checker.py"):
    src = open(EVIDENCE, encoding="utf-8").read()
    assert old in src, "checker text to weaken not found: %r" % old
    path = tmp_path / name
    path.write_text(src.replace(old, new, 1), encoding="utf-8")
    return str(path)


def test_checker_mutant_material_sample_comparison_weakened(tmp_path, golden, tmpdump):
    """Turn the material-dictionary equality into a truthiness test - the classic weakening."""
    weak = _weakened_checker(
        tmp_path,
        "    if sample != EXPECTED_MATERIAL_SAMPLE:",
        "    if not sample:")
    golden["evidence"]["material_map_sample"]["oolite_shader_test_suite_13"]["material_keys"] = []
    mutant = tmpdump(golden)
    rc_real, out_real = run(EVIDENCE, mutant)
    rc_weak, _ = run(weak, mutant)
    assert rc_real == 1, out_real
    assert rc_weak == 0, ("the WEAKENED checker still rejected the mutated dump, so this test is "
                          "not exercising the predicate it names - the kill would be attributed "
                          "to the wrong clause")


def test_checker_mutant_upload_dimension_check_removed(tmp_path, golden, tmpdump):
    weak = _weakened_checker(
        tmp_path,
        "            if got != want:",
        "            if False:")
    for upload in golden["evidence"]["material_texture_uploads"]:
        if upload["key"].endswith("13_specular.png"):
            upload["width"] = 1
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_upload_presence_check_removed(tmp_path, golden, tmpdump):
    """Weaken the loop so it only checks maps that ARE present - the realistic weakening.

    NOT `if False: continue`: that leaves the dimension check dereferencing a key that is no longer
    there, so the weakened checker CRASHES rather than passing, and a crash would be scored as a
    kill the predicate did not earn. The honest weakening is a checker that iterates over what the
    dump happens to carry instead of over what the material REQUIRES - which is exactly the shape a
    careless refactor produces.
    """
    weak = _weakened_checker(
        tmp_path,
        "        for key in sorted(EXPECTED_IHDR_DIMENSIONS):",
        "        for key in sorted(set(EXPECTED_IHDR_DIMENSIONS) & set(by_key)):")
    key = "Textures/oolite_shader_test_suite_13_specular.png"
    golden["evidence"]["material_texture_uploads"] = [
        u for u in golden["evidence"]["material_texture_uploads"] if u["key"] != key]
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_display_model_check_removed(tmp_path, golden, tmpdump):
    """The key check is INDEPENDENT of the label check, and this proves it.

    MEASURED: with only `display_model_key` nulled and only the KEY predicate disabled, the
    weakened checker PASSES - the label is untouched and its own predicate is satisfied. So the two
    are not redundant: each defends a different failure (no model drawn at all vs. the wrong model
    drawn), and dropping either one opens a hole the other does not cover.
    """
    weak = _weakened_checker(
        tmp_path,
        '    if ev.get("display_model_key") != EXPECTED_DISPLAY_MODEL_KEY:',
        '    if False:')
    golden["evidence"]["display_model_key"] = None
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_display_model_label_check_removed(tmp_path, golden, tmpdump):
    """The companion: the LABEL predicate, mutated separately, so each is scored on its own."""
    weak = _weakened_checker(
        tmp_path,
        '    if ev.get("display_model_label") != EXPECTED_DISPLAY_MODEL_LABEL:',
        '    if False:')
    golden["evidence"]["display_model_label"] = "something the fixture never said"
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_standards_count_widened(tmp_path, golden, tmpdump):
    weak = _weakened_checker(
        tmp_path,
        "    if count != EXPECTED_STANDARDS_ERRORS:",
        "    if count is not None and count > 99:")
    golden["evidence"]["oxp_standards_errors"] = 4
    golden["evidence"]["oxp_standards_error_signatures"] = []
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_log_channel_check_removed(tmp_path, golden, tmpdump):
    weak = _weakened_checker(
        tmp_path,
        "    if not isinstance(channels, list) or not REQUIRED_LOG_CHANNELS.issubset(set(channels)):",
        "    if False:")
    golden["evidence"]["log_channels"] = []
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_shipdata_count_check_removed(tmp_path, golden, tmpdump):
    weak = _weakened_checker(
        tmp_path,
        "    if entries != EXPECTED_SHIPDATA_ENTRIES:",
        "    if False:")
    golden["evidence"]["material_shipdata_entries"] = 0
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


def test_checker_mutant_detail_level_check_removed(tmp_path, golden, tmpdump):
    weak = _weakened_checker(
        tmp_path,
        '    if ev.get("detail_level") != EXPECTED_DETAIL_LEVEL:',
        '    if False:')
    golden["evidence"]["detail_level"] = "DETAIL_LEVEL_MINIMUM"
    mutant = tmpdump(golden)
    assert run(EVIDENCE, mutant)[0] == 1
    assert run(weak, mutant)[0] == 0


# =================================================================================================
# The runner's own determinism and isolation properties, asserted on its source
# =================================================================================================

def test_seed_reaches_the_game():
    console_py = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py")
    assert os.path.isfile(console_py), "the console transport is missing at %s" % console_py
    src = open(console_py, encoding="utf-8").read()
    assert "OO_RANDOM_SEED" in src, (
        "console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game")
    runner = open(SCRIPT, encoding="utf-8").read()
    assert "seed=seed" in runner, "material_test_suite.py does not pass seed= to DebugConsole"


def test_run_is_isolated_from_sibling_consoles():
    src = open(SCRIPT, encoding="utf-8").read()
    assert "reserve_port" in src, (
        "no private console port: on the shared 8563 a sibling worker's console can capture and "
        "quit the game seconds in and the run still exits 0 (bead oo-het)")
    assert "_write_console_config" in src, (
        "no debugConfig.plist is written; the game DIALS OUT to the port named there "
        "(OODebugSupport.m:67-80)")


def test_staging_directory_is_not_called_addons():
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'os.path.join(artifact_dir, "addons")' not in src, (
        "<artifact>/addons IS <artifact>/../AddOns case-insensitively, so the game finds the "
        "expansion at TWO roots (bead oo-3ya)")
    assert '"oxp-stage"' in src


def test_no_manifest_is_fabricated_or_removed():
    """This fixture HAS a manifest; the runner must neither write nor delete one.

    NARROWER THAN BEAD oo-3ya's VERSION, DELIBERATELY. 012's guard banned the STRING
    "manifest.plist" anywhere in executable code, which was right for a NOMANIF fixture whose
    scenario had no legitimate reason to name the file. This scenario's whole standards decision
    rests on the manifest EXISTING, and its refusal message says so - banning the string would
    force the gate to explain itself less clearly, which is the wrong trade. What must not happen
    is a WRITE, so that is what is asserted: no `manifest.plist` path is ever constructed, opened,
    copied or removed.
    """
    import ast
    src = open(SCRIPT, encoding="utf-8").read()
    tree = ast.parse(src)
    bad = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        target = ast.unparse(node.func)
        if not any(w in target for w in ("open", "write", "copy", "remove", "unlink", "rmtree",
                                         "makedirs", "path.join")):
            continue
        rendered = ast.unparse(node)
        if "manifest.plist" in rendered:
            bad.append(rendered)
    assert not bad, (
        "material_test_suite.py constructs or writes a manifest.plist path in %r. The fixture's "
        "own manifest must be used exactly as it is - fabricating or deleting it would falsify the "
        "thing under test and would be a write into expansion content." % bad)


def test_the_cast_is_pinned_to_literal_shipkey_form(spec):
    """Bead oo-izi: a bare role is a RANROT draw and a fixed seed does NOT fix the cast."""
    role = spec["display_model_role"]
    assert role.startswith("[") and role.endswith("]"), (
        "display_model_role is %r, not literal [shipKey] form. mission.runScreen's `model` goes to "
        "makeDemoShipWithRole: -> newShipWithRole:, which for a BARE role draws from a probability "
        "set (Universe.m:4008 -> :3948 -> OOShipRegistry.m:276-279) at a position that depends on "
        "frames burned earlier - so a fixed seed does NOT fix which ship appears. In [key] form "
        "OOShipRegistry.m:1229 registers the key at probability 1.0 and no draw is made." % role)
    assert role[1:-1] == spec["expected_display_model_key"]


def test_the_demo_model_does_not_spin():
    """spinModel must be false: a spinning demo ship is oriented from the WALL CLOCK."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert '"spinModel": False' in src, (
        "the mission screen does not pin spinModel=False. makeDemoShipWithRole:spinning: "
        "(Universe.m:5827-5834) sets demoRate=1.0 when spinning and ShipEntity.m:2337-2342 then "
        "derives the model's orientation from [UNIVERSE getTime], so every frame would differ.")


def test_runner_reads_the_golden_and_spec_from_the_guarded_path_first():
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json")' in src
    assert 'os.path.join(HERE, "scenarios", SCENARIO, "spec.json")' in src


def test_spec_allows_no_standards_errors_at_all(spec):
    assert spec["allowed_oxp_standards_errors"] == 0
    assert spec["allowed_oxp_standards_error_signatures"] == []


def test_expected_shipdata_keys_match_the_fixture_on_disk(spec):
    """The 24 keys are not a typed list: they are read out of the fixture's own shipdata.plist."""
    import re
    path = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"), "Config", "shipdata.plist")
    text = open(path, encoding="utf-8", errors="replace").read()
    keys = set(re.findall(r"^\t(oolite_\w+) =$", text, re.M))
    keys.discard("oolite_shader_test_suite_base")  # is_template, not a material under test
    assert keys == set(spec["expected_shipdata_keys"]), (
        "spec expected_shipdata_keys disagrees with the fixture's Config/shipdata.plist: only in "
        "spec %r, only on disk %r"
        % (sorted(set(spec["expected_shipdata_keys"]) - keys),
           sorted(keys - set(spec["expected_shipdata_keys"]))))


def test_expected_ihdr_dimensions_match_the_files_on_disk(spec):
    """The pinned pixel sizes are checked against the IHDR chunks of the real files."""
    sys.path.insert(0, HERE)
    import material_test_suite as mts
    for key, want in spec["expected_ihdr_dimensions"].items():
        path = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"), *key.split("/"))
        assert os.path.isfile(path), "the fixture has no %s" % key
        assert list(mts.png_ihdr_dimensions(path)) == list(want), (
            "spec pins %r at %r but its IHDR chunk reads %r"
            % (key, want, list(mts.png_ihdr_dimensions(path))))


def test_this_fixture_really_does_ship_a_manifest(spec):
    """The decision not to allow-list anything rests on this fact; assert it rather than recall it."""
    path = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"), "manifest.plist")
    assert os.path.isfile(path), (
        "%s has no manifest.plist. This scenario's standards predicate is 'exactly zero, empty "
        "allow-list' precisely because it does; without the manifest the engine emits two "
        "[oxp-standards.error] lines (bead oo-kcrw NOMANIF) and the predicate must be "
        "reconsidered deliberately, not relaxed." % spec["oxp_source"])
    assert "org.oolite.material-test-suite" in open(path, encoding="utf-8").read()
