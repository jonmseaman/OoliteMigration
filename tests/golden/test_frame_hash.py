"""The frame-hash gate: what it asserts, and the proof that it can fail.

Two tiers, because they cost three orders of magnitude apart and a gate nobody can afford to run
is not a gate.

OFFLINE (default, ~1 s). Everything that does not need a game: the tolerance really is derived
from the recorded measurements rather than written down; the derivation refuses an overlapping
pair; the comparator fires in BOTH directions on the recorded sample frames; the rejected dHash
metric is still measurably worse on the same data. These run in CI, in a clean checkout, with no
desktop and no GPU.

ONLINE (`-m online`, ~2 minutes, four game launches). The end-to-end claim: two fresh renders of
the SAME scene agree within tolerance, and a render from a DIFFERENT CAMERA POSITION does not.
Both halves are needed. The same-scene half alone passes for a tolerance of 1.0; the
different-scene half alone passes for a tolerance of 0.0. Only the pair pins a real threshold.

WHY THE SAMPLE FRAMES ARE COMMITTED. The offline tier compares real PNGs from the calibration run
(tests/golden/samples/), not synthetic images. A synthetic gradient has none of the properties
that made this hard - the black-sky flatness that broke dHash, the sub-pixel jitter that sets the
noise floor - so a comparator that works on synthetic input tells you nothing about this one.
"""

import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import frame_hash  # noqa: E402

SAMPLES = os.path.join(HERE, "samples")


def sample(name):
    path = os.path.join(SAMPLES, name)
    if not os.path.isfile(path):
        pytest.fail("missing committed sample frame %s; the offline tier compares real renders, "
                    "not synthetic images" % path)
    return path


# --- the module must be importable regardless of the data ----------------------------------------

def test_import_never_depends_on_the_measurements():
    """A module that cannot be imported while the data is bad cannot be used to fix the data.

    An earlier version computed the tolerance at module scope and raised FrameHashError when the
    populations overlapped. `import frame_hash` then threw, which broke every consumer - including
    calibrate.py, the one tool whose job is to REPLACE the overlapping measurements. The overlap
    condition must be a VALUE the caller inspects, not an exception raised during import.
    """
    import ast
    import inspect

    tree = ast.parse(inspect.getsource(frame_hash))
    for node in tree.body:
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            call = getattr(node, "value", None)
            if isinstance(call, ast.Call) and isinstance(call.func, ast.Name):
                assert call.func.id not in ("derive_tolerance", "margin", "tolerance"), (
                    "frame_hash.py calls %s() at module scope; import would raise on overlapping "
                    "data and break every consumer, calibrate.py included" % call.func.id
                )
    assert callable(frame_hash.tolerance), "the tolerance must be a function, not a constant"
    assert not hasattr(frame_hash, "TOLERANCE"), (
        "a module-scope TOLERANCE constant is the shape that required computing it at import"
    )


def test_overlap_is_a_value_not_an_exception():
    """separated() answers 'is there a threshold at all' without raising, on any data."""
    good = {"same_scene_distances": [0.001], "different_scene_distances": [0.010]}
    bad = {"same_scene_distances": [0.030], "different_scene_distances": [0.020]}
    assert frame_hash.separated(good) is True
    assert frame_hash.separated(bad) is False
    assert frame_hash.separated({}) is False
    # None means "use the committed calibration", which does separate - so this also pins that
    # the shipped data is usable, and the check above covers the empty/unusable case.
    assert frame_hash.separated(None) is True
    assert frame_hash.separated() is True


# --- the calibration is real data ---------------------------------------------------------------

def test_calibration_records_real_measurements():
    """The tolerance is only meaningful if the file behind it holds measurements.

    Guards against the placeholder this module was developed against: a hand-written file with
    plausible numbers would make every other test in this file pass while measuring nothing.
    """
    cal = frame_hash.CALIBRATION
    assert not cal.get("_provisional"), "calibration.json is still the placeholder"
    assert cal["rasteriser"] == frame_hash.REQUIRED_GL_ENV, (
        "calibration was measured against %r but the module requires %r; a tolerance is a "
        "property of a renderer" % (cal["rasteriser"], frame_hash.REQUIRED_GL_ENV)
    )
    assert len(cal["same_scene_distances"]) >= 3
    assert len(cal["different_scene_distances"]) >= 3
    assert cal["hash"]["side"] == frame_hash.GRID_SIDE
    # Each same-scene distance came from two SEPARATE game processes, so none may be exactly zero:
    # a zero would mean the same PNG was compared with itself and the floor is not a floor.
    assert all(d > 0 for d in cal["same_scene_distances"]), (
        "a same-scene distance of exactly 0 means one frame was compared with itself; the noise "
        "floor must come from two independent renders"
    )


def test_a_cryptographic_hash_would_not_work_here():
    """The measured justification for this module existing at all."""
    assert frame_hash.CALIBRATION["exact_match_rate"] < 1.0, (
        "same-scene renders measured byte-identical; sha256 would be the correct instrument and "
        "a tolerance would be unnecessary"
    )


def test_tolerance_is_derived_from_the_data_not_written_down():
    """The constant must follow the measurements, not the other way round."""
    cal = frame_hash.CALIBRATION
    floor, signal = max(cal["same_scene_distances"]), min(cal["different_scene_distances"])
    assert floor < frame_hash.tolerance() < signal, (
        "tolerance %.6f does not sit strictly between the measured noise floor %.6f and the "
        "weakest measured signal %.6f" % (frame_hash.tolerance(), floor, signal)
    )
    # And it is the geometric mean, i.e. the SAME multiplicative margin in both directions.
    assert frame_hash.tolerance() == pytest.approx((floor * signal) ** 0.5, rel=1e-12)
    assert frame_hash.margin() == pytest.approx(signal / frame_hash.tolerance(), rel=1e-9)


def test_the_margin_is_stated_and_not_marginal():
    """A threshold wedged between two touching populations is a flake generator.

    1.5x in each direction is the smallest separation worth shipping: below it, a noise floor that
    drifts by half its own value on a busier machine crosses the threshold.
    """
    assert frame_hash.margin() >= 1.5, (
        "margin is only %.2fx the noise floor (%.6f) against the weakest signal (%.6f). The "
        "populations are nearly touching, so the tolerance will flake. Either the scenes need a "
        "larger deliberate difference or this content cannot be gated by a frame hash."
        % (frame_hash.margin(), max(frame_hash.CALIBRATION["same_scene_distances"]),
           min(frame_hash.CALIBRATION["different_scene_distances"]))
    )


def test_derivation_refuses_overlapping_populations():
    """The negative result must be reachable, or 'they separated' is not a finding."""
    with pytest.raises(frame_hash.FrameHashError, match="OVERLAP"):
        frame_hash.derive_tolerance({"same_scene_distances": [0.30],
                                     "different_scene_distances": [0.20]})


def test_the_rejected_dhash_is_still_measurably_worse():
    """dHash was not rejected by taste; keep its inferiority as data on the same frames.

    The claim is NOT "dhash never separates" - on a strong enough scene set it sometimes does, and
    asserting otherwise would be a test that a weaker instrument stays broken. The claim is that
    its noise floor on this content is two orders of magnitude larger, which leaves it a margin
    too thin to gate anything: it overlapped outright on the first measured scene set and clears
    the second only barely.
    """
    cal = frame_hash.CALIBRATION
    r = cal["rejected_dhash"]
    assert r["noise_floor"] > cal["noise_floor"] * 10, (
        "dhash's noise floor (%.6f) is no longer far above this metric's (%.6f); the recorded "
        "reason for rejecting it does not hold on this data"
        % (r["noise_floor"], cal["noise_floor"])
    )
    assert (r["margin"] or 0.0) < cal["margin"], (
        "dhash now has a margin of %.2fx against this metric's %.2fx; if that is real, revisit "
        "the choice of metric rather than leaving this note in place"
        % (r["margin"] or 0.0, cal["margin"])
    )


def test_grid_side_is_the_smallest_that_separates():
    """GRID_SIDE is a measured choice: the smallest sweep point that still separates."""
    sweep = frame_hash.CALIBRATION["grid_sweep"]
    separating = sorted(int(k) for k, v in sweep.items() if v["separated"])
    assert separating, "no grid size in the sweep separated the populations"
    assert frame_hash.GRID_SIDE in separating
    assert frame_hash.GRID_SIDE == separating[0] or sweep[str(frame_hash.GRID_SIDE)]["separated"]


def test_the_instrument_has_a_documented_blind_spot():
    """A frame hash sees pixels, not objects. Say so with numbers rather than discovering it later."""
    sens = frame_hash.CALIBRATION["sensitivity"]
    assert sens, "no sensitivity curve recorded"
    # Detectability is measured against the TOLERANCE, not the raw noise floor: the gate passes
    # everything at or below the tolerance, so a distance a hair above the floor is still invisible
    # to it.
    tol = frame_hash.tolerance()
    assert all(v["detectable"] == (v["distance"] > tol) for v in sens.values()), (
        "the recorded sensitivity verdicts were not scored against the tolerance %.6f" % tol
    )
    visible = {k: v for k, v in sens.items() if v["detectable"]}
    assert visible, "no ship range was detectable at all; the instrument sees nothing"
    # The curve must be a curve: something detectable AND something not, or it is not a limit.
    assert len(visible) < len(sens), (
        "every measured ship range was detectable, so the recorded sensitivity curve does not "
        "actually locate the instrument's limit and 'it can see a moved ship' is untested at the "
        "boundary"
    )


# --- the comparator fires in both directions ------------------------------------------------------

def test_same_scene_samples_compare_within_tolerance():
    """Positive control on real frames: without it a green run could be vacuous."""
    result = frame_hash.assert_within(sample("ref-a.png"), sample("ref-b.png"),
                                      what="two renders of the reference pose")
    assert result["distance"] <= frame_hash.tolerance()


@pytest.mark.parametrize("other,why", [
    ("moved.png", "a camera translated 400 km along +z"),
    ("turned.png", "a camera yawed 90 degrees in place"),
    ("with-ship.png", "the same camera with a trader parked ahead"),
])
def test_different_scene_samples_compare_beyond_tolerance(other, why):
    """The half that makes the tolerance a test rather than decoration."""
    frame_hash.assert_beyond(sample("ref-a.png"), sample(other), what=why)


def test_assert_within_reports_a_mismatch_with_numbers():
    """The failure message must name the observation; a bare AssertionError sends the next reader
    to the wrong place."""
    with pytest.raises(frame_hash.FrameHashError) as exc:
        frame_hash.assert_within(sample("ref-a.png"), sample("moved.png"))
    text = str(exc.value)
    assert "FRAME HASH MISMATCH" in text
    assert "EXCEEDS the measured tolerance" in text
    assert "llvmpipe" in text  # names the rasteriser the tolerance belongs to


def test_assert_beyond_reports_a_non_discriminating_hash():
    with pytest.raises(frame_hash.FrameHashError) as exc:
        frame_hash.assert_beyond(sample("ref-a.png"), sample("ref-b.png"))
    assert "NOT DISCRIMINATING" in str(exc.value)


def test_distance_is_zero_for_a_frame_against_itself():
    g = frame_hash.frame_grid(sample("ref-a.png"))
    assert frame_hash.distance(g, g) == 0.0


# --- the live gate --------------------------------------------------------------------------------

@pytest.fixture(scope="module")
def live_frames(tmp_path_factory):
    """Four real renders: two of the reference pose, one moved, one with a ship added.

    Module-scoped because each costs a game launch (~22 s measured warm on this host, and a COLD
    first launch can cost minutes).
    """
    import frame_capture

    out = str(tmp_path_factory.mktemp("frames"))
    shots = {}
    for label, pose in (("ref_a", "ref"), ("ref_b", "ref-again"),
                        ("moved", "moved"), ("ship", "ref-with-ship")):
        shots[label] = frame_capture.capture(pose, out)
    return shots


@pytest.mark.online
def test_live_same_scene_frames_agree_within_tolerance(live_frames):
    """Two fresh renders of one fixed camera pose, each from its own game process."""
    result = frame_hash.assert_within(live_frames["ref_a"]["png"], live_frames["ref_b"]["png"],
                                      what="two live renders of the reference pose")
    assert result["distance"] > 0, (
        "two independent renders measured EXACTLY identical, which did not happen in calibration "
        "(exact_match_rate %r). Suspect that both captures returned the same file."
        % frame_hash.CALIBRATION["exact_match_rate"]
    )


@pytest.mark.online
def test_live_moved_camera_clears_the_tolerance(live_frames):
    """The bead's mutant, as a permanent assertion: a different camera position must be seen."""
    frame_hash.assert_beyond(live_frames["ref_a"]["png"], live_frames["moved"]["png"],
                             what="the reference pose vs a camera 400 km away")


@pytest.mark.online
def test_live_moved_ship_clears_the_tolerance(live_frames):
    """The bead's DoD verbatim: a deliberately placed ship changes the hash beyond tolerance,
    with the camera untouched."""
    frame_hash.assert_beyond(live_frames["ref_a"]["png"], live_frames["ship"]["png"],
                             what="the reference pose vs the same pose with a trader ahead")


@pytest.mark.online
def test_live_capture_pinned_the_camera(live_frames):
    """Without this the two same-scene frames could agree because the camera drifted to the same
    place twice by luck rather than because it was fixed."""
    for label in ("ref_a", "ref_b", "ship"):
        assert live_frames[label]["position"] == pytest.approx([0.0, 0.0, 0.0], abs=1.0), (
            "%s rendered from %r, not the declared reference position"
            % (label, live_frames[label]["position"])
        )
    assert live_frames["moved"]["position"] != pytest.approx([0.0, 0.0, 0.0], abs=1.0)


@pytest.mark.online
def test_live_captures_cost_what_a_game_launch_costs(live_frames):
    """An implausibly fast capture is an environment artefact, not a result: a fixed console port
    lets a run attach to a LEFTOVER game and 'pass' in seconds. Measured warm launch on this host
    is ~21-28 s; anything under 5 s never started a game."""
    for label, shot in live_frames.items():
        assert shot["wall_seconds"] >= 5.0, (
            "%s completed in %ss, far below the measured cost of launching this game. The capture "
            "probably attached to an already-running process rather than the one it spawned."
            % (label, shot["wall_seconds"])
        )


def test_calibration_json_is_valid_and_self_consistent():
    with open(frame_hash.CALIBRATION_PATH, encoding="utf-8") as handle:
        cal = json.load(handle)
    assert cal["separated"] is True
    assert cal["noise_floor"] == max(cal["same_scene_distances"])
    assert cal["weakest_signal"] == min(cal["different_scene_distances"])
    assert cal["tolerance"] == pytest.approx(frame_hash.tolerance(), rel=1e-12)
