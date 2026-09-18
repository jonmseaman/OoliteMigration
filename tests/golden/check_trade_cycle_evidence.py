"""Gate: a scenario 004 dump PROVES a trade cycle happened, and could not have been produced
without one.

Run against the STORED golden and against any FRESH dump. The two questions it answers are
different and both are needed:

  * against a fresh dump  - "did this run actually trade, or did it merely exit 0?"
  * against the golden    - "is the artefact we compare future runs to itself non-vacuous?"
    A byte-identical match against a golden that proves nothing proves nothing.

WHY THE PRESENCE CHECKS AND NOT AN ABSENCE OF ERRORS
-----------------------------------------------------
A launch that died in display setup exits with a log carrying ZERO lines matching ERROR (bead
oo-het captured the artefact: 1476 bytes, banner, [process.args], display.initGL, nothing after).
So every clause here names a state that only a completed trade cycle can be in:

  1. the engine's own 14-stage [load.progress] sequence, in order;
  2. TWO legs, buy then sell, each moving the purse in the correct DIRECTION by the EXACT amount
     price*units/credits_scale;
  3. each leg moving the market's quantity of the traded good by exactly the units, in the
     opposite direction to the hold;
  4. each leg moving cargoSpaceUsed - which the ENGINE recomputes from the hold, and the scenario
     never writes - by exactly the units;
  5. the cycle ending ASYMMETRICALLY, with a non-empty hold, so the end state is distinguishable
     from the start state;
  6. every untraded good unchanged, which is the witness that no OTHER carrier moved this market
     (bead oo-rkm: an observable with more than one carrier is a flaky observable).

A COUNT FLOOR IS NOT A CONTENT CHECK, so nothing here asserts merely "at least N of something".
Every predicate names the specific failure it exists to catch, in its message.

EXIT CODES: 0 the dump proves the cycle; 1 it does not (naming what is missing); 2 a usage or
structural error that prevented a verdict.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "004-trade-cycle"

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)

# PlayerEntityLoadSave.m:620-811 emits exactly this many stages inside -loadPlayerFromFile:.
LOAD_PROGRESS_STAGE_COUNT = 14
# trade-goods.plist defines 17 goods for the main system market.
MARKET_GOODS = 17


def fail(message):
    sys.stderr.write("FAIL: %s\n" % message)
    raise SystemExit(1)


def refuse(message):
    sys.stderr.write("REFUSED: %s\n" % message)
    raise SystemExit(2)


def load_spec():
    for path in SPEC_CANDIDATES:
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as handle:
                return json.load(handle), path
    refuse("no spec.json in any of %s; without it the expected knobs are unknown and this checker "
           "would be grading the dump against itself" % ", ".join(SPEC_CANDIDATES))


def check_leg(leg, side, units, spec, label):
    """One leg, checked against the engine's own before/after numbers recorded in the dump."""
    if leg.get("side") != side:
        fail("%s: leg %r is a %r leg, expected %r; a trade CYCLE is a buy followed by a sell, and "
             "two legs in the same direction are not a cycle" % (label, leg, leg.get("side"), side))
    if leg.get("units") != units:
        fail("%s: the %s leg traded %r unit(s) but the spec pins %d" % (label, side, leg.get("units"),
                                                                       units))
    sign = 1 if side == "buy" else -1
    scale = int(spec["credits_scale"])
    price = leg.get("price")
    if not isinstance(price, int) or price <= 0:
        fail("%s: the %s leg records price=%r. A good priced 0 moves the purse by 0, and 'the "
             "money moved' would be unfalsifiable." % (label, side, price))

    expected_cash = round(price * units / float(scale), 3)
    got_cash = round(leg["credits_after"] - leg["credits_before"], 3)
    if abs(got_cash - (-sign * expected_cash)) > 0.0005:
        fail("%s: the %s leg moved the purse %+.3f, but %d unit(s) at price %d over a credit scale "
             "of %d is %+.3f. PlayerEntity stores credits in TENTHS; if the engine changed that "
             "scale this is the line that says so, rather than the golden silently absorbing it."
             % (label, side, got_cash, units, price, scale, -sign * expected_cash))
    if got_cash == 0:
        fail("%s: the %s leg moved no money at all" % (label, side))

    market_delta = leg["market_quantity_after"] - leg["market_quantity_before"]
    if market_delta != -sign * units:
        fail("%s: the %s leg moved the market's quantity by %+d, expected %+d. The market is where "
             "the goods came from or went to; a leg the market did not feel is a leg that did not "
             "happen." % (label, side, market_delta, -sign * units))

    hold_delta = leg["hold_after"] - leg["hold_before"]
    if hold_delta != sign * units:
        fail("%s: the %s leg moved the hold by %+d, expected %+d"
             % (label, side, hold_delta, sign * units))

    used_delta = leg["cargo_space_used_after"] - leg["cargo_space_used_before"]
    if used_delta != sign * units:
        fail("%s: the %s leg moved cargoSpaceUsed by %+d, expected %+d. THIS NUMBER IS NOT WRITTEN "
             "BY THE SCENARIO - -calculateCurrentCargo recomputes it from the hold after the "
             "manifest write - so a disagreement means the write was clamped or dropped and the "
             "goods never reached the ship." % (label, side, used_delta, sign * units))

    if hold_delta != -market_delta:
        fail("%s: the %s leg moved the hold %+d and the market %+d. Goods are conserved across a "
             "trade: what leaves one side arrives at the other, and a leg where both moved the "
             "same way is goods appearing from nowhere." % (label, side, hold_delta, market_delta))
    return expected_cash


def check(path, spec, spec_path, label):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            dump = json.load(handle)
    except (OSError, ValueError) as exc:
        refuse("%s is not a readable JSON dump: %s: %s" % (path, type(exc).__name__, exc))
    if not isinstance(dump, dict):
        refuse("%s parsed to %r, not a dump" % (path, type(dump)))

    evidence = dump.get("evidence")
    if not isinstance(evidence, dict) or not evidence:
        fail("%s carries no `evidence` block. The canonical world state alone cannot distinguish a "
             "traded market from a freshly generated one, which is exactly the vacuity this block "
             "exists to close." % label)
    if evidence.get("scenario") != SCENARIO:
        fail("%s: evidence.scenario=%r, expected %r; this checker is grading the wrong scenario's "
             "dump" % (label, evidence.get("scenario"), SCENARIO))

    # --- defence 1: the engine's own load trace ---------------------------------------------
    stages = evidence.get("load_stages")
    if stages != list(spec["load_progress_stages"]):
        fail("%s: evidence.load_stages is %r, not the %d-stage sequence "
             "PlayerEntityLoadSave.m:620-811 logs inside -loadPlayerFromFile:. Those OOLog calls "
             "exist NOWHERE ELSE, so an empty list means the run never loaded the save and a "
             "PREFIX means the load died partway. rc=0 and an absence of ERROR lines are both "
             "satisfied by a launch that died in display setup."
             % (label, stages, LOAD_PROGRESS_STAGE_COUNT))
    if evidence.get("load_failures"):
        fail("%s: the engine logged %d [load.failed] line(s): %r"
             % (label, len(evidence["load_failures"]), evidence["load_failures"]))

    # --- defence 2/3/4: the two legs ---------------------------------------------------------
    legs = evidence.get("legs")
    if not isinstance(legs, list) or len(legs) != 2:
        fail("%s: evidence.legs is %r; a trade CYCLE is exactly two legs, a buy and a sell"
             % (label, legs))
    if evidence.get("commodity") != spec["commodity"]:
        fail("%s: evidence.commodity=%r but the spec pins %r; the scenario traded a different good "
             "than the one its knobs describe" % (label, evidence.get("commodity"),
                                                  spec["commodity"]))
    if evidence.get("credits_scale") != int(spec["credits_scale"]):
        fail("%s: evidence.credits_scale=%r but the spec pins %r"
             % (label, evidence.get("credits_scale"), spec["credits_scale"]))

    buy_cash = check_leg(legs[0], "buy", int(spec["buy_units"]), spec, label)
    sell_cash = check_leg(legs[1], "sell", int(spec["sell_units"]), spec, label)

    if legs[1]["hold_before"] != legs[0]["hold_after"]:
        fail("%s: the sell leg started from a hold of %d but the buy leg left %d. The legs are not "
             "consecutive states of one cycle; something between them changed the hold."
             % (label, legs[1]["hold_before"], legs[0]["hold_after"]))
    if legs[1]["market_quantity_before"] != legs[0]["market_quantity_after"]:
        fail("%s: the sell leg started from a market quantity of %d but the buy leg left %d; the "
             "market moved between the legs, so this scenario is not the only carrier"
             % (label, legs[1]["market_quantity_before"], legs[0]["market_quantity_after"]))

    # --- defence 5: the cycle is ASYMMETRIC and ends somewhere new ----------------------------
    if int(spec["sell_units"]) >= int(spec["buy_units"]):
        fail("%s: the spec sells %d of the %d bought. A cycle that returns exactly to its starting "
             "point leaves a purse, a hold and a market identical to a run that never traded, so "
             "the golden would be satisfied by a dead trade."
             % (label, spec["sell_units"], spec["buy_units"]))
    if evidence.get("cargo_after_cycle") != int(spec["expected_cargo_after"]):
        fail("%s: the hold carries %r unit(s) of %s after the cycle, but the spec pins %r"
             % (label, evidence.get("cargo_after_cycle"), spec["commodity"],
                spec["expected_cargo_after"]))
    if not evidence.get("cargo_after_cycle"):
        fail("%s: the cycle ended with an empty hold - the state a run that did nothing is in"
             % label)

    net = round(evidence["credits_after"] - evidence["credits_before"], 3)
    if abs(net - round(sell_cash - buy_cash, 3)) > 0.0005:
        fail("%s: the purse moved %+.3f across the whole cycle, but the two legs account for "
             "%+.3f. Money entered or left the purse outside the trade."
             % (label, net, round(sell_cash - buy_cash, 3)))
    if net == 0:
        fail("%s: the purse is unchanged across the whole cycle; at these prices a %d-buy and a "
             "%d-sell cannot net to zero, so this dump does not describe the cycle it claims to"
             % (label, spec["buy_units"], spec["sell_units"]))

    market_net = evidence["market_quantity_after"] - evidence["market_quantity_before"]
    if market_net != int(spec["sell_units"]) - int(spec["buy_units"]):
        fail("%s: the market's quantity of %s moved %+d across the cycle, expected %+d"
             % (label, spec["commodity"], market_net,
                int(spec["sell_units"]) - int(spec["buy_units"])))

    # --- defence 6: the untraded goods, i.e. nothing else wrote to this market ----------------
    changed = evidence.get("untraded_goods_changed")
    if changed:
        fail("%s: %d good(s) this scenario never traded changed during the run: %r. The market has "
             "another carrier, so the observable is shared and this gate is a race against it "
             "rather than a measurement (bead oo-rkm). Diagnose the carrier; do not widen the "
             "comparison." % (label, len(changed), changed))
    compared = evidence.get("untraded_goods_compared")
    if compared != MARKET_GOODS - 1:
        fail("%s: %r untraded good(s) were compared, but the main system market has %d goods and "
             "exactly one of them is traded. A shortened control is the vacuity route wearing a "
             "smaller hat: with nothing to compare, 'nothing else moved' is free."
             % (label, compared, MARKET_GOODS))

    # --- the knobs the dump carries must be the knobs the spec pins --------------------------
    for knob in ("seed", "ticks", "system_id"):
        if evidence.get(knob) != int(spec[knob]):
            fail("%s: evidence.%s=%r but the spec pins %r. The run was made with different knobs "
                 "than the ones recorded beside it." % (label, knob, evidence.get(knob),
                                                        spec[knob]))
    if not evidence.get("tick_budget_met"):
        fail("%s: evidence.tick_budget_met is %r; the run did not hold the goods for the pinned "
             "%s seconds of game time" % (label, evidence.get("tick_budget_met"),
                                          evidence.get("game_seconds_budget")))
    if not evidence.get("world_at_rest") or not evidence.get("world_reached_fixed_point"):
        fail("%s: the world was not at a fixed point when the dump was taken (at_rest=%r, "
             "fixed_point=%r), so the dump is a function of how many frames this box rendered"
             % (label, evidence.get("world_at_rest"), evidence.get("world_reached_fixed_point")))

    # --- the canonical dump itself must agree with the evidence -------------------------------
    market = dump.get("market")
    if not isinstance(market, dict) or len(market) != MARKET_GOODS:
        fail("%s: the canonical dump's `market` is %r, not the %d-good market. The bead asks for "
             "the market in the canonical dump, not only in the evidence block."
             % (label, type(market), MARKET_GOODS))
    good = market.get(spec["commodity"])
    if not good:
        fail("%s: the canonical dump's market has no %r" % (label, spec["commodity"]))
    if good.get("quantity") != evidence["market_quantity_after"]:
        fail("%s: the canonical dump's market quantity for %s is %r but the evidence block records "
             "%r after the cycle; one of the two was edited alone"
             % (label, spec["commodity"], good.get("quantity"), evidence["market_quantity_after"]))
    player = dump.get("player") or {}
    if round(float(player.get("credits", -1)), 3) != round(evidence["credits_after"], 3):
        fail("%s: the canonical dump's player.credits is %r but the evidence records %r after the "
             "cycle; one of the two was edited alone"
             % (label, player.get("credits"), evidence["credits_after"]))
    cargo = {row["commodity"]: row["quantity"] for row in (player.get("cargo") or [])}
    if cargo.get(spec["commodity"]) != evidence["cargo_after_cycle"]:
        fail("%s: the canonical dump's manifest carries %r of %s but the evidence records %r; the "
             "dump's own cargo list is the copy a future diff compares, so the two must agree"
             % (label, cargo.get(spec["commodity"]), spec["commodity"],
                evidence["cargo_after_cycle"]))

    print("PASS: %s proves a trade cycle. Loaded %s (%s, %d bytes) into system %d with all %d "
          "engine-logged load stages; bought %d %s at %d costing %.1f cr, held it %d tick(s) "
          "(%.3f s of game time), sold %d back for %.1f cr; the purse went %.3f -> %.3f (net "
          "%+.3f), the market's quantity went %d -> %d, and the hold ends at %d - engine-recomputed "
          "cargoSpaceUsed agreeing with every leg. All %d untraded good(s) unchanged, so nothing "
          "but this scenario wrote to the market. Knobs read from %s."
          % (label, evidence["save_file"], evidence["save_written_by_version"],
             evidence["save_bytes"], evidence["system_id"], len(stages),
             int(spec["buy_units"]), spec["commodity"], evidence["market_price"], buy_cash,
             evidence["ticks"], evidence["game_seconds_budget"], int(spec["sell_units"]),
             sell_cash, evidence["credits_before"], evidence["credits_after"], net,
             evidence["market_quantity_before"], evidence["market_quantity_after"],
             evidence["cargo_after_cycle"], compared,
             os.path.relpath(spec_path, REPO_ROOT).replace(os.sep, "/")))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_trade_cycle_evidence.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    spec, spec_path = load_spec()
    return check(args.dump, spec, spec_path, args.label or args.dump)


if __name__ == "__main__":
    sys.exit(main())
