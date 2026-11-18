---
status: New
branch: seriesb/029-cpp-component-tests
parent: seriesb/033-drop-oo-prefix
---

On hold (Jon, 2026-11-17). Proper component tests need encapsulation first: this branch's
headless mode turns rendering off with flags in many places instead of a rendering abstraction.

Restacked 2026-11-17 after `seriesb/033-drop-oo-prefix` (stack: 028 → 031 → 032 → 033 → 029 →
030). The 029 commits were replayed on the renamed tree and the tip is
`Restack: 032's cleanups and 033's renames in 029's code`, which applies what 032 and 033 did to
029's code. Only the tip is built and tested; commits before it may still use the old names.
029's `T050a` (RanrotSeedFromRNGSeed in unsigned arithmetic) moved into 032, just before the
`-Wsign-conversion` commit that needs it.
