"""Judge a motion_probe.py witness: did the ship come to rest, and STAY there? (bead oo-jou1)

SPLIT FROM THE PROBE ON PURPOSE. motion_probe.py launches the game and reports numbers; this file
holds every threshold and every verdict and touches no game. That split is what makes the checker
mutable in a mutation harness without relaunching anything, and it is why a stored witness from a
known-bad binary can be replayed offline as a permanent regression fixture.

THE PROPERTY, and why it takes more than one frame. A ship's velocity is `newtonian + thrustVector`
(ShipEntity.m:12830), and thrustVector is `v_forward * flightSpeed` (ShipEntity.m:12824). Writing
ship.velocity calls -setTotalVelocity:, which subtracts the CURRENT thrustVector (ShipEntity.h:944)
- so it zeroes the reading for one frame and -applyThrust: (ShipEntity.m:6734) rebuilds the thrust
on the next. A SINGLE-FRAME reading of speed==0 therefore cannot tell "stopped" from "about to be
re-thrust": both look identical on the frame the write lands. The check below is consecutive-frame
by construction for exactly that reason, and check_multiframe_is_load_bearing() in the test file
pins it so a later refactor cannot quietly collapse it back to one frame.

DEFENCES, each named, each separately mutable (bead oo-jor's lesson: a gate that protects its data
but not its validator is a hole one refactor wide, and bead oo-3ya went 13/15 -> 17/17 kills after
decomposing its defences and mutating each one):

  D1 rest_all_frames     every sampled frame after the write has every ship at speed <= REST_EPS
  D2 rest_frame_count    there were at least MIN_REST_FRAMES of them (the multi-frame requirement)
  D3 position_frozen     the ships did not MOVE either - speed is a scalar the engine could in
                         principle report as 0 while position still integrates, so position is
                         checked independently rather than trusted to follow from speed
  D4 motion_before       the ships were genuinely moving before the write (>= MOTION_FLOOR), so a
                         "stop" that stopped nothing cannot pass
  D5 ships_present       at least MIN_SHIPS ships were sampled - an empty sample satisfies every
                         "for all ships" clause vacuously
  D6 frames_advanced     game time strictly advanced across the sampled frames, so a frozen or
                         paused game cannot masquerade as a settled one
  D7 binary_identified   the witness names the binary it ran (path, size, md5) - a run against a
                         sibling's build proves nothing about this tree's engine

Every one of those can fail on its own and says so by name. rc convention, as elsewhere in this
repo: 0 verified, 1 a real failure, 2 "I cannot tell you" (unreadable/ill-formed witness).
"""

import argparse
import json
import math
import sys

# A ship at rest reads EXACTLY 0.0 in practice (flightSpeed is assigned, not integrated towards
# zero, once ship.speed = 0 is written). The epsilon is not slack for the engine, it is slack for
# the JSON round trip; it is deliberately far below the smallest speed any arm was ever observed
# to produce (the slowest non-zero sample across every run here was 2.125 m/s).
REST_EPS = 1e-6

# Position must not drift either. One millimetre over the whole window: the quantisation the golden
# storage policy stores at is 3 decimals = 1 mm, so anything a golden could distinguish is caught.
POSITION_EPS = 1e-3

# How far a held cruise speed may read from the value written. Exact equality is the observed
# behaviour (the engine stores the double it was handed and -applyThrust: leaves it alone while
# desired_speed matches), but a tolerance costs nothing and keeps the defence about "held" rather
# than about float representation.
CRUISE_EPS = 1e-6

# How many frames of residual-velocity decay are tolerated after the write before position must be
# permanently frozen. Measured at 2 on this engine (see check_position_frozen); 3 leaves one frame
# of headroom without being loose enough to hide a ship that is still under thrust.
MAX_SETTLE_FRAMES = 3

# Consecutive frames required. Four is not a round number for its own sake: the pre-existing
# performStop() path (which this bead measured before changing anything) takes 2-3 frames to decay
# to zero, so a gate of 2 would be satisfied by a ship that merely has not finished accelerating.
MIN_REST_FRAMES = 4

# The ships must have been moving this fast before the write, or there was nothing to stop.
MOTION_FLOOR = 20.0

MIN_SHIPS = 2

# How many individual problems a failing verdict prints before summarising the rest.
MAX_REPORTED = 8


class Refusal(Exception):
    """The witness cannot be judged at all. Never a pass, never a failure: rc=2."""


def _ships(frame):
    ships = frame.get("ships")
    if not isinstance(ships, list):
        raise Refusal("a frame has no 'ships' list")
    return ships


def check_ships_present(arm):
    """D5. An empty sample makes every 'for all ships' clause vacuously true."""
    problems = []
    for index, frame in enumerate(arm["after"]):
        n = len(_ships(frame))
        if n < MIN_SHIPS:
            problems.append(
                "frame %d sampled %d ship(s), fewer than the %d minimum - 'every ship is at rest' "
                "is vacuously true of an empty sample" % (index, n, MIN_SHIPS))
    return problems


def check_motion_before(arm):
    """D4. There must have been motion to stop."""
    problems = []
    before = _ships(arm["before"])
    if not before:
        return ["the pre-write sample has no ships, so there is no evidence anything was moving"]
    for ship in before:
        if ship["speed"] < MOTION_FLOOR:
            problems.append(
                "%s was at %.4f m/s BEFORE the write, below the %.1f m/s floor - this run stopped "
                "a ship that was not moving and proves nothing"
                % (ship["id"], ship["speed"], MOTION_FLOOR))
    return problems


def check_frames_advanced(arm):
    """D6. A paused or frozen game reports a beautifully settled world."""
    times = [float(f["t"]) for f in arm["after"]]
    problems = []
    for i in range(1, len(times)):
        if not times[i] > times[i - 1]:
            problems.append(
                "game time did not advance between frame %d (t=%.4f) and frame %d (t=%.4f); a "
                "world that is not integrating cannot demonstrate that a ship stays at rest"
                % (i - 1, times[i - 1], i, times[i]))
    return problems


def check_rest_frame_count(arm):
    """D2. THE MULTI-FRAME REQUIREMENT. See the module docstring for why one frame cannot do."""
    n = len(arm["after"])
    if n < MIN_REST_FRAMES:
        return ["only %d frame(s) were sampled after the write; %d consecutive frames are required "
                "because a single frame cannot distinguish 'stopped' from 'about to be re-thrust' "
                "- setTotalVelocity: zeroes the reading for exactly one frame and applyThrust: "
                "rebuilds it on the next" % (n, MIN_REST_FRAMES)]
    return []


def check_rest_all_frames(arm):
    """D1. Every frame, every ship, at rest."""
    problems = []
    for index, frame in enumerate(arm["after"]):
        for ship in _ships(frame):
            if ship["speed"] > REST_EPS:
                problems.append(
                    "%s is moving at %.4f m/s on frame %d (t=%.4f) after being told to stop; the "
                    "engine RE-ACCELERATED it, which is what writing ship.velocity alone cannot "
                    "prevent" % (ship["id"], ship["speed"], index, float(frame["t"])))
    return problems


def check_position_frozen(arm):
    """D3. Checked independently of speed, not inferred from it.

    MEASURED BEHAVIOUR, and why this is not simply "every frame equals frame 0". Writing
    ship.speed = 0 holds flightSpeed at exactly 0 from the very first sampled frame, but position
    keeps changing for a frame or two afterwards: -setTotalVelocity: left the velocity ivar at
    `-thrustVector` rather than at zero, and that residual is integrated away over the next couple
    of frames. Observed on the fixed binary, one ship, px in metres:

        f0 -49475.584336   f1 -49483.762053   f2 -49490.024708   f3 -49490.024708   f4 (same)

    So the ship arrives at a permanent rest on frame 2 and never moves again. Demanding equality
    with frame 0 would reject that, which would be a checker asserting something the engine never
    claimed. Demanding nothing would accept a ship that drifts forever.

    This defence therefore locates the settle frame - the first frame from which every later
    position is IDENTICAL - and requires it to be early (<= MAX_SETTLE_FRAMES) with enough frozen
    frames after it to be meaningful. The settle index is reported in the PASS line, so a
    regression that doubles it is visible rather than silently absorbed.
    """
    frames = arm["after"]
    ids = sorted(s["id"] for s in _ships(frames[0]))
    if not ids:
        return ["no ships in the sampled frames"]

    def position_of(frame):
        return {s["id"]: (s["px"], s["py"], s["pz"]) for s in _ships(frame)}

    positions = [position_of(f) for f in frames]
    settle = None
    for start in range(len(positions)):
        if all(
            all(
                ship_id in positions[later]
                and max(abs(positions[later][ship_id][axis] - positions[start][ship_id][axis])
                        for axis in range(3)) <= POSITION_EPS
                for ship_id in ids
            )
            for later in range(start + 1, len(positions))
        ):
            settle = start
            break

    if settle is None:
        drift = max(
            abs(positions[-1][ship_id][axis] - positions[-2][ship_id][axis])
            for ship_id in ids if ship_id in positions[-1] and ship_id in positions[-2]
            for axis in range(3)
        )
        return ["position never stopped changing across %d sampled frames (still moving %.6f m "
                "between the last two) though every frame reported speed 0 - the ship is still "
                "being integrated" % (len(frames), drift)]

    problems = []
    if settle > MAX_SETTLE_FRAMES:
        problems.append(
            "position did not stop changing until frame %d; at most %d frame(s) of residual "
            "velocity decay are expected after the write (-setTotalVelocity: leaves the velocity "
            "ivar at -thrustVector, which integrates away), so a longer settle means something is "
            "still driving the ship" % (settle, MAX_SETTLE_FRAMES))
    frozen = len(frames) - settle
    if frozen < MIN_REST_FRAMES:
        problems.append(
            "only %d frame(s) remain after the position settled on frame %d; %d consecutive frozen "
            "frames are required, because a ship that happens to be stationary on the last frame "
            "sampled has not been shown to STAY stationary" % (frozen, settle, MIN_REST_FRAMES))
    arm["settle_frame"] = settle
    return problems


DEFENCES = (
    ("ships_present", check_ships_present),
    ("motion_before", check_motion_before),
    ("frames_advanced", check_frames_advanced),
    ("rest_frame_count", check_rest_frame_count),
    ("rest_all_frames", check_rest_all_frames),
    ("position_frozen", check_position_frozen),
)


# --- the CRUISE expectation: the complementary positive control ---------------------------------
#
# A seam that only ever accepts 0 would satisfy every defence above and still be useless: it would
# be a "stop()" spelled as a property. These defences judge the opposite claim - that a written
# NONZERO speed is held, and that the ship actually travels - so the two expectations together pin
# "the value written is the value kept" rather than "zero is reachable".
#
# Deliberately a SEPARATE table rather than a flag on the rest defences: sharing one function with
# an `if expect == ...` inside it means one mutation silently weakens both expectations at once,
# which is how a decomposed gate turns back into a single blind one (oo-3ya).

def check_cruise_speed_held(arm):
    """Every sampled frame reads the speed that was written, not a one-frame blip."""
    target = arm.get("target_speed")
    if target is None:
        return ["the arm does not record the speed it wrote, so 'held' cannot be checked"]
    problems = []
    for index, frame in enumerate(arm["after"]):
        for ship in _ships(frame):
            if abs(ship["speed"] - target) > CRUISE_EPS:
                problems.append(
                    "%s reads %.4f m/s on frame %d (t=%.4f) but %.4f was written; the engine did "
                    "not HOLD the scripted speed - a write that survives one frame and decays is "
                    "not a seam" % (ship["id"], ship["speed"], index, float(frame["t"]), target))
    return problems


def check_cruise_position_advances(arm):
    """Checked independently of speed: a speed reading with a frozen position is a lie.

    Monotonic per-axis distance from the frame-0 position. Comparing consecutive frames would pass
    a ship oscillating in place; comparing against the origin will not.
    """
    problems = []
    frames = arm["after"]
    first = {s["id"]: s for s in _ships(frames[0])}
    previous = {ship_id: 0.0 for ship_id in first}
    for index, frame in enumerate(frames[1:], start=1):
        for ship in _ships(frame):
            base = first.get(ship["id"])
            if base is None:
                problems.append("%s appears on frame %d but not on frame 0" % (ship["id"], index))
                continue
            moved = math.sqrt(sum((ship[a] - base[a]) ** 2 for a in ("px", "py", "pz")))
            if moved <= previous[ship["id"]]:
                problems.append(
                    "%s has travelled %.6f m by frame %d, no further than the %.6f m it had "
                    "reached by frame %d, though its speed reads nonzero - the speed is being "
                    "reported but not integrated"
                    % (ship["id"], moved, index, previous[ship["id"]], index - 1))
            previous[ship["id"]] = moved
    return problems


CRUISE_DEFENCES = (
    ("ships_present", check_ships_present),
    ("frames_advanced", check_frames_advanced),
    ("rest_frame_count", check_rest_frame_count),
    ("cruise_speed_held", check_cruise_speed_held),
    ("cruise_position_advances", check_cruise_position_advances),
)

def expectations():
    """The expectation table, rebuilt on every call.

    Deliberately a FUNCTION and not a module-level dict. A dict built at import time captures the
    DEFENCES tuple by reference, so a mutation harness that swaps cs.DEFENCES (which is exactly how
    the per-defence mutants in test_check_settled.py work) would leave judge() still running the
    original table - every mutant would appear killed while none of them were being applied. That
    regression was introduced here and caught by the all-defences-removed control; rebuilding per
    call keeps the mutants live.
    """
    return {"rest": DEFENCES, "cruise": CRUISE_DEFENCES}


def check_binary_identified(witness):
    """D7. A verdict about an unnamed binary is a verdict about nothing."""
    binary = witness.get("binary") or {}
    missing = [k for k in ("exe", "size", "md5") if not binary.get(k)]
    if missing:
        return ["the witness does not identify the binary it ran (missing %s); on a box where "
                "five worktrees hold a build at the same relative path, an unattributed run "
                "cannot testify about THIS tree's engine" % ", ".join(missing)]
    return []


def judge(witness, arm_name, expect="rest"):
    """Return (problems, arm). Raises Refusal when the witness cannot be judged.

    `expect` selects WHICH claim is being made about the arm. There is no default-by-guessing:
    asking for the rest claim about a cruise arm is a real failure and is reported as one, since a
    checker that silently picks the expectation that passes cannot fail.
    """
    if not isinstance(witness, dict) or not isinstance(witness.get("arms"), list):
        raise Refusal("witness is not a motion_probe result (no 'arms' list)")
    table = expectations()
    if expect not in table:
        raise Refusal("unknown expectation %r (known: %s)"
                      % (expect, ", ".join(sorted(table))))
    arms = [a for a in witness["arms"] if a.get("arm") == arm_name]
    if not arms:
        raise Refusal("witness contains no arm named %r (it has %s)"
                      % (arm_name, [a.get("arm") for a in witness["arms"]]))
    arm = arms[0]
    if not arm.get("after"):
        raise Refusal("arm %r has no post-write frames" % arm_name)

    problems = []
    for name, fn in table[expect]:
        for message in fn(arm):
            problems.append("[%s] %s" % (name, message))
    for message in check_binary_identified(witness):
        problems.append("[binary_identified] %s" % message)
    return problems, arm


def summarise(arm, witness):
    speeds = [s["speed"] for f in arm["after"] for s in _ships(f)]
    settle = arm.get("settle_frame")
    return ("arm=%s frames=%d ships=%d settled on frame %s max speed after the write=%.6f m/s "
            "(pre-write max %.4f m/s) binary=%s md5=%s"
            % (arm["arm"], len(arm["after"]), len(_ships(arm["after"][0])),
               "n/a" if settle is None else settle,
               max(speeds) if speeds else float("nan"),
               max(s["speed"] for s in _ships(arm["before"])),
               (witness.get("binary") or {}).get("exe", "?"),
               (witness.get("binary") or {}).get("md5", "?")))


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("witness")
    parser.add_argument("--arm", default="speed")
    parser.add_argument("--expect", default="rest", choices=sorted(expectations()),
                        help="which claim to judge: 'rest' (held at zero) or 'cruise' (a written "
                             "nonzero speed is held and the ship travels)")
    args = parser.parse_args(argv)

    try:
        with open(args.witness, encoding="utf-8") as handle:
            witness = json.load(handle)
    except (OSError, ValueError) as exc:
        print("REFUSED: cannot read %s: %s" % (args.witness, exc))
        return 2

    try:
        problems, arm = judge(witness, args.arm, args.expect)
    except Refusal as exc:
        print("REFUSED: %s" % exc)
        return 2

    if problems:
        print("FAIL: arm %r does not satisfy the %r expectation" % (args.arm, args.expect))
        # Capped: a re-accelerating ship produces one problem per ship per frame per axis, which
        # buries the verdict in scrollback. The names and the count are what a reader needs.
        for problem in problems[:MAX_REPORTED]:
            print("  " + problem)
        if len(problems) > MAX_REPORTED:
            print("  ... and %d more (defences that fired: %s)"
                  % (len(problems) - MAX_REPORTED,
                     ", ".join(sorted({p.split("]")[0][1:] for p in problems}))))
        return 1
    print("PASS: %s" % summarise(arm, witness))
    return 0


if __name__ == "__main__":
    sys.exit(main())
