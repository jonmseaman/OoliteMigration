# I0 — Machines and network

**Status:** not started · **Gates:** [Phase 0](../phases/0-safety-net.md) entry
**Decisions:** [ADR-0010](../decisions/0010-single-windows-machine.md) (one Windows machine until Phase 5; supersedes ADR-0007)

## Goal

An inventory of the one machine that runs agents, both build legs, goldens, and the GUI tier
through Phase 4, sized so the pieces sharing it do not starve each other; plus the Mac that joins
at Phase 5 and the inference endpoint.

## Inventory

Fill in. Unknown is a valid entry; a blank is not.

| Name | OS / version | Arch | CPU cores | RAM | Disk (NVMe?) | GPU | Network | Roles | Grants held |
|---|---|---|---|---|---|---|---|---|---|
| windows | Windows ? | x86-64 | ? | ? | ? | ? | ? | **native:** MSYS2 UCRT64 build; Windows goldens; Windows runner; PyAutoGUI tier · **WSL2:** agents (Claude Code / Hermes) + worktrees + `bd`; Linux build; golden harness; ASan/UBSan; Linux runner (Docker) | interactive desktop session for the runner service (PyAutoGUI) |
| mac | macOS 26.x | arm64 | ? | ? | ? | Apple | ? | **Phase 5 onward:** macOS build + PyAutoGUI tier; planning until then | Accessibility, Screen Recording: **not yet granted** |
| inference | — | — | — | — | — | — | URL in config | OpenAI-compatible endpoint ([ADR-0005](../decisions/0005-defer-dgx-spark.md)), rented or LAN | n/a |

## WSL2 sizing

Everything competes for one machine's RAM, and RAM is the binding constraint:

| Consumer | Where | Sizing note |
|---|---|---|
| Golden scenarios | WSL2 containers | up to 20 concurrent game processes, each with a GL context under Xvfb + Mesa `llvmpipe`; no GPU needed for GL 2.1 compat, but llvmpipe is slow and memory-hungry |
| Agents | WSL2 | N concurrent `run-story` slots × (agent CLI + worktree + build dir); cap is the wrapper's parallelism flag |
| Linux build + ccache | WSL2 | shared cache volume |
| Windows build + Windows goldens | native | must keep enough headroom that WSL2 cannot take it |

Set `.wslconfig` `memory=` and `processors=` explicitly so WSL2 has a hard ceiling; size the golden
concurrency cap and the `run-story` parallelism to what is left inside it. A real GPU with headless EGL inside
WSL2 is the upgrade path if scenario wall-clock becomes the bottleneck.

## Separation inside one box

- Runner jobs run in Docker containers in WSL2. Agent worktrees live in the WSL2 filesystem outside
  those containers. The native Windows runner builds from its own checkout that no agent touches.
- The WSL2 filesystem, not `/mnt/c`, holds worktrees and build dirs (cross-filesystem I/O is slow).

## Secrets and authority

- Frontier API keys and runner tokens live on this machine, next to agents that execute arbitrary
  code. Expansion content (Tier-3 corpus) is untrusted input. Rule from
  [execution-model §5.5](../execution-model.md): no agent that reads corpus content holds write
  authority or secrets. The scan sandbox is a container with no repo mount and no environment
  secrets.
- Runner tokens: one per runner, scoped to the mirror/repo the runners serve
  ([ADR-0008](../decisions/0008-forge-and-runners.md)).

## Verification

- [ ] Every row in the inventory has no `?` left
- [ ] `.wslconfig` caps set; Windows build succeeds while 20 golden containers run in WSL2
- [ ] Windows: runner service has an interactive desktop session (PyAutoGUI needs it)
- [ ] The machine reaches the forge and the inference endpoint
- [ ] Phase 5 only: Mac reaches the forge; Accessibility + Screen Recording granted to the app that will host PyAutoGUI

## Status log

- 2026-09-06 — Created with a three-machine inventory.
- 2026-09-10 — Collapsed to one Windows machine until Phase 5 (ADR-0010).
