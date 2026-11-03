# Implementation Plan: Rebuild the PR series on upstream's QuickJS PRs (`seriesb/*`)

**Branch**: `feature/phase4-polish` (OoliteMigration). Game branches are `seriesb/*` in `oolite-dev`.

**Date**: 2026-11-02

**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-seriesb-rebase-stack/spec.md`

## Summary

**Changed 2026-11-02 at Jon's direction (spec User Story 6, FR-014–FR-016):** the end state uses
upstream's QuickJS-ng binding converted to C++, not the fork's `ooscript` façade. Two new phases
follow the built stack:

- **G5, target:** port `develop` to that binding on `oolite-dev`'s
  `feature/upstream-quickjs-binding`. Jon merges it into `develop`.
- **G6, switch step:** a last seriesb step whose change is that port (`develop` → target). It ends
  the series on upstream's binding.

Research R11–R12 have the measurements and the choice of series shape. Everything below this
paragraph is the plan as built up to step 24.

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
- **G5, target (User Story 6)**: on `feature/upstream-quickjs-binding`, `develop`'s scripting
  layer is replaced by #768's binding converted to C++.
  - Callers and tests move to upstream's API.
  - All suites pass with Clang and GCC.
  - `git grep ooscript -- src tests` is empty.
  - The test-change ledger (`specs/002-seriesb-rebase-stack/series/test-changes.md`) lists every
    changed test.
- **G6, switch step**: seriesb step 025 (source: the target branch) takes the target's tree. The
  final tree equals the target, and the step is verified.
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

- **2026-11-02, Jon: adopt upstream's QuickJS-ng binding; drop the fork's interface.** Tests may move
  to upstream's engine API (FR-015). Hard rule 6 is amended in `CLAUDE.md` (FR-016). The
  verification of steps 3–24 was stopped after step 8 passed: those steps stay as built, but the
  series now ends with the switch step.
- T039/T040 (2026-11-03): the 38 class bindings were ported by four parallel groups (branches
  `feature/upstream-quickjs-binding-a`…`-d`) and merged into `feature/upstream-quickjs-binding`
  (`cbf075918`).
  - Merge conflicts in shared headers took the owning group's port (C: Vector, Quaternion,
    ConstToJSString; D: EquipmentInfo; A: OOJSShip).
  - After the merge, all 50 scripting objects compile with no warnings, except four calls in
    `OOJSGlobal`/`OOJSMission` to `GuiDisplayGen::textureDescriptorFromJSValue`, which is T042's.
  - **Temporary code** (removed in T042): file-local `WeakSelfValue`/`WeakSelfStorage` in
    `OOJSEquipmentInfo.cpp`, until `OOEquipmentType::_jsSelf` is a `JSValue`. `getJSClass()` stays
    beside group A's new `Entity::jsClassID()` until T042 removes it.
  - The groups report that the game objects build at `-Wall`, not `-Wextra`. That is the build's
    existing setup, checked at T045.
- T038 (2026-11-03): the engine core is ported on `feature/upstream-quickjs-binding` (`34fc9465c`; #768's
  compat script in `c39eb267d`). No `ooscript` remains in it, and its 9 objects compile with no
  warnings (rebuilt by the orchestrator). Decisions, all following #768:
  - `OOJSPrivateObject` is kept, reduced to the C++ stand-in for #768's NSObject category;
  - the time limiter is QuickJS's interrupt handler, and the watchdog thread is gone;
  - errors are logged from the exception's stack, with location lines on by default;
  - the monitor receives severity, file and line;
  - the script cache has a new name, so old caches are not reused;
  - #768's QuickJS-ng patch is not applied (the core warns without it; T044 decides).
  The binding API is in T039/T040's briefs. `OOJavaScriptEngine` lost `removeGC*Root` and
  `objectClass()` etc. (T042).
- Estimate (2026-11-02, corrected): 4–7 days to a final seriesb step passing on upstream's binding, or
  about 3 with binding files ported in parallel. The precedent is old steps 003–005 (the façade and
  all ~3,800 call sites moved onto it), which took 3.5 days in the history (2026-09-19 → 09-22). The
  ownership switch is the main risk. An earlier figure of 2–3 weeks was too high.
- T037 (2026-11-02): `series/facade-map.md` maps all 362 public names of `ooscript/JSEngine.hpp`
  (`python -I tools/series/facade_map_check.py` exits 0). 152 have no counterpart in #768. Defaults
  for T038–T040 all follow #768's own design (Jon chose it):
  - **ownership**: the façade's arena, which emulates SpiderMonkey's GC, goes. Every call site takes
    #768's explicit `JS_FreeValue` ownership, so each binding is re-read, not rewritten mechanically;
  - **rooting, requests, versions and GC tuning** have no counterpart and are dropped with their
    callers;
  - **class hooks**: resolve and enumerate become #768's per-class `JSClassExoticMethods`
    (`Manifest`, `MissionVariables`, `SystemInfo`), and `convert` becomes a `toString` method;
  - **script scope**: #768's `with(this){(function(){…})}` wrapper. Its bytecode-only script cache
    replaces the façade's format, so caches made before the change are not reused;
  - **reset**: `clearScope` gives way to #768's free-the-context-and-notify-holders reset;
  - **strings** cross the engine boundary as UTF-8, as in #768, so every `Char16` user changes.
- T036 (2026-11-02): `feature/upstream-quickjs-binding` created at `develop` (`3aa8d65e8`), with its worktree
  at `.agent-tmp/upstream-binding-wt`. Its baseline `./mk.sh build test` (C++ shell) passes: 1,026 build
  steps, 0 warnings. `tools/deny-list.txt`, which `ooscript/JSEngine.hpp`'s comment says bans the `JS_`
  prefix, does not exist, so nothing in code enforces the old rule 6.
- **Series shape (default, research R12):** the built steps 3–24 keep the fork's façade, and a
  final step switches to the converted upstream binding.
  - Why: `src/Core/Scripting` is edited by 23 of the 26 old steps, 50–100 files each in about 15 of
    them. Carrying #768's binding through every step means re-porting all those edits onto #768's
    files by hand.
  - Cost: reviewers see #768's binding replaced at step 3 and brought back, converted, at step 25.
  - The rejected alternative carries the binding through every step. It is reviewable as one story
    but has that porting cost, and it is a follow-up Jon can ask for once the target exists. Its
    end tree is the same target, so G5 is needed either way.

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
- T002 (2026-11-02): G0's Git Town probe passes (`.agent-tmp/seriesb-gt-probe.sh`). It found two
  things, both now in research R2 and the tasks:
  1. Git Town only observes a branch whose `<remote>/<local name>` exists, so `hobleyd`'s refspecs
     map each PR branch onto its seriesb name.
  2. Sync fetches only `origin`, and a force-pushed PR branch makes the observed rebase replay
     upstream's dropped commits. So `parents --refresh` (fetch `hobleyd`, then `update-ref` each
     parent to its tracking ref) runs before every sync.
- T017 (2026-11-02): **old 003–005 fold into one step 003**, which is old 005's tree plus
  `tools/js-parity/**` and `tools/oxp-upgrade/**`.
  - Why: replaying old 003 alone reverts #768's removal of SpiderMonkey, and #780's engine-neutral
    names (dropped by `develop` when it merged #780) would not compile against the façade.
  - The spec's D1, research R4 and the data model are amended.
  - The rejected alternative replays old 004 (the Objective-C++ rename) onto #768 first: a separate
    rename step, but new, unverified resolutions in #768's binding and meson files. Jon can ask for
    it.
- Found at the step 2 verification (2026-11-02): component scenario `s1_police_kills_pirate` is
  **intermittent**.
  - Over 5 runs on the old `series/002-safety-net` (SpiderMonkey), 1 fails, at the 900-tick
    timeout. On seriesb step 2 (#768, QuickJS-ng), 2 of 5 runs fail.
  - When it passes, the police engage the pirate within about 5 s. When it fails, they never do in
    112 s.
  - It is not from #768, and the test is not changed (hard rule 1).
  - Default: seriesb verification retries a failed component run up to twice and records the
    failed attempts. The scenario's reliability is for Jon (a candidate fix belongs in the safety
    net, not here).
- T011 (2026-11-02), gate G1 passes for both parents, in the isolated MSYS2
  (`.agent-tmp/msys2-objc`), with logs in `.agent-tmp/seriesb-verify/gate-*.log`.
  - `000a` (#767): its CI's Windows matrix, `./mk.sh build deployment` and `./mk.sh test deployment`
    with `-Djs_engine=spidermonkey` and `-Djs_engine=quickjs`. Both builds pass (245 and 259 steps),
    and both launch snapshots pass the quality check. `./mk.sh build test` passes.
  - `000b` (#768): `./mk.sh build deployment`, `./mk.sh test deployment` (snapshot passed) and
    `./mk.sh build test` all pass.
  - T012 (fix parent) does not apply.
  - Found for T023: #768's own build has 6 warnings that the old series' QuickJS-era steps did not
    have. Four come from the vendored `subprojects/quickjs-ng/quickjs.c`, at lines 5009–5024
    (`-Wpedantic`: a void function returns a void expression). Two are the clang driver's unused
    `-pthread`. Every step built on #768 inherits them until a step replaces that QuickJS-ng (old
    step 024 upgrades it).
  - Default, recorded here and applied in verification: a step's warnings check counts only
    warnings that its parent's build does not have. The parent's are listed, never silenced (hard
    rule 2), and a warning the step adds still fails it.
- T009 (2026-11-02): parents set up in `oolite-dev`: `000a` = `3758f8a09`, `000b` = `db4920103` (unchanged
  since the baseline), observed, under `develop`. The remote `hobleyd` has `pushurl no-push`. The planning
  refs `refs/upstream-pr/*` are deleted.
- T001: `series/baseline.json` records 27 `series/*` branches, `develop`, `master`, the PR heads
  (`3758f8a09`, `db4920103`) and upstream `master` (`7437f22a5`).
- Open, with the default taken: whether #768's QuickJS-ng patch and `oolite-quickjs-compat.js` are
  needed by `develop`'s engine. The default is to remove both in the new 003. A step test failure
  at G2 reverses this for the file involved, recorded with the evidence (R5).
- Open, with the default taken: if a gate is `flagged`, the default is to hold. G2 does not start,
  and the flag goes to the handover for Jon (FR-003a).
