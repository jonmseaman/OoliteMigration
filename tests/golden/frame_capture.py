"""Render one frame from a FIXED camera pose, over the shared debug-console transport.

A frame hash is worthless unless the camera is nailed down: two renders taken from wherever the
player happened to drift to are two different scenes, and the "tolerance" absorbing that is a
tolerance that absorbs everything. So this module does not snapshot whatever is on screen. It
drives the game to a named, declared pose and only then takes the picture.

WHAT A POSE IS. The player ship IS the camera in the forward view (there is no JS route into
VIEW_CUSTOM - PlayerShip.setCustomView refuses unless the custom view is already active, which is
keyboard work and belongs to the GUI tier). So a pose is the player ship's position and
orientation, written directly: both are READWRITE on Entity (OOJSEntity.m). Velocity is zeroed as
well, or the ship coasts between the console round trip and the snapshot and the "fixed" camera is
fixed only on average.

WHY THE SEQUENCE IS THIS LONG. Reproducing world_steps.py's hard-won order, for the same reasons
it gives: (a) the main menu is a rotating DEMO scene, not a camera, so a save must be loaded;
(b) a loaded save starts DOCKED, where the screen is a station GUI and not a 3D view at all, so
the player must launch; (c) a loaded save carries ~80 entities including pirates that fly around,
so the system is cleared to the player before anything is rendered. The HUD is hidden too: it
draws a clock and a speed readout that change every frame and would be pure noise in the hash.

RASTERISER. Pinned to Mesa llvmpipe by console.py::_env (LIBGL_ALWAYS_SOFTWARE=1,
GALLIUM_DRIVER=llvmpipe) and re-asserted here before the game is launched, because the tolerance in
frame_hash.py was measured against THAT rasteriser and means nothing against another.

Everything about ports, staged app directories and the MSYS path boundary is golden_run's; this
file imports it rather than reimplementing it (bead oo-16s), and console.py remains the only
transport (ADR-0018).
"""

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import frame_hash  # noqa: E402
import golden_run  # noqa: E402

# NO DESKTOP LOCK, deliberately: this is a golden-harness scenario driver, exempt from tools/gui-lock
# on golden_run.py's terms (see its module docstring and tools/check-desktop-lock.sh). It launches
# through golden_run's per-run isolation - a reserved port, a staged private app dir, a private
# artifact dir - which exists so that golden runs can share one machine AT ONCE (stability sweeps,
# tier-b/tier-c golden stages, and several fleet worktrees' acceptance lines side by side). The
# desktop mutex is exclusive, so taking it here would serialise all of them into a queue of one.
# The run never needs the FOREGROUND: no synthetic input, no window click, readiness over the
# console socket, and every frame is rendered game-side from the game's own framebuffer. If this
# scenario ever starts to need the foreground it stops being exempt and must take the lock.

REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO_SAVE = "oolite-standard"

# WHERE THE GAME IS. Not "relative to this file", which is the trap: fleet work happens in git
# WORKTREES and accept.sh runs in a throwaway detached checkout under the MSYS temp dir, and
# neither contains a build - nobody builds a 5 GB game per worktree. The one built game on this
# host lives in the MAIN checkout and is shared by every tier. Resolution order:
#   1. an explicit --app-dir,
#   2. $OO_APP_DIR, so the tool is not welded to one machine,
#   3. a build inside this checkout, if there happens to be one (the non-worktree case),
#   4. the shared build in the main checkout.
# The directory is checked UP FRONT with a message naming the path, rather than failing deep
# inside a capture after a game has already been spawned.
SHARED_APP_DIR = "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"
LOCAL_APP_DIR = os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test", "oolite.app")

LAUNCH_TIMEOUT_SECONDS = 120
FRAME_SETTLE_SECONDS = 1.5

# Poses live in one table so a scenario names a pose instead of carrying magic vectors, and so the
# "deliberately different" pose is visibly a SIBLING of the reference rather than an ad-hoc edit.
# Coordinates are the save's own system frame, in metres; orientation is a quaternion [w,x,y,z].
POSES = {
    # The reference. Parked well clear of the station, looking along +z at the system's planet
    # and sun, which are the only large stable features an empty system has.
    "ref": {
        "position": [0.0, 0.0, 0.0],
        "orientation": [1.0, 0.0, 0.0, 0.0],
    },
    # SAME POSE, captured again: the noise-floor measurement. Identical by construction; kept as a
    # named entry so a calibration run reads as a table rather than as a special case.
    "ref-again": {
        "position": [0.0, 0.0, 0.0],
        "orientation": [1.0, 0.0, 0.0, 0.0],
    },
    # A DIFFERENT CAMERA POSITION: same orientation, translated. This is the mutant the bead
    # demands - a frame from a different camera position must clear the tolerance.
    "moved": {
        "position": [0.0, 0.0, 400000.0],
        "orientation": [1.0, 0.0, 0.0, 0.0],
    },
    # A DIFFERENT CAMERA ORIENTATION: 90 degrees of yaw from the reference, same point in space.
    # quaternion for a +90 deg rotation about y is [cos45, 0, sin45, 0].
    "turned": {
        "position": [0.0, 0.0, 0.0],
        "orientation": [0.7071067811865476, 0.0, 0.7071067811865476, 0.0],
    },
}


# SAME CAMERA, ALTERED SCENE: a trader parked dead ahead of the reference camera, at a declared
# range. This is the bead's "a deliberately moved ship changes the hash beyond tolerance" in its
# hardest form - nothing about the camera changed at all, only the contents of the frame.
#
# Range is a parameter and not a taste call, because it turned out to be the instrument's LIMIT
# rather than a detail. A frame hash sees objects that occupy PIXELS, not objects that exist.
# Measured against a noise floor of ~0.0030 (calibration.json -> sensitivity), a trader dead ahead
# scores:
#     200 m   0.0523   visible, ~17x the floor
#     400 m   0.0044   visible, ~1.5x the floor
#     800 m   0.0029   BELOW the floor - invisible
#    3000 m   0.0022   BELOW the floor - invisible
#   12000 m   0.0021   BELOW the floor - invisible
# So the instrument goes blind somewhere between 400 m and 800 m on a 960x720 surface.
#
# THAT IS WHY THE FIRST CALIBRATION OVERLAPPED, and the diagnosis matters: the populations did not
# overlap because the renderer is too noisy to hash, but because a ship at 3 km IS NOT A VISIBLY
# DIFFERENT FRAME - ref vs ship-3000m scored BELOW ref vs ref-again. A "different" scene that is
# not different on screen contributes a spurious weak signal and drags any threshold into the
# noise. The signal population therefore uses a change the hash can actually see, and the distant
# cases are kept as a measured SENSITIVITY CURVE, labelled as the technique's limit, where they
# document the boundary instead of defining the threshold.
SHIP_RANGE_M = 200
SENSITIVITY_RANGES = (200, 400, 800, 3000, 12000)


def _ship_pose(range_m):
    return {
        "position": [0.0, 0.0, 0.0],
        "orientation": [1.0, 0.0, 0.0, 0.0],
        "scene": [
            "(function(){ var s = system.addShips('trader', 1, [0, 0, %(r)d], 0);"
            " if (s && s.length) { s[0].position = [0, 0, %(r)d];"
            " s[0].orientation = [1, 0, 0, 0]; s[0].velocity = [0, 0, 0]; } })();"
            % {"r": int(range_m)}
        ],
    }


for _r in SENSITIVITY_RANGES:
    POSES["ship-%dm" % _r] = _ship_pose(_r)
POSES["ref-with-ship"] = _ship_pose(SHIP_RANGE_M)


class CaptureError(RuntimeError):
    pass


def _vec(values):
    return "[%s]" % ", ".join("%.6f" % float(v) for v in values)


def _assert_rasteriser():
    """The tolerance is a property of a renderer, so refuse to capture against another one."""
    env = {}
    for key, want in frame_hash.REQUIRED_GL_ENV.items():
        env[key] = os.environ.get(key, want)  # console.py sets these for the CHILD
        if env[key] != want:
            raise CaptureError(
                "rasteriser not pinned: %s=%r in this environment but the tolerance in "
                "frame_hash.py was measured with %s=%r. Refusing to capture a frame whose "
                "noise floor is unknown." % (key, env[key], key, want)
            )
    return env


def _settle(console, seconds=FRAME_SETTLE_SECONDS, timeout=90):
    """Advance on the GAME's clock, never ours (golden_run's rule): a fixed sleep snapshots
    whatever frame happened to be up, including a black first one."""
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(console.evaluate("clock.absoluteSeconds")) - start >= seconds:
            return
        time.sleep(0.25)
    raise CaptureError("game clock did not advance %ss within %ss" % (seconds, timeout))


def _launch_player(console):
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(1)
        if console.evaluate("player.ship.docked").strip().lower() == "false":
            return
    raise CaptureError(
        "player never launched within %ss; while docked the screen is a station GUI and there is "
        "no camera to fix" % LAUNCH_TIMEOUT_SECONDS
    )


def _clear_system(console):
    console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer) { ships[i].remove(); n++; } }"
        " return n; })()"
    )
    remaining = console.evaluate_int("system.allShips.length")
    if remaining > 1:
        raise CaptureError(
            "%d ships remain after clearing; a frame containing the ambient population is not a "
            "fixed scene and its hash would be noise" % remaining
        )


def apply_pose(console, pose):
    """Put the camera exactly where the pose says, and prove it landed there.

    The read-back is not ceremony. A pose that silently failed to apply gives two renders of the
    SAME wrong scene, which passes a same-scene check perfectly while measuring nothing.
    """
    console.perform("player.ship.hudHidden = true;")
    for js in pose.get("scene", []):
        console.perform(js)
    console.perform(
        "player.ship.position = %s; player.ship.orientation = %s; "
        "player.ship.velocity = [0, 0, 0];"
        % (_vec(pose["position"]), _vec(pose["orientation"]))
    )
    got = console.evaluate("player.ship.position")
    want = pose["position"]
    numbers = [float(x) for x in got.replace(",", " ").replace("(", " ").replace(")", " ").split()]
    if len(numbers) != 3 or max(abs(a - b) for a, b in zip(numbers, want)) > 1.0:
        raise CaptureError(
            "camera pose did not apply: asked for position %s, the game reports %r. Two captures "
            "from an unapplied pose are two renders of the same WRONG scene, which would pass a "
            "same-scene check while measuring nothing." % (want, got)
        )
    return numbers


def resolve_app_dir(explicit=None):
    """The built game, or a refusal that names every path tried."""
    tried = []
    for candidate, why in ((explicit, "--app-dir"),
                           (os.environ.get("OO_APP_DIR"), "$OO_APP_DIR"),
                           (LOCAL_APP_DIR, "this checkout"),
                           (SHARED_APP_DIR, "the shared build in the main checkout")):
        if not candidate:
            continue
        native = golden_run.to_native(os.path.abspath(candidate), why)
        if os.path.isdir(native):
            return native
        tried.append("%s (%s)" % (native, why))
    raise CaptureError(
        "no Oolite build found. Tried: %s. A worktree or a throwaway checkout contains no build "
        "by design; point --app-dir or $OO_APP_DIR at the shared build (%s)."
        % ("; ".join(tried) or "nothing", SHARED_APP_DIR)
    )


def capture(pose_name, out_dir, app_dir=None, keep=False):
    """Launch one game, drive it to `pose_name`, snapshot, return the PNG path."""
    if pose_name not in POSES:
        raise CaptureError("unknown pose %r; known: %s" % (pose_name, sorted(POSES)))
    pose = POSES[pose_name]
    _assert_rasteriser()

    sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))
    from console import DebugConsole  # noqa: E402

    out_dir = golden_run.to_native(os.path.abspath(out_dir), "out-dir")
    os.makedirs(out_dir, exist_ok=True)
    app_dir = resolve_app_dir(app_dir)

    run_root = os.path.join(out_dir, "_runs")
    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (pose_name, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir
    )
    started = time.time()
    try:
        console = DebugConsole(staged, port, seed=1, output_dir=artifact_dir,
                               load_save=SCENARIO_SAVE)
        console.start(ready_timeout=180)
        with console:
            _launch_player(console)
            _clear_system(console)
            applied = apply_pose(console, pose)
            _settle(console)
            before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
            console.perform("takeSnapShot();")
            png = golden_run._await_png(artifact_dir, before)
        final = os.path.join(out_dir, "%s-%s.png" % (pose_name, stamp))
        os.replace(png, final)
        digest = frame_hash.frame_hash(final)
        return {
            "pose": pose_name, "png": golden_run._slashes(final),
            "position": applied, "hash": frame_hash.hex_digest(digest),
            "port": port, "wall_seconds": round(time.time() - started, 1),
        }
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/frame_capture.py")
    parser.add_argument("pose", choices=sorted(POSES))
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--app-dir", default="")
    parser.add_argument("--keep", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = capture(args.pose, args.out_dir, args.app_dir or None, args.keep)
    except Exception as exc:  # noqa: BLE001 - the CLI reports, the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
