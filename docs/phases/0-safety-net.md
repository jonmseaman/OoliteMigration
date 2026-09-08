# Phase 0 — Safety net

**Status:** not started · **Est.:** 2–4 eng-months · **Depends on:** [I0 machines](../infra/0-machines.md), [I1 base images](../infra/1-base-images.md) (for timing measurements; design work can start before them)
**Runs in parallel with:** the infra track. Nothing in the migration track starts before this exits.

## Goal

Build the verification substrate that every later phase is gated on: reproducible CI, a
deterministic golden harness, a JS API snapshot, the OXP corpus, the GUI smoke tier, the three-tier
scripts, and the CI guardrails. **No production code changes** to `upstream/oolite` except
determinism fixes that are upstreamable as plain bug fixes.

Almost all of Phase 0 is seam work: nearly every item fails checks 5 and 7 of the sizing rule. It
is design, built once, by a human with a frontier model. The fleet does not exist yet; this phase
is what makes it safe to exist.

## Entry gate

- [ ] [I0](../infra/0-machines.md): machine inventory filled in; Ubuntu VM-or-bare-metal answered
- [ ] [ADR-0008](../decisions/0008-forge-and-runners.md) decided before any runner is attached

## Exit gate

Original gate (MIGRATION_PLAN §5.7) plus the substrate checks (AI_EXECUTION_PLAN §9), merged:

- [ ] Linux + Windows CI green and reproducible on self-hosted runners
- [ ] ≥ 20 scenarios producing stable goldens across 10 consecutive runs, **on two machines of the same architecture**
- [ ] Iteration-order non-determinism found, fixed in Objective-C, and submitted upstream
- [ ] `oxp-contract/js-api-1.92.json` committed and reproduced by CI
- [ ] Tier 1 / 2 / 3 OXP corpus automated (per-commit / nightly / weekly)
- [ ] Mozilla-only-JS scan report published; a hand-audited random 50 agrees with the model at an acceptable rate
- [ ] PyAutoGUI G1–G4 green on Linux and Windows; macOS runner decision made (roadmap open decision 8)
- [ ] `tools/tier-a.sh` measured **< 30 s** on `OOColor.m` and `OORoleSet.m`
- [ ] 20 golden containers run concurrently on one host with no port or display collision
- [ ] A deliberately perturbed market-price calculation is caught by Tier B, not by a reviewer
- [ ] A deliberately introduced use-after-free is caught by ASan in Tier C
- [ ] Reintroducing a `JS_*` or `libgnustep-base` symbol fails CI on the deny-list
- [ ] A PR touching `goldens/` that Jon did not author fails CI
- [ ] A batch of 8 PRs with one bad one: the merge queue bisects to the culprit automatically
- [ ] `docs/templates/story.md`, `docs/stories/G1-exit-via-mouse.md`, and `tools/gen-stories` exist
- [ ] Cross-platform golden policy decided (open decision 11) **before the first golden is blessed**

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| Golden harness container + canonical state dump | `tests/golden/scenario_001_launch_dock/` | Jon + frontier |
| GUI tier helper (`row → screen point`) and G1 | `tests/gui/test_g1_exit_via_mouse.py` | Jon + frontier |
| Story template and generator | `docs/templates/story.md`, `tools/gen-stories` | Jon |
| Tier A / B / C scripts | `tools/tier-a.sh`, `tools/tier-b.sh`, `tools/tier-c.sh` | Jon + frontier |
| Expansion-scan classifier prompt + audit protocol | `tools/oxp-js-scan/` | Jon + frontier |

## Sweeps

Small, and only after their seam exists:

| Sweep | Unit | Inventory | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| Golden scenarios 2–20 | one scenario | the scenario list in 0.4 | scenario 001 | ~19 | after 0.4 seam |
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
expensive to diagnose in Phase 4.

### 0.2 Base image

GNUstep at pinned commits + `mozillajs-linux` 0.0.1, prebuilt and cached. Specified in [I1](../infra/1-base-images.md); listed here because Tier B timing is meaningless without it.

### 0.3 Reproduce upstream builds in our CI

Linux x86-64 and Windows x86-64, matching `upstream/oolite/.github/workflows/build-all.yaml`.
Pin the GNUstep commits and the `mozillajs-linux` 0.0.1 artefact. Cache aggressively — GNUstep
from source is slow, and every later phase pays this cost on every run.

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
  mission trigger, save/load round-trip, each of the 6 `test-oxps`.

**Acceptance for every later phase: the goldens still reproduce.**

Nothing else scales until this exists. `tests/launch_snapshot.py` currently hardcodes
`PORT = 8563` and `HOST = 127.0.0.1`.

- Parameterize port and `DISPLAY`; one scenario per container, Xvfb inside.
- Bake **GNUstep + the `mozillajs-linux` artefact into a base image**, built once from the pinned
  commits. The CI presently compiles GNUstep from source on every run; this alone likely cuts
  iteration time more than any model choice you could make.
- `ccache`/`sccache` with a shared cache volume across agents.
- Emit the canonical sorted-JSON state dump (above) as the container's artifact.


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
build, so there is a known-good baseline before anything changes. G5–G9 can follow.

### 0.9 Tier A / B / C scripts

The tiers are defined in [execution-model §3](../execution-model.md). Agents need a command, not a
budget. Deliver `tools/tier-a.sh <file>` (single-TU compile, `clang-tidy`, deny-list grep, that
module's unit tests; < 30 s, offline), `tools/tier-b.sh` (one-platform build, module tests, 3–5 fast
goldens, Tier-1 subset; < 10 min), `tools/tier-c.sh` (everything; batched by the merge queue).
Getting Tier A under 30 seconds is the single highest-leverage engineering task in the project.

### 0.10 Merge queue with batch-and-bisect

Provided by Gas City's Refinery ([ADR-0006](../decisions/0006-gas-city-and-hermes.md)); wired to CI
per [I2](../infra/2-forge-and-runners.md) and [I3](../infra/3-fleet.md). Verified by the "8 PRs,
one bad" exit-gate item.

### 0.11 CI guardrails (enforce the prohibitions mechanically)

The story prohibitions ([templates/story.md](../templates/story.md)) are stated in every story; they
are also enforced, consistent with "never verify with a model":

- A PR that touches `goldens/` fails unless authored by Jon (CODEOWNERS or an explicit check).
- A grep for new `-Wno-`, `#pragma clang diagnostic`, `#pragma GCC diagnostic` fails the PR.
- A deleted or emptied test file is flagged and fails the PR.
- Symbol deny-list for `libgnustep-base` and `JS_*` (from the per-PR definition of done).

### 0.12 Story template, exemplar story, generator

Commit [templates/story.md](../templates/story.md) and the hand-written
[G1 story](../stories/G1-exit-via-mouse.md) first, then write `tools/gen-stories` against them. The
generator is itself fleet-unsuitable: it encodes the template, which is a design decision.

## Commands

Not yet available. Produced by 0.9.

## Open decisions

- **11 — Cross-platform golden policy.** State dumps are byte-compared. A physics simulation run for
  N ticks diverges between x86-64 and arm64 (FMA contraction, libm differences) and between compiler
  versions and optimisation levels. Frame hashes already have tolerance; state dumps do not.
  Options: (a) goldens blessed per platform; (b) the dump quantises floats to a fixed precision;
  (c) both. Also pin `-ffp-contract=off` and the optimisation level for golden builds. **Decide
  before the first golden is blessed**, because it determines how goldens are stored. Affects the
  Phase 3 gate directly.
- **8 — macOS CI runner** (self-hosted on the Mac, or a local pre-release gate). Decide before Phase 3.
- **ADR-0008 — forge.** Before any runner is attached.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §5 and AI_EXECUTION_PLAN §4.2, §8, §9. No work started.
