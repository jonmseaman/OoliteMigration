# ADR-0001: Bridge, then convert (strangler pattern)

**Status:** Accepted · **Date:** 2026-09-05

## Context

Two ways to get from Objective-C/GNUstep to C++23: a clean-room rewrite against the data formats, or
an in-place conversion. The acceptance criteria are 225k LOC of undocumented gameplay behaviour and
1,591 published expansions that must keep working. The ObjC *runtime* is portable to all three
targets (Apple `libobjc` on arm64, GNUstep `libobjc2` on Windows/Linux); GNUstep's *Foundation* is
what blocks Apple Silicon.

## Decision

Compile the whole tree as Objective-C++. Introduce a C++23 Foundation replacement (`oofnd`) alongside
the existing classes, migrate usage sites onto it, delete `libgnustep-base`, reach Apple Silicon
with the game still in Objective-C (Phase 3), then convert classes to C++ module by module from the
leaves inward (Phase 4). The build is shippable at every commit.

Translate to *conservative* C++ first; modernise in Phase 6. Mixing translation and redesign is the
classic way these projects die.

## Consequences

- Getting to Apple Silicon (Phases 1–3) is decoupled from getting to C++23 (Phase 4+), and is
  worth doing even if Phase 4 never completes.
- Clang is required on all platforms until the last `.mm` is gone (only compiler with ObjC++
  everywhere). GCC returns in Phase 5.
- A rewrite would have been faster to a *nice* architecture and much slower to a *playable* one.

## History

Original reasoning: `MIGRATION_PLAN.md` §1 and §12.3 (git `ee2de41`). Now
[architecture.md §1](../architecture.md).
