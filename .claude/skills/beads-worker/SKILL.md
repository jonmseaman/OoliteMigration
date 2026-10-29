---
name: beads-worker
description: Work the Oolite migration's bead queue, one bead per iteration — claim a bead, implement it on its epic's branch in oolite-dev, run its acceptance gate, and commit it (one commit per bead) for Jon to merge with the rest of the epic. Re-entrant; intended for /loop. Use when asked to work, drain or continue an epic, a phase or a set of beads.
---

# Beads worker

One iteration ("tick") takes **one bead** from `claim` to `committed on the epic branch`. That is
the whole job. The tick is bounded on purpose: `/loop` re-enters this skill, and an epic of
hundreds of beads must not depend on a single context window surviving.

```
tick:  land merged epics  →  claim one bead  →  branch.sh: epic/<slug> in oolite-dev
                          →  implement + commit in oolite-dev
                          →  accept.sh: acceptance commands green?  →  squash to one commit
                          →  bead is `committed`, still OPEN
queue drained:  epic-finish.sh runs the end gate  →  epic is `ready-to-merge`
Jon:   merges epic/<slug> into develop in oolite-dev, locally, and pushes
next tick: land.sh sees the merge  →  the epic and its beads close
```

**You never close a bead, push, or merge anything.** A bead closes only when Jon has merged its
epic's branch into `develop` — `land.sh` reads that from `oolite-dev`. The deny list in
`.claude/settings.json` refuses `bd close` and any push (CLAUDE.md hard rules 3 and 4). Every bead
needs a parent epic (`bd create --parent <epic>`); one worker works one epic branch at a time.

Run with the selector Jon gives you, passed straight through to `bd list`:

```
/loop /beads-worker --parent oo-abc
```

## Each tick

All script paths are relative to `.claude/skills/beads-worker/`. Run them with `bash`.

1. **`scripts/preflight.sh`** — first tick only, or after anything unusual. Proves the beads
   database answers, `oolite-dev` is on a branch and clean, and a local `develop` exists. If it
   fails, stop and report: every later step assumes it passed.
2. **`scripts/land.sh`** — closes every epic labelled `ready-to-merge` whose branch Jon has merged
   into `develop`, together with all of its `committed` beads. Run it first so the queue reflects
   his merges rather than lagging a tick behind.
3. **`scripts/queue-check.sh <selector>`** — exit 0 means nothing actionable is left: say so, name
   what is committed and awaiting Jon's merge, and run the `epic-finish.sh` command it prints (see
   "Epic end"). Then **stop the loop**. Nonzero means carry on.
4. **`scripts/next-bead.sh <selector>`** — claims one bead and prints it as JSON (`id`, `title`,
   `body`, `acceptance`, `notes`, `attempts`, `stale_count`). A bead is ready when every blocker is
   closed or already `committed`. Exit 3 means nothing is ready: report what is blocking and end
   the tick. Committed beads and `design` beads (interactive) are never handed out.
5. **`scripts/context.sh <id>`** — the bead's notes. On a retry this holds the exact failure the
   last attempt hit. Read it before writing code; it is the only thing that survives between ticks.
6. **`scripts/branch.sh <id>`** — puts `oolite-dev` on the bead's epic branch (`epic/<slug>`,
   created once from `develop`) and records where the bead started (`base_commit`). Prints the
   branch. A retried bead keeps its original start.
7. **Implement the bead** in `oolite-dev`, on that branch. Follow the story: no new interfaces, and
   do it the way the exemplar does it. There is no line or file cap, but the bead is one tick's work;
   for a tree-wide sweep use the tool the bead names rather than reading every file. Obey every
   hard rule in `CLAUDE.md` — above all, never weaken a test and never silence a warning. **Commit
   on the epic's branch**, with the bead id in the subject; make as many commits as you like, the
   gate squashes them.
8. **`scripts/accept.sh <id>`** — runs the bead's stored acceptance commands and, only if every one
   exits 0, squashes the bead's commits into one (`<id>: <title>`) and labels it `committed`.
   - **exit 0** — committed. Say which commit, and end the tick.
   - **exit 1** — a failure the bead has not seen before; it is already in the notes. End the tick;
     the bead comes back next time with that failure as its context. There is no attempt cap while
     each round produces new information.
   - **exit 2** — the same failure several times running. Stop retrying. Re-read the bead against
     the code: usually the *task* is wrong, not the implementation. Fix the bead
     (`bd update <id> --acceptance` / `--description`), or `scripts/park.sh <id> "<why>"` to put it
     in Jon's inbox and move on. Never wait for him (hard rule 9).
9. **End the tick** with one line per bead touched and the `queue-check.sh` output, so the next
   iteration starts from evidence rather than memory.

## Writing the acceptance gate

A bead with no executable acceptance block cannot be committed — `accept.sh` refuses, and that
refusal is the gate doing its job. If the bead's block is prose or a placeholder, replace it with
real commands (`bd update <id> --acceptance`) before you implement: deciding what would prove the
work is part of the work.

The block is one command per line, each run in its own `bash -o pipefail -c` from the **repo root**
(so acceptance lines spell the submodule out). The whole block shares a time budget: 300 s by
default, or the bead's `accept_budget` metadata (ceiling 1,800 s) when the proof is a full build and
test run (`bd update <id> --set-metadata accept_budget=900`). A line must be proven to **fail** on
unfixed code, not merely to pass on fixed code — see `references/pitfalls.md`.

The game's own commands, all run from `oolite-dev`:

```
./mk.sh build test                 # build (Clang on Windows via MSYS2 UCRT64)
tests/run.sh unit                  # meson suites: oofnd, core, headers
tests/run.sh component [-k name]   # Gherkin scenarios over the debug console
tests/run.sh gui                   # real window; one at a time, hands off the mouse
tests/run.sh smoke                 # launch and snapshot
```

A typical block: `cd oolite-dev && ./mk.sh build test` then `cd oolite-dev && tests/run.sh unit`
(plus `component -k <name>` when the bead touches behaviour).

## When something is wrong with the task

You are the frontier model: when a bead is wrong, say so rather than forcing it through.

- The story asks you to rewrite C that already compiles — the story is wrong. Park it with that
  reason (hard rule 8).
- The bead needs a capability that does not exist yet — that is a dependency, not a retry. File or
  find the seam bead, `bd dep add <id> <seam>`, release the claim, and move on.
- A decision is missing — take the conservative default, record it with its reason in the bead's
  notes (and the phase doc's Decisions section if it outlives the bead), and proceed. Never wait
  (hard rule 9).

## Epic end

When `queue-check.sh` drains for an epic, run `bash scripts/epic-finish.sh <epic>`. It refuses
while any bead under the epic is still open (beads parked for Jon with the `human` label and
`design` beads aside: a `design` bead must be committed too), runs the end gate in `oolite-dev`
(`./mk.sh build test`, then `tests/run.sh` `unit`, `component`, `smoke`, `gui`; override with
`BEADS_EPIC_GATE`), and on success labels the epic `ready-to-merge`. If the gate fails, the output
is in the epic's notes: file a fix bead under the epic and let the loop run again. The script
prints the merge commands; **Jon** runs them and pushes. Nothing here merges or pushes.

## Phase end

When Jon says a phase is done, everything in it has already been merged epic by epic. What is
left:

1. `scripts/queue-check.sh <selector>` is green and every epic is merged.
2. Bring `oolite-dev` up to date (`git -C oolite-dev checkout develop && git -C oolite-dev pull`)
   and record the new commit here (`git add oolite-dev`, commit). The tick never touches that
   pointer; only this step moves it.
3. Review the whole phase: `git -C oolite-dev diff master...develop`, against the phase doc's exit
   criteria. Dispatch a subagent for this — a fresh reader catches what the author cannot. Use
   `references/reviewer-prompt.md`. File every finding as a bead labelled `review-finding`; an open
   one blocks the pull request.
4. Run `cd oolite-dev && tests/run.sh all`, then open `develop → master` on the game fork with
   `gh pr create --repo jonmseaman/oolite --base master --head develop`. Jon merges it.

## Pitfalls

`references/pitfalls.md` is what previous runs learned the expensive way: orphaned `oolite.exe`
poisoning a launch, acceptance lines that silently cannot fail, MSYS2 PATH traps. Read the section
matching what you are about to do.

Add to it when a tick teaches something the next bead would otherwise rediscover. Keep it specific
and keep the evidence: a pitfall nobody can check becomes folklore.
