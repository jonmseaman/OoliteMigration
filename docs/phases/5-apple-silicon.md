# Phase 5 — Apple Silicon milestone 🎯 (and Linux x64)

**Status:** not started · **Est.:** 1–2 eng-months · **Depends on:** [Phase 4](4-remove-objc-runtime.md)
**Runs in parallel with:** —

## Goal

**Oolite plays on Apple Silicon, with expansions.** By this point the codebase is pure C++20 with
no Objective-C, no `libobjc`, no GNUstep, and no SpiderMonkey, so the macOS port is a platform
layer, a build branch, and packaging: nothing Objective-C-specific ever has to work on macOS
([ADR-0009](../decisions/0009-apple-silicon-after-runtime-removal.md)). This is the first externally
visible win and the right point to talk to upstream ([architecture §6.3](../architecture.md)). It is
also the first time any platform other than Windows x86-64 exists: **Linux x64 joins here too**
([ADR-0017](../decisions/0017-native-windows-subtree.md)), from a container or a rented box, and a
second physical machine joins the setup ([ADR-0010](../decisions/0010-single-windows-machine.md)).
The work is done by a frontier agent in an interactive session on the Mac; Jon's part is the TCC
grants and the signing identity ([ADR-0013](../decisions/0013-decide-up-front-minimise-human.md)).
No fleet.

## Entry gate

- [ ] Phase 4 exit gate green (no `.mm`, no `-fobjc-*`, GCC and Clang both green)
- [ ] Cross-platform golden policy (decision 11) implemented on Windows; this phase is its first cross-platform exercise
- [ ] TCC grants and signing identity held on the Mac ([I0](../infra/0-machines.md)); a Linux build environment reachable
- [ ] Legacy OpenGL 2.1 context still available on the target macOS version, **or** the Phase 6
  renderer work has been pulled forward ([ADR-0004](../decisions/0004-legacy-gl-until-phase-6.md))

## Exit gate

- [ ] `meson` builds `aarch64-apple-darwin` from a `macos` branch in `src/meson/` with Apple Clang
- [ ] Goldens reproduce on macOS **under the cross-platform policy** (per-platform goldens, or quantised dumps)
- [ ] Tier-1 OXP corpus green on macOS
- [ ] PyAutoGUI G1–G9 green on the Mac (this is the proof it is an application, not a binary that links)
- [ ] Signed, notarised `.app` launches on a clean Mac with no prior config (G7)
- [ ] Linux x64 builds and reproduces the goldens under the policy
- [ ] macOS arm64 and Linux x64 added to Tier C; three-platform definition of done in force from here on

## Seams

Everything here is a seam; there are no sweeps.

## Work items

1. Add a `macos` branch to `src/meson/`; SDL3 for window/input (Cocoa backend), legacy GL 2.1 context.
2. `.app` bundle packaging, `Info.plist`, code-signing/notarisation; Application Support paths for
   saves, OXZ downloads, and the cache.
3. Port the residual `SDL/` platform code; consult `upstream/oolite-mac-components` for the
   historical Cocoa dock-tile, document-type, and importer bits (for behaviour, not for code: those
   components are Objective-C and are not coming back).
4. Add macOS arm64 and Linux x64 to Tier C (the Mac natively; Linux in a container or on a rented
   box; restore upstream's `build-linux.sh` flow), running the same goldens **and, on the Mac, the
   PyAutoGUI GUI tier ([0-gui-tier.md](0-gui-tier.md))** — the latter is the actual proof that this
   is a working macOS application rather than a binary that links.
5. Fix whatever arm64 shakes out: alignment, `long` width assumptions, FMA-sensitive float paths
   that the golden policy tolerates but that are actually bugs.

## Commands

From Phase 0; Tier C gains the macOS and Linux legs.

## Open decisions

- **8** — decided: the macOS legs run on Jon's Mac; Jon grants the TCC prompts once (ADR-0013).
- **11** — cross-platform goldens (owned by Phase 0, implemented by Phase 4's exit, consumed here).
- **5** — renderer; only if Apple has removed legacy GL.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 3).
- 2026-09-10 — Resequenced from Phase 3 to Phase 5 (ADR-0009). Goal, entry gate and work items
  rewritten for a codebase with no Objective-C.
- 2026-09-11 — Linux x64 joins here with macOS (ADR-0017); runner wording removed.
