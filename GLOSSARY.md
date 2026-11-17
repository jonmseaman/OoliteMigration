# Glossary

| Term | Meaning |
|---|---|
| **Bead** | A `bd` (beads) issue: one small unit of work. Its notes are the only state that survives between agent iterations. Closed only when Jon merges its PR (`land.sh`). |
| **`accept`** | `.claude/skills/beads-worker/scripts/accept.sh <bead>`: runs the bead's acceptance commands and, only if all pass, opens its pull request with `git town propose`. It does not close the bead. |
| **`land`** | `.claude/skills/beads-worker/scripts/land.sh`: closes every bead whose pull request Jon merged. The only path to `bd close`. |
| **`queue-check`** | `.claude/skills/beads-worker/scripts/queue-check.sh <selector>`: exit 0 iff no matching bead is still actionable. Tells `/loop` when to stop. |
| **Census** | `component_census`: every ship and equipment item in the core data tried once in a headless game, each reported passed, left, not-applicable or failed; expected failures are in `census-expectations.tsv`. |
| **Component test** | A test of the whole game: a C++ program in `oolite-dev/tests/component-cpp/` (headless) or a pytest-bdd scenario in `oolite-dev/tests/component/` (windowed). |
| **Component tier** | Both halves: the headless C++ tests and the windowed Gherkin scenarios (S1–S8, T1) driven over the debug console, asserting tolerant invariants ("no pirate remains after 900 ticks"). `tests/run.sh component`. |
| **GL trap** | On Linux and macOS, a generated replacement for every GL function the game links (`gl_trap_gen.py`): while headless, a call aborts the test naming the function. |
| **Headless** | A game in the test's own process with no window, no GL context and a manual clock (`OOHeadlessOptions`, `GameController::startHeadless`). |
| **Recorded layout** | `tests/component-cpp/layouts/<name>.tsv`: what key code each (scancode, modifiers) gives under a keyboard layout; installed as the view's key lookup. `us` is SDL's built-in map; `fr_azerty` and `ru` are derived. |
| **Windowed** | A game in its own window, driven from outside: the windowed component half, the smoke run. |
| **Exemplar** | An existing file a bead points at: "do it the way `<path>` does it". |
| **Freeze policy** | Upstream changes to a frozen module are ported by hand and recorded in [docs/UPSTREAM_DELTA.md](docs/UPSTREAM_DELTA.md). |
| **`oofnd`** | The in-tree C++20 Foundation replacement (String, PList, Ref, FileSystem, Defaults, Logging). |
| **`oo::Ref<T>` / `WeakRef<T>`** | Intrusive refcounting mirroring Objective-C retain/release. Not `shared_ptr`. |
| **OXP / OXZ** | Oolite expansion pack: unpacked directory / zipped. Data, JS and assets; never native code. Untrusted input. |
| **Parity audit** | The method-by-method comparison of the C++ port against upstream's Objective-C, in [parity/](parity/README.md). ✅ same · ⚠️ intentional · ❌ suspected difference · ➖ removed. |
| **Phase 4p** | Polish for upstream, the current phase: [docs/phases/4p-upstream-polish.md](docs/phases/4p-upstream-polish.md). |
| **Submodule layout** | `oolite-dev` (the fork's `develop`, the game) and `oolite-main` (its `master`) are submodules of `jonmseaman/oolite`; `upstream/*` are OoliteProject's repos, unmodified. |
| **Tier 1 / 2 / 3 corpus** | ~30 / ~150 / all published expansions, load-tested (`tools/corpus.sh`). |
