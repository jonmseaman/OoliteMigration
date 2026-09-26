"""Measure whether a ship can be brought to, and HELD at, rest from JavaScript (bead oo-jou1).

WHY THIS EXISTS. Every golden landed so far pins a STATIC world, dumped under pauseGame() where
delta_t is forced to 0 (GameController.m:401-402) so nothing integrates. The moment a scenario
wants a MOVING world it needs the opposite: real frames, and a way to put a ship into a known
motion state and keep it there. tests/golden/dump/run_dump.py cannot answer that question at all,
because a paused world cannot distinguish "stopped" from "about to be re-thrust" - the exact
mistake this probe is built to make impossible.

WHAT IT MEASURES. A ship's velocity in this engine is two things added together
(ShipEntity.m:12830): the Newtonian `velocity` ivar plus a thrustVector, which is just
`v_forward * flightSpeed` (ShipEntity.m:12824). Writing ship.velocity from JS reaches only the
first: OOJSShip.m's kShip_velocity setter calls -setTotalVelocity:, which is documented
(ShipEntity.h:944) as setting velocity to `vel - thrustVector` - the INSTANTANEOUS velocity. The
engine is untouched, so -applyThrust: (ShipEntity.m:6734) regenerates the thrust on the very next
frame and the ship carries on. This probe samples per-frame speed so that re-acceleration is
visible as a number rather than inferred.

THE ARMS. Each arm is a different way of trying to stop a ship, run against the same spawn:
  velocity            ship.velocity = [0,0,0]                     (the pre-existing seam alone)
  desired             + ship.desiredSpeed = 0                     (the other pre-existing seam)
  desired-nullai      + setAI("nullAI.plist") so no AI re-commands desiredSpeed
  speed               + ship.speed = 0                            (the seam this bead adds)
Only the last is expected to produce immediate, sustained rest; the earlier arms are the controls
that say WHY the new seam is needed rather than asserting it.

The witness it prints is JSON and is consumed by check_settled.py, which owns every threshold.
This file measures; it never judges.
"""

import argparse
import json
import os
import plistlib
import shutil
import socket
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COMPONENT_DIR = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component")
DUMP_DIR = os.path.join(REPO_ROOT, "tests", "golden", "dump")

sys.path.insert(0, COMPONENT_DIR)
sys.path.insert(0, DUMP_DIR)

from console import DebugConsole  # noqa: E402
from state_dump import ensure_launchable, start_with_retry  # noqa: E402

SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"

ARMS = ("velocity", "desired", "desired-nullai", "performstop", "speed", "cruise")


def arm_body(arm):
    """The JS statements one arm applies to each of its ships, in order.

    THE ARM LADDER, and why each rung exists:
      velocity        the pre-existing seam alone (ship.velocity = 0 -> -setTotalVelocity:)
      desired         + desiredSpeed = 0; the other pre-existing numeric seam
      desired-nullai  + setAI('nullAI.plist') first, to remove the AI as a suspect
      performstop     ship.performStop(), the EXISTING engine path (ShipEntityAI.m:517) that sets
                      BEHAVIOUR_STOP_STILL and desired_speed = 0. Measured BEFORE inventing a new
                      mechanism, because an engine that already does the job does not need a
                      second way to do it.
      speed           performStop() + ship.speed = 0, the seam this bead adds
      cruise          the complementary POSITIVE control: hold a nonzero speed, which distinguishes
                      "the setter works" from "the setter only ever writes zero"
    """
    if arm == "velocity":
        return ["s.velocity = new Vector3D(0, 0, 0);"]
    if arm == "desired":
        return ["s.desiredSpeed = 0;", "s.velocity = new Vector3D(0, 0, 0);"]
    if arm == "desired-nullai":
        return ["s.setAI('nullAI.plist');", "s.desiredSpeed = 0;",
                "s.velocity = new Vector3D(0, 0, 0);"]
    if arm == "performstop":
        return ["s.performStop();", "s.velocity = new Vector3D(0, 0, 0);"]
    if arm == "speed":
        return ["s.performStop();", "s.speed = 0;", "s.velocity = new Vector3D(0, 0, 0);"]
    if arm == "cruise":
        return ["s.performStop();", "s.speed = %g;" % CRUISE_SPEED,
                "s.desiredSpeed = %g;" % CRUISE_SPEED]
    raise SystemExit("unknown arm %r" % arm)


# The positive control's target speed. Chosen below every stock ship's maxFlightSpeed so the clamp
# is not what is being measured here, and away from a round binary fraction so a value echoed back
# unchanged is recognisably THIS number.
CRUISE_SPEED = 137.0

# One JS call returns the whole sample, so every ship in a sample is read on the SAME frame.
# Reading them one property at a time would interleave frames and manufacture disagreement that
# the engine never produced.
#
# Only ships whose shipUniqueName carries the probe's own prefix are sampled. That is not tidiness:
# the system populator injects traffic mid-run (it is what parked bead oo-qwk5), stations are
# members of system.allShips and are permanently at speed 0, and either would let "every ship is
# at rest" pass for a reason that has nothing to do with the write under test.
SAMPLE_JS = (
    "(function(){"
    " var ships = system.allShips, out = [];"
    " for (var i = 0; i < ships.length; i++) {"
    "   var s = ships[i];"
    "   var id = s.shipUniqueName || '';"
    "   if (id.indexOf(%(prefix)r) !== 0) continue;"
    "   out.push({id: id, speed: s.speed, desiredSpeed: s.desiredSpeed,"
    "             vx: s.velocity.x, vy: s.velocity.y, vz: s.velocity.z,"
    "             px: s.position.x, py: s.position.y, pz: s.position.z});"
    " }"
    " out.sort(function(a,b){ return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0); });"
    " return JSON.stringify({t: clock.absoluteSeconds, ships: out}); })()"
)


def pick_port(preferred=None):
    """A port nobody else on this box is listening on.

    Five agents share this desktop and console.py binds a FIXED port, so a probe that hardcodes
    8563 can accept a neighbour's game (bead oo-gla measured exactly that: a gate that passed in
    six seconds because it attached to a leftover process). Bind-probing costs nothing and the
    port is made real for the game by write_console_config() below.
    """
    candidates = [preferred] if preferred else range(8700, 8800)
    for port in candidates:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.bind(("127.0.0.1", port))
            return port
        except OSError:
            continue
        finally:
            sock.close()
    raise SystemExit("no free console port")


def write_console_config(root, host, port):
    """Make a non-default port REAL by writing the plist the game merges.

    The game DIALS OUT and reads console-port from debugConfig.plist (OODebugSupport.m:67-80,
    kOOTCPConsolePort=8563 by default), so listening on another port without this file produces a
    60s timeout indistinguishable from a hung game - the trap tests/golden/golden_run.py's
    docstring records. Copied from golden_run.py::_write_console_config deliberately rather than
    imported: that module owns concurrency machinery this probe does not want.
    """
    config = os.path.join(root, "Config")
    os.makedirs(config, exist_ok=True)
    path = os.path.join(config, "debugConfig.plist")
    with open(path, "wb") as handle:
        plistlib.dump({"console-host": host, "console-port": port}, handle, fmt=plistlib.FMT_XML)
    return path


def stage_mesa_if_missing(app_dir):
    """Put Mesa's software GL beside the binary, but only if it is not already there.

    tests/golden/run.sh copies these UNCONDITIONALLY; this probe does not, on purpose. The GUI
    tier temporarily PARKS opengl32.dll/libgallium_wgl.dll out of a shared app dir and restores
    them, and writing them back underneath it is how that hazard spreads to every other worker
    (the 0xC0000135 incidents). Missing-only is enough for a fresh worktree build and touches
    nothing a sibling is managing.
    """
    prefix = os.environ.get("MINGW_PREFIX")
    staged = []
    if not prefix:
        return staged
    for dll in ("opengl32.dll", "libgallium_wgl.dll"):
        target = os.path.join(app_dir, dll)
        source = os.path.join(prefix, "bin", dll)
        if not os.path.isfile(target) and os.path.isfile(source):
            shutil.copy2(source, target)
            staged.append(dll)
    return staged


def app_dir_fingerprint(app_dir):
    """Identify the binary this run will actually execute.

    Every worker on this box has an app dir at the SAME relative path under its own worktree, and
    the shared one is the default. A run that silently picked up somebody else's build would show
    the UNFIXED behaviour and look exactly like a fix that did not work, so the size/mtime/digest
    of the exe are recorded in the witness and printed with every verdict.
    """
    exe = os.path.join(app_dir, "oolite.exe" if os.name == "nt" else "oolite")
    info = {"app_dir": app_dir.replace("\\", "/"), "exe": exe.replace("\\", "/")}
    try:
        st = os.stat(exe)
        info["size"] = st.st_size
        info["mtime"] = int(st.st_mtime)
    except OSError as exc:
        info["error"] = str(exc)
        return info
    import hashlib
    digest = hashlib.md5()
    with open(exe, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    info["md5"] = digest.hexdigest()
    return info


def clear_system(console):
    """Remove every non-player, non-station ship. Same reasoning as run_dump.py:clear_system."""
    console.evaluate_int(
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; }"
        " }"
        " return n; })()"
    )


def apply_arm(console, arm, prefix):
    """Apply one stopping strategy to the probe's own ships, returning the JS actually run.

    Written as ONE JS statement per arm so the whole strategy lands inside a single frame: doing
    it in two console round trips would let the simulation integrate between them and blur which
    write was responsible for what.
    """
    body = arm_body(arm)
    js = (
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   var s = ships[i];"
        "   if ((s.shipUniqueName || '').indexOf(%(prefix)r) !== 0) continue;"
        "   %(body)s"
        "   n++;"
        " }"
        " return n; })()" % {"prefix": prefix, "body": " ".join(body)}
    )
    touched = console.evaluate_int(js)
    if touched == 0:
        raise SystemExit(
            "arm %r touched 0 ships: the write never reached anything, so any later 'at rest' "
            "reading would be vacuous" % arm
        )
    return js


def sample_frames(console, count, tick_seconds, prefix):
    """Take `count` samples, each at least `tick_seconds` of GAME time after the previous one.

    Game time, never the harness clock: a sample loop gated on wall time measures how busy this
    box is, and under five-agent load that is not the same thing as how many frames the engine
    integrated (the same discipline as golden_run.py::_wait_until_rendering).
    """
    js = SAMPLE_JS % {"prefix": prefix}
    samples = []
    last_t = None
    deadline = time.time() + max(120.0, count * tick_seconds * 40)
    while len(samples) < count and time.time() < deadline:
        raw = json.loads(console.evaluate(js))
        t = float(raw["t"])
        if last_t is None or (t - last_t) >= tick_seconds:
            samples.append(raw)
            last_t = t
        else:
            time.sleep(0.02)
    if len(samples) < count:
        raise SystemExit(
            "only %d of %d samples advanced %ss of game time inside the wall budget; the game "
            "is not integrating, so any 'at rest' reading would be vacuous"
            % (len(samples), count, tick_seconds)
        )
    return samples


def spin_up(console, tick_seconds, prefix, floor, max_samples=80):
    """Wait until EVERY probe ship is genuinely moving, and fail loudly if none ever does.

    THE VACUITY THIS EXISTS FOR, found by running the probe without it. addShips spawns a ship at
    flightSpeed 0 and its AI accelerates it over the next second or so. A "stop it" arm applied
    during that window sees speed 0 on every frame afterwards and looks like a triumphant success
    while having done nothing at all - the first run of this probe produced exactly that reading
    for the desired-nullai arm (8/8 frames at 0.0000) purely because the ships had not started
    yet. The stop can only be evidence if there was motion to stop, so the precondition is
    asserted rather than assumed: every ship above `floor` at the same moment, or the run dies.
    """
    js = SAMPLE_JS % {"prefix": prefix}
    last = None
    for _ in range(max_samples):
        last = json.loads(console.evaluate(js))
        ships = last["ships"]
        if ships and all(s["speed"] >= floor for s in ships):
            return last
        time.sleep(max(0.05, tick_seconds / 2.0))
    raise SystemExit(
        "no frame had all %d probe ship(s) moving at >= %s m/s (last sample: %s); there was no "
        "motion to stop, so this run cannot say anything about stopping it"
        % (len(last["ships"]) if last else 0, floor,
           [(s["id"], round(s["speed"], 4)) for s in (last or {}).get("ships", [])])
    )


def spawn_named(console, role, count, prefix):
    """Spawn `count` ships of `role` named `<prefix>000`, `<prefix>001`, ...

    Same shape as tests/golden/dump/state_dump.py::spawn_deterministic, but the name prefix is
    the caller's rather than the role's, because this probe's whole identity discipline rests on
    the prefix being unique to one arm of one run - a role name is shared with whatever the
    populator injects.
    """
    js = (
        "(function(){"
        " var at = player.ship.position;"
        " var added = system.addShips(%(role)r, %(count)d, at, 0);"
        " if (!added) return 0;"
        " for (var i = 0; i < added.length; i++) {"
        "   added[i].shipUniqueName = %(prefix)r + ('000' + i).slice(-3);"
        " }"
        " return added.length; })()"
        % {"role": role, "count": count, "prefix": prefix}
    )
    added = console.evaluate_int(js)
    if added != count:
        raise SystemExit("asked for %d %r, addShips returned %d" % (count, role, added))
    return added


def run(app_dir, port, seed, output_dir, arms, frames, tick_seconds, role="pirate", count=2,
        motion_floor=20.0):
    config_dir = os.path.join(output_dir, "console-config")
    write_console_config(config_dir, "127.0.0.1", port)
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir
    )
    witness = {"arms": [], "frames": frames, "tick_seconds": tick_seconds,
               "role": role, "ships_requested": count, "port": port,
               "motion_floor": motion_floor,
               "binary": app_dir_fingerprint(app_dir)}
    try:
        console = start_with_retry(
            lambda: DebugConsole(app_dir, port, seed=seed, output_dir=output_dir,
                                 load_save=SCENARIO_SAVE)
        )
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
    try:
        # NOT paused, deliberately: under pauseGame() delta_t is 0 and EVERY arm would look like
        # a success because nothing integrates at all. The whole question is what the engine does
        # on the frames AFTER the write.
        for index, arm in enumerate(arms):
            # A fresh prefix per arm, so a ship left over from the previous arm cannot be counted
            # as this arm's - clear_system removes them, but the prefix makes that belt and braces
            # and survives a populator injection that happens to reuse a role.
            prefix = "jou1-%d-%s-" % (index, arm)
            clear_system(console)
            spawn_named(console, role, count, prefix)
            before = spin_up(console, tick_seconds, prefix, motion_floor)
            js = apply_arm(console, arm, prefix)
            after = sample_frames(console, frames, tick_seconds, prefix)
            witness["arms"].append({
                "arm": arm, "js": js, "prefix": prefix, "before": before, "after": after,
                # The speed this arm asked for, so check_settled.py judges "held" against the
                # value actually written rather than a constant duplicated in the checker.
                "target_speed": CRUISE_SPEED if arm == "cruise" else 0.0,
            })
    finally:
        console.close()
    return witness


def _main_unlocked(argv=None):
    parser = argparse.ArgumentParser()
    default_app = os.environ.get(
        "OO_APP_DIR", os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"))
    parser.add_argument("--app-dir", default=default_app)
    parser.add_argument("--port", type=int, default=int(os.environ.get("OO_CONSOLE_PORT", "0")))
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--tick-seconds", type=float, default=0.125)
    parser.add_argument("--arms", default=",".join(ARMS))
    parser.add_argument("--out", default=None)
    parser.add_argument("--output-dir", default=None)
    args = parser.parse_args(argv)

    arms = [a for a in args.arms.split(",") if a]
    bad = [a for a in arms if a not in ARMS]
    if bad:
        raise SystemExit("unknown arm(s) %s; known: %s" % (bad, list(ARMS)))
    if not os.path.isdir(args.app_dir):
        raise SystemExit("no Oolite build at %s; build it first or pass --app-dir" % args.app_dir)

    ensure_launchable(args.app_dir)
    stage_mesa_if_missing(args.app_dir)
    port = pick_port(args.port or None)

    output_dir = args.output_dir
    if output_dir is None:
        import tempfile
        output_dir = tempfile.mkdtemp(prefix="oo_jou1_motion_")
    os.makedirs(output_dir, exist_ok=True)

    witness = run(args.app_dir, port, args.seed, output_dir, arms, args.frames,
                  args.tick_seconds)
    text = json.dumps(witness, indent=2, sort_keys=True)
    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text + "\n")
        print("wrote %s" % args.out)
    else:
        print(text)
    return 0


def main(argv=None):
    """Run the probe holding tools/gui-lock (bead oo-hub0).

    The probe launches the game on the interactive desktop, one game, by hand - not as a member
    of the golden harness's concurrent fan-out - so CLAUDE.md's desktop-lock rule applies and
    tools/check-desktop-lock.sh lists it as a LOCKED launcher. No lock, no launch.
    """
    sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
    from desktop_lock import DesktopLockError, desktop_lock  # noqa: E402  - tools/desktop_lock.py

    try:
        with desktop_lock('motion-probe', start=__file__, stream=sys.stderr):
            return _main_unlocked(argv)
    except DesktopLockError as exc:
        print("motion-probe: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
