"""Offline falsifiability tests for scenario 012-retro-missions (bead oo-3ya). No game, no build.

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

import json
import os
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "012-retro-missions"

# The golden and spec live under tests/golden/pending/ until Jon approves the protected-path
# addition (tools/rebless-approvals.txt refuses a new file under goldens/ or
# tests/golden/scenarios/ without one). Both locations are searched so landing them is a pure
# `git mv` with no code change. See tests/golden/pending/012-retro-missions/LANDING.md.
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

EVIDENCE = os.path.join(HERE, "check_retro_missions_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "retro_missions.py")

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
    path = tempfile.mkdtemp(prefix="oo_3ya_test_")
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


# --- the stored golden is itself real -----------------------------------------------------

def test_the_stored_golden_proves_retromissions_went_live():
    """The green direction. If this fails, every other test here is measuring a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "RetroMissions live" in out, out


def test_the_stored_golden_is_not_a_dead_run(golden):
    ev = golden["evidence"]
    assert ev["oxp_staged"] is True, ev
    assert sorted(ev["oxp_world_scripts"]) == sorted(json.load(
        open(SPEC, encoding="utf-8"))["expected_oxp_world_scripts"]), ev
    assert ev["oxp_script_versions"], ev
    assert ev["ticks"] >= 1 and ev["tick_budget_met"] is True, ev


def test_the_stored_golden_is_a_real_world_state(golden):
    assert len(golden["entities"]) >= 2, golden["entities"]
    assert len(golden["market"]) >= 10, golden["market"]
    assert golden["player"]["ship"], golden["player"]


# --- the spec really pins the knobs, and the script really reads them ---------------------

def test_spec_pins_every_determinism_knob(spec):
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "oxp_source"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3, spec["quant_decimals"]
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1, spec["ticks"]


def test_the_script_reads_every_knob_the_spec_pins():
    """A knob nobody reads is decoration, which is how a 'pinned' scenario silently drifts."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    for key in ("seed", "ticks", "tick_seconds", "system_id", "load_save", "oxp_source",
                "stock_world_scripts", "expected_oxp_world_scripts",
                "allowed_oxp_standards_errors", "allowed_oxp_standards_error_signatures"):
        assert 'spec["%s"]' % key in src, "retro_missions.py never reads spec[%r]" % key


def test_the_scenario_reserves_a_private_port_and_writes_the_plist():
    """The game DIALS OUT to the port in debugConfig.plist (OODebugSupport.m:67-80). On the
    shared 8563 a sibling worker's console can capture and quit the game seconds in while the run
    still exits rc=0 - a fully vacuous pass (bead oo-het/oo-gla)."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert "reserve_port" in src, "retro_missions.py does not reserve a private console port"
    assert "_write_console_config" in src, "retro_missions.py writes no debugConfig.plist"


def test_the_staging_dir_is_not_named_addons():
    """MEASURED: `<artifact>/addons` is `<artifact>/../AddOns` case-insensitively, so the game
    found the expansion at TWO roots and logged FOUR missing-manifest errors instead of two."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    assert '"oxp-stage"' in src, "the staging directory name changed"
    assert 'os.path.join(artifact_dir, "addons")' not in src, (
        "the staging directory is named `addons` again, which collides with the game's own "
        "../AddOns root on a case-insensitive filesystem and loads the expansion twice")


def test_no_manifest_is_staged(spec):
    """The bead's deliberate choice: RetroMissions' missing manifest is TOLERATED EXACTLY, not
    papered over by writing one. Writing a manifest would also be editing expansion content.

    Checked on the AST rather than on the text, because the text says `manifest.plist` many times
    in prose that explains the tolerance - a grep would match the explanation and not the act.
    The check is: no STRING CONSTANT outside a docstring mentions manifest.plist (so no code can
    name that file as a path), and the staging function does nothing but copy the fixture tree.
    """
    import ast

    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    tree = ast.parse(src)
    docstrings = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            body = getattr(node, "body", None)
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant)                     and isinstance(body[0].value.value, str):
                docstrings.add(id(body[0].value))
    offenders = [n.value for n in ast.walk(tree)
                 if isinstance(n, ast.Constant) and isinstance(n.value, str)
                 and id(n) not in docstrings and "manifest.plist" in n.value]
    assert not offenders, (
        "retro_missions.py names manifest.plist in executable code (%r); this scenario must "
        "TOLERATE the missing manifest exactly, never fabricate one" % offenders)

    staging = next(n for n in ast.walk(tree)
                   if isinstance(n, ast.FunctionDef) and n.name == "stage_oxp")
    calls = {ast.unparse(n.func) for n in ast.walk(staging) if isinstance(n, ast.Call)}
    assert "open" not in calls, "stage_oxp opens a file; it must only copy the fixture tree"
    assert "shutil.copytree" in calls, "stage_oxp no longer copies the fixture tree verbatim"

    src_oxp = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    assert not os.path.isfile(os.path.join(src_oxp, "manifest.plist")), (
        "the fixture now HAS a manifest.plist, so the NOMANIF allowance of exactly 2 errors is "
        "stale and this scenario's error pin must be re-measured")


# --- DATA mutants: corrupt the dump, the checker must refuse -------------------------------

def test_a_dump_with_no_expansion_scripts_is_refused(golden, scratch):
    """The central anti-vacuity claim. A run that loaded the game but not the expansion has an
    empty list here, and must not be accepted as a RetroMissions run."""
    golden["evidence"]["oxp_world_scripts"] = []
    rc, out = run(EVIDENCE, write(scratch, "no_scripts.json", golden))
    assert rc == 1, out
    assert "oxp_world_scripts" in out, out


def test_a_dump_with_a_different_expansion_is_refused(golden, scratch):
    golden["evidence"]["oxp_world_scripts"] = ["some-other-oxp-script"]
    rc, out = run(EVIDENCE, write(scratch, "other.json", golden))
    assert rc == 1, out
    assert "not RetroMissions' measured set" in out, out


def test_a_dump_whose_scripts_are_bare_keys_is_refused(golden, scratch):
    """Key enumeration is not instantiation: with no version read off a live object, the names
    could be a merged list with no script behind it."""
    golden["evidence"]["oxp_script_versions"] = {}
    rc, out = run(EVIDENCE, write(scratch, "keys_only.json", golden))
    assert rc == 1, out
    assert "oxp_script_versions" in out, out


def test_a_dump_with_a_WRONG_script_version_is_refused(golden, scratch):
    """The non-empty-but-wrong case, which the emptiness test above does NOT reach.

    `oxp_script_versions` is guarded by two clauses: an emptiness check and a value comparison
    against the measured `{"ahruman-reaper": "1"}`. A dump carrying `{"ahruman-reaper": "999"}`
    passes the first and is caught only by the second. Without this test, deleting the value
    comparison left the whole offline suite green - a mutation harness scored it as a SURVIVOR,
    and the survivor was a gap in these tests rather than redundancy in the checker: measured
    directly, the real checker returns rc=1 on that dump and the mutated copy returns rc=0.
    """
    golden["evidence"]["oxp_script_versions"] = {"ahruman-reaper": "999"}
    rc, out = run(EVIDENCE, write(scratch, "wrong_version.json", golden))
    assert rc == 1, out
    assert "but the measured value is" in out, out


def test_the_script_version_defences_are_not_the_same_check(golden, scratch):
    """Each clause alone must still reject the input the OTHER one is aimed at, or the pair has
    silently collapsed into one check (bead oo-jor)."""
    empty = dict(golden)
    empty["evidence"] = dict(golden["evidence"], oxp_script_versions={})
    wrong = dict(golden)
    wrong["evidence"] = dict(golden["evidence"],
                             oxp_script_versions={"ahruman-reaper": "999"})

    no_emptiness = mutated_checker(
        scratch,
        "    if not isinstance(versions, dict) or not versions:",
        "    if not isinstance(versions, dict):", "mutant_ver_empty.py")
    rc, out = run(no_emptiness, write(scratch, "ver_empty.json", empty))
    assert rc == 1, (
        "with the emptiness clause removed the checker ACCEPTED an EMPTY oxp_script_versions "
        "(rc=%d); the value comparison must still catch it.\n%s" % (rc, out))

    no_value = mutated_checker(
        scratch,
        "    elif versions != EXPECTED_LIVE_SCRIPT_VERSIONS:",
        "    elif False:", "mutant_ver_value.py")
    rc, out = run(no_value, write(scratch, "ver_wrong.json", wrong))
    assert rc == 0, (
        "removing the value comparison did NOT change the verdict on a wrong-but-non-empty "
        "version dict (rc=%d), so this test is not measuring the clause it names.\n%s" % (rc, out))



def test_a_third_missing_manifest_error_is_refused(golden, scratch):
    """oo-kcrw's NOMANIF state is gated on the errors being EXCLUSIVELY that message at that
    EXACT count. Three is a new problem, not more of the same."""
    golden["evidence"]["oxp_standards_errors"] = 3
    rc, out = run(EVIDENCE, write(scratch, "three.json", golden))
    assert rc == 1, out
    assert "exactly 2 is allowed" in out, out


def test_zero_missing_manifest_errors_is_also_refused(golden, scratch):
    """The allowance is two-sided: zero means the expansion was never parsed."""
    golden["evidence"]["oxp_standards_errors"] = 0
    golden["evidence"]["oxp_standards_error_signatures"] = []
    rc, out = run(EVIDENCE, write(scratch, "zero.json", golden))
    assert rc == 1, out
    assert "oxp_standards_errors" in out, out


def test_a_different_oxp_standards_error_is_refused(golden, scratch):
    golden["evidence"]["oxp_standards_error_signatures"] = ["Bad subentity definition found"]
    rc, out = run(EVIDENCE, write(scratch, "other_err.json", golden))
    assert rc == 1, out
    assert "NOT the known missing-manifest message" in out, out


def test_a_dump_that_never_ran_its_ticks_is_refused(golden, scratch):
    golden["evidence"]["tick_budget_met"] = False
    rc, out = run(EVIDENCE, write(scratch, "no_ticks.json", golden))
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
    assert prov["dump_tool"] == "tests/golden/retro_missions.py", prov


def test_provenance_records_the_knobs_the_golden_was_blessed_with(spec):
    """The seed had NO validity predicate, and that was a real hole a mutation harness found.

    Line 2 of the stored gate printed the seed and accepted any value, so an edit to spec.json's
    seed would leave the stored golden silently no longer corresponding to what the spec produces
    - and the fresh-run-vs-golden line cannot catch it either, because changing the seed changes
    BOTH sides of that comparison.

    The fix is not a magic number in the checker: provenance records the knobs the golden was
    BLESSED with, and the gate asserts the spec still agrees. Re-blessing with a new seed stays
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
# known-bad input, so the redundancy cannot be silently collapsed by a refactor.

def test_each_defence_alone_still_rejects_an_empty_script_list(golden, scratch):
    """The redundancy on the CENTRAL anti-vacuity field, pinned defence by defence.

    THE FIELD UNDER TEST IS `oxp_world_scripts` AND ONLY THAT FIELD. An earlier version of this
    test emptied `oxp_script_versions` in the same mutant, which made it worthless: that is a
    DIFFERENT field with its own defence, so the checker would have gone red even with BOTH
    oxp_world_scripts defences deleted, and the test would have reported a kill it did not earn.
    The bad dump below leaves every other evidence field at its real value.

    Two defences guard an empty list, and they are structurally different, not duplicates:

      1a  `if not isinstance(live, list) or not live:`     - the emptiness clause
      1b  `elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:`  - the exact-set comparison, which
          catches the empty set as one case of "wrong set"

    Removing either ALONE must still reject. `test_removing_both_world_script_defences_...`
    below removes both and asserts the dump is then ACCEPTED, which is what proves this pair is
    real redundancy rather than two names for one check.
    """
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_world_scripts=[])
    bad_path = write(scratch, "bad_scripts.json", bad)

    defences = {
        "1a (emptiness clause)": (
            '    if not isinstance(live, list) or not live:',
            '    if not isinstance(live, list):'),
        "1b (exact-set comparison)": (
            '    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:',
            '    elif False:'),
    }
    for tag, (old, new) in defences.items():
        path = mutated_checker(scratch, old, new, "mutant_%s.py" % tag.split()[0])
        rc, out = run(path, bad_path)
        assert rc == 1, (
            "with defence %s removed the checker ACCEPTED a dump whose evidence.oxp_world_scripts "
            "is empty (rc=%d). The property is then held by a single line, so the redundancy this "
            "test pins is gone.\n%s" % (tag, rc, out))


def test_removing_both_world_script_defences_does_change_behaviour(golden, scratch):
    """The mutation that genuinely weakens the gate. If this does NOT go green, the test above is
    measuring something other than what it claims (an equivalent mutant, or a third defence
    nobody named), and the pair must be re-read rather than trusted."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_world_scripts=[])
    bad_path = write(scratch, "bad_both_scripts.json", bad)
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace('    if not isinstance(live, list) or not live:',
                      '    if not isinstance(live, list):', 1)
    src = src.replace('    elif set(live) != EXPECTED_OXP_WORLD_SCRIPTS:', '    elif False:', 1)
    path = os.path.join(scratch, "mutant_scripts_both.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(path, bad_path)
    assert rc == 0, (
        "removing BOTH oxp_world_scripts defences did not change the verdict (rc=%d), so some "
        "OTHER check is rejecting this dump and the redundancy test above is not measuring what "
        "it claims. Read the checker and name the real defence.\n%s" % (rc, out))


def test_the_empty_script_mutant_does_not_leak_into_another_field(golden, scratch):
    """Guard on the guard: the bad dump used above must differ from the golden in exactly ONE
    evidence field, or the two tests before it are attributing a rejection to the wrong check."""
    bad = dict(golden["evidence"])
    bad["oxp_world_scripts"] = []
    differing = [k for k in set(bad) | set(golden["evidence"])
                 if bad.get(k) != golden["evidence"].get(k)]
    assert differing == ["oxp_world_scripts"], differing


def test_weakening_the_error_count_to_at_most_is_still_caught_by_the_signature_clause(
        golden, scratch):
    """The count and the signature list are two independent defences on the NOMANIF allowance."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_standards_errors=0,
                           oxp_standards_error_signatures=[])
    bad_path = write(scratch, "bad_errors.json", bad)
    path = mutated_checker(
        scratch,
        '    if count != EXPECTED_STANDARDS_ERRORS:',
        '    if count is None:',
        "mutant_errcount.py")
    rc, out = run(path, bad_path)
    assert rc == 1, (
        "with the exact-count defence removed the checker ACCEPTED a dump with zero "
        "missing-manifest errors, i.e. a run in which RetroMissions was never parsed (rc=%d). "
        "The signature clause must hold that property on its own.\n%s" % (rc, out))


def test_removing_both_nomanif_defences_does_change_behaviour(golden, scratch):
    """The only mutation that genuinely weakens the gate: with BOTH defences gone a dump that
    never loaded the expansion is accepted. This is the test that proves the pair is not
    decoration."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], oxp_standards_errors=0,
                           oxp_standards_error_signatures=[])
    bad_path = write(scratch, "bad_both.json", bad)
    with open(EVIDENCE, encoding="utf-8") as handle:
        src = handle.read()
    src = src.replace('    if count != EXPECTED_STANDARDS_ERRORS:', '    if count is None:', 1)
    src = src.replace('        if not sigs:', '        if False:', 1)
    path = os.path.join(scratch, "mutant_both.py")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, _ = run(path, bad_path)
    assert rc == 0, (
        "removing BOTH NOMANIF defences did not change the verdict, so this pair of tests is "
        "measuring something other than what it claims (rc=%d)" % rc)


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 is 'I cannot tell you'. A checker that returns 0 when it could not perform the check
    is the most dangerous failure mode a gate can have."""
    rc, out = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2, out
    assert "USAGE" in out, out
