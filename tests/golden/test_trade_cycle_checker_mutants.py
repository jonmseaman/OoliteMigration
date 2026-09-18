"""CHECKER-WEAKENING mutants for scenario 004's evidence checker AND its live gate (bead oo-xy0o).

THE MEASURED HOLE THIS MODULE CLOSES
------------------------------------
A reviewer of bead oo-zv2 replaced single clauses of check_trade_cycle_evidence.py with
`if False:` and the scenario's own suite still reported "47 passed" for every one of:

    :93  the cash-consistency clause (credits moved by exactly price*units/credits_scale)
    :102 market_delta          :113 used_delta          :119 hold_delta == -market_delta
    :214 the untraded `if changed:`                     :220 the untraded-control-size clause

and, worse because the coverage there is UNEVEN rather than absent, trade_cycle.py:666 - the
assert_ran clause asserting that the BUY LEG COSTS MONEY AND THE SELL LEG PAYS IT. Disabling its
neighbours (:670 cargo_after_cycle, :688 untraded_goods_changed) each gave "1 failed, 46 passed";
:666, precisely the predicate distinguishing a genuine buy/sell pair from two legs moving money
the same direction, passed clean.

Every arm below is bead oo-ghhw's pattern (tests/golden/test_cloaking_load.py):

  1. the UNMUTATED validator must REFUSE the input the clause exists to reject - otherwise the
     mutant registers a false kill against an already-red validator (bead oo-4vdc);
  2. a THROWAWAY copy with exactly ONE clause replaced by `if False:` must now ACCEPT it.

Where a clause is redundantly defended, the redundancy is recorded as a MISKILL arm rather than
banked as a kill it did not earn.

WHY THIS MODULE SKIPS RATHER THAN FAILS WHEN SCENARIO 004 IS ABSENT
-------------------------------------------------------------------
Scenario 004's script, checker and staged artefacts land with bead oo-zv2 and may not be in the
tree yet. A mutation suite that hard-failed on their absence would be noise on every unrelated
branch; one that silently passed would be worse. So the module SKIPS with a message naming what is
missing, and `test_the_scenario_004_files_are_either_all_present_or_all_absent` refuses the
halfway state in which a partial landing would quietly disable these arms.

Nothing in the repo is written to: sources are read and mutated into pytest's tmp_path.
"""

import copy
import json
import os
import shutil
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "004-trade-cycle"

CHECKER = os.path.join(HERE, "check_trade_cycle_evidence.py")
SCRIPT = os.path.join(HERE, "trade_cycle.py")
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)


def _first(candidates):
    for path in candidates:
        if os.path.isfile(path):
            return path
    return None


SPEC_PATH = _first(SPEC_CANDIDATES)
GOLDEN_PATH = _first(GOLDEN_CANDIDATES)
PRESENT = [os.path.isfile(CHECKER), os.path.isfile(SCRIPT),
           SPEC_PATH is not None, GOLDEN_PATH is not None]


@pytest.fixture(autouse=True)
def _requires_scenario_004(request):
    """Skip every arm except the half-landed guard when scenario 004 is not in this tree.

    A module-level `pytestmark` would silence the guard too, and the guard is the one test that
    MUST run on every branch: it is what refuses the halfway state in which these arms quietly
    stop running.
    """
    if request.node.get_closest_marker("runs_without_scenario_004"):
        return
    if not all(PRESENT):
        pytest.skip("scenario 004 (checker=%r script=%r spec=%r golden=%r) is not in this tree; "
                    "its artefacts land with bead oo-zv2" % tuple(PRESENT))


@pytest.mark.runs_without_scenario_004
def test_the_scenario_004_files_are_either_all_present_or_all_absent():
    """A PARTIAL landing is the dangerous state: with the checker present but its golden missing
    every mutant arm below would skip, and the suite would report green while testing nothing."""
    assert len(set(PRESENT)) == 1, (
        "scenario 004 is half-landed (checker=%r script=%r spec=%r golden=%r). Until all four "
        "exist the checker-weakening arms in this module cannot run, and a checker whose mutants "
        "cannot run is a checker nobody validates." % tuple(PRESENT))


# ------------------------------------------------------------------------------------------
# helpers
# ------------------------------------------------------------------------------------------

@pytest.fixture(scope="module")
def golden():
    if GOLDEN_PATH is None:
        pytest.skip("no scenario 004 golden in this tree")
    with open(GOLDEN_PATH, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture(scope="module")
def spec():
    if SPEC_PATH is None:
        pytest.skip("no scenario 004 spec.json in this tree")
    with open(SPEC_PATH, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _weaken(src, clauses, what):
    for clause in clauses:
        count = src.count(clause)
        assert count == 1, (
            "the clause %r matches %s %d time(s), not once: it was refactored and this mutant is "
            "stale. A stale mutant silently stops testing anything." % (clause, what, count))
        src = src.replace(clause, "if False:")
    return src


# --- the evidence checker -------------------------------------------------------------------

def mutated_checker(tmp_path, clauses, name="chk"):
    """A throwaway tree carrying the mutated checker AND the spec.json it resolves relative to
    its own __file__ - a mutant dropped anywhere else exits 2 for a reason that has nothing to do
    with the mutation, and an rc!=0 assertion would read that as a kill."""
    with open(CHECKER, "r", encoding="utf-8") as handle:
        src = _weaken(handle.read(), clauses, "check_trade_cycle_evidence.py")
    root = tmp_path / name
    staged = root / "tests" / "golden" / "pending" / SCENARIO
    staged.mkdir(parents=True, exist_ok=True)
    shutil.copy(SPEC_PATH, str(staged / "spec.json"))
    target = root / "tests" / "golden" / "check_trade_cycle_evidence.py"
    target.write_text(src, encoding="utf-8", newline="\n")
    return str(target)


def run_checker(tmp_path, dump, checker=CHECKER, name="dump.json"):
    path = tmp_path / name
    path.write_text(json.dumps(dump, sort_keys=True), encoding="utf-8")
    return subprocess.run([sys.executable, checker, str(path), "--label", "mutant"],
                          capture_output=True, text=True)


def assert_checker_kill(tmp_path, clause_name, clauses, bad):
    baseline = run_checker(tmp_path, bad)
    assert baseline.returncode == 1, (
        "the UNMUTATED checker did not REFUSE (rc=1) the input that %s exists to reject; rc=2 is "
        "a structural error rather than a verdict and the mutant below would register a false "
        "kill (bead oo-4vdc).\n%s%s" % (clause_name, baseline.stdout, baseline.stderr))
    mutated = run_checker(tmp_path, bad, checker=mutated_checker(tmp_path, clauses))
    assert mutated.returncode == 0, (
        "MISKILL: weakening %s did NOT make the checker accept the input it exists to reject, so "
        "that clause is not what rejects it - the mutant is EQUIVALENT or the property has a "
        "second, unpinned defence (bead oo-jor).\n%s%s"
        % (clause_name, mutated.stdout, mutated.stderr))


# --- the live gate (trade_cycle.assert_ran) -------------------------------------------------

# assert_ran is a pure function of (evidence, spec), so it can be driven entirely offline. The
# driver imports a MUTATED COPY of trade_cycle.py by path and reports the verdict as an exit code,
# giving the gate the same rc=1/rc=0 shape as the checker.
GATE_DRIVER = """import importlib.util
import json
import sys

module_path, evidence_path, spec_path = sys.argv[1:4]
with open(spec_path, "r", encoding="utf-8") as handle:
    spec = json.load(handle)
with open(evidence_path, "r", encoding="utf-8") as handle:
    evidence = json.load(handle)
loader = importlib.util.spec_from_file_location("trade_cycle_mutant", module_path)
module = importlib.util.module_from_spec(loader)
loader.loader.exec_module(module)
try:
    module.assert_ran(evidence, spec)
except module.ScenarioError as exc:
    sys.stderr.write("REJECTED: %s\\n" % exc)
    raise SystemExit(1)
print("ACCEPTED")
"""


def _gate_env():
    env = dict(os.environ)
    env["PYTHONPATH"] = os.pathsep.join([
        HERE, os.path.join(HERE, "dump"),
        os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"),
        env.get("PYTHONPATH", "")]).rstrip(os.pathsep)
    return env


def run_gate(tmp_path, evidence, spec, clauses=(), tag="g"):
    with open(SCRIPT, "r", encoding="utf-8") as handle:
        src = _weaken(handle.read(), clauses, "trade_cycle.py")
    module = tmp_path / ("trade_cycle_%s.py" % tag)
    module.write_text(src, encoding="utf-8", newline="\n")
    driver = tmp_path / "gate_driver.py"
    driver.write_text(GATE_DRIVER, encoding="utf-8", newline="\n")
    ev_path = tmp_path / ("evidence_%s.json" % tag)
    ev_path.write_text(json.dumps(evidence), encoding="utf-8")
    spec_path = tmp_path / ("spec_%s.json" % tag)
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    return subprocess.run([sys.executable, str(driver), str(module), str(ev_path),
                           str(spec_path)], capture_output=True, text=True, env=_gate_env())


def assert_gate_kill(tmp_path, clause_name, clauses, evidence, spec):
    baseline = run_gate(tmp_path, evidence, spec, tag="base")
    assert baseline.returncode == 1, (
        "the UNMUTATED gate did not REFUSE the evidence that %s exists to reject; the mutant "
        "below would register a false kill.\n%s%s"
        % (clause_name, baseline.stdout, baseline.stderr))
    mutated = run_gate(tmp_path, evidence, spec, clauses=clauses, tag="mut")
    assert mutated.returncode == 0, (
        "MISKILL: weakening %s did NOT make assert_ran accept the evidence it exists to reject - "
        "the mutant is EQUIVALENT or the property is redundantly defended (bead oo-jor).\n%s%s"
        % (clause_name, mutated.stdout, mutated.stderr))


def ev(golden, **changes):
    dump = copy.deepcopy(golden)
    dump["evidence"].update(changes)
    return dump


def leg(golden, index, **changes):
    dump = copy.deepcopy(golden)
    dump["evidence"]["legs"][index].update(changes)
    return dump


# ============================================================================================
# BASELINES
# ============================================================================================

def test_the_blessed_golden_passes_its_own_checker():
    result = subprocess.run([sys.executable, CHECKER, GOLDEN_PATH, "--label", "golden"],
                            capture_output=True, text=True)
    assert result.returncode == 0, "baseline is RED:\n%s%s" % (result.stdout, result.stderr)


def test_an_unmutated_copy_of_the_checker_still_passes(tmp_path, golden):
    assert run_checker(tmp_path, golden, checker=mutated_checker(tmp_path, ())).returncode == 0


def test_the_unmutated_gate_accepts_the_blessed_evidence(tmp_path, golden, spec):
    result = run_gate(tmp_path, golden["evidence"], spec, tag="sane")
    assert result.returncode == 0, "the gate baseline is RED:\n%s%s" % (result.stdout,
                                                                       result.stderr)


def test_a_stale_clause_is_a_loud_failure_not_a_silent_pass(tmp_path):
    with pytest.raises(AssertionError) as exc:
        mutated_checker(tmp_path, ("if a_refactor_deleted_this:",))
    assert "stale" in str(exc.value)


# ============================================================================================
# CHECKER MUTANTS - the six clauses measured as silently deletable, plus their neighbours
# ============================================================================================

def test_the_cash_consistency_clause_is_load_bearing(tmp_path, golden):
    """check_trade_cycle_evidence.py:93 IN THE REVIEWER'S MEASUREMENT. The purse must move by
    EXACTLY price*units/credits_scale; PlayerEntity stores credits in TENTHS and this clause is
    what would say so if the engine changed that scale, rather than the golden absorbing it."""
    buy = golden["evidence"]["legs"][0]
    assert_checker_kill(tmp_path, "the cash-consistency clause",
                        ("if abs(got_cash - (-sign * expected_cash)) > 0.0005:",),
                        leg(golden, 0, credits_after=buy["credits_before"] - 1.0))


def test_the_engine_recomputed_cargo_space_clause_is_load_bearing(tmp_path, golden):
    """:113 IN THE MEASUREMENT, and the strongest clause in the file: cargoSpaceUsed is NOT
    written by the scenario - -calculateCurrentCargo recomputes it from the hold after the
    manifest write - so a disagreement means the write was clamped or dropped and the goods never
    reached the ship."""
    buy = golden["evidence"]["legs"][0]
    assert_checker_kill(tmp_path, "the used_delta clause", ("if used_delta != sign * units:",),
                        leg(golden, 0,
                            cargo_space_used_after=buy["cargo_space_used_before"]))


def test_the_untraded_goods_clause_is_load_bearing(tmp_path, golden):
    """:214 IN THE MEASUREMENT. A good this scenario never traded that MOVED means the market has
    another carrier, so the observable is shared and the gate is a race rather than a measurement
    (bead oo-rkm). With the clause gone that finding disappears silently."""
    assert_checker_kill(tmp_path, "the untraded-goods clause", ("if changed:",),
                        ev(golden, untraded_goods_changed=[
                            "gold: [14, 396, 127] -> [13, 396, 127]"]))


def test_the_untraded_control_size_clause_is_load_bearing(tmp_path, golden):
    """:220 IN THE MEASUREMENT. A SHORTENED CONTROL is the vacuity route wearing a smaller hat:
    with nothing to compare, "nothing else moved" is free."""
    assert_checker_kill(tmp_path, "the untraded-control-size clause",
                        ("if compared != MARKET_GOODS - 1:",),
                        ev(golden, untraded_goods_compared=1))


def test_the_leg_side_clause_is_load_bearing(tmp_path, golden):
    """A trade CYCLE is a buy followed by a sell; two legs in the same direction are not a
    cycle."""
    assert_checker_kill(tmp_path, "the leg-side clause", ('if leg.get("side") != side:',),
                        leg(golden, 0, side="sell"))


def test_the_leg_unit_count_clause_is_load_bearing(tmp_path, golden):
    assert_checker_kill(tmp_path, "the leg unit-count clause",
                        ('if leg.get("units") != units:',), leg(golden, 0, units=99))


def test_the_cargo_after_cycle_clause_is_load_bearing(tmp_path, golden):
    """THE RE-BLESS ARM. Editing the evidence field alone trips the clause further down that
    requires the canonical dump's own manifest to agree (measured: MISKILL). Moving BOTH is what a
    maintainer re-blessing the golden produces, and then the ONLY thing standing between them and
    a hold that no longer matches the spec is this clause."""
    bad = ev(golden, cargo_after_cycle=99)
    commodity = bad["evidence"]["commodity"]
    for row in bad["player"]["cargo"]:
        if row["commodity"] == commodity:
            row["quantity"] = 99
    assert_checker_kill(tmp_path, "the cargo_after_cycle-vs-spec clause",
                        ('if evidence.get("cargo_after_cycle") != '
                         'int(spec["expected_cargo_after"]):',), bad)


def test_the_whole_cycle_cash_accounting_clause_is_load_bearing(tmp_path, golden):
    """MONEY ENTERED OR LEFT THE PURSE OUTSIDE THE TRADE. Re-blessed the same way: the canonical
    dump's player.credits is moved with the evidence, so only this clause can fire."""
    bad = ev(golden, credits_after=round(golden["evidence"]["credits_after"] + 10.0, 3))
    bad["player"]["credits"] = bad["evidence"]["credits_after"]
    assert_checker_kill(tmp_path, "the whole-cycle cash-accounting clause",
                        ("if abs(net - round(sell_cash - buy_cash, 3)) > 0.0005:",), bad)


def test_the_whole_cycle_market_accounting_clause_is_load_bearing(tmp_path, golden):
    bad = ev(golden, market_quantity_after=golden["evidence"]["market_quantity_before"] + 40)
    bad["market"][bad["evidence"]["commodity"]]["quantity"] = \
        bad["evidence"]["market_quantity_after"]
    assert_checker_kill(tmp_path, "the whole-cycle market-accounting clause",
                        ('if market_net != int(spec["sell_units"]) - int(spec["buy_units"]):',),
                        bad)


def test_the_legs_are_consecutive_in_the_hold(tmp_path, golden, spec):
    """THE WHOLE SELL LEG IS SHIFTED so its own deltas stay correct; only the clause tying the
    sell leg's starting hold to the buy leg's finishing hold can then fire. Editing hold_before
    alone breaks the leg's own hold_delta and is caught by a neighbour (measured: MISKILL)."""
    bad = copy.deepcopy(golden)
    sell = bad["evidence"]["legs"][1]
    sell["hold_before"] = 999
    sell["hold_after"] = 999 - int(spec["sell_units"])
    assert_checker_kill(tmp_path, "the consecutive-hold clause",
                        ('if legs[1]["hold_before"] != legs[0]["hold_after"]:',), bad)


def test_the_legs_are_consecutive_in_the_market(tmp_path, golden, spec):
    """The same shift on the market side: something moved this market BETWEEN the legs, so this
    scenario is not its only carrier."""
    bad = copy.deepcopy(golden)
    sell = bad["evidence"]["legs"][1]
    sell["market_quantity_before"] = 999
    sell["market_quantity_after"] = 999 + int(spec["sell_units"])
    assert_checker_kill(tmp_path, "the consecutive-market clause",
                        ('if legs[1]["market_quantity_before"] != '
                         'legs[0]["market_quantity_after"]:',), bad)


# ============================================================================================
# THE MISKILLS, MEASURED AND RECORDED RATHER THAN BANKED
# ============================================================================================

GOODS_TRIANGLE = ("if market_delta != -sign * units:",
                  "if hold_delta != sign * units:",
                  "if hold_delta != -market_delta:")


def _goods_from_nowhere(golden, spec):
    """A buy leg in which the hold AND the market both move UP: goods appearing from nowhere."""
    bad = copy.deepcopy(golden)
    buy, sell = bad["evidence"]["legs"]
    buy["market_quantity_after"] = buy["market_quantity_before"] + int(spec["buy_units"])
    sell["market_quantity_before"] = buy["market_quantity_after"]
    sell["market_quantity_after"] = buy["market_quantity_after"] + int(spec["sell_units"])
    return bad


@pytest.mark.parametrize("clause", [
    pytest.param("if market_delta != -sign * units:", id="market_delta"),
    pytest.param("if hold_delta != -market_delta:", id="goods_conservation"),
])
def test_the_goods_conservation_clauses_defend_each_other(tmp_path, golden, spec, clause):
    """MEASURED MISKILL, kept because the redundancy is the point.

    market_delta, hold_delta and hold_delta == -market_delta are THREE clauses over TWO numbers:
    any two of them imply the third, so no single one can be isolated - deleting one leaves the
    other two rejecting. That is a genuinely redundant defence, not a survivor to be explained
    away, and this arm PINS it: if a refactor ever reduced the triangle to a single line, this
    test goes red and says the conservation property just became one line deep.
    """
    result = run_checker(tmp_path, _goods_from_nowhere(golden, spec),
                         checker=mutated_checker(tmp_path, (clause,)))
    assert result.returncode == 1, (
        "with %r removed, a leg whose hold AND market both moved UP - goods appearing from "
        "nowhere - was ACCEPTED. The conservation property is now held by that one line.\n%s%s"
        % (clause, result.stdout, result.stderr))


def test_removing_the_whole_conservation_triangle_lets_goods_appear_from_nowhere(
        tmp_path, golden, spec):
    """THE NON-VACUITY PROOF for the triangle as a whole: with all three clauses cut, a leg that
    created goods out of nothing is ACCEPTED (rc=0). That is what proves these clauses - and not
    some neighbour - are what stands between scenario 004 and a vacuous green."""
    bad = _goods_from_nowhere(golden, spec)
    baseline = run_checker(tmp_path, bad)
    assert baseline.returncode == 1, baseline.stdout + baseline.stderr
    result = run_checker(tmp_path, bad, checker=mutated_checker(tmp_path, GOODS_TRIANGLE))
    assert result.returncode == 0, (
        "MISKILL: with every goods-conservation clause removed the impossible leg was STILL "
        "rejected, so something else caught it.\n%s%s" % (result.stdout, result.stderr))


ZERO_CASH_CLAUSES = ("if not isinstance(price, int) or price <= 0:",
                     "if abs(got_cash - (-sign * expected_cash)) > 0.0005:",
                     "if got_cash == 0:")


def _free_trade(golden, spec):
    """A buy leg priced at ZERO that moved no money, with the whole-cycle arithmetic kept
    consistent so only the per-leg clauses can object."""
    bad = copy.deepcopy(golden)
    buy, sell = bad["evidence"]["legs"]
    buy["price"] = 0
    buy["credits_after"] = buy["credits_before"]
    sell["credits_before"] = buy["credits_after"]
    sell["credits_after"] = round(sell["credits_before"] + sell["price"]
                                  * int(spec["sell_units"]) / float(spec["credits_scale"]), 3)
    bad["evidence"]["credits_after"] = sell["credits_after"]
    bad["player"]["credits"] = sell["credits_after"]
    return bad


def test_the_zero_price_clauses_defend_each_other(tmp_path, golden, spec):
    """MEASURED MISKILL. A good priced 0 moves the purse by 0, so "the money moved" would be
    unfalsifiable - and THREE clauses reject it: price > 0, the cash equality, and got_cash == 0.
    Cutting the first two still leaves the third rejecting, so no kill is claimed for them
    individually; the arm below shows the trio as a whole is load-bearing."""
    result = run_checker(tmp_path, _free_trade(golden, spec),
                         checker=mutated_checker(tmp_path, ZERO_CASH_CLAUSES[:2]))
    assert result.returncode == 1, (
        "with the price and cash-equality clauses removed, a ZERO-PRICED leg that moved no money "
        "was ACCEPTED; the survivor clause is gone too.\n%s%s" % (result.stdout, result.stderr))
    assert "no money at all" in result.stderr


def test_removing_every_zero_price_clause_lets_a_free_trade_through(tmp_path, golden, spec):
    bad = _free_trade(golden, spec)
    baseline = run_checker(tmp_path, bad)
    assert baseline.returncode == 1, baseline.stdout + baseline.stderr
    result = run_checker(tmp_path, bad, checker=mutated_checker(tmp_path, ZERO_CASH_CLAUSES))
    assert result.returncode == 0, (
        "MISKILL: with every zero-price clause removed a leg that traded for free was STILL "
        "rejected.\n%s%s" % (result.stdout, result.stderr))


# ============================================================================================
# THE LIVE GATE - trade_cycle.assert_ran, including the clause the measurement found unguarded
# ============================================================================================

DIRECTION_CLAUSE = ('if legs[0]["credits_delta"] >= 0 or legs[1]["credits_delta"] <= 0:')


def test_the_gate_leg_direction_clause_is_load_bearing(tmp_path, golden, spec):
    """trade_cycle.py:666, THE CLAUSE THE REVIEWER MEASURED AS COMPLETELY UNGUARDED: disabling it
    gave "47 passed" while its neighbours each gave "1 failed, 46 passed".

    The input is a pair of legs still LABELLED buy and sell, trading the right unit counts, but
    both moving money in the SAME direction - which is what a run that bought twice, or that
    recorded the sell as a second purchase, produces. Nothing else in the gate can tell that apart
    from a genuine cycle; this clause can, and now the suite says so.
    """
    evidence = copy.deepcopy(golden["evidence"])
    evidence["legs"][1]["credits_delta"] = -abs(evidence["legs"][1]["credits_delta"])
    assert_gate_kill(tmp_path, "the gate's leg-direction clause", (DIRECTION_CLAUSE,),
                     evidence, spec)


def test_the_gate_two_leg_shape_clause_is_load_bearing(tmp_path, golden, spec):
    """TWO BUY LEGS with legal unit counts and legal deltas: the unit-count clause and the
    direction clause are both satisfied, so only the shape clause can reject it."""
    evidence = copy.deepcopy(golden["evidence"])
    second = dict(evidence["legs"][0])
    second["units"] = int(spec["sell_units"])
    second["credits_delta"] = abs(golden["evidence"]["legs"][1]["credits_delta"])
    evidence["legs"] = [dict(evidence["legs"][0]), second]
    assert_gate_kill(tmp_path, "the gate's two-leg shape clause",
                     ('if len(legs) != 2 or [leg["side"] for leg in legs] != ["buy", "sell"]:',),
                     evidence, spec)


def test_the_gate_leg_unit_count_clause_is_load_bearing(tmp_path, golden, spec):
    evidence = copy.deepcopy(golden["evidence"])
    evidence["legs"][1]["units"] = int(spec["buy_units"])
    assert_gate_kill(tmp_path, "the gate's leg unit-count clause",
                     ('if legs[0]["units"] != int(spec["buy_units"]) '
                      'or legs[1]["units"] != int(spec["sell_units"]):',), evidence, spec)


def test_the_gate_load_stage_clause_is_load_bearing(tmp_path, golden, spec):
    """The [load.progress] OOLog calls exist ONLY inside -loadPlayerFromFile:, so an empty list is
    a run that never loaded the save - and rc=0 with no ERROR lines is satisfied by a launch that
    died in display setup (bead oo-het captured that artefact)."""
    assert_gate_kill(tmp_path, "the gate's load-stage clause",
                     ('if evidence["load_stages"] != stages:',),
                     dict(copy.deepcopy(golden["evidence"]), load_stages=[]), spec)


def test_the_gate_load_failure_clause_is_load_bearing(tmp_path, golden, spec):
    assert_gate_kill(tmp_path, "the gate's load-failure clause",
                     ('if evidence["load_failures"]:',),
                     dict(copy.deepcopy(golden["evidence"]),
                          load_failures=["[load.failed] could not read commander data"]), spec)


def test_the_gate_cargo_after_cycle_clause_is_load_bearing(tmp_path, golden, spec):
    assert_gate_kill(tmp_path, "the gate's cargo_after_cycle clause",
                     ('if evidence["cargo_after_cycle"] != int(spec["expected_cargo_after"]):',),
                     dict(copy.deepcopy(golden["evidence"]), cargo_after_cycle=99), spec)


def test_the_gate_empty_hold_clause_is_load_bearing(tmp_path, golden, spec):
    """THE PERMISSIVE-SPEC ARM. A spec pinning expected_cargo_after=0 satisfies the agreement
    clause while describing a cycle whose end state is identical to a run that never traded; this
    clause is the only thing that refuses it."""
    assert_gate_kill(tmp_path, "the gate's empty-hold clause",
                     ('if evidence["cargo_after_cycle"] <= 0:',),
                     dict(copy.deepcopy(golden["evidence"]), cargo_after_cycle=0),
                     dict(spec, expected_cargo_after=0))


def test_the_gate_market_movement_clause_is_load_bearing(tmp_path, golden, spec):
    """A market that did not move is a market nobody traded in."""
    evidence = copy.deepcopy(golden["evidence"])
    evidence["market_quantity_after"] = evidence["market_quantity_before"]
    assert_gate_kill(tmp_path, "the gate's market-movement clause",
                     ('if evidence["market_quantity_after"] == '
                      'evidence["market_quantity_before"]:',), evidence, spec)


def test_the_gate_purse_movement_clause_is_load_bearing(tmp_path, golden, spec):
    evidence = copy.deepcopy(golden["evidence"])
    evidence["credits_after"] = evidence["credits_before"]
    assert_gate_kill(tmp_path, "the gate's purse-movement clause",
                     ('if evidence["credits_after"] == evidence["credits_before"]:',),
                     evidence, spec)


def test_the_gate_untraded_goods_clause_is_load_bearing(tmp_path, golden, spec):
    """trade_cycle.py:688 - already guarded by a data mutant ("1 failed, 46 passed"), pinned here
    as a CHECKER mutant so the kill is attributed to this clause rather than to its neighbours."""
    assert_gate_kill(tmp_path, "the gate's untraded-goods clause",
                     ('if evidence["untraded_goods_changed"]:',),
                     dict(copy.deepcopy(golden["evidence"]), untraded_goods_changed=[
                         "gold: [14, 396, 127] -> [13, 396, 127]"]), spec)


def test_the_gate_untraded_control_size_clause_is_load_bearing(tmp_path, golden, spec):
    assert_gate_kill(tmp_path, "the gate's untraded-control-size clause",
                     ('if evidence["untraded_goods_compared"] < MIN_MARKET_GOODS - 1:',),
                     dict(copy.deepcopy(golden["evidence"]), untraded_goods_compared=1), spec)


def test_the_gate_world_at_rest_clause_is_load_bearing(tmp_path, golden, spec):
    """A world still moving makes the dump a function of how many frames this box rendered."""
    assert_gate_kill(tmp_path, "the gate's world-at-rest clause",
                     ('if not evidence["world_at_rest"] '
                      'or not evidence["world_reached_fixed_point"]:',),
                     dict(copy.deepcopy(golden["evidence"]), world_at_rest=False), spec)


def test_the_gate_zero_money_leg_clause_is_defended_by_the_direction_clause(tmp_path, golden,
                                                                           spec):
    """MEASURED MISKILL, recorded rather than banked. A leg whose credits_delta is ZERO is also
    caught by the direction clause (0 >= 0 is true), so deleting the zero-money clause alone does
    NOT let it through. No kill is claimed for it; instead this arm pins the redundancy, and the
    one below shows the PAIR is load-bearing."""
    evidence = copy.deepcopy(golden["evidence"])
    evidence["legs"][0]["credits_delta"] = 0
    result = run_gate(tmp_path, evidence, spec,
                      clauses=('if not all(leg["credits_delta"] for leg in legs):',), tag="zm")
    assert result.returncode == 1, (
        "with the zero-money clause removed, a leg that moved NO money was ACCEPTED: the "
        "direction clause no longer backs it up.\n%s%s" % (result.stdout, result.stderr))
    assert "COST money" in result.stderr


def test_removing_both_money_clauses_lets_a_moneyless_leg_through(tmp_path, golden, spec):
    evidence = copy.deepcopy(golden["evidence"])
    evidence["legs"][0]["credits_delta"] = 0
    result = run_gate(tmp_path, evidence, spec,
                      clauses=('if not all(leg["credits_delta"] for leg in legs):',
                               DIRECTION_CLAUSE), tag="zm2")
    assert result.returncode == 0, (
        "MISKILL: with BOTH money clauses removed the moneyless leg was still rejected, so "
        "neither is pinned by this pair.\n%s%s" % (result.stdout, result.stderr))
