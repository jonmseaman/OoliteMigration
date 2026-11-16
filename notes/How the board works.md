# How the board works

One note in `tasks/` is one **card**: one piece of work, on one branch, merged as one unit.
Cards are sized to one review sitting.

## Statuses

| Status      | Meaning                                                                         |
| ----------- | ------------------------------------------------------------------------------- |
| New         | Not ready. Lanes ignore it, except a planner lane named in `planner`.           |
| Ready       | A worker may take it once `worker` is set.                                      |
| In Progress | A worker holds it.                                                              |
| Review      | Finished and past the gate; waiting for a reviewer.                             |
| Blocked     | Waiting for you; `needs` says what.                                             |
| Done        | Merged. `done_at` records when; done cards drop out of most views after 7 days. |

`needs` values: `spec`, `plan`, `tasks`, `review`, `merge`, `decision`, `failure`, `login`.

Your moves: New → Ready (approve), Blocked → Ready (carry on), Blocked → Done (after you merge),
any card → New (park it). Dragging a card to another column of the **Workers** view hands it to
that lane.

## Fields

| Field                                    | Who writes it          | Meaning                                                      |
| ---------------------------------------- | ---------------------- | ------------------------------------------------------------ |
| `worker`, `reviewer`, `planner`          | you or the planner     | lane name, `any`, or empty                                   |
| `order`                                  | you or the planner     | lower goes first in a lane's queue                           |
| `repo`, `branch`                         | the planner            | the card's one branch; its parent is in `<repo>-branches.md` |
| `after`                                  | the planner            | cards that must be Done first                                |
| `requires`                               | the planner            | capabilities a lane must have (for example `asan`)           |
| `model`, `effort`                        | you                    | override the role's default                                  |
| `status`, `needs`, `progress`, `done_at` | `oar` (and your drags) | see above                                                    |
| `pr`                                     | the reviewer or you    | the pull request                                             |
| `speckit`, `spec`                        | `oar`                  | Spec Kit stage and spec number (Spec Kit cards only)         |

## Steps

Each `- [ ]` line under `## Steps` is one step: one fresh agent session, ending in commits on the
card's branch. A step's `check:` command must fail before the step and pass after it.

- `- [x]` is done; `oar` adds the commit.
- `- [-]` is cancelled: `oar` skips it. `Mod+1` cycles Todo → Done → Cancelled.
- `review: <kind>` after a step stops the card at Blocked with `needs: <kind>`.
- `role: planner` runs a step with the planner's instructions and model.

Answer a worker's questions, or note what you want changed, under `## Notes for the worker`. The
next step's prompt includes that section.

## Roles

- **Planner** turns requests into cards. It moves a card to Ready only when you say so.
- **Worker** works a card's steps on its branch. It never pushes; `oar` does.
- **Reviewer** reviews Review cards as `.oar/reviewer.md` says, and prepares the pull request.

## Lanes

Each lane is a fixed checkout on one machine. `workers/<lane>.md` shows what it is doing: its
`state` (idle, working, paused, error or login), current card and step, and a log. `oar` keeps it
up to date. Set `paused: true` there to stop that lane after its current step. The **Lanes** view
lists every lane, flags one that has been working for over 4 hours, and shows version skew.

`oar init` writes these notes from `machine.yaml`. To add a lane by hand, create
`workers/<lane>.md` and insert the *Worker* template.
