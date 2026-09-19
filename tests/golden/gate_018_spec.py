"""Gate: scenario 018's determinism knobs are PINNED, READ WHERE THEY ACT, and AGREE WITH PROVENANCE.

Written the way `tests/golden/gate_015_spec.py` is written, for the same measured reasons: bead
oo-3ya's equivalent check was a multi-kilobyte `python -c` line whose quoting hid a survivor (a
knob that was PRINTED but never PREDICATED), so the checks live in a readable file and the stored
acceptance line stays short enough to audit.

THE THREE QUESTIONS, ASKED OF EVERY KNOB
----------------------------------------
  1. IS IT PINNED?  spec.json must declare it, with the right type and a value the engine's own
     source supports.
  2. IS IT READ, WHERE IT ACTS?  `expansion_closure.py` must read `spec["<knob>"]` inside the
     FUNCTION that acts on it, checked by AST rather than by substring. A knob read only to be
     copied into the evidence block is still decoration: the dump reports the spec's value while
     the behaviour runs on a literal, and a substring gate stays green (bead oo-3ya measured
     exactly that).
  3. DOES IT MATCH THE GOLDEN?  provenance.json records the knobs the golden was BLESSED with,
     and the spec must equal them. A fresh-run-vs-golden comparison CANNOT catch a changed seed,
     because changing the seed changes BOTH sides. Hardcoding the seed here would be worse: it
     would make a deliberate re-bless illegal. Agreement with provenance makes drift fatal while
     keeping a governed re-bless legal.

THE KNOB THIS SCENARIO GUARDS HARDEST IS `allowed_manifestless_standards_errors`
-------------------------------------------------------------------------------
It is the one number an implementer under pressure would widen. ResourceManager.m:646 emits
`OOStandardsError` once per scan of an `.oxp` with no manifest.plist, and bead oo-kcrw measured
EXACTLY 2 lines per run for five unrelated in-tree fixtures - the identical count across five
fixtures being the tell that it is a fixture property rather than five defects. Scenario 012
measured FOUR when its staging directory happened to be reachable by two roots, and the exact
count is what caught it. So the gate REFUSES any value but 2 and refuses an allow-list whose
message does not name a missing manifest: a loosened count would bless a golden taken with the
expansion loaded twice, and a loosened message would absorb an unrelated complaint.

THE OTHER KNOB WITH TEETH IS `expected_closure`
-----------------------------------------------
It must have at least TWO members. A one-member "closure" has no dependency to withhold, so the
control arm would be staged identically to the closure arm and the differential would compare a
run against itself - the exact shape of bead oo-gxp's D3 survivor, where both sides of a
comparison moved together.

EXIT CODES: 0 every knob is pinned, read where it acts and agrees with provenance; 1 otherwise
(naming the knob and the disagreement); 2 a usage/structural error that prevented a verdict.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "018-expansion-closure-and-manifestless"
SCENARIO_SCRIPT = os.path.join(HERE, "expansion_closure.py")

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
    "primary_identifier", "expected_closure", "manifestless_oxp",
    "allowed_manifestless_standards_errors", "allowed_manifestless_standards_error_signatures",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "system_id": "assert_system",
    "primary_identifier": "resolve_closure",
    "manifestless_oxp": "manifestless_source",
    "allowed_manifestless_standards_errors": "assert_ran",
    "allowed_manifestless_standards_error_signatures": "assert_ran",
    "seed": "launch_arm",
    "ticks": "launch_arm",
    "tick_seconds": "launch_arm",
    "load_save": "launch_arm",
}

POLICY_QUANT_DECIMALS = 3

#: ResourceManager.m:646 emits OOStandardsError once per scan of a manifest-less .oxp; oo-kcrw
#: measured exactly this many lines per run, identically, for five unrelated in-tree fixtures.
MEASURED_NOMANIF_STANDARDS_ERRORS = 2

#: The scenario stays DOCKED and takes no flight, so the tick budget is small by design; but it
#: must still be positive, or the run loop never steps and tick_budget_met is vacuously true.
MIN_TICKS = 1

STABILITY_RUNS_REQUIRED = 10

#: The save this scenario loads. Any other file makes it a different scenario wearing this golden.
SAVE_SUFFIX = "Resources/Scenarios/oolite-standard.oolite-save"


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
    if not isinstance(spec["ticks"], int) or spec["ticks"] < MIN_TICKS:
        fail("spec ticks=%r, must be an int >= %d; at zero the run loop never steps and "
             "tick_budget_met is vacuously true" % (spec["ticks"], MIN_TICKS))
    if not isinstance(spec["tick_seconds"], (int, float)) or spec["tick_seconds"] <= 0:
        fail("spec tick_seconds=%r, must be a positive number" % spec["tick_seconds"])
    if not isinstance(spec["seed"], int):
        fail("spec seed=%r, must be an int" % spec["seed"])
    if not isinstance(spec["system_id"], int):
        fail("spec system_id=%r, must be an int" % spec["system_id"])

    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s; pointed at any other file this is a different "
             "scenario wearing this one's golden." % (spec["load_save"], SAVE_SUFFIX))

    closure = spec["expected_closure"]
    if not isinstance(closure, list) or len(closure) < 2:
        fail("spec expected_closure=%r must list at least TWO identifiers. With one member there "
             "is no DEPENDENCY to withhold, so the control arm would be staged identically to the "
             "closure arm and the differential would compare a run against itself - both sides "
             "moving together is exactly the shape that survives every comparison (bead oo-gxp)."
             % (closure,))
    if closure[0] != spec["primary_identifier"]:
        fail("spec expected_closure %r does not begin with primary_identifier %r; the closure walk "
             "returns the root FIRST (tools/oxp_deps.py::closure), so a mismatch means the two "
             "knobs were edited apart" % (closure, spec["primary_identifier"]))
    if len(set(closure)) != len(closure):
        fail("spec expected_closure %r contains duplicates; staging one identifier twice makes "
             "the game find it at two paths and doubles its diagnostics" % (closure,))

    manifestless = str(spec["manifestless_oxp"]).replace("\\", "/")
    if not manifestless.endswith(".oxp"):
        fail("spec manifestless_oxp=%r must name an .oxp DIRECTORY, not an .oxz. "
             "ResourceManager.m:634-664 branches on the EXTENSION: a manifest-less .oxz is logged "
             "on oxp.noManifest and RETURNS at :640 (never loaded), while a manifest-less .oxp "
             "emits OOStandardsError at :646 and, in relaxed mode, falls through to :654 where a "
             "manifest is SYNTHESISED and the path IS added. Pointing this knob at an .oxz "
             "silently converts the arm from 'loads and complains' to 'does not load at all'."
             % spec["manifestless_oxp"])
    src = os.path.join(REPO_ROOT, *manifestless.split("/"))
    if not os.path.isdir(src):
        fail("spec manifestless_oxp=%r does not exist at %s; a run staging nothing would emit no "
             "standards error at all, which is indistinguishable from the standards channel "
             "having died" % (spec["manifestless_oxp"], src))
    if os.path.isfile(os.path.join(src, "manifest.plist")):
        fail("%s HAS a manifest.plist, so it is not a manifest-less fixture and this scenario's "
             "NOMANIF arm would assert a count of standards errors that the engine has no reason "
             "to emit" % src)

    allowed = spec["allowed_manifestless_standards_errors"]
    if allowed != MEASURED_NOMANIF_STANDARDS_ERRORS:
        fail("spec allowed_manifestless_standards_errors=%r, but %d is the MEASURED count "
             "(ResourceManager.m:646 emits OOStandardsError once per scan of a manifest-less "
             ".oxp; bead oo-kcrw measured exactly %d per run for five unrelated in-tree fixtures, "
             "and scenario 012 measured 4 when its staging directory was reachable by two roots). "
             "Widening this number is how a golden gets blessed with the expansion loaded twice."
             % (allowed, MEASURED_NOMANIF_STANDARDS_ERRORS,
                MEASURED_NOMANIF_STANDARDS_ERRORS))

    sigs = spec["allowed_manifestless_standards_error_signatures"]
    if not isinstance(sigs, list) or not sigs:
        fail("spec allowed_manifestless_standards_error_signatures=%r must be a non-empty list; "
             "an empty allow-list makes the count assertion unattributable - any two complaints "
             "would satisfy it" % (sigs,))
    for sig in sigs:
        if "manifest.plist" not in sig:
            fail("spec allowed_manifestless_standards_error_signatures carries %r, which does not "
                 "name manifest.plist. The allow-list exists to say WHICH complaint is tolerated; "
                 "a message that is not the missing-manifest one turns the allowance into a "
                 "silencer for whatever error happens to appear." % sig)
        if os.path.basename(manifestless) not in sig:
            fail("spec allow-list entry %r does not name the fixture %r; a complaint about some "
                 "OTHER expansion would then be absorbed into this fixture's allowance"
                 % (sig, os.path.basename(manifestless)))
    return closure


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob in ("quant_decimals", "expected_closure"):
            # quant_decimals is applied by the shared dump policy; expected_closure is the BLESSED
            # record compared against a FRESH walk in provenance/evidence, deliberately not read
            # by the harness (reading it would let a stale spec drive the staging).
            continue
        if 'spec["%s"]' % knob not in source:
            fail("expansion_closure.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("expansion_closure.py has no function %r, so the gate cannot verify that spec[%r] "
                 "is read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("expansion_closure.py reads spec[%r] somewhere, but NOT inside %s() - the "
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
    if "seed=int(spec[\"seed\"])" not in source:
        fail("expansion_closure.py does not pass the spec's seed to DebugConsole; the seed never "
             "reaches the game")
    if "reserve_port" not in source:
        fail("expansion_closure.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("expansion_closure.py does not write a debugConfig.plist; the game DIALS OUT to the "
             "port named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")
    if "oxp-stage" not in source:
        fail("expansion_closure.py does not stage into a directory named 'oxp-stage'. The game "
             "also searches <app dir>/../AddOns and the staged app lives at <artifact>/app, so a "
             "staging directory named <artifact>/addons IS <artifact>/../AddOns on a "
             "case-insensitive filesystem: every expansion is then found at TWO roots and the "
             "standards-error count doubles (scenario 012 measured 4 instead of 2).")
    if "suppress_populators" not in source:
        fail("expansion_closure.py does not suppress the system populator; it keeps adding traffic "
             "mid-run and every ship it adds consumes RANROT draws, so a fixed seed pins the "
             "sequence but not how far a wall-clock-timed run has advanced through it (oo-jor)")


def check_provenance(spec, golden_dir):
    prov_path = os.path.join(golden_dir, "provenance.json")
    with open(prov_path, "r", encoding="utf-8") as handle:
        provenance = json.load(handle)

    knobs = provenance.get("scenario_knobs")
    if not knobs:
        fail("%s records no scenario_knobs; the seed/ticks/closure this golden was BLESSED with "
             "are unrecorded, so nothing can detect the spec drifting away from them" % prov_path)
    if provenance.get("quant_decimals") != POLICY_QUANT_DECIMALS:
        fail("%s records quant_decimals=%r but the policy is %d"
             % (prov_path, provenance.get("quant_decimals"), POLICY_QUANT_DECIMALS))
    if provenance.get("dump_tool") != "tests/golden/expansion_closure.py":
        fail("%s records dump_tool=%r, expected tests/golden/expansion_closure.py"
             % (prov_path, provenance.get("dump_tool")))

    unrecorded = [k for k in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals",
                              "load_save", "primary_identifier", "expected_closure",
                              "manifestless_oxp", "allowed_manifestless_standards_errors")
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
    if dumped + refused != runs:
        fail("provenance stability accounts for %d dumped + %d refused out of %d run(s); every "
             "run's outcome must be recorded regardless of exit code, and a REFUSAL (the harness "
             "declining to dump) is not a DIFFERENCE - collapsing the two is how a stability claim "
             "goes dishonest (bead oo-jor, golden_diff's rc=2-vs-rc=1)." % (dumped, refused, runs))
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

    # --- the frame: liveness asserted, byte-digest deliberately NOT ---------------------------
    if provenance.get("frame_digest_asserted") is not False:
        fail("provenance frame_digest_asserted=%r must be false - llvmpipe is NOT bit-reproducible "
             "(this scenario's sweep produced %s distinct frame digests over ONE dump digest), so "
             "byte-gating the frame would flake forever. Deterministic artifacts get a digest; "
             "renderer output gets a measured floor. The asymmetry is the point."
             % (provenance.get("frame_digest_asserted"),
                stability.get("distinct_frame_grid_digests")))
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the one frame property the "
             "measurements DO support and the one a dead run fails (a run that died before "
             "drawing yields an all-black grid at distance 0). Dropping it leaves the frame "
             "artifact entirely unpinned." % liveness.get("asserted"))
    floor = liveness.get("floor")
    if not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % floor)
    margin = liveness.get("margin") or {}
    for key in ("blessed_frame_vs_black", "max_same_scene_noise"):
        if not isinstance(margin.get(key), (int, float)):
            fail("provenance frame_liveness.margin does not record a numeric %r; a floor with no "
                 "measurement behind it cannot be audited and cannot be defended against being "
                 "lowered" % key)
    if margin["max_same_scene_noise"] >= floor:
        fail("provenance records same-scene frame noise %r at or above the liveness floor %r; the "
             "floor would then reject a real frame on renderer noise alone"
             % (margin["max_same_scene_noise"], floor))
    if margin["blessed_frame_vs_black"] <= floor:
        fail("provenance records the blessed frame at distance %r from black, at or below the "
             "floor %r; the blessed artifact would fail its own liveness check"
             % (margin["blessed_frame_vs_black"], floor))

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

    closure = check_pinned(spec)
    check_read_where_it_acts(source)
    check_isolation(source)
    golden_dir = resolve_golden_dir()
    _, knobs, stability, liveness_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=%d; loads %s; primary %s "
          "with a %d-member closure %r; manifest-less fixture %s pinned at EXACTLY %d standards "
          "error(s) with a %d-entry allow-list naming it. All %d knob(s) pinned, every one read "
          "by expansion_closure.py with %d checked by AST inside the function that acts on it, "
          "and all %d agree with the knobs recorded in %s. Stability: %d run(s), %d dumped / %d "
          "refused / %d errored, %d distinct dump digest. Frame: liveness ASSERTED at floor %.4f, "
          "byte-digest deliberately NOT asserted."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], spec["primary_identifier"],
             len(closure), closure, os.path.basename(spec["manifestless_oxp"]),
             spec["allowed_manifestless_standards_errors"],
             len(spec["allowed_manifestless_standards_error_signatures"]),
             len(REQUIRED_KNOBS), len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], len(stability["distinct_dump_digests"]), liveness_floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
