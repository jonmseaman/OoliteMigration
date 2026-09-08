# I2 — Forge and CI runners

**Status:** blocked on [ADR-0008](../decisions/0008-forge-and-runners.md) · **Gates:** Phase 0 items 0.3, 0.10

## Goal

Three self-hosted runners, one per platform, behind whichever forge ADR-0008 settles on, with the
Refinery gate able to trigger a run and block on its exit status.

## The decision first

ADR-0008 records a conflict: the plan recommends GitHub + self-hosted runners; the stated intent is
self-hosted Forgejo; the recommended reconciliation is GitHub as `origin` with a Forgejo push-mirror
owning CI. **Decide before attaching any runner.** The reason is security: self-hosted runners on a
public GitHub repo execute fork-PR code on your hardware.

## Topology

| Machine | Runner label | Runs |
|---|---|---|
| ubuntu-agent | `self-hosted, linux, x64` | Linux build; golden harness; ASan/UBSan |
| windows-build | `self-hosted, windows, x64` | MSYS2 UCRT64 build + Windows goldens |
| mac | `self-hosted, macos, arm64` | Phase 3 onward: macOS build + PyAutoGUI tier |

Tiering across runners:

| Tier | Where | Proves |
|---|---|---|
| B (per PR) | ubuntu-agent | Linux build + fast goldens; catches most translation breakage |
| C (per merge batch) | + windows-build + mac | native Windows build **and** Windows goldens; ASan/UBSan; the full three-platform gate |

Cross-compiling Windows from Ubuntu is at best an early-warning signal: `clang.ini` is a native
file, `src/meson/meson.build` dispatches on `host_os == 'windows'`, it forces open decision 7 early,
and a cross-compiled binary cannot run goldens on Linux. Add a cross-compile smoke to Tier B only if
Windows-specific compile breakage shows up in practice.

## Wiring the Refinery gate

Gates are pluggable commands. Keep the gate thin: it schedules and waits, it does not build.

GitHub form:

```bash
gh workflow run verify.yml --ref "$BRANCH" \
  && gh run watch "$(gh run list --workflow=verify.yml --branch="$BRANCH" \
       --limit=1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

Forgejo form: the equivalent against the Forgejo Actions API (`tea` or `curl`); to be written when
ADR-0008 lands.

## Verification

- [ ] ADR-0008 status is Accepted
- [ ] Each runner picks up a job with its label and reports status back
- [ ] The gate script returns nonzero on a red run and zero on a green one
- [ ] Runner jobs execute in containers on ubuntu-agent; no job can see an agent worktree
- [ ] If the repo is public: no fork PR can reach a self-hosted runner

## Status log

- 2026-09-06 — Created from AI_EXECUTION_PLAN §14. Blocked on ADR-0008.
