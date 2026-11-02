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

### User Story 4 - The stack can be rebuilt when upstream moves again (Priority: P2)

#767 and #768 are still open. They will gain commits, and they may be merged or squashed. Jon (or
an agent) can rebuild the `seriesb` stack on the new heads from the recorded plan and stored
resolutions, without redoing the conflict work done this time.

**Why this priority**: The base is a pair of open PRs, so the stack will go stale. Rebuilding by
hand each time would cost as much as this feature.

**Independent Test**: Point the recorded parents at a different pair of commits (for example the
same PRs one commit earlier). Rebuild. Confirm that only conflicts with no stored resolution are
reported, and that the rest of the stack is reproduced.

**Acceptance Scenarios**:

1. **Given** new heads for #767/#768, **When** the stack is rebuilt, **Then** previously resolved
   conflicts are re-applied without manual work, and new ones are listed by step and file.
2. **Given** upstream merges #767 and #768 into `master`, **When** the stack is rebuilt, **Then**
   the parents can be replaced by `master` and steps 001 onward are unchanged in content.

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

- **#767 or #768 does not build or pass in our environment**: the parent is still mirrored
  exactly; parents are not ours to fix. The failure is recorded. If a later step needs a fix, it
  goes into the first step that needs it, and that step's description names it.
- **#767 or #768 gains commits during the work**: the stack is built on the heads recorded at the
  start. The newer heads are applied in a later rebuild (Story 4).
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
  `seriesb/000b-upstream-768-quickjs-only`. Their tips MUST be exactly the recorded head commits
  of upstream #767 and #768.
- **FR-003**: No sync, rebuild or other stack operation MAY bring `develop`'s commits or content
  into a `seriesb` parent or step. `develop` is the root in name only, and each step's content
  derives from its parent.
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
  manifest's exclusions. Each exclusion carries a reason, and the old series' three exclusions are
  the default.
- **FR-008**: Every step MUST meet the old series' verification bar (feature 001 FR-003, FR-004,
  FR-005): it builds with no warnings under the project's flags; it builds with Clang, and with
  GCC wherever its parent does; unit and smoke pass; component scenarios pass where the step
  touches covered behaviour; no existing test is modified or deleted. Results are recorded per
  step with a date. The two parents are verified and recorded too, but they are not changed.
- **FR-009**: The old `series/*` branches, their Git Town lineage, the old manifest and `develop`
  MUST be left unchanged.
- **FR-010**: Every conflict resolved while building the stack MUST be stored so that a rebuild on
  new parent heads re-applies it. A rebuild MUST report only conflicts with no stored resolution.
- **FR-011**: A rebuild MUST accept new parent commits, including the case where #767/#768 have
  been merged into upstream `master`, without editing the step definitions.
- **FR-012**: The series MUST come with a manifest, a PR description per step and a handover
  (push commands, dry-run PR commands on the fork, upstream PR commands for steps 001 onward), as
  the old series did. A check command MUST exit 0 only when every branch, file, base and current
  verification is present.
- **FR-013**: Nothing is pushed. Jon pushes and opens PRs (hard rule 3). Commits on `seriesb/*`
  branches carry no bead ids or ADR numbers in their messages (as feature 001 FR-017).

### Key Entities

- **Parent branch**: a `seriesb/000x` branch mirroring one upstream PR head. It has the upstream PR
  number, a head commit and a verification record. It is never modified.
- **Step**: a `seriesb/NNN` branch holding one commit on its parent. It records its old step, title,
  description file, size, re-resolution notes (files and reasons) and verification record.
- **Dropped step**: an old step with no `seriesb` counterpart. It records the reason and the
  upstream PR that covers it.
- **Stored resolution**: a resolved file keyed by the inputs it was resolved from, reused by later
  rebuilds.
- **Manifest (`seriesb`)**: the ordered parents and steps, the anchors (upstream PR heads,
  `develop` commit) and the exclusions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of `seriesb` steps build and pass their recorded verification, and the series
  check exits 0.
- **SC-002**: The last step's tree differs from `develop` only in listed exclusions (0 unlisted
  paths).
- **SC-003**: The new series has no more steps than the old one (26 or fewer), and at least one
  old step (the old 003) is dropped or reduced to the delta that #767/#768 leave.
- **SC-004**: All 27 `series/*` branches and `develop` point at the same commits before and after
  the work.
- **SC-005**: A rebuild on the same parent heads reproduces every `seriesb` tree with zero new
  conflicts and no manual steps.
- **SC-006**: Every difference between a `seriesb` step and its old step is accounted for by that
  step's re-resolution notes (0 unexplained files).

## Assumptions

- The "newer code" is upstream's #767 and #768 at their heads on 2026-11-02 (`3758f8a09`,
  `db4920103`), both above `master` `7437f22a5`. The user's sketch puts SpiderMonkey's removal
  (#768) on top of the QuickJS option (#767), and the PRs are stacked that way upstream.
- `develop` stays at `3aa8d65e8` for the duration. Later `develop` work is a later rebuild's
  concern.
- The feature 001 tooling (series tool, stored resolutions, verification shells, isolated MSYS2
  for Objective-C eras) is reused and extended, not replaced.
- #772 (test harness) is out of scope. It is not stacked on #768 and conflicts with `master`.
- Upstream PR heads are fetched into local refs in `oolite-dev`. Fetching is not pushing.

## Decisions taken without Jon (defaults, open to override)

Hard rule 8 and the agent contract say not to wait on a question, so each item below records the
default that was taken.

- **D1 – scripting layer (scope)**: the end tree stays `develop`, so the fork's engine façade and
  its C++ scripting layer replace #768's QuickJS binding. Old steps 003 and 005 collapse into one
  step placed where old 003 was, titled roughly "Put the QuickJS-ng binding behind the engine
  façade". It holds only the delta between #768 and the fork's façade. *Why*: it keeps every
  verified result on `develop` meaningful and bounds the work to re-resolving known steps. The
  rejected alternative is to adopt upstream's binding as-is and port steps 004–026 onto it. The end
  tree would then no longer be `develop`, so that is a new migration and would need its own spec.
  The plan must measure this step's size. If it is not clearly smaller than old 003 + 005, the plan
  records that as a finding for Jon.
- **D2 – parent names**: `seriesb/000a-upstream-767-quickjs-option` and
  `seriesb/000b-upstream-768-quickjs-only` replace the sketch's `00-parent-spidermonkey` /
  `00-parent-remove-spidermonkey`. They sort before `001` and name the PR they mirror.
- **D3 – numbering**: contiguous renumbering (the sketch's "seriesb/003…" is the next surviving
  step), with the old step number kept in the manifest and description. The rejected alternative
  keeps old numbers with gaps.
- **D4 – root**: `develop` is the Git Town root as drawn, but the parents are pinned mirrors that
  never sync with it (FR-003). The plan picks the Git Town branch types that enforce this.
