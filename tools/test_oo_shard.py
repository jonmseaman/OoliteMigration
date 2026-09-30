#!/usr/bin/env python3
"""Tests for tools/pytest_plugins/oo_shard.py, the sharding tier-b's test stage relies on (oo-3rb.331).

tier-b.sh runs each offline suite as N concurrent `pytest -p oo_shard --oo-shard K/N` processes and
checks the suite's floor against the SUM of the shards' pass counts. That is only as good as the
partition: a shard plugin that dropped an item, or ran one twice, would still sum to a plausible
number. So these tests pin the partition itself, both on a generated suite (exact node ids, every
N tier-b uses) and on the real tests/golden suite at tier-b's shard count, by collection only:

  * the shards are pairwise disjoint and their union is exactly the unsharded collection;
  * --oo-shard 0/1 is the unsharded run;
  * a malformed or out-of-range spec is a usage error (rc 4), never a silent no-op.

Offline, no build, no game: `pytest --collect-only` only.

Run:  python3 -m pytest tools/test_oo_shard.py -q -p no:cacheprovider
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
PLUGINS = TOOLS / "pytest_plugins"


def _collect(suite: Path, *extra: str, cwd: Path = REPO) -> tuple[int, list[str], str]:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(PLUGINS) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", str(suite), "--collect-only", "-q",
         "-p", "no:cacheprovider", "-p", "oo_shard", *extra],
        cwd=cwd, env=env, capture_output=True, text=True, timeout=240,
    )
    ids = [line for line in proc.stdout.splitlines() if "::" in line and not line.startswith(" ")]
    return proc.returncode, ids, proc.stdout + proc.stderr


def _assert_partition(suite: Path, n: int, cwd: Path = REPO) -> int:
    rc, whole, out = _collect(suite, cwd=cwd)
    assert rc == 0 and whole, f"unsharded collection of {suite} failed (rc {rc}):\n{out[-2000:]}"
    seen: list[str] = []
    for k in range(n):
        rc, ids, out = _collect(suite, "--oo-shard", f"{k}/{n}", cwd=cwd)
        # rc 5 = the round-robin gave this shard nothing (more shards than items); tier-b allows it.
        assert rc in (0, 5), f"shard {k}/{n} of {suite} failed (rc {rc}):\n{out[-2000:]}"
        assert ids == whole[k::n], f"shard {k}/{n} of {suite} is not items {k}, {k}+{n}, ..."
        seen.extend(ids)
    assert len(seen) == len(set(seen)), f"an item of {suite} landed in two of the {n} shards"
    assert sorted(seen) == sorted(whole), f"the {n} shards of {suite} do not cover it exactly"
    return len(whole)


@pytest.fixture
def toy_suite(tmp_path: Path) -> Path:
    suite = tmp_path / "suite"
    suite.mkdir()
    for f in range(3):
        body = "".join(f"def test_{f}_{i}():\n    pass\n\n" for i in range(5 + f))
        (suite / f"test_toy_{f}.py").write_text(body, encoding="utf-8")
    return suite


@pytest.mark.parametrize("n", [1, 2, 6, 8, 40])
def test_the_shards_partition_a_suite_exactly(toy_suite: Path, n: int) -> None:
    assert _assert_partition(toy_suite, n, cwd=toy_suite.parent) == 18


def test_shard_0_of_1_is_the_unsharded_run(toy_suite: Path) -> None:
    _, whole, _ = _collect(toy_suite, cwd=toy_suite.parent)
    rc, one, out = _collect(toy_suite, "--oo-shard", "0/1", cwd=toy_suite.parent)
    assert rc == 0 and one == whole, out[-2000:]


@pytest.mark.parametrize("spec", ["", "3", "a/b", "1/0", "2/2", "-1/3", "1/2/3"])
def test_a_bad_spec_is_a_usage_error(toy_suite: Path, spec: str) -> None:
    rc, ids, out = _collect(toy_suite, "--oo-shard", spec, cwd=toy_suite.parent)
    assert rc == 4, f"--oo-shard {spec!r} gave rc {rc}, not a usage error (4):\n{out[-1500:]}"
    assert not ids


def test_the_real_golden_suite_partitions_at_tier_b_shard_count() -> None:
    # tier-b.sh's test_shards_for gives tests/golden 8 shards.
    assert _assert_partition(REPO / "tests" / "golden", 8) > 1000
