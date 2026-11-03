# Feature Specification: Rebuild the PR series on upstream's QuickJS PRs (`seriesb/*`)

**Feature Branch**: `002-seriesb-rebase-stack`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "I recently created a series of branches series/* numbered up to 026
where I implemented a series of changes preparing it for upstream merging. I want to now create a
seriesb set of branches, which are duplicates of the old branches, except they are rebased onto
newer code. So, I want a tree of branches starting from root something like this, also built with
git town. develop / seriesb/00-parent-spidermonkey / seriesb/00-parent-remove-spidermonkey (can
choose better names for these branches) / seriesb/001-random-seed-env / seriesb/002-safety-net /
seriesb/003... (003 right now is the JS facade, but this wouldn't be needed if we go with the
upstream quickjs change). This specification is for making that series of branches."

## Context

Feature 001 (`specs/001-split-migration-prs`) built `series/000-upstream-base` …
`series/026-google-style-format` in `oolite-dev`: 26 steps, each one commit on the one before.
They start at upstream `49a5eb9fc` and end at the fork's `develop` (`3aa8d65e8`), apart from the
listed exclusions. Each step is verified and recorded in `series/manifest.json`.

Upstream has moved since then:

- `master` is at `7437f22a5` (#780, engine-neutral JavaScript names outside the scripting layer).
  The fork's `develop` already contains it.
- **#767** (`hobleyd:quickjs-poc`, open, 21 commits, head `3758f8a09`, based on `7437f22a5`) adds
  QuickJS-ng beside SpiderMonkey behind a build option.
- **#768** (`hobleyd:quickjs-default`, open, 29 commits, head `db4920103`) is stacked on #767. It
  makes QuickJS-ng the only engine and removes SpiderMonkey.
- #772 (`hobleyd:test-harness`, open) is not stacked on #768 and conflicts with `master`.

Old steps 003 (engine façade with a QuickJS-ng backend) and 005 (switch to QuickJS-ng and remove
SpiderMonkey) do the same job as #767 and #768, but with different code: the scripting sources of
#768 and `series/005-quickjs-switch` differ by about 29.5k added and 22.6k removed lines.
If upstream merges #767 and #768, a series based on `master` would have to re-propose that work in
a second form. Basing the series on #768 lets upstream review it as the continuation of the
QuickJS work it is already reviewing.

The re-anchor dry run (feature 001, task T034) found up to 74 conflicts when the stored steps were
replayed onto `7437f22a5`. Most are #780's renames in files the migration rewrote. This feature
meets those conflicts and the new #767/#768 ones.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Jon sees the new stack as one tree under the upstream QuickJS PRs (Priority: P1)

Jon lists the branch tree in `oolite-dev`. He sees two parent branches that are exactly upstream's
#767 and #768, then the migration steps in order, each the child of the one before. The old
`series/*` stack is still there, unchanged, next to it.

**Why this priority**: This is what was asked for. Without the tree there is nothing to review or
push.

**Independent Test**: Read the branch lineage that Git Town records for every `seriesb/*` branch.
Confirm it forms one chain: `seriesb/000a…` → `seriesb/000b…` → `seriesb/001…` → … → the last
step. Confirm each branch's commit is a direct descendant of its parent's tip, and that every
`series/*` branch still points at the commit the old manifest records.

**Acceptance Scenarios**:

1. **Given** the stack is built, **When** Jon displays the Git Town branch tree, **Then** the
   `seriesb/*` branches appear as one chain under the root, in step order, with the two parents
   first.
2. **Given** `seriesb/000a-upstream-767-quickjs-option` and `seriesb/000b-upstream-768-quickjs-only`,
   **When** their tips are compared with the recorded heads of upstream #767 and #768, **Then**
   they are the same commits.
3. **Given** the stack is built, **When** any `series/*` branch or `develop` is compared with its
   state before the work, **Then** it has not moved.

---

### User Story 2 - Each step is the old step, re-applied on newer code (Priority: P1)

A reviewer who has read the old `series/NNN` PR opens the matching `seriesb` step. It has the same
title, purpose and description. The diff is the same change, except where upstream's newer code
forced a different resolution, and the description says where that happened.

**Why this priority**: The series exists to be reviewed. A "duplicate" that silently changes
content would waste the review already done on the old stack.

**Independent Test**: For each `seriesb` step, look up the old step it came from in the new
manifest. Compare the two steps' change summaries (files touched, size). Confirm every difference
falls in a file listed in that step's re-resolution notes.

**Acceptance Scenarios**:

1. **Given** a `seriesb` step derived from old step *k*, **When** its description is read,
   **Then** it names old step *k* and lists the files that were re-resolved against the new base,
   with the reason.
2. **Given** an old step whose whole purpose is already done by #767 or #768, **When** the new
   series is listed, **Then** that step is absent and the manifest says which upstream PR made it
   unnecessary.
3. **Given** an old step that #767 or #768 does only in part, **When** the new series is listed,
   **Then** only the remaining part is present, and its description states what upstream already
   provides.

---

### User Story 3 - Every step still builds and passes, and the end is still `develop` (Priority: P1)

Merging `seriesb` steps 1…*n* and stopping there leaves a game that builds, passes its tests and
plays. After the last step the tree is the fork's `develop`, so every test result on `develop`
still counts.

**Why this priority**: A rebased stack whose middle does not build cannot be merged step by step.
That is the same bar the old series met.

**Independent Test**: Run each step's verification as the old series did: build, unit, smoke, and
component scenarios where the step touches covered behaviour, on Clang and also on GCC wherever
the parent builds with GCC. Then compare the last step's tree with `develop`.

**Acceptance Scenarios**:

1. **Given** any `seriesb` step, **When** it is built and its suites run, **Then** they pass with
   no new warnings, and the result is recorded in the manifest with its date.
2. **Given** the last `seriesb` step, **When** its tree is compared with the recorded `develop`
   commit, **Then** the only differences are the listed exclusions.
3. **Given** a step, **When** it is compared with its parent, **Then** no existing test was
   modified or deleted to make it pass.

---

### User Story 4 - Upstream changes flow down the stack with `git town sync --stack` (Priority: P2)

#767 and #768 are still open. They will gain commits, and they may be merged into upstream
`master`. Jon (or an agent) runs `git town sync --stack`. The new upstream commits reach the
parents and are merged down through every step. Conflicts stop the sync and are resolved by hand
in the step where they appear, the usual Git Town way. Nothing is rebuilt from scratch.

**Why this priority**: The base is a pair of open PRs, so the stack will go stale. Git Town is the
tool Jon already uses for stacks. A merge with manual conflict resolution is an acceptable cost.

**Independent Test**: Sync the stack after upstream adds a commit to #767 or #768, or simulate one
with a scratch copy of the parent's tracking ref. Confirm that:

- the parent's tip is again the PR's head;
- every step contains the new commit;
- no `develop` commit entered any `seriesb` branch;
- after any conflicts are resolved, each step still meets its verification bar.

**Acceptance Scenarios**:

1. **Given** new commits on #767 or #768, **When** Jon runs `git town sync --stack` on the
   `seriesb` stack, **Then** each parent fast-forwards to its PR's head, and the change is merged
   into each step in order.
2. **Given** a sync that hits a conflict, **When** it stops, **Then** the conflict is resolved by
   hand in that step, the sync continues, and the step's notes record the files and why.
3. **Given** upstream merges #767 and #768 into `master`, **When** the stack is next synced,
   **Then** the parents can be retired, and `seriesb/001` can be re-parented onto upstream
   `master`, without changing the content of steps 001 onward.

---

### User Story 5 - Jon pushes and opens the PRs from a handover (Priority: P2)

As with the old series, Jon receives a manifest, a description per step and a handover listing the
push and `gh pr create` commands. Opening the series is clerical work.

**Why this priority**: Agents never push (hard rule 3).

**Independent Test**: The series check command exits 0 for the `seriesb` manifest. Every branch,
description file and verification record it names exists, and every base chains correctly.

**Acceptance Scenarios**:

1. **Given** the handover, **When** Jon reads it, **Then** it lists both parents with the upstream
   PR and head commit each one mirrors, every step with old-step mapping, base, title, size and
   verification, and the push and PR commands.
2. **Given** the handover's PR commands, **When** they are read, **Then** the dry-run PRs on the
   fork target each step's parent, and upstream PRs are not offered for the two parents (they
   are upstream's own).

### Edge Cases

- **#767 or #768 does not build or pass its own tests in our environment**: this is a gate. Work
  on the steps stops, the parent stays an exact mirror (upstream's branches are not ours to
  change), and the failure is flagged to Jon with what fails and why. Jon then picks one of two
  courses:
  - **(a)** a third parent, `seriesb/000c-<slug>`, is added between `000b` and `001`. It holds only
    the fix, and the steps are built on it.
  - **(b)** the `seriesb` series is held, and `series/*` remains the current series.

  The plan records the flag and the chosen course in its Notes. Without a choice, the default is
  (b), hold. A fix is never folded silently into step 001 or later.
- **#767 or #768 gains commits during the work**: the steps are built on the heads recorded at the
  start, and the newer commits arrive through `git town sync --stack` (Story 4).
- **#767/#768 are merged upstream, squashed or closed**: if merged, the parents become upstream
  `master` (Story 4). If closed without merge, the stack is not rebased back onto `master` without
  Jon's say. The `series/*` stack remains the master-based option.
- **The fork's scripting layer and #768's QuickJS binding disagree**: see Decision D1. The end tree
  is `develop`, so the fork's version wins. It enters in one named step, not piecemeal across later
  steps.
- **A step's old boundary no longer builds on the new base**: as in feature 001, the step is fixed
  in place (resolution, or a later fix folded in). It is never offered broken, and the change is
  recorded in that step's re-resolution notes.
- **An old step becomes empty after rebasing** (its whole change is already in a parent): it is
  dropped and recorded (Story 2, scenario 2). Later step numbers close the gap.
- **The old stack's hoisted step 001 (`OO_RANDOM_SEED`)** no longer applies to upstream `master`
  alone. It now sits above #768 and is no longer independent of the QuickJS PRs. Its description
  says so.
- **Intermediate steps carry `JS_*` and Objective-C/GNUstep symbols** (SpiderMonkey in 000a,
  QuickJS's own `JS_*` API, GNUstep before the C++ era): this is allowed in intermediate steps
  only, as in feature 001 (hard rule 6 applies to the end tree). The last step is `develop`, which
  meets the rule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The new series MUST be a single chain of local branches in `oolite-dev` named
  `seriesb/<NNN>-<slug>`. Git Town MUST record each branch's parent, and the chain MUST hang from
  the root the user drew (`develop`, Git Town's main branch).
- **FR-002**: The first two branches MUST be `seriesb/000a-upstream-767-quickjs-option` and
  `seriesb/000b-upstream-768-quickjs-only`. Their tips MUST be exactly the head commits
  of upstream #767 and #768, as recorded at build time and as updated by each sync.
- **FR-003**: `git town sync --stack` MUST be the way upstream changes reach the stack. It brings
  each parent up to its upstream PR's head and merges changes down through the steps. It MUST NOT
  bring `develop`'s commits or content into a `seriesb` parent or step. `develop` is the root in
  name only.
- **FR-003a**: Both parents MUST build, and pass their own tests, in our environment before any
  step is built on them. On failure, the work stops and the failure is flagged to Jon. Jon either
  adds a third parent `seriesb/000c-<slug>`, holding only the fix, between `000b` and `001`, or
  holds the series. Without his choice, the series is held.
- **FR-004**: Every step above the parents MUST derive from an old `series/*` step, in the old
  order. The new manifest MUST record, for each step, the old step it came from and every file
  whose resolution differs from the old step, with the reason.
- **FR-005**: An old step whose purpose #767/#768 fully provide MUST be dropped. One they provide
  in part MUST keep only the remainder. The manifest MUST record which (old 003 and old 005 are
  the expected cases).
- **FR-006**: Steps MUST be numbered contiguously from 001 with three digits. Titles and
  descriptions MUST follow the old step's, edited only where the new base changes what the step
  does.
- **FR-007**: The last step's tree MUST equal the recorded `develop` commit's tree, apart from the
  manifest's exclusions and additions. Each carries a reason.
  - Exclusions are what `develop` has and the series does not. The old series' three are the
    default.
  - Additions are paths #767/#768 add that the series keeps although `develop` lacks them, namely
    upstream's stand-alone tools (`tools/js-parity/**`, `tools/oxp-upgrade/**`).

  (Amended 2026-11-02 by the plan, research R5.) After a sync, paths that upstream's PRs changed
  since the stack was built may differ too: `develop` does not have upstream's newer work. Each
  sync record lists them. (Amended 2026-11-02 at T027.)
- **FR-008**: Every step MUST meet the old series' verification bar (feature 001 FR-003, FR-004,
  FR-005): it builds with no warnings under the project's flags; it builds with Clang, and with
  GCC wherever its parent does; unit and smoke pass; component scenarios pass where the step
  touches covered behaviour; no existing test is modified or deleted. Results are recorded per
  step with a date. The two parents are verified and recorded too, but they are not changed.
- **FR-009**: The old `series/*` branches, their Git Town lineage, the old manifest and `develop`
  MUST be left unchanged.
- **FR-010**: The initial build of the stack MAY reuse feature 001's stored resolutions. Each
  conflict resolved when building the stack, or during a later sync, MUST be recorded in the
  affected step's notes (files and reason). Resolving by hand is acceptable.
- **FR-011**: After a sync, every step MUST again meet FR-008 before the series check passes. Its
  verification record is dated after the sync.
- **FR-011a**: When #767/#768 are merged into upstream `master`, the stack MUST be able to drop
  the parents and re-parent `seriesb/001` onto `master`, without changing the content of the
  steps.
- **FR-012**: The series MUST come with a manifest, a PR description per step and a handover
  (push commands, dry-run PR commands on the fork, upstream PR commands for steps 001 onward), as
  the old series did. A check command MUST exit 0 only when every branch, file, base and current
  verification is present.
- **FR-013**: Nothing is pushed. Jon pushes and opens PRs (hard rule 3). Commits on `seriesb/*`
  branches carry no bead ids or ADR numbers in their messages (as feature 001 FR-017).

### Key Entities

- **Parent branch**: a `seriesb/000a`/`000b` branch mirroring one upstream PR. It has the upstream
  PR number, the head commit it mirrors and a verification record. It changes only by following
  its PR on sync.
- **Fix parent** (only if FR-003a calls for one): `seriesb/000c-<slug>`, our own fix above the
  upstream parents. It records what it fixes and why.
- **Step**: a `seriesb/NNN` branch. It starts as one commit on its parent and gains merge commits
  from later syncs. It records its old step, title, description file, size, re-resolution notes
  (files and reasons) and verification record.
- **Dropped step**: an old step with no `seriesb` counterpart. It records the reason and the
  upstream PR that covers it.
- **Stored resolution**: a resolved file from a replay merge, stored per step and keyed by its
  three input files. Feature 001's resolutions may be consulted, but they don't match replay inputs
  and don't apply automatically. Conflicts during later syncs are resolved by hand and recorded.
- **Manifest (`seriesb`)**: the ordered parents and steps, the anchors (upstream PR heads,
  `develop` commit) and the exclusions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of `seriesb` steps build and pass their recorded verification, and the series
  check exits 0.
- **SC-002**: The last step's tree differs from `develop` only in listed exclusions and additions
  (0 unlisted paths).
- **SC-003**: The new series has no more steps than the old one (26 or fewer). Every old step
  that #767/#768 fully cover is in the dropped list, with the PR that covers it. Every old step
  they cover in part has a narrowed title that names what is left (FR-005). (Amended 2026-11-02
  after the analysis: research R4 measured the new 003 as no smaller than old 003, so "the old 003
  is reduced" was not a criterion the work could meet.)
- **SC-004**: All 27 `series/*` branches and `develop` point at the same commits before and after
  the work.
- **SC-005**: After a `git town sync --stack` that picks up new upstream commits, and once any
  conflicts are resolved by hand, every parent matches its PR's head. Every step contains the new
  commits, no `develop` commit appears in any `seriesb` branch, and the series check exits 0.
- **SC-007**: If a parent fails to build or pass in our environment, the failure is flagged before
  any step is built on it (0 steps built on an unflagged failing parent).
- **SC-006**: Every difference between a `seriesb` step and its old step is accounted for by that
  step's re-resolution notes (0 unexplained files).

## Assumptions

- The "newer code" is upstream's #767 and #768 at their heads on 2026-11-02 (`3758f8a09`,
  `db4920103`), both above `master` `7437f22a5`. The user's sketch puts SpiderMonkey's removal
  (#768) on top of the QuickJS option (#767), and the PRs are stacked that way upstream.
- `develop` stays at `3aa8d65e8` for the duration. Later `develop` work is out of scope here.
- The feature 001 tooling (series tool, stored resolutions, verification shells, isolated MSYS2
  for Objective-C eras) is reused and extended, not replaced.
- #772 (test harness) is out of scope. It is not stacked on #768 and conflicts with `master`.
- Upstream PR heads are fetched into local refs in `oolite-dev`. Fetching is not pushing.

## Decisions taken without Jon (defaults, open to override)

Hard rule 8 and the agent contract say not to wait on a question, so each item below records the
default that was taken.

- **D1 – scripting layer (scope)**: the end tree stays `develop`, so the fork's engine façade and
  its C++ scripting layer replace #768's QuickJS binding. Old steps 003, 004 and 005 are each
  replayed onto #768 as separate steps:
  - the new 003 puts the game's JavaScript behind the façade in place of #768's binding;
  - old 005 is dropped, or keeps only what #768 left undone.

  (Amended 2026-11-02 by the plan, research R4. Collapsing 003 and 005 into one step would have
  meant moving 004, which was cut on 003's tree.)

  **Amended again 2026-11-02 at T017, after building step 2.** Old 003 replayed on its own reverts
  #768's removal of SpiderMonkey (old 003 still has it; old 005 removes it), so that step on top of
  #768 is not reviewable. #780's engine-neutral names, which `develop` dropped when it merged #780,
  would also stop compiling against the façade. So old 003, 004 and 005 fold into one new step
  003. Its tree is old 005's tree whole, plus the two kept upstream tools (research R4, R5). The
  later steps then replay cleanly. The rejected alternative replays old 004 (the Objective-C++
  rename) onto #768 first: it keeps the rename separate, but needs new, unverified resolutions in
  #768's binding and meson files. Jon can ask for it. *Why*: it keeps every
  verified result on `develop` meaningful and bounds the work to re-resolving known steps. The
  rejected alternative is to adopt upstream's binding as-is and port steps 004–026 onto it. The end
  tree would then no longer be `develop`, so that is a new migration and would need its own spec.
  The plan must measure this step's size. If it is not clearly smaller than old 003 + 005, the plan
  records that as a finding for Jon. **Measured (plan R4): not smaller.** The replay gives 124
  conflicted files and about 364 changed files, against 370 for old 002→005. The finding is
  recorded, and the default stands.
- **D2 – parent names**: `seriesb/000a-upstream-767-quickjs-option` and
  `seriesb/000b-upstream-768-quickjs-only` replace the sketch's `00-parent-spidermonkey` /
  `00-parent-remove-spidermonkey`. They sort before `001` and name the PR they mirror.
- **D3 – numbering**: contiguous renumbering (the sketch's "seriesb/003…" is the next surviving
  step), with the old step number kept in the manifest and description. The rejected alternative
  keeps old numbers with gaps.
- **D4 – root**: `develop` is the Git Town root as drawn, but the parents follow their upstream PRs
  and never sync with `develop` (FR-003). The plan picks the Git Town branch types and tracking
  setup that make `git town sync --stack` behave this way.

Settled by Jon (2026-11-02):

- Upstream changes arrive through `git town sync --stack`. Conflicts are resolved by hand; a
  rebuild-from-scratch tool is not required.
- A parent that fails to build or pass its tests in our environment is flagged. Jon then either
  adds a fix parent `seriesb/000c-<slug>` above the upstream parents, or holds the series. The
  default without his choice is to hold.
