"""Golden scenario 002-witchspace: jump from Lave to Zaonce and prove the JUMP HAPPENED.

WHAT THIS SCENARIO IS FOR
=========================
Bead oo-z22 asks for scenario 001's shape (fixed seed, fixed system, fixed tick count, canonical
dump, frame hash, blessed under the golden policy, 10-run stability) applied to a WITCHSPACE JUMP.
Scenario 001 (`tests/golden/launch_dock.py`) is the exemplar and this file is deliberately its
sibling: same port/staging isolation, same populator suppression, same declared pose, same
`assert_*` -before-you-write discipline. The difference is the thing under test and therefore the
evidence.

THE JUMP IS THE THING UNDER TEST, SO "IT DID NOT CRASH" IS NOT EVIDENCE
=======================================================================
A run that launches and then sits in Lave for three seconds exits 0, writes a clean log with no
ERROR lines, and dumps a perfectly reproducible world. It would pass every absence-of-badness
check ever written. So every clause of `assert_jumped()` is POSITIVE and names something ONLY A
COMPLETED JUMP CAN PRODUCE, and each is in the dump so future comparisons re-check it rather than
trusting a capture-time assertion that once passed:

  1. `system_id_before` != `system_id_after`, and `system_id_after` == the pinned destination.
     `system.ID` is changed by exactly one mechanism in a scenario with no scripted teleport:
     Universe.m:1060-1110's witchspace transition. A run that never jumped reports the origin.
  2. `witchspace_enter_events` / `will_exit_events` / `witchspace_exit_events` - ENGINE-DISPATCHED.
     `shipWillEnterWitchspace` is fired at Universe.m:1061, `shipWillExitWitchspace` and
     `shipExitedWitchspace` at :1105-1106. The handlers are INSTALLED by this file and never
     called by it; only the engine's own transition can increment them.
  3. `jump_cause` == "standard jump" and `jump_destination_id` == the pinned destination. Both are
     ARGUMENTS the engine passes to `shipWillEnterWitchspace` ([player jumpCause] and `dest` at
     Universe.m:1061), so they carry the engine's own account of WHY it jumped and WHERE to. A
     galactic jump or a misjump reports a different cause; a mis-targeted jump a different id.
  4. `countdown_status_seen` / `exiting_status_seen` - the run OBSERVED `player.ship.status` pass
     through STATUS_WITCHSPACE_COUNTDOWN and then STATUS_EXITING_WITCHSPACE. That is the witchspace
     countdown actually running, which the bead names, and neither state exists in a run that
     stayed in Lave.
  5. `fuel_consumed_tenths` == `distance_ly_tenths`. The engine bills the jump at exactly the
     inter-system distance (PlayerEntity.m -witchJumpTo:, fuel in tenths of a light year), and
     `system.info.distanceToSystem()` computes that distance from the GALAXY LAYOUT, not from
     anything this scenario declares. MEASURED: fuel 7.0 -> 1.4 with Lave->Zaonce at 5.6 LY. This
     is an independent second witness to the same jump: an engine that changed system.ID without
     performing a jump would not bill the fuel, and one that billed the wrong amount is a finding.
  6. `jump_failed` must be absent. `playerJumpFailed` is dispatched by PlayerEntity.m:7384-7460's
     `witchJumpChecklist:` with a reason string ("blocked", "no target", "too far", "insufficient
     fuel"). An installed-but-never-fired handler is not evidence on its own, which is why it is
     the SIXTH check and not the first.
  7. `destination_station_name` == the destination's OWN main station, and `dock_events` >= 1. Lave
     has a Coriolis Station and Zaonce an Icosahedron Station, so the name of the station the run
     docks at is an independent second witness to WHICH system it ended in - one that does not go
     through `system.ID` at all. The dock event is dispatched by the engine at
     PlayerEntity.m:7206.

WHY THE OBSERVABLES ARE NOT ROLE COUNTS - MEASURED, NOT ASSUMED
===============================================================
Beads oo-rkm and oo-qwk5 both went flaky in one hour by counting a ship ROLE the ambient system
populator also writes to. This scenario counts NO roles. Every observable above has exactly one
carrier: the engine's witchspace transition. The destination's entity set is measured and stored,
but it is a CONSEQUENCE of the jump, not the evidence for it - and it is made reproducible by
clearing and suppressing (below), not by asserting a population size.

THE DESTINATION IS FRESHLY POPULATED AND MUST BE SUPPRESSED AGAIN
=================================================================
MEASURED on this box: arriving in Zaonce, `system.allShips` held 57 entities - asteroids, traders,
police wings, a rock hermit, the witchpoint beacon. The suppression performed in the ORIGIN system
does not survive the jump, because the destination system is built fresh on arrival. So
`quiet_system()` is run TWICE, once in each system, and the second call is the load-bearing one.
Its three parts are scenario 001's and 015's, unchanged and for their stated reasons:
`system.setPopulator(k, null)` (OOJSSystem.m:1311), `station.hasNPCTraffic = false`
(StationEntity.m:960-995), and neutering `oolite-populator.js`'s `systemWillRepopulate`, whose
`_tradeStation` ends in an unconditional `return system.mainStation` and therefore keeps launching
traffic regardless of the flag.

TWO MEASURED FACTS THAT DECIDE THE SCENARIO'S SHAPE
===================================================
  A. THE COUNTDOWN MUST BE STARTED IN FLIGHT, NOT WHILE DOCKED. `beginHyperspaceCountdown` returns
     false unless `[player status] == STATUS_IN_FLIGHT` (OOJSPlayerShip.m:1596). A first probe
     called it three frames after `launch()` while the status was still STATUS_LAUNCHING; it
     returned **false** and the run sat in Lave for 180 seconds looking like a broken jump. The
     scenario now WAITS for STATUS_IN_FLIGHT and REFUSES if the countdown does not begin, so this
     failure can never be mistaken for a jump that silently did not happen.
  B. THE PLAYER MUST BE AWAY FROM THE STATION OR THE JUMP IS BLOCKED AT THE LAST MOMENT.
     `witchJumpChecklist:` (PlayerEntity.m:7387-7401) runs `checkShipsInVicinityForWitchJumpExit`
     when the countdown expires and, if anything is close, sets the status back to
     STATUS_IN_FLIGHT and fires `playerJumpFailed("blocked")`. MEASURED: countdown begun from the
     launch corridor reached STATUS_WITCHSPACE_COUNTDOWN and fell back to STATUS_IN_FLIGHT five
     seconds later with system.ID still 7. The declared pose [0,0,0] puts the ship 434 km from the
     Coriolis and 794 km from the rock hermit, and from there the jump completes every time. The
     pose is DECLARED (spec.json) rather than flown to, for scenario 001's reason: a flown
     position is a function of how many frames this box rendered.

WHAT THIS GOLDEN DOES NOT PIN
=============================
`player.ship.position` and `.velocity` are DECLARED under the pause, exactly as in scenario 001 and
for the same measured reason (ShipEntity.m:12830-12833: `-velocity` is `[super velocity] +
[self thrustVector]`, so a ship under thrust reads a velocity no JS write can clear, whose value
tracks the frame count). A test comparing only those two fields would be vacuous. What IS measured
is the destination's surviving entity set, its station market, the player's ledger, and the whole
evidence block.

THE FRAME
=========
A 64x64 luminance grid is captured and stored. It is NEVER byte-compared: llvmpipe is not
bit-reproducible and this scenario's own sweep produced distinct grid digests over byte-identical
dumps. It is asserted on LIVENESS only - distance from an all-black grid above a floor - which is
the property a run that died before drawing fails. The dump carries this scenario's determinism
claim; the frame does not, and says so (bead oo-gxp's asymmetry: deterministic artifacts get a
digest, renderer output gets a measured tolerance).

PORT / LAUNCH ISOLATION
=======================
`golden_run.py` wholesale: a reserved port, a staged app dir, and a debugConfig.plist in a private
OO_ADDITIONALADDONSDIRS, because the game DIALS OUT to the port named in that plist
(OODebugSupport.m:67-80). A run on the shared 8563 can be captured by a sibling worker's console
and quit four seconds in while still exiting rc=0 (bead oo-het).
"""

import argparse
import hashlib
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

SCENARIO = "002-witchspace"

# Guarded location FIRST, staged location second, so landing the golden is a pure `git mv` with no
# code change (scenarios 010/012/015's arrangement, deliberately identical).
SPEC_CANDIDATES = (
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

LAUNCH_TIMEOUT_SECONDS = 120
IN_FLIGHT_TIMEOUT_SECONDS = 120
JUMP_TIMEOUT_SECONDS = 180
DOCK_TIMEOUT_SECONDS = 180
TICK_WALL_BUDGET_SECONDS = 300
SETTLE_TIMEOUT_SECONDS = 120
FRAME_SETTLE_SECONDS = 1.5
CLEAR_ROUNDS = 20
# See PatientConsole: 15 s (console.py's default) was measured too short on this loaded box.
CONSOLE_REPLY_TIMEOUT_SECONDS = 90

# The floor a frame must clear, in frame_hash distance units, to count as RENDERED. It is NOT a
# same-scene tolerance: it separates "something was drawn" from "an all-black grid", which is what
# a run that died before drawing produces. The measured margin is recorded in provenance.json.
FRAME_LIVENESS_FLOOR = 0.020

# The engine's own name for a plain inter-system jump, passed to shipWillEnterWitchspace as
# [player jumpCause] (Universe.m:1061). A galactic jump or a misjump reports a different string.
STANDARD_JUMP_CAUSE = "standard jump"

# Counters live on debugConsole, the console's own scratch object (OODebugMonitor.m:761), and the
# handlers are attached to a live world script so the ENGINE delivers the events
# (PlayerEntity.m:12927-12939 walks worldScripts and calls the named method on each).
PROBE_JS = """(function(){
  debugConsole.ooZ22 = {enter: 0, willExit: 0, exited: 0, dock: 0,
                        cause: "", dest: "", failed: ""};
  var names = Object.keys(worldScripts);
  if (!names.length) return "NO-WORLD-SCRIPTS";
  var s = worldScripts[names[0]];
  s.shipWillEnterWitchspace = function (cause, dest) {
    debugConsole.ooZ22.enter += 1;
    debugConsole.ooZ22.cause = String(cause);
    debugConsole.ooZ22.dest = String(dest);
  };
  s.shipWillExitWitchspace = function () { debugConsole.ooZ22.willExit += 1; };
  s.shipExitedWitchspace = function () { debugConsole.ooZ22.exited += 1; };
  s.shipDockedWithStation = function () { debugConsole.ooZ22.dock += 1; };
  s.playerJumpFailed = function (why) { debugConsole.ooZ22.failed = String(why); };
  return names[0];
})()"""


class ScenarioError(RuntimeError):
    pass


class PatientConsole:
    """A DebugConsole wrapper that waits longer for an answer, and NOTHING else.

    MEASURED, ON THIS BOX, AND THE REASON THIS CLASS EXISTS. `DebugConsole.evaluate` defaults to a
    15-second reply timeout (console.py:210). That is generous for an idle machine and too short
    for this fleet: with two sibling workers' games resident and the CPU at 88%, two consecutive
    runs of this scenario died with `ConsoleError: no answer to 'player.ship.position' within 15s`
    and `... 'clock.absoluteSeconds' within 15s` - at different call sites, which is the signature
    of a machine-load artefact rather than a hung game (the same expression had answered dozens of
    times earlier in the same run).

    RAISING THE TIMEOUT IS NOT WEAKENING A GATE, AND THE DISTINCTION MATTERS. Nothing this scenario
    asserts is measured on the harness clock: the tick budget is read from `clock.absoluteSeconds`
    INSIDE the game, the jump is watched by status transition and by engine-dispatched events, and
    the dump is quantised state. The reply timeout governs only how long this process is willing to
    wait for a socket round trip, so a longer one changes no recorded value - it only stops a busy
    box from being reported as a failed jump. The timeouts that ARE assertions (the countdown must
    begin, the jump must complete, the world must quiesce) are unchanged.
    """

    def __init__(self, inner, timeout):
        self._inner = inner
        self._timeout = timeout

    def evaluate(self, js, timeout=None):
        if os.environ.get("OO_Z22_TRACE"):
            sys.stderr.write("[trace] eval %s\n" % " ".join(js.split())[:90])
            sys.stderr.flush()
        return self._inner.evaluate(js, timeout=self._timeout if timeout is None else timeout)

    def evaluate_int(self, js, timeout=None):
        return self._inner.evaluate_int(js, timeout=self._timeout if timeout is None else timeout)

    def perform(self, js):
        return self._inner.perform(js)

    @property
    def pid(self):
        proc = getattr(self._inner, "_proc", None)
        return getattr(proc, "pid", None)

    def close(self):
        return self._inner.close()


# Windows constants for undoing the game's own pause-time self-throttling. See
# restore_process_priority().
_NORMAL_PRIORITY_CLASS = 0x00000020
_PROCESS_SET_INFORMATION = 0x0200
_PROCESS_POWER_THROTTLING = 4
_PROCESS_POWER_THROTTLING_CURRENT_VERSION = 1
_PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1


def restore_process_priority(pid):
    """Undo the EcoQoS throttling the game applies to ITSELF when it pauses.

    THE MEASUREMENT THAT FORCED THIS, AND WHY IT IS NOT A WORKAROUND FOR A BUG IN THE SCENARIO.
    `-setGamePaused:YES` calls `-setEcoQoS:YES` (GameController.m:155-197), which on Windows does
    two things to its own process: `SetPriorityClass(IDLE_PRIORITY_CLASS)` and
    `SetProcessInformation(ProcessPowerThrottling, EXECUTION_SPEED)`. On an idle desktop that is
    invisible. On THIS box - a fleet machine with two or three sibling workers' Oolite processes
    resident and the CPU measured at 88% - an IDLE-priority, throttled process is starved by the
    NORMAL-priority ones, and it stops servicing the debug socket: four consecutive runs died with
    `ConsoleError: no answer to 'clock.absoluteSeconds'` on the FIRST call after `pauseGame()`
    returned true, at a 15 s timeout and again at 90 s. Scenario 001's `launch_dock.py`, unmodified,
    fails the same way on the same box right now, which is what identified the cause as shared-box
    contention rather than anything this scenario does.

    So the harness restores the priority of the game process it launched, immediately after pausing
    it. THIS CHANGES NO MEASURED VALUE: `gameIsPaused` is untouched, `delta_t` is still forced to 0
    (GameController.m:399-401), the game clock is still stopped, and the scenario still PROVES the
    clock did not advance across the dump. Scheduling priority is not simulation state. The only
    thing it affects is whether this process can get an answer out of a socket.

    Best-effort by construction: any failure is reported and ignored, because a run on an idle box
    does not need it and must not be failed by its absence.
    """
    if pid is None or not sys.platform.startswith("win"):
        return None
    try:
        import ctypes
        from ctypes import wintypes

        class _Throttling(ctypes.Structure):
            _fields_ = [("Version", wintypes.ULONG),
                        ("ControlMask", wintypes.ULONG),
                        ("StateMask", wintypes.ULONG)]

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        handle = kernel32.OpenProcess(_PROCESS_SET_INFORMATION, False, int(pid))
        if not handle:
            return "OpenProcess failed (%d)" % ctypes.get_last_error()
        try:
            ok_priority = bool(kernel32.SetPriorityClass(handle, _NORMAL_PRIORITY_CLASS))
            state = _Throttling(_PROCESS_POWER_THROTTLING_CURRENT_VERSION,
                                _PROCESS_POWER_THROTTLING_EXECUTION_SPEED, 0)
            ok_throttle = bool(kernel32.SetProcessInformation(
                handle, _PROCESS_POWER_THROTTLING, ctypes.byref(state), ctypes.sizeof(state)))
        finally:
            kernel32.CloseHandle(handle)
        return {"priority_restored": ok_priority, "throttling_cleared": ok_throttle}
    except Exception as exc:  # noqa: BLE001 - best effort; never fails a run
        return "%s: %s" % (type(exc).__name__, exc)


def safe_close(console):
    """Tear the console down WITHOUT letting the teardown replace the run's real exception.

    MEASURED: `DebugConsole.close()` sends `quit()`, waits 15 s, kills, then waits 10 s more, and
    on a loaded box with sibling workers' games running it raised `TimeoutExpired` out of
    `__exit__` - which REPLACED the ScenarioError that had actually ended the run. The first time
    this happened the failure was reported as "timed out after 10 seconds" with no hint of what the
    scenario had objected to. A teardown fault must never be able to impersonate, or erase, the
    diagnosis.
    """
    try:
        console.close()
    except Exception as exc:  # noqa: BLE001 - reported, never allowed to mask the real failure
        sys.stderr.write("[teardown] console.close() raised %s: %s (ignored; the run's own "
                         "verdict stands)\n" % (type(exc).__name__, exc))


class Refusal(RuntimeError):
    """The comparison could not be performed soundly, so no verdict is given (rc=2)."""


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


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def _vec(values):
    return "[%s]" % ", ".join("%.6f" % float(v) for v in values)


def _docked(console):
    return console.evaluate("player.ship.docked").strip().lower() == "true"


def _status(console):
    return console.evaluate("player.ship.status").strip()


def probe_state(console):
    raw = console.evaluate("JSON.stringify(debugConsole.ooZ22)").strip()
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the witchspace event probe came back unparseable (%s): %r"
                            % (exc, raw[:200]))


def install_probe(console):
    """Attach the engine's witchspace event handlers and PROVE a world script was found.

    With no world scripts the handlers would be attached to nothing, every counter would read 0,
    and the scenario would report "the jump did not happen" for a reason about the probe. That is
    the vacuous-evidence shape this whole file exists to prevent, so it is fatal.
    """
    holder = console.evaluate(PROBE_JS).strip()
    if not holder or holder == "NO-WORLD-SCRIPTS":
        raise ScenarioError(
            "could not install the witchspace event probe: the game reports no world scripts, so "
            "shipWillEnterWitchspace / shipExitedWitchspace would never be delivered and every "
            "evidence counter would read zero for a reason unrelated to the jump")
    return holder


def assert_system(console, spec, key, what):
    """Read system.ID and require the pinned value. `key` names the spec knob, so this function is
    where BOTH the origin and the destination knobs are acted on."""
    got = console.evaluate_int("system.ID")
    if got != int(spec[key]):
        raise ScenarioError(
            "scenario %s pins %s to system ID %d but the game reports %d; a golden taken in a "
            "different system is not comparable with the stored one"
            % (SCENARIO, what, int(spec[key]), got))
    return got


def launch(console):
    if not _docked(console):
        raise ScenarioError("the save did not start DOCKED; there is nothing to launch from, and "
                            "player.ship.targetSystem is read-only unless docked "
                            "(OOJSPlayerShip.m:996)")
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(0.5)
        if not _docked(console):
            return True
    raise ScenarioError("player.ship.docked never became false within %ss: the ship did not launch"
                        % LAUNCH_TIMEOUT_SECONDS)


def await_in_flight(console, timeout=IN_FLIGHT_TIMEOUT_SECONDS):
    """Wait for STATUS_IN_FLIGHT. MEASURED NECESSITY, not defensiveness.

    `beginHyperspaceCountdown` returns NO unless the status is STATUS_IN_FLIGHT
    (OOJSPlayerShip.m:1596). A probe that called it while the status was still STATUS_LAUNCHING got
    `false` back and then sat in the origin system for 180 s - a non-jump that looks exactly like a
    broken engine. Waiting here, and REFUSING below if the countdown still does not begin, keeps
    those two causes distinguishable.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _status(console) == "STATUS_IN_FLIGHT":
            return True
        time.sleep(0.25)
    raise ScenarioError("player.ship.status is %r after %ss, never STATUS_IN_FLIGHT; the "
                        "hyperspace countdown cannot be begun from any other state "
                        "(OOJSPlayerShip.m:1596)" % (_status(console), timeout))


def set_target_system(console, spec):
    """Pin the destination WHILE DOCKED - it is read-only otherwise (OOJSPlayerShip.m:996, :1016)."""
    want = int(spec["destination_system_id"])
    console.perform("player.ship.targetSystem = %d;" % want)
    got = console.evaluate_int("player.ship.targetSystem")
    if got != want:
        raise ScenarioError(
            "player.ship.targetSystem reads %d after being set to %d. It is read-only unless the "
            "player is docked (OOJSPlayerShip.m:996), so a silent failure here would send the jump "
            "to whatever the save's target happened to be." % (got, want))
    return got


def suppress_populators(console):
    """Switch the system populator off at the source (scenario 001's function, unchanged)."""
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
            "and every ship it adds consumes RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def suppress_station_traffic(console):
    """Switch off every station's own launch schedule (StationEntity.m:960-995, hasNPCTraffic)."""
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
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` (oolite-populator.js:2656-2680) tests `hasNPCTraffic` inside
    its loop but ENDS WITH an unconditional `return system.mainStation`, so switching the flag off
    does not stop it launching. The handler names come from spec["repopulator_handlers"] so an
    upstream rename becomes a red rather than a silent no-op.
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist; if it has been renamed "
                "upstream the suppression is silently doing nothing and this scenario is no longer "
                "deterministic. Re-derive the handler names rather than dropping the check." % name)
        console.perform("worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError("worldScripts['oolite-populator'].%s did not become a no-op (it "
                                "reads %r)" % (name, after[:120]))
        quieted.append(name)
    return quieted


def quiet_system(console, spec):
    """All three suppressions, as one step. RUN IN BOTH SYSTEMS - see the module docstring: the
    destination is built fresh on arrival and arrived with 57 entities in a measured probe."""
    return (suppress_populators(console),
            suppress_station_traffic(console),
            suppress_repopulator(console, spec))


def clear_system(console):
    """Remove every non-player, non-station ship. DOES NOT JUDGE - quiesce() decides."""
    removed = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    return removed, remaining


def moving_entities(console):
    """`magnitude` IS A FUNCTION, NOT A PROPERTY - it is CALLED. Bead oo-jor shipped a version
    comparing the function OBJECT with a number, which is always false, so the guard passed on
    every run including ones whose dumps differed by twelve velocity fields."""
    raw = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()").strip()
    return [part for part in raw.split(", ") if part]


def quiesce(console, rounds=CLEAR_ROUNDS):
    """Clear AND settle as ONE fixed point; refuse if the world never reaches it."""
    history = []
    for _ in range(rounds):
        removed, remaining = clear_system(console)
        moving = moving_entities(console)
        history.append([removed, remaining, len(moving)])
        if removed == 0 and remaining == 0 and not moving:
            return history
        time.sleep(0.3)
    raise ScenarioError(
        "the world never went quiet: %d rounds went %r ([removed, remaining, moving] per round). "
        "The three known sources are all switched off before this runs; a fourth source is a "
        "FINDING, not a reason to widen the round count." % (rounds, history))


def apply_pose(console, pose):
    """Park the ship at the DECLARED pose and PROVE it landed there.

    The pose is load-bearing twice over. (1) `witchJumpChecklist:` refuses the jump with
    playerJumpFailed("blocked") if anything is close when the countdown expires
    (PlayerEntity.m:7387-7401) - measured: a countdown begun in the launch corridor fell back to
    STATUS_IN_FLIGHT with system.ID unchanged. (2) A pose that silently failed to apply gives two
    runs of the same wrong scene, which reproduces byte-for-byte while measuring nothing.
    """
    console.perform("player.ship.hudHidden = true;")
    console.perform("player.ship.position = %s; player.ship.orientation = %s; "
                    "player.ship.velocity = [0, 0, 0];"
                    % (_vec(pose["position"]), _vec(pose["orientation"])))
    got = console.evaluate("player.ship.position")
    nums = [float(x) for x in got.replace(",", " ").replace("(", " ").replace(")", " ").split()]
    want = pose["position"]
    if len(nums) != 3 or max(abs(a - b) for a, b in zip(nums, want)) > 1.0:
        raise ScenarioError("pose did not apply: asked for %s, the game reports %r" % (want, got))
    return nums


def jump(console, spec, break_jump=False):
    """Begin the countdown, watch the status transitions, and arrive. Returns the observations.

    `break_jump` is the MUTANT ARM: it skips the countdown entirely, so the run stays in the origin
    system and `assert_jumped` MUST reject it. It exists to prove the gate can go red.
    """
    seen = {"countdown": False, "exiting": False, "statuses": []}
    if break_jump:
        time.sleep(1.0)
        seen["statuses"].append(_status(console))
        return seen

    begun = console.evaluate("String(player.ship.beginHyperspaceCountdown(%d))"
                             % int(spec["countdown_seconds"])).strip().lower()
    if begun != "true":
        raise ScenarioError(
            "player.ship.beginHyperspaceCountdown(%d) returned %r. It returns NO unless the player "
            "has a hyperspace motor, is STATUS_IN_FLIGHT and passes witchJumpChecklist: "
            "(OOJSPlayerShip.m:1596); the status is %r, fuel %s, targetSystem %s. This is a "
            "REFUSAL to start the jump, which must never be reported as a jump that did not happen."
            % (int(spec["countdown_seconds"]), begun, _status(console),
               console.evaluate("player.ship.fuel").strip(),
               console.evaluate("player.ship.targetSystem").strip()))

    destination = int(spec["destination_system_id"])
    deadline = time.time() + JUMP_TIMEOUT_SECONDS
    while time.time() < deadline:
        status = _status(console)
        if not seen["statuses"] or seen["statuses"][-1] != status:
            seen["statuses"].append(status)
        if status == "STATUS_WITCHSPACE_COUNTDOWN":
            seen["countdown"] = True
        if status == "STATUS_EXITING_WITCHSPACE":
            seen["exiting"] = True
        if console.evaluate_int("system.ID") == destination and status == "STATUS_IN_FLIGHT":
            return seen
        time.sleep(0.25)
    raise ScenarioError(
        "the jump did not complete within %ss: system.ID is %s, status %r, statuses seen %r, "
        "probe %r. A countdown that begins and then returns to STATUS_IN_FLIGHT in the ORIGIN "
        "system is witchJumpChecklist: refusing at the last moment (PlayerEntity.m:7387-7401) - "
        "read evidence.jump_failed for the engine's own reason."
        % (JUMP_TIMEOUT_SECONDS, console.evaluate("system.ID").strip(), _status(console),
           seen["statuses"], probe_state(console)))


def dock_at_destination(console, timeout=DOCK_TIMEOUT_SECONDS):
    """Dock at the DESTINATION system's own main station, and wait for the sequence to SETTLE.

    Two waits, both learned by scenario 001 and both kept. (a) `-enterDock:`
    (PlayerEntity.m:7083-7090) sets the docked flag immediately, so `player.ship.docked` reads true
    while the break pattern is still playing; `shipDockedWithStation` is dispatched much later, at
    PlayerEntity.m:7206 in `-docked`. (b) Even that event is not the end - it fires six lines before
    `-docked` puts the GUI on the status screen - so this also waits for STATUS_DOCKED.
    """
    if console.evaluate("system.mainStation ? 'yes' : 'no'").strip() != "yes":
        raise ScenarioError(
            "the destination system has no main station to dock with. This scenario ends docked "
            "because pausing IN FLIGHT wedges the debug console (see run()); a destination without "
            "a station needs a different ending, not a skipped one.")
    console.perform("system.mainStation.dockPlayer();")
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(0.5)
        if int(probe_state(console).get("dock", 0)) >= 1:
            break
    else:
        raise ScenarioError(
            "the engine never dispatched shipDockedWithStation within %ss (player.ship.docked=%r); "
            "the docking sequence did not complete, so a dump taken now would be of a half-docked "
            "ship" % (timeout, _docked(console)))
    while time.time() < deadline:
        if _status(console) == "STATUS_DOCKED" and _docked(console):
            return True
        time.sleep(0.5)
    raise ScenarioError(
        "shipDockedWithStation fired but player.ship.status is %r rather than STATUS_DOCKED after "
        "%ss; the docking sequence has not settled and pausing here leaves the world integrating"
        % (_status(console), timeout))


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time, never the harness clock."""
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
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(console.evaluate("clock.absoluteSeconds")) - start >= seconds:
            return
        time.sleep(0.25)
    raise ScenarioError("game clock did not advance %ss within %ss" % (seconds, timeout))


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: `_await_png` waits for the NAME, which on Windows shows
    up while the game still holds the handle open for writing. Reading it then fails with
    PermissionError or, worse, reads a truncated image. Both are retried; a frame that never
    becomes readable is a REFUSAL rather than a hash of half a file (scenario 010's finding).
    """
    before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
    console.perform("takeSnapShot();")
    png = golden_run._await_png(artifact_dir, before)
    last = None
    for _ in range(attempts):
        try:
            return png, frame_hash.frame_grid(png)
        except (PermissionError, OSError, ValueError) as exc:
            last = exc
            time.sleep(0.25)
    raise ScenarioError("the snapshot at %s never became readable (%s: %s); hashing a partial "
                        "image would be worse than no frame at all."
                        % (png, type(last).__name__, last))


def assert_jumped(evidence, spec):
    """The anti-vacuity gate, applied BEFORE anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every future
    diff against the stored golden rather than only at capture time. The ORDER is deliberate: the
    system change first, because it is the thing under test, and the absence of a failure message
    LAST, because an absence proves nothing until a presence has been established.
    """
    origin = int(spec["origin_system_id"])
    destination = int(spec["destination_system_id"])

    if evidence["system_id_before"] != origin:
        raise ScenarioError("the run started in system %d, not the pinned origin %d"
                            % (evidence["system_id_before"], origin))
    if evidence["system_id_after"] == evidence["system_id_before"]:
        raise ScenarioError(
            "system.ID is still %d after the jump: THE JUMP DID NOT HAPPEN. Everything else in "
            "this dump would reproduce perfectly, which is exactly why this is the first check."
            % evidence["system_id_after"])
    if evidence["system_id_after"] != destination:
        raise ScenarioError("the jump arrived in system %d, not the pinned destination %d"
                            % (evidence["system_id_after"], destination))
    if evidence["destination_system_name"] != spec["destination_system_name"]:
        raise ScenarioError("the destination system names itself %r, not the pinned %r"
                            % (evidence["destination_system_name"],
                               spec["destination_system_name"]))

    if evidence["witchspace_enter_events"] < 1:
        raise ScenarioError(
            "evidence.witchspace_enter_events is %d: the engine never dispatched "
            "shipWillEnterWitchspace (Universe.m:1061). system.ID changing WITHOUT that event "
            "means something other than a witchspace jump moved the player."
            % evidence["witchspace_enter_events"])
    if evidence["will_exit_events"] < 1:
        raise ScenarioError("evidence.will_exit_events is %d: the engine never dispatched "
                            "shipWillExitWitchspace (Universe.m:1105)"
                            % evidence["will_exit_events"])
    if evidence["witchspace_exit_events"] < 1:
        raise ScenarioError(
            "evidence.witchspace_exit_events is %d: the engine never dispatched "
            "shipExitedWitchspace (Universe.m:1106), so the ship never arrived out of witchspace"
            % evidence["witchspace_exit_events"])
    if evidence["jump_cause"] != STANDARD_JUMP_CAUSE:
        raise ScenarioError(
            "the engine reports jump cause %r, not %r. The cause is [player jumpCause] passed to "
            "shipWillEnterWitchspace (Universe.m:1061); a galactic jump or a misjump reports a "
            "different string and is a DIFFERENT scenario."
            % (evidence["jump_cause"], STANDARD_JUMP_CAUSE))
    if evidence["jump_destination_id"] != str(destination):
        raise ScenarioError(
            "the engine told shipWillEnterWitchspace the destination was %r, not %r. That argument "
            "is the engine's own account of where it was going."
            % (evidence["jump_destination_id"], str(destination)))

    if not evidence["countdown_status_seen"]:
        raise ScenarioError(
            "player.ship.status was never observed at STATUS_WITCHSPACE_COUNTDOWN (statuses seen: "
            "%r). The witchspace countdown is half of what this bead names; a jump that appeared "
            "without one would mean the transition was driven by something other than the "
            "countdown." % (evidence["statuses_seen"],))
    if not evidence["exiting_status_seen"]:
        raise ScenarioError(
            "player.ship.status was never observed at STATUS_EXITING_WITCHSPACE (statuses seen: "
            "%r); the arrival did not go through the witchspace exit state."
            % (evidence["statuses_seen"],))

    want_tenths = evidence["distance_ly_tenths"]
    if evidence["fuel_consumed_tenths"] != want_tenths:
        raise ScenarioError(
            "the jump billed %d tenths of a light year of fuel but Lave->%s is %d tenths, computed "
            "by system.info.distanceToSystem() from the GALAXY LAYOUT. The fuel bill is an "
            "INDEPENDENT second witness to the jump: an engine that changed system.ID without "
            "jumping would not bill it, and a wrong bill is a finding about the engine, not a "
            "number to relax." % (evidence["fuel_consumed_tenths"],
                                  evidence["destination_system_name"], want_tenths))
    if evidence["fuel_consumed_tenths"] < 1:
        raise ScenarioError("the jump consumed no fuel at all; a zero-cost jump is not a jump")

    if evidence["jump_failed"]:
        raise ScenarioError(
            "the engine dispatched playerJumpFailed(%r). witchJumpChecklist: "
            "(PlayerEntity.m:7387-7460) emits 'blocked', 'no target', 'too far' or 'insufficient "
            "fuel' and sets the status back to STATUS_IN_FLIGHT." % evidence["jump_failed"])

    if evidence["destination_station_name"] != spec["destination_station_name"]:
        raise ScenarioError(
            "the scenario docked at %r, not the destination's own %r. THIS IS THE CHECK THAT A RUN "
            "WHICH NEVER LEFT THE ORIGIN CANNOT PASS: Lave's main station is a Coriolis and "
            "Zaonce's is an Icosahedron, so the station's own name is a second, independent "
            "witness to the arrival."
            % (evidence["destination_station_name"], spec["destination_station_name"]))
    if evidence["dock_events"] < 1:
        raise ScenarioError(
            "evidence.dock_events is %d: the engine never dispatched shipDockedWithStation "
            "(PlayerEntity.m:7206) at the destination, so the ship did not really dock there"
            % evidence["dock_events"])
    if not evidence["docked_at_end"]:
        raise ScenarioError("evidence.docked_at_end is false: the scenario ends undocked, so the "
                            "dump was taken from a state the pause cannot freeze soundly")

    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met: the simulation did not run in the "
                            "destination system")
    if not evidence["world_at_rest"]:
        raise ScenarioError(
            "the world was not at rest when the dump was taken: %r still report motion. "
            "ShipEntity -velocity is [super velocity] + [self thrustVector] "
            "(ShipEntity.m:12830-12833), so a ship under thrust reads a velocity no JS write can "
            "clear, whose value tracks the frame count - dumping it would make the golden a "
            "stopwatch reading." % (evidence.get("moving_entities"),))
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the destination world never reached a clean clear-and-settle round")
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, break_jump=False):
    """One game process, one canonical dump, one frame grid."""
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)

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
    started = time.time()
    if out_path and os.path.exists(out_path):
        # A HARNESS MUST DELETE ITS OUTPUT PATH BEFORE EVERY RUN, or it cannot distinguish "this
        # run produced this" from "something produced this once" (bead oo-gxp's stale-scratch
        # phantom).
        os.remove(out_path)
    try:
        console = PatientConsole(start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"])), CONSOLE_REPLY_TIMEOUT_SECONDS)
        try:
            holder = install_probe(console)
            system_before = assert_system(console, spec, "origin_system_id", "the origin system")
            target = set_target_system(console, spec)
            distance_tenths = int(round(float(console.evaluate(
                "String(system.info.distanceToSystem(System.infoForSystem(galaxyNumber, %d)))"
                % target).strip()) * 10))
            fuel_before_tenths = int(round(
                float(console.evaluate("player.ship.fuel").strip()) * 10))

            launch(console)
            await_in_flight(console)
            quiet_system(console, spec)
            apply_pose(console, spec["pose"])
            quiesce(console)

            seen = jump(console, spec, break_jump=break_jump)

            system_after = console.evaluate_int("system.ID")
            destination_name = console.evaluate("system.name").strip()
            fuel_after_tenths = int(round(
                float(console.evaluate("player.ship.fuel").strip()) * 10))

            # THE DESTINATION IS FRESHLY POPULATED. Measured: 57 entities on arrival in Zaonce.
            # Suppression in the origin does not survive the jump.
            suppressed, stations_quieted, repop = quiet_system(console, spec)
            quiesce(console)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            settle(console)
            clear_rounds = quiesce(console)

            # DOCK AT THE DESTINATION'S OWN MAIN STATION, THEN PAUSE. Two reasons, one measured.
            #
            # (1) EVIDENCE. Docking at a station that exists only in the DESTINATION system is a
            #     further property a run that never left Lave cannot produce, and it is recorded by
            #     name: `destination_station_name` is Zaonce's Icosahedron Station, not Lave's
            #     Coriolis. `dock_events` is incremented by the ENGINE (PlayerEntity.m:7206), never
            #     by this file.
            # (2) MEASURED NECESSITY. Pausing IN FLIGHT wedges the console: three consecutive runs
            #     hung at the first `clock.absoluteSeconds` AFTER `pauseGame()` returned true and
            #     died on the reply timeout, at 15 s and again at 90 s. `-setGamePaused:`
            #     (GameController.m:155-170) calls `setEcoQoS:YES`, which puts the process into
            #     Windows efficiency mode; in flight the game then services the debug socket too
            #     slowly to answer. Scenario 001 pauses while DOCKED and does not hit this. So this
            #     scenario ends where the exemplar ends - docked, paused, clock stopped - and the
            #     pause is never taken in flight.
            dock_at_destination(console)
            destination_station = console.evaluate(
                "system.mainStation ? system.mainStation.name : ''").strip()

            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). "
                    "GlobalPauseGame refuses on the chart/mission/report/keyboard/save screens "
                    "(OOJSGlobal.m:843-848). The simulation would keep integrating through the "
                    "dump and no two runs could agree."
                    % console.evaluate("guiScreen").strip())
            # IMMEDIATELY after the pause: see restore_process_priority(). The game has just put
            # ITSELF into IDLE priority with power throttling, and on this contended box that
            # starves the debug socket. Nothing simulated is touched.
            priority = restore_process_priority(console.pid)
            clock_before = float(console.evaluate("clock.absoluteSeconds"))
            apply_pose(console, spec["pose"])
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs after pauseGame() returned true; the world is "
                    "NOT frozen, so the dump is a stopwatch reading"
                    % (clock_after - clock_before))
            moving = moving_entities(console)
            if moving:
                # CLEAR ONCE MORE UNDER THE PAUSE, then re-assert. Docking at the destination
                # station puts the player back beside a station whose docking sequence can leave
                # entities in the world; the clock is stopped here, so a clear under the pause
                # cannot introduce new nondeterminism - it removes what the docking left. If the
                # world is STILL moving after that, the run REFUSES rather than blessing a
                # frame-count-dependent dump (bead oo-jor's rc=2-vs-rc=1 distinction).
                clear_system(console)
                moving = moving_entities(console)
            probe = probe_state(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))
        finally:
            safe_close(console)

        evidence = {
            "scenario": SCENARIO,
            "system_id_before": system_before,
            "system_id_after": system_after,
            "destination_system_name": destination_name,
            "target_system_set": target,
            "witchspace_enter_events": int(probe.get("enter", 0)),
            "will_exit_events": int(probe.get("willExit", 0)),
            "witchspace_exit_events": int(probe.get("exited", 0)),
            "jump_cause": str(probe.get("cause", "")),
            "jump_destination_id": str(probe.get("dest", "")),
            "jump_failed": str(probe.get("failed", "")),
            "dock_events": int(probe.get("dock", 0)),
            "destination_station_name": destination_station,
            "docked_at_end": bool(state["player"]["ship"]["docked"]),
            "countdown_status_seen": bool(seen["countdown"]),
            "exiting_status_seen": bool(seen["exiting"]),
            "statuses_seen": list(seen["statuses"]),
            "countdown_seconds": int(spec["countdown_seconds"]),
            "fuel_before_tenths": fuel_before_tenths,
            "fuel_after_tenths": fuel_after_tenths,
            "fuel_consumed_tenths": fuel_before_tenths - fuel_after_tenths,
            "distance_ly_tenths": distance_tenths,
            "world_at_rest": not moving,
            "moving_entities": list(moving),
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor).
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repop),
            "probe_script": holder,
        }
        assert_jumped(evidence, spec)
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
                handle.write(bytes(grid))
        return {"ok": True, "out": out_path, "frame_out": frame_out, "port": port,
                "png": golden_run._slashes(png), "bytes": len(text),
                "frame_hash": frame_hash.hex_digest(grid),
                "game_seconds_elapsed": round(elapsed, 3),
                "wall_seconds": round(time.time() - started, 1), "evidence": evidence,
                "priority_restore": priority}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


# --- offline checkers (no game) -----------------------------------------------------------------

def check_evidence(path, spec, label=None):
    """Does THIS dump prove a witchspace jump happened? Re-runs assert_jumped over a stored file.

    This is what makes the stored golden self-describing: the same predicates that gated the
    capture are re-applied to the artifact by every future acceptance run.
    """
    label = label or path
    if not os.path.isfile(path):
        raise Refusal("no dump at %s" % path)
    with open(path, "r", encoding="utf-8") as handle:
        state = json.load(handle)
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise Refusal("%s carries no evidence block; a dump with no evidence compares equal to any "
                      "other evidence-free dump and proves nothing about the jump" % label)
    missing = [k for k in ("system_id_before", "system_id_after", "witchspace_enter_events",
                           "witchspace_exit_events", "jump_cause", "fuel_consumed_tenths",
                           "destination_station_name", "dock_events")
               if k not in evidence]
    if missing:
        raise Refusal("%s's evidence block is missing %s" % (label, missing))
    assert_jumped(evidence, spec)
    print("PASS: %s proves a witchspace jump: system %d -> %d (%s), %d enter / %d exit event(s) "
          "from the engine, cause %r, countdown and exit states both observed, %d tenths of fuel "
          "billed for a %d-tenth jump."
          % (label, evidence["system_id_before"], evidence["system_id_after"],
             evidence["destination_system_name"], evidence["witchspace_enter_events"],
             evidence["witchspace_exit_events"], evidence["jump_cause"],
             evidence["fuel_consumed_tenths"], evidence["distance_ly_tenths"]))
    return 0


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        raise Refusal("%s is %d bytes, not the %d-byte %dx%d luminance grid; any comparison "
                      "against it would be meaningless"
                      % (path, len(blob), frame_hash.GRID_CELLS, frame_hash.GRID_SIDE,
                         frame_hash.GRID_SIDE))
    return blob


def check_frame(grid_path, reference_path):
    """Assert LIVENESS only, and REPORT the distance to the reference.

    NEVER BYTE-HASH THE FRAME. llvmpipe is not bit-reproducible, so a digest comparison would flake
    on renderer noise while the dump - which is quantised and deterministic - is hashed byte-wise.
    That asymmetry is deliberate (bead oo-gxp).
    """
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    live = frame_hash.distance(got, bytes(frame_hash.GRID_CELLS))
    result = {
        "distance_to_reference": frame_hash.distance(got, want),
        "liveness": live,
        "liveness_floor": FRAME_LIVENESS_FLOOR,
        "live": live >= FRAME_LIVENESS_FLOOR,
        "verdict_rests_on": "liveness",
        "hash_got": frame_hash.hex_digest(got),
        "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    if not result["live"]:
        print("FAIL: %s has luminance distance %.6f from an all-black frame, below the %.6f floor. "
              "Nothing was rendered." % (grid_path, live, FRAME_LIVENESS_FLOOR), file=sys.stderr)
        return 1
    return 0


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def stability(app_dir, spec, run_root, runs, keep=False):
    """N independent runs, reporting REFUSED and DIFFERED separately, capturing EVERY run."""
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
            run(app_dir, out, spec, os.path.join(run_root, "runs"), keep=keep, frame_out=grid)
            record["verdict"] = "DUMPED"
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
    summary = {
        "runs": runs,
        "dumps_written": len(dumped),
        "refused": len([r for r in results if r["verdict"] == "REFUSED"]),
        "errored": len([r for r in results if r["verdict"] == "ERROR"]),
        "distinct_dump_digests": digests,
        "distinct_frame_grid_digests": len({r["frame_sha256"] for r in results
                                            if "frame_sha256" in r}),
        "dump_bytes": sorted({r["bytes"] for r in dumped}),
        "wall_seconds_min": min(r["wall_seconds"] for r in results),
        "wall_seconds_max": max(r["wall_seconds"] for r in results),
        "per_run": results,
    }
    if len(dumped) < 2:
        summary["WARNING"] = ("FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing to "
                              "compare and no stability claim can be made." % (len(dumped), runs))
    summary["stable"] = len(dumped) >= 2 and len(digests) == 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/witchspace_jump.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--break-jump", action="store_true",
                        help="MUTANT ARM: skip the countdown so no jump happens. The run must then "
                             "FAIL its own evidence assertions; used to prove the gate goes red.")
    parser.add_argument("--check-evidence", default=None, metavar="DUMP",
                        help="offline: re-apply the jump assertions to a stored dump")
    parser.add_argument("--label", default=None)
    parser.add_argument("--check-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    args = parser.parse_args(argv)

    spec = load_spec()

    try:
        if args.check_evidence:
            return check_evidence(args.check_evidence, spec, args.label)
        if args.check_frame:
            return check_frame(args.check_frame[0], args.check_frame[1])
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
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_z22_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, frame_out=args.frame_out,
                     break_jump=args.break_jump)
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
    print("JUMPED: system %d -> %d (%s), cause %r, %d tenths of fuel for a %d-tenth jump; "
          "countdown and exit states observed; %d ticks run in the destination (%.1fs wall)"
          % (ev["system_id_before"], ev["system_id_after"], ev["destination_system_name"],
             ev["jump_cause"], ev["fuel_consumed_tenths"], ev["distance_ly_tenths"], ev["ticks"],
             result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
