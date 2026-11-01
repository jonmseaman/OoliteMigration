# Plan: split the C++ migration into an upstream PR series

## Context

`oolite-dev/develop` differs from `OoliteProject/oolite` master (`49a5eb9fc`) by **1,137 files,
+335k / −182k lines**. Almost all of it is one squash, `935aedb20 Migrate Oolite from
Objective-C/GNUstep to C++ (phases 1-4)` (1,041 files). Nobody can review that as one PR. The goal
is a series of PRs, each small enough to review in one sitting, each saying what it is, and each
checked by a tool rather than only read.

**Every PR's content comes from the code in `oolite-dev`.** The series is a partition of the
`develop` tree. It isn't a replay of the old phase history (no bridges, no `.mm` stage) and it
isn't ObjC back-ports. The last PR's tree is byte-identical to `develop`. The base is `develop`
once the upstream-sync epic (`epic/upstream-sync-49a5eb9fc`, 14 commits ahead) has been merged,
so the series starts from upstream's current `master`.

The only content not copied from `develop` is the build glue each intermediate step needs (a
meson option, test lists) and one tool-generated reformat of upstream's ObjC (Tranche 1.2).

What makes the diff bigger than it needs to be (measured):

| Noise | Size | How the series handles it |
|---|---|---|
| `13eb19ee7` Google-style reformat | 668 files, ±250k; it roughly doubles each file's diff against its `.m` (ShipEntity 9.6k → 24.9k changed lines, OOColor 391 → 723) | Keep Google style (Jon's decision). First reformat upstream's ObjC tree to Google, in its own mechanical PR. Every conversion PR then compares Google-ObjC with Google-C++. |
| `.m` deleted + `.cpp` added (259 deleted / 275 added; git detects only ~20 renames) | GitHub shows whole-file adds; blame breaks | In each PR, a pure `git mv X.m X.cpp` commit comes first, then the content from `develop`. The diff then shows in place and history follows. |
| Tests | ~110k lines under `tests/` | They go ahead of the code they cover, or in the same PR (below). |

Upstream CI builds **Linux, Windows and Apple Silicon macOS** (#766) with ObjC, and the fork has
only been proven on Windows. So the final switch can't merge upstream until Phase 5 (macOS +
Linux) is done. Everything before it can be reviewed now.

## GitHub stacked PRs: yes for the conversion, but only with branches in upstream

GitHub's native stacked PRs (public preview; `gh stack` CLI, GitHub CLI ≥ 2.90) fit the conversion
tranche well. Each layer shows only its own diff, the stack shows the order, and merging the
bottom layer retargets the next one. **But all branches in a stack must be in the same repository.
Cross-fork stacks are not supported.** Jon has `pull` only on `OoliteProject/oolite` (checked with
`gh api`), so a stack can't be opened from `jonmseaman/oolite`.

So:
- **Tranches 1–2** (independent PRs to `master`): ordinary fork PRs, no stack. Each one stands
  alone, so up to 2–3 can be open at once.
- **Tranche 3** (the conversion): the RFC asks the maintainers for one of two things:
  1. *Preferred:* a ruleset that lets Jon push `cpp/*` branches in `OoliteProject/oolite`, or a
     maintainer who pushes the series branches. Then it is a native stack with
     `cpp-migration` at its base.
  2. *Fallback, no access:* a queue. Tranche 3 PRs go one at a time from the fork into the
     upstream `cpp-migration` branch, and the next opens when the previous merges. The full
     series stays visible as a native stack inside the fork (same repo, so it is supported) for
     reviewers who want to read ahead. Comments that count go on the upstream PR.
     **No auto-retarget across the fork boundary.** A fork stack's PRs target fork branches, so
     merging them merges into the fork. Each upstream PR is a separate fork → upstream PR,
     outside any stack. After one merges upstream:
     - with a merge or rebase merge, the next PR's diff shrinks to its own changes by itself;
     - with a **squash** merge (the usual upstream default), the next branch still carries the
       old commits. The generator then rebuilds it on the new upstream tip, and Jon force-pushes
       that fork branch.

     The RFC asks for merge commits on `cpp-migration` so this isn't needed.
- **What can go to `master` one PR at a time:** only Tranches 1–2 and the final Tranche 4 merge.
  A Tranche 3 PR on `master` would break the ObjC game (converted headers replace ObjC ones), so
  Tranche 3 needs a branch in upstream. Only someone with push access can create it.
- Locally, the branches are built by the generator (below). `gh stack` or git town (already Jon's
  push method) can keep them rebased. Agents never push (hard rule 4).

## Landing model: put to the maintainers in the RFC (Jon's decision)

The prepared default is: Tranches 1–2 on `master`, Tranche 3 stacked or queued into a
`cpp-migration` integration branch, Tranche 4 merges it after Phase 5. If the maintainers insist
that the game run on `master` at every step, that needs ObjC↔C++ bridge code that isn't in
`oolite-dev`. That would be a new plan, not this one.

## Tranches

### Tranche 0 — RFC (one issue/discussion, no code)
It contains the write-up (`notes/Phase 4 Writeup.md`) and this outline with its PR count. The
asks: (1) the integration branch and the push access above; (2) agreement that QuickJS-ng
replaces SpiderMonkey; (3) switching `.clang-format` from WebKit (adopted in #749/#751) to Google,
with CI's clang-format job following. If they refuse (3), stop and re-plan the formatting with
Jon; don't silently reformat `develop`.

### Tranche 1 — on `master`, no change to the ObjC game's behaviour (~6 PRs, plain fork PRs)
1. **Test harness**, taken as it is from `develop`: `tests/run.sh` + smoke
   (`tests/launch_snapshot.py`); the component tier (`tests/component/features/`, split s1–s4,
   s5–s8 + t1); the GUI tier (`tests/gui`). A test goes in only if it passes against the ObjC
   build. The ones that need the C++ build (e.g. a debug-console command only C++ has) wait for
   Tranche 4. The generator's gate decides which, not judgement.
2. **Formatting**: `develop`'s `.clang-format` (Google), plus a `Language: ObjC` section, applied
   to upstream's ObjC tree in one commit listed in `.git-blame-ignore-revs`. To verify it, rerun
   clang-format and expect an empty diff; upstream CI must stay green.
3. Editor/tooling files from `develop` that apply as they are: `.editorconfig`, clangd /
   compile-database setup, `.clang-tidy`.

### Tranche 2 — new libraries on `master`, built and tested, not yet used by the game (~8 PRs)
Files come from `develop` as they are, behind a meson option that is off by default; CI runs
their unit tests.
- **`oofnd`** (`src/oofnd`, 12k lines + `tests/unit/oofnd`), split by layer:
  `Ref`/`Expected`/`StdLib`/`String`/`Encoding` → `Data`/`Date`/`Scanner` → `PList*` (parsing,
  old-style, XML, writing, description, `PListGet`) → `FileSystem`/`ResourcePaths`/`Defaults` →
  `Log`/`LogFile`/`Exception` → `Thread`/`Notification`/`WeakSet`/`Process`/`Http`; plus
  `oofnd/objc` (`OOAssert`, `OOObject`, types).
- **`ooscript`** (`src/Core/Scripting/ooscript`, 5k lines) + `subprojects/quickjs-ng.wrap` +
  `tests/unit/test_jsengine_quickjs.cpp`.

### Tranche 3 — the conversion (~60–90 PRs, stacked or queued into `cpp-migration`)
On the integration branch the ObjC game target is off: converted headers replace the ObjC ones,
so a half-converted tree can't link the game. Instead, each PR has to pass **its own classes'
unit tests**, built from C++ objects only. `tests/unit/core/meson.build` already links each test
against only the objects its class needs.

- **Order = link-dependency order**, computed from the current code: the `core_tests` object
  lists in `tests/unit/core/meson.build` plus undefined symbols per object (`nm` over a `develop`
  build). The result is a DAG of strongly connected components. Leaves come first: maths
  (`OOVector`, `OOMatrix`, `OOQuaternion`, `legacy_random`), `OOColor`, caches, MiniZip and the
  other C → C++ files, sound, joystick, OXP verifier stages, GL state/extension managers,
  textures, materials/shaders, HUD/GUI, ….
- **The "knot"**: the classes whose tests use `['*']` (Entity, ShipEntity, PlayerEntity, Universe,
  GameController, the OOJS* classes that need a live universe) form one cycle that only builds as
  a whole. It goes as a run of PRs (stack layers) where only the top one builds; the layers below
  it are reviewed as diffs. The giant files (ShipEntity 14k, PlayerEntity 14k, Universe 12k lines)
  are split along their existing split files (`ShipEntityAI`, `ShipEntityLoadRestore`,
  `ShipEntityScriptMethods`, `PlayerEntityControls`, …). Within a file, it is split into commits
  by method range: commit k replaces the first k ranges of the `.m` with `develop`'s content.
- **What each PR contains:** commit 1 `git mv` of the cluster's `.m` files; commit 2 the
  `develop` content; commit 3 meson + unit tests. The description lists the classes, gives the
  matching `docs/parity/<area>.md` entries as the review checklist, and lists the known
  differences that were kept on purpose.
- **Size:** at most ~4k changed lines per PR; the generator flags any that are bigger.

### Tranche 4 — cutover (3–4 PRs, after Phase 5)
1. `develop`'s top-level build: the game is built from C++; the ObjC/GNUstep build, Foundation
   and SpiderMonkey (`build_mozilla_js.sh` etc.) are gone; the remaining component + GUI tests are
   added.
2. The whole-game tests (the remaining `['*']` ones such as `test_OOJSShip`).
3. Docs from `develop`: the README build sections, plus `EXPANSION_MIGRATION.md` and the known
   differences from OoliteMigration's `docs/`.
4. Merge `cpp-migration` into `master`: no new code; every line has already been reviewed.

## Producing the series

- **Generator** `tools/upstream-series/` in OoliteMigration (new). It reads `series.yaml` (per PR:
  title, paths, tests, description, the glue to add) and builds `series/NN-<slug>` branches in
  `oolite-dev`, in order. Each branch is the previous one plus those paths checked out from
  `develop`, with the `git mv` commit first. It prints each PR's changed-line count and runs that
  branch's gate.
- **Clustering script** (part of the generator) for Tranche 3's order, as above.
- When `develop` moves (monthly upstream sync via `tools/upstream-delta.sh`, or parity fixes),
  regenerate the series from the new `develop` rather than hand-editing branches. Branches already
  merged upstream stay fixed; later ones are rebuilt.
- One beads epic, one bead per PR; each bead's acceptance command is its branch's gate. Jon
  pushes and opens the PRs.

## Verification

- **The series is `develop`:** `git diff series/<last> develop` is empty. The generator checks
  this at every regeneration.
- **Each branch passes its gate.** Tranches 1–2: the ObjC game builds and upstream CI is green on
  all three platforms, plus their new tests. Tranche 3: `meson test --suite oofnd,core` for the
  tests that branch adds, on Clang and GCC. Tranche 4: `tests/run.sh all`.
- **`develop` itself** passes `tests/run.sh all` on Windows (Clang + GCC), and after Phase 5 also
  on macOS and Linux.
- **Formatting PR:** rerunning clang-format gives an empty diff, and the Tranche 1 tests pass on
  the ObjC game before and after.
- **Stacks:** dry-run the Tranche 3 stack with `gh stack` inside `jonmseaman/oolite`. Confirm that
  each layer's diff shows only its own files, and that merging the bottom layer retargets the
  next one.

## Sources

- [GitHub Docs: stacked pull requests](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests)
  (same-repository only; cross-fork stacks unsupported)
- [gh stack](https://github.github.com/gh-stack/)
