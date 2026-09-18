"""Gate: scenario 015's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_003_spec.py` is written, for the same measured reasons: bead
oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting hid a survivor (a
knob that was PRINTED but never PREDICATED), so the checks live in a readable file and the stored
acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `trumbles_load.py` must read `spec["<knob>"]` inside the FUNCTION
     that acts on it, checked by AST rather than by substring. A knob read only to be copied into
     the evidence block is still decoration: the dump reports the spec's value while the behaviour
     runs on a literal, and a substring gate stays green (bead oo-3ya measured exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOB THIS SCENARIO GUARDS HARDEST IS `trumble_awards`
---------------------------------------------------------
PlayerEntity.m:11531 gates a trumble award on
`trumbleCount < PLAYER_MAX_TRUMBLES/6 || (trumbleCount < PLAYER_MAX_TRUMBLES/3 && ranrot_rand() % 2)`
and PLAYER_MAX_TRUMBLES is 24 (PlayerEntity.h:312). The first FOUR awards take the left branch
unconditionally; the fifth onwards consults RANROT, and a fixed seed pins the SEQUENCE but not how
far into it a run has advanced (bead oo-izi's finding for `system.addShips`). Three runs at THIS
seed were measured agreeing on the first four awards and diverging from the fifth. So 4 is a
MEASURED BOUNDARY, not a convenient number, and raising it silently makes the golden unreproducible
while every comparison still passes on the day it is re-blessed. It gets its own predicate here.

THE FRAME KNOBS ARE GUARDED IN THE OPPOSITE DIRECTION
-----------------------------------------------------
This scenario MEASURED the frame-vs-reference tolerance and REJECTED it: HeadUpDisplay.m:3306
-drawTrumbles: animates the live population every rendered frame, so same-scene pairs land at
1.08x..2.49x the measured tolerance while a ZERO-trumble control frame sits inside that same band -
signal smaller than noise. The gate therefore requires provenance to record `frame_tolerance
.asserted == false` WITH a reason, and `frame_liveness.asserted == true` with a positive floor, so
that neither a later "fix" that widens the tolerance until runs pass, nor a deletion of the one
frame property the data does support, can pass silently.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "015-trumbles"
SCENARIO_SCRIPT = os.path.join(HERE, "trumbles_load.py")

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
# Guarded location first, staged location second, so this file keeps working unchanged after a
# human re-bless moves the artifacts (bead oo-8ij: guardrails.sh refuses CREATE as well as MODIFY
# under goldens/, so this bead cannot land them there itself).
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
    os.path.join(HERE, "pending", SCENARIO),
)

REQUIRED_KNOBS = (
    "seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
    "trumble_awards", "expected_trumble_count", "expected_saved_trumble_count",
    "mission_trumbles_key", "expected_mission_variable_keys", "log_channels",
    "load_progress_stages", "repopulator_handlers", "census",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "load_save": "save_path",
    "census": "saved_census",
    "log_channels": "enable_load_logging",
    "system_id": "assert_system",
    "repopulator_handlers": "suppress_repopulator",
    "load_progress_stages": "assert_ran",
    "expected_mission_variable_keys": "assert_ran",
    "mission_trumbles_key": "assert_ran",
    "expected_trumble_count": "assert_ran",
    "expected_saved_trumble_count": "assert_ran",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
    "trumble_awards": "run",
}

POLICY_QUANT_DECIMALS = 3

# PlayerEntity.h:312. The award gate's unconditional branch is `trumbleCount < MAX/6`.
PLAYER_MAX_TRUMBLES = 24
DETERMINISTIC_AWARD_PREFIX = PLAYER_MAX_TRUMBLES // 6

# PlayerEntityLoadSave.m:620-811 logs exactly this many stages inside -loadPlayerFromFile:.
LOAD_PROGRESS_STAGE_COUNT = 14

# The channel that carries the engine's OWN proof that -load was honoured. It is OFF by default
# (Resources/Config/logcontrol.plist:241), so a spec that drops it silently blinds defence 1.
REQUIRED_LOG_CHANNEL = "load.progress"

SAVE_SUFFIX = "Checklist-files/Missions/Trumbles.oolite-save"

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
    refuse("no provenance.json in any of %s; the knobs the golden was blessed with are "
           "unrecorded, so nothing can detect the spec drifting away from them"
           % ", ".join(GOLDEN_CANDIDATES))


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

    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s. This scenario exists to load the checklist "
             "Trumbles save and pin the 1.75 save-format compatibility contract; pointed at any "
             "other file it is a different scenario wearing this one's golden."
             % (spec["load_save"], SAVE_SUFFIX))

    awards = spec["trumble_awards"]
    if awards != DETERMINISTIC_AWARD_PREFIX:
        fail("spec trumble_awards=%r, but PLAYER_MAX_TRUMBLES/6 = %d/%d = %d is the MEASURED "
             "deterministic prefix of PlayerEntity.m:11531's award gate. The fifth award onwards "
             "consults ranrot_rand(), and a fixed seed pins the RANROT SEQUENCE but not how far "
             "into it a run has advanced - three runs at this seed were measured agreeing on the "
             "first four awards and diverging from the fifth. Raising this makes the golden "
             "unreproducible while every comparison still passes on the day it is re-blessed."
             % (awards, PLAYER_MAX_TRUMBLES, 6, DETERMINISTIC_AWARD_PREFIX))

    saved = spec["expected_saved_trumble_count"]
    expected = spec["expected_trumble_count"]
    if not all(isinstance(v, int) for v in (saved, expected)):
        fail("spec expected_saved_trumble_count=%r / expected_trumble_count=%r must both be ints"
             % (saved, expected))
    if expected != saved + awards:
        fail("spec expects %r trumbles from %r loaded out of the save plus %r awarded; the "
             "arithmetic does not close, so the scenario's population claim is unfalsifiable - "
             "one of the three numbers was edited alone." % (expected, saved, awards))

    keys = spec["expected_mission_variable_keys"]
    if not isinstance(keys, list) or not keys:
        fail("spec expected_mission_variable_keys=%r must be a non-empty list. A DEFAULT NEW GAME "
             "has NO mission variables (PlayerEntity.m:1986-1987), which is precisely what makes "
             "this check unsatisfiable by a run that ignored -load; an empty list asserts nothing."
             % keys)
    if spec["mission_trumbles_key"] not in keys:
        fail("spec expected_mission_variable_keys %r does not contain mission_trumbles_key %r. "
             "The bead names mission_trumbles as the field the canonical dump must carry."
             % (keys, spec["mission_trumbles_key"]))

    stages = spec["load_progress_stages"]
    if not isinstance(stages, list) or len(stages) != LOAD_PROGRESS_STAGE_COUNT:
        fail("spec pins %r load.progress stage(s); PlayerEntityLoadSave.m:620-811 emits exactly "
             "%d, and the WHOLE ORDERED sequence is what distinguishes a completed load from one "
             "that died partway (which emits a PREFIX)."
             % (len(stages) if isinstance(stages, list) else stages, LOAD_PROGRESS_STAGE_COUNT))
    if len(set(stages)) != len(stages):
        fail("spec load_progress_stages contains duplicates; the sequence is compared in order "
             "and a duplicated stage hides a missing one")

    channels = spec["log_channels"]
    if REQUIRED_LOG_CHANNEL not in channels:
        fail("spec log_channels %r omits %r. That channel is OFF by default "
             "(Resources/Config/logcontrol.plist:241) and it carries the engine's OWN proof that "
             "-load was honoured; without it the load_stages defence reads an empty list and the "
             "'no cheat messages' check becomes vacuous because the channel that would emit them "
             "was never switched on." % (channels, REQUIRED_LOG_CHANNEL))

    census = spec["census"]
    if not isinstance(census, list) or len(census) < 2:
        fail("spec census=%r must list at least two fields; the round trip compares the save FILE "
             "(Python plistlib, this process) against the LIVE GAME (JS over the console, another "
             "OS process), and one field cannot distinguish a loaded save from a lucky default."
             % census)
    for entry in census:
        for key in ("plist", "js", "kind", "why"):
            if key not in entry:
                fail("spec census entry %r does not declare %r; every census field must name the "
                     "plist key, the JS expression that reads the same quantity out of the loaded "
                     "game, how the two are made comparable, and why it is evidence"
                     % (entry, key))
    return census


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob == "quant_decimals":
            continue  # applied by the shared dump policy, not by this scenario's own code
        if 'spec["%s"]' % knob not in source:
            fail("trumbles_load.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree)
                 if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("trumbles_load.py has no function %r, so the gate cannot verify that spec[%r] is "
                 "read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("trumbles_load.py reads spec[%r] somewhere, but NOT inside %s() - the function "
                 "that acts on it. A knob read only to be copied into the evidence block is still "
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
        fail("trumbles_load.py does not pass seed= to DebugConsole; the seed never reaches the game")
    if "reserve_port" not in source:
        fail("trumbles_load.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("trumbles_load.py does not write a debugConfig.plist; the game DIALS OUT to the port "
             "named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/ticks/awards this golden was BLESSED with "
             "are unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/trumbles_load.py":
        fail("%s records dump_tool=%r, expected tests/golden/trumbles_load.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "trumble_awards", "expected_trumble_count",
                              "expected_saved_trumble_count") if k not in knobs]
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
             "how a stability claim goes dishonest (bead oo-jor, golden_diff's rc=2-vs-rc=1)."
             % (dumped, refused, runs))
    if errored != 0:
        fail("provenance records %d errored run(s) in the stability sweep; an errored run has no "
             "verdict and cannot support a stability claim" % errored)
    if dumped < 2:
        fail("only %d run(s) produced a dump; with fewer than two there is nothing to compare and "
             "no stability claim can be made" % dumped)
    per_run = stability.get("per_run") or []
    if len(per_run) != runs:
        fail("provenance records %d per-run entries for %d run(s); a sweep that does not report "
             "every run's outcome can hide the ones that disagreed" % (len(per_run), runs))

    # --- the frame: liveness asserted, tolerance deliberately NOT ----------------------------
    tolerance = provenance.get("frame_tolerance") or {}
    if tolerance.get("asserted") is not False:
        fail("provenance frame_tolerance.asserted=%r. For THIS scenario the frame-vs-reference "
             "tolerance was measured and REJECTED: HeadUpDisplay.m:3306 -drawTrumbles: animates "
             "the live population every rendered frame, so same-scene pairs sit at 1.08x..2.49x "
             "the measured tolerance while a ZERO-trumble control frame falls inside the same "
             "band - signal smaller than noise. Asserting it would require widening the tolerance "
             "until every run passes, which is a gate that passes for the wrong reasons too."
             % tolerance.get("asserted"))
    if not tolerance.get("why_not_asserted"):
        fail("provenance frame_tolerance records no why_not_asserted; a rejected assertion must "
             "carry its measurement, or the next agent re-adds it and re-derives the flake")
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the one frame property the "
             "measurements DO support and the one a dead run fails (a run that died before "
             "drawing yields an all-black grid at distance 0). Dropping it leaves the frame "
             "artifact entirely unpinned." % liveness.get("asserted"))
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

    census = check_pinned(spec)
    check_read_where_it_acts(source)
    check_isolation(source)
    golden_dir = resolve_golden_dir()
    _, knobs, stability, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=%d; loads %s; %d award(s) "
          "(= PLAYER_MAX_TRUMBLES/6, the measured deterministic prefix) grow %d saved trumble(s) "
          "to %d; %d load.progress stage(s), %d mission variable key(s) including %r, and %d "
          "census field(s) pinned. All %d knob(s) pinned, every one read by trumbles_load.py with "
          "%d checked by AST inside the function that acts on it, and all %d agree with the knobs "
          "recorded in %s. Stability: %d run(s), %d dumped / %d refused / %d errored, %d distinct "
          "dump digest. Frame: liveness ASSERTED at floor %.4f, tolerance deliberately NOT "
          "asserted (measured and rejected)."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], spec["trumble_awards"],
             spec["expected_saved_trumble_count"], spec["expected_trumble_count"],
             len(spec["load_progress_stages"]), len(spec["expected_mission_variable_keys"]),
             spec["mission_trumbles_key"], len(census), len(REQUIRED_KNOBS),
             len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
