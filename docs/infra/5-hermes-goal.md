# I5 — Running the Hermes beads worker

**Status:** skill written, not yet exercised; setup below was done on the Mac and must be redone on the Windows machine ([ADR-0017](../decisions/0017-native-windows-subtree.md)) · **Decisions:** [ADR-0015](../decisions/0015-hermes-goal-loop.md), [ADR-0014](../decisions/0014-claude-code-opencode-beads.md)

The local-tier driver is Hermes Agent in `/goal` mode with the in-repo skill
[`.agents/skills/beads-worker`](../../.agents/skills/beads-worker/SKILL.md). This page is the
operator's checklist. The skill's own `references/goal.md` holds the goal text.

## One-time setup (done on the Mac 2026-09-10; repeat on Windows)

Applied with `hermes config set`:

| Key | Value | Why |
|---|---|---|
| `goals.max_turns` | `1000000` | Hermes has no "unlimited" for goals (0 falls back to the default of 20). A phase needs thousands of turns. |
| `delegation.max_concurrent_children` | `5` | also the number of beads in flight at once; raise with RAM ([I0](0-machines.md)) |
| `delegation.child_timeout_seconds` | `3600` | a stuck worker cannot hold the loop |
| `delegation.worktree_isolation` | `false` | the skill manages worktrees itself (`.worktrees/<bead>`, branch `bead/<bead>`); Hermes flagged the key as unrecognised, which is fine since false is the default |
| `delegation.subagent_auto_approve` | `true` | unattended loop; children must not block on approval prompts. **Security trade-off, deliberate.** |
| (environment) | `ANTHROPIC_API_KEY` or a logged-in `claude` CLI | `reevaluate.sh` shells out to Claude Code headless; without it the ladder falls back to escalation |

Plus `hermes skills trust <repo path>` so the repo-local skill loads.

**Moving to the Windows machine:** push `main`; `bd dolt push` on the Mac and `bd dolt pull` on
Windows (the beads database is Dolt under `.beads/`, not in git; `sync.remote` is already `origin`);
reapply the table above; trust the skill at its new path; log in `claude`. Then verify, before any
`/goal`: Hermes's `terminal` tool runs **bash** (start Hermes from the MSYS2 UCRT64 shell), the
`bd` guard shim refuses `bd close`, and `python3`, `jq`, `sha256sum` resolve.

Still to do by Jon: route the judge to a cheap local model once the on-prem endpoint is
configured, e.g. `auxiliary.goal_judge.provider` / `.model` in `~/.hermes/config.yaml`; the judge
runs once per turn and only needs to read a `goal-check` result.

## Why there is a `.hermes.md` as well as the skill

Hermes injects a project context file into the **system prompt** every turn, so it survives context
compression on a session that runs for days; a skill's text lives in the conversation and can be
pruned. `.hermes.md` at the repo root therefore carries the standing contract (the loop in seven
lines, the never-do list, the memory rule) and points at the skill for the full procedure, which
the orchestrator reloads with `skill_view` when unsure. Note that for Hermes `.hermes.md` takes
precedence over `AGENTS.md`, so it also carries the `bd prime` pointer. Claude Code still reads
`CLAUDE.md`; the two do not conflict.

## Escalation without blocking

A stuck bead does not go to a human. `scripts/reevaluate.sh` runs Claude Code headless and
read-only (`claude -p`, Read/Grep/Glob only) with the bead, its notes and the shared learnings, and
asks one question: is this the right task? Its JSON decision is applied by script: `retry` with
guidance, `reclassify` to another sweep via `tools/gen-stories.py --reclassify`, `add_dep` on a
seam, or `escalate`. If Claude names a wrong rule in the generator, one deduplicated
`generator-bug` frontier bead is filed so the rule gets fixed and siblings regenerated. Verified
2026-09-11 on the mis-generated `OOOpenGL.m` rename bead: Claude read the file, chose a different
sweep, and filed the generator bug in about two minutes. Escalated beads block only the phase's
terminal item; the fleet keeps going.

## Start a run

From an MSYS2 UCRT64 shell in a Windows Terminal tab, on the unlocked desktop
([I0 checklist](0-machines.md)):

```bash
cd /c/src/OoliteMigration                            # the clone, short NVMe path
export PATH="$PWD/.agents/skills/beads-worker/scripts/bin:$PATH"   # bd guard shim, first
hermes --skills beads-worker
```

Keep the tab open; the session is the run. (`tmux` from MSYS2 works too if you prefer detaching.)

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

`tools/gen-stories.py --apply` populated it on 2026-09-11: epics `Phase 0`–`Phase 4`, ~95 frontier
seams (labels `frontier`, `seam:<key>`), ~585 fleet beads (labels `fleet`, `phase:<N>`,
`sweep:<name>`), rewritten the same day for native Windows (`--refresh`; ADR-0017). Every fleet bead is blocked on its exemplar seam and, transitively, on the previous
phase; `bd ready` shows only what can actually start. Re-running the generator creates only what is
missing. To regenerate a sweep after a template change: `bd list --label sweep:<name> --json` →
`bd delete` those ids → re-run `--apply`.

## Contract with the queue

The skill only works beads that carry **both** `fleet` and `phase:<N>`. It never touches
`frontier`, `rebless`, or `proposed-adr` beads. Acceptance commands live in each bead's
body under `## Acceptance`, one shell command per line, run from the repo root in a fresh checkout
by `accept.sh`, which is the only thing that can run `bd close`. Frontier seams carry prose plus
an `exit 1` guard there until the frontier agent writes real commands. `tools/gen-stories` must produce
beads in exactly this shape.

## Status log

- 2026-09-10 — Created. Skill and config in place; not yet run against a real bead.
- 2026-09-11 — Queue populated (681 beads). `reevaluate.sh` + `--reclassify` added and exercised on a real bead; `.hermes.md` added for durable instructions.
- 2026-09-11 — Native Windows (ADR-0017): setup must be redone there; start commands rewritten; scripts made MSYS2-portable.
