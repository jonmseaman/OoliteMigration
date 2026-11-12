# Workflow

How a change is made and verified. The hard rules are in [CLAUDE.md](../CLAUDE.md); this is the
detail behind them.

## Tools decide correctness, not models

Whether behaviour changed is decided by the unit, component and GUI suites, the JS API contract in
`oxp-contract/`, the expansion corpus, sanitizers, and `-Wall -Wextra`. A model (or a reviewer) may
propose and explain; it never declares a change correct.

## Running the tests

Everything lives in `oolite-dev/tests`, driven by `tests/run.sh` (see [CLAUDE.md](../CLAUDE.md)
for the commands):

| Suite | What it decides | Cost |
|---|---|---|
| `unit` | class behaviour (`oofnd`, `core`, headers); meson | seconds |
| `component` | pytest-bdd scenarios against a real game over the debug console | minutes |
| `gui` | PyAutoGUI against the real window | minutes; one at a time |
| `smoke` | the game launches and renders | seconds |

Before a pull request run `unit` and whatever `component` scenarios touch your change. Before a
phase pull request run `all`, on Clang and on GCC. The expansion corpus (`bash tools/corpus.sh
tier1`) is run by hand when a change could affect what expansions see.

## A unit of work (a bead)

Work is tracked as beads (`bd ready`, `bd show <id>`). A bead is ready to hand to an agent when:

1. it is one tick's work: one coherent change a worker can finish and prove in a single iteration.
   There is no line or file cap. Size a bead by pattern (a tool-driven sweep over the whole tree is
   one bead; name the tool, e.g. a clang-tidy check with `--fix`) or by area (a directory or
   subsystem), not by file count;
2. it has an acceptance command that exits nonzero before the change and zero after;
3. it adds no new interfaces (or quotes them verbatim);
4. it fits in 2–3 sentences;
5. it names an existing file to copy the style from.

If a bead fails 1, 3 or 4, split it. If only 2 fails, write the test first as its own bead. If only
3 and 5 fail, it is design work: label it `design` and do it in an interactive session, not in the
loop.

Acceptance has a time budget: 300 s for the whole block by default. A bead whose proof is a full
build and test run sets `accept_budget` in its metadata
(`bd update <id> --set-metadata accept_budget=900`), up to 1,800 s.

Template: [templates/story.md](templates/story.md). The bead's notes are the only state that
survives between agent iterations.

## Done, for one bead

1. Its acceptance commands pass, and `tests/run.sh unit` passes.
2. Clean at `-Wall -Wextra` on Clang and GCC; no new warnings.
3. ASan clean where the change touches memory ownership.
4. No `libgnustep-base` or `JS_*` symbols (`git grep -nE 'JS_[A-Za-z_]+|gnustep'` over the files you changed).
5. The bead is one commit (`<id>: <title>`) on its epic's branch, labelled `committed` by
   `accept.sh`. It closes when Jon merges that branch into `develop`
   (`.claude/skills/beads-worker/scripts/land.sh` sees the merge); the implementing agent never
   closes it.

## Repo mechanics

- All beads of an epic commit on one branch in `oolite-dev` (`epic/<slug>`, created by
  `branch.sh` from `develop`). The worker may push that branch, never `develop`; Jon merges the
  branch into `develop` locally and pushes it.
- Scripts called as bare programs are committed `100755` with a shebang; check with
  `git ls-files -s`, never `test -x`.
- Vendored code (`src/Core/MiniZip/`, `src/SDL/stb_image_write.h`) is not edited to satisfy the
  warning gate; the gate skips exactly those two paths.
- Upstream changes to a frozen module are ported by hand and recorded in
  [UPSTREAM_DELTA.md](UPSTREAM_DELTA.md); `bash tools/upstream-delta.sh --check` enforces it.
- Expansion (OXP/OXZ) content is untrusted input: tools read it, agents with write access don't.
- Scratch goes in `.agent-tmp/`, never outside the repo.

## Git Town in `oolite-dev`

`oolite-dev` uses Git Town 24; OoliteMigration does not. Its settings
(`git config --get-regexp '^git-town'`):

| Setting | Value |
|---|---|
| main branch | `develop` |
| perennial branch | `upstream-master` (OoliteProject `master`, mirrored on `origin`) |
| dev remote | `origin` |
| feature sync strategy | `rebase` |
| forge | GitHub, through `gh` |

The branches form a tree rooted at `upstream-master`; `git town branch` prints it.

- `upstream-master`: perennial. Nobody commits to it.
- `seriesb/000a-…`, `seriesb/000b-…`: observed branches, each mirroring an upstream PR (#767,
  #768) from the `hobleyd` remote.
- `seriesb/001-…` up to the top step: the fork's changes as upstream-sized steps, each the parent
  of the next ([spec 002](../specs/002-seriesb-rebase-stack/spec.md)).
- Feature branches, each on the step it builds on.

`develop` is not in the tree: Jon merges finished feature branches into it.

For agents:

- Create a branch with `git town append <name>` from its parent. Rename, delete or re-parent with
  `git town rename`, `git town delete`, `git town set-parent`. Plain `git checkout -b` or
  `git branch -m` leaves Git Town without a parent for the branch.
- Sync with `git town sync --stack --detached`; `--detached` leaves `upstream-master` alone.
  Feature branches sync by rebase, so Git Town pushes a rebased branch with `--force-with-lease`.
  That is allowed on your own branches (hard rule 3) and is the only force-push allowed.
- On a conflict, resolve it, `git add` the files and run `git town continue`; `git town undo`
  backs out the whole sync.
- Never run `git town ship` (it merges into the parent, which can be `develop`) or
  `git town propose` (it opens a pull request on GitHub).
- Git Town fetches only `origin`. To bring `000a`/`000b` up to their PR heads, run
  `python -I tools/series/series.py --series seriesb parents --refresh` (from OoliteMigration)
  before the sync.
