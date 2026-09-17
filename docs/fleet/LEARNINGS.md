# Fleet learnings

Cross-bead memory for the agents, Ralph-style. One line per entry, appended by the orchestrator
through `scripts/learn.sh` when a bead taught something that applies beyond itself: a codebase
pattern, a tooling quirk, a way an acceptance command misleads. Per-bead history stays in the
bead's notes; this file is for what the *next* bead should know. The last 40 lines are injected
into every worker and reviewer context, so keep entries short and concrete. Prune when stale.

<!-- entries below; newest last -->
- 2026-09-17 [oo-kgl5] Windows: never hand an MSYS path (/c/...) to a native binary. ccache rejects CCACHE_BASEDIR=/c/... and then ALL later ccache calls fail silently, which made meson fall back to bare clang (0% cache) and killed build-windows.sh in arithmetic; native python turns /c/... into C:/c/... (WinError 3). Convert with cygpath -m at every boundary.
