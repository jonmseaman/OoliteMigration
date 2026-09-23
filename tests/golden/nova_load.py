"""Golden scenario 014: load the Nova checklist save through the game's own -load argument.

WHAT THIS SCENARIO IS FOR
=========================
Bead oo-wseo asks for scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame
hash, blessed under the golden policy, 10-run stability) but STARTING FROM A SAVED GAME:
`upstream/oolite-tests/Checklist-files/Missions/Nova.oolite-save`, loaded through the game's own
`-load` argument (console.py:121-122; parsed in src/SDL/main.m:166-175, dispatched by
GameController.m:353 into PlayerEntityLoadSave.m:597). It is the same design as scenario
015-trumbles (bead oo-hv4d), with a different fixture and a different mission variable, and it
deliberately does NOT repeat scenario 006's finding that only the LOAD half of a save/load round
trip is reachable headlessly on this build.

THE SAVE-FORMAT CONTRACT - MEASURED, AND NOT WHAT THE STORY ASSUMED
===================================================================
The bead's story calls this fixture "a 1.75-era file". It is not, and the difference is recorded
rather than smoothed over, because the fixture is the thing under test. Measured with plistlib:

  Trumbles.oolite-save (scenario 015)   52 top-level keys, `written_by_version` = "1.75"
  Nova.oolite-save     (this scenario)  49 top-level keys, NO `written_by_version` KEY AT ALL

`written_by_version` is written by every save Oolite 1.75 produces, so its ABSENCE places this
fixture BEFORE that era, not in it. The contract is not merely a key census: the loader MIGRATES
this file. It carries `has_energy_bomb` - an item Oolite REMOVED - and PlayerEntity.m:1730-1746
tries to replace it with a Quirium cascade mine, finds all four pylons already full of
EQ_HARDENED_MISSILEs, and falls through to `credits += 9000` (deci-credits = 900 Cr), logging
[load.upgrade.replacedEnergyBomb]. MEASURED live: the plist holds 933068 credits and the loaded
game reports 94206.8, exactly 900 Cr more. That migration is asserted TWICE by two independent
witnesses - the credits census field predicts the arithmetic, and `evidence.legacy_upgrades`
requires the engine's own log line - so an engine that dropped the migration, compensated a
different amount, or found a free pylon fails by name rather than loading a different commander. Nova.oolite-save also lacks `current_system_name`,
`ship_name`, `entity_personality`, `fuel_charge_rate` and `wormholes` - all of which the 1.75
Trumbles file carries - and it carries three keys the 1.75 file does not (`ootunes_on`,
`reducedDetail`, `saved`). So this scenario pins a STRICTLY OLDER compatibility contract than
015 does: a loader that requires `written_by_version`, or that trips over the legacy-only keys,
fails here by name. `evidence.save_written_by_version` is therefore asserted to be EMPTY, and
`evidence.save_format_keys_absent` / `save_format_keys_present` pin the shape of the file itself,
so a future fixture swap cannot quietly weaken the contract.

THE MISSION VARIABLES - WHY PRESENCE AND VALUE ARE CHECKED SEPARATELY
=====================================================================
The bead names `mission_nova` / `mission_novacount`. Measured, this fixture's five mission
variables are:

    mission_TL_FOR_EQ_NAVAL_ENERGY_UNIT = '13'
    mission_conhunt                     = 'MISSION_COMPLETE'
    mission_novacount                   = '3'
    mission_thargplans                  = 'MISSION_COMPLETE'
    mission_trumbles                    = 'NOT_NOW'

`mission_novacount` IS PRESENT with the non-empty value '3'; `mission_nova` IS ABSENT. Both facts
are asserted, and the asymmetry is the point:

  * A MISSION VARIABLE THAT IS THE EMPTY STRING READS IDENTICALLY TO AN ABSENT ONE (the lesson
    scenario 015 was built around: its `mission_trumbles` was ''). So the KEY SET is the primary
    evidence here too - `evidence.mission_variable_keys` - because a fresh commander's mission
    variable dictionary is EMPTY (PlayerEntity.m:1986-1987) and cannot produce these five keys.
  * `mission_novacount` is the one variable this bead names whose value is NOT empty, so it is
    ALSO checked by value ('3'), which the trumbles scenario could not do. A value check is
    strictly stronger where the value is non-empty, and worthless where it is not.
  * `mission_nova` ABSENCE is asserted explicitly. The nova mission sets `mission_nova` when it
    runs (oolite-nova.js), so a game that had actually played through the nova mission - or a
    harness that fabricated the dictionary from the story text - would carry it. Asserting the
    absence is what stops "the bead mentions mission_nova" turning into an unchecked claim.

The engine strips the `mission_` prefix for JS (OOJSMissionVariables.m:191-193), so the plist's
`mission_novacount` is `missionVariables.novacount`.

ANTI-VACUITY: WHAT A FRESH COMMANDER CANNOT PRODUCE
====================================================
"The game started" is satisfiable by a run that ignored `-load`, and rc=0 plus an absence of ERROR
lines is satisfiable by a dead run (bead oo-het caught seven expansions that way). Every check is
POSITIVE and names state a DEFAULT NEW GAME CANNOT HAVE:

  1. `evidence.load_stages` - ENGINE-EMITTED, not inferred here. With `load.progress` switched on
     (enable_load_logging) PlayerEntityLoadSave.m emits a fixed ordered stage sequence from
     "Reading file" to "Loading complete" (:620-811). Those lines exist ONLY inside
     `-loadPlayerFromFile:`, so a run that never loaded emits NONE and a partial load emits a
     PREFIX; the WHOLE ordered sequence is required.
  2. `evidence.mission_variable_keys` + `novacount` value + `mission_nova` absence, above.
  3. `evidence.galaxy_number` == 3. A new commander starts in galaxy 0 and reaching galaxy 3
     needs three galactic hyperdrive jumps; no default game is there.
  4. `census` - nine fields read out of the FILE by Python's plist parser and out of the LIVE GAME
     by the JS API, in two different OS processes sharing no code (scenario 006's invariant).
     Commander 'Tester', 93306.8 credits, 1634 kills: none of them is a default.

THE FRAME
=========
A frame is captured and stored (`frame.grid`, `frame.png`). Whether the frame-vs-reference
TOLERANCE is asserted is a MEASURED question, not a design preference, and the measurement lives
in provenance.json under `frame_tolerance` with `asserted` and, when false, a reason. This
scenario's HUD carries no animated population (scenario 015's trumbles were the picture, giving it
same-scene spreads of 1.08x..2.49x tolerance and no usable separation), so the numbers are
re-measured here rather than inherited. LIVENESS is asserted either way: an all-black grid is what
a run that died before drawing produces, and it is rejected.

frame.grid is NEVER byte-hashed into a verdict: llvmpipe is not bit-reproducible (bead oo-ae9).
state.json IS byte-hashed, and its digest and byte size are witnessed by provenance.json, a
SEPARATE file - a golden cannot witness itself (bead oo-gxp).

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

SCENARIO = "014-nova"

# The spec, golden, provenance and frame live under the guarded goldens/ tree once Jon has
# approved the protected-path addition (tools/rebless-approvals.txt). Until then they are staged
# under tests/golden/pending/, and BOTH locations are searched, so landing them is a pure
# `git mv` with no code change. Scenario 010/012/015's arrangement, deliberately identical.
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

# A real .oolite-save is tens of kilobytes; this fixture is 25407. The floor exists only to reject
# a zero-byte or stub file, which parses to an empty mapping and makes every comparison vacuous.
MIN_SAVE_BYTES = 1024
# Pinned here AND in test_nova_load.py, so shrinking the census to one trivially-equal field
# fails in two places.
MIN_CENSUS_FIELDS = 8

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
CLEAR_ROUNDS = 20

# PlayerEntity.m:1743. Credits are stored in DECI-credits, so 9000 here is 900 Cr. The loader
# adds it when a save's legacy energy bomb cannot be replaced by a Quirium cascade mine because
# every missile pylon is already occupied - which is this fixture's case (four
# EQ_HARDENED_MISSILEs on a four-pylon Cobra III).
LEGACY_ENERGY_BOMB_COMPENSATION_DECI = 9000

# The floor a frame must clear, in frame_hash distance units, to count as RENDERED. Not a
# tolerance and not a same-scene equality test - see compare_frame().
FRAME_LIVENESS_FLOOR = 0.020


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
    tenths while the JS API reports whole units, so the file holds 933068 where JS reports 93306.8.
    An unknown kind raises rather than inventing a conversion.
    """
    if kind == "int":
        return int(value)
    if kind == "str":
        return str(value)
    if kind == "float_tenths":
        return round(float(value) / 10.0, 3)
    if kind == "float_tenths_legacy_energy_bomb":
        # THE LOADER MIGRATES THIS SAVE AND CHANGES THE VALUE, AND THAT IS THE POINT.
        # This fixture has has_energy_bomb = true, an item Oolite removed. On load,
        # PlayerEntity.m:1730-1746 tries to mount a Quirium cascade mine in its place and, if
        # every pylon is already full - this save carries four EQ_HARDENED_MISSILEs, so it is -
        # falls through to `credits += 9000` (deci-credits, i.e. 900 Cr) and logs
        # [load.upgrade.replacedEnergyBomb]. MEASURED live: the plist holds 933068 and the loaded
        # game reports 94206.8, exactly 900 Cr more.
        #
        # This is NOT a fudge to make a comparison pass, and it must not be read as one. It is the
        # save-format compatibility contract this scenario exists to pin, expressed as an
        # arithmetic prediction the engine has to satisfy: an engine that DROPPED the legacy
        # energy-bomb migration, or that compensated a different amount, or that found a free
        # pylon and mounted the mine instead, all fail here by name rather than silently loading a
        # different commander. The engine's own [load.upgrade] line is ALSO asserted
        # (evidence.legacy_upgrades), so the two witnesses have to agree.
        return round((float(value) + LEGACY_ENERGY_BOMB_COMPENSATION_DECI) / 10.0, 3)
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
        elif kind in ("float_tenths", "float_tenths_legacy_energy_bomb"):
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


def save_format_shape(spec, plist):
    """Pin the FILE FORMAT, not only its contents.

    The bead's story calls this fixture 1.75-era; it is OLDER. `written_by_version` is written by
    every 1.75 save and is ABSENT here, and four more 1.75-only keys are absent with it while
    three legacy-only keys are present. Recording both sets means a future fixture swap that
    silently weakened the compatibility contract - to a NEWER file, which is the easy mistake -
    goes red by name instead of passing quietly.
    """
    present = sorted(k for k in spec["save_format_keys_present"] if k in plist)
    absent = sorted(k for k in spec["save_format_keys_absent"] if k not in plist)
    return {
        "save_format_keys_present": present,
        "save_format_keys_absent": absent,
        "save_top_level_keys": len(plist),
    }


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


def read_load_evidence(artifact_dir):
    """Pull the ENGINE's own load trace out of THIS run's Latest.log."""
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log at all, so the engine's own load evidence "
            "cannot be checked and rc=0 would mean nothing." % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    stages, failures = [], []
    for line in text.splitlines():
        stripped = line.strip()
        if "[load.progress]:" in stripped:
            stages.append(stripped.split("[load.progress]:", 1)[1].strip())
        elif "[load.failed]" in stripped:
            failures.append(stripped)
    # THE ENGINE'S OWN WITNESS OF THE FORMAT MIGRATION. This save carries has_energy_bomb, an item
    # Oolite removed; PlayerEntity.m:1730-1746 compensates it and logs on the `load.upgrade`
    # channel. The credits census field predicts the ARITHMETIC of that migration, so requiring
    # the log line as well means the two independent witnesses of the same engine behaviour have
    # to agree - a checker that only predicted the number would pass for a coincidence.
    upgrades = []
    for line in text.splitlines():
        stripped = line.strip()
        if "[load.upgrade." in stripped:
            upgrades.append(stripped.split("]:", 1)[-1].strip())
    return stages, failures, sorted(upgrades), len(text)


def assert_galaxy(console, spec):
    """Galaxy 3 is three galactic hyperdrive jumps from a new commander's galaxy 0."""
    got = console.evaluate_int("galaxyNumber")
    if got != int(spec["galaxy_number"]):
        raise ScenarioError(
            "scenario %s is pinned to galaxy %d but the loaded save reports galaxy %d. A DEFAULT "
            "NEW GAME IS IN GALAXY 0, so this is one of the checks a run that ignored -load "
            "cannot pass." % (SCENARIO, int(spec["galaxy_number"]), got))
    return got


def mission_variables(console):
    """The mission variable KEY SET and the values of the keys this scenario names.

    KEYS FIRST, and that choice is load-bearing: a mission variable whose value is the EMPTY
    STRING reads identically to an absent one, so a pure value comparison can be satisfied by a
    game that never heard of the mission (scenario 015's `mission_trumbles` was exactly that).
    A fresh commander's dictionary is empty (PlayerEntity.m:1986-1987), so the KEY's presence is
    save-specific. This fixture's `novacount` IS non-empty ('3'), so it is additionally checked by
    VALUE, which is strictly stronger where a value exists. The engine strips the `mission_`
    prefix for JS (OOJSMissionVariables.m:191-193).
    """
    raw = console.evaluate(
        "(function(){ var o = []; for (var k in missionVariables) o.push(k);"
        " return o.sort().join(','); })()").strip()
    keys = [k for k in raw.split(",") if k]
    values = {}
    for key in keys:
        values[key] = console.evaluate(
            "String(missionVariables[%s])" % json.dumps(key)).strip()
    return keys, values


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
            "no station was found to suppress. This save is docked by construction, so zero "
            "stations means the save did not load the world.")
    return count


def suppress_station_ai(console, spec):
    """Switch every station's own AI to a null AI - THE FOURTH TRAFFIC SOURCE, FOUND BY MEASURING.

    Scenario 015 needed three suppressions (system populator, StationEntity's launch schedule,
    oolite-populator.js systemWillRepopulate) because it loaded a save docked at Lave's main
    station. THIS save's system contains a ROCK HERMIT as well, and a rock hermit runs
    `rockHermitAI.plist`, whose CHECK_FOR_ROCKS state does `scanForRocks` on a 20 s `pauseAI`
    cycle and, on TARGET_FOUND, `launchMiner`. StationEntity.m:1736-1776 -launchMiner builds a
    Mining Transporter and queues it, and NONE of the three existing suppressions touch that path:
    `hasNPCTraffic` gates the ordinary trader schedule, not a station's own AI.

    MEASURED before this function existed: a 10-run sweep gave FOUR distinct dump digests. Five
    runs dumped a two-entity world and three dumped a THREE-entity world whose extra entity was
    `{"id": "Mining Transporter", "role": "miner", "velocity": [17.557, -39.661, -24.874]}`, and
    two more REFUSED with "1 entity/entities still report motion: Cobra Mark I=254.8750" - the
    hermit's launch queue emptying while the harness was trying to reach a fixed point. A
    follow-up probe watched the miner appear 4-6 s after quiesce() had returned a clean round and
    hold 50 then 100 m/s. That is bead oo-jor's finding one layer deeper: a fourth source is a
    FINDING, and the honest response is to identify and switch it off, never to widen the round
    count until the race is usually won.

    The AI name comes from the spec so an upstream rename turns into a red rather than a silent
    no-op, and the write is VERIFIED by reading `station.AI` back (OOJSShip.m:337 exposes it
    read-only), because a setAI that silently did nothing would leave the race exactly as it was.
    """
    name = spec["station_ai"]
    raw = console.evaluate(
        "(function(){ var s = system.stations, out = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   s[i].setAI(%s); out.push(s[i].name + '=' + s[i].AI); }"
        " return out.join(', '); })()" % json.dumps(name)).strip()
    entries = [e for e in raw.split(", ") if e]
    if not entries:
        raise ScenarioError(
            "no station was found to silence. This save is docked at a station by construction, "
            "so zero stations means the save did not load the world.")
    # The engine reports the AI by the name it RESOLVED, not the name it was given: setAI
    # ("oolite-nullAI.js") reads back as "nullAI.plist" (measured). So the read-back is checked
    # against spec["station_ai_reported"] rather than against the name written, and BOTH are
    # pinned - a setAI that silently did nothing would leave the hermit's rockHermitAI in place
    # and the read-back would say so.
    reported = spec["station_ai_reported"]
    wrong = [e for e in entries if not e.endswith("=" + reported)]
    if wrong:
        raise ScenarioError(
            "these station(s) did not accept the null AI %r (the engine reports the resolved name "
            "%r): %r. StationEntity's own AI is the FOURTH traffic source (a rock hermit's "
            "rockHermitAI launchMiner), and it is not gated by hasNPCTraffic; if setAI is "
            "silently doing nothing this scenario is racing the hermit's launch queue and its "
            "dump is frame-count dependent." % (name, reported, wrong))
    return sorted(entries)


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` (oolite-populator.js:2656-2680) tests `hasNPCTraffic` inside
    its loop but ENDS WITH an unconditional `return system.mainStation`, so switching the flag off
    does not stop it launching. The names come from the spec so an upstream rename turns into a
    red rather than a silent no-op.
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
            "the player is not docked. This save is docked at a station by construction, so an "
            "undocked player means the loaded world is not the saved world.")
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
    want_upgrades = sorted(spec["expected_legacy_upgrades"])
    if evidence["legacy_upgrades"] != want_upgrades:
        raise ScenarioError(
            "the engine logged legacy-format upgrade(s) %r, not the expected %r. This fixture "
            "carries has_energy_bomb - an item Oolite REMOVED - and PlayerEntity.m:1730-1746 "
            "compensates it with 900 Cr because all four pylons already hold hardened missiles. "
            "That migration is the save-format compatibility contract this scenario pins, and "
            "the credits census field predicts its ARITHMETIC independently; both witnesses must "
            "agree or the loader has changed how it handles pre-1.75 saves."
            % (evidence["legacy_upgrades"], want_upgrades))

    want_keys = sorted(spec["expected_mission_variable_keys"])
    if evidence["mission_variable_keys"] != want_keys:
        raise ScenarioError(
            "the loaded game carries mission variables %r, not the save's %r. A DEFAULT NEW GAME "
            "HAS NONE (PlayerEntity.m:1986-1987), so this is the check a fresh commander cannot "
            "pass. Compared as a KEY SET because a mission variable whose value is the empty "
            "string reads identically to an absent one."
            % (evidence["mission_variable_keys"], want_keys))
    novacount = spec["mission_novacount_key"]
    if novacount not in evidence["mission_variable_keys"]:
        raise ScenarioError(
            "missionVariables carries no %r key. That is the mission variable this bead names."
            % novacount)
    if evidence["mission_novacount_value"] != str(spec["expected_mission_novacount_value"]):
        raise ScenarioError(
            "missionVariables.%s is %r, not the save's %r. This variable is NON-EMPTY in this "
            "fixture, so unlike scenario 015's mission_trumbles it can be - and is - checked by "
            "VALUE as well as by presence."
            % (novacount, evidence["mission_novacount_value"],
               str(spec["expected_mission_novacount_value"])))
    nova = spec["mission_nova_key"]
    if nova in evidence["mission_variable_keys"]:
        raise ScenarioError(
            "missionVariables carries a %r key, which this fixture does NOT have. The nova "
            "mission sets it when it runs, so its appearance means the loaded game is not this "
            "save. The absence is asserted deliberately: the bead names mission_nova, and an "
            "unchecked mention is how a claim becomes decoration." % nova)

    if evidence["galaxy_number"] != int(spec["galaxy_number"]):
        raise ScenarioError(
            "the loaded game is in galaxy %d, not the save's %d"
            % (evidence["galaxy_number"], int(spec["galaxy_number"])))
    if evidence["save_written_by_version"] != str(spec["expected_written_by_version"]):
        raise ScenarioError(
            "the save's written_by_version is %r, expected %r. An EMPTY expectation is not an "
            "oversight: this fixture predates the 1.75 saves that write the key, and that older "
            "format is the compatibility contract this scenario pins."
            % (evidence["save_written_by_version"], str(spec["expected_written_by_version"])))
    if evidence["save_format_keys_present"] != sorted(spec["save_format_keys_present"]):
        raise ScenarioError(
            "the save carries legacy-format keys %r, not the expected %r; this is a different "
            "save format from the one this scenario pins."
            % (evidence["save_format_keys_present"], sorted(spec["save_format_keys_present"])))
    if evidence["save_format_keys_absent"] != sorted(spec["save_format_keys_absent"]):
        raise ScenarioError(
            "the save is missing %r, but the keys expected to be ABSENT are %r. A fixture that "
            "acquired written_by_version would be a NEWER file and would silently weaken the "
            "compatibility contract."
            % (evidence["save_format_keys_absent"], sorted(spec["save_format_keys_absent"])))

    if len(evidence["station_ais_silenced"]) != evidence["stations_quieted"]:
        raise ScenarioError(
            "%d station(s) had their launch schedule switched off but only %d had their own AI "
            "silenced. A station's AI is a SEPARATE traffic source that hasNPCTraffic does not "
            "gate - a rock hermit's rockHermitAI launches a miner on its own 20 s cycle - and a "
            "station left with its AI running makes this dump a race (measured: 4 distinct "
            "digests over 10 runs before this suppression existed)."
            % (evidence["stations_quieted"], len(evidence["station_ais_silenced"])))
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

    `expect_from` is the DETECTION CONTROL for the census: the game still loads the scenario's
    save, but the expectation is read from a DIFFERENT file, so a correct engine and a correct
    comparison MUST report a difference. `save_override` swaps the file the GAME loads, which is
    the other half.
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
        shape = save_format_shape(spec, plist)

        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=save))
        with console:
            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE. THE ORDER IS LOAD-BEARING, AND THIS
            # SCENARIO MEASURED IT THE HARD WAY. An earlier revision read the census and the
            # mission variables first - about fourteen console round trips, several seconds - and
            # its 10-run sweep produced FOUR distinct dump digests, three of them carrying an
            # extra Mining Transporter. With the suppressions moved ahead of every probe, a
            # 30-second watch with repeated clearing saw no miner at all. Scenario 010 recorded
            # the same finding for the same reason: whatever runs before the suppression is a
            # window the station launches into.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            station_ais = suppress_station_ai(console, spec)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            galaxy = assert_galaxy(console, spec)
            mv_keys, mv_values = mission_variables(console)
            live = live_census(console, spec)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        stages, failures, upgrades, log_bytes = read_load_evidence(artifact_dir)

        n_saved, pop_saved = assert_non_vacuous(saved, "the census read from the save FILE")
        n_live, _ = assert_non_vacuous(live, "the census read from the LOADED GAME")
        problems = compare_census(saved, live, "saved", "loaded")

        evidence = {
            "scenario": SCENARIO,
            "save_file": os.path.basename(save),
            "save_bytes": size,
            "save_written_by_version": str(plist.get("written_by_version", "")),
            "load_stages": stages,
            "load_failures": failures,
            "legacy_upgrades": upgrades,
            "mission_variable_keys": sorted(mv_keys),
            "mission_variable_count": len(mv_keys),
            "mission_novacount_value": mv_values.get(spec["mission_novacount_key"], ""),
            "mission_nova_present": spec["mission_nova_key"] in mv_keys,
            "galaxy_number": galaxy,
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
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "station_ais_silenced": station_ais,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
        }
        evidence.update(shape)
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
                "saved": saved, "live": live, "mission_values": mv_values}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        # The refusal text is formatted by frame_hash so it cannot be mistyped here: this call
        # site used to spell the side length GRID_SIZE, an attribute frame_hash does not
        # exist (it is GRID_SIDE), which turned this REFUSAL into an AttributeError crash.
        raise ScenarioError(frame_hash.wrong_grid_size_message(path, len(blob)))
    return blob


def compare_frame(grid_path, reference_path, tol=None, assert_tolerance=None):
    """Report a captured grid against the stored reference.

    LIVENESS is always asserted: an all-black grid is what a run that died before drawing, or drew
    into a lost context, produces, and it sits at distance 0 from black.

    Whether the DISTANCE-TO-REFERENCE tolerance is also asserted is read from the stored
    provenance (`frame_tolerance.asserted`), because it is a MEASURED property of this scene and
    not a preference: scenario 015 measured same-scene pairs at 1.08x..2.49x tolerance (an
    animated HUD population) and had to record asserted=false with a reason. The distance is
    computed and PRINTED either way, so a human blessing or reviewing the golden sees the number.
    """
    tol = frame_hash.derive_tolerance() if tol is None else tol
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    d = frame_hash.distance(got, want)
    live = frame_hash.distance(got, bytes(frame_hash.GRID_CELLS))
    if assert_tolerance is None:
        assert_tolerance = _provenance_asserts_tolerance()
    result = {
        "distance_to_reference": d,
        "tolerance": tol,
        "ratio_to_tolerance": d / tol if tol else float("inf"),
        "within_tolerance": d <= tol,
        "tolerance_asserted": bool(assert_tolerance),
        "liveness": live,
        "liveness_floor": FRAME_LIVENESS_FLOOR,
        "live": live >= FRAME_LIVENESS_FLOOR,
        "hash_got": frame_hash.hex_digest(got),
        "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    if not result["live"]:
        print("FAIL: %s has luminance distance %.6f from an all-black frame, below the %.6f "
              "floor. Nothing was rendered - this is what a run that died before drawing, or "
              "drew into a lost context, produces." % (grid_path, live, FRAME_LIVENESS_FLOOR),
              file=sys.stderr)
        return 1
    if assert_tolerance and not result["within_tolerance"]:
        print("FAIL: %s is %.6f from the stored reference, %.2fx the measured tolerance %.6f."
              % (grid_path, d, result["ratio_to_tolerance"], tol), file=sys.stderr)
        return 1
    return 0


def _provenance_asserts_tolerance():
    """Read frame_tolerance.asserted from the stored provenance, defaulting to NOT asserted.

    The default is the conservative one on purpose: a missing provenance must not silently turn on
    an assertion whose supporting measurement nobody has seen.
    """
    for path in (os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
                 os.path.join(HERE, "pending", SCENARIO, "provenance.json")):
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as handle:
                prov = json.load(handle)
            return bool((prov.get("frame_tolerance") or {}).get("asserted"))
    return False


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
    """N independent runs, reporting REFUSED and DIFFERED separately, and ACCOUNTING FOR EVERY RUN.

    CAPTURES the outcome of EVERY run regardless of exit code, and the summary asserts
    dumped + refused + errored == runs, so a run cannot fall out of the arithmetic unnoticed.
    """
    import hashlib

    out_dir = os.path.join(run_root, "stability")
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for i in range(1, runs + 1):
        out = os.path.join(out_dir, "run%02d.json" % i)
        grid = os.path.join(out_dir, "run%02d.grid" % i)
        # A HARNESS MUST DELETE ITS OUTPUT PATH BEFORE EVERY RUN (bead oo-gxp): otherwise a stale
        # artifact from an earlier invocation is read as "this run produced a dump".
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
    refused = len([r for r in results if r["verdict"] == "REFUSED"])
    errored = len([r for r in results if r["verdict"] == "ERROR"])
    summary = {
        "runs": runs,
        "dumps_written": len(dumped),
        "refused": refused,
        "errored": errored,
        "accounted_for": len(dumped) + refused + errored == runs,
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
    summary["stable"] = (len(dumped) >= 2 and len(digests) == 1
                         and summary["accounted_for"])
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/nova_load.py",
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
                        help="print the saved-side census and stop (no game launch)")
    args = parser.parse_args(argv)

    spec = load_spec()

    if args.compare_frame:
        return compare_frame(args.compare_frame[0], args.compare_frame[1])
    if args.census_only:
        try:
            plist, _ = read_save_file(args.save or save_path(spec))
            print(json.dumps(saved_census(spec, plist), indent=2, sort_keys=True))
            print(json.dumps(save_format_shape(spec, plist), indent=2, sort_keys=True))
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
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_wseo_runs")
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
    print("LOADED: %s (%d bytes, written_by_version=%r) -> commander %r in galaxy %d with %d "
          "mission variable(s); missionVariables.%s=%r, %s absent; engine logged all %d load "
          "stages; %d ticks (%.1fs wall)"
          % (ev["save_file"], ev["save_bytes"], ev["save_written_by_version"],
             result["live"].get("player_name"), ev["galaxy_number"],
             ev["mission_variable_count"], spec["mission_novacount_key"],
             ev["mission_novacount_value"], spec["mission_nova_key"], len(ev["load_stages"]),
             ev["ticks"], result["wall_seconds"]))
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
