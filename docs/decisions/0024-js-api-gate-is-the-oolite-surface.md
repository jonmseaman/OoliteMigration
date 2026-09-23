# ADR-0024 — Phase 1's JS API gate compares Oolite's own API surface

**Status:** Proposed — default in effect (Claude Code, Opus orchestrator, 2026-09-22; ADR-0013).
Jon may override.
**Date:** 2026-09-22
**Amends** the exit-gate line "`oxp-contract/js-api-1.93.json` reproduces exactly on QuickJS-ng"
in [1-js-engine.md](../phases/1-js-engine.md).

## Context

`js-api-1.93.json` is an enumeration of everything the SpiderMonkey 1.8.5 game exposed: Oolite's
86 globals and their members, and the ECMAScript library of a 2011 engine (E4X, `Iterator`,
Array/String generics, `arity`/`caller` on functions, ES5-era descriptor attributes). A snapshot
of the QuickJS-ng build cannot reproduce that file byte for byte: its library is ES2023. The
first comparison (bead oo-1gc.6) showed 2,942 raw differences, the large majority in the
ECMAScript library and in descriptor *representation*. Only a few were real API changes. Those were
dropped read-only/permanent attributes from the per-file retarget sweep, fixed in oo-1gc.6 on
both engines.

## Decision

The gate is `tools/js_api_surface_compare.py oxp-contract/js-api-1.93.json <quickjs snapshot>`
exiting 0. Every Oolite global keeps its type and class name, and every member keeps its kind,
writability, enumerability and method arity. A data property and an accessor count as the same
kind, since both engines implement Oolite's native properties through a getter hook. The ECMAScript
globals and the engine's own function properties are out of scope. Their changes are the
language-level changes in `docs/EXPANSION_MIGRATION.md`, with the SpiderMonkey-only functions
expansions actually use polyfilled per ADR-0023. `js-api-1.93.json` stays untouched as the
versioned baseline. A QuickJS-era snapshot is committed beside it under its own name when
Phase 1 closes.

## Consequences

- The gate catches what an expansion author could be broken by (a missing member, a lost
  read-only, a changed arity or class name) and ignores what no expansion can depend on without
  also depending on SpiderMonkey itself.
- The raw full-file diff is still produced for the record; it is not the gate.

## History

- 2026-09-22 — proposed with default in effect.
