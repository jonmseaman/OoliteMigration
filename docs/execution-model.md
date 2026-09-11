# Execution model

**What this is:** the rules under which AI agents do this migration — what decides correctness, the
three verification tiers, the agent authority model, the model-tiering table, and the sizing rule a
story must satisfy before a fleet can consume it. This is the stable part of the execution design.
Where things run (machines, images, forge, fleet software) is the [infra track](infra/); why the
hosting and framework decisions came out the way they did is in [decisions/](decisions/).

**Provenance:** extracted from `AI_EXECUTION_PLAN.md` (2026-09-05/06, git history at `ee2de41`),
sections 1, 3, 4, 5, 10, 11 and 15, plus the per-PR definition of done from `MIGRATION_PLAN.md`.

---

## 1. The measurements that shape everything

### 1.1 The code is a power law — fan-out targets the thin part

Measured across `upstream/oolite/src`, 241 `.m` files, 183,603 lines:

| Bucket | Files | % files | Lines | % lines |
|---|---:|---:|---:|---:|
| < 500 lines | 148 | 61.4% | 32,110 | **17.5%** |
| 500–1,500 | 68 | 28.2% | 56,482 | 30.8% |
| 1,500–4,000 | 19 | 7.9% | 40,465 | 22.0% |
| **> 4,000** | **6** | **2.5%** | **54,546** | **29.7%** |

Median file: 325 lines. p90: 1,430.

A fleet of parallel agents is good at the 148 small files — which are **17.5% of the code**. The six
files that hold 30% of it (`ShipEntity.m` 14,945, `PlayerEntity.m` 13,718, `Universe.m` 11,297,
`PlayerEntityControls.m` 5,690, `HeadUpDisplay.m` 4,497, `OOJSShip.m` 4,399) are not fan-out work at
all. `ShipEntity` alone is 186 ivars and 565 methods; with its headers and dependency closure it is
a 200k+ token problem. `Universe` is explicitly scheduled **last** because everything points at it.

Amdahl's law applies directly: perfect parallelism on every file under 1,500 lines retires 48% of
the lines, and the remaining 52% stays serial-ish and hard.

### 1.2 The largest fan-out arrives last, but it does not arrive first

| Phase | Est. (eng-mo) | Fan-out potential |
|---|---:|---|
| 0 — harness, determinism, corpus | 2–4 | **None.** Design work; one harness, built once. |
| 1 — JS façade + QuickJS-ng | 4–7 | **Seam then high.** The façade is one design; retargeting 3,828 sites across 102 files behind it is ~110 replication stories. |
| 2 — ObjC++ switch + `oofnd` | 6–10 | **Seam then high.** The library *is* design, but migrating ~11k Foundation references onto it is ~250–400 replication stories. |
| **3 — ObjC → C++20, ~500 files** | **12–24** | **Highest — ≈400 stories, and the least seam-bound.** |
| 4 — remove ObjC runtime | 1–2 | None. Mechanical, one pass. |
| 5 — Apple Silicon build/sign/CI | 1–2 | None. |
| 6 — modernise | 4–10 | Low. Design changes by definition. |

Fan-out potential is not a property of a phase; it is a property of the work *after its seam is cut*
(§4, §8). Phase 3 is the largest single block and the least seam-bound, but the fleet does **not**
idle until then: it starts as soon as Phase 0's harness exists and the first seams are cut, on the
Phase 1 and Phase 2 sweeps. What genuinely cannot be parallelised is Phase 0 itself and the seam at
the head of each sweep.

### 1.3 The real bottleneck is validation machine-time, and it isn't GPU work

The per-PR definition of done (§7) is:

1. Goldens reproduce · 2. Tier-1 OXP corpus green · 3. Clean build on **every supported platform** (Linux + Windows until Phase 5, + macOS after) at
`-Wall -Wextra` · 4. **ASan + UBSan clean on Linux** · 5. Symbol deny-list enforced.

Each golden scenario **launches the actual game** and drives it over the debug-console TCP channel
(`tests/launch_snapshot.py`, 230 lines, plist packets on port 8563). Twenty scenarios × a real
process each. The CI builds **GNUstep from source** (`ShellScripts/Linux/build_gnustep.sh`, pinned
commits) before it compiles a line of Oolite.

That is a build-farm and headless-GL problem measured in CPU cores, NVMe, and X displays. It is
**x86-64 Linux and Windows** work. It is not inference. No LLM hardware moves that number.

---

## 2. Never verify with a model

Using frontier models for planning is right. Using them for validation is wrong,
in a way that would quietly destroy the project.

A model asked to judge whether a 14,000-line hand-translated file is correct will produce a
confident, plausible, unfalsifiable yes. Do that 500 times and you have a codebase that no one has
verified and everyone believes. The golden harness exists precisely so that correctness is decided
by **byte-comparison of canonical JSON state dumps**, not by judgment.

Split the word "validation" in two:

| | Decided by | Never by |
|---|---|---|
| **Verification** — did behaviour change? | Goldens, JS API snapshot diff, Tier-1/2/3 corpus, ASan/UBSan, symbol deny-list, `-Wall -Wextra` | A model. Ever. |
| **Adjudication** — a check failed; is this diff legitimate? | Frontier model proposes, human re-blesses | Auto-accept |

Golden re-blessing is the one irreversible step in the whole pipeline. **A model may propose a
re-bless with justification; only you may merge one.** If you automate exactly one gate away, this
is the one that ends the project.

---

## 3. The three verification tiers

The worry that agents run tests sequentially, so there is not enough parallelism, dissolves once the
tiers are separated. Sequential is *correct* at the agent level, provided what runs there takes
seconds.

### 3.1 Three tiers

| Tier | When | Content | Budget | Parallelism |
|---|---|---|---|---|
| **A — in-loop** | every agent edit | Compile the single TU; `clang-tidy`; symbol deny-list grep; that module's unit tests | **< 30 s** | none needed — it's seconds |
| **B — per candidate PR** | agent believes it's done | Full build, **one** platform; module tests; 3–5 fast golden scenarios; Tier-1 OXP subset | **< 10 min** | N-way across CI pool, one container per scenario |
| **C — per merge batch** | merge queue | All 3 platforms; all 20 goldens; ASan + UBSan; full Tier-1; JS API snapshot; PyAutoGUI tier | 30–90 min | batched — see §3.3 |

Tier A is what an agent iterates against. If Tier A is slow, everything else is irrelevant, because
the agent's inner loop dominates wall-clock. **Getting Tier A under 30 seconds is the single highest-
leverage engineering task in this entire document.**

### 3.2 Containerize the golden harness — the prerequisite for all parallelism

Nothing else scales until this exists. `tests/launch_snapshot.py` currently hardcodes
`PORT = 8563` and `HOST = 127.0.0.1`.

- Parameterize port and `DISPLAY`; one scenario per container, Xvfb inside.
- Bake **GNUstep + the `mozillajs-linux` artefact into a base image**, built once from the pinned
  commits. The CI presently compiles GNUstep from source on every run; this alone likely cuts
  iteration time more than any model choice you could make.
- `ccache`/`sccache` with a shared cache volume across agents.
- Emit the canonical sorted-JSON state dump (Phase 0) as the container's artifact.

Scenario parallelism then becomes a scheduling problem, which is a solved one.

### 3.3 Merge queue with batch-and-bisect 

**Do not run Tier C per task.** Batch PRs that passed Tier B, run Tier C once over the batch,
and bisect only on failure:

- 16 PRs, batch passes → **1** Tier-C run instead of 16.
- 16 PRs, batch fails → 1 + log₂(16) = **5** runs. Still a 3.2× amortization.

This is how large monorepos absorb exactly this load. Parallelism comes from the *scheduler batching independent work*, not from each agent
running its own full suite.

### 3.4 Non-negotiable substrate

- **One git worktree per agent.** Without it they fight over the build directory and you will spend
  weeks debugging phantom failures.
- **Deny-list in CI** for `libgnustep-base` and `JS_*` symbols (§7.5) — mechanical, cheap,
  catches the regression that matters most.
- **Determinism first (Phase 0 §0.1).** `NSDictionary`/`NSSet` enumeration order is unspecified. If a
  gameplay path depends on it, the goldens are noise and every downstream signal is worthless.
  Nothing above works until this is done.

---

## 4. Model tiering: what runs where

| Work | Volume | Model tier | Why |
|---|---|---|---|
| Phase-0 harness design; `oofnd`, `JSEngine` façade, `oo::Ref` design | ~50 decisions | **Frontier, interactive, with you** | Determines whether the project works. Cheapest thing you will ever buy. |
| The 6 giant files (30% of lines) | 6 | **Frontier + you, weeks each** | 200k+ token dependency closures. Physically outside a local model's KV budget on 128 GB. |
| Files 1,500–4,000 lines (19 files, 22%) | 19 | Frontier, one at a time | Real design content in each. |
| Files < 1,500 lines (216 files, 48%) | 216 | Frontier sets pattern → **local model drafts, Tier B judges** | Only after `oomath` + `OXPVerifier` establish house style by hand. |
| **Phase 0 scan: expansions for Mozilla-only JS** | 818–1,591 | **Local, high batch** | Small context, independent, 90% accuracy is fine — it feeds a guide, and the engine catches misses. |
| Tier-3 weekly smoke-log triage + clustering | ~1,591 logs | **Local, high batch** | Pure classification. |
| Golden-diff first-pass triage (Phase 3) | high | Local proposes → frontier adjudicates → **you re-bless** | §2. |
| 3,828 JS call sites → façade (Phase 1) | 3,828 | **Neither — `clang-refactor`** | A compiler is more correct and far cheaper than any model here. Do not spend tokens on this. |

> **Corpus size note.** The architecture doc cites 1,591 entries from the live API. The catalog
> checked into this repo (`upstream/oolite-expansion-catalog/expansionUrls.txt`) holds **818 unique
> URLs**. Both can be true — the file lists manifests, the API aggregates versions — but 818 is what
> is reachable offline today, and it is the number to budget the pilot against.

Two things worth internalising: the highest-volume AI work in this project is **classification, not
code generation**, and the highest-*value* AI work is a few dozen design conversations.

**Phase 1 executor split (resolved 2026-09-06).** Earlier drafts said both "Phase 1 is
`clang-refactor`, not agents" and "Phase 1 is a ~110-story fleet sweep". Both are true of different
parts. The five stub/init patterns and the numeric conversions (~40% of the 3,828 sites) are
scripted with `clang-refactor`; the remaining ~60% are a per-file fleet sweep with the façade as the
exemplar. See [Phase 1](phases/1-js-engine.md).

---

## 5. Agent roles — organised by authority, not by task

The instinct to decompose by role is right. The failure mode is role proliferation without an
authority model: every agent proposes, none is accountable, and a "reviewer" quietly becomes a
rubber stamp. Define each role by **what it may decide and what it must escalate**, not by what it
does.

| Role | Lifetime | May decide | Must escalate |
|---|---|---|---|
| **Reporter** | scheduled, daily + weekly | nothing — **read-only, zero write authority** | n/a; it reports merge-queue state, golden drift, Tier-3 trend, upstream delta |
| **Converter** | ephemeral, one per file | commits to *its own worktree branch* | anything that won't pass Tier A |
| **Reviewer** | ephemeral, one per PR | **advisory comments only — cannot merge** | style drift; `isKindOfClass:` sites that want a virtual, not a `dynamic_cast` |
| **Harness steward** | standing, weekly | may fix harness/CI code | **may never re-bless a golden**; reports flake rate and drift |
| **Upstream tracker** | standing, monthly | performs the rebase, files `docs/UPSTREAM_DELTA.md` entries | any conflict inside a frozen module (architecture §6.3) |
| **Adjudicator** (frontier) | on-demand | proposes a re-bless *with written justification* | **every re-bless, always** |
| **Jon** | — | merges to main · re-blesses goldens · roadmap open decisions · freeze policy | — |

Four notes on this table:

1. **The reviewer is not the gate.** Tier A and Tier B are. If a review agent is the only thing
   between a translation and `main`, you have rebuilt the "model validates" antipattern (§2) with
   extra steps and more confidence. The pyramid supplies truth; the reviewer supplies taste.
2. **On "an agent to review high-level goals such as the e2e GUI tests" — don't.** That is the role
   that most needs a human. The PyAutoGUI tier ([GUI tier](phases/0-gui-tier.md), G1–G9) exists specifically to prove the build
   is *a real application and not just a binary that links*. An agent judging whether that tier still
   means something is the exact trap: plausible drift, undetectable. Give the mechanical half
   (are G1–G9 green? how flaky?) to the harness steward, and keep the judgment yours.
3. **The role you didn't list is the one you most need: harness steward.** In a project where the
   goldens *are* the safety net, someone must own the safety net's integrity. Flaky goldens kill a
   migration silently — agents learn to retry until green, and the signal is gone without anyone
   deciding to discard it. Make flake rate a tracked, budgeted metric from day one:
   **> 1% flake on any Tier-B check is a stop-the-line event.**
4. **Start with the reporter.** It is read-only, therefore safe; it is a scheduled job, therefore
   cheap; and it forces you to define what "progress" means numerically (goldens stable, Tier-1
   green, files converted, upstream delta) before any code depends on the answer. It is buildable
   this week.

5. **Untrusted input never meets write authority.** The Tier-3 corpus is 818+ third-party
   expansions full of JavaScript and plists, and the expansion scan feeds that content to a model.
   That is a prompt-injection surface. Rule: no agent that reads Tier-3 corpus *content* (as opposed
   to a pass/fail log line) holds write authority to any repo or holds API secrets. The scan pilot
   runs in a sandbox with no repository access; the Reporter reads logs, not scripts.

---

## 6. Anti-patterns

- **Auto-re-blessing goldens.** The single change most likely to end the project. §2.
- **Fanning out Phase 3 before `oomath` and `OXPVerifier` are hand-converted.** You would get 200
  files in 200 inconsistent styles and a review burden larger than the original work.
- **Spending tokens where a compiler works** — the 3,828 JS call sites, the `.mm` mechanical fixes.
- **Buying inference capacity to fix a build-throughput problem.** §1.3; [ADR-0005](decisions/0005-defer-dgx-spark.md).
- **Letting fork divergence run.** ~340 upstream commits/year, 6+ active contributors. Rebase
  monthly; the goldens are what make each rebase verifiable rather than a leap of faith (architecture §6.3).
- **Building the fleet before the harness.** Agents that can't verify their own work generate
  review debt faster than they generate value.

---

## 7. Definition of done, per PR

1. Goldens reproduce (or the diff is explained and re-blessed with justification).
2. Tier 1 OXP corpus green.
3. Builds clean on every supported platform (Linux and Windows until Phase 5; macOS added there) at `-Wall -Wextra` with no new warnings.
4. ASan + UBSan clean on Linux (essential — hand-translated refcounting *will* produce use-after-free).
5. No new `libgnustep-base` or `JS_*` symbols reintroduced (CI-enforced deny-list).

Items 1, 2, 4 and 5 are mechanical and decided by Tier B/C. Item 1's "re-blessed" path is the one
human gate in the pipeline (§2).

---

## 8. Task granularity: the grain a fleet story must have

This section answers the question that sits
underneath the architecture: **how small must a single task be before a ~Sonnet-4.6-class local model can finish
it in its entirety?** The two are independent — the best harness in the world cannot rescue a task
that is specified at the wrong altitude.

### 8.1 The gap: the phase docs stop two levels short

| Level | Example | Size | In the phase docs? |
|---|---|---|---|
| **L0** Phase | "Phase 2 — `oofnd`" | 6–10 eng-months | ✅ |
| **L1** Plan item | "build `oofnd` bottom-up" | weeks | ✅ |
| **L2** Component | "`PList` + old-style **and** XML parser/writer" | ~2 weeks | ✅ — *their finest grain* |
| **L3** Story | "Old-style plist scanner: quoted strings + `\U` escapes; `test_plist_oldstyle_strings.cpp` cases 1–14 go green" | ~half a day | ❌ **missing** |

Any memoryless work loop — Gas City's **beads**, or a Ralph-style `prd.json` story — spawns a fresh
instance per unit with **no memory of previous work** and decides "done" from acceptance criteria
alone. It consumes L3. The phase docs provide L2.

**This section is harness-independent.** Grain is a property of the task, not of the orchestrator:
switching from Ralph to Gas City changes how a unit is stored, dispatched and closed, but not how
small it has to be. §8.2 survives the switch unchanged; §8.3's mechanics are the part that binds
to a specific harness.

**Scale of the shortfall.** At one L3 story ≈ 0.5–1 eng-day and ~20 eng-days/eng-month, against
the roadmap effort estimates:

| Scope | Eng-months | Eng-days | Est. L3 stories |
|---|---:|---:|---:|
| Phases 0–2 (before the conversion grind) | 12–21 | 240–420 | ~240–840 |
| Phase 3 alone | 12–24 | 240–480 | ~240–960 |
| **Whole migration** | 30–59 | 600–1,180 | **~600–2,360** |

Cross-check on Phase 3, bottom-up from the measured `.m` histogram (§1.1) rather than from the roadmap —
138 files ≤400 lines at 1 story each, 62 at ~1.5, 30 at ~3, 11 at ~7 → **≈400 stories**, inside the
240–960 band.

The original plan contained **51 numbered items**, so the fleet needs roughly **11–46× more
items than exist today**. That is the operative finding: **the story list cannot be hand-authored**
(§8.4).

### 8.2 The seven-check sizing rule

A story is fleet-ready **iff all seven hold**:

| # | Check |
|---:|---|
| 1 | Requires reading ≤ ~1,500 lines (≈2 median `.m` files; **never** a >2,500-line file whole) |
| 2 | Writes ≤ ~400 lines |
| 3 | Touches ≤ 8 files |
| 4 | Has ≥1 acceptance criterion that is a **command exiting nonzero before and zero after** |
| 5 | Introduces **zero new interfaces** — every type and signature already compiles in the tree, or is quoted verbatim in the story |
| 6 | Is describable in 2–3 sentences |
| 7 | Names a **worked example**: "do it the way `<already-converted-path>` does it" |

Checks 5 and 7 are the ones generic guidance omits and the ones that matter most for a translation
project. The size distribution measured in §1.1 is favourable: median `.m` is 325 lines and 138 of
241 are ≤400, so most of Phase 3 is genuinely one story per file.

**The rule is self-diagnosing — read *which* checks fail:**

| Failure pattern | Diagnosis | Action |
|---|---|---|
| Only 5 and 7 fail | It is a **seam** | Human/frontier work; replications follow it (§5) |
| 1, 2, 4 or 6 fail | It is **too big** | Split further before anything else |
| 4 alone fails | **Not verifiable** | Write the test first, as its own story |

**Worked calibration.** [the GUI tier](phases/0-gui-tier.md)'s **G1 scores 5/7**, failing only 5 and 7 — so G1
is the *seam* that defines the GUI-test harness (the `row → screen point` helper the GUI tier doc describes but
never specifies), and G2–G9 are its replications. Phase 2's "`PList` + old-style and XML
parser/writer" scores **2/7**, failing 2, 4, 5, 6 and 7 — too big *and* unverifiable as written.

G1–G9 remain the closest thing to L3 stories anywhere in either document: **use them as the
calibration exemplar** for the right grain.

### 8.3 Hazards of a memoryless work loop

§2 establishes that models never validate. Three failure modes follow from memorylessness itself
and must be written into every work unit, whatever the harness calls it:

- **Reward-hacking the goldens.** The cheapest way to make a golden pass is to edit the golden.
  Every story carries, verbatim: *do not modify files under `goldens/`; do not modify the test; do
  not add `-Wno-*` or `#pragma` to silence warnings.*
- **The agent must not close its own unit.** A model that cannot build will report success anyway.
  Whatever marks a unit done — a Ralph `passes` field, a Gas City bead transition — must be written
  by an external wrapper that ran the acceptance command, never by the agent. Same principle as §2,
  and the single most important thing to get right when wiring a new harness.
- **No memory between iterations.** Unit text must embed absolute paths and the exemplar path. Every
  harness has exactly one carry-over channel (Ralph's `notes`; Gas City's bead body and **mail**) —
  identify it before generating anything, because it is the only state that survives.

Stock templates ship web-shaped acceptance criteria. Replace them wholesale:

| Use | Common default to reject |
|---|---|
| `meson compile -C build` clean, no new warnings at `-Wall -Wextra` | "Typecheck passes" |
| `meson test -C build --suite <suite>` green | — |
| `python3 tests/launch_snapshot.py` passes | — |
| Golden scenario N reproduces | — |
| Tier-1 OXP corpus green | — |
| **ASan + UBSan clean on Linux** | — |
| Symbol deny-list: no new `libgnustep-base` / `JS_*` | — |
| PyAutoGUI tier for window/input work | "Verify in browser" |

### 8.4 Generate stories, don't author them

11–46× more items than exist today is not a writing task. Per sweep, script a generator that walks
an inventory and emits one story per unit from a fixed template:

| Sweep | Unit | Inventory command | Est. stories |
|---|---|---|---:|
| JS retarget (Phase 1) | one file | `grep -rl 'jsapi.h\|OOJavaScriptEngine.h' src` | ~110 |
| `OOCollectionExtractors` retirement | one file | `grep -rl 'oo_[a-zA-Z]*ForKey' src` | ~150 |
| Foundation → `oofnd` | one file, in Phase 2 order | `grep -rl 'NSString\|NSDictionary\|NSArray' src` | ~250–400 |
| ObjC → C++ (Phase 3) | one file ≤400 lines; larger pre-split | `find src -name '*.m' -size -20k` | ~350–800 |

Each generated story inherits the §8.3 criteria and prohibitions, the seam's exemplar path, and
`priority` from the dependency order already given in the Phase 2 and Phase 3 docs.

The generator is itself fleet-unsuitable — it encodes the story template, which is a design
decision. Write it once, by hand, before the first sweep.
