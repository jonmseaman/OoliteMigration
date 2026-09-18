"""Offline falsifiability tests for scenario 011-ai-overflow (bead oo-dto). No game, no build.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game. That is the only part that can observe
real engine behaviour, and it is also the slowest thing on this box, so it is ONE acceptance line.
Everything that can be falsified without a launch is falsified here, where it costs about a second
and cannot be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration.

TWO MUTANTS PER PROPERTY (bead oo-jor's lesson). For the anti-vacuity properties this gate exists
for, there is a test that corrupts the DATA and a test that weakens the CHECKER - because only the
second catches a gate that validates data with a validator nobody validates. The checker mutants
write a COPY of the checker to a temp dir; the real file is never touched.

NOTHING HERE WRITES TO goldens/ OR TO THE STAGED GOLDEN. The stored dump is READ, copied to a
throwaway temp file, and mutated there.
"""

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "011-ai-overflow"

# The golden and spec live under tests/golden/pending/ until Jon approves the protected-path
# addition (tools/guardrails.sh refuses a new file under goldens/ or tests/golden/scenarios/
# without a line in tools/rebless-approvals.txt, and it does NOT distinguish create from modify).
# Both locations are searched so landing them is a pure `git mv` with no code change. See
# tests/golden/pending/011-ai-overflow/LANDING.md.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

EVIDENCE = os.path.join(HERE, "check_ai_overflow_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "ai_overflow.py")
AI_SOURCE = os.path.join(REPO_ROOT, "upstream", "oolite", "src", "Core", "AI.m")

sys.path.insert(0, HERE)


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s; looked in %s" % (what, candidates))


GOLDEN = _first(GOLDEN_CANDIDATES, "stored golden")
SPEC = _first(SPEC_CANDIDATES, "spec.json")
PROVENANCE = _first(PROVENANCE_CANDIDATES, "provenance.json")


def run(script, *args):
    proc = subprocess.run([sys.executable, script] + list(args), capture_output=True, text=True,
                          cwd=REPO_ROOT)
    return proc.returncode, proc.stdout + proc.stderr


@pytest.fixture()
def golden():
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def spec():
    with open(SPEC, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def scratch():
    path = tempfile.mkdtemp(prefix="oo_dto_test_")
    yield path
    shutil.rmtree(path, ignore_errors=True)


def write(scratch, name, data):
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    return path


def mutated_checker(scratch, old, new, name="checker_mutant.py"):
    """A COPY of the evidence checker with one defence weakened. The real file is untouched."""
    with open(EVIDENCE, "r", encoding="utf-8") as handle:
        src = handle.read()
    assert old in src, "the checker no longer contains %r; this mutation is stale" % old
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src.replace(old, new, 1))
    return path


def one_field(golden, **changes):
    """A copy of the golden differing in exactly the named evidence fields."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], **changes)
    return bad


# --- the stored golden is itself real -----------------------------------------------------

def test_the_stored_golden_proves_the_overflow_happened():
    """The green direction. If this fails, every other test here is measuring a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "AI overflow REACHED and HANDLED" in out, out


def test_the_stored_golden_is_not_a_dead_run(golden, spec):
    ev = golden["evidence"]
    assert ev["oxp_staged"] is True, ev
    assert sorted(ev["oxp_ship_keys"]) == sorted(spec["expected_ship_keys"]), ev
    assert ev["oxp_ship_ai_type"] == spec["expected_ship_ai_type"], ev
    assert ev["ai_stack_overflow_events"] >= 1, ev
    assert ev["overflow_handled"] is True, ev
    assert ev["ticks"] >= 1 and ev["tick_budget_met"] is True, ev


def test_the_stored_golden_is_a_real_world_state(golden):
    assert len(golden["entities"]) >= 2, golden["entities"]
    assert len(golden["market"]) >= 10, golden["market"]
    assert golden["player"]["ship"], golden["player"]


# --- the depth constant is DERIVED from the product, and the derivation is pinned ---------

def test_the_stack_depth_is_derived_from_the_engine_not_guessed(spec):
    """The pinned unwind depth must equal kStackLimiter as AI.m actually defines it.

    Bead oo-vwd's rule: derive the magic number from the product's own source AND keep the
    literal, because the derivation keeps the test honest when upstream renumbers (it fails
    loudly instead of asserting the wrong depth) and the literal keeps the derivation honest (a
    regex that matched the wrong line cannot quietly redefine what the test does).

    AI.m:40 reads `kStackLimiter = 32  // setAITo: stack overflow`. The engine dumps one
    [ai.error.stackOverflow.dump] line per PRESERVED frame (AI.m:218-223, `while (count--)` over
    the whole stack), and it raises when `[aiStack count] >= kStackLimiter` (:240), so the number
    of distinct frames is exactly kStackLimiter.
    """
    with open(AI_SOURCE, encoding="utf-8", errors="replace") as handle:
        src = handle.read()
    match = re.search(r"kStackLimiter\s*=\s*(\d+)", src)
    assert match, "AI.m no longer defines kStackLimiter; the pinned depth cannot be derived"
    derived = int(match.group(1))
    assert derived == 32, (
        "AI.m's kStackLimiter is now %d, not 32. The engine's AI stack limit changed, so scenario "
        "011's golden is stale and must be re-measured and re-blessed, not edited." % derived)
    assert spec["expected_max_stack_depth"] == derived, (
        "spec.json pins expected_max_stack_depth=%r but AI.m defines kStackLimiter=%d"
        % (spec["expected_max_stack_depth"], derived))


# --- the spec really pins the knobs, and the script really reads them ---------------------

def test_spec_pins_every_determinism_knob(spec):
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "oxp_source", "overflow_ship_role", "overflow_ship_count",
                "overflow_spawn_distance"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3, spec["quant_decimals"]
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1, spec["ticks"]


def test_the_script_reads_every_knob_the_spec_pins():
    """A knob nobody reads is decoration, which is how a 'pinned' scenario silently drifts."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    for key in ("seed", "ticks", "tick_seconds", "system_id", "load_save", "oxp_source",
                "overflow_ship_role", "overflow_ship_count", "overflow_spawn_distance",
                "expected_ship_keys", "expected_ship_ai_type", "expected_max_stack_depth",
                "expected_overflow_signatures", "expected_squash_signatures",
                "allowed_oxp_standards_errors", "allowed_oxp_standards_error_signatures"):
        assert 'spec["%s"]' % key in src, "ai_overflow.py never reads spec[%r]" % key


def test_the_scenario_reserves_a_private_port_and_writes_the_plist():
    """The game DIALS OUT to the port in debugConfig.plist (OODebugSupport.m:67-80). On the
    shared 8563 a sibling worker's console can capture and quit the game seconds in while the run
    still exits rc=0 - a fully vacuous pass (bead oo-het/oo-gla)."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert "reserve_port" in src, "ai_overflow.py does not reserve a private console port"
    assert "_write_console_config" in src, "ai_overflow.py writes no debugConfig.plist"


def test_the_staging_dir_is_not_named_addons():
    """MEASURED by bead oo-3ya: `<artifact>/addons` is `<artifact>/../AddOns` case-insensitively,
    so the game found the expansion at TWO roots and logged FOUR missing-manifest errors."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert '"oxp-stage"' in src, "the staging directory name changed"
    assert 'os.path.join(artifact_dir, "addons")' not in src, (
        "the staging directory is named `addons` again, which collides with the game's own "
        "../AddOns root on a case-insensitive filesystem and loads the expansion twice")


def test_no_manifest_is_staged(spec):
    """The bead's deliberate choice, and the one its briefing expected to be impossible.

    'AI overflow test' was reported as failing to load on a missing manifest. MEASURED, it LOADS:
    ResourceManager.m:642-664 makes the missing manifest fatal only for an .oxz (:636-641) or
    under OOEnforceStandards() (:647-651); for a relaxed-mode .oxp the engine logs the standards
    error, synthesises a basic manifest (:654) and adds the path to searchPaths (:663). So no
    companion manifest had to be staged, and none is - the missing manifest is TOLERATED EXACTLY.
    Writing one would also be editing expansion content.

    Checked on the AST rather than on the text, because the text says `manifest.plist` many times
    in prose that explains the tolerance - a grep would match the explanation and not the act.
    """
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    tree = ast.parse(src)
    # THE CHECK IS ON THE ACT, NOT ON THE MENTION. An earlier version flagged every non-docstring
    # string constant containing `manifest.plist` and then matched the script's own guard messages
    # and the NOMANIF allow-list signature - i.e. it reported the guard as the violation. What
    # must be forbidden is CREATING that file, so this checks that no path-building or
    # file-opening call carries `manifest.plist` in any argument. Prose and error messages may
    # name it freely; `open(.../manifest.plist, "w")` may not exist.
    creators = {"open", "os.path.join", "shutil.copy", "shutil.copy2", "shutil.copyfile",
                "plistlib.dump", "plistlib.dumps"}
    offenders = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or ast.unparse(node.func) not in creators:
            continue
        for arg in node.args:
            for sub in ast.walk(arg):
                if isinstance(sub, ast.Constant) and isinstance(sub.value, str) \
                        and "manifest.plist" in sub.value:
                    offenders.append(ast.unparse(node))
    assert not offenders, (
        "ai_overflow.py builds a path to manifest.plist in executable code (%r); this scenario "
        "must TOLERATE the missing manifest exactly, never fabricate one" % offenders)

    staging = next(n for n in ast.walk(tree)
                   if isinstance(n, ast.FunctionDef) and n.name == "stage_oxp")
    calls = {ast.unparse(n.func) for n in ast.walk(staging) if isinstance(n, ast.Call)}
    assert "open" not in calls, "stage_oxp opens a file; it must only copy the fixture tree"
    assert "shutil.copytree" in calls, "stage_oxp no longer copies the fixture tree verbatim"

    src_oxp = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    assert not os.path.isfile(os.path.join(src_oxp, "manifest.plist")), (
        "the fixture now HAS a manifest.plist, so the NOMANIF allowance of exactly 2 errors is "
        "stale and this scenario's error pin must be re-measured")


def test_the_overflow_is_awaited_before_the_tick_budget_is_measured():
    """The causal claim in the evidence depends on this ORDER, so the order is pinned.

    `tick_budget_met` is only evidence that the simulation SURVIVED the overflow if the budget
    starts after the overflow was observed. If run_ticks ran first, a met budget would mean
    nothing more than 'the game was alive at some point', and the strongest anti-vacuity field in
    the dump would quietly become the weakest.
    """
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    tree = ast.parse(src)
    fn = next(n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == "run")
    # ORDERED BY SOURCE LINE, not by ast.walk order. ast.walk is a breadth-first queue, so its
    # sequence is tree-shape order and has nothing to do with execution order - an earlier version
    # of this test used it and reported a false failure on correct code.
    calls = {}
    for node in ast.walk(fn):
        if isinstance(node, ast.Call):
            name = ast.unparse(node.func)
            if name not in calls or node.lineno < calls[name]:
                calls[name] = node.lineno
    assert "await_overflow" in calls, "run() no longer waits for the engine's overflow report"
    assert "run_ticks" in calls, "run() no longer measures a tick budget"
    assert calls["await_overflow"] < calls["run_ticks"], (
        "run() measures its tick budget at line %d, BEFORE waiting for the overflow at line %d, "
        "so tick_budget_met no longer shows the simulation survived the overflow"
        % (calls["run_ticks"], calls["await_overflow"]))


# --- DATA mutants: corrupt the dump, the checker must refuse -------------------------------

def test_a_dump_with_no_overflow_is_refused(golden, scratch):
    """THE CENTRAL ANTI-VACUITY CLAIM OF THIS SCENARIO. A run that loaded the OXP and dumped a
    quiet world has zero here, and must not be accepted as an AI-overflow run."""
    rc, out = run(EVIDENCE, write(scratch, "no_overflow.json",
                                  one_field(golden, ai_stack_overflow_events=0)))
    assert rc == 1, out
    assert "ai_stack_overflow_events" in out, out
    assert "NAMED for" in out, out


def test_a_dump_whose_overflow_is_a_different_ai_is_refused(golden, scratch):
    """Attribution: an overflow in some other ship's AI is not this expansion's overflow."""
    rc, out = run(EVIDENCE, write(scratch, "other_ai.json", one_field(
        golden, ai_stack_overflow_signatures=["route1traderAI.plist:GLOBAL"])))
    assert rc == 1, out
    assert "attributes the overflow to THIS expansion" in out, out


def test_a_dump_with_a_wrong_unwind_depth_is_refused(golden, scratch):
    """The depth is a structural constant (AI.m:40 kStackLimiter), not a timing artefact."""
    rc, out = run(EVIDENCE, write(scratch, "depth.json",
                                  one_field(golden, ai_stack_overflow_max_stack_depth=31)))
    assert rc == 1, out
    assert "kStackLimiter" in out, out


def test_a_dump_whose_overflow_escaped_its_handler_is_refused(golden, scratch):
    """Reached is not handled. events=1, squashed=0 must fail, and say why."""
    rc, out = run(EVIDENCE, write(scratch, "escaped.json", one_field(
        golden, ai_stack_overflow_squashed=0, overflow_handled=False,
        ai_stack_overflow_squash_signatures=[])))
    assert rc == 1, out
    assert "ai_stack_overflow_squashed" in out, out


def test_a_dump_with_more_overflows_than_squashes_is_refused(golden, scratch):
    """The RELATION, not either count alone: 2 raised and 1 caught means one escaped."""
    rc, out = run(EVIDENCE, write(scratch, "unbalanced.json",
                                  one_field(golden, ai_stack_overflow_events=2)))
    assert rc == 1, out
    assert "escaped its handler" in out, out


def test_a_dump_with_no_expansion_ship_keys_is_refused(golden, scratch):
    rc, out = run(EVIDENCE, write(scratch, "no_keys.json", one_field(golden, oxp_ship_keys=[])))
    assert rc == 1, out
    assert "oxp_ship_keys" in out, out


def test_a_dump_with_a_different_expansion_is_refused(golden, scratch):
    rc, out = run(EVIDENCE, write(scratch, "other_oxp.json",
                                  one_field(golden, oxp_ship_keys=["some-other-oxp-ship"])))
    assert rc == 1, out
    assert "not this expansion's measured set" in out, out


def test_a_dump_whose_ship_key_is_a_bare_name_is_refused(golden, scratch):
    """Key enumeration is not merged ship data: with no property read, the key could be a name
    with nothing behind it."""
    rc, out = run(EVIDENCE, write(scratch, "bare_key.json",
                                  one_field(golden, oxp_ship_ai_type=None)))
    assert rc == 1, out
    assert "oxp_ship_ai_type" in out, out


def test_a_dump_with_a_WRONG_ship_ai_type_is_refused(golden, scratch):
    """The non-empty-but-wrong case, which the emptiness test above does NOT reach."""
    rc, out = run(EVIDENCE, write(scratch, "wrong_ai.json",
                                  one_field(golden, oxp_ship_ai_type="route1traderAI.plist")))
    assert rc == 1, out
    assert "but the measured value is" in out, out


def test_a_dump_that_spawned_nothing_is_refused(golden, scratch):
    rc, out = run(EVIDENCE, write(scratch, "no_spawn.json",
                                  one_field(golden, overflow_ships_spawned=0)))
    assert rc == 1, out
    assert "overflow_ships_spawned" in out, out


def test_a_third_missing_manifest_error_is_refused(golden, scratch):
    """oo-kcrw's NOMANIF state is gated on the errors being EXCLUSIVELY that message at that
    EXACT count. Three is a new problem, not more of the same."""
    rc, out = run(EVIDENCE, write(scratch, "three.json",
                                  one_field(golden, oxp_standards_errors=3)))
    assert rc == 1, out
    assert "exactly 2 is allowed" in out, out


def test_zero_missing_manifest_errors_is_also_refused(golden, scratch):
    """The allowance is two-sided: zero means the expansion was never parsed."""
    rc, out = run(EVIDENCE, write(scratch, "zero.json", one_field(
        golden, oxp_standards_errors=0, oxp_standards_error_signatures=[])))
    assert rc == 1, out
    assert "oxp_standards_errors" in out, out


def test_a_different_oxp_standards_error_is_refused(golden, scratch):
    rc, out = run(EVIDENCE, write(scratch, "other_err.json", one_field(
        golden, oxp_standards_error_signatures=["Bad subentity definition found"])))
    assert rc == 1, out
    assert "NOT the known missing-manifest message" in out, out


def test_a_dump_that_never_ran_its_ticks_is_refused(golden, scratch):
    rc, out = run(EVIDENCE, write(scratch, "no_ticks.json",
                                  one_field(golden, tick_budget_met=False)))
    assert rc == 1, out
    assert "tick_budget_met" in out, out


def test_a_dump_with_no_evidence_block_is_refused(golden, scratch):
    del golden["evidence"]
    rc, out = run(EVIDENCE, write(scratch, "bare.json", golden))
    assert rc == 1, out
    assert "no `evidence` object" in out, out


def test_a_collapsed_dump_is_refused_by_golden_diff(golden, scratch):
    """golden_diff's own refusals apply to this scenario too: an empty world compares equal to
    any other empty world."""
    empty = write(scratch, "empty.json", {"entities": [], "market": {}, "player": {}})
    rc, out = run(DIFF, GOLDEN, empty)
    assert rc == 2, out
    assert "REFUSED" in out, out


def test_self_comparison_is_refused_not_matched():
    """rc=2 means 'I cannot tell you'; it must never be mistaken for 'they match'."""
    rc, out = run(DIFF, GOLDEN, GOLDEN)
    assert rc == 2, out


def test_a_one_unit_field_perturbation_is_reported_by_name(golden, scratch):
    """One quantised unit (0.001) on one float must go RED naming the field and both values."""
    key = sorted(golden["market"])[0]
    golden["market"][key]["price"] = round(golden["market"][key]["price"] + 0.001, 3)
    rc, out = run(DIFF, GOLDEN, write(scratch, "perturbed.json", golden))
    assert rc == 1, out
    assert "market.%s.price" % key in out, out


def test_provenance_records_the_policy_quantisation():
    with open(PROVENANCE, encoding="utf-8") as handle:
        prov = json.load(handle)
    assert prov["quant_decimals"] == 3, prov
    assert prov["scenario"] == SCENARIO, prov
    assert prov["dump_tool"] == "tests/golden/ai_overflow.py", prov


def test_provenance_records_the_knobs_the_golden_was_blessed_with(spec):
    """The seed had NO validity predicate in bead oo-3ya's first gate, and a mutation harness
    found it: the spec line PRINTED the seed and accepted any value, so an edit to spec.json's
    seed would leave the stored golden silently no longer corresponding to what the spec produces
    - and the fresh-run-vs-golden line cannot catch it either, because changing the seed changes
    BOTH sides of that comparison.

    The fix is not a magic number in the checker: provenance records the knobs the golden was
    BLESSED with, and the gate asserts the spec still agrees. Re-blessing with new knobs stays
    legal (both files move together); drift between them is fatal.
    """
    with open(PROVENANCE, encoding="utf-8") as handle:
        prov = json.load(handle)
    knobs = prov.get("scenario_knobs")
    assert knobs, "provenance records no scenario_knobs; the blessed seed is unrecorded"
    assert "seed" in knobs, knobs
    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    assert not drift, (
        "spec.json disagrees with the knobs this golden was blessed with (blessed, spec): %r"
        % drift)


def test_an_off_policy_quantisation_is_refused(golden, scratch):
    """Rounding harder to make a golden pass is forbidden, and golden_diff enforces it by
    reading the provenance beside the dump."""
    left = write(scratch, "state.json", golden)
    with open(os.path.join(scratch, "provenance.json"), "w", encoding="utf-8") as handle:
        json.dump({"quant_decimals": 0, "scenario": SCENARIO}, handle)
    rc, out = run(DIFF, left, GOLDEN)
    assert rc == 2, out
    assert "quant_decimals" in out, out


# --- CHECKER mutants: weaken the validator, a known-bad input must STILL be rejected -------
#
# oo-jor's lesson: a gate can protect its data and leave its validator unprotected. Each test
# below removes ONE defence from a COPY of the checker and asserts the copy STILL rejects the
# known-bad input, so the redundancy cannot be silently collapsed by a later refactor - and each
# is paired with a test that removes ALL the defences on that property and asserts the verdict
# DOES change, which is what proves the redundancy is real and not two names for one check.

def test_each_defence_alone_still_rejects_a_run_with_no_overflow(golden, scratch):
    """The property this whole scenario exists for, pinned defence by defence.

    THE FIELD UNDER TEST IS THE OVERFLOW EVIDENCE AND ONLY THAT. The bad dump is the honest shape
    of a run that loaded the OXP and never spawned the ship: no events, no signatures, nothing
    squashed, not handled. Every other evidence field keeps its real value, so a rejection cannot
    be credited to some unrelated check.

    Four defences guard it, and they are structurally different rather than duplicates:

      3a  `events < EXPECTED_OVERFLOW_EVENTS`             - the count
      3b  `set(sigs) != EXPECTED_OVERFLOW_SIGNATURES`     - the attribution by AI file name
      4a  `squashed < 1`                                  - something was caught
      4b  `set(squash_sigs) != EXPECTED_SQUASH_SIGNATURES`- the handler that caught it
      (plus `overflow_handled` in REQUIRED_TRUE, exercised by its own removal below)
    """
    bad_path = write(scratch, "quiet_run.json", one_field(
        golden,
        ai_stack_overflow_events=0,
        ai_stack_overflow_signatures=[],
        ai_stack_overflow_squashed=0,
        ai_stack_overflow_squash_signatures=[],
        overflow_handled=False))

    defences = {
        "3a (overflow count)": (
            "    if not isinstance(events, int) or events < EXPECTED_OVERFLOW_EVENTS:",
            "    if not isinstance(events, int) and False:"),
        "3b (overflow attribution)": (
            "    elif set(sigs) != EXPECTED_OVERFLOW_SIGNATURES:",
            "    elif False:"),
        "4a (something was squashed)": (
            "    if not isinstance(squashed, int) or squashed < 1:",
            "    if not isinstance(squashed, int) and False:"),
        "4b (which handler caught it)": (
            "    if not isinstance(squash_sigs, list) or set(squash_sigs) != "
            "EXPECTED_SQUASH_SIGNATURES:",
            "    if not isinstance(squash_sigs, list):"),
        "overflow_handled (REQUIRED_TRUE)": (
            'REQUIRED_TRUE = ("oxp_staged", "tick_budget_met", "overflow_handled")',
            'REQUIRED_TRUE = ("oxp_staged", "tick_budget_met")'),
    }
    for tag, (old, new) in defences.items():
        path = mutated_checker(scratch, old, new, "mutant_%s.py" % re.sub(r"\W+", "_", tag))
        rc, out = run(path, bad_path)
        assert rc == 1, (
            "with defence %s removed the checker ACCEPTED a dump from a run in which NO AI stack "
            "overflow happened (rc=%d). The property is then held by fewer lines than this test "
            "claims.\n%s" % (tag, rc, out))


def test_removing_every_overflow_defence_does_change_behaviour(golden, scratch):
    """The mutation that genuinely weakens the gate. If this does NOT go green, the test above is
    measuring something other than what it claims (an equivalent mutant, or a defence nobody
    named), and the pair must be re-read rather than trusted."""
    bad_path = write(scratch, "quiet_both.json", one_field(
        golden,
        ai_stack_overflow_events=0,
        ai_stack_overflow_signatures=[],
        ai_stack_overflow_squashed=0,
        ai_stack_overflow_squash_signatures=[],
        overflow_handled=False))
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    for old, new in (
        ("    if not isinstance(events, int) or events < EXPECTED_OVERFLOW_EVENTS:",
         "    if not isinstance(events, int) and False:"),
        ("    if not isinstance(sigs, list) or not sigs:",
         "    if not isinstance(sigs, list) and False:"),
        ("    elif set(sigs) != EXPECTED_OVERFLOW_SIGNATURES:", "    elif False:"),
        ("    if not isinstance(squashed, int) or squashed < 1:",
         "    if not isinstance(squashed, int) and False:"),
        ("    if not isinstance(squash_sigs, list) or set(squash_sigs) != "
         "EXPECTED_SQUASH_SIGNATURES:", "    if not isinstance(squash_sigs, list):"),
        ('REQUIRED_TRUE = ("oxp_staged", "tick_budget_met", "overflow_handled")',
         'REQUIRED_TRUE = ("oxp_staged", "tick_budget_met")'),
    ):
        assert old in src, "mutation is stale: %r" % old
        src = src.replace(old, new, 1)
    path = os.path.join(scratch, "mutant_overflow_all.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing EVERY overflow defence did not change the verdict (rc=%d), so some OTHER check "
        "is rejecting this dump and the per-defence test above is not measuring what it claims. "
        "Read the checker and name the real defence.\n%s" % (rc, out))


def test_the_quiet_run_mutant_does_not_leak_into_another_field(golden, scratch):
    """Guard on the guard: the bad dump used above must differ from the golden ONLY in the
    overflow fields, or the two tests before it are attributing a rejection to the wrong check."""
    changed = {"ai_stack_overflow_events", "ai_stack_overflow_signatures",
               "ai_stack_overflow_squashed", "ai_stack_overflow_squash_signatures",
               "overflow_handled"}
    bad = one_field(golden, ai_stack_overflow_events=0, ai_stack_overflow_signatures=[],
                    ai_stack_overflow_squashed=0, ai_stack_overflow_squash_signatures=[],
                    overflow_handled=False)["evidence"]
    differing = {k for k in set(bad) | set(golden["evidence"])
                 if bad.get(k) != golden["evidence"].get(k)}
    assert differing == changed, differing


def test_each_defence_alone_still_rejects_an_unmerged_expansion(golden, scratch):
    """The same discipline on DEFENCE 1/2: 'the expansion's content is live'.

    The bad dump is a run whose registry had nothing from the expansion, which is what --no-oxp
    and --empty-stage produce.
    """
    bad_path = write(scratch, "unmerged.json",
                     one_field(golden, oxp_ship_keys=[], oxp_ship_ai_type=None))
    defences = {
        "1 (registry keys)": (
            "    if not isinstance(keys, list) or not keys:",
            "    if not isinstance(keys, list) and False:"),
        "2 (ai_type property read)": ("    if not ai_type:", "    if False:"),
    }
    for tag, (old, new) in defences.items():
        path = mutated_checker(scratch, old, new, "mutant_%s.py" % re.sub(r"\W+", "_", tag))
        rc, out = run(path, bad_path)
        assert rc == 1, (
            "with defence %s removed the checker ACCEPTED a dump whose running game had none of "
            "the expansion's ship data (rc=%d); the other defence must hold the property on its "
            "own.\n%s" % (tag, rc, out))


def test_removing_both_merge_defences_does_change_behaviour(golden, scratch):
    bad_path = write(scratch, "unmerged_both.json",
                     one_field(golden, oxp_ship_keys=[], oxp_ship_ai_type=None))
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    for old, new in (
        ("    if not isinstance(keys, list) or not keys:",
         "    if not isinstance(keys, list) and False:"),
        ("    elif set(keys) != EXPECTED_SHIP_KEYS:", "    elif False:"),
        ("    if not ai_type:", "    if False:"),
        ("    elif ai_type != EXPECTED_SHIP_AI_TYPE:", "    elif False:"),
    ):
        assert old in src, "mutation is stale: %r" % old
        src = src.replace(old, new, 1)
    path = os.path.join(scratch, "mutant_merge_all.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing every merge defence did not change the verdict (rc=%d), so the per-defence test "
        "above is not measuring what it claims\n%s" % (rc, out))


def test_weakening_the_error_count_to_at_most_is_still_caught_by_the_signature_clause(
        golden, scratch):
    """The count and the signature list are two independent defences on the NOMANIF allowance."""
    bad_path = write(scratch, "bad_errors.json", one_field(
        golden, oxp_standards_errors=0, oxp_standards_error_signatures=[]))
    path = mutated_checker(
        scratch,
        "    if count != EXPECTED_STANDARDS_ERRORS:",
        "    if count is None:",
        "mutant_errcount.py")
    rc, out = run(path, bad_path)
    assert rc == 1, (
        "with the exact-count defence removed the checker ACCEPTED a dump with zero "
        "missing-manifest errors, i.e. a run in which the expansion was never parsed (rc=%d). "
        "The signature clause must hold that property on its own.\n%s" % (rc, out))


def test_removing_both_nomanif_defences_does_change_behaviour(golden, scratch):
    """The only mutation that genuinely weakens the NOMANIF gate."""
    bad_path = write(scratch, "bad_both.json", one_field(
        golden, oxp_standards_errors=0, oxp_standards_error_signatures=[]))
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace("    if count != EXPECTED_STANDARDS_ERRORS:", "    if count is None:", 1)
    src = src.replace("        if not std_sigs:", "        if False:", 1)
    path = os.path.join(scratch, "mutant_nomanif_both.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, _ = run(path, bad_path)
    assert rc == 0, (
        "removing BOTH NOMANIF defences did not change the verdict, so this pair of tests is "
        "measuring something other than what it claims (rc=%d)" % rc)


def test_weakening_the_depth_check_is_not_covered_by_anything_else(golden, scratch):
    """The depth has exactly ONE defence, deliberately: it is a single structural constant.

    This test states that plainly rather than leaving it implicit - with the clause removed, a
    wrong depth IS accepted, so nothing else in the checker covers it and the clause must never be
    deleted as 'redundant'.
    """
    bad_path = write(scratch, "bad_depth.json",
                     one_field(golden, ai_stack_overflow_max_stack_depth=31))
    path = mutated_checker(scratch,
                           "    if depth != EXPECTED_MAX_STACK_DEPTH:",
                           "    if depth is None:", "mutant_depth.py")
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing the depth clause did NOT change the verdict on a wrong-depth dump (rc=%d), so "
        "this test is not measuring the clause it names.\n%s" % (rc, out))
    rc, out = run(EVIDENCE, bad_path)
    assert rc == 1, out


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 is 'I cannot tell you'. A checker that returns 0 when it could not perform the check
    is the most dangerous failure mode a gate can have."""
    rc, out = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2, out
    assert "USAGE" in out, out


# ---------------------------------------------------------------------------------------------
# DRIVING THE GATES, NOT READING THEIR SOURCE.
#
# Everything above this line tests the evidence CHECKER. The tests below test the two offline
# GATES (`ai_overflow.py --gate spec` and `--gate isolation`), and they exist because a mutation
# run measured a real hole: four mutants that weakened those gates survived the ENTIRE stored
# acceptance block. The reason was structural - the suite asserted things about the shape of
# ai_overflow.py's source, so weakening a gate's logic changed nothing any test looked at.
#
# The fix is to run each gate against a deliberately broken INPUT and require it to say no. A
# gate is only known to work when it has been seen refusing.
# ---------------------------------------------------------------------------------------------


def mutated_script(scratch, old, new, name="script_mutant.py", count=-1):
    """A COPY of ai_overflow.py with one defence weakened. The real file is untouched.

    `count` defaults to ALL occurrences, not the first. Replacing only the first occurrence left
    the needle still present elsewhere in the file, so a source-scanning gate went on finding it
    and the test reported a false survival - the mutant had not actually been applied.
    """
    with open(SCRIPT, "r", encoding="utf-8") as handle:
        src = handle.read()
    assert old in src, "anchor for the script mutant is gone: %r" % old
    mutated = src.replace(old, new) if count < 0 else src.replace(old, new, count)
    assert mutated != src, "the mutation changed nothing: %r" % old
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(mutated)
    return path


def test_gate_spec_rejects_a_spec_that_drifted_from_the_blessed_provenance(spec, scratch):
    """C7's target, driven rather than inspected.

    A mutation run weakened `drift = {...}` to `drift = {}` and the whole acceptance block stayed
    green, because nothing ever gave gate_spec a spec that disagreed with its provenance. This
    supplies exactly that and requires a refusal naming both values - the defence bead oo-3ya's
    seed escaped through.
    """
    import ai_overflow

    with open(PROVENANCE, "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    prov["scenario_knobs"]["seed"] = spec["seed"] + 1
    prov_path = write(scratch, "drifted_provenance.json", prov)

    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_spec(spec, prov_path=prov_path)
    message = str(exc.value)
    assert "seed" in message, message
    assert str(spec["seed"]) in message and str(spec["seed"] + 1) in message, (
        "the refusal does not name BOTH the spec value and the blessed value: %s" % message)

    # And the control: against the real provenance the same call must pass.
    ai_overflow.gate_spec(spec, prov_path=PROVENANCE)


def test_gate_spec_refuses_a_provenance_with_no_recorded_knobs(spec, scratch):
    """An unrecorded seed is the same hole as a drifted one: with nothing to compare against, the
    comparison silently succeeds. Deleting scenario_knobs must be fatal, not permissive."""
    import ai_overflow

    with open(PROVENANCE, "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    prov.pop("scenario_knobs", None)
    prov_path = write(scratch, "knobless_provenance.json", prov)

    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_spec(spec, prov_path=prov_path)
    assert "scenario_knobs" in str(exc.value), str(exc.value)


def test_gate_isolation_rejects_a_script_that_dropped_its_private_port(scratch):
    """C8's target, driven rather than inspected.

    On the shared console port 8563 a sibling worker's console captures and quits the game seconds
    in, and the run still exits 0 with no ERROR lines - a fully vacuous pass (bead oo-het). The
    gate must refuse a source that no longer reserves its own port.
    """
    import ai_overflow

    path = mutated_script(scratch, "reserve_port", "shared_port", "no_port.py")
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "port" in str(exc.value), str(exc.value)

    ai_overflow.gate_isolation(src_path=SCRIPT)


def test_gate_isolation_rejects_a_script_that_stopped_writing_the_debug_config(scratch):
    """The game DIALS OUT to the port named in debugConfig.plist; a run that writes no plist can
    never be reached on a private port at all (bead oo-gla)."""
    import ai_overflow

    path = mutated_script(scratch, "_write_console_config", "_skip_console_config", "no_plist.py")
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "debugConfig.plist" in str(exc.value), str(exc.value)


def test_gate_isolation_rejects_a_script_that_stages_the_oxp_into_addons(scratch):
    """<artifact>/addons IS <artifact>/../AddOns case-insensitively on Windows, so the expansion
    loads at TWO roots and logs FOUR missing-manifest errors instead of two (bead oo-3ya)."""
    import ai_overflow

    quoted = chr(34)
    path = mutated_script(scratch,
                          "os.path.join(artifact_dir, %soxp-stage%s)" % (quoted, quoted),
                          "os.path.join(artifact_dir, %saddons%s)" % (quoted, quoted),
                          "addons.py")
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "AddOns" in str(exc.value), str(exc.value)


def test_gate_isolation_rejects_a_script_that_fabricates_a_manifest(scratch):
    """The tolerance for this fixture's missing manifest is NOT permission to write one. A
    fabricated manifest would silence the two oxp-standards errors the scenario pins, turning a
    documented NOMANIF state into an invisible one."""
    import ai_overflow

    quoted = chr(34)
    anchor = "os.path.join(artifact_dir, %soxp-stage%s)" % (quoted, quoted)
    fabricate = ("(open(os.path.join(artifact_dir, %smanifest.plist%s), %sw%s).close(), %s)[1]"
                 % (quoted, quoted, quoted, quoted, anchor))
    path = mutated_script(scratch, anchor, fabricate, "fabricate.py", count=1)
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "manifest" in str(exc.value), str(exc.value)


def test_gate_isolation_rejects_measuring_the_tick_budget_before_the_overflow(scratch):
    """C5's target, driven rather than inspected.

    If run() measures its tick budget BEFORE awaiting the engine's overflow report, then
    evidence.tick_budget_met no longer shows the simulation SURVIVED the overflow - it shows only
    that the game was once alive.
    """
    import ai_overflow

    path = mutated_script(
        scratch,
        "            if spawn:\n                await_overflow(console, artifact_dir)\n"
        "            elapsed = run_ticks(console, ticks, float(spec[\"tick_seconds\"]))",
        "            elapsed = run_ticks(console, ticks, float(spec[\"tick_seconds\"]))\n"
        "            if spawn:\n                await_overflow(console, artifact_dir)",
        "reordered.py")
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "await_overflow" in str(exc.value) or "overflow report" in str(exc.value), \
        str(exc.value)


def test_gate_isolation_rejects_a_run_that_never_reaches_the_await(scratch):
    """C5's harder form: the call is still THERE, so an ordering check alone passes it, but it sits
    under a constant-false guard and can never execute. A source-shape gate must notice that the
    await is unreachable, not merely present."""
    import ai_overflow

    path = mutated_script(scratch,
                          "            if spawn:\n                await_overflow(console, artifact_dir)",
                          "            if False:\n                await_overflow(console, artifact_dir)",
                          "unreachable.py")
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.gate_isolation(src_path=path)
    assert "await_overflow" in str(exc.value) or "unreachable" in str(exc.value), str(exc.value)


def test_the_scenario_refuses_to_dump_when_no_overflow_was_recorded():
    """C6's target: assert_ran is the anti-vacuity gate, and it must be shown refusing.

    This drives assert_ran directly with an otherwise-perfect evidence block whose overflow count
    is zero - exactly the shape a run that loaded the OXP into a quiet world would produce.
    """
    import ai_overflow

    with open(SPEC, "r", encoding="utf-8") as handle:
        spec_data = json.load(handle)
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        evidence = dict(json.load(handle)["evidence"])

    ai_overflow.assert_ran(dict(evidence), spec_data)  # control: the real evidence passes

    evidence["ai_stack_overflow_events"] = 0
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.assert_ran(evidence, spec_data)
    message = str(exc.value)
    assert "ai_stack_overflow_events" in message, message
    assert "quiet world" in message or "did NOT happen" in message, message


def test_the_scenario_refuses_a_dump_whose_overflow_escaped_its_handler():
    """Reaching the overflow is half the claim; the engine HANDLING it is the other half. An
    unequal squashed-vs-raised count means the exception escaped, which is a different engine
    behaviour and must not be recorded as this scenario's golden."""
    import ai_overflow

    with open(SPEC, "r", encoding="utf-8") as handle:
        spec_data = json.load(handle)
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        evidence = dict(json.load(handle)["evidence"])

    evidence["ai_stack_overflow_squashed"] = 0
    with pytest.raises(ai_overflow.ScenarioError) as exc:
        ai_overflow.assert_ran(evidence, spec_data)
    assert "squash" in str(exc.value).lower(), str(exc.value)
