# Contract: `tools/series/series.py --series seriesb`

This document lists only what changes against feature 001's contract
(`specs/001-split-migration-prs/contracts/series-cli.md`). Exit codes are the same: `0` success,
`1` a check or verification failed, `2` usage or environment error.

## Global option

`--series {series,seriesb}` (default `series`) selects the profile:

| Profile | Branch prefix | Series dir | Root | Source types |
|---|---|---|---|---|
| `series` | `series/` | `specs/001-split-migration-prs/series/` | `series/000-upstream-base` | history, hoisted, tail |
| `seriesb` | `seriesb/` | `specs/002-seriesb-rebase-stack/series/` | last parent | replay |

Without the option, every command behaves byte-for-byte as before. Feature 001's tool tests pass
unchanged.

## Never

The tool never pushes, and never touches `develop`, `master`, `main` or any `series/*` branch under
the `seriesb` profile. It never runs `git town sync` itself: syncing is Jon's command, or an
agent's under research R2's flags. It never reads expansion content. `tools/js-parity/` holds an
OXP; the tool treats that path as opaque.

## New and changed commands (profile `seriesb`)

| Command | Does | Exit 0 when |
|---|---|---|
| `parents [--setup] [--refresh] [--retire]` | `--setup`: adds remote `hobleyd`, whose fetch refspecs map only the two PR branches onto `refs/remotes/hobleyd/<parent branch name>` (research R2), creates the parent branches at their tracking heads, sets Git Town lineage (`000a`→`develop`, `000b`→`000a`), and marks them observed. `--refresh`: fetches `hobleyd`, resets each parent to its tracking ref with `update-ref`, which also undoes a force-push (research R2), and records the heads. Refuses if a parent is checked out in any worktree. `--retire`: once both PRs are in upstream `master` (refused otherwise), re-parents step 001 onto a new perennial `seriesb/000m-upstream-master` at `master` and marks the parents `retired`; deletes nothing. Without flags: reports each parent's tip, tracking head and gate. | every parent tip equals its tracking head |
| `gate <parent>` | Runs the parent's verification (research R6) and sets `gate` to `pass`, or to `flagged` with the failing checks. | gate is `pass` |
| `cut --replay [--from-old a] [--to-old b]` | Writes one `planned` replay step per old step, in order, from the old manifest. Titles and descriptions start from the old ones. | manifest written |
| `cut --replay --target REF --title T --slug S --test-ledger PATH` | Adds the switch step last, or updates it: source `{type: "target", ref, commit, test_ledger}`. Its tree is REF's, with the exclusions' reverts applied and every exclusion and addition path as the parent has it. A later `cut` keeps it last (renumbered, its tree recomputed). It has no `differs_from_old`; `tree` takes no `--rule`/`--show`/`--record` for it; the `tests` check and `verify`'s `tests_untouched` require each existing test it changes to be in the ledger (FR-015). | manifest written |
| `tree <n>` | As before, with a replay source: base = old parent tree, ours = new parent tree, theirs = old step tree (research R3). `--show`/`--record` as before, into `series/resolutions/NNN/`. Also accepts `--rule theirs --paths GLOB…` to resolve every conflict under those paths to the old step's side, recorded as `theirs-rule` with a reason. | no unresolved conflicts |
| `drop <n> --covered-by PR --reason TEXT` | Moves step *n* to `dropped` when its tree equals its parent's. | the trees are equal |
| `build` | As before. Refuses while any parent's gate is not `pass`. Refuses to reset a step with commits after `build_commit` unless `--reset`. | steps built |
| `sync-record [--conflict STEP:PATH:REASON …]` | After a sync, records parent heads before and after and the hand-resolved conflicts, and marks every step `stale`. | record written |
| `check [--verified] [--only GROUPS] [--steps a-b]` | Rules 1–7 in `data-model.md`. Groups: `manifest`, `branches`, `lineage`, `baseline` (rule 5, against `series/baseline.json`), `gates`, `differs` (SC-006), `tests` (no test modified or deleted unless the old step did the same), `final-tree`, `descriptions`, `handover`, `messages` (FR-013: no bead ids or ADR numbers in step commit messages), and with `--verified` `verified`. | all selected rules hold |
| `describe` / `describe --handover` | As before. Descriptions name the old step and list `differs_from_old`. Their generated parts are short (Jon, 2026-11-12/13): one line under the title gives the step's place (`Step N/M.`) and names the old step (a target step: its ref, unless that is its own branch); step 1's line alone says it needs #767 and #768 merged first while those PRs are open. The base branch and the size are left to GitHub. A target step has a Test changes section only when it changes existing tests, listing at most 20 files with the command that lists them all. Verified is one line (Windows x64, commit, date; macOS and Linux not verified) over a table of the checks that ran, with the n/a checks named on one line, or `Not verified at <tip>.` when the record is for another commit. No heading carries `**(gen)**`; an HTML comment under the title says which sections a rerun keeps. The handover lists:<br>• the parents (PR, head, gate);<br>• every step;<br>• push commands for the `seriesb/NNN` steps, plus `000b` (or the last parent) pushed to the fork only, as the base of step 001's dry-run PR;<br>• fork dry-run PRs, each against its step's parent;<br>• the sync command (research R2).<br>The parents are never offered as upstream PRs. | every required section present |
| `renumber` | As before, for the `seriesb/` prefix. | `check` passes afterwards |

## Files

```text
specs/002-seriesb-rebase-stack/series/
├── baseline.json        # branch SHAs before the work (rule 5)
├── manifest.json        # data-model.md
├── resolutions/NNN/     # as feature 001, keyed by the replay's three input blobs
├── pr/NNN-slug.md       # one description per step
└── HANDOVER.md          # generated
```
