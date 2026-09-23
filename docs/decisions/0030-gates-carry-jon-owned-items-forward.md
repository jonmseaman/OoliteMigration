# ADR-0030 — A phase review and gate carry Jon-owned items forward instead of waiting on them

**Status:** Proposed — default in effect (Claude Code, Opus orchestrator, 2026-09-23; ADR-0013).
Jon may override.
**Date:** 2026-09-23
**Amends** the acceptance of every phase review bead (`seam:N.review`, e.g. oo-iizf) and the
walking of every exit gate (`seam:N.gate`, e.g. oo-5pr).

## Context

A review bead closes only when `bd list --label phase:N --status open,in_progress` returns
nothing but the review and gate beads themselves. The next phase's first seam depends on the
gate, and the gate depends on the review. So one open bead anywhere in the phase stops every
later phase.

At the end of Phase 1, all the fleet-workable beads are closed. The ones still open are work
only Jon may do:

- **Test or golden changes (CLAUDE.md rules 1 and 2).**
  - oo-7j3t: golden-tier and GUI tests open `.m` sources that are now `.mm`.
  - oo-xa5h: a stale canary in `tools/js_api_reconcile.py`.
- **Adjudications (rule 7).**
  - oo-sjvz: flaky component scenarios. Jon's instruction was to leave them and retry.
  - oo-1gc.7: a Tier-1 corpus group red on both engines. Its triage options are "fix the
    closure" (not applicable; the keys exist in core) or "record a known content failure",
    which changes what a test accepts.
- **The phase epic itself** (oo-1gc), which by design closes after its gate.

Rule 10 says never wait for Jon. As written, the review can only close after Jon acts, and so
Phases 2 to 4 would wait on him too.

## Decision

1. **A review's "nothing left" query ignores three kinds of bead:**
   - beads labelled `human`, which means awaiting Jon: a test, golden or adjudication decision;
   - the phase epic (`issue_type` epic);
   - the review and gate beads themselves.

   Everything else must be closed, as before.
2. **A bead whose only remaining step is Jon's** (a test, golden or re-bless change, or an
   adjudication under rule 7) gets the `human` label and a note saying exactly what is needed. It
   stays open and stays Jon's. The label is added by an orchestrator, never by the bead's
   implementer.
3. **The gate walk marks each box one of two ways:**
   - **checked**, with evidence; or
   - **carried**, naming the `human` bead or the unblessed goldens that stand between the box and
     done, with the evidence for everything short of that.

   A gate whose boxes are all checked or carried passes, and the next phase may start. The status
   log lists every carried item.
4. **Goldens:** "all N goldens reproduce" is checked for every blessed golden. Staged and pending
   goldens are carried until Jon blesses them (rule 1). The gate never blesses them.

## Consequences

- Later phases proceed on the fleet's schedule. The carried items stay visible, on the gate, in
  `bd list --label human`, and in the final report, and they do not disappear.
- A carried item can hide a real regression that surfaces later. This is bounded: each carried
  item has already been diagnosed, and the diagnosis is in its notes.
- If Jon overrides, the review beads get their old acceptance back. The later phases' work is
  unaffected, because nothing in it depended on the carried items.

## History

- 2026-09-23 — Proposed by the orchestrator when Phase 1's review (oo-iizf) could not close with
  four Jon-owned beads open.
