"""Golden scenario 004 - TRADE CYCLE: buy, hold, sell back, at Atdice main station.

Scenario 001's shape (fixed seed, fixed system, fixed tick count, canonical dump, frame hash,
10-run stability) applied to the COMMODITY MARKET and the player's purse and hold.

WHAT A "TRADE CYCLE" IS HERE, AND WHAT IT IS NOT
------------------------------------------------
The engine's own buy/sell orchestration is `-[PlayerEntity tryBuyingCommodity:all:]` /
`-trySellingCommodity:all:` (PlayerEntity.m:11334, :11434). NEITHER IS REACHABLE FROM THIS TIER,
and that was checked rather than assumed: both are two-argument selectors, and the debug console's
`callObjC` only dispatches the four signatures in OOJSCall.m's template class (void/void,
void/object, object/object, plus the scalar returns) - a two-argument selector falls through
`GetMethodType` to kMethodTypeInvalid and is refused by name. They are otherwise driven only from
PlayerEntityControls.m's key handler, i.e. the GUI tier.

So this scenario drives the THREE ENGINE SEAMS the JS API does expose, once per leg:

    station.setMarketQuantity(good, q)   -> -[StationEntity setQuantity:forCommodity:]
    player.ship.manifest[good] = n       -> -[PlayerEntity setCargoQuantityForType:amount:]
    player.credits = c                   -> -[PlayerEntity setCreditBalance:]

and then asserts the ENGINE'S OWN ANSWERS, not its own arithmetic. That distinction is the whole
anti-vacuity argument and it is worth being precise about:

  * `player.ship.cargoSpaceUsed` is NOT written by this scenario. It is recomputed by
    -calculateCurrentCargo from the hold/pods after the manifest write, so "used moved by exactly
    the units traded" is an engine-computed fact. A manifest write that silently did nothing, or
    that was clamped, moves this number differently and the run goes red.
  * the market quantity is READ BACK out of `station.market` after the write.
  * the credit balance is READ BACK after the write, and PlayerEntity stores credits in TENTHS, so
    the expected delta is `price * units / credits_scale` with the scale pinned in the spec and
    MEASURED (probe: price 40 on food, 5 units, balance moved 96522.6 -> 96502.6, i.e. 20.0).

What this scenario therefore CANNOT witness is PlayerEntity's buy/sell orchestration itself
(its capacity and legality branches, the playerBoughtCargo/playerSoldCargo events). THE SEAM THAT
WOULD BE NEEDED is a JS-reachable buy/sell, or a single-argument ObjC shim callObjC can dispatch.
Inventing one is out of scope for a golden scenario; pretending the golden covers it would be
worse than saying so here.

THE OBSERVABLE, AND WHO ELSE CAN WRITE TO IT
--------------------------------------------
Bead oo-rkm's rule: before measuring stability, find every carrier of the thing you assert on.
The market's carriers are

  1. `-[Universe setUpSpace]` / `-[StationEntity initialiseLocalMarket]`, which REGENERATE the
     market (Universe.m:7998, StationEntity.m:264). Both run on system entry and on load, i.e.
     BEFORE this scenario takes its baseline, never during it: the scenario never changes system
     and never re-docks.
  2. the player's own buy/sell - this scenario.
  3. commodity scripts, at generation time only (OOCommodities.m:327-355).

Measured on this box: with the populators, station traffic and the repopulator quieted, a full
17-commodity snapshot of price and quantity was BYTE-IDENTICAL across 4 s of game time. But a
measurement is not a guard, so the guard ships too: `untraded_unchanged` compares the snapshot of
every commodity this scenario does NOT trade, before and after the whole cycle. If anything else
ever writes to the market during the run, that list is non-empty and the run goes RED rather than
flaky (bead oo-rkm's two beads went flaky by counting a shared observable).

ANTI-VACUITY: A DEAD RUN CANNOT REACH ANY OF THESE
---------------------------------------------------
rc=0 and "no ERROR lines" are both satisfied by a launch that died in display setup (bead oo-het),
so every defence here is a PRESENCE of progress:

  1. the engine's own 14-stage `[load.progress]` trace, logged only inside -loadPlayerFromFile:
     (PlayerEntityLoadSave.m:620-811), on a channel this scenario switches on itself;
  2. credits moved by EXACTLY price*units/scale on each leg, twice, in opposite directions;
  3. the market quantity for the traded good moved by EXACTLY the units, twice, in opposite
     directions;
  4. `cargoSpaceUsed`, which the ENGINE recomputes, moved by exactly the units, twice;
  5. the cycle does NOT return to its starting point: sell_units < buy_units by construction, so
     the final dump carries a hold, a purse and a market that a run which did nothing cannot have;
  6. every untraded commodity is unchanged - the witness that nothing else moved the market.

THE DELIBERATE ASYMMETRY (beads oo-gxp, oo-3ya)
------------------------------------------------
state.json is hashed byte-wise and its sha256 AND byte count are recorded in provenance.json - a
SEPARATE file - because a golden cannot witness itself: editing the golden moves both sides of any
golden-vs-copy comparison. frame.grid is NEVER byte-hashed into a verdict: llvmpipe is not
bit-reproducible, so the frame is judged by a measured distance only.

ISOLATION: a private console port with its own debugConfig.plist, because the game DIALS OUT to
the port named there (OODebugSupport.m:67-80) and a run on the shared 8563 can be captured and
quit by a sibling worker's console while still exiting rc=0 (bead oo-het).
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

SCENARIO = "004-trade-cycle"

# Guarded location first, staged location second, so landing is a pure `git mv` with no code
# change (tools/guardrails.sh refuses CREATE as well as MODIFY under goldens/, so this bead
# cannot land them there itself). Scenario 010/012/015's arrangement, deliberately identical.
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
# The main system market carries 17 goods (trade-goods.plist). A snapshot shorter than this is a
# probe failure wearing the shape of a market, and every "unchanged" comparison over it is vacuous.
MIN_MARKET_GOODS = 17

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
# How many times a read-only STARTUP probe may be re-asked when the console does not answer inside
# its own 15s window. Four, because the one stall measured in an acceptance rehearsal cleared on
# the next ask; the bound exists so a game that never settles is REFUSED by name instead of hanging.
STARTUP_PROBE_TRIES = 4
CLEAR_ROUNDS = 20

# The floor a frame must clear, in frame_hash distance units, to count as RENDERED. It is NOT a
# tolerance and NOT a same-scene equality test; see provenance.json frame_liveness for the
# measurement that places it between the same-scene noise and the dimmest real frame.
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


def read_save_file(path):
    """Parse the .oolite-save and PROVE it is worth loading. Refusals, never differences."""
    if not os.path.isfile(path):
        raise Refusal("the save file %s DOES NOT EXIST; there is nothing to load" % path)
    size = os.path.getsize(path)
    if size < MIN_SAVE_BYTES:
        raise Refusal("the save file %s is %d bytes, under the %d-byte floor; a stub save parses "
                      "to few or no keys and every check against it is vacuous however green"
                      % (path, size, MIN_SAVE_BYTES))
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:  # noqa: BLE001 - a parse failure is a refusal, not a difference
        raise Refusal("%s is not a readable property list: %s: %s" % (path, type(exc).__name__,
                                                                     exc))
    if not isinstance(data, dict) or not data:
        raise Refusal("%s parsed to %r, which carries no commander data" % (path, type(data)))
    return data, size


# --- the live game ------------------------------------------------------------------------------

def enable_load_logging(config_dir, spec):
    """Switch the load channels ON via a logcontrol.plist in the private resource root.

    `load.progress` is OFF by default (Resources/Config/logcontrol.plist:241) and CANNOT be
    switched on from the console: the whole load happens before the debug console connects, so a
    JS call arrives after "Loading complete" has already been printed. ResourceManager.m:1761-1777
    merges a logcontrol.plist found in any ROOT path over the built-in copy, and an
    OO_ADDITIONALADDONSDIRS entry is a root path. (Scenario 015's mechanism, unchanged.)
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
        raise ScenarioError("no Latest.log at %s: the run wrote no log at all, so the engine's "
                            "own load evidence cannot be checked and rc=0 would mean nothing"
                            % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    stages, failures = [], []
    for line in text.splitlines():
        stripped = line.strip()
        if "[load.progress]:" in stripped:
            stages.append(stripped.split("[load.progress]:", 1)[1].strip())
        elif "[load.failed]" in stripped:
            failures.append(stripped)
    return stages, failures, len(text)


def evaluate_settling(console, js, tries=STARTUP_PROBE_TRIES):
    """Evaluate a STARTUP probe, re-asking if the console does not answer in time.

    MEASURED, not defensive padding. An acceptance rehearsal on a VM running the fleet's other
    beads hit `no answer to 'String(player.ship.dockedStation === system.mainStation)' within 15s`
    AFTER the two probes before it had already answered - i.e. the game was alive and talking, and
    then stalled for longer than one command window while the load-save GUI transition finished.

    The retry is narrow on purpose, because a broad one would hide real deaths:

      * it is used ONLY by assert_system(), on the read-only probes between launch and the first
        write. Nothing here has a side effect, so re-asking cannot double a trade;
      * `console.evaluate` polls `self._proc.poll()` every second and raises "Oolite exited with N
        mid-command" when the process is gone (console.py:241). That is a DIFFERENT message from
        the timeout, and it is re-raised immediately - a dead game still fails fast, in one window,
        rather than burning every retry;
      * a JS error is likewise re-raised at once: it is an answer, just a bad one;
      * the budget is bounded and reported, so a game that never settles still fails, by name.
    """
    from console import ConsoleError

    last = None
    for attempt in range(tries):
        try:
            return console.evaluate(js)
        except ConsoleError as exc:
            if "no answer to" not in str(exc):
                raise           # exited mid-command, or a JS error: an answer, not a stall.
            last = exc
            time.sleep(1)
    raise ScenarioError(
        "the console did not answer %s in %d attempt(s) though the game was still running: %s. "
        "The world never became responsive enough to probe, so this run is REFUSED rather than "
        "dumped - a dump taken from a game that could not answer is not evidence of anything."
        % (js, tries, last))


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; "
            "the market this scenario trades in is that system's market, so a different system is "
            "a different scenario wearing this one's golden"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))
    if evaluate_settling(console, "String(player.ship.docked)").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked. -[PlayerEntity tryBuyingCommodity:all:] returns NO when "
            "undocked (PlayerEntity.m:11341) and `localMarket` belongs to the docked station, so "
            "an undocked player means there is no market to trade in.")
    if evaluate_settling(
            console,
            "String(player.ship.dockedStation === system.mainStation)").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked at the MAIN station. StationEntity.m:191-203 returns the "
            "SYSTEM market for the main station and a separately generated local market for any "
            "other, so the good's price and quantity would come from a different object.")
    return got


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
        raise ScenarioError("%s populator setting(s) survived suppression; the system will keep "
                            "adding traffic" % remaining)
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
        raise ScenarioError("no station was found to suppress; this save is docked at a main "
                            "station by construction, so zero stations means the world is absent")
    return count


def suppress_repopulator(console, spec):
    """Neuter oolite-populator.js's repopulate handler - the source that defeats the other two.

    Its station picker `_tradeStation` ends with an unconditional `return system.mainStation`, so
    switching hasNPCTraffic off does not stop it launching (scenario 010 measured traffic still
    arriving mid-run). The names come from the spec so an upstream rename is a red, not a no-op.
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist; if it was renamed upstream "
                "the suppression is silently doing nothing. Re-derive the handler names rather "
                "than dropping the check." % name)
        console.perform("worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError("worldScripts['oolite-populator'].%s did not become a no-op (it "
                                "reads %r)" % (name, after[:120]))
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
        "The three known sources are all switched off before this runs; a fourth is a FINDING, "
        "not a reason to widen the round count." % (rounds, history))


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


# --- the market, and the trade itself ------------------------------------------------------------

MARKET_SNAPSHOT_JS = (
    "(function(){ var m = player.ship.dockedStation.market,"
    " k = Object.keys(m).sort(), o = {};"
    " for (var i = 0; i < k.length; i++)"
    "   o[k[i]] = [m[k[i]].quantity, m[k[i]].price, m[k[i]].capacity];"
    " return JSON.stringify(o); })()"
)


def market_snapshot(console, spec):
    """Quantity, price and capacity for EVERY good, read off the docked station's market.

    The whole market is snapshotted, not just the traded good, because the untraded goods are the
    CONTROL: they are what proves no other carrier wrote to this market during the run.
    """
    raw = console.evaluate(MARKET_SNAPSHOT_JS).strip()
    try:
        snap = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the market snapshot came back unparseable (%s): %r" % (exc, raw[:200]))
    if len(snap) < MIN_MARKET_GOODS:
        raise Refusal(
            "the market snapshot carries %d good(s), fewer than the %d the main system market has "
            "(trade-goods.plist). A short snapshot makes every 'untraded goods unchanged' "
            "comparison vacuous." % (len(snap), MIN_MARKET_GOODS))
    if spec["commodity"] not in snap:
        raise Refusal("this market has no good %r; the scenario's whole cycle is about that good"
                      % spec["commodity"])
    return snap


def untraded_changes(before, after, traded):
    """Every good OTHER than the traded one whose quantity, price or capacity moved."""
    moved = []
    for key in sorted(set(before) | set(after)):
        if key == traded:
            continue
        if before.get(key) != after.get(key):
            moved.append("%s: %r -> %r" % (key, before.get(key), after.get(key)))
    return moved


TRADE_LEG_JS = (
    "(function(){"
    " var st = player.ship.dockedStation, g = %(good)s, n = %(units)d, sign = %(sign)d;"
    " var before = { market_quantity: st.market[g].quantity, price: st.market[g].price,"
    "                credits: player.credits, hold: player.ship.manifest[g],"
    "                used: player.ship.cargoSpaceUsed };"
    " st.setMarketQuantity(g, before.market_quantity - sign * n);"
    " player.ship.manifest[g] = before.hold + sign * n;"
    " player.credits = before.credits - sign * n * before.price / %(scale)d;"
    " var after = { market_quantity: st.market[g].quantity, price: st.market[g].price,"
    "               credits: player.credits, hold: player.ship.manifest[g],"
    "               used: player.ship.cargoSpaceUsed };"
    " return JSON.stringify({ before: before, after: after }); })()"
)


def trade_leg(console, spec, side, units):
    """ONE leg of the cycle, through the three engine seams, asserted on the ENGINE'S ANSWERS.

    `side` is "buy" (goods leave the market and enter the hold, cash leaves the purse) or "sell"
    (the reverse). Every delta below is computed from values READ BACK out of the running game
    after the writes, and `used` is not written at all - -calculateCurrentCargo recomputes it from
    the hold, so a manifest write that was clamped or silently dropped moves it differently.

    THE CREDIT SCALE IS PINNED AND MEASURED, NOT ASSUMED: PlayerEntity stores credits in TENTHS,
    so a good priced 40 costs 4.0 credits per unit. Probed on this box: 5 units of food at price
    40 moved the balance 96522.6 -> 96502.6. Reading the scale from the spec means a future engine
    that changed it fails here by name instead of being absorbed.
    """
    if side not in ("buy", "sell"):
        raise Refusal("trade leg side %r is neither buy nor sell" % side)
    sign = 1 if side == "buy" else -1
    good = spec["commodity"]
    scale = int(spec["credits_scale"])
    raw = console.evaluate(TRADE_LEG_JS % {"good": json.dumps(good), "units": int(units),
                                           "sign": sign, "scale": scale}).strip()
    try:
        leg = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the %s leg came back unparseable (%s): %r" % (side, exc, raw[:300]))
    before, after = leg["before"], leg["after"]

    price = before["price"]
    if not price:
        raise Refusal(
            "%r is priced 0 in this market, so the credits leg of the cycle would move the purse "
            "by zero and 'the money moved' would be unfalsifiable." % good)
    expected_cash = round(price * units / float(scale), 3)
    problems = []
    if after["market_quantity"] - before["market_quantity"] != -sign * units:
        problems.append("the market's quantity of %s moved %+d, expected %+d"
                        % (good, after["market_quantity"] - before["market_quantity"],
                           -sign * units))
    if after["hold"] - before["hold"] != sign * units:
        problems.append("the hold's quantity of %s moved %+d, expected %+d"
                        % (good, after["hold"] - before["hold"], sign * units))
    if after["used"] - before["used"] != sign * units:
        problems.append(
            "cargoSpaceUsed moved %+d, expected %+d. This number is NOT written by the scenario - "
            "-calculateCurrentCargo recomputes it from the hold - so a disagreement means the "
            "manifest write was clamped or dropped"
            % (after["used"] - before["used"], sign * units))
    moved_cash = round(after["credits"] - before["credits"], 3)
    if abs(moved_cash - (-sign * expected_cash)) > 0.0005:
        problems.append("the purse moved %+.3f, expected %+.3f (price %d over a scale of %d for "
                        "%d unit(s))" % (moved_cash, -sign * expected_cash, price, scale, units))
    if after["price"] != price:
        problems.append("the price of %s changed from %r to %r during the leg; this scenario never "
                        "writes a price, so something else did" % (good, price, after["price"]))
    if problems:
        raise ScenarioError("the %s leg did not happen as the engine reports it: %s"
                            % (side, "; ".join(problems)))
    return {"side": side, "units": int(units), "price": price,
            "credits_before": round(before["credits"], 3),
            "credits_after": round(after["credits"], 3),
            "credits_delta": moved_cash,
            "market_quantity_before": before["market_quantity"],
            "market_quantity_after": after["market_quantity"],
            "hold_before": before["hold"], "hold_after": after["hold"],
            "cargo_space_used_before": before["used"], "cargo_space_used_after": after["used"]}


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: _await_png waits for the NAME, which on Windows shows
    up while the game still holds the handle open. Both PermissionError and a truncated read are
    retried; a frame that never becomes readable is a REFUSAL, not a hash of half a file.
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
                        "image would be worse than no frame at all" % (png, type(last).__name__,
                                                                       last))


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied BEFORE anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every future
    diff against the stored golden rather than only at capture time.
    """
    stages = list(spec["load_progress_stages"])
    if evidence["load_stages"] != stages:
        raise ScenarioError(
            "the engine logged %d load.progress stage(s), not the %d PlayerEntityLoadSave.m emits "
            "in order. Those OOLog calls exist ONLY inside -loadPlayerFromFile:, so NONE means the "
            "run never loaded the save and a PREFIX means the load died partway. Got %r."
            % (len(evidence["load_stages"]), len(stages), evidence["load_stages"]))
    if evidence["load_failures"]:
        raise ScenarioError("the engine logged %d [load.failed] line(s): %r"
                            % (len(evidence["load_failures"]), evidence["load_failures"]))

    legs = evidence["legs"]
    if len(legs) != 2 or [leg["side"] for leg in legs] != ["buy", "sell"]:
        raise ScenarioError("a trade CYCLE is a buy leg followed by a sell leg; got %r"
                            % [leg["side"] for leg in legs])
    if legs[0]["units"] != int(spec["buy_units"]) or legs[1]["units"] != int(spec["sell_units"]):
        raise ScenarioError("the legs traded %d then %d unit(s), but the spec pins %d then %d"
                            % (legs[0]["units"], legs[1]["units"], int(spec["buy_units"]),
                               int(spec["sell_units"])))
    if not all(leg["credits_delta"] for leg in legs):
        raise ScenarioError(
            "a leg moved the purse by zero: %r. 'The trade happened' would then be satisfiable by "
            "a run in which no money changed hands." % [leg["credits_delta"] for leg in legs])
    if legs[0]["credits_delta"] >= 0 or legs[1]["credits_delta"] <= 0:
        raise ScenarioError("the buy leg must COST money and the sell leg must PAY it; got %+.3f "
                            "then %+.3f" % (legs[0]["credits_delta"], legs[1]["credits_delta"]))

    if evidence["cargo_after_cycle"] != int(spec["expected_cargo_after"]):
        raise ScenarioError(
            "the hold carries %d unit(s) of %s after the cycle but the spec pins %d. The cycle is "
            "DELIBERATELY asymmetric (sell_units < buy_units): a cycle that returned exactly to "
            "its starting point would leave a dump indistinguishable from a run that never traded."
            % (evidence["cargo_after_cycle"], spec["commodity"],
               int(spec["expected_cargo_after"])))
    if evidence["cargo_after_cycle"] <= 0:
        raise ScenarioError("the cycle ended with an empty hold, which is exactly the state a run "
                            "that did nothing at all would be in")
    if evidence["market_quantity_after"] == evidence["market_quantity_before"]:
        raise ScenarioError("the market's quantity of %s is unchanged across the whole cycle (%d); "
                            "a market that did not move is a market nobody traded in"
                            % (spec["commodity"], evidence["market_quantity_before"]))
    if evidence["credits_after"] == evidence["credits_before"]:
        raise ScenarioError("the purse is unchanged across the whole cycle (%.3f)"
                            % evidence["credits_before"])

    if evidence["untraded_goods_changed"]:
        raise ScenarioError(
            "%d good(s) this scenario never traded changed during the run: %r. The market has more "
            "than one carrier after all, so this scenario's observable is shared and the assertion "
            "is a race rather than a measurement (bead oo-rkm). That is a FINDING - diagnose the "
            "carrier, do not widen the comparison."
            % (len(evidence["untraded_goods_changed"]), evidence["untraded_goods_changed"]))
    if evidence["untraded_goods_compared"] < MIN_MARKET_GOODS - 1:
        raise ScenarioError("only %d untraded good(s) were compared; the control that proves "
                            "nothing else moved the market is too small to mean anything"
                            % evidence["untraded_goods_compared"])
    if not evidence["world_at_rest"] or not evidence["world_reached_fixed_point"]:
        raise ScenarioError("the world was not at rest when the dump was taken")
    if not evidence["tick_budget_met"]:
        raise ScenarioError("the tick budget was not met")
    return True


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, seed_override=None, ticks_override=None,
        frame_out=None, buy_override=None, sell_override=None, save_override=None):
    """One game process, one canonical dump, one frame grid."""
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    buy_units = int(spec["buy_units"] if buy_override is None else buy_override)
    sell_units = int(spec["sell_units"] if sell_override is None else sell_override)
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

        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1", load_save=save))
        with console:
            assert_system(console, spec)

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE - order is load-bearing, not tidiness.
            # Scenario 010 measured eight of ten runs refusing when suppression came after a
            # multi-second probe, because a station with hasNPCTraffic still on launched traffic
            # in the meantime.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            before_market = market_snapshot(console, spec)
            credits_before = round(float(console.evaluate("player.credits")), 3)

            buy_leg = trade_leg(console, spec, "buy", buy_units)
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))
            sell_leg = trade_leg(console, spec, "sell", sell_units)

            after_market = market_snapshot(console, spec)
            credits_after = round(float(console.evaluate("player.credits")), 3)
            cargo_after = console.evaluate_int(
                "player.ship.manifest[%s]" % json.dumps(spec["commodity"]))

            settle(console)
            clear_rounds = quiesce(console)
            at_rest = not moving_entities(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        stages, failures, log_bytes = read_load_evidence(artifact_dir)
        moved = untraded_changes(before_market, after_market, spec["commodity"])

        good = spec["commodity"]
        evidence = {
            "scenario": SCENARIO,
            "save_file": os.path.basename(save),
            "save_bytes": size,
            "save_written_by_version": str(plist.get("written_by_version", "")),
            "load_stages": stages,
            "load_failures": failures,
            "commodity": good,
            "credits_scale": int(spec["credits_scale"]),
            "legs": [buy_leg, sell_leg],
            "credits_before": credits_before,
            "credits_after": credits_after,
            "credits_net": round(credits_after - credits_before, 3),
            "cargo_after_cycle": cargo_after,
            "market_quantity_before": before_market[good][0],
            "market_quantity_after": after_market[good][0],
            "market_price": before_market[good][1],
            "market_capacity": before_market[good][2],
            "market_goods": len(before_market),
            "untraded_goods_compared": len(before_market) - 1,
            "untraded_goods_changed": moved,
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
        assert_ran(evidence, spec)
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
                "png": golden_run._slashes(png), "frame_hash": frame_hash.hex_digest(grid),
                "bytes": len(text), "log_bytes": log_bytes,
                "game_seconds_elapsed": round(elapsed, 3),
                "wall_seconds": round(time.time() - started, 1), "evidence": evidence}
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
                            % (path, len(blob), frame_hash.GRID_CELLS, frame_hash.GRID_SIDE,
                               frame_hash.GRID_SIDE))
    return blob


def compare_frame(grid_path, reference_path):
    """Report a captured grid against the stored reference and assert LIVENESS and TOLERANCE.

    Both are asserted for THIS scenario, and the difference from scenario 015 is a measurement,
    not a preference: 015's HUD animates a live trumble population every frame, so its same-scene
    pairs sat at 1.08x..2.49x the measured tolerance and it could only assert liveness. This
    scenario's scene is a docked market view with no animated population; see provenance.json
    frame_tolerance for the measured same-scene spread that justifies asserting it here.
    """
    grid = _read_grid(grid_path)
    reference = _read_grid(reference_path)
    black = bytes(frame_hash.GRID_CELLS)
    tol = frame_hash.derive_tolerance()
    live = frame_hash.distance(grid, black)
    distance = frame_hash.distance(grid, reference)
    print("frame: distance-to-reference %.6f (%.2fx the measured tolerance %.6f); "
          "liveness %.6f (floor %.4f)" % (distance, distance / tol, tol, live,
                                          FRAME_LIVENESS_FLOOR))
    if live < FRAME_LIVENESS_FLOOR:
        print("FAIL: the captured frame is %.6f from an ALL-BLACK grid, under the %.4f liveness "
              "floor: nothing was rendered. A run that died before drawing, or drew into a lost "
              "context, lands here." % (live, FRAME_LIVENESS_FLOOR), file=sys.stderr)
        return 1
    if distance > tol:
        print("FAIL: the captured frame is %.6f from the stored reference, beyond the tolerance "
              "%.6f measured by tests/golden/calibrate.py. Investigate before re-blessing; do NOT "
              "widen the tolerance to make a run pass." % (distance, tol), file=sys.stderr)
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
    """N independent runs, reporting REFUSED and DIFFERED separately.

    CAPTURES the outcome of EVERY run REGARDLESS OF EXIT CODE. A sibling harness recorded results
    only when returncode == 0 and so hid runs that wrote a correct dump but exited nonzero.
    """
    import hashlib

    out_dir = os.path.join(run_root, "stability")
    os.makedirs(out_dir, exist_ok=True)
    results = []
    for i in range(1, runs + 1):
        out = os.path.join(out_dir, "run%02d.json" % i)
        grid = os.path.join(out_dir, "run%02d.grid" % i)
        # A HARNESS MUST DELETE ITS OUTPUT PATH BEFORE EVERY RUN, or it cannot tell "this run
        # produced this" from "something produced this once" (bead oo-gxp's phantom intermittent).
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
        "per_run": [{k: r.get(k) for k in ("run", "verdict", "bytes", "sha256", "frame_sha256",
                                           "wall_seconds")} for r in results],
    }
    if len(dumped) < 2:
        summary["WARNING"] = ("FEWER THAN TWO RUNS PRODUCED A DUMP (%d of %d). There is nothing to "
                              "compare and no stability claim can be made." % (len(dumped), runs))
    summary["stable"] = len(dumped) >= 2 and len(digests) == 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0 if summary.get("stable") else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/trade_cycle.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--save", default=None, help="override the .oolite-save the GAME loads")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--ticks", type=int, default=None)
    parser.add_argument("--buy-units", type=int, default=None)
    parser.add_argument("--sell-units", type=int, default=None)
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--stability", type=int, default=0, metavar="N")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"), default=None)
    args = parser.parse_args(argv)

    spec = load_spec()

    if args.compare_frame:
        return compare_frame(args.compare_frame[0], args.compare_frame[1])

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 2
    ensure_launchable(app_dir)
    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_zv2_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.stability:
        return stability(app_dir, spec, run_root, args.stability, keep=args.keep)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep, seed_override=args.seed,
                     ticks_override=args.ticks, frame_out=args.frame_out,
                     buy_override=args.buy_units, sell_override=args.sell_units,
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
    buy, sell = ev["legs"]
    print("TRADED: %s at %s - bought %d %s at %d (%.1f cr), held %d tick(s), sold %d back "
          "(%.1f cr); purse %.3f -> %.3f, market %d -> %d, hold ends at %d; engine logged all %d "
          "load stages; %d untraded good(s) unchanged (%.1fs wall)"
          % (ev["save_file"], spec.get("system_name"), buy["units"], ev["commodity"],
             ev["market_price"], -buy["credits_delta"], ev["ticks"], sell["units"],
             sell["credits_delta"], ev["credits_before"], ev["credits_after"],
             ev["market_quantity_before"], ev["market_quantity_after"], ev["cargo_after_cycle"],
             len(ev["load_stages"]), ev["untraded_goods_compared"], result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    if result["frame_out"]:
        print("frame: %s (hash %s)" % (result["frame_out"], result["frame_hash"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
