# Oolite migration roadmap

Objective-C/GNUstep → C++23, native on Apple Silicon, Windows x64, and Linux x64, with all
published expansions working unmodified. **Start here.** Every other document is one link away.

**Status (2026-09-06):** planning complete. No code changes to `upstream/oolite`. Nothing built.
**Current focus:** [I0 machines](docs/infra/0-machines.md) and [ADR-0008 forge](docs/decisions/0008-forge-and-runners.md), then [Phase 0](docs/phases/0-safety-net.md).

## Two tracks

**Migration track** — Phases 0–6, the work on the game. Sequential, except 1 ∥ 2.
**Infra track** — I0–I4, the machines, images, forge, fleet and metrics that let AI agents do the
migration track. It gates Phase 0's exit and the first fleet sweep, and is worked in parallel.

Hardware and setup are infra items, not a migration phase: the agent host, build host, and
verification host are separate concerns, and the phase numbers stay stable.

## Migration phases

| Phase | Name | Doc | Est. eng-mo | Depends on | Fleet? | Status |
|---:|---|---|---:|---|---|---|
| 0 | Safety net | [0-safety-net.md](docs/phases/0-safety-net.md) · [GUI tier](docs/phases/0-gui-tier.md) | 2–4 | I0, I1, ADR-0008 | none; seam work | not started |
| 1 | JS engine (De-Mozilla) | [1-js-engine.md](docs/phases/1-js-engine.md) | 4–7 | 0 | ∥ 2 · ~110 stories after the façade seam | not started |
| 2 | `oofnd` (Foundation replacement) | [2-oofnd.md](docs/phases/2-oofnd.md) | 6–10 | 0 | ∥ 1 · ~400–550 stories after seams | not started |
| 3 | **Apple Silicon milestone** 🎯 | [3-apple-silicon.md](docs/phases/3-apple-silicon.md) | 1–2 | 1, 2 | none; Jon's Mac | not started |
| 4 | ObjC → C++23 (~500 files) | [4-cpp-conversion.md](docs/phases/4-cpp-conversion.md) | 12–24 | 3, exemplars | ~400 stories; 6 giant files are human | not started |
| 5 | Remove ObjC runtime | [5-remove-objc-runtime.md](docs/phases/5-remove-objc-runtime.md) | 1–2 | 4 | none; mechanical | not started |
| 6 | Modernise | [6-modernise.md](docs/phases/6-modernise.md) | 4–10 | 5 | low; design | not started |
| | **Total** | | **30–59** | | | |

With 1 and 2 in parallel, **Phase 3 lands after roughly 9–16 engineer-months**, with the game still
in Objective-C. Phases 0–3 pay off on their own (macOS support, a maintained JS engine, no GNUstep)
whether or not Phase 4 ever completes. Every stopping point is a reasonable place to stop.

## Infra track

| Item | Name | Doc | Gates | Status |
|---|---|---|---|---|
| I0 | Machines and network | [0-machines.md](docs/infra/0-machines.md) | Phase 0 entry | not started |
| I1 | Base images and caches | [1-base-images.md](docs/infra/1-base-images.md) | Phase 0 items 0.2, 0.9 | not started |
| I2 | Forge and CI runners | [2-forge-and-runners.md](docs/infra/2-forge-and-runners.md) | Phase 0 items 0.3, 0.10 | **blocked on ADR-0008** |
| I3 | Fleet (Gas City, Hermes, routing) | [3-fleet.md](docs/infra/3-fleet.md) | first sweep | not started; Reporter first |
| I4 | Metrics | [4-metrics.md](docs/infra/4-metrics.md) | I3 step 1 | not started |

## Reference

| Doc | What |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Agent contract: rules, prohibitions, commands, exemplars. Under 1k words. |
| [GLOSSARY.md](GLOSSARY.md) | Every term of art in one table. |
| [docs/architecture.md](docs/architecture.md) | Survey, target design, risk register, expansion contracts, upstream posture. The *why*. |
| [docs/execution-model.md](docs/execution-model.md) | Never verify with a model; Tier A/B/C; agent authority; model tiering; the seven-check sizing rule. The *how*. |
| [docs/decisions/](docs/decisions/README.md) | ADRs 0001–0008, append-only. |
| [docs/templates/](docs/templates/) | Phase and story templates. |
| [docs/stories/G1-exit-via-mouse.md](docs/stories/G1-exit-via-mouse.md) | The hand-written calibration story. |

## Open decisions

Owner is Jon for all. "When" is the latest point the decision can wait.

| # | Decision | Recommendation | When |
|---:|---|---|---|
| 1 | Spike porting SM 1.8.5 to aarch64 (option A) before committing to QuickJS-ng? | Yes, two weeks; de-risks the fallback, gives an early macOS build | before Phase 1 |
| 2 | Hard fork or upstream-collaborative? | Collaborate; talk to upstream at Phase 3 with a working build | before Phase 1 lands |
| 3 | How much C++23 in translated code? | Conservative first, modernise in Phase 6 — **decided**, [ADR-0001](docs/decisions/0001-bridge-then-convert.md) | — |
| 4 | `std::string` vs custom `oo::String`? | `std::string`; benchmark 6,286 sites of copying first | Phase 2, before the String seam |
| 5 | Phase 6 renderer target: GL 3.3 Core / SDL3 GPU / ANGLE? | GL 3.3 Core; [ADR-0004](docs/decisions/0004-legacy-gl-until-phase-6.md) | before Phase 5 ends |
| 6 | Legacy AI and plist scripting: faithful port or sunset? | Faithful; the long tail is the compatibility promise | Phase 4 |
| 7 | Windows toolchain: MinGW-clang vs clang-cl + MSVC STL? | Stay MinGW-clang until C++23 library coverage forces the question | Phase 4 |
| 8 | macOS CI: self-hosted runner on the Mac, or local pre-release gate? | Self-host; TCC grants need it | before Phase 3 |
| 9 | Forge: GitHub + self-hosted runners, or Forgejo? | GitHub origin + Forgejo mirror for CI; [ADR-0008](docs/decisions/0008-forge-and-runners.md) | **before any runner is attached** |
| 10 | Ubuntu agent host: VM on the Windows box, or bare metal? | Bare metal if available; [ADR-0007](docs/decisions/0007-ubuntu-agent-host.md) | I0 |
| 11 | Cross-platform golden policy: per-platform goldens, quantised floats, or both? | Both, plus `-ffp-contract=off` and pinned `-O` | **before the first golden is blessed** |
| 12 | Phase 1 executor split: `clang-refactor` vs fleet? | Resolved: `clang-refactor` for the ~40% stub/numeric patterns, fleet for the rest | — |

## Conventions

- Phase docs follow [templates/phase.md](docs/templates/phase.md). Status logs are append-only and
  dated. Record what the fleet could not do and a human did; that feeds `docs/FLEET_FAILURES.md`.
- Decisions are ADRs. Do not edit a decision in place; supersede it.
- Agent-facing docs have a token budget: `CLAUDE.md` ≤ 1k words, a phase doc ≤ 3k.
- `origin` is Jon's fork, `upstream` is the source project; rebase, don't merge
  ([architecture §6](docs/architecture.md)).
- The two original planning documents, `MIGRATION_PLAN.md` and `AI_EXECUTION_PLAN.md`, were
  dissolved into this tree on 2026-09-06. They are in git history at `ee2de41`.
