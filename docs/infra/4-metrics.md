# I4 — Metrics: what the Reporter reports

**Status:** not started · **Gates:** I3 step 1

## Why this exists

The stated reason for the project is to see how large a job AI tools can complete *to quality*.
That is only answerable if the numbers are defined before the work starts and collected by a
read-only job that cannot be gamed by the agents it measures.

## Daily

| Metric | Source | Why |
|---|---|---|
| Goldens stable (20/20 reproduce on main) | Tier C | the safety net is intact |
| Tier-B flake rate, per check, rolling 7 days | CI | **> 1% on any check is stop-the-line** |
| Merge-queue depth, batches run, bisections triggered | `tools/merge-queue` log | throughput and health |
| Beads: `bd ready` / claimed / closed by wrapper / **closed by human** / claimed > N h (stuck) | `bd list` | the fleet-vs-human ratio; the watchdog |
| First-try Tier-B pass rate for fleet stories | CI | quality of generated work |
| Re-bless queue: proposed / accepted / rejected / **age of oldest pending** | adjudicator log + Jon | the one human gate; age measures how long the fleet waited on a human |
| Proposed ADRs awaiting override | `docs/decisions/` | decisions the fleet took by default this week |
| Tier-1 corpus green | Tier B/C | expansions still work |
| ccache hit rate; Tier-A p50/p95 wall-clock | tools | the inner loop is still fast |

## Weekly

| Metric | Source |
|---|---|
| Files converted / remaining, by module and by size bucket | `grep -rc '@implementation'`, `.m` count |
| Lines converted / remaining | wc |
| Tier-3 weekly smoke: pass / fail / new failures, clustered | Tier-3 run + local-model triage |
| Upstream delta: commits behind, days since last rebase, frozen-module conflicts | upstream tracker |
| Human hours spent this week, by category (re-bless review, credentials/hardware, overrides, GUI judgement, *anything else* — the last should be zero) | Jon, self-reported |

## The log that is the actual research output

`docs/fleet/FLEET_FAILURES.md`, append-only: every point where a story could not be completed by the
fleet and a human stepped in. Date, story id, which sizing check it failed in hindsight, what the
human had to do, whether the story template or generator was changed as a result. This is the
document that answers the question the project was started to answer.

## Status log

- 2026-09-06 — Created. Metrics list derived from AI_EXECUTION_PLAN §11.4 and the Reporter role.
