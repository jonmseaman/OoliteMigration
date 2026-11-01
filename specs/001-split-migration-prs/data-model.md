# Data model: the PR series

All state lives in files under `specs/001-split-migration-prs/series/` (committed in OoliteMigration)
and in branches plus Git Town lineage in `oolite-dev` (local only). The manifest is the source of
truth; the check (`contracts/series-cli.md`, `check`) proves the branches and lineage agree with it.

## Anchors

| Field | Value | Meaning |
|---|---|---|
| `upstream_base` | `49a5eb9fc` | upstream `master` commit the series is based on; `series/000-upstream-base` points here |
| `develop_target` | `3aa8d65e8` | `develop` commit the last step must equal (outside exclusions) |
| `history_repo` | OoliteMigration | where the iterative history lives |
| `history_prefix` | `upstream/oolite` | the history's game path; mapped to the repo root |
| `history_end` | `338463308^` | last history commit with the game as a subtree |
| `history_upstream` | ordered list of `{from_history_commit, upstream_commit}` | what upstream commit each part of the history sat on: `dc55e3e05` from `4f089047c`, `9ee8ff22f` from `4c2bfae9f` |
| `format` | `{clang_format_version: "22.x", style_file_from: <upstream_base>}` | the normaliser (research R3) |

## Step

One entry per PR, in series order.

| Field | Type | Rule |
|---|---|---|
| `n` | int, 1… | position; unique, contiguous |
| `branch` | `series/NNN-slug` | NNN = `n` zero-padded to 3 (FR-019) |
| `parent` | branch | `series/000-upstream-base` for n=1, else the previous step's branch; equals Git Town's recorded parent (FR-018) |
| `title` | string | imperative, no bead ids or ADR numbers (FR-017) |
| `kind` | `independent` \| `hand-written` \| `mechanical` \| `reconcile` | see below |
| `source` | object | where the step's target tree comes from (below) |
| `target_tree` | git tree id | the tree the step's single commit must have; recomputed by `build` |
| `chapter` | `{phase, work_items[], first, last}` or null | required for `source` = `history`: the R14 row; `last` is the boundary merge |
| `size` | `{src, tests, other, deleted_files}` lines | measured on normalised trees, reported in the description; no limit |
| `boundary_moved` | `{from, to, reason}` or null | set if the boundary had to move to a later merge to build |
| `mechanical_command` | string or null | required iff `kind` = `mechanical`; reproduces the diff from `parent` exactly (FR-007) |
| `description` | path | `series/pr/NNN-slug.md`, sections per `contracts/pr-description.md` |
| `era` | `objc-spidermonkey` \| `objc-quickjs` \| `cxx` | decides the verification matrix (research R5) |
| `verification` | object or null | last run: date, commit, per-check result (below) |
| `temporaries` | list of `{id, action: add\|remove}` | shims this step adds or removes (FR-010) |
| `resolutions` | list of paths | conflict resolutions this step needed (research R4) |

### `source` variants

- `history`: `{from: <history commit>, to: <history commit>}`, the chapter's first and last
  first-parent merges (R14). The target is the snapshot at `to`, normalised and merged onto
  upstream (research R4).
- `hoisted`: `{commits: [<history commit>…]}`. An independent fix moved forward; its effect is
  added to every target tree between here and its original place.
- `develop`: `{commits: [<develop commit>…]}`. Fork commits after the squash, grouped by purpose
  (R14 tail table). The target is `develop` after the group's last commit, normalised to upstream's
  style, except in the final mechanical reformat step.
- `reconcile`: `{tree: develop_target}`. The last step: the tree is `develop_target` minus exclusions.

### Kinds

- `independent`: applies to `upstream_base` alone and builds there (FR-008). Placed first.
- `hand-written`: the default for history chapters.
- `mechanical`: one tool-driven change only; has `mechanical_command`.
- `reconcile`: closes the gap to `develop_target`; at most one, last.

### Verification record

`{date, commit, checks: {build_clang, build_gcc, warnings_clang, warnings_gcc, unit, smoke,
component[], clang_format, tests_untouched, no_new_suppressions, tree_matches_target}}`. Each check is
`pass` \| `fail` \| `n/a` with a reason for `n/a` (for example `build_gcc: n/a, objc era`).
A step is **verified** when every check is `pass` or a justified `n/a` and `commit` is the branch's
current tip.

## Exclusion

`{path_glob, reason}`. Paths in `develop_target` that the series does not carry. The last step's tree
equals `develop_target` with these paths taken from `upstream_base` (or absent if upstream lacks them).

## Temporary-code ledger

`{id, description, paths[], added_in: n, removed_in: n}`. Every `add` must have a matching later
`remove` (FR-010); the check fails otherwise.

## State transitions (per step)

```text
planned ──build──▶ built ──verify──▶ verified
   ▲                 │                  │
   └──── replan ◀────┴──── fail ◀───────┘
```

`planned`: in the manifest with a source, no branch yet. `built`: branch exists with one commit whose
tree is `target_tree`, and Git Town lineage is set. `verified`: the verification record passes for the
current tip. Any change to an earlier step's tree makes every later step `built` again (its tree is
recomputed and its parent tip changed), so verification runs in order.

## Validation rules (enforced by `check`)

1. `n` contiguous from 1; branch names match `series/NNN-slug` with NNN = `n`.
2. Every branch exists in `oolite-dev`; each branch's single commit has `parent`'s tip as its only
   parent; and `git config git-town-branch.<branch>.parent` equals `parent`.
3. Each branch's tree equals its `target_tree`.
4. `chapter` set iff `source` = `history`, and chapters are contiguous: each `first` follows the
   previous `last`. `mechanical_command` set iff `kind` = `mechanical`.
5. Independent steps come before all non-independent steps.
6. The ledger balances.
7. The last step's tree equals `develop_target` outside the exclusions.
8. Every description file exists and has the required sections.
9. No step's commit message or description matches `ADR-[0-9]{4}` or `\boo-[0-9a-z]{3,}\b`.
10. With `--verified`: every step is verified.
