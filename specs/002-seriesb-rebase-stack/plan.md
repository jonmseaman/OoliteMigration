# Implementation Plan: Rebuild the PR series on upstream's QuickJS PRs (`seriesb/*`)

**Branch**: `feature/phase4-polish` (OoliteMigration). Game branches are `seriesb/*` in `oolite-dev`.

**Date**: 2026-11-02

**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-seriesb-rebase-stack/spec.md`

## Summary

Mirror upstream #767 and #768 as two observed Git Town parents. Then replay each verified
`series/*` step onto them as a prototype branch, using feature 001's merge-and-resolution tool
under a new `--series seriesb` profile. Before anything is built, the parents must pass a gate
(build and their own tests). Old steps that #768 already covers are dropped or narrowed. After the
last step the tree is `develop`, plus upstream's two stand-alone tools. Later upstream changes
arrive through `git town sync --stack --detached --no-push`, with conflicts resolved by hand and
recorded.

## Technical Context

**Language/Version**: Python 3 (standard library only), as in feature 001's tool. Git, and Git
Town 24.0.0.

**Primary Dependencies**:

- `tools/series/` from feature 001, extended rather than copied (research R8);
- the isolated Objective-C MSYS2 (`.agent-tmp/msys2-objc`) for the Objective-C eras;
- Jon's MSYS2 for the C++ era.

**Storage**:

- the manifest, resolutions and descriptions under `specs/002-seriesb-rebase-stack/series/`
  ([data-model.md](data-model.md));
- branches and Git Town config in `oolite-dev`.

**Testing**:

- `python -I -m unittest discover -s tools/series/tests`: old tests unchanged, plus new tests for
  the profile;
- per step, feature 001's verification matrix (build Clang/GCC, unit, smoke, component where
  touched, format, warnings);
- `series.py --series seriesb check --verified`.

**Target Platform**: Windows x64 (MSYS2 UCRT64), as for feature 001.

**Project Type**: a branch stack, built and checked by a developer CLI.

**Performance Goals**: none beyond feature 001's. One verification pass per step.

**Constraints**:

- hard rules 1–9;
- no push;
- `develop`, `master` and `series/*` are left unchanged;
- the parents are never edited;
- Git Town runs only with `--detached --no-push` when an agent runs it;
- OXP content under `tools/js-parity/` is never read.

**Scale/Scope**:

- 2 parents and up to 26 replayed steps;
- an estimated 125 or more first-pass conflicts on #768, 88 of them in `src/Core/Scripting`
  ([research R4](research.md#r4-how-big-the-d1-step-is-the-spec-asked-the-plan-to-measure-it)), on
  top of feature 001's re-anchor estimate of 74 for `#780`. Many of these overlap.

## Constitution Check

`.specify/memory/constitution.md` is still the unfilled template. The gates applied are the agent
contract's hard rules (CLAUDE.md):

| Rule | How this plan meets it |
|---|---|
| 1 tests | Replays never edit a test to pass. The tool's `--show`/`--record` refuse `tests/` paths, as in feature 001. A conflict in a test file is resolved to one side, unchanged, and recorded. |
| 2 warnings | The verification matrix fails on new warnings. |
| 3 push / develop | No push. Agents sync with `--detached --no-push` (R2). The tool refuses `develop`/`master`/`main` and anything outside `seriesb/`. |
| 4 expansions | `tools/js-parity/oojs_probe.oxp` is carried as opaque paths and never opened. |
| 5 judging | Gates, checks and tests decide. The D1 size finding goes to Jon. |
| 6 GNUstep / `JS_*` | Allowed in parents and intermediate steps only (research R10). The final tree is `develop`. |
| 7 C | No C is rewritten. Replay only. |
| 8 waiting | Every open point has a default (Notes). A flagged gate defaults to "hold" and the session ends with that recorded, not with a question. |
| 9 paths | Scratch goes under `.agent-tmp/`. Game changes go only on `seriesb/*` branches. |

**Result**: pass. The post-design re-check is unchanged: the data model and contract add nothing
that touches a rule.

## Project Structure

### Documentation (this feature)

```text
specs/002-seriesb-rebase-stack/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R10
├── data-model.md         # the seriesb manifest
├── quickstart.md         # build, check, sync
├── contracts/
│   └── series-cli-seriesb.md
├── checklists/requirements.md
├── series/               # created by the tool: manifest.json, resolutions/, pr/, HANDOVER.md
└── tasks.md              # /speckit-tasks
```

### Source Code (repository root)

```text
tools/series/
├── series.py        # --series profile; parents, gate, drop, sync-record; cut --replay
├── profile.py       # new: the two profiles (prefix, dir, root, source types)
├── stack.py         # prefix/root from the profile; observed parents; refuse resets after sync
├── manifest.py      # rules 1–7 for seriesb; parents, dropped, additions, syncs
├── trees.py         # unchanged API; replay passes (old parent, new parent, old step)
├── renumber.py      # prefix from the profile
├── verify.py        # objc-quickjs era for parents; test-warnings path from the profile
└── tests/           # existing tests untouched; new test_profile.py, test_replay.py, test_sync_check.py
oolite-dev/          # branches only: seriesb/000a…, 000b…, 001…; remote hobleyd; Git Town keys
```

**Structure decision**: one tool with two profiles (research R8). Nothing changes in the game
sources outside the replayed trees.

## Phases and gates

- **G0, tooling**:
  - The profile and the new commands land.
  - Feature 001's tests and `check --verified` still pass.
  - The scratch-repo probe of R2 (observed parents, `sync --stack --detached --no-push`) behaves as
    research R2 says.
- **G1, parents**:
  - The parents are set up and mirror the PR heads.
  - Both gates are `pass`. Otherwise the work stops; see Notes.
- **G2, Objective-C-era replays** (old 001–010):
  - Built and verified in order.
  - Old 005 is dropped or narrowed (R4).
  - The R5 decisions are applied in the new 003.
- **G3, C++-era replays** (old 011–026): built and verified.
- **G4, finish**:
  - `check --verified` exits 0.
  - The handover is written.
  - `series/*` and `develop` have not moved.
  - Everything is committed in OoliteMigration. The `oolite-dev` branches are not pushed.

## Complexity Tracking

| Violation | Why needed | Simpler alternative rejected because |
|---|---|---|
| A second remote (`hobleyd`) in `oolite-dev` | Observed branches need a real tracking branch. The PRs live in hobleyd's fork. | `refs/pull/N/head` is not a branch, so Git Town can't track it (R2) |
| The end tree is not exactly `develop`: two retained upstream tools | Deleting upstream's own tools in a PR to upstream would be gratuitous, and they are not part of the game | Strict equality would make step 003 remove `tools/js-parity` and `tools/oxp-upgrade` (R5) |

## Notes (decisions and state that outlive the session)

- 2026-11-02:
  - **D1 finding for Jon**: on #768 the fork's façade is not smaller than old 003 + 005 (R4).
    Replaying 003→005 gives 124 conflicted files and about 364 files changed, against 370 files
    for the old 002→005.
  - The default stands: the end tree is `develop`. Adopting upstream's binding would mean
    re-porting the scripting layer through steps 006–018, which would need its own spec.
- 2026-11-02: the spec's D1 shape is amended. Old 003, 004 and 005 stay separate replayed steps
  (R4), not one collapsed step, because old 004 was cut on old 003's tree. The spec is updated.
- 2026-11-02: the spec's FR-007 is amended. `additions` (`tools/js-parity/**`,
  `tools/oxp-upgrade/**`) join `exclusions` as the allowed differences from `develop` (R5).
- 2026-11-02: the sync command for agents is `git town sync --stack --detached --no-push` (R2).
  Bare `--stack` would also sync `develop`.
- 2026-11-02: the planning session fetched the upstream PR heads into
  `refs/upstream-pr/{767,768,772}` in `oolite-dev`. These are local refs, not branches, and can be
  deleted once `hobleyd` is set up.
- 2026-11-02: the scratch Git Town probe was denied by the permission classifier in planning. It
  is task work under G0, in `.agent-tmp/`, with local bare repos and no network.
- Open, with the default taken: whether #768's QuickJS-ng patch and `oolite-quickjs-compat.js` are
  needed by `develop`'s engine. The default is to remove both in the new 003. A step test failure
  at G2 reverses this for the file involved, recorded with the evidence (R5).
- Open, with the default taken: if a gate is `flagged`, the default is to hold. G2 does not start,
  and the flag goes to the handover for Jon (FR-003a).
