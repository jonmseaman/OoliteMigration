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

### 1.2 The parallelizable phase arrives last

| Phase | Est. (eng-mo) | Fan-out potential |
|---|---:|---|
| 0 — harness, determinism, corpus | 2–4 | **None.** Design work; one harness, built once. |
| 1 — JS façade + QuickJS-ng | 4–7 | Low. 3,828 call sites, but §6 already says `clang-refactor`. |
| 2 — ObjC++ switch + `oofnd` | 6–10 | Low. A few hundred mechanical fixes, then library *design*. |
| 3 — Apple Silicon build/sign/CI | 1–2 | None. |
| **4 — ObjC → C++23, ~500 files** | **12–24** | **High — this is the only real fan-out phase.** |
| 5 — remove ObjC runtime | 1–2 | None. Mechanical, one pass. |
| 6 — modernise | 4–10 | Low. Design changes by definition. |

Phase 4 begins after Phase 3, i.e. **month 10–16**. Everything before it — the part with the clear
payoff (macOS support, maintained JS engine, no GNUstep) — is essentially unparallelizable.

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

I don't have confident current knowledge of OpenClaw or Hermes Agent's state, and I'd rather say so
than guess at a purchase-adjacent recommendation. But the stronger point is that **the harness is
the least important variable here.**

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

## Summary

Your parallelism worry is well-founded but misdirected: sequential testing inside one agent is fine,
because the fix is a **tiered pyramid plus a batching merge queue**, not more concurrent agents.
The fan-out-able work is 17.5% of the code in the small files, it arrives at month 10–16, and the
30% living in six giant files is frontier-and-human work no fleet will touch.

The multi-agent instinct is right, but organise the roles by **authority** rather than by task, and
note that the role most needed is the one least often listed: a **harness steward** who owns the
integrity of the safety net. Reviewing high-level goals — the GUI tier especially — stays human.

Hosting agents on x86-64 Windows and reaching inference over the network is the correct shape, and
it removes the architectural objection to a Spark entirely. Build that indirection now so model
routing is configuration; rent the endpoint for the expansion-scan pilot; buy hardware at Phase 4
entry if the measurements justify it.

Throughout: keep verification mechanical — goldens, sanitizers, and symbol deny-lists decide
correctness. Models only ever propose.
