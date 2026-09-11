# ADR-0015: Hermes Agent `/goal` drives the local-model sweeps; Claude Code is the frontier

**Status:** Accepted · **Date:** 2026-09-10 · **Amends:** [ADR-0014](0014-claude-code-opencode-beads.md) (replaces its OpenCode row)

## Context

ADR-0014 assigned the endpoint-routed, cheaper-model role to OpenCode, driven one story at a time
by an external wrapper. Jon's decision (2026-09-10): Claude Code is the frontier model for certain;
the cheaper on-prem models are driven by **Hermes Agent in `/goal` mode**, which keeps working
until a goal condition holds — here, "all fleet beads in the current phase are closed".

That changes the loop's shape. In ADR-0014 the wrapper was the driver and the agent was memoryless
per story. With `/goal`, **Hermes is the driver**: one long-running agent with persistent memory,
picking beads itself. What must not change is the rule from [execution-model §8.3](../execution-model.md):
**the agent never closes its own unit.** The cheapest way to satisfy "all beads closed" is to
close them, and a goal-seeking loop will find that path if it exists.

## Decision

| Concern | Mechanism |
|---|---|
| **Frontier** (seams, adjudication, giant files, interactive) | **Claude Code.** Interactive for seams; `claude -p` under `tools/fleet/run-story` for frontier-tier stories, memoryless per story. Unchanged from ADR-0014. |
| **Local tier** (sweep stories, expansion-scan classification) | **Hermes Agent `/goal`**, configured against the on-prem OpenAI-compatible endpoint(s). Goal: `tools/fleet/goal-check <phase>` exits 0. Hermes picks from `bd ready`, works in a worktree, and calls `tools/fleet/accept`. OpenCode is dropped; it remains the fallback if `/goal` proves unsuitable. |
| **`tools/fleet/accept <bead>`** (new, the load-bearing piece) | Runs the story's acceptance commands **in a fresh clone of the bead's branch**, never in the agent's worktree; on exit 0 it runs `bd close`, on failure it appends the output to the bead's notes and releases the claim. Hermes calls it; Hermes cannot make it pass except by making the branch pass. `bd close` is otherwise denied to agents (tool allow-list plus a `bd` hook that rejects closes not made by `accept`). |
| **`tools/fleet/goal-check <phase>`** (new) | Exit 0 iff no open bead carries both `phase:<N>` and `fleet`. Beads for Jon (`rebless`, `proposed-adr`) and seams (`frontier`) do not carry `fleet`, so the goal is reachable without a human and Hermes never spins on work it cannot do. |
| **Worktrees** | `tools/fleet/worktree <bead>` creates and later removes them; Hermes uses it rather than working in the main checkout. |
| **Watchdog** | Hermes's own loop plus the Reporter flagging beads claimed longer than N hours; `accept` has a hard timeout. |
| **Memory** | Hermes's persistent memory is a convenience, not the carry-over channel. The bead's notes remain the only state that must survive, because a Hermes session can be restarted and because the same bead may later be picked up by `run-story`. |
| **Reporter** | Unchanged: a scheduled read-only Claude Code task. Delivering it through Hermes's messaging integrations is optional and, if done, uses a separate read-only Hermes profile with no repo write access. |

## Consequences

- **`accept` replaces "the wrapper" as the thing that matters.** Both drivers (`run-story` for
  Claude Code, Hermes `/goal` for the local tier) funnel through it, so the Phase 0 exit criterion
  becomes: an agent that attempts `bd close` directly is refused, and `accept` closes only on a
  green run in a clean clone.
- **Goal definition is a label discipline.** `tools/gen-stories` must label every generated bead
  `fleet` and `phase:<N>`; seams get `frontier`; human items get `rebless` or `proposed-adr`. A
  mislabelled bead either starves the fleet or sends Hermes at a seam.
- **A long-running agent accumulates context and habits.** Hermes's memory may carry a wrong
  pattern from one story into the next in a way a memoryless run cannot. Mitigation: the exemplar
  path in every bead is the style authority, Tier A/B stay the correctness authority, and the
  Reviewer pass flags style drift across a sweep. Track first-try Tier-B pass rate per sweep
  ([I4](../infra/4-metrics.md)); a falling trend inside one Hermes session is the signal to restart it.
- The tool-permission story is now split: Claude Code allow-lists under `run-story`; Hermes's
  tool config for the `/goal` profile. Both deny `git push`, `bd close`, and writes under `goldens/`.
- Model routing is Hermes's provider configuration for the local tier and Claude Code's own
  provider for the frontier tier. Still a config change, still never on Tier A's path (ADR-0005).

## History

ADR-0006 first proposed Hermes, for the Reporter. ADR-0014 dropped it in favour of OpenCode for the
local tier. This ADR brings it back for the local tier's *driver* role, which is a better fit for
`/goal` than the Reporter ever was.

> **Amended 2026-09-11 (Jon).** The frontier model is **Claude Opus 5**: every `claude -p` in
> `run-story`, `reevaluate.sh` and the Reporter passes `--model claude-opus-5`
> (`BEADS_FRONTIER_MODEL` overrides). Interactive frontier sessions use the same model.
>
> **Amended 2026-09-11 (Jon), phase reviews.** Every phase has a `<N>.review` bead, delegated to
> **Claude Fable 5.1** (bead metadata `model=claude-fable-5-1`), that verifies all of the phase's work
> is done, re-runs sampled acceptance on `main`, and files any missing work as new beads
> (`sweep:review-<N>`) it then waits on. The exit gate `<N>.gate` depends on the review.
