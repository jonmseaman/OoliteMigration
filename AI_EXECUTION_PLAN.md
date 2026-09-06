# AI execution architecture for the Oolite ObjC → C++23 migration

## Context

`MIGRATION_PLAN.md` is written and credible: 30–59 engineer-months across 7 phases, with the
Apple Silicon milestone at 9–16 months. The open question is how to execute it with AI leverage —
specifically whether to stand up a fleet harness (OpenClaw / Hermes Agent) on a DGX Spark, and how
to validate a large number of generated tasks when the test suite appears to run in sequence.

I measured the actual task shape before answering, because the answer turns on it. **The concern
about test parallelism is the right concern, but the constraint is not where you think it is, and
the hardware purchase does not address it.**

---

## 1. The three measurements that reframe the question

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
| 3 — Apple Silicon build/sign/CI | 1–2 | None. |
| **4 — ObjC → C++23, ~500 files** | **12–24** | **Highest — ≈400 stories, and the least seam-bound.** |
| 5 — remove ObjC runtime | 1–2 | None. Mechanical, one pass. |
| 6 — modernise | 4–10 | Low. Design changes by definition. |

> **Amended 2026-09-06.** This section originally read "the parallelizable phase arrives last" and
> rated Phases 1–2 as low fan-out. That understated them. The correction: fan-out potential is not
> a property of a phase, it is a property of the work *after its seam is cut* (§11, §15.2). Phase 1's
> own observation that the call sites are `clang-refactor`-able argues **for** fleet-suitability, not
> against it — mechanical is exactly what a fleet wants. Scored against §15.2's rule, the Phase 1 and
> 2 sweeps are replications, not seams.
>
> Phase 4 remains the largest single block and the least seam-bound. But the fleet does **not** idle
> until month 10–16: it starts as soon as Phase 0's harness exists and the first seams are cut, on
> the Phase 1 and 2 sweeps. What genuinely cannot be parallelised is Phase 0 itself (§15.2 checks 5
> and 7 fail for almost everything in it) and the seam at the head of each sweep.

### 1.3 The real bottleneck is validation machine-time, and it isn't GPU work

§10.4 defines done, per PR:

1. Goldens reproduce · 2. Tier-1 OXP corpus green · 3. Clean build on **three platforms** at
`-Wall -Wextra` · 4. **ASan + UBSan clean on Linux** · 5. Symbol deny-list enforced.

Each golden scenario **launches the actual game** and drives it over the debug-console TCP channel
(`tests/launch_snapshot.py`, 230 lines, plist packets on port 8563). Twenty scenarios × a real
process each. The CI builds **GNUstep from source** (`ShellScripts/Linux/build_gnustep.sh`, pinned
commits) before it compiles a line of Oolite.

That is a build-farm and headless-GL problem measured in CPU cores, NVMe, and X displays. It is
**x86-64 Linux and Windows** work. It is not inference. No LLM hardware moves that number.

---

## 2. Recommendation on the DGX Spark: don't buy it — not now, and probably not for this

Four independent reasons, strongest first:

1. **Wrong architecture for the bottleneck.** GB10 is aarch64. Your CI matrix is Linux x86-64 +
   Windows x86-64 (`.github/workflows/build-all.yaml`). The Spark cannot serve as build or
   golden-run capacity for the thing that is actually slow. The macOS GUI tier (§5.6) needs
   Accessibility + Screen Recording TCC grants and must run on your own Mac regardless — open
   decision #8 already identifies that.
2. **Ten months early, in the fastest-moving market there is.** The workload that justifies it
   (Phase 4 fan-out) starts at month 10–16. Buying inference hardware a year before you need it, in
   a market where both silicon and open-weight models turn over in well under a year, is the classic
   error. Re-evaluate at Phase 4 entry.
3. **Bandwidth profile fights interactive agentic coding.** GB10 pairs ~128 GB unified memory with
   roughly ~273 GB/s of bandwidth *(verify current figures and price before any purchase — this is
   from my training data, not measured)*. That ratio makes it a **batch-throughput** machine: good
   at 32–64 concurrent small requests, slow per single stream. Agentic coding loops are latency-
   bound single streams. The one thing it would be excellent at — bulk classification — is also the
   thing you can rent by the hour.
4. **You can pilot the entire local-model pipeline without it.** The one genuinely large batch job
   available today (§5, the expansion scan) is ~800–1,600 small independent classifications. That is
   tens of dollars of rented GPU time, or an overnight run on the Mac. Buy the answer, not the
   hardware.

> **Amended 2026-09-05 — see §12.** Running the Spark as a *network inference endpoint* for agents
> hosted on an x86-64 Windows machine defeats reason 1 entirely, and is the right architecture.
> Reasons 2–4 still say: build for that architecture now, rent the endpoint, buy the box later.

**If you want to spend money on hardware that accelerates this project today:** a self-hosted
**x86-64 Linux CI runner** — high core count, NVMe, 64–128 GB RAM. It attacks the measured
bottleneck (GNUstep + Oolite builds, 20 game launches, ASan runs) directly, and it is useful from
Phase 0 onward rather than from month 10.

---

## 3. The correction that matters most: never validate with a model

Your instinct — "frontier models for planning and validation" — is right on planning and **wrong on
validation**, in a way that would quietly destroy the project.

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

## 4. The validation architecture (this is the actual deliverable)

Your worry — "the AI will run tests in sequence, so not enough parallelism" — dissolves once the
tiers are separated. Sequential is *correct* at the agent level, provided what runs there takes
seconds.

### 4.1 Three tiers

| Tier | When | Content | Budget | Parallelism |
|---|---|---|---|---|
| **A — in-loop** | every agent edit | Compile the single TU; `clang-tidy`; symbol deny-list grep; that module's unit tests | **< 30 s** | none needed — it's seconds |
| **B — per candidate PR** | agent believes it's done | Full build, **one** platform; module tests; 3–5 fast golden scenarios; Tier-1 OXP subset | **< 10 min** | N-way across CI pool, one container per scenario |
| **C — per merge batch** | merge queue | All 3 platforms; all 20 goldens; ASan + UBSan; full Tier-1; JS API snapshot; PyAutoGUI tier | 30–90 min | batched — see 4.3 |

Tier A is what an agent iterates against. If Tier A is slow, everything else is irrelevant, because
the agent's inner loop dominates wall-clock. **Getting Tier A under 30 seconds is the single highest-
leverage engineering task in this entire document.**

### 4.2 Containerize the golden harness — the prerequisite for all parallelism

Nothing else scales until this exists. `tests/launch_snapshot.py` currently hardcodes
`PORT = 8563` and `HOST = 127.0.0.1`.

- Parameterize port and `DISPLAY`; one scenario per container, Xvfb inside.
- Bake **GNUstep + the `mozillajs-linux` artefact into a base image**, built once from the pinned
  commits. The CI presently compiles GNUstep from source on every run; this alone likely cuts
  iteration time more than any model choice you could make.
- `ccache`/`sccache` with a shared cache volume across agents.
- Emit the canonical sorted-JSON state dump (§5.2) as the container's artifact.

Scenario parallelism then becomes a scheduling problem, which is a solved one.

### 4.3 Merge queue with batch-and-bisect — the direct answer to your question

**Do not run Tier C per task.** Batch PRs that passed Tier B, run Tier C once over the batch,
and bisect only on failure:

- 16 PRs, batch passes → **1** Tier-C run instead of 16.
- 16 PRs, batch fails → 1 + log₂(16) = **5** runs. Still a 3.2× amortization.

This is how large monorepos absorb exactly this load, and it is the piece your current mental model
is missing. Parallelism comes from the *scheduler batching independent work*, not from each agent
running its own full suite.

### 4.4 Non-negotiable substrate

- **One git worktree per agent.** Without it they fight over the build directory and you will spend
  weeks debugging phantom failures.
- **Deny-list in CI** for `libgnustep-base` and `JS_*` symbols (§10.4.5) — mechanical, cheap,
  catches the regression that matters most.
- **Determinism first (§5.3).** `NSDictionary`/`NSSet` enumeration order is unspecified. If a
  gameplay path depends on it, your goldens are noise and every downstream signal is worthless.
  Nothing above works until this is done.

---

## 5. Model tiering: what runs where

| Work | Volume | Model tier | Why |
|---|---|---|---|
| Phase-0 harness design; `oofnd`, `JSEngine` façade, `oo::Ref` design | ~50 decisions | **Frontier, interactive, with you** | Determines whether the project works. Cheapest thing you will ever buy. |
| The 6 giant files (30% of lines) | 6 | **Frontier + you, weeks each** | 200k+ token dependency closures. Physically outside a local model's KV budget on 128 GB. |
| Files 1,500–4,000 lines (19 files, 22%) | 19 | Frontier, one at a time | Real design content in each. |
| Files < 1,500 lines (216 files, 48%) | 216 | Frontier sets pattern → **local model drafts, Tier B judges** | Only after `oomath` + `OXPVerifier` establish house style by hand. |
| **§5.5 scan: expansions for Mozilla-only JS** | 818–1,591 | **Local, high batch** | Small context, independent, 90% accuracy is fine — it feeds a guide, and the engine catches misses. |
| Tier-3 weekly smoke-log triage + clustering | ~1,591 logs | **Local, high batch** | Pure classification. |
| Golden-diff first-pass triage (Phase 4) | high | Local proposes → frontier adjudicates → **you re-bless** | §3. |
| 3,828 JS call sites → façade (Phase 1) | 3,828 | **Neither — `clang-refactor`** | A compiler is more correct and far cheaper than any model here. Do not spend tokens on this. |

> **Corpus size note.** MIGRATION_PLAN §5.5 cites 1,591 entries from the live API. The catalog
> checked into this repo (`upstream/oolite-expansion-catalog/expansionUrls.txt`) holds **818 unique
> URLs**. Both can be true — the file lists manifests, the API aggregates versions — but 818 is what
> is reachable offline today, and it is the number to budget the pilot against.

Two things worth internalising: the highest-volume AI work in this project is **classification, not
code generation**, and the highest-*value* AI work is a few dozen design conversations.

---

## 6. Phase-by-phase leverage map

- **Phase 0 (now, 2–4 mo)** — Build the substrate in §4. Zero fan-out, maximum leverage. Contains
  exactly one large batch job (the 1,591-expansion scan), which is your local-model pilot. §5.3
  determinism work is upstreamable as plain bug fixes and builds the credibility §10.3 wants.
- **Phase 1** — `clang-refactor` + review, not agents. Differential testing between backends is
  where Tier C earns its cost.
- **Phase 2** — The `.m` → `.mm` switch produces "a few hundred mechanical fixes": a **compiler-
  driven loop** (fix, rebuild, repeat), which a cheap model does well because the compiler is the
  oracle. `oofnd` itself is frontier design work. Note that `OOCollectionExtractors` → templated
  `PList::get` retires ~1,800 call sites in one stroke — the highest-leverage single change in the
  project, and pure design, not volume.
- **Phase 3** — Apple Silicon. Your Mac, your hands. The PyAutoGUI tier becomes load-bearing here.
- **Phase 4** — The fan-out phase. Order per §8: `oomath` → `OXPVerifier` → leaf utilities → …
  **Convert the first two by hand with a frontier model.** They set the house style that every
  subsequent agent prompt references. Fan out only after the pattern is proven and Tier A is fast.
  Freeze policy per §10.3.5 applies per module.
- **Phases 5–6** — Mechanical then design. No fleet.

---

## 7. Harness choice: defer it, and it gets easier

> **Amended 2026-09-05 — superseded in part by §13.** This section claimed no harness would give you
> a merge queue, worktree isolation, or a fast Tier A, so you would build all of it. Gas Town ships
> the first two and the watchdogs besides. The surviving half of the argument: it does *not* ship
> the golden harness, the base image, or Tier A — so the Phase 0 ordering below is unchanged.

*(Written before the §13 research. Retained for the reasoning; read §13 for the answer.)*

Every candidate gives you roughly the same thing: a work queue, a loop, and worktree isolation.
None of them gives you a containerized golden harness, a GNUstep base image, a merge queue, or a
30-second Tier A — and those are 100% of the actual engineering. Build the substrate during Phase 0
(which you must do anyway), and by Phase 4 the harness is a thin layer you can pick in a week,
against a field that will have moved considerably.

When you do choose, the criteria that matter for *this* workload:

1. Native git-worktree isolation per task.
2. Pluggable model routing per task class (§5's tiering is useless if you can't express it).
3. A merge queue, or clean integration with one — else you rebuild §4.3 yourself.
4. Resumable tasks with durable state; Phase-4 tasks take hours and CI runs fail.
5. Local-endpoint support (OpenAI-compatible) so the frontier/local split is configuration.

---

## 8. Concrete near-term sequence

1. **Determinism audit (§5.3)** — instrument `NSDictionary`/`NSSet` enumeration in a debug build,
   shuffle, find every order-dependent gameplay path, fix in Objective-C, upstream it. *Nothing
   downstream is meaningful before this.*
2. **Base image** — GNUstep at pinned commits + `mozillajs-linux` 0.0.1, prebuilt and cached.
3. **Containerize the harness** — parameterize `launch_snapshot.py`'s port/DISPLAY, one scenario per
   container, canonical JSON state dump as artifact.
4. **~20 golden scenarios**, stable across 10 consecutive runs (the §5.7 gate).
5. **Tier A under 30 seconds**, measured. Treat as a hard requirement, not an aspiration.
6. **Merge queue** with batch-and-bisect.
7. **Local-model pilot: the 1,591-expansion Mozilla-JS scan**, on rented GPU time. It is genuinely
   useful today (§5.5 calls it the most valuable input to the migration guide), it is the right
   shape for batch inference, and it tells you what a Spark would actually buy you — before you buy
   one.
8. **Re-evaluate the hardware at Phase 4 entry**, with real measurements from step 7 and a year of
   model progress in hand.

---

## 9. Verification

The substrate is working when all of these hold:

- [ ] `git bisect`-style: the same commit produces byte-identical state dumps across 10 runs on two
      different machines.
- [ ] 20 golden containers run concurrently on one host without port or display collisions.
- [ ] Tier A measured **< 30 s** on a representative leaf file (`OOColor.m`, `OORoleSet.m`).
- [ ] A deliberately introduced behavioural bug (e.g. perturb a market-price calculation) is caught
      by Tier B, not by a reviewer.
- [ ] A deliberately introduced use-after-free is caught by ASan in Tier C.
- [ ] Reintroducing a `JS_*` or `libgnustep-base` symbol fails CI on the deny-list.
- [ ] A batch of 8 PRs where one is bad: the merge queue bisects to the culprit automatically.
- [ ] The expansion scan pilot: 1,591 classified, and a hand-audited random 50 agrees with the
      model at a rate you find acceptable — *measure this before trusting any bulk model output.*

---

## 10. Anti-patterns to avoid

- **Auto-re-blessing goldens.** The single change most likely to end the project. §3.
- **Fanning out Phase 4 before `oomath` and `OXPVerifier` are hand-converted.** You would get 200
  files in 200 inconsistent styles and a review burden larger than the original work.
- **Spending tokens where a compiler works** — the 3,828 JS call sites, the `.mm` mechanical fixes.
- **Buying inference capacity to fix a build-throughput problem.** §1.3, §2.
- **Letting fork divergence run.** ~340 upstream commits/year, 6+ active contributors. Rebase
  monthly; the goldens are what make each rebase verifiable rather than a leap of faith (§10.3).
- **Building the fleet before the harness.** Agents that can't verify their own work generate
  review debt faster than they generate value.

---

## 11. Agent roles — organise by *authority*, not by task

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
| **Upstream tracker** | standing, monthly | performs the rebase, files `docs/UPSTREAM_DELTA.md` entries | any conflict inside a frozen module (§10.3.5) |
| **Adjudicator** (frontier) | on-demand | proposes a re-bless *with written justification* | **every re-bless, always** |
| **Jon** | — | merges to main · re-blesses goldens · §12 open decisions · freeze policy | — |

Four notes on this table:

1. **The reviewer is not the gate.** Tier A and Tier B are. If a review agent is the only thing
   between a translation and `main`, you have rebuilt the "model validates" antipattern (§3) with
   extra steps and more confidence. The pyramid supplies truth; the reviewer supplies taste.
2. **On "an agent to review high-level goals such as the e2e GUI tests" — don't.** That is the role
   that most needs a human. The PyAutoGUI tier (§5.6, G1–G9) exists specifically to prove the build
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

---

## 12. Hosting: agents on Windows, inference over the network

> **Amended 2026-09-05 — the agent host is Ubuntu, not Windows. See §14.** This is *better*: tmux is
> native, so Gas City needs no WSL2, and the Linux golden harness runs directly. The Windows box
> becomes a build runner rather than the agent host. Everything below about inference-over-network
> and model routing as configuration is unchanged.

Your alternative — agents on the Windows machine, the Spark reachable as a network endpoint exactly
like a hosted model — **is the right architecture, and it defeats the strongest objection in §2.**
The ARM-vs-x86 mismatch only mattered because it assumed the Spark would host the agents and their
builds. As a pure inference endpoint, its architecture is irrelevant.

```
Windows x86-64 box ── agents, worktrees, native Windows CI leg
   └─ Docker Desktop / WSL2 ── Linux containers: golden harness, ASan/UBSan, Linux CI leg
Apple Silicon Mac ─────────── Phase 3 only: macOS build + PyAutoGUI tier (TCC grants)
Inference endpoint ────────── OpenAI-compatible URL behind one config value
```

That last line is the whole point. **Make model routing configuration, not architecture.** The §5
tiering is only real if you can express "this task class → this endpoint," and once you can, the
endpoint's identity — rented GPU, a Spark on your LAN, or a frontier API — is a config change.

Which means the hardware decision genuinely defers at **zero architectural cost**: build the
indirection now, rent the endpoint for the expansion-scan pilot, and re-evaluate buying at Phase 4
entry with measurements in hand. Reasons 2 and 3 in §2 still stand; reason 1 no longer does.

Two caveats, both pointing the same way as §2.3:

- A network endpoint adds per-call latency. Harmless for batch classification, worse for
  interactive loops — which is the same conclusion reached by a different route.
- **Never put an inference endpoint on Tier A's critical path.** Tier A is compiler, linter, and
  deny-list only: no model, under 30 seconds, offline. If Tier A ever depends on the Spark being
  up, a LAN hiccup stalls every agent you have.

### Framework choice

I don't have confident current knowledge of Hermes Agent, OpenClaw, or LangChain Deep Agents, and
I'd rather say so than guess. The honest framing is that they differ mostly in how much you assemble
yourself — Deep Agents is a library you build *with*, the others are closer to turnkey harnesses —
and that **this is still the least important variable** (§7).

The de-risking move: **you already have Claude Code**, which has subagents, hooks, scheduled tasks,
and git-worktree isolation. Every role in §11 has a first version buildable with what is in front of
you — the reporter is a scheduled task, the reviewer is a hook plus a subagent, the converter is a
worktree-isolated agent. Build the roles there, discover which ones you actually use and where they
chafe, then choose a framework against **evidence** rather than a feature list. Adopting a framework
before you know your own requirements is how you end up conforming the project to the tool.

---

## 13. Framework evaluation (researched 2026-09-05)

> **Outcome moved. See §13.6.** This section evaluates Gas Town and concludes in its favour. That
> conclusion now points at **Gas City**, Gas Town's own successor SDK — the analysis below stands as
> the record of *why* this family of tools was chosen, not as the current recommendation.


§7 and §12 said the framework was the least important variable and told you to defer the choice.
**That was half wrong, and Gas Town is the reason.** I claimed no framework would give you a merge
queue, worktree isolation, or watchdogs, so you would build them yourself. Gas Town ships all three.

### 13.1 Scored against this project's actual requirements

Requirements taken from §3, §4, §11 and §12 of this document — not from generic feature lists.

| Requirement | **Gas Town** | **Deep Agents** | **Hermes Agent** | **OpenClaw** |
|---|---|---|---|---|
| Git worktree isolation per agent (§4.4) | **Yes** — "hooks" are worktrees, survive agent crashes | build it | no | no |
| **Merge queue, batch + bisect** (§4.3) | **Yes** — Refinery, Bors-style | build it | no | no |
| Agents never push to main (§11) | **Yes** — explicit invariant | build it | no | no |
| Watchdog / stuck-agent detection (§11.3) | **Yes** — Witness / Deacon / Dogs | build it | no | no |
| Role-based routing (§5, §11) | **Yes** — `role_agents` per role | build it | n/a | n/a |
| Concurrency cap / rate-limit safety | **Yes** — Scheduler capacity limits | build it | no | no |
| Local or network inference endpoint (§12) | **at CLI granularity** — see 13.3 | **Yes** — BYO model | **Yes** — 20+ providers incl. local | **Yes** — model-agnostic |
| Scheduled read-only reporting (§11.4) | partial | build it | **Yes** — its strongest fit | yes |
| Runs on the Ubuntu agent host (§14) | **Yes, natively** — tmux, subprocess, exec, ACP, k8s, herdr | yes | yes | yes |
| Substrate ships, vs. you build it | **ships** | **you build all of it** | n/a | n/a |

### 13.2 The finding that matters

Gas Town's **Refinery is a Bors-style merge queue that batches merge requests, runs verification on
the merged stack, and bisects to isolate the culprit on failure** — which is, independently, the
exact design specified in §4.3 before I knew the project existed. Its role hierarchy also lands
almost 1:1 on the authority table in §11:

| §11 role | Gas Town |
|---|---|
| Converter | Polecat — *"polecats never push directly to main"* |
| Harness steward | Witness (per-rig) / Deacon (cross-rig) / Dogs |
| Merge gate | Refinery |
| Orchestrator | Mayor |
| Jon | Crew |

Two independent designs converging on the same shape is the strongest evidence available that the
shape is right. **Adopt the design regardless of whether you adopt the tool.**

### 13.3 Where Gas Town does not fit cleanly

> *Assessed against Gas Town. What carries to Gas City: **(1) stands** — model routing is still at
> CLI granularity, so verify custom-endpoint support before committing to the Spark path (§12).
> **(2) is retired** — Gas City runs natively on the Ubuntu VM, no WSL2 (see §13.6). **(3) changes** —
> the dependency list becomes tmux, git, jq, pgrep, lsof, Go 1.26.4+. **(4) compounds** — see §13.7.*

1. **It orchestrates agent CLIs over tmux, not model endpoints.** There is no model-provider
   abstraction — `role_agents` maps roles to *CLI presets* (Claude, Codex, Copilot, Gemini, Cursor).
   The §12 Spark-over-network plan therefore works only through a CLI configured against your
   endpoint. Model tiering lands at CLI granularity, which is coarser than §5 assumes but sufficient.
2. **tmux 3.0+ is a hard dependency**, so on the Windows box it runs **inside WSL2**. You need WSL2
   anyway for the Linux golden harness and ASan, so this costs nothing — but it means the agent
   fleet and the Linux CI leg share one WSL2 environment. Size it accordingly.
3. **Dependency surface is non-trivial**: Git 2.20+, tmux 3.0+, sqlite3, Beads (`bd`) 0.57.0+,
   Claude Code CLI as default runtime, Go 1.26.2+ to build from source. A Docker Compose path exists
   and is probably the sane one.
4. **Young and moving fast** — ~7,770 commits, ~350 open issues, against a project that spans years.
   *(Corrected 2026-09-05: an earlier draft here said no changelog or versioning existed. It does —
   `CHANGELOG.md` plus tagged releases at roughly v1.2.x. My original claim came from reading only
   the README. The maturity picture is better than I first reported.)*

On (4), the mitigating structural fact: **Gas Town sits outside your repo.** It is a workspace
manager; the artifacts are git branches and the verification lives in your CI. If it breaks or is
abandoned you lose orchestration, not code, and not the safety net. That low blast radius is what
makes a fast-moving young dependency an acceptable bet here — it would not be if it were embedded.

### 13.4 The three that don't fit

- **Deep Agents** — a *library*, not a system: planning, subagents, virtual filesystem, HITL
  approvals, built on LangGraph with LangSmith for tracing. Genuinely good primitives, and the one
  real reason to consider it is **LangSmith-grade observability**, which the others lack. But it
  ships **no** worktree isolation, merge queue, CI integration, or scheduling. Choosing it means
  building 100% of the §4 substrate yourself — months of work competing directly with Phase 0, to
  arrive at what Gas Town already has. Only correct if you intend to build something bespoke.
- **Hermes Agent** — persistent memory, self-authored skills, and ~20 messaging platforms
  (Telegram, Discord, Slack, iMessage, …), any LLM provider including local. It is a *personal
  assistant*, not a fleet manager: no merge queue, no worktree isolation, no CI gate. **But it is
  the best fit in this table for one specific role — the Reporter (§11.4)** — where "reaches you on
  your phone, remembers the project, read-only" is exactly the requirement.
- **OpenClaw** — same personal-assistant category, model-agnostic, enormous adoption. Nothing in it
  addresses parallel code migration with gated merges. Not the wrong tool so much as a different
  tool.

> **On star counts.** Reported figures are roughly OpenClaw ~347k, Hermes ~175k, Deep Agents ~29k,
> Gas Town ~18k — self-reported via search, not verified, and moving fast. Note the inversion:
> **the best-fitting tool here has an order of magnitude fewer stars than the worst-fitting one.**
> Those counts measure general-purpose assistant appeal, which is close to uncorrelated with
> "can gate 500 file conversions behind a golden harness." Do not let them decide this.

### 13.5 Multi-machine workers: not today — and you don't need them

**Direct answer: no.** A town is confined to one host. The tracking issue for this is
[#2801](https://github.com/gastownhall/gastown/issues/2801), and the status there is:

| Capability | Status |
|---|---|
| mTLS proxy infrastructure (`internal/proxy/`) | exists |
| Per-polecat certificate design | complete |
| `ExecWrapper` | **designed, not landed** |
| Fleet dispatch + machine registry | **concept only** |
| Kubernetes deployment | **not actively planned** |

Two further points close it off for your case. The three enumerated use cases — Daytona cloud burst,
satellite nodes over Tailscale, k8s — all assume **Linux remote execution** (*"polecats run in remote
Linux containers"*). There is no support for a **heterogeneous Windows + Linux worker pool**, which
is precisely what you asked for. And *"single-machine users remain unaffected"* — the local path is
the supported one.

(Two adjacent features exist but solve different problems: **Wasteland** federates *separate towns*
via DoltHub — coordination between independent towns, not one town spanning hosts. **`GT_DOLT_HOST`**
puts the *state database* on another machine over Tailscale — remote state, not remote agents.)

**But cross-platform builds are not an agent-placement problem.** You do not put an agent on each
platform to verify each platform; you put a *build* on each platform. Gas Town's **gates are
pluggable commands**, so the Refinery gate becomes "trigger CI, wait, return the exit code," and CI
fans out:

```
ONE Gas City  (Ubuntu VM — needs tmux/git/jq/pgrep/lsof)
  └─ Refinery gate = trigger CI + wait
        ├─ Linux x86-64   runner ── build, goldens, ASan/UBSan
        ├─ Windows x86-64 runner ── build (native, no WSL)
        └─ macOS arm64    runner ── Phase 3: your Mac, self-hosted (TCC grants)
```

You already have the Linux + Windows matrix in `.github/workflows/build-all.yaml`. §10.4 requires
three-platform builds *per PR* regardless of how agents are arranged — that has always been CI's
job, not the fleet's.

This is strictly better than distributed agents would be, for a reason worth stating: **verification
must run on clean machines.** A cross-platform build executed on a host where agents are actively
mutating worktrees is not evidence of anything. Keeping agents on one host and verification in CI
enforces that separation structurally rather than by discipline.

> **The recurring lesson, third time in this document.** §2: the agent host is not the inference
> host. §12: the agent host is not the build host. Here: agent placement is not verification
> placement. Each time the instinct is to co-locate, and each time the fix is to keep the control
> plane in one place and fan the *work* out. Notice it now and it will save you the next three
> architecture decisions.

---
### 13.6 Recommendation

**Use more than one. The roles have different requirements.**

| Role | Tool | When |
|---|---|---|
| **Reporter** (§11.4) | **Hermes Agent** — or a scheduled Claude Code task | **now** — read-only, therefore safe |
| Converter / Reviewer / Refinery / Witness (§11) | **Gas City**, on the Ubuntu VM | **decided — see amendment below** |
| Adjudication, design, the 6 giant files | Frontier model, interactive | throughout |
| — | *not* Deep Agents unless you want a bespoke build | — |
| — | *not* OpenClaw for this workload | — |

> **Amended 2026-09-06 — decision: Gas City.** Gas Town is superseded by
> [gastownhall/gascity](https://github.com/gastownhall/gascity), its own successor: the same authors'
> extraction of Gas Town's reusable infrastructure into a "primitive-first" orchestration-builder
> SDK. Declarative `city.toml`; **rigs** (project dirs) inside **cities**; **beads**-backed work
> tracking (file- or dolt-backed) with **formulas**, **molecules**, **waits** and **mail**; **sling**
> for work dispatch; a **mayor** supervisory session; and runtime providers spanning tmux,
> subprocess, exec, ACP, Kubernetes and herdr.
>
> Two consequences worth recording now:
>
> 1. **No WSL2.** Gas City requires a Unix runtime — `tmux`, `git`, `jq`, `pgrep`, `lsof` always;
>    Go 1.26.4+ to build. It therefore runs natively on the **Ubuntu VM** (§14.3) rather than in
>    WSL2 on the Windows box, which removes a layer this document previously accepted.
> 2. **§13.5's "not today" on multi-machine workers gets a real escape hatch.** Gas City ships a
>    Kubernetes runtime provider, so scaling out later is a config change rather than a rewrite.
>    That does *not* change the recommendation to stay single-host now — it lowers the cost of
>    being wrong about it.
>
> **Unchanged:** the separation principle. Agents live on the agent host; verification runs on
> clean CI runners (§13.5). Gas City's Kubernetes provider makes it *easier* to blur that line, and
> it must not be used to.

**What does not change: no orchestrator is a substitute for Phase 0.** Its Refinery runs *your*
verification gates and is only ever as good as the checks behind it. A merge queue with no goldens
behind it is a very efficient way to merge broken code at scale. The order stands — determinism
fixes, base image, containerized harness, 20 stable goldens, Tier A under 30 seconds — and *then*
a fleet to feed it.

**Sources:** [gastownhall/gascity](https://github.com/gastownhall/gascity) ·
[gastownhall/gastown](https://github.com/gastownhall/gastown) ·
[agent-provider-integration.md](https://github.com/gastownhall/gastown/blob/main/docs/agent-provider-integration.md) ·
[gastownhall/gascity](https://github.com/gastownhall/gascity) ·
[langchain-ai/deepagents](https://github.com/langchain-ai/deepagents) ·
[LangChain Deep Agents](https://www.langchain.com/deep-agents) ·
[NousResearch/hermes-agent](https://github.com/nousresearch/hermes-agent) ·
[Hermes Agent docs](https://hermes-agent.nousresearch.com/docs/) ·
[OpenClaw (Wikipedia)](https://en.wikipedia.org/wiki/OpenClaw)

---

### 13.7 One refinement: roles are *pack conventions*, not SDK primitives

Verified 2026-09-06, and it slightly changes what "Gas City ships the substrate" means. The decisive
line from the docs:

> Gas City has **no baked-in role names in its Go codebase**; these are instead **pack conventions**
> defined through prompts, formulas, orders, and configuration rather than SDK primitives.

Gas Town was not deleted — its machinery was extracted *downward* into Gas City, and Gas Town
survives above it as a configuration layer, an example pack. So the Refinery, the worktree lifecycle,
and the role hierarchy are all still there, but they arrive **as configuration you own and edit**
rather than as fixed behaviour.

Three consequences:

1. **Start from the Gastown pack; do not compose roles from scratch.** It is the reference
   configuration for exactly the topology §11 describes. Treat it as a starting point you maintain.
2. **This is a genuine upside for this project.** §11 defines an *authority* model — Converter
   commits only to its own branch, Reviewer is advisory and cannot merge, only Jon re-blesses a
   golden. Under fixed roles those were approximated. Under Gas City, **roles are configuration, so
   §11 becomes something you express exactly.** Given that §3 names auto-re-blessing as the single
   change most likely to end the project, being able to encode the human-only gate explicitly is
   worth real setup cost.
3. **Budget for configuration work, and pin versions.** Every role is prompts, formulas, orders and
   `city.toml`; explicit agent identity is now required (the docs warn: *"do not port code or prompts
   that assume directory path implies who the agent is"*). And the maturity picture compounds — Gas
   City is ~1.2k stars / ~5,917 commits / MIT, younger and far less adopted than Gas Town's ~18k,
   and you would depend on a fast-moving SDK *plus* a pack convention on top of it, across a
   multi-year project.

The mitigation from §13.3 is unchanged and still decisive: **it sits outside your repo.** Artifacts
are git branches; verification lives in CI. If it breaks or is abandoned you lose orchestration, not
code and not the safety net.

**Sources:** [gastownhall/gascity](https://github.com/gastownhall/gascity) ·
[coming-from-gastown.md](https://github.com/gastownhall/gascity/blob/main/docs/getting-started/coming-from-gastown.md) ·
[Gastown example & agent roles (DeepWiki)](https://deepwiki.com/gastownhall/gascity/11-gastown-example-and-agent-roles) ·
[cities-and-rigs tutorial](https://github.com/gastownhall/gascity/blob/main/docs/tutorials/01-cities-and-rigs.md)

---

## 14. CI/CD setup (Ubuntu agent host)

Answering the concrete question: the agent fleet runs on Ubuntu; Windows and Linux builds must both
be verified. Note first that **an Ubuntu agent host is better than the Windows one assumed in §12** —
tmux is native, so Gas City runs without WSL2, and the Linux golden harness runs without a
compatibility layer. Revise §12's topology accordingly.

### 14.1 Forgejo vs Argo: not the same category

- **Argo CD** is GitOps *continuous deployment* for Kubernetes — it reconciles manifests into
  clusters. You are producing desktop binaries for three operating systems. Wrong tool.
- **Argo Workflows** is a k8s-native DAG engine that *could* run builds, but it requires a cluster,
  and **Windows builds on Kubernetes are genuinely painful** — Windows containers need Windows
  nodes, and MSYS2 inside a Windows container is a rabbit hole with no payoff here.
- **Forgejo** ships **Forgejo Actions**, which is GitHub-Actions-compatible via `act_runner`. It maps
  onto the existing `build-all.yaml` almost directly.

So: **Forgejo over Argo, decisively.** But that is the second question, and the first one matters
more.

### 14.2 Don't move the forge — add self-hosted runners

The reasons to self-host are all about *runners*, not about the git host:

| Driver | Needs self-hosted runner | Needs a different forge |
|---|---|---|
| GNUstep built from source dominates every run | **yes** — persistent cache / baked image | no |
| 20 golden scenarios launching a real GL game | **yes** — GPU or a well-provisioned host | no |
| macOS GUI tier needs TCC grants (open decision #8) | **yes** — must be your Mac | no |
| CI minutes cost on a private repo | yes | maybe |

And there is a strong reason *not* to move: **upstream lives on GitHub.** §10.3 tells you to rebase
monthly and to upstream everything that isn't the rewrite — determinism fixes, harness improvements,
build fixes. Keeping `origin` on GitHub keeps that frictionless. Moving the forge to make CI faster
solves a runner problem with a migration.

**Recommendation: GitHub Actions with your own self-hosted runners.** Revisit Forgejo only if you
later want the project fully off GitHub; §14.5 covers what that would cost.

### 14.3 Topology

| Machine | Runner label | Role |
|---|---|---|
| **Ubuntu box** | `self-hosted, linux, x64` | Gas City + agents; Linux build; golden harness; ASan/UBSan |
| **Windows box** | `self-hosted, windows, x64` | MSYS2 UCRT64 build + Windows goldens |
| **Mac (Apple Silicon)** | `self-hosted, macos, arm64` | Phase 3 onward: macOS build + PyAutoGUI tier |

Two rules for the Ubuntu box, which is doing double duty:

1. **Agents and verification must not share a workspace.** Runner jobs execute in containers; agent
   worktrees live outside them. A build that reads a tree an agent is concurrently mutating proves
   nothing.
2. **Size for concurrent game instances.** Twenty golden scenarios means twenty processes each
   holding a GL context. Mesa `llvmpipe` under Xvfb is sufficient for Oolite's GL 2.1 compatibility
   profile (§2.7: GLSL 1.10/1.20, no `#version`) and needs no GPU — but it is slow, and RAM is the
   binding constraint. A real GPU with headless EGL is the upgrade path if scenario wall-clock
   becomes the bottleneck.

### 14.4 The two wins that matter more than the CI product

Both come from self-hosting, and both attack the measured bottleneck in §1.3:

1. **Bake GNUstep into an image.** `ShellScripts/Linux/build_gnustep.sh` pins its inputs by commit
   hash, so the result is reproducible and cacheable. Build `oolite-ci-linux:gnustep-<pin>` once,
   rebuild only when a pin moves. This is the §4.2 base image, and it likely cuts iteration time
   more than any other single change.
2. **Pre-provision MSYS2 on the Windows runner.** The hosted workflow spends real time on
   `msys2/setup-msys2@v2` plus `ShellScripts/Windows/install_deps.sh clang` on every run. On a
   self-hosted box you install UCRT64 and the dependencies **once**. This also removes the main
   third-party-action dependency, which is what would otherwise block a Forgejo port later.

### 14.5 On cross-compiling Windows from the Ubuntu box

Tempting — one machine verifies both — but read the tradeoff before committing:

- `clang.ini` is a meson **native** file (`[binaries]` only). Cross-compiling needs a new **cross
  file** plus a MinGW-w64 toolchain, and `src/meson/meson.build` dispatches on
  `host_os == 'windows'`, so the Windows subdir would need to work under a non-MSYS2 toolchain.
- It diverges from upstream's MSYS2/UCRT64 path, which makes **open decision #7** (MinGW-clang vs
  clang-cl) urgent well before you wanted to answer it.
- **Decisive:** a cross-compiled Windows binary cannot run the goldens on Linux. You would get
  compile verification only.

So cross-compilation is at best an *early-warning* signal, never a substitute. Tier it instead:

| Tier | Where | What it proves |
|---|---|---|
| **B** (per PR) | Ubuntu box | Linux build + fast goldens — catches the large majority of translation breakage, since most of it is compile errors or behaviour changes visible on Linux |
| **C** (per merge batch) | + Windows + macOS runners | Native Windows build **and** Windows goldens; ASan/UBSan; the full §10.4 three-platform gate |

§10.4 requires three-platform builds per PR. Batching through the Refinery (§4.3) satisfies that
economically: the gate runs on the batch, and bisection identifies the culprit when it fails.
Adding a Linux→Windows cross-compile smoke to Tier B is a reasonable optional extra — buy it only
if Windows-specific compile breakage actually shows up in practice.

### 14.6 Wiring the Refinery to CI

Gas City exposes **GitHub gates** for release verification, and gates are pluggable commands, so the
gate is a script that triggers CI and blocks on the result:

```bash
gh workflow run verify.yml --ref "$BRANCH" \
  && gh run watch "$(gh run list --workflow=verify.yml --branch="$BRANCH" \
       --limit=1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

`gh run watch --exit-status` propagates the failure, which is all the Refinery needs. Keep the gate
thin: it schedules and waits, it does not build.

> **Security note.** Self-hosted runners execute agent-authored code on your machines. On a private
> repo with only your own agents that is fine. **If this fork is ever made public, self-hosted
> runners plus pull requests from forks means arbitrary code execution on your hardware** — GitHub
> documents this explicitly. Decide the fork's visibility (§12, open decision #2) *before* attaching
> self-hosted runners.

---

## 15. Task granularity: the grain a fleet story must have

§§1–14 answer *what architecture executes the work*. This section answers the question that sits
underneath it: **how small must a single task be before a ~Sonnet-4.6-class local model can finish
it in its entirety?** The two are independent — the best harness in the world cannot rescue a task
that is specified at the wrong altitude.

### 15.1 The gap: `MIGRATION_PLAN.md` stops two levels short

| Level | Example | Size | In `MIGRATION_PLAN.md`? |
|---|---|---|---|
| **L0** Phase | "Phase 2 — `oofnd`" | 6–10 eng-months | ✅ §7 |
| **L1** Plan item | "§7.2 build `oofnd` bottom-up" | weeks | ✅ §7.2 |
| **L2** Component | "`PList` + old-style **and** XML parser/writer" | ~2 weeks | ✅ — *its finest grain* |
| **L3** Story | "Old-style plist scanner: quoted strings + `\U` escapes; `test_plist_oldstyle_strings.cpp` cases 1–14 go green" | ~half a day | ❌ **missing** |

Any memoryless work loop — Gas City's **beads**, or a Ralph-style `prd.json` story — spawns a fresh
instance per unit with **no memory of previous work** and decides "done" from acceptance criteria
alone. It consumes L3. `MIGRATION_PLAN.md` provides L2.

**This section is harness-independent.** Grain is a property of the task, not of the orchestrator:
switching from Ralph to Gas City changes how a unit is stored, dispatched and closed, but not how
small it has to be. §15.2 survives the switch unchanged; §15.3's mechanics are the part that binds
to a specific harness.

**Scale of the shortfall.** At one L3 story ≈ 0.5–1 eng-day and ~20 eng-days/eng-month, against
`MIGRATION_PLAN.md` §11's own estimates:

| Scope | Eng-months | Eng-days | Est. L3 stories |
|---|---:|---:|---:|
| Phases 0–3 | 13–23 | 260–460 | ~260–920 |
| Phase 4 alone | 12–24 | 240–480 | ~240–960 |
| **Whole migration** | 30–59 | 600–1,180 | **~600–2,360** |

Cross-check on Phase 4, bottom-up from the measured `.m` histogram (§1.1) rather than from §11 —
138 files ≤400 lines at 1 story each, 62 at ~1.5, 30 at ~3, 11 at ~7 → **≈400 stories**, inside the
240–960 band.

`MIGRATION_PLAN.md` §§1–12 contain **51 numbered items**, so the fleet needs roughly **11–46× more
items than exist today**. That is the operative finding: **the story list cannot be hand-authored**
(§15.4).

### 15.2 The seven-check sizing rule

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
241 are ≤400, so most of Phase 4 is genuinely one story per file.

**The rule is self-diagnosing — read *which* checks fail:**

| Failure pattern | Diagnosis | Action |
|---|---|---|
| Only 5 and 7 fail | It is a **seam** | Human/frontier work; replications follow it (§11) |
| 1, 2, 4 or 6 fail | It is **too big** | Split further before anything else |
| 4 alone fails | **Not verifiable** | Write the test first, as its own story |

**Worked calibration.** `MIGRATION_PLAN.md` §5.6's **G1 scores 5/7**, failing only 5 and 7 — so G1
is the *seam* that defines the GUI-test harness (the `row → screen point` helper §5.6 describes but
never specifies), and G2–G9 are its replications. §7.2's "`PList` + old-style and XML
parser/writer" scores **2/7**, failing 2, 4, 5, 6 and 7 — too big *and* unverifiable as written.

G1–G9 remain the closest thing to L3 stories anywhere in either document: **use them as the
calibration exemplar** for the right grain.

### 15.3 Hazards of a memoryless work loop

§3 establishes that models never validate. Three failure modes follow from memorylessness itself
and must be written into every work unit, whatever the harness calls it:

- **Reward-hacking the goldens.** The cheapest way to make a golden pass is to edit the golden.
  Every story carries, verbatim: *do not modify files under `goldens/`; do not modify the test; do
  not add `-Wno-*` or `#pragma` to silence warnings.*
- **The agent must not close its own unit.** A model that cannot build will report success anyway.
  Whatever marks a unit done — a Ralph `passes` field, a Gas City bead transition — must be written
  by an external wrapper that ran the acceptance command, never by the agent. Same principle as §3,
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

### 15.4 Generate stories, don't author them

11–46× more items than exist today is not a writing task. Per sweep, script a generator that walks
an inventory and emits one story per unit from a fixed template:

| Sweep | Unit | Inventory command | Est. stories |
|---|---|---|---:|
| JS retarget (Phase 1) | one file | `grep -rl 'jsapi.h\|OOJavaScriptEngine.h' src` | ~110 |
| `OOCollectionExtractors` retirement | one file | `grep -rl 'oo_[a-zA-Z]*ForKey' src` | ~150 |
| Foundation → `oofnd` | one file, in §7.3's order | `grep -rl 'NSString\|NSDictionary\|NSArray' src` | ~250–400 |
| ObjC → C++ (Phase 4) | one file ≤400 lines; larger pre-split | `find src -name '*.m' -size -20k` | ~350–800 |

Each generated story inherits the §15.3 criteria and prohibitions, the seam's exemplar path, and
`priority` from the dependency order already given in `MIGRATION_PLAN.md` §7.3 and §8.

The generator is itself fleet-unsuitable — it encodes the story template, which is a design
decision. Write it once, by hand, before the first sweep.

---

## Summary

Your parallelism worry is well-founded but misdirected: sequential testing inside one agent is fine,
because the fix is a **tiered pyramid plus a batching merge queue**, not more concurrent agents.
The largest fan-out is 17.5% of the code in the small files and peaks in Phase 4, but it does not
*begin* there — the Phase 1 and 2 sweeps are ~360–510 replication stories that start as soon as the
harness exists and their seams are cut (§1.2, amended). The 30% living in six giant files is
frontier-and-human work no fleet will touch.

The multi-agent instinct is right, but organise the roles by **authority** rather than by task, and
note that the role most needed is the one least often listed: a **harness steward** who owns the
integrity of the safety net. Reviewing high-level goals — the GUI tier especially — stays human.

Hosting agents on x86-64 Windows and reaching inference over the network is the correct shape, and
it removes the architectural objection to a Spark entirely. Build that indirection now so model
routing is configuration; rent the endpoint for the expansion-scan pilot; buy hardware at Phase 4
entry if the measurements justify it.

On frameworks: **Gas City is the decision** (§13.6, amended 2026-09-06) — the successor SDK that
extracts Gas Town's infrastructure into a primitive-first model, so the §13 evaluation that selected
Gas Town carries over to it. It needs no WSL2: tmux is native on the Ubuntu agent host. Pair it with
**Hermes Agent for the Reporter role now**. Deep Agents means building the whole substrate yourself;
OpenClaw is a different tool for a different job. None of them substitutes for Phase 0.

> **Resolved 2026-09-06 — batch-and-bisect survives the extraction.** The open question here was
> whether the Refinery's *batching and bisection* (§4.3) carry over from Gas Town into Gas City. They
> do: Gas City's docs describe the Refinery processing completed polecat work through **a Bors-style
> bisecting merge queue in which polecats never push directly to main**, with the polecat lifecycle
> intact — pick up a bead, open a worktree, file a merge request, get recycled. The specific property
> §4.3 depends on is present. One refinement to how it is provided: see §13.7.

Separately from architecture: `MIGRATION_PLAN.md` is written two levels above the grain a fleet
story needs, and closing that gap means **11–46× more items than it contains today** — which is a
generator's job, not an author's. §15 gives the seven-check sizing rule, its calibration against
G1 and the `PList` component, and the hazards of a memoryless work loop.

Throughout: keep verification mechanical — goldens, sanitizers, and symbol deny-lists decide
correctness. Models only ever propose.
