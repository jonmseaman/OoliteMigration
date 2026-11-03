# Data model: the `seriesb` manifest

File: `specs/002-seriesb-rebase-stack/series/manifest.json`. It has the same shape as feature 001's
manifest (`specs/001-split-migration-prs/data-model.md`), with the differences below. Feature 001's
manifest is never written by `--series seriesb` (FR-009).

## Top level

```text
{
  "anchors":    { see below },
  "parents":    [ Parent, … ],          # new
  "steps":      [ Step, … ],
  "dropped":    [ DroppedStep, … ],     # new
  "exclusions": [ … ],                  # as feature 001: develop has it, the series does not
  "additions":  [ Addition, … ],        # new: the series has it, develop does not (research R5)
  "ledger":     [ … ],                  # temporary code, as feature 001
  "syncs":      [ SyncRecord, … ]       # new (research R9)
}
```

## anchors

| Field | Meaning |
|---|---|
| `develop_target` | `develop` commit the last step must equal (`3aa8d65e8`) |
| `upstream_master` | upstream `master` both PRs are based on (`7437f22a5`) |
| `old_manifest` | `specs/001-split-migration-prs/series/manifest.json`; replay sources come from it |
| `format` | as feature 001 (clang-format 22.1.8) |

## Parent

| Field | Meaning | Rule |
|---|---|---|
| `branch` | `seriesb/000a-upstream-767-quickjs-option`, … | prefix `seriesb/000[a-z]-` |
| `kind` | `upstream` or `fix-parent` | `fix-parent` only with a Notes entry naming Jon's choice (FR-003a) |
| `upstream_pr` | 767, 768 (absent for `fix-parent`) | |
| `tracking` | `hobleyd/quickjs-poc`, `hobleyd/quickjs-default` | an `upstream` parent's tip must equal its tracking branch |
| `head` | PR head the parent mirrors at the last build or sync | |
| `parent` | Git Town parent: `develop` for `000a`, previous parent otherwise | |
| `git_town_type` | `observed` (`upstream`) / `prototype` (`fix-parent`) | |
| `verification` | as a step's record; see Gate | |
| `gate` | `pass`, `flagged` (with `flag`: what fails and why), or `waived` (with the Notes reference) | no step may be built while any parent is `flagged` |

## Step (differences from feature 001)

| Field | Meaning | Rule |
|---|---|---|
| `branch` | `seriesb/NNN-slug` | `NNN` = `n`, contiguous from 001 (FR-006) |
| `parent` | previous step, or the last parent for step 1 | lineage in Git Town equals this |
| `source` | `{type: "replay", old_step: k, old_branch, old_commit}` | `old_step` strictly increasing across steps (FR-004) |
| `resolutions` | `[{path, how: stored\|auto\|theirs-rule, reason}]` | each path with a different resolution from the old step has a `reason` |
| `differs_from_old` | paths where this step's change differs from the old step's change, each with a reason | every such path is in `resolutions` or `additions` (SC-006) |
| `build_commit` | the one commit `build` made | later commits on the branch must be sync merges (R9) |
| `era` | old step's era, `objc-spidermonkey` → `objc-quickjs` | research R7 |
| `verification` | as feature 001, plus `after_sync`: index into `syncs` | must be at or after the latest sync (FR-011) |

The other fields are as in feature 001: `title`, `description`, `kind` and `size`. `chapter` and
`boundary_moved` are copied from the old step for the description and are informational only.

## DroppedStep

`{old_step, old_branch, reason, covered_by: 767|768}`. Recorded when a replayed step's tree equals
its parent's tree (FR-005).

## Addition

`{path_glob, from_pr, reason}`. These are paths #767/#768 add that the series keeps although
`develop` lacks them (research R5). The defaults are `tools/js-parity/**` and `tools/oxp-upgrade/**`.

## SyncRecord

`{date, command, parent_heads_before, parent_heads_after, conflicts: [{step, path, reason}]}`.
`series.py sync-record` writes one after Jon or an agent has run the sync.

## State

A parent goes from `planned` to `mirrored`, then `verified` (gate `pass`) or `flagged`. A parent becomes `retired` after `parents --retire` (FR-011a). A flagged
parent becomes `pass` only through a Notes decision (`waived`), or Jon adds a `fix-parent` that
passes.

A step goes `planned` → `built` → `verified`. A sync puts every step back to `stale` until
`verify` passes again. `planned` becomes `dropped` when its replayed tree is empty.

## Rules checked by `series.py --series seriesb check`

1. Branches exist and match the manifest. Lineage is one chain: `develop` → parents → steps.
2. Each `upstream` parent's tip equals its tracking branch and its recorded `head`.
3. Every step tip descends from its parent's tip. Every commit after `build_commit` is a merge
   whose other parent is an ancestor of the parent's tip.
4. No `seriesb` branch contains any commit of `develop` that is not in upstream `master` or in a
   parent (FR-003).
5. Every `series/*` branch, `develop` and `master` is at the commit recorded in
   `series/baseline.json`, which is written before any branch is created (FR-009).
6. The final tree equals `develop_target`'s tree, modulo `exclusions` and `additions` (FR-007).
7. With `--verified`: every parent's gate is `pass`, and every step's verification passes and is
   current after the latest sync.
