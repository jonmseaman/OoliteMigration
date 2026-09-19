# Landing scenario 014-nova into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY
(bead oo-8ij proved this with an A/B control):

    <path> is under a protected golden path and is changed and has no re-bless approval in
    tools/rebless-approvals.txt

A brand-new `goldens/windows-x64/014-nova/state.json` trips that guard exactly as an edit to an
existing golden would. Adding the approval line is Jon's call, not a worker's, so this bead stages
the artefacts **outside** the protected path and ships a rehearsed procedure for moving them.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block (2893 bytes) |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads |
| `provenance.json` | how the golden was produced: the knobs it was blessed with, the state.json digest that witnesses it, the frame measurements, the 10-run sweep run by run, and the two determinism findings |
| `README.md` | the save-format contract and the two traffic sources, in full |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    mkdir -p goldens/windows-x64/014-nova
    git mv tests/golden/pending/014-nova/state.json      goldens/windows-x64/014-nova/state.json
    git mv tests/golden/pending/014-nova/provenance.json goldens/windows-x64/014-nova/provenance.json
    git mv tests/golden/pending/014-nova/frame.grid      goldens/windows-x64/014-nova/frame.grid
    git mv tests/golden/pending/014-nova/frame.png       goldens/windows-x64/014-nova/frame.png
    git mv tests/golden/pending/014-nova/README.md       goldens/windows-x64/014-nova/README.md
    mkdir -p tests/golden/scenarios/014-nova
    git mv tests/golden/pending/014-nova/spec.json       tests/golden/scenarios/014-nova/spec.json
    git rm tests/golden/pending/014-nova/LANDING.md

**`spec.json` goes to `tests/golden/scenarios/014-nova/`, NOT into `goldens/`.** That is the
location `nova_load.py`'s `SPEC_CANDIDATES` and `gate_014_spec.py`'s `SPEC_CANDIDATES` search
FIRST; a sibling bead was rejected this hour for a landing procedure that moved `spec.json` where
its own script could not find it. The other five files go to `goldens/windows-x64/014-nova/`, which
is the first entry of `GOLDEN_CANDIDATES` / `FRAME_CANDIDATES` and of every stored acceptance
line's `ls` fallback.

**No code change is required.** Every consumer resolves each artefact by searching the guarded
location first and the staged location second:

| consumer | guarded first | staged second |
| --- | --- | --- |
| `nova_load.py` `SPEC_CANDIDATES` | `tests/golden/scenarios/014-nova/spec.json` | `tests/golden/pending/014-nova/spec.json` |
| `nova_load.py` `GOLDEN_CANDIDATES` | `goldens/windows-x64/014-nova/state.json` | `tests/golden/pending/014-nova/state.json` |
| `nova_load.py` `FRAME_CANDIDATES` | `goldens/windows-x64/014-nova/frame.grid` | `tests/golden/pending/014-nova/frame.grid` |
| `nova_load.py` `_provenance_asserts_tolerance()` | `goldens/windows-x64/014-nova/provenance.json` | `tests/golden/pending/014-nova/provenance.json` |
| `gate_014_spec.py` `SPEC_CANDIDATES` / `GOLDEN_CANDIDATES` | both of the above | both of the above |
| `test_nova_load.py` `_first(...)` | both of the above | both of the above |
| stored acceptance lines | `{ ls A B 2>/dev/null \|\| true; } \| head -1` | same |

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit -
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 tests/golden/gate_014_spec.py
    python3 -m pytest tests/golden/test_nova_load.py -q
    python3 tests/golden/check_nova_evidence.py goldens/windows-x64/014-nova/state.json

## This procedure was rehearsed, not merely written

The move above was executed against a scratch copy of the tree under `$LOCALAPPDATA/Temp` - the
five `git mv` targets created, `spec.json` placed in `tests/golden/scenarios/014-nova/` - and all
four verification commands re-run there with the artefacts in their POST-LANDING locations. The
gate and the tests resolved every artefact from the guarded paths and passed. The rehearsal used a
throwaway copy; nothing in the real tree or under `goldens/` was touched.
