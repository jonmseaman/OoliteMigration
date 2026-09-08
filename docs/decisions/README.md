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
| [0004](0004-legacy-gl-until-phase-6.md) | Ship on OpenGL 2.1 compatibility profile through Phase 5 | Accepted |
| [0005](0005-defer-dgx-spark.md) | Do not buy inference hardware now; inference is a network endpoint behind config | Accepted |
| [0006](0006-gas-city-and-hermes.md) | Gas City (Gastown pack) for the fleet; Hermes Agent for the Reporter | Accepted |
| [0007](0007-ubuntu-agent-host.md) | Agents run on an Ubuntu host, not Windows; Windows is a build runner | Accepted |
| [0008](0008-forge-and-runners.md) | GitHub + self-hosted runners vs. self-hosted Forgejo | **Open — conflict recorded** |

Template: Status · Date · Context · Decision · Consequences · History.
