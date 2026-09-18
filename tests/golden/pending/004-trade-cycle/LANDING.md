# Landing scenario 004-trade-cycle into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses **any** change there
without a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from
MODIFY, so a brand-new `goldens/windows-x64/004-trade-cycle/state.json` trips the guard exactly as
an edit to an existing golden would. Adding the approval line is Jon's call, not a worker's, so this
bead stages the artefacts **outside** the protected path and ships a **rehearsed** procedure.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block (3055 bytes) |
| `frame.grid` | 4096-byte 64×64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced: the knobs it was blessed with, the 10-run stability table, the frame measurements, and the `state.json` digest that witnesses it |
| `README.md` | the trade-cycle design and every measurement, in full |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    mkdir -p goldens/windows-x64/004-trade-cycle tests/golden/scenarios/004-trade-cycle

    git mv tests/golden/pending/004-trade-cycle/state.json \
           goldens/windows-x64/004-trade-cycle/state.json
    git mv tests/golden/pending/004-trade-cycle/provenance.json \
           goldens/windows-x64/004-trade-cycle/provenance.json
    git mv tests/golden/pending/004-trade-cycle/frame.grid \
           goldens/windows-x64/004-trade-cycle/frame.grid
    git mv tests/golden/pending/004-trade-cycle/frame.png \
           goldens/windows-x64/004-trade-cycle/frame.png
    git mv tests/golden/pending/004-trade-cycle/README.md \
           goldens/windows-x64/004-trade-cycle/README.md
    git mv tests/golden/pending/004-trade-cycle/spec.json \
           tests/golden/scenarios/004-trade-cycle/spec.json

    git rm tests/golden/pending/004-trade-cycle/LANDING.md

**Note the spec goes to a DIFFERENT destination** from the rest. `spec.json` is the run's input and
lives beside the other scenarios' specs under `tests/golden/scenarios/<name>/`; everything else is
the blessed *output* and lives under the guarded `goldens/windows-x64/<name>/`. That split is not
cosmetic — `SPEC_CANDIDATES` and `GOLDEN_CANDIDATES` in both `trade_cycle.py` and `gate_004_spec.py`
search **different** first-choice directories, so moving the spec into `goldens/` would leave the
gate unable to find it. A sibling bead was rejected this session for exactly that mistake, which is
why the procedure below was rehearsed rather than described.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit —
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"            # expect RC=0 with the approval line present
    python3 tests/golden/gate_004_spec.py
    python3 tests/golden/check_trade_cycle_evidence.py \
            goldens/windows-x64/004-trade-cycle/state.json --label "landed golden"
    python3 -m pytest tests/golden/test_trade_cycle.py -q

## Rehearsal record

**Performed, not described.** The whole tree was copied to a throwaway directory under
`%LOCALAPPDATA%\Temp`, the six moves above were applied there with plain `mv` (the copy is not a git
worktree), and all four verification commands were re-run from the moved layout. Every gate resolved
its artefacts through the *guarded* first candidate with no code change, and `gate_004_spec.py`
reported `agree with the knobs recorded in goldens/windows-x64/004-trade-cycle` — i.e. it really did
read the moved provenance, not the staged one. The throwaway copy was then deleted.

**No code change is required.** `trade_cycle.py`, `check_trade_cycle_evidence.py`,
`gate_004_spec.py`, `test_trade_cycle.py` and every stored acceptance line resolve each artefact by
searching the guarded location **first** and falling back to `tests/golden/pending/004-trade-cycle/`.
The acceptance lines use the brace-group form

    G=$( { ls goldens/... tests/golden/pending/... 2>/dev/null || true; } | head -1 )

deliberately: a bare `ls A B | head -1` exits 2 when a named operand is missing, and `accept.sh` runs
each line under `bash -o pipefail -c`, so the plain idiom kills a correct gate before it runs (bead
oo-rad lost four attempts to exactly that).
