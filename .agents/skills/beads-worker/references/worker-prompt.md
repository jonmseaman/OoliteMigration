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
