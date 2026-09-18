"""Offline falsifiability tests for scenario 007-js-interface (bead oo-5k2). No game, no build.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game. That is the only part that can observe
real engine behaviour, and it is also the slowest and flakiest thing on this box, so it is ONE
acceptance line. Everything that can be falsified without a launch is falsified here, where it
costs about a second and cannot be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration.

TWO MUTANTS PER PROPERTY, per bead oo-jor's lesson: one that corrupts the DATA and one that
weakens the CHECKER. Only the second catches a gate that validates data with a validator nobody
validates. The checker mutants copy `check_js_interface_evidence.py` to a temp dir and run the
COPY; the real file is never touched.

Nothing here writes to goldens/ or to the staged golden. The stored dump is READ, copied to a
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
SCENARIO = "007-js-interface"

# The golden is staged outside goldens/ until Jon lands it (tools/guardrails.sh refuses a new
# file under a protected path without a re-bless approval). Both locations are searched so the
# landing is a pure `git mv`.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "staging", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "staging", SCENARIO, "spec.json"),
)

EVIDENCE = os.path.join(HERE, "check_js_interface_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "js_interface.py")

sys.path.insert(0, HERE)


def _first(candidates, what):
    for p in candidates:
        if os.path.isfile(p):
            return p
    raise AssertionError("no %s found; looked at %s" % (what, ", ".join(candidates)))


GOLDEN = _first(GOLDEN_CANDIDATES, "stored golden")
SPEC = _first(SPEC_CANDIDATES, "spec.json")


def run(script, *args):
    proc = subprocess.run([sys.executable, script] + list(args), capture_output=True, text=True,
                          cwd=REPO_ROOT)
    return proc.returncode, proc.stdout + proc.stderr


@pytest.fixture()
def golden():
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def scratch():
    path = tempfile.mkdtemp(prefix="oo_5k2_test_")
    yield path
    shutil.rmtree(path, ignore_errors=True)


def write(scratch, name, data):
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    return path


# --- the stored golden is itself real ------------------------------------------------------

def test_the_stored_golden_proves_the_javascript_ran():
    """The green direction. If this fails, every other test here is measuring a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "tests passed" in out or "FAILED" in out, out


def test_the_stored_golden_carries_the_rigs_own_output(golden):
    """The evidence must be the EXPANSION'S output, not the harness's bookkeeping."""
    ev = golden["evidence"]
    assert ev["js_completion_line"].startswith(("All ", "*****")), ev["js_completion_line"]
    assert ev["js_tests_total"] >= 10, ev
    assert ev["js_pass_lines"] + ev["js_fail_lines"] == ev["js_tests_total"], ev
    assert len(ev["js_test_names_sha256"]) == 64, ev


def test_the_golden_names_its_own_producer():
    """A provenance that confidently names the wrong producer is worse than none."""
    prov = os.path.join(os.path.dirname(GOLDEN), "provenance.json")
    with open(prov, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    assert data["dump_tool"].endswith("js_interface.py"), data["dump_tool"]
    assert data["quant_decimals"] == 3, data
    assert data["scenario"] == SCENARIO, data


# --- THE HEART OF THE BEAD: a dead JS run must be rejected ----------------------------------

def test_a_run_in_which_the_javascript_never_ran_is_rejected(golden, scratch):
    """MUTANT (DATA): the scripts loaded and never executed.

    This is THE vacuous shape for this scenario: no errors, a healthy log, a perfectly
    reproducible dump, and nothing asserted. Every rig-derived field goes to its dead value at
    once, exactly as a real dead run would produce them.
    """
    import hashlib
    ev = golden["evidence"]
    ev["js_completion_line"] = ""
    ev["js_tests_total"] = 0
    ev["js_pass_lines"] = 0
    ev["js_fail_lines"] = 0
    ev["js_result_lines"] = 0
    ev["js_test_names_sha256"] = hashlib.sha256(b"").hexdigest()
    rc, out = run(EVIDENCE, write(scratch, "deadjs.json", golden))
    assert rc == 1, out
    assert "js_completion_line" in out, out
    assert "DID NOT RUN TO COMPLETION" in out, out


def test_a_missing_completion_line_alone_is_rejected(golden, scratch):
    """MUTANT (DATA): every counter still looks healthy; only the rig's terminal line is gone.

    A run that was killed between the last result and completeTests() has exactly this shape, and
    it must not pass merely because the counts look plausible.
    """
    golden["evidence"]["js_completion_line"] = ""
    rc, out = run(EVIDENCE, write(scratch, "nofinish.json", golden))
    assert rc == 1, out
    assert "js_completion_line" in out, out


def test_an_empty_test_name_digest_is_rejected(golden, scratch):
    """MUTANT (DATA): the digest of the empty name set - no $registerTest call site ever ran."""
    import hashlib
    golden["evidence"]["js_test_names_sha256"] = hashlib.sha256(b"").hexdigest()
    rc, out = run(EVIDENCE, write(scratch, "emptyhash.json", golden))
    assert rc == 1, out
    assert "js_test_names_sha256" in out and "EMPTY" in out, out


def test_a_placeholder_digest_is_rejected(golden, scratch):
    """MUTANT (DATA): all-zeroes, the shape a hand-edited dump takes."""
    golden["evidence"]["js_test_names_sha256"] = "0" * 64
    rc, out = run(EVIDENCE, write(scratch, "zerohash.json", golden))
    assert rc == 1, out
    assert "js_test_names_sha256" in out, out


def test_counters_that_disagree_with_the_completion_line_are_rejected(golden, scratch):
    """MUTANT (DATA): 69 reported, 1 collected.

    This is not hypothetical - it is the exact artefact this bead hit three times, from three
    different causes (a function round-tripped through a native property, an array mutated in a
    by-value copy, and a C0 separator mangled by the XML plist transport). Each time the rig said
    `All 69 tests passed.` while the collector held one line. The cross-check is what made it loud.
    """
    golden["evidence"]["js_pass_lines"] = 1
    golden["evidence"]["js_fail_lines"] = 0
    rc, out = run(EVIDENCE, write(scratch, "lost.json", golden))
    assert rc == 1, out
    assert "completion line reports" in out, out


def test_a_rig_that_registered_almost_nothing_is_rejected(golden, scratch):
    """MUTANT (DATA): the rig loaded but only one script registered."""
    golden["evidence"]["js_tests_total"] = 2
    golden["evidence"]["js_pass_lines"] = 2
    golden["evidence"]["js_fail_lines"] = 0
    rc, out = run(EVIDENCE, write(scratch, "thin.json", golden))
    assert rc == 1, out
    assert "js_tests_total" in out, out


def test_a_dump_with_no_evidence_block_at_all_is_rejected(golden, scratch):
    """MUTANT (DATA): a scenario-001-style dump. It must not pass merely by being a valid,
    non-vacuous, on-policy dump."""
    del golden["evidence"]
    rc, out = run(EVIDENCE, write(scratch, "noev.json", golden))
    assert rc == 1, out
    assert "evidence" in out, out


# --- the NOMANIF allow-list is an EXACT count, not a floor ----------------------------------

@pytest.mark.parametrize("count", [0, 1, 3, 4])
def test_a_wrong_no_manifest_count_is_rejected(golden, scratch, count):
    """MUTANT (DATA): the allow-list is pinned at EXACTLY 2 in both directions.

    3 is the case the bead's brief names explicitly. 4 is not hypothetical either: the first
    version of this scenario staged the expansion into a directory called `addons`, which
    collides case-insensitively with the game's own `../AddOns` search root, so one staged copy
    was enumerated twice and the log carried 4. A floor (`>= 2`) would have passed that silently.
    """
    golden["evidence"]["oxp_nomanifest_errors"] = count
    rc, out = run(EVIDENCE, write(scratch, "nomanif.json", golden))
    assert rc == 1, out
    assert "oxp_nomanifest_errors" in out, out


def test_a_dump_that_does_not_record_the_no_manifest_count_is_rejected(golden, scratch):
    """MUTANT (DATA): absence is not 0. A dump that never recorded the count cannot be checked."""
    del golden["evidence"]["oxp_nomanifest_errors"]
    rc, out = run(EVIDENCE, write(scratch, "nocount.json", golden))
    assert rc == 1, out
    assert "oxp_nomanifest_errors" in out, out


# --- the allow-list predicate itself, exercised directly ------------------------------------

GOOD_LOG = "\n".join([
    "10:00:00.100 [log.header]: Opening log for Oolite version 1.93",
    "10:00:01.000 [oxp-standards.error]: OXP C:/t/oxp-under-test/JavaScript Interface Tests.oxp "
    "has no manifest.plist",
    "10:00:01.001 [oxp-standards.error]: OXP C:/t/oxp-under-test/JavaScript Interface Tests.oxp "
    "has no manifest.plist",
    "10:00:02.000 [searchPaths.dumpAll]: Resource paths: ",
    "10:00:03.000 [debugTCP.connected]: Connected to debug console \"OoliteComponentTests\"",
    "10:00:09.000 [startup.complete]: ========== Loading complete in 9.00 seconds. ==========",
])


def test_the_allow_list_accepts_a_real_good_log():
    """The green direction for the log predicate."""
    import js_interface
    nomanif, named, transport = js_interface.assert_log(GOOD_LOG)
    assert nomanif == 2 and named is True and transport == 0


def test_the_console_transport_channel_is_allow_listed():
    """RULE 2: [debugTCP.send.error] is TRANSPORT noise, not the game failing.

    Evidence it is benign, from runs that are not this scenario's: bead oo-kcrw's tier1 corpus
    runs of three unrelated PASSING expansions each carry this channel, all reaching
    startup.complete. Matched by CHANNEL because the packet body carries volatile content.
    """
    import js_interface
    log = GOOD_LOG + ("\n10:00:10.000 [debugTCP.send.error]: The following packet could not be "
                      "sent: {\"color key\" = command; message = \"> quit();\"; }")
    nomanif, _, transport = js_interface.assert_log(log)
    assert nomanif == 2 and transport == 1


def test_a_third_different_error_line_is_still_fatal():
    """The allow-list must not have become a general error suppressor."""
    import js_interface
    log = GOOD_LOG + ("\n10:00:11.000 [shipData.load.error]: Ship data for 'foo' could not be "
                      "loaded")
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "NO allow-list rule covers" in str(exc.value)
    assert "shipData.load.error" in str(exc.value)


def test_a_third_no_manifest_line_is_still_fatal():
    """EXACT count, not a floor."""
    import js_interface
    log = GOOD_LOG + ("\n10:00:12.000 [oxp-standards.error]: OXP "
                      "C:/t/oxp-under-test/JavaScript Interface Tests.oxp has no manifest.plist")
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "EXACTLY 2" in str(exc.value) and "the log has 3" in str(exc.value)


def test_a_strangers_missing_manifest_is_not_absorbed():
    """The allow-listed line must NAME our staged copy."""
    import js_interface
    log = GOOD_LOG.replace(
        "10:00:01.001 [oxp-standards.error]: OXP C:/t/oxp-under-test/JavaScript Interface "
        "Tests.oxp has no manifest.plist",
        "10:00:01.001 [oxp-standards.error]: OXP C:/other/SomeStranger.oxp has no manifest.plist")
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "do not name our staged copy" in str(exc.value)


def test_the_sibling_hijack_signature_stays_fatal():
    """bead oo-het: a stranger's console attaching is FATAL and is NOT covered by the debugTCP
    allow-list, which names the .send.error channel and nothing wider."""
    import js_interface
    log = GOOD_LOG + ("\n10:00:13.000 [debugTCP.connected]: Connected to debug console "
                      "\"SomeoneElsesConsole\"")
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "sibling-hijack" in str(exc.value)


def test_the_debugtcp_allow_list_is_anchored_to_the_send_error_channel():
    """A rule matching `debugTCP` generally would swallow the hijack signature. Pinned so a
    future 'simplification' to a substring match has to be done knowingly."""
    import js_interface
    assert js_interface.DEBUGTCP_SEND_ERROR_CHANNEL == "debugTCP.send.error"
    assert js_interface.classify_allowed(
        "10:00:00.000 [debugTCP.connected]: Connected to debug console \"X\"") is None
    assert js_interface.classify_allowed(
        "10:00:00.000 [debugTCP.send.error]: nope") == "console-transport"


def test_a_log_that_never_names_the_expansion_is_rejected():
    """Positive proof of loading comes FIRST, so a dead run can never reach an allow-list."""
    import js_interface
    log = "\n".join([l for l in GOOD_LOG.splitlines() if "Interface Tests.oxp" not in l])
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "never names" in str(exc.value)


def test_a_log_without_startup_complete_is_rejected():
    """bead oo-het's exit-87 corpse carries the banner and no errors at all."""
    import js_interface
    log = "\n".join([l for l in GOOD_LOG.splitlines() if "startup.complete" not in l])
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_log(log)
    assert "startup.complete" in str(exc.value)


# --- CHECKER MUTANTS: the validator itself must be validated (bead oo-jor) -------------------

CHECKER_DEFENCES = [
    # (source text to remove, replacement, the mutant dump this defence is supposed to catch)
    ('        raise EvidenceError(\n'
     '            "%s carries no `evidence` object.',
     None, None),
]


def _mutate_checker(tmp_path, old, new, name):
    src = open(EVIDENCE, encoding="utf-8").read()
    assert old in src, "the checker no longer contains %r" % old[:60]
    path = str(tmp_path / name)
    with open(path, "w", encoding="utf-8", newline="\n") as h:
        h.write(src.replace(old, new, 1))
    return path


def test_the_dead_js_property_survives_the_loss_of_any_single_checker_defence(
        golden, scratch, tmp_path):
    """MUTANT (CHECKER): weaken the checker, not the data, and require the property to hold.

    "The JavaScript actually ran" is the single most important property in this bead, so it is
    defended in FOUR independent places: the empty-completion-line clause, the total-vs-result
    cross-check, the js_tests_total floor, and the empty-digest clause. Each is removed on its
    own, in a COPY of the checker in a temp dir, and the mutated copy must STILL REJECT a dead
    run. That pins the redundancy so a later refactor cannot collapse it silently.

    The real checker is never touched.
    """
    import hashlib
    ev = golden["evidence"]
    ev["js_completion_line"] = ""
    ev["js_tests_total"] = 0
    ev["js_pass_lines"] = 0
    ev["js_fail_lines"] = 0
    ev["js_result_lines"] = 0
    ev["js_test_names_sha256"] = hashlib.sha256(b"").hexdigest()
    dead = write(scratch, "dead.json", golden)

    src = open(EVIDENCE, encoding="utf-8").read()
    defences = [
        ('    if not isinstance(completion, str) or not completion.strip():',
         '    if False:'),
        ('        if passes + fails != total:', '        if False:'),
        ('    if isinstance(total, int) and total < MIN_JS_TESTS:', '    if False:'),
        ('    elif digest == EMPTY_NAMES_SHA256:', '    elif False:'),
    ]
    for i, (old, new) in enumerate(defences):
        assert old in src, "the checker no longer contains the defence %r" % old[:50]
        path = str(tmp_path / ("checker%d.py" % i))
        with open(path, "w", encoding="utf-8", newline="\n") as h:
            h.write(src.replace(old, new, 1))
        rc, out = run(path, dead)
        assert rc == 1, (
            "with defence %d (%r) removed, the checker ACCEPTED a dump from a run in which the "
            "JavaScript never executed (rc=%d). The property is then held by fewer lines than "
            "this test claims.\n%s" % (i, old.strip()[:60], rc, out))


def test_the_no_manifest_count_defence_is_not_silently_removable(golden, scratch, tmp_path):
    """MUTANT (CHECKER): turn the EXACT count into a floor and require the gate to notice.

    Widening `!= EXPECTED` to `< EXPECTED` is the single most plausible 'harmless' edit anyone
    could make to this allow-list, and it is exactly the weakening that would have hidden the
    doubly-loaded-expansion bug this scenario actually hit. The mutated copy must ACCEPT a count
    of 3 - which proves the strict form is what rejects it, rather than some other clause.
    """
    src = open(EVIDENCE, encoding="utf-8").read()
    old = "    elif nomanif != EXPECTED_NOMANIF_LINES:"
    new = "    elif nomanif < EXPECTED_NOMANIF_LINES:"
    assert old in src
    golden["evidence"]["oxp_nomanifest_errors"] = 3
    bad = write(scratch, "three.json", golden)

    rc_strict, _ = run(EVIDENCE, bad)
    assert rc_strict == 1, "the real checker does not reject a no-manifest count of 3"

    path = str(tmp_path / "loosened.py")
    with open(path, "w", encoding="utf-8", newline="\n") as h:
        h.write(src.replace(old, new, 1))
    rc_loose, out = run(path, bad)
    assert rc_loose == 0, (
        "loosening the exact count to a floor did NOT change the verdict (rc=%d), so something "
        "other than that clause is rejecting a count of 3 and this test is not measuring what it "
        "claims.\n%s" % (rc_loose, out))


# --- golden_diff still discriminates one quantised unit ON THIS golden -----------------------

def test_one_quantised_unit_of_position_is_reported(golden, scratch):
    """MUTANT (DATA): perturb one field by exactly one quantised unit (0.001) in a THROWAWAY COPY.

    This is the property the whole byte-identical claim rests on: if a 1 mm move is invisible, the
    goldens are decoration.
    """
    ent = golden["entities"][0]
    before = ent["position"][0]
    ent["position"][0] = round(before + 0.001, 3)
    assert ent["position"][0] != before
    rc, out = run(DIFF, GOLDEN, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "position[0]" in out, out


def test_a_changed_evidence_field_is_reported_by_the_diff(golden, scratch):
    """The evidence block is IN the golden, so a run in which the JS died fails the ordinary
    comparison too - not only the dedicated checker."""
    golden["evidence"]["js_completion_line"] = ""
    rc, out = run(DIFF, GOLDEN, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "js_completion_line" in out, out


def test_a_changed_test_name_digest_is_reported_by_the_diff(golden, scratch):
    """A regression that DROPS a test keeps the counts plausible and moves the digest."""
    golden["evidence"]["js_test_names_sha256"] = "a" * 64
    rc, out = run(DIFF, GOLDEN, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "js_test_names_sha256" in out, out


def test_self_comparison_is_still_refused():
    """rc=2, not rc=0: a file always equals itself."""
    rc, out = run(DIFF, GOLDEN, GOLDEN)
    assert rc == 2, out


def test_a_coarsened_quantisation_is_refused(golden, scratch):
    """Rounding harder to make a golden pass is the standard way a suite rots into decoration."""
    gdir = os.path.join(scratch, "g")
    os.makedirs(gdir)
    state = write(gdir, "state.json", golden)
    with open(os.path.join(gdir, "provenance.json"), "w", encoding="utf-8") as handle:
        json.dump({"quant_decimals": 0, "platform": "windows-x64", "scenario": SCENARIO}, handle)
    rc, out = run(DIFF, state, write(scratch, "other.json", golden))
    assert rc == 2, out
    assert "uantisation" in out, out


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 is 'I cannot tell you', never 'they match'."""
    rc, _ = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2


# --- the scenario script's own knobs ---------------------------------------------------------

def test_the_spec_pins_every_determinism_knob():
    with open(SPEC, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "oxp", "oxp_dirname"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1


def test_the_script_reads_the_spec_rather_than_hardcoding_it():
    """A knob the script never reads is decoration; the spec would drift silently."""
    src = open(SCRIPT, encoding="utf-8").read()
    for key in ("seed", "system_id", "ticks", "tick_seconds"):
        assert 'spec["%s"]' % key in src, "js_interface.py never reads spec[%r]" % key


def test_the_scenario_asserts_the_rig_is_loaded_before_calling_it():
    """typeof ooRunTests must be checked. Without it, perform('ooRunTests();') on a game where
    the expansion failed to load does nothing, silently, and the run looks perfect."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "typeof ooRunTests" in src, (
        "js_interface.py never checks that the rig exists before calling it, so a run in which "
        "the expansion did not load would proceed silently")


def test_the_scenario_waits_for_the_rigs_own_completion_line():
    """Polling for our own marker would be circular; the rig's line is not."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "oo5k2Done" in src and "completeTests()" in src, (
        "js_interface.py does not wait for the rig's own completion line")


def test_the_scenario_checks_that_the_pause_actually_took():
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'console.evaluate("pauseGame()").strip().lower() != "true"' in src, (
        "js_interface.py does not check pauseGame()'s return value")
    assert "clock_before" in src and "clock_after" in src, (
        "js_interface.py does not verify the game clock stopped after the pause")


def test_the_scenario_calls_velocity_magnitude_as_a_function():
    """As a bare property it is a function object and the comparison is always false."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "magnitude()" in src


def test_the_staging_directory_cannot_collide_with_the_games_own_addons_root():
    """MEASURED BUG, pinned. `<artifact>/addons` and the game's `../AddOns` are the same
    directory on a case-insensitive filesystem, so the expansion was enumerated twice and the
    log carried 4 no-manifest lines instead of 2."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'os.path.join(artifact_dir, "oxp-under-test")' in src
    assert 'os.path.join(artifact_dir, "addons")' not in src, (
        "the staging directory collides case-insensitively with the game's ../AddOns search "
        "root, which double-loads the expansion")


def test_the_result_separator_is_printable_ascii():
    """MEASURED BUG, pinned. A C0 control character is rendered by the XML property list as a
    literal escape, which silently collapses 69 results into one unsplittable string."""
    import js_interface
    sep = js_interface.OO5K2_SEP
    assert sep, "no separator defined"
    assert all(32 <= ord(c) < 127 for c in sep), (
        "the result separator %r contains a non-printable character; the debug-console protocol "
        "carries it through an XML property list, which escapes C0 controls into literal text "
        "and destroys the split" % sep)


def test_assert_ran_rejects_each_missing_half():
    """The in-process assertion, exercised directly rather than through a game."""
    import hashlib
    import js_interface

    good = {"js_rig_loaded": True, "js_completion_line": "All 69 tests passed.",
            "js_tests_total": 69, "js_pass_lines": 69, "js_fail_lines": 0,
            "js_result_lines": 70,
            "js_test_names_sha256": hashlib.sha256(b"x").hexdigest(),
            "oxp_nomanifest_errors": 2, "tick_budget_met": True,
            "game_seconds_budget": 3.0, "ticks": 24}
    js_interface.assert_ran(dict(good))  # green

    for field, bad in (("js_rig_loaded", False), ("js_completion_line", ""),
                       ("js_tests_total", 0), ("oxp_nomanifest_errors", 3),
                       ("tick_budget_met", False)):
        mutant = dict(good)
        mutant[field] = bad
        with pytest.raises(js_interface.ScenarioError) as exc:
            js_interface.assert_ran(mutant)
        assert field in str(exc.value), (field, str(exc.value))

    # The empty-name digest, which has its own clause and its own message.
    mutant = dict(good)
    mutant["js_test_names_sha256"] = hashlib.sha256(b"").hexdigest()
    with pytest.raises(js_interface.ScenarioError) as exc:
        js_interface.assert_ran(mutant)
    assert "EMPTY" in str(exc.value)
