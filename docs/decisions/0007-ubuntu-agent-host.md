# ADR-0007: Agents run on an Ubuntu host; the Windows box is a build runner

**Status:** Accepted · **Date:** 2026-09-05 · **Open detail:** VM or bare metal (see below)

## Context

An earlier version of the plan put agents on the Windows x86-64 box with Docker Desktop / WSL2 for
the Linux golden harness. Gas City needs tmux and a Unix runtime.

## Decision

```
Ubuntu x86-64 host ─────── Gas City + agents + worktrees; Linux build; golden harness; ASan/UBSan
Windows x86-64 box ─────── self-hosted runner: MSYS2 UCRT64 build + Windows goldens
Apple Silicon Mac ──────── Phase 3 onward: macOS build + PyAutoGUI tier (needs TCC grants)
Inference endpoint ─────── OpenAI-compatible URL behind one config value (ADR-0005)
```

Two rules for the Ubuntu host, which does double duty: agents and verification must not share a
workspace (runner jobs in containers, agent worktrees outside them); size it for ~20 concurrent
game instances each holding a GL context under Xvfb + llvmpipe, where RAM is the binding constraint.

## Consequences

- Removes the WSL2 layer entirely; the Linux harness runs natively.
- **Unresolved:** the plan text says both "Ubuntu VM" and "Ubuntu box". If it is a VM on the
  Windows machine, the double-duty sizing and the workspace-separation rule are both harder, and the
  Windows runner competes with it for the same RAM. Answer in [infra/0-machines.md](../infra/0-machines.md).
- The recurring lesson, stated three times in the original plan and worth keeping: the agent host is
  not the inference host, not the build host, and not the verification host. Keep the control plane
  in one place and fan the *work* out.

## History

`AI_EXECUTION_PLAN.md` §12 (Windows host), §14 preamble (amendment to Ubuntu), §14.3 (topology).
