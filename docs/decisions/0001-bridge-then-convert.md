# ADR-0001: Bridge, then convert (strangler pattern)

**Status:** Accepted; sequencing amended by [ADR-0009](0009-apple-silicon-after-runtime-removal.md), standard amended by [ADR-0011](0011-cpp20-then-cpp23.md) · **Date:** 2026-09-05

## Context

Two ways to get from Objective-C/GNUstep to modern C++: a clean-room rewrite against the data formats, or
an in-place conversion. The acceptance criteria are 225k LOC of undocumented gameplay behaviour and
1,591 published expansions that must keep working. The ObjC *runtime* is portable to all three
targets (Apple `libobjc` on arm64, GNUstep `libobjc2` on Windows/Linux); GNUstep's *Foundation* is
what blocks Apple Silicon.

## Decision

Compile the whole tree as Objective-C++. Introduce a C++ Foundation replacement (`oofnd`) alongside
the existing classes, migrate usage sites onto it, delete `libgnustep-base`, then convert classes to
C++ module by module from the leaves inward (Phase 3), remove the runtime (Phase 4), and only then
build for Apple Silicon (Phase 5; originally Phase 3, resequenced by ADR-0009). The build is
shippable at every commit.

Translate to *conservative* C++ first; modernise in Phase 6. Mixing translation and redesign is the
classic way these projects die.

## Consequences

- Getting to Apple Silicon is *technically* decoupled from getting to C++ (the runtime is
  portable), which is what makes the strangler pattern safe. ADR-0009 chooses not to exploit that
  for scheduling. Phases 0–2 are still worth doing even if Phase 3 never completes.
- Clang is required on all platforms until the last `.mm` is gone (only compiler with ObjC++
  everywhere). GCC returns in Phase 4.
- A rewrite would have been faster to a *nice* architecture and much slower to a *playable* one.

## History

Original reasoning: `MIGRATION_PLAN.md` §1 and §12.3 (git `ee2de41`). Now
[architecture.md §1](../architecture.md).
