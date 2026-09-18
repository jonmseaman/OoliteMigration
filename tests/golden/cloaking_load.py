"""Golden scenario 016: load the 1.75-era CloakingDevice checklist save and pin the SAVE FORMAT.

WHAT THIS SCENARIO IS FOR, AND HOW IT DIFFERS FROM SCENARIO 005
==============================================================
Bead oo-ghhw asks for scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame
hash, blessed under the golden policy, 10-run stability) starting from
`upstream/oolite-tests/Checklist-files/Missions/CloakingDevice.oolite-save` through the game's own
`-load` argument, so that the 1.75 save-format compatibility contract is pinned.

Bead oo-rkm's scenario 005 loads THE SAME FIXTURE. The two are deliberately complementary and
assert opposite halves of the same load:

    005 (oo-rkm)  A WORLD-SCRIPT EVENT MUTATED STATE.  systemWillPopulate fires
                  oolite-cloaking-device-mission.js, whose :62 does `missionVariables.cloakcounter++`
                  and whose :71-89 registers a populator that spawns a cloaked Asp. 005 asserts the
                  counter MOVED (6 on disk -> 7 in the engine) and that the ambush exists. Its
                  observables are the trigger's side effects.

    016 (this)    EVERYTHING ELSE SURVIVED THE ROUND TRIP UNCHANGED.  A 1.75 plist is deserialised
                  into a live 2.x engine; this scenario reads a 15-field census, the 16-key saved
                  equipment set and all 10 mission variables out of BOTH the file and the running
                  game and requires them EQUAL - with exactly ONE declared exception, cloakcounter,
                  which is 005's subject. The exception is not a hole: `spec["mission_variable_write_exceptions"]`
                  names the key, the writer and the delta, the run asserts the set of differing
                  keys is EXACTLY that set, and asserts the delta - so a second field quietly
                  failing to round-trip is a RED here, and a cloakcounter that stopped moving is
                  also a RED here.

In one line: 005 proves the engine WROTE one mission variable; 016 proves that every other
observable the 1.75 file carries either survived unchanged or was migrated in a DECLARED way with
a pinned delta and a named mechanism. Neither result implies the other, and 016's gate fails on
dumps 005's gate accepts (a load that corrupted `credits` still fires the trigger) and vice versa.

THE CONTRACT IS A CLOSED PAIR, NOT "EVERYTHING IS IDENTICAL"
============================================================
Loading this 1.75 fixture into the modern engine performs THREE migrations. All three were FOUND
BY RUNNING IT - the first live run failed with "the live ship is MISSING EQ_ENERGY_BOMB" - and all
three are declared in spec.json with their mechanism in the engine source:

  EQ_ENERGY_BOMB is REMOVED.        PlayerEntity.m:1394-1398. Energy bombs are no longer supported
                                    without an OXP, so [OOEquipmentType equipmentTypeWithIdentifier:]
                                    returns nil, the loader deletes the key and sets
                                    energyBombCompensation.
  credits +900.                     PlayerEntity.m:1730-1746 compensates: it tries to mount an
                                    EQ_QC_MINE first and, because all four pylons already carry
                                    EQ_HARDENED_MISSILE, falls to `credits += 9000` (tenths). The
                                    engine LOGS which branch it took on load.upgrade.replacedEnergyBomb,
                                    and this scenario REQUIRES that line - so the credit delta rests
                                    on the engine's own testimony, not on arithmetic that adds up.
  fuel_charge_rate 1.0 -> 2.0.      DERIVED, NOT RESTORED. 1.75 stored the value; the modern engine
                                    never reads the key back. -[PlayerEntity fuelChargeRate]
                                    (PlayerEntity.m:13007-13021) computes it from hull mass
                                    (ShipEntity.m:8122) and scales by state of repair when
                                    ship_trade_in_factor is 75..90 - this commander's is 85.

`compare_sides` + `assert_declared_set` make that a CLOSED PAIR: the set of fields that differ must
be EXACTLY the declared set, so BOTH directions are red - an undeclared field that stopped
round-tripping, AND a declared migration that stopped happening. A count floor cannot do this; it
cannot distinguish 13 equal fields from 12 equal plus one silently drifted (bead oo-9w5).

A MISSION VARIABLE THAT IS THE EMPTY STRING READS IDENTICALLY TO AN ABSENT ONE
=============================================================================
so the evidence carries `mission_variable_keys_in_file` and `mission_variable_keys_in_engine` as
KEY SETS proving PRESENCE, independently of any value comparison. (This fixture has no empty
mission variable today, but its sibling Trumbles.oolite-save does, and a value-only check would
be satisfied by a game that had never heard of the mission.)

BEWARE THE CLOAK - WHY 24 TICKS
===============================
005's trigger spawns an `asp-cloaked`, and bead oo-qwk5 measured that ship family flipping
scanClass CLASS_NEUTRAL -> CLASS_NO_DRAW at t=21.6s when it cloaks. This scenario removes every
non-player, non-station ship to a FIXED POINT before it ticks (removing the Asp drops an "unusual
cargo container", so one pass is not enough - oo-rkm measured that), and then ticks
24 x 0.125 = 3.0s of GAME time, an order of magnitude short of 21.6s. The cloak therefore cannot
reach the dump or the frame by either route: the ship is gone, and the budget ends long before it
would have cloaked. The tick count is that choice, not a default.

THE DELIBERATE ASYMMETRY
========================
`state.json` is hashed byte-wise and its sha256 AND byte count are recorded in `provenance.json`,
a SEPARATE file (bead oo-gxp: a golden cannot witness itself). `frame.grid` is NEVER byte-hashed
into a verdict - llvmpipe is not bit-reproducible - it is compared with the tolerance bead oo-ae9
MEASURED, and the run additionally asserts frame LIVENESS against an all-black grid.
"""

import argparse
import hashlib
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

SCENARIO = "016-cloaking-save"

# goldens/ is a guarded path (tools/guardrails.sh refuses CREATE as well as MODIFY without Jon's
# approval line), so the artifacts are staged under tests/golden/pending/ and BOTH locations are
# searched, in that order - landing them is a pure `git mv`. Scenario 010/012/015's arrangement.
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

MIN_SAVE_BYTES = 1024
MIN_CENSUS_FIELDS = 12          # pinned here AND in test_cloaking_load.py
TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.0
SETTLE_TIMEOUT_SECONDS = 120
CLEAR_ROUNDS = 12
# Measured on this box: same-scene pairs sit far below this and an all-black grid sits at 0.
FRAME_LIVENESS_FLOOR = 0.020


class ScenarioError(RuntimeError):
    """A real difference or a failed precondition (rc=1)."""


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


def save_path(spec, key="load_save"):
    return golden_run._slashes(os.path.join(REPO_ROOT, *spec[key].split("/")))


# --- the file side -----------------------------------------------------------------------------

def read_save_file(path):
    """Parse the .oolite-save and PROVE it is worth comparing against.

    Every failure here is a REFUSAL (rc=2, "I cannot tell you"), never a difference (rc=1) -
    golden_diff.py's convention. A checker that answers "equal" when it could not compare is the
    most dangerous failure mode a gate can have.
    """
    if not os.path.isfile(path):
        raise Refusal("the save file %s DOES NOT EXIST; every check about 'the loaded state' "
                      "would compare the live game against an empty mapping." % path)
    size = os.path.getsize(path)
    if size < MIN_SAVE_BYTES:
        raise Refusal("the save file %s is %d bytes, under the %d-byte floor. A stub parses to "
                      "few or no keys and a comparison against it is vacuous however green."
                      % (path, size, MIN_SAVE_BYTES))
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:  # noqa: BLE001 - any parse failure is a refusal
        raise Refusal("%s is not a readable property list: %s: %s" % (path, type(exc).__name__, exc))
    if not isinstance(data, dict) or not data:
        raise Refusal("%s parsed to %r, which carries no commander data" % (path, type(data)))
    return data, size


def _normalise(value, kind, spec=None):
    """The ONLY place a scale or a format mapping is applied, with NO catch-all branch.

    `float_tenths` is MEASURED: PlayerEntity stores credits and fuel as integers in tenths while
    the JS API reports whole units, so this fixture's 956226 is 95622.6 and its 70 is 7.0.

    `weapon_id` is the one place the two FORMATS genuinely differ in type: 1.75 stores a weapon as
    a legacy OOWeaponType INTEGER while the modern engine reports an equipment key. The mapping is
    read from `spec["weapon_ids"]`, DECLARED rather than inferred, so an upstream renumbering goes
    red instead of being silently absorbed.

    An unknown kind raises rather than inventing a conversion that would make some field agree.
    """
    if kind == "int":
        return int(value)
    if kind == "str":
        return str(value)
    if kind == "float_tenths":
        return round(float(value) / 10.0, 3)
    if kind == "float":
        return round(float(value), 3)
    if kind == "weapon_id":
        table = (spec or {}).get("weapon_ids") or {}
        key = str(int(value))
        if key not in table:
            raise Refusal(
                "the save stores weapon ID %s, which spec['weapon_ids'] does not map to an "
                "equipment key. The 1.75 integer numbering is DECLARED, not inferred; an "
                "unmapped ID is a format finding, not a value to guess." % key)
        return str(table[key])
    raise Refusal("census field declares unknown kind %r; refusing to invent a conversion" % kind)


def saved_census(spec, plist):
    """The LEFT side: read out of the file's own bytes by Python's plist parser."""
    out, missing = {}, []
    for field in spec["census"]:
        key = field["plist"]
        if key not in plist:
            missing.append(key)
            continue
        out[key] = _normalise(plist[key], field["kind"], spec)
    if missing:
        raise Refusal("the save file is missing %d census key(s) this scenario compares on: %s. "
                      "The census describes a save this file is not."
                      % (len(missing), ", ".join(missing)))
    return out


def file_mission_variables(plist):
    """The file's mission_variables, verbatim, with the FILE's key names kept.

    The `mission_` prefix is NOT stripped here: this scenario is about the save FORMAT, so the
    dump carries the format's own key names (`mission_cloakcounter`) and the JS-side names are
    derived from them at comparison time, in one place.
    """
    raw = plist.get("mission_variables")
    if not isinstance(raw, dict) or not raw:
        raise Refusal("%s carries no mission_variables mapping; the mission state this scenario "
                      "round-trips is not in the file at all." % ("the save file",))
    return {str(k): raw[k] for k in raw}


def _norm_mv(value):
    """Normalise ONE mission variable value for cross-reader comparison.

    The 1.75 plist stores every mission variable as a STRING; the engine's JS view reports the
    numeric ones as NUMBERS. Both sides are reduced to a canonical string so that "13" and 13
    compare equal while "MISSION_COMPLETE" and 13 never can. Booleans are handled before the
    numeric branch because `int(True)` is 1 in Python and would silently equal the string "1".
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float) and value == int(value):
        value = int(value)
    text = str(value)
    try:
        return str(int(text))
    except ValueError:
        return text


# --- the live game side ------------------------------------------------------------------------

def _js_json(console, expr):
    raw = console.evaluate(expr).strip()
    try:
        return json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the game answered %r for %s, which is not JSON (%s)"
                            % (raw[:200], expr, exc))


def live_census(console, spec):
    """The RIGHT side: read out of the LIVE game, in a SEPARATE OS PROCESS, over the console.

    Two independent readers sharing no code - Python's plistlib in this process and Oolite's
    Objective-C deserialiser in another - so the two sides cannot be the same object even in
    principle (scenario 006's invariant).
    """
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
        elif kind == "float":
            out[field["plist"]] = round(float(raw), 3)
        elif kind == "weapon_id":
            # The engine side is ALREADY an equipment key; the file side is mapped to one.
            out[field["plist"]] = str(raw)
        else:
            raise Refusal("census field declares unknown kind %r" % kind)
    return out


def live_mission_variables(console):
    """Enumerate missionVariables out of the running engine, keyed by the FILE's names."""
    got = _js_json(console, "(function(){ var o = {}, k;"
                            " for (k in missionVariables) o[k] = missionVariables[k];"
                            " return JSON.stringify(o); })()")
    if not isinstance(got, dict):
        raise ScenarioError("missionVariables enumerated to %r, not an object" % (got,))
    return {"mission_" + str(k): got[k] for k in got}


def live_equipment(console):
    return _js_json(console, "(function(){ var e = player.ship.equipment, o = [], i;"
                             " for (i = 0; i < e.length; i++) o.push(e[i].equipmentKey);"
                             " return JSON.stringify(o.sort()); })()")


def assert_non_vacuous(census, label):
    if len(census) < MIN_CENSUS_FIELDS:
        raise Refusal("%s carries %d field(s), fewer than the %d minimum. A short census is the "
                      "empty-state vacuity route wearing a smaller hat."
                      % (label, len(census), MIN_CENSUS_FIELDS))
    populated = [k for k, v in census.items() if v not in ("", 0, 0.0, None)]
    if len(populated) < MIN_CENSUS_FIELDS // 2:
        raise Refusal("%s has only %d non-empty value(s) out of %d: %r. A census of zeros and "
                      "empty strings compares equal to any other empty census."
                      % (label, len(populated), len(census), census))
    return len(census), len(populated)


def compare_sides(left, right, declared, norm=lambda v: v):
    """THE CLOSED PAIR, used for BOTH the census and the mission variables.

    Returns (equal keys, differing keys, detail). The CALLER asserts that `differing` is EXACTLY
    the declared-migration key set, which makes BOTH failure directions red:
      * a field that stopped round-tripping appears in `differing` and was not declared;
      * a declared migration that stopped happening disappears from `differing` and was declared.
    Neither list may be edited to make a run pass. A count floor alone would not do this: it
    cannot distinguish 13 equal fields from 12 equal plus one silently-drifted (bead oo-9w5).

    REFUSES BY IDENTITY, NOT EQUALITY: a mapping always equals itself, the in-memory twin of
    golden_diff.py's st_dev/st_ino guard. `left == right` is the ANSWER, so using it as the guard
    would refuse every correct load.
    """
    if left is right:
        raise Refusal("both sides of the comparison are the SAME object in memory (id=%d); this "
                      "comparison could never fail." % id(left))
    equal, differing, detail = [], [], {}
    for key in sorted(set(left) | set(right)):
        lv = norm(left[key]) if key in left else None
        rv = norm(right[key]) if key in right else None
        if key in left and key in right and lv == rv:
            equal.append(key)
        else:
            differing.append(key)
            detail[key] = {"in_file": lv, "in_engine": rv,
                           "declared": key in declared,
                           "mechanism": (declared.get(key) or {}).get("mechanism")
                                        or (declared.get(key) or {}).get("writer")}
    return equal, differing, detail


def assert_declared_set(differing, detail, declared, what):
    """`differing` must be EXACTLY `declared` - the assertion the closed pair exists for."""
    if sorted(differing) != sorted(declared):
        undeclared = sorted(set(differing) - set(declared))
        missing = sorted(set(declared) - set(differing))
        raise ScenarioError(
            "%s differ between the FILE and the ENGINE on %r, but this scenario declares exactly "
            "%r. UNDECLARED DRIFT: %r - a field that stopped round-tripping is the save-format "
            "regression this scenario exists to catch. DECLARED BUT ABSENT: %r - a migration the "
            "engine is documented to perform stopped happening. Both are FINDINGS; neither list "
            "is a list to edit. Detail: %r"
            % (what, sorted(differing), sorted(declared), undeclared, missing, detail))


# --- world quieting ------------------------------------------------------------------------

def suppress_populators(console):
    """Switch the system populator off at the source AND prove it is off (scenario 001)."""
    keys = console.evaluate(
        "(function(){ var s = system.populatorSettings, out = [];"
        " for (var k in s) out.push(k);"
        " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
        " return out.join(','); })()").strip()
    remaining = console.evaluate(
        "(function(){ var n = 0; for (var k in system.populatorSettings) n++;"
        " return String(n); })()").strip()
    if remaining not in ("0", ""):
        raise ScenarioError("%s populator setting(s) survived suppression; the system will keep "
                            "adding traffic and every ship it adds consumes RANROT draws"
                            % remaining)
    return [k for k in keys.split(",") if k]


def suppress_station_traffic(console):
    """Switch off every station's own launch schedule (StationEntity.m:960-995)."""
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
        raise ScenarioError("no station was found to suppress. This save is a DOCKED commander by "
                            "construction, so zero stations means the save did not load a world.")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` ends with an UNCONDITIONAL `return system.mainStation`, so
    clearing hasNPCTraffic does not stop it launching (scenario 010/015 measured traffic still
    arriving mid-run). The names come from the SPEC so an upstream rename is a red, not a silent
    no-op.
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
            raise ScenarioError("worldScripts['oolite-populator'].%s did not become a no-op "
                                "(it reads %r)" % (name, after[:120]))
        quieted.append(name)
    return quieted


def clear_system(console):
    removed = console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && !s[i].isStation) { s[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && !s[i].isStation) n++; }"
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
    """Clear AND settle as ONE fixed point; refuse rather than hang if it is never reached.

    REMOVAL CREATES ENTITIES HERE: removing the cloaked Asp that 005's trigger spawns runs its
    death_actions, which drop an "unusual cargo container" into the system, so one sweep reliably
    leaves exactly one entity behind (oo-rkm measured it). A single write is not a clearing.
    """
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
        "The known sources (system populator, StationEntity's own schedule, oolite-populator.js "
        "systemWillRepopulate, the cloaking mission's ambush populator) are all switched off "
        "before this runs; a further source is a FINDING, not a reason to widen the round count."
        % (rounds, history))


def assert_at_rest(console):
    moving = moving_entities(console)
    if moving:
        raise ScenarioError(
            "%d entity/entities still report motion: %s. ShipEntity -velocity is [super velocity] "
            "+ [self thrustVector], so a ship under thrust reads a non-zero velocity no JS write "
            "can clear, whose value depends on the frame count."
            % (len(moving), ", ".join(moving)))
    if console.evaluate("player.ship.docked").strip().lower() != "true":
        raise ScenarioError("the player is not docked. This is a docked commander save by "
                            "construction, so an undocked player means the loaded world is not "
                            "the saved world.")
    return True


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` ticks of GAME time, measured on the GAME's clock, never the harness's."""
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
    raise ScenarioError("the game clock did not advance %ss within %ss" % (seconds, timeout))


def read_upgrade_log(artifact_dir):
    """Pull the ENGINE's OWN testimony about legacy migrations out of THIS run's Latest.log.

    `load.upgrade.replacedEnergyBomb` is logged UNCONDITIONALLY by PlayerEntity.m:1730-1746 (it is
    an OOLog, not OOLogWithFormat on a gated channel), so it needs no logcontrol.plist. It is the
    difference between "credits went up by 900" - arithmetic that could be coincidence - and "the
    loader says it took the cash-compensation branch".
    """
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log at all, so the engine's own migration "
            "testimony cannot be read and rc=0 would mean nothing." % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    lines = [ln.strip().split("]:", 1)[-1].strip()
             for ln in text.splitlines() if "[load.upgrade" in ln]
    return lines, len(text)


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: on Windows the name shows up while the game still
    holds the handle open, so reading it then fails or hashes half a frame (bead oo-gxp).
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


# --- the anti-vacuity gate ---------------------------------------------------------------------

def assert_round_trip(evidence, spec):
    """THE 1.75 SAVE-FORMAT CONTRACT, held at CAPTURE time here and again, independently and
    offline, by check_cloaking_evidence.py - so every future diff against the stored golden
    re-checks it rather than only the capture run."""
    if evidence["save_written_by_version"] != spec["save_format_version"]:
        raise ScenarioError(
            "the fixture reports written_by_version=%r but this scenario pins the %r-era format "
            "as its compatibility contract. If upstream replaced the fixture that is a FINDING: "
            "re-measure, do NOT edit the assertion to match."
            % (evidence["save_written_by_version"], spec["save_format_version"]))

    # --- mission variables: presence, then the closed pair ------------------------------------
    want_keys = sorted(spec["expected_mission_variable_keys"])
    for side in ("mission_variable_keys_in_file", "mission_variable_keys_in_engine"):
        if evidence[side] != want_keys:
            raise ScenarioError(
                "%s is %r, not the %d key(s) this 1.75 save carries (%r). A DEFAULT NEW GAME HAS "
                "NONE (PlayerEntity.m:1986-1987), so this key SET is what a run that ignored "
                "-load cannot produce. KEYS, NEVER VALUES: an empty-string mission variable reads "
                "identically to an absent one, so presence must be witnessed on its own."
                % (side, evidence[side], len(want_keys), want_keys))

    writes = spec["mission_variable_write_exceptions"]
    assert_declared_set(evidence["mission_variables_differing"],
                        evidence["mission_variables_detail"], writes,
                        "the mission variables that")
    for key, rule in writes.items():
        got = evidence["mission_variables_detail"][key]
        if int(got["in_engine"]) - int(got["in_file"]) != int(rule["delta"]):
            raise ScenarioError(
                "%s reads %r on disk and %r in the engine, a delta of %d, but %s is declared to "
                "write %+d. EQUAL VALUES WOULD BE THE DESERIALISER-COPY SIGNATURE and any other "
                "delta means something else is writing this key too."
                % (key, got["in_file"], got["in_engine"],
                   int(got["in_engine"]) - int(got["in_file"]), rule["writer"], int(rule["delta"])))
    if evidence["mission_variables_equal_count"] < int(spec["min_mission_variables_round_tripped"]):
        raise ScenarioError(
            "only %d mission variable(s) round-tripped unchanged, under the floor of %d. A single "
            "surviving field plus the declared write would otherwise satisfy the exact-set clause."
            % (evidence["mission_variables_equal_count"],
               int(spec["min_mission_variables_round_tripped"])))

    # --- the census: the same closed pair, over the format's own field types ------------------
    migrations = spec["census_migrations"]
    assert_declared_set(evidence["census_differing"], evidence["census_detail"], migrations,
                        "the census fields that")
    for key, rule in migrations.items():
        got = evidence["census_detail"][key]
        delta = round(float(got["in_engine"]) - float(got["in_file"]), 3)
        if delta != round(float(rule["delta"]), 3):
            raise ScenarioError(
                "census field %s reads %r on disk and %r in the engine, a delta of %r, but this "
                "scenario pins %r. The declared mechanism is: %s. A changed delta means the "
                "migration changed; re-measure it, do NOT adjust the number."
                % (key, got["in_file"], got["in_engine"], delta, rule["delta"], rule["mechanism"]))
    if evidence["census_equal_count"] < int(spec["min_census_fields_round_tripped"]):
        raise ScenarioError(
            "only %d census field(s) round-tripped unchanged, under the floor of %d."
            % (evidence["census_equal_count"], int(spec["min_census_fields_round_tripped"])))

    # --- equipment: containment minus declared removals, witnessed by the ENGINE's own log ----
    removals = {k for k, v in spec["equipment_migrations"].items() if v["disposition"] == "REMOVED"}
    unexplained = sorted(set(evidence["equipment_missing_in_engine"]) - removals)
    if unexplained:
        raise ScenarioError(
            "the live ship is MISSING %d item(s) the save restored and this scenario does NOT "
            "declare a migration for: %r. `extra_equipment` is the 1.75 format's equipment record "
            "and a loader that silently drops entries from it is exactly the save-format "
            "regression this scenario pins." % (len(unexplained), unexplained))
    still_present = sorted(removals - set(evidence["equipment_missing_in_engine"]))
    if still_present:
        raise ScenarioError(
            "this scenario declares %r to be REMOVED by the loader's legacy migration, but the "
            "live ship still carries %r. The declared migration stopped happening; that is a "
            "FINDING about the loader, not a line to delete." % (sorted(removals), still_present))
    for key, rule in spec["equipment_migrations"].items():
        if rule["disposition"] != "REMOVED":
            continue
        want = rule["compensation_log_substring"]
        if want not in evidence["upgrade_log_lines_text"]:
            raise ScenarioError(
                "the engine logged no %r line for the %s migration. Its own testimony on the "
                "%s channel is what makes the credit delta PROOF of the compensation branch "
                "rather than arithmetic that happened to add up; without it the assertion is "
                "circumstantial. Lines seen: %r"
                % (want, key, rule["compensation_log_channel"], evidence["upgrade_log_lines"]))
    if evidence["equipment_saved_count"] != int(spec["expected_equipment_count"]):
        raise ScenarioError(
            "the fixture's extra_equipment carries %d key(s), not the %d this scenario pins; the "
            "containment assertion would be measuring a different save."
            % (evidence["equipment_saved_count"], int(spec["expected_equipment_count"])))

    if not evidence["world_at_rest"] or not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the world was not at a fixed point when the dump was taken; its "
                            "values would be frame-count dependent")
    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met, so the dump is not the state this "
                            "scenario specifies")
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, expect_from=None, save_override=None):
    """One game process, one canonical dump, one frame grid.

    `expect_from` is the DETECTION CONTROL: the game still loads the real save, but the
    expectation is read from a DIFFERENT checklist save, so a correct engine and a correct
    comparison MUST report a difference. `save_override` swaps the file the GAME loads, the other
    half of the same control.
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

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir)
    started = time.time()
    try:
        plist, size = read_save_file(save)
        expect_plist, _ = read_save_file(expect_from) if expect_from else (plist, size)
        saved = saved_census(spec, expect_plist)
        file_mv = file_mission_variables(expect_plist)

        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=save))
        with console:
            system_id = console.evaluate_int("system.ID")
            if system_id != int(spec["system_id"]):
                raise ScenarioError(
                    "scenario %s is pinned to system ID %d (%s) but the loaded save is in system "
                    "ID %d" % (SCENARIO, int(spec["system_id"]), spec.get("system_name"),
                               system_id))
            live = live_census(console, spec)
            engine_mv = live_mission_variables(console)
            equip_live = live_equipment(console)

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness.
            # Scenario 010 measured eight of ten runs refusing when suppression came after a
            # multi-second probe, because a station with hasNPCTraffic still on launched traffic
            # in the meantime.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        equip_saved = sorted(str(k) for k in (expect_plist.get("extra_equipment") or {}))
        # AFTER the game has exited, so the log is complete and flushed.
        upgrade_lines, log_bytes = read_upgrade_log(artifact_dir)

        mv_equal, mv_diff, mv_detail = compare_sides(
            file_mv, engine_mv, spec["mission_variable_write_exceptions"], norm=_norm_mv)
        n_saved, pop_saved = assert_non_vacuous(saved, "the census read from the save FILE")
        assert_non_vacuous(live, "the census read from the LOADED GAME")
        c_equal, c_diff, c_detail = compare_sides(saved, live, spec["census_migrations"])

        evidence = {
            "scenario": SCENARIO,
            "save_file": os.path.basename(save),
            "save_bytes": size,
            "save_written_by_version": str(plist.get("written_by_version", "")),
            "census_fields": n_saved,
            "census_populated": pop_saved,
            "census_equal": c_equal,
            "census_equal_count": len(c_equal),
            "census_differing": c_diff,
            "census_detail": c_detail,
            "mission_variable_keys_in_file": sorted(file_mv),
            "mission_variable_keys_in_engine": sorted(engine_mv),
            "mission_variable_count": len(file_mv),
            "mission_variables_equal": mv_equal,
            "mission_variables_equal_count": len(mv_equal),
            "mission_variables_differing": mv_diff,
            "mission_variables_detail": mv_detail,
            "equipment_saved_count": len(equip_saved),
            "equipment_missing_in_engine": sorted(set(equip_saved) - set(equip_live)),
            "equipment_live_only": sorted(set(equip_live) - set(equip_saved)),
            "upgrade_log_lines": upgrade_lines,
            "upgrade_log_lines_text": "\n".join(upgrade_lines),
            "world_at_rest": bool(at_rest),
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump -
            # the overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor).
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": system_id,
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
        }
        assert_round_trip(evidence, spec)
        # The canonical dump carries the mission variables at TOP LEVEL under the FILE's own key
        # names, so `mission_cloakcounter` is in the golden by name and any future diff sees it.
        state["mission_variables"] = {k: _norm_mv(v) for k, v in engine_mv.items()}
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
                "png": golden_run._slashes(png),
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


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        raise ScenarioError("%s is %d bytes, not the %d-byte %dx%d luminance grid; any comparison "
                            "against it would be meaningless"
                            % (path, len(blob), frame_hash.GRID_CELLS, frame_hash.GRID_SIZE,
                               frame_hash.GRID_SIZE))
    return blob


def compare_frame(grid_path, reference_path, tol=None):
    """Compare a captured grid with the stored reference: tolerance AND liveness, both printed.

    NEVER byte-wise. llvmpipe is not bit-reproducible across runs, so a byte comparison of the
    frame would flake on renderer noise; the tolerance is the one bead oo-ae9 MEASURED and is used
    as measured, never adjusted to make a run pass. LIVENESS is asserted separately because a run
    that died before drawing produces an all-black grid that is within tolerance of nothing.
    """
    tol = frame_hash.derive_tolerance() if tol is None else tol
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    d = frame_hash.distance(got, want)
    live = frame_hash.distance(got, bytes(frame_hash.GRID_CELLS))
    result = {
        "distance_to_reference": d, "tolerance": tol,
        "ratio_to_tolerance": d / tol if tol else float("inf"),
        "within_tolerance": d <= tol,
        "liveness": live, "liveness_floor": FRAME_LIVENESS_FLOOR,
        "live": live >= FRAME_LIVENESS_FLOOR,
        "hash_got": frame_hash.hex_digest(got), "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    if not result["live"]:
        print("FAIL: %s has luminance distance %.6f from an all-black frame, below the %.6f "
              "floor. Nothing was rendered - this is what a run that died before drawing, or drew "
              "into a lost context, produces." % (grid_path, live, FRAME_LIVENESS_FLOOR),
              file=sys.stderr)
        return 1
    if not result["within_tolerance"]:
        print("FAIL: %s is %.6f from the stored reference, %.2fx the MEASURED tolerance %.6f. "
              "Investigate before re-blessing; do NOT widen the tolerance to make it pass."
              % (grid_path, d, d / tol, tol), file=sys.stderr)
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
    """N independent runs, ACCOUNTING FOR EVERY RUN and reporting REFUSED and DIFFERED separately.

    Captures each run's outcome regardless of exit code: a sibling harness recorded results only
    when returncode == 0 and so hid runs that wrote a correct dump but exited nonzero.
    """
    out_dir = os.path.join(run_root, "stability")
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for i in range(1, runs + 1):
        out = os.path.join(out_dir, "run%02d.json" % i)
        grid = os.path.join(out_dir, "run%02d.grid" % i)
        # A HARNESS MUST DELETE ITS OUTPUT PATH BEFORE EVERY RUN, or a stale artifact from an
        # earlier invocation is read as "this run produced output" (bead oo-gxp).
        for path in (out, grid):
            if os.path.exists(path):
                os.remove(path)
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
    }
    # EVERY RUN MUST BE ACCOUNTED FOR: a sweep whose verdicts do not sum to `runs` is reporting on
    # a population it did not observe.
    summary["accounted_for"] = (summary["dumps_written"] + summary["refused"]
                                + summary["errored"]) == runs
    if len(dumped) < 2:
        summary["WARNING"] = ("FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing "
                              "to compare and no stability claim can be made from this sweep."
                              % (len(dumped), runs))
    summary["stable"] = len(dumped) >= 2 and len(digests) == 1 and summary["accounted_for"]
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/cloaking_load.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--save", default=None, help="override the .oolite-save the GAME loads")
    parser.add_argument("--expect-from", default=None,
                        help="DETECTION CONTROL: read the expected census and mission variables "
                             "from this save while the game loads the real one; a different "
                             "checklist save MUST produce a difference")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    parser.add_argument("--census-only", action="store_true",
                        help="print the saved-side census and mission variables, no game launch")
    args = parser.parse_args(argv)

    spec = load_spec()

    if args.compare_frame:
        return compare_frame(args.compare_frame[0], args.compare_frame[1])
    if args.census_only:
        try:
            plist, _ = read_save_file(args.save or save_path(spec))
            print(json.dumps({"census": saved_census(spec, plist),
                              "mission_variables": file_mission_variables(plist),
                              "extra_equipment": sorted(plist.get("extra_equipment") or {})},
                             indent=2, sort_keys=True))
        except Refusal as exc:
            sys.stderr.write("REFUSED: %s\n" % exc)
            return 2
        return 0

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 2
    ensure_launchable(app_dir)
    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_ghhw_runs")
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
    print("ROUND TRIP: %s (%s-era, %d bytes) -> %d/%d census field(s) and %d/%d mission "
          "variable(s) identical across two independent readers; the only differences are the "
          "DECLARED migrations %r and the declared engine write %r; all %d saved equipment key(s) "
          "accounted for, engine testimony %r (%.1fs wall)"
          % (ev["save_file"], ev["save_written_by_version"], ev["save_bytes"],
             ev["census_equal_count"], ev["census_fields"],
             ev["mission_variables_equal_count"], ev["mission_variable_count"],
             ev["census_differing"], ev["mission_variables_differing"],
             ev["equipment_saved_count"], ev["upgrade_log_lines"], result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
