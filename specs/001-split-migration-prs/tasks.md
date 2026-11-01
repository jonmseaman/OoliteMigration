---

description: "Tasks for splitting the C++ migration into a reviewable PR series (option B)"
---

# Tasks: Split the C++ migration into a reviewable PR series

**Input**: Design documents from `specs/001-split-migration-prs/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md) (R1–R14),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Included. The plan's gate G1 requires unit tests for `tools/series`, and CLAUDE.md
requires every task to have a command that exits nonzero before it and zero after. Each task ends
with its **Accept:** command.

**Organization**: by the spec's user stories. US1–US3 are P1 and depend on each other in the order
US1 → US2 → US3 (the stack must exist before it is verified, and the tail sits on the history
steps). US4 and US5 are P2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1…US5 from spec.md
- Paths: tool code in `tools/series/` (OoliteMigration root); outputs in
  `specs/001-split-migration-prs/series/`; branches only in `oolite-dev`.

## Rules for every task

- Run from the OoliteMigration root in Git Bash. Run game builds and tests through MSYS2:
  `MSYSTEM=UCRT64 C:/Users/jon/scoop/apps/msys2/current/usr/bin/bash -lc 'cd <dir> && …'`, with
  an explicit `cd` (a login shell starts in `$HOME`).
- Never push, never run `git town sync`/`propose`, never check out or move `develop`, `master` or
  `main` in `oolite-dev`. Never edit a file under `oolite-dev/tests` by hand. Scratch goes under
  `.agent-tmp/series*`.
- Worktrees: create with `git worktree add`, remove with `git worktree remove`; never
  `git worktree prune` from Git for Windows git.
- Python: standard library only. Run scripts with `python -I` and unit tests with `python -m
  unittest`: isolated mode drops the working directory, so the test package can't be imported.
  Write files with `newline="\n"`.
- Commit each finished task in OoliteMigration (`<task id>: <title>`, with the attribution trailer).
  Branch and git-config changes in `oolite-dev` need no commit.
- If an Accept command can't be made to pass, stop that task, record why and the default taken in
  plan.md's Notes, and go on to tasks that don't depend on it.

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the tools, objects and refs every later task uses.

- [X] T001 Create the package skeleton `tools/series/__init__.py`, `tools/series/series.py` (argparse
  CLI with the nine subcommands from contracts/series-cli.md, each exiting 2 with "not implemented"),
  and `tools/series/tests/__init__.py`. Accept: `python -I tools/series/series.py --help` exits 0
  and lists `inventory cut hoist tree build verify describe check renumber`.
- [X] T002 [P] Install clang-format 22 into a venv: `python -m venv .agent-tmp/series-venv &&
  .agent-tmp/series-venv/Scripts/pip install "clang-format>=22,<23"`. Record the exact version in
  plan.md Notes. Accept: `.agent-tmp/series-venv/Scripts/clang-format --version | grep -q 'version 22\.'`.
- [X] T003 [P] Make the history reachable from `oolite-dev` without a branch: `git -C oolite-dev
  fetch .. 338463308:refs/series/history`. If the SHA fetch is refused, fetch
  `feature/phase4-polish` and `update-ref refs/series/history 338463308`. Accept:
  `git -C oolite-dev rev-parse --verify refs/series/history^:upstream/oolite`.
- [X] T004 [P] Create the stack root and Git Town config in `oolite-dev`: `git branch
  series/000-upstream-base 49a5eb9fc` and `git config git-town.perennial-branches
  series/000-upstream-base` (append if the key exists). Also `git config rerere.enabled true` and
  `git config rerere.autoUpdate false`. Accept: `[ "$(git -C oolite-dev rev-parse
  series/000-upstream-base)" = "$(git -C oolite-dev rev-parse 49a5eb9fc)" ] && git -C oolite-dev
  config --get git-town.perennial-branches | grep -q series/000-upstream-base`.
- [X] T005 Gate G0: build an isolated MSYS2 for the Objective-C steps. Unpack the MSYS2 base archive
  (`msys2-base-x86_64-latest.tar.zst` from repo.msys2.org) into `.agent-tmp/msys2-objc/`, then run
  upstream's `ShellScripts/Windows/install_deps.sh clang` from a `49a5eb9fc` worktree at
  `.agent-tmp/series-g0/`, inside that MSYS2's UCRT64 shell. Jon's scoop MSYS2 must not be touched.
  Then build `49a5eb9fc` with `./mk.sh build test` there. Write the shell path to plan.md Notes. If
  it can't be done, record the fallback (CI on Jon's push, research R5) in plan.md Notes and mark
  this task done-with-fallback. Accept: `MSYSTEM=UCRT64 .agent-tmp/msys2-objc/usr/bin/bash -lc
  'cd /c/Users/jon/OoliteMigration/.agent-tmp/series-g0 && ./mk.sh build test'` exits 0, or plan.md
  Notes contain a line starting `G0 fallback:`.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the library modules every story uses. Each has unit tests on fixture repos built in a
temporary directory by `tools/series/tests/fixtures.py`: a fake superproject with `upstream/oolite/`
history, merges into `main`, and a fake upstream with a reformat commit.

**⚠️ CRITICAL**: no story work can begin until this phase is complete.

- [X] T006 Write `tools/series/tests/fixtures.py`: `make_history_repo(tmp)` builds a superproject with a
  subtree-like `upstream/oolite/` (an add commit, 6 first-parent bead merges whose subjects follow
  `bead oo-xxx: merge into main`, one subtree-pull commit), plus a `game` repo whose `master` holds the
  upstream base and a reformat commit. Accept: `python -m unittest tools.series.tests.test_fixtures`
  (write that test too: the fixture builds and has 6 first-parent merges) exits 0.
- [X] T007 [P] Write `tools/series/tests/test_manifest.py` for data-model.md's validation rules 1, 4–6 and
  9, then implement `tools/series/manifest.py` (load, save with sorted keys and `newline="\n"`,
  `validate()` returning a list of rule violations). Encode verbatim: branch `series/NNN-slug` with
  NNN = `n` zero-padded to 3; `chapter` set iff `source` = `history`, chapters contiguous;
  `mechanical_command` set iff `kind` = `mechanical`; independent steps before all others; ledger
  `add` has a later `remove`; no `ADR-[0-9]{4}` or `\boo-[0-9a-z]{3,}\b` in titles or descriptions.
  Accept: `python -m unittest tools.series.tests.test_manifest` exits 0 (and failed before
  `manifest.py` existed).
- [X] T008 [P] Write `tools/series/tests/test_history.py`, then implement `tools/series/history.py`:
  `first_parent(repo, prefix, start, end)` lists merges under the prefix; `snapshot(repo, commit,
  prefix)` returns the tree id of `<commit>:<prefix>`; `upstream_under(commit)` returns
  `dc55e3e05` before `4c2bfae9f` and `9ee8ff22f` from it on (research table "Upstream under the
  history"). Accept: `python -m unittest tools.series.tests.test_history` exits 0.
- [X] T009 [P] Write `tools/series/tests/test_normalise.py`, then implement `tools/series/normalise.py`
  (research R3): `normalise_tree(repo, tree, style_from)` formats `src/**` and `tests/**` files with
  extensions `.h .hpp .m .mm .c .cpp`, using `.agent-tmp/series-venv/Scripts/clang-format` and the
  `.clang-format` from `style_from`. It writes blobs with `git hash-object -w`, keeps a per-blob
  cache in `.agent-tmp/series-cache/normalise.json`, and returns a new tree id. Test: idempotent
  (normalising twice gives the same tree) and leaves non-source files byte-identical. Accept:
  `python -m unittest tools.series.tests.test_normalise` exits 0.
- [X] T010 Write `tools/series/tests/test_trees.py`, then implement `tools/series/trees.py` (research
  R4): `target_tree(base_tree, upstream_tree, snapshot_tree)` runs `git merge-tree --write-tree
  --merge-base=<N(base)> <upstream> <N(snapshot)>` with temporary commits for the three trees. It
  applies stored resolutions from `series/resolutions/NNN/*.patch` and returns `(tree, conflicts[])`.
  It uses the upstream file wherever the snapshot's file equals the base's. Test with the fixture:
  an upstream-only change survives, a history-only change survives, and a both-sides change is
  reported as a conflict, then resolved by a patch. Depends on T008, T009. Accept: `python -I -m
  unittest tools.series.tests.test_trees` exits 0.
- [X] T011 Write `tools/series/tests/test_stack.py`, then implement `tools/series/stack.py` (research
  R8): `make_step(repo, branch, parent, tree, message)` creates or force-resets the branch to one
  commit (`git commit-tree <tree> -p <parent tip>`). On first creation it records lineage with
  `git town append <branch> --prototype --no-sync --no-push` run from the parent, then moves the
  branch to the commit. Later it uses `git town set-parent`. `lineage(repo, branch)` reads `git
  config git-town-branch.<branch>.parent`. The test checks the commit's only parent is the parent's
  tip and that lineage matches. Accept: `python -m unittest tools.series.tests.test_stack` exits 0.

**Checkpoint**: `python -m unittest discover -s tools/series/tests -t .` exits 0. That is gate G1.

---

## Phase 3: User Story 1: a maintainer reviews the migration one chapter at a time (P1) 🎯 MVP

**Goal**: the 25-step chapter stack (R14) exists as branches on `series/000-upstream-base`, each one
commit whose tree is its chapter's snapshot carried onto upstream, with a PR description.

**Independent Test**: `python -I tools/series/series.py check` exits 0. Every branch chains on its
parent with matching Git Town lineage, every tree equals its target, and every description has
the contract's sections.

- [X] T012 [US1] Implement `inventory` in `tools/series/series.py`: write
  `specs/001-split-migration-prs/series/inventory.tsv`. Columns: `idx`, `commit`, `date`,
  `bead`, `phase` (from the bead id prefix: `oo-1bf` P0, `oo-1gc` P1, `oo-3rb` P2, `oo-9ht` P3,
  `oo-6e1` P4, else `?`), `subject`, `upstream_under`. Use the 1,400 first-parent merges of
  `refs/series/history` under `upstream/oolite` from `4f089047c`. Accept: `python -I
  tools/series/series.py inventory && [ $(tail -n +2 specs/001-split-migration-prs/series/inventory.tsv
  | wc -l) -eq 1400 ]`.
- [X] T013 [US1] Implement `cut --chapters`: write the 19 history chapters from research.md R14
  (first/last commits, phase, work items, slug) and the 6 tail steps (020–025, `source` = `develop`
  with the listed commits; 025 `kind` = `mechanical`, `mechanical_command` = `clang-format -i` with
  version 22 and `develop`'s `.clang-format`) into `specs/001-split-migration-prs/series/manifest.json`.
  Also set the anchors from data-model.md (`upstream_base` `49a5eb9fc`, `develop_target`
  `3aa8d65e8`, `history_end` `338463308^`) and the exclusions (`.zed/`, `.vscode/`, the CI
  filter lines from `3aa8d65e8`). It must check that the chapters tile inventory rows 0–1399 with
  no gap or overlap. Accept: `python -I tools/series/series.py cut --chapters && python -I -c
  "import json;m=json.load(open('specs/001-split-migration-prs/series/manifest.json'));assert
  len(m['steps'])==25"`.
- [X] T014 [US1] Implement `tree <n>` for `source` = `history`, using `trees.target_tree` with
  `N(upstream_under(last))` as the merge base, `49a5eb9fc` as ours, and `N(snapshot(last))` as
  theirs. Print the tree id, or list conflicting paths and exit 1. Accept: `python -I
  tools/series/series.py tree 1` prints a tree id, or lists only paths that both upstream and the
  chapter changed. (Amended: chapter 1 also edits `OOCocoa.h`, which upstream renamed to
  `OOFoundation.h` in #737, so step 1 has one real conflict. It is resolved in T015.)
- [X] T015 [US1] Resolve the conflicts for steps 2–19 in order. For each step run `tree <n>`. For
  each conflicting path, write the resolution that keeps upstream's change carried into that
  step's code. The answer is the file as it is at `develop` `3aa8d65e8`, adapted to the step. Save
  it as `specs/001-split-migration-prs/series/resolutions/NNN/<path>.patch`, and let rerere reuse
  identical hunks. Don't change behaviour beyond the merge, and never touch a test file (rule 1;
  a conflict in `tests/` stops the task: record it in plan.md Notes). Accept: `for n in $(seq 1
  19); do python -I tools/series/series.py tree $n || exit 1; done`. (Amended: resolutions are
  stored as whole files under `resolutions/NNN/files/` keyed by stage blobs in `index.json`, not as
  patches; the specs that produced them are in `series/resolution-specs/`.)
- [X] T016 [US1] Implement `build [--from n]`: for each step in order, compute the tree (`tree`) and call
  `stack.make_step` with message `<title>` plus the step's chapter line (no bead ids), then store
  `target_tree` in the manifest. Run it for steps 1–19. Accept: `python -I tools/series/series.py
  build --from 1 --to 19 && git -C oolite-dev town branch | grep -c 'series/0' | grep -qx 20`
  (000 plus 19).
- [X] T017 [P] [US1] Implement `describe <n>`: create or refresh
  `specs/001-split-migration-prs/series/pr/NNN-slug.md` per contracts/pr-description.md. Rewrite
  the **(gen)** sections (position, size by src/tests/other/deleted from normalised trees,
  verification table, temporary code) and keep the hand-written ones. Accept: `python -I
  tools/series/series.py describe 1 && grep -q '^## What this changes'
  specs/001-split-migration-prs/series/pr/001-*.md`.
- [ ] T018 [US1] Write the hand-written sections (What this changes, Why, Behaviour changes, How to
  review) for steps 1–19. Take them from the phase docs at `archive/phase-0-4-docs:docs/phases/`
  and the chapter's merge subjects in `inventory.tsv`. Explain the code, not the project: no bead
  ids, ADR numbers or OoliteMigration doc paths (FR-017). "Behaviour changes" lists each change
  with the test that pins it, or "None.". Where waves mix work items (chapters 12–15), say which.
  Accept: `python -I tools/series/series.py check --only descriptions --steps 1-19` exits 0.
- [ ] T019 [US1] Implement `check` (all data-model.md rules, with `--only <rule-group>` and `--steps a-b`
  filters used above): branches exist; single commit on the parent tip; Git Town lineage equals
  `parent`; tree equals `target_tree`; descriptions complete; no bookkeeping ids. Accept: `python
  -I tools/series/series.py check --steps 1-19` exits 0.

**Checkpoint**: the history chapters are a reviewable stack: US1 is delivered for 001–019.

---

## Phase 4: User Story 2: every step leaves a working game (P1)

**Goal**: every step has a passing verification record for its era (research R5) in the shared
verification worktree (R9).

**Independent Test**: `python -I tools/series/series.py check --verified` exits 0.

- [X] T020 [US2] Write `tools/series/tests/test_verify.py` (era from the tree: `objc-spidermonkey`
  if `src` has `.m`/`.mm` files and a SpiderMonkey dependency in `meson.build`; `objc-quickjs` if
  Objective-C without SpiderMonkey; `cxx` otherwise; GCC required iff the parent's record has
  `build_gcc: pass`). Then implement `tools/series/verify.py`: the shared worktree at
  `.agent-tmp/series-verify/`, build dirs per compiler, incremental `mk.sh build test` (Clang;
  `--native-file=gcc.ini` for GCC), warning count from the build log, then `tests/run.sh unit` and
  `tests/run.sh smoke` if present in the tree, and `tests/run.sh component -k <names>` for scenarios
  whose files the step touches. Objective-C eras use the T005 shell (or record `ci-pending` under
  the G0 fallback). Accept: `python -m unittest tools.series.tests.test_verify` exits 0.
- [X] T021 [US2] Add the construction-integrity checks to `verify.py` (research R11), recorded as
  `tests_untouched`, `no_new_suppressions`, `clang_format` and `no_new_spidermonkey_or_gnustep`:
  (a) no file under `tests/` differs between the step's tree and its source snapshot carried onto
  the base, except by the step's stored resolutions, which must not touch `tests/`; (b) no added
  line matching `-Wno-|#pragma .*diagnostic` that the source snapshot lacks; (c) upstream's
  clang-format check passes with version 22 on steps 1–24; (d) no added `jsapi.h`, `mozjs`,
  `js32ECMAv5` or `gnustep-base` reference that the parent lacks. Accept: `python -m unittest
  tools.series.tests.test_verify` exits 0, with a test per check.
- [ ] T022 [US2] Implement `verify <n> | --from n [--clean]`: write the verification record into the
  manifest (date, branch tip, each check `pass`/`fail`/`n/a` with reason), and refresh the
  description's Verified section. Accept: `python -I tools/series/series.py verify 1 --clean` exits 0.
- [ ] T023 [US2] Verify steps 1–19 in order: `verify --from 1`, with clean builds at each era's first
  step and at step 19. When a step fails, read the failure. If the cause is in a stored
  resolution, fix the resolution (T015) and rebuild from that step. If the history snapshot itself
  doesn't build on the base, move the boundary to the next merge that does: set `boundary_moved`
  and record it in plan.md Notes. Never edit tests or silence warnings. GUI and smoke runs go one
  at a time; don't use the desktop while they run. Accept: `python -I tools/series/series.py check
  --verified --steps 1-19` exits 0.

**Checkpoint**: 001–019 build, warning-free, with their suites passing. US1 and US2 hold.

---

## Phase 5: User Story 3: the last step is the fork (P1)

**Goal**: steps 020–025 carry `develop`'s post-squash work (R14 tail table), and step 025's tree
equals `3aa8d65e8` outside the exclusions.

**Independent Test**: `git -C oolite-dev diff --name-only series/025-* 3aa8d65e8` lists only paths
matching the manifest's exclusions, and `check --verified` passes for 020–025.

- [ ] T024 [US3] Extend `tree <n>` for `source` = `develop`. For steps 020–024 the target is
  `N_upstream(develop at the group's last commit)`, with commits outside the group backed out by
  3-way merge, plus the exclusions taken from the base. For step 025 it is `develop_target` with
  the exclusions taken from the base. Add a test to `tools/series/tests/test_trees.py` using the
  fixture's reformat commit. Accept: `python -m unittest tools.series.tests.test_trees && for n
  in 20 21 22 23 24 25; do python -I tools/series/series.py tree $n || exit 1; done`.
- [ ] T025 [US3] Build steps 20–25, write their descriptions (step 025: mechanical, optional, gives
  the reproducing command, and notes that 001–024 already pass upstream's own clang-format check),
  and verify them. If a step from 020–024 doesn't build in upstream style, fold its commits into
  025, `renumber` (T030; if not yet done, do it by hand and record it), and note it in plan.md
  Notes. Accept: `python -I tools/series/series.py build --from 20 && python -I
  tools/series/series.py verify --from 20 && python -I tools/series/series.py check --verified`.
- [ ] T026 [US3] Add data-model rule 7 to `check`: the last step's tree equals `develop_target` outside
  the exclusions, and every exclusion has a reason. Accept: `python -I tools/series/series.py check
  --only final-tree` exits 0.

**Checkpoint**: the whole stack exists, every step is verified, and the end equals the fork.

---

## Phase 6: User Story 4: independent fixes can be taken alone (P2)

**Goal**: fixes useful without the migration are separate PRs ahead of chapter 1 (FR-008, R7).

**Independent Test**: each `independent` step applies alone to `49a5eb9fc`
(`git merge-tree --write-tree 49a5eb9fc <step>` with the base as merge base gives no conflicts)
and builds there with Clang.

- [ ] T027 [US4] Implement `hoist <history-commit>… --slug S`: check that the commits' combined
  change applies to `49a5eb9fc` with `git apply --3way` and builds in the T005 shell. Then insert
  an `independent` step before step 1, and remove the same change from later steps' diffs by
  carrying it into every target tree up to its original chapter. Add a test with the fixture.
  Accept: `python -m unittest tools.series.tests.test_hoist` exits 0.
- [ ] T028 [US4] Pick the candidates: from `inventory.tsv`, list merges whose subjects or bead
  titles name determinism, `OO_RANDOM_SEED`, iteration order, or a bug fix in code that upstream
  also has. Read each diff, keeping only changes outside test-harness and migration code, and
  write the list with a one-line reason each to plan.md Notes. Defaults: `oo-scnp`
  (`OO_RANDOM_SEED`) and `oo-r3r` (enumeration-order shuffle, debug build) are in; anything
  needing `oofnd` or the façade is out. Accept: `grep -q '^- Hoist candidates:'
  specs/001-split-migration-prs/plan.md`.
- [ ] T029 [US4] Hoist each accepted candidate, `renumber`, rebuild and re-verify the stack from the
  first changed step, and write the independent PRs' descriptions. Accept: `python -I
  tools/series/series.py check --verified` exits 0, and the manifest's first steps have `kind` =
  `independent`.

---

## Phase 7: User Story 5: Jon opens the PRs from a prepared series (P2)

**Goal**: the series is complete enough that opening it is clerical (SC-007).

**Independent Test**: `python -I tools/series/series.py check --verified` exits 0, and
`specs/001-split-migration-prs/series/HANDOVER.md` lists, per step in order, the exact push and
`gh pr create` commands with no placeholders.

- [ ] T030 [P] [US5] Implement `renumber`: after a step is inserted or removed, rename the branches
  (`git branch -m`), description files and resolution directories so that NNN = `n`. Rewrite the
  manifest and reset Git Town lineage with `git town set-parent` for every moved branch. Add a test
  with the fixture. Accept: `python -m unittest tools.series.tests.test_renumber` exits 0.
- [ ] T031 [US5] Generate `specs/001-split-migration-prs/series/HANDOVER.md` from the manifest
  (`series.py describe --handover`). It contains the anchors, the exclusions, the temporary-code
  ledger, and per step: branch, base, title, size and verification. It then gives Jon's commands,
  following quickstart §5: the push with Git for Windows git
  (`/mingw64/bin/git -C oolite-dev push origin <branches>` and `GIT_TERMINAL_PROMPT=0`), and `gh
  pr create` with `--body-file` per step, against the fork's previous step for a dry run or
  upstream `master` one at a time. Accept: `python -I tools/series/series.py describe --handover &&
  ! grep -nE '<[a-z-]+>|…' specs/001-split-migration-prs/series/HANDOVER.md`.

---

## Phase 8: Polish and cross-cutting

- [ ] T032 [P] Run quickstart.md end to end against the built stack and fix any drift between it,
  contracts/series-cli.md and the tool. Accept: every command block in quickstart.md §1–4 exits 0.
- [ ] T033 [P] Update plan.md's Notes "To fill at G2" items with the results (boundary moves,
  hoisted fixes, tail folds), and the status log in `docs/phases/4p-upstream-polish.md` with one
  line. Accept: `! grep -q 'To fill at G2' specs/001-split-migration-prs/plan.md`.
- [ ] T034 Re-anchor dry run (research R12, gate G5): in a copy of the manifest
  (`.agent-tmp/series-reanchor/manifest.json`), set `upstream_base` to `upstream/master`
  (`7437f22a5` today) and run `tree` for every step. List the new conflicts (expected: #780 in the
  scripting steps) in plan.md Notes, without changing the real stack. Accept: `grep -q '^-
  Re-anchor dry run' specs/001-split-migration-prs/plan.md`.
- [ ] T035 Final gate: the full tool test suite, then `check --verified`, then `git -C oolite-dev
  status --porcelain` empty and `git -C oolite-dev rev-parse develop` still `3aa8d65e8`.
  Accept: `python -m unittest discover -s tools/series/tests -t . && python -I
  tools/series/series.py check --verified && [ -z "$(git -C oolite-dev status --porcelain)" ] && [
  "$(git -C oolite-dev rev-parse --short=9 develop)" = 3aa8d65e8 ]`.

---

## Dependencies and execution order

### Phases

- **Setup (T001–T005)**: no dependencies. T005 (G0) is long and can run beside Phase 2. Only the
  Objective-C verification in T023, and the hoist builds in T027/T029, wait on it.
- **Foundational (T006–T011)**: T006 first. T007, T008 and T009 are parallel. T010 needs T008 and
  T009. T011 needs T006. This phase blocks all stories.
- **US1 (T012–T019)**: T012 → T013 → T014 → T015 → T016 → T018 → T019. T017 is parallel with T014–T016.
- **US2 (T020–T023)**: needs US1's branches. T020 → T021 → T022 → T023 (T023 also needs T005, or
  records the CI fallback).
- **US3 (T024–T026)**: needs T016 (step 19 is 020's parent) and T022. T024 → T025. T026 is
  parallel with T025.
- **US4 (T027–T029)**: needs US2 (hoisting re-verifies) and T030 (renumber).
- **US5 (T030–T031)**: T030 can start after Phase 2. T031 needs US3 complete.
- **Polish (T032–T035)**: after the stories; T035 is last.

### Story order

US1 → US2 → US3 are sequential by construction (build, then verify, then append the tail). US4 and
US5 come after; T030 can be pulled forward at any time.

## Parallel examples

```text
# Phase 1, together:
T002 clang-format venv      T003 history ref      T004 stack root + Git Town config
# (T005, the isolated MSYS2, runs in the background through Phase 2)

# Phase 2, after T006:
T007 manifest.py + tests    T008 history.py + tests    T009 normalise.py + tests

# US1, while conflicts are resolved:
T017 describe (generated sections), beside T014–T016
```

## Implementation strategy

### MVP (US1)

Phases 1–2, then US1. Stop and check with `check --steps 1-19`. At that point, chapters 001–019
exist as a reviewable stack, which is already enough to show the shape to a maintainer from the
branches, before verification.

### Incremental delivery

1. Setup + Foundational → G1 green.
2. US1 → the stack of history chapters (G3 for 001–019).
3. US2 → every chapter verified (G4 for 001–019).
4. US3 → the tail; the end equals `develop` (G3/G4 for all).
5. US4 → independent PRs in front; re-verified.
6. US5 → HANDOVER.md; Jon pushes and opens.
7. Polish → quickstart, notes, re-anchor dry run, final gate.

## Notes

- Defaults already taken and recorded in research and plan: option B; base `49a5eb9fc`; tail
  reformat last; exclusions `.zed/`, `.vscode/`, the fork's CI filter; isolated MSYS2 for G0 with
  CI as the fallback; rule 6 read as "no step adds GNUstep/SpiderMonkey".
- Machine time: T023 and T025 are the long ones (incremental builds, plus smoke and unit runs per
  step). T005 needs a download of the MSYS2 base and upstream's package set.
- Each task is one OoliteMigration commit. The `oolite-dev` side is branches and config only, and
  `develop` never moves.
