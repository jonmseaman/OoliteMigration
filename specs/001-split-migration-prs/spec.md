# Feature Specification: Split the C++ migration into a reviewable PR series

**Feature Branch**: `001-split-migration-prs`

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Convert the current fork jonmseaman/oolite into a series of changes instead of one massive C++ migration PR. Create a series of PRs."

## Context

The fork's `develop` is upstream `OoliteProject/oolite` `master` (last merged at `49a5eb9fc`) plus
59 commits. One of them, `935aedb20` "Migrate Oolite from Objective-C/GNUstep to C++ (phases 1-4)",
holds almost all of the work: 1,041 files, +293k/−160k lines. Against upstream the whole fork is
1,142 files, +374k/−249k lines. No Oolite maintainer can review that as one change, and it cannot
be bisected.

The iterative history still exists. The best copy is in **this repo**: before the 2026-10-27 switch
to submodules (`338463308`), the game lived at `upstream/oolite/`, and 1,940 non-merge commits
(2026-09-05 → 2026-10-27, 4,692 counting merges) migrated it step by step. Those commits are
bead-sized and mostly tested. The subtree's last state (`338463308^:upstream/oolite`) is within
6 files (+17/−101) of the squash's tree. The fork also has `origin/migration/phase-1` and `phase-2`
(about 3,500 commits, 2,100 of them merges), which are the same work but noisier. Neither history
can be offered as it is: it is too long, it has merges of upstream subtree pulls, and its messages
carry bead ids and ADR numbers.

This feature replaces "one PR" with an ordered series of PRs that a maintainer can review and
accept one at a time, and that together arrive at the same game as `develop`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A maintainer reviews the migration one step at a time (Priority: P1)

An Oolite maintainer opens the first PR of the series. It is based on upstream `master`, explains
in its description what it changes and why, and is one chapter of the migration: one phase work
item from the phase plan, or a wave of them. They accept it (or ask for changes) without having to
look at any later PR. Then they move to the next.

**Why this priority**: This is the whole point. Without it the migration does not go upstream.

**Independent Test**: Take the series manifest; for each PR in order, check out its branch and
confirm it is based on its predecessor (the first on upstream `master`), that `git town`
records the same parent, that its tree is its chapter's boundary snapshot, and that its
description has the required sections.

**Acceptance Scenarios**:

1. **Given** the series is prepared, **When** a reviewer opens PR *n*, **Then** its base is PR
   *n−1* (PR 1's base is upstream `master` at the recorded commit) and its diff contains only that
   step's change.
2. **Given** a PR whose change is hand-written, **When** the reviewer reads its description,
   **Then** it names its phase and work items, its history range, its size, and where to start
   reading (FR-006).
3. **Given** a PR whose change is mechanical (a reformat, a rename sweep, a vendored library, a
   generated file), **When** the reviewer reads its description, **Then** it names the command that
   reproduces the change, and running that command on the predecessor reproduces the diff exactly.

---

### User Story 2 - Every step leaves a working game (Priority: P1)

A maintainer who has merged PRs 1…*n* and stops there still has an Oolite that builds, passes its
tests and plays. Bisecting a regression later lands on one PR, not on "the migration".

**Why this priority**: Equal to Story 1. A series whose middle steps do not build cannot be merged
step by step, so it is one PR again in disguise.

**Independent Test**: For each branch in the series, run the build and the unit suite on Clang and
GCC, and the smoke suite; all pass and no new warnings appear.

**Acceptance Scenarios**:

1. **Given** any PR branch in the series, **When** it is built on Windows x64 with the compilers
   FR-003 requires for it, **Then** the build succeeds with no warnings under the project's warning
   flags.
2. **Given** any PR branch, **When** the unit and smoke suites run, **Then** they pass.
3. **Given** a PR that changes behaviour a component scenario covers, **When** those scenarios run
   on that branch, **Then** they pass.
4. **Given** a PR whose step introduces or removes a test, **When** it is compared with its
   predecessor, **Then** no existing test was modified or deleted to make the step pass.

---

### User Story 3 - The last step is the fork (Priority: P1)

After the whole series is merged, the result is the game on `develop` today, not an approximation
of it.

**Why this priority**: The series is a re-presentation of finished, tested work. If it drifts from
`develop`, every test result on `develop` stops counting.

**Independent Test**: Compare the tree of the last branch in the series with the tree of the
recorded `develop` commit; the only differences are those listed in the series manifest's
exclusions.

**Acceptance Scenarios**:

1. **Given** the last branch of the series, **When** its tree is compared with the recorded
   `develop` commit, **Then** they are identical apart from the listed exclusions.
2. **Given** the exclusions list, **When** each entry is read, **Then** it names the paths and the
   reason (for example: fork-only CI settings, migration tooling that upstream should not carry).

---

### User Story 4 - Independent fixes can be taken alone (Priority: P2)

Some changes are useful to upstream whether or not it takes the C++ migration: determinism fixes,
the fixed-seed option, bug fixes found by the tests, ports of upstream PRs. A maintainer can take
these without committing to the rest.

**Why this priority**: It gets value upstream early and builds trust before the large steps.

**Independent Test**: Each PR marked independent applies to upstream `master` on its own (without
the PRs before it), builds, and passes upstream's existing checks.

**Acceptance Scenarios**:

1. **Given** a PR marked independent in the manifest, **When** it is rebased alone onto upstream
   `master`, **Then** it applies cleanly and builds.
2. **Given** the series, **When** it is ordered, **Then** independent PRs come before the PRs that
   depend on them.

---

### User Story 5 - Jon opens the PRs from a prepared series (Priority: P2)

Jon receives the series as local branches, a manifest and a PR description per branch. He pushes
the branches and opens the PRs himself, in order, without having to write or reorder anything.

**Why this priority**: Agents never push (hard rule 3); the series must be complete enough that
opening it is a clerical step.

**Independent Test**: The manifest lists every branch with its base, title, description file, kind
(hand-written / mechanical / independent) and verification results; a check script confirms each
listed branch and file exists and the bases chain correctly.

**Acceptance Scenarios**:

1. **Given** the prepared series, **When** Jon reads the manifest, **Then** each entry has a branch,
   base, title, description, kind, size, and the date and result of its verification run.
2. **Given** the description for any PR, **When** it is read, **Then** it says what the step changes,
   why, what behaviour changes (or "none"), how it was verified, and what comes next.

### Edge Cases

- **A chapter boundary snapshot does not build** on the series base: the boundary moves to the
  nearest later merge whose snapshot does, and the manifest records the move. Boundaries never
  move backwards past a work item's last merge.
- **The intermediate state needs code the final tree does not have** (an Objective-C/C++ bridge, a
  compatibility shim): it is allowed in the intermediate PRs and is removed by a later PR in the
  series; the manifest names the PR that adds it and the PR that removes it.
- **Upstream `master` moves while the series is prepared or under review**: the series is rebuilt
  on the new upstream commit using the same plan; the manifest records which upstream commit it is
  based on.
- **`develop` moves while the series is prepared**: the series targets the `develop` commit recorded
  when preparation started; later `develop` work becomes extra PRs at the end.
- **A step passes on Windows but upstream's CI builds macOS or Linux**: macOS is not converted yet
  (Phase 5). The PR description says which platforms it was verified on and which are known not to
  build, rather than claiming they work.
- **A test on `develop` turns out to fail at an intermediate step because the behaviour arrives
  later**: the test is introduced in the PR that brings the behaviour, not earlier; it is never
  weakened.
- **The migration history disagrees with `develop`** (the 6-file gap at the squash, and the 58
  commits on `develop` since): `develop` is the truth. The series takes its steps from the
  history, then a reconciliation step (or extra steps at the end) brings the tree to `develop`.
- **A history range includes a merge of an upstream subtree pull**: upstream's own changes must
  not show up as fork changes. Because the series is based on the upstream commit `develop` last
  merged, the upstream content is already in the base. Each step carries only the migration's
  delta for its range.
- **A history range does not build on its own** (a commit that was fixed by a later one): the
  range is widened to include the fix, or the fix is squashed into the step. A step is never
  offered broken.
- **History commits that were reverted or superseded later in the history** (for example,
  scaffolding added and then deleted): if the add and the delete fall inside one step, they cancel
  out and the step shows neither. If they fall in different steps, they go on the temporary-code
  ledger.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The series MUST be an ordered chain of branches: the first is based on upstream
  `master` at a recorded commit, and each later branch is based on the one before it.
- **FR-002**: The tree of the last branch MUST equal the tree of the recorded `develop` commit,
  except for the paths in the manifest's exclusions list, each with a reason.
- **FR-003**: Every branch in the series MUST build on Windows x64 with no warnings under the
  project's flags, and pass the unit and smoke suites present in its tree. It MUST build with Clang,
  and with GCC whenever its parent builds with GCC (no step may break a compiler its parent
  supports). Objective-C steps are Clang-only, as upstream's are; from the C++ era on, every step
  builds with both. (Amended 2026-11-01 by the plan, research R5.)
- **FR-004**: A branch whose change touches behaviour covered by a component scenario MUST pass
  those scenarios.
- **FR-005**: No branch MAY modify or delete an existing test in order to pass; tests are added in
  the step that makes them pass.
- **FR-006**: Each history PR MUST be exactly one **chapter**: the contiguous history range that
  holds one phase work item, or one wave of interleaved work items, from the phase plan
  (`archive/phase-0-4-docs:docs/phases/`). It ends at a recorded boundary merge. There is no line
  limit. The description names the chapter's phase, its work items, its history range and its
  measured size, and gives a reading order. The chapter list is pinned in research R14. (Amended
  2026-11-01: Jon chose option B over a 3,000-line limit.)
- **FR-007**: A mechanical PR (reformat, rename sweep, comment sweep, vendored import, generated
  file) MUST contain only that mechanical change and MUST name a command that reproduces its diff
  exactly from its base.
- **FR-008**: Changes that are useful without the migration (determinism, fixed seed, bug fixes,
  ports of upstream PRs) MUST be separate PRs, placed before anything that depends on them, and
  marked independent if they apply to upstream `master` alone.
- **FR-009**: The series MUST follow the order in which the migration is safe to review: the test
  safety net first, then independent fixes, then the JavaScript engine, then the Foundation
  replacement, then class conversions grouped by subsystem, then removal of the Objective-C runtime,
  then source hygiene and formatting.
- **FR-010**: Any temporary code an intermediate step needs (bridges, shims) MUST be removed by a
  later PR in the series, and the manifest MUST name both PRs.
- **FR-011**: Each PR MUST have a description stating what it changes, why, behaviour changes (or
  "none"), the platforms and suites it was verified on, and its position in the series.
- **FR-012**: The series MUST come with a manifest listing, per PR: branch, base, title,
  description file, kind, size, and verification result with date; plus the upstream and `develop`
  commits it was built from and the exclusions list.
- **FR-013**: A check MUST exist that exits nonzero unless every manifest entry's branch exists, the
  bases chain as listed, each history step's tree is its chapter boundary snapshot carried onto the
  base, and the last tree matches `develop` apart from exclusions.
- **FR-014**: Preparing the series MUST NOT change `develop`, `master` or `main`, MUST NOT push,
  and MUST NOT open PRs; those are Jon's steps.
- **FR-015**: Steps MUST be derived from the iterative migration history in this repo
  (`upstream/oolite/` up to `338463308^`): each step is a contiguous range (or a grouped set) of
  history commits, re-based onto the series base, with history paths mapped from
  `upstream/oolite/` to the repo root. The manifest MUST record each step's source range.
- **FR-016**: Bookkeeping-only history commits (bead ids, docs paths, tracker files outside
  `upstream/oolite/`) MUST NOT produce steps; a step's diff contains only game-tree changes.
- **FR-017**: Commit messages and PR descriptions MUST explain the code, not the project's history:
  no bead ids or ADR numbers.
- **FR-018**: The ordering MUST be recorded in Git Town's branch lineage as well as in the
  manifest. Each step is created with `git town append` from its predecessor, so `git town` knows
  every step's parent. The root of the stack is a base branch at the series' upstream commit, not
  `develop`. The check (FR-013) MUST fail if the Git Town lineage and the manifest disagree.
- **FR-019**: Branch names MUST carry the step's position as a zero-padded number,
  `series/NNN-slug` (for example `series/001-fixed-random-seed`), so that sorting by name gives the
  series order. Inserting a step later renumbers the steps after it, and the manifest and lineage
  are updated with it.

### Key Entities

- **Series**: the ordered set of PRs; based on one upstream commit, ending at one `develop` commit.
- **Step (PR)**: one branch and its description; kind is hand-written, mechanical or independent;
  has a base, a size and a verification record.
- **Manifest**: the machine-checkable list of steps, the two anchor commits, the exclusions, and
  the temporary-code ledger (which step adds and which removes each shim).
- **Exclusion**: a path in `develop` that the series deliberately does not carry upstream, with a
  reason.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of branches in the series build and pass unit and smoke suites on both
  compilers; the verification record shows it for every step.
- **SC-002**: The last branch matches `develop` exactly outside the exclusions list (zero
  unexplained differences).
- **SC-003**: Every history PR maps to exactly one chapter of the phase plan, and every phase work
  item appears in exactly one PR's description.
- **SC-004**: The series has 25 PRs (19 history chapters and 6 `develop`-tail steps), plus the
  hoisted independent fixes. A reviewer
  can tell from the title and first paragraph of any PR which phase and work item it is and why it
  comes where it does.
- **SC-005**: Every mechanical PR's diff is reproduced exactly by its stated command.
- **SC-006**: At least the independent fixes can be offered upstream as PRs that apply to upstream
  `master` alone.
- **SC-007**: Jon can open the whole series from the manifest without editing a title, description
  or base.

## Assumptions

Defaults taken where the request did not say (recorded per CLAUDE.md rule 8; Jon may override):

- **"Create PRs" means prepare them, not open them.** Agents never push (hard rule 3). The
  deliverable is local branches in `oolite-dev`, a description per PR and the manifest; Jon pushes
  and opens the PRs. Conservative: nothing outward-facing happens without him.
- **Target is upstream `OoliteProject/oolite` `master`**, at the commit `develop` last merged
  (`49a5eb9fc`), because the series is for the upstream maintainers (Phase 4p's goal). It can be
  opened against the fork first for a dry run with no change to the branches.
- **Anchor `develop` commit** is the tip when preparation starts (currently `3aa8d65e8`); later work
  is appended.
- **The series is replayed from the iterative history in this repo** (`upstream/oolite/`, 1,940
  non-merge commits) because those commits are already small, ordered and tested, and the
  history's end is 6 files from the squash. Commits are grouped into chapters by phase and work
  item.
  The fork's `origin/migration/phase-*` branches are a fallback for any range the subtree history
  lacks. `develop` stays the authority on the final tree (FR-002).
- **Granularity is the chapter, not a line count** (Jon, 2026-11-01, option B in research R13).
  Measured sizes run from 2k to 79k reviewed lines (median about 20k). Reviewers get structure in
  place of small diffs.
- **Verification platform** is Windows x64 (Clang and GCC), the only platform the fork builds today.
  Linux is reported where it builds; macOS is Phase 5 and is stated as not verified.
- **Fork-only content** (fork CI tweaks, migration-only tooling if any remains in `oolite-dev`) goes
  in the exclusions list rather than upstream; deciding each item is part of the plan.
- **Branch naming and lineage**: `series/NNN-slug` with three digits, kept although about 24 steps
  fit in two, so names stay stable if chapters are split later. The stack is built with `git town append` (per Jon,
  2026-11-01). In `oolite-dev`, Git Town's main branch is `develop`, so the stack's root is a local
  base branch `series/000-upstream-base` at `49a5eb9fc`, made Git Town's parent of step 001.
  Pushing (`git town sync`/`propose`) stays Jon's step.
- **Squash merges**: Jon squash-merges on GitHub, so each step should read well as one commit; the
  history commits inside a step are a means of building it, not something the reviewer sees.
- Phase 4p polish work continuing on `develop` is not blocked by this feature; it lands as later
  steps.
