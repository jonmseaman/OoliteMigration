# Phase 6 — Modernise

**Status:** not started · **Est.:** 4–10 eng-months · **Depends on:** [Phase 5](5-remove-objc-runtime.md)

## Goal

Only now, with a pure C++23 codebase and a working golden harness, is it safe to make design
changes. Low fan-out: these are design changes by definition.

## Entry gate

- [ ] Phase 5 exit gate green

## Exit gate

Per sub-project; each is its own mini-phase with goldens as the gate:

- Renderer → GL 3.3 Core (or SDL3 GPU). See [ADR-0004](../decisions/0004-legacy-gl-until-phase-6.md).
- Value semantics for leaf types; `unique_ptr` for exclusive ownership; shrink `Ref` usage to the
  entity graph where it belongs.
- Break up `Universe`: separate scene graph, simulation, and presentation.
- `std::expected` error paths replacing out-parameter + `BOOL` returns.
- `std::jthread` + a proper job system for `OOAsyncWorkManager`.
- Revisit C++20 modules.

## Open decisions

- **5** — renderer target: GL 3.3 Core vs SDL3 GPU vs ANGLE. Preference order in ADR-0004. Decided in Phase 5 at the latest.
- C++20 modules: revisit here once Meson + Clang + MSVC module support is even.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 6).
