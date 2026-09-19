"""Falsifiability suite for golden scenario 020 (hud-render-modes).

TWO KINDS OF ARM, AND BOTH ARE NEEDED
=====================================
DATA MUTANTS (`test_checker_rejects_*`) feed the evidence checker a dump carrying one specific
defect and require rc=1. They prove the checker rejects those inputs TODAY.

CHECKER MUTANTS (`test_clause_is_load_bearing_*`) go further, because data mutants alone cannot
tell a load-bearing clause from a redundant one: if two clauses overlap, either could be deleted
and every data mutant would still be caught by the other, leaving the suite green over a checker
that had lost half its teeth. Bead oo-xy0o measured exactly that hole on a checker that had
ALREADY LANDED. Each of those arms is bead oo-ghhw's two-sided pattern:

  1. the UNMUTATED checker must REJECT the input the clause exists to reject - otherwise the arm
     registers a FALSE KILL against an already-red checker (bead oo-4vdc);
  2. a THROWAWAY copy of the checker with exactly ONE clause weakened must now ACCEPT it.

If side 2 still rejects, the clause is REDUNDANT and the arm FAILS saying so. That is the finding
this file exists to produce.

NOTHING IN THE REPO IS WRITTEN TO. Sources are read, mutated in memory, written into pytest's
tmp_path, and the checker is run as a SUBPROCESS, so a weakened module can never leak into another
test's import cache.

NO ARM HERE LAUNCHES THE GAME. Every one is offline and takes milliseconds: a launching test goes
red from a sibling worker's orphan holding the console port, which is not a finding.
"""

import copy
import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "020-hud-render-modes"

HARNESS = os.path.join(HERE, "hud_render_modes.py")
CHECKER = os.path.join(HERE, "check_hud_render_evidence.py")
GATE = os.path.join(HERE, "gate_020_spec.py")

# Guarded location first, staged second - the same order every other artifact resolver uses, so
# this suite keeps working unchanged after Jon lands the scenario.
DIR_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
    os.path.join(HERE, "scenarios", SCENARIO),
    os.path.join(HERE, "pending", SCENARIO),
)


def artifact_dir():
    for path in DIR_CANDIDATES:
        if os.path.isfile(os.path.join(path, "state.json")):
            return path
    raise AssertionError("no blessed state.json for %s; searched %r"
                         % (SCENARIO, list(DIR_CANDIDATES)))


def spec_path():
    """spec.json may sit beside the golden OR under tests/golden/scenarios/ after landing."""
    for path in DIR_CANDIDATES + (os.path.join(HERE, "scenarios", SCENARIO),):
        candidate = os.path.join(path, "spec.json")
        if os.path.isfile(candidate):
            return candidate
    raise AssertionError("no spec.json for %s" % SCENARIO)


def golden():
    with open(os.path.join(artifact_dir(), "state.json"), encoding="utf-8") as handle:
        return json.load(handle)


def spec():
    with open(spec_path(), encoding="utf-8") as handle:
        return json.load(handle)


def run_checker(dump_path, checker=CHECKER):
    return subprocess.run([sys.executable, checker, dump_path, "--spec", spec_path()],
                          capture_output=True, text=True, cwd=REPO_ROOT)


def write_dump(tmp_path, state, name="mutant.json"):
    path = os.path.join(str(tmp_path), name)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2, sort_keys=True)
    return path


# ---------------------------------------------------------------------------------------------
# The blessed artifacts must pass, or every rejection below is meaningless.
# ---------------------------------------------------------------------------------------------

def test_blessed_dump_passes_the_checker():
    result = run_checker(os.path.join(artifact_dir(), "state.json"))
    assert result.returncode == 0, result.stdout + result.stderr


def test_spec_gate_passes():
    result = subprocess.run([sys.executable, GATE], capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, result.stdout + result.stderr


def test_stored_grids_separate_the_modes_without_a_game():
    """The separation must be re-derivable FROM PIXELS, not just from the dump's own numbers.

    A dump can claim any distances it likes. This recomputes them from the stored per-mode grids,
    which is the only witness a doctored dump cannot satisfy.
    """
    result = subprocess.run(
        [sys.executable, HARNESS, "--check-stored-separation", artifact_dir()],
        capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS" in result.stdout


# ---------------------------------------------------------------------------------------------
# DATA MUTANTS - one defect each, all must be rejected.
# ---------------------------------------------------------------------------------------------

def test_checker_rejects_a_dump_whose_modes_all_render_the_same(tmp_path):
    """THE CENTRAL DEFECT. If switchHudTo did nothing, every mode would render one picture.

    This is the mutant that corresponds to a renderer which ignores the HUD entirely: the modes
    are all still NAMED in the dump, the run still exits 0, the frame is still live. Only the
    between-mode distance falls, so only a distance assertion can see it.
    """
    state = copy.deepcopy(golden())
    ev = state["evidence"]
    ev["best_between_mode_distance"] = ev["worst_within_mode_distance"] / 2.0
    ev["separation_ratio"] = 0.5
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1
    assert "separat" in (result.stdout + result.stderr).lower()


def test_checker_rejects_identical_grid_digests_across_modes(tmp_path):
    """Three modes reported with ONE grid digest is a renderer drawing the same frame thrice."""
    state = copy.deepcopy(golden())
    state["evidence"]["distinct_mode_grid_digests"] = 1
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_a_dump_where_the_engine_accepted_an_unknown_hud(tmp_path):
    """The REFUSAL is the positive evidence. A permissive model stores whatever it is handed.

    -switchHudTo: (PlayerEntity.m:4537-4542) returns NO without touching the HUD when the plist
    cannot be loaded. A dump saying the bogus name was accepted describes an engine that lost that
    rule, and "no ERROR lines" would not notice (bead oo-het's exit-87 corpse had none).
    """
    state = copy.deepcopy(golden())
    state["evidence"]["hud_refused_unknown_plist"] = False
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1
    assert "refus" in (result.stdout + result.stderr).lower()


def test_checker_rejects_a_hud_readback_that_disagrees_with_what_was_written(tmp_path):
    state = copy.deepcopy(golden())
    state["evidence"]["hud_readback_ok"] = False
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_captures_taken_on_a_station_screen(tmp_path):
    """The HUD is drawn over the 3-D view ONLY.

    Docked, all three modes render the same station GUI, so every distance in the dump would be
    renderer noise and the scenario would be measuring nothing at all.
    """
    state = copy.deepcopy(golden())
    state["evidence"]["gui_screens"] = ["GUI_SCREEN_STATUS"] * len(state["evidence"]["modes"])
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_ambient_traffic_at_any_single_capture(tmp_path):
    """A ship in frame at ONE capture is a real difference between two captures of the same mode.

    Tolerating it would inflate the within-mode population and LOOSEN the very tolerance this
    scenario measures. This is asserted per capture rather than once at the end, because an
    end-of-run census cannot see traffic present for one capture and gone by the next - which is
    exactly what the pre-fix sweep measured (3 ships at the FIRST capture, gone later).
    """
    state = copy.deepcopy(golden())
    counts = list(state["evidence"]["ships_at_each_capture"])
    counts[0] = 1
    state["evidence"]["ships_at_each_capture"] = counts
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1
    assert "traffic" in (result.stdout + result.stderr).lower()


def test_checker_rejects_a_dead_frame(tmp_path):
    """A run that died before drawing yields a near-uniform grid; liveness is what catches it."""
    state = copy.deepcopy(golden())
    state["evidence"]["frame_liveness"] = {k: 0.0 for k in state["evidence"]["frame_liveness"]}
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_a_tolerance_that_does_not_match_the_spec(tmp_path):
    """The dump may not carry its own threshold.

    A dump that reports the tolerance it was judged against, and is judged against THAT, can
    always pass. The checker re-reads the spec.
    """
    state = copy.deepcopy(golden())
    state["evidence"]["within_mode_tolerance"] = 999.0
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_a_within_mode_distance_over_tolerance(tmp_path):
    """The other direction of the same claim: the SAME mode must be STABLE across captures."""
    state = copy.deepcopy(golden())
    ev = state["evidence"]
    ev["worst_within_mode_distance"] = float(spec()["within_mode_tolerance"]) * 2.0
    ev["separation_ratio"] = ev["best_between_mode_distance"] / ev["worst_within_mode_distance"]
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_fewer_modes_than_the_spec_declares(tmp_path):
    """With two modes there is ONE between-mode pair, which cannot distinguish 'the modes differ'
    from 'this particular pair differs'."""
    state = copy.deepcopy(golden())
    state["evidence"]["modes"] = state["evidence"]["modes"][:2]
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode == 1


def test_checker_rejects_a_dump_with_the_evidence_block_removed(tmp_path):
    """The blunt corpse: a dump that records nothing cannot be accepted for recording nothing."""
    state = copy.deepcopy(golden())
    del state["evidence"]
    result = run_checker(write_dump(tmp_path, state))
    assert result.returncode != 0


# ---------------------------------------------------------------------------------------------
# CHECKER MUTANTS - prove each clause is load-bearing, not redundant.
# ---------------------------------------------------------------------------------------------

def _thin_margin(state):
    """A defect in the ONE region only the ratio floor can see.

    Both absolute assertions still pass - the between-mode distance is ABOVE the tolerance and the
    within-mode distance is BELOW it - but the two populations sit only 1.5x apart, which is the
    stimulus shrinking towards the noise. If the absolute clauses could catch this, the ratio floor
    would be redundant; the point of the floor is precisely that they cannot.
    """
    ev = state["evidence"]
    tol = float(spec()["within_mode_tolerance"])
    between = tol * 1.05
    within = between / 1.5
    ev["between_mode_distances"] = [dict(d, distance=between)
                                    for d in ev["between_mode_distances"]]
    ev["best_between_mode_distance"] = between
    ev["within_mode_distances"] = [dict(d, distance=within)
                                   for d in ev.get("within_mode_distances", [])]
    ev["worst_within_mode_distance"] = within
    ev["separation_ratio"] = 1.5


CLAUSE_MUTANTS = [
    pytest.param(
        "separation",
        'if derived_ratio < floor_ratio:',
        'if False:',
        _thin_margin,
        id="separation_ratio_floor"),
    pytest.param(
        "refusal",
        'if evidence["hud_refused_unknown_plist"] is not True:',
        'if False:',
        lambda state: state["evidence"].update({"hud_refused_unknown_plist": False}),
        id="engine_refusal"),
    pytest.param(
        "readback",
        'if evidence["hud_readback_ok"] is not True:',
        'if False:',
        lambda state: state["evidence"].update({"hud_readback_ok": False}),
        id="hud_readback"),
    pytest.param(
        "traffic",
        'if per_capture != [0] * len(evidence["modes"]):',
        'if False:',
        lambda state: state["evidence"].__setitem__(
            "ships_at_each_capture",
            [1] + list(state["evidence"]["ships_at_each_capture"])[1:]),
        id="ambient_traffic"),
    pytest.param(
        "digests",
        'if distinct != len(evidence["modes"]):',
        'if False:',
        # One digest for every mode, and the dump's own count agreed down to 1, so the
        # self-consistency clause below it stays quiet and only THIS clause can object.
        lambda state: state["evidence"].update(
            {"mode_grid_digests": {m: "identical-grid-digest"
                                   for m in state["evidence"]["mode_grid_digests"]},
             "distinct_mode_grid_digests": 1}),
        id="distinct_grid_digests"),
]


@pytest.mark.parametrize("label,needle,replacement,defect", CLAUSE_MUTANTS)
def test_clause_is_load_bearing(tmp_path, label, needle, replacement, defect):
    with open(CHECKER, encoding="utf-8") as handle:
        source = handle.read()
    assert source.count(needle) == 1, (
        "the %s clause is not present verbatim exactly once in %s (found %d). The checker was "
        "refactored and this mutant now proves nothing - fix the needle rather than deleting the "
        "arm." % (label, os.path.basename(CHECKER), source.count(needle)))

    state = copy.deepcopy(golden())
    defect(state)
    dump_path = write_dump(tmp_path, state, "%s.json" % label)

    # SIDE 1: the real checker must reject, or this is a false kill against an already-red input.
    real = run_checker(dump_path)
    assert real.returncode == 1, (
        "the UNMUTATED checker did not reject the %s defect, so side 2 below would be a FALSE "
        "KILL (bead oo-4vdc).\n%s" % (label, real.stdout + real.stderr))

    # SIDE 2: with that one clause neutered, the same input must now be ACCEPTED.
    mutant = os.path.join(str(tmp_path), "checker_%s.py" % label)
    with open(mutant, "w", encoding="utf-8") as handle:
        handle.write(source.replace(needle, replacement))
    weakened = run_checker(dump_path, checker=mutant)
    assert weakened.returncode == 0, (
        "with the %s clause neutered the checker STILL rejected the defect it guards, so that "
        "clause is REDUNDANT - another clause is doing its work, and deleting it would leave this "
        "suite green over a weaker checker (bead oo-xy0o). That is a finding, not a flake.\n%s"
        % (label, weakened.stdout + weakened.stderr))


# ---------------------------------------------------------------------------------------------
# Repository invariants this scenario must not break.
# ---------------------------------------------------------------------------------------------

def test_the_shared_dump_carries_no_hud_state():
    """Adding HUD state to the SHARED dump would re-bless every landed golden.

    tests/golden/dump/dump_state.js is used by 002-019. Scenario 019 found that a change there
    invalidates every other pending scenario's blessed state.json. 020 adds its own blocks to the
    state IT dumps, as 015 and 019 do.
    """
    for name in ("dump_state.js", "state_dump.py"):
        with open(os.path.join(HERE, "dump", name), encoding="utf-8") as handle:
            text = handle.read()
        for marker in ("hudHidden", "hud.plist", "hud_modes"):
            assert marker not in text, (
                "the shared tests/golden/dump/%s mentions %r; that would move 002-019's stored "
                "dumps and turn this scenario into a re-bless of the whole suite" % (name, marker))


def test_the_tolerance_is_not_the_shared_3d_constant():
    """020 is the only scenario whose catalogue status is buildable-pending-own-calibration.

    The shared 0.004377 was measured by bead oo-ae9 against 3-D SCENE changes and says nothing
    about a HUD overlay; copying it is the thing the catalogue forbids.
    """
    shared_path = os.path.join(HERE, "calibration.json")
    with open(shared_path, encoding="utf-8") as handle:
        shared = json.load(handle)
    mine = float(spec()["within_mode_tolerance"])
    for key in ("tolerance", "derived_tolerance"):
        if key in shared:
            assert abs(mine - float(shared[key])) > 1e-9, (
                "spec within_mode_tolerance equals the shared 3-D constant %r" % shared[key])


def test_provenance_digests_witness_the_artifacts():
    """The witness must live OUTSIDE the file it defends.

    Editing a golden moves both sides of every self-comparison; only an external digest sees it
    (beads oo-3ya, oo-gxp).
    """
    import hashlib
    directory = artifact_dir()
    with open(os.path.join(directory, "provenance.json"), encoding="utf-8") as handle:
        prov = json.load(handle)
    for name, meta in prov["artifacts"].items():
        blob = open(os.path.join(directory, name), "rb").read()
        assert hashlib.sha256(blob).hexdigest() == meta["sha256"], (
            "%s does not match the digest recorded in provenance.json" % name)
        assert len(blob) == meta["bytes"]


def test_provenance_records_a_refusal_free_sweep_and_its_history():
    """The sweep's honesty, both halves.

    A REFUSAL is not a DIFFERENCE, and collapsing the two is how a stability claim goes dishonest
    (bead oo-jor). The final sweep must be clean AND the earlier refusals must still be recorded,
    because a scenario that hid the traffic finding would be claiming a determinism it did not
    have.
    """
    with open(os.path.join(artifact_dir(), "provenance.json"), encoding="utf-8") as handle:
        prov = json.load(handle)
    stability = prov["stability"]
    assert stability["runs"] == 10
    assert stability["dumps_written"] == 10
    assert stability["refused"] == 0
    assert stability["errored"] == 0
    assert stability["separation_held_every_run"] is True
    assert len(stability["per_run"]) == 10

    traffic = prov["ambient_traffic"]
    assert "StationEntity.m:991" in traffic["fourth_source"]
    assert "20%" in traffic["measured_before_fix"]
    assert "0%" in traffic["measured_after_fix"]
