# ADR-0009: Apple Silicon is Phase 5, after the Objective-C runtime is removed

**Status:** Accepted · **Date:** 2026-09-10 · **Amends:** [ADR-0001](0001-bridge-then-convert.md)

## Context

The original sequence exploited the portability of the Objective-C runtime to reach Apple Silicon
at Phase 3, with the game still written in Objective-C, before the ~500-file conversion. That put
the first macOS build at roughly 9–16 engineer-months and made Phases 0–3 a self-contained payoff.

Jon's decision (2026-09-10): do the macOS port after the conversion and the runtime removal.

## Decision

New order: 0 safety net → 1 JS engine ∥ 2 `oofnd` → 3 ObjC → C++20 conversion → 4 remove the
Objective-C runtime → **5 Apple Silicon** → 6 modernise.

## Consequences

- **The macOS build never contains Objective-C.** No `libobjc`, no Objective-C++, no Apple
  Foundation, no Xcode-specific toolchain concerns; the port is SDL3 + a Meson branch + bundle
  packaging on a plain C++20 codebase. Phase 5 gets simpler and its scope is now honest.
- **The first macOS build arrives at ~22–42 engineer-months** instead of 9–16. Phases 0–2 are
  still independently valuable (maintained JS engine, no GNUstep, upstreamable); the macOS payoff
  is no longer an early hedge against the conversion stalling.
- **Legacy OpenGL risk grows** ([ADR-0004](0004-legacy-gl-until-phase-6.md)): Apple has a longer
  window in which to remove the 2.1 compatibility context before Phase 5 exists. Phase 5's entry
  gate checks for it; if it is gone, the Phase 6 renderer work moves ahead of Phase 5.
- **Everything through Phase 4 is x86-64 only**, which is what makes
  [ADR-0010](0010-single-windows-machine.md) (one machine) possible. arm64-specific bugs and the
  cross-platform golden policy (open decision 11) are all first exercised in Phase 5, so the golden
  storage format must still be chosen at the first bless.
- Talking to upstream moves to Phase 5 with the build in hand ([architecture §6.3](../architecture.md)).
- The GUI tier ([0-gui-tier.md](../phases/0-gui-tier.md)) still becomes load-bearing at the macOS
  phase; the macOS runner decision (open decision 8) is due before Phase 5 rather than Phase 3.

## History

Supersedes the sequencing in `MIGRATION_PLAN.md` §8 / §11 (git `ee2de41`) and the 2026-09-06 phase
docs. The technical decoupling argument in ADR-0001 is unchanged; only its use for scheduling is.
