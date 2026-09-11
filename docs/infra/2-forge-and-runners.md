# I2 — Forge and CI runners

**Status:** not started; [ADR-0008](../decisions/0008-forge-and-runners.md) decided (GitHub origin + Forgejo mirror) · **Gates:** Phase 0 items 0.3, 0.10

## Goal

Two self-hosted runners on the one Windows machine (native and WSL2), a third on the Mac from
Phase 5, behind whichever forge ADR-0008 settles on, with the merge-queue gate able to trigger a run
and block on its exit status.

## The decision

ADR-0008, decided by default under ADR-0013: GitHub stays `origin` for upstream collaboration; a
Forgejo push-mirror owns CI and the self-hosted runners; the merge-queue gate targets Forgejo. Runners
never attach to GitHub, so fork PRs can never reach them. Jon's part: create the Forgejo instance
or account and issue runner tokens (ADR-0013 responsibility 2); an agent does the rest.

## Topology

| Machine | Runner label | Runs |
|---|---|---|
| windows / WSL2 | `self-hosted, linux, x64` | Linux build; golden harness; ASan/UBSan; jobs in Docker containers |
| windows / native | `self-hosted, windows, x64` | MSYS2 UCRT64 build + Windows goldens + PyAutoGUI tier |
| mac | `self-hosted, macos, arm64` | Phase 5 onward: macOS build + PyAutoGUI tier |

Both Windows-machine runners share RAM; see [I0](0-machines.md) for the WSL2 caps.

Tiering across runners:

| Tier | Where | Proves |
|---|---|---|
| B (per PR) | WSL2 runner | Linux build + fast goldens; catches most translation breakage |
| C (per merge batch) | + native Windows runner (+ mac from Phase 5) | native Windows build **and** Windows goldens; ASan/UBSan; every supported platform |

Cross-compiling Windows from WSL2 is unnecessary: the native Windows build is on the same machine.
The only reason to consider it is a Linux→Windows compile smoke inside Tier B; add that only if
Windows-specific compile breakage shows up often enough between Tier B and Tier C to matter.

## Wiring the merge-queue gate

`tools/merge-queue` ([I3](3-fleet.md)) calls one script to run Tier C on a candidate branch. Keep
it thin: it schedules and waits, it does not build.

GitHub form:

```bash
gh workflow run verify.yml --ref "$BRANCH" \
  && gh run watch "$(gh run list --workflow=verify.yml --branch="$BRANCH" \
       --limit=1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

Forgejo form: the equivalent against the Forgejo Actions API (`tea` or `curl`); this is the one
that ships, since ADR-0008 puts CI on the mirror.

## Verification

- [ ] Forgejo mirror receives every push to `origin` within a minute
- [ ] Each runner picks up a job with its label and reports status back
- [ ] The gate script returns nonzero on a red run and zero on a green one
- [ ] WSL2 runner jobs execute in containers; no job can see an agent worktree; the native runner's checkout is untouched by agents
- [ ] If the repo is public: no fork PR can reach a self-hosted runner

## Status log

- 2026-09-06 — Created from AI_EXECUTION_PLAN §14. Blocked on ADR-0008.
- 2026-09-10 — Topology collapsed to one machine until Phase 5 (ADR-0010). Forge decided (ADR-0013).
