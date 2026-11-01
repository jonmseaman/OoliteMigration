# Contract: `tools/series/series.py`

Python 3 standard library only. Run from the OoliteMigration root; operates on `oolite-dev` and the
manifest at `specs/001-split-migration-prs/series/manifest.json`. Exit codes: `0` success, `1` a
check or verification failed, `2` usage or environment error. Never pushes, never runs
`git town sync` or `propose`, and never touches `develop`, `master` or `main`.

| Command | Does | Exit 0 when |
|---|---|---|
| `inventory` | Lists the history's first-parent commits under `history_prefix` with normalised size, paths, and the upstream commit each sits on. Writes `series/inventory.tsv`. | always (read-only) |
| `cut [--limit 3000]` | Proposes cut points from the inventory (research R6) and writes `planned` steps into the manifest. Does not overwrite steps already `built`. | manifest written |
| `hoist <history-commit>… --slug S` | Turns history commits into an `independent` step at the front, if they apply to `upstream_base` alone. | the commits apply and the step is planned |
| `tree <n>` | Computes step *n*'s target tree (normalise, 3-way merge onto upstream, apply resolutions); prints the tree id, or the conflicting paths. | no unresolved conflicts |
| `build [<n>…\|--from n]` | For each step in order: creates or resets `series/NNN-slug` to one commit on the parent tip with the target tree; sets Git Town lineage (`git town append --prototype --no-sync --no-push` on first creation, `git town set-parent` after). | every requested step is `built` |
| `verify <n>\|--from n [--clean]` | Runs the verification matrix for the step's era in the shared verification worktree (research R7); writes the verification record. | every check is `pass` or justified `n/a` |
| `describe <n>` | Writes or refreshes the generated parts of `series/pr/NNN-slug.md` (size, source range, verification, position); keeps the hand-written sections. | file has every required section |
| `check [--verified]` | Validates the manifest, branches, lineage and trees against `data-model.md`'s rules. | all rules hold |
| `renumber` | After inserting or removing a step: renames branches and description files, and rewrites the manifest and lineage to keep `NNN` = `n`. | `check` passes afterwards |

## Files

```text
specs/001-split-migration-prs/series/
├── manifest.json          # anchors, steps, exclusions, ledger (data-model.md)
├── inventory.tsv          # output of `inventory`
├── resolutions/NNN/<path>.patch   # conflict resolutions, applied by `tree`
└── pr/NNN-slug.md         # one PR description per step (pr-description.md)
```
