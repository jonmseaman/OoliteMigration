# Glossary

| Term | Meaning |
|---|---|
| **Bead** | A `bd` (beads) issue: one small unit of work. Its notes are the only state that survives between agent iterations. Closed only when Jon merges its PR (`land.sh`). |
| **`accept`** | `.claude/skills/beads-worker/scripts/accept.sh <bead>`: runs the bead's acceptance commands and, only if all pass, opens its pull request with `git town propose`. It does not close the bead. |
| **`land`** | `.claude/skills/beads-worker/scripts/land.sh`: closes every bead whose pull request Jon merged. The only path to `bd close`. |
| **`queue-check`** | `.claude/skills/beads-worker/scripts/queue-check.sh <selector>`: exit 0 iff no matching bead is still actionable. Tells `/loop` when to stop. |
| **Component tier** | pytest-bdd Gherkin scenarios (S1–S8, T1) driven over the debug console, asserting tolerant invariants ("no pirate remains after 900 ticks"). `oolite-dev/tests/component/`. |
| **Deny-list** | Tier A/B/C grep that fails on reintroduced `libgnustep-base` or `JS_*` symbols. |
| **Exemplar** | An existing file a bead points at: "do it the way `<path>` does it". |
| **Freeze policy** | Upstream changes to a frozen module are ported by hand and recorded in [docs/UPSTREAM_DELTA.md](docs/UPSTREAM_DELTA.md). |
| **G1–G11** | The PyAutoGUI GUI tests that drive the real window. `oolite-dev/tests/gui/`. |
| **Golden** | A committed canonical state dump (sorted JSON) from a seeded headless run of one scenario. Byte-compared; only Jon re-blesses. Under `goldens/windows-x64/`. |
| **`oofnd`** | The in-tree C++20 Foundation replacement (String, PList, Ref, FileSystem, Defaults, Logging). |
| **`oo::Ref<T>` / `WeakRef<T>`** | Intrusive refcounting mirroring Objective-C retain/release. Not `shared_ptr`. |
| **OXP / OXZ** | Oolite expansion pack: unpacked directory / zipped. Data, JS and assets; never native code. Untrusted input. |
| **Parity audit** | The method-by-method comparison of the C++ port against upstream's Objective-C, in [docs/parity/](docs/parity/README.md). ✅ same · ⚠️ intentional · ❌ suspected difference · ➖ removed. |
| **Phase 4p** | Polish for upstream, the current phase: [docs/phases/4p-upstream-polish.md](docs/phases/4p-upstream-polish.md). |
| **Re-bless** | Replacing a golden after an intentional behaviour change. Jon only. |
| **Submodule layout** | `oolite-dev` (the fork's `develop`, the game) and `oolite-main` (its `master`) are submodules of `jonmseaman/oolite`; `upstream/*` are OoliteProject's repos, unmodified. |
| **Tier A / B / C** | Per edit (< 30 s) / per PR (< 10 min) / per phase (everything, ASan, GUI tier). [docs/workflow.md](docs/workflow.md). |
| **Tier 1 / 2 / 3 corpus** | ~30 / ~150 / all published expansions, load-tested. Distinct from Tier A/B/C. |
