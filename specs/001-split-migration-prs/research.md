# Research: split the C++ migration into a PR series

Measured on 2026-11-01. Commit ids are OoliteMigration's for the history and `oolite-dev`'s for the game.

## Facts found

| What | Measurement |
|---|---|
| History span | `4f089047c` (subtree added at upstream `dc55e3e05`, squashed) … `338463308^` (last subtree state) |
| History size | 1,935 non-merge commits touching `upstream/oolite/` (1,400 first-parent); 1.31M changed lines of churn, against a net diff of 1,118 files, +374k/−261k |
| Cadence | W37 5 · W38 89 · W39 787 · W40 494 · W41 466 · W42 64 · W43 29 commits |
| Upstream under the history | `dc55e3e05` until `4c2bfae9f` (2026-10-25: subtree pull of 13 upstream commits to `9ee8ff22f`; `src` kept as it was, then ported by hand) |
| Upstream under `develop` | `49a5eb9fc` (merged in `7912222ed`); 23 upstream commits after `dc55e3e05`, 519 `src` files, almost all from #749 (a clang-format reformat of the whole tree) |
| Upstream now | `7437f22a5` (#780, "engine-neutral JavaScript names outside the scripting layer"), one commit past `49a5eb9fc` |
| End of history vs the squash | `338463308^:upstream/oolite` vs `935aedb20^{tree}`: 6 files, +17/−101 |
| Eras by file counts | 09-15: 242 `.m` · 09-25: 0 `.m`, 282 `.mm` (the `.m`→`.mm` switch, `d1ec3b0856`, 09-22) · 10-15: 228 `.mm`, 14 `.cpp` · 10-20: 1 `.mm`, 224 `.cpp` |
| Landmarks | tests tier `f43a842f4b` 09-11 · QuickJS-ng `d0847dd50a` 09-19 · ooscript façade `a7a0059c55` 09-22 · `oofnd` `46cfe30741` 09-22 · facades deleted 10-09…10-18 · no libobjc headers `18c1e782b2` 10-20 |
| Largest commits | 52 commits are over 3,000 lines and carry 749k of the 1.31M. The largest is `3003adb7d5` (446k, the clang-format of the C++ tree); then facade deletions (`8489f99143` 20k, `49ef090d11` 18k), the ooscript façade (`a7a0059c55` 11k), and slice conversions of 5–9k each |
| Messy commits | 24 "uncommitted work harvested by beads-worker" commits; subjects carry bead ids throughout |
| Toolchain here | Clang 23.1.4, clang-format 23.1.4, GCC (scoop), MSYS2 `gnustep-base-1.31.1+7a5990974`, `libobjc2-2.3`, SpiderMonkey `libjs32ECMAv5`, Python 3.14, Git Town 24.0.0 (main branch `develop`), no `git filter-repo` |
| Objective-C build here | **Fails** for both `dc55e3e05` and the series base `49a5eb9fc`: GNUstep's `NSBackgroundActivityScheduler.h:80` puts `__block` on an ivar, which Clang 23 rejects. Upstream CI installs the latest `OoliteProject/oolite_windeps_build` packages via `ShellScripts/Windows/install_deps.sh` |
| CI clang-format | `clang-format-version: '22'` (`jidicula/clang-format-action`) |

## Decisions

### R1. Steps are target trees, not replayed patches

- **Decision:** Each step is defined by the tree it must end with. Step *k*'s tree comes from the
  history snapshot at its cut, carried onto the series base (R4). The branch is one commit whose
  tree is that target and whose parent is the previous step.
- **Rationale:** The history has 1.31M lines of churn for a 635k net change: slices were converted,
  facades added and then deleted. Diffs between snapshots cancel churn inside a step for free.
  Absolute trees make hoisting, regrouping and re-anchoring cheap: changing one step only changes
  the diffs of its neighbours. One commit per step also matches Jon's squash merges.
- **Alternatives:** cherry-picking each history commit (1,935 commits, the churn shown to
  reviewers, and conflicts on every one); `git subtree split` (keeps every commit and the upstream
  pull merges, so it is no better than the old branches); rebuilding steps by hand from the final
  tree (throws away tested intermediate states).

### R2. Read the history in place

- **Decision:** `git -C oolite-dev fetch .. 338463308` brings OoliteMigration's objects into the
  submodule. Then `<commit>:upstream/oolite` is a tree id usable directly in `oolite-dev`, which maps
  the paths with no rewriting.
- **Rationale:** no `filter-repo` needed and nothing is copied; read-only on the history.

### R3. Normalise formatting before comparing

- **Decision:** A normaliser N formats `src/**/*.{h,m,mm,c,cpp}` with clang-format **22** (CI's
  version, from the `clang-format` PyPI wheel in `.agent-tmp/series-venv`) and the `.clang-format`
  of the upstream commit underneath. It is applied to the history snapshot and to the upstream
  base of the merge, never to upstream's own tree, which is already formatted (#749).
- **Rationale:** Upstream reformatted the whole tree (#749) after the history branched, and the
  history's own reformat (`3003adb7d5`, 446k lines) came at the very end. Without normalising, every
  step conflicts on every file. With it, only real edits remain, and each step should pass
  upstream's clang-format check.
- **Alternatives:** the local clang-format 23 (its output differs from CI's 22); `git merge -X
  ignore-space-change` (doesn't cover brace and wrap changes).
- **Risk:** clang-format can make different choices on ObjC than #749 did. The merge rule in R4 takes
  upstream's file wherever the history did not change it, so this only affects files the step
  changes anyway.

### R4. Carry each snapshot onto the series base by a 3-way merge

- **Decision:** For step *k* with cut `c`, let `B` be the upstream commit under `c` (`dc55e3e05`, or
  `9ee8ff22f` from `4c2bfae9f` on). Then
  `T_k = merge3(base = N(B), ours = 49a5eb9fc + hoisted fixes, theirs = N(H_c))`
  (`git merge-tree --write-tree`). Files the history did not change take upstream's version. The
  conflicts are where upstream and the migration both edited a file, for real (about 30 files from
  #369, #737, #740, #742, #744, #745, #747, #748, #756, #758, #765, #766, #774, #781). They are
  resolved once and stored as patches under `series/resolutions/NNN/`, with `git rerere` enabled so
  that identical hunks resolve themselves in later steps. The end state of every resolution is
  known: `develop`, where those upstream changes were already ported into C++.
- **Rationale:** reviewers see the migration on top of today's upstream, not a revert of
  upstream's last two months.
- **Alternative rejected:** base the series on `dc55e3e05` and port upstream at the end. Every PR
  would conflict with upstream `master` (#749 alone touches 519 files), so the PRs could not be merged.

### R5. Verification by era

- **Decision:** Three eras, each with its own matrix:
  | Era | Steps | Build | Tests |
  |---|---|---|---|
  | `objc-spidermonkey` | up to the ooscript façade over QuickJS | Clang, upstream-matching GNUstep + SpiderMonkey | suites present in the tree; smoke |
  | `objc-quickjs` | until the game builds without libobjc | Clang, upstream-matching GNUstep | unit, smoke, the component scenarios touched |
  | `cxx` | from `18c1e782b2` on | Clang **and** GCC | unit, smoke, the component scenarios touched |
  The GCC rule: *no step may break a compiler its parent builds with*. GCC is required from the
  first step whose parent builds with GCC.
- **Rationale:** upstream itself builds Objective-C with Clang only (GNUstep's runtime), so "Clang
  and GCC on every branch" (spec FR-003 as first written) is impossible before the C++ era. Spec
  FR-003 is amended to say this.
- **Environment (gate G0):** the Objective-C eras need the packages upstream CI uses, and this
  machine's are older. Default: a **second, isolated MSYS2** under `.agent-tmp/msys2-objc/`
  (inside the workspace, rule 9), set up with upstream's `install_deps.sh clang`. Jon's MSYS2 is not
  touched. Fallback if that fails: the fork's GitHub Actions (upstream's workflows) on the pushed
  branches, which is Jon's step. The Objective-C steps are then marked verified by CI with the run
  URL. Recorded in plan.md's notes.

### R6. Cutting the history into steps

*Superseded in part by R13: cuts are made at chapter boundaries first. The size rule below applies
only inside a chapter.*

- **Decision:** Walk the first-parent history in order and cut greedily. Each step's **counted**
  size is the normalised diff from the previous cut, without vendored paths (`subprojects/`),
  generated data (test goldens and snapshots, named in the manifest), pure renames, and whole-file
  deletions. The tool cuts before a commit that would take the step over 3,000. It prefers cuts at
  landmarks (R-table) and at batch boundaries ("batch X", "slice N" ranges are kept whole where
  they fit). A commit that is over the limit by itself becomes its own step with `oversize_reason`.
  A cut that does not build moves forward to the next commit that does.
- **Interpretation recorded:** pure renames and whole-file deletions count as mechanical inside a
  hand-written step. The reviewer's check is "the file is gone or renamed", not reading it.
  Without this, a conversion step counts the C++ it adds *and* the Objective-C it deletes, which
  roughly halves the usable limit.
- **Expected scale:** on the order of 100–200 steps. The real number comes from `cut`, which writes
  it to plan.md's notes. If it exceeds 200, the default is to keep the limit: the spec's limit is
  what makes each PR reviewable, and the cost of more PRs is clerical.

### R7. Hoisting independent fixes

- **Decision:** `inventory` flags candidates: commits touching only non-migration code (determinism,
  `OO_RANDOM_SEED`, bug fixes found by tests, header fixes) that `git apply --3way` onto
  `49a5eb9fc` and that build there. Each accepted candidate becomes an `independent` step at the
  front. Its effect is merged into every target tree up to its original position. Candidates that
  don't apply cleanly stay in place, as hand-written.

### R8. Git Town lineage without `develop`

- **Decision:** `series/000-upstream-base` is a local branch at `49a5eb9fc`, registered as a Git Town
  **perennial** branch (repo-local config) so Git Town treats it as a root. Each step is created from
  its parent with `git town append series/NNN-slug --prototype --no-sync --no-push`. Prototype
  branches are local-only, a second guard against pushing. After a renumber or rebuild, the tool
  uses `git town set-parent`. The check compares `git config git-town-branch.<b>.parent` with the
  manifest.
- **Rationale:** Git Town's main branch in `oolite-dev` is `develop`; appending from it would put the
  fork under step 1.

### R9. Verifying in order, incrementally

- **Decision:** One shared verification worktree at `.agent-tmp/series-verify/` (created with MSYS
  git and removed with `git worktree remove`, never `prune` from Windows git), with one build
  directory per compiler. Each step is checked out in turn and rebuilt incrementally with ninja. A
  clean build runs at each era's first step and at the last step.
- **Rationale:** consecutive steps differ little, so incremental builds turn hours into minutes.

### R10. The tail after the history

- **Decision:** After the last history step come `develop` steps. These are the squash's 6-file
  gap, then `develop`'s non-merge first-parent commits after `935aedb20` (the
  upstream merge `7912222ed` is already in the base, and its port commits `f80c74210`, `a1e2ce889`,
  `ac193cfe7` become steps). The reformat to Google style (`13eb19ee7`, `21c3048a2`) is one
  `mechanical` step. Last comes a `reconcile` step only if the tree still differs from `3aa8d65e8`
  outside exclusions.
- **Exclusions (default, conservative: only clearly fork-only):** `.zed/`, `.vscode/`, and the fork's
  CI branch filter (`3aa8d65e8`). Everything else in `develop`, including `tests/`, `.clangd`,
  `.clang-tidy` and `.editorconfig`, is offered upstream. The PR descriptions name the optional
  pieces.

### R11. Hard rules that need an interpretation here

- **Rule 6 (no `libgnustep-base` or `JS_*`):** the series base *is* upstream, which has both, so the
  early steps necessarily contain them. Interpretation: no step may **add** a GNUstep or SpiderMonkey
  dependency that its parent lacks, and the last step must have none (it equals `develop`). QuickJS
  also uses `JS_` names, so the check is for SpiderMonkey headers and libraries
  (`jsapi.h`, `mozjs`, `js32ECMAv5`), not the prefix.
- **Rule 1 (tests):** the construction never edits a test. A test change in a step must come from
  the history or `develop` commit it carries. The check flags any test-file difference between a
  step's tree and the history snapshot it was built from.
- **Rule 2 (warnings):** the construction adds no `-Wno-*` or `#pragma … diagnostic`. The check
  flags any such line not present in the history snapshot or `develop`.
- **Rule 3 (never push):** prototype branches plus the tool never invoking push, sync or propose.

### R12. Re-anchoring on newer upstream

- **Decision:** Build and verify on `49a5eb9fc`, the base `develop` is proven against. When Jon is
  ready to open the series, re-anchor on upstream's tip (now `7437f22a5`, #780) by changing
  `upstream_base` and rebuilding. R1 and R4 make that one command plus new resolutions for #780,
  which touches JavaScript naming and so will conflict with the ooscript steps.

### R13. Split by phase and work item ("chapters"), not by line count alone

Measured 2026-11-01 with the archived bead export (`git show 0c07daef7^:.beads/issues.jsonl`,
1,860 beads; the five phase epics are `oo-1bf` P0, `oo-1gc` P1, `oo-3rb` P2, `oo-9ht` P3 and
`oo-6e1` P4). Work items come from `archive/phase-0-4-docs:docs/phases/{0..4}-*.md`. Scripts are in
`.agent-tmp/001/`.

**What the history looks like:**
- Each of the 1,400 first-parent entries is one bead merge. **Phases are contiguous** in that order:
  P0×41 → P1×~60 → P2×774 → P3×461 → P4 (plus 60 late unlabelled fix-ups), with a handful of
  stragglers. Every phase boundary is a snapshot that was built and tested at the time.
- **Inside a phase, work items interleave**, because parallel workers merged whatever was ready.
  By module, P2 has 533 runs in 774 merges and P3 has 245 in 461. Regrouping strictly by work item
  would move a merge past a later merge touching a shared file for 56–61% of P2 and 77–86% of P3
  (`commute.py`). Those intermediate states never existed, so each would need its conflicts
  resolved and its build re-proved.
- **But there are waves.** In time order, P3 runs as leaf/oomath/OXPVerifier conversions →
  Scripting/Entities/audio/Materials conversions → slice plans and `ShipEntity` slices →
  `Universe`/`PlayerEntity` slices → facade-deletion batches → the root `Entity` facade. P2 runs as
  the `.m`→`.mm` switch → the `oofnd` core → Foundation sweeps → selector families → dropping
  gnustep-base. P1 runs as façade and retargeting → QuickJS backend → deleting SpiderMonkey.
- Net size per phase, as one PR each (src non-test lines counted / test lines): P0 0.5k/13.6k ·
  P1 25.6k/0.9k · P2 95k/13k · P3 119k/79k · P4 plus the tail 354k/8k. The last figure includes the
  446k-line reformat and the `.mm`→`.cpp` renames; normalising (R3) removes most of it.

**Without the history (split the final tree directly):** 75% of `develop`'s `src` (232 of 306
units, 210k lines) is **one strongly connected include component** (`scc.py`). Without the
history's Objective-C/C++ bridges, those files can't build in parts. A history-free series is
therefore some additive PRs that build on their own (the test tiers, `oofnd` as a library with its
unit tests, QuickJS-ng as an unused subproject, tooling and format config, the independent fixes),
then **one ~210k-line flip PR** that replaces the core. Splitting that flip means writing new
bridges, which is redoing the migration.

**Options compared:**

| | A. Size only (R6 as first written) | B. Chapters (phase/work item) | C. No history | **D. Chapters, split by size inside** |
|---|---|---|---|---|
| PRs | ~100–200 | ~20–25 | ~8 + 1 giant | ~20–25 chapters, ~60–120 PRs |
| Every step a tested snapshot | yes | yes (cuts at wave boundaries) | additive ones yes; the flip is one big step | yes |
| Reviewer can see why a PR exists | weak (arbitrary cuts) | strong (maps to the phase docs) | strong for additive, none for the flip | strong |
| Largest PR | ≤3k counted | 20–60k | ~210k | ≤3k counted, except whole-commit outliers |
| Conflict work | R4 only | R4 only | low (taken from the final tree) | R4 only |
| Fidelity to how it was done | high | high | none | high |

**Decision: D.** Cut first at chapter boundaries: the first-parent position closest to each
work-item transition listed below. The range stays contiguous, so no reordering, and every cut is a
historical snapshot. Inside a chapter, split at merge boundaries with the R6 size rule. Allowed
reordering is limited to (1) hoisting independent fixes (R7) and (2) the P0 test-tier additions,
which are new files and commute; both are re-proved by building. PR titles carry the chapter
(for example "Phase 3 · ShipEntity slices (2/5): …"), and each chapter's first PR explains the chapter.

Initial chapter list (boundaries to be fixed by `cut --chapters` against the waves):

| Ch | Phase · work item |
|---|---|
| 0a | Independent fixes: iteration-order determinism, `OO_RANDOM_SEED` (hoisted) |
| 0b | Safety net: goldens and the JS API snapshot; GUI tier; component tier |
| 1a | JS façade (`ooscript`), call sites retargeted, SpiderMonkey still underneath |
| 1b | QuickJS-ng backend; switch |
| 1c | Delete SpiderMonkey and NSPR |
| 2a | `.m` → `.mm` (Objective-C++), one mechanical step |
| 2b | `oofnd` core (`Ref`, `PList`, typed accessors, strings, `FileSystem`, `Defaults`, logging) with unit tests |
| 2c | Foundation → `oofnd` sweeps, in the doc's module order as far as the waves allow |
| 2d | Selector families |
| 2e | Drop gnustep-base |
| 3a | Leaf, oomath, OXPVerifier conversions (house style from `OOColor`) |
| 3b | Scripting, Entities, audio and Materials conversions |
| 3c | Slice plans and `ShipEntity` slices |
| 3d | `Universe` and `PlayerEntity` slices |
| 3e | Facade-deletion batches |
| 3f | The root `Entity` facade |
| 4a | Deferred release (`AutoreleaseScope`) |
| 4b | Objective-C runtime out: root classes, `@try`, `@selector`, `@encode`, `#import` |
| 4c | `.mm` → `.cpp` rename (mechanical) and the GCC build |
| T | Tail (R10): upstream ports, source hygiene, format |

Where waves overlap (3c–3e interleave on 10-05…10-09), the chapter takes the contiguous range and
says in its description which work items it mixes. Default: no reordering to purify a chapter.
