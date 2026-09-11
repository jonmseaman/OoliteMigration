# I3 — Fleet: Gas City, the Gastown pack, Hermes reporter, model routing

**Status:** not started · **Gates:** the first sweep (Phase 1 or 2). **Do not bring up before Phase 0's harness exists.**
**Decisions:** [ADR-0006](../decisions/0006-gas-city-and-hermes.md), [ADR-0005](../decisions/0005-defer-dgx-spark.md)

## Goal

The authority model in [execution-model §5](../execution-model.md) expressed exactly as Gas City
configuration, with a Reporter running first, and model routing as configuration.

## Order of bring-up

1. **Reporter first** (Hermes Agent, or a scheduled Claude Code task). Read-only, so safe; a
   scheduled job, so cheap; and it forces the metrics in [I4](4-metrics.md) to be defined before
   any code depends on them. Buildable this week.
2. **Gas City in WSL2 on the Windows machine** ([ADR-0010](../decisions/0010-single-windows-machine.md)), from the **Gastown pack**. Pin the Gas City version and the pack
   commit. Dependencies: tmux, git, jq, pgrep, lsof; Go 1.26.4+ to build from source.
3. **Roles as pack configuration.** Map the authority table onto prompts, formulas, orders and
   `city.toml`. Explicit agent identity is required (do not port prompts that assume the directory
   path implies who the agent is).
4. **Refinery gate** = the I2 gate script.
5. **The "done" wrapper.** Whatever transitions a bead to done runs the story's acceptance commands
   itself and transitions only on exit 0. The agent never closes its own unit. This is the single
   most important thing to get right when wiring the harness.
6. **Model routing.** Task class → endpoint URL in config. Gas City routes at CLI granularity
   (`role_agents` → CLI preset), so each preset is configured against its endpoint. **Verify custom
   OpenAI-compatible endpoint support before relying on it.** Tier A never depends on any endpoint.

## Role → pack mapping

| Authority-table role | Gastown pack role | Notes |
|---|---|---|
| Converter | Polecat | own worktree branch; never pushes to main |
| Reviewer | (advisory polecat or hook) | comments only; not a gate |
| Harness steward | Witness (per-rig) / Deacon / Dogs | may fix harness code; **may never re-bless a golden**; > 1% Tier-B flake = stop the line |
| Merge gate | Refinery | Bors-style batch-and-bisect |
| Orchestrator | Mayor | |
| Reporter | Hermes / scheduled task | outside Gas City; read-only |
| Adjudicator | frontier, interactive | proposes re-bless with justification; escalates always |
| Jon | Crew | merges to main; re-blesses goldens; open decisions; freeze policy |

## Guardrails that must exist in the pack config

- Stories carry the [template prohibitions](../templates/story.md) verbatim.
- The carry-over channel (bead body / mail) is the *only* state between iterations; story text
  embeds absolute paths and the exemplar path.
- No role that reads Tier-3 corpus content has repo write access or secrets.
- Concurrency cap sized to the WSL2 memory ceiling, net of golden containers ([I0](0-machines.md)).

## Verification

- [ ] Reporter delivers a daily message with every I4 metric populated (zeros are fine)
- [ ] A polecat given the G2 story completes it in its own worktree and files a merge request; it does not close the bead
- [ ] The wrapper closes the bead only after `tools/tier-a.sh` and the story's acceptance commands exit 0
- [ ] A polecat that edits `goldens/` is rejected at Tier B (0.11 guardrail), not by a reviewer
- [ ] Refinery bisects an 8-PR batch with one bad PR (Phase 0 exit item)
- [ ] Switching a role's endpoint URL requires only a config change

## Status log

- 2026-09-06 — Created from AI_EXECUTION_PLAN §11, §12, §13.6, §13.7.
- 2026-09-10 — Host is WSL2 on the single Windows machine (ADR-0010).
