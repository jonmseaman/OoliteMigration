# Landing procedure for golden scenario 003-combat

This directory holds a golden that is **staged, not blessed**.

## Why it is here and not under `goldens/`

`tools/guardrails.sh` protects two prefixes:

```
PROTECTED_PREFIXES="goldens/ tests/golden/scenarios/"
```

Any change under either requires a human approval line in `tools/rebless-approvals.txt`, added by
Jon in a **separate prior commit** — and the approvals file itself refuses a change that touches
both it and a protected path, so an agent cannot approve its own work (CLAUDE.md hard rule 1).

**The guard does not distinguish CREATE from MODIFY.** Bead oo-8ij established this by A/B
control, and it was re-confirmed for *both* protected prefixes while building this scenario, on
this tree, at base `9094649`:

| arm | tree | result | rc |
|---|---|---|---|
| A | this bead's files, none under a protected prefix | `guardrails: OK (goldens, suppression, tests, deny-list) against 9094649` | 0 |
| B | same tree plus brand-new `tests/golden/scenarios/003-combat/{spec.json,README.md}` | `guardrails: goldens: tests/golden/scenarios/003-combat/spec.json is under a protected golden path and is changed and has no re-bless approval in tools/rebless-approvals.txt` … `guardrails: FAIL` | 1 |

Arm B named *both* new files and failed. Neither had ever existed before, so creating a golden is
refused exactly as modifying one is. `goldens/windows-x64/003-combat/` would fail identically.

**Do not add a line to `tools/rebless-approvals.txt`.** That is Jon's decision alone.

## What the gate does in the meantime

Every acceptance line resolves the golden, the provenance and the spec by searching the **guarded
location first** and falling back to this directory:

```sh
G=$(ls goldens/windows-x64/003-combat/state.json \
       tests/golden/pending/003-combat/state.json 2>/dev/null | head -1)
```

`tests/golden/gate_003_spec.py`, `tests/golden/combat.py` and `tests/golden/test_combat.py` all do
the same in Python (`GOLDEN_CANDIDATES` / `SPEC_CANDIDATES`). So the gate is fully live today
against the staged copy, and **nothing has to change** when the golden lands — the same lines
start reading the blessed copy the moment it exists.

## Procedure to land it (for Jon)

1. Review `README.md` beside this file, in particular the three findings that make a combat
   golden reproducible at all and the explicit statement of what this golden does **not** pin
   (AI target selection, weapon aiming, hit probability — all nondeterministic on this build).

2. Verify the staged artifacts on the current tree:

   ```sh
   export PATH=/ucrt64/bin:$PATH
   python3 tests/golden/gate_003_spec.py
   python3 tests/golden/check_combat_evidence.py tests/golden/pending/003-combat/state.json
   python3 -m pytest tests/golden/test_combat.py -q
   ```

   Re-confirm the dump still reproduces (the bead measured 10/10 byte-identical,
   md5 `54ff0e9d8fbe2a0564fc4cf4208c9bbc`, 1848 bytes):

   ```sh
   python3 tests/golden/combat.py --out "$LOCALAPPDATA/Temp/fresh.json" \
                                  --run-root "$LOCALAPPDATA/Temp/oo003"
   python3 tests/golden/golden_diff.py tests/golden/pending/003-combat/state.json \
                                       "$LOCALAPPDATA/Temp/fresh.json"
   ```

3. In a commit that touches **nothing else**, append the approval line to
   `tools/rebless-approvals.txt` in whatever form that file specifies.

4. In a **second** commit, move the four files:

   ```sh
   mkdir -p goldens/windows-x64/003-combat
   git mv tests/golden/pending/003-combat/state.json      goldens/windows-x64/003-combat/state.json
   git mv tests/golden/pending/003-combat/provenance.json goldens/windows-x64/003-combat/provenance.json
   mkdir -p tests/golden/scenarios/003-combat
   git mv tests/golden/pending/003-combat/spec.json       tests/golden/scenarios/003-combat/spec.json
   git mv tests/golden/pending/003-combat/README.md       tests/golden/scenarios/003-combat/README.md
   ```

   Keep this `LANDING.md` or delete it; nothing reads it.

5. Re-run the gate. It should report `... match the values recorded in
   goldens/windows-x64/003-combat` — the changed path in the PASS message is the proof the
   fallback flipped to the guarded copy. Then:

   ```sh
   bash tools/guardrails.sh   # expect rc=0
   ```

## Note on `PROTECTED_PREFIXES_PENDING`

`tools/guardrails.sh` currently emits, on a completely clean tree:

```
guardrails: goldens: goldens/ is populated (5 files) but is still listed in
PROTECTED_PREFIXES_PENDING - that exemption is stale and should be deleted
```

That is a **pre-existing** advisory, not caused by this bead (it is present with `git stash -u` on
the untouched tree, alongside `guardrails: OK` and rc=0). It belongs to whoever owns
`tools/guardrails.sh`; this bead deliberately does not touch that file.
