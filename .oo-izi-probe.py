"""SCRATCH determinism probe for bead oo-izi (scenario 003, combat encounter).

Question this answers: is a combat encounter in Oolite reproducible run-to-run under a fixed
OO_RANDOM_SEED, tick for tick, well enough to bless a byte-identical golden?

Two engagement modes are measured separately, because they are different determinism claims:

  --mode ai        a real dogfight: attacker and victim get their roles' real AIs, the attacker
                   is given the victim as target and told to performAttack(). Every shot, every
                   hit roll and every manoeuvre is the engine's.
  --mode scripted  a SCRIPTED energy strike: the attacker calls ship.dealEnergyDamage(d, r) a
                   fixed number of times. That reaches the same engine damage path as a laser
                   hit (ShipEntity.m:8836 -> takeEnergyDamage: -> noteTakingDamage ->
                   shipTakingDamage; energy <= 0 -> getDestroyedBy -> shipDied/shipKilledOther),
                   but the damage AMOUNT is declared, not rolled, and there is no aiming.

Evidence counters are ENGINE dispatches, hooked onto the ships' own script objects the way
Resources/Scripts/oolite-tutorial.js:860 does (`buoy.script.shipTakingDamage = function(...)`).
Nothing in this file can increment them.

Dumps are taken at --quant decimals (default 15, i.e. effectively unrounded) so that divergence
is measured at full precision rather than hidden by the 3-decimal storage policy.
"""

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = HERE
GOLDEN = os.path.join(HERE, "tests", "golden")
DUMP_DIR = os.path.join(GOLDEN, "dump")
sys.path.insert(0, GOLDEN)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import golden_run  # noqa: E402
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SAVE = "Resources/Scenarios/oolite-standard.oolite-save"

PROBE_JS = """(function(){
  debugConsole.ooIziDamage = 0;
  debugConsole.ooIziDeaths = 0;
  debugConsole.ooIziKills = 0;
  debugConsole.ooIziDamageTotal = 0;
  var v = debugConsole.ooIziVictim, a = debugConsole.ooIziAttacker;
  if (!v || !a) return "NO-SHIPS";
  v.script.shipTakingDamage = function (amount, whom, type) {
    debugConsole.ooIziDamage += 1;
    debugConsole.ooIziDamageTotal += amount;
  };
  v.script.shipDied = function (whom, type) { debugConsole.ooIziDeaths += 1; };
  a.script.shipKilledOther = function (other, type) { debugConsole.ooIziKills += 1; };
  return "OK";
})()"""


def vec(values):
    return "[%s]" % ", ".join("%.6f" % float(v) for v in values)


def ev(console, js, timeout=15):
    return console.evaluate(js, timeout=timeout).strip()


def setup_cast(console, attacker_pos, victim_pos, mode, akey, vkey):
    """Spawn exactly one attacker and one victim at DECLARED positions."""
    console.perform("debugConsole.ooIziAKey = %r; debugConsole.ooIziVKey = %r;" % (akey, vkey))
    n = console.evaluate_int(
        "(function(){"
        " var a = system.addShips(debugConsole.ooIziAKey, 1, player.ship.position, 3000);"
        " var v = system.addShips(debugConsole.ooIziVKey, 1, player.ship.position, 3000);"
        " if (!a || !v || !a.length || !v.length) return 0;"
        " debugConsole.ooIziAttacker = a[0]; debugConsole.ooIziVictim = v[0];"
        " a[0].shipUniqueName = 'attacker-000'; v[0].shipUniqueName = 'victim-000';"
        " return 2; })()")
    if n != 2:
        raise RuntimeError("could not spawn the two-ship cast (addShips returned %r)" % n)
    console.perform(
        "debugConsole.ooIziAttacker.position = %s;"
        "debugConsole.ooIziVictim.position = %s;"
        % (vec(attacker_pos), vec(victim_pos)))
    if mode == "ai":
        console.perform(
            "debugConsole.ooIziAttacker.setAI('oolite-policeAI.js');"
            "debugConsole.ooIziVictim.setAI('oolite-pirateAI.js');")
    return n


def engage(console, mode, strikes, damage, radius):
    if mode == "ai":
        console.perform(
            "debugConsole.ooIziAttacker.target = debugConsole.ooIziVictim;"
            "debugConsole.ooIziAttacker.performAttack();")
        return 0
    fired = console.evaluate_int(
        "(function(){ var a = debugConsole.ooIziAttacker, n = 0;"
        " for (var i = 0; i < %d; i++) { if (!a || !a.isValid) break;"
        "   a.dealEnergyDamage(%f, %f); n++; }"
        " return n; })()" % (strikes, damage, radius))
    return fired


def counters(console):
    return {
        "damage_events": console.evaluate_int("debugConsole.ooIziDamage"),
        "death_events": console.evaluate_int("debugConsole.ooIziDeaths"),
        "kill_events": console.evaluate_int("debugConsole.ooIziKills"),
        "damage_total": float(ev(console, "debugConsole.ooIziDamageTotal")),
    }


def run_ticks(console, ticks, tick_seconds, wall_budget=300):
    budget = ticks * tick_seconds
    start = float(ev(console, "clock.absoluteSeconds"))
    deadline = time.time() + wall_budget
    while time.time() < deadline:
        elapsed = float(ev(console, "clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise RuntimeError("game time did not advance %ss within %ss wall" % (budget, wall_budget))


def once(app_dir, out_path, run_root, seed, mode, ticks, tick_seconds, quant,
         strikes, damage, radius, akey='police', vkey='pirate'):
    from console import DebugConsole

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "probe-%s" % stamp))
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
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=SAVE))
        with console:
            console.perform("player.ship.launch();")
            deadline = time.time() + 120
            while time.time() < deadline:
                time.sleep(0.5)
                if ev(console, "player.ship.docked").lower() == "false":
                    break
            else:
                raise RuntimeError("never launched")

            suppressed = ev(console,
                            "(function(){ var s = system.populatorSettings, out = [];"
                            " for (var k in s) out.push(k);"
                            " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
                            " return String(out.length); })()")
            console.evaluate_int(
                "(function(){ var s = system.allShips, n = 0;"
                " for (var i = 0; i < s.length; i++) {"
                "   if (!s[i].isPlayer && !s[i].isStation) { s[i].remove(); n++; } }"
                " return n; })()")
            console.perform("player.ship.hudHidden = true;"
                            "player.ship.position = [0, 0, 0];"
                            "player.ship.orientation = [1, 0, 0, 0];"
                            "player.ship.velocity = [0, 0, 0];")

            setup_cast(console, [0.0, 0.0, 2000.0], [0.0, 0.0, 3200.0], mode, akey, vkey)
            hooked = ev(console, PROBE_JS)
            if hooked != "OK":
                raise RuntimeError("could not hook engine combat events: %s" % hooked)
            ident = ev(console,
                       "(function(){ var a = debugConsole.ooIziAttacker,"
                       " v = debugConsole.ooIziVictim;"
                       " return [a.name, a.maxEnergy, a.energy, v.name, v.maxEnergy,"
                       "  v.energy, system.allShips.length].join('|'); })()")
            fired = engage(console, mode, strikes, damage, radius)
            elapsed = run_ticks(console, ticks, tick_seconds)
            counts = counters(console)
            alive = ev(console,
                       "(function(){ var s = system.allShips, n = 0, names = [];"
                       " for (var i = 0; i < s.length; i++) if (!s[i].isPlayer && !s[i].isStation)"
                       "   names.push((s[i].shipUniqueName || s[i].name));"
                       " return names.sort().join(','); })()")
            victim_alive = ev(console,
                              "(debugConsole.ooIziVictim && debugConsole.ooIziVictim.isValid)"
                              " ? 'yes' : 'no'")
            attacker_alive = ev(console,
                                "(debugConsole.ooIziAttacker && debugConsole.ooIziAttacker.isValid)"
                                " ? 'yes' : 'no'")
            if os.environ.get("OO_IZI_CLEAR_AFTER") == "1":
                console.evaluate_int(
                    "(function(){ var s = system.allShips, n = 0;"
                    " for (var i = 0; i < s.length; i++) {"
                    "   if (!s[i].isPlayer && !s[i].isStation) { s[i].remove(); n++; } }"
                    " return n; })()")
            if ev(console, "pauseGame()").lower() != "true":
                raise RuntimeError("pauseGame() refused (guiScreen=%s)"
                                   % ev(console, "guiScreen"))
            console.perform("player.ship.position = [0, 0, 0];"
                            "player.ship.orientation = [1, 0, 0, 0];"
                            "player.ship.velocity = [0, 0, 0];")
            console.perform("debugConsole.dumpQuantDecimals = %d;" % quant)
            moving = ev(console,
                        "(function(){ var s = system.allShips, bad = [];"
                        " for (var i = 0; i < s.length; i++) {"
                        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
                        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
                        "              s[i].velocity.magnitude().toFixed(4)); }"
                        " return bad.join(', '); })()")
            state = json.loads(dump_state(console))
            state_moving = moving

        state["probe"] = dict(counts, identity=ident, moving=state_moving, mode=mode, ticks=ticks, seed=seed, fired=fired,
                              suppressed=int(suppressed), survivors=alive,
                              victim_alive=victim_alive, attacker_alive=attacker_alive,
                              game_seconds=round(elapsed, 3))
        text = json.dumps(state, sort_keys=True, separators=(",", ":"))
        with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        return {"ok": True, "bytes": len(text), "wall": round(time.time() - started, 1),
                "probe": state["probe"]}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        golden_run.unstage_app(staged)
        golden_run.release_all()


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--app-dir",
                   default="C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app")
    p.add_argument("--out", required=True)
    p.add_argument("--run-root", required=True)
    p.add_argument("--seed", type=int, default=20260918)
    p.add_argument("--mode", choices=("ai", "scripted"), default="ai")
    p.add_argument("--ticks", type=int, default=64)
    p.add_argument("--tick-seconds", type=float, default=0.125)
    p.add_argument("--quant", type=int, default=15)
    p.add_argument("--strikes", type=int, default=6)
    p.add_argument("--damage", type=float, default=60.0)
    p.add_argument("--radius", type=float, default=2500.0)
    p.add_argument("--akey", default="police")
    p.add_argument("--vkey", default="pirate")
    a = p.parse_args(argv)
    ensure_launchable(a.app_dir)
    try:
        r = once(a.app_dir, a.out, a.run_root, a.seed, a.mode, a.ticks, a.tick_seconds,
                 a.quant, a.strikes, a.damage, a.radius, a.akey, a.vkey)
    except Exception as exc:  # noqa: BLE001
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(r, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
