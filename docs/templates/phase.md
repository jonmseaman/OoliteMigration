# Phase N — <name>

**Status:** not started | in progress | done · **Est.:** N–M eng-months · **Depends on:** <phases / infra items>
**Runs in parallel with:** <phase or —>

## Goal

Two or three sentences. What is true when this phase is done that was not true before.

## Entry gate

- [ ] Each item is a phase or infra exit criterion, linked.

## Exit gate

- [ ] Each item is a **command that exits nonzero before and zero after**, where at all possible.
- [ ] Items that are human judgement say so explicitly and name who judges.

## Seams (human / frontier work)

The design decisions that must exist before any sweep can start. Each one fails checks 5 and 7 of
the [sizing rule](../workflow.md#a-unit-of-work-a-bead). Name the exemplar path each
seam produces.

| Seam | Produces (exemplar path) | Owner |
|---|---|---|

## Sweeps (fleet work)

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|

One bead per unit, written from the inventory using [templates/story.md](story.md).

## Work items

Numbered `N.1`, `N.2`, … in dependency order. Each is a seam, a sweep, or a one-off.

## Commands

The build and test commands for this phase's work ([workflow.md](../workflow.md)).

## Decisions

Decisions this phase takes, each with its default and the reason, dated. There is no separate ADR
folder.

## Status log

Append-only, dated. What changed, what was learned, what the fleet could not do and a human did.
