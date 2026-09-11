# ADR-0016: No CI/CD forge for now; Tier B and Tier C run locally

**Status:** Accepted · **Date:** 2026-09-10 · **Defers:** [ADR-0008](0008-forge-and-runners.md)

## Context

ADR-0008 settled the forge question (GitHub origin, Forgejo mirror owning CI and self-hosted
runners). Jon's decision (2026-09-10): with the single Windows machine, no CI/CD forge at all for
now. Local builds and local golden runs only.

## Decision

- **No forge, no runners, no Actions** until further notice. ADR-0008 is deferred, not reversed;
  its analysis stands for when a second machine (the Mac, Phase 5) or a public fork makes CI
  worth having.
- **`tools/tier-b.sh` and `tools/tier-c.sh` are the verification**, run locally: Tier B in WSL2
  (Linux build + fast goldens), Tier C in WSL2 plus the native Windows build and Windows goldens
  on the same machine.
- **`tools/merge-queue` calls `tools/tier-c.sh` directly** instead of triggering a CI run and
  waiting. The batch-and-bisect logic is unchanged; the gate is a local command.
- **The Reporter reads local results** (the tier scripts' logs and `bd`), not a CI API.
- `origin` on GitHub stays as the backup and rebase point; pushes are manual and gate nothing.

## Consequences

- One fewer service to run and no runner tokens; [I2](../infra/2-forge-and-runners.md) is
  deferred and its verification list moves to "when a forge exists".
- **Verification and agents share a machine and a filesystem.** The separation rule from
  ADR-0010 is now the only thing keeping a build from reading a tree an agent is mutating: Tier
  B/C run in a fresh clone or a dedicated verification worktree, never in an agent worktree. The
  beads-worker `accept.sh` already does this for acceptance.
- **Wall-clock contention is real.** A Tier C run (20 golden containers, ASan, Windows build)
  competes with the agents for RAM and cores. The merge queue should run Tier C at a cadence, not
  per merge request, which is what batching was for anyway.
- The security note in ADR-0008 about fork PRs reaching runners is moot while there are no runners.
- Phase 0's "Reproduce upstream builds in our CI" becomes "reproduce upstream builds locally, both
  legs, from a clean clone, scripted".

## History

ADR-0008 (forge decision), ADR-0010 (single machine).
