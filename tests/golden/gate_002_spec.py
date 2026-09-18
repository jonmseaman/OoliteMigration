"""Gate: scenario 002's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` and `gate_003_spec.py` are written, for the same
measured reason: bead oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting
hid a survivor (a knob that was PRINTED but never PREDICATED), so the checks live in a readable
file and the stored acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `witchspace_jump.py` must read `spec["<knob>"]` inside the
     FUNCTION that acts on it, checked by AST rather than by substring. A knob read only to be
     copied into the evidence block is still decoration: the dump reports the spec's value while
     the behaviour runs on a literal, and a substring gate stays green (bead oo-3ya measured
     exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with, and
     the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOBS THIS SCENARIO GUARDS HARDEST
--------------------------------------
`destination_system_id` and `countdown_seconds`, because they are what make the jump a jump.

  * THE DESTINATION MUST DIFFER FROM THE ORIGIN. `witchJumpChecklist:` (PlayerEntity.m:7411-7424)
    refuses a jump to the current system outright with playerJumpFailed("no target"), so a spec
    whose two system ids agreed would describe a scenario that CANNOT jump - and the gate's own
    `system_id_after != system_id_before` predicate would then be unsatisfiable rather than
    falsifiable. It gets its own predicate here.
  * THE COUNTDOWN MUST BE IN THE ENGINE'S LEGAL RANGE. `PlayerShipBeginHyperspaceCountdown`
    (OOJSPlayerShip.m:1580-1586) rejects anything outside 5..60 with a bad-arguments error, so a
    spec outside that range makes every run refuse for a reason about the spec, not the engine.
  * THE PROVENANCE MUST RECORD A FUEL BILL EQUAL TO THE DISTANCE. That is the scenario's
    INDEPENDENT second witness to the jump, and a provenance that dropped it would leave the whole
    claim resting on `system.ID` alone.

THE FRAME IS GUARDED IN THE OPPOSITE DIRECTION
----------------------------------------------
provenance must record `frame_digest_asserted: false` WITH a reason, and `frame_liveness.asserted:
true` with a positive floor. Byte-hashing the frame would make the gate flake on llvmpipe's
non-reproducibility; dropping liveness would leave the frame artifact entirely unpinned. Both
directions are failures, so both are predicated (bead oo-gxp's asymmetry).

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "002-witchspace"
SCENARIO_SCRIPT = os.path.join(HERE, "witchspace_jump.py")

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
    "seed", "origin_system_id", "origin_system_name", "destination_system_id",
    "destination_system_name", "destination_station_name", "countdown_seconds", "ticks",
    "tick_seconds", "quant_decimals", "load_save", "pose", "repopulator_handlers",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "origin_system_id": "assert_origin_system",
    "destination_system_id": "assert_destination_system",
    "destination_system_name": "assert_jumped",
    "destination_station_name": "assert_jumped",
    "countdown_seconds": "jump",
    "repopulator_handlers": "suppress_repopulator",
    "pose": "run",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
    "load_save": "run",
}

POLICY_QUANT_DECIMALS = 3

# OOJSPlayerShip.m:1580-1586 rejects a spin-up time outside this range outright.
COUNTDOWN_MIN_SECONDS = 5
COUNTDOWN_MAX_SECONDS = 60

# The engine's own name for a plain inter-system jump ([player jumpCause], Universe.m:1061).
STANDARD_JUMP_CAUSE = "standard jump"

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

    origin = spec["origin_system_id"]
    destination = spec["destination_system_id"]
    if not all(isinstance(v, int) for v in (origin, destination)):
        fail("spec origin_system_id=%r / destination_system_id=%r must both be ints"
             % (origin, destination))
    if origin == destination:
        fail("spec pins origin_system_id == destination_system_id == %r. witchJumpChecklist: "
             "(PlayerEntity.m:7411-7424) REFUSES a jump to the current system with "
             "playerJumpFailed('no target'), so this scenario could never jump - and its central "
             "predicate (system_id_after != system_id_before) would become UNSATISFIABLE rather "
             "than falsifiable, which is the most expensive kind of green." % origin)
    if not spec["destination_system_name"] or not spec["destination_station_name"]:
        fail("spec destination_system_name=%r / destination_station_name=%r must both be non-empty; "
             "they are the two independent witnesses to WHICH system the run ended in"
             % (spec["destination_system_name"], spec["destination_station_name"]))

    countdown = spec["countdown_seconds"]
    if not isinstance(countdown, int):
        fail("spec countdown_seconds=%r must be an int" % countdown)
    if not COUNTDOWN_MIN_SECONDS <= countdown <= COUNTDOWN_MAX_SECONDS:
        fail("spec countdown_seconds=%r is outside the engine's legal %d..%d range. "
             "PlayerShipBeginHyperspaceCountdown (OOJSPlayerShip.m:1580-1586) rejects anything "
             "else with a bad-arguments error, so every run would refuse for a reason about the "
             "spec rather than about the engine."
             % (countdown, COUNTDOWN_MIN_SECONDS, COUNTDOWN_MAX_SECONDS))

    pose = spec["pose"]
    if not isinstance(pose, dict) or "position" not in pose or "orientation" not in pose:
        fail("spec pose=%r must declare position and orientation. The pose is not cosmetic: "
             "witchJumpChecklist: refuses the jump with playerJumpFailed('blocked') if anything is "
             "near when the countdown expires (PlayerEntity.m:7387-7401), and a countdown begun in "
             "the launch corridor was MEASURED falling back to STATUS_IN_FLIGHT with system.ID "
             "unchanged." % (pose,))

    handlers = spec["repopulator_handlers"]
    if not isinstance(handlers, list) or not handlers:
        fail("spec repopulator_handlers=%r must be a non-empty list. oolite-populator.js's "
             "_tradeStation ends in an unconditional `return system.mainStation`, so switching "
             "hasNPCTraffic off does NOT stop it launching traffic; neutering the handler is the "
             "only suppression that works, and an empty list silently disables it." % handlers)
    return spec


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob in ("quant_decimals", "origin_system_name"):
            # quant_decimals is applied by the shared dump policy; origin_system_name is reported
            # by assert_system's message, not predicated - both are declared exemptions, named.
            continue
        if 'spec["%s"]' % knob not in source:
            fail("witchspace_jump.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("witchspace_jump.py has no function %r, so the gate cannot verify that spec[%r] "
                 "is read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("witchspace_jump.py reads spec[%r] somewhere, but NOT inside %s() - the function "
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
        fail("witchspace_jump.py does not pass seed= to DebugConsole; the seed never reaches the "
             "game")
    if "reserve_port" not in source:
        fail("witchspace_jump.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("witchspace_jump.py does not write a debugConfig.plist; the game DIALS OUT to the "
             "port named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/systems/ticks this golden was BLESSED with "
             "are unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/witchspace_jump.py":
        fail("%s records dump_tool=%r, expected tests/golden/witchspace_jump.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "origin_system_id", "destination_system_id",
                              "destination_station_name", "countdown_seconds", "ticks",
                              "tick_seconds", "quant_decimals", "load_save") if k not in knobs]
    if unrecorded:
        fail("provenance scenario_knobs does not record %s; those knobs could be changed in the "
             "spec with nothing going red" % unrecorded)

    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    if drift:
        fail("spec.json disagrees with the knobs this golden was blessed with (%s records "
             "blessed-vs-spec %r). The stored golden no longer corresponds to what the spec would "
             "produce; re-bless deliberately or restore the spec - do NOT edit one side to match."
             % (prov_path, drift))

    # --- the jump itself, as the provenance recorded it ----------------------------------------
    jump = provenance.get("jump") or {}
    for key in ("cause", "distance_ly_tenths", "fuel_consumed_tenths",
                "witchspace_enter_events", "witchspace_exit_events"):
        if key not in jump:
            fail("provenance `jump` block does not record %r. This scenario's claim is that a "
                 "witchspace jump HAPPENED; a provenance that does not record the engine's own "
                 "account of it leaves that claim resting on nothing a later reader can check."
                 % key)
    if jump["cause"] != STANDARD_JUMP_CAUSE:
        fail("provenance records jump cause %r, not %r. A galactic jump or a misjump reports a "
             "different string and is a DIFFERENT scenario." % (jump["cause"], STANDARD_JUMP_CAUSE))
    if jump["fuel_consumed_tenths"] != jump["distance_ly_tenths"]:
        fail("provenance records %r tenths of fuel billed for a %r-tenth jump. The fuel bill is "
             "this scenario's INDEPENDENT second witness - an engine that changed system.ID "
             "without jumping would not bill it - and the two must agree."
             % (jump["fuel_consumed_tenths"], jump["distance_ly_tenths"]))
    if jump["fuel_consumed_tenths"] < 1:
        fail("provenance records a zero-cost jump (%r tenths); a jump that costs no fuel is not a "
             "jump" % jump["fuel_consumed_tenths"])
    if jump["witchspace_enter_events"] < 1 or jump["witchspace_exit_events"] < 1:
        fail("provenance records %r enter / %r exit witchspace event(s); both are dispatched by "
             "the ENGINE (Universe.m:1061, :1106) and both must be at least 1"
             % (jump["witchspace_enter_events"], jump["witchspace_exit_events"]))

    # --- the 10-run stability claim, accounted for run by run -----------------------------------
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
             "run(s); every run's outcome must be recorded regardless of exit code, and a REFUSAL "
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

    # --- the frame: liveness asserted, byte digest deliberately NOT ----------------------------
    if provenance.get("frame_digest_asserted") is not False:
        fail("provenance frame_digest_asserted=%r. The frame grid must NEVER be byte-compared: "
             "llvmpipe is not bit-reproducible, so a digest predicate would flake on renderer "
             "noise. The dump is hashed byte-wise because it is quantised and deterministic; the "
             "frame is not. The asymmetry is deliberate (bead oo-gxp)."
             % provenance.get("frame_digest_asserted"))
    if not provenance.get("frame_digest_why_not_asserted"):
        fail("provenance records no frame_digest_why_not_asserted; a rejected assertion must carry "
             "its reason, or the next agent re-adds it and re-derives the flake")
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the one frame property a dead run "
             "fails (a run that died before drawing yields an all-black grid at distance 0). "
             "Dropping it leaves the frame artifact entirely unpinned." % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)

    artifacts = provenance.get("artifacts") or {}
    if "state.json" not in artifacts:
        fail("%s records no artifacts.state.json digest. Without a witness OUTSIDE the file being "
             "defended, editing the golden moves BOTH sides of every self-comparison and no line "
             "can see it (beads oo-3ya, oo-gxp)." % prov_path)
    for key in ("sha256", "bytes"):
        if key not in artifacts["state.json"]:
            fail("%s records artifacts.state.json without %r. BOTH are needed: a one-quantised-unit "
                 "edit changes the digest, and recording the byte count as well makes a truncation "
                 "or an append visible even to a reader who cannot hash." % (prov_path, key))
    return provenance, knobs, stability, jump, floor


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
    _, knobs, stability, jump, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s jumps %s (%s) -> %s (%s), docking at %s; countdown %ss (engine legal "
          "range %d..%d); %s ticks x %ss in the destination, quant=%d. All %d knob(s) pinned, every "
          "one read by witchspace_jump.py with %d checked by AST inside the function that acts on "
          "it, and all %d agree with the knobs recorded in %s. Jump: cause %r, %d enter / %d exit "
          "event(s) from the engine, %d tenths of fuel billed for a %d-tenth jump. Stability: %d "
          "run(s), %d dumped / %d refused / %d errored, %d distinct dump digest. Frame: liveness "
          "ASSERTED at floor %.4f, byte digest deliberately NOT asserted."
          % (spec["seed"], spec["origin_system_id"], spec["origin_system_name"],
             spec["destination_system_id"], spec["destination_system_name"],
             spec["destination_station_name"], spec["countdown_seconds"],
             COUNTDOWN_MIN_SECONDS, COUNTDOWN_MAX_SECONDS, spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, len(REQUIRED_KNOBS), len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             jump["cause"], jump["witchspace_enter_events"], jump["witchspace_exit_events"],
             jump["fuel_consumed_tenths"], jump["distance_ly_tenths"],
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
