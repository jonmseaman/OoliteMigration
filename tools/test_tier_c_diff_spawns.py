#!/usr/bin/env python3
"""tools/tier-c-diff.sh --report-only must cost a constant, small number of process spawns
(bead oo-3rb.349).

WHY THIS IS A TEST. tools/test_tier_c_diff.py runs the real tier-c-diff.sh --report-only with a
60 s bound. Standalone that takes seconds; under tier-b's concurrent pytest shards it took over
60 s and timed out twice in the Phase 2 exit gate, because the report was rendered in bash with a
cygpath/grep/sed/wc/python spawn for nearly every line (~60 for a two-scenario fixture) and an
MSYS spawn costs 1-2 s on a loaded machine. Wall-clock is the symptom and is load-dependent, so it
cannot be pinned deterministically; the spawn count is the cause and can. This test puts counting
shims for the external commands the script could call ahead of PATH, runs --report-only against
the same fixture tools/test_tier_c_diff.py builds, and pins that the count is small and does NOT
grow with the number of golden scenarios.
"""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
DIFF_SH = HERE / "tier-c-diff.sh"

sys.path.insert(0, str(HERE))
from test_tier_c_diff import big_dump, make_fixture  # the selftest's own fixture shape

# Every external command tier-c-diff.sh's report path has used or could plausibly use.
SHIMMED = ("cygpath", "grep", "sed", "wc", "sort", "tr", "ls", "mkdir", "tail", "cat", "head",
           "dirname", "mktemp", "awk", "cut", "python3", "python")

# The report path's whole budget: locating itself, the --out dir, a native path or two, and ONE
# interpreter. Anything per scenario, per corpus group or per report line blows it.
MAX_SPAWNS = 8


def make_shims(shim_dir: Path, log: Path) -> None:
    shim_dir.mkdir(parents=True, exist_ok=True)
    for name in SHIMMED:
        real = shutil.which(name)
        if real is None:
            continue
        real = Path(real).as_posix()
        shim = shim_dir / name
        shim.write_text("#!/bin/sh\nprintf '%%s\\n' %s >> '%s'\nexec '%s' \"$@\"\n"
                        % (name, log.as_posix(), real), newline="\n")
        shim.chmod(shim.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def spawns_for(out: Path, extra_scenarios: int) -> tuple[subprocess.CompletedProcess, list[str]]:
    make_fixture(out, credits_diverge=True, corpus_diverge=True)
    for i in range(extra_scenarios):
        for root in ("sm-root", "qjs-root"):
            (out / root / ("%03d.json" % (100 + i))).write_text(json.dumps(big_dump(100.5)))
    shim_dir = out.parent / (out.name + "-shims")
    log = out.parent / (out.name + "-spawns.log")
    make_shims(shim_dir, log)
    env = dict(os.environ)
    env.update({"OOLITE_TIER_C_GOLDEN_FLOOR": "2", "OOLITE_TIER_C_CORPUS_FLOOR": "3",
                "PATH": str(shim_dir) + os.pathsep + env.get("PATH", "")})
    proc = subprocess.run(["bash", str(DIFF_SH), "--report-only", "--out", str(out)],
                          capture_output=True, text=True, timeout=600, cwd=str(REPO_ROOT),
                          env=env)
    spawned = log.read_text().split() if log.exists() else []
    return proc, spawned


@pytest.fixture()
def tmp_root():
    d = Path(tempfile.mkdtemp(prefix="tier-c-diff-spawns-"))
    try:
        yield d
    finally:
        shutil.rmtree(d, ignore_errors=True)


def test_report_only_spawns_are_few_and_do_not_scale_with_scenarios(tmp_root: Path) -> None:
    small_out, big_out = tmp_root / "two", tmp_root / "twelve"
    small_out.mkdir()
    big_out.mkdir()
    small, small_spawns = spawns_for(small_out, extra_scenarios=0)
    big, big_spawns = spawns_for(big_out, extra_scenarios=10)

    # The shims must not change the verdict: both fixtures diverge (golden 002, corpus g2).
    assert small.returncode == 1, small.stdout + small.stderr
    assert big.returncode == 1, big.stdout + big.stderr
    assert "1 golden, 1 corpus" in (small_out / "divergence-report.md").read_text()
    assert "1 golden, 1 corpus" in (big_out / "divergence-report.md").read_text()
    # Anti-vacuity: the shims really were on PATH (the script spawns at least its interpreter).
    assert any(s.startswith("python") for s in small_spawns), small_spawns

    assert len(small_spawns) <= MAX_SPAWNS, \
        "tier-c-diff.sh --report-only spawned %d processes for 2 scenarios (budget %d): %s" \
        % (len(small_spawns), MAX_SPAWNS, " ".join(small_spawns))
    assert len(big_spawns) == len(small_spawns), \
        "spawns grow with the scenario count: %d for 2 scenarios, %d for 12" \
        % (len(small_spawns), len(big_spawns))


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q"]))
