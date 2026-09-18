"""Gate: scenario 014's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` and `gate_003_spec.py` are written, for the same
measured reason: bead oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting
hid a survivor (a knob that was PRINTED but never PREDICATED), so the checks live in a readable
file and the stored acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `nova_load.py` must read `spec["<knob>"]` inside the FUNCTION
     that acts on it, checked by AST rather than by substring. A knob read only to be copied into
     the evidence block is still decoration: the dump reports the spec's value while the behaviour
     runs on a literal, and a substring gate stays green (bead oo-3ya measured exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOBS THIS SCENARIO GUARDS HARDEST ARE THE SAVE-FORMAT ONES
---------------------------------------------------------------
The bead's story calls this fixture 1.75-era. Measured, it is OLDER: it has no
`written_by_version` key at all (every 1.75 save writes one), it lacks four more keys the 1.75
Trumbles fixture carries, and it carries three legacy-only keys. It is also MIGRATED on load - it
has `has_energy_bomb`, an item Oolite removed, and PlayerEntity.m:1730-1746 compensates it with
900 Cr because all four pylons already hold hardened missiles.

So `expected_written_by_version` must be the EMPTY STRING and the gate says why, because the
obvious "correction" - setting it to "1.75" to match the story, or swapping in a sibling checklist
save - would silently replace an older compatibility contract with a newer one while every
comparison still passed on the day it was re-blessed. `expected_legacy_upgrades` gets its own
predicate for the same reason: it is the ENGINE's own witness of the migration whose arithmetic
the credits census field predicts, and a spec that emptied it would leave the number unwitnessed.

THE MISSION-VARIABLE KNOBS ARE GUARDED IN BOTH DIRECTIONS
----------------------------------------------------------
`mission_novacount_key` must be IN `expected_mission_variable_keys` and
`expected_mission_novacount_value` must be NON-EMPTY, because an empty expected value would be
satisfiable by a game that never loaded the save (an absent mission variable reads as empty - the
trap scenario 015 was built around). `mission_nova_key` must be ABSENT from the expected key set,
because the bead names it and this fixture does not have it: the assertion is of absence, and a
spec that quietly added it would make the scenario claim the opposite of what was measured.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "014-nova"
SCENARIO_SCRIPT = os.path.join(HERE, "nova_load.py")

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
    "seed", "galaxy_number", "ticks", "tick_seconds", "quant_decimals", "load_save",
    "expected_mission_variable_keys", "mission_novacount_key", "mission_nova_key",
    "expected_mission_novacount_value", "expected_written_by_version",
    "save_format_keys_present", "save_format_keys_absent", "expected_legacy_upgrades",
    "log_channels", "load_progress_stages", "repopulator_handlers", "station_ai", "station_ai_reported", "census",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "load_save": "save_path",
    "census": "saved_census",
    "log_channels": "enable_load_logging",
    "galaxy_number": "assert_galaxy",
    "repopulator_handlers": "suppress_repopulator",
    "station_ai": "suppress_station_ai",
    "station_ai_reported": "suppress_station_ai",
    "save_format_keys_present": "save_format_shape",
    "save_format_keys_absent": "save_format_shape",
    "load_progress_stages": "assert_ran",
    "expected_mission_variable_keys": "assert_ran",
    "mission_novacount_key": "assert_ran",
    "mission_nova_key": "assert_ran",
    "expected_mission_novacount_value": "assert_ran",
    "expected_written_by_version": "assert_ran",
    "expected_legacy_upgrades": "assert_ran",
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
# The channel that carries the engine's own witness of the legacy energy-bomb migration.
REQUIRED_UPGRADE_CHANNEL_PREFIX = "load"

SAVE_SUFFIX = "Checklist-files/Missions/Nova.oolite-save"

# Galaxy 3, three galactic hyperdrive jumps from a new commander's galaxy 0.
EXPECTED_GALAXY_NUMBER = 3
# The key whose ABSENCE places this fixture before the 1.75 era.
VERSION_KEY = "written_by_version"
# PlayerEntity.m:1743, in deci-credits.
LEGACY_ENERGY_BOMB_COMPENSATION_DECI = 9000

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
    if spec["galaxy_number"] != EXPECTED_GALAXY_NUMBER:
        fail("spec galaxy_number=%r, expected %d. A DEFAULT NEW GAME IS IN GALAXY 0 and only "
             "three galactic hyperdrive jumps reach galaxy 3, which is what makes this knob "
             "evidence rather than decoration." % (spec["galaxy_number"], EXPECTED_GALAXY_NUMBER))

    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s. This scenario exists to load the checklist "
             "Nova save and pin ITS save-format compatibility contract; pointed at any other "
             "file - including a sibling checklist save - it is a different scenario wearing this "
             "one's golden." % (spec["load_save"], SAVE_SUFFIX))

    # --- the save-format contract, the knob set most likely to be 'corrected' wrongly ----------
    if spec["expected_written_by_version"] != "":
        fail("spec expected_written_by_version=%r, expected the EMPTY STRING. Measured: this "
             "fixture has NO %r key at all, while every Oolite 1.75 save writes one, so it "
             "predates that era. The bead's story calls it '1.75-era'; the file disagrees and the "
             "file is the thing under test. Setting this to '1.75' - or swapping in a sibling "
             "checklist save that really is 1.75 - would replace an OLDER compatibility contract "
             "with a newer one while every comparison still passed."
             % (spec["expected_written_by_version"], VERSION_KEY))
    absent = spec["save_format_keys_absent"]
    if not isinstance(absent, list) or VERSION_KEY not in absent:
        fail("spec save_format_keys_absent=%r must be a list containing %r. That key's ABSENCE is "
             "what dates this fixture, and a set that does not name it asserts nothing about the "
             "format." % (absent, VERSION_KEY))
    present = spec["save_format_keys_present"]
    if not isinstance(present, list) or "has_energy_bomb" not in present:
        fail("spec save_format_keys_present=%r must be a list containing 'has_energy_bomb' - the "
             "REMOVED item whose presence triggers the loader's migration this scenario pins."
             % (present,))
    if set(present) & set(absent):
        fail("spec names %r as both present and absent in the save; the format claim is "
             "self-contradictory and would be satisfied by any file"
             % sorted(set(present) & set(absent)))
    upgrades = spec["expected_legacy_upgrades"]
    if not isinstance(upgrades, list) or not upgrades:
        fail("spec expected_legacy_upgrades=%r must be a non-empty list. It is the ENGINE's own "
             "witness (the [load.upgrade.*] log line) of the legacy energy-bomb migration whose "
             "ARITHMETIC the credits census field predicts independently; emptying it leaves the "
             "number with a single witness and a coincidence would pass." % (upgrades,))
    if not any("900 credits" in str(u) for u in upgrades):
        fail("spec expected_legacy_upgrades=%r names no 900-credit compensation. "
             "PlayerEntity.m:1743 adds %d deci-credits when the legacy energy bomb cannot be "
             "replaced by a Quirium cascade mine, which is this fixture's case (four pylons, four "
             "hardened missiles). A different amount here means a different engine behaviour."
             % (upgrades, LEGACY_ENERGY_BOMB_COMPENSATION_DECI))

    # --- the mission variables the bead names, guarded in BOTH directions ----------------------
    keys = spec["expected_mission_variable_keys"]
    if not isinstance(keys, list) or not keys:
        fail("spec expected_mission_variable_keys=%r must be a non-empty list. A DEFAULT NEW GAME "
             "has NO mission variables (PlayerEntity.m:1986-1987), which is precisely what makes "
             "this check unsatisfiable by a run that ignored -load; an empty list asserts nothing."
             % keys)
    if spec["mission_novacount_key"] not in keys:
        fail("spec expected_mission_variable_keys %r does not contain mission_novacount_key %r. "
             "The bead names mission_novacount as a field the canonical dump must carry."
             % (keys, spec["mission_novacount_key"]))
    value = spec["expected_mission_novacount_value"]
    if not isinstance(value, str) or value == "":
        fail("spec expected_mission_novacount_value=%r must be a NON-EMPTY string. This fixture "
             "holds '3', and a value check is only worth making where a value exists: an empty "
             "expectation reads identically to an absent mission variable and would be satisfied "
             "by a game that had never heard of the mission (scenario 015's measured trap)."
             % (value,))
    if spec["mission_nova_key"] in keys:
        fail("spec expected_mission_variable_keys %r contains mission_nova_key %r, but this "
             "fixture does NOT carry it - measured. The scenario asserts its ABSENCE, and a spec "
             "that added it would make the scenario claim the opposite of what was measured while "
             "still looking like it checked the variable the bead names."
             % (keys, spec["mission_nova_key"]))

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
             "-load was honoured; without it the load_stages defence reads an empty list."
             % (channels, REQUIRED_LOG_CHANNEL))
    if REQUIRED_UPGRADE_CHANNEL_PREFIX not in channels:
        fail("spec log_channels %r omits %r, the parent channel that carries "
             "[load.upgrade.replacedEnergyBomb]. Without it evidence.legacy_upgrades reads an "
             "EMPTY LIST for every run and the migration witness becomes vacuous - an absence "
             "that looks like a pass." % (channels, REQUIRED_UPGRADE_CHANNEL_PREFIX))

    for knob in ("station_ai", "station_ai_reported"):
        if not isinstance(spec[knob], str) or "null" not in spec[knob].lower():
            fail("spec %s=%r does not name a NULL AI" % (knob, spec[knob]))
    ai = spec["station_ai"]
    if not isinstance(ai, str) or "null" not in ai.lower():
        fail("spec station_ai=%r does not name a NULL AI. It exists to silence a station's OWN AI "
             "- the fourth traffic source, which hasNPCTraffic does not gate: a rock hermit's "
             "rockHermitAI calls launchMiner on a 20 s cycle (StationEntity.m:1736-1776). "
             "MEASURED before this knob existed: 10 runs gave FOUR distinct dump digests, three "
             "carrying an extra Mining Transporter entity and two refusing with a ship still "
             "under thrust. Pointing this at a real AI re-opens the race while every comparison "
             "still looks like it checked something." % (ai,))

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
    kinds = {e["plist"]: e["kind"] for e in census}
    if kinds.get("credits") != "float_tenths_legacy_energy_bomb":
        fail("spec census field `credits` declares kind %r, expected "
             "'float_tenths_legacy_energy_bomb'. The loader MIGRATES this save and the credits "
             "value CHANGES by 900 Cr; a plain float_tenths kind would predict the unmigrated "
             "number, the round trip would fail, and the obvious 'fix' is to drop credits from "
             "the census - which would delete the one census field that tests the migration."
             % kinds.get("credits"))
    return census


def _spec_reads(node, knob):
    return [n for n in ast.walk(node)
            if isinstance(n, ast.Subscript)
            and isinstance(n.value, ast.Name) and n.value.id == "spec"
            and isinstance(n.slice, ast.Constant) and n.slice.value == knob]


def _only_inside_raise(func, target):
    """True when `target` occurs only under a Raise statement within `func`."""
    for raise_node in [n for n in ast.walk(func) if isinstance(n, ast.Raise)]:
        for sub in ast.walk(raise_node):
            if sub is target:
                return True
    return False


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob == "quant_decimals":
            continue  # applied by the shared dump policy, not by this scenario's own code
        if 'spec["%s"]' % knob not in source:
            fail("nova_load.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree)
                 if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("nova_load.py has no function %r, so the gate cannot verify that spec[%r] is "
                 "read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = _spec_reads(func, knob)
        if not reads:
            fail("nova_load.py reads spec[%r] somewhere, but NOT inside %s() - the function "
                 "that acts on it. A knob read only to be copied into the evidence block is still "
                 "decoration: the dump would report the spec's value while the behaviour ran on a "
                 "literal, and a substring-only gate would stay green." % (knob, func_name))
        # A READ IS NOT AN ACT. This distinction was found by this gate's OWN mutant: replacing
        # `if evidence[...] != str(spec["expected_written_by_version"]):` with a literal left the
        # knob still read - INSIDE THE FAILURE MESSAGE of the very `raise` that no longer used it
        # - and the gate stayed GREEN. A knob that appears only in the text a failure prints is
        # decoration with extra steps: the message would quote the spec while the predicate ran
        # on the literal. So the read must occur in an ACTING position - a comparison, a call
        # argument, a subscript base, an assignment value - and reads that appear ONLY inside a
        # raise statement do not count.
        acting = [n for n in reads if not _only_inside_raise(func, n)]
        if not acting:
            fail("nova_load.py reads spec[%r] inside %s() but ONLY within a `raise` - i.e. only "
                 "in the text a failure prints, never in a predicate. The knob is decoration: "
                 "changing it would change the wording of an error and nothing else."
                 % (knob, func_name))


def check_isolation(source):
    console_path = os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component", "console.py")
    if not os.path.isfile(console_path):
        refuse("no console.py at %s" % console_path)
    with open(console_path, "r", encoding="utf-8") as handle:
        console_src = handle.read()
    if "OO_RANDOM_SEED" not in console_src:
        fail("console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game")
    if "load_save" not in console_src:
        fail("console.py takes no load_save argument, so nothing can pass the game's -load "
             "argument and this scenario cannot load a save at all")
    if "seed=seed" not in source:
        fail("nova_load.py does not pass seed= to DebugConsole; the seed never reaches the game")
    if "load_save=save" not in source:
        fail("nova_load.py does not pass load_save= to DebugConsole; the game would start a "
             "DEFAULT NEW COMMANDER and every 'the loaded state' check would be about a game that "
             "never loaded anything")
    if "reserve_port" not in source:
        fail("nova_load.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("nova_load.py does not write a debugConfig.plist; the game DIALS OUT to the port "
             "named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/ticks/format expectations this golden was "
             "BLESSED with are unrecorded, so nothing can detect the spec drifting away from them"
             % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/nova_load.py":
        fail("%s records dump_tool=%r, expected tests/golden/nova_load.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "galaxy_number", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "expected_written_by_version",
                              "expected_legacy_upgrades", "expected_mission_novacount_value")
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
    if dumped + refused + errored != runs:
        fail("provenance stability accounts for %d dumped + %d refused + %d errored out of %d "
             "run(s); EVERY run's outcome must be recorded regardless of exit code, and a REFUSAL "
             "(the harness declining to dump an unsettled world) is not a DIFFERENCE - collapsing "
             "the two is how a stability claim goes dishonest (bead oo-jor, golden_diff's "
             "rc=2-vs-rc=1)." % (dumped, refused, errored, runs))
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

    # --- the frame: liveness always asserted; tolerance only with its measurement --------------
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the frame property a dead run "
             "fails (a run that died before drawing yields an all-black grid at distance 0). "
             "Dropping it leaves the frame artifact entirely unpinned." % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)
    tolerance = provenance.get("frame_tolerance") or {}
    if "asserted" not in tolerance:
        fail("provenance frame_tolerance records no `asserted` flag. Whether the frame-vs-"
             "reference tolerance can carry a verdict is a MEASURED property of the scene, not a "
             "preference, and it must be stated either way.")
    if tolerance["asserted"] is False and not tolerance.get("why_not_asserted"):
        fail("provenance frame_tolerance.asserted is false but records no why_not_asserted; a "
             "rejected assertion must carry its measurement, or the next agent re-adds it and "
             "re-derives the flake")
    if tolerance["asserted"] is True and not tolerance.get("measurements"):
        fail("provenance frame_tolerance.asserted is true but records no measurements; an "
             "asserted threshold with no measurement behind it is a number someone liked")

    artifacts = provenance.get("artifacts") or {}
    if "state.json" not in artifacts:
        fail("%s records no artifacts.state.json digest. Without a witness OUTSIDE the file being "
             "defended, editing the golden moves BOTH sides of every self-comparison and no line "
             "can see it (beads oo-3ya, oo-gxp)." % prov_path)
    return provenance, knobs, stability, floor, tolerance


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
    _, knobs, stability, liveness_floor, tolerance = check_provenance(spec, golden_dir)

    print("PASS: seed=%s galaxy=%s ticks=%s tick_seconds=%s quant=%d; loads %s; save-format "
          "contract pinned as PRE-1.75 (written_by_version=%r, %d legacy-only key(s) present, %d "
          "1.75-era key(s) absent, engine-logged migration %r); %d load.progress stage(s), %d "
          "mission variable key(s) with %s=%r asserted present-and-equal and %r asserted ABSENT, "
          "and %d census field(s) pinned. All %d knob(s) pinned, every one read by nova_load.py "
          "with %d checked by AST inside the function that acts on it, and all %d agree with the "
          "knobs recorded in %s. Stability: %d run(s), %d dumped / %d refused / %d errored, %d "
          "distinct dump digest. Frame: liveness ASSERTED at floor %.4f, tolerance asserted=%s."
          % (spec["seed"], spec["galaxy_number"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], spec["expected_written_by_version"],
             len(spec["save_format_keys_present"]), len(spec["save_format_keys_absent"]),
             spec["expected_legacy_upgrades"], len(spec["load_progress_stages"]),
             len(spec["expected_mission_variable_keys"]), spec["mission_novacount_key"],
             spec["expected_mission_novacount_value"], spec["mission_nova_key"], len(census),
             len(REQUIRED_KNOBS), len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor,
             tolerance["asserted"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
