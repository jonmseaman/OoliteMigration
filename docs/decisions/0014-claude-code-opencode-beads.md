# ADR-0014: Claude Code and/or OpenCode as the agent runtime; beads for work tracking; no orchestration framework

**Status:** Accepted; the OpenCode row is replaced by Hermes Agent `/goal` in [ADR-0015](0015-hermes-goal-loop.md) · **Date:** 2026-09-10 · **Supersedes:** [ADR-0006](0006-gas-city-and-hermes.md)

## Context

ADR-0006 chose Gas City (with the Gastown pack) for the fleet and Hermes Agent for the Reporter.
Jon's decision (2026-09-10): no Gas Town, no Gas City. The agent runtime is **Claude Code and/or
OpenCode**. Separately, Jon ran `bd init` (commit `f4e84bc`), so **beads** (`bd`, the standalone
issue tracker) is the work store.

What Gas City was going to provide, and now is not: worktree isolation per task, a Bors-style
batch-and-bisect merge queue, stuck-agent watchdogs, role-based model routing, a concurrency cap,
and a "done" transition written by something other than the agent. The original execution plan's
§7 argued these were "100% of the actual engineering" and would be built during Phase 0 anyway;
ADR-0006 shortcut that. This ADR puts it back, smaller than it sounds.

## Decision

| Concern | Mechanism |
|---|---|
| **Frontier agent** (seams, adjudication, the six giant files, interactive sessions) | **Claude Code**: interactive for seams; `claude -p` headless for stories; subagents, hooks, native worktrees, scheduled tasks. |
| **Local / network-endpoint agent** (sweep stories on a cheaper model, the expansion-scan pilot) | **OpenCode**: provider-agnostic, any OpenAI-compatible endpoint via config, `opencode run` headless. This is how ADR-0005's "model routing is configuration" is satisfied natively. *(Verify current OpenCode capabilities before relying on a specific feature.)* |
| **Work queue** | **beads.** One bead = one L3 story. `bd ready` is the queue; dependencies are `bd dep`; the story text is the bead body; the carry-over channel is the bead's notes. The story generator (`tools/gen-stories`) emits beads. |
| **Worktree isolation** | `git worktree add` per bead, created and removed by the wrapper. |
| **The run-story wrapper** (`tools/fleet/run-story`) | `bd ready` → claim → worktree → launch the agent headless with the bead body → run the story's acceptance commands → **`bd close` only on exit 0**, otherwise append what happened to the bead notes and release the claim. Hard timeout with forced kill. The agent never runs `bd close`. |
| **Merge queue, batch-and-bisect** (`tools/merge-queue`) | A Phase 0 seam: collect Tier-B-green branches, merge them into a candidate, run Tier C via the CI gate ([I2](../infra/2-forge-and-runners.md)), fast-forward `main` on green, bisect on red. A few hundred lines of script over `git` and the Forgejo API. |
| **Watchdog** | The wrapper's timeout, plus the Reporter flagging any bead claimed longer than N hours. |
| **Concurrency cap** | The wrapper's parallelism setting, sized per [I0](../infra/0-machines.md). |
| **Reporter** | A scheduled Claude Code task (routine) or cron + `claude -p`, read-only. Hermes Agent is dropped with ADR-0006. |
| **Adjudicator** | Interactive Claude Code session over a Tier-C diff; writes a re-bless proposal into a bead tagged for Jon's weekly queue. |

Role names from the authority table ([execution-model §5](../execution-model.md)) are unchanged:
Reporter, Converter, Reviewer, Harness steward, Upstream tracker, Adjudicator, Jon. Each is now a
wrapper invocation with a prompt, a model, and a tool allow-list rather than a pack convention.

The Ralph-loop plugin in Jon's Claude Code environment is an acceptable inner loop for a single
story (`prd.json`-style), provided the external wrapper, not the loop, closes the bead.

## Consequences

- **Two new Phase 0 seams:** the run-story wrapper and the merge queue. Both are small, both are
  design, both are done by a frontier agent. The "8 PRs, one bad, bisects automatically" exit
  criterion now tests our script rather than someone else's.
- **Nothing sits between the repo and the agents but shell and `bd`.** The blast radius of a tool
  going away is now zero, which was ADR-0006's own argument for accepting a young dependency.
- **WSL2 is still where agents live** ([ADR-0010](0010-single-windows-machine.md)), not because the
  runtime needs it (Claude Code runs on Windows natively) but because the worktrees, the Linux
  Tier A compile, ccache and the golden containers are there. Tier A must be seconds and offline;
  crossing the Windows/WSL2 filesystem boundary per story would break that.
- **The "shape" argument survives.** ADR-0006 noted that this project and Gas Town independently
  converged on the same design (worktree per task, batch-and-bisect gate, agents never touch main,
  authority-based roles) and said to adopt the design regardless of the tool. That is what this
  ADR does.
- Model tiering ([execution-model §4](../execution-model.md)) maps to: Claude Code for the frontier
  rows, OpenCode against a rented or LAN endpoint for the local rows.

## History

`AI_EXECUTION_PLAN.md` §7 (build the substrate, defer the harness), §12 ("you already have Claude
Code … build the roles there, then choose a framework against evidence"), §13 (Gas Town
evaluation), ADR-0006 (Gas City). This ADR lands where §12 pointed.
