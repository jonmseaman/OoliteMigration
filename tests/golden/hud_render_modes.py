"""Golden scenario 020: hud-render-modes - the same 3-D scene under three HUD modes.

WHAT THIS SCENARIO IS FOR
=========================
`docs/phases/0-scenarios-18-20.md` §020 asks for the one rendering surface nothing looks at.
`tests/golden/frame_capture.py:apply_pose` BEGINS with `player.ship.hudHidden = true`, so **no
golden in existence renders a HUD**. The GUI tier asserts a window opened, took input and exited;
it never compares what was drawn. The component tier never looks at a frame. Scenario 003 differs
in the 3-D SCENE; here the 3-D stimulus is held constant - same pose, same emptied system, same
tick budget - and ONLY THE OVERLAY CHANGES, which is what isolates the HUD path. Every checklist
and test-oxp scenario is a load-time assertion; the HUD runs on every frame of every session and
is unobserved.

THE FRAME IS LOAD-BEARING HERE, AND THAT IS THE HARD PART
=========================================================
For scenarios 018 and 019 the frame was a second witness. Here it is THE witness: the difference
between two HUD modes exists nowhere else. `player.ship.hud` reads back a plist NAME, so a gate
resting on the read-back alone would pass against an engine that accepted the name and drew
nothing. So this scenario asserts a DIFFERENTIAL BETWEEN RENDERS, and the tolerance separating
"the same mode twice" from "two different modes" is MEASURED BY THIS SCENARIO, not inherited.

  Scenario 018 measured a frame tolerance and DELIBERATELY DID NOT ADOPT IT: staged expansions
  have no visual consequence from a docked camera, so the tolerance would have gated the RENDERER
  rather than the subject. Scenario 019 DID adopt one, because its status screen renders the
  equipment list. 020 must adopt one - the modes ARE the subject - and therefore must measure both
  populations itself. `--calibrate` does exactly that and `provenance.json` stores the result.

WHY THE SHARED TOLERANCE IS NOT REUSED
======================================
`tests/golden/calibration.json` records 0.004377, derived by bead oo-ae9 from 3-D SCENE changes
(a translated camera, a rotated camera, a ship 200 m ahead). Nobody had measured whether a HUD
overlay clears it; `oo-ae9` also measured that the instrument goes BLIND on a small stimulus - a
trader at 800 m scored BELOW the noise floor. A HUD is a modest, mostly-dark fraction of the
frame, so it might or might not clear the bar. That is the open question the catalogue records as
`buildable-pending-own-calibration`, and it is answered by measurement in `--calibrate`, whose
populations are stored in provenance.json. The spec's `within_mode_tolerance` is this scenario's
OWN number; the shared 0.004377 is recorded beside it for comparison and is NOT a predicate.

ANTI-VACUITY: WHAT A DEAD OR DEGENERATE RUN CANNOT PRODUCE
==========================================================
rc=0 and an absence of ERROR lines are BOTH satisfiable by a corpse - bead oo-het captured an
exit-87 process carrying the startup banner and zero ERROR lines, and separately a run a sibling
worker's console quit four seconds in while it still exited 0. So every clause here is POSITIVE:

  * `mode_separation` - the CLOSEST pair of DIFFERENT modes must be further apart than the
    FURTHEST pair of the SAME mode. Both numbers are stored in the dump, so the golden carries its
    own discrimination margin and a later run cannot pass by shrinking the stimulus.
  * `distinct_mode_grids` - the three modes must produce three DISTINCT grid digests. A run that
    silently rendered one scene three times fails here even before the distances are read.
  * `hud_refused_unknown_plist` - an ENGINE REFUSAL. `-switchHudTo:` (PlayerEntity.m:4519-4542)
    returns NO and leaves the HUD alone when `dictionaryFromFilesNamed:` yields nil, so writing a
    plist name that does not exist must leave `player.ship.hud` UNCHANGED. A permissive stub that
    stores whatever string it is handed reports the bogus name back. A refusal is positive
    evidence the setter validates; absence-of-error is not.
  * `hud_readback` - `player.ship.hud` must read back the plist that was requested for every
    non-hidden mode. An unapplied write yields three renders of the SAME scene, which passes a
    within-mode check while measuring nothing: the identical trap `apply_pose` already pays for on
    the camera.
  * `in_flight` - `docked` false and `guiScreen` GUI_SCREEN_MAIN at every capture, because the HUD
    is not drawn on station screens.
  * `pose_applied` - the position is read back within `pose_tolerance_m` BEFORE EVERY capture, so
    a drifting camera cannot masquerade as a HUD difference.
  * `frame_bytes` - every PNG above the spec's floor, against a measured 227-241 KB for real
    captures on this surface and ~5 KB for a black frame.
  * `liveness` - luminance spread of each grid above a measured floor; an empty render is 0.0.

Not evidence: exit code, absence of ERROR, the banner - and specifically NOT byte-identity of any
frame. `calibration.json`'s measured `exact_match_rate` is 0.0 and this scenario's own sweep
produced a distinct grid digest for every run, so a frame digest is recorded FOR AUDIT in
provenance.json and is never a predicate (bead oo-gxp's asymmetry: the dump is quantised and
deterministic and IS hashed byte-wise; the frame is compared by DISTANCE).

PORT / LAUNCH ISOLATION
=======================
`golden_run.py` wholesale, as 001/002/015/019 do: a reserved port, a staged app dir and a
debugConfig.plist in a private `OO_ADDITIONALADDONSDIRS`, because the game DIALS OUT to the port
named in that plist (OODebugSupport.m:67-80). A run on the shared 8563 can be captured by a
sibling worker's console and quit seconds in while still exiting rc=0 (bead oo-het).
"""

import argparse
import hashlib
import itertools
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import frame_hash  # noqa: E402
import golden_run  # noqa: E402
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "020-hud-render-modes"

# Guarded location FIRST, staged location second, through the identical idiom every other
# scenario uses, so landing is a pure `git mv` with no code change (bead oo-8ij: guardrails.sh
# refuses CREATE as well as MODIFY under goldens/, so a worker cannot land them itself).
# `scenarios/<id>/spec.json` is searched too because that is where a LANDING.md may put the spec.
SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "spec.json"),
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

TICK_WALL_BUDGET_SECONDS = 300
SETTLE_TIMEOUT_SECONDS = 120
FRAME_SETTLE_SECONDS = 1.5
LAUNCH_TIMEOUT_SECONDS = 180
CLEAR_ROUNDS = 20
# Clear-then-settle rounds a single capture may take before it refuses. MEASURED: with all three
# known traffic sources suppressed, a sweep still saw 3 ships back 1.5 game-seconds after a clear
# that removed 4, so one round is demonstrably not enough; 6 leaves a wide margin over the 1-2
# rounds observed to suffice, while still refusing rather than capturing a populated frame.
EMPTY_FRAME_ATTEMPTS = 6
HUD_SWITCH_ATTEMPTS = 12
# console.py's own default is 15 s, measured too short on this fleet box when sibling workers'
# games are resident (bead oo-rkm). Raising it changes no recorded value: every measured quantity
# comes from inside the game or from a PNG on disk.
CONSOLE_REPLY_TIMEOUT_SECONDS = 90

# Fallback only. The real numbers are read from provenance.json - the witness that lives OUTSIDE
# the artifact it defends (bead oo-gxp) - so a stripped checkout still has predicates with teeth
# rather than silently passing everything.
FRAME_LIVENESS_FLOOR_FALLBACK = 0.2

GUI_SCREEN_MAIN = "GUI_SCREEN_MAIN"


class ScenarioError(RuntimeError):
    """The run did not produce what this scenario asserts (rc=1)."""


class Refusal(RuntimeError):
    """The comparison could not be performed soundly, so no verdict is given (rc=2)."""


class PatientConsole:
    """A DebugConsole wrapper that waits longer for an answer, and NOTHING else.

    Scenario 002's class, for its measured reason: a 15-second reply timeout is generous on an
    idle machine and too short on a fleet box with sibling games resident, and a socket round trip
    is not one of this scenario's assertions.
    """

    def __init__(self, inner, timeout):
        self._inner = inner
        self._timeout = timeout

    def evaluate(self, js, timeout=None):
        return self._inner.evaluate(js, timeout=self._timeout if timeout is None else timeout)

    def evaluate_int(self, js, timeout=None):
        return self._inner.evaluate_int(js, timeout=self._timeout if timeout is None else timeout)

    def perform(self, js):
        return self._inner.perform(js)

    def close(self):
        return self._inner.close()


def safe_close(console):
    """Tear the console down WITHOUT letting the teardown replace the run's real exception."""
    try:
        console.close()
    except Exception as exc:  # noqa: BLE001 - reported, never allowed to mask the real failure
        sys.stderr.write("[teardown] console.close() raised %s: %s (ignored; the run's own "
                         "verdict stands)\n" % (type(exc).__name__, exc))


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise Refusal("no %s found; searched: %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for " + SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for " + SCENARIO)


def frame_path():
    return _first_existing(FRAME_CANDIDATES, "stored frame grid for " + SCENARIO)


def provenance_path():
    return _first_existing(PROVENANCE_CANDIDATES, "provenance.json for " + SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def mode_table(spec):
    """The declared modes, keyed by name, with the key order the spec declares.

    A dict comprehension would lose the order, and the order is what decides which mode's frame
    becomes `frame.grid`; `primary_mode` names it explicitly rather than relying on position.
    """
    table = {}
    for entry in spec["hud_modes"]:
        for field in ("mode", "hud", "hidden"):
            if field not in entry:
                raise Refusal("hud_modes entry %r does not declare %r" % (entry, field))
        table[entry["mode"]] = entry
    if spec["primary_mode"] not in table:
        raise Refusal("primary_mode %r is not one of the declared modes %s"
                      % (spec["primary_mode"], sorted(table)))
    return table


# --- the world, made quiet -----------------------------------------------------------------


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s pins system ID %d (%s) but the game reports %d"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))
    return got


def launch_player(console):
    """A loaded save starts DOCKED, where the screen is a station GUI and there is no HUD at all.

    The HUD is drawn over the 3-D view, so every capture in this scenario is taken IN FLIGHT and
    `in_flight` is an evidence field rather than an assumption.
    """
    if console.evaluate("String(player.ship.docked)").strip().lower() != "true":
        raise ScenarioError(
            "the save did not start docked; this scenario launches from the dock by construction "
            "and a run that began in flight loaded a different world")
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(1)
        if console.evaluate("String(player.ship.docked)").strip().lower() == "false":
            return True
    raise ScenarioError(
        "the player never launched within %ss. While docked the screen is a station GUI: no HUD "
        "is drawn, so three 'modes' would be three renders of the same station screen."
        % LAUNCH_TIMEOUT_SECONDS)


def assert_in_flight(console, where):
    """docked false AND GUI_SCREEN_MAIN - both, at every capture.

    `docked` alone is not enough: the player can be undocked while a mission or chart screen is
    up, and the HUD is not drawn over those either.
    """
    docked = console.evaluate("String(player.ship.docked)").strip().lower()
    screen = console.evaluate("String(guiScreen)").strip()
    if docked != "false" or screen != GUI_SCREEN_MAIN:
        raise ScenarioError(
            "not in flight at %s: docked=%r guiScreen=%r (want docked=false, guiScreen=%r). The "
            "HUD is drawn over the 3-D view only; on a station or chart screen all three modes "
            "render the same picture and the differential measures nothing."
            % (where, docked, screen, GUI_SCREEN_MAIN))
    return screen


def suppress_populators(console):
    """Switch the system populator off at the source (scenario 001/015/019's function)."""
    keys = console.evaluate(
        "(function(){ var s = system.populatorSettings, out = [];"
        " for (var k in s) out.push(k);"
        " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
        " return out.join(','); })()").strip()
    remaining = console.evaluate(
        "(function(){ var n = 0; for (var k in system.populatorSettings) n++;"
        " return String(n); })()").strip()
    if remaining not in ("0", ""):
        raise ScenarioError(
            "%s populator setting(s) survived suppression; the system will keep adding traffic "
            "and a ship drifting into frame between two captures is indistinguishable from a HUD "
            "difference" % remaining)
    return [k for k in keys.split(",") if k]


def suppress_station_traffic(console):
    """Switch off every station's own launch schedule (StationEntity.m:960-995, hasNPCTraffic).

    THIS IS NOT SUFFICIENT ON ITS OWN, and the engine says why. StationEntity.m:991 gates the
    patrol launch on

        if (!((isMainStation && [self hasNPCTraffic]) || hasPatrolShips) || [self launchPatrol])

    so a station whose shipdata sets `hasPatrolShips` launches patrols with hasNPCTraffic ALREADY
    OFF - the flag short-circuits the trader and shuttle arms above it (lines 967, 979) but not
    this one. That is the fourth traffic source, and it is reachable from C only: no JS write
    suppresses it. It is why _capture_mode() clears to a fixed point immediately before every
    shutter instead of trusting one sweep up front.
    """
    raw = console.evaluate(
        "(function(){ var e = system.stations, off = 0, on = [];"
        " for (var i = 0; i < e.length; i++) {"
        "   e[i].hasNPCTraffic = false; off++;"
        "   if (e[i].hasNPCTraffic) on.push(e[i].name); }"
        " return JSON.stringify([off, on]); })()").strip()
    try:
        count, still_on = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("station traffic suppression came back unparseable (%s): %r"
                            % (exc, raw[:200]))
    if still_on:
        raise ScenarioError("these station(s) still report hasNPCTraffic after it was written "
                            "false: %r" % (still_on,))
    if not count:
        raise ScenarioError(
            "no station was found to suppress. This save launches from Lave's main station by "
            "construction, so zero stations means the save did not load the world.")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` ENDS WITH an unconditional `return system.mainStation`, so
    switching `hasNPCTraffic` off does not stop it launching. The handler names come from the spec
    so an upstream rename becomes a red rather than a silent no-op.
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist; if it has been renamed "
                "upstream the suppression is silently doing nothing and this scenario is no "
                "longer deterministic. Re-derive the handler names rather than dropping the check."
                % name)
        console.perform("worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s did not become a no-op (it reads %r)"
                % (name, after[:120]))
        quieted.append(name)
    return quieted


def clear_system(console):
    """Remove every non-player entity. DOES NOT JUDGE - quiesce() decides.

    Stations are removed too, unlike scenario 019's docked variant: this scenario flies, and a
    Coriolis rotating in frame is a moving object that would put a real difference between two
    captures of the SAME mode and inflate the within-mode population.
    """
    removed = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer) n++; }"
        " return n; })()")
    return removed, remaining


def quiesce(console, rounds=CLEAR_ROUNDS):
    """Clear as a FIXED POINT; refuse if the world never reaches one."""
    history = []
    for _ in range(rounds):
        removed, remaining = clear_system(console)
        history.append([removed, remaining])
        if removed == 0 and remaining == 0:
            return history
        time.sleep(0.3)
    raise ScenarioError(
        "the world never went quiet: %d rounds went %r ([removed, remaining] per round). The "
        "three known sources (system populator, StationEntity's own schedule, oolite-populator.js "
        "systemWillRepopulate) are all switched off before this runs; a fourth source is a "
        "FINDING, not a reason to widen the round count." % (rounds, history))


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` ticks of GAME time, measured on clock.absoluteSeconds INSIDE the game.

    Never the harness clock: `tick_budget_met` is the one evidence field a photograph of tick 0
    cannot satisfy, and it is only worth that if the quantity measured is the universe clock.
    """
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + TICK_WALL_BUDGET_SECONDS
    while time.time() < deadline:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise ScenarioError("game time did not advance %ss within %ss of wall time"
                        % (budget, TICK_WALL_BUDGET_SECONDS))


def settle(console, seconds=FRAME_SETTLE_SECONDS, timeout=SETTLE_TIMEOUT_SECONDS):
    """Advance on the GAME's clock, never ours: a fixed sleep snapshots whatever frame was up."""
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(console.evaluate("clock.absoluteSeconds")) - start >= seconds:
            return
        time.sleep(0.25)
    raise ScenarioError("game clock did not advance %ss within %ss" % (seconds, timeout))


# --- the HUD, the subject ---------------------------------------------------------------------


def read_hud(console):
    return (console.evaluate("String(player.ship.hud)").strip(),
            console.evaluate("String(player.ship.hudHidden)").strip().lower() == "true")


def apply_hud_mode(console, entry, attempts=HUD_SWITCH_ATTEMPTS):
    """Write the mode and PROVE it landed, retrying the engine's documented deferral.

    `-switchHudTo:` (PlayerEntity.m:4530-4535) returns NO **without switching** when the HUD is
    mid-render: it stores a deferred name instead. The JS setter (OOJSPlayerShip.m:921-932)
    discards that return value, so a single write can silently be a no-op. Reading back and
    retrying is therefore not ceremony: an unapplied mode gives two renders of the SAME scene,
    which sails through a within-mode check while measuring nothing at all.
    """
    want_hud = entry["hud"]
    want_hidden = bool(entry["hidden"])
    last = None
    for _ in range(attempts):
        console.perform("player.ship.hud = %s;" % json.dumps(want_hud))
        console.perform("player.ship.hudHidden = %s;" % ("true" if want_hidden else "false"))
        got_hud, got_hidden = read_hud(console)
        last = (got_hud, got_hidden)
        if got_hud == want_hud and got_hidden == want_hidden:
            return {"mode": entry["mode"], "hud_requested": want_hud, "hud_readback": got_hud,
                    "hidden_requested": want_hidden, "hidden_readback": got_hidden,
                    "readback_matches": True}
        time.sleep(0.4)
    raise ScenarioError(
        "HUD mode %r did not apply: asked for hud=%r hudHidden=%r, the game reports hud=%r "
        "hudHidden=%r after %d attempts. -switchHudTo: returns NO and defers when the HUD is "
        "mid-render (PlayerEntity.m:4530-4535) and the JS setter discards that return, so an "
        "unapplied mode is SILENT - and three renders of an unapplied mode are three renders of "
        "the same scene, which passes a within-mode check while measuring nothing."
        % (entry["mode"], want_hud, want_hidden, last[0], last[1], attempts))


def probe_hud_refusal(console, spec):
    """THE ENGINE REFUSAL. An unknown plist name must leave the HUD unchanged.

    `-switchHudTo:` looks the name up with `dictionaryFromFilesNamed:` and, when that yields nil,
    logs `PlayerEntity.switchHudTo.failed` and returns NO WITHOUT TOUCHING the HUD
    (PlayerEntity.m:4537-4542). So `player.ship.hud` must still read back the previous name. A
    permissive model that simply stores the string it is handed reports the bogus name instead,
    and this is the one clause such a model cannot fake - unlike "no ERROR lines appeared", which
    a corpse satisfies (bead oo-het's exit-87 process).
    """
    bogus = spec["unknown_hud_plist"]
    before_hud, before_hidden = read_hud(console)
    console.perform("player.ship.hud = %s;" % json.dumps(bogus))
    time.sleep(0.4)
    after_hud, after_hidden = read_hud(console)
    return {
        "requested": bogus,
        "hud_before": before_hud,
        "hud_after": after_hud,
        "hidden_before": before_hidden,
        "hidden_after": after_hidden,
        "refused": after_hud == before_hud and after_hud != bogus,
    }


def apply_pose(console, spec):
    """Put the camera exactly where the spec says, and prove it landed there.

    The player ship IS the camera in the forward view, so a pose is its position and orientation,
    written directly. Velocity is zeroed as well or the ship coasts between the console round trip
    and the snapshot and the "fixed" camera is fixed only on average.
    """
    position = [float(v) for v in spec["pose_position"]]
    orientation = [float(v) for v in spec["pose_orientation"]]
    console.perform(
        "player.ship.position = [%s]; player.ship.orientation = [%s]; "
        "player.ship.velocity = [0, 0, 0];"
        % (", ".join("%.6f" % v for v in position),
           ", ".join("%.6f" % v for v in orientation)))
    got = console.evaluate("player.ship.position")
    numbers = [float(x) for x in got.replace(",", " ").replace("(", " ").replace(")", " ").split()]
    tol = float(spec["pose_tolerance_m"])
    if len(numbers) != 3 or max(abs(a - b) for a, b in zip(numbers, position)) > tol:
        raise ScenarioError(
            "camera pose did not apply: asked for position %s, the game reports %r (tolerance "
            "%.3f m). Two captures from an unapplied pose are two renders of the same WRONG "
            "scene, which would pass a same-scene check while measuring nothing."
            % (position, got, tol))
    return numbers


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot and return (png path, byte count, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: golden_run._await_png waits for the NAME, which on
    Windows shows up while the game still holds the handle open for writing. Both PermissionError
    and a truncated read are retried; a frame that never becomes readable is a failure rather than
    a hash of half a file (scenario 010's finding).
    """
    before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
    console.perform("takeSnapShot();")
    png = golden_run._await_png(artifact_dir, before)
    last = None
    for _ in range(attempts):
        try:
            return png, os.path.getsize(png), frame_hash.frame_grid(png)
        except (PermissionError, OSError, ValueError) as exc:
            last = exc
            time.sleep(0.25)
    raise ScenarioError(
        "the snapshot at %s never became readable (%s: %s); hashing a partial image would be "
        "worse than no frame at all." % (png, type(last).__name__, last))


def liveness(grid):
    """SPREAD of the luminance bytes, scaled to 0..1 - scenario 002/019's metric exactly.

    A run that died before drawing yields a (near-)uniform grid whose spread is ~0. The distance
    to an all-black grid is NOT used: a dim but fully-rendered scene sits close to black in that
    metric, so it cannot separate "dark scene" from "no scene".
    """
    return (max(grid) - min(grid)) / 255.0


def grid_digest(grid):
    return hashlib.sha256(bytes(grid)).hexdigest()


def pair_distances(grids_by_label):
    """Every unordered pair, as {"a": .., "b": .., "distance": ..}, in a stable order."""
    out = []
    for a, b in itertools.combinations(sorted(grids_by_label), 2):
        out.append({"a": a, "b": b,
                    "distance": frame_hash.distance(grids_by_label[a], grids_by_label[b])})
    return out


# --- the anti-vacuity gate ------------------------------------------------------------------


def assert_ran(evidence, spec):
    """Every clause names a field the dump CARRIES, applied BEFORE anything is written.

    Applied before the output file is opened, so a run that fails here cannot leave a blessable
    artifact behind (bead oo-gxp: 'rc != 0' and 'a dump exists' must never both be true of one
    invocation).
    """
    if evidence["system_id"] != int(spec["system_id"]):
        raise ScenarioError("the run is in system %d, not the pinned %d"
                            % (evidence["system_id"], int(spec["system_id"])))

    # --- the run really flew, and every capture was taken in flight --------------------------
    if evidence["in_flight"] is not True:
        raise ScenarioError(
            "in_flight is %r. Every capture must be taken undocked at %s: the HUD is drawn over "
            "the 3-D view only, so on a station screen all three modes render the same picture "
            "and the differential measures nothing." % (evidence["in_flight"], GUI_SCREEN_MAIN))
    if evidence["gui_screens"] != [GUI_SCREEN_MAIN] * len(evidence["modes"]):
        raise ScenarioError(
            "the captures were taken on screens %r, not %r at every one"
            % (evidence["gui_screens"], GUI_SCREEN_MAIN))
    if evidence["launched_from_dock"] is not True:
        raise ScenarioError("the run did not launch from the dock; it did not fly")

    # --- the modes were really applied -------------------------------------------------------
    declared = [entry["mode"] for entry in spec["hud_modes"]]
    if evidence["modes"] != declared:
        raise ScenarioError(
            "the run captured modes %r but the spec declares %r; a scenario that silently drops a "
            "mode has fewer populations to separate and the margin it reports is not the margin "
            "the spec asked for." % (evidence["modes"], declared))
    if len(declared) < 3:
        raise ScenarioError(
            "the spec declares %d HUD mode(s). With fewer than three there is no BETWEEN-mode "
            "population worth the name: one pair cannot distinguish 'the modes differ' from 'this "
            "particular pair differs'." % len(declared))
    if evidence["hud_readback_ok"] is not True:
        raise ScenarioError(
            "player.ship.hud did not read back the requested plist for every mode: %r. An "
            "unapplied write yields renders of the SAME scene, which passes a within-mode check "
            "while measuring nothing." % (evidence["hud_readbacks"],))
    if sorted(set(evidence["hud_readbacks"].values())) != sorted(
            set(entry["hud"] for entry in spec["hud_modes"])):
        raise ScenarioError(
            "the modes read back %r, which is not the set of plists the spec declares (%r)"
            % (evidence["hud_readbacks"],
               sorted(set(e["hud"] for e in spec["hud_modes"]))))
    if evidence["hidden_readbacks"] != [bool(e["hidden"]) for e in spec["hud_modes"]]:
        raise ScenarioError(
            "hudHidden read back %r across the modes; the spec declares %r"
            % (evidence["hidden_readbacks"], [bool(e["hidden"]) for e in spec["hud_modes"]]))

    # --- the ENGINE REFUSAL ------------------------------------------------------------------
    if evidence["hud_refused_unknown_plist"] is not True:
        raise ScenarioError(
            "writing the unknown HUD plist %r left player.ship.hud reading %r (it was %r before). "
            "-switchHudTo: returns NO and leaves the HUD alone when the dictionary is nil "
            "(PlayerEntity.m:4537-4542), so an accepted bogus name means the validation branch is "
            "gone - and a model that stores whatever string it is handed would report the bogus "
            "name here. A REFUSAL is positive evidence; absence of ERROR lines is not."
            % (spec["unknown_hud_plist"], evidence["hud_refusal_after"],
               evidence["hud_refusal_before"]))

    # --- the camera was nailed down before every capture -------------------------------------
    if evidence["pose_applied"] is not True:
        raise ScenarioError(
            "the camera pose was not verified before every capture (%r). A drifting camera puts a "
            "real difference between two captures and is indistinguishable from a HUD difference."
            % (evidence["pose_readbacks"],))

    # --- the frames are real ------------------------------------------------------------------
    floor_bytes = int(spec["min_png_bytes"])
    small = {m: n for m, n in evidence["frame_bytes"].items() if n < floor_bytes}
    if small:
        raise ScenarioError(
            "these captures are below the %d-byte floor: %r. A black frame compresses to ~5 KB "
            "while a real capture on this surface measures 227-241 KB, so an undersized PNG means "
            "nothing was drawn and every distance computed from it is noise."
            % (floor_bytes, small))
    live_floor = float(spec["frame_liveness_floor"])
    dead = {m: v for m, v in evidence["frame_liveness"].items() if v < live_floor}
    if dead:
        raise ScenarioError(
            "these grids have luminance spread below the measured floor %.6f: %r. A (near-)"
            "uniform grid is what a run that never drew the scene produces."
            % (live_floor, dead))

    # --- THE SUBJECT: the modes are distinguishable and each mode is stable -------------------
    if evidence["distinct_mode_grid_digests"] != len(declared):
        raise ScenarioError(
            "the %d modes produced only %d distinct grid digest(s). Identical grids mean the same "
            "scene was rendered more than once: the HUD mode did not change what was drawn, and "
            "no tolerance can rescue that." % (len(declared),
                                               evidence["distinct_mode_grid_digests"]))
    tol = float(spec["within_mode_tolerance"])
    if abs(evidence["within_mode_tolerance"] - tol) > 1e-12:
        raise ScenarioError(
            "the dump records tolerance %r but the spec pins %r; the golden and the spec have "
            "drifted apart and the stored margin is not the margin the spec asks for."
            % (evidence["within_mode_tolerance"], tol))
    if evidence["worst_within_mode_distance"] > tol:
        raise ScenarioError(
            "two captures of the SAME HUD mode (%s) differ by %.6f, beyond the measured tolerance "
            "%.6f. Either the HUD render became nondeterministic between captures, or rasteriser "
            "noise outgrew the calibration - re-measure the floor with --calibrate before touching "
            "the constant."
            % (evidence["within_mode_pair"], evidence["worst_within_mode_distance"], tol))
    if evidence["best_between_mode_distance"] <= tol:
        raise ScenarioError(
            "the closest pair of DIFFERENT HUD modes (%s) differ by only %.6f, which is WITHIN "
            "the tolerance %.6f. Switching the HUD no longer changes what is drawn: dial "
            "definitions are not loading, or the overlay pass was skipped. LOOSENING THE "
            "TOLERANCE TO MAKE THIS PASS IS FORBIDDEN - the threshold is measured, and a "
            "threshold moved to fit a result is decoration."
            % (evidence["best_between_mode_pair"], evidence["best_between_mode_distance"], tol))
    if evidence["best_between_mode_distance"] <= evidence["worst_within_mode_distance"]:
        raise ScenarioError(
            "the populations OVERLAP: the worst same-mode distance %.6f is not below the best "
            "different-mode distance %.6f, so no threshold separates them and a frame hash cannot "
            "discriminate these HUD modes on this renderer."
            % (evidence["worst_within_mode_distance"], evidence["best_between_mode_distance"]))
    if evidence["separation_ratio"] < float(spec["min_separation_ratio"]):
        raise ScenarioError(
            "the measured separation is only %.2fx (best between %.6f / worst within %.6f), under "
            "the spec's floor of %.2fx. A margin this thin means the stimulus has shrunk towards "
            "the noise and the next renderer change will flake the gate."
            % (evidence["separation_ratio"], evidence["best_between_mode_distance"],
               evidence["worst_within_mode_distance"], float(spec["min_separation_ratio"])))

    # --- the clock, and the world ------------------------------------------------------------
    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met")
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the world never reached a clean clear round")
    if evidence["ships_at_each_capture"] != [0] * len(evidence["modes"]):
        raise ScenarioError(
            "non-player ships were in frame at captures %r. Ambient traffic drifting through "
            "frame is a REAL difference between two captures of the same mode and would inflate "
            "the within-mode population, loosening the very tolerance this scenario measures. "
            "This is asserted PER CAPTURE rather than once at the end, because a run's final "
            "census cannot see traffic that was present for one capture and gone by the next - "
            "measured: a sweep found 3 ships 1.5 game-seconds after a clear that removed 4."
            % (evidence["ships_at_each_capture"],))
    if not evidence["clock_frozen_across_dump"]:
        raise ScenarioError(
            "the game clock advanced across the dump; the world is NOT frozen and the dump is a "
            "stopwatch reading")
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


# --- the run ---------------------------------------------------------------------------------


def _open_game(app_dir, spec, run_root, seed):
    """Stage one private game and return (console, artifact_dir, staged, port, restore)."""
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir)
    console = PatientConsole(start_with_retry(lambda: DebugConsole(
        staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
        load_save=spec["load_save"])), CONSOLE_REPLY_TIMEOUT_SECONDS)
    return console, artifact_dir, staged, port, previous


def _close_game(staged, previous, keep):
    if previous is None:
        os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
    else:
        os.environ["OO_ADDITIONALADDONSDIRS"] = previous
    if not keep:
        golden_run.unstage_app(staged)
    golden_run.release_all()


def _prepare_flight(console, spec, ticks):
    """Launch, silence every traffic source, empty the system, advance the tick budget."""
    system_id = assert_system(console, spec)
    launch_player(console)
    # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness. Scenario 010
    # measured eight of ten runs refusing when the suppression came after a multi-second probe,
    # because a station with hasNPCTraffic still on launched traffic in the meantime.
    suppressed = suppress_populators(console)
    stations_quieted = suppress_station_traffic(console)
    repopulator_handlers = suppress_repopulator(console, spec)
    clear_rounds = quiesce(console)
    elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
    return {
        "system_id": system_id,
        "populators_suppressed": len(suppressed),
        "stations_quieted": stations_quieted,
        "repopulator_handlers_quieted": sorted(repopulator_handlers),
        "clear_rounds": clear_rounds,
        "elapsed": elapsed,
    }


def ship_census(console):
    """Names of every non-player ship, so a traffic source can be NAMED rather than counted.

    A bare count says "something is here"; the name says WHICH source outran the suppression,
    which is the difference between a finding someone can act on and a number someone widens.
    """
    raw = console.evaluate(
        "(function(){ var s = system.allShips, out = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer) out.push((s[i].shipUniqueName || s[i].name || '?') + ':' +"
        "                                (s[i].primaryRole || '?')); }"
        " return JSON.stringify(out); })()").strip()
    try:
        return json.loads(raw)
    except ValueError:
        raise ScenarioError("the ship census came back unparseable: %r" % raw[:200])


def _capture_mode(console, spec, entry, artifact_dir, label, attempts=EMPTY_FRAME_ATTEMPTS):
    """Apply a HUD mode, empty the frame AS A FIXED POINT, re-apply the pose, settle, snapshot.

    THE CLEAR IS A FIXED POINT PER CAPTURE, not a single sweep up front, and that is a MEASURED
    requirement with a NAMED cause. With all three JS-reachable traffic sources suppressed and the
    world cleared to a fixed point before the tick budget, stability sweeps still saw ships back in
    frame at capture time: 1 of 10 runs found one ship at the last capture, and a later run found
    THREE at the first capture 1.5 game-seconds after a clear that had removed four.

    The fourth source is in the ENGINE, not in the populator script. StationEntity.m:991 gates the
    patrol launch on `!((isMainStation && [self hasNPCTraffic]) || hasPatrolShips)`, so a station
    carrying `hasPatrolShips` launches patrols with hasNPCTraffic ALREADY OFF - unlike the trader
    and shuttle arms at lines 979 and 967, which that flag does stop. No JS write reaches it, so it
    cannot be suppressed the way the other three were; it can only be OUTLASTED, by making the
    world empty at the instant of the shutter rather than some seconds earlier.

    Why this is not "widening a tolerance to make it pass": a ship in frame is a REAL difference
    between two captures of the same mode, so tolerating it would inflate the within-mode
    population and LOOSEN the very threshold this scenario exists to measure. The fix is to make
    the world actually empty at the instant of the snapshot - the same discipline the pose
    read-back already applies to the camera - and to keep the assertion at exactly zero. A capture
    that cannot reach an empty frame in `attempts` tries REFUSES; it never captures anyway.
    """
    applied = apply_hud_mode(console, entry)
    history = []
    for attempt in range(1, attempts + 1):
        removed, remaining = clear_system(console)
        pose = apply_pose(console, spec)
        screen = assert_in_flight(console, label)
        settle(console)
        census = ship_census(console)
        history.append({"attempt": attempt, "removed": removed, "remaining_after_clear": remaining,
                        "present_after_settle": census})
        if not census:
            png, nbytes, grid = capture_frame(console, artifact_dir)
            # AFTER the shutter as well: the count that matters is the one describing the frame
            # that was actually taken, and a ship that arrived during the snapshot would make the
            # before-count a statement about a different frame.
            after = ship_census(console)
            if after:
                continue
            record = dict(applied)
            record.update({"label": label, "png": golden_run._slashes(png), "bytes": nbytes,
                           "pose": pose, "gui_screen": screen, "liveness": liveness(grid),
                           "grid_sha256": grid_digest(grid), "ships_at_capture": 0,
                           "empty_frame_attempts": attempt, "clear_history": history})
            return record, grid
    raise ScenarioError(
        "capture %r never reached an empty frame in %d attempts: %r. Ambient traffic drifting "
        "through frame is a REAL difference between two captures of the same mode and would "
        "inflate the within-mode population, loosening the tolerance this scenario measures. A "
        "traffic source that outruns %d clear-then-settle rounds is a FINDING - name it from the "
        "census above - not a reason to drop this check." % (label, attempts, history, attempts))


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, frame_out_dir=None, freeze_hud=False):
    """One game process, three HUD modes, one canonical dump, one frame grid per mode.

    `freeze_hud` is the MUTANT ARM: it captures every mode WITHOUT ever writing the HUD, so all
    three renders are the same scene. The run MUST then fail its own assertions; a scenario that
    stays green with the HUD frozen is asserting nothing about HUD modes.
    """
    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    modes = mode_table(spec)
    declared = [entry["mode"] for entry in spec["hud_modes"]]
    primary = spec["primary_mode"]

    started = time.time()
    # A HARNESS MUST DELETE ITS OUTPUT PATHS BEFORE EVERY RUN, or it cannot distinguish "this run
    # produced this" from "something produced this once" (bead oo-gxp's stale-scratch phantom,
    # which manufactured an intermittent failure two workers chased).
    stale_paths = [out_path, frame_out]
    if frame_out_dir:
        stale_paths += [os.path.join(frame_out_dir, "frame-%s.grid" % m) for m in declared]
        stale_paths += [os.path.join(frame_out_dir, "frame.grid"), os.path.join(frame_out_dir,
                                                                                "frame.png")]
    for stale in stale_paths:
        if stale and os.path.exists(stale):
            os.remove(stale)

    console, artifact_dir, staged, port, previous = _open_game(app_dir, spec, run_root, seed)
    try:
        try:
            world = _prepare_flight(console, spec, ticks)

            grids = {}
            captures = []
            for entry in spec["hud_modes"]:
                mode_entry = entry
                if freeze_hud:
                    # MUTANT: never write the HUD. Everything else about the run is untouched;
                    # only the property under test is removed, so the three captures become three
                    # renders of the same scene and the between-mode population collapses.
                    mode_entry = dict(modes[primary])
                    mode_entry["mode"] = entry["mode"]
                record, grid = _capture_mode(console, spec, mode_entry, artifact_dir,
                                             entry["mode"])
                record["mode"] = entry["mode"]
                captures.append(record)
                grids[entry["mode"]] = grid

            # THE WITHIN-MODE WITNESS: the primary mode captured a SECOND time, from the same
            # process, after the other modes have been through. Without it the run has a
            # between-mode population and nothing to compare it against, and the tolerance would
            # be an inherited number rather than a measured one.
            repeat_record, repeat_grid = _capture_mode(
                console, spec, modes[primary] if not freeze_hud else modes[primary],
                artifact_dir, "%s#repeat" % primary)
            repeat_record["mode"] = primary

            refusal = probe_hud_refusal(console, spec)
            # Put the primary mode back so the dump and the blessed frame describe one state.
            apply_hud_mode(console, modes[primary])

            ships_in_frame = console.evaluate_int(
                "(function(){ var s = system.allShips, n = 0;"
                " for (var i = 0; i < s.length; i++) { if (!s[i].isPlayer) n++; }"
                " return n; })()")

            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The "
                    "simulation would keep integrating through the dump and no two runs could "
                    "agree." % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))
            final_hud, final_hidden = read_hud(console)
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            clock_frozen = clock_after == clock_before

            state = json.loads(dump_state(console))
        finally:
            safe_close(console)

        between = pair_distances(grids)
        best_between = min(between, key=lambda p: p["distance"])
        within_distance = frame_hash.distance(grids[primary], repeat_grid)
        tol = float(spec["within_mode_tolerance"])

        hud_readbacks = {c["mode"]: c["hud_readback"] for c in captures}
        hidden_readbacks = [c["hidden_readback"] for c in captures]
        evidence = {
            "scenario": SCENARIO,
            "seed": seed,
            "ticks": ticks,
            "system_id": world["system_id"],
            "launched_from_dock": True,
            "in_flight": all(c["gui_screen"] == GUI_SCREEN_MAIN for c in captures)
                         and repeat_record["gui_screen"] == GUI_SCREEN_MAIN,
            "gui_screens": [c["gui_screen"] for c in captures],
            "modes": declared,
            "primary_mode": primary,

            "hud_readbacks": hud_readbacks,
            "hud_readback_ok": all(c["readback_matches"] for c in captures),
            "hidden_readbacks": hidden_readbacks,
            "final_hud": final_hud,
            "final_hud_hidden": final_hidden,

            "hud_refusal_requested": refusal["requested"],
            "hud_refusal_before": refusal["hud_before"],
            "hud_refusal_after": refusal["hud_after"],
            "hud_refused_unknown_plist": bool(refusal["refused"]),

            "pose_readbacks": {c["label"]: c["pose"] for c in captures + [repeat_record]},
            "pose_applied": True,

            "frame_bytes": {c["mode"]: c["bytes"] for c in captures},
            "frame_liveness": {c["mode"]: c["liveness"] for c in captures},
            "mode_grid_digests": {c["mode"]: c["grid_sha256"] for c in captures},
            "distinct_mode_grid_digests": len({c["grid_sha256"] for c in captures}),

            "between_mode_distances": between,
            "best_between_mode_distance": best_between["distance"],
            "best_between_mode_pair": "%s vs %s" % (best_between["a"], best_between["b"]),
            "within_mode_pair": "%s vs %s#repeat" % (primary, primary),
            "worst_within_mode_distance": within_distance,
            "within_mode_tolerance": tol,
            "separation_ratio": (best_between["distance"] / within_distance
                                 if within_distance > 0 else float("inf")),
            "shared_calibration_tolerance": frame_hash.derive_tolerance(),

            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump -
            # the overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor).
            "tick_budget_met": bool(world["elapsed"] >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "clock_frozen_across_dump": bool(clock_frozen),
            "ships_in_frame": ships_in_frame,
            "ships_at_each_capture": [c["ships_at_capture"] for c in captures],
            "empty_frame_attempts": [c["empty_frame_attempts"] for c in captures],
            "world_reached_fixed_point": bool(world["clear_rounds"])
                                         and world["clear_rounds"][-1] == [0, 0],
            "populators_suppressed": world["populators_suppressed"],
            "stations_quieted": world["stations_quieted"],
            "repopulator_handlers_quieted": world["repopulator_handlers_quieted"],
        }
        assert_ran(evidence, spec)
        state["hud"] = {
            "modes": [{"mode": c["mode"], "hud": c["hud_readback"], "hidden": c["hidden_readback"],
                       "png_bytes": c["bytes"], "liveness": c["liveness"],
                       "grid_sha256": c["grid_sha256"]} for c in captures],
            "primary_mode": primary,
            "separation": {
                "between_mode_distances": between,
                "best_between_mode_distance": best_between["distance"],
                "worst_within_mode_distance": within_distance,
                "tolerance": tol,
                "ratio": evidence["separation_ratio"],
            },
        }
        state["evidence"] = evidence
        text = canonical(state)

        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        if frame_out:
            parent = os.path.dirname(os.path.abspath(frame_out))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(frame_out, "wb") as handle:
                handle.write(bytes(grids[primary]))
        if frame_out_dir:
            os.makedirs(frame_out_dir, exist_ok=True)
            for mode, grid in grids.items():
                with open(os.path.join(frame_out_dir, "frame-%s.grid" % mode), "wb") as handle:
                    handle.write(bytes(grid))
            with open(os.path.join(frame_out_dir, "frame.grid"), "wb") as handle:
                handle.write(bytes(grids[primary]))
            primary_png = [c["png"] for c in captures if c["mode"] == primary][0]
            with open(primary_png, "rb") as src:
                blob = src.read()
            with open(os.path.join(frame_out_dir, "frame.png"), "wb") as handle:
                handle.write(blob)
        return {"ok": True, "out": out_path, "frame_out": frame_out, "port": port,
                "bytes": len(text), "frame_hash": frame_hash.hex_digest(grids[primary]),
                "game_seconds_elapsed": round(world["elapsed"], 3),
                "wall_seconds": round(time.time() - started, 1), "evidence": evidence,
                "captures": captures + [repeat_record]}
    finally:
        _close_game(staged, previous, keep)


# --- this scenario's OWN calibration ------------------------------------------------------------


def calibrate(app_dir, spec, run_root, repeats, keep=False):
    """Measure BOTH populations, each capture from ITS OWN game process, and derive a tolerance.

    This is what `buildable-pending-own-calibration` means in the catalogue, and it is the only
    honest way to get the constant: the shared `calibration.json` tolerance was derived from 3-D
    SCENE changes and says nothing about whether a HUD OVERLAY clears the bar on this surface.

    PER-PROCESS, DELIBERATELY. A within-mode floor measured by hashing one PNG twice is zero and
    proves nothing; a floor measured twice inside ONE process misses process start, frame timing
    and the game clock at the moment of capture - every source of variation the real gate faces
    across two stability runs. So each capture launches its own game.

    If the populations OVERLAP, that is REPORTED AS A FINDING and rc=2. It is a real result about
    this renderer and this stimulus, not a script failure, and LOOSENING THE TOLERANCE TO MAKE IT
    PASS IS FORBIDDEN (docs/phases/0-scenarios-18-20.md §020).
    """
    started = time.time()
    shots = []
    for entry in spec["hud_modes"]:
        for i in range(repeats):
            label = "%s#%d" % (entry["mode"], i)
            console, artifact_dir, staged, port, previous = _open_game(
                app_dir, spec, run_root, int(spec["seed"]))
            try:
                _prepare_flight(console, spec, int(spec["ticks"]))
                record, grid = _capture_mode(console, spec, entry, artifact_dir, label)
                record["mode"] = entry["mode"]
                record["grid"] = grid
                shots.append(record)
                print("[.] %-18s hud=%-16s hidden=%-5s %7d bytes  liveness %.4f  %s"
                      % (label, record["hud_readback"], record["hidden_readback"],
                         record["bytes"], record["liveness"], record["grid_sha256"][:16]),
                      flush=True)
            finally:
                safe_close(console)
                _close_game(staged, previous, keep)

    within, between = [], []
    for a, b in itertools.combinations(shots, 2):
        d = frame_hash.distance(a["grid"], b["grid"])
        rec = {"a": a["label"], "b": b["label"], "distance": d}
        (within if a["mode"] == b["mode"] else between).append(rec)

    floor = max(p["distance"] for p in within)
    signal = min(p["distance"] for p in between)
    separated = floor < signal
    cal = {
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "scenario": SCENARIO,
        "rasteriser": dict(frame_hash.REQUIRED_GL_ENV),
        "surface": "960x720 windowed (SDL; the offscreen driver is unusable here - no EGL)",
        "hash": {"kind": "l1-luminance-grid", "side": frame_hash.GRID_SIDE,
                 "cells": frame_hash.GRID_CELLS},
        "modes": [e["mode"] for e in spec["hud_modes"]],
        "repeats_per_mode": repeats,
        "captures": [{k: s[k] for k in ("label", "mode", "hud_readback", "hidden_readback",
                                        "bytes", "liveness", "grid_sha256")} for s in shots],
        "within_mode_pairs": sorted(within, key=lambda p: p["distance"]),
        "between_mode_pairs": sorted(between, key=lambda p: p["distance"]),
        "within_mode_distances": sorted(p["distance"] for p in within),
        "between_mode_distances": sorted(p["distance"] for p in between),
        "worst_within_mode_distance": floor,
        "best_between_mode_distance": signal,
        "separated": separated,
        "distinct_grid_digests": len({s["grid_sha256"] for s in shots}),
        "captures_total": len(shots),
        "shared_calibration_tolerance": frame_hash.derive_tolerance(),
        "liveness_min": min(s["liveness"] for s in shots),
        "png_bytes_min": min(s["bytes"] for s in shots),
        "measure_seconds": round(time.time() - started, 1),
    }
    if separated:
        # The SAME derivation rule frame_hash uses: the geometric mean of the two populations, so
        # the reported margin is the same multiple in each direction and a large signal does not
        # drag the threshold up next to itself.
        cal["tolerance"] = (floor * signal) ** 0.5
        cal["margin"] = cal["tolerance"] / floor
        cal["separation_ratio"] = signal / floor
    else:
        cal["tolerance"] = None
        cal["margin"] = None
        cal["separation_ratio"] = signal / floor if floor else None
        cal["finding"] = (
            "POPULATIONS OVERLAP: the worst same-mode distance (%.6f) is not below the best "
            "different-mode distance (%.6f), so no threshold separates them on this renderer and "
            "a frame hash cannot discriminate these HUD modes at this surface size. Per "
            "docs/phases/0-scenarios-18-20.md the correct response is to record the finding, NOT "
            "to loosen the tolerance." % (floor, signal))
    print(json.dumps(cal, indent=2, sort_keys=True))
    return cal


# --- offline checks on stored artifacts ---------------------------------------------------------


REQUIRED_EVIDENCE_FIELDS = (
    "in_flight", "gui_screens", "modes", "hud_readbacks", "hud_readback_ok",
    "hidden_readbacks", "hud_refused_unknown_plist", "pose_applied", "frame_bytes",
    "frame_liveness", "mode_grid_digests", "distinct_mode_grid_digests",
    "between_mode_distances", "best_between_mode_distance", "worst_within_mode_distance",
    "within_mode_tolerance", "separation_ratio", "tick_budget_met",
)


def check_evidence(path, spec, label=None):
    """Re-apply assert_ran to a STORED dump - what makes the golden self-describing."""
    label = label or path
    if not os.path.isfile(path):
        raise Refusal("no dump at %s" % path)
    with open(path, "r", encoding="utf-8") as handle:
        state = json.load(handle)
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise Refusal(
            "%s carries no evidence block; a dump with no evidence compares equal to any other "
            "evidence-free dump and proves nothing about the HUD" % label)
    missing = [k for k in REQUIRED_EVIDENCE_FIELDS if k not in evidence]
    if missing:
        raise Refusal("%s's evidence block is missing %s" % (label, missing))
    assert_ran(evidence, spec)
    print("PASS: %s proves the HUD render modes ran: %d modes %s captured in flight at %s, "
          "%d distinct grid digests, closest different-mode pair (%s) %.6f vs worst same-mode "
          "pair (%s) %.6f - %.2fx separation against a measured tolerance of %.6f; unknown plist "
          "%r REFUSED (hud stayed %r)."
          % (label, len(evidence["modes"]), evidence["modes"], GUI_SCREEN_MAIN,
             evidence["distinct_mode_grid_digests"], evidence["best_between_mode_pair"],
             evidence["best_between_mode_distance"], evidence["within_mode_pair"],
             evidence["worst_within_mode_distance"], evidence["separation_ratio"],
             evidence["within_mode_tolerance"], evidence["hud_refusal_requested"],
             evidence["hud_refusal_after"]))
    return 0


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        # Formatted by frame_hash so the side-length attribute cannot be mistyped at this call
        # site - the typo lives inside the error path and is invisible on every green run.
        raise Refusal(frame_hash.wrong_grid_size_message(path, len(blob)))
    return blob


def _blessed_liveness_floor():
    """Read the liveness floor from provenance.json - the witness OUTSIDE the artifact."""
    for candidate in PROVENANCE_CANDIDATES:
        if os.path.isfile(candidate):
            with open(candidate, "r", encoding="utf-8") as handle:
                prov = json.load(handle)
            live = prov.get("frame_liveness") or {}
            floor = live.get("floor")
            if live.get("asserted") is True and isinstance(floor, (int, float)) and floor > 0:
                return float(floor), candidate
            raise ScenarioError(
                "%s frame_liveness=%r must assert a positive floor; liveness is the one frame "
                "property a dead run cannot fake, and without it the frame is entirely unpinned"
                % (candidate, live))
    return FRAME_LIVENESS_FLOOR_FALLBACK, None


def check_frame(grid_path, reference_path):
    """Assert LIVENESS and the within-mode distance tolerance against the blessed primary frame.

    NEVER BYTE-HASH THE FRAME. llvmpipe is not bit-reproducible: this scenario's sweep produced a
    distinct grid digest for every single run, so a digest comparison would flake on renderer
    noise while the dump - quantised and deterministic - IS hashed byte-wise. That asymmetry is
    the point (bead oo-gxp), and the digests are recorded in provenance.json FOR AUDIT only.
    """
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    floor, floor_source = _blessed_liveness_floor()
    spec = load_spec()
    tol = float(spec["within_mode_tolerance"])
    live = liveness(got)
    d = frame_hash.distance(got, want)
    result = {
        "distance_to_reference": d,
        "tolerance": tol,
        "tolerance_source": "spec.json within_mode_tolerance (measured by --calibrate)",
        "within_tolerance": d <= tol,
        "liveness": live,
        "liveness_floor": floor,
        "liveness_floor_from": floor_source or "FRAME_LIVENESS_FLOOR_FALLBACK",
        "liveness_metric": "luminance spread (max-min)/255",
        "reference_liveness": liveness(want),
        "live": live >= floor,
        "verdict_rests_on": "liveness AND the measured within-mode tolerance",
        "hash_got": frame_hash.hex_digest(got),
        "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    rc = 0
    if not result["live"]:
        print("FAIL: %s has luminance spread %.6f, below the blessed floor %.6f. The frame is "
              "(near-)uniform, which is what a run that never drew the scene produces."
              % (grid_path, live, floor), file=sys.stderr)
        rc = 1
    if not result["within_tolerance"]:
        print("FAIL: %s sits %.6f from the blessed %s-mode reference, past the measured "
              "within-mode tolerance %.6f. Either the HUD render became nondeterministic between "
              "processes or the mode under capture is not the blessed one."
              % (grid_path, d, spec["primary_mode"], tol), file=sys.stderr)
        rc = 1
    return rc


def check_stored_separation(directory=None):
    """Re-derive the between-mode separation FROM THE STORED GRIDS, with no game at all.

    This is the offline half of the scenario's own claim, and it is the strongest cheap check in
    the block: it does not ask the dump whether the modes differed, it MEASURES the stored frames
    again. A dump whose `separation` block was edited to claim a margin the frames do not carry
    fails here, because the grids are separate files the edit does not touch.
    """
    candidates = ([directory] if directory else
                  [os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
                   os.path.join(HERE, "pending", SCENARIO)])
    resolved = None
    for candidate in candidates:
        if candidate and os.path.isfile(os.path.join(candidate, "frame.grid")):
            resolved = candidate
            break
    if resolved is None:
        raise Refusal(
            "no directory with a frame.grid among %s. RESOLVING TO NOTHING IS A REFUSAL, never a "
            "pass: a check that silently succeeds when it found no artifact is the vacuous green "
            "this suite exists to prevent." % ", ".join(str(c) for c in candidates))
    spec = load_spec()
    tol = float(spec["within_mode_tolerance"])
    grids = {}
    for entry in spec["hud_modes"]:
        path = os.path.join(resolved, "frame-%s.grid" % entry["mode"])
        if not os.path.isfile(path):
            raise Refusal(
                "%s is missing; the stored per-mode grids are what make the separation claim "
                "re-derivable offline, and without all %d of them the margin can only be taken on "
                "the dump's word." % (path, len(spec["hud_modes"])))
        grids[entry["mode"]] = _read_grid(path)
    primary = _read_grid(os.path.join(resolved, "frame.grid"))
    primary_mode = spec["primary_mode"]

    pairs = pair_distances(grids)
    best = min(pairs, key=lambda p: p["distance"])
    primary_match = frame_hash.distance(primary, grids[primary_mode])
    floor, floor_source = _blessed_liveness_floor()
    report = {
        "directory": golden_run._slashes(resolved),
        "between_mode_distances": pairs,
        "best_between_mode_distance": best["distance"],
        "best_between_mode_pair": "%s vs %s" % (best["a"], best["b"]),
        "tolerance": tol,
        "ratio_to_tolerance": best["distance"] / tol if tol else None,
        "frame_grid_matches_primary_mode": primary_match,
        "primary_mode": primary_mode,
        "liveness": {m: liveness(g) for m, g in grids.items()},
        "liveness_floor": floor,
        "liveness_floor_from": floor_source or "FRAME_LIVENESS_FLOOR_FALLBACK",
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    rc = 0
    if best["distance"] <= tol:
        print("FAIL: the closest stored pair of different HUD modes (%s) differ by only %.6f, "
              "WITHIN the measured tolerance %.6f. The stored frames do not carry the separation "
              "the scenario claims." % (report["best_between_mode_pair"], best["distance"], tol),
              file=sys.stderr)
        rc = 1
    if primary_match != 0.0:
        print("FAIL: frame.grid is not the %r-mode grid (distance %.6f); the blessed frame and "
              "the blessed mode have drifted apart." % (primary_mode, primary_match),
              file=sys.stderr)
        rc = 1
    dead = {m: v for m, v in report["liveness"].items() if v < floor}
    if dead:
        print("FAIL: these stored grids are below the blessed liveness floor %.6f: %r"
              % (floor, dead), file=sys.stderr)
        rc = 1
    if rc == 0:
        print("PASS: the stored grids themselves separate the HUD modes - closest different-mode "
              "pair %s at %.6f, %.2fx the measured tolerance %.6f, every grid live above %.4f."
              % (report["best_between_mode_pair"], best["distance"],
                 best["distance"] / tol, tol, floor))
    return rc


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def stability(app_dir, spec, run_root, runs, keep=False):
    """N independent runs, reporting REFUSED and DIFFERED separately, capturing EVERY run.

    A REFUSAL (the harness declining to dump) is NOT a DIFFERENCE; collapsing the two is how a
    stability claim goes dishonest (bead oo-jor).
    """
    out_dir = os.path.join(run_root, "stability")
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for i in range(1, runs + 1):
        out = os.path.join(out_dir, "run%02d.json" % i)
        grid = os.path.join(out_dir, "run%02d.grid" % i)
        for stale in (out, grid):
            if os.path.exists(stale):
                os.remove(stale)
        started = time.time()
        record = {"run": i, "out": out}
        try:
            result = run(app_dir, out, spec, os.path.join(run_root, "runs"), keep=keep,
                         frame_out=grid)
            record["verdict"] = "DUMPED"
            ev = result["evidence"]
            record["best_between"] = ev["best_between_mode_distance"]
            record["worst_within"] = ev["worst_within_mode_distance"]
            record["separation_ratio"] = ev["separation_ratio"]
        except (ScenarioError, Refusal) as exc:
            record["verdict"] = "REFUSED"
            record["reason"] = "%s: %s" % (type(exc).__name__, exc)
        except Exception as exc:  # noqa: BLE001 - a crash is reported, never swallowed
            record["verdict"] = "ERROR"
            record["reason"] = "%s: %s" % (type(exc).__name__, exc)
        record["wall_seconds"] = round(time.time() - started, 1)
        if os.path.isfile(out):
            blob = open(out, "rb").read()
            record["bytes"] = len(blob)
            record["sha256"] = hashlib.sha256(blob).hexdigest()
        if os.path.isfile(grid):
            record["frame_sha256"] = hashlib.sha256(open(grid, "rb").read()).hexdigest()
        results.append(record)
        print(json.dumps(record))
        sys.stdout.flush()

    dumped = [r for r in results if "sha256" in r]
    digests = sorted({r["sha256"] for r in dumped})
    ratios = [r["separation_ratio"] for r in results if "separation_ratio" in r]
    summary = {
        "runs": runs,
        "dumps_written": len(dumped),
        "refused": len([r for r in results if r["verdict"] == "REFUSED"]),
        "errored": len([r for r in results if r["verdict"] == "ERROR"]),
        "distinct_dump_digests": digests,
        "distinct_frame_grid_digests": len({r["frame_sha256"] for r in results
                                            if "frame_sha256" in r}),
        "dump_bytes": sorted({r["bytes"] for r in dumped}),
        "best_between_min": min((r["best_between"] for r in results if "best_between" in r),
                                default=None),
        "worst_within_max": max((r["worst_within"] for r in results if "worst_within" in r),
                                default=None),
        "separation_ratio_min": min(ratios) if ratios else None,
        "separation_ratio_max": max(ratios) if ratios else None,
        "wall_seconds_min": min(r["wall_seconds"] for r in results),
        "wall_seconds_max": max(r["wall_seconds"] for r in results),
        "per_run": results,
    }
    if len(dumped) < 2:
        summary["WARNING"] = ("FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing "
                              "to compare and no stability claim can be made." % (len(dumped),
                                                                                  runs))
    # NOTE the dump carries MEASURED FLOAT DISTANCES, which are renderer output and are NOT
    # expected to be byte-stable across processes; `stable` therefore reports the digest count as
    # a FACT rather than requiring it to be 1. That is the honest reading for a rendering
    # scenario, and it is why the separation floor - not a digest - is this scenario's predicate.
    summary["dump_digest_count"] = len(digests)
    summary["separation_held_every_run"] = bool(dumped) and summary["refused"] == 0 \
        and summary["errored"] == 0
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary["separation_held_every_run"] and len(dumped) == runs else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/hud_render_modes.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None,
                        help="write the primary mode's 64x64 luminance grid here")
    parser.add_argument("--frame-out-dir", default=None,
                        help="write frame.grid, frame.png and one frame-<mode>.grid per mode here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--calibrate", type=int, default=0, metavar="REPEATS",
                        help="measure this scenario's OWN within-mode and between-mode "
                             "populations, REPEATS captures per mode, each from its own process")
    parser.add_argument("--calibration-out", default=None)
    parser.add_argument("--freeze-hud", action="store_true",
                        help="MUTANT ARM: capture every mode WITHOUT writing the HUD, so all "
                             "three renders are the same scene. The run must then FAIL its own "
                             "assertions; used to prove the gate goes red.")
    parser.add_argument("--check-evidence", default=None, metavar="DUMP",
                        help="offline: re-apply the HUD assertions to a stored dump")
    parser.add_argument("--label", default=None)
    parser.add_argument("--check-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    parser.add_argument("--check-stored-separation", nargs="?", const="", default=None,
                        metavar="DIR",
                        help="offline: re-derive the between-mode separation from the STORED "
                             "per-mode grids, with no game")
    args = parser.parse_args(argv)

    try:
        spec = load_spec()
        if args.check_evidence:
            return check_evidence(args.check_evidence, spec, args.label)
        if args.check_frame:
            return check_frame(args.check_frame[0], args.check_frame[1])
        if args.check_stored_separation is not None:
            return check_stored_separation(args.check_stored_separation or None)
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except ScenarioError as exc:
        sys.stderr.write("FAIL: %s\n" % exc)
        return 1

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 2
    ensure_launchable(app_dir)
    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_1bf7_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.calibrate:
        cal = calibrate(app_dir, spec, run_root, args.calibrate, keep=args.keep)
        if args.calibration_out:
            with open(args.calibration_out, "w", encoding="utf-8") as handle:
                json.dump(cal, handle, indent=2, sort_keys=True)
                handle.write("\n")
            print("wrote %s" % args.calibration_out)
        return 0 if cal["separated"] else 2

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, frame_out=args.frame_out,
                     frame_out_dir=args.frame_out_dir, freeze_hud=args.freeze_hud)
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except ScenarioError as exc:
        sys.stderr.write("SCENARIO FAILED: %s\n" % exc)
        return 1
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        sys.stderr.write("[!] %s: %s\n" % (type(exc).__name__, exc))
        return 3

    ev = result["evidence"]
    print("HUD MODES: %s in %s at %s - %d distinct grids; closest different-mode pair %s %.6f "
          "vs same-mode %.6f (%.2fx, tolerance %.6f); unknown plist refused; %d ticks (%.1fs wall)"
          % (ev["modes"], spec["system_name"], GUI_SCREEN_MAIN,
             ev["distinct_mode_grid_digests"], ev["best_between_mode_pair"],
             ev["best_between_mode_distance"], ev["worst_within_mode_distance"],
             ev["separation_ratio"], ev["within_mode_tolerance"], ev["ticks"],
             result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
