"""Knob gate for golden 019 (equipment-and-station-services).

WHAT THIS GATE IS FOR
=====================
A golden suite rots by a predictable route: someone widens a threshold, or edits a spec value so a
red run goes green, and nothing objects because the spec is the only statement of what the
scenario meant. This file objects. It asserts, offline and with no game:

  1. every knob the scenario needs is PINNED in spec.json;
  2. every pinned knob is actually READ BY THE SCENARIO - and, for the ones that matter, read
     INSIDE THE FUNCTION THAT ACTS ON IT, verified by AST rather than substring, because a knob
     read only to be copied into the evidence block is still decoration: the dump would report the
     spec's value while the behaviour ran on a literal;
  3. the scenario isolates its game (private port, private debugConfig.plist, seed passed through);
  4. the stored provenance AGREES with the spec, so nobody can edit one side alone;
  5. the stability sweep accounted for every run, and the frame claims carry their measurements.

The structural assertions about the scenario's own numbers are derived from the ENGINE, and each
one carries where it comes from. A threshold with no derivation is a number someone can lower.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "019-equipment-and-station-services"
SCENARIO_SCRIPT = os.path.join(HERE, "equipment_services.py")
EVIDENCE_CHECKER = os.path.join(HERE, "check_equipment_evidence.py")

SPEC_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "spec.json"),
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
    "docked_throughout", "award_key", "undamageable_key", "purchase_key",
    "above_tech_level_key", "expected_purchase_price", "expected_station_tech_level",
    "expected_price_factor", "credits_start", "min_registry_entries", "repopulator_handlers",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "system_id": "assert_system",
    "docked_throughout": "assert_docked",
    "repopulator_handlers": "suppress_repopulator",
    "award_key": "award_cycle",
    "undamageable_key": "undamageable_probe",
    "purchase_key": "purchase",
    "credits_start": "purchase",
    "above_tech_level_key": "tech_level_gate",
    "expected_purchase_price": "assert_ran",
    "expected_station_tech_level": "assert_ran",
    "expected_price_factor": "assert_ran",
    "min_registry_entries": "assert_ran",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
    "load_save": "run",
}

POLICY_QUANT_DECIMALS = 3

# Lave. The scenario's prices, tech level and station identity are all Lave-specific; pointed at
# another system it is a different scenario wearing this one's golden.
EXPECTED_SYSTEM_ID = 7
SAVE_SUFFIX = "Resources/Scenarios/oolite-standard.oolite-save"

# OOJSShip.m:2900-2930 defines exactly these three script-visible equipment states.
VALID_STATUSES = ("EQUIPMENT_OK", "EQUIPMENT_DAMAGED", "EQUIPMENT_UNAVAILABLE")

# StationEntity.m:696-697 floors equipmentPriceFactor at 0.5; anything below it cannot be a real
# reading and would silently halve every price the scenario records.
MIN_PRICE_FACTOR = 0.5

# PlayerEntity stores credits as DECI-credits (PlayerEntityScriptMethods.m:52-59: creditBalance is
# 0.1 * credits), so a starting balance with more than one decimal place does not survive the
# round trip and the run would measure a rounding error instead of a price.
CREDIT_DECIMAL_PLACES = 1

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
    if spec["system_id"] != EXPECTED_SYSTEM_ID:
        fail("spec system_id=%r, expected %d (Lave). Every price, tech level and station identity "
             "this scenario pins is Lave-specific; pointed at another system it is a different "
             "scenario wearing this one's golden." % (spec["system_id"], EXPECTED_SYSTEM_ID))
    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s. The scenario's 'the ship starts with NO "
             "equipment' premise - what makes the measured growth attributable - is a property of "
             "THAT save." % (spec["load_save"], SAVE_SUFFIX))

    if spec["docked_throughout"] is not True:
        fail("spec docked_throughout=%r. This scenario reads equipmentPriceFactor and "
             "equivalentTechLevel off player.ship.dockedStation, which is null in flight; "
             "undocked it measures nothing it claims to measure." % spec["docked_throughout"])

    # --- the four keys must be four DIFFERENT keys, each playing its own role -----------------
    keys = {name: spec[name] for name in
            ("award_key", "undamageable_key", "purchase_key", "above_tech_level_key")}
    for name, key in sorted(keys.items()):
        if not isinstance(key, str) or not key.startswith("EQ_"):
            fail("spec %s=%r is not an EQ_ equipment key" % (name, key))
    if spec["award_key"] == spec["undamageable_key"]:
        fail("spec award_key and undamageable_key are both %r. One item cannot be both damageable "
             "and undamageable, so one of the two refusal arms would be asserting nothing."
             % spec["award_key"])
    if spec["purchase_key"] == spec["above_tech_level_key"]:
        fail("spec purchase_key and above_tech_level_key are both %r, so both sides of the "
             "tech-level gate are the same item and the gate cannot straddle the station's level. "
             "One key on one side of a threshold passes against ANY constant, including a station "
             "reporting 0 or NSNotFound." % spec["purchase_key"])

    # --- pricing knobs ------------------------------------------------------------------------
    price = spec["expected_purchase_price"]
    factor = spec["expected_price_factor"]
    if not isinstance(price, (int, float)) or price <= 0:
        fail("spec expected_purchase_price=%r must be a positive number; a free item makes the "
             "credit-balance assertion vacuous - every balance survives a charge of zero" % price)
    if not isinstance(factor, (int, float)) or factor < MIN_PRICE_FACTOR:
        fail("spec expected_price_factor=%r is below %r, which StationEntity.m:696-697 floors it "
             "at; a factor under the engine's own floor cannot be a real reading"
             % (factor, MIN_PRICE_FACTOR))

    start = spec["credits_start"]
    if not isinstance(start, (int, float)):
        fail("spec credits_start=%r must be a number" % start)
    if round(start, CREDIT_DECIMAL_PLACES) != start:
        fail("spec credits_start=%r has more than %d decimal place(s). PlayerEntity stores credits "
             "as deci-credits (PlayerEntityScriptMethods.m:52-59), so the value would not survive "
             "the round trip and the run would measure a rounding error instead of a price."
             % (start, CREDIT_DECIMAL_PLACES))
    charge = price * factor
    if start < charge:
        fail("spec credits_start=%r cannot cover the purchase's %r (price %r x factor %r). The "
             "engine refuses a purchase it cannot afford, so the run would measure a REFUSAL "
             "while claiming to measure a purchase." % (start, charge, price, factor))
    if start == charge:
        fail("spec credits_start=%r exactly equals the charge, leaving a final balance of zero. "
             "Zero is the value an uninitialised balance also has, so the recorded 'credits_after' "
             "would be indistinguishable from a credit system that never ran." % start)

    tech = spec["expected_station_tech_level"]
    if not isinstance(tech, int) or tech < 1:
        fail("spec expected_station_tech_level=%r must be a positive int. A station reporting 0 "
             "or a sentinel is exactly the degenerate reading the two-sided gate exists to catch, "
             "and pinning it here would bless the degeneracy." % tech)

    floor = spec["min_registry_entries"]
    if not isinstance(floor, int) or floor < 2:
        fail("spec min_registry_entries=%r must be an int >= 2; an order pinned over fewer than "
             "two entries has no order to compare and cannot see the reordering item 0.1 names."
             % floor)

    handlers = spec["repopulator_handlers"]
    if not isinstance(handlers, list) or not handlers:
        fail("spec repopulator_handlers=%r must be a non-empty list. oolite-populator.js's "
             "_tradeStation ENDS WITH an unconditional `return system.mainStation`, so switching "
             "hasNPCTraffic off does NOT stop it launching traffic; with no handler named, the "
             "world never goes quiet and the dump is not reproducible." % handlers)
    return keys


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob == "quant_decimals":
            continue  # applied by the shared dump policy, not by this scenario's own code
        if 'spec["%s"]' % knob not in source:
            fail("equipment_services.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("equipment_services.py has no function %r, so the gate cannot verify that "
                 "spec[%r] is read where it is acted on; the scenario was refactored and this "
                 "gate was not" % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("equipment_services.py reads spec[%r] somewhere, but NOT inside %s() - the "
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
    if "seed=seed" not in source:
        fail("equipment_services.py does not pass seed= to DebugConsole; the seed never reaches "
             "the game")
    if "reserve_port" not in source:
        fail("equipment_services.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("equipment_services.py does not write a debugConfig.plist; the game DIALS OUT to the "
             "port named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")


def check_refusals_are_asserted(source, checker_source):
    """The three ENGINE REFUSALS must be asserted by BOTH the harness and the offline checker.

    They are the clauses a permissive stub cannot fake, and they are the reason this scenario is
    not satisfiable by a corpse. If either file stops asserting one, the scenario quietly becomes
    a set of positive writes that any accept-everything model passes.
    """
    for clause in ("duplicate_award_refused", "damage_refused_for_undamageable"):
        if clause not in source:
            fail("equipment_services.py does not mention %r. The engine REFUSALS are what a "
                 "permissive model cannot fake; without them this scenario asserts only that "
                 "writes were accepted." % clause)
        if clause not in checker_source:
            fail("check_equipment_evidence.py does not assert %r, so a stored dump missing the "
                 "refusal would pass the offline check" % clause)
    for status in VALID_STATUSES:
        if status not in source:
            fail("equipment_services.py never names %r; the OK/DAMAGED status machine is this "
                 "scenario's stated purpose" % status)
    if "status_transition" not in checker_source:
        fail("check_equipment_evidence.py does not assert status_transition. BOTH readings are "
             "stored precisely so a COLLAPSED state machine shows up as the same value twice, and "
             "only a checker that compares the PAIR can see that.")
    if "registry_order" not in checker_source:
        fail("check_equipment_evidence.py does not assert registry_order; equipment ordering is "
             "the regression class item 0.1 names and no other artifact in the repository pins it")


def check_no_dump_surgery():
    """The SHARED dump must not have been edited to carry this scenario's blocks.

    dump_state.js is used by every landed golden. Adding an equipment block there would move
    002-017's stored dumps, turning one new scenario into a re-bless of the whole suite. This
    scenario adds its blocks to its OWN state, as 015 does.
    """
    shared = os.path.join(HERE, "dump", "dump_state.js")
    if not os.path.isfile(shared):
        refuse("no shared dump at %s" % shared)
    with open(shared, "r", encoding="utf-8") as handle:
        text = handle.read()
    for marker in ("equipmentKey", "allEquipment", "equipmentStatus"):
        if marker in text:
            fail("the SHARED tests/golden/dump/dump_state.js mentions %r. It is used by every "
                 "landed golden, so adding equipment to it would move 002-017's stored dumps and "
                 "turn this scenario into a re-bless of the whole suite. Scenario 019 adds its "
                 "own 'equipment' and 'evidence' blocks to the state IT dumps." % marker)


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the knobs this golden was BLESSED with are "
             "unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/equipment_services.py":
        fail("%s records dump_tool=%r, expected tests/golden/equipment_services.py"
             % (prov_path, provenance.get("dump_tool")))
    if provenance.get("evidence_checker") != "tests/golden/check_equipment_evidence.py":
        fail("%s records evidence_checker=%r, expected tests/golden/check_equipment_evidence.py"
             % (prov_path, provenance.get("evidence_checker")))

    unrecorded = [k for k in REQUIRED_KNOBS if k not in knobs]
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
        fail("provenance records %d errored run(s); an errored run has no verdict and cannot "
             "support a stability claim" % errored)
    if dumped < 2:
        fail("only %d run(s) produced a dump; with fewer than two there is nothing to compare"
             % dumped)
    per_run = stability.get("per_run") or []
    if len(per_run) != runs:
        fail("provenance records %d per-run entries for %d run(s); a sweep that does not report "
             "every run's outcome can hide the ones that disagreed" % (len(per_run), runs))

    # --- the frame: BOTH claims asserted here, and both must carry their measurements ---------
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the property a dead run fails (a "
             "run that died before drawing yields a near-uniform grid). Dropping it leaves the "
             "frame artifact unpinned." % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)
    if not (liveness.get("margin") or {}).get("reading"):
        fail("provenance frame_liveness records no margin reading; a floor with no measurement "
             "beside it is a number someone can lower until every frame passes")

    tolerance = provenance.get("frame_tolerance") or {}
    if tolerance.get("asserted") is not True:
        fail("provenance frame_tolerance.asserted=%r. For THIS scenario the tolerance WAS "
             "measured and accepted: the status screen renders the equipment list, and frames "
             "with and without equipment separate by ~2.9x the same-scene noise. If a "
             "re-measurement rejects it, record why_not_asserted WITH the measurement, as 015 "
             "does - do not simply flip the flag." % tolerance.get("asserted"))
    measurements = tolerance.get("measurements") or {}
    for field in ("within_bare", "within_loaded", "between_min", "separation_ratio"):
        if field not in measurements:
            fail("provenance frame_tolerance.measurements does not record %r; an asserted "
                 "tolerance with no separation measurement behind it is a threshold nobody can "
                 "check, and the next agent widens it the first time a run flakes" % field)
    if measurements["between_min"] <= max(measurements["within_bare"] +
                                          measurements["within_loaded"]):
        fail("provenance records a best between-group distance of %r against a worst within-group "
             "distance of %r: the two populations OVERLAP, so no threshold separates them and the "
             "asserted tolerance cannot discriminate."
             % (measurements["between_min"],
                max(measurements["within_bare"] + measurements["within_loaded"])))

    artifacts = provenance.get("artifacts") or {}
    for name in ("state.json", "frame.grid"):
        if name not in artifacts or not artifacts[name].get("sha256"):
            fail("%s records no artifacts.%s digest. Without a witness OUTSIDE the file being "
                 "defended, editing the golden moves BOTH sides of every self-comparison and no "
                 "line can see it (beads oo-3ya, oo-gxp)." % (prov_path, name))
    for name, meta in sorted(artifacts.items()):
        path = os.path.join(golden_dir, name)
        if not os.path.isfile(path):
            fail("provenance records a digest for %s but the file is missing from %s"
                 % (name, golden_dir))
        actual = os.path.getsize(path)
        if meta.get("bytes") != actual:
            fail("provenance records %s at %r bytes; the stored file is %d bytes. The witness and "
                 "the artifact disagree, so one of them was edited alone."
                 % (name, meta.get("bytes"), actual))

    rehearsal = provenance.get("landing_rehearsal") or {}
    if rehearsal.get("rehearsed") is not True:
        fail("provenance landing_rehearsal.rehearsed=%r; the bead requires a REHEARSED LANDING.md, "
             "not a written one" % rehearsal.get("rehearsed"))
    return provenance, knobs, stability, floor


def main():
    spec_path = next((c for c in SPEC_CANDIDATES if os.path.isfile(c)), None)
    if spec_path is None:
        refuse("no spec.json in any of %s" % ", ".join(SPEC_CANDIDATES))
    for path in (SCENARIO_SCRIPT, EVIDENCE_CHECKER):
        if not os.path.isfile(path):
            refuse("no file at %s" % path)

    with open(spec_path, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    with open(SCENARIO_SCRIPT, "r", encoding="utf-8") as handle:
        source = handle.read()
    with open(EVIDENCE_CHECKER, "r", encoding="utf-8") as handle:
        checker_source = handle.read()

    keys = check_pinned(spec)
    check_read_where_it_acts(source)
    check_isolation(source)
    check_refusals_are_asserted(source, checker_source)
    check_no_dump_surgery()
    golden_dir = resolve_golden_dir()
    _, knobs, stability, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s (Lave) ticks=%s tick_seconds=%s quant=%d; loads %s docked "
          "throughout. Four distinct keys pinned: award %s, undamageable %s, purchase %s at %g x "
          "factor %g from a %g-credit start, control %s above the station's TL %d. All %d knob(s) "
          "pinned, every one read by equipment_services.py with %d checked by AST inside the "
          "function that acts on it, and all %d agree with the knobs recorded in %s. Both engine "
          "refusals asserted by harness AND offline checker; the shared dump_state.js is "
          "untouched. Stability: %d run(s), %d dumped / %d refused / %d errored, %d distinct dump "
          "digest. Frame: liveness ASSERTED at floor %.4f AND tolerance ASSERTED (measured, "
          "populations separated by %.2fx)."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], keys["award_key"],
             keys["undamageable_key"], keys["purchase_key"], spec["expected_purchase_price"],
             spec["expected_price_factor"], spec["credits_start"], keys["above_tech_level_key"],
             spec["expected_station_tech_level"], len(REQUIRED_KNOBS), len(READ_IN_FUNCTION),
             len(knobs), os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor,
             json.load(open(os.path.join(golden_dir, "provenance.json"), encoding="utf-8"))
             ["frame_tolerance"]["measurements"]["separation_ratio"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
