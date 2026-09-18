# Landing scenario 005 into `goldens/`

**Nothing in this bead writes under `goldens/`.** Blessing a guarded path is Jon's decision alone,
via `tools/rebless-approvals.txt`. The artifacts are staged here instead.

## Landing is a pure `git mv`

Both the scenario script and every acceptance line resolve their artifacts through the *identical*
idiom — the guarded path **first**, this pending directory as fallback:

```sh
G=$( { ls goldens/windows-x64/005-mission-trigger/state.json \
        tests/golden/pending/005-mission-trigger/state.json 2>/dev/null || true; } | head -1 )
```

(The subshell matters: `ls A B | head -1` exits 2 when a path is missing, and under
`set -o pipefail` that becomes the line's status.)

So landing requires **no code change**:

```sh
mkdir -p goldens/windows-x64/005-mission-trigger
git mv tests/golden/pending/005-mission-trigger/state.json      goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/frame.grid      goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/provenance.json goldens/windows-x64/005-mission-trigger/
git mv tests/golden/pending/005-mission-trigger/spec.json       tests/golden/scenarios/005-mission-trigger/spec.json
```

Then re-run `acceptance.txt`; every line should report the `goldens/...` paths instead of the
pending ones, with identical verdicts.

## What must NOT happen at landing

- **Do not regenerate the artifacts.** `state.json` is byte-hashed in `provenance.json`; a
  regenerated dump that differs is a **finding**, not a file to overwrite.
- **Do not update a digest to make a line pass.** If `state.json` and `provenance.json` disagree,
  one of them was edited alone. A deliberate re-bless moves both together.
- **Do not byte-hash `frame.grid`.** llvmpipe is not bit-reproducible; the frame is compared with
  the measured tolerance and that asymmetry is intentional.
- **Do not widen `expected_spawned_roles` to include `asp-pirate`.** That role is also the ordinary
  Asp's and the ambient populator writes to it; counting it made 2 of 10 runs fail. See README.md.

## Rehearsal

The fallback path was exercised end-to-end from this pending directory: all seven acceptance lines
pass, including the live line that launches the game, reproduces the blessed dump byte-for-byte and
compares the rendered frame within tolerance.
