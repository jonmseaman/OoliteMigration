# ADR-0017: Everything runs natively on Windows; no WSL2; the fork is a subtree; Linux joins at Phase 5

**Status:** Accepted · **Date:** 2026-09-11 · **Amends:** [ADR-0010](0010-single-windows-machine.md) (drops its WSL2 leg), [ADR-0016](0016-no-forge-local-verification.md) (push cadence), [ADR-0014](0014-claude-code-opencode-beads.md) (submodule posture)

## Context

ADR-0010 kept a Linux leg inside WSL2 for the agents, the worktrees, `bd`, a Linux build, the
golden containers and the sanitizers. Jon's decision (2026-09-11): no WSL2. Hermes Agent and Claude
Code both install natively on Windows, and one environment is simpler than two. Jon will have Claude
review and refine the mechanics once the move to the Windows machine happens.

A consistency review the same day found that the planning repo's worktree and accept scripts could
not work against `upstream/oolite` as a git **submodule**: `git worktree add` leaves a submodule
empty, and a commit made inside one is not on the bead branch that `accept.sh` merges. It also found
that only the planning repo's `main` and the beads database need to move machines.

## Decision

1. **One environment: native Windows.** Hermes, Claude Code, `bd`, git worktrees, the MSYS2 UCRT64
   build, the golden harness, the GUI tier and the merge queue all run natively. The beads-worker
   scripts stay bash and run from the MSYS2 UCRT64 shell, which the build needs anyway and which
   supplies bash, coreutils, `jq`, `python3` and `sha256sum`. `bd` is the Windows binary. No
   containers, no Xvfb, no Docker.
2. **Windows is the only verified platform through Phase 4.** The definition of done reads
   "Windows x64" until Phase 5, where **macOS arm64 and Linux x64 join together** as "the other
   platforms" (Linux from a container or a rented box, not this machine). ADR-0009's argument
   applies to Linux exactly as to macOS: a Linux port of a pure-C++ codebase is a build branch.
   Per-platform goldens (decision 11) therefore start with one platform; the Linux-vs-Windows
   exercise moves from Phase 4 to Phase 5. Jon may override by ADR if a Linux check is wanted
   earlier; the cheapest form would be upstream's own hosted Linux workflow on the fork.
3. **Goldens run as native processes, not containers.** One game process per scenario on a
   parameterised port, MSYS2's Mesa `opengl32.dll` (llvmpipe) next to the binary as upstream's own
   test does, a real window on the desktop. Concurrency is bounded by RAM and by the desktop, not by
   a container cap. Determinism comes from the pinned build flags and the software rasteriser.
4. **Sanitizers: prove ASan under MSYS2 clang in Phase 0** (the "deliberate use-after-free is
   caught" exit-gate item). If MinGW's compiler-rt cannot deliver it, the fallback is a `clang-cl`
   ASan build variant of the sanitizer-relevant targets once the Objective-C is gone, or a rented
   Linux run on a cadence. UBSan is best-effort on Windows; the gate item is ASan.
5. **The GUI tier and the Windows goldens need the interactive desktop.** The machine stays logged
   in and unlocked with sleep and the lock screen disabled (a keep-awake tool; see the
   [I0 checklist](../infra/0-machines.md)). The PyAutoGUI tier runs **in Tier C only** (per merge
   batch, at most a few times a day) plus a nightly run, never per bead: it takes the desktop
   exclusively while it runs, and per-bead runs would slow development. Tier B stays headless.
6. **`upstream/oolite` is a git subtree of the fork, not a submodule**, added with `--squash` at the
   previously pinned commit. `upstream/oolite-tests` and `upstream/oolite-expansion-catalog` likewise,
   because acceptance commands read them. The other three (`spidermonkey-ff4`, `oolite-debug-console`,
   `oolite-mac-components`) stay submodules: reference only, never touched by a bead, absent from
   worktrees by design.
7. **Push cadence.** The bead branches merge into the planning repo's `main` locally. After each
   Tier C green batch the merge queue pushes `main` to `origin` and runs
   `git subtree push --prefix=upstream/oolite fork migration`, so the fork's `migration` branch is a
   mirror of the converted tree with its history grafted onto the fork's commits. Not per bead: a
   subtree split walks the history each time and a mirror gains nothing from finer grain. Until the
   merge queue exists, Jon pushes both weekly. Upstream sync is
   `git subtree pull --prefix=upstream/oolite upstream master --squash` in the monthly
   upstream-tracker task; the "rebase, never merge" convention applied to the submodule and is
   retired.
8. **Moving machines** is: push `main`; `bd dolt push` here and `bd dolt pull` there
   (`sync.remote` is already `origin`); reapply the Hermes config from [I5](../infra/5-hermes-goal.md)
   and `hermes skills trust <path>`; log in `claude`.

## Consequences

- ADR-0010's diagram loses its WSL2 half; its "separation is a rule, not a fact" consequence now
  reads: verification runs in a clean worktree, never in an agent worktree, and the GUI tier holds
  a desktop lock.
- "Both legs" and "Linux (WSL2) and Windows" throughout the phase and infra docs become "Windows"
  until Phase 5. I1's base image becomes a one-time MSYS2 provisioning script; I0's WSL2 sizing
  becomes a RAM budget for concurrent game processes.
- Hermes's `terminal` tool must run bash for the skill's scripts and the `bd` guard shim to work;
  that is the first thing to verify on the Windows machine.
- The story generator's seams are rewritten for one platform (no Linux build, no container
  harness, no cross-leg golden check before Phase 5), and the GUI-tier acceptance loses `xvfb-run`.
- The Phase 4 exit gate no longer says "last phase on the single Windows machine" in the sense of
  a second leg: Phase 5 adds two platforms, not one.

## History

ADR-0007 (Ubuntu host) → ADR-0010 (Windows + WSL2) → this (Windows only). ADR-0014 said
"submodules are pinned"; superseded here by the subtree posture.
