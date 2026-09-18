"""Offline falsifiability tests for scenario 001-launch-dock (bead oo-jor). No game, no build.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game twice. That is the only part that can
observe real engine behaviour, and it is also the flakiest and slowest thing on this box, so it
is ONE acceptance line. Everything that can be falsified without a launch is falsified here, where
it costs about a second and cannot be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration - and this suite already caught two of
its own: an evidence check that read a JS function object as a number (always false), and a pause
whose refusal was never checked.

Nothing here writes to goldens/. The stored golden is READ, copied to a throwaway temp file, and
mutated there.
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
GOLDEN = os.path.join(REPO_ROOT, "goldens", "windows-x64", "001-launch-dock", "state.json")
SPEC = os.path.join(HERE, "scenarios", "001-launch-dock", "spec.json")
EVIDENCE = os.path.join(HERE, "check_launch_dock_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "launch_dock.py")

sys.path.insert(0, HERE)


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
    path = tempfile.mkdtemp(prefix="oo_jor_test_")
    yield path
    shutil.rmtree(path, ignore_errors=True)


def write(scratch, name, data):
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    return path


# --- the stored golden is itself real ------------------------------------------------------

def test_the_stored_golden_carries_launch_and_dock_evidence():
    """The green direction. If this fails, every other test here is measuring a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "launched" in out and "docked" in out, out


def test_the_stored_golden_is_not_a_paused_photograph(golden):
    """The evidence block must show a real flight, not scenario 001's pause-and-spawn shape."""
    ev = golden["evidence"]
    assert ev["launch_events"] >= 1 and ev["dock_events"] >= 1, ev
    assert ev["undocked_seen"] is True, ev
    assert ev["ticks"] >= 1 and ev["tick_budget_met"] is True, ev


def test_the_golden_names_its_own_producer():
    """provenance.dump_tool must name launch_dock.py, not run_dump.py.

    bless_golden.py hardcoded 'tests/golden/dump/run_dump.py' before this bead. A provenance that
    confidently names the wrong producer is worse than none: the next reader cannot reproduce the
    golden and has no reason to doubt the file.
    """
    prov = os.path.join(os.path.dirname(GOLDEN), "provenance.json")
    with open(prov, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    assert data["dump_tool"].endswith("launch_dock.py"), data["dump_tool"]
    assert data["quant_decimals"] == 3, data


# --- the evidence checker can go red -------------------------------------------------------

@pytest.mark.parametrize("field", ["launch_events", "dock_events"])
def test_a_zeroed_engine_event_counter_is_rejected(golden, scratch, field):
    """MUTANT: the scenario crashed before that half ran. Byte-identical twice, proves nothing."""
    golden["evidence"][field] = 0
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert field in out and "0" in out, out


def test_a_run_that_never_left_the_station_is_rejected(golden, scratch):
    """MUTANT: docked the whole time - the docked flag never read false."""
    golden["evidence"]["undocked_seen"] = False
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "undocked_seen" in out, out


def test_a_run_that_did_not_meet_its_tick_budget_is_rejected(golden, scratch):
    """MUTANT: the tick count was cut - the simulation never ran the pinned budget."""
    golden["evidence"]["tick_budget_met"] = False
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "tick_budget_met" in out, out


def test_a_dump_with_no_evidence_block_at_all_is_rejected(golden, scratch):
    """MUTANT: a scenario-001-style dump, which has no evidence block. It must not pass this gate
    merely by being a valid, non-vacuous, on-policy dump."""
    del golden["evidence"]
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "evidence" in out, out


def test_a_dump_that_ends_undocked_is_rejected(golden, scratch):
    """MUTANT: the dock step was skipped (launch_dock.py --break-dock's signature)."""
    golden["player"]["ship"]["docked"] = False
    golden["evidence"]["docked_at_end"] = False
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "docked" in out, out


def test_a_dump_taken_with_the_populator_still_running_is_rejected(golden, scratch):
    """MUTANT: a dump from before the populator was suppressed.

    The populator both adds traffic and consumes a per-run-variable number of RANROT draws, so a
    dump taken with it running may be reproducible by luck rather than by construction. The field
    must be PRESENT (a value of 0 is legitimate; absence is not).
    """
    del golden["evidence"]["populators_suppressed"]
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "populators_suppressed" in out, out


def test_the_scenario_switches_the_populator_off_at_the_source():
    """Option (b), and it is reachable from the scripting seam - not a workaround.

    system.populatorSettings is read-only (OOJSSystem.m:170) and system.setPopulator(key, null)
    deletes a setting (OOJSSystem.m:1311 -> [UNIVERSE setPopulatorSetting:key to:nil]). Clearing
    ships before the dump treats the symptom; this removes the cause, so the FLIGHT is quiet too.
    """
    src = open(SCRIPT, encoding="utf-8").read()
    assert "setPopulator" in src, "launch_dock.py never suppresses the system populator"
    assert "populatorSettings" in src, (
        "launch_dock.py does not re-read populatorSettings, so an ineffective suppression would "
        "pass unnoticed")


def test_the_scenario_does_not_fake_ship_velocities():
    """A spawned ship under thrust reports a velocity no JS write can clear.

    ShipEntity.m:12830-12833 defines -velocity as [super velocity] + [self thrustVector], so the
    JS setter reaches only the Newtonian half. An earlier version wrote zeros over every ship and
    the golden then carried those zeros as if measured. The scenario must ASSERT the world is at
    rest, not declare it.
    """
    src = open(SCRIPT, encoding="utf-8").read()
    assert "s[i].velocity = [0, 0, 0]" not in src, (
        "launch_dock.py still writes zero velocities over ships; that value cannot be made to "
        "stick and would be stored in the golden as if it had been measured")
    assert "magnitude()" in src, (
        "launch_dock.py does not CALL velocity.magnitude(); as a bare property it is a function "
        "object and the comparison is always false")


def test_a_collapsed_dump_is_rejected(golden, scratch):
    """MUTANT: the world emptied. Two empty dumps agree perfectly."""
    golden["entities"] = []
    golden["market"] = {}
    rc, out = run(EVIDENCE, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "entities" in out or "market" in out, out


def test_the_dock_evidence_is_defended_in_more_than_one_place(golden, scratch, tmp_path):
    """dock_events >= 1 must survive the loss of ANY SINGLE defence in the checker.

    This exists because of a mutation result that looked like a hole and was not. Dropping
    dock_events from REQUIRED_POSITIVE left the gate green - not because the gate is blind, but
    because a dedicated clause still names the engine event, so the property was never removed
    (an EQUIVALENT mutant). That redundancy is deliberate for the single most important property
    in this bead, and it is pinned here so a future refactor that collapses the two clauses into
    one has to do it knowingly.

    The test mutates a COPY of the checker in a temp dir and runs it - the real file is untouched.
    """
    src = open(EVIDENCE, encoding="utf-8").read()
    defences = [
        'REQUIRED_POSITIVE = ("launch_events", "dock_events", "ticks")',
        '    if ev.get("dock_events", 0) < 1:',
    ]
    for d in defences:
        assert d in src, "the checker no longer contains the defence %r" % d[:50]

    golden["evidence"]["dock_events"] = 0
    bad = write(scratch, "nodock.json", golden)

    # Each defence alone must still reject the bad input.
    for i, drop in enumerate(defences):
        mutated = src.replace(drop, "pass  # mutant\n" if drop.startswith("    if") else
                              'REQUIRED_POSITIVE = ("ticks",)  # mutant', 1)
        path = str(tmp_path / ("checker%d.py" % i))
        with open(path, "w", encoding="utf-8", newline="\n") as h:
            h.write(mutated)
        rc, out = run(path, bad)
        assert rc == 1, (
            "with defence %d removed the checker ACCEPTED dock_events=0 (rc=%d). The property is "
            "then held by a single line, so the redundancy this test pins is gone.\n%s"
            % (i, rc, out))


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 is 'I cannot tell you', never 'they match' - golden_diff's convention."""
    rc, _ = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2


# --- golden_diff still discriminates one quantised unit ON THIS golden -----------------------

def test_one_quantised_unit_of_position_is_reported(golden, scratch):
    """MUTANT: perturb one field by exactly one quantised unit (0.001) in a THROWAWAY COPY.

    This is the property the whole byte-identical claim rests on: if a 1 mm move is invisible, the
    goldens are decoration. Run against THIS scenario's golden, not oo-ss8's, because a scenario
    with different content can have a different float profile.
    """
    ent = golden["entities"][0]
    before = ent["position"][0]
    ent["position"][0] = round(before + 0.001, 3)
    assert ent["position"][0] != before
    mutant = write(scratch, "mutant.json", golden)
    rc, out = run(DIFF, GOLDEN, mutant)
    assert rc == 1, out
    assert "position[0]" in out, out
    assert repr(before) in out or str(before) in out, out


def test_a_changed_evidence_field_is_reported_by_the_diff(golden, scratch):
    """The evidence block is IN the golden, so a run that skipped the dock fails the ordinary
    byte comparison too - not only the dedicated checker."""
    golden["evidence"]["dock_events"] = 0
    rc, out = run(DIFF, GOLDEN, write(scratch, "mutant.json", golden))
    assert rc == 1, out
    assert "dock_events" in out, out


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
        json.dump({"quant_decimals": 0, "platform": "windows-x64",
                   "scenario": "001-launch-dock"}, handle)
    other = write(scratch, "other.json", golden)
    rc, out = run(DIFF, state, other)
    assert rc == 2, out
    assert "uantisation" in out, out


# --- the scenario script's own knobs ---------------------------------------------------------

def test_the_spec_pins_every_determinism_knob():
    with open(SPEC, "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "pose"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1


def test_the_script_reads_the_spec_rather_than_hardcoding_it():
    """A knob the script never reads is decoration; the spec would drift silently."""
    src = open(SCRIPT, encoding="utf-8").read()
    for key in ("seed", "system_id", "ticks", "tick_seconds"):
        assert 'spec["%s"]' % key in src, "launch_dock.py never reads spec[%r]" % key


def test_the_script_checks_that_the_pause_actually_took():
    """pauseGame() returns NO on several GUI screens (OOJSGlobal.m:843-848) and a silent refusal
    leaves the world integrating through the dump. Measured: it is what made three runs disagree
    on 12 velocity fields."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert 'console.evaluate("pauseGame()").strip().lower() != "true"' in src, (
        "launch_dock.py does not check pauseGame()'s return value")
    assert "clock_before" in src and "clock_after" in src, (
        "launch_dock.py does not verify the game clock stopped after the pause")


def test_the_scenario_asserts_its_system():
    src = open(SCRIPT, encoding="utf-8").read()
    assert "system.ID" in src, "launch_dock.py never checks which system it is in"


def test_assert_flew_rejects_each_missing_half():
    """The in-process assertion, exercised directly rather than through a game."""
    import launch_dock

    good = {"undocked_seen": True, "launch_events": 1, "dock_events": 1, "docked_at_end": True,
            "tick_budget_met": True, "game_seconds_budget": 3.0, "ticks": 24,
            "populators_suppressed": 36}
    launch_dock.assert_flew(dict(good))  # green

    for field, bad in (("undocked_seen", False), ("launch_events", 0), ("dock_events", 0),
                       ("docked_at_end", False), ("tick_budget_met", False)):
        mutant = dict(good)
        mutant[field] = bad
        with pytest.raises(launch_dock.ScenarioError) as exc:
            launch_dock.assert_flew(mutant)
        assert field in str(exc.value), (field, str(exc.value))
