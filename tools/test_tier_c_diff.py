#!/usr/bin/env python3
"""Offline selftest for tools/tier-c-diff.sh (Phase 1 seam 1.5a, bead oo-2t6).

tools/tier-c-diff.sh's real job needs two built backends and takes 30+ minutes (it runs
tools/tier-c.sh --backend=sm and --backend=quickjs, each doing goldens+corpus). That cannot run
inside a bead's stored acceptance block. This file is the split the rest of the fleet uses for
that (see tools/tier_c_selftest.py's docstring for the pattern): it builds a FAKE pair of kept
tier-c.sh run roots -- the exact directory shape tier-c.sh's goldens/corpus stages actually leave
behind (bead oo-j4u's OOLITE_TIER_C_KEEP=1: "$RUN_ROOT/$name.json" dumps, "$RUN_ROOT/corpus.log"
naming a results.json) -- and runs the REAL tools/tier-c-diff.sh --report-only against them. No
build, no launch, no network, seconds not minutes.

It proves the DONE WHEN this bead exists for: "Report lists every golden/corpus divergence with
the first differing line", in both directions -- a report with real divergences names them and
their first line, and a report with none says so and exits 0 -- plus the anti-vacuity floors that
make "0 divergences" mean "compared everything and found nothing" rather than "compared nothing".
"""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
DIFF_SH = HERE / "tier-c-diff.sh"


def big_dump(credits: float) -> dict:
    """A dump that clears golden_diff.py's own non-vacuity floors (>=40 leaf fields, >=2
    entities, fractional floats), so the fixture is REFUSED by golden_diff.py for the identical
    reason a truncated real dump would be -- not because it is a hand-rolled toy."""
    entities = [{"id": i, "role": "r%d" % i, "x": float(i) + 0.125, "y": 1.5, "z": 2.5}
                for i in range(6)]
    market = {"good%d" % i: float(i) + 0.5 for i in range(20)}
    player = {"credits": credits, "cargo": 0, "legalStatus": "Clean", "score": 1.0, "ship": "Cobra"}
    return {"entities": entities, "market": market, "player": player}


def make_fixture(tmp: Path, *, credits_diverge: bool, corpus_diverge: bool) -> Path:
    """Build the exact directory shape tools/tier-c.sh's goldens+corpus stages leave under a
    KEPT run root, for both backends, and the tier-c-diff.sh wrapper logs that point at them."""
    sm_root = tmp / "sm-root"
    qjs_root = tmp / "qjs-root"
    sm_work = tmp / "sm-corpus-work"
    qjs_work = tmp / "qjs-corpus-work"
    for d in (sm_root, qjs_root, sm_work, qjs_work):
        d.mkdir(parents=True, exist_ok=True)

    (sm_root / "001.json").write_text(json.dumps(big_dump(100.5)))
    (qjs_root / "001.json").write_text(json.dumps(big_dump(100.5)))
    (sm_root / "002.json").write_text(json.dumps(big_dump(100.5)))
    (qjs_root / "002.json").write_text(json.dumps(big_dump(200.5 if credits_diverge else 100.5)))

    sm_results = [{"name": "g1", "verdict": "PASS", "errors": []},
                  {"name": "g2", "verdict": "PASS", "errors": []},
                  {"name": "g3", "verdict": "PASS", "errors": []}]
    qjs_results = [{"name": "g1", "verdict": "PASS", "errors": []},
                   {"name": "g2", "verdict": "LOG" if corpus_diverge else "PASS",
                    "errors": ["ERROR: something"] if corpus_diverge else []},
                   {"name": "g3", "verdict": "PASS", "errors": []}]
    (sm_work / "results.json").write_text(json.dumps(sm_results))
    (qjs_work / "results.json").write_text(json.dumps(qjs_results))

    (sm_root / "corpus.log").write_text("results: %s\n" % (sm_work / "results.json").as_posix())
    (qjs_root / "corpus.log").write_text("results: %s\n" % (qjs_work / "results.json").as_posix())

    (tmp / "tier-c-sm.log").write_text(
        "==> tier-c (windows-x64, budget 2400s, 2 stage(s): goldens corpus)\n"
        "tier-c: logs kept at %s\n" % sm_root.as_posix())
    (tmp / "tier-c-quickjs.log").write_text(
        "==> tier-c (windows-x64, budget 2400s, 2 stage(s): goldens corpus)\n"
        "tier-c: logs kept at %s\n" % qjs_root.as_posix())
    return tmp


def run_diff(out: Path, floors: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    env = {"OOLITE_TIER_C_GOLDEN_FLOOR": "2", "OOLITE_TIER_C_CORPUS_FLOOR": "3"}
    if floors:
        env.update(floors)
    import os
    full_env = dict(os.environ)
    full_env.update(env)
    return subprocess.run(
        ["bash", str(DIFF_SH), "--report-only", "--out", str(out)],
        capture_output=True, text=True, timeout=60, cwd=str(REPO_ROOT), env=full_env,
    )


@pytest.fixture()
def tmp_out():
    d = Path(tempfile.mkdtemp(prefix="tier-c-diff-selftest-"))
    try:
        yield d
    finally:
        shutil.rmtree(d, ignore_errors=True)


def test_no_divergence_is_green(tmp_out: Path) -> None:
    make_fixture(tmp_out, credits_diverge=False, corpus_diverge=False)
    proc = run_diff(tmp_out)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "GREEN" in proc.stdout
    report = (tmp_out / "divergence-report.md").read_text()
    assert "NO golden divergences" in report
    assert "NO corpus divergences" in report
    assert "0 total divergence(s)" in report


def test_golden_divergence_names_the_first_differing_line(tmp_out: Path) -> None:
    make_fixture(tmp_out, credits_diverge=True, corpus_diverge=False)
    proc = run_diff(tmp_out)
    assert proc.returncode == 1, proc.stdout + proc.stderr
    report = (tmp_out / "divergence-report.md").read_text()
    # The DONE WHEN clause, verified literally: the report names the scenario AND the first
    # differing line golden_diff.py reported (the field that moved, both values).
    assert "002" in report
    assert "player.credits: 100.5 != 200.5" in report
    assert "001" not in report.split("## Corpus")[0].split("002")[0].replace("Goldens (2", "")


def test_corpus_divergence_names_verdicts_and_first_error(tmp_out: Path) -> None:
    make_fixture(tmp_out, credits_diverge=False, corpus_diverge=True)
    proc = run_diff(tmp_out)
    assert proc.returncode == 1, proc.stdout + proc.stderr
    report = (tmp_out / "divergence-report.md").read_text()
    assert "g2" in report
    assert "PASS" in report and "LOG" in report
    assert "ERROR: something" in report


def test_both_kinds_diverge_together(tmp_out: Path) -> None:
    make_fixture(tmp_out, credits_diverge=True, corpus_diverge=True)
    proc = run_diff(tmp_out)
    assert proc.returncode == 1, proc.stdout + proc.stderr
    report = (tmp_out / "divergence-report.md").read_text()
    assert "1 golden, 1 corpus" in report


def test_golden_floor_refuses_a_short_run(tmp_out: Path) -> None:
    """ANTI-VACUITY: a run that dumped fewer goldens than the floor must REFUSE, not report a
    misleadingly clean '0 divergences' over a set too small to mean anything."""
    make_fixture(tmp_out, credits_diverge=False, corpus_diverge=False)
    proc = run_diff(tmp_out, floors={"OOLITE_TIER_C_GOLDEN_FLOOR": "99"})
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "fewer than the floor" in proc.stderr


def test_corpus_floor_refuses_a_short_run(tmp_out: Path) -> None:
    make_fixture(tmp_out, credits_diverge=False, corpus_diverge=False)
    proc = run_diff(tmp_out, floors={"OOLITE_TIER_C_CORPUS_FLOOR": "99"})
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "fewer than the floor" in proc.stderr


def test_report_only_without_a_prior_run_refuses(tmp_out: Path) -> None:
    """--report-only against an --out with no prior run must be a usage error, not a silent
    empty-and-green report."""
    proc = run_diff(tmp_out)
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "does not exist" in proc.stderr


def test_backend_flag_accepted_by_tier_c_dry_run() -> None:
    """tier-c-diff.sh depends on tools/tier-c.sh's --backend=<sm|quickjs> (bead oo-2t6's other
    half); pin that the flag is wired all the way through --dry-run for both spellings."""
    tier_c = HERE / "tier-c.sh"
    for flag in ("sm", "quickjs"):
        proc = subprocess.run(["bash", str(tier_c), "--backend=" + flag, "--dry-run"],
                              capture_output=True, text=True, timeout=60, cwd=str(REPO_ROOT))
        assert proc.returncode == 0, proc.stdout + proc.stderr
        assert "backend" in proc.stdout


def test_backend_flag_rejects_an_unknown_name() -> None:
    tier_c = HERE / "tier-c.sh"
    proc = subprocess.run(["bash", str(tier_c), "--backend=bogus", "--dry-run"],
                          capture_output=True, text=True, timeout=60, cwd=str(REPO_ROOT))
    assert proc.returncode != 0
    assert "unknown --backend" in proc.stderr


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q"]))
