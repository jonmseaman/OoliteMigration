"""Golden scenario 017: load the 1.75-era ThargoidPlans checklist save and pin its mission state.

WHAT THIS SCENARIO IS FOR
=========================
Bead oo-zyj1 asks for scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame
hash, blessed under the golden policy, 10-run stability) but STARTING FROM A SAVED GAME:
`upstream/oolite-tests/Checklist-files/Missions/ThargoidPlans.oolite-save`, loaded through the
game's own `-load` argument (console.py:121-122; parsed in src/SDL/main.m, dispatched by
GameController.m into PlayerEntityLoadSave.m:597). The save was written by Oolite 1.75
(`written_by_version` in the plist), so the scenario also pins the save-format compatibility
contract: a loader that stopped understanding a 1.75 file fails here by name.

It is scenario 015's design (bead oo-hv4d, the Trumbles fixture) applied to a DIFFERENT fixture,
and the interesting difference is not cosmetic - see the next section.

THE MISSION VARIABLES - MEASURED FIRST, THEN ASSERTED. THE DIFFERENCE FROM SCENARIO 015.
========================================================================================
Scenario 015's fixture carries `mission_trumbles` as the EMPTY STRING, and an ABSENT mission
variable reads identically to an empty one over the JS bridge, so that scenario could asserted
only a KEY SET - presence, never value. THIS FIXTURE WAS CHECKED BEFORE THE ASSERTION WAS
DESIGNED, and it is the other case: every one of its five mission variables holds a NON-EMPTY
string,

    mission_CT_thargonCount     '0'
    mission_conhunt             'MISSION_COMPLETE'
    mission_snoopers_CRCNews    '|'
    mission_snoopers_usedSlots  '0'
    mission_trumbles            'NOT_NOW'

so this scenario asserts the whole KEY->VALUE MAP (`evidence.mission_variables`), which is
strictly stronger: a key set is satisfied by any save carrying the same five names, whereas the
map pins `conhunt == MISSION_COMPLETE`, the flag that ARMS the Thargoid Plans mission. A fresh
commander has an EMPTY mission variable dictionary (PlayerEntity.m:1986-1987), so either form is
unsatisfiable by a run that ignored `-load`; the map is the form the data supports here and it is
used because it is available, not because it is prettier.

`mission_thargplans` IS NOT IN THIS FILE, AND THE FIXTURE'S POSITION WAS MEASURED, NOT ASSUMED.
The bead's prose names `mission_thargplans`. It is ABSENT from the save: the checklist fixture is
positioned BEFORE the mission starts. oolite-thargoid-plans-mission.js:77-90 arms the first
briefing on

    !missionVariables.thargplans && missionVariables.conhunt === "MISSION_COMPLETE"
        && player.score > 1280 && galaxyNumber === 2 && system.ID !== 83

FOUR of those five clauses hold here - no thargplans, conhunt complete, ship_kills 1281 (ONE over
the 1280 threshold), Quedle is system 147 rather than 83. THE FIFTH DOES NOT, and finding that out
changed this scenario's design. A first draft asserted `galaxyNumber === 2` on the assumption that
the JS field was 1-based over the plist's 0-based `galaxy_number` of 1. The live run returned
false. OOJSGlobal.m:190-191 resolves `galaxyNumber` to `[player currentGalaxyID]`, the SAME 0-based
index, so this save is in galaxy 1 and the mission runs in galaxy 2. The fixture carries
EQ_GAL_DRIVE and `has_galactic_hyperdrive`, so it sits ONE GALACTIC JUMP SHORT of the mission -
which is exactly the step the checklist asks a human tester to perform.

So the scenario records the arming clauses AS MEASURED (`evidence.thargplans_preconditions`, a
clause-by-clause map including the false one) rather than as a single "armed" boolean that would
have been wrong. That is a stronger statement about the fixture than a variable's value: an engine
that moved the fixture's galaxy, cleared `conhunt`, rounded the kill score across 1280, or started
the mission early goes red BY CLAUSE NAME. `evidence.thargplans_present` records whether the
loaded game carries the variable at all, and `mission_variables_stable_across_ticks` records that
nothing started it inside the budget - MEASURED both before and after the ticks.

ANTI-VACUITY: WHAT A FRESH COMMANDER CANNOT PRODUCE
====================================================
"The game started" is satisfiable by a run that ignored `-load`, and rc=0 plus an absence of ERROR
lines is satisfiable by a dead run (bead oo-het caught seven expansions that way). Every check is
POSITIVE and names state a DEFAULT NEW GAME CANNOT HAVE:

  1. `evidence.load_stages` - ENGINE-EMITTED, not inferred here. With `load.progress` switched on
     (see enable_load_logging) PlayerEntityLoadSave.m emits a fixed 14-stage sequence from
     "Reading file" to "Loading complete". Those lines exist ONLY inside `-loadPlayerFromFile:`,
     so a run that never loaded emits NONE of them and a load that died partway emits a PREFIX.
  2. `evidence.mission_variables` - the five-entry MAP above.
  3. `census` - fields read out of the FILE by Python's plist parser and out of the LIVE GAME by
     the JS API, in two processes sharing no code (scenario 006's invariant). Commander
     "ThargoidPlans", credits 99454.7, 1281 kills, system Quedle: none of them a default.
  4. `evidence.thargplans_preconditions` - the mission's own arming clauses, read live.

THE FRAME
=========
A frame is captured and stored (`frame.grid`, `frame.png`). It is NEVER byte-hashed into a
verdict: llvmpipe is not bit-reproducible (bead oo-ae9 measured 0 of 3 same-scene pairs
byte-identical). What it is asserted on is recorded in provenance.json and enforced by
gate_017_spec.py; see compare_frame below for the measured numbers behind that choice.

PORT / LAUNCH ISOLATION
=======================
golden_run.py wholesale, as scenarios 001/006/010/015 do: a reserved port, a staged app dir, and a
debugConfig.plist in a private OO_ADDITIONALADDONSDIRS, because the game DIALS OUT to the port
named in that plist (OODebugSupport.m:67-80). A run on the shared 8563 can be captured by a
sibling worker's console and quit four seconds in while still exiting rc=0 (bead oo-het).
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

SCENARIO = "017-thargoid-plans"

# The spec, golden, provenance and frame live under the guarded goldens/ tree once Jon has
# approved the protected-path addition (tools/rebless-approvals.txt). Until then they are staged
# under tests/golden/pending/, and BOTH locations are searched, so landing them is a pure
# `git mv` with no code change. Scenarios 010/012/015's arrangement, deliberately identical.
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

# A real .oolite-save is tens of kilobytes; this fixture is 25976. The floor exists only to reject
# a zero-byte or stub file, which parses to an empty mapping and makes every comparison vacuous.
MIN_SAVE_BYTES = 1024
MIN_CENSUS_FIELDS = 8

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
CLEAR_ROUNDS = 20


class ScenarioError(RuntimeError):
    pass


class Refusal(RuntimeError):
    """The comparison could not be performed soundly, so no verdict is given (rc=2)."""


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise ScenarioError("no %s found; searched: %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for " + SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for " + SCENARIO)


def frame_path():
    return _first_existing(FRAME_CANDIDATES, "stored frame grid for " + SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def save_path(spec):
    return golden_run._slashes(os.path.join(REPO_ROOT, *spec["load_save"].split("/")))


# --- the save file, and the two independent readers of it --------------------------------------

def read_save_file(path):
    """Parse the .oolite-save and PROVE it is worth comparing against.

    Every refusal here is a vacuity route, and they are refusals (rc=2, "I cannot tell you"),
    never differences (rc=1) - golden_diff.py's convention. A checker that answers "equal" when it
    could not actually compare is the most dangerous failure mode a gate can have.
    """
    if not os.path.isfile(path):
        raise Refusal(
            "the save file %s DOES NOT EXIST. There is nothing to load, so every check about "
            "'the loaded state' would be comparing the live game against an empty mapping."
            % path)
    size = os.path.getsize(path)
    if size < MIN_SAVE_BYTES:
        raise Refusal(
            "the save file %s is %d bytes, under the %d-byte floor. A stub or truncated save "
            "parses to few or no keys and a comparison against it is vacuous however green."
            % (path, size, MIN_SAVE_BYTES))
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:  # noqa: BLE001 - any parse failure is a refusal, not a difference
        raise Refusal("%s is not a readable property list: %s: %s"
                      % (path, type(exc).__name__, exc))
    if not isinstance(data, dict) or not data:
        raise Refusal("%s parsed to %r, which carries no commander data" % (path, type(data)))
    return data, size


def _normalise(value, kind):
    """The ONLY place a scale is applied, with no catch-all branch.

    `float_tenths` is measured, not a fudge: PlayerEntity stores credits and fuel as integers in
    tenths while the JS API reports whole units, so the file holds 994547 where JS reports 99454.7.
    An unknown kind raises rather than inventing a conversion.
    """
    if kind == "int":
        return int(value)
    if kind == "str":
        return str(value)
    if kind == "float_tenths":
        return round(float(value) / 10.0, 3)
    raise Refusal("census field declares unknown kind %r; refusing to invent a conversion" % kind)


def saved_census(spec, plist):
    """The LEFT side: read out of the file's own bytes by Python's plist parser."""
    out, missing = {}, []
    for field in spec["census"]:
        key = field["plist"]
        if key not in plist:
            missing.append(key)
            continue
        out[key] = _normalise(plist[key], field["kind"])
    if missing:
        raise Refusal(
            "the save file is missing %d census key(s) this scenario compares on: %s. The census "
            "describes a save this file is not." % (len(missing), ", ".join(missing)))
    return out


def apply_load_migrations(spec, census, plist):
    """Adjust the FILE-side census by the migrations the loader performs on a 1.75-era save.

    THE SAVE-FORMAT COMPATIBILITY CONTRACT, AS AN EXACT NUMBER RATHER THAN A TOLERANCE.
    This fixture carries `has_energy_bomb` and EQ_ENERGY_BOMB - equipment that no longer exists.
    PlayerEntity.m:1731-1746 migrates it at load time: it tries to mount an EQ_QC_MINE and,
    failing that (all four of this commander's pylons already hold EQ_HARDENED_MISSILE), does
    `credits += 9000` - 9000 DECIcredits, 900 credits - and logs the fact. So the loaded credits
    are NOT the saved credits, and MEASURED, the first live run of this scenario failed with
    `credits: 99454.7 (saved) != 100354.7 (loaded)`, which is this migration exactly.

    The delta is declared in the spec and added HERE, on the FILE side, so the round trip stays an
    EXACT equality. The alternative - widening credits to a tolerance - would have hidden any
    other credit bug of up to 900 credits, which is most of them.
    """
    applied = []
    for migration in spec["load_migrations"]:
        key = migration["plist"]
        if key not in census:
            continue
        field = next(f for f in spec["census"] if f["plist"] == key)
        census[key] = _normalise(int(plist[key]) + int(migration["delta"]), field["kind"])
        applied.append(key)
    return applied


def live_census(console, spec):
    """The RIGHT side: read out of the LIVE game, in a SEPARATE OS PROCESS, over the console."""
    out = {}
    for field in spec["census"]:
        raw = console.evaluate(field["js"]).strip()
        if raw == "" or raw.lower() in ("undefined", "null"):
            raise ScenarioError(
                "the game answered %r for census field %s (%s); an absent value would compare "
                "unequal for a reason about the probe rather than about the load."
                % (raw, field["plist"], field["js"]))
        kind = field["kind"]
        if kind == "int":
            out[field["plist"]] = int(float(raw))
        elif kind == "str":
            out[field["plist"]] = str(raw)
        elif kind == "float_tenths":
            out[field["plist"]] = round(float(raw), 3)
        else:
            raise Refusal("census field declares unknown kind %r" % kind)
    return out


def assert_non_vacuous(census, label):
    if len(census) < MIN_CENSUS_FIELDS:
        raise Refusal(
            "%s carries %d field(s), fewer than the %d minimum. A short census is the empty-state "
            "vacuity route wearing a smaller hat." % (label, len(census), MIN_CENSUS_FIELDS))
    populated = [k for k, v in census.items() if v not in ("", 0, 0.0, None)]
    if len(populated) < MIN_CENSUS_FIELDS // 2:
        raise Refusal(
            "%s has only %d non-empty value(s) out of %d: %r. A census of zeros and empty strings "
            "compares equal to any other empty census." % (label, len(populated), len(census),
                                                           census))
    return len(census), len(populated)


def compare_census(left, right, left_label, right_label):
    """Refuses by IDENTITY, not equality: a mapping always equals itself, which is the in-memory
    twin of golden_diff.py's st_dev/st_ino guard. `left == right` is the ANSWER, so using it as
    the guard would refuse every correct load."""
    if left is right:
        raise Refusal(
            "both sides of the comparison are the SAME object in memory (id=%d); this comparison "
            "could never fail." % id(left))
    problems = []
    for key in sorted(set(left) | set(right)):
        if key not in left:
            problems.append("%s: <absent in %s> != %r" % (key, left_label, right[key]))
        elif key not in right:
            problems.append("%s: %r != <absent in %s>" % (key, left[key], right_label))
        elif left[key] != right[key]:
            problems.append("%s: %r (%s) != %r (%s)"
                            % (key, left[key], left_label, right[key], right_label))
    return problems


def saved_mission_variables(plist):
    """The save's OWN mission variable map, with the engine's `mission_` prefix stripped.

    OOJSMissionVariables.m:191-193 strips the prefix for JS, so the plist's `mission_conhunt` is
    `missionVariables.conhunt`. Returned as a MAP because every value in this fixture is a
    NON-EMPTY string - checked before the assertion was designed, and the reason this scenario can
    assert values where scenario 015 could only assert a key set.
    """
    raw = plist.get("mission_variables")
    if not isinstance(raw, dict) or not raw:
        raise Refusal(
            "the save's `mission_variables` value is %r, not a non-empty mapping. This scenario "
            "exists to pin the loaded mission state; a fixture with no mission variables cannot "
            "carry that claim and every comparison about it would be vacuous." % (raw,))
    out = {}
    for key, value in raw.items():
        name = key[len("mission_"):] if key.startswith("mission_") else key
        out[name] = str(value)
    empties = sorted(k for k, v in out.items() if v == "")
    if empties:
        raise Refusal(
            "mission variable(s) %r in this fixture hold the EMPTY STRING. An absent mission "
            "variable reads identically to an empty one over the JS bridge, so a VALUE assertion "
            "on them would be satisfied by a game that had never heard of the mission. This "
            "scenario asserts the whole map precisely because THIS fixture has no empty values; "
            "if that changes, fall back to a key-set assertion (scenario 015's shape) rather than "
            "keeping a check that cannot fail." % (empties,))
    return out


# --- the live game -----------------------------------------------------------------------------

def enable_load_logging(config_dir, spec):
    """Write a logcontrol.plist into the private resource root switching the load channels ON.

    THE EVIDENCE MUST COME FROM THE ENGINE, and `load.progress` is OFF by default
    (Resources/Config/logcontrol.plist:241 `load.progress = no`). It cannot be switched on from
    the console the way texture channels are in scenario 010, because the whole load happens
    BEFORE the debug console connects - by the time a JS call could run, "Loading complete" has
    already been printed. ResourceManager.m:1761-1777 merges a logcontrol.plist found in any ROOT
    path over the built-in copy, and OO_ADDITIONALADDONSDIRS entries are root paths, so the same
    private directory that carries debugConfig.plist carries this too.
    """
    config = os.path.join(config_dir, "Config")
    os.makedirs(config, exist_ok=True)
    path = os.path.join(config, "logcontrol.plist")
    with open(path, "wb") as handle:
        plistlib.dump({channel: "yes" for channel in spec["log_channels"]}, handle,
                      fmt=plistlib.FMT_XML)
    return path


def read_load_evidence(artifact_dir, spec):
    """Pull the ENGINE's own load trace out of THIS run's Latest.log.

    Returns (ordered stage list, load failure lines, upgrade messages, log size). The stages are
    the literal strings PlayerEntityLoadSave.m logs; the scenario requires the whole ordered
    sequence, so a load that died halfway is a different list and fails by name. The upgrade
    messages are the engine's OWN record of the 1.75 format migrations (PlayerEntity.m:1731-1746)
    and are what makes the adjusted census arithmetic falsifiable rather than a fudge factor.
    """
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log at all, so the engine's own load evidence "
            "cannot be checked and rc=0 would mean nothing." % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    stages, failures, upgrades = [], [], []
    channel = "[%s]:" % spec["load_migrations"][0]["log_channel"]
    for line in text.splitlines():
        stripped = line.strip()
        if "[load.progress]:" in stripped:
            stages.append(stripped.split("[load.progress]:", 1)[1].strip())
        elif "[load.failed]" in stripped:
            failures.append(stripped)
        elif channel in stripped:
            upgrades.append(stripped.split(channel, 1)[1].strip())
    return stages, failures, upgrades, len(text)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))
    return got


def mission_variables(console):
    """The live mission variable MAP, read from the game as JSON.

    Every value in this fixture is a NON-EMPTY string (see the module docstring), which is what
    makes a VALUE assertion meaningful here where scenario 015 could only assert presence.
    """
    raw = console.evaluate(
        "(function(){ var o = {}; for (var k in missionVariables)"
        " o[k] = String(missionVariables[k]); return JSON.stringify(o); })()").strip()
    try:
        parsed = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the live mission variable map came back unparseable (%s): %r"
                            % (exc, raw[:200]))
    return parsed


def thargplans_preconditions(console, spec):
    """The Thargoid Plans mission's own arming clauses, read LIVE, one at a time.

    oolite-thargoid-plans-mission.js:77-90 opens the first briefing when
    `!missionVariables.thargplans && missionVariables.conhunt === "MISSION_COMPLETE" &&
    player.score > 1280 && galaxyNumber === 2 && system.ID !== 83`. This fixture was BUILT to sit
    at that moment - 1281 kills is one over the threshold - so the clauses are recorded as
    evidence. They are read through the SAME JS expressions the mission script uses, not
    re-derived from the plist, so a loader that restored the file but not the runtime state fails
    here.
    """
    out = {}
    for name, expr in sorted(spec["thargplans_precondition_probes"].items()):
        raw = console.evaluate(expr).strip()
        if raw == "" or raw.lower() in ("undefined", "null"):
            raise ScenarioError(
                "the game answered %r for mission precondition %s (%s); an absent answer would be "
                "recorded as a failed precondition for a reason about the probe rather than about "
                "the loaded save." % (raw, name, expr))
        out[name] = raw.lower() == "true"
    return out


def suppress_populators(console):
    """Switch the system populator off at the source (scenario 001/010/015's function)."""
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
        raise ScenarioError(
            "these station(s) still report hasNPCTraffic after it was written false: %r"
            % (still_on,))
    if not count:
        raise ScenarioError(
            "no station was found to suppress. This save is docked at a main station by "
            "construction, so zero stations means the save did not load the world.")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` ENDS WITH an unconditional `return system.mainStation`, so
    switching `hasNPCTraffic` off does not stop it launching (scenario 010 measured traffic still
    arriving mid-run). The names come from the spec so an upstream rename turns into a red rather
    than a silent no-op.
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
    every run including ones whose dumps differed."""
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
        "The three known sources (system populator, StationEntity's own schedule, "
        "oolite-populator.js systemWillRepopulate) are all switched off before this runs; a "
        "fourth source is a FINDING, not a reason to widen the round count." % (rounds, history))


def assert_at_rest(console):
    moving = moving_entities(console)
    if moving:
        raise ScenarioError(
            "%d entity/entities still report motion: %s. ShipEntity -velocity is [super velocity] "
            "+ [self thrustVector] (ShipEntity.m:12830-12833), so a ship under thrust reads a "
            "non-zero velocity no JS write can clear, whose value depends on the frame count."
            % (len(moving), ", ".join(moving)))
    if console.evaluate("player.ship.docked").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked. This save is docked at a main station by construction, so "
            "an undocked player means the loaded world is not the saved world.")
    return True


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

    THE FILE APPEARS BEFORE IT IS FINISHED: golden_run._await_png waits for the NAME, which on
    Windows shows up while the game still holds the handle open for writing. Reading it then fails
    with PermissionError or, worse, reads a truncated image. Both are retried; a frame that never
    becomes readable is a REFUSAL rather than a hash of half a file. (Scenario 010's finding.)
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
    raise ScenarioError(
        "the snapshot at %s never became readable (%s: %s); hashing a partial image would be "
        "worse than no frame at all." % (png, type(last).__name__, last))


def assert_ran(evidence, spec, problems=None):
    """The anti-vacuity gate, applied BEFORE anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    stages = list(spec["load_progress_stages"])
    if evidence["load_stages"] != stages:
        raise ScenarioError(
            "the engine's own load trace is %r, not the %d-stage sequence "
            "PlayerEntityLoadSave.m:620-811 emits for a completed load (%r). Those lines exist "
            "ONLY inside -loadPlayerFromFile:, so a run that ignored -load emits NONE of them and "
            "a load that died partway emits a PREFIX - either way this scenario is not measuring "
            "a loaded save." % (evidence["load_stages"], len(stages), stages))
    if evidence["load_failures"]:
        raise ScenarioError("the engine logged load failure(s): %r" % (evidence["load_failures"],))

    want_upgrades = list(spec["expected_upgrade_messages"])
    if evidence["load_upgrade_messages"] != want_upgrades:
        raise ScenarioError(
            "the engine logged 1.75 format-upgrade message(s) %r, not %r. PlayerEntity.m:1731-1746 "
            "compensates this save's legacy EQ_ENERGY_BOMB with 9000 decicredits and SAYS SO on "
            "the load.upgrade.replacedEnergyBomb channel; the census adds that same delta on the "
            "file side, so without the engine's own line the adjusted arithmetic would be an "
            "unfalsifiable fudge factor. This is the save-format compatibility contract the bead "
            "names, and a loader that stopped migrating goes red HERE as well as on credits."
            % (evidence["load_upgrade_messages"], want_upgrades))
    if [m["plist"] for m in spec["load_migrations"]] != evidence["census_fields_migrated"]:
        raise ScenarioError(
            "the census applied migrations to %r but the spec declares %r; a migration declared "
            "and not applied (or applied and not declared) silently changes what the round trip "
            "compares."
            % (evidence["census_fields_migrated"],
               [m["plist"] for m in spec["load_migrations"]]))

    want = dict(spec["expected_mission_variables"])
    if evidence["mission_variables"] != want:
        raise ScenarioError(
            "the loaded game carries mission variables %r, not the save's %r. A DEFAULT NEW GAME "
            "HAS NONE (PlayerEntity.m:1986-1987), so this is the check a fresh commander cannot "
            "pass. Compared as a KEY->VALUE MAP because EVERY value in THIS fixture is a "
            "non-empty string - unlike scenario 015's fixture, where an empty value forced a "
            "key-set-only comparison."
            % (evidence["mission_variables"], want))
    if spec["thargplans_key"] in evidence["mission_variables"] and not spec["thargplans_expected"]:
        raise ScenarioError(
            "missionVariables carries a %r key (%r) but this fixture is positioned BEFORE the "
            "Thargoid Plans mission starts, with the variable ABSENT. If the engine now starts "
            "the mission inside this scenario's budget that is a FINDING about the mission "
            "script, not a number to update quietly."
            % (spec["thargplans_key"], evidence["mission_variables"][spec["thargplans_key"]]))

    want_pre = dict(spec["expected_thargplans_preconditions"])
    if evidence["thargplans_preconditions"] != want_pre:
        raise ScenarioError(
            "the Thargoid Plans mission's arming clauses read %r live, not the %r this fixture "
            "was built to satisfy (oolite-thargoid-plans-mission.js:77-90). The clause map is the "
            "MEASURED state of this fixture, false clauses included (it sits one GALACTIC jump "
            "short of the mission's galaxy); a clause that no longer reads as measured means the "
            "loaded runtime state is not the saved one."
            % (evidence["thargplans_preconditions"], want_pre))

    if not evidence["mission_variables_stable_across_ticks"]:
        raise ScenarioError(
            "the mission variable map moved from %r to %r across the %d-tick budget. This fixture "
            "sits BEFORE the Thargoid Plans mission starts and a docked player running no mission "
            "screen should not change it; a change here is a FINDING about the mission scripts, "
            "not a number to update quietly."
            % (evidence["mission_variables_at_load"], evidence["mission_variables"],
               evidence["ticks"]))

    if evidence["save_written_by_version"] != str(spec["expected_save_version"]):
        raise ScenarioError(
            "the loaded save reports written_by_version %r, not %r. This scenario pins the "
            "1.75-era save-format compatibility contract; a different fixture does not pin it."
            % (evidence["save_written_by_version"], spec["expected_save_version"]))

    if not evidence["world_at_rest"]:
        raise ScenarioError("the world was not at rest when the dump was taken")
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the world never reached a clean clear-and-settle round")
    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met")
    if not evidence["round_trip_ok"]:
        # NAME THE FIELDS. A refusal that says only "they disagree" cannot be distinguished, by a
        # gate or by a human, from an unrelated failure earlier in the run - and the red-proof
        # acceptance line for this scenario has to prove the census is what rejected the run.
        detail = ("; ".join(str(p) for p in problems) if problems
                  else "%d of %d census field(s) differ" % (
                      evidence["census_fields"] - evidence["round_trip_fields_equal"],
                      evidence["census_fields"]))
        raise ScenarioError(
            "CENSUS DIFFERS: census fields disagree between the save FILE (read here by Python's "
            "plist parser) and the LOADED GAME (read over the console by the JS API, in a separate "
            "OS process sharing no code): %s" % detail)
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, expect_from=None, save_override=None):
    """One game process, one canonical dump, one frame grid.

    `expect_from` is the DETECTION CONTROL for the census: the game still loads --save, but the
    expectation is read from a DIFFERENT file, so a correct engine and a correct comparison MUST
    report a difference. `save_override` swaps the file the GAME loads, which is the other half.
    """
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    save = save_override or save_path(spec)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    enable_load_logging(config_dir, spec)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir)
    started = time.time()
    try:
        plist, size = read_save_file(save)
        expect_plist, _ = read_save_file(expect_from) if expect_from else (plist, size)
        saved = saved_census(spec, expect_plist)
        migrated = apply_load_migrations(spec, saved, expect_plist)
        saved_mv = saved_mission_variables(plist)

        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=save))
        with console:
            assert_system(console, spec)
            mv = mission_variables(console)
            preconditions = thargplans_preconditions(console, spec)
            live = live_census(console, spec)

            # THE CENSUS VERDICT IS TAKEN HERE, THE INSTANT BOTH SIDES EXIST - not after the
            # tick budget with the other assertions. ORDER IS THE WHOLE POINT: a census
            # disagreement means the game loaded a DIFFERENT COMMANDER than the harness expects,
            # which is an identity error, whereas everything below it (quiescence, at-rest,
            # frame) is physics that can fail for its own unrelated reasons. Measured: the live
            # red proof (--expect-from a sibling checklist save) once failed on a stray cargo
            # container instead of the census it was built to provoke, so the engineered failure
            # was MASKED by an unrelated one and the line proved nothing about the census. Taking
            # the verdict first makes the red proof report the disagreement it engineered.
            n_saved, pop_saved = assert_non_vacuous(saved, "the census read from the save FILE")
            n_live, _ = assert_non_vacuous(live, "the census read from the LOADED GAME")
            problems = compare_census(saved, live, "saved", "loaded")
            if problems:
                raise ScenarioError(
                    "CENSUS DIFFERS: census fields disagree between the save FILE (read here by "
                    "Python's plist parser) and the LOADED GAME (read over the console by the JS "
                    "API, in a separate OS process sharing no code): %s"
                    % "; ".join(str(p) for p in problems))

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness.
            # Scenario 010 measured eight of ten runs refusing when the suppression came after a
            # multi-second probe, because a station with hasNPCTraffic still on launched traffic
            # in the meantime.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            mv_after = mission_variables(console)

            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        stages, failures, upgrades, log_bytes = read_load_evidence(artifact_dir, spec)

        evidence = {
            "scenario": SCENARIO,
            "save_file": os.path.basename(save),
            "save_bytes": size,
            "save_written_by_version": str(plist.get("written_by_version", "")),
            "load_stages": stages,
            "load_failures": failures,
            "load_upgrade_messages": upgrades,
            "census_fields_migrated": sorted(migrated),
            "mission_variables": mv_after,
            "mission_variables_at_load": mv,
            "mission_variable_count": len(mv_after),
            "mission_variables_stable_across_ticks": mv == mv_after,
            "mission_variables_in_save_file": saved_mv,
            "thargplans_preconditions": preconditions,
            "thargplans_present": spec["thargplans_key"] in mv_after,
            "census_fields": n_saved,
            "census_populated": pop_saved,
            "round_trip_fields_equal": n_saved - len(problems),
            "round_trip_ok": not problems,
            "world_at_rest": bool(at_rest),
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor).
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
        }
        assert_ran(evidence, spec, problems)
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
                "png": golden_run._slashes(png), "problems": problems,
                "frame_hash": frame_hash.hex_digest(grid), "bytes": len(text),
                "log_bytes": log_bytes, "game_seconds_elapsed": round(elapsed, 3),
                "wall_seconds": round(time.time() - started, 1), "evidence": evidence,
                "saved": saved, "live": live}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


# The floor a frame must clear, in frame_hash distance units, to count as RENDERED. Measured on
# this box; see provenance.json frame_liveness.margin for the readings behind it.
FRAME_LIVENESS_FLOOR = 0.020


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        raise ScenarioError(
            "%s is %d bytes, not the %d-byte %dx%d luminance grid; any comparison against it "
            "would be meaningless"
            # GRID_SIDE, not GRID_SIZE: the attribute is named GRID_SIDE in frame_hash.py and a
            # typo here turns this REFUSAL into an AttributeError, i.e. a crash where a named
            # rejection was intended. Caught by test_a_wrong_sized_grid_is_rejected.
            % (path, len(blob), frame_hash.GRID_CELLS, frame_hash.GRID_SIDE, frame_hash.GRID_SIDE))
    return blob


def compare_frame(grid_path, reference_path, tol=None):
    """Report a captured grid against the stored reference and assert what the data supports.

    NEVER BYTE EQUALITY: llvmpipe is not bit-reproducible (bead oo-ae9 measured 0 of 3 same-scene
    pairs byte-identical), so the grid is compared with the MEASURED tolerance from
    frame_hash.derive_tolerance() - used as measured, never widened to make a run pass - and with
    a LIVENESS floor that an all-black frame (a run that died before drawing, or drew into a lost
    context) cannot clear. Both numbers are printed either way so a human blessing or reviewing
    the golden sees them.
    """
    tol = frame_hash.derive_tolerance() if tol is None else tol
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    d = frame_hash.distance(got, want)
    live = frame_hash.distance(got, bytes(frame_hash.GRID_CELLS))
    result = {
        "distance_to_reference": d,
        "tolerance": tol,
        "ratio_to_tolerance": d / tol if tol else float("inf"),
        "within_tolerance": d <= tol,
        "liveness": live,
        "liveness_floor": FRAME_LIVENESS_FLOOR,
        "live": live >= FRAME_LIVENESS_FLOOR,
        "hash_got": frame_hash.hex_digest(got),
        "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    rc = 0
    if not result["live"]:
        print("FAIL: %s has luminance distance %.6f from an all-black frame, below the %.6f "
              "floor. Nothing was rendered - this is what a run that died before drawing, or "
              "drew into a lost context, produces." % (grid_path, live, FRAME_LIVENESS_FLOOR),
              file=sys.stderr)
        rc = 1
    if not result["within_tolerance"]:
        print("FAIL: %s is %.6f from the stored reference, %.2fx the measured tolerance %.6f. "
              "The tolerance is DERIVED from tests/golden/calibration.json and is never widened "
              "to make a run pass; a frame this far out is a FINDING."
              % (grid_path, d, result["ratio_to_tolerance"], tol), file=sys.stderr)
        rc = 1
    return rc


def audit_exclusions(spec, save):
    """Print EVERY save-file key the census does not compare, with its value."""
    plist, size = read_save_file(save)
    included = {f["plist"] for f in spec["census"]}
    print("save file: %s (%d bytes, %d top-level keys)" % (save, size, len(plist)))
    print("census compares %d of them; the rest are listed below with their values.\n"
          % len(included & set(plist)))
    for key in sorted(plist):
        if key in included:
            continue
        value = repr(plist[key])
        if len(value) > 90:
            value = value[:87] + "..."
        print("  EXCLUDED  %-28s %s" % (key, value))
    print("\nINCLUDED (the load assertion):")
    for field in spec["census"]:
        print("  %-28s <- %-38s [%s]" % (field["plist"], field["js"], field["kind"]))
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
    """N independent runs, reporting REFUSED and DIFFERED separately.

    CAPTURES the outcome FOR EVERY RUN REGARDLESS OF EXIT CODE. A sibling harness recorded results
    only when returncode == 0 and so hid runs that wrote a correct dump but exited nonzero,
    reporting '1/10 dumped' when four byte-identical dumps existed.
    """
    import hashlib

    out_dir = os.path.join(run_root, "stability")
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for i in range(1, runs + 1):
        out = os.path.join(out_dir, "run%02d.json" % i)
        grid = os.path.join(out_dir, "run%02d.grid" % i)
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
        # Recorded whatever the verdict was: a dump on disk is a dump on disk.
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
    }
    if len(dumped) < 2:
        summary["WARNING"] = (
            "FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing to compare and no "
            "stability claim can be made from this sweep." % (len(dumped), runs))
    summary["stable"] = len(dumped) >= 2 and len(digests) == 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/thargoid_plans_load.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--save", default=None, help="override the .oolite-save the GAME loads")
    parser.add_argument("--expect-from", default=None,
                        help="DETECTION CONTROL: read the expected census from this save while "
                             "the game loads the real one; a different file MUST differ")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--audit-exclusions", action="store_true")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    parser.add_argument("--census-only", action="store_true",
                        help="print the saved-side census and mission variables (no game launch)")
    args = parser.parse_args(argv)

    spec = load_spec()

    if args.compare_frame:
        return compare_frame(args.compare_frame[0], args.compare_frame[1])
    if args.census_only:
        try:
            plist, _ = read_save_file(args.save or save_path(spec))
            print(json.dumps({"census": saved_census(spec, plist),
                              "mission_variables": saved_mission_variables(plist)},
                             indent=2, sort_keys=True))
        except Refusal as exc:
            sys.stderr.write("REFUSED: %s\n" % exc)
            return 2
        return 0
    if args.audit_exclusions:
        try:
            return audit_exclusions(spec, args.save or save_path(spec))
        except Refusal as exc:
            sys.stderr.write("REFUSED: %s\n" % exc)
            return 2

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 2
    ensure_launchable(app_dir)
    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_zyj1_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, frame_out=args.frame_out,
                     expect_from=args.expect_from, save_override=args.save)
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
    print("LOADED: %s (%s, %d bytes) -> commander %r in %s with %d mission variable(s) %r; "
          "engine logged all %d load stages; Thargoid Plans preconditions %r (%.1fs wall)"
          % (ev["save_file"], ev["save_written_by_version"], ev["save_bytes"],
             result["live"].get("player_name"), spec["system_name"],
             ev["mission_variable_count"], sorted(ev["mission_variables"]),
             len(ev["load_stages"]), ev["thargplans_preconditions"], result["wall_seconds"]))
    if result["problems"]:
        sys.stderr.write("CENSUS DIFFERS:\n")
        for p in result["problems"]:
            sys.stderr.write("  %s\n" % p)
        return 1
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
