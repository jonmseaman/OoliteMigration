# Reviewer task template

Advisory only. The verdict never gates acceptance; `request_changes` earns at most one more worker
round. Pass as `delegate_task(tasks=[{goal, context, output_schema}])`.

## goal

Review the change for bead {id} — "{title}" — on branch bead/{id} in the worktree at
{worktree_path}. Run `git diff main...bead/{id}` there and judge it against the story and the
rules below. Do not edit anything. Return a verdict and concrete findings with file:line.

## context

The story:

{bead_body}

Exemplar the change must match in style: {exemplar_path}. Read it first.

Bead notes and fleet learnings (previous attempts may explain why the change looks the way it does):

{context_sh_output}

Check, in this order, and report each as a finding if violated:
1. Prohibitions: any change under goldens/, any test modified or deleted, any new -Wno-* or
   #pragma diagnostic, any file outside the story's file list, any C rewritten that was already C.
2. Fidelity: behaviour-preserving translation only; no redesign, no "improvements", `oo::Ref<T>`
   not `shared_ptr`, `isKindOfClass:` sites converted deliberately not blindly.
3. Style drift from the exemplar: naming, header layout, error handling shape.
4. Sizing: reads ≤ ~1,500 lines, writes ≤ ~400 lines, ≤ 8 files.
5. Acceptance: the acceptance commands are plausible to pass; the diff does not game them.

Be specific. A finding without a file and line is not a finding.

## output_schema

```json
{
  "type": "object",
  "required": ["verdict", "findings"],
  "properties": {
    "verdict": {"type": "string", "enum": ["approve", "request_changes"]},
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["file", "line", "rule", "detail"],
        "properties": {
          "file": {"type": "string"},
          "line": {"type": "integer"},
          "rule": {"type": "string"},
          "detail": {"type": "string"}
        }
      }
    }
  }
}
```
