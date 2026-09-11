# ADR-0002: Replace SpiderMonkey 1.8.5 with QuickJS-ng behind a façade

**Status:** Accepted · **Date:** 2026-09-05

## Context

Oolite embeds a patched SpiderMonkey 1.8.5 (Firefox 4.0, March 2011). Its `configure.in` does not
recognise `aarch64`; nanojit has no arm64 target; the build is autoconf 2.13. There are 3,828 `JS_*`
call sites across 102 files. This is the hard blocker for Apple Silicon and is independent of the
language migration.

Options considered: (A) port SM 1.8.5 to aarch64 interpreter-only; (B) upgrade to mozjs-128 ESR;
(C) swap to QuickJS-ng; (D) different engine per platform.

## Decision

**C, with A held in reserve.** Define `ooscript/JSEngine.hpp`, a thin C++ façade sized to what
Oolite uses. Retarget all call sites onto the façade with SpiderMonkey still behind it (must be
byte-identical in behaviour). Add a QuickJS-ng backend. Differential-test both against the goldens
and the OXP corpus. Delete SpiderMonkey.

B rejected: total API rewrite plus Rust and Mozilla's build system as hard deps on three platforms.
D rejected: fragments OXP compatibility, the one thing that cannot be fragmented.

## Consequences

- The JS *language level* (contract C3) is the only expansion-facing contract that knowingly
  changes: Mozilla-only syntax (`for each`, E4X, conditional catch, `.quote()`, …) becomes a hard
  error. In-tree scripts have zero occurrences; the third-party corpus is scanned in Phase 0.
- An expansion-author migration guide and a lint tool are deliverables.
- A two-week spike on option A is still recommended first: it de-risks the fallback and gives an
  early macOS build to test with (roadmap open decision 1).

## History

`MIGRATION_PLAN.md` §4/R1, §6, §9.3. Now [architecture.md §4](../architecture.md) and
[Phase 1](../phases/1-js-engine.md).
