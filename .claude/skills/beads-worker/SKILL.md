---
name: beads-worker
description: Work the Oolite migration's bead queue, one bead per iteration — claim a bead, branch it in oolite-dev with git town, implement it, run its acceptance gate, and open a pull request for Jon to review. Re-entrant; intended for /loop. Use when asked to work, drain or continue a phase or a set of beads.
---

# Beads worker

One iteration ("tick") takes **one bead** from `claim` to `pull request open`. That is the whole
job. The tick is bounded on purpose: `/loop` re-enters this skill, and a phase of several hundred
beads must not depend on a single context window surviving.

```
tick:  land merged PRs  →  claim one bead  →  git town append feature/MMDD-slug
                        →  implement + commit in oolite-dev
                        →  accept.sh: acceptance commands green?  →  git town propose
                        →  bead is `proposed`, still OPEN
Jon:   reviews and merges the pull request on GitHub
next tick: land.sh sees the merge  →  bead closes
```

**You never close a bead and you never merge anything.** A bead closes only when Jon has merged its
pull request — `land.sh` reads that from GitHub. The guard shim on PATH refuses `bd close` outright
(CLAUDE.md hard rule 4), and refuses any push that would write `develop`, `master` or `main`.

Run with the selector Jon gives you, passed straight through to `bd list`:

```
/loop /beads-worker --label phase:5
```

## Each tick

All script paths are relative to `.claude/skills/beads-worker/`. Run them with `bash`.

1. **`scripts/preflight.sh`** — first tick only, or after anything unusual. Proves the beads
   database answers, the guard shim really is on PATH, `oolite-dev` is clean, and Git Town knows
   `develop` is its main branch. If it fails, stop and report: every later step assumes it passed.
2. **`scripts/land.sh`** — closes every `proposed` bead whose pull request Jon merged, and sends
   back any whose pull request he closed unmerged (read that review before retrying). Run it first
   so the queue reflects his reviews rather than lagging a tick behind.
3. **`scripts/queue-check.sh <selector>`** — exit 0 means nothing actionable is left: say so, name
   anything still awaiting review, and **stop the loop**. Nonzero means carry on.
4. **`scripts/next-bead.sh <selector>`** — claims one bead and prints it as JSON (`id`, `title`,
   `body`, `acceptance`, `notes`, `attempts`, `stale_count`). Exit 3 means nothing is ready:
   report what is blocking and end the tick. Beads already awaiting review are never handed back.
5. **`scripts/context.sh <id>`** — the bead's notes. On a retry this holds the exact failure the
   last attempt hit. Read it before writing code; it is the only thing that survives between ticks.
6. **`scripts/branch.sh <id>`** — checks out `develop` and `git town append`s `feature/MMDD-slug`
   for the bead. Prints the branch. A retried bead returns to its existing branch instead.
7. **Implement the bead** in `oolite-dev`, on that branch. Follow the story: ≤ 1,500 lines read,
   ≤ 400 written, ≤ 8 files, no new interfaces, and do it the way the exemplar does it. Obey every
   hard rule in `CLAUDE.md` — above all, never touch `goldens/`, never weaken a test, never silence
   a warning. **Commit on the bead's branch**, with the bead id in the subject.
8. **`scripts/accept.sh <id>`** — runs the bead's stored acceptance commands and, only if every one
   exits 0, opens the pull request and marks the bead `proposed`.
   - **exit 0** — proposed. Say which pull request, and end the tick.
   - **exit 1** — a failure the bead has not seen before; it is already in the notes. End the tick;
     the bead comes back next time with that failure as its context. There is no attempt cap while
     each round produces new information.
   - **exit 2** — the same failure several times running. Stop retrying. Re-read the bead against
     the code: usually the *task* is wrong, not the implementation. Fix the bead
     (`bd update <id> --acceptance` / `--description`), or `scripts/park.sh <id> "<why>"` to put it
     in Jon's inbox and move on. Never wait for him (hard rule 10).
9. **End the tick** with one line per bead touched and the `queue-check.sh` output, so the next
   iteration starts from evidence rather than memory.

## Writing the acceptance gate

A bead with no executable acceptance block cannot be proposed — `accept.sh` refuses, and that
refusal is the gate doing its job. If the bead's block is prose or a placeholder, replace it with
real commands (`bd update <id> --acceptance`) before you implement: deciding what would prove the
work is part of the work.

The block is one command per line, each run in its own `bash -o pipefail -c` from the **repo root**
(so acceptance lines spell the submodule out: `cd oolite-dev && ./mk.sh build test`). The whole
block shares a five-minute budget (ADR-0021); a slow proof belongs in one of `tools/tier-c.sh`'s
stage lists (ADR-0068), not in a bigger budget. A line must be proven to **fail** on unfixed code, not merely to pass on
fixed code — see `references/pitfalls.md`.

## When something is wrong with the task

You are the frontier model: when a bead is wrong, say so rather than forcing it through.

- The story asks you to rewrite C that already compiles, or to touch `goldens/` — the story is
  wrong. Park it with that reason (hard rule 9).
- The bead needs a capability that does not exist yet — that is a dependency, not a retry. File or
  find the seam bead, `bd dep add <id> <seam>`, release the claim, and move on.
- A decision is missing — write a proposed ADR under `docs/decisions/` with a recommended default
  and proceed on it. Never wait (hard rule 10).

## Phase end

When Jon says a phase is done, everything in it has already been reviewed and merged one pull
request at a time. What is left is the phase gate:

1. `scripts/queue-check.sh <selector>` is green and nothing is awaiting review.
2. `bash tools/sync-dev.sh` — pull the merged work into `develop` and record the new `oolite-dev`
   commit in this repo. The tick never touches that pointer; this is the only thing that moves it.
3. Review the whole phase: `git -C oolite-dev diff master...develop`, against the phase doc's exit
   criteria. Dispatch a subagent for this — a fresh reader catches what the author cannot. Use
   `references/reviewer-prompt.md`. File every finding as a bead labelled `review-finding`; an open
   one blocks the pull request.
4. `bash tools/phase-pr.sh --selector "<selector>"` — opens `develop → master` on the game fork.
   Add `--dry-run` first to see exactly what it would do.

## Pitfalls

`references/pitfalls.md` is what previous runs learned the expensive way: orphaned `oolite.exe`
poisoning a launch, `OO_APP_DIR`, acceptance lines that silently cannot fail, MSYS2 PATH traps,
goldens refusals that mean a real regression. Read the section matching what you are about to do.

Add to it when a tick teaches something the next bead would otherwise rediscover. Keep it specific
and keep the evidence: a pitfall nobody can check becomes folklore.
