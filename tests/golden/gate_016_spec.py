"""Gate: scenario 016's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` is written, for the same measured reason: bead
oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting hid a survivor (a
knob that was PRINTED but never PREDICATED), so the checks live in a readable file and the stored
acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `cloaking_load.py` must read `spec["<knob>"]` inside the FUNCTION
     that acts on it, checked by AST rather than by substring. A knob read only to be copied into
     the evidence block is still decoration: the dump reports the spec's value while the behaviour
     runs on a literal, and a substring gate stays green (bead oo-3ya measured exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal.

THE KNOBS THIS SCENARIO GUARDS HARDEST
--------------------------------------
`census_migrations` and `mission_variable_write_exceptions` are the DECLARED-MIGRATION SETS that
make this scenario's contract a CLOSED PAIR. They are the one place a future maintainer could
quietly make a failing run pass, by adding the drifting field to the declared set. Three
predicates defend them: each declared migration must carry a non-empty MECHANISM string (so a
migration cannot be declared without saying what in the engine performs it), the sets must be
SMALL relative to the fields they except (a spec that declared every field would assert nothing),
and the floors must leave the majority of fields genuinely round-tripping.

`ticks` is guarded against the CLOAK. Bead oo-qwk5 measured this ship family flipping scanClass
CLASS_NEUTRAL -> CLASS_NO_DRAW at t=21.6s. A tick budget that reached 21.6s of game time would
put a cloaking transition inside the measured window, so the budget has an upper bound here with
that number named.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "016-cloaking-save"
SCENARIO_SCRIPT = os.path.join(HERE, "cloaking_load.py")

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
# Guarded location FIRST, staged location second, so this file keeps working unchanged after a
# human re-bless moves the artifacts (bead oo-8ij: guardrails.sh refuses CREATE as well as MODIFY
# under goldens/, so this bead cannot land them there itself).
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
    os.path.join(HERE, "pending", SCENARIO),
)

REQUIRED_KNOBS = (
    "seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save", "control_save",
    "save_format_version", "census", "census_migrations", "weapon_ids",
    "expected_mission_variable_keys", "mission_variable_write_exceptions",
    "min_mission_variables_round_tripped", "min_census_fields_round_tripped",
    "expected_equipment_count", "equipment_migrations", "repopulator_handlers",
)

# Read inside the FUNCTION that acts on the knob, verified by AST - not merely somewhere in the file.
READ_IN_FUNCTION = {
    "load_save": "save_path",
    "control_save": "save_path",
    "census": "saved_census",
    "weapon_ids": "_normalise",
    "repopulator_handlers": "suppress_repopulator",
    "save_format_version": "assert_round_trip",
    "expected_mission_variable_keys": "assert_round_trip",
    "mission_variable_write_exceptions": "assert_round_trip",
    "census_migrations": "assert_round_trip",
    "equipment_migrations": "assert_round_trip",
    "expected_equipment_count": "assert_round_trip",
    "min_mission_variables_round_tripped": "assert_round_trip",
    "min_census_fields_round_tripped": "assert_round_trip",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
    "system_id": "run",
}

POLICY_QUANT_DECIMALS = 3

SAVE_SUFFIX = "Checklist-files/Missions/CloakingDevice.oolite-save"

# Bead oo-qwk5, measured: the asp-cloaked family flips scanClass CLASS_NEUTRAL -> CLASS_NO_DRAW at
# t=21.6s of game time when it cloaks. A budget that reaches it puts a cloaking transition inside
# the measured window.
CLOAK_TRANSITION_SECONDS = 21.6

STABILITY_RUNS_REQUIRED = 10

# A declared-migration set that grew to swallow most of the census would assert nothing: the
# closed pair only has teeth while the exceptions are a small minority.
MAX_DECLARED_FRACTION = 0.34


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

    budget = spec["ticks"] * float(spec["tick_seconds"])
    if budget >= CLOAK_TRANSITION_SECONDS:
        fail("spec ticks x tick_seconds = %.3fs of game time, at or beyond the %.1fs at which "
             "bead oo-qwk5 MEASURED this ship family flipping scanClass CLASS_NEUTRAL -> "
             "CLASS_NO_DRAW as it cloaks. A budget that reaches the cloak puts a mid-run "
             "transition inside the measured window, and the dump would carry whichever side of "
             "it the run happened to land on. Re-measure before widening this."
             % (budget, CLOAK_TRANSITION_SECONDS))

    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s. This scenario exists to load the CloakingDevice "
             "checklist save and pin the %s save-format compatibility contract; pointed at any "
             "other file it is a different scenario wearing this one's golden."
             % (spec["load_save"], SAVE_SUFFIX, spec.get("save_format_version")))
    if spec["control_save"] == spec["load_save"]:
        fail("spec control_save is the SAME file as load_save; a wrong-save control whose two arms "
             "are the same file cannot move, and the red-proof it exists to provide is vacuous.")
    if not str(spec["control_save"]).replace("\\", "/").startswith(
            "upstream/oolite-tests/Checklist-files/"):
        fail("spec control_save=%r is not a sibling CHECKLIST save. A fresh game is an easy "
             "control and proves little: the control must differ from the subject only in its "
             "CONTENTS, not in whether a save was loaded at all." % spec["control_save"])
    if str(spec["save_format_version"]) != "1.75":
        fail("spec save_format_version=%r; this scenario IS the 1.75 compatibility contract. If "
             "upstream replaced the fixture that is a FINDING - re-measure, do not edit this."
             % spec["save_format_version"])

    census = spec["census"]
    if not isinstance(census, list) or len(census) < 8:
        fail("spec census=%r must list at least eight fields; the round trip compares the save "
             "FILE (Python plistlib, this process) against the LIVE GAME (JS over the console, "
             "another OS process), and a short census is the empty-state vacuity route wearing a "
             "smaller hat." % census)
    kinds = set()
    for entry in census:
        for key in ("plist", "js", "kind", "why"):
            if key not in entry:
                fail("spec census entry %r does not declare %r; every census field must name the "
                     "plist key, the JS expression that reads the same quantity out of the loaded "
                     "game, how the two are made comparable, and why it is evidence" % (entry, key))
        kinds.add(entry["kind"])
    if len(kinds) < 3:
        fail("spec census exercises only the kind(s) %r. A save FORMAT contract that compares one "
             "type of field is not a format contract: the 1.75 plist carries integers, strings, "
             "floats and legacy weapon IDs, and each is a separate deserialisation path." % kinds)

    # --- the declared-migration sets, the place a failing run could be made to pass -----------
    for name, declared, population, detail_key in (
            ("census_migrations", spec["census_migrations"], census, "mechanism"),
            ("mission_variable_write_exceptions", spec["mission_variable_write_exceptions"],
             spec["expected_mission_variable_keys"], "writer")):
        if not isinstance(declared, dict):
            fail("spec %s=%r must be an object keyed by the field it excepts" % (name, declared))
        if not declared:
            fail("spec %s is EMPTY. This scenario's contract is a CLOSED PAIR - the set of fields "
                 "that differ must equal the declared set - and measurement shows that set is not "
                 "empty. An empty declaration turns the assertion into 'nothing may differ', "
                 "which THIS fixture cannot satisfy, so a green would mean the comparison stopped "
                 "running." % name)
        fraction = len(declared) / float(len(population))
        if fraction > MAX_DECLARED_FRACTION:
            fail("spec %s excepts %d of %d field(s) (%.0f%%), over the %.0f%% ceiling. A declared "
                 "set that grew to swallow the population asserts nothing: the closed pair only "
                 "has teeth while the exceptions are a small minority. Adding a drifting field to "
                 "this set is the one way to make a failing run pass, so it is bounded."
                 % (name, len(declared), len(population), fraction * 100,
                    MAX_DECLARED_FRACTION * 100))
        for key, rule in declared.items():
            if "delta" not in rule:
                fail("spec %s[%r] declares no `delta`; a migration without a pinned magnitude "
                     "accepts any change to that field" % (name, key))
            if not str(rule.get(detail_key) or "").strip():
                fail("spec %s[%r] declares no %r. A migration may not be declared without naming "
                     "WHAT IN THE ENGINE performs it: an unexplained entry here is how a "
                     "regression gets reclassified as intended behaviour." % (name, key, detail_key))

    for key, rule in spec["equipment_migrations"].items():
        if rule.get("disposition") != "REMOVED":
            continue
        if not str(rule.get("compensation_log_substring") or "").strip():
            fail("spec equipment_migrations[%r] declares a REMOVED item with no "
                 "compensation_log_substring. The engine's OWN log line is what turns the credits "
                 "delta into proof of which compensation branch ran; without it the delta is "
                 "arithmetic that happens to add up." % key)

    keys = spec["expected_mission_variable_keys"]
    if not isinstance(keys, list) or not keys:
        fail("spec expected_mission_variable_keys=%r must be a non-empty list. A DEFAULT NEW GAME "
             "has NO mission variables (PlayerEntity.m:1986-1987), which is precisely what makes "
             "this check unsatisfiable by a run that ignored -load; an empty list asserts nothing."
             % keys)
    if "mission_cloakcounter" not in keys:
        fail("spec expected_mission_variable_keys %r omits mission_cloakcounter; the bead names "
             "that field as one the canonical dump must carry." % keys)

    floors = ((("min_census_fields_round_tripped"), len(census)),
              (("min_mission_variables_round_tripped"), len(keys)))
    for knob, total in floors:
        value = spec[knob]
        if not isinstance(value, int) or value < 1:
            fail("spec %s=%r must be a positive int" % (knob, value))
        if value > total:
            fail("spec %s=%d exceeds the %d field(s) available; the floor can never be met and "
                 "the scenario is unrunnable" % (knob, value, total))
        if value < total // 2:
            fail("spec %s=%d is under half of %d. The exact-set clause plus a low floor could be "
                 "satisfied by a fixture reduced to almost nothing." % (knob, value, total))
    return census


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob == "quant_decimals":
            continue  # applied by the shared dump policy, not by this scenario's own code
        if 'spec["%s"]' % knob not in source:
            fail("cloaking_load.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("cloaking_load.py has no function %r, so the gate cannot verify that spec[%r] is "
                 "read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("cloaking_load.py reads spec[%r] somewhere, but NOT inside %s() - the function "
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
    if "load_save=save" not in source:
        fail("cloaking_load.py does not pass load_save= to DebugConsole; the game's own -load "
             "argument is how this scenario's fixture reaches it, and without it the run would "
             "measure a fresh commander while every probe still answered")
    if "seed=seed" not in source:
        fail("cloaking_load.py does not pass seed= to DebugConsole; the seed never reaches the game")
    if "reserve_port" not in source:
        fail("cloaking_load.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("cloaking_load.py does not write a debugConfig.plist; the game DIALS OUT to the port "
             "named there, so a port that writes no plist can never connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/ticks/system this golden was BLESSED with "
             "are unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/cloaking_load.py":
        fail("%s records dump_tool=%r, expected tests/golden/cloaking_load.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "save_format_version", "expected_equipment_count")
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

    # --- the declared migrations must be recorded in provenance TOO --------------------------
    # Otherwise the spec's declared set could be widened with nothing outside it disagreeing, and
    # the closed pair's one soft spot would be unwatched.
    recorded = provenance.get("declared_migrations") or {}
    for name in ("census_migrations", "mission_variable_write_exceptions", "equipment_migrations"):
        got = sorted(recorded.get(name) or [])
        want = sorted(spec[name])
        if got != want:
            fail("provenance declared_migrations.%s records %r but spec.json declares %r. The "
                 "declared set is the ONE place a failing run could be made to pass by widening "
                 "it, so it is witnessed from OUTSIDE the spec; a change must move both files "
                 "deliberately." % (name, got, want))

    # --- the 10-run stability claim, ACCOUNTED FOR RUN BY RUN ---------------------------------
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
        fail("provenance records %d errored run(s); an errored run has no verdict and cannot "
             "support a stability claim" % errored)
    if dumped < 2:
        fail("only %d run(s) produced a dump; with fewer than two there is nothing to compare"
             % dumped)
    per_run = stability.get("per_run") or []
    if len(per_run) != runs:
        fail("provenance records %d per-run entries for %d run(s); a sweep that does not report "
             "every run's outcome can hide the ones that disagreed" % (len(per_run), runs))

    # --- the frame asymmetry ------------------------------------------------------------------
    artifacts = provenance.get("artifacts") or {}
    if "state.json" not in artifacts:
        fail("%s records no artifacts.state.json digest. Without a witness OUTSIDE the file being "
             "defended, editing the golden moves BOTH sides of every self-comparison and no line "
             "can see it (beads oo-3ya, oo-gxp)." % prov_path)
    for key in ("sha256", "bytes"):
        if key not in artifacts["state.json"]:
            fail("%s artifacts.state.json records no %r; a one-quantised-unit edit to the golden "
                 "is invisible without BOTH the digest and the byte count" % (prov_path, key))
    frame = artifacts.get("frame.grid") or {}
    if not str(frame.get("note") or "").strip():
        fail("%s records no note on artifacts['frame.grid'] explaining why its digest is NOT a "
             "gate predicate. llvmpipe is not bit-reproducible; without the written reason the "
             "next agent byte-hashes the frame and the gate starts flaking on renderer noise."
             % prov_path)
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the frame property a dead run "
             "fails (a run that died before drawing yields an all-black grid at distance 0). "
             "Dropping it leaves the frame artifact unpinned." % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)
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

    print("PASS: seed=%s system_id=%s ticks=%s x %ss = %.3fs game time (well under the %.1fs "
          "cloak transition) quant=%d; loads %s against the %s control; %d census field(s) in %d "
          "kind(s) and %d mission variable key(s) pinned, with %d + %d + %d DECLARED migration(s) "
          "each naming its engine mechanism and each witnessed in provenance. All %d knob(s) "
          "pinned, every one read by cloaking_load.py with %d checked by AST inside the function "
          "that acts on it, and all %d agree with the knobs recorded in %s. Stability: %d run(s), "
          "%d dumped / %d refused / %d errored, %d distinct dump digest. Frame: liveness ASSERTED "
          "at floor %.4f; the frame grid is recorded but deliberately NOT byte-gated."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             spec["ticks"] * float(spec["tick_seconds"]), CLOAK_TRANSITION_SECONDS,
             POLICY_QUANT_DECIMALS, os.path.basename(spec["load_save"]),
             os.path.basename(spec["control_save"]), len(census),
             len({e["kind"] for e in census}), len(spec["expected_mission_variable_keys"]),
             len(spec["census_migrations"]), len(spec["mission_variable_write_exceptions"]),
             len(spec["equipment_migrations"]), len(REQUIRED_KNOBS), len(READ_IN_FUNCTION),
             len(knobs), os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
