"""Golden scenario 001-launch-dock: launch from the station, fly a FIXED number of game ticks,
dock again, and emit a canonical state dump plus a frame hash.

WHY THIS SCENARIO EXISTS
------------------------
Golden scenario 001 (`tests/golden/dump/run_dump.py`, bead oo-gla/oo-ss8) pauses the game and
spawns ships without ever moving the player: `delta_t` is forced to 0, so the simulation never
advances and the dump is a photograph of a world that never ran. That was the right first step -
it proved the DUMP is canonical - but it exercises almost nothing of the engine.

This scenario is the exemplar for every golden that follows, so it does the thing the bead names:
the player LAUNCHES, the simulation RUNS for a fixed tick count, and the player DOCKS again.

ANTI-VACUITY: THE SCENARIO MUST ACTUALLY LAUNCH AND DOCK
--------------------------------------------------------
A scenario that dies on tick 3 and dumps a near-empty world reproduces byte-for-byte perfectly and
proves nothing. Two independent classes of positive evidence are therefore collected and BOTH are
written into the dump, so the stored golden itself carries them and any future run that skips the
flight fails the comparison by name:

  1. ENGINE EVENT COUNTERS, not our own bookkeeping. `install_probe()` attaches
     `shipWillLaunchFromStation` and `shipDockedWithStation` handlers to a live world script
     object. Those names are dispatched by the ENGINE - DockEntity.m:935 and
     PlayerEntity.m:7206 respectively - and reach world scripts through
     PlayerEntity.m:12889-12893 (`-doScriptEvent:` forwards to `-doWorldScriptEvent:`). Nothing in
     this file can increment them; only a real undocking and a real docking can. They appear in the
     dump as `evidence.launch_events` and `evidence.dock_events`, and `assert_flew()` requires
     both to be >= 1.
  2. A STATE TRANSITION WITH A MEASURED MIDPOINT. `player.ship.docked` must read true, then
     false (recorded as `evidence.undocked_seen`), then true again. A run that never left the
     station has `undocked_seen: false`, which is a dump FIELD, not a log line - so it survives
     into the golden and into every diff.

  Plus `evidence.tick_budget_met`: the game clock really advanced by the scenario's tick budget.
  A crashed or frozen run cannot fake it, because it is read from `clock.absoluteSeconds` inside
  the game, never from the harness clock. It is stored as a BOOLEAN and not as the measured float
  - see the comment beside it in `run()` for why storing the float would break the golden for a
  reason unrelated to the engine.

DETERMINISM KNOBS (all three are pinned in scenarios/001-launch-dock/spec.json)
------------------------------------------------------------------------------
  seed    -> OO_RANDOM_SEED, via console.py's `_env` (GameController.m, bead oo-scnp).
  system  -> asserted, not assumed: `system.ID` must equal spec["system_id"], and a mismatch is
             fatal. The save fixes it; the assertion catches a save that silently changed.
  ticks   -> a fixed number of AI ticks of GAME time (clock.absoluteSeconds), never wall time, so
             the dump does not depend on how loaded this box happens to be.

The flight itself is pinned to a fixed pose (position/orientation/velocity written directly and
read back), because "fly for 24 ticks" from a station launch corridor otherwise ends wherever the
launch impulse and the frame rate left the ship.

PORT / LAUNCH ISOLATION
-----------------------
Reuses `golden_run.py` wholesale: a reserved port, a staged app dir, and a debugConfig.plist in a
private OO_ADDITIONALADDONSDIRS - because the game DIALS OUT to the port named in that plist
(OODebugSupport.m:67-80). A run on the shared 8563 can be captured by a sibling worker's console
and quit four seconds in while still exiting rc=0 (bead oo-het), which is a fully vacuous pass.
"""

import argparse
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
from state_dump import (  # noqa: E402
    dump_state,
    ensure_launchable,
    spawn_deterministic,
    start_with_retry,
)

SCENARIO = "001-launch-dock"
SPEC_PATH = os.path.join(HERE, "scenarios", SCENARIO, "spec.json")

LAUNCH_TIMEOUT_SECONDS = 120
DOCK_TIMEOUT_SECONDS = 120
TICK_WALL_BUDGET_SECONDS = 300

# The probe's storage lives on the console's own scratch object, which every tier already uses as
# scratch state (OODebugMonitor.m:761, world_steps.py:135). Counters are installed BEFORE the
# launch so an event that fires during it is not missed.
PROBE_JS = """(function(){
  debugConsole.ooJorLaunchEvents = 0;
  debugConsole.ooJorDockEvents = 0;
  var names = Object.keys(worldScripts);
  if (!names.length) return "NO-WORLD-SCRIPTS";
  var s = worldScripts[names[0]];
  s.shipWillLaunchFromStation = function () { debugConsole.ooJorLaunchEvents += 1; };
  s.shipDockedWithStation = function () { debugConsole.ooJorDockEvents += 1; };
  return names[0];
})()"""


class ScenarioError(RuntimeError):
    pass


def load_spec(path=SPEC_PATH):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _vec(values):
    return "[%s]" % ", ".join("%.6f" % float(v) for v in values)


def install_probe(console):
    """Attach engine-event counters to a live world script and prove one was found.

    `-doWorldScriptEvent:` (PlayerEntity.m:12927-12939) walks `worldScripts` and calls the named
    method on each, so a function assigned here is invoked by the ENGINE on the real event. If
    there are no world scripts the probe would silently count nothing, which is exactly the
    vacuous-evidence shape this whole file exists to prevent - so that is fatal.
    """
    holder = console.evaluate(PROBE_JS).strip()
    if not holder or holder == "NO-WORLD-SCRIPTS":
        raise ScenarioError(
            "could not install the launch/dock event probe: the game reports no world scripts, so "
            "shipWillLaunchFromStation / shipDockedWithStation would never be delivered and the "
            "dump's evidence fields would be zero for a reason unrelated to the flight"
        )
    return holder


def probe_counts(console):
    return (console.evaluate_int("debugConsole.ooJorLaunchEvents"),
            console.evaluate_int("debugConsole.ooJorDockEvents"))


def _docked(console):
    return console.evaluate("player.ship.docked").strip().lower() == "true"


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def launch(console):
    if not _docked(console):
        raise ScenarioError("the save did not start DOCKED; this scenario's first half is the "
                            "launch, and there is nothing to launch from")
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(0.5)
        if not _docked(console):
            return True
    raise ScenarioError("player.ship.docked never became false within %ss: the ship did not "
                        "launch, so any dump taken now is of a world that never flew"
                        % LAUNCH_TIMEOUT_SECONDS)


def suppress_populators(console):
    """Turn the system populator OFF for the rest of the run, and report what was removed.

    REACHABLE FROM THE SCRIPTING SEAM - checked, not assumed. `system.populatorSettings` is a
    read-only dictionary of the active populator keys (OOJSSystem.m:170, :339) and
    `system.setPopulator(key, null)` deletes one: OOJSSystem.m:1311 calls
    `[UNIVERSE setPopulatorSetting:key to:nil]` when the second argument is null.

    WHY THIS AND NOT JUST CLEARING SHIPS BEFORE THE DUMP. Clearing afterwards is necessary but
    treats the symptom: while the scenario flies, `system_repopulator` (Universe.m:7101) keeps
    adding traffic, and every ship it adds consumes RANROT draws. A fixed OO_RANDOM_SEED fixes the
    SEQUENCE but not how far through it a wall-clock-timed flight has got, so a populator running
    during the flight is a per-run-variable draw consumer - the mechanism behind the scattered
    velocities this scenario measured. Switching it off at the source makes the flight itself
    quieter and makes every scenario that copies this exemplar cheaper.

    Returns the list of suppressed keys. An empty list is fine (a system may define none) and is
    reported rather than treated as failure - but the CALLER asserts the traffic is gone later,
    so a silently ineffective suppression cannot pass unnoticed.
    """
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
            "during the flight, consuming a per-run-variable number of RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship.

    Copied from run_dump.clear_system for the reason its docstring gives: removing the main
    station undocks the player and makes docked/undocked a second, unintended source of
    divergence. Here it matters more, because this scenario docks at that station.
    """
    console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    if remaining:
        raise ScenarioError("%d non-station ship(s) remain after clearing; the dump would measure "
                            "the ambient population instead of the scenario" % remaining)
    return remaining


def apply_pose(console, pose):
    """Park the ship at the scenario's declared pose and PROVE it landed there.

    A pose that silently failed to apply gives two runs of the same wrong scene, which reproduces
    byte-for-byte while measuring nothing (the lesson frame_capture.py:200-222 already paid for).
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


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time and return the elapsed game seconds.

    Gated on clock.absoluteSeconds, never on time.sleep: a wall-clock budget makes the dump a
    function of how loaded the machine is, which is the opposite of a golden.
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


def dock(console):
    """Dock, wait for the ENGINE's own dock event, then wait for the sequence to SETTLE.

    MEASURED, not assumed, twice over.

    (a) `-enterDock:` (PlayerEntity.m:7083-7090) sets dockedStation and the DOCKING status
        immediately, so `player.ship.docked` reads true while the break pattern is still playing;
        `shipDockedWithStation` is dispatched much later, at PlayerEntity.m:7206 in `-docked`. A
        first version polled the flag and reached the dump with dock_events still 0 - it would
        have blessed a golden taken mid-docking-sequence.

    (b) Even the event is not the end: it fires at :7206, six lines BEFORE `-docked` puts the GUI
        on the status screen (:7212), and the entities are still being settled around it. Pausing
        in that window produced runs whose spawned ships kept moving after the world was
        supposedly frozen. So this also waits for `player.ship.status` to reach STATUS_DOCKED,
        which is the state `-docked` leaves behind once it has finished.
    """
    station = console.evaluate("system.mainStation ? 'yes' : 'no'").strip()
    if station != "yes":
        raise ScenarioError("no main station in this system; nothing to dock with")
    console.perform("system.mainStation.dockPlayer();")
    deadline = time.time() + DOCK_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(0.5)
        if probe_counts(console)[1] >= 1:
            break
    else:
        raise ScenarioError(
            "the engine never dispatched shipDockedWithStation within %ss (player.ship.docked=%r): "
            "the docking sequence did not complete, so a dump taken now would be of a half-docked "
            "ship" % (DOCK_TIMEOUT_SECONDS, _docked(console)))

    while time.time() < deadline:
        if console.evaluate("player.ship.status").strip() == "STATUS_DOCKED" and _docked(console):
            return True
        time.sleep(0.5)
    raise ScenarioError(
        "shipDockedWithStation fired but player.ship.status is %r rather than STATUS_DOCKED after "
        "%ss; the docking sequence has not settled and pausing here leaves the world integrating"
        % (console.evaluate("player.ship.status").strip(), DOCK_TIMEOUT_SECONDS))


def assert_flew(evidence):
    """The anti-vacuity gate on the run itself, applied before anything is written.

    Every clause names a field the dump carries, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    if not evidence["undocked_seen"]:
        raise ScenarioError("evidence.undocked_seen is false: player.ship.docked never read false, "
                            "so the ship never actually left the station")
    if evidence["launch_events"] < 1:
        raise ScenarioError(
            "evidence.launch_events is %d: the engine never dispatched shipWillLaunchFromStation "
            "(DockEntity.m:935). player.ship.docked flipping without that event means the docked "
            "flag was changed by something other than a launch"
            % evidence["launch_events"])
    if evidence["dock_events"] < 1:
        raise ScenarioError(
            "evidence.dock_events is %d: the engine never dispatched shipDockedWithStation "
            "(PlayerEntity.m:7206), so the ship did not really dock"
            % evidence["dock_events"])
    if not evidence["docked_at_end"]:
        raise ScenarioError("evidence.docked_at_end is false: the scenario ends undocked")
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, snapshot=True,
        break_dock=False, seed_override=None, ticks_override=None):
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
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            holder = install_probe(console)
            assert_system(console, spec)
            docked_at_start = _docked(console)

            launch(console)
            undocked_seen = not _docked(console)
            # OFF AT THE SOURCE, before the flight consumes any of its draws (option (b)): the
            # populator is the thing that both adds traffic and eats a per-run-variable number of
            # RANROT draws. Clearing ships afterwards treats the symptom; this removes the cause.
            suppressed = suppress_populators(console)
            clear_system(console)
            apply_pose(console, spec["pose"])
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            png = None
            if snapshot:
                before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
                console.perform("takeSnapShot();")
                png = golden_run._await_png(artifact_dir, before)

            # RE-APPLY THE DECLARED POSE BEFORE DOCKING. Measured, not defensive: the player's
            # velocity is FROZEN at the instant the docking completes (probe: it reads
            # (0, 0, -58.136) and never changes again once status is STATUS_DOCKED), and the
            # instant at which dockPlayer() is issued depends on run_ticks' 100 ms poll landing
            # a few milliseconds either side of the budget. Two runs measured -42.968 and -38.552
            # for player.ship.velocity[2] for exactly that reason - a harness-granularity
            # artefact, not engine behaviour. Ending the flight at a DECLARED pose removes it at
            # the source. See docs 'What this golden does and does not pin'.
            apply_pose(console, spec["pose"])

            if not break_dock:
                dock(console)

            # Pause LAST, and CHECK THE RETURN VALUE. delta_t is forced to 0 while paused
            # (GameController.m:401-402), which is what stops the world drifting between the dock
            # and the dump; pausing any earlier would freeze the flight this scenario is about.
            #
            # pauseGame() IS NOT UNCONDITIONAL and a silent refusal is the most expensive bug this
            # scenario hit. GlobalPauseGame (OOJSGlobal.m:831-856) returns NO without pausing
            # anything when the player is on the long-range chart, a mission, a REPORT, a keyboard
            # entry or the save screen - and a docking can leave a docking report on screen
            # (PlayerEntity.m:12902). When it refuses, the simulation keeps integrating while the
            # scenario spawns its cast and dumps, so the dump records whatever the ships had
            # drifted to: three runs measured police-000.velocity[0] at 0.709, 10.954, -53.198 and
            # 59.749, and one run that DID pause recorded a clean 0. An unchecked pause turns a
            # deterministic scenario into a stopwatch.
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). "
                    "GlobalPauseGame refuses on the chart/mission/report/keyboard/save screens "
                    "(OOJSGlobal.m:843-848). The simulation would keep integrating through the "
                    "dump and no two runs could agree."
                    % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))

            # PIN THE PLAYER'S KINEMATIC STATE TO THE DECLARED POSE, AFTER THE PAUSE.
            #
            # This is the one place this scenario declares a value rather than measuring one, so
            # it is spelled out. MEASURED FACT: the player's velocity is not settled when the
            # docking completes. A probe run zeroed velocity and desiredSpeed and then watched it
            # grow anyway - (0,0,54.784) at t+1.0s, (0,0,110.72) at t+2.5s, while `speed` stayed
            # pinned at 175 - and the value frozen into the dump is whatever it had reached at the
            # frame the docking sequence ended. Across runs that landed at -164.856 and -164.504,
            # and before the ambient-traffic fix at -42.968 and -38.552. It tracks WALL-CLOCK
            # frames between two console round trips, so it is a property of how loaded this box
            # is, not of the simulation.
            #
            # The rejected alternative was to quantise it away. That is expressly the thing this
            # policy forbids: it would need ~0 decimals, which golden_diff.py refuses outright,
            # and it would blind the golden to every other float at the same time.
            #
            # So the scenario DECLARES the player's final pose instead, from spec.json, while the
            # clock is stopped and nothing can integrate it. The cost is stated plainly in
            # tests/golden/scenarios/001-launch-dock/README.md: player.ship.position and
            # .velocity are NOT evidence in this golden - they are constants, and a test that
            # compared only them would be vacuous. The measured content of this golden is the
            # entity set, the market, the player's ledger, and the evidence block; the launch and
            # dock are evidenced by engine event counters, which nothing here can write.
            apply_pose(console, spec["pose"])

            # CLEAR THE AMBIENT TRAFFIC AND SPAWN NOTHING. Two measured findings, both real.
            #
            # (1) The system populator adds traffic while the scenario flies (Universe.m:7101
            #     system_repopulator) and which ship it draws depends on how many frames this box
            #     rendered, not on the seed: two runs measured a 'Cobra Mark I' and a 'Worm', both
            #     role 'miner'. Bead oo-qwk5's lesson exactly - a scenario asserting on a
            #     population the populator also writes to is re-falsifiable by a ship it never
            #     spawned. So the traffic goes.
            #
            # (2) A SPAWNED CAST CANNOT BE FROZEN FROM JS, and this cost several runs to learn.
            #     `spawn_deterministic` gives ships identical POSITIONS run to run but scattered
            #     VELOCITIES (12 differing fields across two runs, no positions among them),
            #     because the velocity comes from an RNG draw whose offset in the RANROT stream
            #     depends on how many draws the timed flight consumed. Writing velocity = [0,0,0]
            #     does NOT fix it: ShipEntity.m:12830-12833 defines
            #         - (Vector) velocity { return [super velocity] + [self thrustVector]; }
            #     so the JS setter zeroes only the NEWTONIAN component while the thrust component
            #     (flightSpeed along v_forward) survives and reads straight back. `setTotalVelocity:`
            #     would do it but is not exposed to JS, and `speed` is READONLY there. Measured: 4
            #     of 6 ships still reading 60-97 m/s immediately after the write, on 3 of 10 runs.
            #
            # So this scenario deliberately dumps a world containing only the SYSTEM'S OWN fixed
            # entities - the main station and the rock hermit, both genuinely at rest - plus the
            # player. Those are MEASURED values, not declared ones. The scenario under test is the
            # player's launch and dock; adding a cast whose velocities cannot be pinned would have
            # meant either a flaky golden or a faked field, and both are worse than a smaller one.
            # A future scenario that needs moving ships needs a JS seam for flightSpeed first.
            clear_system(console)

            # THE WORLD MUST BE GENUINELY AT REST. This is an ASSERTION, not a write.
            #
            # An earlier version wrote velocity = [0,0,0] over every non-player ship here. That
            # was the wrong shape twice over: it declared a value the golden then reported as if
            # measured, and (per (2) above) it did not even work, because the JS setter reaches
            # only the Newtonian half of ShipEntity's velocity. With no cast to spawn, the
            # remaining entities are the system's own fixed furniture, which really is at rest -
            # so the honest instrument is to CHECK that, and to fail loudly if it is not.
            #
            # THE CLOCK CHECK COMES FIRST, because a world that is still integrating is the CAUSE
            # and residual motion is only its symptom; reporting the symptom first sends the
            # reader to audit the entities rather than the pause.
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned "
                    "true; the world is NOT frozen, so the dump is a stopwatch reading and no two "
                    "runs can agree" % (clock_after - clock_before, clock_before, clock_after))

            # `magnitude` IS A FUNCTION, NOT A PROPERTY. A first version wrote
            # `s[i].velocity.magnitude > 0.0005`, comparing a JS function object with a number:
            # always false, so the guard passed on every run including ones whose dumps differed
            # by 12 velocity fields. A guard that cannot fail is worse than none, because it is
            # reported as evidence. It is CALLED here, and this is what caught finding (2).
            moving = console.evaluate(
                "(function(){ var s = system.allShips, bad = [];"
                " for (var i = 0; i < s.length; i++) {"
                "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
                "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
                "              s[i].velocity.magnitude().toFixed(4)); }"
                " return bad.join(', '); })()").strip()
            if moving:
                raise ScenarioError(
                    "the game clock is stopped but %d entity/entities still report motion: %s. "
                    "ShipEntity -velocity is [super velocity] + [self thrustVector] "
                    "(ShipEntity.m:12830-12833), so a ship under thrust reads a non-zero velocity "
                    "that no JS write can clear; its value depends on the frame count and no two "
                    "runs can reproduce it." % (moving.count("=") + 1, moving))

            launch_events, dock_events = probe_counts(console)
            state = json.loads(dump_state(console))

        evidence = {
            "docked_at_start": bool(docked_at_start),
            "undocked_seen": bool(undocked_seen),
            "docked_at_end": bool(state["player"]["ship"]["docked"]),
            "launch_events": launch_events,
            "dock_events": dock_events,
            # The BUDGET is pinned; the measured elapsed time is NOT in the dump on purpose.
            # run_ticks polls the game clock every 100 ms and stops at the first sample at or
            # above the budget, so the overshoot (measured: 3.04 against a 3.000 budget) is a
            # property of how fast this box happened to render that poll interval - a harness
            # artefact, not engine state. Storing it would make the golden depend on machine load
            # and guarantee that no two runs ever match, for a reason that has nothing to do with
            # the simulation. The ASSERTION on it is kept in full strength as a boolean: the
            # clock must have advanced at least the budget, and `tick_budget_met` false is fatal.
            # The raw float is reported on stdout by the CLI, where a human can see it.
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
            "probe_script": holder,
        }
        assert_flew(evidence)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        result = {"ok": True, "out": out_path, "port": port, "png": png,
                  "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                  "game_seconds_elapsed": round(elapsed, 3), "evidence": evidence}
        if png:
            import frame_hash
            result["frame_hash"] = frame_hash.hex_digest(frame_hash.frame_hash(png))
        return result
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/launch_dock.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--no-snapshot", action="store_true",
                        help="skip the frame capture (the dump alone is much cheaper)")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--break-dock", action="store_true",
                        help="MUTANT: skip the docking step. The run must then FAIL its own "
                             "evidence assertions; used to prove the gate can go red.")
    args = parser.parse_args(argv)

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_jor_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     snapshot=not args.no_snapshot, break_dock=args.break_dock,
                     seed_override=args.seed, ticks_override=args.ticks)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())