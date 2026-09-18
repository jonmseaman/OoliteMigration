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

Both arms were exercised under `bash -o pipefail -c`, the shell `accept.sh` uses, replaying the
**stored** acceptance block with `RAN == stored == 7` asserted on each arm.

1. **Staged (pending) arm** — lines 1–6 `rc=0` from this pending directory; line 7 (the live
   launch) was green in the worker's own worktree at bless time, reproducing the blessed dump
   byte-for-byte and comparing the rendered frame within tolerance.
2. **Landed arm** — a scratch `git worktree add --detach` on `main`, `git merge --no-edit
   bead/oo-rkm`, then the four `git mv` commands above **verbatim**. Lines 1–6 `rc=0`, line 1
   reporting `spec=tests/golden/scenarios/005-mission-trigger/spec.json` and
   `golden/prov/frame=goldens/windows-x64/005-mission-trigger/…`.

**Line 7 on the landed arm is UNVERIFIED UNDER LOAD, not failed.** Six replays returned `rc=1`
with instrument failures only — `subprocess.TimeoutExpired … after 10 seconds`, `ConsoleError: no
answer to 'system.name' within 15s`, `rm: Device or resource busy` — each with five or six sibling
`oolite.exe` processes launching the same build concurrently and sharing the debug console port.
Line 7 is **byte-identical** to its pre-fix revision (this change touched only lines 1–3) and was
measured green 3/3 at 56 s/49 s/106 s on this tree on a quiet box. A 10-second subprocess timeout
cannot survive six concurrent launches: that is contention, not a regression. Re-run it on a quiet
machine before accepting.

The *original* version of this document claimed the landed arm had been rehearsed when only the
staged arm had been; that is what hid the spec-path contradiction above. Do not record
`landing_rehearsal.performed: true` for an arm you did not actually run.
