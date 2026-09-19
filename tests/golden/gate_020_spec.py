"""Knob gate for golden 020 (hud-render-modes).

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
  5. the stability sweep accounted for every run, and the frame claims carry their measurements;
  6. THE TOLERANCE IS THIS SCENARIO'S OWN, derived from its own recorded populations by the same
     geometric-mean rule frame_hash uses - the thing `buildable-pending-own-calibration` asks for.

WHY 6 MATTERS MORE HERE THAN ANYWHERE ELSE
==========================================
This is the only scenario in the catalogue whose status is `buildable-pending-own-calibration`,
and the reason is in docs/phases/0-scenarios-18-20.md: the shared tolerance in
tests/golden/calibration.json (0.004377) was measured by bead oo-ae9 against 3-D SCENE changes,
and the same work measured the instrument going BLIND on a small stimulus (a trader at 800 m
scored below the noise floor). A HUD is a modest, mostly-dark fraction of the frame. Whether it
clears the bar was an OPEN QUESTION, and the doc is explicit that "loosening the tolerance to make
it pass is forbidden". So this gate RE-DERIVES the stored tolerance from the stored populations
and fails if the two disagree: a hand-edited constant cannot survive, because the populations it
would have to match are recorded beside it.
"""

import ast
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SCENARIO = "020-hud-render-modes"
SCENARIO_SCRIPT = os.path.join(HERE, "hud_render_modes.py")
EVIDENCE_CHECKER = os.path.join(HERE, "check_hud_render_evidence.py")

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
    "seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save", "in_flight",
    "pose_name", "pose_position", "pose_orientation", "pose_tolerance_m", "hud_modes",
    "primary_mode", "unknown_hud_plist", "within_mode_tolerance", "min_separation_ratio",
    "frame_liveness_floor", "min_png_bytes", "repopulator_handlers",
)

# Read inside the function that ACTS on the knob, verified by AST.
READ_IN_FUNCTION = {
    "system_id": "assert_system",
    "repopulator_handlers": "suppress_repopulator",
    "pose_position": "apply_pose",
    "pose_orientation": "apply_pose",
    "pose_tolerance_m": "apply_pose",
    "unknown_hud_plist": "probe_hud_refusal",
    "hud_modes": "assert_ran",
    "within_mode_tolerance": "assert_ran",
    "min_separation_ratio": "assert_ran",
    "frame_liveness_floor": "assert_ran",
    "min_png_bytes": "assert_ran",
    "primary_mode": "mode_table",
    "seed": "run",
    "ticks": "run",
    "tick_seconds": "run",
    "load_save": "_open_game",
}

POLICY_QUANT_DECIMALS = 3

# Lave, as the rest of the golden suite. The pose and the emptied system are what make the 3-D
# stimulus constant; pointed at another system it is a different scene wearing this one's golden.
EXPECTED_SYSTEM_ID = 7
SAVE_SUFFIX = "Resources/Scenarios/oolite-standard.oolite-save"

# The two stock HUD plists shipped in upstream/oolite/Resources/Config. A mode naming anything
# else is either an OXP HUD (not present in a clean checkout, so the scenario would silently fall
# back) or a typo, and -switchHudTo: fails SILENTLY from JS: OOJSPlayerShip.m:921-932 discards the
# BOOL. So an unresolvable plist name must be caught here, offline, not at run time.
STOCK_HUD_PLISTS = ("hud.plist", "hud-small.plist")
HUD_PLIST_DIR = os.path.join(REPO_ROOT, "upstream", "oolite", "Resources", "Config")

# calibration.json's tolerance, measured by bead oo-ae9 against 3-D SCENE changes. Recorded here
# ONLY so this gate can assert that 020's own number was derived independently rather than copied.
SHARED_3D_TOLERANCE = 0.004377268476873758

# A margin floor under 1.0 would accept populations that merely fail to overlap, which is not a
# separation anyone should bless; and a floor ABOVE what was measured would be a gate nobody can
# pass. Both ends are checked against the recorded measurement.
MIN_ALLOWED_SEPARATION_FLOOR = 1.5

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
        fail("spec system_id=%r, expected %d (Lave). The 3-D stimulus this scenario holds constant "
             "is THAT system's planet and sun from the ref pose; pointed elsewhere it is a "
             "different scene wearing this golden." % (spec["system_id"], EXPECTED_SYSTEM_ID))
    if not str(spec["load_save"]).replace("\\", "/").endswith(SAVE_SUFFIX):
        fail("spec load_save=%r does not end in %s" % (spec["load_save"], SAVE_SUFFIX))
    if spec["in_flight"] is not True:
        fail("spec in_flight=%r. The HUD is drawn over the 3-D view ONLY; while docked the screen "
             "is a station GUI and all three modes render the same picture, so the between-mode "
             "differential this scenario rests on would measure nothing." % spec["in_flight"])

    # --- the pose, which is what holds the 3-D stimulus constant ------------------------------
    for field in ("pose_position", "pose_orientation"):
        value = spec[field]
        want = 3 if field == "pose_position" else 4
        if not isinstance(value, list) or len(value) != want:
            fail("spec %s=%r must be a list of %d numbers" % (field, value, want))
        if not all(isinstance(v, (int, float)) for v in value):
            fail("spec %s=%r contains a non-number" % (field, value))
    if not isinstance(spec["pose_tolerance_m"], (int, float)) or spec["pose_tolerance_m"] <= 0:
        fail("spec pose_tolerance_m=%r must be a positive number; a tolerance of zero or less can "
             "never be satisfied by a float read-back, and the check would be dead code"
             % spec["pose_tolerance_m"])
    if spec["pose_tolerance_m"] > 100:
        fail("spec pose_tolerance_m=%r metres is large enough to absorb a camera move that would "
             "change the frame more than the HUD does, which would make a pose drift look like a "
             "HUD difference." % spec["pose_tolerance_m"])

    # --- the modes: the subject --------------------------------------------------------------
    modes = spec["hud_modes"]
    if not isinstance(modes, list) or len(modes) < 3:
        fail("spec hud_modes=%r must declare at least THREE modes. With two there is a single "
             "between-mode pair, and one pair cannot distinguish 'the modes differ' from 'this "
             "particular pair differs'." % (modes,))
    names = [m.get("mode") for m in modes]
    if len(set(names)) != len(names):
        fail("spec hud_modes has duplicate mode names %r; two modes with one name collapse into "
             "one population and the dump cannot say which frame belongs to which" % names)
    for entry in modes:
        for field in ("mode", "hud", "hidden"):
            if field not in entry:
                fail("spec hud_modes entry %r does not declare %r" % (entry, field))
        if not isinstance(entry["hidden"], bool):
            fail("spec hud_modes entry %r has non-boolean hidden=%r" % (entry, entry["hidden"]))
        if entry["hud"] not in STOCK_HUD_PLISTS:
            fail("spec hud_modes entry %r names HUD plist %r, which is not one of the stock "
                 "plists %r. An OXP HUD is not present in a clean checkout and -switchHudTo: "
                 "fails SILENTLY from JS (OOJSPlayerShip.m:921-932 discards the BOOL), so the "
                 "scenario would render the previous HUD while claiming to render this one."
                 % (entry, entry["hud"], list(STOCK_HUD_PLISTS)))
        plist = os.path.join(HUD_PLIST_DIR, entry["hud"])
        if not os.path.isfile(plist):
            fail("spec hud_modes names %r but there is no file at %s; the mode cannot load"
                 % (entry["hud"], plist))
    visible = [m for m in modes if not m["hidden"]]
    if len({m["hud"] for m in visible}) < 2:
        fail("spec hud_modes declares only %d distinct VISIBLE HUD plist(s) %r. Hiding the HUD is "
             "one kind of change; the scenario's stated purpose is also to compare two DIFFERENT "
             "HUDs, and without two visible plists that half is missing."
             % (len({m["hud"] for m in visible}), sorted({m["hud"] for m in visible})))
    if not any(m["hidden"] for m in modes):
        fail("spec hud_modes declares no hidden mode. The hidden arm is the largest available "
             "stimulus (the whole overlay), and it is the control that distinguishes 'the HUD "
             "changed' from 'the HUD is drawn at all'.")
    if spec["primary_mode"] not in names:
        fail("spec primary_mode=%r is not one of the declared modes %r"
             % (spec["primary_mode"], names))

    bogus = spec["unknown_hud_plist"]
    if not isinstance(bogus, str) or not bogus:
        fail("spec unknown_hud_plist=%r must be a non-empty string" % (bogus,))
    if bogus in STOCK_HUD_PLISTS or os.path.isfile(os.path.join(HUD_PLIST_DIR, bogus)):
        fail("spec unknown_hud_plist=%r RESOLVES to a real HUD. The refusal arm exists to prove "
             "-switchHudTo: REJECTS a name it cannot load (PlayerEntity.m:4537-4542); pointed at "
             "a real plist it asserts the opposite of the engine's contract and would go red on a "
             "correct engine." % bogus)
    if bogus in {m["hud"] for m in modes}:
        fail("spec unknown_hud_plist=%r is also one of the declared modes" % bogus)

    # --- the numbers this scenario had to MEASURE ---------------------------------------------
    tol = spec["within_mode_tolerance"]
    if not isinstance(tol, (int, float)) or tol <= 0:
        fail("spec within_mode_tolerance=%r must be a positive number" % (tol,))
    ratio_floor = spec["min_separation_ratio"]
    if not isinstance(ratio_floor, (int, float)) or ratio_floor < MIN_ALLOWED_SEPARATION_FLOOR:
        fail("spec min_separation_ratio=%r is below %r. A floor at or near 1.0 accepts populations "
             "that merely fail to overlap, which is not a separation anyone should bless - the "
             "next capture's noise crosses it." % (ratio_floor, MIN_ALLOWED_SEPARATION_FLOOR))
    live = spec["frame_liveness_floor"]
    if not isinstance(live, (int, float)) or not 0 < live < 1:
        fail("spec frame_liveness_floor=%r must be a fraction in (0,1); it is a luminance SPREAD "
             "scaled to 0..1" % (live,))
    png_floor = spec["min_png_bytes"]
    if not isinstance(png_floor, int) or png_floor < 10000:
        fail("spec min_png_bytes=%r must be an int of at least 10000. A black frame compresses to "
             "~5 KB, so a floor under that cannot separate a black frame from a real one."
             % (png_floor,))

    handlers = spec["repopulator_handlers"]
    if not isinstance(handlers, list) or not handlers:
        fail("spec repopulator_handlers=%r must be a non-empty list. oolite-populator.js's "
             "_tradeStation ENDS WITH an unconditional `return system.mainStation`, so switching "
             "hasNPCTraffic off does NOT stop it launching traffic; with no handler named, ships "
             "drift into frame and a ship in frame is a real difference between two captures of "
             "the SAME mode." % handlers)
    return names


def check_read_where_it_acts(source):
    for knob in REQUIRED_KNOBS:
        if knob in ("quant_decimals", "pose_name", "in_flight"):
            # quant_decimals is applied by the shared dump policy; pose_name and in_flight are
            # DECLARATIONS checked by this gate rather than values the harness branches on, and
            # saying so here is better than pretending they are read.
            continue
        if 'spec["%s"]' % knob not in source:
            fail("hud_render_modes.py never reads spec[%r]; the knob is decoration - changing it "
                 "would change nothing and no line would go red" % knob)

    tree = ast.parse(source)
    functions = {node.name: node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)}
    for knob, func_name in sorted(READ_IN_FUNCTION.items()):
        func = functions.get(func_name)
        if func is None:
            fail("hud_render_modes.py has no function %r, so the gate cannot verify that spec[%r] "
                 "is read where it is acted on; the scenario was refactored and this gate was not"
                 % (func_name, knob))
        reads = [n for n in ast.walk(func)
                 if isinstance(n, ast.Subscript)
                 and isinstance(n.value, ast.Name) and n.value.id == "spec"
                 and isinstance(n.slice, ast.Constant) and n.slice.value == knob]
        if not reads:
            fail("hud_render_modes.py reads spec[%r] somewhere, but NOT inside %s() - the "
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
        fail("hud_render_modes.py does not pass seed= to DebugConsole; the seed never reaches "
             "the game")
    if "reserve_port" not in source:
        fail("hud_render_modes.py does not reserve a private console port; on the shared 8563 a "
             "sibling worker's console can capture and quit the game seconds in and the run still "
             "exits 0 with no ERROR lines (bead oo-het)")
    if "_write_console_config" not in source:
        fail("hud_render_modes.py does not write a debugConfig.plist; the game DIALS OUT to the "
             "port named there (OODebugSupport.m:67-80), so a port that writes no plist can never "
             "connect (bead oo-gla)")
    for marker in ("LIBGL_ALWAYS_SOFTWARE", "REQUIRED_GL_ENV"):
        if marker not in source and marker not in console_src:
            fail("neither hud_render_modes.py nor console.py mentions %r. This scenario's "
                 "tolerance was MEASURED against Mesa llvmpipe; against another rasteriser its "
                 "noise floor is unknown and the threshold means nothing." % marker)


def check_claims_are_asserted(source, checker_source):
    """The positive clauses must be asserted by BOTH the harness and the offline checker.

    They are what makes this scenario unsatisfiable by a corpse. If either file stops asserting
    one, the scenario quietly degrades into "the process exited 0", which bead oo-het's exit-87
    log with zero ERROR lines already proved worthless.
    """
    for clause in ("hud_refused_unknown_plist", "hud_readback_ok", "distinct_mode_grid_digests",
                   "best_between_mode_distance", "worst_within_mode_distance",
                   "separation_ratio"):
        if clause not in source:
            fail("hud_render_modes.py does not mention %r; without it the scenario asserts less "
                 "than it claims" % clause)
        if clause not in checker_source:
            fail("check_hud_render_evidence.py does not assert %r, so a stored dump missing or "
                 "falsifying it would pass the offline check" % clause)
    if "switchHudTo" not in source or "switchHudTo" not in checker_source:
        fail("the engine call -switchHudTo: is not cited in both the harness and the checker. The "
             "refusal arm's whole justification is that PlayerEntity.m:4537-4542 returns NO "
             "WITHOUT touching the HUD; a clause with no derivation is a number someone deletes.")
    if "GUI_SCREEN_MAIN" not in checker_source:
        fail("check_hud_render_evidence.py does not assert the GUI screen. The HUD is drawn over "
             "the 3-D view only, so on a station screen all three modes render the same picture "
             "and every distance in the dump would be renderer noise.")


def check_no_dump_surgery():
    """The SHARED dump must not have been edited to carry this scenario's blocks.

    dump_state.js is used by every landed golden. Adding a hud block there would move 002-019's
    stored dumps, turning one new scenario into a re-bless of the whole suite (scenario 019's
    finding, stated in its LANDING.md). This scenario adds its blocks to its OWN state, as 015
    and 019 do.
    """
    for name in ("dump_state.js", "state_dump.py"):
        shared = os.path.join(HERE, "dump", name)
        if not os.path.isfile(shared):
            refuse("no shared dump component at %s" % shared)
        with open(shared, "r", encoding="utf-8") as handle:
            text = handle.read()
        for marker in ("hudHidden", "hud.plist", "hud_modes"):
            if marker in text:
                fail("the SHARED tests/golden/dump/%s mentions %r. It is used by every landed "
                     "golden, so adding HUD state to it would move 002-019's stored dumps and "
                     "turn this scenario into a re-bless of the whole suite. Scenario 020 adds "
                     "its own 'hud' and 'evidence' blocks to the state IT dumps." % (name, marker))


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
    if provenance.get("dump_tool") != "tests/golden/hud_render_modes.py":
        fail("%s records dump_tool=%r, expected tests/golden/hud_render_modes.py"
             % (prov_path, provenance.get("dump_tool")))
    if provenance.get("evidence_checker") != "tests/golden/check_hud_render_evidence.py":
        fail("%s records evidence_checker=%r, expected "
             "tests/golden/check_hud_render_evidence.py"
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
    dumped = stability.get("dumps_written")
    refused = stability.get("refused")
    errored = stability.get("errored")
    if not all(isinstance(v, int) for v in (dumped, refused, errored)):
        fail("provenance stability must record integer dumps_written/refused/errored, got %r/%r/%r"
             % (dumped, refused, errored))
    if dumped + refused != runs:
        fail("provenance stability accounts for %d dumped + %d refused out of %d run(s); every "
             "run's outcome must be recorded regardless of exit code, and a REFUSAL (the harness "
             "declining to dump) is not a DIFFERENCE - collapsing the two is how a stability "
             "claim goes dishonest (bead oo-jor)." % (dumped, refused, runs))
    if errored != 0:
        fail("provenance records %d errored run(s); an errored run has no verdict and cannot "
             "support a stability claim" % errored)
    if dumped < STABILITY_RUNS_REQUIRED:
        fail("only %d of %d run(s) produced a dump; this scenario's stability claim is that EVERY "
             "run separated the modes, and a sweep with a hole cannot make it" % (dumped, runs))
    per_run = stability.get("per_run") or []
    if len(per_run) != runs:
        fail("provenance records %d per-run entries for %d run(s); a sweep that does not report "
             "every run's outcome can hide the ones that disagreed" % (len(per_run), runs))

    # THE DUMP DIGEST IS A FACT HERE, NOT A PREDICATE - and that is a DIFFERENCE from 019.
    # This dump carries MEASURED FLOAT DISTANCES between rendered frames, and llvmpipe is not
    # bit-reproducible, so demanding one digest across ten runs would be demanding the renderer be
    # deterministic to the last bit, which calibration.json already measured it is not
    # (exact_match_rate 0.0). What IS demanded is that the separation held on every run.
    digests = stability.get("distinct_dump_digests")
    if not isinstance(digests, list) or not digests:
        fail("provenance stability records no distinct_dump_digests; the sweep's dumps must be "
             "accounted for even when they legitimately differ")
    sep = stability.get("separation_per_run") or {}
    for field in ("best_between_min", "worst_within_max", "separation_ratio_min"):
        if field not in sep:
            fail("provenance stability.separation_per_run does not record %r. For THIS scenario "
                 "the per-run separation IS the stability claim (the dump digests legitimately "
                 "differ because they carry renderer floats), so a sweep that does not report it "
                 "has made no claim at all." % field)
    if sep["worst_within_max"] >= sep["best_between_min"]:
        fail("across the sweep the worst within-mode distance %r is not below the best "
             "between-mode distance %r: the populations OVERLAP over the sweep even if they "
             "separated on individual runs." % (sep["worst_within_max"], sep["best_between_min"]))
    if sep["separation_ratio_min"] < float(spec["min_separation_ratio"]):
        fail("the weakest run of the sweep separated by only %rx, under the spec's floor of %rx"
             % (sep["separation_ratio_min"], spec["min_separation_ratio"]))

    # --- THE OWN-CALIBRATION, re-derived rather than trusted ---------------------------------
    cal = provenance.get("calibration") or {}
    for field in ("within_mode_distances", "between_mode_distances", "captures_total",
                  "repeats_per_mode", "per_process", "tolerance", "separated"):
        if field not in cal:
            fail("provenance.calibration does not record %r. This is the ONLY scenario whose "
                 "catalogue status is buildable-pending-own-calibration: the tolerance must be "
                 "MEASURED here and the measurement stored, or the constant is inherited from a "
                 "3-D-scene calibration that says nothing about a HUD overlay." % field)
    if cal["separated"] is not True:
        fail("provenance.calibration records separated=%r. Overlapping populations mean no "
             "threshold exists on this renderer, and the correct response is the finding, not a "
             "looser number (docs/phases/0-scenarios-18-20.md)." % cal["separated"])
    if cal["per_process"] is not True:
        fail("provenance.calibration records per_process=%r. A within-mode floor measured inside "
             "ONE process misses process start, frame timing and the game clock at the moment of "
             "capture - every source of variation the real gate faces between two stability runs "
             "- and a floor measured by hashing one PNG twice is zero." % cal["per_process"])
    within = cal["within_mode_distances"]
    between = cal["between_mode_distances"]
    if not within or not between:
        fail("provenance.calibration stores an empty population (%d within, %d between); a "
             "tolerance with no measurement behind it is a number someone can move"
             % (len(within), len(between)))
    if len(within) < 3 or len(between) < 3:
        fail("provenance.calibration stores %d within-mode and %d between-mode distance(s). Two "
             "points cannot show whether the floor is a constant or a distribution, and a "
             "tolerance derived from one pair is a coincidence." % (len(within), len(between)))
    floor = max(within)
    signal = min(between)
    if floor >= signal:
        fail("provenance.calibration's populations OVERLAP: worst within-mode %.9f is not below "
             "best between-mode %.9f" % (floor, signal))
    derived = (floor * signal) ** 0.5
    if abs(derived - cal["tolerance"]) > 1e-12:
        fail("provenance.calibration records tolerance %.12f but the geometric mean of its own "
             "populations (worst within %.9f, best between %.9f) is %.12f. The stored constant "
             "was not derived from the stored measurements - which is exactly what a hand-edited "
             "threshold looks like." % (cal["tolerance"], floor, signal, derived))
    if abs(float(spec["within_mode_tolerance"]) - derived) > 1e-12:
        fail("spec within_mode_tolerance=%.12f does not equal the tolerance derived from the "
             "recorded calibration populations (%.12f). Someone moved the constant without "
             "re-measuring." % (float(spec["within_mode_tolerance"]), derived))
    if abs(float(spec["within_mode_tolerance"]) - SHARED_3D_TOLERANCE) < 1e-12:
        fail("spec within_mode_tolerance equals the SHARED 3-D calibration constant %.12f. This "
             "scenario's status is buildable-pending-own-calibration precisely because that "
             "number was measured against scene changes and says nothing about a HUD overlay; "
             "copying it is the thing the catalogue forbids." % SHARED_3D_TOLERANCE)
    measured_ratio = signal / floor
    if measured_ratio < float(spec["min_separation_ratio"]):
        fail("the calibration measured a %.2fx separation, under the spec's own floor of %.2fx - "
             "the spec asks for more margin than the measurement supports"
             % (measured_ratio, float(spec["min_separation_ratio"])))

    # --- the frame claims ---------------------------------------------------------------------
    liveness = provenance.get("frame_liveness") or {}
    if liveness.get("asserted") is not True:
        fail("provenance frame_liveness.asserted=%r; liveness is the property a dead run fails (a "
             "run that died before drawing yields a near-uniform grid). Dropping it leaves the "
             "frame artifact unpinned." % liveness.get("asserted"))
    live_floor = liveness.get("floor")
    if not isinstance(live_floor, (int, float)) or live_floor <= 0:
        fail("provenance frame_liveness.floor=%r must be a positive number" % live_floor)
    if live_floor != spec["frame_liveness_floor"]:
        fail("provenance frame_liveness.floor=%r disagrees with spec frame_liveness_floor=%r"
             % (live_floor, spec["frame_liveness_floor"]))
    if not (liveness.get("margin") or {}).get("reading"):
        fail("provenance frame_liveness records no margin reading; a floor with no measurement "
             "beside it is a number someone can lower until every frame passes")

    tolerance = provenance.get("frame_tolerance") or {}
    if tolerance.get("asserted") is not True:
        fail("provenance frame_tolerance.asserted=%r. For THIS scenario the tolerance is the "
             "whole point: the HUD modes ARE the subject, and a scenario that measured a "
             "tolerance and declined to assert it (as 018 correctly did, because staged "
             "expansions have no visual consequence) would be asserting nothing about HUD "
             "rendering at all." % tolerance.get("asserted"))
    if tolerance.get("value") != spec["within_mode_tolerance"]:
        fail("provenance frame_tolerance.value=%r disagrees with spec within_mode_tolerance=%r"
             % (tolerance.get("value"), spec["within_mode_tolerance"]))
    if tolerance.get("source") != "this scenario's own calibration":
        fail("provenance frame_tolerance.source=%r; it must say the tolerance came from THIS "
             "scenario's own calibration, because that claim is the catalogue's "
             "buildable-pending-own-calibration requirement" % tolerance.get("source"))

    frames = provenance.get("frame_digests") or {}
    if frames.get("asserted") is not False:
        fail("provenance frame_digests.asserted=%r must be FALSE. Ten sweep runs of this scenario "
             "produced ten DISTINCT grid digests, so a digest predicate would flake on renderer "
             "noise; the digests are recorded FOR AUDIT and the comparison is by DISTANCE (bead "
             "oo-gxp's asymmetry)." % frames.get("asserted"))

    artifacts = provenance.get("artifacts") or {}
    for name in ("state.json", "frame.grid"):
        if name not in artifacts or not artifacts[name].get("sha256"):
            fail("%s records no artifacts.%s digest. Without a witness OUTSIDE the file being "
                 "defended, editing the golden moves BOTH sides of every self-comparison and no "
                 "line can see it (beads oo-3ya, oo-gxp)." % (prov_path, name))
    for entry in spec["hud_modes"]:
        name = "frame-%s.grid" % entry["mode"]
        if name not in artifacts:
            fail("%s records no digest for %s. The per-mode grids are what make the separation "
                 "claim re-derivable from pixels rather than from the dump's own numbers, and "
                 "they are the only witness a doctored dump cannot satisfy." % (prov_path, name))
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
    return provenance, knobs, stability, cal, live_floor


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

    names = check_pinned(spec)
    check_read_where_it_acts(source)
    check_isolation(source)
    check_claims_are_asserted(source, checker_source)
    check_no_dump_surgery()
    golden_dir = resolve_golden_dir()
    _, knobs, stability, cal, live_floor = check_provenance(spec, golden_dir)

    print("PASS: seed=%s system_id=%s (Lave) ticks=%s tick_seconds=%s quant=%d; loads %s and FLIES "
          "to the %s pose. %d HUD modes pinned %r with %r primary and %r as the unresolvable plist "
          "the engine must REFUSE. All %d knob(s) pinned, every one read by hud_render_modes.py "
          "with %d checked by AST inside the function that acts on it, and all %d agree with the "
          "knobs recorded in %s. The shared dump is untouched. Stability: %d run(s), %d dumped / "
          "%d refused / %d errored, weakest separation %.2fx. Frame: liveness ASSERTED at floor "
          "%.4f, tolerance ASSERTED at %.9f - DERIVED from this scenario's OWN %d-capture "
          "calibration (worst within %.6f, best between %.6f, %.2fx apart), NOT from the shared "
          "3-D constant %.9f; frame digests recorded for audit only."
          % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
             POLICY_QUANT_DECIMALS, spec["load_save"], spec["pose_name"], len(names), names,
             spec["primary_mode"], spec["unknown_hud_plist"], len(REQUIRED_KNOBS),
             len(READ_IN_FUNCTION), len(knobs),
             os.path.relpath(golden_dir, REPO_ROOT).replace(os.sep, "/"),
             stability["runs"], stability["dumps_written"], stability["refused"],
             stability["errored"], stability["separation_per_run"]["separation_ratio_min"],
             live_floor, spec["within_mode_tolerance"], cal["captures_total"],
             max(cal["within_mode_distances"]), min(cal["between_mode_distances"]),
             min(cal["between_mode_distances"]) / max(cal["within_mode_distances"]),
             SHARED_3D_TOLERANCE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
