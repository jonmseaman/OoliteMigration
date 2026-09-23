"""Golden scenario 012-retro-missions: load the in-tree RetroMissions test-OXP, prove its content
is LIVE inside the running game, run a FIXED number of game ticks, and emit a canonical dump.

WHY THIS SCENARIO EXISTS
------------------------
Scenario 001 (`tests/golden/launch_dock.py`, bead oo-jor) is the exemplar: fixed seed, fixed
system, fixed tick count, a canonical dump, and an evidence block the stored golden carries. This
scenario copies that shape and points it at an EXPANSION instead of at the player's flight.

WHAT "RETROMISSIONS IS LIVE" MEANS HERE, AND WHY A DEAD RUN CANNOT FAKE IT
-------------------------------------------------------------------------
Being named in `[searchPaths.dumpAll]` proves only that ResourceManager accepted a DIRECTORY. It
does not prove any of the expansion's content was parsed, merged or executed. So the evidence in
this dump is one step further in:

  `evidence.oxp_world_scripts` is the list of world-script names that exist in the RUNNING game's
  `worldScripts` object and do NOT exist in a stock game. A name gets there only if

    1. the OXP's directory was accepted as a resource path, AND
    2. its `Config/world-scripts.plist` was merged into the game's world-script list, AND
    3. the named script file was found, compiled by the JS engine, and INSTANTIATED as a live
       script object (Universe.m loads world scripts through OOScript/ResourceManager at startup).

  A run that crashed in display init, or that had the OXP on the search path but failed to parse
  it, has an EMPTY list here. The baseline of stock names is not guessed: it is pinned in
  spec.json as `stock_world_scripts`, MEASURED by running this same scenario with `--no-oxp`
  (which stages nothing), so the difference is attributable to RetroMissions and to nothing else.

  `evidence.oxp_script_versions` reads a PROPERTY off each of those live script objects
  (`worldScripts[name].version`). A name in a list could in principle be a stale key; a property
  read succeeds only against a real JS object the engine constructed.

  `evidence.ticks` / `tick_budget_met` come from `clock.absoluteSeconds` INSIDE the game, so a
  frozen or crashed run cannot satisfy them.

THE MISSING manifest.plist IS TOLERATED EXPLICITLY, NOT IGNORED (bead oo-kcrw)
-----------------------------------------------------------------------------
RetroMissions is one of five in-tree legacy test fixtures that predate the manifest format. It
ships no manifest.plist and the engine emits exactly TWO
`[oxp-standards.error]: OXP ... has no manifest.plist` lines on every load. oo-kcrw classified
that as NOMANIF - a fixture property, not a defect - and gated the state on positive proof of
loading AND on the errors being EXCLUSIVELY that message at that exact count.

This scenario follows that standard rather than weakening the predicate:

  * no manifest is staged (writing one would falsify the fixture and would be editing expansion
    content);
  * `oxp_standards_errors` records the COUNT of `[oxp-standards.error]` lines in the run's own
    Latest.log, and `oxp_standards_error_signatures` records the DISTINCT normalised messages
    (the volatile staged path is replaced by the OXP's basename, because the staging directory
    carries a timestamp and a pid);
  * `assert_ran()` refuses to dump unless the count is EXACTLY `spec["allowed_oxp_standards_
    errors"]` and every signature is in `spec["allowed_oxp_standards_error_signatures"]`.

So a THIRD such line, or a DIFFERENT error, fails the run. The allowance is a pin, not a mute.

DETERMINISM AND ISOLATION
-------------------------
Identical to 001, and for the same measured reasons: a reserved port plus a debugConfig.plist in a
private OO_ADDITIONALADDONSDIRS (the game DIALS OUT to the port named there, OODebugSupport.m:67-80
- a run on the shared 8563 can be captured and quit by a sibling worker's console while still
exiting rc=0, bead oo-het); the populator switched off at the source before anything is measured;
the world asserted at rest under a CHECKED pauseGame(); the tick budget measured on the game clock.

This scenario never launches the player. It is the smallest world in which the question "did the
expansion's content go live" can be asked, which is exactly what a golden wants.
"""

import argparse
import json
import os
import re
import shutil
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
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "012-retro-missions"

# The spec lives under tests/golden/scenarios/<SCENARIO>/ once Jon has approved the protected-path
# addition (tools/rebless-approvals.txt). Until then it is staged under tests/golden/pending/, and
# BOTH locations are searched so that landing it is a pure `git mv` with no code change. See
# tests/golden/pending/012-retro-missions/LANDING.md.
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)

TICK_WALL_BUDGET_SECONDS = 300

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")


class ScenarioError(RuntimeError):
    pass


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise ScenarioError("no %s found; looked in: %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for scenario %s" % SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for scenario %s" % SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def oxp_source(spec):
    src = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    if not os.path.isdir(src):
        raise ScenarioError(
            "the test-OXP this scenario is about is not in the tree at %s; a run staging nothing "
            "would still load the game and would dump a world with no expansion in it" % src)
    return src


def stage_oxp(spec, addons_dir):
    """Copy the expansion into a private addons root and return its staged path.

    A COPY, not a junction: the game writes nothing here, but the staged root is deleted at the
    end of the run and unstage must never follow a link into the tracked tree.

    THE DIRECTORY IS CALLED `oxp-stage`, NOT `addons`, AND THAT IS LOAD-BEARING. The game also
    searches `<app dir>/../AddOns` by default, and the staged app lives at `<artifact>/app`, so a
    staging directory named `<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive
    filesystem. MEASURED: the expansion was then found at TWO roots and the run logged FOUR
    `[oxp-standards.error]: ... has no manifest.plist` lines (two per root) instead of the two
    bead oo-kcrw records. The exact-count guard in assert_ran() is what caught it - a guard that
    merely allowed "some missing-manifest errors" would have blessed a golden taken with the
    expansion loaded twice.
    """
    src = oxp_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    return golden_run._slashes(target)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def world_script_names(console):
    """The names of every live world script, sorted. Read from the RUNNING game.

    Returned as JSON rather than as a joined string: the console transport is an XML property
    list, and a MEASURED attempt to use U+0001 as a separator came back as the literal text
    '\\U0001' (plist escaping), which would have silently collapsed 16 names into one.
    """
    raw = console.evaluate(
        "(function(){ var n = Object.keys(worldScripts); n.sort();"
        " return JSON.stringify(n); })()").strip()
    try:
        names = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("worldScripts did not come back as JSON (%s): %r" % (exc, raw[:200]))
    if not isinstance(names, list):
        raise ScenarioError("worldScripts came back as %r, not a list" % (names,))
    return names


def world_script_versions(console, names):
    """Split `names` into scripts that resolve to a LIVE JS object and those that do not.

    MEASURED, and the split is real engine behaviour rather than a defensive branch. RetroMissions
    contributes six world-script names. Probing each one in a running game:

        ahruman-reaper    typeof "object"    .name "ahruman-reaper"   .version "1"
        cloaking-device   typeof "undefined"
        constrictor_hunt  typeof "undefined"
        nova              typeof "undefined"
        thargoid_plans    typeof "undefined"
        trumbles          typeof "undefined"

    The five undefined ones are the expansion's LEGACY scripts - they come from
    `Scripts/oolite-legacy-scripts.plist`, which the engine logs as deprecated - and they
    enumerate as keys of `worldScripts` without being addressable as JS objects. `ahruman-reaper`
    is the expansion's own .js world script and is a fully live object.

    Both halves are returned and both are stored, because they measure different things: the
    NAMES prove the expansion's world-scripts list was merged, and the VERSION read proves a
    script file was found, compiled and instantiated. Collapsing the two would let a run pass on
    key enumeration alone.
    """
    live, key_only = {}, []
    for name in names:
        expr = ("(function(){ var s = worldScripts[%s];"
                " if (!s) return 'OO3YA-KEY-ONLY';"
                " return String(s.version); })()" % json.dumps(name))
        value = console.evaluate(expr).strip()
        if value == "OO3YA-KEY-ONLY":
            key_only.append(name)
        else:
            live[name] = value
    return live, sorted(key_only)


def suppress_populators(console):
    """Switch the system populator off at the source (copied from scenario 001).

    `system.setPopulator(key, null)` deletes a populator setting (OOJSSystem.m:1311). The
    populator keeps adding traffic while the scenario runs and every ship it adds consumes RANROT
    draws, so a fixed seed fixes the SEQUENCE but not how far a wall-clock-timed run has got
    through it (bead oo-jor).
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
            "during the run, consuming a per-run-variable number of RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship (copied from scenario 001)."""
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


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time and return the elapsed game seconds."""
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


def normalise_oxp_error(message, oxp_basename):
    """Replace the volatile staged path with the OXP's basename.

    The staged addons root carries a timestamp, a port and a pid, so the raw message differs on
    every run by construction. Only the path is replaced; the rest of the message is compared
    VERBATIM, so a different error at the same path does not match the allow-list.
    """
    return re.sub(r"\S*%s" % re.escape(oxp_basename), oxp_basename, message).strip()


def read_oxp_standards_errors(artifact_dir, oxp_basename):
    """Collect every [oxp-standards.error] line from THIS run's own Latest.log."""
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so the claim that the expansion's only "
            "errors are the known missing-manifest pair cannot be checked at all" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    found = [normalise_oxp_error(m.group(1), oxp_basename)
             for m in OXP_STANDARDS_RE.finditer(text)]
    return found, len(text)


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied before anything is written.

    Every clause names a field the dump carries, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    if not evidence["oxp_staged"]:
        raise ScenarioError("evidence.oxp_staged is false: nothing was staged, so this run says "
                            "nothing about the expansion")
    if not evidence["oxp_world_scripts"]:
        raise ScenarioError(
            "evidence.oxp_world_scripts is empty: the running game has no world script that a "
            "stock game lacks, so RetroMissions' Config/world-scripts.plist was never merged and "
            "its scripts were never instantiated. The OXP being on the search path is not the "
            "same as its content being live.")
    expected = sorted(spec["expected_oxp_world_scripts"])
    if sorted(evidence["oxp_world_scripts"]) != expected:
        raise ScenarioError(
            "evidence.oxp_world_scripts is %r but the spec pins %r. A golden taken against a "
            "different set of expansion scripts is not comparable with the stored one."
            % (sorted(evidence["oxp_world_scripts"]), expected))
    expected_live = spec["expected_live_script_versions"]
    if evidence["oxp_script_versions"] != expected_live:
        raise ScenarioError(
            "evidence.oxp_script_versions is %r but the spec pins %r. This is the read that "
            "proves a script FILE was found, compiled and instantiated - a name in "
            "oxp_world_scripts only proves the world-scripts list was merged."
            % (evidence["oxp_script_versions"], expected_live))
    if not evidence["oxp_script_versions"]:
        raise ScenarioError(
            "evidence.oxp_script_versions is empty: not one of the expansion's world-script names "
            "resolved to a live JS object, so nothing was instantiated and the names are bare "
            "keys")
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))

    allowed_count = int(spec["allowed_oxp_standards_errors"])
    allowed = set(spec["allowed_oxp_standards_error_signatures"])
    if evidence["oxp_standards_errors"] != allowed_count:
        raise ScenarioError(
            "evidence.oxp_standards_errors is %d but exactly %d is allowed for this fixture "
            "(bead oo-kcrw: RetroMissions is NOMANIF - it predates the manifest format and emits "
            "exactly %d '[oxp-standards.error]' lines). A different count means a NEW problem, "
            "and widening this number to make the run pass is forbidden. Signatures seen: %r"
            % (evidence["oxp_standards_errors"], allowed_count, allowed_count,
               evidence["oxp_standards_error_signatures"]))
    unexpected = [s for s in evidence["oxp_standards_error_signatures"] if s not in allowed]
    if unexpected:
        raise ScenarioError(
            "the run emitted an [oxp-standards.error] line that is NOT the known missing-manifest "
            "message: %r. The allow-list is %r and it is deliberately exact - a third or "
            "different error is a finding, not noise." % (unexpected, sorted(allowed)))


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, stage=True, empty_stage=False,
        seed_override=None, ticks_override=None):
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    oxp_basename = os.path.basename(spec["oxp_source"].rstrip("/"))

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-stage"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    # `empty_stage` is the NARROW mutant (see --empty-stage): the staging root exists and is on
    # OO_ADDITIONALADDONSDIRS, but the expansion has been removed from it. It is narrower than
    # --no-oxp on purpose - oxp_staged stays true, so the run gets past the staging assertion and
    # trips the assertion that is actually under test, the one about the expansion's content
    # being live. A mutant applied above the assertion you mean to exercise short-circuits it
    # (bead oo-vwd).
    if empty_stage:
        os.makedirs(addons_dir, exist_ok=True)
        staged_oxp = None
    else:
        staged_oxp = stage_oxp(spec, addons_dir) if stage else None

    roots = [config_dir] + ([addons_dir] if stage or empty_stage else [])
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots + ([previous] if previous else []))
    started = time.time()
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            assert_system(console, spec)
            names = world_script_names(console)
            stock = set(spec["stock_world_scripts"])
            oxp_names = sorted(n for n in names if n not in stock)
            versions, key_only = world_script_versions(console, oxp_names)

            suppressed = suppress_populators(console)
            clear_system(console)
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # Pause LAST and CHECK THE RETURN VALUE: GlobalPauseGame (OOJSGlobal.m:831-856)
            # returns NO without pausing on the chart/mission/report/keyboard/save screens, and an
            # unchecked pause turns a deterministic scenario into a stopwatch (bead oo-jor).
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The "
                    "simulation would keep integrating through the dump and no two runs could "
                    "agree." % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))

            clear_system(console)
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned "
                    "true; the world is NOT frozen, so the dump is a stopwatch reading and no two "
                    "runs can agree" % (clock_after - clock_before, clock_before, clock_after))

            # `magnitude` IS A FUNCTION, NOT A PROPERTY - calling it is what makes this guard able
            # to fail at all (bead oo-jor measured a version that compared a function object with
            # a number and therefore passed on every run).
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

            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        signatures, log_bytes = read_oxp_standards_errors(artifact_dir, oxp_basename)

        evidence = {
            "scenario": SCENARIO,
            "oxp_staged": bool(stage or empty_stage),
            "oxp_basename": oxp_basename,
            "oxp_world_scripts": oxp_names,
            "oxp_script_versions": versions,
            "oxp_key_only_scripts": key_only,
            "oxp_standards_errors": len(signatures),
            "oxp_standards_error_signatures": sorted(set(signatures)),
            # The BUDGET is pinned; the measured elapsed time is NOT in the dump on purpose - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor). The assertion keeps full strength as a
            # boolean and the raw float is reported on stdout by the CLI.
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
        }
        assert_ran(evidence, spec)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        return {"ok": True, "out": out_path, "port": port, "staged_oxp": staged_oxp,
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "log_bytes": log_bytes, "game_seconds_elapsed": round(elapsed, 3),
                "evidence": evidence}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
            shutil.rmtree(addons_dir, ignore_errors=True)
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
    parser = argparse.ArgumentParser(prog="tests/golden/retro_missions.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--empty-stage", action="store_true",
                        help="MUTANT: create the staging directory but REMOVE the expansion from "
                             "it. Narrower than --no-oxp: the run reaches and trips the "
                             "expansion-content evidence assertion rather than the staging one.")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT: stage no expansion. The run must then FAIL its own evidence "
                             "assertions; used to prove the gate can go red, and to MEASURE the "
                             "stock world-script baseline pinned in spec.json.")
    parser.add_argument("--probe-world-scripts", action="store_true",
                        help="print the live world-script names and exit 0 without dumping; used "
                             "once, to measure the baseline the spec pins.")
    args = parser.parse_args(argv)

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_3ya_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.probe_world_scripts:
        return _probe(app_dir, spec, run_root, stage=not args.no_oxp)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     stage=not (args.no_oxp or args.empty_stage),
                     empty_stage=args.empty_stage,
                     seed_override=args.seed, ticks_override=args.ticks)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def _probe(app_dir, spec, run_root, stage):
    """One launch, print the live world-script names and the oxp-standards lines, exit.

    This is the MEASUREMENT behind spec.json's `stock_world_scripts` and
    `allowed_oxp_standards_error_signatures`: both were read out of a running game rather than
    guessed, and `--no-oxp --probe-world-scripts` is the control that makes the difference
    attributable to RetroMissions.
    """
    from console import DebugConsole  # noqa: E402

    oxp_basename = os.path.basename(spec["oxp_source"].rstrip("/"))
    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "probe-%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, stamp))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-stage"))
    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    if stage:
        stage_oxp(spec, addons_dir)
    roots = [config_dir] + ([addons_dir] if stage else [])
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots + ([previous] if previous else []))
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=int(spec["seed"]), output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            names = world_script_names(console)
            system_id = console.evaluate_int("system.ID")
            stock = set(spec["stock_world_scripts"])
            live, key_only = world_script_versions(
                console, sorted(n for n in names if n not in stock))
        signatures, log_bytes = read_oxp_standards_errors(artifact_dir, oxp_basename)
        json.dump({"staged": stage, "system_id": system_id, "world_scripts": names,
                   "live_script_versions": live, "key_only_scripts": key_only,
                   "oxp_standards_errors": len(signatures),
                   "oxp_standards_error_signatures": sorted(set(signatures)),
                   "log_bytes": log_bytes, "artifact_dir": artifact_dir},
                  sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        golden_run.unstage_app(staged)
        shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


if __name__ == "__main__":
    sys.exit(main())
