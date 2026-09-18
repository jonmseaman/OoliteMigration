# Landing scenario 013 into the guarded paths — blocked on a re-bless approval

## The blocker

`tools/guardrails.sh` protects two prefixes: `goldens/` and `tests/golden/scenarios/`. The
protected-path check does **not** distinguish a modification from a brand-new file — every changed
path under a protected prefix demands an approval line in `tools/rebless-approvals.txt`, additions
included. Bead `oo-3ya` verified this empirically for scenario 012 (see that scenario's
`LANDING.md` for the transcript); nothing about the guard has changed, so this bead did not repeat
the probe and instead staged its artefacts under `tests/golden/pending/` from the start.

**`tools/rebless-approvals.txt` was NOT edited.** The guard refuses a change that touches both a
protected path and the approvals file — *a change may not approve itself* — and adding an approval
is Jon's decision alone (CLAUDE.md rule 1).

| staged now | lands at |
|---|---|
| `tests/golden/pending/013-constrictor/spec.json` | `tests/golden/scenarios/013-constrictor/spec.json` |
| `tests/golden/pending/013-constrictor/README.md` | `tests/golden/scenarios/013-constrictor/README.md` |
| `tests/golden/pending/013-constrictor/state.json` | `goldens/windows-x64/013-constrictor/state.json` |
| `tests/golden/pending/013-constrictor/provenance.json` | `goldens/windows-x64/013-constrictor/provenance.json` |
| `tests/golden/pending/013-constrictor/frame.grid` | `goldens/windows-x64/013-constrictor/frame.grid` |

## Why no code has to change when they land

`constrictor_save.py`, `test_constrictor_save.py` and `scenario_013.sh` all search **both**
locations, blessed path first, through the **identical** idiom:

```python
SPEC_CANDIDATES = (repo/"tests/golden/scenarios/013-constrictor/spec.json",
                   here/"pending/013-constrictor/spec.json")
```

```bash
G=$(ls goldens/windows-x64/013-constrictor/state.json \
       tests/golden/pending/013-constrictor/state.json 2>/dev/null | head -1)
```

The stored acceptance block uses the same `ls … | head -1` idiom, so every line keeps passing on
either side of the move. Landing is a pure `git mv`.

## The procedure, once Jon has added the approvals

1. Jon lands, in a **separate commit of his own**, five lines starting in column one of
   `tools/rebless-approvals.txt` (an approval names **one file**; a directory prefix is not
   accepted):

   ```
   tests/golden/scenarios/013-constrictor/spec.json      Jon <date>, bead oo-5h8e: new scenario
   tests/golden/scenarios/013-constrictor/README.md      Jon <date>, bead oo-5h8e: new scenario
   goldens/windows-x64/013-constrictor/state.json        Jon <date>, bead oo-5h8e: first bless
   goldens/windows-x64/013-constrictor/provenance.json   Jon <date>, bead oo-5h8e: first bless
   goldens/windows-x64/013-constrictor/frame.grid        Jon <date>, bead oo-5h8e: first bless
   ```

2. On a branch based on that commit:

   ```bash
   cd <repo root>
   mkdir -p tests/golden/scenarios/013-constrictor goldens/windows-x64/013-constrictor
   git mv tests/golden/pending/013-constrictor/spec.json \
          tests/golden/scenarios/013-constrictor/spec.json
   git mv tests/golden/pending/013-constrictor/README.md \
          tests/golden/scenarios/013-constrictor/README.md
   git mv tests/golden/pending/013-constrictor/state.json \
          goldens/windows-x64/013-constrictor/state.json
   git mv tests/golden/pending/013-constrictor/provenance.json \
          goldens/windows-x64/013-constrictor/provenance.json
   git mv tests/golden/pending/013-constrictor/frame.grid \
          goldens/windows-x64/013-constrictor/frame.grid
   ```

3. Prove the move changed nothing:

   ```bash
   export PATH=/ucrt64/bin:$PATH
   bash tools/guardrails.sh                                     # must print PASS
   python3 -m pytest tests/golden/test_constrictor_save.py -q   # must stay fully green
   python3 tests/golden/check_constrictor_evidence.py \
       goldens/windows-x64/013-constrictor/state.json           # must stay rc=0
   git show --stat                                              # must be 5 pure renames, R100
   ```

3a. **Verify the landed bytes are the bytes that were blessed.** `provenance.json` records
    `artifacts["state.json"].sha256` and `.bytes` and `artifacts["frame.grid"].sha256`; the
    acceptance block already asserts the golden against them, so simply replaying the block after
    the move is the check. Pass forward-slash paths to `md5sum` — GNU `md5sum` prefixes its output
    with a backslash when the filename contains one, silently yielding a truncated 31-character
    digest.

    `state.json` is 2851 bytes, md5 `f9c9e6e2ecf2254bb1c87337d0035202`, and that digest is the one
    **all 10 stability runs** produced — so a mismatch here means the file changed in transit, not
    that the scenario drifted.

4. Replay the bead's stored acceptance block. Nothing in it hard-codes `pending/`.

**Do not** move these files without step 1 on record, and do not add the approval lines yourself:
the guard refuses a self-approving change, and that refusal is the mechanism, not an obstacle.
