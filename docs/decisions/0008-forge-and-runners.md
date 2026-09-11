# ADR-0008: Forge and CI runners — GitHub + self-hosted runners, or self-hosted Forgejo

**Status:** **Accepted** 2026-09-10 as the default under [ADR-0013](0013-decide-up-front-minimise-human.md): the third column below. Jon may override by superseding ADR. · **Date:** 2026-09-06

## Context

Self-hosting is needed for *runners* regardless of forge: GNUstep-from-source dominates hosted runs,
20 golden scenarios launch a real GL game, and the macOS GUI tier needs TCC grants only Jon's Mac
can hold. Argo CD/Workflows are the wrong category (Kubernetes deployment; Windows builds on k8s
are painful). Forgejo Actions is GitHub-Actions-compatible via `act_runner`.

**The recorded recommendation (AI_EXECUTION_PLAN §14.2, 2026-09-05):** keep GitHub, add self-hosted
runners. Reason: upstream lives on GitHub, the plan rebases monthly and upstreams everything that
is not the rewrite, and moving the forge to fix a runner problem is a migration for no gain.

**The stated intent (Jon, 2026-09-06):** set up a self-hosted Forgejo CI/CD pipeline.

**A consideration the original analysis missed:** self-hosted runners attached to a *public* GitHub
repo mean arbitrary code execution from fork PRs on Jon's hardware. Forgejo never receives fork PRs.
So Forgejo is *safer* if the fork ever goes public, which is roadmap open decision 2.

## Options

| | GitHub + self-hosted runners | Self-hosted Forgejo | **GitHub origin + Forgejo mirror for CI** |
|---|---|---|---|
| Upstream collaboration | frictionless | PRs must be re-pushed to GitHub | frictionless (origin unchanged) |
| Fork-PR RCE exposure if public | **yes** | no | no (runners only see the mirror) |
| Merge-queue gate target | `gh workflow run` + `gh run watch` | Forgejo API equivalent | Forgejo API equivalent |
| Third-party actions | `msys2/setup-msys2@v2` etc. | must be pre-provisioned anyway ([infra/1](../infra/1-base-images.md)) | same |
| Extra service to run | none | Forgejo | Forgejo + a push mirror |
| PR status visible on GitHub | yes | no | no — but `tools/merge-queue`, not GitHub checks, is the gate |

## Decision (taken by default, 2026-09-10)

The third column: **GitHub stays `origin` for upstream collaboration; Forgejo is a push mirror that
owns CI and the self-hosted runners; the merge-queue gate talks to Forgejo.** It satisfies the original
reasoning and the stated intent, and closes the RCE exposure. Cost: one more service and a mirror
to keep healthy.

Decided before any runner is attached, as the security note requires. [I2](../infra/2-forge-and-runners.md) is unblocked.

## History

`AI_EXECUTION_PLAN.md` §14.1, §14.2, §14.6 security note.
