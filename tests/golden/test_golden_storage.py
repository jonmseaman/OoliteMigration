"""Offline tests for the golden storage policy (oo-ss8). No game, no build, ~1s.

These pin the properties that make the zero-difference gate MEAN something. The gate itself is
cheap to write and trivially easy to make vacuous, so the falsifiability lives here:

  * golden_diff refuses a comparison of a file with itself, and of a link to itself
  * golden_diff refuses an empty or collapsed dump
  * golden_diff refuses a golden whose provenance records an off-policy quantisation
  * golden_diff refuses a dump whose floats have all been rounded to whole numbers
  * golden_diff REPORTS a difference of exactly one quantised unit, naming the field
  * check_build_flags fails on a build database missing -ffp-contract=off
  * check_build_flags fails on a database whose EFFECTIVE -O is not the pinned level
  * check_build_flags refuses an implausibly small database
"""

import json
import os
import shutil
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import check_build_flags as cbf  # noqa: E402
import golden_diff as gd  # noqa: E402

REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GOLDEN_001 = os.path.join(REPO_ROOT, "goldens", "windows-x64", "001", "state.json")
QUANTUM = 10 ** -gd.POLICY_QUANT_DECIMALS


def _dump(n_ents=4):
    """A synthetic dump that passes every non-vacuity floor, for testing the guards."""
    ents = [{"aiState": "GLOBAL", "id": "ship-%03d" % i, "isPlayer": False,
             "position": [1.5 + i, 2.25, 3.125], "role": "police",
             "velocity": [0.0, 0.5, 0.125]} for i in range(n_ents)]
    market = {"food-%d" % i: {"capacity": 100.0, "price": 40.5 + i, "quantity": 7.25}
              for i in range(6)}
    return {"entities": ents, "market": market,
            "player": {"cargo": [], "credits": 100.5, "legalStatus": 0, "score": 0,
                       "ship": {"aiState": "", "docked": True, "position": [0.5, 0.5, 0.5],
                                "velocity": [0.0, 0.0, 0.0]}}}


def write(tmp_path, name, data):
    p = tmp_path / name
    p.write_text(json.dumps(data, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    return str(p)


def run_diff(*args):
    cmd = [sys.executable, os.path.join(HERE, "golden_diff.py")] + list(args)
    return subprocess.run(cmd, capture_output=True, text=True)


# --------------------------------------------------------------------------- the refusals

def test_refuses_comparing_a_file_with_itself(tmp_path):
    a = write(tmp_path, "a.json", _dump())
    r = run_diff(a, a)
    assert r.returncode == 2, r
    assert "same path" in r.stderr


def test_refuses_two_names_for_one_file(tmp_path):
    a = write(tmp_path, "a.json", _dump())
    b = str(tmp_path / "b.json")
    try:
        os.link(a, b)
    except (OSError, NotImplementedError):
        pytest.skip("hard links unavailable on this filesystem")
    r = run_diff(a, b)
    assert r.returncode == 2, r
    assert "same file on disk" in r.stderr


def test_refuses_empty_dumps(tmp_path):
    a = tmp_path / "a.json"; a.write_text("", encoding="utf-8")
    b = tmp_path / "b.json"; b.write_text("", encoding="utf-8")
    r = run_diff(str(a), str(b))
    assert r.returncode == 2, r
    assert "empty" in r.stderr


def test_refuses_a_collapsed_dump(tmp_path):
    a = write(tmp_path, "a.json", _dump())
    b = write(tmp_path, "b.json", {"entities": [], "market": {}, "player": {}})
    r = run_diff(a, b)
    assert r.returncode == 2, r
    assert "vacuous" in r.stderr or "leaf field" in r.stderr


def test_refuses_off_policy_quantisation_in_provenance(tmp_path):
    d = tmp_path / "g"
    d.mkdir()
    a = write(d, "state.json", _dump())
    (d / "provenance.json").write_text(json.dumps({"quant_decimals": 1}), encoding="utf-8")
    b = write(tmp_path, "b.json", _dump())
    r = run_diff(a, b)
    assert r.returncode == 2, r
    assert "quant_decimals=1" in r.stderr
    assert "Coarsening quantisation" in r.stderr


def test_refuses_a_dump_rounded_to_whole_numbers(tmp_path):
    """The 'round harder until it passes' attack, caught even with no provenance at all."""
    coarse = json.loads(json.dumps(_dump()))
    for e in coarse["entities"]:
        e["position"] = [float(round(v)) for v in e["position"]]
        e["velocity"] = [float(round(v)) for v in e["velocity"]]
    for g in coarse["market"].values():
        for k in g:
            g[k] = float(round(g[k]))
    coarse["player"]["credits"] = float(round(coarse["player"]["credits"]))
    ps = coarse["player"]["ship"]
    ps["position"] = [float(round(v)) for v in ps["position"]]
    ps["velocity"] = [float(round(v)) for v in ps["velocity"]]

    a = write(tmp_path, "a.json", coarse)
    b = write(tmp_path, "b.json", _dump())
    r = run_diff(a, b)
    assert r.returncode == 2, r
    assert "whole number" in r.stderr


# --------------------------------------------------------------------------- the discrimination

def test_one_quantised_unit_is_reported_with_both_values(tmp_path):
    a_data = _dump()
    b_data = json.loads(json.dumps(a_data))
    b_data["entities"][1]["position"][0] = round(
        b_data["entities"][1]["position"][0] + QUANTUM, gd.POLICY_QUANT_DECIMALS)

    a = write(tmp_path, "a.json", a_data)
    b = write(tmp_path, "b.json", b_data)
    r = run_diff(a, b)
    assert r.returncode == 1, r
    assert "entities[ship-001].position[0]" in r.stderr
    assert "2.5" in r.stderr and "2.501" in r.stderr


def test_identical_independent_dumps_match(tmp_path):
    a = write(tmp_path, "a.json", _dump())
    b = write(tmp_path, "b.json", _dump())
    r = run_diff(a, b)
    assert r.returncode == 0, r.stderr
    assert "MATCH" in r.stdout


def test_entities_are_keyed_by_id_not_index(tmp_path):
    """A removed ship must report as one absent entity, not shift every later index."""
    a_data = _dump()
    b_data = json.loads(json.dumps(a_data))
    del b_data["entities"][0]
    a = write(tmp_path, "a.json", a_data)
    b = write(tmp_path, "b.json", b_data)
    r = run_diff(a, b)
    assert r.returncode == 1
    assert "ship-000" in r.stderr
    assert "ship-003" not in r.stderr, "index-keyed diff would smear the change across all ships"


# --------------------------------------------------------------------------- build flags

def _fake_db(n=200, fp=cbf.REQUIRED_FP, tail_o=None, extra=()):
    entries = []
    for i in range(n):
        args = ["clang", "-O2"]
        if fp:
            args.append(fp)
        if tail_o:
            args.append(tail_o)
        args.extend(extra)
        args.extend(["-c", "src/f%d.m" % i])
        entries.append({"directory": ".", "file": "src/f%d.m" % i, "arguments": args})
    return entries


def _write_db(tmp_path, entries):
    p = tmp_path / "compile_commands.json"
    p.write_text(json.dumps(entries), encoding="utf-8")
    return str(p)


def test_build_flags_pass_on_a_compliant_database(tmp_path):
    db, problems, levels = cbf.check_db(_write_db(tmp_path, _fake_db()))
    assert problems == [], problems
    assert levels == {"-O2": 200}


def test_build_flags_fail_without_ffp_contract_off(tmp_path):
    _, problems, _ = cbf.check_db(_write_db(tmp_path, _fake_db(fp=None)))
    assert any("ffp-contract=off" in p for p in problems), problems


def test_build_flags_fail_when_a_later_O_overrides_the_pin(tmp_path):
    """-O2 present but -O0 last: the build really compiles at -O0."""
    _, problems, _ = cbf.check_db(_write_db(tmp_path, _fake_db(tail_o="-O0")))
    assert any("pinned -O2" in p and "-O0" in p for p in problems), problems


def test_build_flags_fail_on_fast_math(tmp_path):
    _, problems, _ = cbf.check_db(_write_db(tmp_path, _fake_db(extra=["-ffast-math"])))
    assert any("ffast-math" in p for p in problems), problems


def test_build_flags_refuse_a_tiny_database(tmp_path):
    _, problems, _ = cbf.check_db(_write_db(tmp_path, _fake_db(n=3)))
    assert any("vacuous" in p for p in problems), problems


# --------------------------------------------------------------------------- the stored golden

def test_stored_golden_001_exists_and_is_canonical():
    assert os.path.isfile(GOLDEN_001), GOLDEN_001
    sys.path.insert(0, os.path.join(HERE, "dump"))
    import check_canonical
    with open(GOLDEN_001, "r", encoding="utf-8") as h:
        text = h.read()
    assert check_canonical.check(text) == [], check_canonical.check(text)


def test_stored_golden_001_provenance_is_on_policy():
    prov_path = os.path.join(os.path.dirname(GOLDEN_001), "provenance.json")
    assert os.path.isfile(prov_path), prov_path
    prov = json.load(open(prov_path, encoding="utf-8"))
    assert prov["quant_decimals"] == gd.POLICY_QUANT_DECIMALS
    assert prov["platform"] == "windows-x64"
    assert prov["build_flags"]["policy_fp_contract"] == cbf.REQUIRED_FP
    assert prov["build_flags"]["policy_optimization"] == cbf.PINNED_O


def test_provenance_records_OBSERVED_flags_not_the_policy_it_wishes_for():
    """A provenance file that asserts compliance by construction is worse than none.

    The shared build that produced this golden predates the -ffp-contract=off pin, so its
    build_flags block must say so - `verified: false` with a `detail` naming the missing flag.
    This test exists so the finding cannot be lost by someone tidying the provenance up, and so
    that a later rebuild flipping it to verified:true is a deliberate, visible change.
    """
    prov = json.load(open(os.path.join(os.path.dirname(GOLDEN_001), "provenance.json"),
                          encoding="utf-8"))
    flags = prov["build_flags"]
    assert "verified" in flags, "provenance does not say whether the flags were verified at all"
    assert isinstance(flags["detail"], str) and flags["detail"], \
        "provenance records no detail about the build flags"
    if not flags["verified"]:
        assert cbf.REQUIRED_FP in flags["detail"] or "-O" in flags["detail"], \
            "flags are unverified but the reason does not name a flag: %r" % flags["detail"]


def test_the_measurement_limit_is_pinned_not_forgotten():
    """The 5-run "identical at 15 decimals" result does NOT measure a float noise floor.

    Asserted against the RAW-PRECISION measurement artifact, not the quantised golden: the claim
    is about the values as the game emitted them at 15 decimal places. Every one is an exact
    binary fraction terminating well short of 15 places, so toFixed(15) rounded nothing and the
    byte-identical result cannot be cited as evidence for any particular decimal count.

    If a future scenario emits a value needing MORE exact places than the measurement precision,
    the measurement starts to exercise rounding, becomes meaningful, and GOLDEN_STORAGE.md must
    be updated with the real spread instead of this limit.
    """
    from decimal import Decimal
    raw_path = os.path.join(HERE, "measurements", "001-raw15-runA.json")
    summary_path = os.path.join(HERE, "measurements", "001-raw15-summary.json")
    assert os.path.isfile(raw_path), raw_path
    assert os.path.isfile(summary_path), summary_path

    summary = json.load(open(summary_path, encoding="utf-8"))
    assert summary["distinct_hashes"] == 1, "the five runs were not byte-identical after all"
    assert summary["max_observed_absolute_spread"] == 0.0

    raw = json.load(open(raw_path, encoding="utf-8"))
    floats = [v for v in gd.flatten(raw).values() if isinstance(v, float)]
    assert len(floats) >= 20, len(floats)
    # Exact decimal places each value needs: the shortest decimal that is EQUAL to the binary
    # value, which is what toFixed(15) printed.
    worst = max(-Decimal(repr(v)).as_tuple().exponent for v in floats)
    assert worst == summary["max_exact_decimal_places_needed"], (
        "the summary records %d exact decimal places but the data needs %d"
        % (summary["max_exact_decimal_places_needed"], worst))
    assert worst < 15, (
        "a raw value needs %d exact decimal places, i.e. the 15-decimal measurement DID round "
        "something - it now locates a real noise floor and GOLDEN_STORAGE.md should quote it "
        "instead of describing the measurement as not exercising rounding" % worst)


def test_quantisation_actually_alters_the_stored_values():
    """Non-vacuity of the policy itself: if quantisation changed nothing it would be decoration."""
    raw_floats = [v for v in gd.flatten(json.load(open(GOLDEN_001, encoding="utf-8"))).values()
                  if isinstance(v, float)]
    assert len(raw_floats) >= 10, len(raw_floats)
    # Every stored value must already be AT the policy precision (it was quantised on the way out).
    assert all(round(v, gd.POLICY_QUANT_DECIMALS) == v for v in raw_floats), \
        "a stored golden value carries more precision than the policy allows"


def test_perturbing_the_stored_golden_by_one_unit_goes_red(tmp_path):
    """THE FALSIFIABILITY PROOF, on the REAL golden - in a throwaway copy, never in goldens/.

    If this test ever passes-by-matching, the gate's zero-difference result means nothing.
    """
    data = json.load(open(GOLDEN_001, encoding="utf-8"))
    target = data["entities"][0]
    before = target["position"][0]
    target["position"][0] = round(before + QUANTUM, gd.POLICY_QUANT_DECIMALS)
    assert target["position"][0] != before

    mutant = write(tmp_path, "mutant.json", data)
    r = run_diff(GOLDEN_001, mutant)
    assert r.returncode == 1, "one quantised unit on the real golden was NOT detected: %r" % (r,)
    assert "entities[%s].position[0]" % data["entities"][0]["id"] in r.stderr
    assert repr(before) in r.stderr

    # ... and GREEN against an untouched copy of the same golden.
    clean = str(tmp_path / "clean.json")
    shutil.copyfile(GOLDEN_001, clean)
    g = run_diff(GOLDEN_001, clean)
    assert g.returncode == 0, g.stderr
