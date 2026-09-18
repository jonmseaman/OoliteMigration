# Landing scenario 015-trumbles into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY:

    <path> is under a protected golden path and is changed and has no re-bless approval in
    tools/rebless-approvals.txt

A brand-new `goldens/windows-x64/015-trumbles/state.json` trips that guard exactly as an edit to
an existing golden would. Adding the approval line is Jon's call, not a worker's, so this bead
stages the artefacts **outside** the protected path and ships a tested procedure for moving them.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced, including the knobs it was blessed with and the state.json digest that witnesses it |
| `README.md` | the trumble determinism measurement, in full |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/015-trumbles/state.json \
           goldens/windows-x64/015-trumbles/state.json
    git mv tests/golden/pending/015-trumbles/provenance.json \
           goldens/windows-x64/015-trumbles/provenance.json
    git mv tests/golden/pending/015-trumbles/frame.grid \
           goldens/windows-x64/015-trumbles/frame.grid
    git mv tests/golden/pending/015-trumbles/frame.png \
           goldens/windows-x64/015-trumbles/frame.png
    git mv tests/golden/pending/015-trumbles/spec.json \
           tests/golden/scenarios/015-trumbles/spec.json

`LANDING.md` itself is deleted by the same commit; `README.md` moves beside the golden.

**No code change is required.** `tests/golden/trumbles_load.py`, `check_trumbles_evidence.py`,
`test_trumbles_load.py` and every stored acceptance line resolve each artefact by searching
`goldens/windows-x64/015-trumbles/` FIRST and falling back to `tests/golden/pending/015-trumbles/`,
through the identical `ls A B 2>/dev/null | head -1` idiom. That is the shape scenarios 010 and 012
use, deliberately.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit -
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 -m pytest tests/golden/test_trumbles_load.py -q
    python3 tests/golden/check_trumbles_evidence.py goldens/windows-x64/015-trumbles/state.json

The `SPEC_CANDIDATES` / `GOLDEN_CANDIDATES` / `FRAME_CANDIDATES` tuples in `trumbles_load.py` and
the matching `_first()` search in `test_trumbles_load.py` already list both locations in that
order, so nothing needs editing when the files move.
