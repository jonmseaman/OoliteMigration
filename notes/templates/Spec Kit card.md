---
status: New
needs:
speckit:
spec:
worker:
reviewer:
order: 50
repo:
branch:
after: []
requires: []
model:
effort:
progress:
pr:
done_at:
tags:
  - speckit
---
## Feature
What the feature is for, in a few sentences. This becomes the `/speckit-specify` description.

## Steps
- [ ] Specify: `/speckit-specify` — check: `test -f "specs/$OAR_SPEC/spec.md"` — role: planner — review: spec
- [ ] Clarify: `/speckit-clarify` — check: `grep -q "## Clarifications" "specs/$OAR_SPEC/spec.md"` — role: planner
- [ ] Plan: `/speckit-plan` — check: `test -f "specs/$OAR_SPEC/plan.md"` — role: planner — review: plan
- [ ] Tasks: `/speckit-tasks`, then `/speckit-analyze` — check: `test -f "specs/$OAR_SPEC/tasks.md"` — review: tasks
- [ ] Implement: `/speckit-implement` — check: `false`

## Notes for the worker
Answers to clarify questions go here.

## Log
- {{date}} {{time}}: created
