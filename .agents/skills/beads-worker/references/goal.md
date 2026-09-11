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

Then, in the same session:

```
/goal gate add .agents/skills/beads-worker/scripts/goal-gate.sh 3
```

Check with `/goal show` (contract) and `/goal gate` (gate state). `/goal status` shows turns used.
