# The /goal to paste

Replace `3` with the phase number in all four places. Paste the block as one message; the
`field:` lines become the completion contract.

```
/goal Drain the beads queue for phase 3 using the beads-worker skill: for every open bead labelled fleet and phase:3, delegate a worker, delegate a reviewer, run scripts/accept.sh, and repeat until none remain.
verify: .agents/skills/beads-worker/scripts/goal-check.sh 3 exits 0, and its output is quoted at the end of the final turn
constraints: never run bd close yourself; never touch goldens/, tests, or warning flags; never work on frontier, rebless or proposed-adr beads; never push
boundaries: the repository root and .worktrees/<bead> checkouts only; bd, git and the beads-worker scripts
stop when: three consecutive turns produce no closed bead, no escalation and no new acceptance failure, or a bead is blocked on a decision that has no default
```

When the session's model is the frontier model and it should take the Phase 0 seams as well, start
Hermes with `BEADS_WORKER_LABELS="fleet frontier"` exported and paste this instead (the scripts read
the variable; the contract names both labels):

```
/goal Drain the beads queue for phase 0 using the beads-worker skill: for every open bead labelled phase:0 and either fleet or frontier, delegate a worker, delegate a reviewer, run scripts/accept.sh, and repeat until none remain. A frontier bead's acceptance is prose plus exit 1: its worker must replace it with executable commands via bd update <id> --acceptance before accept.
verify: .agents/skills/beads-worker/scripts/goal-check.sh 0 exits 0, and its output is quoted at the end of the final turn
constraints: never run bd close yourself; never touch goldens/, tests, or warning flags; never work on review, rebless, proposed-adr or escalated beads; never push
boundaries: the repository root and .worktrees/<bead> checkouts only; bd, git and the beads-worker scripts
stop when: three consecutive turns produce no closed bead, no escalation and no new acceptance failure, or a bead is blocked on a decision that has no default
```

Then, in the same session:

```
/goal gate add .agents/skills/beads-worker/scripts/goal-gate.sh 3
```

**On Windows the gate must be wrapped in the MSYS2 bash.** Hermes runs gates with Python's
`subprocess.run(shell=True)`, which is `cmd.exe` whatever shell Hermes was started from (the
terminal tool's `HERMES_GIT_BASH_PATH` does not apply to gates). A bare `.agents/...` gate fails
every attempt with `'.agents' is not recognized`, exhausts its 3 retries and pauses the goal
(2026-09-17, phase 0). Set the labels inside the wrapper too, because the gate does not inherit the
exports of the shell that launched a desktop-attached session:

```
/goal gate add C:\Users\jon\scoop\apps\msys2\current\usr\bin\bash.exe -lc "cd /c/Users/jon/OoliteMigration && MSYSTEM=UCRT64 BEADS_WORKER_LABELS='fleet frontier' .agents/skills/beads-worker/scripts/goal-gate.sh 3"
```

`/goal gate list` shows attempts and the last output tail; `/goal gate clear` removes a broken one;
`/goal resume` un-pauses after the gate is fixed.

Check with `/goal show` (contract) and `/goal gate` (gate state). `/goal status` shows turns used.
