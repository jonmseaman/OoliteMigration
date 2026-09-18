"""Offline tests for scenario 014-nova: the harness, the evidence checker and the knob gate.

NO GAME LAUNCH HAPPENS HERE, deliberately: these run in seconds in any checkout, including the
detached one accept.sh builds, which has no Oolite build directory (bead oo-1xz). The LIVE
properties - that the game really loads the save, that ten runs agree - are stored acceptance
lines and provenance; what is tested here is the code that JUDGES those runs.

THE POINT OF THESE TESTS IS NOT COVERAGE, IT IS DISCRIMINATION. A passing test COUNT proves
nothing (bead oo-jor). Every test below feeds the checker a KNOWN-BAD input and asserts it is
REJECTED, and the per-defence tests go further: for each property defended by more than one clause
they copy the checker to a THROWAWAY file under Temp, delete ONE defence, and assert the mutated
copy STILL rejects the bad input - so deliberate redundancy on a critical property cannot be
silently collapsed by a later refactor, and a surviving mutant is distinguishable from a blind
gate (bead oo-jor's three causes).

MUTATION HAPPENS ONLY ON THROWAWAY COPIES under $LOCALAPPDATA/Temp. A harness that mutates in
place is one timeout away from committing a sabotaged gate (bead oo-dto committed `if False:` in
place of the one predicate its scenario was named for).
"""

import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import check_nova_evidence as checker  # noqa: E402

SCENARIO = "014-nova"
SAVE = os.path.join(REPO_ROOT, "upstream", "oolite-tests", "Checklist-files", "Missions",
                    "Nova.oolite-save")
GATE = os.path.join(HERE, "gate_014_spec.py")
CHECKER_SRC = os.path.join(HERE, "check_nova_evidence.py")

# Pinned here AND in nova_load.py, so shrinking the census fails in two places.
MIN_CENSUS_FIELDS = 8


def _first(*candidates):
    for path in candidates:
        if os.path.isfile(path):
            return path
    return None


def spec_path():
    return _first(os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
                  os.path.join(HERE, "pending", SCENARIO, "spec.json"))


def golden_path():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
                  os.path.join(HERE, "pending", SCENARIO, "state.json"))


def provenance_path():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
                  os.path.join(HERE, "pending", SCENARIO, "provenance.json"))


@pytest.fixture(scope="module")
def spec():
    path = spec_path()
    assert path, "no spec.json for scenario %s in either the guarded or the staged location" % SCENARIO
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def golden():
    path = golden_path()
    assert path, "no stored golden for scenario %s" % SCENARIO
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


# --- the fixture itself -------------------------------------------------------------------------

def test_the_save_fixture_exists_and_is_a_real_plist():
    import plistlib
    assert os.path.isfile(SAVE), "the checklist save this scenario loads is missing: %s" % SAVE
    assert os.path.getsize(SAVE) > 1024
    with open(SAVE, "rb") as handle:
        data = plistlib.load(handle)
    assert isinstance(data, dict) and data


def test_the_fixture_is_PRE_1_75_not_1_75_as_the_story_says():
    """The bead's story calls this a 1.75-era file. Measured, it is OLDER, and the scenario pins
    the older contract. This test exists so a future fixture swap to a genuinely 1.75 save - which
    would look like a correction - fails loudly instead of silently weakening the contract."""
    import plistlib
    with open(SAVE, "rb") as handle:
        data = plistlib.load(handle)
    assert "written_by_version" not in data, (
        "Nova.oolite-save has acquired a written_by_version key. Every Oolite 1.75 save writes "
        "one and this fixture had none, which is what dated it BEFORE that era; a file that now "
        "has one is a different, NEWER file and pins a weaker compatibility contract.")
    assert data.get("has_energy_bomb") is True, (
        "the fixture no longer carries has_energy_bomb, the REMOVED item whose presence triggers "
        "the loader migration (PlayerEntity.m:1730-1746) that this scenario's credits census "
        "field predicts.")


def test_the_named_mission_variables_are_what_was_measured():
    """mission_novacount is PRESENT and NON-EMPTY; mission_nova is ABSENT. Both are asserted by
    the scenario, and the asymmetry is the whole design - see check_nova_evidence's docstring."""
    import plistlib
    with open(SAVE, "rb") as handle:
        mv = plistlib.load(handle)["mission_variables"]
    assert mv.get("mission_novacount") == "3", (
        "mission_novacount is %r, not '3'. It is the one variable this bead names whose value is "
        "non-empty, which is what lets the scenario check it BY VALUE rather than only by "
        "presence." % (mv.get("mission_novacount"),))
    assert "mission_nova" not in mv, (
        "the fixture has acquired mission_nova, which it did not have. The scenario asserts its "
        "ABSENCE; a fixture that now carries it makes that assertion false.")


# --- the spec ------------------------------------------------------------------------------------

def test_spec_pins_the_save_and_the_census(spec):
    assert spec["load_save"].endswith("Missions/Nova.oolite-save")
    assert len(spec["census"]) >= MIN_CENSUS_FIELDS
    kinds = {e["plist"]: e["kind"] for e in spec["census"]}
    assert kinds["credits"] == "float_tenths_legacy_energy_bomb"


def test_spec_expects_an_EMPTY_written_by_version(spec):
    assert spec["expected_written_by_version"] == "", (
        "an expectation of '1.75' here would be the story's claim rather than the file's, and "
        "would be satisfied only by swapping in a different, newer fixture.")


# --- the evidence checker: known-bad inputs must be REJECTED --------------------------------------

def test_checker_accepts_the_stored_golden(golden):
    summary = checker.check(copy.deepcopy(golden), "stored golden")
    assert summary["load_stages"] == len(checker.EXPECTED_LOAD_STAGES)
    assert summary["novacount"] == checker.EXPECTED_MISSION_NOVACOUNT_VALUE


@pytest.mark.parametrize("mutate,why", [
    (lambda d: d["evidence"].update(load_stages=[]),
     "a run that never entered -loadPlayerFromFile: logs NO load stages"),
    (lambda d: d["evidence"].update(load_stages=list(checker.EXPECTED_LOAD_STAGES)[:6]),
     "a load that died partway logs a PREFIX of the sequence"),
    (lambda d: d["evidence"].update(mission_variable_keys=[]),
     "a DEFAULT NEW GAME has no mission variables at all"),
    (lambda d: d["evidence"].update(mission_novacount_value=""),
     "an EMPTY novacount reads identically to an absent mission variable"),
    (lambda d: d["evidence"].update(mission_nova_present=True),
     "this fixture does not carry mission_nova; its appearance means a different game"),
    (lambda d: d["evidence"].update(save_written_by_version="1.75"),
     "a 1.75 fixture pins a NEWER contract than the one this scenario measured"),
    (lambda d: d["evidence"].update(legacy_upgrades=[]),
     "no [load.upgrade] line means the engine did not migrate the legacy energy bomb"),
    (lambda d: d["evidence"].update(legacy_upgrades=["Replaced legacy energy bomb with "
                                                     "Quirium cascade mine."]),
     "the OTHER branch of the migration: a free pylon would make the credits prediction wrong"),
    (lambda d: d["evidence"].update(galaxy_number=0),
     "galaxy 0 is where a DEFAULT NEW COMMANDER starts"),
    (lambda d: d["evidence"].update(round_trip_ok=False),
     "the save file and the loaded game disagreed"),
    (lambda d: d["evidence"].update(round_trip_fields_equal=3),
     "only some census fields agreed"),
    (lambda d: d["evidence"].update(census_populated=1),
     "a census of zeros and empty strings compares equal to any other empty census"),
    (lambda d: d["evidence"].update(station_ais_silenced=[]),
     "a station left with its own AI running launches traffic hasNPCTraffic does not gate"),
    (lambda d: d["evidence"].update(world_at_rest=False),
     "a moving world makes the dump frame-count dependent"),
    (lambda d: d.update(entities=[]),
     "a dump with no world in it compares equal to any other empty world"),
    (lambda d: d.update(market={}),
     "the save's own market was not loaded"),
    (lambda d: d.pop("evidence"),
     "a dump with no evidence block records a world with no claim about how it came to be"),
])
def test_checker_rejects_known_bad_dumps(golden, mutate, why):
    bad = copy.deepcopy(golden)
    mutate(bad)
    with pytest.raises(checker.EvidenceError):
        checker.check(bad, "mutant")


# --- per-defence mutants: each redundant clause must reject the bad input ALONE ------------------

# Each entry: (a line fragment unique to one defence, a mutation the OTHER defence would also
# catch). Deleting the named line from a THROWAWAY copy must leave the copy still rejecting.
PER_DEFENCE = [
    ("if list(stages or []) != list(EXPECTED_LOAD_STAGES):",
     "load_stages", []),
    ("if len(stages or []) != len(EXPECTED_LOAD_STAGES):",
     "load_stages", []),
    ("if ev.get(\"census_fields\") != EXPECTED_CENSUS_FIELDS:",
     "census_fields", 2),
]


@pytest.mark.parametrize("marker,field,bad_value", PER_DEFENCE)
def test_each_defence_alone_rejects(golden, marker, field, bad_value):
    """Delete ONE defence in a THROWAWAY COPY and assert the copy STILL rejects the bad dump.

    This is bead oo-jor's lesson made executable: a property held by exactly one line is one
    refactor away from being held by none, and a surviving mutant is only acceptable when the
    redundancy is deliberate AND pinned. Nothing in the real tree is touched.
    """
    with open(CHECKER_SRC, "r", encoding="utf-8") as handle:
        source = handle.read()
    assert marker in source, "the defence %r is no longer in the checker; this pin is stale" % marker
    # Replace the guard's CONDITION with something that never fires, so only that one defence is
    # removed and the block's body stays syntactically valid.
    mutated = source.replace(marker, marker.replace("if ", "if False and ", 1), 1)
    assert mutated != source

    tmp = tempfile.mkdtemp(prefix="wseo_defence_", dir=os.environ.get("LOCALAPPDATA", None) and
                           os.path.join(os.environ["LOCALAPPDATA"], "Temp") or None)
    try:
        path = os.path.join(tmp, "mutated_checker.py")
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(mutated)
        bad = copy.deepcopy(golden)
        bad["evidence"][field] = bad_value
        blob = os.path.join(tmp, "bad.json")
        with open(blob, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(bad, handle)
        proc = subprocess.run([sys.executable, path, blob], capture_output=True, text=True)
        assert proc.returncode == 1, (
            "with the defence %r removed, the checker ACCEPTED a dump whose %s is %r. The "
            "property is held by that one line alone: either restore a second defence or accept "
            "that a refactor can silently delete it.\nstdout: %s\nstderr: %s"
            % (marker, field, bad_value, proc.stdout, proc.stderr))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# --- the knob gate --------------------------------------------------------------------------------

def test_gate_passes_on_the_committed_tree():
    proc = subprocess.run([sys.executable, GATE], capture_output=True, text=True,
                          cwd=REPO_ROOT)
    assert proc.returncode == 0, "gate_014_spec.py failed:\n%s\n%s" % (proc.stdout, proc.stderr)
    assert "PASS" in proc.stdout


@pytest.mark.parametrize("knob,value,why", [
    ("seed", 31337, "a changed seed decouples the spec from the golden it was blessed with, and "
                    "a fresh-run-vs-golden comparison cannot see it because it moves BOTH sides"),
    ("ticks", 0, "a zero tick budget means no game time passed"),
    ("galaxy_number", 0, "galaxy 0 is a default new commander's galaxy"),
    ("quant_decimals", 6, "coarsening or sharpening quantisation off-policy makes goldens pass"),
    ("expected_written_by_version", "1.75", "the story's claim, not the file's"),
    ("expected_mission_novacount_value", "", "an empty expectation reads like an absent variable"),
    ("station_ai", "rockHermitAI.plist", "pointing this at a real AI re-opens the miner race"),
    ("expected_legacy_upgrades", [], "the engine's own witness of the migration, deleted"),
    ("load_save", "upstream/oolite-tests/Checklist-files/Missions/Trumbles.oolite-save",
     "a SIBLING checklist save: a different scenario wearing this one's golden"),
])
def test_gate_rejects_a_drifted_spec(knob, value, why, tmp_path):
    """Mutate a THROWAWAY COPY of spec.json and assert the gate goes RED.

    The gate resolves its spec from `tests/golden/scenarios/014-nova/spec.json` first, so the
    mutant is written into a COPY OF THE WHOLE REPO's relevant files - no: instead the copy is
    made by pointing the gate at a temp tree, which is why the gate is invoked as a subprocess in
    a scratch checkout of the two files it reads. Nothing in the real tree is modified.
    """
    src_spec = spec_path()
    with open(src_spec, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    spec[knob] = value

    # Build a minimal scratch tree: tests/golden/{nova_load.py,gate_014_spec.py,pending/...}
    root = tmp_path / "repo"
    golden_dir = root / "tests" / "golden"
    pending = golden_dir / "pending" / SCENARIO
    pending.mkdir(parents=True)
    (root / "upstream" / "oolite" / "tests" / "component").mkdir(parents=True)
    shutil.copy(os.path.join(HERE, "nova_load.py"), golden_dir / "nova_load.py")
    shutil.copy(GATE, golden_dir / "gate_014_spec.py")
    shutil.copy(os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py"),
                root / "upstream" / "oolite" / "tests" / "component" / "console.py")
    prov = provenance_path()
    assert prov, "no provenance.json; the gate cannot check knob agreement"
    shutil.copy(prov, pending / "provenance.json")
    with open(pending / "spec.json", "w", encoding="utf-8", newline="\n") as handle:
        json.dump(spec, handle, indent=2)

    proc = subprocess.run([sys.executable, str(golden_dir / "gate_014_spec.py")],
                          capture_output=True, text=True, cwd=str(root))
    assert proc.returncode == 1, (
        "the gate stayed GREEN with %s set to %r. %s.\nstdout: %s\nstderr: %s"
        % (knob, value, why, proc.stdout, proc.stderr))


def test_gate_rejects_a_hardcoded_knob(tmp_path):
    """A knob READ ONLY TO BE PRINTED is decoration. Rewrite a THROWAWAY COPY of nova_load.py so
    assert_ran() uses a LITERAL instead of spec["expected_written_by_version"], and assert the
    gate's AST check catches it - a substring check would not, because the string still appears
    elsewhere in the file (bead oo-3ya measured exactly that survivor)."""
    with open(os.path.join(HERE, "nova_load.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    marker = 'if evidence["save_written_by_version"] != str(spec["expected_written_by_version"]):'
    assert marker in source, "the assertion this mutant targets has moved; the pin is stale"
    mutated = source.replace(marker,
                             'if evidence["save_written_by_version"] != "":', 1)
    assert mutated != source
    assert 'spec["expected_written_by_version"]' in mutated, (
        "the mutant must leave the string elsewhere in the file, or it would be caught by the "
        "substring check rather than by the AST check this test exists to pin")

    root = tmp_path / "repo"
    golden_dir = root / "tests" / "golden"
    pending = golden_dir / "pending" / SCENARIO
    pending.mkdir(parents=True)
    (root / "upstream" / "oolite" / "tests" / "component").mkdir(parents=True)
    with open(golden_dir / "nova_load.py", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(mutated)
    shutil.copy(GATE, golden_dir / "gate_014_spec.py")
    shutil.copy(os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py"),
                root / "upstream" / "oolite" / "tests" / "component" / "console.py")
    shutil.copy(spec_path(), pending / "spec.json")
    shutil.copy(provenance_path(), pending / "provenance.json")

    proc = subprocess.run([sys.executable, str(golden_dir / "gate_014_spec.py")],
                          capture_output=True, text=True, cwd=str(root))
    assert proc.returncode == 1, (
        "the gate stayed GREEN when assert_ran() read a LITERAL instead of "
        "spec['expected_written_by_version']. The knob would be decoration: the dump would report "
        "the spec's value while the behaviour ran on the literal.\n%s\n%s"
        % (proc.stdout, proc.stderr))


# --- the golden's own witness ---------------------------------------------------------------------

def test_provenance_witnesses_the_golden_byte_for_byte():
    """A GOLDEN CANNOT WITNESS ITSELF (bead oo-gxp). provenance.json is a SEPARATE file, so a
    one-quantised-unit edit of state.json is visible to it and invisible to any comparison of the
    golden against a copy of itself."""
    import hashlib
    g, p = golden_path(), provenance_path()
    assert g and p
    blob = open(g, "rb").read()
    with open(p, "r", encoding="utf-8") as handle:
        rec = (json.load(handle).get("artifacts") or {}).get("state.json")
    assert rec, "provenance records no artifacts.state.json digest"
    assert len(blob) == rec["bytes"]
    assert hashlib.sha256(blob).hexdigest() == rec["sha256"]


def test_the_frame_grid_is_never_byte_hashed_into_a_verdict():
    """llvmpipe is not bit-reproducible (bead oo-ae9), and this scenario's own sweep measured
    distinct frame digests over byte-identical dumps. The frame's digest may be RECORDED for
    provenance, but nothing may compare it for equality."""
    with open(os.path.join(HERE, "nova_load.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    assert "hash_got" in source and "distance" in source, (
        "compare_frame no longer computes a distance; if the frame is being compared by hash "
        "equality the gate will flake on renderer noise rather than on the product")
    prov = provenance_path()
    with open(prov, "r", encoding="utf-8") as handle:
        p = json.load(handle)
    assert (p.get("artifacts") or {}).get("frame.grid", {}).get("note"), (
        "provenance records no note explaining why frame.grid's digest is NOT a gate predicate; "
        "without it the next agent adds the byte comparison the measurements forbid")
