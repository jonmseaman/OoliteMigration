# Landing scenario 005 into `goldens/`

**Nothing in this bead writes under `goldens/`.** Blessing a guarded path is Jon's decision alone,
via `tools/rebless-approvals.txt`. The artifacts are staged here instead.

## Two resolvers, two destinations — read this before moving anything

The four staged artifacts do **not** all land in the same place, because they are resolved by two
different candidate lists and those lists have different *first* candidates:

| artifact | resolved by | first candidate (landed) | fallback (staged) |
|---|---|---|---|
| `state.json` | acceptance lines 1, 5, 6, 7 and `mission_trigger.py` `GOLDEN_CANDIDATES` | `goldens/windows-x64/005-mission-trigger/state.json` | `tests/golden/pending/005-mission-trigger/state.json` |
| `frame.grid` | acceptance lines 1, 5, 7 and `mission_trigger.py` `FRAME_CANDIDATES` | `goldens/windows-x64/005-mission-trigger/frame.grid` | same pending dir |
| `provenance.json` | acceptance lines 1, 5, 6 and `test_mission_trigger.py` `PROVENANCE_CANDIDATES` | `goldens/windows-x64/005-mission-trigger/provenance.json` | same pending dir |
| `spec.json` | acceptance lines 1, 2, 3 and `mission_trigger.py` / `test_mission_trigger.py` `SPEC_CANDIDATES` | **`tests/golden/scenarios/005-mission-trigger/spec.json`** | same pending dir |

`spec.json` is the odd one out **by repo convention, not by accident**: a spec is not a blessed
measurement, it is the input that produced one, so every scenario in this repo (001, 003, 009, …)
keeps it under `tests/golden/scenarios/<scenario>/` rather than under the guarded `goldens/` tree.
`mission_trigger.py:93-96` and `test_mission_trigger.py:31-33` both encode that, and as of this
bead the acceptance lines' spec candidate list **matches them exactly**:

```sh
S=$( { ls tests/golden/scenarios/005-mission-trigger/spec.json \
        tests/golden/pending/005-mission-trigger/spec.json 2>/dev/null || true; } | head -1 )
G=$( { ls goldens/windows-x64/005-mission-trigger/state.json \
        tests/golden/pending/005-mission-trigger/state.json 2>/dev/null || true; } | head -1 )
```

(The subshell matters: `ls A B | head -1` exits 2 when a path is missing, and under
`set -o pipefail` that becomes the line's status.)

An earlier revision of this file claimed a single idiom covered all four artifacts. It did not:
the acceptance lines searched `goldens/…/spec.json` while both Python resolvers searched
`tests/golden/scenarios/…/spec.json`, so **no** placement satisfied both and landing was broken in
either direction. The candidate list in the acceptance lines was corrected, not the resolvers.

## Landing is a pure `git mv`

```sh
mkdir -p goldens/windows-x64/005-mission-trigger tests/golden/scenarios/005-mission-trigger
git mv tests/golden/pending/005-mission-trigger/state.json      goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/frame.grid      goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/provenance.json goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/spec.json       tests/golden/scenarios/005-mission-trigger/spec.json
```

Then re-run `acceptance.txt`; every line should report the landed paths (`goldens/…` for the
golden, provenance and frame; `tests/golden/scenarios/…` for the spec) with identical verdicts.
`README.md`, `LANDING.md` and `acceptance.txt` stay in the pending directory as documentation.

## What must NOT happen at landing

- **Do not regenerate the artifacts.** `state.json` is byte-hashed in `provenance.json`; a
  regenerated dump that differs is a **finding**, not a file to overwrite.
- **Do not update a digest to make a line pass.** If `state.json` and `provenance.json` disagree,
  one of them was edited alone. A deliberate re-bless moves both together.
- **Do not byte-hash `frame.grid`.** llvmpipe is not bit-reproducible; the frame is compared with
  the measured tolerance and that asymmetry is intentional.
- **Do not widen `expected_spawned_roles` to include `asp-pirate`.** That role is also the ordinary
  Asp's and the ambient populator writes to it; counting it made 2 of 10 runs fail. See README.md.
- **Do not move `spec.json` under `goldens/`.** The two Python resolvers would stop finding it and
  the scenario script refuses with `no spec.json for 005-mission-trigger`.

## Rehearsal

Two arms were exercised, both under `bash -o pipefail -c`, the shell `accept.sh` uses.

1. **Staged (pending) arm** — all seven acceptance lines run from this pending directory, including
   the live line that launches the game, reproduces the blessed dump byte-for-byte and compares the
   rendered frame within tolerance.
2. **Landed arm** — in a scratch `git worktree add --detach` checkout merged with this branch, the
   four `git mv` commands above were performed verbatim and all seven lines were replayed. Result
   recorded in `provenance.json` under `landing_rehearsal`.

The *original* version of this document claimed the landed arm had been rehearsed when only the
staged arm had been; that is what hid the spec-path contradiction above. Do not re-record
`landing_rehearsal.performed: true` for an arm you did not actually run.
