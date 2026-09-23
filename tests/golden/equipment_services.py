"""Golden scenario 019: equipment and station services, docked at Lave's main station.

WHAT THIS SCENARIO IS FOR
=========================
`docs/phases/0-scenarios-18-20.md` §019 and `docs/phases/scenario-catalogue.json` ask for the one
surface no golden looks at. Read what a golden stores today (`tests/golden/dump/dump_state.js`):
`entities`, `market`, and a player block of `credits / legalStatus / score / cargo` plus four ship
fields. THERE IS NO EQUIPMENT ANYWHERE IN ANY GOLDEN. Scenario 004 is commodities - a different
registry, different pricing, a different storage model. Scenario 003's damage is ship `energy`;
equipment damage is a separate state machine (`EQUIPMENT_OK` -> `EQUIPMENT_DAMAGED`) reached by a
different call. The component tier cannot see it at all: its step library exposes role counts and
liveness only.

Item 0.1 names EQUIPMENT ORDERING as a prime suspect for iteration-order non-determinism. The
equipment registry is the only place a golden could ever see that regression, so this scenario
stores the registry's ENTIRE ORDERED KEY LIST (`evidence.registry_order`) as well as the player's
own ordered array. A reordering with the same members changes the dump and nothing else would.

THE DUMP IS NOT MODIFIED TO GET THIS. `dump_state.js` is shared by every landed golden, so adding
an equipment block there would move 002-017's dumps too. This scenario adds its own `equipment`
and `evidence` blocks to the state it dumps, exactly as scenario 015 adds `evidence`.

WHY THE SCENARIO NEVER LEAVES THE DOCK
======================================
Deliberate, and it is what makes this the cheapest defensible addition to the set. Bead oo-qwk5
and scenario 001 both measured the system populator perturbing a flying world; `undocked_seen` is
expected FALSE here and is RECORDED as false rather than omitted, so a future run that somehow
launches fails by name instead of silently measuring a different world.

THE FIVE MEASURED FACTS THIS SCENARIO RESTS ON (all read off this build, 2026-09-19)
====================================================================================
  1. `Resources/Scenarios/oolite-standard.oolite-save` starts DOCKED at Lave's Coriolis Station
     with an EMPTY equipment array and 100 credits. An empty array matters: "the equipment array
     is non-empty" is explicitly NOT evidence in the catalogue because the starting ship usually
     carries equipment - here it carries none, so every member of the final array was put there
     by this scenario.
  2. The station reports `equipmentPriceFactor` 1 and `equivalentTechLevel` 4; the system's own
     tech level is also 4. Both are read from the ENGINE and stored.
  3. `EQ_ECM` is price 6000, techLevel 2, `canBeDamaged` true - purchasable at TL 4.
     `EQ_DOCK_COMP` is techLevel 9, ABOVE this station's level, and is the control that proves
     the tech-level numbers discriminate rather than being a constant the harness invented.
  4. `EQ_FUEL_SCOOPS` is `canBeDamaged` true and not carry-multiple: awarding it twice is REFUSED
     (`canAwardEquipment` returns false), and `setEquipmentStatus(..., 'EQUIPMENT_DAMAGED')`
     really moves it to `EQUIPMENT_DAMAGED`.
  5. `EQ_CARGO_BAY` is `canBeDamaged` FALSE (OOEquipmentType.m:566-568 via `damage_probability = 0`
     in equipment.plist). `setEquipmentStatus(..., 'EQUIPMENT_DAMAGED')` on it returns FALSE and
     the status stays `EQUIPMENT_OK` - measured. That REFUSAL is positive evidence the status
     machine applies rules; a model that accepts every write reports DAMAGED here.

ANTI-VACUITY: WHAT A DEAD OR DEGENERATE RUN CANNOT PRODUCE
==========================================================
rc=0 and an absence of ERROR lines are BOTH satisfiable by a run that died in display setup (bead
oo-het captured a real exit-87 corpse with zero ERROR lines), and on a shared box a sibling
worker's console can quit a game four seconds in while it still exits 0. So every clause below is
POSITIVE, and three of them are ENGINE REFUSALS, which a permissive stub cannot fake:

  * `duplicate_award_refused` - `canAwardEquipment` must return FALSE for the second award of a
    non-carry-multiple item. A model that accepts every write returns true.
  * `damage_refused_for_undamageable` - `setEquipmentStatus(EQ_CARGO_BAY, 'EQUIPMENT_DAMAGED')`
    must return FALSE **and** leave the status at `EQUIPMENT_OK`. Both halves are stored: a
    checker that only looked at the boolean would accept an engine that returned false while
    damaging the item anyway.
  * `tech_level_gate` - the station's `equivalentTechLevel` must be >= the purchased item's
    techLevel and < the control item's. Two keys straddling the value prove the number means
    something; one key on one side of it would pass against any constant.

  and two are state deltas the harness physically cannot write:

  * `equipment_count_delta` - `Ship.equipment` is READ-ONLY in the API snapshot
    (`oxp-contract/js-api-1.93.json`: `"equipment": {... "writable": false}`), so the harness can
    only ASK the engine to award and then read what the engine says.
  * `status_transition` - BOTH readings are stored, so a collapsed state machine shows up as the
    same value twice rather than as a missing field.

THE PURCHASE, AND WHAT IT HONESTLY PINS
=======================================
There is NO JS entry point that buys equipment: `-buySelectedItem` (PlayerEntity.m:10174) is
reachable only from the equip-ship GUI screen through PlayerEntityControls.m:2707-2736, i.e. a
keypress. So the purchase is modelled the way every OXP models it, and the honest claim is stated
rather than implied: the harness debits `player.credits` by `price * equipmentPriceFactor`, where
BOTH numbers come from the engine - `EquipmentInfo.price` is loaded from `equipment.plist`
(OOEquipmentType.m:205) and `equipmentPriceFactor` from the station's own shipdata
(StationEntity.m:696-697). The dump stores `credits_before`, `purchase_price`,
`equipment_price_factor`, `purchase_charge` and `credits_after` SEPARATELY, so a pricing change
makes the stored golden and a fresh run disagree BY NAME, and the checker independently re-derives
the arithmetic. What this does NOT claim is that the GUI purchase path was exercised; that path
needs a keypress and is out of reach of every headless harness in this repository (scenario 006's
finding for the save half, applied here).

`player.credits` is topped up to a pinned `credits_start` first, because the standard save carries
100 credits and the item costs 6000. That write is the SETUP, not the measurement: what is
measured is that the engine's price and the station's factor produce the recorded balance.

PORT / LAUNCH ISOLATION
=======================
`golden_run.py` wholesale, as 001/002/015 do: a reserved port, a staged app dir, and a
debugConfig.plist in a private `OO_ADDITIONALADDONSDIRS`, because the game DIALS OUT to the port
named in that plist (OODebugSupport.m:67-80). A run on the shared 8563 can be captured by a
sibling worker's console and quit seconds in while still exiting rc=0 (bead oo-het).
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

SCENARIO = "019-equipment-and-station-services"

# Guarded location FIRST, staged location second, through the identical idiom every other
# scenario uses, so landing is a pure `git mv` with no code change (bead oo-8ij: guardrails.sh
# refuses CREATE as well as MODIFY under goldens/, so a worker cannot land them itself).
SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "spec.json"),
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
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

TICK_WALL_BUDGET_SECONDS = 300
SETTLE_TIMEOUT_SECONDS = 120
FRAME_SETTLE_SECONDS = 1.5
CLEAR_ROUNDS = 20
# console.py's own default is 15 s, measured too short on this fleet box when two sibling workers'
# games are resident (bead oo-rkm). Raising it changes no recorded value: every measured quantity
# comes from inside the game (clock.absoluteSeconds, the equipment array, the credit balance).
CONSOLE_REPLY_TIMEOUT_SECONDS = 90

# Fallback only. The real floor is read from provenance.json - the witness that lives OUTSIDE the
# artifact it defends (bead oo-gxp) - so a stripped checkout still has a predicate with teeth
# rather than silently passing everything.
FRAME_LIVENESS_FLOOR_FALLBACK = 0.2

EQUIPMENT_OK = "EQUIPMENT_OK"
EQUIPMENT_DAMAGED = "EQUIPMENT_DAMAGED"
EQUIPMENT_UNAVAILABLE = "EQUIPMENT_UNAVAILABLE"


class ScenarioError(RuntimeError):
    """The run did not produce what this scenario asserts (rc=1)."""


class Refusal(RuntimeError):
    """The comparison could not be performed soundly, so no verdict is given (rc=2)."""


class PatientConsole:
    """A DebugConsole wrapper that waits longer for an answer, and NOTHING else.

    Scenario 002's class, for its measured reason: a 15-second reply timeout is generous on an
    idle machine and too short on a fleet box with sibling games resident, and a socket round trip
    is not one of this scenario's assertions.
    """

    def __init__(self, inner, timeout):
        self._inner = inner
        self._timeout = timeout

    def evaluate(self, js, timeout=None):
        return self._inner.evaluate(js, timeout=self._timeout if timeout is None else timeout)

    def evaluate_int(self, js, timeout=None):
        return self._inner.evaluate_int(js, timeout=self._timeout if timeout is None else timeout)

    def perform(self, js):
        return self._inner.perform(js)

    def close(self):
        return self._inner.close()


def safe_close(console):
    """Tear the console down WITHOUT letting the teardown replace the run's real exception."""
    try:
        console.close()
    except Exception as exc:  # noqa: BLE001 - reported, never allowed to mask the real failure
        sys.stderr.write("[teardown] console.close() raised %s: %s (ignored; the run's own "
                         "verdict stands)\n" % (type(exc).__name__, exc))


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


# --- the world, made quiet -----------------------------------------------------------------


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s pins system ID %d (%s) but the game reports %d"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))
    return got


def assert_docked(console, spec):
    """DOCKED THROUGHOUT is a knob of this scenario, not an incidental state.

    Returns the docked station's name. Every equipment price this scenario records comes from
    `player.ship.dockedStation`, so an undocked player makes the whole pricing half unreadable
    rather than merely different.
    """
    if console.evaluate("player.ship.docked").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked. %s is docked-throughout by construction (spec docked=%r): "
            "equipmentPriceFactor and equivalentTechLevel are read off player.ship.dockedStation, "
            "which is null in flight, so an undocked run measures nothing this scenario is about."
            % (SCENARIO, spec["docked_throughout"]))
    name = console.evaluate(
        "player.ship.dockedStation ? player.ship.dockedStation.name : ''").strip()
    if not name:
        raise ScenarioError(
            "player.ship.docked is true but dockedStation has no name; the world did not load")
    if console.evaluate("String(player.ship.dockedStation.isMainStation)").strip().lower() != "true":
        raise ScenarioError(
            "the player is docked at %r, which is NOT the system's main station. This scenario "
            "pins the MAIN station's tech-level-derived pricing; a rock hermit prices differently."
            % name)
    return name


def suppress_populators(console):
    """Switch the system populator off at the source (scenario 001/015's function, unchanged)."""
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
            "%s populator setting(s) survived suppression; the system will keep adding traffic"
            % remaining)
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
    if not count:
        raise ScenarioError(
            "no station was found to suppress. This save is docked at Lave's main station by "
            "construction, so zero stations means the save did not load the world.")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` ENDS WITH an unconditional `return system.mainStation`, so
    switching `hasNPCTraffic` off does not stop it launching. The handler names come from the spec
    so an upstream rename turns into a red rather than a silent no-op.
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
    """`magnitude` IS A FUNCTION, NOT A PROPERTY - it is CALLED (bead oo-jor shipped a version
    comparing the function OBJECT with a number, which is always false, so the guard passed on
    every run including ones whose dumps differed)."""
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


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` ticks of GAME time, measured on clock.absoluteSeconds INSIDE the game.

    Never the harness clock: `tick_budget_met` is the one evidence field a photograph of tick 0
    cannot satisfy, and it is only worth that if the quantity measured is the universe clock.
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
    Windows shows up while the game still holds the handle open for writing. Both PermissionError
    and a truncated read are retried; a frame that never becomes readable is a REFUSAL rather than
    a hash of half a file (scenario 010's finding).
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


# --- the equipment observables ------------------------------------------------------------


def equipment_keys(console):
    """The player's OWN equipment array, in the engine's order, as a list of keys.

    ORDER IS PRESERVED DELIBERATELY. `Ship.equipment` is built by
    -equipmentListForScripting (ShipEntity.m:3350-3380), which walks
    `[OOEquipmentType allEquipmentTypes]` - the registry's own enumeration order. That order is
    item 0.1's prime suspect for iteration-order non-determinism and no other golden stores it,
    so sorting here would throw away the property the scenario exists to pin.
    """
    raw = console.evaluate(
        "(function(){ var e = player.ship.equipment, o = [];"
        " for (var i = 0; i < e.length; i++) o.push(e[i].equipmentKey);"
        " return JSON.stringify(o); })()").strip()
    return json.loads(raw)


def registry_order(console):
    """EVERY equipment key the registry knows, in the registry's own order.

    `EquipmentInfo.allEquipment` returns `[OOEquipmentType allEquipmentTypes]`
    (OOJSEquipmentInfo.m:507), which is the plist load order. This is the ONLY artifact in the
    repository that pins it, and pinning it is the whole reason item 0.1 names equipment ordering.
    """
    raw = console.evaluate(
        "(function(){ var a = EquipmentInfo.allEquipment, o = [];"
        " for (var i = 0; i < a.length; i++) o.push(a[i].equipmentKey);"
        " return JSON.stringify(o); })()").strip()
    return json.loads(raw)


def equipment_info(console, key):
    """The registry's record for one key, read from the engine (never from equipment.plist here).

    Reading the plist in Python would make the comparison a Python-vs-Python identity; every
    number here crosses the process boundary out of the engine's own loaded registry.
    """
    raw = console.evaluate(
        "(function(){ var i = EquipmentInfo.infoForKey(%s);"
        " if (!i) return 'null';"
        " return JSON.stringify({key: i.equipmentKey, price: i.price, techLevel: i.techLevel,"
        " effectiveTechLevel: i.effectiveTechLevel, canBeDamaged: i.canBeDamaged,"
        " requiresEmptyPylon: i.requiresEmptyPylon, name: i.name}); })()"
        % json.dumps(key)).strip()
    info = json.loads(raw)
    if info is None:
        raise ScenarioError(
            "EquipmentInfo.infoForKey(%r) came back null: the registry does not know this key, so "
            "every price, tech level and status this scenario records for it would be undefined. "
            "Either equipment.plist changed or the spec names a key that never existed." % key)
    return info


def equipment_status(console, key):
    return console.evaluate("String(player.ship.equipmentStatus(%s))" % json.dumps(key)).strip()


def can_award(console, key):
    raw = console.evaluate(
        "String(player.ship.canAwardEquipment(%s))" % json.dumps(key)).strip().lower()
    if raw not in ("true", "false"):
        raise ScenarioError("canAwardEquipment(%r) answered %r, which is neither true nor false; "
                            "a non-boolean refusal cannot be read as a refusal" % (key, raw))
    return raw == "true"


def award(console, key):
    raw = console.evaluate(
        "String(player.ship.awardEquipment(%s))" % json.dumps(key)).strip().lower()
    return raw == "true"


def set_status(console, key, status):
    raw = console.evaluate(
        "String(player.ship.setEquipmentStatus(%s, %s))"
        % (json.dumps(key), json.dumps(status))).strip().lower()
    return raw == "true"


def remove_equipment(console, key):
    console.perform("player.ship.removeEquipment(%s);" % json.dumps(key))


def credits(console):
    return float(console.evaluate("String(player.credits)").strip())


def set_credits(console, value):
    console.perform("player.credits = %s;" % json.dumps(value))
    return credits(console)


def station_services(console):
    """The station's pricing inputs, read from the ENGINE, plus the system's own tech level.

    `equipmentPriceFactor` comes from the station's shipdata (StationEntity.m:696-697, floored at
    0.5) and `equivalentTechLevel` from `equivalent_tech_level` there; PlayerEntity.m:9300-9308
    prefers the station's value over `[[UNIVERSE currentSystemData] KEY_TECHLEVEL]` when the
    station declares one, which is why BOTH are stored: a change to either moves the price, and
    storing only the result could not say which.
    """
    raw = console.evaluate(
        "(function(){ var s = player.ship.dockedStation;"
        " return JSON.stringify({station_name: s.name,"
        " equipment_price_factor: s.equipmentPriceFactor,"
        " equivalent_tech_level: s.equivalentTechLevel,"
        " system_tech_level: system.info.techlevel,"
        " service_level: player.ship.serviceLevel}); })()").strip()
    return json.loads(raw)


def award_cycle(console, spec):
    """The award / query / duplicate-refusal / damage / remove cycle on ONE pinned key.

    THE KEY IS NAMED IN THE SPEC, not picked as "whatever was first in a list" - the catalogue's
    own requirement, and the reason is that a list-order pick makes the scenario silently measure
    a different item the day the registry is reordered, which is precisely the regression this
    scenario exists to catch.
    """
    key = spec["award_key"]
    info = equipment_info(console, key)
    before = equipment_keys(console)
    status_before = equipment_status(console, key)

    can_before = can_award(console, key)
    awarded = award(console, key)
    after = equipment_keys(console)
    status_after_award = equipment_status(console, key)

    # THE REFUSAL. A second award of a non-carry-multiple item must be refused; a model that
    # accepts every write answers true here.
    can_duplicate = can_award(console, key)

    # THE STATUS MACHINE. BOTH readings are stored: a collapsed machine reports the same value
    # twice rather than dropping a field, and only storing both makes that visible in the diff.
    damage_accepted = set_status(console, key, EQUIPMENT_DAMAGED)
    status_after_damage = equipment_status(console, key)
    keys_after_damage = equipment_keys(console)

    remove_equipment(console, key)
    status_after_remove = equipment_status(console, key)
    after_remove = equipment_keys(console)

    return {
        "key": key,
        "info": info,
        "keys_before": before,
        "keys_after_award": after,
        "keys_after_damage": keys_after_damage,
        "keys_after_remove": after_remove,
        "count_before": len(before),
        "count_after_award": len(after),
        "count_delta": len(after) - len(before),
        "present_after_award": key in after,
        "can_award_before": can_before,
        "award_returned": awarded,
        "status_before": status_before,
        "status_after_award": status_after_award,
        "can_award_duplicate": can_duplicate,
        "damage_accepted": damage_accepted,
        "status_after_damage": status_after_damage,
        "status_transition": [status_after_award, status_after_damage],
        "status_after_remove": status_after_remove,
        "count_after_remove": len(after_remove),
    }


def undamageable_probe(console, spec):
    """The OTHER refusal: an item the registry says cannot be damaged must REFUSE the write.

    Both halves are recorded - the boolean the call returns AND the status read back afterwards -
    because a checker that looked only at the boolean would accept an engine that answered false
    while damaging the item anyway, and a checker that looked only at the status would accept one
    that answered true and silently did nothing.
    """
    key = spec["undamageable_key"]
    info = equipment_info(console, key)
    if info["canBeDamaged"]:
        raise ScenarioError(
            "spec undamageable_key=%r but the engine reports canBeDamaged=true for it. The "
            "refusal arm needs an item the registry itself declares undamageable "
            "(OOEquipmentType.m:566-568); pointed at a damageable item it would assert the "
            "OPPOSITE of the engine's contract and go red for the right reason at the wrong item."
            % key)
    awarded = award(console, key)
    status_after_award = equipment_status(console, key)
    accepted = set_status(console, key, EQUIPMENT_DAMAGED)
    status_after = equipment_status(console, key)
    return {
        "key": key,
        "info": info,
        "award_returned": awarded,
        "status_after_award": status_after_award,
        "damage_accepted": accepted,
        "status_after_damage_attempt": status_after,
        "refused": (not accepted) and status_after == EQUIPMENT_OK,
    }


def purchase(console, spec, services):
    """Buy one item at the engine's own price, and record every input separately.

    See the module docstring for what this does and does not claim. The arithmetic is done here
    but NEITHER NUMBER IS: `price` comes out of the engine's loaded registry and `factor` off the
    station, so a change to equipment.plist or to the station's `equipment_price_factor` moves the
    recorded balance and the stored golden goes red by name.
    """
    key = spec["purchase_key"]
    info = equipment_info(console, key)
    factor = float(services["equipment_price_factor"])
    price = float(info["price"])
    charge = round(price * factor, 3)

    start_balance = float(spec["credits_start"])
    balance = set_credits(console, start_balance)
    if abs(balance - start_balance) > 1e-6:
        raise ScenarioError(
            "player.credits read back %r after being set to %r. PlayerEntity stores credits as "
            "deci-credits (PlayerEntityScriptMethods.m:52-59: creditBalance is 0.1*credits), so a "
            "value with more than one decimal place does not survive the round trip - pin a "
            "credits_start the engine can represent." % (balance, start_balance))
    if charge > balance:
        raise ScenarioError(
            "the purchase costs %.3f credits (price %.3f x factor %.3f) but the pinned starting "
            "balance is %.3f. The engine refuses a purchase it cannot afford "
            "(PlayerEntity.m:10344-10347), so this run would measure a refusal while claiming to "
            "measure a purchase." % (charge, price, factor, balance))

    can_before = can_award(console, key)
    before = credits(console)
    set_credits(console, round(before - charge, 3))
    awarded = award(console, key)
    after = credits(console)
    status = equipment_status(console, key)
    return {
        "key": key,
        "info": info,
        "credits_start": start_balance,
        "credits_before": before,
        "purchase_price": price,
        "equipment_price_factor": factor,
        "purchase_charge": charge,
        "credits_after": after,
        "credits_delta": round(before - after, 3),
        "can_award_before": can_before,
        "award_returned": awarded,
        "status_after_purchase": status,
    }


def tech_level_gate(console, spec, services):
    """Two keys STRADDLING the station's tech level, so the number is proven to discriminate.

    One key on one side of a threshold passes against any constant - including a station that
    reported NSNotFound or 0 for its tech level. Requiring the purchased item to be at or below
    the station's level AND a named control item to be above it is a two-sided predicate that a
    degenerate tech level cannot satisfy.
    """
    tl = int(services["equivalent_tech_level"])
    within = equipment_info(console, spec["purchase_key"])
    above = equipment_info(console, spec["above_tech_level_key"])
    return {
        "station_tech_level": tl,
        "within_key": within["key"],
        "within_tech_level": int(within["techLevel"]),
        "above_key": above["key"],
        "above_tech_level": int(above["techLevel"]),
        "within_is_available": int(within["techLevel"]) <= tl,
        "above_is_unavailable": int(above["techLevel"]) > tl,
    }


# --- the anti-vacuity gate ------------------------------------------------------------------


def assert_ran(evidence, spec):
    """Every clause names a field the dump CARRIES, applied BEFORE anything is written.

    Applied before the output file is opened, so a run that fails here cannot leave a blessable
    artifact behind (bead oo-gxp: 'rc != 0' and 'a dump exists' must never both be true of one
    invocation).
    """
    if evidence["system_id"] != int(spec["system_id"]):
        raise ScenarioError("the run is in system %d, not the pinned %d"
                            % (evidence["system_id"], int(spec["system_id"])))
    if evidence["undocked_seen"] is not False:
        raise ScenarioError(
            "undocked_seen is %r. This scenario is DOCKED THROUGHOUT by construction and records "
            "that as an explicit FALSE rather than omitting it, so a run that launched is caught "
            "here instead of silently measuring a different world."
            % evidence["undocked_seen"])
    if evidence["docked"] is not True:
        raise ScenarioError("the player is not docked at the dump")
    if evidence["station_is_main"] is not True:
        raise ScenarioError("the player is not docked at the system's MAIN station")

    # --- the award / query / damage / remove cycle -------------------------------------------
    if evidence["equipment_count_delta"] != 1:
        raise ScenarioError(
            "awarding %r changed the equipment array by %r item(s), not exactly 1. "
            "Ship.equipment is READ-ONLY in the JS API, so this number comes from the engine: an "
            "unchanged array after a successful award means equipment can be bought and silently "
            "not installed." % (spec["award_key"], evidence["equipment_count_delta"]))
    if not evidence["awarded_key_present"]:
        raise ScenarioError(
            "the equipment array grew but does not contain %r. The count alone cannot tell an "
            "award of the right item from an award of the wrong one."
            % spec["award_key"])
    if evidence["status_transition"] != [EQUIPMENT_OK, EQUIPMENT_DAMAGED]:
        raise ScenarioError(
            "the status machine read %r, not %r. BOTH readings are stored precisely so a "
            "COLLAPSED state machine shows up as the same value twice: EQUIPMENT_OK after a "
            "damage write means damaged equipment keeps working."
            % (evidence["status_transition"], [EQUIPMENT_OK, EQUIPMENT_DAMAGED]))
    if evidence["duplicate_award_refused"] is not True:
        raise ScenarioError(
            "canAwardEquipment(%r) returned TRUE for a second award of a non-carry-multiple item. "
            "A REFUSAL is positive evidence the equipment model applies rules; a model that "
            "accepts every write returns true here, so this going green would mean the refusal "
            "branch is gone." % spec["award_key"])
    if evidence["status_after_remove"] != EQUIPMENT_UNAVAILABLE:
        raise ScenarioError(
            "after removeEquipment(%r) the status reads %r, not %r; the removal path did not "
            "take the item off the ship."
            % (spec["award_key"], evidence["status_after_remove"], EQUIPMENT_UNAVAILABLE))
    if evidence["count_after_remove"] != evidence["count_before_award"]:
        raise ScenarioError(
            "the equipment array holds %d item(s) after the remove but held %d before the award; "
            "award and remove are not inverses on this key."
            % (evidence["count_after_remove"], evidence["count_before_award"]))

    # --- the second refusal -------------------------------------------------------------------
    if evidence["damage_refused_for_undamageable"] is not True:
        raise ScenarioError(
            "setEquipmentStatus(%r, 'EQUIPMENT_DAMAGED') was NOT refused (call returned %r, "
            "status read back %r). The registry declares this item undamageable "
            "(OOEquipmentType.m:566-568) and OOJSShip.m:2926 warns rather than damaging it; an "
            "accepted write means the canBeDamaged branch is gone."
            % (spec["undamageable_key"], evidence["undamageable_damage_accepted"],
               evidence["undamageable_status_after"]))

    # --- pricing ------------------------------------------------------------------------------
    expected_charge = round(evidence["purchase_price"] * evidence["equipment_price_factor"], 3)
    if abs(evidence["purchase_charge"] - expected_charge) > 1e-6:
        raise ScenarioError(
            "purchase_charge %r is not price %r x factor %r = %r"
            % (evidence["purchase_charge"], evidence["purchase_price"],
               evidence["equipment_price_factor"], expected_charge))
    if abs(evidence["credits_delta"] - evidence["purchase_charge"]) > 1e-6:
        raise ScenarioError(
            "credits moved by %r but the engine's price for %r at this station is %r. The two "
            "numbers are recorded separately exactly so a pricing change makes them disagree BY "
            "NAME instead of both sliding together."
            % (evidence["credits_delta"], spec["purchase_key"], evidence["purchase_charge"]))
    if evidence["credits_delta"] <= 0:
        raise ScenarioError(
            "credits moved by %r, which is not a payment. Credits unchanged or moving the wrong "
            "way means the pricing path is dead." % evidence["credits_delta"])
    if evidence["purchase_status"] != EQUIPMENT_OK:
        raise ScenarioError("the purchased item %r reads %r, not %r, after being paid for"
                            % (spec["purchase_key"], evidence["purchase_status"], EQUIPMENT_OK))
    if evidence["purchase_price"] != int(spec["expected_purchase_price"]):
        raise ScenarioError(
            "the engine prices %r at %r; the spec pins %r. This is the tech-level-derived pricing "
            "this scenario exists to observe - investigate before re-blessing."
            % (spec["purchase_key"], evidence["purchase_price"],
               spec["expected_purchase_price"]))
    if evidence["equipment_price_factor"] != float(spec["expected_price_factor"]):
        raise ScenarioError(
            "%s reports equipmentPriceFactor %r; the spec pins %r"
            % (evidence["station_name"], evidence["equipment_price_factor"],
               spec["expected_price_factor"]))

    # --- the tech-level gate, two-sided -------------------------------------------------------
    if evidence["station_tech_level"] != int(spec["expected_station_tech_level"]):
        raise ScenarioError(
            "the station reports equivalentTechLevel %r; the spec pins %r"
            % (evidence["station_tech_level"], spec["expected_station_tech_level"]))
    if not evidence["tech_level_within_available"]:
        raise ScenarioError(
            "the purchased item %r is techLevel %r, ABOVE the station's %r - it is not on sale "
            "here, so this run bought something the station does not stock."
            % (spec["purchase_key"], evidence["tech_level_within"],
               evidence["station_tech_level"]))
    if not evidence["tech_level_above_unavailable"]:
        raise ScenarioError(
            "the control item %r is techLevel %r and the station reports %r, so the control is "
            "NOT above the station's level. Both keys then sit on the same side of the threshold "
            "and the pair proves nothing: a station reporting 0, NSNotFound or any other "
            "degenerate tech level would pass."
            % (spec["above_tech_level_key"], evidence["tech_level_above"],
               evidence["station_tech_level"]))

    # --- ordering, the failure class item 0.1 names -------------------------------------------
    if len(evidence["registry_order"]) < int(spec["min_registry_entries"]):
        raise ScenarioError(
            "the equipment registry enumerated %d key(s), fewer than the %s minimum. A short "
            "registry means equipment.plist did not load, and an order pinned over three entries "
            "cannot see the reordering this scenario exists to catch."
            % (len(evidence["registry_order"]), spec["min_registry_entries"]))
    if len(set(evidence["registry_order"])) != len(evidence["registry_order"]):
        raise ScenarioError(
            "the equipment registry enumerated duplicate keys; a duplicated entry hides a missing "
            "one when the order is compared")
    for key in (spec["award_key"], spec["purchase_key"], spec["undamageable_key"],
                spec["above_tech_level_key"]):
        if key not in evidence["registry_order"]:
            raise ScenarioError(
                "%r is not in the enumerated registry, so this scenario's own keys are not the "
                "keys the engine knows about" % key)
    if len(evidence["equipment_keys_final"]) < 2:
        raise ScenarioError(
            "the final equipment array holds %d item(s); with fewer than two there is no ORDER to "
            "pin, and equipment ordering is the regression class item 0.1 names."
            % len(evidence["equipment_keys_final"]))

    # --- the clock, and the world ------------------------------------------------------------
    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met")
    if not evidence["world_at_rest"]:
        raise ScenarioError("the world was not at rest when the dump was taken")
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the world never reached a clean clear-and-settle round")
    if not evidence["clock_frozen_across_dump"]:
        raise ScenarioError(
            "the game clock advanced across the dump; the world is NOT frozen and the dump is a "
            "stopwatch reading")
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


# --- the run ---------------------------------------------------------------------------------


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, break_equipment=False):
    """One game process, one canonical dump, one frame grid.

    `break_equipment` is the MUTANT ARM: it removes the awarded item again before the evidence is
    assembled, so the award this scenario is named for did not stick. The run MUST then fail its
    own assertions; a scenario that stays green with the award undone is asserting nothing.
    """
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
    for stale in (out_path, frame_out):
        # A HARNESS MUST DELETE ITS OUTPUT PATH BEFORE EVERY RUN, or it cannot distinguish "this
        # run produced this" from "something produced this once" (bead oo-gxp's stale-scratch
        # phantom, which manufactured a phantom intermittent failure two workers chased).
        if stale and os.path.exists(stale):
            os.remove(stale)
    try:
        console = PatientConsole(start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"])), CONSOLE_REPLY_TIMEOUT_SECONDS)
        try:
            system_id = assert_system(console, spec)
            station_name = assert_docked(console, spec)

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness.
            # Scenario 010 measured eight of ten runs refusing when the suppression came after a
            # multi-second probe, because a station with hasNPCTraffic still on launched traffic
            # in the meantime.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            services = station_services(console)
            registry = registry_order(console)
            cycle = award_cycle(console, spec)
            undamageable = undamageable_probe(console, spec)
            bought = purchase(console, spec, services)
            gate = tech_level_gate(console, spec, services)

            if break_equipment:
                # MUTANT: undo the purchase, so the array the dump records never grew. Everything
                # else about the run is untouched; only the property under test is removed.
                remove_equipment(console, spec["purchase_key"])
                remove_equipment(console, spec["undamageable_key"])
                cycle["count_delta"] = 0
                cycle["present_after_award"] = False

            undocked_seen = console.evaluate("String(player.ship.docked)").strip().lower() != "true"
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            settle(console)
            clear_rounds = quiesce(console)
            moving = moving_entities(console)

            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The "
                    "simulation would keep integrating through the dump and no two runs could "
                    "agree." % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))
            final_keys = equipment_keys(console)
            final_statuses = {k: equipment_status(console, k) for k in final_keys}
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            clock_frozen = clock_after == clock_before

            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))
        finally:
            safe_close(console)

        equipment_block = {
            "registry_order": registry,
            "registry_entries": len(registry),
            "player_equipment": final_keys,
            "player_equipment_status": final_statuses,
            "station": services,
        }
        evidence = {
            "scenario": SCENARIO,
            "seed": seed,
            "ticks": ticks,
            "system_id": system_id,
            "station_name": station_name,
            "station_is_main": True,
            "docked": True,
            "undocked_seen": bool(undocked_seen),
            "service_level": services["service_level"],

            "award_key": cycle["key"],
            "count_before_award": cycle["count_before"],
            "equipment_count_delta": cycle["count_delta"],
            "awarded_key_present": bool(cycle["present_after_award"]),
            "can_award_before": bool(cycle["can_award_before"]),
            "award_returned": bool(cycle["award_returned"]),
            "status_transition": cycle["status_transition"],
            "duplicate_award_refused": not cycle["can_award_duplicate"],
            "status_after_remove": cycle["status_after_remove"],
            "count_after_remove": cycle["count_after_remove"],

            "undamageable_key": undamageable["key"],
            "undamageable_can_be_damaged": bool(undamageable["info"]["canBeDamaged"]),
            "undamageable_damage_accepted": bool(undamageable["damage_accepted"]),
            "undamageable_status_after": undamageable["status_after_damage_attempt"],
            "damage_refused_for_undamageable": bool(undamageable["refused"]),

            "purchase_key": bought["key"],
            "purchase_price": bought["purchase_price"],
            "equipment_price_factor": bought["equipment_price_factor"],
            "purchase_charge": bought["purchase_charge"],
            "credits_before": bought["credits_before"],
            "credits_after": bought["credits_after"],
            "credits_delta": bought["credits_delta"],
            "purchase_status": bought["status_after_purchase"],

            "station_tech_level": gate["station_tech_level"],
            "system_tech_level": services["system_tech_level"],
            "tech_level_within_key": gate["within_key"],
            "tech_level_within": gate["within_tech_level"],
            "tech_level_within_available": bool(gate["within_is_available"]),
            "tech_level_above_key": gate["above_key"],
            "tech_level_above": gate["above_tech_level"],
            "tech_level_above_unavailable": bool(gate["above_is_unavailable"]),

            "registry_order": registry,
            "registry_entries": len(registry),
            "equipment_keys_final": final_keys,

            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump -
            # the overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor).
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "clock_frozen_across_dump": bool(clock_frozen),
            "world_at_rest": not moving,
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
        }
        assert_ran(evidence, spec)
        state["equipment"] = equipment_block
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
                "equipment": equipment_block}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


# --- offline checks on a stored dump ---------------------------------------------------------


REQUIRED_EVIDENCE_FIELDS = (
    "equipment_count_delta", "awarded_key_present", "status_transition",
    "duplicate_award_refused", "damage_refused_for_undamageable", "credits_delta",
    "purchase_price", "equipment_price_factor", "station_tech_level", "registry_order",
    "tick_budget_met", "undocked_seen",
)


def check_evidence(path, spec, label=None):
    """Re-apply assert_ran to a STORED dump - what makes the golden self-describing."""
    label = label or path
    if not os.path.isfile(path):
        raise Refusal("no dump at %s" % path)
    with open(path, "r", encoding="utf-8") as handle:
        state = json.load(handle)
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise Refusal(
            "%s carries no evidence block; a dump with no evidence compares equal to any other "
            "evidence-free dump and proves nothing about the equipment model" % label)
    missing = [k for k in REQUIRED_EVIDENCE_FIELDS if k not in evidence]
    if missing:
        raise Refusal("%s's evidence block is missing %s" % (label, missing))
    assert_ran(evidence, spec)
    print("PASS: %s proves the equipment model ran: %r awarded (array %d -> %d, %s), status %s, "
          "duplicate award REFUSED, damage REFUSED for the undamageable %r, %r bought for %g "
          "credits (price %g x factor %g) at TL %d with %r (TL %d) above the station's level, "
          "%d registry entries pinned in order."
          % (label, evidence["award_key"], evidence["count_before_award"],
             evidence["count_before_award"] + evidence["equipment_count_delta"],
             evidence["awarded_key_present"], " -> ".join(evidence["status_transition"]),
             evidence["undamageable_key"], evidence["purchase_key"], evidence["credits_delta"],
             evidence["purchase_price"], evidence["equipment_price_factor"],
             evidence["station_tech_level"], evidence["tech_level_above_key"],
             evidence["tech_level_above"], len(evidence["registry_order"])))
    return 0


def _read_grid(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        # Formatted by frame_hash so the side-length attribute cannot be mistyped at this call
        # site - the typo lives inside the error path and is invisible on every green run.
        raise Refusal(frame_hash.wrong_grid_size_message(path, len(blob)))
    return blob


def _blessed_liveness_floor():
    """Read the liveness floor from provenance.json - the witness OUTSIDE the artifact."""
    for candidate in PROVENANCE_CANDIDATES:
        if os.path.isfile(candidate):
            with open(candidate, "r", encoding="utf-8") as handle:
                prov = json.load(handle)
            liveness = prov.get("frame_liveness") or {}
            floor = liveness.get("floor")
            if liveness.get("asserted") is True and isinstance(floor, (int, float)) and floor > 0:
                return float(floor), candidate
            raise ScenarioError(
                "%s frame_liveness=%r must assert a positive floor; liveness is the one frame "
                "property a dead run cannot fake, and without it the frame is entirely unpinned"
                % (candidate, liveness))
    return FRAME_LIVENESS_FLOOR_FALLBACK, None


def _liveness(grid):
    """SPREAD of the luminance bytes, scaled to 0..1 - scenario 002's metric exactly.

    A run that died before drawing yields a (near-)uniform grid whose spread is ~0. The distance
    to an all-black grid is NOT used: a dim but fully-rendered scene sits close to black in that
    metric, so it cannot separate "dark scene" from "no scene".
    """
    return (max(grid) - min(grid)) / 255.0


def check_frame(grid_path, reference_path):
    """Assert LIVENESS **and** the distance tolerance - both, because both were MEASURED here.

    NEVER BYTE-HASH THE FRAME. llvmpipe is not bit-reproducible: ten stability runs of this
    scenario produced ten DISTINCT grid digests, so a digest comparison would flake on renderer
    noise while the dump - quantised and deterministic - IS hashed byte-wise. That asymmetry is the
    point (bead oo-gxp).

    Tolerance IS asserted here, unlike scenario 015. It was measured rather than assumed: within a
    single process at the same GUI screen, three frames taken with NO equipment and three taken
    after awarding EQ_ECM/EQ_CARGO_BAY/EQ_FUEL_SCOOPS sat at 0.00148..0.00174 inside each group and
    0.00509..0.00521 between them, straddling the shared derived tolerance 0.004377 with ~2.9x
    separation. The status screen RENDERS the equipment list, so the frame is a genuine second
    witness to the scenario's own subject - and a run that installed nothing lands outside the
    tolerance rather than inside it. (015 rejected the same assertion for the opposite measured
    reason: its signal was smaller than its noise.)
    """
    got = _read_grid(grid_path)
    want = _read_grid(reference_path)
    floor, floor_source = _blessed_liveness_floor()
    live = _liveness(got)
    distance = frame_hash.distance(got, want)
    tolerance = frame_hash.derive_tolerance()
    result = {
        "distance_to_reference": distance,
        "tolerance": tolerance,
        "within_tolerance": distance <= tolerance,
        "liveness": live,
        "liveness_floor": floor,
        "liveness_floor_from": floor_source or "FRAME_LIVENESS_FLOOR_FALLBACK",
        "liveness_metric": "luminance spread (max-min)/255",
        "reference_liveness": _liveness(want),
        "live": live >= floor,
        "verdict_rests_on": "liveness AND distance tolerance",
        "hash_got": frame_hash.hex_digest(got),
        "hash_want": frame_hash.hex_digest(want),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    rc = 0
    if not result["live"]:
        print("FAIL: %s has luminance spread %.6f, below the blessed floor %.6f. The frame is "
              "(near-)uniform, which is what a run that never drew the scene produces."
              % (grid_path, live, floor), file=sys.stderr)
        rc = 1
    if not result["within_tolerance"]:
        print("FAIL: %s sits %.6f from the blessed reference, past the derived tolerance %.6f. "
              "Same-scene pairs of this scenario were measured at 0.00148..0.00174 and an "
              "equipment-free control at 0.00509, so this distance is signal, not renderer noise."
              % (grid_path, distance, tolerance), file=sys.stderr)
        rc = 1
    return rc


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def stability(app_dir, spec, run_root, runs, keep=False):
    """N independent runs, reporting REFUSED and DIFFERED separately, capturing EVERY run.

    A REFUSAL (the harness declining to dump an unsettled world) is NOT a DIFFERENCE; collapsing
    the two is how a stability claim goes dishonest (bead oo-jor).
    """
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
        summary["WARNING"] = ("FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing "
                              "to compare and no stability claim can be made." % (len(dumped),
                                                                                  runs))
    summary["stable"] = len(dumped) >= 2 and len(digests) == 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/equipment_services.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--break-equipment", action="store_true",
                        help="MUTANT ARM: remove the awarded equipment again before the evidence "
                             "is assembled, so the award did not stick. The run must then FAIL "
                             "its own assertions; used to prove the gate goes red.")
    parser.add_argument("--check-evidence", default=None, metavar="DUMP",
                        help="offline: re-apply the equipment assertions to a stored dump")
    parser.add_argument("--label", default=None)
    parser.add_argument("--check-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    args = parser.parse_args(argv)

    try:
        spec = load_spec()
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
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_1bf6_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, frame_out=args.frame_out,
                     break_equipment=args.break_equipment)
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
    print("EQUIPPED: %s at %s (TL %d, price factor %g): %r awarded (+%d, %s), %r bought for %g "
          "credits, %r refused damage, %d registry entries in order; %d ticks docked (%.1fs wall)"
          % (spec["system_name"], ev["station_name"], ev["station_tech_level"],
             ev["equipment_price_factor"], ev["award_key"], ev["equipment_count_delta"],
             " -> ".join(ev["status_transition"]), ev["purchase_key"], ev["credits_delta"],
             ev["undamageable_key"], ev["registry_entries"], ev["ticks"],
             result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
