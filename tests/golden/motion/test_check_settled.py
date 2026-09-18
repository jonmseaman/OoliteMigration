"""Offline proof that check_settled.py discriminates - no game, no build, runs in a fresh clone.

WHY THESE TESTS AND NOT A LIVE RUN. The bead's real evidence is a launch: spawn ships, stop them,
watch N frames. That costs a built tree and ~15 s of game, neither of which a fresh acceptance
checkout has (bead oo-1xz failed acceptance on exactly that). So the live run produces two
COMMITTED WITNESSES - one from the unfixed engine, one from the fixed one - and these tests replay
them offline. The witnesses are the measurement; this file is the proof that the judgement of them
can fail.

THE MUTANT DISCIPLINE (bead oo-jor, bead oo-3ya). For every property the checker defends there are
TWO mutants: one that corrupts the DATA and one that weakens the CHECKER. A gate that validates
data with a validator nobody validates is a hole one refactor wide. Each of check_settled's
defences is mutated SEPARATELY, because two defences that both happen to catch the same corruption
hide each other - collapsing them into one mutant is how a redundant defence gets mistaken for a
load-bearing one.

The single most important test here is test_single_frame_check_would_wrongly_pass: it takes the
RED witness (a ship visibly re-accelerating) and shows that a checker looking at only the FIRST
frame calls it settled. That is the mistake the old seam made possible, and it is why
MIN_REST_FRAMES exists.
"""

import copy
import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_settled as cs  # noqa: E402

FIXTURES = os.path.join(HERE, "fixtures")
RED = os.path.join(FIXTURES, "red-unfixed-engine.json")
GREEN = os.path.join(FIXTURES, "green-speed-arm.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def arm_of(witness, name):
    """A detached COPY of one arm, for tests that only read it.

    Deep-copied so a test that pokes at the arm cannot leak into another test through the module's
    cached fixture. Tests that mean to corrupt the witness must use arm_in(), which returns the
    live object - a mutation applied to a copy silently does nothing and the mutant appears killed
    when it was never applied.
    """
    return copy.deepcopy(arm_in(witness, name))


def arm_in(witness, name):
    """The LIVE arm inside `witness`, for tests that corrupt it deliberately."""
    for arm in witness["arms"]:
        if arm["arm"] == name:
            return arm
    raise AssertionError("no arm %r in fixture" % name)


def problems_for(witness, arm_name):
    return cs.judge(witness, arm_name)[0]


def names(problems):
    return {p.split("]")[0].lstrip("[") for p in problems}


def _position_drift_problems(problems):
    """Only the position_frozen messages about actual DRIFT, not about window length.

    check_position_frozen makes two distinct complaints: "you are still moving" (a fact about the
    frames) and "there are not enough frozen frames" (a fact about the window). A single-frame
    window trivially triggers the second, so a test about blindness to drift has to separate them
    or it silently stops testing what it says it does.
    """
    return [p for p in problems if "frozen frames are required" not in p]


# --- the fixtures are what they claim to be ----------------------------------------------------
#
# Every later test rests on these two files, so their provenance is asserted rather than assumed:
# a fixture quietly regenerated from the same binary would make every mutant below vacuous.

def test_fixtures_come_from_two_different_binaries():
    red, green = load(RED), load(GREEN)
    assert red["binary"]["md5"] != green["binary"]["md5"], (
        "the RED and GREEN witnesses were produced by the SAME binary; one of them cannot be "
        "showing the behaviour it claims"
    )
    for witness, label in ((red, "RED"), (green, "GREEN")):
        assert witness["binary"]["exe"].endswith("oolite.exe"), label
        assert witness["binary"]["size"] > 1_000_000, label


def test_fixtures_are_not_vacuous():
    """Ships genuinely moving before each write, and enough frames after it to mean anything."""
    for path in (RED, GREEN):
        witness = load(path)
        for arm in witness["arms"]:
            assert len(arm["after"]) >= cs.MIN_REST_FRAMES, (path, arm["arm"])
            assert arm["before"]["ships"], (path, arm["arm"])
            assert all(s["speed"] >= cs.MOTION_FLOOR for s in arm["before"]["ships"]), (
                "%s arm %s: a ship was not moving before the write" % (path, arm["arm"]))


# --- the headline behaviours -------------------------------------------------------------------

def test_green_witness_passes_on_the_speed_arm():
    assert problems_for(load(GREEN), "speed") == []


def test_red_witness_fails_naming_the_reacceleration():
    problems = problems_for(load(RED), "velocity")
    assert problems, "the unfixed engine's witness must not pass"
    assert "rest_all_frames" in names(problems)
    assert any("RE-ACCELERATED" in p for p in problems)


def test_the_preexisting_performstop_path_is_measured_not_assumed():
    """performStop() alone does NOT hold the ship still from the first frame.

    This is the honest record of the alternative mechanism: on the unfixed engine performStop()
    decays flightSpeed to zero over 2-3 frames rather than arriving there, so a window that starts
    at the write catches it still moving. That is a real behavioural difference from ship.speed = 0
    and it is why this bead adds the direct write rather than declaring the existing call
    sufficient - not a claim that performStop() is broken.
    """
    problems = problems_for(load(RED), "performstop")
    assert problems, "performstop must not pass from frame 0 - it decays rather than snapping"
    speeds = [s["speed"] for f in arm_of(load(RED), "performstop")["after"] for s in f["ships"]]
    assert speeds[0] > 0 and speeds[-1] == 0, (
        "the recorded performstop arm should start moving and end stopped; this test is about the "
        "DECAY between those, so a witness without one is not exercising it")
    assert any("rest_all_frames" in p and "moving at" in p for p in problems), (
        "the failure should be the decay tail - the ship still moving on the frames right after "
        "the call - not a full re-acceleration")
    assert not any("245.7000" in p or "299.98" in p for p in problems), (
        "performstop must not look like the velocity arm's runaway re-acceleration")


def test_setting_a_nonzero_speed_holds_it():
    """The complementary POSITIVE control: the setter is not a write-zero special case.

    A seam that only ever accepts 0 would satisfy every rest assertion above while being useless
    for the thing this bead exists to enable - a golden containing a ship under sustained,
    predictable motion. The cruise arm writes 137 m/s and the ship holds exactly that on every
    sampled frame while its position advances monotonically.
    """
    arm = arm_of(load(GREEN), "cruise")
    for index, frame in enumerate(arm["after"]):
        for ship in frame["ships"]:
            assert abs(ship["speed"] - 137.0) < 1e-6, (
                "frame %d: %s is at %.6f m/s, not the 137 m/s it was set to"
                % (index, ship["id"], ship["speed"]))
    # and it is MOVING, not merely reporting a number
    first, last = arm["after"][0]["ships"][0], arm["after"][-1]["ships"][0]
    travelled = sum((last[a] - first[a]) ** 2 for a in ("px", "py", "pz")) ** 0.5
    elapsed = float(arm["after"][-1]["t"]) - float(arm["after"][0]["t"])
    assert travelled > 100.0, (
        "the ship reported 137 m/s for %.3f s but moved only %.3f m - the speed reading is not "
        "connected to the motion" % (elapsed, travelled))
    # Distance should be within a generous band of speed*time; the band is wide because the
    # sample times are frame times, not exact integration bounds.
    assert 0.5 < travelled / (137.0 * elapsed) < 1.5, (
        "travelled %.3f m in %.3f s at a reported 137 m/s" % (travelled, elapsed))


# --- THE CRUX: the multi-frame requirement is load-bearing --------------------------------------

def test_single_frame_check_would_wrongly_pass():
    """THE CRUX. Truncate the window to one frame and the re-accelerating witness is not caught
    by the frame-content defences - only by the defences that count frames.

    Frame 0 of the RED velocity arm is the frame the write landed on, where setTotalVelocity: has
    just subtracted the current thrustVector, so position has not moved yet. A gate that read a
    single frame would see that and report a ship which goes on to reach 299.98 m/s as settled.

    Two independent defences stand in the way, and BOTH are asserted here: rest_frame_count (there
    were not enough frames) and position_frozen (not enough frozen frames after the settle). The
    redundancy is deliberate - the multi-frame requirement is the one property whose loss silently
    restores the original defect, so it is guarded twice on purpose rather than by accident.
    """
    witness = load(RED)
    arm = arm_of(witness, "velocity")

    assert cs.check_position_frozen(arm), "sanity: the full window must see the drift"

    one_frame = dict(arm, after=arm["after"][:1])

    # The frame-CONTENT defence cannot see a drift in a single frame: there is nothing to compare.
    # This is exactly the blindness the multi-frame requirement exists to cover.
    assert _position_drift_problems(cs.check_position_frozen(one_frame)) == [], (
        "a one-frame window must be unable to see DRIFT - if it can, this test is not exercising "
        "the weakening it claims to")

    # ...and the frame-COUNT defences both refuse it.
    assert cs.check_rest_frame_count(one_frame), (
        "rest_frame_count did not fire on a one-frame window; the multi-frame requirement is not "
        "enforced and a single-frame reading would pass")
    assert any("frozen frames are required" in p for p in cs.check_position_frozen(one_frame)), (
        "position_frozen accepted a window with no frames after the settle, so 'stopped' is not "
        "distinguished from 'about to be re-thrust'")
    assert "1 frame(s)" in cs.check_rest_frame_count(one_frame)[0]


def test_min_rest_frames_rejects_a_window_shorter_than_itself():
    arm = arm_of(load(GREEN), "speed")
    short = dict(arm, after=arm["after"][:cs.MIN_REST_FRAMES - 1])
    assert cs.check_rest_frame_count(short)
    assert cs.check_rest_frame_count(dict(arm, after=arm["after"][:cs.MIN_REST_FRAMES])) == []


# --- DATA mutants: corrupt the witness, the checker must notice ---------------------------------

def test_data_mutant_reaccelerating_ship_is_caught():
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    witness["arms"][0]["after"][5]["ships"][0]["speed"] = 43.5
    problems = problems_for(witness, "speed")
    assert "rest_all_frames" in names(problems)


def test_data_mutant_drifting_position_is_caught_even_at_speed_zero():
    """Position is checked INDEPENDENTLY of speed, so a speed reading of 0 cannot cover a drift.

    The drift is PROGRESSIVE (a growing offset), not a constant one. A constant shift applied from
    some frame onward leaves every later frame identical to its neighbours, which is a settled ship
    at a different place - genuinely not what this defence is for. A ship still being integrated
    moves a bit more each frame, and that is what must be caught.
    """
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    for step, frame in enumerate(witness["arms"][0]["after"][3:], start=1):
        frame["ships"][0]["px"] += 5.0 * step  # moving, while speed still reads exactly 0.0
    problems = problems_for(witness, "speed")
    assert "position_frozen" in names(problems)
    assert "rest_all_frames" not in names(problems), (
        "this mutant must be caught by position_frozen ALONE; if rest_all_frames also fires the "
        "two defences are not independent and this is a MISKILL")


def test_data_mutant_a_late_settle_is_caught():
    """The settle frame is bounded, not merely required to exist.

    Without the MAX_SETTLE_FRAMES bound, a ship that coasted for eight frames and stopped on the
    ninth would pass as "settled" - the defence would have degenerated into "stops eventually",
    which every decelerating ship satisfies.
    """
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    for step, frame in enumerate(witness["arms"][0]["after"][:6], start=1):
        frame["ships"][0]["px"] += 5.0 * (6 - step)
    problems = problems_for(witness, "speed")
    assert "position_frozen" in names(problems)
    assert any("did not stop changing until frame" in p for p in problems), (
        "a ship that settles only after MAX_SETTLE_FRAMES must be named as a late settle")


def test_data_mutant_ship_that_was_never_moving_is_caught():
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    for ship in witness["arms"][0]["before"]["ships"]:
        ship["speed"] = 0.0
    assert "motion_before" in names(problems_for(witness, "speed"))


def test_data_mutant_empty_sample_is_caught():
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    for frame in witness["arms"][0]["after"]:
        frame["ships"] = []
    assert "ships_present" in names(problems_for(witness, "speed"))


def test_data_mutant_frozen_clock_is_caught():
    """A paused game reports a perfectly settled world; that must not read as evidence."""
    witness = load(GREEN)
    witness["arms"] = [a for a in witness["arms"] if a["arm"] == "speed"]
    for frame in witness["arms"][0]["after"]:
        frame["t"] = 42.0
    assert "frames_advanced" in names(problems_for(witness, "speed"))


def test_data_mutant_unattributed_binary_is_caught():
    witness = load(GREEN)
    witness["binary"] = {"app_dir": "somewhere"}
    assert "binary_identified" in names(problems_for(witness, "speed"))


# --- the CRUISE expectation: mutants against the positive control -------------------------------

def cruise_problems(witness, arm_name="cruise"):
    return cs.judge(witness, arm_name, "cruise")[0]


def test_the_cruise_arm_passes_the_cruise_expectation():
    assert cruise_problems(load(GREEN)) == []


def test_data_mutant_a_decayed_cruise_speed_is_caught():
    """The blip case: the write lands, then the engine pulls the speed back.

    This is the failure mode a rest-only gate is completely blind to, and it is the one that
    distinguishes 'ship.speed is writable' from 'ship.speed accepts a write and keeps it'.
    """
    witness = load(GREEN)
    arm = arm_in(witness, "cruise")
    for step, frame in enumerate(arm["after"][1:], start=1):
        for ship in frame["ships"]:
            ship["speed"] = max(0.0, ship["speed"] - 15.0 * step)
    problems = cruise_problems(witness)
    assert "cruise_speed_held" in names(problems)
    assert any("did not HOLD" in p for p in problems)


def test_data_mutant_a_reported_speed_with_a_frozen_position_is_caught():
    """Position is verified independently: a speed reading alone is not motion."""
    witness = load(GREEN)
    arm = arm_in(witness, "cruise")
    frozen = arm["after"][0]["ships"][0]
    for frame in arm["after"][1:]:
        for ship in frame["ships"]:
            for axis in ("px", "py", "pz"):
                ship[axis] = frozen[axis]
    problems = cruise_problems(witness)
    assert "cruise_position_advances" in names(problems)
    assert "cruise_speed_held" not in names(problems), (
        "this mutant must be caught by the POSITION defence alone; if the speed defence also fires "
        "the two are not independent and this is a MISKILL")


CRUISE_MUTANTS = {
    # defence name -> a function corrupting the GREEN cruise arm in the way that defence exists to
    # catch. Each defence must have one, so removing it lets a known-bad witness through.
    "cruise_speed_held": lambda arm: [
        ship.__setitem__("speed", 3.0)
        for frame in arm["after"][1:] for ship in frame["ships"]],
    "cruise_position_advances": lambda arm: [
        ship.__setitem__(axis, arm["after"][0]["ships"][0][axis])
        for frame in arm["after"][1:] for ship in frame["ships"]
        for axis in ("px", "py", "pz")],
    "ships_present": lambda arm: [frame.__setitem__("ships", []) for frame in arm["after"]],
    "frames_advanced": lambda arm: [
        frame.__setitem__("t", arm["after"][0]["t"]) for frame in arm["after"]],
    "rest_frame_count": lambda arm: arm.__setitem__("after", arm["after"][:1]),
}


@pytest.mark.parametrize("defence", [name for name, _ in cs.CRUISE_DEFENCES])
def test_each_cruise_defence_is_load_bearing(monkeypatch, defence):
    """Each cruise defence catches something no other cruise defence catches.

    Built as corrupt-then-remove, not remove-and-hope: the witness is mutated in the way this
    defence exists to catch, the full table must REJECT it, and the table without this one defence
    must ACCEPT it. Asserting only that a good witness still passes would be vacuous - it passes
    with every defence removed too.
    """
    assert defence in CRUISE_MUTANTS, (
        "cruise defence %r has no mutant; a defence with no failing input it uniquely catches is "
        "untested and may be dead" % defence)

    witness = load(GREEN)
    CRUISE_MUTANTS[defence](arm_in(witness, "cruise"))
    assert cruise_problems(witness), "the mutated witness must be rejected by the full table"

    monkeypatch.setattr(cs, "CRUISE_DEFENCES",
                        tuple((n, f) for n, f in cs.CRUISE_DEFENCES if n != defence))
    weakened = load(GREEN)
    CRUISE_MUTANTS[defence](arm_in(weakened, "cruise"))
    assert cruise_problems(weakened) == [], (
        "with %r removed the corrupted witness is STILL rejected, so another defence covers the "
        "same ground - either this defence is redundant or the mutant is not specific to it"
        % defence)


# --- CHECKER mutants: weaken a defence, the known-bad input must still be rejected ---------------
#
# Each defence is removed SEPARATELY and the RED witness re-judged. Two defences catch a
# re-accelerating ship (its speed rises AND its position drifts), so this table proves DELIBERATE
# REDUNDANCY on the bead's central property rather than that each defence is individually
# load-bearing - which is the right shape for a property this important, and is pinned here so a
# later refactor cannot silently collapse it to one (bead oo-jor: the correct response to
# deliberate redundancy is to pin it, not to remove it). The defences that are NOT redundant are
# pinned one-by-one by the DATA mutants above, each of which is caught by exactly one defence.

@pytest.mark.parametrize("defence", [name for name, _ in cs.DEFENCES])
def test_checker_mutant_removing_one_defence_still_rejects_the_red_witness(defence, monkeypatch):
    monkeypatch.setattr(cs, "DEFENCES",
                        tuple((n, f) for n, f in cs.DEFENCES if n != defence))
    problems = problems_for(load(RED), "velocity")
    assert problems, (
        "with the %r defence removed the checker ACCEPTS a witness in which the ship "
        "re-accelerates from 25 m/s to 234 m/s over ten frames; the remaining defences do not "
        "cover it, so this property has lost its last guard" % defence)


def test_the_redundancy_on_reacceleration_is_exactly_two_defences():
    """Name the redundancy rather than leaving it implicit.

    If a future change makes a third defence fire on this input, or reduces it to one, that is a
    real change in how the gate is held up and should be a deliberate edit here, not a silent
    drift.
    """
    fired = names(problems_for(load(RED), "velocity"))
    assert fired == {"rest_all_frames", "position_frozen"}, (
        "the re-accelerating witness is caught by %s; the gate's redundancy on its central "
        "property has changed" % sorted(fired))


def test_checker_mutant_removing_all_defences_makes_the_gate_blind():
    """The control for the test above: with every defence gone the bad input passes.

    Without this, the parametrised test could be green because the RED witness is rejected by
    something outside DEFENCES entirely, and the whole table would prove nothing.
    """
    import unittest.mock as mock
    with mock.patch.object(cs, "DEFENCES", ()):
        problems = problems_for(load(RED), "velocity")
    assert problems == [], (
        "the RED witness is still rejected with EVERY defence removed, so something other than "
        "DEFENCES is doing the work and the per-defence mutants above are not measuring the gate")


def test_checker_mutant_loosening_rest_eps_accepts_a_moving_ship(monkeypatch):
    """The threshold itself is a defence: a value nobody predicates on is decoration (oo-3ya)."""
    arm = arm_of(load(RED), "velocity")
    assert cs.check_rest_all_frames(arm), "sanity: the motion is visible at the real threshold"
    monkeypatch.setattr(cs, "REST_EPS", 1e6)
    assert cs.check_rest_all_frames(arm) == [], (
        "raising REST_EPS to 1e6 must make the defence blind; if it still fires, the threshold "
        "is not what that defence reads and the constant is decoration")


def test_checker_mutant_loosening_position_eps_accepts_drift(monkeypatch):
    arm = arm_of(load(RED), "velocity")
    assert cs.check_position_frozen(arm), "sanity: the drift is visible at the real threshold"
    monkeypatch.setattr(cs, "POSITION_EPS", 1e9)
    assert cs.check_position_frozen(arm) == []


def test_checker_mutant_lowering_motion_floor_accepts_a_stationary_before(monkeypatch):
    witness = load(GREEN)
    arm = arm_of(witness, "speed")
    for ship in arm["before"]["ships"]:
        ship["speed"] = 0.5
    assert cs.check_motion_before(arm), "sanity: 0.5 m/s is below the floor"
    monkeypatch.setattr(cs, "MOTION_FLOOR", 0.0)
    assert cs.check_motion_before(arm) == []


# --- refusals are not passes --------------------------------------------------------------------

def test_missing_arm_is_a_refusal_not_a_pass():
    with pytest.raises(cs.Refusal):
        cs.judge(load(GREEN), "no-such-arm")


def test_malformed_witness_is_a_refusal():
    with pytest.raises(cs.Refusal):
        cs.judge({"not": "a witness"}, "speed")


def test_cli_returns_two_for_an_unreadable_witness(tmp_path):
    assert cs.main([str(tmp_path / "nope.json")]) == 2


def test_cli_returns_one_for_red_and_zero_for_green():
    assert cs.main([RED, "--arm", "velocity"]) == 1
    assert cs.main([GREEN, "--arm", "speed"]) == 0
