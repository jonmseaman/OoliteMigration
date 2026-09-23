# ADR-0025 — Phase 1's "builds for aarch64-apple-darwin" box is satisfied by engine-neutrality evidence; the build itself is Phase 5's

**Status:** Proposed — default in effect (Claude Fable 5.1, Phase 1 review 1, bead oo-iizf,
2026-09-23; ADR-0013 rule: nothing waits on a human). Jon may override.
**Date:** 2026-09-23
**Amends** the exit-gate line "The tree builds for `aarch64-apple-darwin` as far as the GNUstep
dependency permits" in [1-js-engine.md](../phases/1-js-engine.md).

## Context

The Phase 1 review 1 walked the exit gate and found this box with no evidence and no way to
produce any on the fleet machine: there is no Apple toolchain or SDK on it (ADR-0017: Windows is
the only platform until Phase 5), ADR-0013 decision 1 dropped the SpiderMonkey aarch64 spike for
the same reason, and the macOS `meson` branch in `src/meson/` is a Phase 5 exit-gate item
([5-apple-silicon.md](../phases/5-apple-silicon.md)). The box was written when Phase 1's purpose
was "unblock Apple Silicon", i.e. it asks whether Phase 1 left anything that would stop an arm64
build later, not for a build that Phase 5 owns.

What Phase 1 can show today, offline:

- the façade header compiles with no engine include path and names no engine type
  (`tools/check-jsengine-facade.sh`, steps 1–2);
- the only engine-specific translation unit is `ooscript/JSEngine_quickjs.cpp` (step 3), and
  QuickJS-ng 0.16.2 builds and is tested upstream on arm64 macOS;
- SpiderMonkey 1.8.5, NSPR and the `js_backend` option are out of the build (bead oo-7wx), which
  were the aarch64 blockers named in ADR-0002.

## Decision

1. The box reads as: *Phase 1 introduces no platform-specific code; the JS engine and the façade
   are proven engine-neutral and the vendored engine supports arm64.* Its evidence is
   `tools/check-jsengine-facade.sh` and `tools/check-jsengine-facade-quickjs.sh` passing, plus
   bead oo-7wx's acceptance (no SpiderMonkey/NSPR in the build).
2. The `aarch64-apple-darwin` build is Phase 5's exit-gate line and is not re-stated in Phase 1.
   The Phase 1 exit gate (bead oo-5pr) ticks this box on the evidence in (1), not on a build.
3. If Jon overrides and wants a Phase 1 cross-compile smoke, it is one bead: `clang++
   --target=aarch64-apple-darwin -fsyntax-only` of `JSEngine_quickjs.cpp` against a checked-in
   SDK stub, and it cannot run on the fleet machine until an SDK exists there.

## Consequences

- No Phase 1 bead is filed for this box; the review records it as "deferred to Phase 5 per
  ADR-0025" in the phase doc's status log.
- Phase 5's entry gate should cite this ADR so the arm64 build is not assumed done.
