# ADR-0022 — Phase 1 finishes on an all-Objective-C++ tree; the façade carries a reduced debug API

**Status:** Proposed — default in effect (Claude Code, Opus orchestrator, 2026-09-22; ADR-0013 rule:
nothing waits on a human). Jon may override.
**Date:** 2026-09-22
**Amends** the sequencing in [2-oofnd.md](../phases/2-oofnd.md) (seam 2.1 lands during Phase 1) and
the "Not in the façade" list in `upstream/oolite/src/Core/Scripting/ooscript/README.md`.

## Context

Phase 1 must end with no SpiderMonkey symbol in the game and the game linked against QuickJS-ng.
Measured on `main` @ 364cba8 when the Opus session took over from the Hermes fleet:

- the per-file retarget sweep had removed engine *calls* from ~40 binding files but left the engine's
  *types* everywhere: 1,166 `JSContext`, 1,022 `jsval`, 530 `JSObject` across 104 files, 44 includes of
  the engine header. The game could not be built against any other engine;
- 21 files still called the engine directly and had no bead (the generator selected by `#include`,
  oo-utqt);
- the façade (`JSEngine.hpp`) is C++; ~100 of the 204 `.m` files reach an engine type through headers,
  so removing the types needs every such file to compile as Objective-C++;
- the SpiderMonkey-only debugging features (stack-frame walks with variables, the `debugger`-statement
  hook, the MOZ_TRACE_JSCALLS function callback, root/heap dumps) had no façade equivalent.

## Decision

1. **Seam 2.1 (the `.m` → `.mm` switch, bead oo-x7o) is pulled forward into Phase 1.** Every `.m`
   becomes `.mm` in one behaviour-free commit (ADR-0001's "the whole tree compiles as Objective-C++
   during the bridge"). The ADR-0012 half of that seam (C-in-`.m` → `.c`) stays with the existing
   `sweep:renames` beads.
2. **The rest of the retarget is a codemod plus hand-finishing**, not ~20 more per-file beads:
   `tools/refactor/js-types.py` (seam 1.2b) rewrites the engine vocabulary 1:1 onto the façade across
   the tree; the `OOJS_*` macro layer is ported by hand onto `ooscript::CallArgs`; what the codemod
   cannot express is finished file by file (bead oo-1gc.3).
3. **The façade gains a debug section** (`frameIterator`/`frameScript`/`frameLineNumber`/…,
   `getScopeVariables`, `setDebuggerHandler`, `setFunctionCallback`, `setContextCallback`,
   `dumpNamedRoots`, `dumpHeap`) with an explicit contract: a backend may answer with less, and nothing
   there may influence what a golden observes. On SpiderMonkey it is the old behaviour exactly. On
   QuickJS-ng it is filename+line frames from an Error stack snapshot, no variables, no debugger or
   profiler hook, and a memory-usage dump instead of a heap dump.
4. **QuickJS-ng value lifetime emulates SpiderMonkey's conservative GC with a handle arena** (bead
   oo-1gc.2): every value handed to game code holds a reference until the next `gc()`/`maybeGC()` at
   request depth ≤ 1; roots are addresses re-read at that point.

## Consequences

- Phase 2's seam 2.1 is done when Phase 2 starts; the `sweep:renames` beads still turn C-only files
  into `.c` afterwards.
- Debug-console users on the QuickJS build lose variable dumps in stack traces, the `debugger`
  statement breakpoint and JS-function profiling; `console.dumpHeap()` writes a memory summary.
  Recorded in `docs/EXPANSION_MIGRATION.md` only if an expansion is shown to depend on them.
- A game-code path that holds an unrooted value across a `gc()` inside its own request would now see
  it freed on QuickJS-ng (it would already have been unsafe on SpiderMonkey, but rarely observed).
  The goldens and the corpus are the detector.

## History

- 2026-09-22 — proposed with defaults in effect.
