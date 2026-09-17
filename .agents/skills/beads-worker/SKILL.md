---
name: beads-worker
description: "Drain a beads queue: delegate, review, accept, repeat."
version: 0.1.0
author: Jon Seaman (jonmseaman), Hermes Agent
license: MIT
platforms: [windows, linux, macos]
prerequisites:
  commands: [bd, git, jq]
metadata:
  hermes:
    tags: [beads, bd, autonomous, queue, delegation, review, ralph-loop]
    related_skills: [beads]
---

# Beads Worker Skill

Turns this Hermes session into an autonomous worker for a `bd` (beads) queue: claim the next
ready beads for a phase, delegate a worker per bead to implement it in its own worktree, delegate
a reviewer, and once the reviewer approves, close the bead through `scripts/accept.sh`, which runs
the bead's acceptance commands in a clean checkout. Repeat until the phase's goal check passes.
You orchestrate and you close; you never write code yourself, and **the worker that implemented a
bead never closes it**. A bead is done only when its work is a merge commit on the base branch and
the acceptance commands passed on that merged tree; nothing a worker leaves in a worktree is ever
discarded (`harvest.sh`, `gc.sh`). A bead is retried as many times as it keeps producing new information;
only the goal's turn budget bounds the run. The scripts under `scripts/` are the source of truth
for the mechanics; this file tells you when to call them.

## When to Use

- The user sets a `/goal` like "work phase 3 to done" or "drain the beads queue"
- The user asks to autonomously complete all beads matching a label set
- Don't use for: a single bead the user wants done interactively (just do it), planning or
  creating beads (use the `beads` skill), or anything touching `goldens/` (never)

## Prerequisites

- `bd`, `git`, `jq` on PATH; a repo with an initialised beads workspace (`bd where` succeeds).
  The scripts are bash: on the Windows machine run Hermes from the MSYS2 UCRT64 shell (the shell
  the build already needs), which provides bash, coreutils, `jq`, `python3` and `sha256sum`
- The `bd` guard shim first on PATH **before Hermes starts**, so no agent in this process tree can
  close a bead directly: `export PATH="$REPO/.agents/skills/beads-worker/scripts/bin:$PATH"`
- Beads labelled per the queue contract: every workable bead carries `fleet` and `phase:<N>`;
  beads for humans carry `rebless` or `proposed-adr`; seams carry `frontier`. The loop works the
  labels in `BEADS_WORKER_LABELS` (default `fleet`); export `BEADS_WORKER_LABELS="fleet frontier"`
  before starting Hermes when its model is the frontier model and it should take the seams too.
  `review`, `rebless`, `proposed-adr` and `escalated` beads are always excluded
  (`BEADS_WORKER_EXCLUDE`). A `frontier` bead's acceptance is prose plus `exit 1` until the worker
  replaces it with executable commands (`bd update <id> --acceptance`), so the worker prompt says so. Acceptance lives in
  the bead body under `## Acceptance` (fenced), one shell command per line, each exiting 0 on
  success; `accept.sh` refuses a block that is comments only
- `delegation.max_concurrent_children` ≥ 2 in `config.yaml`; `delegation.child_timeout_seconds`
  set (30–60 min) so a stuck worker cannot hold the loop

## How to Run

The user starts the loop; you keep it going. Canonical start, in the repo root:

```
/goal Work every open bead labelled fleet and phase:3 to closed using the beads-worker skill. Do not stop while scripts/goal-check.sh 3 fails.
/goal gate add .agents/skills/beads-worker/scripts/goal-gate.sh 3
```

The full goal text with its completion contract is in `references/goal.md`; the user pastes it.
The gate passes when the phase is drained *or* a bead was closed/escalated since the last turn,
and fails only on a turn with no progress, so three idle turns pause the goal (stuck detection).
The judge may not declare done while the gate fails; end every turn with the output of
`scripts/goal-check.sh <N>` so the judge has evidence rather than a claim.

## Quick Reference

All paths relative to the repo root. Run each with `terminal(command=..., timeout=...)`.

```
scripts/goal-check.sh <phase>            exit 0 iff no open/in-progress bead has fleet+phase:<N>
scripts/goal-gate.sh <phase>             the /goal gate: exit 0 if drained or progress this turn; consumes progress markers
scripts/next-bead.sh <phase> [count]     claim up to <count> ready fleet beads (retries first); one JSON per line {id,title,body,acceptance,notes,exemplar,attempts,stale_count}
scripts/worktree.sh <bead>               create .worktrees/<bead> on branch bead/<bead> from the base branch; prints the absolute path
scripts/worktree.sh --remove <bead>      harvest, remove the worktree; delete the branch only if merged into base (unmerged branches are kept)
scripts/harvest.sh <bead>                commit anything the worker left uncommitted in .worktrees/<bead> onto bead/<bead>; run after every worker round
scripts/accept.sh <bead>                 harvest → clean checkout of base → merge bead/<bead> → run acceptance on the merged tree → fast-forward base → verify the merge is on base → close → remove worktree+branch. Exit 0 closed+merged · 1 rejected with new learning (retry; includes merge conflicts and empty branches) · 2 rejected, identical failure repeated (escalate). One at a time (lock)
scripts/gc.sh [--check]                  audit bead/* branches and .worktrees/*: delete what is merged, harvest what is dirty, reopen any closed bead whose branch never reached base. goal-check runs --check
scripts/escalate.sh <bead> "<reason>"    swap fleet→frontier, add escalated, release claim, log a row in docs/fleet/FLEET_FAILURES.md
scripts/reevaluate.sh <bead> "<why>"     ask Claude Code (frontier, read-only) whether the TASK is right; applies retry/reclassify/add_dep/escalate; exit 3 = unavailable
scripts/context.sh <bead>                print the bead's notes + the last 40 fleet learnings; paste into every worker/reviewer task
scripts/learn.sh <bead> "<line>"         record a cross-bead learning in docs/fleet/LEARNINGS.md and the bead's notes
scripts/bin/bd                           guard shim: refuses close / status=closed unless BEADS_ACCEPT=1
```

## Procedure

Repeat from step 1 after every batch. Work **P beads at a time**, where P is
`delegation.max_concurrent_children` (check with `terminal(command="hermes config get delegation.max_concurrent_children")`);
more beads in flight is fine, more children than P is not.

1. **Check the gate.** `terminal(command="scripts/goal-check.sh <N>")`. Exit 0 → report "phase <N>
   queue drained" and stop; the judge will confirm. Nonzero → continue. *Done when: you know
   whether work remains.*
2. **Claim a batch.** `terminal(command="scripts/next-bead.sh <N> <P>")`. One JSON record per
   line; beads that failed a previous round come first, with `attempts` and `notes` populated.
   Exit 3 → nothing is ready (all remaining beads are blocked or claimed by someone else); run
   `bd list --label fleet --label phase:<N> --status open,in_progress`, report what is blocking,
   then wait one turn. *Done when: you hold records for 1..P claimed beads.*
3. **Worktrees.** `terminal(command="scripts/worktree.sh <id>")` for each. *Done when: each
   bead has an absolute path on branch `bead/<id>`.* (A retried bead reuses its worktree.)
4. **Delegate the workers, one `delegate_task` call, one task per bead**, each built from
   `references/worker-prompt.md`: the bead body verbatim, the absolute worktree path, the
   exemplar path, the acceptance commands, the attempt number, the output of
   `scripts/context.sh <id>` (previous attempts, failures, review findings, and the shared
   learnings), and the prohibitions block. Require `output_schema`
   `{summary, files_changed[], commands_run[], committed: bool, blocked: bool, blocked_reason}`.
   *Done when: every result says `committed: true`, or `blocked: true` with a reason.*
   - **Then `terminal(command="scripts/harvest.sh <id>")` for every bead in the batch**, whatever
     the worker reported: a worker that timed out or forgot to commit leaves work in the worktree
     that the reviewer and `accept.sh` cannot see. Harvest commits it and notes the fact.
   - For every result: `bd update <id> --append-notes "attempt N worker: <summary>; files: <list>"`.
     The notes are the bead's memory; the next attempt reads them through `context.sh`.
   - `blocked: true` → `bd update <id> --append-notes "<reason>"`, then
     `terminal(command="scripts/reevaluate.sh <id> \"blocked: <reason>\"", timeout=900)`. Claude
     decides whether the task itself is wrong (see *Escalation ladder* below). Only if it returns
     exit 3 do you `scripts/escalate.sh <id> "<reason>"` yourself. That bead leaves the batch.
5. **Delegate the reviewers, one call, one task per committed bead**, each built from
   `references/reviewer-prompt.md`: the worktree path, `git diff main...bead/<id>`, the bead's
   sizing checks and prohibitions. Require `output_schema` `{verdict: approve|request_changes, findings[]}`.
   *Done when: every bead has a verdict.*
   - For every verdict: `bd update <id> --append-notes "review: <verdict>; <findings, one per line>"`.
   - `request_changes` → delegate the worker again with the findings appended as context, then
     re-review. Repeat until `approve`. There is no round cap, but if two consecutive reviews
     return the same findings the worker is not learning: `scripts/reevaluate.sh <id> "reviewer
     stalemate: <findings>"`.
6. **Accept each approved bead.** `terminal(command="scripts/accept.sh <id>", timeout=1800)`.
   You are closing your own work here, which is allowed because the reviewer approved it and
   because `accept.sh`, not you, decides: it merges the bead into the base branch in a clean
   checkout, runs the acceptance commands on the merged tree, and only on exit 0 fast-forwards the
   base branch, verifies the merge commit is an ancestor of the base branch, closes, and removes
   the worktree and branch. **Merging back is part of accepting**; there is no separate merge or
   cleanup step for a closed bead. Accepts are serialised by a lock; call them one after another.
   *Done when: each bead returned 0, 1, or 2.*
   - Exit 0 → closed, merged, worktree and branch gone.
   - Exit 1 → rejected with a failure the bead has not seen before. Keep the claim and the
     worktree; the bead comes back in the next batch with the failure tail in its notes, and the
     worker prompt must include it. No cap on rounds.
   - Exit 2 → rejected with the same failure as last time: the loop is not learning.
     `scripts/reevaluate.sh <id> "stale acceptance failure: <last failure tail>"`. Claude either
     hands you guidance (the bead comes back with `stale_count` reset), changes the task
     (reclassify / add_dep, the bead leaves the batch until its new deps close), or escalates.
     Fall back to `scripts/escalate.sh` only on exit 3.
7. **Clean up.** `terminal(command="scripts/gc.sh")` once per turn. It removes worktrees and
   branches whose work is on the base branch, harvests dirty worktrees of live beads, keeps the
   unmerged branch of every escalated bead for the frontier agent, and reopens any closed bead
   whose branch never reached the base branch. Never remove a worktree by hand for a bead that is
   going round again.
8. **Record learnings.** For any bead that taught something the *next* bead should know (a
   codebase pattern, a misleading acceptance command, a tooling quirk), one line:
   `scripts/learn.sh <id> "<learning>"`. Not every bead has one; do not pad.
9. **Report one line** per bead: id, outcome (closed / retry / escalated), review verdict,
   attempts. End the turn with the output of `scripts/goal-check.sh <N>`. Then go to step 1.

## Escalation ladder

A bead never goes straight from "stuck" to a human. In order:

1. **Retry with new information** — every failed accept appends its output to the notes and the
   next worker reads it. Unlimited while the failure keeps changing.
2. **Re-evaluate the task with the frontier model** — `scripts/reevaluate.sh` runs Claude Code
   headless and read-only (`claude -p`, Read/Grep/Glob only, no `bd close`, no edits) with the
   bead, its notes and the shared learnings, and asks one question: *is this the right task?* Its
   answer is applied mechanically: `retry` with guidance, `reclassify` to another sweep (e.g. a
   "rename to .c" bead whose file turns out to be full of message sends becomes a convert bead),
   `add_dep` on a seam it needs first, or `escalate`. If it names a generator rule that is wrong,
   one deduplicated `generator-bug` frontier bead is filed so the *rule* gets fixed and the sibling
   beads regenerated, not just this instance.
3. **Escalate** — the bead becomes `frontier` + `escalated`, leaves the goal, and is logged in
   `docs/fleet/FLEET_FAILURES.md`. Nothing else blocks on it except the phase's terminal item.

Triggers for step 2: a worker reports `blocked`; `accept.sh` returns 2 (identical failure);
two reviews with the same findings. One Claude call per stuck bead, never per attempt.

## Pitfalls

- **The goal is reachable without a human by construction.** `goal-check` counts only
  `phase:<N>` beads with a `BEADS_WORKER_LABELS` label; `rebless`, `proposed-adr`, `review` and
  `escalated` beads are invisible to it, and `frontier` beads only when the label set includes them.
  If the gate never passes, a bead is mislabelled or blocked, not "hard": say so rather than
  attempting `frontier` work.
- **`reevaluate.sh` needs `claude` on PATH and an Anthropic credential in the environment.** If
  it returns exit 3, say so in the turn report and escalate; do not retry it in a loop.
- **Raw `bd close` is refused for you and your children.** That is the guard shim doing its job.
  You close beads by calling `scripts/accept.sh`, which sets `BEADS_ACCEPT=1` itself; the
  implementing worker has no path to close at all. If the shim is not on PATH, stop and tell the
  user; do not proceed without it.
- **An exemplar may be a seam key, not a path.** Generated beads name their exemplar as
  `seam:<key>` (or a bare key like `3.exemplar-oocolor`) when the exemplar is produced by a seam
  bead. Resolve it: `bd list --label seam:<key> --all --json` → read that bead's notes and the
  paths it landed, and pass those paths to the worker as the exemplar. If the seam bead is not
  closed, the fleet bead should not be ready; report it rather than guessing an exemplar.
- **Workers must commit, and you harvest anyway.** The worker prompt says commit; `harvest.sh`
  commits whatever was left so the reviewer sees it and `accept.sh` merges it. A branch with no
  commits beyond the base branch is rejected by `accept.sh` (exit 1) with a note, not merged empty.
- **Nothing is done until it is on the base branch.** `accept.sh` closes only after the merge
  commit is verified to be an ancestor of the base branch, and `goal-check.sh` refuses to pass while
  `gc.sh --check` finds a closed bead with an unmerged branch or a dirty worktree.
- **Merge conflicts are rejections.** With several beads in flight, a bead may conflict with one
  merged before it. `accept.sh` reports the conflicting files into the notes and returns 1; the
  worker's next round merges the base branch into its worktree and resolves. The base branch is
  `main` unless `BEADS_WORKER_BASE_BRANCH` says otherwise (a merge queue may later point it at an
  integration branch and promote to `main` after Tier C).
- **Turn budget.** `/goal` pauses when `goals.max_turns` is exhausted; the repo's Hermes config
  sets it to 1,000,000 so a phase fits. If you see "Goal paused", `/goal resume` resets the counter.
  A pause is not a failure.
- **Gate retries are stuck detection, and "progress" means new information.** `goal-gate.sh`
  passes on any turn where a bead was closed, escalated, or rejected with a failure it had not
  seen before. Three consecutive turns with none of those pause the goal. If that happens, the
  queue is blocked or every remaining bead is stale: report which, do not spin.
- **No per-bead attempt cap.** A bead goes round as long as each round changes what fails.
  `accept.sh` compares failure signatures; five identical failures in a row return exit 2 and you
  escalate. The threshold is `BEADS_WORKER_STALE_REPEATS`, default 5.
- **Memory lives in two places, on purpose.** The bead's notes hold everything about that bead
  (worker summaries, review findings, acceptance failures). `docs/fleet/LEARNINGS.md` holds what
  carries across beads. `context.sh` assembles both for a task. Your own session memory is a
  convenience, not a record: if it is not in notes or learnings, the next session does not know it.
- **Progress markers.** `accept.sh`/`escalate.sh` drop `.fleet-progress.<id>` files at the repo
  root and the gate deletes them. Do not delete or commit them yourself.
- **Children cannot delegate, cannot ask the user, and know nothing you did not put in `context`.**
  Repeat the worktree path and the prohibitions in every task.
- **Never touch `goldens/`, tests, or warning flags to make acceptance pass.** These are hard
  rules in the repo's `CLAUDE.md`; a worker that does it will be caught at Tier B and the bead
  reopened. Escalate instead.
- **Persistent memory is not the carry-over channel.** Anything the next attempt must know goes
  in the bead's notes, because the next attempt may run in a different session or a different agent.

## Verification

- `scripts/goal-check.sh <N>` flips from nonzero to zero over the course of the run
- `scripts/goal-gate.sh <N>` exits 0 on a turn right after `accept.sh` closed a bead, and 1 on a turn where nothing happened
- `scripts/reevaluate.sh <bead> "blocked: file is full of message sends"` on a rename bead rewrites it as a convert bead (title, labels, body, deps) and keeps its notes
- Every closed bead is a merge commit on the base branch whose acceptance commands exit 0 on the merged tree (`bd show <id>` metadata `merge_commit`), and has no `bead/<id>` branch or `.worktrees/<id>` left
- A worktree with uncommitted changes and no commits: `accept.sh` harvests, merges and closes it; the notes record the harvest
- A branch with zero commits beyond base: `accept.sh` rejects with exit 1 and a note
- `gc.sh --check` exits 1 when a closed bead's branch is unmerged; `gc.sh` reopens that bead; `goal-check.sh` fails until it is accepted
- `bd list --status closed --label phase:<N>` closures are all attributed to `accept.sh`
  (reason text starts with `accepted:`)
- `bd close <id>` typed directly returns the guard's refusal message
- A deliberately broken bead (acceptance `false`) is rejected with exit 1, then with exit 2 on the
  fifth identical failure, escalated with `frontier` + `escalated`, logged in
  `docs/fleet/FLEET_FAILURES.md`, and no longer counted by the gate
- After a bead closes, `bd show <id>` notes contain the worker summary, the review verdict and, if
  any, a `learning:` line that also appears in `docs/fleet/LEARNINGS.md`
- Two beads claimed in one `next-bead.sh <N> 2` call are implemented by one two-task `delegate_task`
