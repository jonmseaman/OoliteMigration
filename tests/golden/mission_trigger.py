"""Golden scenario 005: a MISSION SCRIPT FIRES from a world-script event, and its variables pin.

WHAT THIS SCENARIO IS FOR
=========================
`upstream/oolite-tests/Checklist-files/Missions/CloakingDevice.oolite-save` is loaded through the
game's own `-load` argument (console.py:121-122; dispatched by PlayerEntityLoadSave.m into
`-loadPlayerFromFile:`). Loading calls `[UNIVERSE populateNormalSpace]`
(PlayerEntityLoadSave.m:777), which fires the **`systemWillPopulate` world-script event**
(Universe.m:1732-1737). That event is the subject of this scenario.

THE TRIGGER, AND WHY IT CANNOT BE FAKED BY A DESERIALISER
=========================================================
`oolite-cloaking-device-mission.js:47-103` handles `systemWillPopulate`. In galaxy 5
(`galaxyNumber === 4`) with `missionVariables.cloak` unset it INCREMENTS `cloakcounter`, and when
the counter passes 6 with no `asp-cloaked` in the system it registers the ambush populator and
spawns the cloaked Asp plus two escorts.

The fixture's `mission_cloakcounter` is **6** ON DISK. MEASURED in the running engine after the
load it is **7**. That one-unit difference is the whole point:

    a value the deserialiser merely COPIED would read 6.
    a value the MISSION SCRIPT WROTE reads 7.

So `engine_cloakcounter == file_cloakcounter + 1` is a positive, falsifiable assertion that a
world-script event ran a mission script's code. It is paired with the two *side effects* of the
same `if` block, because a counter alone could in principle move for another reason:

  * `oolite-cloaking-device-mission` appears in `system.populatorSettings` - a key only that
    script's `system.setPopulator(...)` call creates;
  * the ambush exists: `system.countShipsWithRole('asp-cloaked') == 1` and `'asp-pirate' == 2`.

All three are read out of the LIVE engine before the world is cleared for the dump, and all three
are recorded as dump fields so every later comparison re-checks them.

THE CONTROL ARM
===============
`spec['control_save']` is `Constrictor.oolite-save`: the identical scenario, same seed, same
ticks, same dump, a different checklist save. It is in galaxy 1, so the `galaxyNumber === 4` guard
fails, `cloakcounter` is absent, no ambush populator is registered and no Asp is spawned - i.e.
the mission script is LOADED but its trigger did NOT fire. That is a sharper control than a dead
run: it proves the assertions measure the TRIGGER and not merely "a game with a save in it".
`--fresh-control` (no `-load` at all) is the second arm, where the mission script is not even
built.

DETERMINISM
===========
No `system.addShips(<role>, ...)` is issued by this harness. The ambush spawn inside the mission
script IS a role draw, so those ships are counted and then REMOVED with the rest of the ambient
population before the dump: what is pinned byte-wise is the settled world (station, hermits,
player, market), while the draw-dependent cast is pinned only by its COUNT, which the script's
own literals fix. The populator is switched off and proven off before the dump (scenario 001's
finding), the game is paused and the world is asserted at rest.

FRAME, AND THE DELIBERATE ASYMMETRY
===================================
A 64x64 luminance grid is stored BESIDE the dump as `frame.grid`, never inside it: llvmpipe is
not bit-reproducible across runs, so the grid is compared with the tolerance bead oo-ae9 MEASURED
and is NEVER byte-hashed. The dump IS byte-hashed, and its sha256 and byte count live in
`provenance.json` - a SEPARATE file - because a golden compared against a copy of itself moves
both sides when edited and cannot see a one-quantised-unit perturbation (bead oo-gxp).
"""

import argparse
import json
import os
import plistlib
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

SCENARIO = "005-mission-trigger"

# Blessed path FIRST, pending path second, through the IDENTICAL idiom, so landing these files
# into the guarded goldens/ tree is a pure `git mv` with no code change (bead oo-3ya).
SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "tests", "golden", "scenarios", SCENARIO, "spec.json"),
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

MIN_SAVE_BYTES = 1024
TICK_WALL_BUDGET_SECONDS = 120
FRAME_SETTLE_SECONDS = 1.0
SETTLE_TIMEOUT_SECONDS = 90


class ScenarioError(RuntimeError):
    pass


class Refusal(RuntimeError):
    """The run could not be performed soundly, so no verdict is given (rc=2)."""


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise Refusal("no %s found; looked in %s" % (what, " and ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for %s" % SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for %s" % SCENARIO)


def frame_path():
    return _first_existing(FRAME_CANDIDATES, "stored reference frame grid for %s" % SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def save_path(spec):
    """The save this scenario is ABOUT. Spelled with the literal key so the knob pin in
    test_mission_trigger.py can see it: a knob reached only through a variable subscript is a knob
    no reader - and no test - can confirm is read."""
    return golden_run._slashes(os.path.join(REPO_ROOT, *spec["load_save"].split("/")))


def control_save_path(spec):
    """The DIFFERENTIAL control arm's save. Same reason for the literal key."""
    return golden_run._slashes(os.path.join(REPO_ROOT, *spec["control_save"].split("/")))


def read_save_file(path):
    """Parse the .oolite-save and PROVE it is worth loading. Every failure here is a REFUSAL."""
    if not os.path.isfile(path):
        raise Refusal(
            "the save file %s DOES NOT EXIST. A scenario that loads nothing and compares the "
            "result against a golden taken the same way agrees with itself for ever." % path)
    size = os.path.getsize(path)
    if size < MIN_SAVE_BYTES:
        raise Refusal(
            "the save file %s is %d bytes, under the %d-byte floor; a stub save parses to few or "
            "no keys and every mission-state assertion against it is vacuous."
            % (path, size, MIN_SAVE_BYTES))
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:  # noqa: BLE001 - any parse failure is a refusal, not a difference
        raise Refusal("%s is not a readable property list: %s: %s" % (path, type(exc).__name__, exc))
    if not isinstance(data, dict) or "mission_variables" not in data:
        raise Refusal("%s carries no mission_variables dict; it is not a checklist mission save"
                      % path)
    return data, size


def file_counter(plist, spec):
    """The counter's value ON DISK. The engine's value is read separately and must differ by +1.

    Absent is reported as None rather than raised: the CONTROL arm's save legitimately has no
    counter, and that absence is one of the fields the differential reports as moved.
    """
    raw = (plist.get("mission_variables") or {}).get(spec["mission_variable_key_in_file"])
    if raw is None:
        return None
    try:
        return int(str(raw))
    except ValueError:
        raise Refusal("%s in the save file is %r, which is not an integer; the +1 assertion this "
                      "scenario is built on cannot be evaluated"
                      % (spec["mission_variable_key_in_file"], raw))


def _js_json(console, expr):
    raw = console.evaluate(expr).strip()
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the game answered %r for %s, which is not JSON (%s)" % (raw, expr, exc))


def read_trigger_state(console, spec, require_script=True):
    """Read the MISSION TRIGGER's three observables out of the LIVE engine, before any clearing.

    1. `missionVariables` enumerated - the state after the world-script event ran.
    2. `system.populatorSettings` keys - the ambush populator the mission script REGISTERED.
    3. the role counts of the ships that populator spawned.

    `require_script=False` is for the FRESH control arm only: with no `-load` the world scripts
    are never built, so `worldScripts[...]` is `undefined`. That is a third way the fresh arm
    differs and it is RECORDED, not raised - a control's purpose is to differ.
    """
    mission_vars = _js_json(console, "(function(){ var o = {}, k;"
                                     " for (k in missionVariables) o[k] = missionVariables[k];"
                                     " return JSON.stringify(o); })()")
    if not isinstance(mission_vars, dict):
        raise ScenarioError("missionVariables enumerated to %r, not an object" % (mission_vars,))

    script = spec["mission_script_name"]
    script_type = console.evaluate("typeof worldScripts[%s]" % json.dumps(script)).strip()
    loaded = script_type == "object"
    if not loaded and require_script:
        raise ScenarioError(
            "worldScripts[%r] is %r, not a live object: the stock cloaking-device mission script "
            "is not loaded, so no world-script event of it can have fired" % (script, script_type))

    live = []
    if loaded:
        live = _js_json(console, "(function(){ var s = worldScripts[%s], out = [], k, want = %s;"
                                 " for (k = 0; k < want.length; k++)"
                                 "   if (typeof s[want[k]] === 'function') out.push(want[k]);"
                                 " return JSON.stringify(out); })()"
                        % (json.dumps(script),
                           json.dumps(list(spec["expected_live_mission_handlers"]))))

    populators = _js_json(console, "(function(){ var out = [], k;"
                                   " for (k in system.populatorSettings) out.push(k);"
                                   " return JSON.stringify(out.sort()); })()")
    counts = {}
    for role in spec["expected_spawned_roles"]:
        counts[role] = console.evaluate_int("system.countShipsWithRole(%s)" % json.dumps(role))

    key = spec["mission_variable_key"]
    counter = mission_vars.get(key)
    return {
        "mission_variables": mission_vars,
        "mission_variable_names": sorted(mission_vars),
        "mission_counter_key": key,
        "mission_counter_in_engine": counter,
        "mission_counter_present": key in mission_vars,
        "mission_script": script,
        "mission_script_loaded": loaded,
        "live_mission_handlers": sorted(live),
        "ambush_populator": spec["expected_populator_key"],
        "ambush_populator_registered": spec["expected_populator_key"] in populators,
        "spawned_role_counts": counts,
    }


def assert_loaded(console, spec, plist):
    """Positive proof the SAVE was loaded, before anything else is measured.

    A game that ignored -load sits on the intro screen as Jameson in Lave with an EMPTY
    missionVariables. It answers every JS probe, so every probe-SHAPED check passes on it.
    """
    evidence = {}
    for js, key, want in (("player.name", "commander_name", str(plist["player_name"])),
                          ("system.name", "system_name", str(plist["current_system_name"]))):
        got = console.evaluate(js).strip()
        evidence[key] = got
        if got != want:
            raise ScenarioError(
                "%s is %r but the save file names %r: the save was not loaded, so the state being "
                "dumped is not the saved state" % (js, got, want))

    evidence["galaxy_number"] = console.evaluate_int("galaxyNumber")
    if evidence["galaxy_number"] != int(plist["galaxy_number"]):
        raise ScenarioError("galaxyNumber is %d but the save names %d"
                            % (evidence["galaxy_number"], int(plist["galaxy_number"])))

    evidence["score"] = console.evaluate_int("player.score")
    if evidence["score"] != int(plist["ship_kills"]):
        raise ScenarioError("player.score is %d but the save's ship_kills is %d"
                            % (evidence["score"], int(plist["ship_kills"])))

    # clock.seconds is [player clockTime] - the value ship_clock restores. NOT
    # clock.absoluteSeconds, which is the seconds THIS session has run (bead oo-8ij).
    want_clock = float(plist["ship_clock"])
    got_clock = float(console.evaluate("clock.seconds"))
    evidence["saved_ship_clock"] = round(want_clock, 3)
    evidence["clock_at_or_past_save"] = bool(got_clock >= want_clock)
    if not evidence["clock_at_or_past_save"]:
        raise ScenarioError(
            "clock.seconds (the PLAYER clock) is %.3f, BEFORE the save's own ship_clock %.3f: the "
            "game did not adopt the saved clock" % (got_clock, want_clock))

    evidence["save_format_version"] = str(plist.get("written_by_version", ""))
    evidence["docked"] = console.evaluate("player.ship.docked").strip().lower() == "true"
    if not evidence["docked"]:
        raise ScenarioError(
            "the player is not docked. These saves are docked commanders and the frame is the "
            "docked status screen; undocked, the camera is wherever the ship drifted to.")
    return evidence


def suppress_populators(console):
    """Switch the system populator OFF and PROVE it is off (scenario 001's finding).

    Read AFTER the trigger observables, never before: this call deletes the very populator key
    the mission script registered, which is one of the three things the scenario measures.
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
            "%s populator setting(s) survived suppression; the system will keep adding traffic, so "
            "the dump records ambient population rather than the loaded save" % remaining)
    return [k for k in keys.split(",") if k]


CLEAR_PASSES = 8


def clear_system(console, passes=CLEAR_PASSES):
    """Remove every non-player, non-station ship, iterating TO A FIXED POINT.

    ONE PASS IS NOT ENOUGH IN THIS SCENARIO, measured: removing the cloaked Asp runs its
    death_actions, which drop an "Unusual cargo container" (primaryRole `cloaking-device`) INTO
    the system - so a single sweep reliably leaves exactly one entity behind and the run aborts
    with a message that sounds like ambient traffic and is not. Removal here CREATES entities, so
    clearing is a fixed point, not a single write (the same shape as scenario 001's settling
    finding).

    The ambush the mission script spawned is counted BEFORE this and removed BY this: its cast is
    chosen by a RANROT role draw, so it is pinned by COUNT (a literal in the mission script), not
    by identity. The main station is spared: removing it undocks the player.
    """
    removed = 0
    for _ in range(passes):
        removed += console.evaluate_int(
            "(function(){ var ships = system.allShips, n = 0;"
            " for (var i = 0; i < ships.length; i++) {"
            "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
            " return n; })()")
        remaining = console.evaluate_int(
            "(function(){ var ships = system.allShips, n = 0;"
            " for (var i = 0; i < ships.length; i++) {"
            "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
            " return n; })()")
        if not remaining:
            return removed
    raise ScenarioError(
        "%d non-station ship(s) still present after %d clearing passes; the world is not reaching "
        "a fixed point, so the dump would measure whatever the last pass happened to leave"
        % (remaining, passes))


def assert_at_rest(console):
    """The world must be genuinely still. An ASSERTION, not a write.

    `magnitude` IS A FUNCTION, NOT A PROPERTY - scenario 001 shipped a version comparing the
    function object with a number, which is always false. It is CALLED here.
    """
    moving = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()").strip()
    if moving:
        raise ScenarioError(
            "the game is paused but these entities still report motion: %s. Their values depend "
            "on the frame count and no two runs can reproduce them." % moving)
    return True


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` ticks of GAME time. Measured on the GAME's clock, never the harness's."""
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
        time.sleep(0.1)
    raise ScenarioError("the game clock did not advance %ss within %ss" % (seconds, timeout))


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot the current frame and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: on Windows the name shows up while the game still
    holds the handle open, so reading it then fails or, worse, hashes half a frame (bead oo-gxp).
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
                        "image is worse than no frame at all" % (png, type(last).__name__, last))


def assert_trigger_fired(evidence, spec):
    """THE POINT OF THIS SCENARIO: a mission script's world-script event handler RAN.

    Held at CAPTURE time here and again, independently, by check_mission_trigger_evidence.py
    against the stored dump - so a golden blessed before a clause existed cannot pass as if it had.
    """
    if evidence["commander_name"] != spec["expected_commander_name"]:
        raise ScenarioError("commander is %r, expected %r"
                            % (evidence["commander_name"], spec["expected_commander_name"]))
    if evidence["galaxy_number"] != int(spec["expected_galaxy_number"]):
        raise ScenarioError(
            "galaxyNumber is %r but this scenario needs %r. The trigger's own guard is "
            "`galaxyNumber === 4` (oolite-cloaking-device-mission.js:50), so in any other galaxy "
            "the handler returns without doing anything and this scenario measures nothing."
            % (evidence["galaxy_number"], spec["expected_galaxy_number"]))

    want_file = spec["expected_counter_in_file"]
    if evidence["mission_counter_in_file"] != want_file:
        raise ScenarioError(
            "the save file's %s is %r but the fixture pins %r. That EXACT value is load-bearing: "
            "the trigger fires only once the incremented counter exceeds 6."
            % (spec["mission_variable_key_in_file"], evidence["mission_counter_in_file"], want_file))

    got = evidence["mission_counter_in_engine"]
    want = evidence["mission_counter_in_file"] + 1
    if got != want:
        raise ScenarioError(
            "missionVariables.%s is %r in the running engine but the save file holds %r, so the "
            "expected post-trigger value is %r. THIS IS THE ASSERTION THE SCENARIO EXISTS FOR: a "
            "value the deserialiser merely copied reads the file's value; only the mission "
            "script's own `missionVariables.%s++` (oolite-cloaking-device-mission.js:62) produces "
            "file+1, so an unequal value means the world-script event did not run the handler."
            % (spec["mission_variable_key"], got, evidence["mission_counter_in_file"], want,
               spec["mission_variable_key"]))

    if not evidence["ambush_populator_registered"]:
        raise ScenarioError(
            "%r is not among the system's populator settings. The mission script registers it with "
            "system.setPopulator() inside the same `if` block as the counter increment "
            "(oolite-cloaking-device-mission.js:71-89), so its absence means the block did not run."
            % evidence["ambush_populator"])

    for role, want_count in sorted(spec["expected_spawned_roles"].items()):
        got_count = evidence["spawned_role_counts"].get(role)
        if got_count != want_count:
            raise ScenarioError(
                "system.countShipsWithRole(%r) is %r, expected %r. These ships are the ambush the "
                "populator callback spawns; their COUNT is fixed by literals in the mission script "
                "even though their cast is a RANROT role draw." % (role, got_count, want_count))

    if evidence["mission_variables"] != spec["expected_mission_variables"]:
        raise ScenarioError(
            "mission_variables is %r but the fixture's measured post-trigger set is %r. A fresh "
            "game's is EMPTY, so this clause alone rejects a run that never loaded a save."
            % (evidence["mission_variables"], spec["expected_mission_variables"]))

    want_handlers = sorted(spec["expected_live_mission_handlers"])
    if sorted(evidence["live_mission_handlers"]) != want_handlers:
        raise ScenarioError(
            "live_mission_handlers is %r but %r is the measured set. systemWillPopulate must still "
            "be a live function on the script object: `startUp` deletes it when the mission is "
            "already resolved (oolite-cloaking-device-mission.js:38-45), and a script with no "
            "handler cannot have been the thing that fired."
            % (sorted(evidence["live_mission_handlers"]), want_handlers))
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def probe(app_dir, spec, run_root, save=None, load=True, keep=False, tag="run",
          seed_override=None, ticks_override=None):
    """One game process on a PRIVATE port, its own debugConfig.plist and its own staged app dir."""
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s-%s" % (SCENARIO, tag, stamp)))
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
        plist = None
        if load:
            plist, save_bytes = read_save_file(save)
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=(save if load else None)))
        with console:
            if load:
                evidence = assert_loaded(console, spec, plist)
                evidence["save_file"] = os.path.basename(save)
                evidence["save_bytes"] = save_bytes
                evidence["mission_counter_in_file"] = file_counter(plist, spec)
            else:
                evidence = {
                    "commander_name": console.evaluate("player.name").strip(),
                    "system_name": console.evaluate("system.name").strip(),
                    "galaxy_number": console.evaluate_int("galaxyNumber"),
                    "score": console.evaluate_int("player.score"),
                    "save_file": None, "save_bytes": 0, "mission_counter_in_file": None,
                }
            evidence["system_id"] = console.evaluate_int("system.ID")
            # BEFORE suppression and clearing: suppress_populators() deletes the very key, and
            # clear_system() removes the very ships, that this scenario measures.
            evidence.update(read_trigger_state(console, spec, require_script=load))

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            evidence["ticks"] = ticks
            evidence["game_seconds_budget"] = round(ticks * float(spec["tick_seconds"]), 3)
            evidence["tick_budget_met"] = bool(elapsed >= evidence["game_seconds_budget"])

            settle(console)
            png, grid = capture_frame(console, artifact_dir)
            evidence["gui_screen"] = console.evaluate("guiScreen").strip()

            # Pause LAST and CHECK THE RETURN VALUE: GlobalPauseGame (OOJSGlobal.m:832-855)
            # returns NO without pausing on five GUI screens, and an unpaused dump records
            # whatever the world drifted to.
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s), so the "
                    "dump would keep integrating and no two runs could agree"
                    % console.evaluate("guiScreen").strip())

            suppressed = suppress_populators(console)
            clear_system(console)
            assert_at_rest(console)
            dump = json.loads(dump_state(console))

        evidence["populators_suppressed"] = len(suppressed)
        evidence["seed"] = seed
        evidence["scenario"] = SCENARIO
        return {"evidence": evidence, "dump": dump, "grid": grid, "png": png, "port": port,
                "wall_seconds": round(time.time() - started, 1), "artifact_dir": artifact_dir}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


def run(app_dir, spec, run_root, out_path=None, frame_out=None, keep=False, save=None,
        load=True, check_state=True, seed_override=None, ticks_override=None, tag="run"):
    result = probe(app_dir, spec, run_root, save=save, load=load, keep=keep, tag=tag,
                   seed_override=seed_override, ticks_override=ticks_override)
    if check_state:
        if result["evidence"]["system_id"] != int(spec["system_id"]):
            raise ScenarioError(
                "scenario %s is pinned to system ID %d (%s) but the run is in system ID %d"
                % (SCENARIO, int(spec["system_id"]), spec.get("system_name"),
                   result["evidence"]["system_id"]))
        assert_trigger_fired(result["evidence"], spec)

    state = dict(result["dump"])
    state["evidence"] = result["evidence"]
    # The bead asks for the mission variables IN THE DUMP, not only inside evidence: a consumer
    # reading the dump should not have to know the evidence schema.
    state["mission_variables"] = result["evidence"]["mission_variables"]
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
            handle.write(result["grid"])
    return {"ok": True, "out": out_path, "frame_out": frame_out, "bytes": len(text),
            "evidence": result["evidence"], "grid": result["grid"],
            "wall_seconds": result["wall_seconds"], "artifact_dir": result["artifact_dir"]}


# --- the differential control ------------------------------------------------------------------

DIFFERENTIAL_FIELDS = ("commander_name", "system_name", "system_id", "galaxy_number",
                       "mission_counter_in_engine", "mission_counter_present",
                       "ambush_populator_registered", "spawned_role_counts",
                       "mission_variable_names", "mission_script_loaded")


def differential(subject, control, subject_label, control_label):
    """Name the fields that MOVED between the two arms. An empty list is a failed control."""
    moved, same = [], []
    for field in DIFFERENTIAL_FIELDS:
        a, b = subject.get(field), control.get(field)
        (moved if a != b else same).append(
            "%s: %r (%s) vs %r (%s)" % (field, a, subject_label, b, control_label))
    return moved, same


def _grid_file(path):
    with open(path, "rb") as handle:
        return handle.read()


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/mission_trigger.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override spec seed (controls only)")
    parser.add_argument("--ticks", type=int, default=None, help="override spec ticks (controls)")
    parser.add_argument("--control", action="store_true",
                        help="DIFFERENTIAL ARM: load spec['control_save'] instead - the mission "
                             "script is loaded but its trigger's galaxy guard fails")
    parser.add_argument("--fresh-control", action="store_true",
                        help="DIFFERENTIAL ARM: launch with NO -load at all")
    parser.add_argument("--compare-frame", nargs=2, metavar=("A", "B"),
                        help="compare two stored 64x64 grids with the MEASURED tolerance")
    args = parser.parse_args(argv)

    if args.compare_frame:
        a, b = args.compare_frame
        try:
            ga, gb = _grid_file(a), _grid_file(b)
        except OSError as exc:
            sys.stderr.write("USAGE: %s\n" % exc)
            return 2
        tol = frame_hash.derive_tolerance()
        d = frame_hash.distance(ga, gb)
        print(json.dumps({"a": a, "b": b, "distance": d, "tolerance": tol,
                          "ratio": d / tol if tol else None, "within": bool(d <= tol),
                          "hash_a": frame_hash.hex_digest(ga),
                          "hash_b": frame_hash.hex_digest(gb)}, indent=2, sort_keys=True))
        return 0 if d <= tol else 1

    try:
        spec = load_spec()
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        sys.stderr.write("[!] no Oolite build; pass --app-dir or set OO_APP_DIR\n")
        return 2
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_rkm_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    load = not args.fresh_control
    if not load:
        save, tag = None, "fresh-control"
    elif args.control:
        save, tag = control_save_path(spec), "control"
    else:
        save, tag = save_path(spec), "run"
    # A control arm deliberately does NOT fire the trigger, so the trigger assertion is not
    # applied to it - its whole purpose is to differ.
    check_state = not (args.control or args.fresh_control)

    try:
        result = run(app_dir, spec, run_root, out_path=args.out, frame_out=args.frame_out,
                     keep=args.keep, save=save, load=load, check_state=check_state,
                     seed_override=args.seed, ticks_override=args.ticks, tag=tag)
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        sys.stderr.write("[!] %s: %s\n" % (type(exc).__name__, exc))
        return 3

    ev = result["evidence"]
    print("scenario %s: commander=%r system=%r(%s) galaxy=%s %s file=%r engine=%r populator=%s "
          "spawned=%s handlers=%s mission_vars=%d ticks=%s wall=%.1fs"
          % (SCENARIO, ev["commander_name"], ev["system_name"], ev["system_id"],
             ev.get("galaxy_number"), ev["mission_counter_key"], ev["mission_counter_in_file"],
             ev["mission_counter_in_engine"], ev["ambush_populator_registered"],
             ev["spawned_role_counts"], ev["live_mission_handlers"],
             len(ev["mission_variables"]), ev["ticks"], result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (%d bytes)" % (result["frame_out"], len(result["grid"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
