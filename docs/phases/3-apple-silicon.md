# Phase 3 — Apple Silicon milestone 🎯

**Status:** not started · **Est.:** 1–2 eng-months · **Depends on:** [Phase 1](1-js-engine.md) and [Phase 2](2-oofnd.md)
**Runs in parallel with:** —

## Goal

**Oolite plays on Apple Silicon, with expansions.** With SpiderMonkey and GNUstep-base gone, the
only Objective-C dependency left is the runtime, which Apple provides natively on arm64. This is the
first externally visible win and the right point to talk to upstream
([architecture §6.3](../architecture.md)). This phase is Jon's Mac and Jon's hands; no fleet.

## Entry gate

- [ ] Phase 1 and Phase 2 exit gates green
- [ ] macOS runner decision made (open decision 8)
- [ ] Cross-platform golden policy decided and implemented (open decision 11; see Phase 0)

## Exit gate

- [ ] `meson` builds `aarch64-apple-darwin` from a `macos` branch in `src/meson/`
- [ ] Goldens reproduce on macOS **under the cross-platform policy** (per-platform goldens, or quantised dumps)
- [ ] Tier-1 OXP corpus green on macOS
- [ ] PyAutoGUI G1–G9 green on the Mac (this is the proof it is an application, not a binary that links)
- [ ] Signed, notarised `.app` launches on a clean Mac with no prior config (G7)
- [ ] macOS arm64 added to Tier C

## Seams

Everything here is a seam; there are no sweeps.

## Work items

1. Add a `macos` branch to `src/meson/`; SDL3 for window/input (Cocoa backend), legacy GL 2.1 context.
2. `.app` bundle packaging, `Info.plist`, code-signing/notarisation; Application Support paths for
   saves, OXZ downloads, and the cache.
3. Port the residual `SDL/` platform code; consult `upstream/oolite-mac-components` for the
   historical Cocoa dock-tile, document-type, and importer bits.
4. Add macOS arm64 to CI, running the same goldens **and the PyAutoGUI GUI tier ([0-gui-tier.md](0-gui-tier.md))** — the
   latter is the actual proof that this is a working macOS application rather than a binary that
   links. Requires the self-hosted-runner decision (open decision 8) to have been made by now.

## Commands

From Phase 0, plus the macOS runner label `self-hosted, macos, arm64` ([I2](../infra/2-forge-and-runners.md)).

## Open decisions

- **8** — macOS runner. PyAutoGUI needs Accessibility and Screen Recording TCC grants, per-app, granted interactively once. Hosted runners cannot. Either self-host on the Mac or run the macOS GUI tier as a local pre-release gate.
- **11** — cross-platform goldens (owned by Phase 0, consumed here).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 3).
