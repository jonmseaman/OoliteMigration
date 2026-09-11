# I0 — The machine and its checklist

**Status:** not started · **Gates:** [Phase 0](../phases/0-safety-net.md) entry
**Decisions:** [ADR-0010](../decisions/0010-single-windows-machine.md) (one Windows machine until Phase 5), [ADR-0017](../decisions/0017-native-windows-subtree.md) (everything native, no WSL2)

## Goal

An inventory of the one Windows machine that runs the agents, the build, the goldens and the GUI
tier through Phase 4, a RAM budget for what shares it, and the one-time checklist Jon works before
the first fleet run; plus the Mac and the Linux environment that join at Phase 5, and the
inference endpoint.

## Inventory

Fill in. Unknown is a valid entry; a blank is not.

| Name | OS / version | Arch | CPU cores | RAM | Disk (NVMe?) | GPU | Roles | Grants held |
|---|---|---|---|---|---|---|---|---|
| windows | Windows 11 Pro 25H2 (26200.9445.260908) | x86-64 | 2 | 8 GiB | 128 GiB Premium SSD P10 (~500 IOPS, 100 MB/s); **no local NVMe at this size** | none; Mesa llvmpipe software GL | Hermes `/goal` + Claude Code + `bd` + worktrees; MSYS2 UCRT64 build; goldens (native processes, Mesa llvmpipe); PyAutoGUI tier; merge queue | RDP as `azureuser`; SSH key from the Mac |
| mac | macOS 26.x | arm64 | ? | ? | ? | Apple | **Phase 5 onward:** macOS build + PyAutoGUI tier; planning until then | Accessibility, Screen Recording: **not yet granted** |
| linux | container or rented box | x86-64 | — | — | — | — | **Phase 5 onward:** Linux build + goldens | n/a |
| inference | — | — | — | — | — | — | OpenAI-compatible endpoint ([ADR-0005](../decisions/0005-defer-dgx-spark.md)), rented or LAN; URL in Hermes config | n/a |

## The machine is an Azure VM

Since 2026-09-11 the `windows` row is not a physical desktop but an Azure VM, because Jon has no
access to the desktop. Provisioned and recovered with `az` from the Mac; see
[`tools/azure/`](../../tools/azure/).

| Field | Value |
|---|---|
| Resource | `OoliteConversion`, resource group `WINDEV`, `eastus`, zone 1 |
| Subscription | Pay-As-You-Go (`14b84d2b-…`). The default `Microsoft Imagine` subscription denies `Microsoft.Network` and `Microsoft.Compute`; `az account set` first. |
| Size | `Standard_D2s_v3` — 2 vCPU, 8 GiB |
| Public IP | 51.8.88.44; NSG `OoliteConversion-nsg` allows 22 and 3389 **from `*`** |
| Admin | `azureuser`; `licenseType: Windows_Client` (Azure Hybrid Benefit) |

**This size is below what the plan assumes.** [I5](5-hermes-goal.md) sets
`delegation.max_concurrent_children = 5`; 2 vCPU / 8 GiB supports **1**, and Jon set concurrency to 1
on 2026-09-11 for bring-up. Any Tier-A/Tier-B timing measured here is a single-worker number and
does not predict the fleet — the parallel case is the workload that matters.

**Quota ceiling.** `Total Regional vCPUs` in `eastus` is **10**, and `standardDDSv5Family` is **0**,
so a `D4ds_v5` resize is rejected outright. `Ddsv6` has a limit of 10, making `Standard_D8ds_v6`
(8 vCPU / 32 GiB / local NVMe) the largest in-quota target. Anything above 10 vCPU needs a
quota-increase request first.

**Two open risks this introduces:**

- *No console session.* The I0 checklist below assumes a logged-in, unlocked desktop. An Azure VM
  has no physical console: disconnecting RDP takes the desktop away, which the checklist says fails
  the GUI tier silently. The GUI tier and the goldens need a fix here (an auto-logon console
  session, or a persistent RDP session that is never disconnected) before they can run unattended.
- *Exposed to the internet.* RDP and SSH accept connections from any source address, on the machine
  that will hold frontier API keys next to agents executing arbitrary code. Narrowing the NSG to
  Jon's egress IP is not yet done.

## Before the first fleet run (Jon, once)

The things an agent cannot do for itself on this machine. Tick them here.

- [ ] **Keep-awake.** Install a keep-awake tool (the Windows equivalent of Amphetamine, e.g.
      Caffeine or PowerToys Awake), disable sleep, hibernation and the lock screen for the account
      that runs the fleet. The GUI tier and the goldens open real windows and need an unlocked,
      logged-in desktop; a locked screen fails them silently. If you use RDP, disconnecting takes
      the desktop away: use a local session or a tool that keeps the console session alive.
- [ ] **MSYS2 UCRT64** installed; `tools/setup-windows.sh` (Phase 0 item 0.2) run once. Until it
      exists: upstream's `ShellScripts/Windows/install_deps.sh clang`, plus `mingw-w64-ucrt-x86_64-mesa`
      (the llvmpipe `opengl32.dll`), `ccache`, `jq`, `python` with `pytest` and `pyautogui`.
- [ ] Windows git: `core.autocrlf=false`, `core.longpaths=true`; clone to a short path on NVMe.
      The repo's `.gitattributes` keeps scripts LF.
- [ ] Remotes on the clone: `fork` = `jonmseaman/oolite`, `upstream` = `OoliteProject/oolite`
      (local git config, not in the repo).
- [ ] `bd` (Windows binary) installed; `bd dolt pull` after a `bd dolt push` from the Mac
      (`sync.remote` is `origin`).
- [ ] Hermes installed natively; the [I5](5-hermes-goal.md) config reapplied;
      `hermes skills trust <repo path>`; verify its `terminal` tool runs bash from the MSYS2
      UCRT64 shell (the skill's scripts and the `bd` guard shim are bash).
- [ ] `claude` CLI installed and logged in (for `reevaluate.sh` and the frontier lane).
- [ ] Frontier API key and the inference endpoint URL in place; no secrets in the repo.
- [ ] Phase 5 only: Accessibility and Screen Recording granted on the Mac to the app that will host
      PyAutoGUI; signing identity; a Linux build environment reachable.

## RAM budget

Everything competes for one machine's RAM, and RAM is the binding constraint. Fill in the numbers
once measured; they set the concurrency caps.

| Consumer | Sizing note | Cap |
|---|---|---|
| Golden scenarios | one game process each, GL context under Mesa llvmpipe (software rasteriser, memory-hungry); measure one process, divide the headroom | `N` in `tests/golden/run.sh` |
| Agents | P concurrent workers × (agent CLI + worktree + build dir); `ccache` shared | `delegation.max_concurrent_children` |
| Build | one MSYS2 build at a time per worktree; `ccache` on NVMe | — |
| GUI tier | exclusive: holds the desktop lock; nothing else that opens a window runs meanwhile | Tier C and nightly only ([ADR-0017](../decisions/0017-native-windows-subtree.md)) |

## Separation on one box

- Verification (Tier B, Tier C, `accept.sh`) runs in a fresh clean worktree, never in an agent
  worktree. A build that reads a tree an agent is mutating proves nothing.
- The GUI tier takes a desktop lock (`tools/gui-lock`); the goldens do not need one (they are
  driven over TCP, not by input) but do need the desktop unlocked.
- Worktrees and build dirs live on NVMe under the repo's `.worktrees/`.

## Secrets and authority

- Frontier API keys live on this machine, next to agents that execute arbitrary code. Expansion
  content (Tier-3 corpus) is untrusted input. Rule from
  [execution-model §5.5](../execution-model.md): no agent that reads corpus content holds write
  authority or secrets. The scan sandbox is a separate user account or VM with no repo checkout
  and no environment secrets.

## Verification

- [ ] Every row in the inventory has no `?` left
- [ ] Every box in the checklist above is ticked
- [ ] The RAM budget table has measured numbers; N goldens run concurrently while a build runs
- [ ] The machine reaches the inference endpoint
- [ ] Phase 5 only: Mac grants held; Linux environment reachable

## Status log

- 2026-09-06 — Created with a three-machine inventory.
- 2026-09-10 — Collapsed to one Windows machine until Phase 5 (ADR-0010).
- 2026-09-11 — WSL2 dropped; everything native; checklist added (keep-awake, MSYS2, logins, `bd dolt`); Linux joins at Phase 5 (ADR-0017).
- 2026-09-11 — The `windows` machine is an Azure VM (`OoliteConversion`, `Standard_D2s_v3`), inventory filled in, quota ceiling and two risks recorded; concurrency set to 1.
