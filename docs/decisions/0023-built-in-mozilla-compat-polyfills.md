# ADR-0023 — The QuickJS-ng build ships the Mozilla-compatibility polyfills built in

**Status:** Proposed — default in effect (Claude Code, Opus orchestrator, 2026-09-22; ADR-0013:
nothing waits on a human). Jon may override.
**Date:** 2026-09-22
**Amends** the "interim relief" in [EXPANSION_MIGRATION.md](../EXPANSION_MIGRATION.md) (to-source,
quote-method) and the corpus exit criterion of [Phase 1](../phases/1-js-engine.md).

## Context

The first real differential run (bead oo-1gc.6: goldens + the 36-group Tier-1 corpus on both
engines) matched everywhere except expansions that call SpiderMonkey-only library functions:
`Library_1.10.5.oxz`'s `lib_test.js` calls `toSource()` ("TypeError: not a function"), and the
two Tier-1 groups that depend on it (GNN, Planetfall) failed with it. The corpus lint (bead oo-ctq)
had already found that these calls are the whole blast radius across the 818-expansion catalogue.
`tools/oxp-compat-shim` (bead oo-864) polyfills exactly these, but only if the user installs it,
and the Phase 1 exit gate requires Tier-1 green on QuickJS-ng.

## Decision

`Resources/Scripts/oolite-global-prefix.js`, which runs before every script, installs:

- the shim's `Object.prototype.toSource`, `Array.prototype.toSource`, `String.prototype.quote`
  and `uneval`;
- SpiderMonkey's Array and String "generics" (`Array.forEach(array, fn)`, `String.replace(s, ...)`).

Every install is guarded (`if (typeof X !== "function")`), so under SpiderMonkey 1.8.5 each one is
a no-op and the goldens cannot move. Output is the shim's best-effort form, not byte-identical to
SpiderMonkey's source reflection.

Syntax that cannot be polyfilled (E4X, `for each`, expression closures, `catch (e if ...)`,
legacy `let` blocks) stays removed, as documented.

## Consequences

- Tier-1 expansions that used these functions keep working unmodified; `docs/EXPANSION_MIGRATION.md`
  still tells authors to migrate (to `JSON.stringify`, `Array.prototype.forEach`, ...).
- The standalone CompatShim.oxp becomes redundant for these functions; it stays as a tested
  artefact, and a no-op when both are present (each install is guarded).

## History

- 2026-09-22 — proposed with default in effect.
