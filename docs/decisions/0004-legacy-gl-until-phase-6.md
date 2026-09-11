# ADR-0004: Ship on OpenGL 2.1 compatibility profile through Phase 4

**Status:** Accepted · **Date:** 2026-09-05

## Context

Fixed-function and immediate mode throughout (380 `glVertex3f`, 21 files), GLSL 1.10/1.20 with no
`#version`. macOS still ships a legacy GL 2.1 compatibility context implemented over Metal, and it
works on Apple Silicon (VAOs via `APPLE_vertex_array_object`). It is deprecated.

## Decision

The existing renderer runs on Apple Silicon essentially unmodified. Do not let renderer
modernisation become Phase 1's or Phase 5's problem. Modernise in Phase 6, in preference order:
GL 3.3 Core, SDL3 GPU, ANGLE.

## Consequences

- The Apple Silicon build (Phase 5) inherits a renderer that runs on macOS's legacy context
  unmodified, so the port is a platform layer, not a renderer rewrite.
- Risk, **increased by ADR-0009**: Apple removes legacy GL before Phase 5, now ~22–42
  engineer-months out rather than 9–16. Mitigation: the renderer target decision (roadmap open
  decision 5) is made before Phase 4 ends, and the Phase 6 renderer work is pulled forward ahead of
  Phase 5 if the legacy context disappears first. Phase 5's entry gate checks this explicitly.
- Mesa `llvmpipe` under Xvfb is sufficient for CI golden runs; no GPU needed.

## History

`MIGRATION_PLAN.md` §4/R4. Now [architecture.md §4](../architecture.md).
