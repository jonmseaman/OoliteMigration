# Landing scenario 010-png-test-suite into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY:

    <path> is under a protected golden path and is changed and has no re-bless approval in
    tools/rebless-approvals.txt

A brand-new `goldens/windows-x64/010-png-test-suite/state.json` trips that guard exactly as an edit
to an existing golden would (A/B control: tree without the file -> `guardrails: OK`, RC=0; same
tree with it -> the message above, RC=1). Adding the approval line is Jon's call, not a worker's,
so this bead stages the artefacts **outside** the protected path and ships a tested procedure for
moving them in.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced, including the knobs it was blessed with |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/010-png-test-suite/state.json \
           goldens/windows-x64/010-png-test-suite/state.json
    git mv tests/golden/pending/010-png-test-suite/provenance.json \
           goldens/windows-x64/010-png-test-suite/provenance.json
    git mv tests/golden/pending/010-png-test-suite/frame.grid \
           goldens/windows-x64/010-png-test-suite/frame.grid
    git mv tests/golden/pending/010-png-test-suite/frame.png \
           goldens/windows-x64/010-png-test-suite/frame.png
    git mv tests/golden/pending/010-png-test-suite/spec.json \
           tests/golden/scenarios/010-png-test-suite/spec.json

`LANDING.md` itself is deleted by the same commit.

**No code change is required.** Both the gate and the offline tests resolve each artefact by
searching `goldens/windows-x64/010-png-test-suite/` FIRST and falling back to
`tests/golden/pending/010-png-test-suite/`, so the move flips them over with nothing to edit. That
is the same shape scenario 012 (bead oo-3ya) uses, deliberately.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit -
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 -m pytest tests/golden/test_png_test_suite.py -q
    python3 tests/golden/check_png_evidence.py goldens/windows-x64/010-png-test-suite/state.json

### Tested, not assumed

The fallback was exercised by actually performing the move in a scratch clone: with the files under
`goldens/windows-x64/010-png-test-suite/` and `tests/golden/scenarios/010-png-test-suite/` and the
`pending/` directory gone, `tests/golden/test_png_test_suite.py` collected and passed unchanged.
The result is recorded in `provenance.json` under `landing_rehearsal`.

## Re-blessing later

Re-run the scenario and overwrite `state.json`, `frame.grid`, `frame.png` and `provenance.json`
together. They are one observation: `provenance.json` records the seed, system, tick count and
tick length the dump was taken with, and `tests/golden/test_png_test_suite.py` asserts `spec.json`
still agrees with them. Updating one without the others is the failure mode that check exists for.

Do **not** edit `frame_hash.TOLERANCE` to make a run pass. It is derived from bead oo-ae9's
measured populations in `tests/golden/calibration.json`; if the renderer genuinely changed,
re-measure with `tests/golden/calibrate.py` and re-bless.
