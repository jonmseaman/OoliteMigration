# Phase 0 — Safety net

**Status:** not started · **Est.:** 2–4 eng-months · **Depends on:** [I0 machines](../infra/0-machines.md), [I1 base images](../infra/1-base-images.md) (for timing measurements; design work can start before them)
**Runs in parallel with:** the infra track. Nothing in the migration track starts before this exits.

## Goal

Build the verification substrate that every later phase is gated on: reproducible local builds, a
deterministic golden harness, a JS API snapshot, the OXP corpus, the GUI smoke tier, the three-tier
scripts, and the guardrail checks. **No production code changes** to `upstream/oolite` except
determinism fixes that are upstreamable as plain bug fixes.

Almost all of Phase 0 is seam work: nearly every item fails checks 5 and 7 of the sizing rule. It
is design, built once, by a frontier agent in an interactive session. The fleet does not exist yet;
this phase is what makes it safe to exist.

## Entry gate

- [ ] [I0](../infra/0-machines.md): the Windows machine's inventory filled in and its checklist done (keep-awake, MSYS2, logins)
- [ ] ~~ADR-0008 decided before any runner is attached~~ — no runners for now ([ADR-0016](../decisions/0016-no-forge-local-verification.md))

## Exit gate

Original gate (MIGRATION_PLAN §5.7) plus the substrate checks (AI_EXECUTION_PLAN §9), merged:

- [ ] Windows build green and reproducible **locally from a clean clone**, scripted; no CI ([ADR-0016](../decisions/0016-no-forge-local-verification.md)); Windows is the only platform until Phase 5 ([ADR-0017](../decisions/0017-native-windows-subtree.md))
- [ ] ≥ 20 scenarios producing stable goldens across 10 consecutive runs, from **two independent clean worktrees** on the one machine
- [ ] Iteration-order non-determinism found, fixed in Objective-C, and submitted upstream
- [ ] `oxp-contract/js-api-1.92.json` committed and reproduced by Tier C
- [ ] Tier 1 / 2 / 3 OXP corpus automated (per-commit / nightly / weekly)
- [ ] Mozilla-only-JS scan report published; a hand-audited random 50 agrees with the model at an acceptable rate
- [ ] PyAutoGUI G1–G4 green on Windows, run by Tier C and nightly under the desktop lock (never per bead)
- [ ] `tools/tier-a.sh` measured **< 30 s** on `OOColor.m` and `OORoleSet.m`
- [ ] N golden game processes (N from the [I0](../infra/0-machines.md) RAM budget, at least 4) run concurrently with no port or output collision
- [ ] A deliberately perturbed market-price calculation is caught by Tier B, not by a reviewer
- [ ] A deliberately introduced use-after-free is caught by ASan in Tier C
- [ ] Reintroducing a `JS_*` or `libgnustep-base` symbol fails Tier B on the deny-list
- [ ] A bead branch touching `goldens/` without an approved re-bless (Jon, weekly queue) fails Tier B
- [ ] A batch of 8 branches with one bad one: `tools/merge-queue` bisects to the culprit and requeues its bead
- [ ] `tools/fleet/accept` closes a bead only after acceptance exits 0 in a fresh clone; an agent attempting `bd close` directly is refused
- [ ] `tools/fleet/goal-check` returns 0 for a phase whose only open beads are `rebless` / `proposed-adr` / `frontier`
- [ ] `docs/templates/story.md`, `docs/stories/G1-exit-via-mouse.md`, and `tools/gen-stories` exist
- [ ] Cross-platform golden policy (decision 11: per-platform + quantised floats) implemented **before the first golden is blessed**

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| Golden harness runner (native game processes) + canonical state dump | `tests/golden/scenarios/001/` | Frontier agent |
| GUI tier helper (`row → screen point`) and G1 | `tests/gui/test_g1_exit_via_mouse.py` | Frontier agent |
| Story template and generator (emits beads) | `docs/templates/story.md`, `tools/gen-stories` | Frontier agent |
| Fleet scripts: `accept` (the only path to `bd close`), `goal-check`, `worktree`, `run-story` | `tools/fleet/` | Frontier agent |
| Merge queue, batch-and-bisect | `tools/merge-queue` | Frontier agent |
| Tier A / B / C scripts | `tools/tier-a.sh`, `tools/tier-b.sh`, `tools/tier-c.sh` | Frontier agent |
| Expansion-scan classifier prompt + audit protocol | `tools/oxp-js-scan/` | Frontier agent |

## Sweeps

Small, and only after their seam exists:

| Sweep | Unit | Inventory | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| Golden scenarios 2–20 (13–17 load the checklist saves) | one scenario | the scenario list in 0.4 | scenario 001 | ~19 | after 0.4 seam |
| GUI tests G2–G9 | one test | [0-gui-tier.md](0-gui-tier.md) | G1 | 8 | after G1 |
| Tier-2 corpus curation | one expansion entry | catalog | — | ~150 | any time |

## Work items

Order matters; it is the dependency order from the original near-term sequence.

### 0.1 Iteration-order determinism (do this before anything else)

GNUstep's `NSDictionary`/`NSSet` enumeration order is unspecified and will differ from any C++
container we choose. If any gameplay path depends on it — populator scripts, role selection,
ship registry, equipment ordering are all prime suspects — behaviour will silently diverge and
goldens will be worthless.

**Action:** instrument `NSDictionary`/`NSSet` enumeration in a debug build to shuffle order, run the
scenarios, and find every place the outcome changes. Fix those to sort explicitly *in the Objective-C
code, upstreamable as bug fixes*, before migrating anything. This is cheap now and extremely
expensive to diagnose in Phase 3.

### 0.2 One-time provisioning

`tools/setup-windows.sh`: MSYS2 UCRT64 with upstream's dependencies, Mesa's `opengl32.dll`, `ccache`, Python with pytest and PyAutoGUI, done once and idempotent. Specified in [I1](../infra/1-base-images.md); listed here because Tier B timing is meaningless without it.

### 0.3 Reproduce the upstream Windows build locally

No forge for now (ADR-0016): the target is `tools/build-windows.sh`, native MSYS2 UCRT64 from a
clean clone, matching the Windows job in `upstream/oolite/.github/workflows/build-all.yaml` minus
its per-run provisioning. Cache aggressively (`ccache`); every later phase pays the build cost on
every run. The Linux build is a Phase 5 item ([ADR-0017](../decisions/0017-native-windows-subtree.md)).

### 0.4 Containerised golden harness ("the goldens")

Build on `tests/launch_snapshot.py` and `upstream/oolite-debug-console`, which together already
give a scriptable TCP channel into a running game (plist packets, port 8563, `Perform Command`
executes arbitrary JS in the game context).

Required properties:

- **Determinism.** Fixed RNG seed, fixed system, fixed tick count, fixed clock. `legacy_random.c`
  is already a deterministic LCG; audit every other entropy source (`OOAsyncWorkManager` completion
  order, texture-load ordering, `NSDictionary` iteration order — **that last one will bite**, see
  0.1) and make it reproducible.
- **State dumps.** After N ticks, serialise the world (entity list, positions, velocities,
  orientations, AI states, market prices, player state) to a canonical sorted JSON.
- **Frame hashes.** Perceptual hash of rendered frames at fixed camera positions, with tolerance —
  exact pixel equality across GL drivers is not achievable and chasing it wastes weeks.
- **Scenarios.** Start with ~20: launch/dock, witchspace jump, combat encounter, trade cycle,
  mission trigger, save/load round-trip, each of the 6 `test-oxps`, and one per checklist save
  (`upstream/oolite-tests/Checklist-files/Missions/`: Constrictor, Nova, Trumbles, CloakingDevice,
  ThargoidPlans, loaded with the game's `-load`; 1.75-era files, so they pin save-format
  compatibility and each mission script's state).

**Acceptance for every later phase: the goldens still reproduce.**

Nothing else scales until this exists. `tests/launch_snapshot.py` currently hardcodes
`PORT = 8563` and `HOST = 127.0.0.1`.

- Parameterize port, output directory and `--load`; one scenario per native game process, Mesa's
  llvmpipe `opengl32.dll` beside the binary as `tests/run_test_fn.sh` already does, a real window
  on the desktop ([ADR-0017](../decisions/0017-native-windows-subtree.md)).
- **Provision MSYS2 once** (0.2). Upstream's workflow reprovisions on every run; this alone likely
  cuts iteration time more than any model choice you could make.
- `ccache` with one cache directory shared across agent worktrees.
- Emit the canonical sorted-JSON state dump (above) as the run's artifact.


### 0.5 JS API conformance snapshot

Via the debug console, enumerate all 61 JS globals and, for each of the ~45 native classes, dump
every property and method name, arity, and type. Commit as `oxp-contract/js-api-1.92.json`. Any
later build must reproduce it exactly. This is the machine-checkable form of "expansions still work".

### 0.6 OXP compatibility corpus

From `upstream/oolite-expansion-catalog/expansionUrls.txt` and the live API (1,591 entries via the API; 818 unique URLs in the checked-in catalog — budget against 818), assemble
a tiered corpus:

- **Tier 1 (~30):** the most-installed expansions + all 6 `test-oxps`. Must pass, every commit.
- **Tier 2 (~150):** broad category coverage (ships, missions, HUDs, equipment, OXPs with heavy JS).
  Nightly.
- **Tier 3 (all 1,591):** load-only smoke test — does it parse, register, and reach the main menu
  without errors in `Latest.log`? Weekly.

Also: statically scan all Tier-3 scripts for the Mozilla-only JS constructs in architecture §5.3. That scan is
the single most valuable input to the expansion-author migration guide, and it can run today.

### 0.7 Local-model pilot: the expansion scan

The scan in 0.6 is the local-model pilot: 818–1,591 small, independent classifications, run on
rented GPU time before any hardware is bought ([ADR-0005](../decisions/0005-defer-dgx-spark.md)).
Hand-audit a random 50 against the model before trusting any bulk output. Runs sandboxed, no repo
access, no secrets: expansion content is untrusted input ([execution-model §5.5](../execution-model.md)).

### 0.8 GUI smoke tests (PyAutoGUI)

Specified in [0-gui-tier.md](0-gui-tier.md). G1–G4 in this phase, against the current Objective-C
build, so there is a known-good baseline before anything changes. G5–G9 can follow. The tier needs
the desktop: it runs in Tier C and nightly under a desktop lock, never per bead
([ADR-0017](../decisions/0017-native-windows-subtree.md)).

### 0.9 Tier A / B / C scripts

The tiers are defined in [execution-model §3](../execution-model.md). Agents need a command, not a
budget. Deliver `tools/tier-a.sh <file>` (single-TU compile, `clang-tidy`, deny-list grep, that
module's unit tests; < 30 s, offline), `tools/tier-b.sh` (one-platform build, module tests, 3–5 fast
goldens, Tier-1 subset; < 10 min), `tools/tier-c.sh` (everything; batched by the merge queue).
Getting Tier A under 30 seconds is the single highest-leverage engineering task in the project.

### 0.10 Merge queue with batch-and-bisect

`tools/merge-queue`, an in-repo script ([ADR-0014](../decisions/0014-claude-code-opencode-beads.md)):
collect Tier-B-green branches, merge into a candidate, run `tools/tier-c.sh` locally in a clean
worktree ([ADR-0016](../decisions/0016-no-forge-local-verification.md)), fast-forward `main` on green, bisect on red and requeue the
culprit's bead. Companion seam: the `tools/fleet/` scripts, of which `accept` is the one that
matters: it runs a story's acceptance in a fresh clone and alone may `bd close`, whether the driver
is `run-story` (Claude Code) or Hermes `/goal` (local tier) ([I3](../infra/3-fleet.md),
[ADR-0015](../decisions/0015-hermes-goal-loop.md)). Verified by the "8 branches, one bad" and
"`accept` closes the bead" exit-gate items.

### 0.11 Guardrails (enforce the prohibitions mechanically)

The story prohibitions ([templates/story.md](../templates/story.md)) are stated in every story; they
are also enforced, consistent with "never verify with a model":

- A branch that touches `goldens/` fails Tier B unless it carries a re-bless approval from Jon's weekly queue (an explicit check in `tools/guardrails.sh`).
- A grep for new `-Wno-`, `#pragma clang diagnostic`, `#pragma GCC diagnostic` fails the branch.
- A deleted or emptied test file is flagged and fails the branch.
- Symbol deny-list for `libgnustep-base` and `JS_*` (from the per-bead definition of done).

### 0.12 Story template, exemplar story, generator

**Done (v0, 2026-09-11).** `tools/gen-stories.py` derives the beads for Phases 0–4 from the
upstream tree and creates them through `bd create --graph` in one call: one epic per phase, small
frontier seams, and one fleet bead per file for each sweep (JS retarget, extractor retirement,
Foundation→oofnd, C-file renames, class conversions, pre-split plans for files over 1,500 lines).
It is idempotent by title. First run: 681 beads, 1,436 dependency edges, no cycles; the only ready
work is the four Phase 0 seams with no prerequisites. Acceptance commands live in each bead body
under `## Acceptance`; the beads-worker scripts read them from there. Remaining item in this
seam: bead 0.12 verifies the first generated Phase 1 bead end to end once `tier-a`/`tier-b` exist.

## Commands

Not yet available. Produced by 0.9.

## Open decisions

- **11 — Cross-platform golden policy.** State dumps are byte-compared. A physics simulation run for
  N ticks diverges between x86-64 and arm64 (FMA contraction, libm differences) and between compiler
  versions and optimisation levels. Frame hashes already have tolerance; state dumps do not.
  Options: (a) goldens blessed per platform; (b) the dump quantises floats to a fixed precision;
  (c) both. Only Windows x86-64 exists until Phase 5, where macOS and Linux join and the policy is
  first exercised across platforms ([ADR-0017](../decisions/0017-native-windows-subtree.md)). Also pin `-ffp-contract=off` and the optimisation level for golden builds. **Decide
  before the first golden is blessed**, because it determines how goldens are stored. Affects the
  Phase 5 gate directly.
- **8 — macOS GUI tier:** decided, runs on Jon's Mac (ADR-0013).
- **ADR-0008 — forge:** deferred; no forge for now (ADR-0016).
- **11:** decided, per-platform goldens and quantised floats (ADR-0013). Implement in 0.4.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §5 and AI_EXECUTION_PLAN §4.2, §8, §9. No work started.
- 2026-09-11 — Rewritten for native Windows only (ADR-0017): no Linux build, no containers; scenarios 13–17 are the checklist saves; the GUI tier runs in Tier C and nightly.
