"""Offline falsifiability tests for golden scenario 005-mission-trigger. No game is launched.

These pin the things a live run cannot: that each defence in check_mission_trigger_evidence.py
REJECTS the known-bad input ON ITS OWN, that the spec's determinism knobs agree with the knobs the
golden was BLESSED with, and that the stored golden is byte-for-byte the artifact provenance
witnesses.

THE RULE THESE EXIST TO HONOUR (bead oo-jor): for every property a gate defends, write TWO mutants
- one that corrupts the DATA and one that WEAKENS THE CHECKER - because only the second catches a
gate that validates data with a validator nobody validates. Every checker mutation here is written
to a THROWAWAY COPY under a tmp_path; the real file is never touched.
"""

import hashlib
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

SCENARIO = "005-mission-trigger"
CHECKER = os.path.join(HERE, "check_mission_trigger_evidence.py")
SCRIPT = os.path.join(HERE, "mission_trigger.py")

SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "tests", "golden", "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    pytest.skip("no %s (looked in %s)" % (what, ", ".join(candidates)))


@pytest.fixture(scope="module")
def spec():
    with open(_first(SPEC_CANDIDATES, "spec.json"), "r", encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture(scope="module")
def golden_path():
    return _first(GOLDEN_CANDIDATES, "stored golden")


@pytest.fixture(scope="module")
def golden(golden_path):
    with open(golden_path, "r", encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture(scope="module")
def provenance():
    with open(_first(PROVENANCE_CANDIDATES, "provenance.json"), "r", encoding="utf-8") as fh:
        return json.load(fh)


def run_checker(path, checker=CHECKER):
    proc = subprocess.run([sys.executable, checker, str(path)], capture_output=True, text=True)
    return proc.returncode, (proc.stdout + proc.stderr)


# --- the scenario's own shape --------------------------------------------------------------------

def test_the_scenario_script_and_checker_are_importable():
    for path in (SCRIPT, CHECKER):
        proc = subprocess.run([sys.executable, "-m", "py_compile", path],
                              capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr


def test_the_save_fixture_exists_and_its_counter_is_the_value_the_trigger_needs(spec):
    """THE FIXTURE'S COUNTER IS THE WHOLE EXPERIMENT.

    The mission script increments cloakcounter and spawns the ambush only when the INCREMENTED
    value exceeds 6 (oolite-cloaking-device-mission.js:66). The fixture holds exactly 6, so 6->7
    is the smallest value that fires the trigger. If upstream changes the fixture this test goes
    red, and that is a FINDING to re-measure - not an assertion to edit.
    """
    import plistlib

    path = os.path.join(REPO_ROOT, *spec["load_save"].split("/"))
    assert os.path.isfile(path), "the fixture this scenario loads is missing: %s" % path
    with open(path, "rb") as fh:
        data = plistlib.load(fh)
    mv = data.get("mission_variables")
    assert isinstance(mv, dict), "%s has no mission_variables dict" % path
    key = spec["mission_variable_key_in_file"]
    assert key in mv, (
        "%s no longer carries %r; without a saved counter there is nothing for the mission script "
        "to increment and the scenario's core assertion is unevaluable" % (path, key))
    assert int(mv[key]) == spec["expected_counter_in_file"], (
        "the fixture's %s moved to %r; the spec pins %r, and that exact value is why the "
        "incremented counter crosses the script's `> 6` threshold"
        % (key, mv[key], spec["expected_counter_in_file"]))
    assert int(data["galaxy_number"]) == spec["expected_galaxy_number"], (
        "the fixture is in galaxy %r but the trigger's guard is `galaxyNumber === 4`; in any "
        "other galaxy the handler returns without doing anything" % data["galaxy_number"])
    assert "mission_cloak" not in mv, (
        "the fixture now carries a `cloak` mission variable. oolite-cloaking-device-mission.js:40 "
        "DELETES systemWillPopulate in startUp when cloak is set, so the trigger could never "
        "fire. Re-measure; do not edit the assertion.")


def test_the_engine_value_is_exactly_one_more_than_the_file_value(spec):
    """The spec's two counter values must encode the RELATION, not two unrelated numbers."""
    assert spec["expected_counter_in_engine"] == spec["expected_counter_in_file"] + 1, (
        "spec pins file=%r and engine=%r. The scenario asserts that a MISSION SCRIPT incremented "
        "the counter; any other relation is a spec that no longer describes that experiment."
        % (spec["expected_counter_in_file"], spec["expected_counter_in_engine"]))


def test_the_spec_mission_variables_carry_the_incremented_counter(spec):
    """A post-trigger mission-variable set that still held the FILE's value would silently turn
    the whole scenario back into a deserialiser test."""
    assert spec["expected_mission_variables"][spec["mission_variable_key"]] == \
        spec["expected_counter_in_engine"], (
        "spec expected_mission_variables[%r] is %r but the post-trigger engine value is %r"
        % (spec["mission_variable_key"],
           spec["expected_mission_variables"].get(spec["mission_variable_key"]),
           spec["expected_counter_in_engine"]))


def test_the_control_save_is_a_different_file_from_the_subject(spec):
    assert spec["control_save"] != spec["load_save"], (
        "the differential's two arms name the same file; a control that is the subject cannot move")


def test_every_determinism_knob_is_actually_read_by_the_script(spec):
    """A knob no code reads is decoration: change it and no line goes red."""
    with open(SCRIPT, "r", encoding="utf-8") as fh:
        src = fh.read()
    for knob in ("seed", "system_id", "ticks", "tick_seconds", "load_save", "control_save",
                 "mission_script_name", "mission_variable_key", "mission_variable_key_in_file",
                 "expected_counter_in_file", "expected_populator_key", "expected_spawned_roles",
                 "ambush_leader_role", "expected_ambush_leader_script",
                 "expected_ambush_escort_group_count",
                 "expected_live_mission_handlers", "expected_mission_variables",
                 "expected_commander_name", "expected_galaxy_number"):
        assert 'spec["%s"]' % knob in src, (
            "mission_trigger.py never reads spec[%r]; the knob is decoration - if someone changed "
            "it, no line would go red" % knob)


def test_spec_knobs_equal_the_knobs_the_golden_was_blessed_with(spec, provenance):
    """bead oo-3ya: a fresh-run-vs-golden comparison CANNOT catch a changed seed, because changing
    the seed changes both sides. The witness has to be the provenance."""
    knobs = provenance.get("scenario_knobs")
    assert knobs, "provenance records no scenario_knobs"
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals"):
        assert key in knobs, "provenance scenario_knobs does not record %r" % key
    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    assert not drift, (
        "spec.json disagrees with the knobs this golden was BLESSED with (blessed-vs-spec %r). "
        "The stored golden no longer corresponds to what the spec would produce." % drift)


def test_the_golden_is_the_artifact_provenance_witnesses(golden_path, provenance):
    """The INDEPENDENT witness. Mutating state.json moves both sides of every self-comparison;
    provenance is a separate file the mutant does not touch (bead oo-gxp)."""
    rec = (provenance.get("artifacts") or {}).get("state.json")
    assert rec, "provenance records no artifacts.state.json digest"
    blob = open(golden_path, "rb").read()
    assert len(blob) == rec["bytes"], (
        "the golden is %d bytes, provenance witnesses %d" % (len(blob), rec["bytes"]))
    assert hashlib.sha256(blob).hexdigest() == rec["sha256"], (
        "the golden's sha256 does not match the one provenance witnesses")


def test_the_frame_grid_is_not_byte_hashed_into_the_dump(golden):
    """THE DELIBERATE ASYMMETRY. llvmpipe is not bit-reproducible, so a frame digest inside
    state.json would make the byte-identical comparison flake on renderer noise."""
    text = json.dumps(golden)
    assert "frame_hash" not in text and "frame_grid" not in text, (
        "the dump carries a frame digest; frames are compared with the MEASURED tolerance and "
        "stored beside the dump as frame.grid, never byte-hashed into it")


def test_the_stored_frame_grid_is_the_expected_size():
    path = _first(FRAME_CANDIDATES, "frame.grid")
    assert os.path.getsize(path) == 4096, "frame.grid is not the 64x64 luminance grid"


# --- the stored golden carries the trigger evidence ----------------------------------------------

def test_the_stored_golden_passes_the_evidence_checker(golden_path):
    rc, out = run_checker(golden_path)
    assert rc == 0, out


def test_the_golden_records_both_counter_values_and_their_relation(golden):
    ev = golden["evidence"]
    assert ev["mission_counter_in_engine"] == ev["mission_counter_in_file"] + 1, (
        "the blessed golden's counters are file=%r engine=%r. Equal values mean the save loaded "
        "and the world-script event never ran the handler - the exact vacuity this scenario "
        "exists to exclude." % (ev["mission_counter_in_file"], ev["mission_counter_in_engine"]))


def test_the_golden_carries_mission_variables_at_top_level_and_in_evidence(golden, spec):
    assert golden["mission_variables"] == golden["evidence"]["mission_variables"]
    assert golden["mission_variables"] == spec["expected_mission_variables"]


def test_a_usage_error_is_distinguishable_from_a_verdict(tmp_path):
    """rc=2 means 'I cannot tell you'; it is never 'they match'."""
    rc, _ = run_checker(tmp_path / "does-not-exist.json")
    assert rc == 2
    bad = tmp_path / "bad.json"
    bad.write_text("{not json", encoding="utf-8")
    rc, _ = run_checker(bad)
    assert rc == 2


def test_the_checker_rejects_an_empty_dump(tmp_path):
    path = tmp_path / "empty.json"
    path.write_text("{}", encoding="utf-8")
    rc, out = run_checker(path)
    assert rc == 1 and "no `evidence` object" in out


# --- DATA mutants: each corrupted field must be REJECTED ------------------------------------------

DATA_MUTANTS = (
    # THE CORE: the deserialiser-copy signature. Both numbers equal, both individually plausible.
    ("the engine counter equal to the file counter (the deserialiser-copy signature)",
     lambda d: (d["evidence"].update(mission_counter_in_engine=6),
                d["evidence"]["mission_variables"].update(cloakcounter=6),
                d["mission_variables"].update(cloakcounter=6))),
    ("the engine counter two ahead of the file counter",
     lambda d: (d["evidence"].update(mission_counter_in_engine=8),
                d["evidence"]["mission_variables"].update(cloakcounter=8),
                d["mission_variables"].update(cloakcounter=8))),
    ("the file counter moved so the relation holds but the fixture is not the pinned one",
     lambda d: (d["evidence"].update(mission_counter_in_file=10,
                                     mission_counter_in_engine=11),
                d["evidence"]["mission_variables"].update(cloakcounter=11),
                d["mission_variables"].update(cloakcounter=11))),
    ("the ambush populator reported as not registered",
     lambda d: d["evidence"].update(ambush_populator_registered=False)),
    ("the ambush populator renamed",
     lambda d: d["evidence"].update(ambush_populator="oolite-populator")),
    ("the ambush ships gone (the trigger did not spawn)",
     lambda d: d["evidence"].update(spawned_role_counts={"asp-cloaked": 0})),
    ("the ambush leader absent (the populator was registered but its callback never ran)",
     lambda d: d["evidence"].update(ambush_leader=None)),
    ("the ambush leader carrying a different script",
     lambda d: d["evidence"].update(ambush_leader={"script": "oolite-default-ship-script",
                                                   "escort_group_count": 3})),
    ("the ambush leader one escort short",
     lambda d: d["evidence"].update(ambush_leader={
         "script": "oolite-cloaking-device-target-ship", "escort_group_count": 2})),
    ("the counter reported as absent",
     lambda d: d["evidence"].update(mission_counter_present=False)),
    ("the galaxy swapped out of the trigger's guard",
     lambda d: d["evidence"].update(galaxy_number=1)),
    ("the mission variables emptied (a default new game)",
     lambda d: (d["evidence"].update(mission_variables={}), d.update(mission_variables={}))),
    ("the live mission handlers emptied (the script was never built)",
     lambda d: d["evidence"].update(live_mission_handlers=[])),
    ("systemWillPopulate dropped, leaving only startUp",
     lambda d: d["evidence"].update(live_mission_handlers=["startUp"])),
    ("the commander swapped", lambda d: d["evidence"].update(commander_name="Jameson")),
    ("the system swapped", lambda d: d["evidence"].update(system_name="Lave", system_id=7)),
    ("the save file swapped",
     lambda d: d["evidence"].update(save_file="Constrictor.oolite-save")),
    ("the save-format version dropped",
     lambda d: d["evidence"].update(save_format_version="1.90")),
    ("the mission script reported as not loaded",
     lambda d: d["evidence"].update(mission_script_loaded=False)),
    ("the top-level mission_variables desynchronised from evidence",
     lambda d: d.update(mission_variables={"cloakcounter": 7})),
    ("the evidence block removed entirely", lambda d: d.pop("evidence")),
)


@pytest.mark.parametrize("label,mutate", DATA_MUTANTS, ids=[m[0] for m in DATA_MUTANTS])
def test_a_corrupted_golden_is_rejected(golden, tmp_path, label, mutate):
    data = json.loads(json.dumps(golden))
    mutate(data)
    path = tmp_path / "mutant.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    rc, out = run_checker(path)
    assert rc == 1, ("the checker ACCEPTED a golden with %s (rc=%d). That property is not "
                     "defended.\n%s" % (label, rc, out))


# --- CHECKER mutants: weakening the validator must ALSO be caught ---------------------------------
#
# A validator nobody validates is a hole one refactor wide (bead oo-jor). For each defence, a COPY
# of the checker is written to tmp_path with that defence removed, and the mutated copy is asserted
# to ACCEPT the matching bad input - i.e. each defence must be load-bearing ON ITS OWN, or, where a
# property is deliberately defended twice, the redundancy is pinned so a refactor cannot silently
# collapse it. The real file is NEVER touched.

CHECKER_MUTANTS = (
    ("EXPECTED_POPULATOR widened to a key every system has",
     'EXPECTED_POPULATOR = "oolite-cloaking-device-mission"',
     'EXPECTED_POPULATOR = "oolite-populator"',
     lambda d: d["evidence"].update(ambush_populator="oolite-populator")),
    ("EXPECTED_SPAWNED_ROLES zeroed",
     'EXPECTED_SPAWNED_ROLES = {"asp-cloaked": 1}',
     'EXPECTED_SPAWNED_ROLES = {"asp-cloaked": 0}',
     lambda d: d["evidence"].update(spawned_role_counts={"asp-cloaked": 0})),
    ("EXPECTED_LEADER_SCRIPT widened to the default ship script",
     'EXPECTED_LEADER_SCRIPT = "oolite-cloaking-device-target-ship"',
     'EXPECTED_LEADER_SCRIPT = "oolite-default-ship-script"',
     lambda d: d["evidence"].update(ambush_leader={"script": "oolite-default-ship-script",
                                                   "escort_group_count": 3})),
    ("EXPECTED_LEADER_ESCORTS lowered",
     "EXPECTED_LEADER_ESCORTS = 3", "EXPECTED_LEADER_ESCORTS = 2",
     lambda d: d["evidence"].update(ambush_leader={
         "script": "oolite-cloaking-device-target-ship", "escort_group_count": 2})),
    ("EXPECTED_GALAXY widened off the trigger's guard",
     "EXPECTED_GALAXY = 4", "EXPECTED_GALAXY = 1",
     lambda d: d["evidence"].update(galaxy_number=1)),
    ("EXPECTED_COMMANDER widened",
     'EXPECTED_COMMANDER = "CloakingDevice"', 'EXPECTED_COMMANDER = "Jameson"',
     lambda d: d["evidence"].update(commander_name="Jameson")),
    ("EXPECTED_COUNTER_IN_FILE widened",
     "EXPECTED_COUNTER_IN_FILE = 6", "EXPECTED_COUNTER_IN_FILE = 10",
     lambda d: (d["evidence"].update(mission_counter_in_file=10,
                                     mission_counter_in_engine=11),
                d["evidence"]["mission_variables"].update(cloakcounter=11),
                d["mission_variables"].update(cloakcounter=11))),
    ("EXPECTED_LIVE_HANDLERS reduced to one name",
     'EXPECTED_LIVE_HANDLERS = ("startUp", "systemWillPopulate")',
     'EXPECTED_LIVE_HANDLERS = ("startUp",)',
     lambda d: d["evidence"].update(live_mission_handlers=["startUp"])),
)


@pytest.mark.parametrize("label,old,new,mutate", CHECKER_MUTANTS,
                         ids=[m[0] for m in CHECKER_MUTANTS])
def test_weakening_the_checker_stops_it_discriminating(golden, tmp_path, label, old, new, mutate):
    """Each constant must be WHAT DOES THE DISCRIMINATING, so a future edit that loosens it is a
    real behaviour change and not a no-op. The bad input is REJECTED by the real checker and
    ACCEPTED by the weakened copy."""
    source = open(CHECKER, "r", encoding="utf-8").read()
    assert old in source, "the checker no longer contains %r; this mutant is stale" % old
    mutated_source = source.replace(old, new, 1)
    assert mutated_source != source, "the mutation was a no-op; this mutant proves nothing"
    weakened = tmp_path / "weak_checker.py"
    weakened.write_text(mutated_source, encoding="utf-8")

    data = json.loads(json.dumps(golden))
    mutate(data)
    path = tmp_path / "mutant.json"
    path.write_text(json.dumps(data), encoding="utf-8")

    rc_real, out_real = run_checker(path)
    assert rc_real == 1, "the REAL checker did not reject %s: %s" % (label, out_real)

    rc_weak, out_weak = run_checker(path, checker=str(weakened))
    assert rc_weak == 0, (
        "the weakened checker STILL rejected the input after %s (rc=%d). Either the constant is "
        "not what enforces the property - a future refactor could delete it with no test going "
        "red - or the property is defended redundantly and that redundancy must be pinned "
        "explicitly rather than left implicit.\n%s" % (label, rc_weak, out_weak))


def test_the_increment_relation_is_defended_twice(golden, tmp_path):
    """DELIBERATE REDUNDANCY, PINNED BEHAVIOURALLY (bead oo-jor).

    `engine == file + 1` is the scenario's core, so the checker holds it TWICE: as the two
    measured constants (EXPECTED_COUNTER_IN_FILE / EXPECTED_COUNTER_IN_ENGINE) and as the
    RELATION clause. Either alone rejects the deserialiser-copy signature, which is why widening
    just one is an EQUIVALENT mutant rather than a hole. This test asserts EACH defence ALONE
    still rejects it, and that removing BOTH - the only mutation that genuinely changes behaviour
    - DOES let the bad input through.
    """
    source = open(CHECKER, "r", encoding="utf-8").read()
    relation = "elif in_engine != in_file + 1:"
    constants = "    if in_engine != EXPECTED_COUNTER_IN_ENGINE:"
    assert relation in source and constants in source, (
        "the two increment defences have been renamed; this test is stale")

    data = json.loads(json.dumps(golden))
    # The deserialiser-copy signature: the engine value never moved off the file value.
    data["evidence"]["mission_counter_in_engine"] = data["evidence"]["mission_counter_in_file"]
    data["evidence"]["mission_variables"]["cloakcounter"] = \
        data["evidence"]["mission_counter_in_file"]
    data["mission_variables"]["cloakcounter"] = data["evidence"]["mission_counter_in_file"]
    path = tmp_path / "copied.json"
    path.write_text(json.dumps(data), encoding="utf-8")

    # Defence 1 removed: the constants alone must still reject.
    only_constants = tmp_path / "only_constants.py"
    only_constants.write_text(source.replace(relation, "elif False:", 1), encoding="utf-8")
    rc, out = run_checker(path, checker=str(only_constants))
    assert rc == 1, ("with the RELATION clause removed the checker ACCEPTED a dump whose engine "
                     "counter equals its file counter (rc=%d)\n%s" % (rc, out))

    # Defence 2 removed: the relation alone must still reject.
    only_relation = tmp_path / "only_relation.py"
    only_relation.write_text(
        source.replace(constants, "    if False:", 1)
              .replace("EXPECTED_MISSION_VARIABLES = {",
                       "EXPECTED_MISSION_VARIABLES = {\n    # relation-only mutant\n", 1),
        encoding="utf-8")
    # The mission-variable map would also catch this, so it is neutralised for THIS arm only:
    # the point is to isolate the relation clause, not to prove the map works (it has its own
    # DATA mutant above).
    src2 = only_relation.read_text(encoding="utf-8")
    src2 = src2.replace("    elif mv != EXPECTED_MISSION_VARIABLES:", "    elif False:", 1)
    only_relation.write_text(src2, encoding="utf-8")
    rc, out = run_checker(path, checker=str(only_relation))
    assert rc == 1, ("with the CONSTANTS removed the checker ACCEPTED a dump whose engine counter "
                     "equals its file counter (rc=%d)\n%s" % (rc, out))

    # BOTH removed (plus the mission-variable map, the third witness): the only mutation that
    # genuinely changes behaviour must let it through.
    neither = tmp_path / "neither.py"
    src3 = source.replace(relation, "elif False:", 1).replace(constants, "    if False:", 1)
    src3 = src3.replace("    elif mv != EXPECTED_MISSION_VARIABLES:", "    elif False:", 1)
    neither.write_text(src3, encoding="utf-8")
    rc, out = run_checker(path, checker=str(neither))
    assert rc == 0, (
        "with every increment defence removed the checker STILL rejected the deserialiser-copy "
        "dump (rc=%d), so something else is doing this work and the clauses above are not the "
        "defence they appear to be.\n%s" % (rc, out))


def test_the_differential_subject_is_the_blessed_golden(golden, provenance):
    """SECOND, INDEPENDENT WITNESS on the differential.

    Without this, provenance could claim the blessed dump had a fired trigger while the golden
    said otherwise, and the differential would be evidence about a dump nobody shipped.
    """
    md = provenance.get("trigger_differential")
    assert md, "provenance records no trigger_differential"
    sub = md.get("subject") or {}
    ev = golden["evidence"]
    for key in ("commander_name", "system_name", "system_id", "galaxy_number",
                "mission_counter_in_file", "mission_counter_in_engine",
                "ambush_populator_registered", "ambush_leader", "spawned_role_counts",
                "mission_script_loaded"):
        assert sub.get(key) == ev.get(key), (
            "provenance subject.%s=%r but the blessed golden reports %r; the differential was "
            "measured against a different dump than the one blessed"
            % (key, sub.get(key), ev.get(key)))
    for arm in ("control_constrictor", "control_fresh_game"):
        assert arm in md, "provenance records no %s control arm" % arm
        moved = [k for k in sub if md[arm].get(k) != sub.get(k)]
        assert moved, (
            "control arm %r moves NO field against the subject; the dump does not observe whether "
            "the trigger fired and the golden is vacuous" % arm)
        assert md[arm].get("mission_counter_in_engine") != sub.get("mission_counter_in_engine"), (
            "control arm %r reports the SAME post-trigger counter as the subject; the counter is "
            "then not what distinguishes a fired trigger from an unfired one" % arm)


def test_the_frame_control_separates_signal_from_noise(provenance):
    """A tolerance with no measured separation is a number, not a control (bead oo-ae9/oo-gxp)."""
    fc = provenance.get("frame_control")
    assert fc, "provenance records no frame_control"
    tol = float(fc["tolerance"])
    assert float(fc["same_scene_distance"]) < tol, (
        "two launches of the SAME scenario differ by %r, at or beyond the measured tolerance %r; "
        "the frame comparison would flake" % (fc["same_scene_distance"], tol))
    for arm in ("control_constrictor_distance", "control_fresh_game_distance"):
        assert float(fc[arm]) / tol > 2, (
            "%s is only %.2fx the measured tolerance; the frame does not discriminate this "
            "scenario from that control" % (arm, float(fc[arm]) / tol))
