# ADR-0013: Decide up front; the human is in exactly four places

**Status:** Accepted · **Date:** 2026-09-10

## Context

The stated purpose of the project is to see how much of it AI tools can complete to quality. The
2026-09-06 docs left twelve decisions "open, owner Jon", assigned every seam to "Jon + frontier",
and made Jon the merge gate for every PR. Each of those is a place where the fleet stops and waits
for a human. Jon's instruction (2026-09-10): anything that requires him is decided up front, and
his involvement is minimised.

## Decision

**Jon's irreducible responsibilities**, and nothing else:

| # | What | Why it cannot be an agent | Cadence |
|---|---|---|---|
| 1 | **Re-bless a golden** | The one verification step that cannot be mechanical: a behaviour change is being declared correct. Automating it ends the project (execution-model §2). | batched: the Adjudicator queues proposals, Jon reviews the queue weekly |
| 2 | **Accounts, credentials, hardware** | GitHub/Forgejo accounts and runner tokens; API keys and billing; Apple signing and notarisation identity; buying RAM/NVMe; the macOS TCC grants (Accessibility, Screen Recording), which are interactive by design | once each, mostly in I0–I2 and at Phase 5 entry |
| 3 | **Override a default decision** | Every open decision now has a decided default (below). Jon may supersede any of them with a new ADR. Nobody waits for him to. | ad hoc |
| 4 | **Judge whether the GUI tier still means something** | Plausible drift in "is this a real application" is undetectable by the thing that drifted (execution-model §5 note 2) | monthly, prompted by the Reporter; never blocking |

**Everything else is an agent's job.** Specifically:

- **Merging to `main` is automatic.** `tools/merge-queue` merges a batch when Tier C is green. Jon does
  not approve PRs. (Supersedes "Jon alone merges to main" in the authority table.)
- **Seams are done by a frontier agent in an interactive session, not by Jon.** The Seams tables
  in the phase docs now read "Frontier agent". Jon is *informed* through the Reporter, not
  consulted. If a seam genuinely needs a human judgement, the agent files it as a proposed ADR
  with a recommended default and proceeds on that default.
- **Benchmarks, spikes, and triage are agent stories** with a numeric threshold that decides the
  outcome; the threshold is written into the story so no human reads the result to decide.
- **Upstream PRs**, if any, are drafted by the Upstream-tracker agent and batched; whether Jon
  clicks "create pull request" is optional and never gates anything.

**All twelve roadmap decisions are decided now**, by taking each recorded recommendation as the
decision. The roadmap table records them as *decided (default)*. Rationale for each stays in the
ADR or phase doc it came from.

| # | Decided |
|---:|---|
| 1 | No SpiderMonkey aarch64 spike. QuickJS-ng is committed (ADR-0002); with Apple Silicon at Phase 5 there is no early macOS build to justify it. |
| 2 | Private fork. Upstreamable fixes are batched and offered at Phase 5; nothing depends on upstream accepting them. |
| 3 | Conservative C++20 during conversion; C++23 in Phase 6 (ADR-0001, ADR-0011). |
| 4 | `std::string`. A Phase 2 story benchmarks golden wall-clock before/after the String seam; > 5% regression escalates via the Reporter, else nothing happens. |
| 5 | GL 3.3 Core in Phase 6 (ADR-0004). Pulled forward only if Apple removes legacy GL before Phase 5. |
| 6 | Legacy AI and plist scripting are ported faithfully. No sunset. |
| 7 | MinGW-clang, upstream's toolchain. Revisit only in the Phase 6 C++23 upgrade if library coverage forces it. |
| 8 | Self-hosted runner on the Mac from Phase 5. Jon grants TCC once (responsibility 2). |
| 9 | GitHub stays `origin`; a Forgejo push-mirror owns CI and the self-hosted runners; the merge-queue gate targets Forgejo (ADR-0008 → Accepted). |
| 10 | Closed by ADR-0010: one Windows machine, WSL2 for the Unix leg. |
| 11 | Per-platform blessed goldens **and** float quantisation in the dump; `-ffp-contract=off`; pinned `-O` for golden builds. |
| 12 | `clang-refactor` for the ~40% stub/numeric JS patterns, fleet for the rest. |

## Consequences

- The fleet never blocks on Jon between weekly re-bless reviews. If it does, that is a bug in the
  stories or the pack configuration, and it is logged in `docs/fleet/FLEET_FAILURES.md` (I4).
- "Jon + frontier" and "Owner: Jon" disappear from the phase and infra docs.
- The authority table's Jon row shrinks to the four items above. The Reporter's weekly message
  includes the re-bless queue and any proposed ADRs awaiting override.
- A decision that turns out badly is reversed by superseding ADR, which is cheap; a decision that
  waits on a human for a month is not.
