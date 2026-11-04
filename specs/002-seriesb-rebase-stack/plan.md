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

- `python -I -m unittest discover -s tools/series/tests -t .`: old tests unchanged, plus new tests for
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
- **2026-11-03, Jon: keep the façade in steps 3–24.** Step 003 restores the fork's `ooscript` façade
  so steps 4–24 replay as built and tested; step 025 alone moves to #768's binding. Porting each of
  steps 3–24 to #768's API instead was rejected (same final tree, far more work and churn).
  **Reversed by Jon later on 2026-11-03** (spec User Story 7, FR-017): reviewers should never see
  the façade. Steps 3–24 are rebuilt on #768's binding, `poc/` is carried and converted to C++,
  and step 025 is dropped or shrinks to what is left. The old heads are kept as local tags
  `archive/seriesb-facade/NNN` (`000b` and `001`–`025`). Branches are updated in place, so Jon
  force-pushes them. Tasks T049–T057.
- **2026-11-03, Jon: bring in upstream's newly merged PR.** Upstream `master` moved to `28ceaaba0`,
  merging #783 (`joystick_gui`: joystick control of GUI screens, and fixes to the joystick
  configuration screen). #767/#768 did not move. #783 changes eight Objective-C files that the
  stack converts to C++, so it is ported into the C++ code with its behaviour kept, on the
  end-target branch (T051a). In the stack it joins step 023, which already carries the upstream
  `master` changes that are not in #767/#768. *Default taken*: extend step 023 instead of adding a
  step 024a, because a new step would renumber 024–025 and step 023 is the stack's place for
  "ports of upstream master".
- **2026-11-03, clang-format.** CI pins clang-format 22. This machine has 23.1.4, which disagrees
  with 22 only on wrapped enum initialisers (4 untouched files). New code in Phase 11 is formatted
  with 23 and checked for that construct; the CI format check is the authority.
- **Behaviour changes that follow #768, for Jon to confirm** (found while porting and moving tests,
  2026-11-03). Tests expecting the old behaviour are updated, and each update is in the test ledger:
  - **Manifest**: assigning an invalid value to a manifest entry, or deleting one, now throws
    (`Cannot set property food of instance of Manifest to invalid value x.`). Before, the error was
    reported and the assignment ignored. This matches #768's `OOJSManifest.m` (group D).
  - **Class tags**: `Object.prototype.toString.call(<game object>)` now gives `[object Object]`, not
    e.g. `[object Vector3D]`. The façade tagged class prototypes with `Symbol.toStringTag`; #768 does
    not. Scripts that test those strings would change behaviour. T045's parity probe measures it.
  - **Native results**: `effect.scale(2)` returns `undefined` (#768's `JS_UNDEFINED`, where
    SpiderMonkey left the function in the result slot). A native called on the wrong `this` throws
    where it returned `undefined` (Station's `launchMiner`).
  - **Time limiter**: `SoundFromJSValue` now resumes the limiter it pauses (#768's own fix).
  - **Read-only properties throw in strict code**: #768 defines them with `OOJS_PROPERTY_RO` (no
    setter), so a strict-mode write to e.g. `wormhole.origin` or `timer.isRunning` throws a
    TypeError; SpiderMonkey ignored it.
  - **SystemInfo enumeration**: #768 hides the four fixed properties (coordinates,
    internalCoordinates, galaxyID, systemID) from `Object.keys()` and for..in, which list only the
    system data keys. **The fork adds a `has_property` hook** (`73a7aa796`): QuickJS-ng 0.17's for..in
    drops every key `JS_HasProperty()` denies, so with #768's hooks for..in listed nothing, on #768
    itself too (same hook, same QuickJS-ng). With the hook, `'economy' in info` is `true`, where
    SpiderMonkey gave `false`; `hasOwnProperty()` stays `false`. Default taken: for..in working (the
    test asserts it, and #768's comment intends it) outweighs `in` matching SpiderMonkey, since no
    hook can give both without patching QuickJS-ng. Worth reporting to #768.
  - **Exceptions from a `filteredEntities` predicate** are reported and stop the script
    (`OOJSNativeFailure`, #768's comment says so), so the script's own `catch` no longer sees them.
  - **Timer** reads the callback's `name` once, in its constructor, and caches it.
  - **`isExecutableJavaScript('1 +')`** is `false`: #768's `IsIncompleteSyntaxError()` treats
    incomplete input as not executable, as SpiderMonkey's `JS_BufferIsCompilableUnit()` did.
  - **`setExtraGuiScreenKeys` bad-argument messages** give the count of the definition's arguments
    (`MIN(argc - 1, 2)`), and **`quitGame()`** is deferred until the script returns.
  - **Debug monitor**: the strict-mode exception text is now `Exception: …` (no `(strict mode)`), and
    the non-exception error message class is gone; the monitor API has only warning and exception.
    `OOJSConsoleDestroy()` is gone.
  - **Stack dumps** use #768's `OOJSDumpStack` frame format, and the stack-skip flag affects only the
    error handler, not the dump.
  - Removed as façade-only: `test_jsengine_quickjs.cpp` (the façade's own backend test), named-root
    and request checks. The full list, per test, is in `series/test-changes.md`.
- T042 GCC (2026-11-03): `./mk.sh build test --native-file=gcc.ini` fails on `develop` itself
  (`3aa8d65e8`, GCC 16.2 with LTO): `test_OOCacheManager` and `test_OOJoystickManager` do not link
  (undefined `oo::EntityDescription`, pulled in by an inline in `EntityPListForeign.h`), and it prints
  49 warning lines (ODR and LTO type mismatches from test stand-ins of `OOJavaScriptEngine`/`OOJSScript`,
  libstdc++ `-Waggressive-loop-optimizations`, `OOMatrix.h` `-Wnonnull-compare`). The binding branch
  fails the same two links and prints 24 warning lines of the same kinds; the one extra
  `aggressive-loop` line is the new `test_OOJSTimeLimiter`, which links the whole game. Default taken:
  T042 is accepted as "no worse than `develop` with GCC"; the GCC unit run waits on the pre-existing
  link failures, which are a separate fix (not this feature's).
- T044 (2026-11-03): #768's non-source parts, on `feature/upstream-quickjs-binding` (`fb47a9c26`).
  - `Resources/Scripts/oolite-quickjs-compat.js`: identical to #768's (came with the core, `c39eb267d`).
  - `tools/js-parity/**` and `tools/oxp-upgrade/**`: taken whole from #768's branch by path, not
    opened (the probe is an OXP, hard rule 4).
  - `logcontrol.plist`: #768's two classes, `script.javaScript.cache` and `script.javaScript.load.modern`;
    the ported `OOJSScript.cpp` logs under both.
  - **Not applied**: #768's `0001-oolite-primitive-property-assignment.patch` (strict-mode `"s".foo = 1`
    is silently ignored instead of throwing). Research R5's default: the tests pass without it, and
    `develop` (also QuickJS-ng 0.17) has never had it. T045's parity probe will show whether it
    matters; adopting it is one line in the wrap.
  - Left as the fork has them: CI workflows, install scripts, `meson.options`, README (#768's
    SpiderMonkey removals there do not apply; the fork never had SpiderMonkey's build).
- T045 (2026-11-03): `feature/upstream-quickjs-binding` at `fb47a9c26`, in the MSYS2 UCRT64 shell
  (Git Bash cannot run `get_version.sh`): `./mk.sh build test` with Clang exit 0, 0 warnings;
  `tests/run.sh unit` 0 failures (oofnd 40, core 175, headers 1); `smoke` pass; `component` 19
  passed; `gui` 178 passed. GCC: see the T042 GCC note (no worse than `develop`; its unit run waits
  on `develop`'s two link failures).
  - **js-parity not run.** `tools/js-parity/run_probe.sh` needs Linux (`xvfb-run`, `xdotool`, Mesa
    llvmpipe), and `develop` has no copy of the tool. Default taken: the parity comparison
    (`develop` vs the branch, then the SpiderMonkey baselines) waits for the Linux phase; writing a
    Windows runner is new tooling outside this feature. So whether the unapplied primitive-property
    patch (T044) matters is still open; nothing in the four suites shows it.
  - Then `531ddd659` formats the 70 ported `src/` files with clang-format 22.1.8 (step 025's
    `clang_format` gate failed on them; formatting only, 392+/405-). Step 025's verify rebuilds
    and reruns unit and smoke on it; component and GUI ran on `fb47a9c26`.
  - Branch tip for T046: `531ddd659` (full id in `series/manifest.json`, `anchors.develop_target`).
- T043 (2026-11-03): the unit tests moved by five parallel groups (branches `…-t1`…`-t5`), merged
  `86e33d549`..`c977f6058`; `tests/unit/core/meson.build` conflicts were resolved line by line (each
  group's own tests). Ledger: `series/test-changes.md`. `git grep ooscript` is empty;
  `./mk.sh build test` with Clang: 0 warnings; `tests/run.sh unit`: oofnd 40, core 175, headers 1,
  all pass.
- T042 (2026-11-03): the 50 files outside the scripting layer were ported in two parts, E (debug console
  and monitor, Universe, GuiDisplayGen, string and constant utilities) and F (the entities,
  OOEquipmentType, OOShipGroup), then merged (`49aad3e87`).
  - Group D's temporary EquipmentInfo bridge is gone, and `getJSClass()` is replaced everywhere by
    `jsClassID()`, as in #768.
  - Two use-after-free hazards under explicit ownership were fixed as upstream fixes them: the
    ship-killed event reused a freed value, and the ECM blast shared argument values across
    targets.
  - Removed as #768 removes them: the console's `dumpNamedRoots` and `OOJSConsoleDestroy`, and
    Universe's GC-byte logging. `pedanticMode` is now a flag with no effect.
  - Kept from the fork: the jump cause is passed as `""` when nil (upstream passes null), and the
    console holds the monitor strongly.
- T041 (2026-11-03): `src/Core/Scripting/ooscript/` is removed, with its meson entry (`8fe16dcc6`). `git grep
  ooscript -- src` is empty. The unit tests' meson file still links the deleted backend (T043), so
  the game alone is checked with a deployment build, which leaves the core unit tests out.
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
- T035 (2026-11-03): gate G4 passes on the 25-step stack: the tool suite (189 tests), the old
  series' `check --verified`, `$S check --verified`, `--only baseline`, `--only messages`, a clean
  `oolite-dev`, and everything committed here. Open: T045's js-parity run (Linux) and T046 (Jon).
- T034 (2026-11-03): quickstart sections 0–3 run as written on the 25-step stack (section 4 n/a, T030).
  Two corrections: `unittest discover` needs `-t .` under `-I` (the repo root is not on `sys.path`),
  and `describe --handover` must come before `check --verified`, since any verify dates the handover.
- T030 (2026-11-03): n/a: no upstream change since T009 (`$S parents` after `git fetch hobleyd`:
  PR #767 head `3758f8a09b`, PR #768 head `db49201034`, both equal to the parents' tips). The sync
  procedure stays covered by T026's fixture test.
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
- **Phase 11 state (2026-11-03).** End target: `feature/upstream-quickjs-poc-cxx` (`6fe168427` =
  binding branch + C++ `poc/`), worktree `.agent-tmp/poc-cxx-wt`; #783's port (T051a) lands there
  next. New step 003 is being assembled in `.agent-tmp/seriesb-nofacade-wt` (detached at
  `archive/seriesb-facade/002`, uncommitted) by `.agent-tmp/step3/build_tree.sh` (old 003 path by
  path; Scripting and `poc/` from 002 renamed `.mm`), then `apply_nonfacade_hunks.py` (old 003's
  hunks on the 35 façade users that neither add façade code nor remove #768 API code) and
  `rename_this.py` (`this` → `thisObj` in #768's code, as the C++ end state names it). It keeps
  #768's QuickJS-ng 0.17.0 wrap and patch, `oolite-quickjs-compat.js` and `poc/`, which reverses
  the earlier default above for those files. Steps 004–024 replay by `git cherry-pick -x
  archive/seriesb-facade/NNN` onto the rebuilt parent.
- **Upstream #783 oddity, for Jon (2026-11-03).** Upstream's `clearMappings` resets `axismap` and
  `buttonmap` but not the new `guibuttonmap`, which therefore starts all zero, and 0 is
  `BUTTON_INCTHRUST`. At run time every unassigned joystick button also drives increase-thrust, and
  a save writes `"0": {stick 3, button 79}` into `GuiJoystickButs`, which the next load assigns to
  increase-thrust, unbinding the player's own increase-thrust button. The faithful port
  (`765619143`, T051a) therefore fails the existing test `savesAndLoadsSettings` in
  `test_OOJoystickManager`; the test is unchanged (hard rule 1). **Jon, 2026-11-03: fix it in the
  port.** `2042fac85` resets `guibuttonmap` in `clearMappings` with the other two tables, a
  deliberate deviation from upstream that step 023's description must name (and suggest upstream
  take). The new #783 tests pin the fixed behaviour; all 216 suites pass.
- **New step 003 built (2026-11-03): `51a1ac527` on `seriesb/003-quickjs-switch`** (slug rename to
  `003-objective-cxx` waits for the manifest update, T052). 288 files, +2110/−1622 against 002
  (old 003: 407 files, about +34k/−25k). Build rc=0 with exactly 002's 7 warnings (QuickJS-ng's own
  `-Wpedantic` and `-pthread`), smoke passes, no façade, no test changed. *Default taken, against
  the earlier "keep the rest of old 003" rule*: old 003 also reverted #768 outside the façade
  (dropped `OOJSFreeValue` calls, SpiderMonkey's macOS build script and patch, Mozilla CI steps,
  `XP_*` defines, polyfills in `oolite-global-prefix.js`, its own QuickJS LTO and clock changes).
  Those files keep 002's content; `.agent-tmp/step3/find_reverts.py` finds such hunks (002→old step
  hunks that undo #768's changes since `7437f22a5`) and `step3/reverts.txt` lists them. The end
  target has none of the SpiderMonkey files, so later steps' deletions of them become no-ops; any
  remaining `develop`-only difference surfaces at T055's final-tree check and is placed then.
  Replays of 004–024 run `find_reverts.py` on each step for the same reason.
- **Step 004 replayed (2026-11-03): `6f1c77819` on `seriesb/004-oofnd-core`**, on new 003
  (`51a1ac527`). 7 conflicts; façade-only work (the watchdog thread, `MOZ_TRACE_JSCALLS` callbacks,
  `ConsoleDumpNamedRoots`, the façade `OOJSDumpStack`) dropped as having no purpose on #768; the
  step's Foundation changes (`@autoreleasepool`, `OOJSCall` signature matching) redone on #768's
  code. No ledger rows. Build rc=0 (only the parent's `-pthread` warning), oofnd 20/20, smoke
  passes with no leaked JS objects. Open with Jon: whether to trim step 003 to renames, the
  Objective-C++ switch and the fixes it requires, dropping hunks that take upstream code back to
  the fork's older form (the joystick managers: 002 equals upstream with #742/#748/#749, and old
  step 018 ports them forward again). If trimmed, 004 is redone on the trimmed 003 (rerere keeps
  its resolutions).
- **Jon, 2026-11-03: keep recent upstream PRs in every step.** No step may take code that upstream
  changed in `dc55e3e05..7437f22a5` (#369–#765, #766, #774, #780, #781: everything between the
  fork's branch point and #767/#768's base, all already in 002) back to the fork's older form. A
  replayed hunk that does so is dropped, or, where the step must change that code (Objective-C++,
  Foundation → oofnd, C++), the change is made on upstream's version. Tests are added where a kept
  upstream change has none, at the first step whose test suites can reach the code. Old steps 018
  and 023 then shrink to whatever port is still needed. Step 003 is trimmed first, then 004 is redone
  on it.
- **Step 003 trimmed, 004 redone (2026-11-03).** 003 = `de8858b2c` (284 files, +1672/−1304 vs
  002), 004 = `494a1a4c4`, both on their branches; gates pass (build rc=0 with 002's 7 warnings;
  oofnd 20/20 at 004; smoke; no façade; tests unchanged). 775 hunks classified in
  `.agent-tmp/step3/trim-classification.md`: 729 required by Objective-C++ (kept, each made on
  upstream's code); 29 reverted upstream (#742/#748/#749 joystick layout, #780
  `playerWillSaveGame` via `doScriptEvent:`), restored to 002; 17 neither (post_build's `ldd`
  closure, anonymous-namespace wrapping, split `if ((self = [super init]))`, `static`), dropped as
  not needed for the build. History ids are dropped from comments step 003 adds.
  `.agent-tmp/step3/trim/find_reverts5.py` detects lines a hunk adds that the range removed (ignoring
  #749's reformat); it finds none in new 003 or 004.
- **The end target reverts recent upstream PRs too (found 2026-11-03).** `feature/upstream-quickjs-
  poc-cxx` (from `develop`) still has the fork's pre-#742 joystick layout and calls
  `ShipScriptEventNoCx` where #780 calls `doScriptEvent:OOJSID("playerWillSaveGame")`. Under Jon's
  rule the end target must take upstream's forms first (T051b), or the last step would have to
  revert them to match it.
- **T051b audit and ports (2026-11-03)** (`.agent-tmp/t051b/audit.md`). Of the range's 19 PRs, 16
  need nothing in the end target (present, ported in 018/023, net zero, or a deliberate fork form:
  Google style for #749/#751; #766's macOS parts deferred to the macOS port; SpiderMonkey items
  excluded by hard rule 6). Ported with new tests: #780 (`3978a13b4`: `playerWillSaveGame`,
  `playerJumpFailed`, `alertConditionChanged`, `entityDestroyed` through `doScriptEvent`; pinned by
  `test_EntityScriptEvents.cpp`, 8 cases) and #748's `OOOpenGLOnly.h` (`8fb30e6ee`, pinned by
  `test_OOOpenGLOnly.cpp`). Gates at `8fb30e6ee`: clang build 0 warnings, 218 suites Ok, harness Ok.
  Stopped (hard rule 1), for Jon: #742 (decoding in `OOSDLJoystickManager`; existing
  `test_OOJoystickManager`/`test_OOSDLJoystickManager` call the base-class decoders and `Joy*Event`
  types) and #748's maths headers (upstream's do not compile standalone, so the `headers` suite
  fails). GCC: two core tests fail to link under LTO (`oo::EntityDescription`) already at
  `2042fac85`; pre-existing, its own task.
- **Jon, 2026-11-03, on T051b's two stops.** (1) #742: take upstream's layout (decoding in
  `OOSDLJoystickManager` on SDL event types, #783's GUI-button decode with it); the decode cases of
  `test_OOJoystickManager.cpp`/`test_OOSDLJoystickManager.cpp` move to `OOSDLJoystickManager` and SDL
  events, keeping what they assert, each listed in `series/test-changes.md` under "## End target
  (T051b)" (an exception to hard rule 1 like FR-015). (2) #748's maths headers: upstream's form, with
  `OOMaths.h`'s scalar/macro part split into its own header that each maths header includes, so every
  header compiles standalone and the `headers` suite passes unchanged.
- **Jon, 2026-11-03: force-push the rebuilt branches.** The handover (T057) gives
  `git push --force-with-lease origin <branch>` for each rebuilt `seriesb/*` step, keeping the
  existing names. Jon noted that adding commits on top would also have been acceptable to him; the
  rebuild stays history-clean (no façade commit reachable from any step) as FR-017 asks.
- **End target final (2026-11-03): `feature/upstream-quickjs-poc-cxx` at `21c8c1df0`**, now
  `anchors.develop_target`. #742 (`4f1896f10`: SDL decoding in `OOSDLJoystickManager` on SDL event
  types, #783's GUI decode with it; 8 test cases moved, ledgered under "## End target (T051b)",
  `bca7f1b95`; new `test_OOJoystickDecoding.cpp`) and #748's maths headers (`21c8c1df0`: upstream's
  form, shared part split into `OOMathsBase.h`; new `test_OOMathsHeaders.cpp`). Clang: 0 warnings,
  220 suites Ok, harness Ok. Audit: no recent upstream PR left in older form.
- **Steps 005–006 replayed (2026-11-03).** 005 = `fdea6440f` (21 conflicts; oofnd 28/28), 006 =
  `ab8b54991` (65 files, ~380 conflict blocks, re-expressed by hand on #768's code; oofnd 33/33,
  all 8 component scenarios). Both: clean build with exactly 002's 7 warnings, smoke with no leaked
  JS objects, no façade, tests equal to the old steps' (bar the ledgered façade test), no
  unexplained revert. Kept upstream #742's joystick layout through both (so `OOJoystickManager`'s
  ivars stay non-`@private`: the SDL subclass decodes through them). 005 also posts the engine's
  reset notification from `-shutDown` on `oo::NotificationCenter`, which the old step did not need:
  `OOJSValue`/`OOJSTimer` observe that centre and would otherwise leak at shutdown. 006 found that
  git's auto-merge silently deleted #768 code in heavily conflicted files (matching banner lines);
  those files were rebuilt from #768's version with the old hunks re-applied, and
  `.agent-tmp/step6/mismerge.py` checks clean merges for unexpected removals — use it on every
  later replay.
- **Steps 007–008 replayed (2026-11-03).** 007 = `405db782b` (79 conflicted files, 243 blocks), 008 =
  `f381fd0c7` (75 files, 498 blocks; the 11 bridges #768's code still used deleted as the old step does),
  both re-expressed on #768's code by parallel agents with the 006 brief. Both: clean build with only
  QuickJS-ng's 4 `-Wpedantic` warnings, oofnd 39/39 then 44/44, game-unit 1/1 (007), smoke with no leaked
  JS objects, all 8 component scenarios, no façade, tests equal to the old steps' except 007's expander
  stubs (ledger). Defaults taken: (1) 007's QuickJS-ng `-O2` pin goes into the options of #768's
  `dependency('quickjs-ng')` (measured: 10 TUs at `-O2` with NDEBUG), not into a wrap patch, since the
  wrap is #768's; (2) 007 also sets the Windows `threads` override the old stack had, because the old
  step's new `game_test_defaults_bridge` link added a fourth unused `-pthread` warning; with it the
  parent's three go too, so from 007 the build prints 4 warnings, not 7; (3) #768 code the old steps
  never saw is moved the same way (reset observers to `oo::NotificationCenter` in 007; `quitGame()` via
  `OOScheduleDeferredCall`; the script cache, class registry and console syntax check off the deleted
  bridges in 008); (4) the unregistered expander test's stub declares the NSString
  `OOJSReportWarningWithArguments` while 008's expander calls the `cxx_` form, as in the old step 008
  itself (tests unchanged from the old step; the test is not built).
- **Open, default taken: the harness's `meson.build` in steps 005–009.** From 005 the engine header
  imports `oofnd/objc/OOObject.h`, but #767's `poc/meson.build` lacks `src/` on its include path and
  the oofnd dependencies, so it probably no longer builds on Linux. It cannot be built here (it needs
  GNUstep, Linux only), so it is left unchanged until the step that converts the harness (the first
  C++ step), which gives it the end target's build file; recorded for the Linux phase.
- **Jon, 2026-11-03: take #768's QuickJS-ng patch** (reverses the earlier "Not applied" default
  above). The end target logged `script.javaScript.init.unpatchedEngine` on every launch because it
  kept #768's start-up check but not the patch. `fce807b50` adds
  `packagefiles/quickjs-ng/0001-oolite-primitive-property-assignment.patch` (unchanged, #768's path)
  to the wrap after the fork's `o2` and `void-return` patches, and a new harness script
  `poc/tests/primitive_property.js` with two checks in `poc/main.cpp` (they fail without the patch
  with "TypeError: not an object"). Gates: build 0 warnings, 220 suites Ok, harness 23/23, smoke with
  no warning. `anchors.develop_target` = `fce807b50`. Replays of old step 022 (QuickJS-ng upgrade)
  must keep the patch.
- **Step 009 replayed (2026-11-03): `dbb0c371c` on `seriesb/009-leaf-conversions`**, on 008
  (`f381fd0c7`). 60 conflicted files (~370 blocks), re-expressed on #768's code by nine parallel
  agents (`.agent-tmp/step9/brief.md`); the worst (OOJSVector, OOJSQuaternion, OOJSFunction, OOJSTimer,
  OOJSScript, OOJSConsole) rebuilt from 008 with the old hunks re-applied. Clean build (isolated
  Objective-C MSYS2) rc=0 with only QuickJS-ng's 4 `-Wpedantic` warnings; oofnd 46/46, core 55/55;
  smoke with no leaked JS objects; 8/8 component scenarios (s4 failed once on its ambient-population
  precondition, passed on retry); no façade; tests equal to old 009's except the 13 ledgered under
  "## Step 009" in `series/test-changes.md`. Defaults taken:
  1. #768's native-wrapper macros stay in `OOJavaScriptEngine.h` (with #768's names) and get the old
     step's C++ try/catch and scope-guard form there; `OOJSEngineNativeWrappers.h` stays #768's.
  2. **For Jon:** the old step's Vector3D/Quaternion conversion statistics (`OO_DEBUG` only,
     `PS.callObjC("reportJSVectorStatistics")`) are kept though #768 removed them, because the old
     step's new `core` tests assert them (hard rule 1) and the end target has them. Under the
     "keep #768" rule they would go; that needs the tests' `statistics` cases dropped, which only Jon
     can sign off.
  3. The new `test_OOProfilingStopwatch` asserts a reversed delta is negative; #768's Windows
     `timeGetTime` path subtracted unsigned `DWORD`s. Fixed on #768's code (signed 32-bit difference)
     rather than restoring the fork's steady-clock branch #768 removed. The end target still has that
     branch; T055's final-tree check will show the difference.
  4. #768 code using Foundation that the old step never saw moves off it as the end target does
     (`NSCAssert` -> `OOCAssert`, `OOJSWrapScriptSource`/`OOJSClassNameOfValue` -> `std::string`,
     SystemInfo's null-assigned set, Universe/Player jump-cause and alert-condition events, the
     GuiDisplayGen String-object test by class id).
  5. OOSDLJoystickManager converts to `cxx::` on #742's layout; the three SDL decoders stay
     Objective-C in a category, since they use OOJoystickManager's ivars.
  6. **Harness:** moved off GNUstep in this step (Foundation-free Objective-C++ on oofnd, the game's
     QuickJS-ng; #767's `-Wincomplete-implementation` pragma removed, the unused engine methods are
     no-ops instead). It builds and runs on Windows: 20 checks, 0 failures; the "Linux only" error is
     gone. This closes the "harness's meson.build in steps 005–009" item above.
- **Step 009 replayed (2026-11-03): `dbb0c371c`** (outer `494fe6878`, 13 ledger rows). gnustep-base
  out; first C++ conversions; `core` suite arrives (55/55); oofnd 46/46; component 8/8; smoke clean.
  #767's harness is off GNUstep here and builds and passes (20/20) on Windows, so the `poc` verify
  check runs from 009 on. *Default taken*: the new harness script `primitive_property.js` and its
  two checks (end target `fce807b50`) join the stack at 009, the first step whose harness can run
  them; until then the file is absent (adding a test is not a change to an existing one).
  *Default taken*: `OOProfilingStopwatch` keeps #768's `timeGetTime` path in 009, fixed to a signed
  difference so the step's new test (a reversed delta is negative) passes; the end target's
  steady-clock branch is the fork's own improvement, not an upstream revert, and is taken at the
  step that converts the stopwatch to C++ (T055's final-tree check confirms).
- **Jon, 2026-11-03: remove the Vector3D/Quaternion conversion statistics, as #768 did.** They go
  from the end target and from step 009 on (009 gets a follow-up commit). The test cases that assert
  them are removed, each listed in `series/test-changes.md` (end target under "## End target
  (T051b)", step 009 under "## Step 009"), an exception to hard rule 1 Jon signed off with this
  decision.
- **Statistics removed (2026-11-04).** End target `655583067` (also drops `OOJSCall`'s
  statistics-only `kPlayerMethods` table; build 0 warnings, 220 Ok, harness 23/23, smoke clean) =
  `anchors.develop_target`. Step 009 gains `ee0a23aca` (statistics out; the two `+ObjCBridge`
  files that held only their `PlayerEntity` categories deleted) and `1912db791` (the
  primitive-property harness test, 23/23); oofnd 46 + core 55 Ok, smoke clean. Ledger `10e88e853`.
  Tip of 009 = `1912db791`.
- **Jon, 2026-11-04: step 003's branch is `seriesb/003-objcpp-switch`** (was `003-quickjs-switch`;
  it no longer switches the engine). Git Town lineage, manifest (branch, description, title) and
  references updated; the description file is `series/pr/003-objcpp-switch.md`. `origin` still has
  the old name: the handover deletes it after pushing the new one.
- **Jon, 2026-11-04: no GCC requirement in seriesb.** The series adds no GCC to CI (upstream already
  ships `gcc.ini`; old step 017 changes only source and tests). Its code fixes stay (portable
  correctness fixes GCC found); step 017 is retitled at its replay to say so (e.g. "Fix code that
  GCC warns about"). Verification no longer builds with GCC for seriesb (`verify_step(gcc=False)`,
  `build_gcc` = n/a), so the end target's pre-existing GCC LTO link failure no longer gates anything.
- **Jon, 2026-11-04: old 018's (and 023's) upstream ports move earlier.** No branch may revert an
  upstream fix, so each hunk of old 018 (#369–#765 ported into the C++ code) and old 023 (#766,
  #774, #781) belongs in the step that converts or writes the code it touches. A placement plan is
  being drawn up (`series/review/placement-018-023.md`); replays of 010–017 fold in their hunks, and any
  hunk owned by rebuilt 003–009 gets a follow-up commit there, merged up. 018 and 023 are then
  dropped; #783's port stays as its own late step.
- **Step 010 replayed (2026-11-04): `a7764d6a9` on `seriesb/010-module-conversions`**, on 009
  (`1912db791`). 73 conflicted files (571 blocks) plus 58 new façade files. Ten parallel agents
  (`.agent-tmp/step10/brief.md`) rebuilt most bindings from 009 with the old hunks re-applied.
  Gates, all in the isolated Objective-C MSYS2:
  - clean build rc=0, with only QuickJS-ng's 4 `-Wpedantic` warnings;
  - oofnd 46/46 and core 153/153;
  - smoke clean, with no leaked JS objects;
  - component 8/8 scenarios and `test_world_setup_clear` 3/3;
  - harness 23 checks, 0 failures;
  - no façade and no statistics left.

  The tests are equal to old 010's except those ledgered under "## Step 010". Defaults taken:
  1. `OOJavaScriptEngine.h` is split as the old step split it. The plain C++ part becomes
     `OOJSEngineCore.h`. The native-wrapper macros move into `OOJSEngineNativeWrappers.h`, which
     the core includes; this is the old step's and the end target's layout, with #768's macro
     names. It reverses 009's default 1, which applied while the header was whole.
  2. Old 018/023 placement for 010 (`series/review/placement-018-023.md`) is folded in:
     - #756: `OO_DEBUG_MONITOR_ENABLED` guards in the converted entity, drawable, material and
       texture headers and in the Entity, texture and debug bridges. Step 009 itself still has
       `#ifndef NDEBUG` on the Materials headers it converted; this step fixes them.
     - #737 comments, a69 and a105.
     - #766: `OOLITE_MAC_COCOA_UI` is kept in GameController, and the GLSL 3.30→1.20 translator
       is converted to C++ with its `test_OOShaderProgram` cases, plus `OOLITE_MACOS`.
     - a167-168 are already satisfied (the new test has no unused counter).
  3. The joystick SDL decoders become members of the C++ `OOSDLJoystickManager`. They reach the
     base's state as a friend, through the facade, until the SDL class derives from the base.
     **For Jon:** `test_OOJoystickManager`'s `facadeContract` changes the receiver of one check
     (ledger row). It has no end-target counterpart.
  4. The limiter cases of the old `test_OOJSEngineTimeManagement` move to a new
     `test_OOJSTimeLimiter.mm` on the real engine, as the end target does. The engine starts in an
     `@autoreleasepool`: an autoreleased `OOJSValue` otherwise outlived the notification centre at
     process exit (`std::system_error`).
  5. The fork's SystemInfo `has_property` hook comes in with SystemInfo's conversion. Manifest and
     MissionVariables' exotic hooks catch with C++ `try`/`catch (...)`, the end target's form,
     because `@catch (id)` cannot catch the C++ exception the test throws.
  6. `OOProfilingStopwatch.h` includes `<windows.h>`, with BOOL renamed as `OOFoundation.h` does,
     for plain C++ translation units (`OOJSFont.cpp`).

  Found:
  - Another session's automation used console port 8563 during the first component run, so s3,
    s4 and s8 connected to the wrong listener or none. A sequential rerun that waits for the port
    to be free passed all of them (`.agent-tmp/step10/component_seq.sh`).
  - A debug-flavour build (the harness's build dir) does not link 8 Materials core tests
    (`OOGLNoteCurrentFunction`), because the test lists lack `OOOpenGLStateManager`. The harness
    target itself is fine.
- **T059 follow-ups on 004–009 (2026-11-04)**, each a commit on its step, merged up (no rewrites):
  tips 004 `5b609646a`, 005 `a4d0a10cb`, 006 `404b8369c`, 007 `8f62d84da`, 008 `037cf9049`, 009
  `f18e064bc`; ledger `4f8ead04b`. The deployment build was broken from 006 (`AI.mm` `debugContext`;
  `Universe.mm`'s bridge import under `OO_LOCALIZATION_TOOLS`) and could not launch from 008
  (`OOAssert` compiled out under NDEBUG skipped `-deferredInit`'s ship set-up); it now compiles at
  006–009 and its smoke passes at 006, 008 and 009. New tests: `test_objc_assert_ndebug` (007, fails
  on the old header), `test_OoliteEquipmentControlScript` (009, #369). Step 010 merged the new 009
  (`0747c771a`, four trivial conflicts); re-gated: build 0 warnings, unit 201/201, smoke, harness pass.
- **Rule learned (2026-11-04): one game instance at a time, or private console ports.** Two agents
  launching the game on the default debug-console port 8563 broke each other's smoke and component
  runs. Agents running in parallel set `OO_CONSOLE_PORT` to a private port; GUI tests still run
  alone (CLAUDE.md).
- **Open: debug-config core tests do not link** (`-Ddebug=true`, e.g. the harness build dir): 8–9
  Materials/GL core tests miss `OOGLNoteCurrentFunction` (their meson source lists lack
  `OOOpenGLStateManager`). Present since 009; the release-flavour gates are unaffected (T066).
- **For Jon: `test_OOJoystickManager` `facadeContract` (step 010).** One check's receiver moves from
  the base manager to the decoding manager under #742; the expected value is unchanged. There is no
  end-target counterpart, so it waits for his sign-off.
- **Step 011 replayed (2026-11-04): `c5e9fa535` on `seriesb/011-first-slices`**, on 010 (`0747c771a`).
  44 conflicted files plus 57 façade users; eight parallel agents (`.agent-tmp/step11/brief.md`) rebuilt
  OOJavaScriptEngine.mm, OOJSPlayerShip.mm and OOJSSystem.mm from 010 with the old hunks re-applied.
  Gates (isolated Objective-C MSYS2): clean build rc=0 with only QuickJS-ng's 4 `-Wpedantic`; oofnd
  47/47, core 165/165; smoke clean (no leaked JS objects); component 10/10 on the first attempt;
  harness 23/23; deployment build rc=0 (plus the parent's `legacy_random.c` deployment-only warning)
  and its smoke pass; no façade, no statistics; tests equal to old 011's except the rows under
  "## Step 011". Defaults taken:
  1. The engine is `cxx::OOJavaScriptEngine` with #768's members and selectors; its one facade is the
     sender of the reset notifications, so `oo::ToObjC(engine)` always answers the same object.
  2. `OOJSSpecialFunctions` keeps #768's `JSSpecialFunctionsObjectWrapper` (the end target's form),
     so the old step's `+ObjCBridge` pair, left empty, is not added.
  3. Old 018/023 folded: a52 (GameController's paused-console priority under
     `OO_DEBUG_MONITOR_ENABLED`), a88-90 (OOMesh), a124-126 + a166 (#744: no dark-mode code; test
     line ledgered), a169 (#747 `copyUrlKey` test), b585/b591 (#774), b587-589 (#766 front-buffer
     snapshot, on `OOLITE_MAC_OS_X` until 016).
  4. The old step's `test_OOMaterialConvenienceCreators` `typeid` form warns; it takes the end
     target's warning-free form (ledgered, no assertion changed).
  5. **For Jon:** `test_OOJavaScriptEngine`'s plain-OOObject check becomes `!JS_IsObject` with the
     exception cleared (#768 boxes undefined, which throws); the end target has no counterpart.
  Found: the component tier cannot move the game off port 8563 (`console.py` writes no
  `debugConfig.plist`); this run put one in a private `OO_ADDITIONALADDONSDIRS` root, as
  `launch_snapshot.py` does, with `OO_CONSOLE_PORT=8621`.
- **T054: step 012 replayed on #768's binding (2026-11-04): `f8f3c21af` on
  `seriesb/012-shipentity-slices`**, on 011 (`c5e9fa535`). 16 conflicted files (42 blocks) and one
  modify/delete (`OOJSGlobal+ObjCBridge.mm`, deleted as in the old step), resolved by one agent
  (`.agent-tmp/step12/`; no sub-agents). Gates (isolated Objective-C MSYS2): clean build rc=0 with
  only QuickJS-ng's 4 `-Wpedantic`; oofnd 47/47, core 170/170, headers and game-unit pass; smoke
  clean (no leaked JS objects); component 10/10 on the first attempt (port 8622, private
  `OO_ADDITIONALADDONSDIRS`); harness 23/23; deployment build rc=0 and its smoke pass; no façade,
  no statistics; tests equal to old 012's except the rows under "## Step 012". Defaults taken:
  1. Old 018/023 folded: a44-47 (#756 guards on `cxx::ShipEntity`'s debug members), extended to
     the same members in `ShipEntity+ObjCBridge.h/.mm` and Universe's `debugDumpEntities`/
     `cxx_entityList` in `Universe+ObjCBridge.h` (the old step's `#ifndef NDEBUG` there broke the
     deployment build); b199, 202-204, 212-215, 552, 553 (`OOLITE_MAC_COCOA_UI` for every
     `OOLITE_MAC_OS_X` the old step wrote in GameController and Universe). The paused-console
     priority (#756) is kept in the C++ `GameController::setEcoQoS`.
  2. **Placement correction:** old 012, not 013, dropped #766's multisample colour renderbuffer
     (`OO_MSAA_COLOR_RENDERBUFFER`) from Universe's framebuffer code; it is kept here, so
     b554-557 are already satisfied when 013 is replayed.
  3. #768's shut-down leak check stays in the C++ GameController (`[[::OOJavaScriptEngine
     sharedEngine] shutDown]`); the end target `655583067` dropped it (T055's final-tree check).
  4. **For Jon:** `test_Universe.mm` `flags` passes its 7 and 2 through `int` locals; the literal
     form warns (`-Wobjc-bool-constant-conversion`), which the parent's build does not. Values and
     checks unchanged (ledger row).
  5. T060: no `+ObjCBridge` wrapper loses its last caller in this step beyond
     `OOJSGlobal+ObjCBridge.mm`, which the old step already deletes.
- **T054: step 013 replayed on #768's binding (2026-11-04): `9304fedba` on
  `seriesb/013-universe-player-slices`**, on 012 (`f8f3c21af`). 31 conflicted files (5 modify/delete,
  the old step's facade deletions, taken), resolved by three parallel agents (`.agent-tmp/step13/brief.md`;
  bindings and OOJSPrivateObject; plume/flasher/visual effect and Entity; PlayerEntity, OORegExpMatcher,
  ShipEntityAI) and the orchestrator (Universe: old 013's file with the parent's #768 delta re-applied, 9
  hunks by hand). Gates (isolated Objective-C MSYS2): clean build rc=0 with only QuickJS-ng's 4
  `-Wpedantic`; oofnd 47/47, core 172/172, headers and game-unit pass; smoke clean (no leaked JS
  objects); component 10/10 on the first attempt (port 8623, private `OO_ADDITIONALADDONSDIRS`); harness
  23/23; deployment build rc=0 (only the parent's `legacy_random.c` warning) and its smoke pass; no
  façade, no statistics; revert flags all explained (moves, or the step's own conversion on #768's form);
  tests equal to old 013's except the rows under "## Step 013". Defaults taken:
  1. Old 018/023 folded: a118-119 (#756 `OO_DEBUG_MONITOR_ENABLED` on `cxx::Universe`'s
     `debugDumpEntities`/`entityList`), extended to the facade's declarations and forwarders; b554-557
     (#766 MSAA renderbuffer) kept, now in `cxx::Universe`'s framebuffer code; also #766's
     `OOLITE_MAC_COCOA_UI` for the Mac speech routines the old step moved (it wrote `OOLITE_MAC_OS_X`).
  2. `OOJSPrivateObject` takes the end target's #768 form; at this stage its finalizer is
     `OOJSCxxObjectWrapperFinalize` (the engine's `OOJSObjectWrapperFinalize` is still Objective-C).
     The Timer keeps #768's `transferJSSelf()` ownership and the old step's converter answering the
     facade (`OOJSBasicPrivateObjectConverter` would read the C++ slot as an `id`).
  3. **Old-step bug fixed:** old 013 opened slice 26's `namespace cxx` inside `#if OO_LOCALIZATION_TOOLS`,
     so the deployment build (tools off) failed; the guard now sits inside the namespace. The test build
     (tools on) preprocesses to the same code.
  4. `test_OOJavaScriptEngine`'s `aValueLeftInTheThreadPoolAtExit`, added by the old step and not in the
     end target, is kept, rewritten on #768.
  5. T060: no `+ObjCBridge` wrapper loses its last caller here beyond the five the old step deletes
     (and `OOJSVisualEffect+ObjCBridge.mm`); `OOJSTimer+ObjCBridge` still serves the timer queue and
     converter, `PlayerEntity+ObjCBridge` is the Objective-C player itself.
- **T051c (2026-11-04): the end target restores #768's shutdown leak check.** `9d4ce2b1e` on
  `feature/upstream-quickjs-poc-cxx` (on `655583067`) = `anchors.develop_target`.
  `GameController::exitAppWithContext` calls `OOJavaScriptEngine::sharedEngine()->shutDown()` after
  the defaults are synchronized, under #768's `#ifndef NDEBUG` (step 012 keeps the same guard).
  `sharedEngine()` creates the engine if there is none, as #768's `+sharedEngine` does. The new
  component test `test_exit_runs_js_leak_check.py` fails without the call and passes with it. Gates:
  build 0 warnings, unit 220 Ok, smoke clean, harness 23/23, deployment build and its smoke pass
  (NDEBUG, so the check is compiled out there, as upstream does).
- **T051d (2026-11-04): the end target uses #756's debug-monitor guard for the shader bindings.**
  `8a0a3c97a` on `feature/upstream-quickjs-poc-cxx` (on `9d4ce2b1e`) = `anchors.develop_target`.
  `EntityShaderBindings.cpp`'s table is under `#if OO_SHADERS || defined(OO_DEBUG_MONITOR_ENABLED)`, as
  `OOShaderUniformMethodType.h/.cpp` and step 014's `Entity+ObjCBridge.mm` are, and
  `PlayerEntity::suppressClangStuff` (it reads the monitor-only `n_key_dump_*`/`n_key_debug_*` and is
  inside upstream's #756 `dumpSelfState` block) moved from `#ifndef NDEBUG` to `#ifdef
  OO_DEBUG_MONITOR_ENABLED`. The other 118 NDEBUG guards in `src` stay: each matches a guard upstream
  (`7437f22a5`) still keeps on NDEBUG (asserts, sanity checks, AI debug stack, time-limiter console
  hooks under `OOJS_PROFILE`, STAGE_TRACKING, entity-list verification) or is fork-only with no
  monitor use (#768's leak check, the poc engine). Test: `tests/check_debug_monitor_guards.py` (meson
  suite `headers`), a source check because no runtime tier can see the guard: the deployment flavour
  has `OO_SHADERS` on, so the table compiles either way except with `no_shaders`. Default taken: the
  check lives in oolite-dev beside `check_headers_standalone.py`, not in `tools/series/tests`. Gates:
  build 0 warnings, unit 40+179+2 Ok, smoke clean (port 8627), harness 23/23, deployment build 0
  warnings and its smoke pass.
- **T054: step 014 replayed on #768's binding (2026-11-04): `d461ca10a` on
  `seriesb/014-facade-deletions`**, on 013 (`9304fedba`). 124 conflicted files (707 blocks) and 48
  modify/delete (the old step's bridge deletions, taken), resolved by ten parallel agents
  (`.agent-tmp/step14/brief.md`; entity classes rebuilt as old 014 plus the parent's #768 delta, bindings
  as the parent plus the old step's change; OOJSShip by a token-level three-way merge) and the
  orchestrator (Universe, meson). Gates (isolated Objective-C MSYS2): clean build rc=0 with only
  QuickJS-ng's 4 `-Wpedantic`; oofnd 47/47, core 175/175, headers and game-unit pass; smoke clean (no
  leaked JS objects); component 10/10 on the first attempt (port 8625, private
  `OO_ADDITIONALADDONSDIRS`); harness 23/23; deployment build rc=0 (only the parent's `legacy_random.c`
  warning) and its smoke pass; no façade, no statistics; tests equal to old 014's except the rows under
  "## Step 014". Revert check: 6 `+!` lines, all generic (`return YES;`, braces style of #749 in
  `OOJSConsole`'s inspect); 271 removed upstream/#768 lines beyond the old step's own are #768-form
  message sends and class glue that this step converts to C++ calls (no `JS_FreeValue`, guard or
  exception handling lost). Defaults taken:
  1. Old 018/023 folded: a29-32, a41, a42 (#740: a new game reads `last_savename`; no
     `OO_USE_CUSTOM_LOAD_SAVE`/AppKit panel selectors, which the old step re-created) with the new test
     `lastsaveNameIsRememberedInTheDefaults` (a171-172); a31, a43, a94 (#756); a33-40 (#749/#751:
     `AnyKeyPressed()` where the conversion wrote `||`; it needs `<initializer_list>`, not `<cstring>`).
  2. The C++ objects in the private slot (script, ship group, system info, equipment info, sound, sound
     source) use `OOJSCxxObjectWrapperFinalize` and class-specific converters: at this stage the
     engine's `OOJSObjectWrapperFinalize`/`OOJSBasicPrivateObjectConverter` still treat the slot as an
     Objective-C object. The end target uses the generic ones once the engine is C++.
  3. **For Jon:** the moved entity shader-binding table is guarded `OO_SHADERS ||
     defined(OO_DEBUG_MONITOR_ENABLED)` (#756's guard of `OOShaderUniformMethodType.h`); the end
     target still says `!defined(NDEBUG)` (T055's final-tree check will show it).
  4. SystemInfo drops the old step's raw `_jsSelf` (no wrapper is remembered, as in the end target);
     the reset observer key for the deleted `OOSystemInfo` class is `nullptr`.
  5. The cherry-pick's conflict markers end in the commit subject, which carries a CR, so each left a
     lone `)` line; every resolved file was checked for them.
  6. Comment-only test edits (bead ids dropped) are ledgered in one row.
  7. T060: 014 cannot shrink much. Of the bridges whose deletion conflicted (48 files, the ones the
     rebuilt 011-013 had touched), only `OOJSConsole+ObjCBridge` had no caller outside its own class
     at 013; every other one needed this step's conversions first (PlayerEntity slices 2-28, the ship
     family, OOJSShip slices 2-6). The 74 cleanly deleted bridge files were not audited one by one. The
     rebuilt 011-013 did what old 011-013 did and nothing of 014's (they deleted no extra bridge).
     Merging 014 with 015 ("Delete the root Entity facade", 492 files) would give one ~1,000-file step;
     default: keep them separate.
- **T054: step 015 replayed on #768's binding (2026-11-04): `5309798dc` on
  `seriesb/015-entity-facade`**, on 014 (`d461ca10a`). 161 conflicted files (579 blocks), 25 modify/delete
  and one delete/modify (`ooscript/JSEngine.hpp`, kept deleted), resolved by fourteen parallel agents
  (`.agent-tmp/step15/brief.md`; entity classes as old 015 plus the parent's delta, bindings and engine as
  the parent plus the old step's change, the end target `8a0a3c97a` as the reference) and the orchestrator
  (Universe and GameController as old 015 plus the parent's delta, meson, `UniverseVirtualMembers.h`, the
  harness's `cxx::` names). Gates (isolated Objective-C MSYS2): clean build rc=0 with only QuickJS-ng's 4
  `-Wpedantic`; oofnd 47/47, core 178/178, headers and game-unit pass; smoke clean (no leaked JS objects);
  component 10/10 on the first attempt (port 8626, private `OO_ADDITIONALADDONSDIRS`); harness 23/23;
  deployment build rc=0 (only the parent's `legacy_random.c` warning) and its smoke pass; no façade, no
  statistics; tests equal to old 015's except the rows under "## Step 015". Revert check: no `+!` line;
  117 removed upstream/#768 lines beyond the old step's own, all #768-form code this step converts
  (finalizer and converter swaps to `OOJSCxxObjectWrapperFinalize`/`OOJSEntityObjectConverter`, Objective-C
  sends to `UNIVERSE`/engine/entity becoming C++ calls, `DEFINE_JS_OBJECT_GETTER` and `weakRetain` slots
  becoming the holder; no `JS_FreeValue`, guard or exception path lost). Defaults taken:
  1. Old 018/023 folded: a12-16, a18, a19, a22, a23 (#756 on the entity counters, debug virtual members
     and by-name rows); a20, a21, a106, a107 (the generated tables in the generator's layout with the
     clang-format marker, #740's custom load/save rows removed, #756's `drawDebugStuff`; rows keep old
     015's `@encode`, as `OOTypeEncodings.h` comes later); a54, a60 (#737 comments); b42, b558-560
     (virtual-member macros one member per line inside clang-format markers, system includes first).
     Also `PlayerEntity::suppressClangStuff` and the entity shader-binding table under #756's guard (T051d).
  2. At this stage `OOJSObjectWrapperFinalize`/`OOJSBasicPrivateObjectConverter` keep #768's
     Objective-C form; no game object puts an Objective-C object in a JS slot any more (entities hold an
     `OOJSEntityHolder`), so the end target's generic C++ forms can replace them when the runtime goes.
  3. #768 kept over the old step: deferred `quitGame()` (through the `std::function` deferred call), the
     definitions' reset observers until destruction, `OOJSFunction` compiling in the global scope, no
     watchdog (old 015's watchdog case in `test_OOJSEngineTimeManagement` is not carried).
  4. Old-step bug fixed: `OOConstToJSString.cpp`'s `-Wextra` initializer named the façade's field
     (`.jsString`); it is #768's `.atom = JS_ATOM_NULL`, as in the end target.
  5. **For Jon:** old 015 deletes `test_OOJoystickManager`'s `facadeContract` case with the joystick
     facade, so the step-010 sign-off on it lapses here. A stale waypoint's property read now fails
     (`OOJSNativeFailure`) where it answered `undefined`, as old 015 and the end target do.
  6. T060: per area, the pieces with no dependency on the root Entity facade (the joystick, cache,
     texture, material, resource, registry and async managers' facades, the C++ engine and monitor,
     OONull/OOJSValue as foreign objects, the #756/#740 table and guard ports, comment scrubs) could have
     gone into 014 or a step between; the entity holder slot, `EntityHold`/`WeakSet` members, the by-name
     tables and every `Entity*` signature needed it. Moving them would change 014 (already ~1,000 files
     with its bridges) and save little review in 015 (most of its 492 files are the entity conversion);
     default: keep 015 whole.
- **T054: step 016 replayed on #768's binding (2026-11-04): `ff8664462` on
  `seriesb/016-objc-runtime-out`**, on 015 (`5309798dc`). 154 conflicted files (341 blocks), 14
  modify/delete and one delete/modify (`ooscript/JSEngine_quickjs.cpp`, kept deleted), resolved by ten
  parallel agents (`.agent-tmp/step16/brief.md`; mostly the parent's file plus the old step's change, the
  end target `8a0a3c97a` as the reference) and the orchestrator (GameController, Universe, meson lists,
  README). The new-stack `.mm` files the old step never saw (#768's `OOJSClasses`, #767's `poc/`,
  `test_OOJSTimeLimiter`, `test_OoliteEquipmentControlScript`, `test_objc_assert_ndebug`) are renamed
  `.cpp` and converted. First step in the C++ era (`verify.py` `era()` = cxx: scoop MSYS2, no `.m`/`.mm`
  left). Gates: clean build rc=0 with only QuickJS-ng's 4 `-Wpedantic`; oofnd 40/40, core 175/175 (the
  parent's 178 less the retired `test_OOWeakReference`, `test_OOWeakSet`, `test_OOAsyncQueue`), headers
  and game-unit pass; smoke clean (no leaked JS objects); component 10/10 on the first attempt (port 8628,
  private `OO_ADDITIONALADDONSDIRS`); harness 23/23; deployment build rc=0 (only the parent's
  `legacy_random.c` warning) and its smoke pass; `no_new_spidermonkey_or_gnustep` pass; no façade, no
  statistics; tests equal to old 016's except the rows under "## Step 016". Revert check: no `+!` line;
  291 `-!` lines, all Objective-C syntax this step converts (`@try`/`@catch`/`@finally`, `#import`, pools,
  `OOLITE_MAC_OS_X` to `OOLITE_MACOS` on the folded hunks) or Objective-C paths the old step deletes
  (callObjC on a non-entity, `OOShaderUniform::setBindingTarget(id)`, the objc meson arguments). Defaults
  taken:
  1. Old 018/023 folded: a58, a62, a63, a68, a71, a116, a123 (#748 include order); a100, a101
     (`OOTypeEncodings.h` in the generator's layout, marker without bead id); a134 (#737); b439 (#766
     legacy-context check in C++); b381, b420-b429, b581-b584, b592, b594 (`OOLITE_MACOS`), plus the three
     `MyOpenGLView.cpp` snapshot guards for consistency (old 023, 025 and the end target agree); b6/b7 in
     part (the README's Objective-C section and source-tree lines). **Skipped (Jon's pending default, keep
     macOS CI):** b1-b4 (macOS CI jobs and the artifact count) and b6/b7's removal of the macOS build docs
     and "Windows, Linux and macOS"; T058 records macOS as "not verified".
  2. Tests keep old 016's `#import` lines (clang accepts them; step 017 converts them); only real
     Objective-C in tests is converted.
  3. `OOProfilingStopwatch.h`'s Windows block (the parent's) gains `__OBJC_BOOL` around `<windows.h>`, as
     `OOFoundation.h` has it: without an Objective-C compiler `<minwindef.h>` declared its own `BOOL`.
  4. #768's own Objective-C becomes C++ in the end target's form: the mission reset observer, `@try`/
     `@catch (id)` in the console, world scripts and `OOJSSystem`, the engine's `OOJSObjectWrapperFinalize`/
     `OOJSBasicPrivateObjectConverter`; `OOJSReportWrappedException(id)`, which #768 had re-added, goes.
  5. `clang.ini` drops only the objc lines; the end target's `ar = 'llvm-ar'` came from the old façade
     step and is not taken (the parent never needed it).
  6. **For Jon:** `test_objc_assert_ndebug` loses its 4 method-form checks with the method forms (as the
     end target); `test_OOJavaScriptEngine`'s T068 check and `aValueLeftInTheThreadPoolAtExit` go with old
     016's retirements.
  7. T070 not done here: the tree passes `check_debug_monitor_guards.py` (run from scratch, rc=0, no guard
     to fix), but the check imports `tests/idiom_check.py`, which arrives with step 022, and its meson hook
     sits in the `headers` suite, which arrives with step 019. Default: add it at 022's replay.
- **T054, T062: step 017 replayed on #768's binding (2026-11-04): `c37c508dd` on `seriesb/017-gcc-build`**,
  on 016 (`ff8664462`), retitled "Fix code that GCC warns about or evaluates differently" (the old step
  also orders random draws as Clang did, so "warns about" alone undersells it); branch slug kept. 2
  conflicted source files (`OO_PRINTF_FORMAT` on #768's `JSContext*` signatures) and 53 tests (`#import`
  to `#include` on the parent's lines), resolved by one agent (`.agent-tmp/step17/`). Gates (C++ era,
  scoop MSYS2): clean build rc=0 with only QuickJS-ng's 4 `-Wpedantic`; oofnd 40/40, core 175/175,
  headers and game-unit pass; smoke clean (no leaked JS objects); component 10/10 on the first attempt
  (port 8629, private `OO_ADDITIONALADDONSDIRS`); harness 23/23; deployment build rc=0 with 0 warnings
  (the parent's `legacy_random.c` warning is fixed here) and its smoke pass;
  `no_new_spidermonkey_or_gnustep`, no new suppressions, no façade, no statistics; clang-format 22.1.8:
  the same 17 files as the parent, none new. Revert check: no hunk flagged. Tests equal old 017's except
  the rows under "## Step 017". GCC was not built (not a gate). Defaults taken:
  1. Old 018/023 folded: a10, 17, 27, 49, 55, 56, 64, 66, 72, 74, 76, 83, 87, 91, 93, 104, 115, 122, 127,
     130 (include what you use); a81 was already satisfied; a75 (`gnu_inline`), a120/a121
     (`legacy_random.c`), a128 and b595 (`chdir` results), b48 and b388 (`PRIu64`, in the current
     layout, not old 023's). `OOCharacter.cpp` also includes `<cinttypes>`: the Clang build does not
     reach it transitively there.
  2. No CI hunk to skip: old 017 changes no workflow and `gcc.ini` was already in the tree.
  3. `OOMathsBase.h` (#748, end target `21c8c1df0`) is not old 017's; it lands with the headers suite
     (step 019), as the placement table says.
  4. **For Jon:** clang-format 22.1.8 finds 17 unformatted files at 016 and 017 (5 at 014, 6 at 015; 0 in
     the old stack), all in files the rebuilt steps resolved by hand; the old step's gate had the check.
     Step 024 reformats everything; until then the rebuilt steps fail the per-step `clang_format` check.
