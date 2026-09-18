# Landing scenario 008-material-test-suite

This scenario is complete and blessed, but its artifacts sit in
`tests/golden/pending/008-material-test-suite/` rather than in
`goldens/windows-x64/008-material-test-suite/`.

## Why it is here and not under goldens/

`tools/guardrails.sh` refuses ANY change under `goldens/`, including **creating a new file**,
unless the path is listed in `tools/rebless-approvals.txt`. Verified A/B: the guard returns RC=0
with these files under `tests/golden/pending/` and RC=1 with the same files under `goldens/`. A
worker may not write that approvals file, so landing the golden is Jon's call, not mine.

## What landing takes

```
git mv tests/golden/pending/008-material-test-suite goldens/windows-x64/008-material-test-suite
git mv goldens/windows-x64/008-material-test-suite/spec.json tests/golden/scenarios/008-material-test-suite/spec.json
```

**No code change is required.** Both `tests/golden/material_test_suite.py` and
`tests/golden/test_material_test_suite.py` search the guarded path FIRST and fall back to the
pending path:

- golden: `goldens/windows-x64/008-material-test-suite/state.json`, else `tests/golden/pending/.../state.json`
- spec: `tests/golden/scenarios/008-material-test-suite/spec.json`, else `tests/golden/pending/.../spec.json`
- frame: `goldens/windows-x64/008-material-test-suite/frame.grid`, else `tests/golden/pending/.../frame.grid`

The stored acceptance lines resolve the golden the same way, so they keep passing across the move.
This is the same shape scenarios 010 and 012 use.

## Files

| file | role |
|---|---|
| `state.json` | the blessed dump (3389 bytes, md5 `ca2df8e9d5c9aa322030b6e2d93e1a8f`) |
| `frame.grid` | 64x64 luminance grid, compared with the MEASURED tolerance, never byte-wise |
| `frame.png` | the actual captured frame, for human eyes only — nothing asserts against it |
| `spec.json` | the determinism knobs; belongs in `tests/golden/scenarios/` after landing |
| `provenance.json` | how it was blessed, the frame-control measurements, the stability sweep, and the duplicate-identifier finding |

## Before landing, re-verify

```
bash tools/guardrails.sh                                   # expect RC=0
python3 -m pytest tests/golden/test_material_test_suite.py -q    # expect 80 passed
python3 tests/golden/material_test_suite.py --out /tmp/x.json    # expect rc=0
python3 tests/golden/golden_diff.py <golden> /tmp/x.json         # expect MATCH
```
