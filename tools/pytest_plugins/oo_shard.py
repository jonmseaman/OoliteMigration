"""Deterministic test sharding for tools/tier-b.sh's offline test stage (bead oo-3rb.331).

    python3 -m pytest <suite> -p oo_shard --oo-shard K/N      # keep collected items K, K+N, K+2N...

Loaded with ``-p oo_shard`` and this directory on PYTHONPATH (nothing else lives here, so no
test module can be shadowed). Every shard collects the SAME suite in the SAME order, keeps the
items whose collection index is congruent to K modulo N, and reports the rest as deselected, so
the N shards partition the suite exactly: each test runs in precisely one shard, none in two,
none in zero. Round-robin rather than contiguous blocks, so a file of slow tests (e.g.
tools/test_tier_c_diff.py, ~80 s in six tests) is spread across shards instead of landing on one.

This exists instead of pytest-xdist because xdist is not installed in the fleet's MSYS2 Python
and tier-b must not grow a dependency to run; the stage enforces the same per-suite floors over
the SUM of the shards' pass counts, so a shard that silently ran nothing cannot hide a loss.
"""
from __future__ import annotations

import pytest


def pytest_addoption(parser):
    parser.addoption(
        "--oo-shard",
        default=None,
        metavar="K/N",
        help="run only collected items whose index modulo N equals K (0 <= K < N)",
    )


def _parse(spec: str) -> tuple[int, int]:
    try:
        k_text, n_text = spec.split("/")
        k, n = int(k_text), int(n_text)
    except ValueError:
        raise pytest.UsageError(f"--oo-shard wants K/N with integers, got {spec!r}")
    if n < 1 or not 0 <= k < n:
        raise pytest.UsageError(f"--oo-shard {spec!r}: need N >= 1 and 0 <= K < N")
    return k, n


def pytest_configure(config):
    spec = config.getoption("--oo-shard")
    if spec is not None:
        _parse(spec)  # a malformed spec is a usage error before collection, not a silent no-op


@pytest.hookimpl(trylast=True)
def pytest_collection_modifyitems(config, items):
    spec = config.getoption("--oo-shard")
    if spec is None:
        return
    k, n = _parse(spec)
    keep = [item for index, item in enumerate(items) if index % n == k]
    drop = [item for index, item in enumerate(items) if index % n != k]
    if drop:
        config.hook.pytest_deselected(items=drop)
        items[:] = keep
