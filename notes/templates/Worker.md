---
machine:
state: idle
roles:
  - worker
capabilities: []
card:
step:
since: "{{date}}T{{time}}:00"
agent_version:
oar_version:
paused: false
---
# {{title}}

One lane: a fixed checkout on one machine. The note's name is the lane's name, which cards put in
`worker` (or `reviewer`, `planner`) to assign it.

`oar init` writes one of these per lane in `machine.yaml`, and the lane's runner keeps every field
up to date except `paused`. Use this template only to add a lane by hand before `oar init` runs.

| Field | Written by | Meaning |
|---|---|---|
| `machine` | oar | the machine's `name` from `machine.yaml` |
| `state` | oar | idle, working, paused, error, or login (its agent needs a fresh login) |
| `roles` | oar | worker, reviewer, planner: the cards this lane may take |
| `capabilities` | oar | matched against a card's `requires` |
| `card`, `step` | oar | what it is working on now |
| `since` | oar | when `state` last changed |
| `agent_version`, `oar_version` | oar | so version skew across machines shows in the Lanes view |
| `paused` | you | `true` stops the lane after its current step |

## Log
