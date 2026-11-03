# Research: `seriesb/*`, the PR series on upstream #767/#768

Measurements were taken on 2026-11-02 in `oolite-dev`, with the upstream PR heads fetched into
`refs/upstream-pr/{767,768,772}`. The probe merges are `git merge-tree --write-tree` with a 30%
rename threshold, the same as feature 001's R15. They write no branches. Their conflicted-file
lists are in `.agent-tmp/probe-*.txt`.

## R1. What the parents are

- **Decision**: there are two parents.
  - `seriesb/000a-upstream-767-quickjs-option` = `hobleyd/oolite` `quickjs-poc` (#767), head
    `3758f8a09`.
  - `seriesb/000b-upstream-768-quickjs-only` = `hobleyd/oolite` `quickjs-default` (#768), head
    `db4920103`.
- **Rationale**: `git merge-base --is-ancestor` confirms #767 ⊂ #768. Both fork from upstream
  `master` `7437f22a5`, which `develop` already contains (#780). #772 (`test-harness`) is based on
  `52117591f`, is not stacked on #768, and GitHub reports it as conflicting. It stays out (spec
  Assumptions).
- **Alternatives**: a single parent at #768 would hide the #767/#768 boundary that upstream
  reviews as two PRs. It was rejected because Jon's sketch has two parents.

## R2. Git Town branch types and the sync command

- **Decision**:
  - **Parents** are **observed** branches. Each tracks its PR branch through a new remote `hobleyd`
    (`https://github.com/hobleyd/oolite.git`, fetching `quickjs-poc` and `quickjs-default` only).
    Lineage: `000a` → parent `develop`, `000b` → parent `000a`.
  - **Steps** are **prototype** branches, as in feature 001, created with
    `git town append --prototype`.
  - **The sync command** is `git town sync --stack --detached --no-push`, run from any `seriesb`
    step.
- **Rationale** (from `git town observe --help` and `git town sync --help`, Git Town 24.0.0):
  - On an observed branch, sync "pulls down updates from the tracking branch (always via rebase),
    does not push, does not pull updates from the parent branch". So `develop` never flows into
    `000a`/`000b` (FR-003). A parent has no local commits, so rebasing it onto its tracking branch
    leaves it equal to the PR head (FR-002).
  - Prototype branches merge their parent in (the repo's `prototype sync strategy: merge`) and are
    never pushed.
  - `--detached` ("don't update the perennial root branch") keeps sync from pulling, pushing or
    upstream-syncing `develop` (hard rule 3). Without it, sync also syncs the root.
  - `--no-push` is belt and braces (hard rule 3).

  This is Jon's `git town sync --stack` with the two flags that keep it inside the rules. Jon may
  run it bare from his own shell; agents always add both flags.
- **Not yet observed**: a scratch-repo probe of this exact setup was denied by the permission
  classifier in the planning session, because it pushes to local bare repos. Task T002 repeats it
  inside `.agent-tmp/` (local bare repos only, no network) and must pass before any real branch is
  created. If observed parents misbehave, the fallback is **contribution** branches with
  `push branches: no` for the seriesb branches, then perennial parents updated by a fetch-and-reset
  helper (`series.py follow`). The fallback is recorded in Notes if taken.
- **Alternatives**:
  - Perennial parents: perennial sync pulls and pushes, and Git Town gives perennials no parent,
    which breaks the `develop` → … tree Jon drew.
  - Tracking `upstream`'s `refs/pull/N/head` instead of a `hobleyd` remote: a pull ref is not a
    branch, so Git Town can't treat it as a tracking branch.

## R3. How a step is built: replay of the old step

- **Decision**: the steps are built by replaying the old ones (`source.type = "replay"`). Step *k*'s
  tree is a 3-way merge with:
  - base = the old parent's tree (`series/(k-1)`, or `series/000-upstream-base` for 001);
  - ours = the new parent's tree;
  - theirs = the old step's tree.

  This is `trees.target_tree` with feature 001's stored-resolution machinery, in a new resolutions
  directory. Each new branch starts as one commit on its parent, as in feature 001.
- **Rationale**: the old step's tree is already the verified, re-resolved state of its chapter.
  Replaying it carries exactly "the old step's change" (spec Story 2) and keeps the old step as the
  reference. Re-deriving from the 1,940-commit history would redo feature 001's cuts and
  normalisation for no gain.
- **Alternatives**:
  - Re-running feature 001's history pipeline with `upstream_base` set to `000b`: this is what the
    T034 dry run did. Its 74 conflicts came from the history snapshots, not from the reviewed steps.
  - `git rebase --onto` of the old branches: the same merges, but with no resolution store, no
    per-file record, and an interactive conflict loop.

## R4. How big the D1 step is (the spec asked the plan to measure it)

Probe on top of #768 (`P1` = old 002's tree merged onto #768, base `49a5eb9fc`):

| Probe | Conflicted files | Size vs. its parent |
|---|---|---|
| old 001+002 onto #768 | 1 (`OOJSShip.m`) | — |
| old 003 replayed onto P1 | 80 | ~138 files, +30.9k −7.8k (markers inflate this) |
| old 003→005 replayed onto P1 | 124 (88 in `src/Core/Scripting`, 17 `src/Core`, 11 `Entities`, 4 `Debug`, 2 workflows, 1 subproject, 1 meson) | ~364 files, +35.6k −10.1k |
| (old series, for comparison) 002→003 | — | 135 files, +20.9k −7.5k |
| (old series) 002→005 | — | 370 files, +22.2k −12.0k |

- **Finding**: on #768 the fork's façade is **not** smaller than old 003+005. It is about the same
  number of files with more lines added, because it has to replace #768's binding as well as add
  its own. The spec's D1 says to record this finding for Jon, and the default stands (the end tree
  is still `develop`, R5). It is in Notes.
- **Decision**: old 003, 004 and 005 each stay a separate replayed step, so 004's
  Objective-C++ change is not reordered. FR-005 then applies to each one by measurement after it is
  built:
  - **New 003**: old 003 replayed. Its title and description are rewritten: "Put the game's
    JavaScript behind an engine façade, replacing the QuickJS-ng binding". SpiderMonkey is already
    gone, so "beside SpiderMonkey" no longer applies.
  - **New 004**: old 004 replayed (Objective-C++).
  - **Old 005**: replayed. Whatever #768 already did (removing SpiderMonkey) merges away. If its
    tree equals its parent's, it is dropped with `covered_by: 768`. Otherwise it keeps the
    remainder (expected: NSPR, the build switch, `install_deps.sh`) under a narrowed title.
- **Amends** the spec's D1 wording ("collapse into one step placed where old 003 was"). That
  default needed 004 moved ahead of the façade, and old 004 was cut on top of 003's tree. The spec
  is updated to match.

## R5. Upstream additions that `develop` does not have

#767/#768 add 35 paths that `develop` lacks. Classified by what they are, without reading OXP
content (hard rule 4):

| Paths | What | Decision |
|---|---|---|
| `src/Core/Scripting/poc/**` (13), `src/Core/Scripting/OOJSClasses.m`, `src/Core/Scripting/README.md` | #767/#768's QuickJS binding and its standalone test harness | **Removed in new 003.** The fork's façade replaces them, so the end tree is `develop`. |
| `subprojects/packagefiles/quickjs-ng/0001-oolite-primitive-property-assignment.patch` | #768's patch to QuickJS-ng | **Decided at T010 by evidence**: kept if `develop`'s QuickJS-ng needs the same behaviour (the step's tests show it), otherwise removed in new 003. Default: removed, because `develop` passes without it. |
| `Resources/Scripts/oolite-quickjs-compat.js` | #768's runtime compatibility shim for scripts | Same rule. Default: removed in new 003, because `develop` passes its tests without it. |
| `tools/js-parity/**` (9; contains an OXP, which is not read) | #767's SpiderMonkey/QuickJS parity probe | **Retained.** It is upstream's own tooling and not part of the game build. Deleting it in a PR to upstream would be gratuitous. Listed as a retained addition (FR-007). |
| `tools/oxp-upgrade/**` (9) | #768's OXP name-upgrade tool (Node) | **Retained**, for the same reason. |

- **Rationale**: the spec's end-tree rule protects `develop`'s verified game. Upstream's
  stand-alone tools don't change the game, and removing them costs goodwill.
- **Consequence**: the manifest gets an `additions` list (path glob, PR, reason). `check
  final-tree` compares the last step with `develop` modulo `exclusions` ∪ `additions`. The spec's
  FR-007 is amended to say so.

## R6. The parent gate

- **Decision**:
  - Each parent is built and tested in the isolated Objective-C MSYS2 (`.agent-tmp/msys2-objc`,
    feature 001's T005) with what it ships: `./mk.sh build test`, and for `000a` its build-option
    variants (default and `-Djs_engine=quickjs`). The checks the PR's own Windows CI job runs are
    read from its `.github/workflows/` at T005.
  - The parents get the same verification record as steps, with `kind: parent`.
  - Any failure stops the work at gate G1 and is flagged in Notes and the handover (FR-003a). Steps
    are not built until it is resolved.
  - The tool can add `seriesb/000c-<slug>` (`kind: fix-parent`, a prototype branch on `000b`), but
    only when Notes record Jon's choice.
- **Rationale**: the gate comes from Jon's reply on 2026-11-02. A broken parent makes every step
  above it unverifiable.
- **Alternatives**: verifying the parents in Jon's scoop MSYS2 was rejected. Its GNUstep headers
  fail with Clang 23 even on upstream's base (feature 001's Complexity Tracking).

## R7. Verification eras

- **Decision**:
  - The parents and steps up to the one that drops `gnustep-base` use `objc-quickjs` (the isolated
    MSYS2). No `seriesb` step has SpiderMonkey, except `000a`'s default build.
  - From the old 011 counterpart on, the era is `cxx` (Jon's MSYS2), as in feature 001's T020.
  - Each step's era is taken from its old step, with `objc-spidermonkey` mapped to `objc-quickjs`.
- **Rationale**: the eras follow the code, and the code is the old step's apart from the
  JavaScript engine.

## R8. Making the tool handle two series

- **Decision**: `tools/series/series.py` gets a global `--series {series,seriesb}` option (default
  `series`). It selects a profile:
  - branch prefix;
  - series directory (`specs/001-…/series` or `specs/002-seriesb-rebase-stack/series`);
  - root branch (`series/000-upstream-base` or the last parent);
  - the allowed source types.

  `stack.make_step` refuses any branch outside the active prefix. Additions:
  - a `replay` source type for `tree` and `build`;
  - a `parents` command that sets up the remote, observed branches and lineage, and records
    heads;
  - a `drop` command for FR-005;
  - `check` support for the merge commits that `sync` adds.

  The default profile behaves exactly as before. Feature 001's unit tests pass unchanged, and new
  tests cover the `seriesb` profile.
- **Rationale**: it is one tool with two manifests. A copy of 3,000 lines would drift.
- **Alternatives**: a separate `seriesb.py` was rejected because of the duplication.

## R9. After a sync, branches are no longer "one commit on the parent"

- **Decision**: `build` refuses to reset a step that has commits beyond its build commit (a
  sync's merges) unless given `--reset`. Each sync is recorded in the manifest's `syncs` list
  (date, parent heads before and after, conflicts by step and path, with reasons). After a sync,
  `check`:
  - accepts merge commits whose second parent is the step's parent at that time;
  - requires each step's verification to be dated after the latest sync (FR-011).
- **Rationale**: Jon's reply on 2026-11-02 says updates come through sync, by hand, and are not
  rebuilt.

## R10. Hard rule 6 in intermediate steps

- **Decision**: the interpretation from feature 001's Complexity Tracking carries over. `JS_*`
  symbols (SpiderMonkey's in `000a`, QuickJS's in every QuickJS-era step) and GNUstep exist only
  in parents and intermediate steps. `check final-tree` enforces the rule on the last step, which
  is `develop`.
