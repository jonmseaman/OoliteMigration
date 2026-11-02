# Phase 6 — Modernise

**Status:** not started · **Est.:** 4–10 eng-months · **Depends on:** [Phase 5](5-apple-silicon.md)

## Goal

Only now, with a pure C++20 codebase running on all three platforms and a working golden harness,
is it safe to make design changes. Low fan-out: these are design changes by definition.

The design the conversion landed on is reviewed against SOLID in
[6-solid-review.md](6-solid-review.md): four god objects (`Universe`, `Entity`, `ShipEntity`,
`PlayerEntity`) carry essentially every violation, and the Objective-C constraints that justified
them are gone. Its §8 is this phase's work list, with sizes and sequencing.

## Entry gate

- [ ] Phase 5 exit gate green

## Exit gate

Per sub-project; each is its own mini-phase with goldens as the gate:

- **C++23 upgrade** ([ADR-0011](../decisions/0011-cpp20-then-cpp23.md)): `-std=c++23` on all
  three toolchains at their pinned minimums; `oo::Expected` → `std::expected`; adopt `std::print`,
  deducing `this`, C++23 ranges adaptors per the architecture §3.2 table. Mechanical first, then
  idiomatic.

- Renderer → GL 3.3 Core (or SDL3 GPU). See [ADR-0004](../decisions/0004-legacy-gl-until-phase-6.md).
- Value semantics for leaf *classes* (`OOColor`, `OORoleSet`, …; the math types are already C
  structs, [ADR-0012](../decisions/0012-c-stays-c.md)); `unique_ptr` for exclusive ownership;
  shrink `Ref` usage to the entity graph where it belongs.
- Break up `Universe`: separate scene graph, simulation, and presentation. Gated on extracting
  `IUniverse`/`IGameView` first, and on the 968-name by-name surface
  ([6-solid-review.md §8](6-solid-review.md#8-work-items-for-phase-6) items 3 and 6).
- The 24 runtime `OOLogGenericSubclassResponsibility()` stubs become `= 0`; `Entity`/`ShipEntity`
  fields become private behind inline accessors; the three parallel type-discrimination mechanisms
  collapse to one; `Entity`'s 49-member interface is segregated
  ([6-solid-review.md §8](6-solid-review.md#8-work-items-for-phase-6) items 1, 2, 4, 7).
- `std::expected` error paths replacing out-parameter + `BOOL` returns.
- `std::jthread` + a proper job system for `OOAsyncWorkManager`.
- Revisit C++20 modules.

## Open decisions

- **5** — decided: GL 3.3 Core (ADR-0004, ADR-0013).
- C++20 modules: revisit here once Meson + Clang + MSVC module support is even.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 6).
- 2026-11-02 — SOLID design review of the converted tree added
  ([6-solid-review.md](6-solid-review.md), `oolite-dev` `21c3048a2`); its §8 work items folded into
  the exit gate. Beads not filed (`bd` unreachable at the time).
