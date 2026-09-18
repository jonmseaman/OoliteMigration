"""Gate: scenario 004's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH
PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` is written, for the same measured reason: bead
oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting hid a survivor - a
knob that was PRINTED but never PREDICATED - so the checks live in a readable file and the stored
acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source or this scenario's own measurements support.
  2. IS IT READ, WHERE IT ACTS?  `trade_cycle.py` must read `spec["<knob>"]` inside the FUNCTION
     that acts on it, checked by AST rather than by substring. A knob read only to be copied into
     the evidence block is still decoration: the dump reports the spec's value while the behaviour
     runs on a literal, and a substring gate stays green (bead oo-3ya measured exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse - it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOBS THIS SCENARIO GUARDS HARDEST ARE THE TRADE ARITHMETIC
----------------------------------------------------------------
`buy_units`, `sell_units` and `expected_cargo_after` are not three independent numbers: the cycle
must close (`expected_cargo_after == buy_units - sell_units`) AND it must be ASYMMETRIC
(`sell_units < buy_units`). A symmetric cycle returns the purse, the hold and the market to their
starting values, leaving a dump indistinguishable from a run that never traded - a golden a dead
trade would satisfy. Both predicates are here because editing one number alone is exactly how such
a scenario rots into decoration.

`credits_scale` gets its own predicate for the opposite reason: it is the one number in the
arithmetic that is a property of the ENGINE (PlayerEntity stores credits in tenths), not of this
scenario's choices. It was MEASURED, not assumed, and a value of 1 would make every cash assertion
pass for a purse that moved ten times too far.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "004-trade-cycle"
SCENARIO_SCRIPT = os.path.join(HERE, "trade_cycle.py")

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
# Guarded location first, staged location second, so this file keeps working unchanged after a
# human re-bless moves the artifacts (guardrails.sh refuses CREATE as well as MODIFY under
# goldens/, so this bead cannot land them there itself).
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
    os.path.join(HERE, "pending", SCENARIO),
)

REQUIRED_KNOBS = (
    "seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
    "commodity", "buy_units", "sell_units", "expected_cargo_after", "credits_scale",
    "log_channels", "load_progress_stages", "repopulator_handlers",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "load_save": "save_path",
    "log_channels": "enable_load_logging",
    "system_id": "assert_system",
    "repopulator_handlers": "suppress_repopulator",
    "commodity": "market_snapshot",
    "credits_scale": "trade_leg",
    "load_progress_stages": "assert_ran",
    "buy_units": "assert_ran",
    "sell_units": "assert_ran",
    "expected_cargo_after": "assert_ran",
    # run_once(), not run(): run() is the thin relaunch wrapper, and the knobs are read by the
    # function that actually launches the game and acts on them.
    "seed": "run_once",
    "ticks": "run_once",
    "tick_seconds": "run_once",
}

POLICY_QUANT_DECIMALS = 3

# PlayerEntityLoadSave.m:620-811 logs exactly this many stages inside -loadPlayerFromFile:.
LOAD_PROGRESS_STAGE_COUNT = 14
# The channel carrying the engine's OWN proof that -load was honoured. OFF by default
# (Resources/Config/logcontrol.plist:241), so a spec that drops it silently blinds defence 1.
REQUIRED_LOG_CHANNEL = "load.progress"
# PlayerEntity stores credits in TENTHS. Measured: 5 units of food at price 40 moved the balance
# by exactly 20.0. A scale of 1 would let a purse that moved ten times too far pass every check.
CREDITS_SCALE = 10

SAVE_SUFFIX = "Checklist-files/Missions/CloakingDevice.oolite-save"

STABILITY_RUNS_REQUIRED = 10


def fail(message):
    sys.stderr.write("FAIL: %s\n" % message)
    raise SystemExit(1)


def refuse(message):
    sys.stderr.write("REFUSED: %s\n" % message)
    raise SystemExit(2)


def resolve_golden_dir():
    for candidate in GOLDEN_CANDIDATES:
        if os.path.isfile(os.path.join(candidate, "provenance.json")):
            return candidate
    refuse("no provenance.json in any of %s; the knobs the golden was blessed with are unrecorded, "
           "so nothing can detect the spec drifting away from them" % ", ".join(GOLDEN_CANDIDATES))


def check_pinned(spec):
    missing = [k for k in REQUIRED_KNOBS if k not in spec]
    if missing:
        fail("spec.json does not pin %s; without them the scenario is not reproducible" % missing)

    if spec["quant_decimals"] != POLICY_QUANT_DECIMALS:
        fail("spec quant_decimals=%r but the storage policy is %d. Coarsening quantisation makes "
             "every golden pass and is the standard way a golden suite rots into decoration."
             % (spec["quant_decimals"], POLICY_QUANT_DECIMALS))
    if not isinstance(spec["ticks"], int) or spec["ticks"] < 1:
        fail("spec ticks=%r, must be a positive int" % spec["ticks"])
    if not isinstance(spec["tick_seconds"], (int, float)) or spec["tick_seconds"] <= 0:
        fail("spec tick_seconds=%r, must be a positive number" % spec["tick_seconds"])
    if not isinstance(spec["seed"], int):
        fail("spec seed=%r, must be an int" % spec["seed"])
    if not isinstance(spec["system_id"], int):
        fail("spec system_id=%r, must be an int" % spec["system_id"])

    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s. This scenario's market, prices and purse are "
             "the ones THAT save is docked in; pointed at any other file it is a different "
             "scenario wearing this one's golden." % (spec["load_save"], SAVE_SUFFIX))

    # --- the trade arithmetic ------------------------------------------------------------------
    buy, sell, after = spec["buy_units"], spec["sell_units"], spec["expected_cargo_after"]
    if not all(isinstance(v, int) for v in (buy, sell, after)):
        fail("spec buy_units=%r / sell_units=%r / expected_cargo_after=%r must all be ints"
             % (buy, sell, after))
    if buy < 1 or sell < 1:
        fail("spec buy_units=%r sell_units=%r; a leg of zero units moves nothing and asserts "
             "nothing" % (buy, sell))
    if sell >= buy:
        fail("spec sells %d of the %d bought. The cycle MUST be asymmetric: one that returns to "
             "its starting point leaves a purse, a hold and a market identical to a run that never "
             "traded, so the stored golden would be satisfied by a dead trade." % (sell, buy))
    if after != buy - sell:
        fail("spec expects %d unit(s) in the hold after buying %d and selling %d; the arithmetic "
             "does not close, so one of the three numbers was edited alone and the scenario's "
             "claim about its own end state is unfalsifiable." % (after, buy, sell))

    if spec["credits_scale"] != CREDITS_SCALE:
        fail("spec credits_scale=%r, but PlayerEntity stores credits in TENTHS - measured on this "
             "box, 5 units of food at price 40 moved the balance by exactly 20.0. A scale of 1 "
             "would make every cash assertion pass for a purse that moved ten times too far, and "
             "a scale of 100 would pass for one that barely moved." % spec["credits_scale"])
    if not isinstance(spec["commodity"], str) or not spec["commodity"]:
        fail("spec commodity=%r must be a non-empty trade-goods.plist key" % spec["commodity"])

    stages = spec["load_progress_stages"]
    if not isinstance(stages, list) or len(stages) != LOAD_PROGRESS_STAGE_COUNT:
        fail("spec pins %r load.progress stage(s); PlayerEntityLoadSave.m:620-811 emits exactly "
             "%d, and the WHOLE ORDERED sequence is what distinguishes a completed load from one "
             "that died partway (which emits a PREFIX)."
             % (len(stages) if isinstance(stages, list) else stages, LOAD_PROGRESS_STAGE_COUNT))
    if len(set(stages)) != len(stages):
        fail("spec load_progress_stages contains duplicates; the sequence is compared in order and "
             "a duplicated stage hides a missing one")

    if REQUIRED_LOG_CHANNEL not in spec["log_channels"]:
        fail("spec log_channels %r omits %r. That channel is OFF by default "
             "(Resources/Config/logcontrol.plist:241) and carries the engine's OWN proof that "
             "-load was honoured; without it the load_stages defence reads an empty list and the "
             "whole presence-of-progress precondition disappears."
             % (spec["log_channels"], REQUIRED_LOG_CHANNEL))
    if not spec["repopulator_handlers"]:
        fail("spec repopulator_handlers is empty; oolite-populator.js's repopulate handler defeats "
             "both other suppressions on its own (its _tradeStation ends with an unconditional "
             "`return system.mainStation`), so an empty list means the world is not quiet")
    return True


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob == "quant_decimals":
            continue  # applied by the shared dump policy, not by this scenario's own code
        if 'spec["%s"]' % knob not in source:
            fail("trade_cycle.py never reads spec[%r]; the knob is decoration - changing it would "
                 "change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("trade_cycle.py has no function %r, so the gate cannot verify that spec[%r] is "
                 "read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("trade_cycle.py reads spec[%r] somewhere, but NOT inside %s() - the function that "
                 "acts on it. A knob read only to be copied into the evidence block is still "
                 "decoration: the dump would report the spec's value while the behaviour ran on a "
                 "literal, and a substring-only gate would stay green." % (knob, func_name))


def check_isolation(source):
    console_path = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py")
    if not os.path.isfile(console_path):
        refuse("no console.py at %s" % console_path)
    with open(console_path, "r", encoding="utf-8") as handle:
        console_src = handle.read()
    if "OO_RANDOM_SEED" not in console_src:
        fail("console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game")
    if "seed=seed" not in source:
        fail("trade_cycle.py does not pass seed= to DebugConsole; the seed never reaches the game")
    if "reserve_port" not in source:
        fail("trade_cycle.py does not reserve a private console port; on the shared 8563 a sibling "
             "worker's console can capture and quit the game seconds in and the run still exits 0 "
             "with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("trade_cycle.py does not write a debugConfig.plist; the game DIALS OUT to the port "
             "named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/system/ticks/units this golden was BLESSED "
             "with are unrecorded, so nothing can detect the spec drifting away from them"
             % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/trade_cycle.py":
        fail("%s records dump_tool=%r, expected tests/golden/trade_cycle.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "commodity", "buy_units", "sell_units",
                              "expected_cargo_after", "credits_scale") if k not in knobs]
    if unrecorded:
        fail("provenance scenario_knobs does not record %s; those knobs could be changed in the "
             "spec with nothing going red" % unrecorded)

    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    if drift:
        fail("spec.json disagrees with the knobs this golden was blessed with (%s records "
             "blessed-vs-spec %r). The stored golden no longer corresponds to what the spec would "
             "produce; re-bless deliberately or restore the spec - do NOT edit one side to match."
             % (prov_path, drift))

    # --- the 10-run stability claim, accounted for run by run ---------------------------------
    stability = provenance.get("stability") or {}
    runs = stability.get("runs")
    if not isinstance(runs, int) or runs < STABILITY_RUNS_REQUIRED:
        fail("provenance records %r stability run(s); the scenario must prove stability over at "
             "least %d" % (runs, STABILITY_RUNS_REQUIRED))
    digests = stability.get("distinct_dump_digests") or []
    if len(digests) != 1:
        fail("the stability sweep produced %d distinct dump digest(s) %r; a golden may be blessed "
             "only from a sweep that agreed with itself" % (len(digests), digests))
    dumped = stability.get("dumps_written")
    refused = stability.get("refused")
    errored = stability.get("errored")
    if not all(isinstance(v, int) for v in (dumped, refused, errored)):
        fail("provenance stability must record integer dumps_written/refused/errored, got %r/%r/%r"
             % (dumped, refused, errored))
    if dumped + refused != runs:
        fail("provenance stability accounts for %d dumped + %d refused out of %d run(s); every "
             "run's outcome must be recorded regardless of exit code, and a REFUSAL (the harness "
             "declining to dump an unsettled world) is not a DIFFERENCE - collapsing the two is "
             "how a stability claim goes dishonest (bead oo-jor)." % (dumped, refused, runs))
    if errored != 0:
        fail("provenance records %d errored run(s) in the stability sweep; an errored run has no "
             "verdict and cannot support a stability claim" % errored)
    if dumped < 2:
        fail("only %d run(s) produced a dump; with fewer than two there is nothing to compare"
             % dumped)
    per_run = stability.get("per_run") or []
    if len(per_run) != runs:
        fail("provenance records %d per-run entries for %d run(s); a sweep that does not report "
             "every run's outcome can hide the ones that disagreed" % (len(per_run), runs))

    # --- the frame: liveness AND tolerance, both measured --------------------------------------
    tolerance = provenance.get("frame_tolerance") or {}
    if tolerance.get("asserted") is not True:
        fail("provenance frame_tolerance.asserted=%r. This scenario's scene is a docked market "
             "view with no animated population, and its same-scene spread was MEASURED below the "
             "calibrated tolerance - see frame_measurements. Dropping the assertion would leave "
             "the frame artifact judged only by liveness, which an unrelated scene also passes."
             % tolerance.get("asserted"))
    if not tolerance.get("tolerance_source"):
        fail("provenance frame_tolerance records no tolerance_source; a tolerance with no "
             "provenance is a number somebody chose to make a run pass")
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the property a DEAD run fails (a "
             "run that died before drawing yields an all-black grid at distance 0). A tolerance "
             "assertion alone does not catch it, because two black frames match perfectly."
             % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)

    artifacts = provenance.get("artifacts") or {}
    if "state.json" not in artifacts:
        fail("%s records no artifacts.state.json digest. Without a witness OUTSIDE the file being "
             "defended, editing the golden moves BOTH sides of every self-comparison and no line "
             "can see it (beads oo-3ya, oo-gxp)." % prov_path)
    return provenance, knobs, stability, floor


def main():
    spec_path = next((c for c in SPEC_CANDIDATES if os.path.isfile(c)), None)
    if spec_path is None:
        refuse("no spec.json in any of %s" % ", ".join(SPEC_CANDIDATES))
    if not os.path.isfile(SCENARIO_SCRIPT):
        refuse("no scenario script at %s" % SCENARIO_SCRIPT)

    with open(spec_path, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    with open(SCENARIO_SCRIPT, "r", encoding="utf-8") as handle:
        source = handle.read()

    check_pinned(spec)
    check_read_where_it_acts(source)
    check_isolation(source)
    golden_dir = resolve_golden_dir()
    _, knobs, stability, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=%d; loads %s; buys %d %s and "
          "sells %d back, leaving %d (asymmetric by construction, arithmetic closes) at a credit "
          "scale of %d; %d load.progress stage(s) pinned. All %d knob(s) pinned, every one read by "
          "trade_cycle.py with %d checked by AST inside the function that acts on it, and all %d "
          "agree with the knobs recorded in %s. Stability: %d run(s), %d dumped / %d refused / %d "
          "errored, %d distinct dump digest. Frame: liveness ASSERTED at floor %.4f AND tolerance "
          "ASSERTED from the calibrated measurement."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], spec["buy_units"], spec["commodity"],
             spec["sell_units"], spec["expected_cargo_after"], spec["credits_scale"],
             len(spec["load_progress_stages"]), len(REQUIRED_KNOBS), len(READ_IN_FUNCTION),
             len(knobs), os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
