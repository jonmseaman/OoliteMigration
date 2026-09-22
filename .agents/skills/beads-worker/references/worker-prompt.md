# Worker task template

Fill every `{…}`. Pass as `delegate_task(tasks=[{goal, context, output_schema}])`.

## goal

Implement bead {id} — "{title}" — in the git worktree at {worktree_path} on branch bead/{id}, then
commit. Do it the way {exemplar_path} does it. Make these acceptance commands exit 0 when run from
the worktree root:

{acceptance_commands}

## context

You are attempt {attempts} for this bead. Below are this bead's notes (previous attempts, what
failed, review findings) and the fleet's shared learnings from other beads. If a previous attempt
failed, do something different from it; if a learning applies, apply it.

{context_sh_output}

Repository rules (from CLAUDE.md, non-negotiable):
- Never modify anything under goldens/.
- Never modify or delete a test to make it pass. If a test is wrong, stop and report blocked.
- Never add -Wno-*, #pragma diagnostic, or unused-attributes to silence a warning.
- Never run `bd close` or change a bead's status; the orchestrator's accept step does that.
- Never push. Commit on branch bead/{id} only.
- Never rewrite code that already compiles as C; a file with no @implementation is not a target.
- Never read expansion (OXP/OXZ) content.
- If the task does not fit in ≤1,500 lines read / ≤400 lines written / ≤8 files, or needs an
  interface that does not exist and is not quoted below, stop and report blocked with the reason.

Bead body (the story):

{bead_body}

If this bead carries the `frontier` label, its acceptance block is prose: a `# DONE WHEN:` line and
an `exit 1` guard. Turning that prose into executable commands is part of the work. Before you
finish, write them with `bd update {id} --acceptance "<one command per line>"`; each must exit 0
from the repository root on the merged tree, and `accept.sh` runs that field, not the description.
A block that is only comments or `exit 1` is rejected.

**The acceptance block has a five-minute budget** (ADR-0021; `accept.sh` enforces
`BEADS_ACCEPT_BUDGET`, default 300 s, across the WHOLE block). It is the fast proof that the bead
is done: offline checks, at most one game launch, no loops, no `for i in 1 2 3`, no stability or
mutant sweeps. A block that runs out is rejected with the budget named; the fix is never to raise
the budget. Anything slower belongs in `tests/nightly/checks.txt` (one shell command per line, run
from the repository root by `tools/run-nightly-checks.sh` every night and at phase end): add your
slow proof there in the same commit, and keep a one-line fast proof in the acceptance block.

`accept.sh` runs EACH LINE of the stored acceptance as its OWN independent `bash -o pipefail -c`
invocation — shell state (variables, `cd`, `set -e`) does NOT carry from one line to the next. A
multi-statement script that sets a variable on one line and reads it on a later line (e.g.
`B="$TMPDIR/x"` then `mkdir -p "$B"`) will see `$B` empty on the second line and fail with a
confusing error. If your acceptance needs shared state across statements, join them into ONE
LOGICAL LINE with `;` or `&&` (not real newlines) before storing, and verify the joined line
passes under `bash -o pipefail -c "$CMD"` exactly as accept.sh will invoke it, before calling
`bd update --acceptance`.

Work only inside {worktree_path}. If the notes report a merge conflict from a previous attempt,
start with `git merge {base_branch}` in the worktree and resolve it. Run the acceptance commands
yourself before you finish. **Commit everything** with message "bead {id}: {title}" and confirm
with `git status --porcelain` printing nothing; the orchestrator merges the branch, not the
worktree, and work left uncommitted is committed for you with a note that you did not. Do not
touch files outside the story's file list. Do not create other branches or worktrees.

## output_schema

```json
{
  "type": "object",
  "required": ["summary", "files_changed", "commands_run", "committed", "blocked"],
  "properties": {
    "summary": {"type": "string"},
    "files_changed": {"type": "array", "items": {"type": "string"}},
    "commands_run": {"type": "array", "items": {"type": "string"}},
    "committed": {"type": "boolean"},
    "blocked": {"type": "boolean"},
    "blocked_reason": {"type": "string"}
  }
}
```
