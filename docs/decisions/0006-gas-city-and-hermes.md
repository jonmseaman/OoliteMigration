# ADR-0006: Gas City (with the Gastown pack) for the fleet; Hermes Agent for the Reporter

**Status:** Accepted · **Date:** 2026-09-06

## Context

Candidates evaluated 2026-09-05: Gas Town, LangChain Deep Agents, Hermes Agent, OpenClaw. Scored
against this project's requirements: worktree isolation per agent, a batch-and-bisect merge queue,
agents never pushing to main, stuck-agent detection, role-based routing, concurrency caps, local or
network inference, scheduled read-only reporting, runs on a Unix host.

Gas Town scored highest and its Refinery is, independently, the exact Bors-style batch-and-bisect
merge queue this project had already specified. Its role hierarchy lands almost 1:1 on the
authority table. Deep Agents is a library (you build the entire substrate). Hermes and OpenClaw are
personal assistants, not fleet managers. Star counts are inversely correlated with fit here.

Gas Town has since been superseded by **Gas City**, the same authors' extraction of Gas Town's
infrastructure into a primitive-first SDK (`city.toml`, rigs, beads, formulas, sling, mayor;
runtime providers: tmux, subprocess, exec, ACP, Kubernetes, herdr). Gas Town survives above it as a
configuration layer / example pack. Verified 2026-09-06: batch-and-bisect and the polecat worktree
lifecycle survive the extraction.

## Decision

- **Gas City**, starting from the **Gastown pack**, for Converter / Reviewer / Refinery / Witness.
- **Hermes Agent** (or a scheduled Claude Code task) for the Reporter, now. Read-only, so safe.
- Frontier model, interactive, for adjudication, design, and the six giant files.
- Not Deep Agents; not OpenClaw.

## Consequences

- **Roles are pack conventions, not SDK primitives.** Gas City has no baked-in role names. The
  authority model becomes something expressed exactly in prompts, formulas, orders and `city.toml`
  rather than approximated. Budget for configuration work and pin versions.
- Gas City needs a Unix runtime (tmux, git, jq, pgrep, lsof; Go 1.26.4+ to build). It runs in
  **WSL2 on the single Windows machine** ([ADR-0010](0010-single-windows-machine.md); an
  interim decision for a native Ubuntu host, ADR-0007, was superseded).
- Model routing is at **CLI granularity** (`role_agents` maps roles to CLI presets). Verify custom
  OpenAI-compatible endpoint support before betting the ADR-0005 routing plan on it.
- Multi-machine workers are not supported today and are not needed: agents stay on one host,
  verification fans out through CI (see [infra/2](../infra/2-forge-and-runners.md)). Gas City's
  Kubernetes provider is an escape hatch, not a plan, and must not be used to blur that line.
- Maturity risk (~1.2k stars, fast-moving, young) is acceptable because it sits *outside* the
  repo: artifacts are git branches, verification lives in CI. If it breaks you lose orchestration,
  not code and not the safety net.
- **No orchestrator substitutes for Phase 0.** A merge queue with no goldens behind it merges broken
  code at scale.
- Whatever marks a work unit done (a bead transition) is written by an external wrapper that ran the
  acceptance command, never by the agent.

## History

`AI_EXECUTION_PLAN.md` §7 (defer the choice), §12 (framework paragraph), §13 (evaluation, Gas Town),
§13.6 amendment (Gas City), §13.7 (roles are pack conventions). Sources listed there:
gastownhall/gascity, gastownhall/gastown, langchain-ai/deepagents, NousResearch/hermes-agent.
