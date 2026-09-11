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
| [0010](0010-single-windows-machine.md) | One Windows x86-64 machine (native + WSL2) for everything until Phase 5 | Accepted |
| [0011](0011-cpp20-then-cpp23.md) | Conversion targets C++20; the C++23 upgrade is part of Phase 6 | Accepted |
| [0012](0012-c-stays-c.md) | Existing C stays C; only files with `@implementation` are converted; `oomath` is a rename, not the exemplar | Accepted |
| [0013](0013-decide-up-front-minimise-human.md) | All open decisions decided by default; Jon is in exactly four places; merges are automatic | Accepted |
| [0014](0014-claude-code-opencode-beads.md) | Claude Code as the runtime; beads as the queue; merge queue + run-story wrapper as in-repo scripts | Accepted; local tier amended by 0015 |
| [0015](0015-hermes-goal-loop.md) | Hermes Agent `/goal` drives local-model sweeps; `tools/fleet/accept` is the only path to `bd close` | Accepted |
| [0016](0016-no-forge-local-verification.md) | No CI/CD forge for now; Tier B/C and the merge-queue gate run locally | Accepted; defers 0008 |

Template: Status · Date · Context · Decision · Consequences · History.
