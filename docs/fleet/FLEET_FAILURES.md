# Fleet failures

The research log ([I4](../infra/4-metrics.md)): every bead the fleet could not finish and handed
to the frontier tier. Appended by `scripts/escalate.sh`; a human adds the "what it needed" column
when the bead is eventually done. This is the document that answers the question the project was
started to answer: how far did AI get, and where did it stop.

| Date | Bead | Phase | Attempts | Reason | What it needed (filled in later) |
|---|---|---|---|---|---|
| 2026-09-19 | oo-phi | 0 | 0 | claude: oo-phi is a frontier-labeled seam that a fleet worker should never have been dispatched; its dependency on the oo-do10 Phase 0 review is correct ordering (the gate must not check boxes against evidence the review has not yet re-verified), review beads already do not block fleet drain per goal-check.sh, and oo-phi's acceptance is a placeholder 'exit 1' that only a frontier agent may replace. | |
| 2026-09-19 | oo-hq8 | 0 | 0 | claude: The dependency on oo-e7c is correct and in fact insufficient: oo-hq8's definition of done requires a generated Phase 1 js-retarget bead to be closed by accept.sh, which cannot exist until the JSEngine façade (1.1), its exemplar retarget (1.1x) and the refactor scripts (1.2) land, so it cannot be rescoped into Phase 0 — and it is a frontier bead with a non-executable acceptance block that no fleet worker should hold. | |
