# I3 — Fleet: Claude Code, Hermes `/goal`, beads, and the fleet scripts

**Status:** not started · **Gates:** the first sweep (Phase 1 or 2). **Do not bring up before Phase 0's harness exists.**
**Decisions:** [ADR-0014](../decisions/0014-claude-code-opencode-beads.md) and [ADR-0015](../decisions/0015-hermes-goal-loop.md) (runtime), [ADR-0005](../decisions/0005-defer-dgx-spark.md) (routing), [ADR-0013](../decisions/0013-decide-up-front-minimise-human.md) (no human in the loop)

## Goal

The authority model in [execution-model §5](../execution-model.md) implemented as: beads for the
queue; `tools/fleet/accept` as the single path to `bd close`; Claude Code (via `run-story`) for
frontier work; Hermes Agent in `/goal` mode for local-model sweeps; `tools/merge-queue` for the
gate; and a scheduled read-only Reporter running first.

## Order of bring-up

1. **Reporter first.** A scheduled Claude Code task (or cron + `claude -p`) that reads `bd list`,
   CI status, and the golden results and posts the [I4](4-metrics.md) numbers. Read-only, so safe;
   cheap; and it forces the metrics to be defined before any code depends on them.
2. **beads conventions.** Bead body = the story ([template](../templates/story.md)); `bd dep` for
   ordering; bead notes are the only carry-over channel. Labels are load-bearing because they
   define the Hermes goal: `phase:<N>` on everything; `fleet` on generated sweep stories;
   `frontier` on seams; `rebless` for Jon's weekly queue; `proposed-adr` for defaults the fleet
   took. `goal-check <N>` passes when no open bead has both `phase:<N>` and `fleet`.
3. **`tools/fleet/accept <bead>`** (Phase 0 seam, the load-bearing script). Fresh clone of the
   bead's branch → run the story's acceptance commands → `bd close` **only** on exit 0, else
   append the output to the bead notes and release the claim. Hard timeout. A `bd` hook rejects
   any `bd close` not issued by `accept`. Both drivers below end every story here.
4. **The Hermes side is written:** `.agents/skills/beads-worker/` (SKILL.md, worker and reviewer
   prompt templates, and the scripts `goal-check`, `goal-gate`, `next-bead`, `worktree`,
   `accept`, `escalate`, plus the `bd` guard shim). It is the concrete form of steps 3, 5 and the
   guardrails for the local tier; `tools/fleet/` will call the same scripts. How to start it:
   [5-hermes-goal.md](5-hermes-goal.md).
5. **`tools/fleet/run-story`** (frontier driver). `bd ready` filtered to `frontier`-tier beads →
   claim → `tools/fleet/worktree` → `claude -p` with the bead body as the prompt and `CLAUDE.md`
   in scope → `accept` → remove the worktree. Memoryless per story. Parallelism flag = the
   concurrency cap from [I0](0-machines.md).
6. **Hermes Agent `/goal`** (local-tier driver). One long-running Hermes session per phase,
   configured against the on-prem endpoint, with the goal "`tools/fleet/goal-check <N>` exits 0".
   It picks `fleet` beads from `bd ready`, claims, works in a `tools/fleet/worktree` checkout,
   and calls `accept`. Its tool config denies `git push`, `bd close`, and writes under `goldens/`.
   Restart the session when the sweep's first-try Tier-B pass rate trends down
   ([ADR-0015](../decisions/0015-hermes-goal-loop.md)).
7. **`tools/merge-queue`** (Phase 0 seam). Collect branches whose Tier B is green, merge into a
   candidate branch, run `tools/tier-c.sh` locally in a clean worktree (no CI for now,
   [ADR-0016](../decisions/0016-no-forge-local-verification.md)), fast-forward
   `main` on green; on red, bisect the batch, merge the good half, and put the culprit's bead back
   in `bd ready` with the failure in its notes. No human approval (ADR-0013).
8. **Model routing.** Hermes's provider config holds the on-prem endpoint URL(s); Claude Code uses
   its own provider. Switching an endpoint is a config edit. Tier A never depends on any endpoint.
9. **Adjudication and seams** are interactive Claude Code sessions, not loop runs.

## Role → mechanism

| Authority-table role | Mechanism | Notes |
|---|---|---|
| Converter (frontier tier) | `run-story` + `claude -p` | own worktree; never pushes to `main`; ends in `accept` |
| Converter (local tier) | Hermes `/goal` against on-prem models | own worktree per bead; never pushes to `main`; ends in `accept` |
| Reviewer | a `claude -p` pass over the diff, posting comments to the PR | advisory; not a gate |
| Harness steward | scheduled `claude -p` with write access to `tools/` and `tests/` only | may fix harness code; **may never touch `goldens/`**; > 1% Tier-B flake = stop the line |
| Merge gate | `tools/merge-queue` | automatic; batch-and-bisect |
| Reporter | scheduled Claude Code task, read-only | outside the loop |
| Upstream tracker | monthly `claude -p` rebase task | files `docs/UPSTREAM_DELTA.md` entries |
| Adjudicator | interactive Claude Code | writes a re-bless proposal bead tagged `rebless` |
| Jon | — | works the `rebless` queue weekly; credentials; overrides by ADR; monthly GUI-tier judgement |

## Guardrails that must exist in the scripts

- The bead body carries the [template prohibitions](../templates/story.md) verbatim; the wrapper
  prepends absolute paths and the exemplar path.
- Agents run with a tool allow-list that excludes `bd close`, `git push`, and any path under
  `goldens/`; `accept` and `merge-queue` hold those. A `bd` hook enforces the `bd close` half
  regardless of which agent runtime is calling.
- No agent that reads Tier-3 corpus content gets repo write access or an environment with secrets;
  the scan runs in a container with neither.
- Concurrency cap sized to the WSL2 memory ceiling, net of golden containers ([I0](0-machines.md)).

## Verification

- [ ] Reporter delivers a daily message with every I4 metric populated (zeros are fine)
- [ ] `run-story` given the G2 bead completes it in its own worktree and opens a PR; the bead is still open until `accept` passes
- [ ] `accept` closes the bead only after `tools/tier-a.sh` and the story's acceptance commands exit 0 in a fresh clone; an agent that tries `bd close` is refused by the hook
- [ ] A Hermes `/goal` session given a phase with three `fleet` beads and one `rebless` bead closes the three through `accept` and stops with the goal satisfied, never touching the `rebless` bead
- [ ] An agent that edits `goldens/` is rejected at Tier B (Phase 0 guardrail), not by a reviewer
- [ ] `tools/merge-queue` bisects an 8-PR batch with one bad PR and requeues the culprit's bead (Phase 0 exit item)
- [ ] Switching a role's endpoint URL requires only a config change
- [ ] A full week passes with the fleet never blocked on Jon outside the `rebless` queue

## Status log

- 2026-09-06 — Created around Gas City (ADR-0006).
- 2026-09-10 — Host is WSL2 on the single Windows machine (ADR-0010).
- 2026-09-10 — Rewritten for Claude Code / beads; Gas City dropped (ADR-0014).
- 2026-09-10 — Hermes Agent `/goal` is the local-tier driver; OpenCode dropped; `accept` split out as the single path to `bd close` (ADR-0015).
- 2026-09-10 — beads-worker skill written under `.agents/skills/`; Hermes configured for it; no CI forge (ADR-0016).
