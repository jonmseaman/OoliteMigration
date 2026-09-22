# Nightly and weekly schedule log

One line per scheduled run, appended by [`tools/nightly.sh`](../../tools/nightly.sh).

There is no forge and no hosted scheduler ([ADR-0016](../decisions/0016-no-forge-local-verification.md)),
so the nightly Tier C and the weekly Tier 3 corpus are two Windows scheduled tasks on the fleet
machine, registered by [`tools/install-scheduled-tasks.ps1`](../../tools/install-scheduled-tasks.ps1)
and documented in [the workstation runbook](../infra/windows-workstation-setup.md#the-nightly-and-weekly-schedule).

The full output of each run is kept under `build/nightly/<job>-<stamp>.log`, which is gitignored:
a 02:00 job must never dirty the shared checkout, because `accept.sh` refuses to fast-forward a
dirty root and that would block acceptance for the whole fleet.

`VERDICT` is **not** the exit status. A job is GREEN only if its runner also printed the
completion marker it emits after really finishing — `tier-c: GREEN` for Tier C, a non-zero
expansion count in the corpus report for Tier 3. A run that exits 0 having done nothing is
recorded RED, because a schedule nobody watches is exactly where a vacuous green survives.

| started | job | verdict | rc | wall | log | note |
|---|---|---|---|---|---|---|
| 2026-09-19 03:04:35 | tier-c | RED | 1 | 65s | `build/nightly/tier-c-20260919-030434.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed (pytest rc=1, 1065 passed); full log C:/Users/jon/scoop/apps/msys2/2025- |
| 2026-09-20 02:00:03 | tier-c | RED | 1 | 50s | `build/nightly/tier-c-20260920-020002.log` | rc=1; tier-b: FAIL (stage build): the build failed; last 30 lines above, full log C:/Users/jon/scoop/apps/msys2/2025-12-13/tmp |
| 2026-09-20 03:00:01 | corpus-tier3 | RED | 1 | 6199s | `build/nightly/corpus-tier3-20260920-030001.log` | rc=1; NOTLOADED_DEPS gsagostinho.CobraMkIV                             8.7s  'gsagostinho.CobraMkIV.oxz' is ABSENT from the [s |
| 2026-09-21 02:00:02 | tier-c | RED | 1 | 48s | `build/nightly/tier-c-20260921-020002.log` | rc=1; tier-b: FAIL (stage build): the build failed; last 30 lines above, full log C:/Users/jon/scoop/apps/msys2/2025-12-13/tmp |
