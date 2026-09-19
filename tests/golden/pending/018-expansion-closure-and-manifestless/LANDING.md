# Landing scenario 018-expansion-closure-and-manifestless into `goldens/`

## Why this golden is not already in `goldens/`

`tools/guardrails.sh` treats `goldens/**` as a protected path and refuses ANY change there without
a matching line in `tools/rebless-approvals.txt`. It does **not** distinguish CREATE from MODIFY:

    <path> is under a protected golden path and is changed and has no re-bless approval in
    tools/rebless-approvals.txt

A brand-new `goldens/windows-x64/018-expansion-closure-and-manifestless/state.json` trips that
guard exactly as an edit to an existing golden would. Adding the approval line is Jon's call, not a
worker's, so this bead stages the artefacts **outside** the protected path and ships a tested
procedure for moving them.

## What is staged here

| file | what it is |
| --- | --- |
| `state.json` | the blessed dump: quantised world state plus the `evidence` block that carries both launches' search paths, refusal diagnostics and standards-error attribution |
| `frame.grid` | 4096-byte 64x64 luminance grid of the blessed frame (`tests/golden/frame_hash.py`) |
| `frame.png` | the blessed frame itself, for a human to look at |
| `spec.json` | every determinism knob the run reads, including the closure and the manifest-less fixture |
| `provenance.json` | how the golden was produced: the knobs it was blessed with, the 10-run sweep, the frame measurements, the two live mutant arms, and the `state.json` digest that witnesses it from outside |
| `README.md` | the scenario in full: the differential, the `ResourceManager` citations, what goes RED and why |

## The procedure

Run from the repo root, on `main`, after this bead's branch has merged.

    git mv tests/golden/pending/018-expansion-closure-and-manifestless/state.json \
           goldens/windows-x64/018-expansion-closure-and-manifestless/state.json
    git mv tests/golden/pending/018-expansion-closure-and-manifestless/provenance.json \
           goldens/windows-x64/018-expansion-closure-and-manifestless/provenance.json
    git mv tests/golden/pending/018-expansion-closure-and-manifestless/frame.grid \
           goldens/windows-x64/018-expansion-closure-and-manifestless/frame.grid
    git mv tests/golden/pending/018-expansion-closure-and-manifestless/frame.png \
           goldens/windows-x64/018-expansion-closure-and-manifestless/frame.png
    git mv tests/golden/pending/018-expansion-closure-and-manifestless/README.md \
           goldens/windows-x64/018-expansion-closure-and-manifestless/README.md
    git mv tests/golden/pending/018-expansion-closure-and-manifestless/spec.json \
           tests/golden/scenarios/018-expansion-closure-and-manifestless/spec.json

`LANDING.md` itself is deleted by the same commit.

**No code change is required.** `tests/golden/expansion_closure.py`, `check_018_evidence.py`,
`gate_018_spec.py` and `test_expansion_closure.py` resolve each artefact by searching
`goldens/windows-x64/018-expansion-closure-and-manifestless/` FIRST and falling back to
`tests/golden/pending/018-expansion-closure-and-manifestless/`, through the identical
`ls A B 2>/dev/null | head -1` idiom the stored acceptance lines use. That is the shape scenarios
010, 012 and 015 use, deliberately, and every stored acceptance line for this bead is written in
the same two-candidate form so it stays green across the move.

Whoever lands it must add the approval line to `tools/rebless-approvals.txt` in the same commit —
that is the human decision the guard exists to force, and **a worker must never add it**.

## Verifying the move

    bash tools/guardrails.sh; echo "RC=$?"          # expect RC=0 with the approval line present
    python3 -m pytest tests/golden/test_expansion_closure.py -q
    python3 tests/golden/gate_018_spec.py
    python3 tests/golden/check_018_evidence.py \
        goldens/windows-x64/018-expansion-closure-and-manifestless/state.json
    python3 tests/golden/expansion_closure.py --check-frame \
        goldens/windows-x64/018-expansion-closure-and-manifestless/frame.grid

All five are offline and take under 5 seconds combined; none of them launches the game. The live
re-run is the sixth check and is optional at landing time:

    python3 tests/golden/expansion_closure.py --out "$W/fresh.json" --frame-out "$W/fresh.grid"
    python3 tests/golden/expansion_closure.py --check-evidence "$W/fresh.json" --label "fresh run"
    python3 tests/golden/golden_diff.py \
        goldens/windows-x64/018-expansion-closure-and-manifestless/state.json "$W/fresh.json"

Before that one, confirm `ps -W | grep -ci oolite` reads `0`. An orphaned `oolite.exe` keeps console
port 8563 bound and keeps handles on its staged app copy, which poisons the run with
`TimeoutExpired` or `no answer to system.name within 15s` rather than a real verdict.

## What a landing reviewer should look at first

1. `provenance.json` → `stability`: 10 runs, 10 DUMPED, **one** dump digest, **ten** frame digests.
   The asymmetry is the point — the dump is quantised and deterministic, the frame is llvmpipe.
2. `provenance.json` → `frame_liveness.margin.reading`: the floor sits 10.8x above the measured
   same-scene noise and at 0.62x of the dimmest real frame.
3. `provenance.json` → `mutants`: both live arms, with their measured rc, wall time and message.
4. `state.json` → `evidence.control_primary_in_search_paths` is `false` and
   `evidence.control_requirement_missing_lines` names the primary. That pair **is** the scenario;
   everything else supports it.
