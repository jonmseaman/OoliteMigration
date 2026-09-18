"""Golden scenario 003-combat: one attacker destroys one victim with a scripted energy strike,
then the world is settled and a canonical dump is written.

WHY THIS SCENARIO LOOKS THE WAY IT DOES - READ THIS BEFORE CHANGING THE CAST
---------------------------------------------------------------------------
Combat is the first golden whose subject MOVES. A byte-identical dump needs the whole encounter
to be reproducible, and the measurement that shaped this file (reported in
tests/golden/pending/003-combat/README.md) found exactly THREE sources of divergence, two of
which are fatal and one of which is avoidable.

  (1) SPAWNING BY ROLE IS NOT DETERMINISTIC. `system.addShips("pirate", 1, ...)` goes through
      Universe.m:4008 -newShipWithRole: -> :3948 randomShipKeyForRoleRespectingConditions: ->
      OOShipRegistry.m:276-279 `[[self probabilitySetForRole:role] randomObject]`, i.e. a RANROT
      draw. A fixed OO_RANDOM_SEED fixes the SEQUENCE but not how far into it the run has got,
      because the frames burned between launch and spawn depend on how fast this box renders.
      MEASURED across three role-spawned runs at one seed: the victim came back as a
      "Moray Star Boat" with maxEnergy 240, a "Moray Star Boat" with maxEnergy 496, and a
      "Mamba" with maxEnergy 240. A fixed strike then kills the victim in two of those runs and
      leaves it alive in the third - the ENCOUNTER'S OUTCOME changed, not just a float.
      So the cast is pinned by SHIP KEY. `"[viper]"` is the documented literal-key form
      (OOShipRegistry.m:1229 registers "[<shipKey>]" as a role of probability 1.0 for every
      ship), which resolves through the same addShips call with no draw to make. MEASURED: three
      keyed runs returned GalCop Viper/180 and Adder/85 every time.

  (2) AI-DRIVEN GUNNERY IS NOT DETERMINISTIC, and on this build it does not even finish. Three
      runs of a real dogfight (both ships on their roles' real AIs, attacker.performAttack()),
      400 ticks each, produced damage_total 35.475 / 24.0 / 36.0 and death_events 0 / 0 / 0 -
      different damage every time and no kill at all within 50 game seconds. The engine's own
      hit path is RANROT-fed (ShipEntity.m:8983 noteTakingDamage is reached from the laser
      code at :11763-11769, and -noteTakingDamage itself rolls `randf()*10.0 < accuracy` at
      :8988 to pick an evasion behaviour), so no seed pinning makes a dogfight repeatable while
      delta_t is wall-clock. THEREFORE THE DAMAGE IS SCRIPTED: the attacker calls
      `ship.dealEnergyDamage(amount, range)` a fixed number of times. That is NOT a way of
      faking combat - it enters the engine at OOJSShip.m:2406 -> ShipEntity.m:8836
      -dealEnergyDamage:atRange:withBias:, which calls -takeEnergyDamage: (:13119) exactly as a
      laser hit does, which decrements `energy` (:13131), dispatches shipTakingDamage (:8983),
      and on energy <= 0 runs -getDestroyedBy: -> -noteKilledBy: (:9020-9024) dispatching
      shipDied on the victim and shipKilledOther on the attacker. Every counter this scenario
      asserts on is an ENGINE dispatch on that path.

  (3) delta_t IS WALL-CLOCK (GameController.m:405 `delta_t = [NSDate
      timeIntervalSinceReferenceDate] - last_timeInterval`), so any entity still integrating at
      dump time carries a frame-count-dependent value. A spawned ship under thrust cannot be
      frozen from JS - ShipEntity.m:12830-12833 defines -velocity as
      `[super velocity] + [self thrustVector]`, so the JS setter clears only the Newtonian half.
      MEASURED: keeping the surviving attacker in the dump diverged on 7 fields across 3 runs,
      with the attacker reading 15.92 and 320.00 m/s after the world was supposedly frozen.
      So the combat is fought, the ENGINE COUNTERS ARE HARVESTED, and then every non-station
      ship is removed before the dump - the same shape scenario 001 settled on, for the same
      reason. The dump therefore records the station furniture plus an evidence block; the
      encounter is evidenced by counters nothing in this file can write.

ANTI-VACUITY: WHAT A DEAD RUN CANNOT SATISFY
--------------------------------------------
A combat scenario in which combat never happens (ships out of range, an inert AI, an
invulnerable target) produces a clean log and a stable dump. Six independent fields make that
impossible to pass, and all six are stored IN the dump so every future diff re-checks them:

  evidence.damage_events   >= 1  engine shipTakingDamage dispatches on the victim
  evidence.damage_total    >  0  the engine's own `amount` argument, summed
  evidence.death_events    == 1  engine shipDied on the victim
  evidence.kill_events     >= 1  engine shipKilledOther on the ATTACKER - the engine's own
                                 attribution of the kill, which no proximity accident supplies
  evidence.victim_destroyed true the victim handle is no longer valid
  evidence.cast_alive_before/after  2 -> 1: the scenario's OWN two handles, so the count is
                                 immune to the system populator (bead oo-qwk5's blocker: a role
                                 count cannot tell a spawned ship from a wanderer; a handle can)

`--no-fire` is the built-in red proof: it skips the strike and nothing else, and the run then
fails its own assertions naming evidence.damage_events.

DETERMINISM KNOBS (all pinned in scenarios/003-combat/spec.json, all read below, and all
asserted equal to the values recorded in the staged golden's provenance.json by
tests/golden/gate_003_spec.py - a knob with no predicate is decoration, bead oo-3ya)
  seed, system_id, ticks, tick_seconds, quant_decimals, load_save,
  attacker_key, victim_key, strikes, strike_damage, strike_range,
  attacker_position, victim_position.

PORT / LAUNCH ISOLATION: reuses golden_run.py wholesale, exactly as scenario 001 does - a
reserved port and a debugConfig.plist in a private OO_ADDITIONALADDONSDIRS, because the game
DIALS OUT to the port named there (OODebugSupport.m:67-80). A run on the shared 8563 can be
captured and quit by a sibling worker's console while still exiting rc=0 (bead oo-het).
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
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "003-combat"
# The spec lives beside the STAGED golden, not under tests/golden/scenarios/. Both that
# directory and goldens/ are protected paths in tools/guardrails.sh (PROTECTED_PREFIXES =
# "goldens/ tests/golden/scenarios/"), and A/B control on a clean tree confirmed the guard
# refuses a brand-new file under either with no re-bless approval. The guarded location is
# searched FIRST, so this keeps working unchanged once a human lands the golden.
def _spec_path():
    for candidate in (
            os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
            os.path.join(HERE, "pending", SCENARIO, "spec.json")):
        if os.path.isfile(candidate):
            return candidate
    return os.path.join(HERE, "pending", SCENARIO, "spec.json")


SPEC_PATH = _spec_path()

LAUNCH_TIMEOUT_SECONDS = 120
TICK_WALL_BUDGET_SECONDS = 300

# The counters are hung on the SHIPS' OWN script objects, which is how the stock content does it
# (Resources/Scripts/oolite-tutorial.js:860 `buoy.script.shipTakingDamage = function(...)`).
# ShipScriptEvent (ShipEntity.h:1266) dispatches to exactly that object, so a function assigned
# here is invoked by the ENGINE on the real event and nothing in this file can increment it.
# `amount` is the engine's own damage argument (ShipEntity.m:8977-8983).
PROBE_JS = """(function(){
  debugConsole.ooIziDamage = 0;
  debugConsole.ooIziDamageTotal = 0;
  debugConsole.ooIziDeaths = 0;
  debugConsole.ooIziKills = 0;
  var v = debugConsole.ooIziVictim, a = debugConsole.ooIziAttacker;
  if (!v || !a) return "NO-CAST";
  if (!v.script || !a.script) return "NO-SHIP-SCRIPTS";
  v.script.shipTakingDamage = function (amount, whom, type) {
    debugConsole.ooIziDamage += 1;
    debugConsole.ooIziDamageTotal += amount;
  };
  v.script.shipDied = function (whom, type) { debugConsole.ooIziDeaths += 1; };
  a.script.shipKilledOther = function (other, type) { debugConsole.ooIziKills += 1; };
  return "OK";
})()"""


class ScenarioError(RuntimeError):
    pass


def load_spec(path=SPEC_PATH):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _vec(values):
    return "[%s]" % ", ".join("%.6f" % float(v) for v in values)


def _js_string(value):
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


def _ev(console, js, timeout=15):
    return console.evaluate(js, timeout=timeout).strip()


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def launch(console):
    """Get the universe actually simulating. A loaded save starts DOCKED, and while docked NPC AI
    does not tick at all (world_steps.py's own docstring records 90 s of zero movement), so a
    combat scenario run from the station dock measures nothing."""
    if _ev(console, "player.ship.docked").lower() != "true":
        raise ScenarioError("the save did not start DOCKED; the launch is what starts the "
                            "simulation, and there is nothing to launch from")
    console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(0.5)
        if _ev(console, "player.ship.docked").lower() == "false":
            return True
    raise ScenarioError("player.ship.docked never became false within %ss: the universe is not "
                        "simulating, so no combat can occur" % LAUNCH_TIMEOUT_SECONDS)


def suppress_populators(console):
    """Switch the system populator off at the source and prove none survived.

    `system.populatorSettings` is the read-only dictionary of active keys (OOJSSystem.m:170,
    :339) and `system.setPopulator(key, null)` deletes one (OOJSSystem.m:1311 ->
    `[UNIVERSE setPopulatorSetting:key to:nil]`). Left running, Universe.m:7101's
    system_repopulator adds traffic mid-run and each added ship consumes RANROT draws, which is
    the mechanism behind finding (1) in the module docstring.

    This does NOT stop the main station launching its own traffic (StationEntity.m:961-995, a
    separate timer), which is why the surviving traffic is cleared before the dump rather than
    assumed absent.
    """
    keys = _ev(console,
               "(function(){ var s = system.populatorSettings, out = [];"
               " for (var k in s) out.push(k);"
               " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
               " return out.join(','); })()")
    remaining = _ev(console, "(function(){ var n = 0;"
                             " for (var k in system.populatorSettings) n++;"
                             " return String(n); })()")
    if remaining not in ("0", ""):
        raise ScenarioError(
            "%s populator setting(s) survived suppression; the system would keep adding traffic "
            "during the encounter, consuming a per-run-variable number of RANROT draws"
            % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship and prove none remain.

    The main station is kept deliberately: removing it undocks the player and makes
    docked/undocked a second unintended source of divergence (the reason run_dump.clear_system
    gives, and scenario 001 copies).
    """
    console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && !s[i].isStation) { s[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && !s[i].isStation) n++; }"
        " return n; })()")
    if remaining:
        raise ScenarioError("%d non-station ship(s) remain after clearing; the dump would measure "
                            "the ambient population instead of the scenario" % remaining)
    return remaining


def spawn_cast(console, spec):
    """Spawn exactly one attacker and one victim BY SHIP KEY at declared positions.

    The keys, not roles - see finding (1) in the module docstring. Handles are kept on
    debugConsole (a writable JS global the whole tier already uses as scratch,
    OODebugMonitor.m:761) so every later assertion names THIS scenario's two ships and cannot be
    satisfied or falsified by a ship the station launched (bead oo-qwk5's blocker).
    """
    console.perform("debugConsole.ooIziAKey = %s; debugConsole.ooIziVKey = %s;"
                    % (_js_string(spec["attacker_key"]), _js_string(spec["victim_key"])))
    n = console.evaluate_int(
        "(function(){"
        " var a = system.addShips(debugConsole.ooIziAKey, 1, player.ship.position, 3000);"
        " var v = system.addShips(debugConsole.ooIziVKey, 1, player.ship.position, 3000);"
        " if (!a || !v || !a.length || !v.length) return 0;"
        " debugConsole.ooIziAttacker = a[0]; debugConsole.ooIziVictim = v[0];"
        " a[0].shipUniqueName = 'attacker-000'; v[0].shipUniqueName = 'victim-000';"
        " return 2; })()")
    if n != 2:
        raise ScenarioError(
            "could not spawn the cast: addShips(%r)/addShips(%r) did not both return a ship "
            "(got %r). The keys must be literal ship keys in the '[shipKey]' form registered by "
            "OOShipRegistry.m:1229; a role name here would reintroduce the RANROT draw this "
            "scenario exists to remove."
            % (spec["attacker_key"], spec["victim_key"], n))
    console.perform("debugConsole.ooIziAttacker.position = %s;"
                    "debugConsole.ooIziVictim.position = %s;"
                    % (_vec(spec["attacker_position"]), _vec(spec["victim_position"])))
    identity = _ev(console,
                   "(function(){ var a = debugConsole.ooIziAttacker,"
                   " v = debugConsole.ooIziVictim;"
                   " return [a.name, a.maxEnergy, v.name, v.maxEnergy].join('|'); })()")
    return identity


def install_probe(console):
    result = _ev(console, PROBE_JS)
    if result != "OK":
        raise ScenarioError(
            "could not install the combat event probe (%s): without it shipTakingDamage / "
            "shipDied / shipKilledOther would never be counted and the dump's evidence fields "
            "would be zero for a reason unrelated to the encounter" % result)
    return result


def cast_alive(console):
    """How many of THIS SCENARIO'S two ships are still valid. Not a role count: the populator and
    the station both write to role counts and neither can write to these two handles."""
    return console.evaluate_int(
        "(function(){ var n = 0;"
        " if (debugConsole.ooIziAttacker && debugConsole.ooIziAttacker.isValid) n++;"
        " if (debugConsole.ooIziVictim && debugConsole.ooIziVictim.isValid) n++;"
        " return n; })()")


def strike(console, spec):
    """Deal the scenario's fixed energy strike and return how many strikes landed.

    Enters the engine at OOJSShip.m:2406 -> ShipEntity.m:8836, which is the same
    -takeEnergyDamage: path a laser hit takes (:13119). The loop stops the moment the target
    stops being valid, so the strike count in the dump is the number actually delivered rather
    than the number requested - a scenario whose victim died on strike 1 must not claim 6.
    """
    return console.evaluate_int(
        "(function(){ var a = debugConsole.ooIziAttacker, n = 0;"
        " for (var i = 0; i < %d; i++) {"
        "   if (!a || !a.isValid) break;"
        "   if (!debugConsole.ooIziVictim || !debugConsole.ooIziVictim.isValid) break;"
        "   a.dealEnergyDamage(%f, %f); n++; }"
        " return n; })()"
        % (int(spec["strikes"]), float(spec["strike_damage"]), float(spec["strike_range"])))


def probe_counts(console):
    return {
        "damage_events": console.evaluate_int("debugConsole.ooIziDamage"),
        "damage_total": round(float(_ev(console, "debugConsole.ooIziDamageTotal")), 3),
        "death_events": console.evaluate_int("debugConsole.ooIziDeaths"),
        "kill_events": console.evaluate_int("debugConsole.ooIziKills"),
    }


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time. Gated on clock.absoluteSeconds, never time.sleep:
    a wall-clock budget makes the dump a function of machine load."""
    budget = ticks * tick_seconds
    start = float(_ev(console, "clock.absoluteSeconds"))
    deadline = time.time() + TICK_WALL_BUDGET_SECONDS
    while time.time() < deadline:
        elapsed = float(_ev(console, "clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise ScenarioError("game time did not advance %ss within %ss of wall time"
                        % (budget, TICK_WALL_BUDGET_SECONDS))


def assert_fought(evidence):
    """The anti-vacuity gate on the RUN, applied before anything is written to disk.

    Every clause names a field the dump carries, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    if evidence["damage_events"] < 1:
        raise ScenarioError(
            "evidence.damage_events is %d: the engine never dispatched shipTakingDamage on the "
            "victim (ShipEntity.m:8983), so no damage reached it and no combat occurred"
            % evidence["damage_events"])
    if evidence["damage_total"] <= 0:
        raise ScenarioError(
            "evidence.damage_total is %r: the engine reported zero total damage even though it "
            "dispatched %d damage event(s); the strike landed for nothing"
            % (evidence["damage_total"], evidence["damage_events"]))
    if evidence["death_events"] != 1:
        raise ScenarioError(
            "evidence.death_events is %d, expected exactly 1: the engine dispatches shipDied "
            "once per destruction (ShipEntity.m:9020). 0 means the victim survived the "
            "encounter; more than 1 means the handle is not the single ship this scenario "
            "spawned" % evidence["death_events"])
    if evidence["kill_events"] < 1:
        raise ScenarioError(
            "evidence.kill_events is %d: the engine never dispatched shipKilledOther on the "
            "ATTACKER (ShipEntity.m:9024), so the victim's death was not attributed to this "
            "scenario's attacker. Something else killed it." % evidence["kill_events"])
    if not evidence["victim_destroyed"]:
        raise ScenarioError("evidence.victim_destroyed is false: the victim handle is still "
                            "valid, so the target was not destroyed")
    if not evidence["attacker_survived"]:
        raise ScenarioError("evidence.attacker_survived is false: the attacker did not outlive "
                            "the encounter, so the outcome is not the one this golden pins")
    if evidence["cast_alive_before"] != 2 or evidence["cast_alive_after"] != 1:
        raise ScenarioError(
            "evidence.cast_alive went %d -> %d, expected 2 -> 1: the scenario's own two ships "
            "must number two before the strike and exactly one after it"
            % (evidence["cast_alive_before"], evidence["cast_alive_after"]))
    if evidence["strikes_delivered"] < 1:
        raise ScenarioError("evidence.strikes_delivered is %d: the attacker never fired"
                            % evidence["strikes_delivered"])
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, no_fire=False,
        seed_override=None, ticks_override=None):
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
            assert_system(console, spec)
            launch(console)
            suppressed = suppress_populators(console)
            clear_system(console)

            # Park the player at the declared pose BEFORE the encounter so the strike geometry is
            # the spec's, not wherever the launch corridor left the ship.
            console.perform("player.ship.hudHidden = true;"
                            "player.ship.position = [0.000000, 0.000000, 0.000000];"
                            "player.ship.orientation = [1.000000, 0.000000, 0.000000, 0.000000];"
                            "player.ship.velocity = [0.000000, 0.000000, 0.000000];")

            identity = spawn_cast(console, spec)
            install_probe(console)
            before = cast_alive(console)
            # --no-fire is the built-in mutant: it removes the strike AND NOTHING ELSE, so the
            # run reaches its own evidence assertions and fails on damage_events rather than
            # dying earlier for an unrelated reason.
            delivered = 0 if no_fire else strike(console, spec)
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            after = cast_alive(console)
            counts = probe_counts(console)
            victim_valid = _ev(console, "(debugConsole.ooIziVictim && "
                                        "debugConsole.ooIziVictim.isValid) ? 'yes' : 'no'")
            attacker_valid = _ev(console, "(debugConsole.ooIziAttacker && "
                                          "debugConsole.ooIziAttacker.isValid) ? 'yes' : 'no'")

            # THE ENCOUNTER IS OVER AND ITS EVIDENCE IS HARVESTED. Now settle the world.
            #
            # Everything the dump will contain must be genuinely at rest, and a ship under thrust
            # cannot be made so from JS: ShipEntity.m:12830-12833 defines -velocity as
            # [super velocity] + [self thrustVector], so the setter clears only the Newtonian
            # half. MEASURED on this scenario: keeping the surviving attacker in the dump
            # diverged on 7 fields across 3 runs, the attacker reading 15.92 and 320.00 m/s
            # after the world was supposedly frozen. So the survivor is removed with the rest of
            # the traffic, and the dump keeps the station furniture, which really is at rest.
            # The encounter survives into the golden as the evidence block, which is measured
            # ENGINE output, not a declared constant.
            clear_system(console)

            if _ev(console, "pauseGame()").lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). "
                    "GlobalPauseGame refuses on the chart/mission/report/keyboard/save screens "
                    "(OOJSGlobal.m:843-848). delta_t is wall-clock (GameController.m:405), so "
                    "the simulation would keep integrating through the dump and no two runs "
                    "could agree." % _ev(console, "guiScreen"))
            clock_before = float(_ev(console, "clock.absoluteSeconds"))

            # The player is the one entity that cannot be removed, and its own velocity is not
            # settled after a launch (scenario 001 measured it growing from 0 to 110 m/s between
            # two console round trips while `speed` stayed pinned). Declared here, under the
            # pause, and declared as such in the README: player.ship.position and .velocity are
            # NOT evidence in this golden.
            console.perform("player.ship.position = [0.000000, 0.000000, 0.000000];"
                            "player.ship.orientation = [1.000000, 0.000000, 0.000000, 0.000000];"
                            "player.ship.velocity = [0.000000, 0.000000, 0.000000];")

            clock_after = float(_ev(console, "clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned "
                    "true; the world is NOT frozen, so the dump is a stopwatch reading and no "
                    "two runs can agree" % (clock_after - clock_before, clock_before, clock_after))

            # `magnitude` IS A FUNCTION, NOT A PROPERTY (scenario 001 shipped a guard comparing a
            # function object with a number, which is always false and therefore always passed).
            # It is CALLED here.
            moving = _ev(console,
                         "(function(){ var s = system.allShips, bad = [];"
                         " for (var i = 0; i < s.length; i++) {"
                         "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
                         "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
                         "              s[i].velocity.magnitude().toFixed(4)); }"
                         " return bad.join(', '); })()")
            if moving:
                raise ScenarioError(
                    "the game clock is stopped but %d entity/entities still report motion: %s. "
                    "ShipEntity -velocity is [super velocity] + [self thrustVector] "
                    "(ShipEntity.m:12830-12833), so a ship under thrust reads a non-zero "
                    "velocity that no JS write can clear; its value depends on the frame count "
                    "and no two runs can reproduce it." % (moving.count("=") + 1, moving))

            state = json.loads(dump_state(console))

        evidence = dict(
            counts,
            victim_destroyed=(victim_valid == "no"),
            attacker_survived=(attacker_valid == "yes"),
            cast_alive_before=before,
            cast_alive_after=after,
            strikes_delivered=delivered,
            strikes_requested=int(spec["strikes"]),
            strike_damage=float(spec["strike_damage"]),
            strike_range=float(spec["strike_range"]),
            attacker_key=spec["attacker_key"],
            victim_key=spec["victim_key"],
            cast_identity=identity,
            # BOOLEAN, not the measured float, for the reason scenario 001 documents: run_ticks
            # polls the game clock every 100 ms and stops at the first sample at or above the
            # budget, so the overshoot is a property of how fast this box rendered that interval.
            # Storing it would make the golden depend on machine load. The assertion keeps full
            # strength; the raw float is reported on stdout where a human can see it.
            tick_budget_met=bool(elapsed >= ticks * float(spec["tick_seconds"])),
            game_seconds_budget=round(ticks * float(spec["tick_seconds"]), 3),
            ticks=ticks,
            seed=seed,
            system_id=int(spec["system_id"]),
            populators_suppressed=len(suppressed),
        )
        assert_fought(evidence)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        return {"ok": True, "out": out_path, "port": port,
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "game_seconds_elapsed": round(elapsed, 3), "evidence": evidence}
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
    parser = argparse.ArgumentParser(prog="tests/golden/combat.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--no-fire", action="store_true",
                        help="MUTANT: skip the strike and nothing else. The run must then FAIL "
                             "its own evidence assertions naming evidence.damage_events; used to "
                             "prove the gate can go red.")
    args = parser.parse_args(argv)

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_izi_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, no_fire=args.no_fire,
                     seed_override=args.seed, ticks_override=args.ticks)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
