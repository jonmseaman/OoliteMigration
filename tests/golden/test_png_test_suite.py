"""Offline falsifiability tests for scenario 010-png-test-suite (bead oo-gxp). No game, no build.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game. That is the only part that can observe
real engine behaviour, and it is also the slowest thing on this box, so it is ONE acceptance line.
Everything that can be falsified without a launch is falsified here, where it costs about a second
and cannot be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration.

TWO MUTANTS PER PROPERTY (bead oo-jor's lesson, and oo-3ya's 13/15 -> 17/17). For the anti-vacuity
properties this gate exists for, there is a test that corrupts the DATA and a test that weakens the
CHECKER - because only the second catches a gate that validates data with a validator nobody
validates. Where a property is held by TWO defences, each is removed separately and the input must
STILL be rejected, and a final mutant removes BOTH and asserts the verdict then FLIPS - which is
what proves the pair is real redundancy rather than two names for one check.

The checker mutants write a COPY of the checker to a temp dir; the real file is never touched.

NOTHING HERE WRITES TO goldens/ OR TO THE STAGED GOLDEN. The stored dump is READ, copied to a
throwaway temp file, and mutated there.
"""

import ast
import json
import os
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "010-png-test-suite"

# The golden, frame and spec live under tests/golden/pending/ until Jon approves the
# protected-path addition (tools/guardrails.sh refuses ANY change under goldens/ - CREATE as well
# as MODIFY - without a re-bless line in tools/rebless-approvals.txt, proven by A/B control in bead
# oo-8ij). Both locations are searched so landing them is a pure `git mv` with no code change. See
# tests/golden/pending/010-png-test-suite/LANDING.md.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

EVIDENCE = os.path.join(HERE, "check_png_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "png_test_suite.py")

sys.path.insert(0, HERE)

import frame_hash  # noqa: E402


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s; looked in %s" % (what, candidates))


GOLDEN = _first(GOLDEN_CANDIDATES, "stored golden")
FRAME = _first(FRAME_CANDIDATES, "stored reference frame grid")
SPEC = _first(SPEC_CANDIDATES, "spec.json")
PROVENANCE = _first(PROVENANCE_CANDIDATES, "provenance.json")


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
def scratch():
    path = tempfile.mkdtemp(prefix="oo_gxp_test_")
    yield path
    shutil.rmtree(path, ignore_errors=True)


def write(scratch, name, data):
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    return path


def mutated_checker(scratch, old, new, name="checker_mutant.py"):
    """A COPY of the evidence checker with one defence weakened. The real file is untouched."""
    with open(EVIDENCE, "r", encoding="utf-8") as handle:
        src = handle.read()
    assert old in src, "the checker no longer contains %r; this mutation is stale" % old
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src.replace(old, new, 1))
    return path


# --- the stored golden is itself real -----------------------------------------------------

def test_the_stored_golden_proves_a_png_was_decoded():
    """The green direction. If this fails, every other test here is measuring a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "PNGTestSuite live and a PNG DECODED" in out, out


def test_the_stored_golden_is_not_a_dead_run(golden, spec):
    ev = golden["evidence"]
    assert ev["oxp_staged"] is True, ev
    assert sorted(ev["oxp_world_scripts"]) == sorted(spec["expected_oxp_world_scripts"]), ev
    assert ev["oxp_script_versions"] == spec["expected_live_script_versions"], ev
    assert ev["png_shipdata_entries"] == spec["png_test_count"], ev
    assert ev["png_texture_uploads"], ev
    assert ev["ticks"] >= 1 and ev["tick_budget_met"] is True, ev


def test_the_stored_golden_is_a_real_world_state(golden):
    assert len(golden["entities"]) >= 2, golden["entities"]
    assert len(golden["market"]) >= 10, golden["market"]
    assert golden["player"]["ship"], golden["player"]


def test_the_stored_frame_grid_is_a_real_grid():
    """4096 bytes of luminance, not a stub. A grid of one repeated value would compare equal to
    every other grid of that value and the frame assertion would be decoration."""
    with open(FRAME, "rb") as handle:
        grid = handle.read()
    assert len(grid) == frame_hash.GRID_CELLS, len(grid)
    assert len(set(grid)) > 16, (
        "the stored frame grid has only %d distinct luminance values; a near-flat grid carries no "
        "image and any other flat grid would compare within tolerance of it" % len(set(grid)))


# --- the spec really pins the knobs, and the script really reads them ---------------------

def test_spec_pins_every_determinism_knob(spec):
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "oxp_source"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3, spec["quant_decimals"]
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1, spec["ticks"]


def test_the_script_reads_every_knob_the_spec_pins():
    """A knob nobody reads is decoration, which is how a 'pinned' scenario silently drifts."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    for key in ("seed", "ticks", "tick_seconds", "system_id", "load_save", "oxp_source",
                "stock_world_scripts", "expected_oxp_world_scripts",
                "expected_live_script_versions", "png_test_count", "png_sample_indices",
                "png_shipdata_key_prefix", "expected_diffuse_map_sample", "expected_texture_key",
                "expected_ihdr_dimensions", "backdrop_image", "backdrop_image_relpath",
                "texture_log_channels", "allowed_oxp_standards_errors",
                "allowed_oxp_standards_error_signatures"):
        assert 'spec["%s"]' % key in src, "png_test_suite.py never reads spec[%r]" % key


def test_the_scenario_reserves_a_private_port_and_writes_the_plist():
    """The game DIALS OUT to the port in debugConfig.plist (OODebugSupport.m:67-80). On the
    shared 8563 a sibling worker's console can capture and quit the game seconds in while the run
    still exits rc=0 - a fully vacuous pass (bead oo-het/oo-gla)."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert "reserve_port" in src, "png_test_suite.py does not reserve a private console port"
    assert "_write_console_config" in src, "png_test_suite.py writes no debugConfig.plist"


def test_the_staging_dir_is_not_named_addons():
    """MEASURED by bead oo-3ya: `<artifact>/addons` IS `<artifact>/../AddOns` case-insensitively,
    so the game found the expansion at TWO roots and logged FOUR missing-manifest errors."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert '"oxp-stage"' in src, "the staging directory name changed"
    assert 'os.path.join(artifact_dir, "addons")' not in src, (
        "the staging directory is named `addons` again, which collides with the game's own "
        "../AddOns root on a case-insensitive filesystem and loads the expansion twice")


def test_no_manifest_is_staged(spec):
    """The bead's deliberate CHOICE: PNGTestSuite's missing manifest is TOLERATED EXACTLY, not
    papered over by writing one. Staging a manifest would fabricate content the fixture does not
    have - a falsification of the thing under test and a write into expansion content.

    Checked on the AST rather than on the text, because the text says `manifest.plist` many times
    in prose that explains the tolerance - a grep would match the explanation, not the act.
    """
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    tree = ast.parse(src)
    docstrings = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            body = getattr(node, "body", None)
            if (body and isinstance(body[0], ast.Expr)
                    and isinstance(body[0].value, ast.Constant)
                    and isinstance(body[0].value.value, str)):
                docstrings.add(id(body[0].value))
    offenders = [n.value for n in ast.walk(tree)
                 if isinstance(n, ast.Constant) and isinstance(n.value, str)
                 and id(n) not in docstrings and "manifest.plist" in n.value]
    assert not offenders, (
        "png_test_suite.py names manifest.plist in executable code (%r); this scenario must "
        "TOLERATE the missing manifest exactly, never fabricate one" % offenders)

    staging = next(n for n in ast.walk(tree)
                   if isinstance(n, ast.FunctionDef) and n.name == "stage_oxp")
    calls = {ast.unparse(n.func) for n in ast.walk(staging) if isinstance(n, ast.Call)}
    assert "open" not in calls, "stage_oxp opens a file; it must only copy the fixture tree"
    assert "shutil.copytree" in calls, "stage_oxp no longer copies the fixture tree verbatim"

    src_oxp = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    assert not os.path.isfile(os.path.join(src_oxp, "manifest.plist")), (
        "the fixture now HAS a manifest.plist, so the NOMANIF allowance of exactly 2 errors is "
        "stale and this scenario's error pin must be re-measured")


def test_the_fixture_still_ships_exactly_one_png_and_153_entries(spec):
    """The scenario's shape is derived from the fixture, so a change to the fixture must break
    the gate rather than silently change what it means.

    PNGTestSuite's README states the 153 PNG Suite images are NOT included (licensing), and the
    scenario is built on that: the texture evidence is about the ONE image that IS shipped. If the
    images ever arrive, this scenario needs redesigning, not a tolerance.
    """
    src_oxp = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    images = sorted(f for f in os.listdir(os.path.join(src_oxp, "Images"))
                    if f.lower().endswith(".png"))
    assert images == [spec["backdrop_image"]], (
        "the fixture's Images/ now holds %r, not just the backdrop. The scenario's texture "
        "evidence names ONE image because that is all the fixture ships; a different set means "
        "this scenario must be redesigned rather than retuned." % images)

    shipdata = os.path.join(src_oxp, "Config", "shipdata.plist")
    with open(shipdata, encoding="utf-8") as handle:
        text = handle.read()
    entries = text.count('like_ship = "oolite_png_test_suite_base"')
    assert entries == spec["png_test_count"], (
        "the fixture defines %d test-cube entries but the spec pins %d; the merged-registry count "
        "the gate asserts on is derived from the fixture and they have drifted apart"
        % (entries, spec["png_test_count"]))


def test_the_expected_ihdr_matches_the_file_on_disk(spec):
    """THE DERIVATION AND THE LITERAL, both (bead oo-vwd). The run parses the IHDR chunk off the
    staged file and checks the engine's upload line against it; the literal in spec.json keeps a
    broken IHDR parse from quietly redefining the test. Here they are checked against each other.
    """
    sys.path.insert(0, HERE)
    import png_test_suite

    png = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"),
                       *spec["backdrop_image_relpath"].split("/"))
    assert list(png_test_suite.png_ihdr_dimensions(png)) == list(
        spec["expected_ihdr_dimensions"]), (
        "the fixture's PNG is not the size the spec pins; either the fixture changed or the IHDR "
        "parse is reading the wrong bytes")


def test_the_texture_upload_regex_matches_the_engines_real_format():
    """The evidence is scraped out of a log line, so the SCRAPER is pinned against the format
    string in the engine's own source - not against a line somebody remembered.

    OOConcreteTexture.m:525 emits
        OOLog(@"texture.upload", @"Uploaded texture %u (%ux%u pixels, %@)", ...)
    A refactor of that line silently empties png_texture_uploads, which the checker would then
    report as 'no PNG was decoded' - a confusing red. This test makes the drift itself the red.
    """
    import png_test_suite

    source = os.path.join(REPO_ROOT, "upstream", "oolite", "src", "Core", "Materials",
                          "OOConcreteTexture.mm")
    with open(source, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    assert '@"Uploaded texture %u (%ux%u pixels, %@)"' in text, (
        "OOConcreteTexture.m no longer emits the [texture.upload] line this scenario scrapes; the "
        "texture-decode evidence must be re-derived from whatever replaced it")

    sample = ("07:16:48.087 [texture.upload]: Uploaded texture 8 "
              "(1024x512 pixels, Images/oolite_material_test_suite_backdrop.png:0x2017/0/0)")
    match = png_test_suite.TEXTURE_UPLOAD_RE.search(sample)
    assert match, "the scraper does not match a real [texture.upload] line"
    assert (int(match.group(1)), int(match.group(2))) == (1024, 512), match.groups()
    assert png_test_suite.normalise_texture_key(
        match.group(3), "PNGTestSuite.oxp") == "Images/oolite_material_test_suite_backdrop.png"


def test_the_texture_channels_are_off_by_default_in_logcontrol():
    """WHY the run must switch them on, pinned against the engine's own configuration.

    If upstream ever turns texture.upload on by default, `enable_texture_logging`'s read-back
    becomes a no-op rather than a necessity, and the docstring explaining it becomes a lie. Better
    to learn that from a red test than from a confusing green one.
    """
    logcontrol = os.path.join(REPO_ROOT, "upstream", "oolite", "Resources", "Config",
                              "logcontrol.plist")
    with open(logcontrol, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    assert "$textureDebug" in text and "texture.upload" in text, text[:400]
    assert "$textureDebug\t\t\t\t\t\t\t= no;" in text or "$textureDebug = no;" in text, (
        "logcontrol.plist no longer disables $textureDebug by default; the run's channel "
        "enable-and-read-back may no longer be load-bearing and the reasoning must be re-checked")


# --- DATA mutants: corrupt the dump, the checker must refuse -------------------------------

def test_a_dump_with_no_expansion_scripts_is_refused(golden, scratch):
    golden["evidence"]["oxp_world_scripts"] = []
    rc, out = run(EVIDENCE, write(scratch, "no_scripts.json", golden))
    assert rc == 1, out
    assert "oxp_world_scripts" in out, out


def test_a_dump_with_a_different_expansion_is_refused(golden, scratch):
    golden["evidence"]["oxp_world_scripts"] = ["some-other-oxp-script"]
    rc, out = run(EVIDENCE, write(scratch, "other.json", golden))
    assert rc == 1, out
    assert "not PNGTestSuite's measured set" in out, out


def test_a_dump_whose_script_is_a_bare_key_is_refused(golden, scratch):
    golden["evidence"]["oxp_script_versions"] = {}
    rc, out = run(EVIDENCE, write(scratch, "keys_only.json", golden))
    assert rc == 1, out
    assert "oxp_script_versions" in out, out


def test_a_dump_with_a_WRONG_script_version_is_refused(golden, scratch):
    """The non-empty-but-wrong case, which the emptiness test above does NOT reach."""
    golden["evidence"]["oxp_script_versions"] = {"oolite-png-test-suite": "999"}
    rc, out = run(EVIDENCE, write(scratch, "wrong_version.json", golden))
    assert rc == 1, out
    assert "but the measured value is" in out, out


def test_a_dump_with_NO_TEXTURE_UPLOADS_is_refused(golden, scratch):
    """THE CENTRAL ANTI-VACUITY CLAIM OF THIS SCENARIO.

    A run in which the PNG loader produced nothing writes the same clean log and the same quiet
    world dump as a run in which it worked. This is the field that separates them, and a dump
    carrying an empty list must never be accepted as a texture-decoding run.
    """
    golden["evidence"]["png_texture_uploads"] = []
    rc, out = run(EVIDENCE, write(scratch, "no_uploads.json", golden))
    assert rc == 1, out
    assert "NO PNG FROM THIS EXPANSION WAS DECODED" in out, out


def test_a_dump_whose_upload_names_a_DIFFERENT_image_is_refused(golden, scratch):
    """Non-empty but wrong: some other texture uploading does not prove THIS image decoded."""
    golden["evidence"]["png_texture_uploads"] = [
        {"key": "Images/some_other_texture.png", "width": 1024, "height": 512}]
    rc, out = run(EVIDENCE, write(scratch, "other_upload.json", golden))
    assert rc == 1, out
    assert "no [texture.upload] entry named" in out, out


def test_a_dump_whose_upload_is_the_WRONG_SIZE_is_refused(golden, scratch):
    """One quantised unit on the dimension: 1024x512 -> 1024x511. The size is what ties the
    upload line to the bytes in the file, so it must not be a formality."""
    golden["evidence"]["png_texture_uploads"] = [
        {"key": "Images/oolite_material_test_suite_backdrop.png", "width": 1024, "height": 511}]
    rc, out = run(EVIDENCE, write(scratch, "wrong_size.json", golden))
    assert rc == 1, out
    assert "is not this image" in out, out


def test_a_dump_whose_IHDR_disagrees_with_the_file_is_refused(golden, scratch):
    golden["evidence"]["png_ihdr_dimensions"] = [512, 512]
    rc, out = run(EVIDENCE, write(scratch, "bad_ihdr.json", golden))
    assert rc == 1, out
    assert "png_ihdr_dimensions" in out, out


def test_a_dump_with_PNG_LOADER_FAILURES_is_refused(golden, scratch):
    golden["evidence"]["png_load_failures"] = [
        "***** A PNG loading error occurred for basi0g01.png: bad signature"]
    rc, out = run(EVIDENCE, write(scratch, "png_fail.json", golden))
    assert rc == 1, out
    assert "did not decode cleanly" in out, out


def test_a_dump_whose_log_channels_were_OFF_is_refused(golden, scratch):
    """The absence assertion is only worth anything if somebody was listening.

    With texture.upload off, `png_load_failures == []` means 'not logged', which is exactly the
    reading a texture scenario must not be allowed to make.
    """
    golden["evidence"]["texture_log_channels"] = []
    rc, out = run(EVIDENCE, write(scratch, "no_channels.json", golden))
    assert rc == 1, out
    assert "nobody was listening" in out, out


def test_a_dump_with_an_incomplete_shipdata_merge_is_refused(golden, scratch):
    """One entry short of 153: the plist was merged partially, so the gate is not looking at the
    registry the scenario is about."""
    golden["evidence"]["png_shipdata_entries"] = 152
    rc, out = run(EVIDENCE, write(scratch, "short_shipdata.json", golden))
    assert rc == 1, out
    assert "png_shipdata_entries" in out, out


def test_a_dump_with_a_wrong_diffuse_map_sample_is_refused(golden, scratch):
    golden["evidence"]["png_diffuse_map_sample"]["1"] = "not_a_real_image.png"
    rc, out = run(EVIDENCE, write(scratch, "bad_sample.json", golden))
    assert rc == 1, out
    assert "png_diffuse_map_sample" in out, out


def test_a_third_missing_manifest_error_is_refused(golden, scratch):
    golden["evidence"]["oxp_standards_errors"] = 3
    rc, out = run(EVIDENCE, write(scratch, "three.json", golden))
    assert rc == 1, out
    assert "exactly 2 is allowed" in out, out


def test_zero_missing_manifest_errors_is_also_refused(golden, scratch):
    """The allowance is two-sided: zero means the expansion was never parsed."""
    golden["evidence"]["oxp_standards_errors"] = 0
    golden["evidence"]["oxp_standards_error_signatures"] = []
    rc, out = run(EVIDENCE, write(scratch, "zero.json", golden))
    assert rc == 1, out
    assert "oxp_standards_errors" in out, out


def test_a_different_oxp_standards_error_is_refused(golden, scratch):
    golden["evidence"]["oxp_standards_error_signatures"] = ["Bad subentity definition found"]
    rc, out = run(EVIDENCE, write(scratch, "other_err.json", golden))
    assert rc == 1, out
    assert "NOT the known missing-manifest message" in out, out


def test_a_dump_that_never_ran_its_ticks_is_refused(golden, scratch):
    golden["evidence"]["tick_budget_met"] = False
    rc, out = run(EVIDENCE, write(scratch, "no_ticks.json", golden))
    assert rc == 1, out
    assert "tick_budget_met" in out, out


def test_a_dump_taken_with_the_station_still_launching_traffic_is_refused(golden, scratch):
    """MEASURED: with only the system populator off, ten runs gave five different dumps.
    StationEntity -update has its own launch schedule; the second suppression is load-bearing."""
    golden["evidence"]["stations_quieted"] = 0
    rc, out = run(EVIDENCE, write(scratch, "noisy_station.json", golden))
    assert rc == 1, out
    assert "stations_quieted" in out, out


def test_a_dump_taken_on_the_wrong_screen_is_refused(golden, scratch):
    golden["evidence"]["gui_screen"] = "GUI_SCREEN_STATUS"
    rc, out = run(EVIDENCE, write(scratch, "wrong_screen.json", golden))
    assert rc == 1, out
    assert "gui_screen" in out, out


def test_a_dump_with_no_evidence_block_is_refused(golden, scratch):
    del golden["evidence"]
    rc, out = run(EVIDENCE, write(scratch, "bare.json", golden))
    assert rc == 1, out
    assert "no `evidence` object" in out, out


# --- the frame assertion, and that it can go red -------------------------------------------

def test_the_stored_frame_matches_itself_within_the_measured_tolerance(scratch):
    """Green direction, and a sanity check on the comparator: a grid must match a copy of itself."""
    copy = os.path.join(scratch, "copy.grid")
    shutil.copyfile(FRAME, copy)
    rc, out = run(SCRIPT, "--compare-frame", copy, FRAME)
    assert rc == 0, out
    assert '"within": true' in out, out


def test_a_BLACK_frame_is_beyond_the_tolerance(scratch):
    """THE OXP-ABSENT CONTROL, replayed offline.

    MEASURED with a real launch: the identical scenario with the OXP NOT staged renders a BLACK
    mission screen, because with no expansion there is no such background image. Staged vs absent
    scored 0.140094, which is 32.00x the measured tolerance; two separate launches of the STAGED
    scenario scored 0.000489, 0.11x the tolerance. That 290-fold separation is why the frame is a
    texture-decode assertion and not decoration.

    This test reproduces the absent case's ARTIFACT (an all-black grid) without launching, so the
    red direction is exercised every run rather than once at bless time.
    """
    black = os.path.join(scratch, "black.grid")
    with open(black, "wb") as handle:
        handle.write(b"\x00" * frame_hash.GRID_CELLS)
    rc, out = run(SCRIPT, "--compare-frame", black, FRAME)
    assert rc == 1, out
    assert '"within": false' in out, out


def test_a_one_unit_luminance_perturbation_stays_within_tolerance(scratch):
    """The tolerance is NOT zero, and this is why it must not be: llvmpipe is not bit-reproducible
    (bead oo-ae9 measured 0 of 3 same-scene pairs byte-identical). A single-cell +1 must pass, or
    the gate would flake on renderer noise instead of catching a texture failure."""
    with open(FRAME, "rb") as handle:
        grid = bytearray(handle.read())
    grid[0] = min(255, grid[0] + 1)
    path = os.path.join(scratch, "nudged.grid")
    with open(path, "wb") as handle:
        handle.write(bytes(grid))
    rc, out = run(SCRIPT, "--compare-frame", path, FRAME)
    assert rc == 0, out


def test_the_tolerance_is_the_one_bead_ooae9_MEASURED():
    """Not loosened to make a run pass. The constant is DERIVED from calibration.json's measured
    populations, and the derivation is asserted against the recorded numbers here so a later edit
    to either side goes red."""
    cal = frame_hash.CALIBRATION
    assert cal, "no calibration data; the tolerance would be a guess"
    tol = frame_hash.derive_tolerance()
    assert abs(tol - 0.004377268476873758) < 1e-12, (
        "the frame-hash tolerance has moved from the value bead oo-ae9 measured (%r). This "
        "scenario uses it as measured; if the renderer really changed, re-measure with "
        "calibrate.py and re-bless - do not adjust the constant to make a run pass." % tol)
    floor = max(cal["same_scene_distances"])
    signal = min(cal["different_scene_distances"])
    assert floor < tol < signal, (floor, tol, signal)


def test_this_scenarios_measured_distances_sit_inside_the_calibrated_band():
    """The bead's instruction: if this scenario's frames fall OUTSIDE the measured discrimination
    band, report it as a finding rather than adjusting the constant. They do not - they sit well
    inside it, and the margins are recorded in provenance so the claim is auditable."""
    with open(PROVENANCE, encoding="utf-8") as handle:
        prov = json.load(handle)
    frame = prov.get("frame_control")
    assert frame, "provenance records no frame_control; the OXP-absent control is unrecorded"
    tol = frame_hash.derive_tolerance()
    assert frame["same_scene_distance"] < tol, frame
    assert frame["oxp_absent_distance"] > tol, frame
    assert frame["oxp_absent_distance"] / tol > 5, (
        "the OXP-absent control is only %.2fx the tolerance; that is too close to call the frame "
        "a discriminating observable" % (frame["oxp_absent_distance"] / tol))


# --- golden_diff's own refusals apply here too --------------------------------------------

def test_a_collapsed_dump_is_refused_by_golden_diff(scratch):
    empty = write(scratch, "empty.json", {"entities": [], "market": {}, "player": {}})
    rc, out = run(DIFF, GOLDEN, empty)
    assert rc == 2, out
    assert "REFUSED" in out, out


def test_self_comparison_is_refused_not_matched():
    """rc=2 means 'I cannot tell you'; it must never be mistaken for 'they match'."""
    rc, out = run(DIFF, GOLDEN, GOLDEN)
    assert rc == 2, out


def test_a_one_unit_field_perturbation_is_reported_by_name(golden, scratch):
    """One quantised unit (0.001) on one float must go RED naming the field and both values."""
    key = sorted(golden["market"])[0]
    golden["market"][key]["price"] = round(golden["market"][key]["price"] + 0.001, 3)
    rc, out = run(DIFF, GOLDEN, write(scratch, "perturbed.json", golden))
    assert rc == 1, out
    assert "market.%s.price" % key in out, out


def test_an_off_policy_quantisation_is_refused(golden, scratch):
    left = write(scratch, "state.json", golden)
    with open(os.path.join(scratch, "provenance.json"), "w", encoding="utf-8") as handle:
        json.dump({"quant_decimals": 0, "scenario": SCENARIO}, handle)
    rc, out = run(DIFF, left, GOLDEN)
    assert rc == 2, out
    assert "quant_decimals" in out, out


# --- provenance pins the knobs the golden was blessed with ---------------------------------

def test_provenance_records_the_policy_quantisation():
    with open(PROVENANCE, encoding="utf-8") as handle:
        prov = json.load(handle)
    assert prov["quant_decimals"] == 3, prov
    assert prov["scenario"] == SCENARIO, prov
    assert prov["dump_tool"] == "tests/golden/png_test_suite.py", prov


def test_provenance_records_the_knobs_the_golden_was_blessed_with(spec):
    """Bead oo-3ya's finding, applied here from the start: a seed that is PRINTED but has no
    predicate can be changed with the gate staying green, and a fresh-run-vs-golden comparison
    cannot catch it because changing the seed changes BOTH sides.

    The fix is not a magic number in the checker (which makes re-blessing illegal and invites
    somebody to edit the constant): provenance records the knobs the golden was BLESSED with, and
    the gate asserts the spec still agrees. Re-blessing with a new seed stays legal - both files
    move together; drift between them is fatal.
    """
    with open(PROVENANCE, encoding="utf-8") as handle:
        prov = json.load(handle)
    knobs = prov.get("scenario_knobs")
    assert knobs, "provenance records no scenario_knobs; the blessed seed is unrecorded"
    for key in ("seed", "system_id", "ticks", "tick_seconds"):
        assert key in knobs, "provenance does not record the blessed %r" % key
    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    assert not drift, (
        "spec.json disagrees with the knobs this golden was blessed with (blessed, spec): %r"
        % drift)


# --- CHECKER mutants: weaken the validator, a known-bad input must STILL be rejected -------
#
# oo-jor's lesson: a gate can protect its data and leave its validator unprotected. Each test
# below removes ONE defence from a COPY of the checker and asserts the copy STILL rejects the
# known-bad input, so the redundancy cannot be silently collapsed by a later refactor. Then a
# final mutant removes ALL of them and asserts the verdict FLIPS - the only mutation that
# genuinely changes behaviour, and the proof that the pair is redundancy rather than one check
# wearing two names.

def test_each_defence_alone_still_rejects_an_empty_script_list(golden, scratch):
    """THE FIELD UNDER TEST IS `oxp_world_scripts` AND ONLY THAT FIELD - every other evidence
    field keeps its real value, so a rejection cannot be attributed to a different check."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_world_scripts=[])
    bad_path = write(scratch, "bad_scripts.json", bad)

    defences = {
        "1a-emptiness": (
            "    if not isinstance(live, list) or not live:",
            "    if not isinstance(live, list):"),
        "1b-exactset": (
            "    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:",
            "    elif False:"),
    }
    for tag, (old, new) in defences.items():
        path = mutated_checker(scratch, old, new, "mutant_%s.py" % tag)
        rc, out = run(path, bad_path)
        assert rc == 1, (
            "with defence %s removed the checker ACCEPTED a dump whose evidence.oxp_world_scripts "
            "is empty (rc=%d). The property is then held by a single line, so the redundancy this "
            "test pins is gone.\n%s" % (tag, rc, out))


def test_removing_both_world_script_defences_does_change_behaviour(golden, scratch):
    """If this does NOT go green the test above is measuring something other than what it claims
    (an equivalent mutant, or a third defence nobody named)."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_world_scripts=[])
    bad_path = write(scratch, "bad_both_scripts.json", bad)
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace("    if not isinstance(live, list) or not live:",
                      "    if not isinstance(live, list):", 1)
    src = src.replace("    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:", "    elif False:", 1)
    path = os.path.join(scratch, "mutant_scripts_both.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing BOTH oxp_world_scripts defences did not change the verdict (rc=%d), so some "
        "OTHER check is rejecting this dump and the redundancy test above is not measuring what "
        "it claims. Read the checker and name the real defence.\n%s" % (rc, out))


def test_each_texture_defence_alone_still_rejects_a_wrong_upload(golden, scratch):
    """The texture evidence is guarded by THREE structurally different clauses, and each must hold
    a different known-bad input on its own:

      3a  emptiness            - `not uploads`
      3b  the key comparison   - no entry named the expansion's image
      3c  the size comparison  - an entry at the wrong pixel size

    Each mutant below removes ONE clause and feeds the input that OTHER clauses should still
    catch, so a rejection is attributable.
    """
    cases = {
        # remove emptiness -> an EMPTY list must still be caught by the key comparison
        "3a-emptiness": (
            "    if not isinstance(uploads, list) or not uploads:",
            "    if not isinstance(uploads, list):",
            []),
        # remove the key comparison -> a WRONG-SIZE entry must still be caught by the size check
        "3b-key": (
            "        if not matching:",
            "        if False:",
            [{"key": "Images/oolite_material_test_suite_backdrop.png",
              "width": 1024, "height": 511}]),
        # remove the size comparison -> a WRONG-KEY entry must still be caught by the key check
        "3c-size": (
            "            if [upload.get(\"width\"), upload.get(\"height\")] "
            "!= EXPECTED_IHDR_DIMENSIONS:",
            "            if False:",
            [{"key": "Images/some_other_texture.png", "width": 1024, "height": 512}]),
    }
    for tag, (old, new, uploads) in cases.items():
        bad = dict(golden)
        bad["evidence"] = dict(golden["evidence"], png_texture_uploads=uploads)
        bad_path = write(scratch, "bad_tex_%s.json" % tag, bad)
        path = mutated_checker(scratch, old, new, "mutant_tex_%s.py" % tag)
        rc, out = run(path, bad_path)
        assert rc == 1, (
            "with texture defence %s removed the checker ACCEPTED evidence.png_texture_uploads=%r "
            "(rc=%d); the remaining clauses must still hold the property.\n%s"
            % (tag, uploads, rc, out))


def test_removing_all_texture_defences_does_change_behaviour(golden, scratch):
    """The mutation that genuinely weakens the gate: with all three clauses gone, a dump in which
    NOTHING decoded is accepted as a texture-decoding run."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], png_texture_uploads=[])
    bad_path = write(scratch, "bad_tex_all.json", bad)
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace("    if not isinstance(uploads, list) or not uploads:",
                      "    if not isinstance(uploads, list):", 1)
    src = src.replace("        if not matching:", "        if False:", 1)
    path = os.path.join(scratch, "mutant_tex_all.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing every texture defence did not change the verdict (rc=%d), so this scenario's "
        "central anti-vacuity property is being enforced somewhere this test does not know "
        "about. Read the checker and name it.\n%s" % (rc, out))


def test_weakening_the_error_count_to_at_most_is_still_caught_by_the_signature_clause(
        golden, scratch):
    """The count and the signature list are two independent defences on the NOMANIF allowance."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_standards_errors=0,
                           oxp_standards_error_signatures=[])
    bad_path = write(scratch, "bad_errors.json", bad)
    path = mutated_checker(
        scratch,
        "    if count != EXPECTED_STANDARDS_ERRORS:",
        "    if count is None:",
        "mutant_errcount.py")
    rc, out = run(path, bad_path)
    assert rc == 1, (
        "with the exact-count defence removed the checker ACCEPTED a dump with zero "
        "missing-manifest errors, i.e. a run in which PNGTestSuite was never parsed (rc=%d). "
        "The signature clause must hold that property on its own.\n%s" % (rc, out))


def test_removing_both_nomanif_defences_does_change_behaviour(golden, scratch):
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_standards_errors=0,
                           oxp_standards_error_signatures=[])
    bad_path = write(scratch, "bad_both.json", bad)
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace("    if count != EXPECTED_STANDARDS_ERRORS:", "    if count is None:", 1)
    src = src.replace("        if not sigs:", "        if False:", 1)
    path = os.path.join(scratch, "mutant_both.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, _ = run(path, bad_path)
    assert rc == 0, (
        "removing BOTH NOMANIF defences did not change the verdict, so this pair of tests is "
        "measuring something other than what it claims (rc=%d)" % rc)


def test_weakening_the_channel_check_leaves_the_failure_list_unguarded(golden, scratch):
    """The CHECKER mutant for defence 4, which is the subtlest one in this gate.

    Removing the channel requirement does NOT make the checker reject anything less on a good
    dump - it makes the EMPTY `png_load_failures` list meaningless. That is proven here by
    feeding a dump with no channels recorded: the real checker rejects it, the mutated copy
    accepts it, and the difference is exactly the reading 'nobody was listening'.
    """
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], texture_log_channels=[])
    bad_path = write(scratch, "bad_channels.json", bad)

    rc, out = run(EVIDENCE, bad_path)
    assert rc == 1, ("the real checker accepted a dump recording NO enabled log channels "
                     "(rc=%d)\n%s" % (rc, out))

    path = mutated_checker(
        scratch,
        "    if not isinstance(channels, list) or not REQUIRED_LOG_CHANNELS.issubset("
        "set(channels)):",
        "    if False:",
        "mutant_channels.py")
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing the channel requirement did NOT change the verdict on a dump with no channels "
        "recorded (rc=%d), so this test is not measuring the clause it names.\n%s" % (rc, out))


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 is 'I cannot tell you'. A checker that returns 0 when it could not perform the check
    is the most dangerous failure mode a gate can have."""
    rc, out = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2, out
    assert "USAGE" in out, out


def test_the_frame_comparator_refuses_a_wrong_sized_grid(scratch):
    """A truncated grid must be a REFUSAL (rc=2), never a verdict - the same convention
    golden_diff uses."""
    stub = os.path.join(scratch, "stub.grid")
    with open(stub, "wb") as handle:
        handle.write(b"\x00" * 16)
    rc, out = run(SCRIPT, "--compare-frame", stub, FRAME)
    assert rc == 2, out
    assert "not %d bytes" % frame_hash.GRID_CELLS in out, out
