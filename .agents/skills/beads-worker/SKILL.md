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
  labels in `BEADS_WORKER_LABELS`, or when that is unset `git config beads-worker.labels`, or
  `fleet`. Run `git config beads-worker.labels "fleet frontier"` in the checkout when the session's
  model is the frontier model and it should take the seams too: the git config is shared by every
  worktree and reaches the workers of a desktop-launched Hermes, whose terminal is a non-login
  `bash -c` that an exported variable never reaches.
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

**Dispatch `accept.sh` in the background and immediately keep claiming/dispatching new work —
do not block the turn waiting for an accept to finish.** `accept.sh` serialises itself with its
own lock, so firing off several in the background is safe; the orchestrator's job is to keep
every worker/reviewer/accept slot full, not to wait on any one of them before starting the next
action. End the turn only when there is nothing left that could be started this turn.

1. **Check the gate.** `terminal(command="scripts/goal-check.sh <N>")`. Exit 0 → report "phase <N>
   queue drained" and stop; the judge will confirm. Nonzero → continue. *Done when: you know
   whether work remains.*
2. **Claim a batch.** `terminal(command="scripts/next-bead.sh <N> <P>")`. One JSON record per
   line; beads that failed a previous round come first, with `attempts` and `notes` populated,
   then `bug` beads before tasks (a bug is a defect in work already on the base branch), then by
   priority.
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
   - **Blocked on a capability that does not exist yet is a dependency, not a retry**
     ([ADR-0020](../../../docs/decisions/0020-component-scenarios-are-smoke-tests-for-now.md)
     §4, from `oo-kbqw`). The first time a blocked report is verified: file or find the seam
     bead, `bd dep add <id> <seam>`, release the claim, remove the worktree. A bead whose status
     is merely set back to open is still ready, and the next worker re-derives the same report.
   - **"Verified against main" from a worker often means a second worktree, not the base branch
     itself — re-verify on the real thing.** A worker reporting a bead's own acceptance line fails
     for reasons "unrelated to this bead, reproduces on main" has usually only checked a parallel
     worktree copy. Before filing an infra-debt bead or calling `reevaluate.sh`, `git branch
     --show-current` to confirm you're actually on the base branch, then re-run the failing line
     yourself there — a worktree can silently diverge (stale checkout, uncommitted local state) in
     ways the real base branch won't. Only a reproduction on the base branch itself turns "probably
     pre-existing" into a fact you can act on.
   - **A frontier worker that times out may have left real, working code — harvest and check before
     treating it as a failed attempt.** A bead's worker can complete the actual implementation and
     even build it successfully, then time out before the last step (writing and storing real
     acceptance via `bd update --acceptance`), which is the only thing that makes the bead look
     "done": from the outside a timeout with no `committed:true` summary looks identical whether the
     worker got nothing done or got everything done. After harvesting a timed-out frontier bead,
     read what actually landed (`git diff main...HEAD --stat`, then the files) before dispatching a
     from-scratch retry: if there's a substantial, coherent implementation, try running whatever the
     worker built (a check script, a test binary) yourself. If it passes, you've just saved a full
     retry round — store the acceptance yourself (single logical line, verified — see the
     accept.sh-per-line pitfall above) and send it straight to review instead of re-implementing.
     But a timeout can just as easily mean the worker was killed mid-edit, leaving a diff that
     LOOKS coherent but does not actually work (e.g. a regex literal truncated mid-token) — a
     "substantial, coherent implementation" claim from reading the diff alone is not proof.
     Independently execute a cheap correctness check on every file the timeout touched before
     trusting it (`python3 -c "import ast; ast.parse(open(f).read())"` / `re.compile(...)` for a
     changed regex, a syntax-only compiler invocation for C/C++) — a five-second check that
     distinguishes "finished, salvageable" from "stopped mid-token, needs from-scratch retry" far
     cheaper than a full retry dispatched on the wrong assumption either way.
   - **Anything parked for Jon gets the `human` label too** (with `rebless` or `proposed-adr`):
     `bd human list` is his inbox and only sees that label; `bd human respond <id>` is his reply.
5. **Delegate the reviewers, one call, one task per committed bead**, each built from
   `references/reviewer-prompt.md`: the worktree path, `git diff main...bead/<id>`, the bead's
   sizing checks and prohibitions. Require `output_schema` `{verdict: approve|request_changes, findings[]}`.
   - **Sizing for golden-scenario beads is read as AUTHORED FILES, not authored lines.** The
     story's `writes<=400 / <=8 files` budget is calibrated for code-porting beads. A golden
     scenario must carry a harness, an evidence checker, a knob gate and a falsifiability suite,
     which lands at ~2300–2700 authored lines in every instance accepted so far (oo-hv4d 2282,
     oo-wseo 2725, oo-ghhw 2519). Count blessed run artifacts (`state.json`, `frame.grid`,
     `frame.png`, `provenance.json`) as DATA, hold the bead to `<=8` authored files, and record the
     line count as advisory. Three reviewers in one session raised this independently and all three
     declined to block on it — do not make each new bead re-litigate it.
   *Done when: every bead has a verdict.*
   - For every verdict: `bd update <id> --append-notes "review: <verdict>; <findings, one per line>"`.
   - `request_changes` → delegate the worker again with the findings appended as context, then
     re-review. Repeat until `approve`. There is no round cap, but if two consecutive reviews
     return the same findings the worker is not learning: `scripts/reevaluate.sh <id> "reviewer
     stalemate: <findings>"`.
6. **Accept each approved bead, and only approved beads.** The review gates acceptance: a bead
   with `request_changes` goes back to step 4 with the findings, never to `accept.sh`. A finding
   is fixed on the bead branch before the merge, not filed as a new bead after it.
   `terminal(command="scripts/accept.sh <id>", timeout=600)`. The acceptance block has a
   five-minute budget in total (`BEADS_ACCEPT_BUDGET`, ADR-0021); a rejection that says
   "ACCEPTANCE BUDGET EXCEEDED" goes back to the worker with "move the slow line to
   `tests/nightly/checks.txt`", never with a bigger budget.
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
- **Harvest can commit a SABOTAGED GATE, so check before accepting.** A worker killed at its
  timeout mid-mutation leaves its gate disabled on disk, and `harvest.sh` commits whatever is
  there. Bead `oo-dto` was harvested with `if False:` in place of the one predicate the scenario is
  named for; the gate would have passed a run where the event never happened. Before accepting any
  bead that ran a mutation harness, grep the **committed** tree for disabled predicates
  (`if False:`, `if 0:`, `elif False:`, commented-out `raise`) and read each hit: a replacement
  *string literal* inside a mutant-building test is fine, a live code path is not. Tell workers to
  mutate a throwaway copy under `$LOCALAPPDATA/Temp`, never the real file — restore-on-exit never
  runs when the process is killed.
- **`gc.sh` and `next-bead.sh` are blind to live workers — check before you act on them.** Both
  reason from bead status and worktree state on disk, and neither can tell "abandoned by a dead
  worker" from "in active use by a live one". Run mid-cycle, `gc.sh` harvested three worktrees
  belonging to *running* workers and `next-bead.sh` re-claimed two beads already in flight — a
  dispatch straight from that output would have put two workers on one bead. Worse, a mid-flight
  harvest commits whatever the worktree holds **at that instant**, which for a worker running a
  mutation harness is a disabled gate (see the sabotage bullet above). Before acting on either
  script's output, call `delegate_task action='list'` and treat every bead whose worker is
  `status='running'` as off limits; audit any `uncommitted work harvested` commit for disabled
  predicates before it can reach an accept. Mutating only throwaway copies under
  `$LOCALAPPDATA/Temp` makes a worktree safe to harvest at any instant.
- **Harvest can also commit a file into the guarded `goldens/` tree.** `harvest.sh` commits
  whatever is on disk and knows nothing about protected paths. Bead `oo-qd6` timed out leaving a
  3-byte `{}` stub at `goldens/windows-x64/008-material-test-suite/state.json` — a mutation probe
  of the gate's guarded-path fallback — and it was committed. `guardrails.sh` caught it (`FAIL`,
  "is under a protected golden path and is changed and has no re-bless approval"), but acceptance
  replays the *bead's own* lines, so a bead that never invokes guardrails would have merged it.
  After harvesting any timed-out bead run `git diff --name-only main...HEAD | grep ^goldens/` and
  `bash tools/guardrails.sh` in the worktree before accepting. Before deleting such a file, `cmp`
  it against the staged copy under `tests/golden/pending/` and read its contents — a stub is safe
  to drop, the real artifact is not.
- **Export `PATH="/ucrt64/bin:$PATH"` in every terminal call that runs a fleet script.** `accept.sh`
  inherits the orchestrator's shell, and the Hermes desktop terminal's PATH has no MSYS2 UCRT64
  prefix, so acceptance lines calling `python3` die with `command not found` `[exit 127]` on
  perfectly correct work (observed on oo-5ggu: attempt 1 rejected at line 1; the identical command
  re-run with `/ucrt64/bin` on PATH closed the bead). An `[exit 127]` is an environment defect, not
  a verdict: fix the environment and re-run **before** writing `accept attempt N failed` into the
  notes or counting it toward `BEADS_WORKER_STALE_REPEATS`. Same class as the oo-gla learning, one
  level up — there a bad PATH killed a game launch inside a worker, here it killed the accepter.
- **Do not fill the batch with game-LAUNCHING beads: they starve each other and fail healthy work.**
  Four scenario beads running 10-run stability sweeps at once made oo-rkm's live acceptance line
  fail **six consecutive times**, every failure an instrument signature (`TimeoutExpired ... after
  10 seconds`, `ConsoleError: no answer to 'system.name' within 15s`, `rm: ... Device or resource
  busy`, each logged at `procs=5`/`procs=6`) — while the same line on the same tree measured green
  3/3 an hour earlier. Six identical failures is normally the signature of a broken gate
  (`BEADS_WORKER_STALE_REPEATS` is 5), so this is exactly where an orchestrator wrongly escalates
  healthy work. Launching beads contend for CPU, for the shared console port 8563 and for the
  shared app dir; offline beads (checkers, gates, mutation suites over stored artifacts)
  parallelise freely. **Mix the batch: at most one or two launching beads at a time**, and when a
  launching line fails, check the sibling load before believing it.
- **Before any game-launching line, require `ps -W | grep -ci oolite` to be 0 — orphans poison it.**
  A game a worker launched through a harness subprocess is **not** killed when that worker ends: it
  keeps console port 8563 bound and keeps handles on its staged app copy. oo-rkm's live line failed
  seven times across two sessions (`TimeoutExpired ... after 10 seconds`, `ConsoleError: no answer
  to 'system.name' within 15s`, `rm: ... Device or resource busy`) with **no children running** —
  three orphaned `oolite.exe` were still alive, two of them hours old. After killing them the
  identical line on the identical tree returned **rc=0 in 16s**, against rc=1 after 117s moments
  earlier. MSYS `ps` puts the *Windows* pid in field 4, and `taskkill //PID` is mangled by MSYS
  argument conversion, so kill with:
  `ps -W | grep -i oolite | awk '{print $4}' | while read p; do /c/Windows/System32/taskkill.exe /PID $p /F; done`
  Log the count beside every result: `rc=1 wall=117s oolite_procs=4` diagnoses itself; a bare rc=1
  gets mistaken for a broken gate and, at five repeats, escalates healthy work. A long wall time is
  the tell — the harness is burning its retry budget against a port that will never answer.
- **A component-stage timeout (`[exit 124]`) after several concurrent worker/accept rounds is
  usually orphan-process buildup across ALL of them, not just `oolite.exe` — sweep every process
  tree, not just the game binary.** Multiple workers each running their own `tier-b.sh --fast` in
  parallel leave behind not only orphaned `oolite.exe` (see above) but orphaned `tools/gui-lock`,
  `tools/tier-b.sh`, and `tools/gui-acceptance-recheck` shell trees with PPID 1 (reparented after
  their owning subagent already exited) that keep holding or re-queuing for the desktop lock.
  `ps -W -f | grep -iE "gui-lock|tier-b|oolite"` after a batch of several workers/accepts is
  routine, not exceptional; kill every orphaned line (`kill -9 <pid>` for bash trees, the
  `taskkill.exe` loop above for `oolite.exe`), not just the game processes, before retrying an
  accept that hit a timeout. A single sweep can take two or three rounds — new orphans surface as
  a killed tree's children get reparented — so re-check `ps` after killing, not just once.
- **Replay a stored acceptance block the way `accept.sh` does, or you will silently skip a line.**
  `while IFS= read -r l; ...; done < file` DROPS the final line when the file has no trailing
  newline (measured: `printf 'a\nb\nc' > f` reads **2 of 3**). `accept.sh` is immune because it uses
  a here-string — `done <<<"$acceptance"` — and bash always terminates a here-string (3 of 3). A
  reviewer hit this on oo-zyj1, reported `RAN=6` against 7 stored lines, and nearly filed it as a
  bead defect; the dropped line was the LIVE RED PROOF, the one whose absence most weakens a
  review. Always assert lines-run == lines-stored taken from `bd show --json`, never from your own
  temp file — a count from the file that lost the line cannot detect the loss. A worker that
  validated its own acceptance this way may have left its last line untested while honestly
  reporting success.
- **Keep the root checkout clean, or an accept will pass its gates and still fail to land.**
  `accept.sh` runs acceptance on a scratch tree, then fast-forwards the base branch *in the repo
  root*; a dirty root makes that last step fail with `acceptance passed but fast-forwarding main
  ... failed (dirty checkout?)`, leaving a valid merge commit orphaned and the bead open. The mess
  is usually the fleet's own housekeeping — bd DB writes to `.beads/*.jsonl`, `docs/fleet/
  LEARNINGS.md`, stale `.fleet-progress.*` files, untracked `.ctx/`. Commit the real tracked-file
  changes (`git add <files> && git commit`) and/or `git clean -fd` the untracked scratch, then
  re-run `accept.sh`: the work is not lost, the merge commit is intact and a plain retry usually
  fast-forwards onto it.
  **But if enough time passed between the failed accept and your retry that OTHER accepts landed
  on main in between, the orphaned merge commit itself is now stale relative to main (it was built
  as a fast-forward child of an OLDER main) — a bare retry's `--ff-only` will fail again with
  "not possible" even though the root is now clean, because it's no longer a fast-forward, it's a
  genuine divergence.** Diagnose with `git merge-base --is-ancestor <the reported merge sha> HEAD;
  echo $?` (1 means it does NOT reach current main). Fix by merging it in for real:
  `git merge <the reported merge sha> --no-edit` (resolve any trivial conflicts, e.g. two sessions'
  appends to the same append-only log file — keep both sides) — this lands the bead's actual code
  on main immediately, but the bead itself is still `in_progress` because `accept.sh` never got to
  run its own close step. Re-run `accept.sh <id>` again (in the background is fine): it will
  harvest/merge/rebuild/rerun acceptance against a tree that now already contains the fix (so it
  should pass quickly) and complete the close/cleanup that the manual merge skipped.
- **Two different live-launch failures look alike; only one is an orphan.** `rc=3
  ConnectionResetError [WinError 10054]` arrives FAST (6–10s) with `oolite_procs == 0` — a reset
  mid-handshake, measured at 3 of 5 attempts in one window and then 12 clean passes, clustering
  within ~3s of a taskkill sweep (teardown racing the console port). The harness does not cover it:
  `start_with_retry` handles a process that dies before `main()`, `WorldNotProbeable` one that never
  answers, a reset is neither. It blocked a real accept (oo-rkm, already approved, both landing arms
  7/7 green). Wrap the accept batch in a retry loop that INSPECTS the output: on
  `ConnectionResetError`/`rc=3`/`TimeoutExpired`, clear orphans, wait ~20s for the port to settle,
  retry up to 3 times; on ANY other failure stop at once — a real gate failure must never be
  retried into a false green. Never taskkill and immediately relaunch.
- **Pre-check a `sweep:js-retarget` file for real `JS_*` sites before dispatching a worker.**
  `tools/gen-stories.py:374`'s selector for this sweep matches on header import (`jsapi.h`/
  `OOJavaScriptEngine.h`), not on its own acceptance predicate (`grep -nE '\bJS_[A-Za-z]+'`), so it
  files vacuous beads for files that already have zero `JS_*` call sites (tracked as generator-bug
  `oo-utqt`, not yet fixed as of this writing). Before claiming a worker slot for a retarget bead,
  `grep -c -E '\bJS_[A-Za-z]+' <the file>`; if it's 0, skip the worker round-trip entirely and go
  straight to `worktree.sh` (to get a branch for the notes/escalation trail) then `escalate.sh`
  with the pre-check result, citing the existing generator-bug bead instead of filing a duplicate.
  Two sibling beads independently discovered and filed the identical generator-bug in one batch
  (`oo-utqt` from `oo-0s4`, `oo-hj97` from `oo-1sk`) before this was known — when that happens,
  mark the later one's notes as a duplicate of the earlier rather than trying to close either
  (only `accept.sh`/the human triaging `phase:0` closes a bead).
- **A stored acceptance line must be proven to FAIL, not just to pass.** A worker built a regex
  acceptance line in python3 (`frame_hash\.GRID_SIZE`) and stored it via `bd update --acceptance`;
  the round trip through bd/JSON doubled the backslash to `frame_hash\\.GRID_SIZE`, which `git grep`
  reads as literal-backslash-then-any-char and matches nothing — on ANY tree, fixed or not. Every
  replay on the fixed tree looked green. Only a reviewer running the stored line verbatim on the
  UNFIXED tree caught it: rc=0, "PASS: no reference remains," while the bug was still there. Rule:
  whenever a stored line embeds a backslash, after reading it back with `bd show --json`, run it on
  a tree where the defect is KNOWN to still be present (pre-fix main, or a throwaway copy with the
  bug reintroduced) and confirm it fails there. Green-only replay cannot detect a gate that can
  never turn red.
- **A regex/text-scan codemod script that rewrites JS_* (or any) tokens must be string/comment-aware, or it corrupts source it should leave alone.** A reviewer caught bead oo-oio's `tools/refactor/js_stubs.py` rewriting matched tokens found INSIDE string literals (e.g. a log message quoting `"JS_PropertyStub"`) and inside comments with call-shaped text (e.g. `// JS_ValueToNumber(context, val, &x)`), because it scanned raw file text with a bare regex/`.find()` and had no notion of what a string or comment span is. A single test fixture had passed only by luck (its one comment mention had no real parens to rewrite). Any codemod/refactor-script bead — and there will be many more of these in a retarget-pattern-across-N-files sweep — must be reviewed by constructing TWO adversarial fixtures beyond the happy-path exemplar: one with the target token inside a string literal, one with a call-shaped mention inside a comment with real arguments, and asserting both are byte-for-byte unchanged after the rewrite. Do not accept a codemod script whose selftest only proves the exemplar file round-trips correctly.
 The same class of bug recurs one level up: a token-shape codemod tuned against a single exemplar
 call site can still corrupt other real call sites that have a different STRUCTURAL shape around
 the same token. Bead oo-oio's `JS_InitClass` rewrite worked on the exemplar's bare
 `sVectorPrototype = JS_InitClass(...)` but stranded the leading type in front of the rewrite for
 the equally-common `JSObject *clockPrototype = JS_InitClass(...)` inline-declaration form — found
 in 3 of 27 real call sites in the tree, none of which the exemplar or fixtures happened to cover.
 Before approving a codemod, `grep -n <target-token>` across the real source tree the script will
 actually run against, group the hits by surrounding shape (leading type declaration, expression
 context, multiple statements per line, etc.), and require the worker to run the script (`--stdout`
 or equivalent dry-run) against at least one REAL file for each distinct shape found, not just the
 synthetic fixtures the worker built — a fixture built by the same author who wrote the regex tends
 to only exercise the shape the regex was written for.
- **A Python heredoc storing acceptance via `bd update <id> --acceptance` MUST use a raw string, or `\b` becomes a literal backspace byte that silently corrupts the regex.** A non-raw `"...\\bJS_...\"` collapses `\b` to `\x08` before it reaches bd; `bd show --json` round-trips that same corrupted byte, so a visual read-back looks fine while accept.sh's shell parse breaks or the regex matches nothing/everything. Always build the string with `r"""..."""`, and after storing, explicitly assert `chr(8) not in acc` in the read-back check.
- **A bead's own approved rename (e.g. `.m`->`.mm`) can leave the stored `tools/tier-b.sh --fast` line missing `OO_APP_DIR` AND pointing at the pre-rename filename — check both.** `tools/tier-b.sh --fast` needs `OO_APP_DIR` pointed at the shared local build or a fresh `accept.sh` checkout fails at `[build]` with "no oolite.exe ... point OO_APP_DIR"; separately, if you patch an existing acceptance string yourself after a worker renamed the file, respell the grep/tier-a targets to the new name too, or tier-a silently PASSes on a file that no longer exists. Fix both together, verified with `ls` in the worktree before storing: `OO_APP_DIR="${OO_APP_DIR:-<repo>/upstream/oolite/build/meson_test/oolite.app}" tools/tier-b.sh --fast`.
- **A worktree branched before a sibling bead's rename-only merge will diff as REVERTING that sibling's work when compared against current main — this is a stale-branch artifact, not sabotage.** `git diff main..HEAD` on the stale branch shows the shared file (`meson.build`, or the renamed source file) disappearing/reverting because the worktree's snapshot of main predates the sibling's merge, even though this bead's worker never touched that file. Do not block the bead: dispatch a `git merge main` continuation (same pattern as a real merge conflict) to fold in the sibling's landed rename, verify `git diff main..HEAD` now shows ONLY this bead's own change, and only re-review if the merge touched logic — a pure rename-conflict resolution can often skip a second full review round.
- **Component-scenario nondeterminism is not confined to whichever 3 scenarios a flake bead names — treat a new scenario's failure as the same class, not a new bug.** oo-sjvz was scoped to s1/s5/s6, but s2 (trader-survival) also flaked on a later, unrelated bead's accept — same role-based-spawn nondeterminism, different scenario. Don't file a new investigation bead per newly-observed flaky scenario; log it as a widening-scope note on the existing escalated flake bead and keep retrying the blocked accept, since the fix (when it lands) will likely cover all of them.
- **Fixing scenario nondeterminism must pin it INSIDE the existing step's Python implementation, never by editing or adding Gherkin step text.** `guardrails.sh`'s test-immutability classifier flags ANY change to a `.feature` step-text signature as "emptying" a live test unit, even a precision-adding rewrite — and adding brand-new step definitions alongside the old ones has the same problem once the `.feature` file is edited to call them. The approach that actually lands: keep every step's wording byte-for-byte identical to what already ran, and move the fix into the step's underlying Python (`world_steps.py`) — e.g. a `role -> pinned ship key` / `role -> pinned bounty` lookup dict inside `_spawn`, so a role-spawned step becomes deterministic without the `.feature` file ever mentioning a ship key. A worker fixing this class of bug should end with a `.feature` diff of **zero** and all determinism logic living in the step implementation only; if the `.feature` diff is non-empty, the fix is in the wrong layer and guardrails will likely reject it.
- **A stored acceptance block runs one line at a time, each in its OWN `bash -o pipefail -c`; shell state does not cross lines.** `accept.sh` reads the stored acceptance with `while IFS= read -r cmd; do ... bash -o pipefail -c "$cmd" ...; done`, so a variable set on one line (`B="$TMPDIR/x"`) is gone by the next line that reads `"$B"` — it silently expands empty and the command fails with a confusing message (`mkdir: cannot create directory '': No such file or directory`), not an obvious "undefined variable" error. This burned two stale-identical rejections on bead oo-kte before the cause was found. FIX: any acceptance script with shared state across statements must be stored as ONE LOGICAL LINE (`;` or `&&`-joined, not real newlines). Before storing with `bd update <id> --acceptance`, test the fully-joined line under `bash -o pipefail -c "$CMD"` exactly as accept.sh will invoke it — a multi-line version that "looks right" and even runs fine interactively (where the whole block executes in one live shell) is not proof, because interactively you never split it into independent subshells the way accept.sh does. This is the worker-prompt.md rule now too, but the orchestrator must also catch it: a `mkdir`/`cd`/file-path failure with an EMPTY path in an accept.sh rejection is this bug, not a real defect — read the notes for a vanished variable before bumping stale_count.
- **A bead's own approved rename (e.g. `.m` -> `.mm`) makes its OWN stored acceptance stale — fix
  the path, don't retry blind.** `accept.sh` rejects with "No such file or directory" on the
  `grep`/`tier-a.sh` line because the acceptance was generated (or written attempt 1) against the
  pre-rename filename, and the worker's approved diff legitimately renamed the file as part of the
  retarget. This is not a code defect: `bd show <id> --json` the `acceptance_criteria`, confirm the
  file at the new name (`ls upstream/.../Foo.mm`), and `bd update <id> --acceptance "<same lines,
  new path>"` (single logical line if it was one before — see the accept.sh-per-line pitfall) before
  re-running `accept.sh`. Do not bump `stale_count`/retry the worker for this; the fix is bd-data
  only and does not need a worker round-trip (see below).
  **`acceptance_criteria: None` (falling back to the bead body's pre-generation filename) is the
  DEFAULT state for a freshly generated js-retarget bead, not an occasional miss** — every instance
  checked (oo-9yr, oo-aa0, oo-af1, oo-c4q, oo-dhx, oo-b8w, oo-bgt, oo-bnq) needed this fix. When a
  `next-bead.sh` batch claims several js-retarget beads at once, check and fix all of them in one
  pass right after `worktree.sh` — `bd show <id> --json` for `acceptance_criteria`, `ls` the
  worktree's directory for the real `.mm` name, store the corrected 3-line block (grep, tier-a,
  `OO_APP_DIR=... tools/tier-b.sh --fast`) — instead of discovering it one accept-rejection at a
  time; the fix is identical across every bead in the sweep and costs nothing to do proactively.
- **`bd update <id> --acceptance/--append-notes` is bd-data, not a git-tracked file — the
  orchestrator MAY run it directly.** A worker confirmed this explicitly: bd's store is
  dolt-backed and gitignored, so fixing a stale acceptance path or appending a note is not
  "touching a worktree's tracked files" and does not need a delegated worker. The "never touch a
  worktree's tracked files yourself" rule is about files git will diff/commit (`upstream/...`,
  `tools/...`, anything `git status` shows) — if you catch yourself reaching for `patch`/
  `write_file` on one of those inside `.worktrees/<id>`, stop and delegate instead (caught and
  reverted mid-session: a one-line `guardrails.sh` SCAN_EXEMPT addition was patched directly by
  the orchestrator, then reverted and redone as a worker task, which is the correct path for any
  file `git diff` would show).
- **`tools/tier-b.sh --fast` needs `OO_APP_DIR` pointed at a real build, or every bead's stored
  acceptance breaks in a fresh `accept.sh` checkout.** `--fast` skips the `[build]` stage and reuses
  whatever `OO_APP_DIR` already points at; a bead's stored acceptance line that just says
  `tools/tier-b.sh --fast` works in the worker's own worktree (which has a build) but fails with
  "no oolite.exe at .../oolite.app; point OO_APP_DIR" the moment `accept.sh` replays it in a fresh
  scratch checkout with no build of its own. Fix once per bead: `bd update <id> --acceptance` with
  `OO_APP_DIR="${OO_APP_DIR:-<repo>/upstream/oolite/build/meson_test/oolite.app}" tools/tier-b.sh
  --fast` in place of the bare call — this defaults to the repo's one shared local build without
  breaking a caller that already sets `OO_APP_DIR` explicitly.
  **`--fast` NEVER rebuilds, so for a bead whose actual fix is a source/binary change (not a
  test/harness-only change), an all-`--fast` acceptance can pass or fail based on a STALE shared
  binary that predates the fix entirely — it is testing whether the fix compiled, not the fix
  itself.** If the shared binary at `OO_APP_DIR` was built before the bead's commit landed, every
  `--fast` run replays the SAME pre-fix behavior regardless of how correct the diff is; a
  "5 consecutive passes" acceptance can genuinely need those 5 runs to see the fix and still fail
  every time because none of them ever compiled it in. For any bead whose diff touches source (not
  purely tests/harness), store acceptance as ONE real build followed by `--fast` reruns, not all
  `--fast`: `bash tools/tier-b.sh || exit 1; for i in 2 3 4 5; do bash tools/tier-b.sh --fast || exit 1; done`
  — this compiles the fix in exactly once (the scratch checkout's own build) and then reuses that
  freshly-built binary for the remaining repeats, avoiding 5 full rebuilds while still proving the
  fix is what's under test.
- **A `001-launch-dock` "N entities, fewer than M minimum" (or similarly-shaped) golden refusal is
  not automatically the known load-dependent flake below — a genuine JS/init regression can produce
  the IDENTICAL symptom, and only running the scenario against a binary that actually contains the
  candidate fix distinguishes them.** A `JS_InitClass`/`initClass` call passed a null constructor
  left a prototype (e.g. `Mission.prototype`) undefined, which threw inside a `defineMethod(...)`
  call during world-load script execution and aborted population before the scenario's second
  entity ever spawned — same "has 1 entity, fewer than 2 minimum" refusal text as the load-flake
  class. Before writing off a goldens refusal as the documented flake (or before writing off a
  fix as "unrelated to this symptom" the way a reviewer might on a diff that touches
  `OOJSMission.mm`/init code rather than a test file): grep `Resources/Scripts/` for a
  `defineMethod`/property access on the prototype the diff touches, trace whether that call
  executes during world load, then independently rebuild and run the scenario 2+ times against a
  binary containing ONLY the candidate fix (see the `--fast`-staleness bullet above for how to
  force a real rebuild) before either accepting a reviewer's scope objection or overriding it — the
  empirical rerun is stronger evidence than either the diff's apparent unrelatedness or a stored
  "scope" argument alone.
- **`tools/guardrails.sh`'s own documented remedy for a low-similarity-rename deny-list false
  positive ("split the pure move into its own commit") does not actually work — verify before
  trusting the tool's comment.** The script's header explains that a rename git scores below its
  ~50% similarity threshold (`git diff -M`) gets no baseline credit and reads as delete+add, and
  suggests splitting history so the pure rename lands as its own commit. In practice `guardrails.sh`
  computes `CHANGE` as a tree-to-tree diff across the full `BASE..HEAD` range
  (`git diff --name-status --find-renames "$BASE" --`), which compares the ORIGINAL content at BASE
  against the FINAL content at HEAD regardless of how many commits sit between them — splitting the
  commit cannot raise that end-to-end similarity score. A worker that reports "split the commit,
  guardrails now passes" must be independently re-run (`bash tools/guardrails.sh --base <ref>` in
  the worktree, not trusted from the summary) before treating the bead as unblocked; if it still
  FAILs, this is a real tool defect worth its own bead/ADR (pass `--base` at the exact pre-move ref,
  or extend the deny-list's rename-credit logic to work per-commit), not something a retarget-sweep
  worker can fix by rearranging their own history.
- **When `next-bead.sh` hands you a batch of beads that all share the exact same acceptance
  pattern (e.g. every `sweep:js-retarget` bead ends in `tools/tier-b.sh --fast`), and you already
  know that pattern is broken (an infra-fix bead for it is filed or in flight), do not dispatch
  workers on the batch — release every claimed bead back to `open` (`bd update <id> --status
  open`) and file/point at the one shared infra bead instead.** Each worker dispatched anyway will
  independently discover the same wall ~15-20 minutes later (one real game-launch cycle), costing
  a full round per bead for information you already have. Confirmed cheap in practice: 5 freshly
  claimed retarget beads released in one batch, replaced by a single P1 infra bead
  (`tools/tier-b.sh --fast`'s component-stage budget), which unblocked all of them at once once
  merged. Re-claim the released beads with `next-bead.sh` normally after the infra bead closes.
- **Three different, unrelated component-tier failures across consecutive `accept.sh` retries of
  the SAME bead is a signal to stop retrying and check the budget/infra, not to try a fourth time.**
  Genuine flakiness (a random-draw combat scenario per the `docs/fleet/LEARNINGS.md` oo-qwk5/oo-jor/
  oo-izi entries) produces the SAME kind of failure repeating; three DIFFERENT scenario failures in
  a row (e.g. a hostile-target timeout, then an over-budget green run, then an unrelated survival
  assertion) on a bead whose diff never touches the component tier points at the gate itself, not
  the bead — most often `tools/tier-b.sh --fast`'s component stage exceeding its own stated budget
  regardless of content (measured 769-957s against a 600s budget). `scripts/reevaluate.sh` on the
  bead, quoting all three distinct failures, is cheaper than a fourth ~15min attempt and correctly
  routes to a shared infra fix (e.g. raising the budget) rather than one bead absorbing the cost of
  every sibling bead's same wall.
- **ANY worker — frontier or plain fleet — can finish real work, report `committed: true` with no
  timeout, and STILL leave `acceptance_criteria` unset (`None`) or as unreplaced prose.** This is
  distinct from the timeout case above: the worker did everything else (implementation, build,
  tests) and simply skipped the "store real acceptance via `bd update <id> --acceptance`"
  instruction despite it being in the worker prompt. Not a frontier-only failure mode: it happens
  on ordinary fleet beads too, including ones the orchestrator itself created without an initial
  acceptance block. Before harvesting ANY bead's result as done, always `bd show <id> --json` and
  check `acceptance_criteria` is not `None`/comment-only, regardless of what the worker's summary
  claims — do not trust a `committed: true` report as proof the acceptance step happened. If it's
  missing or still prose, either dispatch a short continuation round asking only for that one step
  (with the concrete acceptance command spelled out), or — since `bd update --acceptance` is
  bd-data, not a tracked file — the orchestrator may write it directly after independently
  deriving and verifying a real, single-logical-line command (see the bd-data-not-tracked-file
  bullet above) rather than round-tripping a worker for a one-line store.
- **Never touch a worktree's tracked files yourself — not for a reviewer-specified one-liner, and
  not for a fix you diagnosed yourself either, even a merge-artifact compile error that feels like
  "obviously just restore the known-correct structure from main".** The orchestrator delegates all
  code changes; `patch`/`write_file` on a file under `.worktrees/<id>` is a rule violation
  regardless of how trivial, how clearly-correct, or how self-evidently mechanical the edit looks
  (e.g. restoring a malformed `extern "C"` brace pair to match main's known-good structure after a
  stale merge). Dispatch a worker continuation round instead, even when you could type the fix
  faster yourself and even when you are confident you know exactly what's wrong — the discipline
  exists so every change has a worker attribution and passes through review/harvest like every
  other change, not because the fix is hard to get right.
- **The orchestrating shell can be missing `LOCALAPPDATA` even when the same variable is visible in other command batches.** A plain `terminal()` call sometimes runs `accept.sh` without `LOCALAPPDATA` set (its acceptance lines use `${LOCALAPPDATA:-/tmp}` and get the wrong, empty-under-MSYS `/tmp` fallback on some invocations). Explicitly `export LOCALAPPDATA="C:\Users\<user>\AppData\Local"` alongside `PATH="/ucrt64/bin:$PATH"` at the top of every `accept.sh` call rather than assuming it is inherited.
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
- **`tools/tier-b.sh --fast`'s default `OO_APP_DIR` points at ONE shared build at the repo root
  (`upstream/oolite/build/meson_test/oolite.app`), and it can go missing mid-run for reasons that
  have nothing to do with the bead being accepted.** Symptom: `accept.sh` fails fast (~20s) with
  `no oolite.exe at .../oolite.app; point OO_APP_DIR` even though the exact same bead passed tier-a
  and has a clean diff. Before treating this as a real rejection: `ls
  upstream/oolite/build/meson_test/oolite.app/oolite.exe` at the repo root. If it is missing, do
  NOT blindly `bash tools/build-windows.sh test` at the root and wait 10+ minutes — first check
  whether any live worktree already has a fresh, link-clean build (a worker that just finished
  `tools/build-windows.sh test` in its own worktree as part of verifying its own fix is the
  fastest source): `cp -r .worktrees/<id>/upstream/oolite/build/meson_test/oolite.app
  upstream/oolite/build/meson_test/` restores the shared build in seconds. Only fall back to a
  full root-level rebuild if no worktree has one. Log this as environment state in the bead's
  notes, not as an acceptance failure, and do not count it toward `stale_count`. Root cause is
  usually mundane (another concurrent accept's scratch-checkout run, or the shared build simply
  never having been populated at the root this session) — it is not evidence against the bead.
- **A component/offline pytest failure surfacing only inside a `tier-b.sh --fast` run must be
  reproduced with a bare, direct pytest invocation before it is blamed on the bead under review.**
  `accept.sh`/`tier-b.sh` wrap the real command in scratch checkouts and timeouts that make it hard
  to tell "this bead broke it" from "this was already broken on main". Isolate: `cd` to the repo
  root (confirm with `git branch --show-current` = the base branch), then run the exact failing
  test file/node directly, e.g. `python3 -m pytest <path>::<test> -x -q` — no `tier-b.sh`, no
  scratch checkout, no timeout wrapper. If it fails the same way on plain `main`, it is a
  pre-existing infra defect (log it, do not count it against the bead) rather than a regression;
  if it only fails through the wrapped run, the wrapper/environment is the suspect, not the code.
- **This box routinely runs MORE THAN ONE orchestrator session against the same repo at the same time — never assume you are the sole actor on the queue.** Evidence every session should expect: another session's `accept.sh` holding `.beads-worker-accept.lock` with a live, different PID; bd notes on a bead you just claimed already containing an `orchestrator:`/`review:` entry timestamped minutes ago from a session you didn't start; a worker's own `git log` showing a `bead oo-x: merge into main` commit that is NOT yet an ancestor of your local `main` (a sibling's scratch-checkout merge simulation, not a landed merge). Before retrying a lock, an accept, or a review round: check the lock's PID is actually yours or dead (`cat .beads-worker-accept.lock/pid`, `ps -W | grep <pid>`) rather than assuming staleness, and re-`bd show <id> --json` immediately before acting on a bead's notes/acceptance rather than trusting what you read a few tool calls ago — a sibling session can have rewritten it in between. This is expected steady-state, not a fault to fix.
  **Do not manually poll the lock file before launching your own `accept.sh` — it already self-queues.** `accept.sh` retries `mkdir "$lock"` in a loop for up to `BEADS_ACCEPT_LOCK_WAIT` (default 1800s) and reclaims a lock whose owner PID is dead, so firing it off in the background the moment a bead is approved — even while a sibling session visibly holds the lock — is correct and cheap: it will simply wait its turn and run the instant the lock frees, no separate polling loop needed from you. Spending several `sleep 300` + `cat .../pid` + `ps -W` cycles checking whether the lock is free before you dare launch is wasted turns; launch immediately, then poll the accept *process* (`process_manage poll`) instead of the lock file, and use the freed turns to claim/dispatch the next bead. Also re-check whether a queue-wide shared-infra fix bead (e.g. the recurring post-rename C-linkage fix below) has landed since you last looked before merging a bead's worktree with `main` — a concurrent sibling session closing it mid-turn is common and silently unblocks several of your own queued beads.
  **A worker or reviewer's own summary casually citing an ADR spreads across sessions faster than a human would notice — treat every ADR citation as unverified even when an earlier bead's notes already "confirmed" it, and verify MERGED STATUS, not just existence.** A citation used to justify weakening acceptance (e.g. claiming some ADR replaced `tools/tier-b.sh --fast` with a cheaper check for a whole sweep) can be independently repeated by a different worker and a different reviewer in two different concurrent sessions within the same hour, each treating the other's confident phrasing as corroboration. Two distinct failure shapes look identical from a bead's notes and both must block the same way: the ADR can be fully fabricated (`find docs/decisions -iname '*NNNN*'` finds nothing on ANY branch), or it can be real but still `in_progress` on its own bead branch, not yet merged to the base branch (`git show main:docs/decisions/NNNN-*.md` fails even though `git show bead/<its-id>:docs/decisions/NNNN-*.md` succeeds). Either way the cheaper check is not yet a valid substitute for the base branch's real gate — do not accept an acceptance-rewrite on the strength of a citation until `git show <base-branch>:docs/decisions/NNNN-*.md` succeeds. Run this check on sight of any ADR number you don't already have memorized as landed, every time, not just once per session; the same citation can resurface after you already corrected it once, cited by a sibling who never saw your correction, and once the real ADR eventually does merge, every bead that was held to the stricter gate in the meantime should be revisited in one pass rather than each one re-discovering the merge independently.
- **A recurring "post-rename C-linkage" infra break (missing `OOJS_EXTERN_C`/`extern "C"` after a `.m`->`.mm` rename) can resurface even after a dedicated fix bead for it just closed, because sibling accepts keep landing new renames while the fix bead is in flight.** Chasing whichever undefined symbols the linker reports *right now* only fixes yesterday's backlog; by the time that fix bead merges, more renames may have landed. Symptom: `bash tools/build-windows.sh test` off a fresh clean `main` fails to link, shortly after a bead that fixed the exact same class of bug closed. Treat this as a systemic sweep-vs-race problem: file/dispatch a new fix bead the same way (grep the linker's undefined-symbol list, wrap each declaring header), but expect it to need another round soon if there are still open js-retarget beads landing renames concurrently — don't be surprised when it recurs, and don't block the whole fleet waiting for a single "final" fix bead to make it permanently green.
- **A worker/review round's citation of an ADR or decision doc must be verified to exist before it changes what gate you require — this pattern (fabricating a citation to justify weakening the acceptance bar) recurs across different beads, not just once.** `find docs/decisions -iname '*NNNN*'` / `grep -r 'ADR-NNNN' docs/` before accepting any acceptance-rewrite that swaps `tools/tier-b.sh --fast` for something cheaper (e.g. `tools/guardrails.sh` alone). Do this reflexively on every acceptance-rewrite you see, not only after being burned once.
- **A worker on a fleet/sweep bead can silently do the work of its own blocking FRONTIER seam bead instead of stopping — a reviewer must check this explicitly, and the fix is to split, not to re-implement from scratch.** A retarget-sweep worker hit a call site with no facade equivalent, correctly identified that adding one is a new-interface violation requiring a seam bead, but then added the interface itself inside the fleet bead anyway rather than stopping (the seam bead it should have deferred to was sitting open, unclaimed, with `bd dep add` already pointing at it). The diff was otherwise excellent — do not discard it. Fix: dispatch a worker for the seam bead that extracts the EXACT SAME hunks from the sweep bead's own commit (`git show <sha> -- <files> | git apply`, or `git diff main...HEAD -- <files>` read and hand-applied) into the seam bead's own branch, adds real (non-prose) acceptance for it, and gets it reviewed independently; only once the seam bead is merged does the sweep bead's worker `git merge main` and drop its now-duplicate hunks (main's copy wins the conflict) so its own diff shrinks back to just its licensed scope. This preserves the seam's own review/acceptance gate instead of laundering a new interface through a bead not scoped to add one, and costs one extraction task rather than a from-scratch reimplementation.
- **When independently verifying a worker's "this failure is pre-existing on main, not caused by my change" claim, never run `git checkout <ref> -- <file>` or any other tracked-file mutation inside an EXISTING bead worktree you don't own — build a separate, disposable one.** The urge to quickly swap a file back to main's version inside a worktree that's mid-review dirties a branch that must stay clean for `accept.sh`'s fast-forward step, and is easy to do by habit when you're already `cd`'d into that worktree to compare diffs. Instead: `git worktree add --detach <repo>/.worktrees/_verify_<label> main` (a fresh path, never an existing `.worktrees/<bead>`), run the check there, then `git worktree remove --force` it when done. If you do slip and modify a live worktree's tracked file, `git checkout HEAD -- <file>` immediately and confirm `git status --porcelain` is empty again before doing anything else with that worktree.
- **A stored acceptance line piped through `grep -q` can fail with `[exit 141]` (SIGPIPE) on a
  correct, passing check — not a real rejection.** `accept.sh` runs each line under
  `bash -o pipefail -c`; `grep -q` exits the instant it finds its first match and SIGPIPEs the
  still-writing producer (`git log --oneline main | grep -q <sha>`), and `pipefail` turns that
  SIGPIPE into a nonzero exit even though the match was real. Symptom: `rejected <id> (attempt N):
  new failure` with the failing line ending in `grep -q ...` and `[exit 141]`, while running the
  identical line manually (outside pipefail) clearly passes. Fix: drop `-q` and redirect instead —
  `grep <pattern> > /dev/null` (or `grep -c <pattern> >/dev/null` if you need "at least one match"
  semantics) — never `grep -q` on the read side of a pipe inside stored acceptance. Verify the fix
  with `bash -o pipefail -c "<line>"` before re-storing, the same discipline as any other stored
  acceptance change.
- **Before firing a new background `accept.sh <id>`, check whether one is already queued for that
  same bead — duplicates just add contention, they do not speed anything up.** `accept.sh`
  self-serializes on one lock, so re-dispatching the same bead because an earlier call "seemed
  slow" or timed out in your own wait loop stacks a second, third, fourth instance behind the
  first, all fighting for the same lock and the same shared build/game-launch resources once each
  gets its turn — observed growing an accept queue past 30 concurrent processes this way, which
  made every single accept (including brand-new, unrelated beads) take 15-40+ minutes just to reach
  the front. Check first: `ps -ef | grep "accept.sh <id>" | grep -v grep`; only dispatch a new one
 if that returns nothing. A `could not take ... lock` or `[exit 1]` from your OWN prior attempt
 timing out in a wait loop does not mean the bead's accept died — it usually means a queued
 duplicate is still working through the backlog; check `bd show <id> --json` status and the queue
 before assuming you need to retry.
 **Duplicates survive a context compaction, because the compacted summary drops which
 background PIDs you already have in flight — sweep for them explicitly right after a
 compaction, not just before each new dispatch.** A session that compacts mid-run loses its own
 memory of "I already queued accept.sh for oo-x", so the first few turns after resuming can
 re-dispatch beads that already had 1-3 instances queued from before the compaction, silently
 doubling queue depth with zero new work. Right after noticing a queue-depth plateau (closed
 count flat for several turns while queue depth stays high), run
 `ps -ef | grep accept.sh | grep -v grep | grep -oE "accept\.sh [a-z0-9.-]+" | sort | uniq -c |
 sort -rn` once and kill every extra instance beyond the oldest PID per bead
 (`kill -9 <pid>`) before dispatching anything new — a wrapper+inner shell pair (2 processes) per
 bead is normal and not a duplicate; 3+ for one bead id is the real signal.
  **`beads-worker: accept: could not take ... lock` (or `accept: reclaiming ... lock left by dead
  accept pid 'unknown'`) is the internal `BEADS_ACCEPT_LOCK_WAIT` (default 1800s) simply expiring
  under sustained multi-session load, not a gate verdict on the bead.** Do not append it to the
  bead's notes as an acceptance failure and do not count it toward `stale_count` — it carries no
  information about the bead's code at all, only about how many sibling sessions are also
  accepting right now. Confirm the lock's current PID is live (`cat .beads-worker-accept.lock/pid`,
  `ps -W | grep <pid>`) and, if so, simply re-dispatch `accept.sh <id>` again in the background
  (after checking you don't already have one queued, per the bullet above) — it will queue again
  and eventually get its turn once contention eases; there is no need to sleep-poll the lock file
  yourself first.
- **`next-bead.sh` can hand you a bead another concurrent SESSION (not just another worker in
  yours) is already actively implementing — check the bead's own notes/timestamps before
  dispatching a duplicate worker.** `next-bead.sh` claims by bd status alone; it cannot see a
  sibling orchestrator's in-flight `delegate_task`. Before dispatching a worker for a freshly
  claimed bead, `bd show <id> --json` and look at the notes' most recent entry and its
  timestamp — an `attempt N worker:`/`review:` line from within the last few minutes to an hour
  means someone else is already working it live. Release the claim (`bd update <id> --status
  open`) instead of burning a worker round-trip that will just collide with theirs; re-claim it
  later if it's still open on a subsequent `next-bead.sh` call.
- **`tools/tier-a.sh`'s fixed wall-clock budget can fail a PASS-quality result under heavy
  concurrent box load — retry once with the budget bumped to isolate a load flake from a real
  regression before treating it as a rejection.** Symptom: `tier-a: PASS but Ns exceeds the Ns
  budget` on a file whose diff never touched anything timing-related, immediately after (or
  during) several other sessions' accepts/builds are running. Retry the same `accept.sh <id>` with
  `OOLITE_TIER_A_BUDGET=90` (or higher) exported alongside the usual `PATH`/`LOCALAPPDATA` — the
  var is read by `tools/tier-a.sh` and passed through by `accept.sh`'s `bash -o pipefail -c "$cmd"`
  execution. If it now passes cleanly with the same deny-list/warning counts as the failing runs,
  the budget overrun was load, not code; log it as a load flake in the bead's notes rather than a
  real rejection and do not count it toward `stale_count`.
- **A failing GUI acceptance line is not trusted until it fails ISOLATED too (bug oo-ac3f).**
  `tools/gui-lock` (the session-scoped `desktop_lock` fixture in
  `upstream/oolite/tests/gui/conftest.py`) already serialises every GUI-launching pytest run, so
  two GUI processes cannot fight over the desktop at the same instant — that collision is not the
  risk. The risk is a CONCURRENT NON-GUI sibling (another tier compiling, several pytest processes
  running at once) starving the CPU of whichever process holds the lock: the GUI tier's timeouts
  (`TRANSITION_TIMEOUT_SECONDS`, `ScreenWitness.accept(timeout=...)`, `gui_screen(timeout=...)`)
  are real wall-clock timers, so contention alone can flip a transition-timeout test from pass to
  fail with no code change at all. Observed in production: oo-6zd's acceptance line 6 returned
  rc=1 under contention with a sibling launching G5, then rc=0 seconds later run alone — same
  code, same tree, opposite verdicts. So: when a GUI-tier acceptance line (`accept.sh` runs
  anything under `upstream/oolite/tests/gui/`) returns nonzero, re-run it once with
  `tools/gui-acceptance-recheck "<line>"` before writing `accept attempt N failed` into the bead's
  notes or counting it toward `stale_count`. That script re-runs the line once the gui-lock is
  free and the sibling-load proxy is quiet (or a bounded wait elapses), and reports the gui-lock
  holder and a process-count proxy around both runs. If the recheck passes, the failure was
  contention, not a genuine regression: do not append it to notes as a failure and do not count it
  toward `BEADS_WORKER_STALE_REPEATS`; treat that acceptance round as needing a plain retry instead.
  If the recheck also fails, it is genuine — proceed exactly as `accept.sh` already does. This does
  NOT apply to non-GUI (unit/component) acceptance lines, and it does not replace fixing an
  actually-flaky GUI test (that is a bug in the test, e.g. oo-3opg, not a review-process step).
- **A `libtre-5.dll`/`libsystre-0.dll` (or any DLL) unresolved-imports failure inside
  `tests/golden/dump/test_launch_preflight.py` under `tier-b.sh --fast` is a shared-build-dir
  staging race, not a code defect — and the race can be a genuinely ORPHANED process, not just
  serialized contention.** The test hard-links whatever files currently exist in the ONE shared
  `APP_DIR` at the instant it runs; some dependency DLLs (e.g. `libtre-5.dll`) are staged as a
  side effect of `stage_mesa` copying files one at a time and are not in the test's own explicit
  dependency set, so a concurrent `tier-b.sh` mid-`stage_mesa` can be caught with one DLL copied
  and its dependency not yet copied. Before treating repeated identical failures here as a stale
  gate (5x -> escalate): `ps -ef | grep -iE "tier-b|pytest"` and, for each hit, check whether its
  PARENT pid is still alive (`kill -0 <ppid>`) — a `tier-b.sh`/pytest tree whose parent `accept.sh`
  already died (timed out, was killed, or exited) is NOT covered by `accept.sh`'s own lock
  discipline and can keep racing the shared build dir indefinitely; `kill -9` the orphaned tree.
  Retry after killing orphans and once `ps -ef | grep -c tier-b` drops; do not count these
  failures toward `stale_count` while sibling `tier-b`/`accept.sh` processes are still running.
- **Never dispatch a `delegate_task` worker for a code fix without first creating its
  bead+worktree, even for a one-line, clearly-correct, time-pressured infra fix.** A worker given
  no worktree path defaults to operating in the root checkout and will commit straight to `main`,
  bypassing bead tracking, review, and `accept.sh`'s merge-and-verify gate entirely — exactly the
  workflow this skill exists to enforce. If this happens and the fix is independently verified
  correct (clean build, no prohibited paths touched), leaving it on `main` is better than reverting
  and re-breaking everyone queued behind it, but log the mistake and do not repeat the shortcut:
  even an urgent, build-blocking fix gets a bead id, `worktree.sh`, and goes through
  review+`accept.sh` like everything else — the two extra tool calls are cheap next to a
  process-bypass precedent.
- **When the SAME failure signature (identical error text, not just the same class) recurs across
  MANY DIFFERENT beads' accept attempts, search `bd` for an existing bug bead tracking that exact
  signature before continuing per-bead retries — someone (a sibling session, an earlier turn) may
  already have filed and even started fixing the root cause.** `bd list --all --json | grep -i
  "<distinctive phrase from the failure>"` or a plain `bd list` scan; if a matching bead exists,
  claim it and dispatch a dedicated worker to root-cause and fix it (harness code, not `goldens/`
  or the test itself), rather than treating every instance as one-off infra noise to retry through
  forever. Fixing the shared root cause once unblocks every bead hitting it simultaneously, which
  is far cheaper than N beads each burning retry rounds against the same wall. Keep the affected
  beads' own accept retries going in parallel while the fix bead is in flight — do not block them
  waiting, since the retries are cheap and some may get lucky on timing before the fix lands.
- **A worker's fix that makes the ONE named failing test pass can silently break SIBLING tests
  that share the same constant/fixture for a different purpose — always re-run the FULL test file
  (or the full acceptance line) against a real build before trusting a fix, not just the test the
  bead was filed against.** A constant like a DLL/dependency set can be dual-purpose: used both as
  "the exact set an assertion checks against" (must stay a fixed, closed list) and as "the set of
  things to stage/copy for a fixture" (should grow to include transitive deps). Folding a new
  transitive dependency directly into the shared constant fixes the staging use but pollutes every
  assertion that expects the original, narrower set — a naive worker fix can go from 1 failing test
  to 2 newly-broken ones while claiming success. Independently re-run the whole test file (not the
  `-k`/single-node command the worker reports) with the real build (`OO_APP_DIR` set) before
  accepting a `committed: true` claim on any fix that touches a shared constant, fixture helper, or
  config value used in more than one place. If it breaks siblings, the correct fix is usually to
  split the constant in two (one for the assertion target, a separate one for the staging/fixture
  set) rather than widening the shared one — send it back with that specific direction rather than
  a generic "fix your regression".
- **A stored acceptance exemption keyed to specific LINE NUMBERS (e.g. "ignore JS_* hits on lines
  N1,N2,...") for a documented out-of-scope carve-out) goes stale the moment the file is edited
  again, even by a legitimate continuation round on the same bead.** Re-derive the exemption list
  from the CURRENT file (`grep -nE '<pattern>' <file> | cut -d: -f1`) every time before trusting or
  re-storing a line-number-based acceptance check, and prefer matching by the exempted SYMBOL NAMES
  (e.g. `JS_IsDebuggerFrame`, `JS_GetFrameScopeChain`) over line numbers when the carve-out is a
  fixed, documented set of calls — a name-based exclusion survives further edits to the file that a
  line-number one does not.
  **A line-number exclusion regex without a leading `^` anchor matches nowhere in `line:content`
  output and silently makes the whole acceptance line always-fail, even though it LOOKS like a
  correct exemption when read.** `grep -vE ':(41|42|...):'` matches the number anywhere
  (`content` text containing a colon-digit-colon substring), not just at the start of the
  `grep -n` line prefix; if the excluded numbers never happen to appear that way in the code, every
  original hit survives the `-v` filter and the negated acceptance line (`! grep ... | grep -v ...`)
  reports a false failure on a file that is actually clean. Always verify a stored exclusion
  pattern by running it exactly as `accept.sh` will (`bash -o pipefail -c "<line>"`) BOTH against
  the fixed file (must exit 0/no output) before storing — the visual "looks like it excludes the
  right numbers" read is not proof; a worker reported this line as passing without ever executing
  it, and it does not.
- **Calling a bead-tracker binary by its ABSOLUTE PATH (bypassing PATH resolution) also bypasses
  any PATH-based guard shim placed in front of it — this includes accidental status changes, not
  just deliberate closes.** The guard shim that refuses `bd close`/`bd update --status closed` only
  intercepts calls that resolve through PATH; invoking the real binary directly (needed on this box
  because the shim script itself can't be exec'd from some callers) means an innocuous-looking
  `bd update <id> --status closed` used to mark something "not worth tracking further" silently
  succeeds and actually closes the bead, with no refusal and no warning. Never issue `--status
  closed` this way for ANY reason, including "this is a duplicate" — a duplicate gets a note
  cross-referencing the real bead and stays open (or the human/owning process closes it through the
  proper channel); if you catch yourself doing this, `bd update <id> --status open` immediately to
  reopen and record the correction in notes.
- **A tier-b goldens-stage failure with the signature "N entities, fewer than the M minimum;
  a dump with no world in it compares equal to any other empty world" (golden_diff rc=2 REFUSED) on
  the `001-launch-dock` scenario is a known load-dependent determinism defect in the scenario
  itself, not a code regression — escalate after 2 occurrences across ANY bead, don't keep
  retrying.** Under heavy concurrent box load the launch/dock run can dump before the second entity
  ever spawns; `tests`/`parity` stages pass cleanly both before and after, confirming the bead's own
  diff is not at fault. The scenario's own guards don't assert the expected entity set, so a
  truncated run "refuses" instead of failing loudly — a real fix (assert the entity set, or
  decouple spawn timing from elapsed frames) touches `tests/`/`goldens/` and needs Jon's decision,
  so `reevaluate.sh` will correctly route it to `escalate`. Once one bead hits this signature and is
  escalated, escalate every sibling bead that hits the SAME signature directly (cite the first
  bead's escalation reason) rather than re-running `reevaluate.sh` per bead — it is the same root
  cause every time, not a new one.
- **The same underlying bug can get filed as more than one bead by concurrent sessions — before
  filing a new bead for something you just root-caused, `bd list --json` grep for its symptom
  string.** If a match with `fleet`/`phase:<N>` labels already exists (even freshly filed, even by
  a different session), claim and work THAT one instead of your own; close your duplicate only via
  the normal channel (never `--status closed` yourself — see above) by leaving it open with a note
  pointing at the real bead's id, so a human or `accept.sh`-driven process can retire it properly.
- **When you manually merge a bead's already-diverged merge commit into main yourself (see the
  dirty-checkout-fast-forward-failure bullet above), a SECOND `docs/fleet/LEARNINGS.md` (or other
  append-only log) conflict on the retry is common if another accept landed in between — resolve it
  the same way every time: `grep -n '^<<<<<<<\|^=======\|^>>>>>>>' <file>` to find the markers,
  confirm both sides are independent appended lines (not edits to the same line), delete just the
  three marker lines (`sed -i '<n1>d;<n2>d;<n3>d' <file>`, highest line number first if doing
  several by hand) to keep both sides' content, `git add` and `git commit --no-edit`. Do not try to
  pick a "winning" side on an append-only log — both sessions' entries are real and belong.
  **After a manual merge like this, `bead/<id>`'s branch can end up with ZERO commits beyond main
  once the merge is folded in** — `accept.sh` then rejects with "bead/<id> has no commits beyond
  main" even though the bead's actual fix IS on main (verify with `git log --oneline main | grep
  <the fix's known commit sha>`). This is not a real rejection: the code landed, there's just
  nothing left on the branch to formally re-merge. Fix by adding one trivial commit to the branch
  (e.g. append a one-line confirmation note to `docs/fleet/LEARNINGS.md` in the worktree) so
  `accept.sh` has something to merge, then retry — it will pass acceptance quickly (the fix is
  already compiled into main) and formally close the bead.
- **Once a systemic root-cause bug bead (the kind filed after "escalate every sibling bead hitting
  the SAME signature" above) lands on main, actively sweep for beads that were escalated for that
  exact signature and un-stick them — do not leave them sitting in `escalated`/`frontier` waiting
  to be noticed.** `bd list --all --json` for beads with `escalated` whose notes mention the fixed
  signature (or whose worktree still exists with real uncommitted/committed work from before the
  escalation); if the bead's actual implementation work is intact and unrelated to the now-fixed
  systemic bug, `bd update <id> --claim --actor "<name>"`, note that the blocking flake is fixed
  (cite the fix's bead id and merge commit), and re-queue `accept.sh` rather than treating
  `escalated` as a terminal state. A parallel session's escalations for the same root cause you
  just fixed are exactly the highest-value beads to reclaim next — they already have the retry
  history and often just need the now-passing gate to confirm.

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
