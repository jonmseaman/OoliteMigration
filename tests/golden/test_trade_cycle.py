"""Offline tests for scenario 004 - no game launch, no build required.

These exercise the parts of `trade_cycle.py` that can be reasoned about without a running Oolite:
the refusals that close vacuity routes, the leg arithmetic, and the untraded-goods control. The
LIVE behaviour is gated by the stored acceptance lines, which do launch the game.

NOTE ON MUTATION: every mutant below is a STRING built inside this test, applied to a THROWAWAY
COPY under the system temp directory. Nothing in the repo tree is ever edited, because a harness
that mutates in place is one timeout away from committing a sabotaged gate (bead oo-dto committed
`if False:` in place of the one predicate its scenario was named for).
"""

import json
import os
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import trade_cycle  # noqa: E402

SCENARIO = "004-trade-cycle"
PY = sys.executable


def _first(*candidates):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("none of %r exists" % (candidates,))


def golden_state():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
                  os.path.join(HERE, "pending", SCENARIO, "state.json"))


def golden_provenance():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
                  os.path.join(HERE, "pending", SCENARIO, "provenance.json"))


def golden_frame():
    return _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
                  os.path.join(HERE, "pending", SCENARIO, "frame.grid"))


@pytest.fixture(scope="module")
def spec():
    return trade_cycle.load_spec()


# --- the knobs are real, and the arithmetic closes ------------------------------------------------

def test_spec_cycle_is_asymmetric_and_closes(spec):
    assert spec["sell_units"] < spec["buy_units"], (
        "a symmetric cycle returns the purse, hold and market to their starting values, leaving a "
        "dump a run that never traded could also produce")
    assert spec["expected_cargo_after"] == spec["buy_units"] - spec["sell_units"]


def test_spec_credits_scale_is_the_measured_tenths(spec):
    assert spec["credits_scale"] == 10


# --- the refusals that close vacuity routes -------------------------------------------------------

def test_read_save_file_refuses_a_missing_save(tmp_path):
    with pytest.raises(trade_cycle.Refusal) as exc:
        trade_cycle.read_save_file(str(tmp_path / "nope.oolite-save"))
    assert "DOES NOT EXIST" in str(exc.value)


def test_read_save_file_refuses_a_stub(tmp_path):
    stub = tmp_path / "stub.oolite-save"
    stub.write_bytes(b"x" * 16)
    with pytest.raises(trade_cycle.Refusal) as exc:
        trade_cycle.read_save_file(str(stub))
    assert "byte floor" in str(exc.value)


def test_read_save_file_accepts_the_real_fixture(spec):
    plist, size = trade_cycle.read_save_file(trade_cycle.save_path(spec))
    assert size > trade_cycle.MIN_SAVE_BYTES
    assert str(plist.get("written_by_version")) == "1.75"
    # The fixture must be docked where this scenario says it is, or the market is a different one.
    assert plist.get("current_system_name") == spec["system_name"]


def test_grid_reader_refuses_a_wrong_sized_grid(tmp_path):
    bad = tmp_path / "short.grid"
    bad.write_bytes(b"\x00" * 100)
    with pytest.raises(trade_cycle.ScenarioError) as exc:
        trade_cycle._read_grid(str(bad))
    assert "luminance grid" in str(exc.value)


# --- the untraded-goods control -------------------------------------------------------------------

def test_untraded_changes_ignores_the_traded_good_and_reports_every_other():
    before = {"food": [17, 40, 127], "gold": [14, 396, 127], "furs": [24, 584, 127]}
    after = {"food": [12, 40, 127], "gold": [14, 396, 127], "furs": [23, 584, 127]}
    moved = trade_cycle.untraded_changes(before, after, "food")
    assert len(moved) == 1 and moved[0].startswith("furs:"), (
        "the traded good must be excluded and every other change reported; a control that also "
        "ignored furs would never notice a second carrier writing to this market")


def test_untraded_changes_is_empty_when_only_the_traded_good_moved():
    before = {"food": [17, 40, 127], "gold": [14, 396, 127]}
    after = {"food": [12, 40, 127], "gold": [14, 396, 127]}
    assert trade_cycle.untraded_changes(before, after, "food") == []


# --- assert_ran: the anti-vacuity gate, driven by mutated evidence ---------------------------------

def _evidence_from_golden():
    with open(golden_state(), "r", encoding="utf-8") as handle:
        return json.load(handle)["evidence"]


def test_assert_ran_passes_on_the_blessed_evidence(spec):
    assert trade_cycle.assert_ran(_evidence_from_golden(), spec) is True


@pytest.mark.parametrize("mutate,expect", [
    (lambda e: e.update(load_stages=e["load_stages"][:7]),
     "died partway"),
    (lambda e: e.update(load_stages=[]),
     "never loaded"),
    (lambda e: e.update(untraded_goods_changed=["gold: [14, 396, 127] -> [13, 396, 127]"]),
     "never traded changed"),
    (lambda e: e.update(cargo_after_cycle=0),
     "but the spec pins 2"),
    (lambda e: e.update(market_quantity_after=e["market_quantity_before"]),
     "unchanged across the whole cycle"),
    (lambda e: e.update(credits_after=e["credits_before"]),
     "purse is unchanged"),
    (lambda e: e.update(legs=[e["legs"][0]]),
     "buy leg followed by a sell"),
    (lambda e: e.update(tick_budget_met=False),
     "tick budget"),
    (lambda e: e.update(world_at_rest=False),
     "at rest"),
    (lambda e: e.update(untraded_goods_compared=1),
     "too small to mean anything"),
])
def test_assert_ran_rejects_a_mutated_evidence_block(spec, mutate, expect):
    """Each mutant is a failure this gate exists to catch; none may pass."""
    evidence = _evidence_from_golden()
    mutate(evidence)
    with pytest.raises(trade_cycle.ScenarioError) as exc:
        trade_cycle.assert_ran(evidence, spec)
    assert expect in str(exc.value), "wrong reason: %s" % exc.value


def test_assert_ran_rejects_an_empty_hold_even_when_the_spec_agrees(spec):
    """The empty-hold clause has its own test because the spec-agreement clause fires first.

    A spec that pinned expected_cargo_after=0 would satisfy the agreement check while describing a
    cycle whose end state is identical to a run that never traded; this clause is what refuses it.
    """
    evidence = _evidence_from_golden()
    evidence["cargo_after_cycle"] = 0
    permissive = dict(spec, expected_cargo_after=0)
    with pytest.raises(trade_cycle.ScenarioError) as exc:
        trade_cycle.assert_ran(evidence, permissive)
    assert "empty hold" in str(exc.value)


# --- the startup-probe retry: narrow on purpose -----------------------------------------------

class _FakeConsole:
    """Minimal stand-in: answers on the Nth ask, raising whatever is queued before that."""

    def __init__(self, failures, answer="true"):
        self.failures = list(failures)
        self.answer = answer
        self.asks = 0

    def evaluate(self, js, timeout=15):
        self.asks += 1
        if self.failures:
            raise self.failures.pop(0)
        return self.answer


def _console_error(text):
    sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))
    from console import ConsoleError
    return ConsoleError(text)


def test_startup_probe_reasks_after_a_stall_and_returns_the_answer(monkeypatch):
    monkeypatch.setattr(trade_cycle.time, "sleep", lambda _s: None)
    console = _FakeConsole([_console_error("no answer to 'x' within 15s")])
    assert trade_cycle.evaluate_settling(console, "x") == "true"
    assert console.asks == 2, "the stall must be re-asked exactly once, not swallowed"


def test_startup_probe_does_not_retry_a_dead_game(monkeypatch):
    """A dead game must fail in ONE window, not burn the whole retry budget."""
    monkeypatch.setattr(trade_cycle.time, "sleep", lambda _s: None)
    console = _FakeConsole([_console_error("Oolite exited with 3 mid-command")])
    with pytest.raises(Exception) as exc:
        trade_cycle.evaluate_settling(console, "x")
    assert "exited with 3" in str(exc.value)
    assert console.asks == 1, "a process death is an answer; retrying it hides the death"


def test_startup_probe_does_not_retry_a_js_error(monkeypatch):
    monkeypatch.setattr(trade_cycle.time, "sleep", lambda _s: None)
    console = _FakeConsole([_console_error("JS error evaluating 'x': ReferenceError")])
    with pytest.raises(Exception) as exc:
        trade_cycle.evaluate_settling(console, "x")
    assert "ReferenceError" in str(exc.value)
    assert console.asks == 1


def test_startup_probe_refuses_rather_than_hangs_when_it_never_settles(monkeypatch):
    monkeypatch.setattr(trade_cycle.time, "sleep", lambda _s: None)
    stalls = [_console_error("no answer to 'x' within 15s")
              for _ in range(trade_cycle.STARTUP_PROBE_TRIES)]
    console = _FakeConsole(stalls)
    with pytest.raises(trade_cycle.ScenarioError) as exc:
        trade_cycle.evaluate_settling(console, "x")
    assert "REFUSED rather than dumped" in str(exc.value)
    assert console.asks == trade_cycle.STARTUP_PROBE_TRIES, "the budget must be bounded"


def test_startup_retry_is_used_only_on_read_only_startup_probes():
    """The retry must not reach anything with a side effect: re-asking a trade would double it."""
    import ast
    tree = ast.parse(open(os.path.join(HERE, "trade_cycle.py"), encoding="utf-8").read())
    callers = set()
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef,)):
            continue
        for inner in ast.walk(node):
            if (isinstance(inner, ast.Call) and isinstance(inner.func, ast.Name)
                    and inner.func.id == "evaluate_settling"):
                callers.add(node.name)
    assert callers == {"assert_system"}, (
        "evaluate_settling() is called from %r; it may only be used by assert_system(), whose "
        "probes are read-only and run before the first write" % sorted(callers))


# --- the relaunch is narrow: only an unprobeable world, never a disagreeing measurement --------

def _relaunching_run(monkeypatch, outcomes):
    """Drive trade_cycle.run() with a fake run_once that yields `outcomes` in order."""
    calls = []

    def fake_run_once(*a, **kw):
        calls.append(1)
        item = outcomes.pop(0)
        if isinstance(item, Exception):
            raise item
        return item

    monkeypatch.setattr(trade_cycle, "run_once", fake_run_once)
    return calls


def test_run_relaunches_an_unprobeable_world_and_succeeds(monkeypatch, capsys):
    calls = _relaunching_run(monkeypatch, [
        trade_cycle.WorldNotProbeable("never answered"), {"ok": True}])
    assert trade_cycle.run("app", "out", {}, "root") == {"ok": True}
    assert len(calls) == 2
    assert "never became probeable" in capsys.readouterr().err, (
        "a run that needed two launches must SAY so, not look like a clean first try")


def test_run_does_not_relaunch_a_disagreeing_measurement(monkeypatch):
    """Relaunching until a measurement agrees is indistinguishable from having no gate."""
    calls = _relaunching_run(monkeypatch, [
        trade_cycle.ScenarioError("the purse is unchanged across the whole cycle"),
        {"ok": True}])
    with pytest.raises(trade_cycle.ScenarioError, match="purse is unchanged"):
        trade_cycle.run("app", "out", {}, "root")
    assert len(calls) == 1, "a failed assertion must propagate on the FIRST occurrence"


def test_run_gives_up_after_a_bounded_number_of_launches(monkeypatch):
    outcomes = [trade_cycle.WorldNotProbeable("never answered")
                for _ in range(trade_cycle.PROBEABLE_LAUNCH_ATTEMPTS + 2)]
    calls = _relaunching_run(monkeypatch, outcomes)
    with pytest.raises(trade_cycle.WorldNotProbeable):
        trade_cycle.run("app", "out", {}, "root")
    assert len(calls) == trade_cycle.PROBEABLE_LAUNCH_ATTEMPTS


def test_world_not_probeable_is_raised_from_exactly_one_place():
    """If it could be raised after a write, a relaunch could repeat a trade."""
    import ast
    tree = ast.parse(open(os.path.join(HERE, "trade_cycle.py"), encoding="utf-8").read())
    raisers = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        for inner in ast.walk(node):
            if (isinstance(inner, ast.Raise) and isinstance(inner.exc, ast.Call)
                    and isinstance(inner.exc.func, ast.Name)
                    and inner.exc.func.id == "WorldNotProbeable"):
                raisers.add(node.name)
    assert raisers == {"evaluate_settling"}, (
        "WorldNotProbeable is raised from %r; only evaluate_settling() may raise it, because only "
        "its probes run before the first write and are therefore safe to relaunch" % sorted(raisers))


def test_world_not_probeable_is_a_scenario_error():
    """It must still fail the run when the budget is spent - it is not a soft outcome."""
    assert issubclass(trade_cycle.WorldNotProbeable, trade_cycle.ScenarioError)


# --- teardown is not the run ------------------------------------------------------------------

class _ClosingConsole:
    def __init__(self, raises=None):
        self.raises = raises
        self.closed = 0
        self.killed = 0

        outer = self

        class _P:
            def kill(self_inner):
                outer.killed += 1
        self._proc = _P()

    def close(self):
        self.closed += 1
        if self.raises:
            raise self.raises


def test_shutdown_tolerates_a_reap_timeout_and_kills_the_corpse(capsys):
    """A killed process the OS has not yet reaped is a property of the box, not of the engine."""
    import subprocess as sp
    console = _ClosingConsole(sp.TimeoutExpired(cmd="oolite.exe", timeout=10))
    trade_cycle.shutdown(console)
    assert console.killed == 1, "the process must still be killed on the way out"
    assert "did not reap" in capsys.readouterr().err


def test_shutdown_reraises_anything_that_is_not_a_reap_timeout():
    console = _ClosingConsole(RuntimeError("socket exploded"))
    with pytest.raises(RuntimeError):
        trade_cycle.shutdown(console)


def test_a_failure_inside_the_run_is_not_masked_by_teardown():
    """try/finally, not `with console:` - and a failure in the block must still propagate."""
    import subprocess as sp
    console = _ClosingConsole(sp.TimeoutExpired(cmd="oolite.exe", timeout=10))
    with pytest.raises(ValueError, match="the real failure"):
        try:
            raise ValueError("the real failure")
        finally:
            trade_cycle.shutdown(console)
    assert console.closed == 1


def test_run_does_not_use_the_console_context_manager():
    """`with console:` would let __exit__'s teardown timeout replace a completed run's result."""
    import re
    src = open(os.path.join(HERE, "trade_cycle.py"), encoding="utf-8").read()
    assert not re.search(r"^\s*with console:", src, re.M), (
        "the run block must be try/finally with shutdown(), so a teardown timeout cannot turn a "
        "completed measurement into a failure - nor mask one")
    assert "shutdown(console)" in src


def test_teardown_note_is_not_written_into_the_dump():
    """How fast the box reaped a process must never reach the golden - it differs run to run."""
    with open(golden_state(), "r", encoding="utf-8") as handle:
        blob = handle.read()
    for token in ("did not reap", "TimeoutExpired", "teardown"):
        assert token not in blob


# --- the evidence checker, as a subprocess, on the stored golden -----------------------------------

def test_evidence_checker_passes_on_the_stored_golden():
    result = subprocess.run([PY, os.path.join(HERE, "check_trade_cycle_evidence.py"),
                             golden_state(), "--label", "stored golden"],
                            capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "proves a trade cycle" in result.stdout


def test_evidence_checker_rejects_a_dump_with_no_evidence_block(tmp_path):
    with open(golden_state(), "r", encoding="utf-8") as handle:
        dump = json.load(handle)
    dump.pop("evidence")
    victim = tmp_path / "no-evidence.json"
    victim.write_text(json.dumps(dump), encoding="utf-8")
    result = subprocess.run([PY, os.path.join(HERE, "check_trade_cycle_evidence.py"),
                             str(victim)], capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 1
    assert "no `evidence` block" in result.stderr


def test_evidence_checker_rejects_a_market_edited_away_from_the_evidence(tmp_path):
    """The canonical dump and its evidence block must agree: editing one alone is a red."""
    with open(golden_state(), "r", encoding="utf-8") as handle:
        dump = json.load(handle)
    good = dump["evidence"]["commodity"]
    dump["market"][good]["quantity"] += 1
    victim = tmp_path / "edited-market.json"
    victim.write_text(json.dumps(dump), encoding="utf-8")
    result = subprocess.run([PY, os.path.join(HERE, "check_trade_cycle_evidence.py"),
                             str(victim)], capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 1
    assert "edited alone" in result.stderr


# --- the golden is witnessed from OUTSIDE itself ---------------------------------------------------

def test_provenance_witnesses_the_golden_byte_for_byte():
    """A golden cannot witness itself (beads oo-3ya, oo-gxp).

    The digest and byte count live in provenance.json, a SEPARATE file, so a one-quantised-unit
    edit to state.json is visible - a golden-vs-copy comparison moves BOTH sides and cannot see it.
    """
    import hashlib
    blob = open(golden_state(), "rb").read()
    with open(golden_provenance(), "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    record = prov["artifacts"]["state.json"]
    assert len(blob) == record["bytes"]
    assert hashlib.sha256(blob).hexdigest() == record["sha256"]


def test_provenance_does_not_gate_the_frame_grid_byte_wise():
    """The deliberate asymmetry: the frame digest is RECORDED but must never be a predicate."""
    with open(golden_provenance(), "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    note = prov["artifacts"]["frame.grid"]["note"]
    assert "NEVER a gate predicate" in note
    assert prov["stability"]["distinct_frame_grid_digests"] > 1, (
        "if the frame grids had agreed across the sweep, this scenario would owe an explanation "
        "for why it does not byte-gate them")


def test_stability_claim_is_accounted_for_run_by_run():
    with open(golden_provenance(), "r", encoding="utf-8") as handle:
        stability = json.load(handle)["stability"]
    assert stability["runs"] >= 10
    assert stability["dumps_written"] + stability["refused"] == stability["runs"]
    assert stability["errored"] == 0
    assert len(stability["distinct_dump_digests"]) == 1
    assert len(stability["per_run"]) == stability["runs"]


def test_frame_grid_is_the_expected_size():
    import frame_hash
    assert len(trade_cycle._read_grid(golden_frame())) == frame_hash.GRID_CELLS


# --- the spec gate ---------------------------------------------------------------------------------

def test_spec_gate_passes():
    result = subprocess.run([PY, os.path.join(HERE, "gate_004_spec.py")],
                            capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.startswith("PASS:")


@pytest.mark.parametrize("knob,value,expect", [
    ("sell_units", 5, "asymmetric"),
    ("expected_cargo_after", 3, "arithmetic does not close"),
    ("credits_scale", 1, "TENTHS"),
    ("quant_decimals", 6, "Coarsening quantisation"),
])
def test_spec_gate_rejects_a_mutated_spec(tmp_path, knob, value, expect):
    """MUTATES A THROWAWAY COPY OF THE WHOLE TREE'S spec, never the repo file.

    The gate resolves its spec through SPEC_CANDIDATES, so the mutant is applied by running the
    gate with a patched module-level candidate tuple in a subprocess - the repo's spec.json is
    never touched, which is what makes this harness safe to harvest at any instant.
    """
    with open(trade_cycle.spec_path(), "r", encoding="utf-8") as handle:
        spec = json.load(handle)
    spec[knob] = value
    victim = tmp_path / "spec.json"
    victim.write_text(json.dumps(spec), encoding="utf-8")
    driver = tmp_path / "drive.py"
    driver.write_text(
        "import sys\n"
        "sys.path.insert(0, %r)\n"
        "import gate_004_spec as g\n"
        "g.SPEC_CANDIDATES = (%r,)\n"
        "sys.exit(g.main())\n" % (HERE, str(victim)), encoding="utf-8")
    result = subprocess.run([PY, str(driver)], capture_output=True, text=True, cwd=REPO_ROOT)
    assert result.returncode == 1, result.stdout + result.stderr
    assert expect in result.stderr, "wrong reason: %s" % result.stderr
