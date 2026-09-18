"""Gate: scenario 017's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` is written, for the same measured reasons: bead
oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting hid a survivor (a
knob that was PRINTED but never PREDICATED), so the checks live in a readable file and the stored
acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `thargoid_plans_load.py` must read `spec["<knob>"]` inside the
     FUNCTION that acts on it, checked by AST rather than by substring. A knob read only to be
     copied into the evidence block is still decoration: the dump reports the spec's value while
     the behaviour runs on a literal, and a substring gate stays green (bead oo-3ya measured
     exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOB THIS SCENARIO GUARDS HARDEST IS `load_migrations`
-----------------------------------------------------------
This fixture is a 1.75 save carrying a legacy EQ_ENERGY_BOMB, and PlayerEntity.m:1731-1746 pays
9000 decicredits (900 credits) of compensation for it at load time. That is the save-format
compatibility contract the bead names, and it is also the single most dangerous knob in the spec:
the census adds the same delta on the FILE side to keep the round trip an EXACT equality, so a
delta edited alone silently changes what "the loaded credits are correct" means. The gate
therefore requires the delta to be the engine's 9000, the migrated field to be a real census
field, and the engine's own log message to be pinned alongside it - a migration applied without
the log line asserted would be an unfalsifiable fudge factor.

THE MISSION VARIABLE ASSERTION IS GUARDED FOR ITS *FORM*
---------------------------------------------------------
Scenario 015 could only assert a mission variable KEY SET because its fixture's `mission_trumbles`
is the EMPTY STRING, and an absent mission variable reads identically over the JS bridge. THIS
fixture's five values are all non-empty, so the whole MAP is asserted. The gate enforces that
strength: no expected value may be the empty string, because such a value would be satisfied by a
game that had never heard of the mission, and it would be satisfied SILENTLY.

THE FRAME KNOBS
---------------
Unlike scenario 015 this scenario's scene is static and the frame-vs-reference tolerance WAS
measurable: 45 same-scene pairs at 0.31x..0.35x of it against a wrong-scene distance at 5.7x,
separation ratio 16.2. The gate requires provenance to record `frame_tolerance.asserted == true`
WITH its measurements AND `frame_liveness.asserted == true` with a positive floor, so that neither
a silent downgrade to "liveness only" nor a deletion of the absolute floor can pass unnoticed.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "017-thargoid-plans"
SCENARIO_SCRIPT = os.path.join(HERE, "thargoid_plans_load.py")

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
    "expected_save_version", "load_migrations", "expected_upgrade_messages",
    "expected_mission_variables", "thargplans_key", "thargplans_expected",
    "thargplans_precondition_probes", "expected_thargplans_preconditions",
    "log_channels", "load_progress_stages", "repopulator_handlers", "census",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "load_save": "save_path",
    "census": "saved_census",
    "load_migrations": "apply_load_migrations",
    "log_channels": "enable_load_logging",
    "system_id": "assert_system",
    "repopulator_handlers": "suppress_repopulator",
    "thargplans_precondition_probes": "thargplans_preconditions",
    "load_progress_stages": "assert_ran",
    "expected_mission_variables": "assert_ran",
    "expected_thargplans_preconditions": "assert_ran",
    "expected_upgrade_messages": "assert_ran",
    "expected_save_version": "assert_ran",
    "thargplans_key": "assert_ran",
    "thargplans_expected": "assert_ran",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
}

POLICY_QUANT_DECIMALS = 3

# PlayerEntityLoadSave.m:620-811 logs exactly this many stages inside -loadPlayerFromFile:.
LOAD_PROGRESS_STAGE_COUNT = 14

# The channel that carries the engine's OWN proof that -load was honoured. It is OFF by default
# (Resources/Config/logcontrol.plist:241), so a spec that drops it silently blinds defence 1.
REQUIRED_LOG_CHANNEL = "load.progress"
# The channel that carries the engine's OWN proof that the 1.75 migration happened.
REQUIRED_UPGRADE_CHANNEL = "load.upgrade.replacedEnergyBomb"

SAVE_SUFFIX = "Checklist-files/Missions/ThargoidPlans.oolite-save"
EXPECTED_SAVE_VERSION = "1.75"
# PlayerEntity.m:1743 `credits += 9000`. Decicredits, i.e. 900 credits.
ENERGY_BOMB_COMPENSATION_DECICREDITS = 9000

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
             "ThargoidPlans save and pin the 1.75 save-format compatibility contract; pointed at "
             "any other file it is a different scenario wearing this one's golden."
             % (spec["load_save"], SAVE_SUFFIX))
    if spec["expected_save_version"] != EXPECTED_SAVE_VERSION:
        fail("spec expected_save_version=%r, expected %r. The 1.75 era is the contract this "
             "scenario pins." % (spec["expected_save_version"], EXPECTED_SAVE_VERSION))

    # --- the 1.75 migration: the knob that changes what "correct credits" MEANS ----------------
    migrations = spec["load_migrations"]
    if not isinstance(migrations, list) or len(migrations) != 1:
        fail("spec load_migrations=%r must list exactly the one migration this fixture triggers "
             "(the legacy energy-bomb compensation, PlayerEntity.m:1731-1746). An empty list "
             "would make the census compare RAW saved credits against MIGRATED loaded credits, "
             "which is red on a CORRECT engine; an extra entry would silently adjust a field "
             "nobody measured." % (migrations,))
    migration = migrations[0]
    for key in ("plist", "delta", "log_channel", "log_message", "source", "why"):
        if key not in migration:
            fail("spec load_migrations entry %r does not declare %r; a migration must name the "
                 "field it moves, by how much, the channel and message the engine logs when it "
                 "performs it, and where in the source it lives" % (migration, key))
    if migration["delta"] != ENERGY_BOMB_COMPENSATION_DECICREDITS:
        fail("spec load_migrations delta=%r but PlayerEntity.m:1743 does `credits += %d` "
             "(DECIcredits, i.e. 900 credits). The census adds this delta to the FILE side to "
             "keep the round trip an EXACT equality, so a delta edited alone changes what 'the "
             "loaded credits are correct' means while every comparison still passes."
             % (migration["delta"], ENERGY_BOMB_COMPENSATION_DECICREDITS))
    census_keys = {f["plist"] for f in spec["census"]}
    if migration["plist"] not in census_keys:
        fail("spec migrates %r, which is not one of the census fields %r; a migration applied to "
             "a field nobody compares adjusts nothing and hides nothing - it is decoration"
             % (migration["plist"], sorted(census_keys)))
    if migration["log_channel"] != REQUIRED_UPGRADE_CHANNEL:
        fail("spec load_migrations log_channel=%r, expected %r - the channel PlayerEntity.m:1744 "
             "actually logs on. The harness reads THAT channel out of the run's own log; a wrong "
             "name makes evidence.load_upgrade_messages permanently empty."
             % (migration["log_channel"], REQUIRED_UPGRADE_CHANNEL))
    messages = spec["expected_upgrade_messages"]
    if not isinstance(messages, list) or not messages:
        fail("spec expected_upgrade_messages=%r must be a non-empty list. The migration above "
             "adjusts the census arithmetic; without the engine's OWN record of having performed "
             "it, that adjustment is an unfalsifiable fudge factor and a loader that stopped "
             "migrating would go red on credits with no line naming why." % (messages,))
    if migration["log_message"] not in messages:
        fail("spec expected_upgrade_messages %r does not contain the migration's own log_message "
             "%r; the two describe the same engine line and cannot disagree."
             % (messages, migration["log_message"]))
    if REQUIRED_UPGRADE_CHANNEL not in spec["log_channels"]:
        fail("spec log_channels %r omits %r, so the channel the migration logs on is never "
             "switched on and evidence.load_upgrade_messages reads empty for a reason about the "
             "logging configuration rather than about the loader."
             % (spec["log_channels"], REQUIRED_UPGRADE_CHANNEL))

    # --- mission variables: the FORM of the assertion is the property ---------------------------
    mv = spec["expected_mission_variables"]
    if not isinstance(mv, dict) or not mv:
        fail("spec expected_mission_variables=%r must be a non-empty MAPPING. A DEFAULT NEW GAME "
             "has NO mission variables (PlayerEntity.m:1986-1987), which is precisely what makes "
             "this check unsatisfiable by a run that ignored -load; an empty map asserts nothing."
             % (mv,))
    empty = sorted(k for k, v in mv.items() if v == "")
    if empty:
        fail("spec expected_mission_variables assigns the EMPTY STRING to %r. An ABSENT mission "
             "variable reads identically to an empty one over the JS bridge, so those clauses "
             "would be satisfied by a game that had never heard of the mission - silently. THIS "
             "fixture's values are all non-empty, which is why the whole MAP is asserted here "
             "where scenario 015 could assert only a key SET; downgrading a value to empty "
             "removes the strength without removing the check." % (empty,))
    if spec["thargplans_expected"] is not False:
        fail("spec thargplans_expected=%r. This fixture sits BEFORE the Thargoid Plans mission "
             "starts and mission_thargplans is ABSENT from the save; expecting it present would "
             "make the scenario describe a fixture this is not."
             % (spec["thargplans_expected"],))
    if spec["thargplans_key"] in mv:
        fail("spec expected_mission_variables contains %r, but the fixture does not carry it and "
             "thargplans_expected is false; the two halves of the same claim disagree."
             % (spec["thargplans_key"],))

    # --- the mission's arming clauses -----------------------------------------------------------
    probes = spec["thargplans_precondition_probes"]
    expected_pre = spec["expected_thargplans_preconditions"]
    if not isinstance(probes, dict) or not probes:
        fail("spec thargplans_precondition_probes=%r must be a non-empty mapping of clause name "
             "to the JS that reads it live" % (probes,))
    if sorted(probes) != sorted(expected_pre):
        fail("spec probes %r and expectations %r name different clauses; a probe with no "
             "expectation is never asserted and an expectation with no probe can never be read"
             % (sorted(probes), sorted(expected_pre)))
    if not any(v is False for v in expected_pre.values()):
        fail("spec expected_thargplans_preconditions %r has no FALSE clause. This fixture sits "
             "ONE GALACTIC JUMP SHORT of the mission's galaxy: JS galaxyNumber is [player "
             "currentGalaxyID] (OOJSGlobal.m:190-191), the same 0-based index the plist stores, "
             "so galaxy_is_two is FALSE here. A first draft of this scenario assumed a 1-based JS "
             "field and asserted it true; the live run disproved it. An all-true map means the "
             "measurement was replaced by the assumption again." % (expected_pre,))
    if not any(v is True for v in expected_pre.values()):
        fail("spec expected_thargplans_preconditions %r has no TRUE clause; the fixture would be "
             "asserting nothing positive about the loaded mission state" % (expected_pre,))

    stages = spec["load_progress_stages"]
    if not isinstance(stages, list) or len(stages) != LOAD_PROGRESS_STAGE_COUNT:
        fail("spec pins %r load.progress stage(s); PlayerEntityLoadSave.m:620-811 emits exactly "
             "%d, and the WHOLE ORDERED sequence is what distinguishes a completed load from one "
             "that died partway (which emits a PREFIX)."
             % (len(stages) if isinstance(stages, list) else stages, LOAD_PROGRESS_STAGE_COUNT))
    if len(set(stages)) != len(stages):
        fail("spec load_progress_stages contains duplicates; the sequence is compared in order "
             "and a duplicated stage hides a missing one")

    if REQUIRED_LOG_CHANNEL not in spec["log_channels"]:
        fail("spec log_channels %r omits %r. That channel is OFF by default "
             "(Resources/Config/logcontrol.plist:241) and it carries the engine's OWN proof that "
             "-load was honoured; without it the load_stages defence reads an empty list."
             % (spec["log_channels"], REQUIRED_LOG_CHANNEL))

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
            fail("thargoid_plans_load.py never reads spec[%r]; the knob is decoration - changing "
                 "it would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree)
                 if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("thargoid_plans_load.py has no function %r, so the gate cannot verify that "
                 "spec[%r] is read where it is acted on; the scenario was refactored and this "
                 "gate was not" % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("thargoid_plans_load.py reads spec[%r] somewhere, but NOT inside %s() - the "
                 "function that acts on it. A knob read only to be copied into the evidence block "
                 "is still decoration: the dump would report the spec's value while the behaviour "
                 "ran on a literal, and a substring-only gate would stay green."
                 % (knob, func_name))


def check_isolation(source):
    console_path = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py")
    if not os.path.isfile(console_path):
        refuse("no console.py at %s" % console_path)
    with open(console_path, "r", encoding="utf-8") as handle:
        console_src = handle.read()
    if "OO_RANDOM_SEED" not in console_src:
        fail("console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game")
    if "load_save=save" not in source:
        fail("thargoid_plans_load.py does not pass load_save= to DebugConsole; the game would "
             "start a FRESH COMMANDER and every check about 'the loaded save' would be measuring "
             "a default game (console.py:121-122 turns it into the -load argument)")
    if "seed=seed" not in source:
        fail("thargoid_plans_load.py does not pass seed= to DebugConsole; the seed never reaches "
             "the game")
    if "reserve_port" not in source:
        fail("thargoid_plans_load.py does not reserve a private console port; on the shared 8563 "
             "a sibling worker's console can capture and quit the game seconds in and the run "
             "still exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("thargoid_plans_load.py does not write a debugConfig.plist; the game DIALS OUT to "
             "the port named there (OODebugSupport.m:67-80), so a port that writes no plist can "
             "never connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/ticks/save this golden was BLESSED with are "
             "unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/thargoid_plans_load.py":
        fail("%s records dump_tool=%r, expected tests/golden/thargoid_plans_load.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "expected_save_version", "thargplans_expected")
                  if k not in knobs]
    if unrecorded:
        fail("provenance scenario_knobs does not record %s; those knobs could be changed in the "
             "spec with nothing going red" % unrecorded)

    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    if drift:
        fail("spec.json disagrees with the knobs this golden was blessed with (%s records "
             "blessed-vs-spec %r). The stored golden no longer corresponds to what the spec would "
             "produce; re-bless deliberately or restore the spec - do NOT edit one side to match."
             % (prov_path, drift))

    # --- the 1.75 contract must be recorded where a reviewer will find it ----------------------
    contract = provenance.get("save_format_contract") or {}
    if contract.get("written_by_version") != EXPECTED_SAVE_VERSION:
        fail("%s records save_format_contract.written_by_version=%r, expected %r; the era this "
             "scenario pins must be stated where the golden is described, not only in the code"
             % (prov_path, contract.get("written_by_version"), EXPECTED_SAVE_VERSION))
    if contract.get("credits_delta_decicredits") != ENERGY_BOMB_COMPENSATION_DECICREDITS:
        fail("%s records save_format_contract.credits_delta_decicredits=%r but the engine adds "
             "%d (PlayerEntity.m:1743). The provenance and the spec must agree about the "
             "migration, or a re-bless could move one and not the other."
             % (prov_path, contract.get("credits_delta_decicredits"),
                ENERGY_BOMB_COMPENSATION_DECICREDITS))
    if contract.get("credits_delta_decicredits") != spec["load_migrations"][0]["delta"]:
        fail("%s records a credits delta of %r while the spec applies %r; the number the golden "
             "was blessed with and the number the harness applies have diverged."
             % (prov_path, contract.get("credits_delta_decicredits"),
                spec["load_migrations"][0]["delta"]))

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

    # --- the frame: BOTH tolerance and liveness asserted, and both measured --------------------
    tolerance = provenance.get("frame_tolerance") or {}
    if tolerance.get("asserted") is not True:
        fail("provenance frame_tolerance.asserted=%r. For THIS scenario the frame-vs-reference "
             "tolerance WAS measurable and IS asserted: the docked scene is static, all 45 "
             "same-scene pairs sit at 0.31x..0.35x the tolerance and a wrong scene at 5.7x, a "
             "separation ratio of 16. (Scenario 015 measured 0.25 on an animated scene and could "
             "assert only liveness - the opposite finding, reached the same way.) Downgrading "
             "this to liveness-only would drop a real property without measuring anything."
             % tolerance.get("asserted"))
    if not tolerance.get("tolerance_source"):
        fail("provenance frame_tolerance records no tolerance_source; a threshold with no stated "
             "derivation is indistinguishable from one tuned until the runs passed")
    measurements = provenance.get("frame_measurements") or {}
    ratio = measurements.get("separation_ratio")
    if not isinstance(ratio, (int, float)) or ratio <= 1:
        fail("provenance frame_measurements.separation_ratio=%r. The tolerance may be asserted "
             "only when the wrong-scene distance exceeds the same-scene noise, i.e. a ratio above "
             "1; at or below it the verdict is a coin toss dressed as a gate." % (ratio,))
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the property a dead run fails (a "
             "run that died before drawing yields an all-black grid) and it is checked against an "
             "ABSOLUTE, so it survives a reference frame that was itself black - which the "
             "tolerance does not." % liveness.get("asserted"))
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
    provenance, knobs, stability, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=%d; loads the %s-era %s; the "
          "legacy energy-bomb migration of %d decicredits is declared, applied to census field %r "
          "and witnessed by the engine's own %r line; %d load.progress stage(s), %d mission "
          "variable(s) asserted BY VALUE (none empty) with %r absent, %d arming clause(s) "
          "(%d measured false), and %d census field(s) pinned. All %d knob(s) pinned, every one "
          "read by thargoid_plans_load.py with %d checked by AST inside the function that acts on "
          "it, and all %d agree with the knobs recorded in %s. Stability: %d run(s), %d dumped / "
          "%d refused / %d errored, %d distinct dump digest. Frame: tolerance ASSERTED "
          "(separation ratio %s) and liveness ASSERTED at floor %.4f."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["expected_save_version"], spec["load_save"],
             spec["load_migrations"][0]["delta"], spec["load_migrations"][0]["plist"],
             spec["expected_upgrade_messages"][0], len(spec["load_progress_stages"]),
             len(spec["expected_mission_variables"]), spec["thargplans_key"],
             len(spec["expected_thargplans_preconditions"]),
             sum(1 for v in spec["expected_thargplans_preconditions"].values() if v is False),
             len(census), len(REQUIRED_KNOBS), len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]),
             (provenance.get("frame_measurements") or {}).get("separation_ratio"), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
