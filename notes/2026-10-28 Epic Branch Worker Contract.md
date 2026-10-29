# Worker contract: one branch per epic, merged locally (draft v2, for review)

Jon, 2026-10-28: one branch per epic; no guards ("I review all the changes eventually"); no pushing ("merging locally and me manually pushing is fine"); each bead is its own commit; no drift handling ("I'm doing all the work on this machine"). This draft changes the beads-worker skill (`.claude/skills/beads-worker/`), `CLAUDE.md`, `docs/workflow.md` and `.claude/settings.json` so the two idiom epics ([[2026-10-28 Idiom Epics and Beads Outline]]) can run that way. **Implemented 2026-10-28, uncommitted, for Jon's review** (see `git diff` in the planning repo). Tested against a scratch repo and a scratch beads database: 40 checks pass (epic branch creation, dependency on a `committed` bead, one commit per bead with `Co-Authored-By` kept, `epic-finish.sh` refusing and passing, `land.sh` after a merge commit and after a cherry-pick/rebase-style merge, blocker-first closing, `park.sh` reverting, a bead without an epic). Not run against the real beads database or a real epic. Written against `HEAD` (`bd7a4392d`) plus the sizing edits (caps dropped; `accept_budget` in `accept.sh`).

## 1. What changes

| | Today | Proposed |
|---|---|---|
| Branch | `branch.sh` runs `git town append feature/MMDD-slug` per bead | one `epic/<slug>` per epic, created once from `develop` with plain `git checkout -b`; every bead commits onto it |
| Commits | any number on a bead branch | **exactly one commit per bead**, `<id>: <title>`; `accept.sh` squashes the bead's own unpublished commits into it after the gate passes |
| End of a tick | `accept.sh` passes → `git town propose` → `proposed` | `accept.sh` passes → squash → label `committed`. No push, no PR |
| Finishing an epic | PR per bead | `epic-finish.sh` runs the end gate when the queue is drained and labels the epic `ready-to-merge`. **Jon merges the branch into `develop` locally and pushes** |
| Bead closes | `land.sh`: the bead's PR is `MERGED` on GitHub | `land.sh`: the epic branch is merged into `develop` in the local `oolite-dev` clone; it closes the epic and every `committed` child |
| Dependencies | blocker must be `closed` | a blocker also counts as satisfied when `committed` on the same epic branch |
| Guard | `tools/guard` shims, asserted by `preflight.sh` | removed. Rule 3 rests on the `settings.json` deny list and on `land.sh` being the only script that closes beads |
| Remote tooling | `git town`, `gh` | not needed by the worker at all |
| Workers | many | one worker per epic branch |

Unchanged: one bead per tick; the agent never closes a bead; acceptance commands fail before and pass after; the bead's notes carry state between ticks; `park.sh` for beads that cannot finish; `design`-labelled beads are interactive and skipped by the loop.

## 2. States

```
child bead:  open → in_progress → [label committed] ─────────────→ closed
                  ↑ accept.sh fails: stays in_progress,               ↑ land.sh, when epic/<slug> is merged into develop
                    failure appended to notes
epic bead:   open → [label ready-to-merge] ──────────────────────→ closed (land.sh)
```

Metadata: child `base_commit` (HEAD when claimed), `dev_commit` (the bead's one commit after the squash), plus the existing `attempts`, `last_failure_sig`, `stale_count`, and optional `accept_budget`; epic `branch` (`epic/<slug>`), `finished_at`. Children are tied to the epic by `bd`'s `parent` field (`bd create --parent <epic>`; `bd show --json` returns `.parent` and `.dependencies[].dependency_type`).

## 3. Script changes

| File | Change |
|---|---|
| `_lib.sh` | Add `epic_of <id>` (`.parent`), `epic_branch <epic>` (`.metadata.branch`, else `epic/<slug>` from the title), `is_committed <id>`, `epic_merged <branch>` (see `land.sh`). Remove `_unguarded_path`/`real_bd`/`real_git` indirection if nothing else needs it (they only strip `tools/guard` from `PATH`; keep the names as thin wrappers to avoid editing every caller). Add `design` to the default `BEADS_WORKER_EXCLUDE` (`rebless proposed-adr design`). |
| `branch.sh <id>` | Ensure `epic/<slug>` exists (create once from `develop`, record `metadata.branch` on the epic), check it out, record `base_commit=HEAD` on the child. Re-running for a retried bead is a no-op. |
| `next-bead.sh` | Never return an epic bead. Replace `--ready` with a local test: for each candidate from `bd list --status open,in_progress`, `bd show --json` it and keep it only if every `dependencies[]` entry with `dependency_type == "blocks"` is `closed` or labelled `committed` (`bd list --json` has no dependency fields, so this is one `bd show` per candidate; stop at the first match). `committed` beads are not actionable. Parent-child links never block. |
| `accept.sh <id>` | *(budget done)* Check the branch is the child's epic branch. "Nothing committed" = `rev-list base_commit..HEAD` is empty. Acceptance block, budget, failure signature and stale counting unchanged. **On pass:** `git reset --soft base_commit && git commit -m "<id>: <title>"` (this only rewrites the bead's own unpublished commits), label `committed`, record `dev_commit`. Remove all of the `git town propose` / `gh` / `metadata.pr` / `git push` logic. |
| `park.sh <id> "<why>"` | Before releasing the claim, `git revert --no-edit base_commit..HEAD` so a parked bead's half-finished commits do not break later beads. Never resets or rewrites. |
| `queue-check.sh` | Report `committed` beads as "done on the epic branch". When nothing is actionable, print `run epic-finish.sh <epic>`. |
| **`epic-finish.sh <epic>`** (new) | See §4. |
| `land.sh` | Loop over epics labelled `ready-to-merge`; see §4. |
| `preflight.sh` | Remove the guard-shim assertion, the `git-town` config and the `gh auth` check (and `need gh git-town`). Keep: database answers, `oolite-dev` clean. Add: report the current epic branch if there is one. |
| `guard-probe.sh`, `guard-probe-git.sh` | Delete. |
| `.claude/settings.json` | Remove the two `guard-probe*.sh` allow rules; add `Bash(bash .claude/skills/beads-worker/scripts/epic-finish.sh:*)`. Keep the deny list (`bd close`, `git push`, `gh pr create`, `gh pr merge`). |

## 4. `epic-finish.sh` and `land.sh`

`epic-finish.sh <epic>` (run by the loop; exit 0 means ready to merge):
1. Refuse unless no child is actionable or `in_progress`, `oolite-dev` is clean, and the current branch is the epic's. `human`-parked children are listed, not blocking.
2. End gate in `oolite-dev`: `./mk.sh build test`, `tests/run.sh unit`, `component`, `smoke`, `gui`. A failure is appended to the epic's notes and the script exits 1 so a fix bead can be opened.
3. Label the epic `ready-to-merge`, record `finished_at`, and print the commands for Jon:
   ```bash
   git -C oolite-dev checkout develop
   git -C oolite-dev merge --no-ff epic/<slug>      # or: git rebase develop epic/<slug> && git merge --ff-only
   git -C oolite-dev push origin develop
   ```
   Nothing is merged or pushed by the script.

`land.sh` (run at the start of a tick):
```
for epic in beads labelled ready-to-merge:
  branch = metadata.branch
  merged if  git merge-base --is-ancestor <branch> develop            # merge commit or fast-forward
          or git cherry develop <branch> | no line starts with '+'     # rebase-and-merge (patch-equivalent commits)
  merged   → bd close every child labelled committed (reason: "accepted: <branch> merged into develop at <sha>"), then the epic
  not yet  → print "epic/<slug> ready; not merged into develop"
```
A squash merge is not detectable this way; Jon closes those beads himself with `bd close` from his own shell (the deny list stops only the agent).

## 5. Rule and doc edits

`CLAUDE.md` (current numbering):
- **Rule 3:** "The agent that implemented a bead never closes it. Never run `bd close`; the `settings.json` deny list refuses it. A bead closes only when Jon has merged its epic's branch into `develop`; `land.sh` reads that from `oolite-dev` and is the only script that closes beads. The beads block below is generic guidance and this rule wins."
- **Rule 4:** "**Never push, and never touch `develop`, `master` or `main`.** Work reaches `develop` when Jon merges the epic's branch (`epic/…`) locally and pushes it himself. Commit everything before you finish a tick; uncommitted work in `oolite-dev` stops the next tick dead."
- **Rule 10:** "on the bead's own branch" → "on the epic's branch".
- **How work is shaped:** the sentence "Ownership is `oo::Ref<T>`, not `shared_ptr`; no redesign unless the bead asks for it" stays, but Epic B's `Ref` beads are exactly such beads; add "unless the bead says otherwise."
- **Runtime paragraph:** "claim it, commit it on the epic's branch in `oolite-dev`, pass its acceptance commands (it becomes `committed`, one commit per bead). When the epic's queue drains, `epic-finish.sh` runs the end gate; Jon merges the branch locally, and that closes every bead in it. One worker per epic branch."

`docs/workflow.md` "Done, for one bead": item 5 becomes "The bead is one commit on its epic's branch (`committed`). It closes when Jon merges that branch into `develop`." "Repo mechanics": replace "Branch in `oolite-dev` with `git town append`; push only that feature branch." with "Work on the epic's branch in `oolite-dev`; the worker never pushes."

`.claude/skills/beads-worker/SKILL.md`: replace the tick diagram and steps 6 and 8, the opening paragraph ("opens a pull request for Jon to review" in the front-matter description, `git town`, `pull request`), and "Phase end" (add an "Epic end" step list from §4; the existing `develop → master` pull-request step at a phase boundary is unchanged and is still Jon's). `references/pitfalls.md:32` (the guard-shim line) goes.

## 6. Verification once implemented

- A throwaway `oolite-dev` clone and a scratch beads database with an epic of two beads, the second blocked by the first: tick 1 produces one commit and `committed`; tick 2 gets bead 2 without bead 1 being closed; `epic-finish.sh` refuses while a child is `in_progress`, passes the gate when drained, and labels `ready-to-merge` without pushing; `land.sh` closes nothing until `epic/<slug>` is merged, then closes both children and the epic; also check the `git cherry` path with a rebase-merge.
- `park.sh` on a bead with two commits leaves two revert commits and a building tree.
- `accept.sh` leaves exactly one commit for a bead that took three attempts.
- `preflight.sh` passes with no `tools/guard`, no `gh` and no `git-town` installed.
