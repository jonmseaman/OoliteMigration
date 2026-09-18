# Landing scenario 017-thargoid-plans into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY:

    <path> is under a protected golden path and is changed and has no re-bless approval in
    tools/rebless-approvals.txt

A brand-new `goldens/windows-x64/017-thargoid-plans/state.json` trips that guard exactly as an edit
to an existing golden would. Adding the approval line is Jon's call, not a worker's, so this bead
stages the artefacts **outside** the protected path and ships a **rehearsed** procedure for moving
them.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced: the knobs it was blessed with, the 1.75 migration contract, the frame measurements, the 10-run sweep, and the `state.json` digest that witnesses it |
| `README.md` | the measurements, in full, including the two places a measurement overturned the design |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    mkdir -p goldens/windows-x64/017-thargoid-plans tests/golden/scenarios/017-thargoid-plans
    git mv tests/golden/pending/017-thargoid-plans/state.json \
           goldens/windows-x64/017-thargoid-plans/state.json
    git mv tests/golden/pending/017-thargoid-plans/provenance.json \
           goldens/windows-x64/017-thargoid-plans/provenance.json
    git mv tests/golden/pending/017-thargoid-plans/frame.grid \
           goldens/windows-x64/017-thargoid-plans/frame.grid
    git mv tests/golden/pending/017-thargoid-plans/frame.png \
           goldens/windows-x64/017-thargoid-plans/frame.png
    git mv tests/golden/pending/017-thargoid-plans/README.md \
           goldens/windows-x64/017-thargoid-plans/README.md
    git mv tests/golden/pending/017-thargoid-plans/spec.json \
           tests/golden/scenarios/017-thargoid-plans/spec.json
    git rm tests/golden/pending/017-thargoid-plans/LANDING.md

**Note the split**: `spec.json` goes to `tests/golden/scenarios/017-thargoid-plans/`, everything
else to `goldens/windows-x64/017-thargoid-plans/`. That is the order `SPEC_CANDIDATES` and
`GOLDEN_CANDIDATES` search, and the two lists are deliberately different — a sibling bead was
rejected this session for a landing procedure that moved `spec.json` somewhere its own script could
not find it.

**No code change is required.** `thargoid_plans_load.py`, `gate_017_spec.py`,
`check_thargoid_plans_evidence.py`, `test_thargoid_plans_load.py`, `test_gate_017_spec.py` and
every stored acceptance line resolve each artefact by searching the guarded location FIRST and
falling back to `tests/golden/pending/017-thargoid-plans/`, through the identical
`ls A B 2>/dev/null | head -1` idiom. That is the shape scenarios 010, 012 and 015 use.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit —
that is the human decision the guard exists to force, and **a worker must never add it**.

## Rehearsal — performed for real, not described

The move above was executed in a scratch detached worktree and **every stored acceptance line was
re-run afterwards**, all green, with no file edited. Specifically, after the `git mv`s:

    python3 tests/golden/gate_017_spec.py                                   # PASS
    python3 -m pytest tests/golden/test_thargoid_plans_load.py \
                      tests/golden/test_gate_017_spec.py -q                 # 79 passed
    python3 tests/golden/check_thargoid_plans_evidence.py \
            goldens/windows-x64/017-thargoid-plans/state.json               # EVIDENCE OK
    python3 tests/golden/thargoid_plans_load.py --census-only               # resolves the moved spec

The rehearsal is recorded in `provenance.json` under `landing_rehearsal.performed`.

## Verifying the move when it is done for real

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 tests/golden/gate_017_spec.py
    python3 -m pytest tests/golden/test_thargoid_plans_load.py tests/golden/test_gate_017_spec.py -q
    python3 tests/golden/check_thargoid_plans_evidence.py goldens/windows-x64/017-thargoid-plans/state.json
