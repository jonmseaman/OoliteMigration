---
paused: false
cooldown_until:
---
# Agent Board

Board-wide switches. `oar` reads this note on every poll.

- **`paused: true`** stops every lane from starting a new step. Running steps finish.
- **`cooldown_until`** is written by `oar` after a usage-limit error; lanes wait until then.

Open [[Agent Board.base]] for task progress and [[Spec Kit.base]] for spec progress.
[[How the board works]] explains the fields, statuses and roles.

To add work, create a note in `tasks/` and press `Alt+T` to insert a template:
*Card* for a small task, *Plan card* for a planned piece of work, *Spec Kit card* for a feature
that goes through specify, plan, tasks and implement.
