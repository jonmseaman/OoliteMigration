# Architecture decision records

Append-only. One file per decision. A decision that changes gets a new ADR that supersedes the old
one; the old file gains a `Superseded by` line and is otherwise untouched. The point is that an
agent or a future reader can see *what is decided now* from the newest ADR on a topic, and *why it
changed* from the chain.

| # | Decision | Status |
|---|---|---|
| [0001](0001-bridge-then-convert.md) | Strangler pattern: compile as ObjC++, replace Foundation, convert leaves inward | Accepted |
| [0002](0002-quickjs-ng.md) | Replace SpiderMonkey 1.8.5 with QuickJS-ng behind a façade; aarch64 SM port held in reserve | Accepted |
| [0003](0003-intrusive-refcount.md) | Mirror ObjC refcounting with `oo::Ref<T>`, not `std::shared_ptr` | Accepted |
| [0004](0004-legacy-gl-until-phase-6.md) | Ship on OpenGL 2.1 compatibility profile through Phase 4 | Accepted |
| [0005](0005-defer-dgx-spark.md) | Do not buy inference hardware now; inference is a network endpoint behind config | Accepted |
| [0006](0006-gas-city-and-hermes.md) | Gas City (Gastown pack) for the fleet; Hermes Agent for the Reporter | Superseded by 0014 |
| [0007](0007-ubuntu-agent-host.md) | Agents run on an Ubuntu host, not Windows; Windows is a build runner | Superseded by 0010 |
| [0008](0008-forge-and-runners.md) | GitHub origin + Forgejo mirror owning CI and runners | Accepted; **deferred by 0016** |
| [0009](0009-apple-silicon-after-runtime-removal.md) | Apple Silicon is Phase 5, after the Objective-C runtime is removed | Accepted |
| [0010](0010-single-windows-machine.md) | One Windows x86-64 machine (native + WSL2) for everything until Phase 5 | Accepted; WSL2 leg dropped by 0017 |
| [0011](0011-cpp20-then-cpp23.md) | Conversion targets C++20; the C++23 upgrade is part of Phase 6 | Accepted |
| [0012](0012-c-stays-c.md) | Existing C stays C; only files with `@implementation` are converted; `oomath` is a rename, not the exemplar | Accepted |
| [0013](0013-decide-up-front-minimise-human.md) | All open decisions decided by default; Jon is in exactly four places; merges are automatic | Accepted |
| [0014](0014-claude-code-opencode-beads.md) | Claude Code as the runtime; beads as the queue; merge queue + run-story wrapper as in-repo scripts | Accepted; local tier amended by 0015; submodule posture superseded by 0017 |
| [0015](0015-hermes-goal-loop.md) | Hermes Agent `/goal` drives local-model sweeps; `tools/fleet/accept` is the only path to `bd close` | Accepted |
| [0016](0016-no-forge-local-verification.md) | No CI/CD forge for now; Tier B/C and the merge-queue gate run locally | Accepted; defers 0008 |
| [0017](0017-native-windows-subtree.md) | Native Windows only (no WSL2); `upstream/oolite` is a subtree of the fork; Linux joins at Phase 5; merge queue pushes after each green batch | Accepted; amends 0010, 0014, 0016 |
| [0018](0018-component-test-tier.md) | A component test tier: Gherkin scenarios over the debug console in Python (pytest-bdd, not cucumber-cpp); `OO_RANDOM_SEED` as its one enabler | Proposed — default in effect |
| [0022](0022-phase1-finishes-on-objcpp-with-a-debug-facade.md) | Phase 1 finishes on an all-Objective-C++ tree (seam 2.1 pulled forward); the rest of the retarget is a codemod; the façade carries a reduced-capability debug API; QuickJS-ng values live in a GC-emulating arena | Proposed — default in effect |
| [0023](0023-built-in-mozilla-compat-polyfills.md) | The QuickJS-ng build ships the toSource/quote/uneval and Array/String-generics polyfills built in (guarded no-ops on SpiderMonkey) | Proposed — default in effect |
| [0024](0024-js-api-gate-is-the-oolite-surface.md) | Phase 1's JS API gate compares Oolite's own API surface (tools/js_api_surface_compare.py), not the ES library of the old engine | Proposed — default in effect |
| [0026](0026-oofnd-ref-semantics.md) | `oo::Ref` details ADR-0003 leaves open: retaining raw-pointer ctor + `adopt`, weak refs zeroed before the destructor, GNUstep autorelease order, ADR-0003's thread-safety only, insertion-ordered `WeakSet` | Proposed — default in effect |
| [0029](0029-objc-floor-without-foundation.md) | The Objective-C floor without Foundation: root class `OOObject` on libobjc2's own refcount/pool/weak refs, `OOConstantString` (+ tag-4 `OOTinyString`) behind `@"..."` flipped with oo-qps, ObjC exceptions kept in Phase 2, one bead per remaining Foundation family | Proposed — default in effect |

Template: Status · Date · Context · Decision · Consequences · History.
