# I0 — Machines and network

**Status:** not started · **Gates:** [Phase 0](../phases/0-safety-net.md) entry
**Decisions:** [ADR-0007](../decisions/0007-ubuntu-agent-host.md) (Ubuntu agent host)

## Goal

An inventory of every machine that will run agents, builds, goldens, or the GUI tier, with enough
detail to size the golden harness and to answer the one question the plan currently leaves open:
**is the Ubuntu host a VM on the Windows box or its own hardware?**

## Inventory

Fill in. Unknown is a valid entry; a blank is not.

| Name | OS / version | Arch | CPU cores | RAM | Disk (NVMe?) | GPU | VM or bare metal | Network (LAN / Tailscale) | Roles | TCC grants held |
|---|---|---|---|---|---|---|---|---|---|---|
| ubuntu-agent | Ubuntu ? | x86-64 | ? | ? | ? | ? | **?** | ? | Gas City + agents; Linux build; goldens; ASan/UBSan; Linux runner | n/a |
| windows-build | Windows ? | x86-64 | ? | ? | ? | ? | bare metal | ? | Windows runner: MSYS2 UCRT64 build + Windows goldens | n/a |
| mac | macOS 26.x | arm64 | ? | ? | ? | Apple | bare metal | ? | Phase 3+: macOS build + PyAutoGUI tier; planning | Accessibility, Screen Recording: **not yet granted** |
| inference | — | — | — | — | — | — | rented / LAN | URL in config | OpenAI-compatible endpoint ([ADR-0005](../decisions/0005-defer-dgx-spark.md)) | n/a |

## Sizing notes

- Twenty golden scenarios means twenty game processes, each holding a GL context under Xvfb with
  Mesa `llvmpipe`. No GPU needed for GL 2.1 compatibility profile; **RAM is the binding
  constraint**, and llvmpipe is slow. A real GPU with headless EGL is the upgrade path if scenario
  wall-clock becomes the bottleneck.
- The Ubuntu host does double duty (agents + verification). Runner jobs run in containers; agent
  worktrees live outside them. A build that reads a tree an agent is mutating proves nothing.
- If ubuntu-agent is a VM on windows-build, both of the above compete with the Windows runner for
  the same RAM and the workspace separation is one hypervisor away from being violated. Record the
  answer in [ADR-0007](../decisions/0007-ubuntu-agent-host.md) once known.

## Secrets and authority

- Frontier API keys and runner tokens live on the agent host. Agents execute arbitrary code.
  Expansion content (Tier-3 corpus) is untrusted input. Rule from
  [execution-model §5.5](../execution-model.md): no agent that reads corpus content holds write
  authority or secrets. Decide *where* the scan sandbox runs (a container with no repo mount and no
  environment secrets is sufficient).
- Runner tokens: one per machine, scoped to the mirror/repo the runners serve
  ([ADR-0008](../decisions/0008-forge-and-runners.md)).

## Verification

- [ ] Every row in the inventory has no `?` left
- [ ] VM-or-bare-metal answered and recorded in ADR-0007
- [ ] All three machines reach each other and the forge over the chosen network
- [ ] Mac: Accessibility + Screen Recording granted to the terminal/runner app that will host PyAutoGUI (once, interactively)
- [ ] Windows: interactive desktop session available to the runner service (PyAutoGUI needs it)

## Status log

- 2026-09-06 — Created. Nothing filled in yet.
