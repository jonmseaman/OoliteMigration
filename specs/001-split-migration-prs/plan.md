# Implementation Plan: Split the C++ migration into a reviewable PR series

**Branch**: `feature/phase4-polish` (OoliteMigration); the series' own branches are `series/NNN-slug` in
`oolite-dev` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-split-migration-prs/spec.md`

## Summary

Turn `develop` (upstream `49a5eb9fc` plus a squashed 1,041-file migration and 58 later commits) into
an ordered Git Town stack of one-commit PR branches that a maintainer can merge one at a time. The
steps come from this repo's own iterative history: 1,935 commits under `upstream/oolite/`, from
2026-09-05 to 10-27. Each step is a **target tree**: the history snapshot at a cut point, with
formatting normalised by clang-format 22, carried onto upstream by a 3-way merge
(research R1–R4), cut into one PR per phase work-item chapter (option B, research R14): 19 history chapters plus
6 `develop`-tail steps, 25 PRs. A small stdlib Python tool (`tools/series/series.py`) plans cuts, builds the
branches, verifies each one in order for its era (R5, R9), writes the PR descriptions, and checks
the manifest, branches and Git Town lineage against each other. Jon pushes and opens the PRs.

## Technical Context

**Language/Version**: Python 3.14 (stdlib only) for the tool; Bash in MSYS2 UCRT64 for game builds

**Primary Dependencies**: git ≥ 2.38 (`merge-tree --write-tree`), Git Town 24 (`append --prototype`,
`set-parent`, perennial branches), clang-format 22 (PyPI wheel, in `.agent-tmp/series-venv`), the
game's own `mk.sh` / `tests/run.sh`

**Storage**: files: `specs/001-split-migration-prs/series/` (manifest JSON, inventory TSV,
resolution patches, PR descriptions); branches plus `git-town-branch.*` config in `oolite-dev`

**Testing**: `python -m unittest discover tools/series/tests` for the tool (fixture repos built in a
temp dir); for each step, the game's build, `tests/run.sh unit`, `smoke`, and the component scenarios
it touches

**Target Platform**: Windows x64 (MSYS2 UCRT64). Objective-C steps use an isolated MSYS2 that matches
upstream CI (G0)

**Project Type**: repository tooling (CLI) plus a deliverable of git branches and documents

**Performance Goals**: verify the whole series in under 24 h of machine time with incremental builds
(R9)

**Constraints**: never push, sync or propose; never touch `develop`, `master` or `main`; never edit a
test; scratch only under `.agent-tmp/`; GUI and smoke tests run one at a time

**Scale/Scope**: 1,935 history commits → 19 chapters + 6 tail steps = 25 PRs (R14), 2k–79k reviewed lines each; about 30 files with real conflicts
between upstream and the migration (R4)

## Constitution Check

`.specify/memory/constitution.md` is still the unfilled template, so the gates are CLAUDE.md's
hard rules.

| Rule | Gate | Status |
|---|---|---|
| 1 Never modify a test to pass | The construction never edits tests; the check flags any test difference from the source snapshot (R11) | pass |
| 2 Never silence a warning | Construction adds no `-Wno-*` or `pragma diagnostic`; checked (R11) | pass |
| 3 Never push / touch `develop` | Prototype branches, perennial root, tool never pushes; handover is Jon's (quickstart §5) | pass |
| 4 No expansion content | The series touches no OXP/OXZ | pass |
| 5 Tools judge correctness | Every step's status comes from its verification record, not judgement | pass |
| 6 No GNUstep / `JS_*` | **Interpreted** (R11): early steps carry upstream's GNUstep and SpiderMonkey; no step may add either; the last step has neither | justified, see Complexity Tracking |
| 7 Don't rewrite C | Vendored C is carried as the history has it | pass |
| 8 Never wait for Jon | Every open choice has a recorded default (below, research) | pass |
| 9 Stay in the workspace | Tool, venv, isolated MSYS2 and verify worktree all under the repo | pass |
| Workflow: command fails before, passes after | Every task's acceptance is `series.py check`/`verify` or the tool's unit tests | pass |

Post-design re-check: same result. The design adds no new rule pressure beyond rule 6's
interpretation.

## Project Structure

### Documentation (this feature)

```text
specs/001-split-migration-prs/
├── spec.md
├── plan.md              # this file
├── research.md          # R1–R12
├── data-model.md        # manifest, step, verification, ledger
├── quickstart.md        # run and hand-over guide
├── contracts/
│   ├── series-cli.md    # tools/series/series.py commands
│   └── pr-description.md
├── checklists/requirements.md
├── series/              # produced by the tool (manifest.json, inventory.tsv, resolutions/, pr/)
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
tools/series/
├── series.py            # CLI entry: inventory, cut, hoist, tree, build, verify, describe, check, renumber
├── history.py           # reading the history: first-parent walk, snapshots, upstream-under-commit
├── normalise.py         # clang-format 22 normaliser with per-blob cache
├── trees.py             # 3-way merge onto the base, resolutions, rerere
├── stack.py             # branches, single commits, Git Town lineage
├── verify.py            # era matrix, MSYS2 invocation, shared worktree, records
├── manifest.py          # load/save/validate (data-model.md rules)
└── tests/               # unittest; fixture repos with a fake subtree history

oolite-dev/ (branches only; no files change on develop)
├── series/000-upstream-base      # 49a5eb9fc, Git Town perennial
├── series/001-…  …  series/NNN-… # one commit each, prototype branches
```

**Structure Decision**: the tool lives in OoliteMigration (`tools/`, next to `corpus.sh` and the
`oxp_*.py` tools) because it reads this repo's history; its outputs live in the spec directory. The
game repo only gets local branches.

## Gates and order of work

- **G0, environment:** the upstream base `49a5eb9fc` builds in the isolated MSYS2
  (`.agent-tmp/msys2-objc`, set up with upstream's `install_deps.sh clang`). Until it does, only
  `cxx`-era steps can be verified locally. Fallback: CI on the fork after Jon pushes.
- **G1, tool:** `series.py` unit tests pass on fixture repos (inventory, normalise, merge,
  build, lineage, check, renumber).
- **G2, chapters:** `inventory` and `cut --chapters` write R14's 25 steps into the manifest; the
  boundary snapshots are confirmed and the hoist candidates in chapter 1 are listed in the notes below.
- **G3, build:** every step is `built`; `check` passes (lineage, trees, ledger, descriptions).
- **G4, verify:** `check --verified` passes; the last step equals `develop` outside exclusions.
- **G5, re-anchor (when Jon asks):** rebuild on upstream's tip (R12).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Rule 6 interpreted, not applied literally, to intermediate steps | The series base is upstream, which uses GNUstep and SpiderMonkey; the migration removes them step by step | Removing them in step 1 is the one-big-PR the feature exists to avoid |
| A second MSYS2 install under `.agent-tmp/` | The installed GNUstep headers fail with Clang 23 even on upstream's own base; upstream CI uses newer packages | Upgrading Jon's MSYS2 changes his working toolchain (`pacman -Syu`) without his say |
| A custom tool instead of plain git commands | 25 steps × (normalise, merge, resolutions, lineage, verify) must be repeatable when upstream moves (R12) | Hand-made branches can't be rebuilt or checked |

## Notes (decisions and state that outlive the session)

- 2026-11-01: Steps are target trees from this repo's `upstream/oolite/` history, per Jon's
  pointer that the history is the asset (spec FR-015).
- 2026-11-01: Lineage via `git town append`, branches `series/NNN-slug` (Jon). Three digits because
  the step count may exceed 99.
- 2026-11-01: FR-003 amended (R5): GCC is required only from steps whose parent builds with GCC.
- 2026-11-01: **Option B** (Jon): one PR per chapter, with no line limit; chapters and tail pinned in R14.
  This supersedes the 3,000-line rule (R6) and option D (R13).
- 2026-11-01: The base stays `49a5eb9fc` while building; re-anchor on upstream's tip (`7437f22a5`
  today) is a separate, final gate (R12).
- 2026-11-01: Default exclusions: `.zed/`, `.vscode/`, the fork-only CI branch filter (R10).
- Open, with defaults taken: if the isolated MSYS2 can't reproduce upstream CI's packages, the
  Objective-C steps are verified by CI on Jon's push, and their records say "CI" with the run URL.
- 2026-11-01: Cuts follow phases and work items first ("chapters"), size second (research R13,
  option D), after Jon asked for a logical split. A history-free split was rejected: 75% of `src`
  is one include cycle, so it would need a ~210k-line flip PR.
- T002: clang-format 22.1.8 (PyPI `clang-format` wheel) in `.agent-tmp/series-venv`.
- T003: the history is `refs/series/history` in `oolite-dev` (= OoliteMigration `338463308`); fetch by
  full hash (abbreviated hashes are refused).
- T005 / G0 passed 2026-11-01: isolated MSYS2 at `.agent-tmp/msys2-objc/` (2.8 GB, unpacked from scoop's
  cached base `msys2#2025-12-13`, then `pacman -Syuu` twice and upstream's `install_deps.sh clang`).
  Shell: `MSYSTEM=UCRT64 .agent-tmp/msys2-objc/usr/bin/bash.exe -l <script>`. Packages: clang 23.1.4,
  gnustep-base 1.31.1+85dedc64b, libobjc2 2.3, nspr 4.40. Upstream `49a5eb9fc` builds there with
  `./mk.sh build test`, with 0 warnings. Jon's scoop MSYS2 is untouched.
- T010: resolutions are whole resolved files keyed by their three input blobs
  (`series/resolutions/NNN/index.json` + `files/<path>`), not patches, so a stale one is reported
  instead of applied. `git rerere` does not apply to `merge-tree` and is unused.
- 2026-11-01: merges are incremental, rebase-style, with a 30% rename threshold (research R15), after
  the from-scratch merge gave ~2,300 recurring conflicts.
- To fill at G2: boundary moves (if a snapshot doesn't build), hoisted fixes in chapter 1, and
  whether the tail groups 020–024 build in upstream style (else they fold into 025).
- T020: verification shells per era (default, conservative): Objective-C eras in the isolated
  `.agent-tmp/msys2-objc` (upstream's packages), the C++ era in Jon's MSYS2 (scoop), where `develop`
  builds; no step's `install_deps.sh` is run during verification, so no package changes. Clang and
  GCC get separate worktrees (`.agent-tmp/series-verify`, `-gcc`) since `mk.sh` fixes the build
  directory name. The era is the Windows build's: `src/meson/darwin/` (still SpiderMonkey until
  macOS is converted) is ignored. Eras: 1-3 `objc-spidermonkey`, 4-16 `objc-quickjs`, 17+ `cxx`.
- Found at T020: the history's source comments carry bead ids and ADR numbers (e.g. `src/meson.build`
  "bead oo-7wx", root `meson.build` "oo-pdsng, proposed ADR-0066"). FR-017 covers messages and
  descriptions only; scrubbing code comments is a code change, so it is left for T032 (polish) as
  a candidate, not done silently.
- T018 review findings (description agents, 2026-11-01), with the default taken:
  - Titles that overpromised were corrected in `chapters.py` (step 1: no goldens or JS API snapshot
    in the game tree; step 6: `OOCollectionExtractors` survives it; gnustep-base is dropped in step
    10, not 9).
  - Step 19's `test_builds.yaml` resolution took the history's side whole and so undid upstream #782
    (Fedora AppImage removed) and #766's macOS job; to fix by keeping upstream's side of both hunks.
  - Steps 12-18 carry upstream's Objective-C copy-URL methods in C++ files (`OOOXZManager`,
    `PlayerEntity`): the planned C++ port at T023; then reword 019's #747 bullet.
  - Tests cited by descriptions but registered in no `meson.build` (`test_enumeration_shuffle.c`,
    `test_jsengine_*.cpp`, `tests/unit/expander`, `tests/unit/sysdesc`): named as unwired in the
    descriptions; registering them is a test addition, left as a candidate for T032.
  - Step 16's generated tables come from generators that live outside the game tree; the description
    says to sample rows by hand. Default: no generator is added to the series.
  - From step 4 the build fetches QuickJS-ng through `subprojects/quickjs-ng.wrap` (network at
    configure time); described, not changed.
- T023 (2026-11-01), decisions taken while verifying:
  - Clang 23 warns about constructs the history built past with an older compiler (variable-length
    arrays in C++, C++20 enum/float arithmetic, set-but-unused globals, string literals as `char*`).
    FR-003 asks for none and rule 2 forbids silencing, so each step gets the fix in the form the
    history itself reaches later, carried forward by the merges. Kept upstream bugs stay kept (the
    HDR brightness not-found branch that never runs: the comparison is made explicit, as the history
    does).
  - The normaliser N sorts includes (upstream's .clang-format) in `.m`/`.mm` files too, which upstream's
    CI does not check. Where an include depends on order (OOJSShipGroup.h at step 4, main.mm at step 5)
    the order is restored by a stored resolution, the needed header in a block of its own. N itself is
    unchanged: changing it would invalidate every stored resolution.
  - Build fixes the history made later are brought forward where an earlier step first needs them:
    `ar = 'llvm-ar'` in clang.ini (LTO archives, step 4), llvm-tools in the Windows dependency script,
    the Windows threads override for QuickJS-ng, a 0.16.2 wrap patch for its void-return warnings
    (develop has the 0.17.0 one).
  - The automatic merge's "upstream deleted the block" rule now conflicts instead of dropping a line
    the history adds inside or at the edge of the block (a reorder reads as a deletion). Every
    remaining use of the rule was checked.
  - The isolated MSYS2 gained `mingw-w64-ucrt-x86_64-llvm-tools` (llvm-ar), as the history's
    dependency script installs.
  - The normaliser N formats `src/` only (research R3 named `src/` and `tests/`): upstream has no C or
    C++ test sources to align with, and its include sorting broke an order-dependent test
    (`tests/unit/oofnd/test_objc_ref.mm`). Every step's `tests/` is now the history's byte for byte,
    apart from upstream's own two scripts, merged cleanly.
  - From step 8 the history's own code carries warnings (the history built its middle steps with them):
    hidden instance variables, an unnamed selector part, a definition whose parameter type disagrees
    with its declaration (a real mismatch). FR-003 is kept as written: they are fixed, in the
    history's later form where there is one (its step-9 local names; the declared parameter type), or
    minimally (a new local name). The unnamed part of -cxx_getContainersOfCommodity:: becomes
    how_much:, upstream's own label, for steps 8-15 (clang-format will not let a space fix a header).
  - Test sources get the normaliser's transform (upstream's #745 selector and #737 include renames)
    but no formatting: the history's tests call the history's API names, which the series renames
    as upstream did, and a test changes only as far as that rename requires (the history makes the
    same rename itself when it pulls #745 at step 19).
  - Upstream's copy-URL state (#747) becomes std::optional<std::string> at step 10, where NSString
    goes; its methods become members at step 12.
  - The history's scripting unit tests (steps 11-16, and as C++ until 19) declare stub entity classes
    and include only the scripting header. Upstream's #748 imports the entity header in seven of
    those headers (OOJSDock/Sound/Player/Station/Planet/Waypoint/Wormhole.h), which defines each class
    twice; the import goes at step 11 (each header forward-declares the class). At step 17 the
    history's C++ headers drop #748's other four such imports, as the history's own port of #748 at
    step 19 does, and the second #pragma once (upstream's and the history's) goes everywhere but
    vendored miniz.h.
  - FR-003 against hard rules 1 and 2: Clang 23 warns in a few of the history's own unit tests
    (unused stand-ins and finalizer counters, steps 11-18). The tests are not edited and nothing is
    silenced; each warning is listed in series/test-warnings.md with its step range, and verify
    passes a step whose only warnings are listed ones in files under tests/ (the record counts
    them). Any other warning still fails. Game-code warnings of the same kind are fixed in the
    history's later forms (step 11: the texture trace context, the Manifest prototype).
  - Step 12 carries upstream code into the history's C++ view in its terms: #774's splash-window
    replacement calls the C++ createWindowWithSize (ported here, not deferred), #747's common
    display functions lose the history's Windows guard, #766's mouse pixel density reads the C++
    view's window. The bounding-box selector (#745 named its parts; the normaliser's table has no
    entry) uses the history's spelling in step 12's call, which the history's OOMesh bridge declares.
  - #744's dark-mode removal waits for the history (steps 12-18): the history's view test calls
    isDarkModeOn until its own port of #744 at step 19. A test that exercises code upstream removed
    keeps that code until the history drops the test; the deferral is listed in series/deferred.md.
