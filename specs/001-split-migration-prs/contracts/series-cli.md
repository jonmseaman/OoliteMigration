# Contract: `tools/series/series.py`

Python 3 standard library only. Run from the OoliteMigration root; operates on `oolite-dev` and the
manifest at `specs/001-split-migration-prs/series/manifest.json`. Exit codes: `0` success, `1` a
check or verification failed, `2` usage or environment error. Never pushes, never runs
`git town sync` or `propose`, and never touches `develop`, `master` or `main`.

| Command | Does | Exit 0 when |
|---|---|---|
| `inventory` | Lists the history's first-parent commits under `history_prefix` with normalised size, paths, and the upstream commit each sits on. Writes `series/inventory.tsv`. | always (read-only) |
| `cut --chapters` | Writes R14's chapters and tail groups as `planned` steps, resolving each boundary to its first-parent merge and checking that the chapters tile the history with no gaps. Keeps every step's state (by branch name) and the hoisted `independent` steps in front. | manifest written, chapters contiguous |
| `hoist <history-commit>… --slug S [--title T]` | Turns history commits into an `independent` step after any existing ones, if their change (in normalised space) merges cleanly onto `upstream_base` alone and onto the series base; shifts later steps' `n`. Building it is `verify`'s check. Run `renumber` next. | the commits apply and the step is planned |
| `tree <n> [--show PATH\|--record PATH] [--commit LABEL]` | Computes step *n*'s target tree (normalise, 3-way merge onto upstream, apply resolutions); prints the tree id, or the conflicting paths. `--show` writes the conflict-marked file and its upstream/history/base inputs to `.agent-tmp/series-resolve/NNN/`; `--record` stores the edited file (no markers; a missing file means deleted) as the resolution. Both refuse paths under `tests/`. For a tail step, `--commit` names the replayed develop commit the conflict is in. | no unresolved conflicts |
| `build [<n>…\|--from n [--to m]]` | For each step in order: creates or resets `series/NNN-slug` to one commit on the parent tip with the target tree; sets Git Town lineage (`git town append --prototype --no-sync --no-push` on first creation, `git town set-parent` after). | every requested step is `built` |
| `verify <n>\|--from n [--clean] [--integrity-only]` | Runs the verification matrix for the step's era in the shared verification worktree (research R9); writes the verification record. | every check is `pass` or justified `n/a` |
| `describe <n>\|--handover` | Writes or refreshes the generated parts of `series/pr/NNN-slug.md` (size, source range, verification, position) and keeps the hand-written sections. With `--handover`, writes `series/HANDOVER.md` (anchors, exclusions, ledger, and per step the push and `gh pr create` commands for Jon). | file has every required section |
| `check [--verified] [--only <group>] [--steps a-b]` | Validates the manifest, branches, lineage and trees against `data-model.md`'s rules. Groups: `manifest`, `branches`, `lineage`, `trees`, `descriptions`, `final-tree`, `ledger`, and with `--verified` `verified` (each record passes and still describes its branch). | all selected rules hold |
| `renumber` | After inserting or removing a step: renames branches (with their Git Town keys), description files and resolution directories, and rewrites the manifest and lineage to keep `NNN` = `n`. | `check` passes afterwards |

## Files

```text
specs/001-split-migration-prs/series/
├── manifest.json          # anchors, steps, exclusions, ledger (data-model.md)
├── inventory.tsv          # output of `inventory`
├── resolutions/NNN/      # index.json + files/<path>: whole resolved files keyed by their inputs (tail steps: NNN/<commit>/)
├── pr/NNN-slug.md         # one PR description per step (pr-description.md)
└── HANDOVER.md            # Jon's push and open-PR commands, generated
```
