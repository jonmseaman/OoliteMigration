# ADR-0010: One Windows x86-64 machine (native + WSL2) for everything until Phase 5

**Status:** Accepted · **Date:** 2026-09-10 · **Supersedes:** [ADR-0007](0007-ubuntu-agent-host.md)

## Context

ADR-0007 put the agents on a separate Ubuntu host with the Windows box as a build runner, and left
open whether that host was a VM or bare metal. With Apple Silicon resequenced to Phase 5
([ADR-0009](0009-apple-silicon-after-runtime-removal.md)), every target before Phase 5 is x86-64.
Jon's decision (2026-09-10): for simplicity, everything up to the Apple Silicon phase runs on a
single Windows 64-bit machine.

Two facts constrain how that is laid out. The agent's inner loop (Tier A: single-TU compile,
ccache, worktrees) has to be seconds and offline, and it is Linux-shaped. And upstream's build tooling, `build_gnustep.sh`,
`launch_snapshot.py` with Xvfb, and the sanitizer story (UBSan is incomplete on Windows toolchains)
are all Linux-shaped.

## Decision

One physical machine, two environments:

```
Windows x86-64 machine
├─ native Windows ──── MSYS2 UCRT64 build; Windows goldens; Windows self-hosted runner;
│                      PyAutoGUI tier (needs the interactive desktop session)
└─ WSL2 (Ubuntu) ───── agents (Claude Code / Hermes) + worktrees + bd; Linux build; golden harness (Xvfb + llvmpipe);
                       ASan/UBSan; Linux self-hosted runner, jobs in Docker containers
Inference endpoint ─── OpenAI-compatible URL behind one config value (ADR-0005), rented or LAN
Apple Silicon Mac ──── joins at Phase 5 only
```

Keep the Linux leg. It is where the agents' fast inner loop lives anyway, it keeps parity with
upstream's primary CI platform, and it is where the sanitizers are trustworthy. The alternative,
Windows-only verification, is recorded as rejected for now; revisit if WSL2 overhead becomes the
bottleneck.

## Consequences

- **Separation is now inside one box, so it is a rule, not a fact.** Runner jobs execute in
  containers in WSL2; agent worktrees live in the WSL2 filesystem outside those containers; the
  native Windows runner builds from its own checkout that no agent ever touches. A build that reads
  a tree an agent is mutating proves nothing.
- **RAM is the binding constraint, more than before.** Agents, two build legs, ccache, and up to 20
  concurrent game instances under llvmpipe share one machine. Size WSL2 explicitly (`.wslconfig`
  memory and processor caps) so it cannot starve the Windows runner, and size the golden
  concurrency cap to what is left. This replaces ADR-0005's "buy a Linux CI runner" with "put the
  RAM and NVMe in this machine".
- The definition of done reads "every supported platform": Linux and Windows through Phase 4,
  three platforms from Phase 5. The three-way build matrix does not exist before then.
- The forge decision ([ADR-0008](0008-forge-and-runners.md)) is unaffected; both runners now carry
  the same machine's hostname, which is fine.
- The "agent host ≠ build host ≠ verification host" principle from the original plan is
  deliberately relaxed for simplicity. The compensating controls are the two bullets above.
- The infra inventory ([I0](../infra/0-machines.md)) collapses to one row until Phase 5.

## History

`AI_EXECUTION_PLAN.md` §12 originally proposed Windows + WSL2; §14 moved to Ubuntu; ADR-0007
recorded that; this ADR returns to a single Windows machine, now with the Linux leg explicitly
inside WSL2 and the Mac deferred to Phase 5.

> **Amended 2026-09-10 by [ADR-0014](0014-claude-code-opencode-beads.md).** The original text
> justified WSL2 by Gas City's need for a Unix runtime. Gas City is gone; the layout is unchanged
> because the reason that survives is the agents' Tier A inner loop and worktrees living next to the
> Linux build and ccache.

> **Amended 2026-09-11 by [ADR-0017](0017-native-windows-subtree.md).** The WSL2 leg is dropped:
> agents, worktrees, `bd`, the build, the goldens and the GUI tier all run natively on Windows, and
> Linux joins at Phase 5 with macOS. The "self-hosted runner" rows in the diagram were already void
> under ADR-0016 (no forge).
