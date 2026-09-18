"""Offline falsifiability suite for golden scenario 016. No game, no build, no network.

WHAT THIS FILE IS FOR
---------------------
Scenario 016's claim is "a 1.75 save round-trips into the modern engine, except for three DECLARED
migrations". That claim is only worth the artifact it is stored in if the CHECKER that judges it
can actually say NO. Bead oo-jor's rule applies: for every property the gate defends, write TWO
mutants - one that corrupts the DATA and one that WEAKENS THE CHECKER - because only the second
catches a validator nobody validates.

Every test builds a THROWAWAY COPY under pytest's tmp_path. The real dump, spec, provenance, gate
and checker are NEVER written to. That is not tidiness: restore-on-exit does not run when a worker
is killed at its timeout, and the orchestrator's gc can harvest-and-commit a worktree at any
instant - which is exactly how bead oo-dto committed `if False:` in place of the one predicate its
scenario was named for.

`test_stored_golden_is_witnessed` is the baseline every mutant depends on: a checker that is
already red registers a false kill for every mutant run against it (bead oo-4vdc).
"""

import copy
import json
import os
import shutil
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "016-cloaking-save"

CHECKER = os.path.join(HERE, "check_cloaking_evidence.py")
GATE = os.path.join(HERE, "gate_016_spec.py")
SCRIPT = os.path.join(HERE, "cloaking_load.py")

sys.path.insert(0, HERE)


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s found; searched %r" % (what, candidates))


def golden_dir():
    for candidate in (os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
                      os.path.join(HERE, "pending", SCENARIO)):
        if os.path.isfile(os.path.join(candidate, "state.json")):
            return candidate
    raise AssertionError("no blessed state.json for %s in either location" % SCENARIO)


def spec_path():
    return _first((os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
                   os.path.join(HERE, "pending", SCENARIO, "spec.json")), "spec.json")


@pytest.fixture(scope="module")
def spec():
    with open(spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def golden():
    with open(os.path.join(golden_dir(), "state.json"), "r", encoding="utf-8") as handle:
        return json.load(handle)


def run_checker(path, cwd=REPO_ROOT, checker=CHECKER):
    return subprocess.run([sys.executable, checker, path, "--label", "test"],
                          cwd=cwd, capture_output=True, text=True)


def write_dump(tmp_path, dump, name="mutant.json"):
    p = tmp_path / name
    p.write_text(json.dumps(dump, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    return str(p)


# ===========================================================================================
# BASELINE - every mutant below is meaningless without this
# ===========================================================================================

def test_stored_golden_is_witnessed():
    """The blessed artifact must PASS its own offline checker. A checker that is already red
    registers a false kill for every mutant run against it (bead oo-4vdc)."""
    result = run_checker(os.path.join(golden_dir(), "state.json"))
    assert result.returncode == 0, "baseline is RED:\n%s\n%s" % (result.stdout, result.stderr)
    assert "witnesses a 1.75-era save round-tripping" in result.stdout


def test_unmutated_copy_of_the_golden_also_passes(tmp_path, golden):
    """Round-tripping the golden through json must not change the verdict; if it did, every
    mutant below would be measuring the serialisation rather than the mutation."""
    assert run_checker(write_dump(tmp_path, golden)).returncode == 0


def test_gate_spec_passes_unmutated():
    result = subprocess.run([sys.executable, GATE], cwd=REPO_ROOT, capture_output=True, text=True)
    assert result.returncode == 0, "gate baseline is RED:\n%s\n%s" % (result.stdout, result.stderr)


# ===========================================================================================
# DATA MUTANTS - break the artifact, the unmutated checker must say NO
# ===========================================================================================

def test_rejects_a_dump_with_no_evidence_block(tmp_path, golden):
    d = copy.deepcopy(golden)
    d.pop("evidence")
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 2, r.stdout + r.stderr          # cannot tell, not "equal"
    assert "no `evidence` block" in r.stderr


def test_rejects_a_dump_from_the_wrong_fixture(tmp_path, golden):
    d = copy.deepcopy(golden)
    d["evidence"]["save_file"] = "Trumbles.oolite-save"
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "not the" in r.stderr and "CloakingDevice" in r.stderr


def test_rejects_a_save_from_a_different_format_era(tmp_path, golden):
    """THE COMPATIBILITY CONTRACT. A fixture silently replaced by a modern save would make every
    other clause pass while the 1.75 deserialisation path went untested."""
    d = copy.deepcopy(golden)
    d["evidence"]["save_written_by_version"] = "1.90"
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "1.75" in r.stderr


def test_rejects_an_empty_mission_variable_key_set(tmp_path, golden):
    """AN EMPTY SET IS A SUBSET OF EVERY OTHER. A fresh commander has no mission variables, so an
    empty key set is precisely what a run that ignored -load produces."""
    d = copy.deepcopy(golden)
    d["evidence"]["mission_variable_keys_in_file"] = []
    d["evidence"]["mission_variable_keys_in_engine"] = []
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "FRESH COMMANDER HAS NONE" in r.stderr or "not the" in r.stderr


def test_rejects_a_mission_variable_key_dropped_from_the_engine_side(tmp_path, golden, spec):
    """THE EMPTY-STRING TRAP, TESTED DIRECTLY. Presence is witnessed as a KEY SET, so a key that
    vanished from the engine is caught even though a value comparison would see "" == absent."""
    d = copy.deepcopy(golden)
    d["evidence"]["mission_variable_keys_in_engine"] = [
        k for k in d["evidence"]["mission_variable_keys_in_engine"] if k != "mission_trumbles"]
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "mission_variable_keys_in_engine" in r.stderr


def test_rejects_an_undeclared_census_field_that_stopped_round_tripping(tmp_path, golden):
    """THE REGRESSION THIS SCENARIO EXISTS TO CATCH: a field the loader silently changed."""
    d = copy.deepcopy(golden)
    d["evidence"]["census_differing"] = sorted(d["evidence"]["census_differing"] + ["ship_kills"])
    d["evidence"]["census_detail"]["ship_kills"] = {"in_file": 1661, "in_engine": 0,
                                                    "declared": False, "mechanism": None}
    d["evidence"]["census_equal_count"] -= 1
    d["evidence"]["census_equal"] = [k for k in d["evidence"]["census_equal"] if k != "ship_kills"]
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "UNDECLARED" in r.stderr and "ship_kills" in r.stderr


def test_rejects_a_declared_migration_that_stopped_happening(tmp_path, golden):
    """THE OTHER DIRECTION OF THE CLOSED PAIR. A gate that only caught new differences would let
    the energy-bomb credit compensation quietly stop without anything going red."""
    d = copy.deepcopy(golden)
    d["evidence"]["census_differing"] = [k for k in d["evidence"]["census_differing"]
                                         if k != "credits"]
    d["evidence"]["census_detail"].pop("credits", None)
    d["evidence"]["census_equal"] = sorted(d["evidence"]["census_equal"] + ["credits"])
    d["evidence"]["census_equal_count"] += 1
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "DECLARED BUT ABSENT" in r.stderr and "credits" in r.stderr


def test_rejects_a_changed_delta_on_a_declared_migration(tmp_path, golden):
    """A migration declared with the WRONG magnitude accepts any change to that field."""
    d = copy.deepcopy(golden)
    d["evidence"]["census_detail"]["credits"]["in_engine"] = (
        float(d["evidence"]["census_detail"]["credits"]["in_file"]) + 1.0)
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "delta" in r.stderr


def test_rejects_the_deserialiser_copy_signature(tmp_path, golden):
    """EQUAL VALUES ARE THE DESERIALISER-COPY SIGNATURE for cloakcounter: the save loaded but the
    world-script event never ran. That is scenario 005's subject and a legitimate failure here."""
    d = copy.deepcopy(golden)
    det = d["evidence"]["mission_variables_detail"]["mission_cloakcounter"]
    det["in_engine"] = det["in_file"]
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "DESERIALISER-COPY SIGNATURE" in r.stderr


def test_rejects_an_equipment_key_silently_dropped_by_the_loader(tmp_path, golden):
    d = copy.deepcopy(golden)
    d["evidence"]["equipment_missing_in_engine"] = sorted(
        d["evidence"]["equipment_missing_in_engine"] + ["EQ_ESCAPE_POD"])
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "EQ_ESCAPE_POD" in r.stderr


def test_rejects_a_declared_equipment_removal_that_stopped(tmp_path, golden):
    d = copy.deepcopy(golden)
    d["evidence"]["equipment_missing_in_engine"] = []
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "stopped happening" in r.stderr


def test_rejects_a_missing_engine_testimony_line(tmp_path, golden):
    """THE INDEPENDENT WITNESS FOR THE CREDIT DELTA. Without the loader's own log line the +900 is
    arithmetic that happens to add up - it could equally be a save whose credits were corrupted by
    exactly that amount."""
    d = copy.deepcopy(golden)
    d["evidence"]["upgrade_log_lines"] = []
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "testimony" in r.stderr


def test_rejects_a_shrunken_census(tmp_path, golden, spec):
    d = copy.deepcopy(golden)
    d["evidence"]["census_fields"] = 3
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "smaller hat" in r.stderr or "spec declares" in r.stderr


def test_rejects_a_dump_with_no_top_level_mission_variables(tmp_path, golden):
    """The bead requires the canonical dump to carry mission_variables, in particular
    mission_cloakcounter, BY NAME."""
    d = copy.deepcopy(golden)
    d.pop("mission_variables")
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "mission_variables" in r.stderr


def test_rejects_a_dump_missing_the_cloakcounter_by_name(tmp_path, golden):
    d = copy.deepcopy(golden)
    d["mission_variables"].pop("mission_cloakcounter")
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "mission_cloakcounter" in r.stderr


def test_rejects_an_unsettled_world(tmp_path, golden):
    for key in ("world_at_rest", "world_reached_fixed_point", "tick_budget_met"):
        d = copy.deepcopy(golden)
        d["evidence"][key] = False
        r = run_checker(write_dump(tmp_path, d, name="%s.json" % key))
        assert r.returncode == 1, key
        assert key in r.stderr


def test_rejects_a_dump_produced_at_a_different_seed(tmp_path, golden, spec):
    """A fresh-run-vs-golden comparison CANNOT catch this: changing the seed changes both sides."""
    d = copy.deepcopy(golden)
    d["evidence"]["seed"] = 31337
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "seed" in r.stderr


def test_rejects_a_frame_digest_inside_the_dump(tmp_path, golden):
    """THE DELIBERATE ASYMMETRY. llvmpipe is not bit-reproducible: this scenario's own sweep
    produced ten DISTINCT frame-grid digests over ten BYTE-IDENTICAL dumps, so a frame hash inside
    state.json would make the golden comparison flake on renderer noise."""
    d = copy.deepcopy(golden)
    d["frame_hash"] = "deadbeef"
    r = run_checker(write_dump(tmp_path, d))
    assert r.returncode == 1
    assert "not bit-reproducible" in r.stderr or "frame digest" in r.stderr


# ===========================================================================================
# CHECKER MUTANTS - weaken one defence, feed it the input that defence exists to reject, and
# assert the MUTATED checker goes GREEN. That proves the defence is what does the rejecting and
# not a neighbour (bead oo-9w5's MISKILL concept, bead oo-jor's "mutate the checker" rule).
# ===========================================================================================

CHECKER_MUTANTS = [
    pytest.param(
        "the closed-pair exact-set clause",
        ("        if got != want:", "        if False:"),
        "undeclared_drift",
        id="closed_pair_exact_set"),
    pytest.param(
        "the mission-variable key-set presence clause",
        ("        if sorted(ev[side]) != want_keys:", "        if False:"),
        "dropped_key",
        id="key_set_presence"),
    pytest.param(
        "the engine-testimony clause for the credit compensation",
        ("        if rule[\"compensation_log_substring\"] not in text:", "        if False:"),
        "no_testimony",
        id="engine_testimony"),
    pytest.param(
        "the equipment containment clause",
        ("    if unexplained:", "    if False:"),
        "dropped_equipment",
        id="equipment_containment"),
]


def _mutant_input(kind, golden):
    d = copy.deepcopy(golden)
    if kind == "undeclared_drift":
        d["evidence"]["census_differing"] = sorted(d["evidence"]["census_differing"] + ["fuel"])
        d["evidence"]["census_detail"]["fuel"] = {"in_file": 7.0, "in_engine": 0.0,
                                                  "declared": False, "mechanism": None}
        d["evidence"]["census_equal"] = [k for k in d["evidence"]["census_equal"] if k != "fuel"]
    elif kind == "dropped_key":
        d["evidence"]["mission_variable_keys_in_engine"] = [
            k for k in d["evidence"]["mission_variable_keys_in_engine"] if k != "mission_nova"]
    elif kind == "no_testimony":
        d["evidence"]["upgrade_log_lines"] = []
    elif kind == "dropped_equipment":
        d["evidence"]["equipment_missing_in_engine"] = sorted(
            d["evidence"]["equipment_missing_in_engine"] + ["EQ_ECM"])
    else:  # pragma: no cover - a typo in the table must be loud, not silent
        raise AssertionError("unknown mutant input kind %r" % kind)
    return d


def _mutated_checker(tmp_path, old, new, name):
    """Write a MUTATED copy of the checker into a throwaway tree that mirrors the paths it needs.

    The checker resolves spec.json relative to its OWN __file__, so a mutant dropped anywhere else
    exits 2 ("no spec.json") for a reason that has nothing to do with the mutation - and an
    rc!=0 assertion would then read that as a kill. The tree is rebuilt from copies; the repo is
    never written to.
    """
    src = open(CHECKER, "r", encoding="utf-8").read()
    assert src.count(old) == 1, ("checker mutant for %s no longer matches exactly one line (%d); "
                                 "the checker was refactored and this test was not"
                                 % (name, src.count(old)))
    root = tmp_path / "chk"
    staged = root / "tests" / "golden" / "pending" / SCENARIO
    staged.mkdir(parents=True)
    shutil.copy(spec_path(), staged / "spec.json")
    target = root / "tests" / "golden" / "check_cloaking_evidence.py"
    target.write_text(src.replace(old, new), encoding="utf-8")
    return str(target)


@pytest.mark.parametrize("name,edit,kind", CHECKER_MUTANTS)
def test_each_checker_defence_is_load_bearing(tmp_path, golden, name, edit, kind):
    """Two assertions per defence, and BOTH are required:

    1. the UNMUTATED checker REJECTS the bad input - the defence (or a neighbour) fires;
    2. the MUTATED checker ACCEPTS it - so the defence under test is what fired, not a neighbour.

    If (2) also went red the mutant would be EQUIVALENT or the property redundantly defended
    (bead oo-jor's third cause for a survivor), and this test would say so rather than reporting a
    kill that never happened.
    """
    bad = write_dump(tmp_path, _mutant_input(kind, golden), name="bad.json")

    baseline = run_checker(bad)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject; rc=2 is "
        "a structural error, not a verdict, and the mutant below would register a false kill.\n%s%s"
        % (name, baseline.stdout, baseline.stderr))

    old, new = edit
    result = run_checker(bad, checker=_mutated_checker(tmp_path, old, new, name))
    assert result.returncode == 0, (
        "removing %s did NOT make the checker accept the bad input, so that clause is not what "
        "rejects it - either the mutant is EQUIVALENT or the property has a second, unpinned "
        "defence (bead oo-jor). Investigate before trusting the kill.\n%s%s"
        % (name, result.stdout, result.stderr))


# ===========================================================================================
# THE GATE'S OWN DEFENCES
# ===========================================================================================

def _gate_tree(tmp_path, spec_edit=None, prov_edit=None, gate_edit=None):
    """Run a THROWAWAY copy of the gate over throwaway copies of its inputs. Nothing in the repo
    is written."""
    root = tmp_path / "t"
    staged = root / "tests" / "golden" / "pending" / SCENARIO
    staged.mkdir(parents=True)
    comp = root / "upstream" / "oolite" / "tests" / "component"
    comp.mkdir(parents=True)
    shutil.copy(os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py"),
                comp / "console.py")

    gdir = golden_dir()
    for name in os.listdir(gdir):
        src = os.path.join(gdir, name)
        if os.path.isfile(src):
            shutil.copy(src, staged / name)
    shutil.copy(spec_path(), staged / "spec.json")
    shutil.copy(SCRIPT, root / "tests" / "golden" / "cloaking_load.py")

    src = open(GATE, "r", encoding="utf-8").read()
    if gate_edit:
        old, new = gate_edit
        assert src.count(old) == 1, "gate mutant %r matches %d times" % (old, src.count(old))
        src = src.replace(old, new)
    (root / "tests" / "golden" / "gate_016_spec.py").write_text(src, encoding="utf-8")

    for path, edit in ((staged / "spec.json", spec_edit),
                       (staged / "provenance.json", prov_edit)):
        if edit:
            data = json.loads(path.read_text(encoding="utf-8"))
            edit(data)
            path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")

    return subprocess.run([sys.executable, "tests/golden/gate_016_spec.py"],
                          cwd=str(root), capture_output=True, text=True)


def test_gate_tree_helper_is_green_unmutated(tmp_path):
    r = _gate_tree(tmp_path)
    assert r.returncode == 0, "the throwaway gate tree is RED before any mutation:\n%s%s" % (
        r.stdout, r.stderr)


def test_gate_rejects_a_seed_that_drifted_from_the_golden(tmp_path):
    """The failure a fresh-run-vs-golden comparison is structurally incapable of seeing."""
    r = _gate_tree(tmp_path, spec_edit=lambda s: s.update(seed=31337))
    assert r.returncode == 1
    assert "blessed" in r.stderr


def test_gate_rejects_a_tick_budget_that_reaches_the_cloak(tmp_path):
    """BEWARE THE CLOAK: bead oo-qwk5 measured the transition at t=21.6s."""
    r = _gate_tree(tmp_path, spec_edit=lambda s: s.update(ticks=400))
    assert r.returncode == 1
    assert "cloak" in r.stderr.lower()


def test_gate_rejects_a_declared_set_widened_in_the_spec_alone(tmp_path):
    """THE ONE WAY A FAILING RUN COULD BE MADE TO PASS: adding the drifting field to the declared
    set. provenance.json witnesses the set from OUTSIDE the spec, so widening one alone is red."""
    def widen(s):
        s["census_migrations"]["ship_kills"] = {"delta": 0, "mechanism": "invented"}
    r = _gate_tree(tmp_path, spec_edit=widen)
    assert r.returncode == 1
    assert "declared_migrations" in r.stderr or "ship_kills" in r.stderr


def test_gate_rejects_a_migration_declared_without_a_mechanism(tmp_path):
    def blank(s):
        s["census_migrations"]["credits"]["mechanism"] = ""
    r = _gate_tree(tmp_path, spec_edit=blank)
    assert r.returncode == 1
    assert "mechanism" in r.stderr


def test_gate_rejects_a_control_save_equal_to_the_subject(tmp_path):
    def same(s):
        s["control_save"] = s["load_save"]
    r = _gate_tree(tmp_path, spec_edit=same)
    assert r.returncode == 1
    assert "control" in r.stderr


def test_gate_rejects_a_coarsened_quantisation(tmp_path):
    r = _gate_tree(tmp_path, spec_edit=lambda s: s.update(quant_decimals=0))
    assert r.returncode == 1
    assert "quant" in r.stderr


def test_gate_rejects_a_stability_sweep_that_does_not_account_for_every_run(tmp_path):
    def lose(p):
        p["stability"]["dumps_written"] = 3
    r = _gate_tree(tmp_path, prov_edit=lose)
    assert r.returncode == 1
    assert "accounts for" in r.stderr or "dump" in r.stderr


def test_gate_rejects_provenance_with_no_state_json_digest(tmp_path):
    """A GOLDEN CANNOT WITNESS ITSELF (bead oo-gxp): without a digest in a SEPARATE file, a
    one-quantised-unit edit moves both sides of every self-comparison."""
    def strip(p):
        p["artifacts"].pop("state.json")
    r = _gate_tree(tmp_path, prov_edit=strip)
    assert r.returncode == 1
    assert "witness" in r.stderr.lower()


@pytest.mark.parametrize("name,edit,spec_edit,prov_edit", [
    pytest.param("the knob-drift clause",
                 ("    if drift:", "    if False:"),
                 lambda s: s.update(seed=31337), None, id="knob_drift"),
    pytest.param("the cloak tick-budget clause",
                 ("    if budget >= CLOAK_TRANSITION_SECONDS:", "    if False:"),
                 lambda s: s.update(ticks=400),
                 # THE RE-BLESS ARM. Moving ticks in spec.json ALONE also trips the knob-drift
                 # clause, so this mutant would be redundantly defended and the pairing below
                 # would - correctly - refuse to report a kill. Moving BOTH files is exactly what
                 # a deliberate re-bless looks like, and it is the case that matters: a
                 # maintainer who widens the tick budget and re-blesses the golden has a
                 # self-consistent pair of files, and the ONLY thing standing between them and a
                 # cloaking transition inside the measured window is this clause.
                 lambda p: p["scenario_knobs"].update(ticks=400), id="cloak_budget"),
    pytest.param("the declared-set provenance witness",
                 ("        if got != want:", "        if False:"),
                 lambda s: s["census_migrations"].update(
                     ship_kills={"delta": 0, "mechanism": "invented"}), None,
                 id="declared_witness"),
])
def test_each_gate_defence_is_load_bearing(tmp_path, name, edit, spec_edit, prov_edit):
    baseline = _gate_tree(tmp_path / "a", spec_edit=spec_edit, prov_edit=prov_edit)
    assert baseline.returncode == 1, (
        "the UNMUTATED gate did not FAIL (rc=1) on the spec that %s exists to reject:\n%s%s"
        % (name, baseline.stdout, baseline.stderr))
    mutated = _gate_tree(tmp_path / "b", spec_edit=spec_edit, prov_edit=prov_edit, gate_edit=edit)
    assert mutated.returncode == 0, (
        "removing %s did NOT make the gate accept the bad spec, so that clause is not what "
        "rejects it - the mutant is EQUIVALENT or the property is redundantly defended "
        "(bead oo-jor).\n%s%s" % (name, mutated.stdout, mutated.stderr))


# ===========================================================================================
# THE SPEC'S OWN CLAIMS, CHECKED AGAINST THE FIXTURE ON DISK
# ===========================================================================================

def test_the_fixture_still_carries_what_the_spec_claims(spec):
    """If upstream ever replaced the fixture, that is a FINDING - and it would otherwise surface
    as a mysterious value difference in a live run rather than by name here."""
    import plistlib
    path = os.path.join(REPO_ROOT, *spec["load_save"].split("/"))
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
    assert str(plist["written_by_version"]) == spec["save_format_version"]
    assert str(plist["player_name"]) == spec["expected_commander_name"]
    assert int(plist["galaxy_number"]) == spec["galaxy_number"]
    mv = plist["mission_variables"]
    assert sorted(mv) == sorted(spec["expected_mission_variable_keys"])
    assert int(mv["mission_cloakcounter"]) == \
        spec["mission_variable_write_exceptions"]["mission_cloakcounter"]["in_file"]
    assert len(plist["extra_equipment"]) == spec["expected_equipment_count"]
    assert "EQ_ENERGY_BOMB" in plist["extra_equipment"], (
        "the energy-bomb migration is the load-bearing equipment clause; a fixture without it "
        "makes that whole defence unevaluable")


def test_the_control_save_really_is_a_different_save(spec):
    """A wrong-save control whose two arms agree cannot move."""
    import plistlib
    a = os.path.join(REPO_ROOT, *spec["load_save"].split("/"))
    b = os.path.join(REPO_ROOT, *spec["control_save"].split("/"))
    assert a != b
    pa = plistlib.load(open(a, "rb"))
    pb = plistlib.load(open(b, "rb"))
    assert pa["player_name"] != pb["player_name"]
    assert pa["current_system_name"] != pb["current_system_name"]
    assert sorted(pa["mission_variables"]) != sorted(pb["mission_variables"]), (
        "the control carries the same mission variable key set as the subject, so the key-set "
        "presence defence could not tell the two apart")
    assert str(pb["written_by_version"]) == spec["save_format_version"], (
        "the control must be the SAME era as the subject - a control that differs in era as well "
        "as contents cannot isolate the contents")


def test_the_two_sides_of_the_census_are_read_by_different_code(spec):
    """Scenario 006's invariant, asserted structurally: the file side goes through plistlib in
    this process and the live side through a JS expression evaluated in ANOTHER OS process."""
    import cloaking_load
    src = open(SCRIPT, "r", encoding="utf-8").read()
    assert "plistlib.load" in src
    for field in spec["census"]:
        assert field["js"].strip(), field
    saved = cloaking_load.saved_census(
        spec, __import__("plistlib").load(
            open(os.path.join(REPO_ROOT, *spec["load_save"].split("/")), "rb")))
    assert len(saved) == len(spec["census"])
    # Not a single trivially-equal field: a census of zeros compares equal to any other.
    populated = [k for k, v in saved.items() if v not in ("", 0, 0.0, None)]
    assert len(populated) >= len(spec["census"]) // 2, saved


def test_normalise_refuses_an_unknown_kind():
    """NO CATCH-ALL BRANCH. A conversion invented to make two sides agree is how a round-trip
    claim becomes unfalsifiable."""
    import cloaking_load
    with pytest.raises(cloaking_load.Refusal):
        cloaking_load._normalise(1, "furlongs")


def test_normalise_refuses_an_unmapped_weapon_id(spec):
    import cloaking_load
    with pytest.raises(cloaking_load.Refusal):
        cloaking_load._normalise(99, "weapon_id", spec)


def test_norm_mv_does_not_conflate_a_boolean_with_the_string_one():
    """int(True) is 1 in Python, so a naive numeric branch would make True == "1"."""
    import cloaking_load
    assert cloaking_load._norm_mv(True) != cloaking_load._norm_mv("1")
    assert cloaking_load._norm_mv("13") == cloaking_load._norm_mv(13)
    assert cloaking_load._norm_mv("MISSION_COMPLETE") == "MISSION_COMPLETE"


def test_compare_sides_refuses_to_compare_an_object_with_itself():
    """A mapping always equals itself; using equality as the guard would refuse every good load,
    so the guard is IDENTITY (the in-memory twin of golden_diff's st_dev/st_ino check)."""
    import cloaking_load
    same = {"a": 1}
    with pytest.raises(cloaking_load.Refusal):
        cloaking_load.compare_sides(same, same, {})


def test_scenario_016_asserts_something_scenario_005_does_not(spec):
    """THE ANTI-DUPLICATE TEST. Bead oo-rkm's scenario 005 loads the SAME fixture. This scenario is
    only worth having if its gate fails on dumps 005's gate accepts.

    005's subject is the cloakcounter MOVING and the ambush spawning. 016's subject is everything
    else staying still. Structurally: 016's declared write set is 005's entire subject, and 016's
    census - fifteen fields including credits, equipment, weapons and entity_personality - is
    absent from 005's assertions altogether. A load that corrupted `credits` still fires the
    trigger and still passes 005; it fails here."""
    assert set(spec["mission_variable_write_exceptions"]) == {"mission_cloakcounter"}, (
        "016's DECLARED set must be exactly 005's subject; if it grew, the two beads have started "
        "asserting the same thing")
    census_keys = {f["plist"] for f in spec["census"]}
    assert "credits" in census_keys and "entity_personality" in census_keys
    assert len(census_keys) >= 12
    assert spec["census_migrations"], (
        "016's distinguishing content is the DECLARED MIGRATION set - the fields the 1.75 format "
        "does NOT round-trip verbatim. 005 measures none of them.")
    assert set(spec["census_migrations"]) & census_keys == set(spec["census_migrations"])
