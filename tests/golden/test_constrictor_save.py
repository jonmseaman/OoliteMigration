"""Offline falsifiability tests for golden scenario 013-constrictor. No game is launched.

These pin the things a live run cannot: that each defence in check_constrictor_evidence.py REJECTS
the known-bad input ON ITS OWN, that the spec's determinism knobs agree with the knobs the golden
was BLESSED with, and that the stored golden is byte-for-byte the artifact provenance witnesses.

THE RULE THESE EXIST TO HONOUR (bead oo-jor): for every property a gate defends, write TWO
mutants - one that corrupts the DATA and one that WEAKENS THE CHECKER - because only the second
catches a gate that validates data with a validator nobody validates. Every checker mutation here
is written to a THROWAWAY COPY under a tmp_path; the real file is never touched.
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

SCENARIO = "013-constrictor"
CHECKER = os.path.join(HERE, "check_constrictor_evidence.py")
SCRIPT = os.path.join(HERE, "constrictor_save.py")

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
    proc = subprocess.run([sys.executable, checker, str(path)],
                          capture_output=True, text=True)
    return proc.returncode, (proc.stdout + proc.stderr)


# --- the scenario's own shape --------------------------------------------------------------------

def test_the_scenario_script_and_checker_are_importable():
    for path in (SCRIPT, CHECKER):
        proc = subprocess.run([sys.executable, "-m", "py_compile", path],
                              capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr


def test_the_save_fixture_exists_and_carries_mission_variables(spec):
    import plistlib

    path = os.path.join(REPO_ROOT, *spec["load_save"].split("/"))
    assert os.path.isfile(path), "the fixture this scenario loads is missing: %s" % path
    with open(path, "rb") as fh:
        data = plistlib.load(fh)
    assert "mission_variables" in data, (
        "%s has no mission_variables; the whole point of this scenario is mission state" % path)
    assert "conhunt" not in {k.replace("mission_", "", 1) for k in data["mission_variables"]}, (
        "the fixture now carries a conhunt mission variable. This scenario asserts its ABSENCE, "
        "measured from ship_kills being exactly 255 and the mission script's `score > 255` "
        "threshold. If upstream changed the fixture this is a FINDING: re-measure, do not edit "
        "the assertion to match.")
    assert int(data["ship_kills"]) == spec["expected_score"], (
        "the fixture's ship_kills moved to %r; the spec pins %r, and that exact value is why "
        "conhunt is absent" % (data["ship_kills"], spec["expected_score"]))


def test_every_determinism_knob_is_actually_read_by_the_script(spec):
    """A knob no code reads is decoration: change it and no line goes red."""
    with open(SCRIPT, "r", encoding="utf-8") as fh:
        src = fh.read()
    for knob in ("seed", "system_id", "ticks", "tick_seconds", "load_save", "control_save",
                 "mission_script_name", "expected_live_mission_handlers",
                 "expected_mission_variables", "expected_mission_conhunt",
                 "expected_mission_conhunt_present", "expected_commander_name", "expected_score"):
        assert 'spec["%s"]' % knob in src, (
            "constrictor_save.py never reads spec[%r]; the knob is decoration - if someone "
            "changed it, no line would go red" % knob)


def test_spec_knobs_equal_the_knobs_the_golden_was_blessed_with(spec, provenance):
    """bead oo-3ya: a fresh-run-vs-golden comparison CANNOT catch a changed seed, because
    changing the seed changes both sides. The witness has to be the provenance."""
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


# --- the stored golden carries the mission evidence ----------------------------------------------

def test_the_stored_golden_passes_the_evidence_checker(golden_path):
    rc, out = run_checker(golden_path)
    assert rc == 0, out


def test_the_golden_carries_mission_variables_at_top_level_and_in_evidence(golden):
    assert golden["mission_variables"] == golden["evidence"]["mission_variables"]
    assert golden["mission_variables"] == {
        "CT_thargonCount": 0, "snoopers_CRCNews": "|", "snoopers_usedSlots": 0,
        "trumbles": "NOT_NOW"}


def test_a_usage_error_is_distinguishable_from_a_verdict(tmp_path):
    """rc=2 means 'I cannot tell you'; it is never 'they match'."""
    rc, _ = run_checker(tmp_path / "does-not-exist.json")
    assert rc == 2
    bad = tmp_path / "bad.json"
    bad.write_text("{not json", encoding="utf-8")
    rc, _ = run_checker(bad)
    assert rc == 2


# --- DATA mutants: each corrupted field must be REJECTED ------------------------------------------

DATA_MUTANTS = (
    ("mission_conhunt set to MISSION_COMPLETE (the wrong-save signature)",
     lambda d: d["evidence"].update(mission_conhunt="MISSION_COMPLETE",
                                    mission_conhunt_present=True)),
    ("a mission variable's value changed",
     lambda d: (d["evidence"]["mission_variables"].update(trumbles="OK"),
                d["mission_variables"].update(trumbles="OK"))),
    ("the mission variables emptied (a default new game)",
     lambda d: (d["evidence"].update(mission_variables={}), d.update(mission_variables={}))),
    ("the live mission handlers emptied (a completed-mission save)",
     lambda d: d["evidence"].update(live_mission_handlers=[])),
    ("one live handler dropped",
     lambda d: d["evidence"].update(live_mission_handlers=["guiScreenChanged",
                                                           "systemWillPopulate"])),
    ("the commander swapped",
     lambda d: d["evidence"].update(commander_name="Jameson")),
    ("the system swapped", lambda d: d["evidence"].update(system_name="Lave", system_id=7)),
    ("the score moved by one", lambda d: d["evidence"].update(score=256)),
    ("the save-format version dropped",
     lambda d: d["evidence"].update(save_format_version="1.90")),
    ("the save file swapped",
     lambda d: d["evidence"].update(save_file="ThargoidPlans.oolite-save")),
    ("the mission script reported as not loaded",
     lambda d: d["evidence"].update(mission_script_loaded=False)),
    ("the top-level mission_variables desynchronised from evidence",
     lambda d: d.update(mission_variables={"trumbles": "NOT_NOW"})),
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
# to still reject the matching bad input - i.e. each defence must be load-bearing ON ITS OWN, or,
# where a property is deliberately defended twice, the redundancy is pinned so a refactor cannot
# silently collapse it. The real file is NEVER touched.

CHECKER_MUTANTS = (
    ("EXPECTED_CONHUNT_PRESENT flipped to True",
     'EXPECTED_CONHUNT_PRESENT = False', 'EXPECTED_CONHUNT_PRESENT = True',
     lambda d: d["evidence"].update(mission_conhunt_present=True)),
    # The bad input here is a WRONG, NON-EMPTY handler list. An EMPTY list is caught by a SECOND,
    # independent defence (`not handlers`), so emptying the constant and feeding [] would be an
    # equivalent mutant - see test_the_empty_handler_list_is_defended_twice, which pins that
    # redundancy deliberately instead of removing it (bead oo-jor's classification).
    ("EXPECTED_LIVE_HANDLERS reduced to one name",
     'EXPECTED_LIVE_HANDLERS = ("guiScreenChanged", "missionScreenOpportunity", '
     '"systemWillPopulate")',
     'EXPECTED_LIVE_HANDLERS = ("guiScreenChanged",)',
     lambda d: d["evidence"].update(live_mission_handlers=["guiScreenChanged"])),
    ("EXPECTED_MISSION_VARIABLES widened to the control save's set",
     'EXPECTED_MISSION_VARIABLES = {\n    "CT_thargonCount": 0,',
     'EXPECTED_MISSION_VARIABLES = {\n    "conhunt": "MISSION_COMPLETE",\n    "CT_thargonCount": 0,',
     lambda d: (d["evidence"]["mission_variables"].update(conhunt="MISSION_COMPLETE"),
                d["mission_variables"].update(conhunt="MISSION_COMPLETE"))),
    ("EXPECTED_COMMANDER widened",
     'EXPECTED_COMMANDER = "Constrictor"', 'EXPECTED_COMMANDER = "Jameson"',
     lambda d: d["evidence"].update(commander_name="Jameson")),
    ("EXPECTED_SCORE widened",
     "EXPECTED_SCORE = 255", "EXPECTED_SCORE = 256",
     lambda d: d["evidence"].update(score=256)),
)


@pytest.mark.parametrize("label,old,new,mutate", CHECKER_MUTANTS,
                         ids=[m[0] for m in CHECKER_MUTANTS])
def test_weakening_the_checker_stops_it_discriminating(golden, tmp_path, label, old, new, mutate):
    """Each constant must be WHAT DOES THE DISCRIMINATING, so a future edit that loosens it is a
    real behaviour change and not a no-op. The bad input is REJECTED by the real checker and
    ACCEPTED by the weakened copy."""
    source = open(CHECKER, "r", encoding="utf-8").read()
    assert old in source, "the checker no longer contains %r; this mutant is stale" % old
    weakened = tmp_path / "weak_checker.py"
    mutated_source = source.replace(old, new, 1)
    assert mutated_source != source, "the mutation was a no-op; this mutant proves nothing"
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


def test_the_empty_handler_list_is_defended_twice(golden, tmp_path):
    """DELIBERATE REDUNDANCY, PINNED BEHAVIOURALLY (bead oo-jor).

    `live_mission_handlers == []` is the wrong-save AND the dead-run signature, so the checker
    holds it with TWO independent clauses: `not handlers` (the emptiness clause) and
    `sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS)` (the exact-set clause). Removing EITHER
    leaves the property fully enforced by the other - which is why emptying EXPECTED_LIVE_HANDLERS
    is an EQUIVALENT mutant, not a hole. This test asserts EACH defence ALONE still rejects [], so
    a later refactor cannot silently collapse the redundancy, and that removing BOTH - the only
    mutation that genuinely changes behaviour - DOES let the bad input through.
    """
    source = open(CHECKER, "r", encoding="utf-8").read()
    empt = "if not isinstance(handlers, list) or not handlers:"
    exact = "elif sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS):"
    assert empt in source and exact in source, "the two handler defences have been renamed"

    data = json.loads(json.dumps(golden))
    data["evidence"]["live_mission_handlers"] = []
    path = tmp_path / "no-handlers.json"
    path.write_text(json.dumps(data), encoding="utf-8")

    # Defence 1 removed: the exact-set clause alone must still reject. (The `elif` becomes an `if`
    # so it is still reached once the emptiness branch no longer fires on [].)
    only_exact = tmp_path / "only_exact.py"
    only_exact.write_text(
        source.replace(empt, "if not isinstance(handlers, list):", 1)
              .replace(exact, "if sorted(handlers) != sorted(EXPECTED_LIVE_HANDLERS):", 1),
        encoding="utf-8")
    rc, out = run_checker(path, checker=str(only_exact))
    assert rc == 1, ("with the emptiness clause removed the checker ACCEPTED an EMPTY handler "
                     "list (rc=%d); the property is then held by a single line.\n%s" % (rc, out))

    # Defence 2 removed: the emptiness clause alone must still reject.
    only_empty = tmp_path / "only_empty.py"
    only_empty.write_text(source.replace(exact, "elif False:", 1), encoding="utf-8")
    rc, out = run_checker(path, checker=str(only_empty))
    assert rc == 1, ("with the exact-set clause removed the checker ACCEPTED an EMPTY handler "
                     "list (rc=%d)\n%s" % (rc, out))

    # BOTH removed: the only mutation that genuinely changes behaviour must let it through.
    neither = tmp_path / "neither.py"
    neither.write_text(source.replace(empt, "if False:", 1).replace(exact, "elif False:", 1),
                       encoding="utf-8")
    rc, out = run_checker(path, checker=str(neither))
    assert rc == 0, ("with BOTH handler defences removed the checker still rejected an empty "
                     "handler list (rc=%d), so something else is doing this work and the two "
                     "clauses above are not the defence they appear to be.\n%s" % (rc, out))


def test_the_differential_subject_is_the_blessed_golden(golden, provenance):
    """SECOND, INDEPENDENT WITNESS on the differential (found by mutation).

    The mutation run showed that removing `gate_013_differential.py`'s subject/golden agreement
    predicate AND desynchronising provenance's recorded subject left the ENTIRE acceptance block
    green: a blind gate, defended in exactly one place. Without this, provenance could claim the
    blessed dump had `mission_conhunt=MISSION_COMPLETE` while the golden says otherwise, and the
    differential would then be evidence about a dump nobody shipped.
    """
    md = provenance.get("mission_state_differential")
    assert md, "provenance records no mission_state_differential"
    sub = md.get("subject") or {}
    ev = golden["evidence"]
    for key in ("commander_name", "system_name", "system_id", "mission_conhunt",
                "mission_conhunt_present", "live_mission_handlers", "mission_script_loaded"):
        assert sub.get(key) == ev.get(key), (
            "provenance subject.%s=%r but the blessed golden reports %r; the differential was "
            "measured against a different dump than the one blessed" % (key, sub.get(key),
                                                                        ev.get(key)))
    for arm in ("control_thargoidplans", "control_fresh_game"):
        assert arm in md, "provenance records no %s control arm" % arm
        moved = [k for k in sub if md[arm].get(k) != sub.get(k)]
        assert moved, (
            "control arm %r moves NO mission-state field against the subject; the dump does not "
            "observe which save was loaded and the golden is vacuous" % arm)


def test_the_checker_rejects_an_empty_dump(tmp_path):
    path = tmp_path / "empty.json"
    path.write_text("{}", encoding="utf-8")
    rc, out = run_checker(path)
    assert rc == 1 and "no `evidence` object" in out


def test_the_mutation_gate_carries_its_mutants(golden_path):
    """A MUTATION GATE THAT RUNS ZERO MUTANTS EXITS 0 AND REPORTS SUCCESS.

    Measured: emptying `gate_013_mutants.MUTANTS` left that gate printing "all 0 data mutants ...
    are REJECTED" with rc=0 — true, and exactly as useful as no gate. The gate now carries its own
    `MIN_MUTANTS` floor, and this test pins the count from OUTSIDE the file, so lowering the floor
    and emptying the list in one edit still goes red here.
    """
    import importlib.util

    path = os.path.join(HERE, "gate_013_mutants.py")
    spec_ = importlib.util.spec_from_file_location("gate_013_mutants", path)
    mod = importlib.util.module_from_spec(spec_)
    spec_.loader.exec_module(mod)
    assert len(mod.MUTANTS) >= 8, (
        "gate_013_mutants.py carries %d mutant(s); a mutation gate with no mutants passes "
        "vacuously" % len(mod.MUTANTS))
    assert mod.MIN_MUTANTS >= 8, (
        "gate_013_mutants.MIN_MUTANTS was lowered to %d; that floor is the gate's own defence "
        "against being emptied" % mod.MIN_MUTANTS)
    # And it must actually go red on this golden's mutants.
    proc = subprocess.run([sys.executable, path, golden_path], capture_output=True, text=True)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "all %d data mutants" % len(mod.MUTANTS) in proc.stdout, proc.stdout
