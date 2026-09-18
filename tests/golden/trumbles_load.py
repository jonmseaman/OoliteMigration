"""Golden scenario 015: load the 1.75-era Trumbles checklist save, and measure the population.

WHAT THIS SCENARIO IS FOR
=========================
Bead oo-hv4d asks for scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame
hash, blessed under the golden policy, 10-run stability) but STARTING FROM A SAVED GAME:
`upstream/oolite-tests/Checklist-files/Missions/Trumbles.oolite-save`, loaded through the game's
own `-load` argument (console.py:121-122; parsed in src/SDL/main.m:166-175, dispatched by
GameController.m:353 into PlayerEntityLoadSave.m:597). The save was written by Oolite 1.75
(`written_by_version` in the plist), so the scenario also pins the save-format compatibility
contract: a loader that stopped understanding a 1.75 file fails here by name.

Scenario 006 (bead oo-8ij) already established that only the LOAD half of a save/load round trip
is reachable headlessly on this build - every writer funnels into `-writePlayerToPath:` and all
three of its callers need a GUI keypress or an AppKit panel. That finding is not repeated here;
this scenario is the load half applied to a specific, interesting fixture.

THE TRUMBLE POPULATION - THE CORE QUESTION, AND THE MEASURED ANSWER
===================================================================
Trumbles are a LIVE, MULTIPLYING population, which makes "is the count after N ticks
reproducible?" the sharpest determinism question in the save-load set. It was measured on this
box rather than reasoned about, and the answer has two halves, BOTH of which are recorded in the
dump so that a future change to either is caught by name.

  HALF ONE - THE SAVED POPULATION IS EXACTLY REPRODUCIBLE, AND IT IS ZERO.
  The fixture's `trumbles` plist value is `[0, 20936, [24 trumble dictionaries]]`. The first
  element is the count, the second is the anti-cheat checksum. `-setTrumbleValueFrom:`
  (PlayerEntity.m:12069-12175) accepts the count only if the checksum agrees, recomputing it with
  munge_checksum over the commander name, credits and ship_kills (legacy_random.c:48-57).
  Reimplementing that checksum in Python over this fixture's own values ("Trumbles", 65534, 0)
  yields 20936 for n=0 and for NO other n in 0..23, so the count the loader accepts is pinned by
  the file: the engine reads back `player.trumbleCount == 0`, confirmed live.
  A ZERO population cannot breed (updateTrumbles: iterates `trumbleCount` times), so on the
  fixture alone the determinism question has a trivial answer and no teeth.

  HALF TWO - A LIVE POPULATION IS *NOT* REPRODUCIBLE PAST FOUR, AND THIS SCENARIO STOPS AT FOUR.
  To give the question teeth the scenario grows a real population with
  `player.ship.awardEquipment('EQ_TRUMBLE')`, which reaches PlayerEntity.m:11521-11534:

      if ((trumbleCount < PLAYER_MAX_TRUMBLES / 6) ||
          (trumbleCount < PLAYER_MAX_TRUMBLES / 3 && ranrot_rand() % 2 > 0))
          [self addTrumble:trumble[ranrot_rand() % PLAYER_MAX_TRUMBLES]];

  PLAYER_MAX_TRUMBLES is 24 (PlayerEntity.h:312), so the FIRST FOUR awards take the left branch
  unconditionally and the fifth onwards are gated on a RANROT draw. MEASURED, three runs at the
  identical seed 20260918, counts after each of 14 awards:

      run 1: 1 2 3 4 5 6 6 7 7 7 7 8 8 8
      run 2: 1 2 3 4 5 5 6 6 7 8 8 8 8 8
      run 3: 1 2 3 4 5 5 6 6 6 6 6 7 8 8

  The first four entries agree on every run; from the fifth they diverge. This is EXACTLY the
  shape bead oo-izi measured for system.addShips: a fixed seed pins the RANROT SEQUENCE but not
  how far into it a run has advanced, because the number of frames burned before the draw depends
  on how fast this box rendered. So `spec["trumble_awards"] = 4` is not a convenient number, it is
  the measured boundary of the deterministic prefix, and `expected_trumble_count` is asserted
  against it. THE SEAM THAT WOULD BE NEEDED to pin a larger population is a JS-reachable way to
  seed or step the engine's RANROT stream at a known point (or to award without consulting it);
  inventing one is out of scope for a golden scenario, and coarsening the dump to hide the
  divergence would be worse than not measuring it.

  HALF TWO, CONTINUED - BREEDING DOES NOT FIRE INSIDE THE TICK BUDGET, AND THAT IS ASSERTED.
  OOTrumble.m:623-627 sets `readyToSpawn` only after a trumble has eaten 10 accumulated units of
  cargo (`trumbleAppetiteAccumulator > 10.0`) while full-grown and comfortable, and the feeding
  branch at :585-612 needs `[player cargo]` - the CARGO PODS, which a docked player has none of.
  MEASURED: with 8 live trumbles the count did not move across 15 s of game time. So the dump
  carries `trumble_count_stable_across_ticks`, and if a future engine ever breeds inside this
  budget the golden goes red instead of silently drifting.

ANTI-VACUITY: WHAT A FRESH COMMANDER CANNOT PRODUCE
====================================================
"The game started" is satisfiable by a run that ignored `-load` entirely, and rc=0 plus an absence
of ERROR lines is satisfiable by a dead run (bead oo-het caught seven expansions that way). Every
check below is POSITIVE and names state a DEFAULT NEW GAME CANNOT HAVE:

  1. `evidence.load_stages` - ENGINE-EMITTED, not inferred by this script. With `load.progress`
     switched on (see enable_load_logging) PlayerEntityLoadSave.m emits a fixed 14-stage sequence
     from "Reading file" to "Loading complete" (:620-811). Those lines exist ONLY inside
     `-loadPlayerFromFile:`. A run that never loaded a save emits NONE of them, and the scenario
     requires the WHOLE ordered sequence, so a partial load that died at "Creating player ship"
     also fails. This is the strongest evidence here and it comes from the engine.
  2. `evidence.mission_variable_keys` - the save carries five mission variables including
     `mission_trumbles`, the field the bead names. A fresh commander has an EMPTY mission variable
     dictionary (PlayerEntity.m:1986-1987 allocates a new empty one). Checked as a KEY SET, never
     by value, because `mission_trumbles` is the EMPTY STRING in this fixture and an absent
     mission variable also reads as empty - value equality here would be satisfied by a game that
     had never heard of the mission. (The engine strips the `mission_` prefix for JS:
     OOJSMissionVariables.m:191-193, so the plist's `mission_trumbles` is `missionVariables.trumbles`.)
  3. `census` - eleven fields read out of the FILE by Python's plist parser and out of the LIVE
     GAME by the JS API, in two different processes sharing no code (scenario 006's invariant).
     Includes commander name "Trumbles", credits 6553.4 and the 1.75-era ship clock.
  4. `evidence.saved_trumble_count` / `trumble_count` - the population, before and after.

THE FRAME - A MEASURED NEGATIVE, REPORTED RATHER THAN PAPERED OVER
==================================================================
The bead asks for a frame hash. One is captured and stored (`frame.grid`, `frame.png`), but IT IS
NOT A GATE PREDICATE IN THIS SCENARIO, because it was measured and it cannot carry one. The
numbers, all from this box:

  same-scene pairs, 10 independent runs        0.004725 .. 0.010916   (1.08x .. 2.49x tolerance)
  two frames 1s apart INSIDE ONE RUN           0.005263 .. 0.006840   (1.20x .. 1.56x tolerance)
  the same control with ZERO trumbles          0.001573 .. 0.001710   (0.36x .. 0.39x tolerance)
  a ZERO-TRUMBLE frame vs the populated ones   0.002768 .. 0.007899   (0.63x .. 1.80x tolerance)
  an ALL-BLACK frame vs the blessed one        0.034308               (7.8x tolerance)

Read them in that order and the conclusion is forced. Intra-run variation is as large as cross-run
variation, so the spread is NOT cross-run nondeterminism. With the trumbles removed it collapses
by a factor of four to well inside the tolerance, so the source is identified: HeadUpDisplay.m:3306
`-drawTrumbles:` draws the live population every frame, and OOTrumble's animation state machine
(`updateBlink`, `updateProot`, `updateStoned`, ... each scheduling the next animation with
`randf()`, OOTrumble.m:305-353) keeps it moving for as long as the game renders. The trumbles ARE
the picture.

And the separation test fails outright: the smallest distance between a ZERO-trumble frame and a
populated one (0.002768) is 0.25x the largest distance between two POPULATED frames (0.010916).
The signal is smaller than the noise, so no tolerance exists that admits two runs of this scenario
while rejecting a run with no trumbles at all. Bead oo-gxp's scenario 010 had a 261-fold
separation; this scenario has none.

So the frame is stored for a human to look at and is asserted only on the one property the data
DOES support - LIVENESS, that something was rendered at all, an all-black frame being 7.8x the
tolerance away and 4.5x outside the noise band. Widening the tolerance until a same-scene pair fits
would have produced a gate that passes for every reason including the wrong ones. The tick count
and the dump carry this scenario's determinism claim; the frame does not, and says so.

PORT / LAUNCH ISOLATION
=======================
golden_run.py wholesale, as scenarios 001/006/010 do: a reserved port, a staged app dir, and a
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

SCENARIO = "015-trumbles"

# The spec, golden, provenance and frame live under the guarded goldens/ tree once Jon has
# approved the protected-path addition (tools/rebless-approvals.txt). Until then they are staged
# under tests/golden/pending/, and BOTH locations are searched, so landing them is a pure
# `git mv` with no code change. Scenario 010/012's arrangement, deliberately identical.
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

# A real .oolite-save is tens of kilobytes; this fixture is 24424. The floor exists only to reject
# a zero-byte or stub file, which parses to an empty mapping and makes every comparison vacuous.
MIN_SAVE_BYTES = 1024
# Pinned here AND in test_trumbles_load.py, so shrinking the census to one trivially-equal field
# fails in two places.
MIN_CENSUS_FIELDS = 8

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
CLEAR_ROUNDS = 20

# PlayerEntity.h:312. The award gate's thresholds are MAX/6 and MAX/3, so this constant is what
# makes 4 the deterministic prefix; it is read rather than hardcoded as "4" in the reasoning.
PLAYER_MAX_TRUMBLES = 24


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
    tenths while the JS API reports whole units, so the file holds 65534 where JS reports 6553.4.
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


def saved_trumble_count(plist):
    """The count the file claims, with the shape of the value checked rather than assumed.

    `trumbles` is [count, checksum, [24 dictionaries]] (PlayerEntity.m:12045-12066). The engine
    accepts the count only if the checksum agrees; verify_trumble_checksum() below reimplements
    that check independently, so this scenario knows what the loader WILL do before it runs.
    """
    value = plist.get("trumbles")
    if not isinstance(value, list) or len(value) != 3:
        raise Refusal(
            "the save's `trumbles` value is %r, not the [count, checksum, array] triple "
            "PlayerEntity.m:12065 writes; this fixture is not the Trumbles save this scenario is "
            "about." % (value,))
    count, checksum, array = value
    if not isinstance(array, list) or len(array) != PLAYER_MAX_TRUMBLES:
        raise Refusal(
            "the save's trumble array holds %s entries, not the %d PLAYER_MAX_TRUMBLES the loader "
            "requires (PlayerEntity.m:12161); it would be ignored wholesale."
            % (len(array) if isinstance(array, list) else type(array), PLAYER_MAX_TRUMBLES))
    return int(count), int(checksum), len(array)


def _munge_checksum(state, value):
    """legacy_random.c:48-57, reimplemented exactly. 32-bit truncation then 16-bit mask."""
    value &= 0xFFFFFFFF
    mult = (value & 15) + 8
    state = ((state + value) * mult + mult) & 0xFFFF
    return state


def verify_trumble_checksum(plist):
    """Recompute the anti-cheat checksum over this fixture and report which count it authorises.

    PlayerEntity.m:12097-12101 clears the checksum, mungs the commander name character by
    character, then credits, then ship_kills, then the candidate count. If the file's checksum
    does not match the file's count, :12112-12125 SEARCHES 1..23 for a count that does match - so
    the count the engine ends up with is a function of the checksum, not of the stored integer.
    Knowing that here is what lets the scenario assert the live count is the FILE's count rather
    than merely 'some number'.
    """
    def checksum_for(count):
        state = 0
        for ch in str(plist["player_name"]):
            state = _munge_checksum(state, ord(ch))
        state = _munge_checksum(state, int(plist["credits"]))
        state = _munge_checksum(state, int(plist["ship_kills"]))
        return _munge_checksum(state, count)

    stored_count, stored_checksum, _ = saved_trumble_count(plist)
    authorised = [n for n in range(PLAYER_MAX_TRUMBLES) if checksum_for(n) == stored_checksum]
    return {
        "stored_count": stored_count,
        "stored_checksum": stored_checksum,
        "counts_matching_checksum": authorised,
        "checksum_authorises_stored_count": authorised == [stored_count],
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
    private directory that carries debugConfig.plist carries this too. Verified by running it:
    without the file the log has no [load.progress] lines, with it the full 14-stage sequence.
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

    Returns (ordered stage list, load failure lines, cheat lines, log size). The stages are the
    literal strings PlayerEntityLoadSave.m logs; the scenario requires the whole ordered sequence,
    so a load that died halfway is a different list and fails by name.
    """
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log at all, so the engine's own load evidence "
            "cannot be checked and rc=0 would mean nothing." % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    stages, failures, cheats = [], [], []
    for line in text.splitlines():
        stripped = line.strip()
        if "[load.progress]:" in stripped:
            stages.append(stripped.split("[load.progress]:", 1)[1].strip())
        elif "[load.failed]" in stripped:
            failures.append(stripped)
        elif "[cheat." in stripped:
            cheats.append(stripped.split("]:", 1)[-1].strip())
    return stages, failures, cheats, len(text)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))
    return got


def mission_variable_keys(console):
    """The mission variable KEY SET, read from the live game.

    KEYS, NOT VALUES, and that choice is the whole point: this fixture's `mission_trumbles` is the
    EMPTY STRING, and an absent mission variable also reads as empty, so a value comparison would
    be satisfied by a game that never loaded the save. A fresh commander's dictionary is empty
    (PlayerEntity.m:1986-1987), so the KEY's presence is save-specific and cannot be faked by a
    default game. The engine strips the `mission_` prefix for JS (OOJSMissionVariables.m:191-193).
    """
    raw = console.evaluate(
        "(function(){ var o = []; for (var k in missionVariables) o.push(k);"
        " return o.sort().join(','); })()").strip()
    return [k for k in raw.split(",") if k]


def suppress_populators(console):
    """Switch the system populator off at the source (scenario 001/010's function, unchanged)."""
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
            "no station was found to suppress. This save is docked at Lave's main station by "
            "construction, so zero stations means the save did not load the world.")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` (oolite-populator.js:2656-2680) tests `hasNPCTraffic` inside
    its loop but ENDS WITH an unconditional `return system.mainStation`, so switching the flag off
    does not stop it launching (scenario 010 measured traffic still arriving mid-run). The names
    come from the spec so an upstream rename turns into a red rather than a silent no-op.
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
            "the player is not docked. This save is docked at Lave main station by construction, "
            "so an undocked player means the loaded world is not the saved world.")
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


def grow_population(console, awards):
    """Grow the live trumble population by `awards` awards and return the count after each.

    THE DETERMINISTIC PREFIX, AND WHY IT ENDS AT FOUR. PlayerEntity.m:11521-11534:
        if ((trumbleCount < PLAYER_MAX_TRUMBLES / 6) ||
            (trumbleCount < PLAYER_MAX_TRUMBLES / 3 && ranrot_rand() % 2 > 0))
    With PLAYER_MAX_TRUMBLES = 24 the first FOUR awards take the left branch unconditionally; the
    fifth onwards consult RANROT, and a fixed seed pins the SEQUENCE but not how far a run has
    advanced through it (bead oo-izi). Measured over three runs at seed 20260918 the counts agreed
    for the first four awards and diverged from the fifth - see the module docstring for the
    numbers. The per-award series is RETURNED, not just the final count, so the assertion can name
    the award at which a future engine first disagreed.
    """
    series = []
    for _ in range(awards):
        console.perform("player.ship.awardEquipment('EQ_TRUMBLE');")
        series.append(console.evaluate_int("player.trumbleCount"))
    return series


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
    if evidence["cheat_messages"]:
        raise ScenarioError(
            "the engine logged anti-cheat message(s) while restoring the trumble population: %r. "
            "PlayerEntity.m:12106-12128 emits those when the save's trumble checksum does not "
            "authorise its stored count, and the loader then SEARCHES for a count that does - so "
            "the live population would not be the file's." % (evidence["cheat_messages"],))

    want_keys = sorted(spec["expected_mission_variable_keys"])
    if evidence["mission_variable_keys"] != want_keys:
        raise ScenarioError(
            "the loaded game carries mission variables %r, not the save's %r. A DEFAULT NEW GAME "
            "HAS NONE (PlayerEntity.m:1986-1987), so this is the check a fresh commander cannot "
            "pass. Compared as a KEY SET because this fixture's mission_trumbles is the empty "
            "string and an absent variable reads the same way."
            % (evidence["mission_variable_keys"], want_keys))
    if spec["mission_trumbles_key"] not in evidence["mission_variable_keys"]:
        raise ScenarioError(
            "missionVariables carries no %r key. That is the mission variable this bead names, "
            "and its VALUE is the empty string, so only its PRESENCE can carry evidence."
            % spec["mission_trumbles_key"])

    if evidence["saved_trumble_count"] != int(spec["expected_saved_trumble_count"]):
        raise ScenarioError(
            "the loaded game reports %d trumble(s) from the save but the file's checksum "
            "authorises %d. The anti-cheat search at PlayerEntity.m:12112-12125 has picked a "
            "different count, so the population is not the file's."
            % (evidence["saved_trumble_count"], int(spec["expected_saved_trumble_count"])))
    if not evidence["checksum_authorises_stored_count"]:
        raise ScenarioError(
            "the save's trumble checksum %d does not uniquely authorise its stored count %d "
            "(counts matching: %r). The engine would search for a count that matches and the "
            "live population would be that one instead."
            % (evidence["saved_trumble_checksum"], evidence["saved_trumble_count"],
               evidence["counts_matching_checksum"]))

    awards = int(spec["trumble_awards"])
    if evidence["trumble_award_series"] != list(range(1, awards + 1)):
        raise ScenarioError(
            "growing the population by %d awards produced the counts %r, not %r. The first "
            "PLAYER_MAX_TRUMBLES/6 = %d awards take PlayerEntity.m:11531's LEFT branch "
            "unconditionally; a divergence inside that prefix means the gate's thresholds have "
            "changed. Do NOT raise trumble_awards past %d - the fifth award onwards is a RANROT "
            "draw and was MEASURED to differ between runs at the same seed."
            % (awards, evidence["trumble_award_series"], list(range(1, awards + 1)),
               PLAYER_MAX_TRUMBLES // 6, PLAYER_MAX_TRUMBLES // 6))
    if evidence["trumble_count"] != int(spec["expected_trumble_count"]):
        raise ScenarioError(
            "the live trumble population is %d, expected %d"
            % (evidence["trumble_count"], int(spec["expected_trumble_count"])))
    if not evidence["trumble_count_stable_across_ticks"]:
        raise ScenarioError(
            "the trumble population moved from %d to %d across the %d-tick budget. Breeding needs "
            "trumbleAppetiteAccumulator > 10.0 from eating CARGO PODS (OOTrumble.m:585-627) and a "
            "docked player has none, so this is a FINDING about the engine - report it, do not "
            "widen the tolerance."
            % (evidence["trumble_count_before_ticks"], evidence["trumble_count"],
               evidence["ticks"]))
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
        awards_override=None, frame_out=None, expect_from=None, save_override=None):
    """One game process, one canonical dump, one frame grid.

    `expect_from` is the DETECTION CONTROL for the census: the game still loads --save, but the
    expectation is read from a DIFFERENT file, so a correct engine and a correct comparison MUST
    report a difference. `save_override` swaps the file the GAME loads, which is the other half.
    """
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    awards = int(spec["trumble_awards"] if awards_override is None else awards_override)
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
        checksum = verify_trumble_checksum(plist)

        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=save))
        with console:
            assert_system(console, spec)
            mv_keys = mission_variable_keys(console)
            live = live_census(console, spec)
            saved_count = console.evaluate_int("player.trumbleCount")

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness.
            # Scenario 010 measured eight of ten runs refusing when the suppression came after a
            # multi-second probe, because a station with hasNPCTraffic still on launched traffic
            # in the meantime.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            award_series = grow_population(console, awards)
            count_before_ticks = console.evaluate_int("player.trumbleCount")
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            count_after_ticks = console.evaluate_int("player.trumbleCount")

            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        stages, failures, cheats, log_bytes = read_load_evidence(artifact_dir, spec)

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
            "cheat_messages": cheats,
            "mission_variable_keys": sorted(mv_keys),
            "mission_variable_count": len(mv_keys),
            "saved_trumble_count": saved_count,
            "saved_trumble_checksum": checksum["stored_checksum"],
            "counts_matching_checksum": checksum["counts_matching_checksum"],
            "checksum_authorises_stored_count": checksum["checksum_authorises_stored_count"],
            "trumble_awards": awards,
            "trumble_award_series": award_series,
            "trumble_count_before_ticks": count_before_ticks,
            "trumble_count": count_after_ticks,
            "trumble_count_stable_across_ticks": count_before_ticks == count_after_ticks,
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


# The floor a frame must clear, in frame_hash distance units, to count as RENDERED.
#
# It is NOT a tolerance and it is NOT a same-scene equality test. Measured on this box:
#   largest distance between two frames of THIS SAME SCENE   0.010916   (renderer + HUD noise)
#   smallest distance from an ALL-BLACK frame to a real one  0.031028   (the dimmest real frame)
# The floor sits between them, 1.8x above the noise and 0.65x of the dimmest real frame, so no
# same-scene pair can push a real frame under it and an empty render cannot climb over it. See
# the module docstring for why an EQUALITY comparison is not available to this scenario: the
# animated trumble HUD makes same-scene variation larger than the signal it would have to detect.
FRAME_LIVENESS_FLOOR = 0.020


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        raise ScenarioError(
            "%s is %d bytes, not the %d-byte %dx%d luminance grid; any comparison against it "
            "would be meaningless"
            % (path, len(blob), frame_hash.GRID_CELLS, frame_hash.GRID_SIZE, frame_hash.GRID_SIZE))
    return blob


def compare_frame(grid_path, reference_path, tol=None):
    """Report a captured grid against the stored reference, and assert only LIVENESS.

    WHAT THIS DOES NOT DO, DELIBERATELY: it does not require the two frames to match within the
    measured tolerance. That assertion was tried, measured and rejected - see the module
    docstring. Same-scene pairs of this scenario land at 1.08x..2.49x the tolerance because
    HeadUpDisplay.m:3306 -drawTrumbles: animates the live population on every rendered frame, and
    a ZERO-trumble control frame sits INSIDE that same band (0.63x..1.80x). Signal smaller than
    noise: no threshold separates "same scene" from "wrong scene" here, so the equality verdict
    would be a coin toss dressed as a gate. Coarsening the tolerance until same-scene pairs fit
    is exactly the papering-over this scenario refuses to do.

    What the data DOES support is that something was rendered at all, and that is asserted
    against FRAME_LIVENESS_FLOOR with a 2.8x margin. The distance to the reference is computed
    and PRINTED either way, so a human blessing or reviewing the golden sees the number.
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
        "verdict_rests_on": "liveness",
        "note": ("distance_to_reference is REPORTED, not asserted: same-scene pairs of this "
                 "scenario span %.6f..%.6f (the animated trumble HUD), which straddles the "
                 "tolerance %.6f, and a zero-trumble frame falls inside that same band. The "
                 "verdict is liveness only." % (0.004725, 0.010916, tol)),
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
    return 0


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

    CAPTURES stdout/stderr FOR EVERY RUN REGARDLESS OF EXIT CODE. A sibling harness recorded
    results only when returncode == 0 and so hid runs that wrote a correct dump but exited
    nonzero, reporting '1/10 dumped' when four byte-identical dumps existed.
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
    parser = argparse.ArgumentParser(prog="tests/golden/trumbles_load.py",
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
    parser.add_argument("--awards", type=int, default=None,
                        help="override trumble_awards; values above PLAYER_MAX_TRUMBLES/6 were "
                             "MEASURED to be non-reproducible and exist only for that measurement")
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
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_hv4d_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, awards_override=args.awards,
                     frame_out=args.frame_out, expect_from=args.expect_from,
                     save_override=args.save)
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
    print("LOADED: %s (%s, %d bytes) -> commander %r in %s with %d mission variable(s) including "
          "%r; engine logged all %d load stages; population %d from the save, grown to %d by %d "
          "award(s) and STABLE across %d ticks (%.1fs wall)"
          % (ev["save_file"], ev["save_written_by_version"], ev["save_bytes"],
             result["live"].get("player_name"), spec["system_name"], ev["mission_variable_count"],
             spec["mission_trumbles_key"], len(ev["load_stages"]), ev["saved_trumble_count"],
             ev["trumble_count"], ev["trumble_awards"], ev["ticks"], result["wall_seconds"]))
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
