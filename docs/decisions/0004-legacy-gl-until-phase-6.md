# ADR-0004: Ship on OpenGL 2.1 compatibility profile through Phase 5

**Status:** Accepted · **Date:** 2026-09-05

## Context

Fixed-function and immediate mode throughout (380 `glVertex3f`, 21 files), GLSL 1.10/1.20 with no
`#version`. macOS still ships a legacy GL 2.1 compatibility context implemented over Metal, and it
works on Apple Silicon (VAOs via `APPLE_vertex_array_object`). It is deprecated.

## Decision

The existing renderer runs on Apple Silicon essentially unmodified. Do not let renderer
modernisation become Phase 1's or Phase 3's problem. Modernise in Phase 6, in preference order:
GL 3.3 Core, SDL3 GPU, ANGLE.

## Consequences

- The Apple Silicon milestone stays realistic at 9–16 engineer-months.
- Risk: Apple removes legacy GL before Phase 6. Mitigation: the renderer target decision (roadmap
  open decision 5) must be made before Phase 5 ends, not after.
- Mesa `llvmpipe` under Xvfb is sufficient for CI golden runs; no GPU needed.

## History

`MIGRATION_PLAN.md` §4/R4. Now [architecture.md §4](../architecture.md).
