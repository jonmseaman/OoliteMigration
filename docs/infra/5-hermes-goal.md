# I5 — Running the Hermes beads worker

**Status:** skill written, not yet exercised · **Decisions:** [ADR-0015](../decisions/0015-hermes-goal-loop.md), [ADR-0014](../decisions/0014-claude-code-opencode-beads.md)

The local-tier driver is Hermes Agent in `/goal` mode with the in-repo skill
[`.agents/skills/beads-worker`](../../.agents/skills/beads-worker/SKILL.md). This page is the
operator's checklist. The skill's own `references/goal.md` holds the goal text.

## One-time setup (done 2026-09-10)

Applied with `hermes config set`:

| Key | Value | Why |
|---|---|---|
| `goals.max_turns` | `1000000` | Hermes has no "unlimited" for goals (0 falls back to the default of 20). A phase needs thousands of turns. |
| `delegation.max_concurrent_children` | `5` | also the number of beads in flight at once; raise with RAM ([I0](0-machines.md)) |
| `delegation.child_timeout_seconds` | `3600` | a stuck worker cannot hold the loop |
| `delegation.worktree_isolation` | `false` | the skill manages worktrees itself (`.worktrees/<bead>`, branch `bead/<bead>`); Hermes flagged the key as unrecognised, which is fine since false is the default |
| `delegation.subagent_auto_approve` | `true` | unattended loop; children must not block on approval prompts. **Security trade-off, deliberate.** |

Plus `hermes skills trust /Users/jonms/OoliteMigration` so the repo-local skill loads.

Still to do by Jon: route the judge to a cheap local model once the on-prem endpoint is
configured, e.g. `auxiliary.goal_judge.provider` / `.model` in `~/.hermes/config.yaml`; the judge
runs once per turn and only needs to read a `goal-check` result.

## Start a run

```bash
cd /Users/jonms/OoliteMigration                      # WSL2 path on the Windows machine
export PATH="$PWD/.agents/skills/beads-worker/scripts/bin:$PATH"   # bd guard shim, first
tmux new-session -d -s fleet -x 200 -y 50 'hermes --skills beads-worker'
```

Then paste the two commands from
[`references/goal.md`](../../.agents/skills/beads-worker/references/goal.md) into the session
(the `/goal …` block with its contract, then `/goal gate add … <phase>`).

## While it runs

- `/goal status` — turns used; `/goal gate` — gate state; `/goal show` — the contract.
- `bd list --label fleet --label phase:<N> --status open,in_progress` — what is left.
- `bd list --label escalated` — what the fleet gave up on; these are now `frontier` beads for a
  Claude Code session.
- A **pause** means either the turn budget (should not happen at 1,000,000) or three consecutive
  turns with no new information: no bead closed, none escalated, and no acceptance failure that
  differed from the previous one. Look at the last gate output; it names the blocker.
  `/goal resume` continues.
- There is no per-bead attempt cap. A bead is retried while each round fails differently; five
  identical failures in a row escalate it to `frontier` (threshold `BEADS_WORKER_STALE_REPEATS`,
  default 5).
- **Memory.** Each bead's notes accumulate worker summaries, review findings and acceptance
  failures; `docs/fleet/LEARNINGS.md` accumulates cross-bead learnings; `docs/fleet/FLEET_FAILURES.md`
  gets a row per escalation. Commit the two files periodically; they are the run's record.
- Beads run in parallel: the skill claims up to `delegation.max_concurrent_children` at once and
  delegates one worker per bead in a single call. Raise that setting as RAM allows.

## The queue as it stands

`tools/gen-stories.py --apply` populated it on 2026-09-11: epics `Phase 0`–`Phase 4`, 96 frontier
seams (labels `frontier`, `seam:<key>`), 580 fleet beads (labels `fleet`, `phase:<N>`,
`sweep:<name>`). Every fleet bead is blocked on its exemplar seam and, transitively, on the previous
phase; `bd ready` shows only what can actually start. Re-running the generator creates only what is
missing. To regenerate a sweep after a template change: `bd list --label sweep:<name> --json` →
`bd delete` those ids → re-run `--apply`.

## Contract with the queue

The skill only works beads that carry **both** `fleet` and `phase:<N>`. It never touches
`frontier`, `rebless`, or `proposed-adr` beads. Acceptance commands live in each bead's
`acceptance` field, one shell command per line, run from the branch root in a fresh checkout by
`accept.sh`, which is the only thing that can run `bd close`. `tools/gen-stories` must produce
beads in exactly this shape.

## Status log

- 2026-09-10 — Created. Skill and config in place; not yet run against a real bead.
