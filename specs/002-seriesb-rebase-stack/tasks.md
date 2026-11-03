---

description: "Tasks for rebuilding the PR series on upstream #767/#768 as seriesb/*"
---

# Tasks: Rebuild the PR series on upstream's QuickJS PRs (`seriesb/*`)

**Input**: Design documents from `specs/002-seriesb-rebase-stack/`

**Prerequisites**:

- [plan.md](plan.md)
- [spec.md](spec.md)
- [research.md](research.md) (R1–R10)
- [data-model.md](data-model.md)
- [contracts/series-cli-seriesb.md](contracts/series-cli-seriesb.md)
- [quickstart.md](quickstart.md)

**Tests**: Included. CLAUDE.md requires every task to have a command that exits nonzero before it
and zero after, and the plan's G0 requires that feature 001's tool tests still pass. Each task ends
with its **Accept:** command.

**Organization**: by the spec's user stories.

- US1 → US2 → US3 are P1 and sequential by construction: parents first, then replayed steps, then
  verification and the final tree.
- US4 (sync) and US5 (handover) are P2. US4 needs a verified stack. US5's generator can start after
  Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1…US5 from spec.md
- **Paths**:
  - tool code in `tools/series/` (OoliteMigration root);
  - outputs in `specs/002-seriesb-rebase-stack/series/`;
  - branches and Git Town config only in `oolite-dev`.

## Rules for every task

- Run from the OoliteMigration root in Git Bash. `S="python -I tools/series/series.py --series
  seriesb"`.
- Run game builds and tests through the era's MSYS2, as feature 001's `verify.py` does:
  - Objective-C: `MSYSTEM=UCRT64 .agent-tmp/msys2-objc/usr/bin/bash -lc 'cd <dir> && …'`;
  - C++: `C:/Users/jon/scoop/apps/msys2/current/usr/bin/bash`.

  Always use an explicit `cd`, because a login shell starts in `$HOME`.
- Never push. Never check out or move `develop`, `master`, `main` or any `series/*` branch. Never
  edit a file under `oolite-dev/tests` by hand. Never open anything under
  `tools/js-parity/oojs_probe.oxp` (hard rule 4). Scratch goes under `.agent-tmp/seriesb*`.
- Git Town: agents run `sync` only as `git town sync --stack --detached --no-push` (research R2),
  and only in T030. Every other Git Town command gets `--no-sync --no-push` where it accepts them.
- Worktrees: create with `git worktree add`, remove with `git worktree remove`. Never run
  `git worktree prune` from Git for Windows' git.
- Python: standard library only. Run scripts with `python -I` and tests with
  `python -m unittest discover -s tools/series/tests`. Write files with `newline="\n"`.
- Feature 001's tests (`tools/series/tests/test_*.py` as of `ae8845673`) are not modified (hard rule
  1). New behaviour gets new test files.
- Commit each finished task in OoliteMigration (`<task id>: <title>`, with the attribution trailer).
  Branch and git-config changes in `oolite-dev` need no commit.
- If an Accept command can't be made to pass, stop that task. Record why, and the default taken, in
  plan.md's Notes, then go on to tasks that don't depend on it.

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: a recorded baseline that every later "nothing moved" check compares against, and the
Git Town behaviour the plan relies on.

- [X] T001 Record the baseline. Write `specs/002-seriesb-rebase-stack/series/baseline.json` with:
  - `{branch: sha}` for every `series/*` branch, plus `develop` and `master`, from
    `git -C oolite-dev for-each-ref refs/heads`;
  - the PR heads of #767 and #768 (`3758f8a09…`, `db4920103…` as full SHAs);
  - upstream `master` (`7437f22a5…`).

  Accept: `python -I -c "import json;b=json.load(open('specs/002-seriesb-rebase-stack/series/baseline.json'));assert len([k for k in b['branches'] if k.startswith('series/')])==27 and 'develop' in b['branches']"`.
- [X] T002 [P] Run the Git Town probe of research R2 in scratch: `.agent-tmp/seriesb-gt-probe/`, local
  bare repos only, no network. The script is `.agent-tmp/seriesb-gt-probe.sh`. It builds:
  - a `develop` main with a commit absent from the PR branches;
  - a bare "hobleyd" remote with `quickjs-poc` and a `quickjs-default` stacked on it;
  - observed `seriesb/000a` (parent `develop`) and observed `seriesb/000b` (parent `000a`), each
    tracking its remote branch;
  - two prototype steps.

  It then adds a commit to each remote PR branch and runs `git town sync --stack --detached
  --no-push` from the top step. Assert that:
  1. each parent equals its remote branch;
  2. each step contains the new commits through a merge;
  3. no step and no parent contains the `develop`-only commit;
  4. `develop` and the bare `origin` are unchanged.

  Repeat with a force-pushed (rewritten) `quickjs-default`, and record what happens in plan.md's
  Notes. There are three outcomes, and they must be kept apart:
  - **The probe passes**: G0 holds.
  - **The probe ran and (1)–(4) failed**: switch to research R2's fallback and record
    `G0 fallback:` in Notes, with the failing assertion.
  - **The probe could not run** (for example, denied by the permission classifier, as in planning):
    record `G0 unverified:` in Notes with the reason, and keep observed parents. Not being allowed
    to run is not evidence against them. The behaviour is then confirmed on the real stack:
    - T009: the parents equal their tracking heads, and `develop` has not moved;
    - T030: a sync, if upstream has moved, or otherwise T026's fixture test.

  Accept: `bash .agent-tmp/seriesb-gt-probe.sh` exits 0, or plan.md Notes contain a line starting
  `G0 fallback:` or `G0 unverified:`.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the `--series` profile in `tools/series`, with the old profile unchanged (research
R8).

**⚠️ CRITICAL**: no story work can begin until this phase is complete.

- [X] T003 Write the tests first, in `tools/series/tests/test_profile.py`:
  - `profile.get("series")` returns prefix `series/`, dir `specs/001-split-migration-prs/series`
    and root `series/000-upstream-base`;
  - `profile.get("seriesb")` returns prefix `seriesb/`, dir `specs/002-seriesb-rebase-stack/series`,
    and a root equal to the manifest's last parent;
  - `stack.make_step` under `seriesb` refuses `develop`, `master`, `main`, `series/001-x` and
    anything not starting `seriesb/`;
  - `manifest.BRANCH_RE` for `seriesb` accepts `seriesb/001-a-b` and rejects `seriesb/1-a` and
    `seriesb/000a-x` as a step.

  Accept: the file exists, and `python -m unittest tools.series.tests.test_profile` fails before
  T004 and passes after.
- [X] T004 Implement `tools/series/profile.py` and thread the profile through the code:
  - `tools/series/series.py`: a global `--series {series,seriesb}`, default `series`. `SERIES_DIR`,
    the description path in the handover, and the `ROOT_BRANCH` uses come from the profile.
  - `tools/series/stack.py`: `ROOT_BRANCH` and the `series/` prefix check come from the profile.
  - `tools/series/manifest.py`: `ROOT_BRANCH` and `BRANCH_RE` come from the profile.
  - `tools/series/renumber.py`: the `series/` literals come from the profile.
  - `tools/series/hoist.py`: the `series/` literals come from the profile.
  - `tools/series/verify.py`: `TEST_WARNINGS` comes from the profile.

  **Keep the module-level names the old tests use.** `tools/series/tests/test_build.py` sets
  `series.SERIES_DIR` during the test, and `tools/series/tests/test_stack.py` reads
  `stack.ROOT_BRANCH`.
  - `series.SERIES_DIR`, `stack.ROOT_BRANCH`, `manifest.ROOT_BRANCH`, `manifest.BRANCH_RE` and
    `verify.TEST_WARNINGS` stay module attributes, defaulting to the `series` profile's values.
  - `profile.activate(name)` (called once by `--series`) rebinds them.
  - Every function reads them from the module at call time: no copies are captured at import, and
    no default arguments are bound to them.

  If an old test fails, fix the tool, never the test (hard rule 1). Accept, all of these:
  - `python -m unittest discover -s tools/series/tests` (old and new) passes;
  - `python -I tools/series/series.py check --verified` exits 0, so the old series is unaffected;
  - `git diff ae8845673 -- tools/series/tests/test_*.py` shows no change to pre-existing files.
- [X] T005 [P] Write the tests for the seriesb manifest rules in
  `tools/series/tests/test_seriesb_manifest.py`, on a fixture repo built in a temporary directory.
  `tools/series/tests/fixtures_seriesb.py` builds `develop`, an "upstream" with two stacked PR
  branches, the old `series/*` stack of 3 steps, and a `seriesb` stack replaying it. Cover each of
  data-model.md's rules 1–7, one failing case per rule:
  - a broken chain;
  - a parent tip that is not its tracking head;
  - a non-merge commit after `build_commit`;
  - a `develop`-only commit reachable from a step;
  - a moved `series/*` branch;
  - a final tree differing outside `exclusions` ∪ `additions`;
  - a verification older than the latest sync.

  Accept: the file exists and fails before T006.
- [X] T006 Implement the seriesb manifest schema and `check` rules 1–7 in `tools/series/manifest.py`
  and `tools/series/series.py` (`cmd_check`). Use these fields from data-model.md:
  - `parents[]` (`kind` is `upstream` or `fix-parent`; a `fix-parent` is allowed "only with a
    Notes entry naming Jon's choice");
  - `steps[].source = {type: "replay", old_step, old_branch, old_commit}`, where "`old_step` is
    strictly increasing across steps";
  - `steps[].differs_from_old`, `build_commit` and `verification.after_sync`;
  - `dropped[]`, `additions[]` and `syncs[]`.

  Accept: `python -m unittest tools.series.tests.test_seriesb_manifest` passes, and T004's Accept
  still passes.

**Checkpoint**: the tool runs under both profiles. G0 holds when T002's Accept passes too.

---

## Phase 3: User Story 1: the stack hangs under upstream's QuickJS PRs (P1) 🎯 MVP

**Goal**:

- `develop` → `seriesb/000a-upstream-767-quickjs-option` → `seriesb/000b-upstream-768-quickjs-only`
  in Git Town, mirroring the PR heads exactly;
- both gates decided;
- the `series/*` branches unchanged.

**Independent Test**: `$S parents` exits 0, and `$S check --only lineage,branches,baseline` exits 0.

- [X] T007 [US1] Write `tools/series/tests/test_parents.py` on T005's fixture. It checks that
  `parents --setup`:
  - adds a remote (fetch refspecs limited to the two PR branches);
  - creates both branches at the remote heads;
  - sets `git-town-branch.<b>.parent` (`000a`→`develop`, `000b`→`000a`);
  - lists both in `git-town.observed-branches`;
  - records `head`.

  It also checks that a second run changes nothing, and that `parents` exits 1 when a tip differs
  from its tracking head. Accept: the file exists and fails before T008.
- [X] T008 [US1] Implement `parents [--setup] [--refresh]` in `tools/series/series.py` and
  `tools/series/stack.py`, per the contract. The remote is
  `hobleyd https://github.com/hobleyd/oolite.git`, with fetch refspecs
  `+refs/heads/quickjs-poc:refs/remotes/hobleyd/seriesb/000a-upstream-767-quickjs-option` and
  `+refs/heads/quickjs-default:refs/remotes/hobleyd/seriesb/000b-upstream-768-quickjs-only` only.
  Git Town needs `<remote>/<local name>` (research R2, found by T002). `--refresh` fetches
  `hobleyd` and resets each parent to its tracking ref with `update-ref`. Mark the branches with
  `git town observe`. Write the `parents[]` entries to
  `specs/002-seriesb-rebase-stack/series/manifest.json`, creating the manifest with `anchors`:
  - `develop_target` `3aa8d65e8`;
  - `upstream_master` `7437f22a5`;
  - `old_manifest`;
  - `format` copied from feature 001.

  Accept: `python -m unittest tools.series.tests.test_parents` passes.
- [X] T009 [US1] Run `$S parents --setup` against the real `oolite-dev`.
  - If the PR heads have moved since `baseline.json`, use the new heads and record both in plan.md's
    Notes.
  - Delete the planning refs `refs/upstream-pr/{767,768,772}`
    (`git -C oolite-dev update-ref -d …`).
  - Run `git town branch` in `oolite-dev`, and confirm the two parents under `develop`.

  Accept: `$S parents` exits 0, and `$S check --only baseline` exits 0, so no `series/*`, `develop`
  or `master` moved.
- [X] T010 [US1] Implement `gate <parent>` (research R6) in `tools/series/series.py` and
  `tools/series/verify.py`:
  - for `000a`, the `objc-spidermonkey` era, plus a second build with `-Djs_engine=quickjs`;
  - for `000b`, the `objc-quickjs` era;
  - in both cases, the Windows checks that the parent's own `.github/workflows/*.yaml` runs. Read
    them from the parent's tree at run time, and list them in the record.

  The record is written to `parents[].verification`, and `gate` becomes `pass` or `flagged` with the
  failing checks. Add `tools/series/tests/test_gate.py` (a fake verify runner) for pass, flagged and
  re-run. Accept: `python -m unittest tools.series.tests.test_gate` passes.
- [X] T011 [US1] Gate G1. Run `$S gate seriesb/000a-upstream-767-quickjs-option` and `$S gate
  seriesb/000b-upstream-768-quickjs-only`. If either is `flagged`:
  - write `G1 flagged:` lines in plan.md's Notes (what fails, the log path under
    `.agent-tmp/seriesb-verify/`, and whether it looks environmental or a defect in the PR);
  - put the same in `specs/002-seriesb-rebase-stack/series/HANDOVER.md` under "Waiting for Jon";
  - **stop**. The default is hold (spec FR-003a). Nothing in Phase 4 or later starts until Notes
    record Jon's choice: a `000c` fix parent (then do T012) or waive.

  Accept: `$S check --only gates` exits 0 (both `pass`), or plan.md's Notes contain `G1 flagged:`.
- [X] T012 [US1] *(Only if Jon chose a fix parent at T011.)* Create `seriesb/000c-<slug>` with
  `git town append --prototype --no-sync --no-push` from `000b`, holding only the fix Jon named.
  Add it to `parents[]` with `kind: fix-parent` and the Notes reference, and gate it. Accept: `$S
  check --only gates,lineage` exits 0. If T011 passed, mark this task skipped, with "n/a: G1
  passed". **Done: n/a, G1 passed (plan.md Notes, T011).**

**Checkpoint**: the parents exist, mirror upstream, and pass, or the work is held with the flag
recorded.

---

## Phase 4: User Story 2: each step is the old step, re-applied (P1)

**Goal**:

- one `seriesb/NNN` prototype branch per surviving old step, in the old order;
- each step records the old step it came from and every file whose change differs from it;
- old steps fully covered by #768 are dropped.

**Independent Test**: `$S check --only manifest,lineage,branches,differs` exits 0, and every
`steps[].source.old_step` is strictly increasing.

- [X] T013 [US2] Write `tools/series/tests/test_replay.py` on T005's fixture. It checks that:
  - `cut --replay` writes one `planned` step per old step, with the old title and description copied
    and `source.type == "replay"`;
  - `tree <n>` merges (base = old parent tree, ours = new parent tree, theirs = old step tree), and
    reports conflicts or a tree;
  - `--rule theirs --paths GLOB` resolves only conflicts under the globs, recording `how:
    theirs-rule` with a reason;
  - `differs_from_old` lists exactly the paths whose (parent→step) change differs between the old
    and new stacks;
  - `drop` refuses when the trees differ;
  - `build` refuses while a gate is not `pass`, and refuses to reset a branch with commits after
    `build_commit` unless given `--reset`.

  Accept: the file exists and fails before T014.
- [X] T014 [US2] Implement `cut --replay`, the replay source in `tree`/`build`, `--rule theirs`,
  `differs_from_old` and `drop` in `tools/series/series.py`, `tools/series/stack.py` and
  `tools/series/manifest.py`. Reuse `trees.target_tree` unchanged, with the resolutions directory
  `specs/002-seriesb-rebase-stack/series/resolutions/NNN/`. `tree --show/--record` keep refusing
  paths under `tests/`. Accept: `python -m unittest tools.series.tests.test_replay` passes, and
  T004's Accept still passes.
- [X] T015 [US2] Run `$S cut --replay` to write 26 planned steps from the old manifest. Accept:
  `$S check --only manifest` exits 0 with 26 steps whose `old_step` runs 1…26.
- [X] T016 [US2] Replay old 001 and 002 (Objective-C era). For each *n* in 1, 2:
  1. Run `$S tree n`.
  2. Resolve each conflict with `--show`/`--record`. The probe expects one, `src/Core/Scripting/OOJSShip.m`.
     Give each a reason: what #767/#768 changed against what the old step changed.
  3. Run `$S build n`.

  Accept: `$S check --only lineage,branches,differs --steps 1-2` exits 0.
- [X] T017 [US2] *(Changed at T017, 2026-11-02: see spec D1's second amendment and research R4.
  Done as `fold 3 5 --title … --reason …`, then `tree 3 --take-old --keep 'tools/js-parity/**'
  'tools/oxp-upgrade/**' --reason …`. The new 003 is old 005's tree plus the two tools, and T018's
  separate old 004/005 replays no longer exist. The Accept command is unchanged.)* Replay old 003 as the new 003, "Put the game's JavaScript behind an engine façade,
  replacing the QuickJS-ng binding" (research R4).
  - Resolve the conflicts under `src/Core/Scripting/**` and the JavaScript files in
    `src/Core/Debug/**` with `--rule theirs`, reason "the fork's façade replaces #768's binding
    (spec D1)".
  - Resolve every other conflict by hand with `--record`, including the entities, `Universe`,
    `GameController`, meson, CI and `install_deps.sh`.
  - Apply research R5 in this step's tree by recording deletions:
    - `src/Core/Scripting/poc/**`, `src/Core/Scripting/OOJSClasses.m` and
      `src/Core/Scripting/README.md` are removed;
    - `subprojects/packagefiles/quickjs-ng/0001-oolite-primitive-property-assignment.patch` and
      `Resources/Scripts/oolite-quickjs-compat.js` are removed (the default);
    - `tools/js-parity/**` and `tools/oxp-upgrade/**` are kept and added to `additions[]` with
      reasons.
  - Rewrite the title and the description's summary to match.
  - Run `$S build 3`.

  Accept: `$S check --only lineage,branches,differs --steps 1-3` exits 0, and the step's tree
  contains no `src/Core/Scripting/poc/`.
- [X] T018 [US2] Replay old 004 (Objective-C++) and old 005. For old 005:
  - if `$S tree` gives a tree equal to its parent's, run `$S drop 5 --covered-by 768 --reason
    "#768 already makes QuickJS-ng the only engine and removes SpiderMonkey"`;
  - otherwise keep it with a narrowed title naming what is left (expected: NSPR and build-switch
    leftovers), and build it.

  Accept: `$S check --only manifest,lineage,branches,differs --steps 1-5` exits 0, and old 005 is
  either in `dropped[]` or has a title differing from the old one.
- [X] T019 [US2] Replay old 006–010 in order (Objective-C era), resolving and building each as in
  T016. Most conflicts are expected to be the #780/#768 renames, in successive versions of the same
  entity files; reuse a step's resolution reasoning for the next. Accept: `$S check --only
  lineage,branches,differs --steps 1-10` exits 0 (step numbers as currently in the manifest).
- [X] T020 [US2] Replay old 011–026 in order (C++ era from old 011 on), resolving and building each
  as in T016. Accept: `$S check --only manifest,lineage,branches,differs` exits 0 for all steps.
- [X] T021 [US2] Run `$S renumber` if a step was dropped, so step numbers are contiguous from 001
  (spec FR-006). Then check `git town branch` in `oolite-dev` shows one chain
  `develop`→`000a`→`000b`→`001`…. Accept: `$S check --only manifest,lineage,branches` exits 0, and
  `$S check --only baseline` exits 0.

**Checkpoint**: the whole `seriesb` stack exists, one commit per step, unverified.

---

## Phase 5: User Story 3: every step builds and passes; the end is `develop` (P1)

**Goal**:

- every step meets feature 001's verification bar;
- the final tree is `develop` apart from the exclusions and additions.

**Independent Test**: `$S check --verified` exits 0.

- [X] T022 [US3] Run `$S check --only final-tree`.
  - If the last step's tree differs from `develop` (`3aa8d65e8`) outside `exclusions` ∪
    `additions`, find which step introduced each difference: bisect with
    `git diff seriesb/NNN 3aa8d65e8 -- <path>`.
  - Fix that step's resolution with `--record`, rebuild from it (`$S build --from NNN`), and keep
    the reasons current.

  Do this before verification, so that nothing is verified twice. Accept: `$S check --only
  final-tree` exits 0.
- [ ] T023 [US3] Verify the Objective-C-era steps: `$S verify --from 1 --to <last objc step>` in
  the isolated MSYS2.
  - On a failure, fix the step's resolution (never a test; hard rule 1), rebuild from that step,
    and re-verify from it.
  - If a failure traces to removing the #768 patch or `oolite-quickjs-compat.js` (research R5),
    restore that file in the new 003 instead. Move it to `additions[]` with the evidence (the
    failing check and log), and record it in plan.md's Notes.

  Accept: `$S check --verified --steps 1-<last objc step>` exits 0.
- [ ] T024 [US3] Verify the C++-era steps: `$S verify --from <first cxx step>` in Jon's MSYS2,
  handling failures as in T023. Accept: `$S check --verified` exits 0.
- [X] T025 [US3] Spot-check hard rule 1 across the stack. For each step, `git diff --name-status
  <parent> <step> -- tests/` must show no `M`/`D` of a test that exists in the parent unless the
  old step did the same (compare with `series/` at the same old step). Add this as `check
  --only tests`, with a test in `tools/series/tests/test_seriesb_manifest.py`.

  In the same way, add `check --only messages` (spec FR-013, with the patterns in T035), and a test
  that a step commit whose message carries `oo-abc12` fails. Replay `build` takes its commit
  message from the step's title and description, as feature 001's message builder does ("no bead
  ids, no history paths"), and never from the old commit's message.

  Accept: `$S check --only tests,messages` exits 0.

**Checkpoint**: the stack is verified, and it ends at `develop`.

---

## Phase 6: User Story 4: upstream changes arrive by `git town sync --stack` (P2)

**Goal**:

- a sync brings new #767/#768 commits through the stack;
- conflicts are resolved by hand and recorded;
- `check` understands the result.

**Independent Test**: after a real or rehearsed sync, `$S check --verified` exits 0, and `syncs[]`
has an entry.

- [X] T026 [US4] Write `tools/series/tests/test_sync_check.py` on T005's fixture. Its scenario:
  - add a commit to both fixture PR branches;
  - run `git town sync --stack --detached --no-push` in the fixture;
  - run `sync-record --conflict …`;
  - assert that `check` rules 2–3 pass, every step is `stale` until re-verified, a merge with a
    `develop` commit fails rule 4, and a non-merge commit after `build_commit` fails rule 3.

  Accept: the file exists and fails before T027.
- [X] T027 [US4] Implement `sync-record [--conflict STEP:PATH:REASON …]` in `tools/series/series.py`.
  It writes `syncs[]` (`date`, `command`, `parent_heads_before`, `parent_heads_after`,
  `conflicts`), updates `parents[].head`, and sets every step to `stale`. Make `check` accept sync
  merges (research R9). Accept: `python -m unittest tools.series.tests.test_sync_check` passes.
- [X] T028 [US4] Implement FR-011a's re-parent path as `parents --retire`. It applies once #767/#768
  are in upstream `master`, and refuses otherwise:
  - it creates `seriesb/000m-upstream-master` at upstream `master`, as a perennial branch and a
    parent with `kind: upstream-master`;
  - it moves `seriesb/001`'s Git Town parent onto that branch;
  - it marks the old parents `retired` in the manifest.

  It deletes no branch; deletion is Jon's. Test it in
  `tools/series/tests/test_sync_check.py` with the fixture's PR branches merged into its master.
  Accept: that test passes.
- [X] T029 [US4] Write `docs/series-sync.md`, the procedure for Jon and agents:
  - which commands to run, in research R2's order: `parents --refresh`, then
    `git town sync --stack --detached --no-push`, and why agents add the two flags;
  - resolving a conflict, with `git town continue`;
  - `sync-record`;
  - re-verify from the first changed step;
  - when to `parents --retire`.

  Link it from `docs/README.md`. Accept: `grep -q 'series-sync.md' docs/README.md && grep -q
  -- '--detached --no-push' docs/series-sync.md`.
- [ ] T030 [US4] Rehearse a sync, but only if upstream's `quickjs-poc` or `quickjs-default` has
  moved since T009 (check with `git -C oolite-dev fetch hobleyd` and `$S parents`).
  - If they moved, follow `docs/series-sync.md` on the real stack, then run `$S sync-record`,
    re-verify, and update the Notes.
  - If they have not moved, mark this task "n/a: no upstream change since T009" in plan.md's
    Notes. The procedure is covered by T026's fixture test.

  Accept: `$S check --verified` exits 0, and plan.md's Notes have a `T030:` line.

---

## Phase 7: User Story 5: Jon pushes and opens the PRs from a handover (P2)

**Goal**: the descriptions and `HANDOVER.md` are generated, and the check passes.

**Independent Test**: `$S check --verified --only descriptions,handover` exits 0.

- [X] T031 [P] [US5] Extend `describe` for the `seriesb` profile in `tools/series/series.py`. Each
  description:
  - names its old step (`series/NNN-slug`);
  - lists `differs_from_old` with reasons;
  - says it is based on #768 (or the fix parent);
  - notes that it is not independent of the QuickJS PRs (spec edge case for 001).

  `describe --handover` writes:
  - the parents (PR, head, gate);
  - the dropped steps;
  - the additions and exclusions;
  - per step: old step, base, title, size and verification;
  - a push command for the `seriesb/NNN` steps only (Git for Windows' git, as feature 001), with
    the parents never pushed;
  - fork dry-run `gh pr create` commands against each step's parent. Step 001's base is a pushed
    copy of `000b`, sent to the fork only with an explicit refspec:
    `git push origin seriesb/000b-upstream-768-quickjs-only:refs/heads/seriesb/000b-upstream-768-quickjs-only`.
    A bare push would go to the branch's tracking remote, `hobleyd`.
  - an "Upstream, one at a time" section, as in feature 001, against `OoliteProject/oolite`
    `master`:
    - while any parent is `upstream` and not `retired`, the section says "wait: #767/#768 are not
      merged yet". It explains that a PR for step 001 opened now would carry their commits, and
      lists no commands;
    - after `parents --retire`, it lists `gh pr create -R OoliteProject/oolite --base master --head
      jonmseaman:seriesb/NNN-…` for each step, each opened when the one before it has merged
      (spec FR-012);
  - the sync command from `docs/series-sync.md`.

  Add assertions to `tools/series/tests/test_replay.py`. Accept: those tests pass.
- [ ] T032 [US5] Run `$S describe` for every step and `$S describe --handover`. Hand-edit only the
  hand-written sections, for the steps whose purpose changed (the new 003, and old 005 if
  narrowed). Accept: `$S check --verified --only descriptions,handover` exits 0, and
  `specs/002-seriesb-rebase-stack/series/HANDOVER.md` exists.

---

## Phase 8: Polish and cross-cutting

- [X] T033 [P] Update `docs/README.md`'s index and `ROADMAP.md` with the `seriesb` stack: what it is,
  where its manifest is, and that `series/*` remains the master-based option. Describe the code as
  it is now. Accept: `grep -q seriesb ROADMAP.md && grep -q 002-seriesb-rebase-stack docs/README.md`.
- [ ] T034 Run quickstart.md end to end (sections 0–3; section 4 only if T030 ran a real sync), and
  correct quickstart.md and the contract wherever the tool differs. Accept: every command in
  quickstart.md sections 0–3 exits 0 as written.
- [ ] T035 Final gate G4:
  - `python -m unittest discover -s tools/series/tests` passes;
  - `python -I tools/series/series.py check --verified` passes (the old series is untouched);
  - `$S check --verified` passes;
  - `git -C oolite-dev status --porcelain` is empty;
  - `$S check --only baseline` passes (`develop`, `master` and `series/*` unmoved);
  - `$S check --only messages` passes (spec FR-013): no commit that is reachable from a
    `seriesb/NNN` step and absent from its parent has a message matching `\boo-[a-z0-9]{3,}\b` or
    `\bADR-?\d+`;
  - everything is committed in OoliteMigration.

  Accept: all seven exit 0.

---

## Phase 9: User Story 6: the game runs on upstream's QuickJS-ng binding (P1, added 2026-11-02)

**Goal**: `develop`'s scripting layer replaced by #767/#768's binding converted to C++, on
`oolite-dev`'s `feature/upstream-quickjs-binding`. The `ooscript` façade goes. Callers and tests use
upstream's API (spec FR-014–FR-016; research R11).

**Independent Test**:
- All suites pass on the branch with Clang and GCC.
- `git -C oolite-dev grep -n ooscript feature/upstream-quickjs-binding -- src tests` is empty.
- `series/test-changes.md` lists every test that differs from `develop`.

Work happens in the worktree `.agent-tmp/upstream-binding-wt`, never in `oolite-dev`'s main checkout.
Commit to the feature branch as each task finishes. The rules above apply, with FR-015's exception
for tests and FR-016's amended hard rule 6.

- [X] T036 [US6] Create the branch and the worktree:
  `git -C oolite-dev worktree add -b feature/upstream-quickjs-binding .agent-tmp/upstream-binding-wt develop`,
  then build it once (`./mk.sh build test` in the C++ shell) to record the starting point.
  Accept: `git -C oolite-dev merge-base --is-ancestor develop feature/upstream-quickjs-binding`, and
  the worktree's build exits 0.
- [ ] T037 [US6] Write the façade dictionary `specs/002-seriesb-rebase-stack/series/facade-map.md`.
  It has one row per public name in `src/Core/Scripting/ooscript/JSEngine.hpp`: the façade name,
  how `JSEngine_quickjs.cpp` implements it on QuickJS, and the form #768's binding uses for the same
  job (with a file:line example from `seriesb/000b-upstream-768-quickjs-only`). Accept: a script
  `.agent-tmp/facade_map_check.py` lists `JSEngine.hpp`'s public names, and every one appears in the
  table.
- [ ] T038 [US6] Port the engine core to #768's design, in C++:
  - `OOJavaScriptEngine.{h,cpp}`, `OOJSScript`, `OOJSFunction`, `OOJSCall`,
    `OOJSEngineTimeManagement`, `OOJSEngineDebuggerHelpers`, `OOJSPropID.h`;
  - a new `OOJSClasses`, from #768's `OOJSClasses.m`.

  Method (research R11): for each file, `develop`'s C++ file with every façade call replaced by
  #768's QuickJS form, adopting #768's structure. Keep the fork's C++ conventions (`oo::Ref<T>`,
  `oofnd` types, the exemplar `src/Core/OOColor.*`). Accept: `git grep -n ooscript` over those
  files is empty, and their objects compile:
  `ninja -C build/meson_test $(ninja -C build/meson_test -t targets all | grep -oE '[^ :]*(OOJavaScriptEngine|OOJSScript|OOJSFunction|OOJSCall|OOJSEngineTimeManagement|OOJSEngineDebuggerHelpers|OOJSClasses)\.cpp\.obj')`
  exits 0 in the worktree.
- [ ] T039 [P] [US6] Port the entity bindings the same way: `OOJSEntity`, `OOJSShip`, `OOJSStation`,
  `OOJSDock`, `OOJSPlanet`, `OOJSSun`, `OOJSWormhole`, `OOJSPlayer`, `OOJSPlayerShip`,
  `OOJSVisualEffect`, `OOJSExhaustPlume`, `OOJSFlasher`, `OOJSWaypoint`, `OOJSShipGroup` and
  `EntityOOJavaScriptExtensions`. Accept: no `ooscript` in them, and their objects compile (the
  T038 form, with these names).
- [ ] T040 [P] [US6] Port the remaining bindings: `OOJSVector`, `OOJSQuaternion`, `OOJSTimer`,
  `OOJSClock`, `OOJSSound`, `OOJSSoundSource`, `OOJSFont`, `OOJSManifest`, `OOJSMission`,
  `OOJSMissionVariables`, `OOJSSystem`, `OOJSSystemInfo`, `OOJSOolite`, `OOJSGlobal`,
  `OOJSWorldScripts`, `OOJSSpecialFunctions`, `OOJSFrameCallbacks`, `OOJSEquipmentInfo`,
  `OOJSInterfaceDefinition`, `OOJSGuiScreenKeyDefinition`, `OOJSPopulatorDefinition` and
  `OOConstToJSString`. Accept: as T039.
- [ ] T041 [US6] Remove `src/Core/Scripting/ooscript/`, plus `OOJSEngineNativeWrappers` and
  `OOJSPrivateObject` where #768's design has no counterpart (otherwise reduce them to it), and
  update the meson lists. Accept: `git grep -n ooscript -- src/Core/Scripting` is empty in the
  worktree, and `./mk.sh build test` gets past `src/Core/Scripting`.
- [ ] T042 [US6] Move the 50 files outside the scripting layer that name `ooscript`, and the 16 that
  include `OOJavaScriptEngine.h`, to #780's engine-neutral names and #768's API. Accept:
  `git grep -n ooscript -- src` is empty, and `./mk.sh build test` exits 0 with Clang, and with
  `--native-file=gcc.ini`.
- [ ] T043 [US6] Move the tests (FR-015): the 73 in `tests/unit/core`, 2 in `tests/unit/expander` and
  1 in `tests/unit` that use the façade.
  - Keep every assertion. Replace `tests/unit/test_jsengine_quickjs.cpp` (a test of the façade) by
    #768's equivalent where one exists, or remove it.
  - Write `specs/002-seriesb-rebase-stack/series/test-changes.md`: one row per test file that differs
    from `develop` (path, what changed, why, and whether any assertion changed, which should be
    none).

  Accept, all of these:
  - `git grep -n ooscript -- tests` is empty;
  - `tests/run.sh unit` passes;
  - every path in `git diff --name-only develop -- tests` appears in `test-changes.md`.
- [ ] T044 [US6] Bring #768's non-source parts: `Resources/Scripts/oolite-quickjs-compat.js`, the
  QuickJS-ng patch (applied to the fork's newer QuickJS-ng if it still applies and the tests need
  it; research R5's rule), `tools/js-parity/**` and `tools/oxp-upgrade/**`. Record each decision
  with its evidence in plan.md's Notes. Accept: both tools exist on the branch, and plan.md's Notes
  have a `T044:` line.
- [ ] T045 [US6] Verify the target: `./mk.sh build test` with Clang and with GCC (no new warnings),
  then `tests/run.sh unit`, `tests/run.sh component`, `tests/run.sh smoke` and `tests/run.sh gui`
  (one GUI run at a time). Also run `tools/js-parity` against `develop` and the branch, and record
  the differences. Accept: every suite exits 0, and plan.md's Notes have a `T045:` line with the
  results and the parity differences.
- [ ] T046 [US6] *(Jon)* Merge `feature/upstream-quickjs-binding` into `develop` and push. Until he
  does, seriesb's `anchors.develop_target` is the branch tip (spec FR-007). Agents do not do this
  task. Accept: n/a for agents. Record the branch tip in plan.md's Notes when T045 passes.

---

## Phase 10: The switch step (P1, added 2026-11-02)

**Goal**: seriesb ends on upstream's binding. Step 025 takes the target's tree.

- [ ] T047 [US6] Add a `target` source type to the tool, with tests in
  `tools/series/tests/test_replay.py`. A step with `source: {type: "target", ref}` has the target's
  tree minus `exclusions`, plus the parent's `additions`. `differs_from_old` does not apply; the
  description says it is the switch. `cut --replay` keeps it last. Accept:
  `python -m unittest tools.series.tests.test_replay` passes.
- [ ] T048 [US6] Add step 025, "Move the scripting layer to upstream's QuickJS-ng binding", with
  source `feature/upstream-quickjs-binding`. Set `anchors.develop_target` to the branch tip, build
  the step, and verify steps 9–25 (the stopped run's remainder). Accept:
  `$S check --only manifest,lineage,branches,final-tree` exits 0, and
  `$S check --verified --steps 1-25` exits 0.

After Phase 10, T030 (sync rehearsal), T032 (descriptions), T034 (quickstart) and T035 (final gate)
run on the 25-step stack.

---

## Dependencies and execution order

### Phases

- **Setup (T001–T002)**: no dependencies. T002 runs alongside Phase 2, but G0 needs it before
  T009.
- **Foundational (T003–T006)**: T003 → T004. T005 → T006, after T004 (shared files). This phase
  blocks all stories.
- **US1 (T007–T012)**: T007 → T008 → T009 (also needs T002). T010 → T011. T012 only if T011
  flagged and Jon chose a fix parent. **A flagged T011 with no choice from Jon stops everything
  after it.**
- **US2 (T013–T021)**: needs T011 (or T012). T013 → T014 → T015 → T016 → T017 → T018 → T019 → T020
  → T021, strictly in step order.
- **US3 (T022–T025)**: needs US2. T022 → T023 → T024. T025 after T022.
- **US4 (T026–T030)**: T026 → T027 → T028. T029 can follow T027. T030 needs US3 and T029.
- **US5 (T031–T032)**: T031 can start after Phase 2. T032 needs US3.
- **Polish (T033–T035)**: after the stories. T035 is last.

### Story order

US1 → US2 → US3 are sequential by construction. US4 and US5 come after US3, and their tool work
(T026–T029, T031) can be done earlier, alongside US2.

## Parallel examples

```text
# Setup:
T001 baseline                 T002 Git Town scratch probe

# While US2's conflicts are resolved (long), in parallel with T016–T020:
T026–T028 sync tooling        T031 describe/handover generator      T029 docs/series-sync.md

# Polish:
T033 docs index/roadmap       (T034 and T035 after)
```

## Implementation strategy

### MVP (US1)

Phases 1–2, then US1:

- the two parents mirror upstream;
- the parents are gated;
- the tree shows in Git Town.

This alone answers whether #767/#768 are a usable base in our environment. If G1 flags, this is
also where the work stops for Jon's choice.

### Incremental delivery

1. Setup + Foundational → G0.
2. US1 → G1 (parents pass).
3. US2 → the replayed stack, with old 001–005 first. T017 (the new 003) is the largest and most
   uncertain step; see research R4.
4. US3 → verified, ending at `develop`.
5. US4 → sync tooling and procedure. US5 → handover. Jon pushes.

## Notes

- Step numbers in T019–T024 refer to the manifest's current numbering. After a drop and T021's
  renumber, they shift by one from old 006 on.
- Old 005 is the only expected drop (research R4). Any other empty replay is dropped the same way,
  with its `covered_by`.
- `[P]` tasks touch different files. Every task's Accept command is the authority (hard rule 5).
