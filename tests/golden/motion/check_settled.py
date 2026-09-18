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
import sys

# A ship at rest reads EXACTLY 0.0 in practice (flightSpeed is assigned, not integrated towards
# zero, once ship.speed = 0 is written). The epsilon is not slack for the engine, it is slack for
# the JSON round trip; it is deliberately far below the smallest speed any arm was ever observed
# to produce (the slowest non-zero sample across every run here was 2.125 m/s).
REST_EPS = 1e-6

# Position must not drift either. One millimetre over the whole window: the quantisation the golden
# storage policy stores at is 3 decimals = 1 mm, so anything a golden could distinguish is caught.
POSITION_EPS = 1e-3

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
    """D3. Checked independently of speed, not inferred from it."""
    problems = []
    first = {s["id"]: s for s in _ships(arm["after"][0])}
    for index, frame in enumerate(arm["after"][1:], start=1):
        for ship in _ships(frame):
            base = first.get(ship["id"])
            if base is None:
                problems.append("%s appears on frame %d but not on frame 0" % (ship["id"], index))
                continue
            for axis in ("px", "py", "pz"):
                drift = abs(ship[axis] - base[axis])
                if drift > POSITION_EPS:
                    problems.append(
                        "%s drifted %.6f m on %s by frame %d though its speed read as zero - the "
                        "ship is still being integrated" % (ship["id"], drift, axis, index))
    return problems


DEFENCES = (
    ("ships_present", check_ships_present),
    ("motion_before", check_motion_before),
    ("frames_advanced", check_frames_advanced),
    ("rest_frame_count", check_rest_frame_count),
    ("rest_all_frames", check_rest_all_frames),
    ("position_frozen", check_position_frozen),
)


def check_binary_identified(witness):
    """D7. A verdict about an unnamed binary is a verdict about nothing."""
    binary = witness.get("binary") or {}
    missing = [k for k in ("exe", "size", "md5") if not binary.get(k)]
    if missing:
        return ["the witness does not identify the binary it ran (missing %s); on a box where "
                "five worktrees hold a build at the same relative path, an unattributed run "
                "cannot testify about THIS tree's engine" % ", ".join(missing)]
    return []


def judge(witness, arm_name):
    """Return (problems, arm). Raises Refusal when the witness cannot be judged."""
    if not isinstance(witness, dict) or not isinstance(witness.get("arms"), list):
        raise Refusal("witness is not a motion_probe result (no 'arms' list)")
    arms = [a for a in witness["arms"] if a.get("arm") == arm_name]
    if not arms:
        raise Refusal("witness contains no arm named %r (it has %s)"
                      % (arm_name, [a.get("arm") for a in witness["arms"]]))
    arm = arms[0]
    if not arm.get("after"):
        raise Refusal("arm %r has no post-write frames" % arm_name)

    problems = []
    for name, fn in DEFENCES:
        for message in fn(arm):
            problems.append("[%s] %s" % (name, message))
    for message in check_binary_identified(witness):
        problems.append("[binary_identified] %s" % message)
    return problems, arm


def summarise(arm, witness):
    speeds = [s["speed"] for f in arm["after"] for s in _ships(f)]
    return ("arm=%s frames=%d ships=%d max speed after the write=%.6f m/s "
            "(pre-write max %.4f m/s) binary=%s md5=%s"
            % (arm["arm"], len(arm["after"]), len(_ships(arm["after"][0])),
               max(speeds) if speeds else float("nan"),
               max(s["speed"] for s in _ships(arm["before"])),
               (witness.get("binary") or {}).get("exe", "?"),
               (witness.get("binary") or {}).get("md5", "?")))


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("witness")
    parser.add_argument("--arm", default="speed")
    args = parser.parse_args(argv)

    try:
        with open(args.witness, encoding="utf-8") as handle:
            witness = json.load(handle)
    except (OSError, ValueError) as exc:
        print("REFUSED: cannot read %s: %s" % (args.witness, exc))
        return 2

    try:
        problems, arm = judge(witness, args.arm)
    except Refusal as exc:
        print("REFUSED: %s" % exc)
        return 2

    if problems:
        print("FAIL: the ship did not come to and stay at rest")
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
