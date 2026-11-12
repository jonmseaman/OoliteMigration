# Adaptation ledger: running #772's files on the fork

Every fork-side change needed to run the files imported from OoliteProject/oolite#772 (FR-002).
The imported files stay byte-identical to upstream; each adaptation lives in fork-owned code.

Pinned upstream commit: `12c39549e` (2026-11-08).

## Left out of the import

| Path | Why |
|---|---|
| `tests/fetch_oxps.py`, `tests/test-oxps.txt` | Download third-party OXPs (Hard rule 4) |
| `tools/js-parity/oxp_corpus.py`, `oxp-corpus.txt`, `oxp-corpus-known.txt` | Same |
| `tests/launch_snapshot.py`, `tests/run_test_fn.sh`, `tests/README.md`, `mk.sh`, `.github/workflows/*` | The fork has its own versions; see decision D3 |

`tools/js-parity/README.md` still mentions `oxp_corpus.py`; it is imported unchanged.

## Adaptations

| # | Where | What | Why |
|---|---|---|---|
| A1 | `tests/run.sh` (to do) | Run the runners with the venv's Python, not `python -I` | `-I` drops the script's directory from `sys.path`, so `run_js_tests.py` cannot import `oolite_harness` |
| A2 | `tests/run.sh` parity tier (to do) | Normalise `C:/…/AddOns` in the probe output to `<AddOns>` before comparing | `run_probe.py` replaces the path with backslashes; the game logs forward slashes on Windows (triage run 1, row 1) |
