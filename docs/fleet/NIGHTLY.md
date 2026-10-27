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
| 2026-09-22 02:00:02 | tier-c | RED | 1 | 15s | `build/nightly/tier-c-20260922-020002.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-09-29 02:00:03 | tier-c | RED | 1 | 313s | `build/nightly/tier-c-20260929-020003.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-09-30 02:00:09 | tier-c | RED | 1 | 1306s | `build/nightly/tier-c-20260930-020009.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-10-01 02:00:28 | tier-c | RED | 1 | 141s | `build/nightly/tier-c-20261001-020025.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-10-02 02:00:05 | tier-c | RED | 1 | 59s | `build/nightly/tier-c-20261002-020005.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-10-03 02:00:04 | tier-c | RED | 1 | 50s | `build/nightly/tier-c-20261003-020004.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-10-05 02:00:02 | tier-c | RED | 1 | 29s | `build/nightly/tier-c-20261005-020002.log` | rc=1; tier-b: FAIL (stage guardrails): tools/guardrails.sh found a violation of CLAUDE.md rules 1/2/3/8 (see above); this is t |
| 2026-10-06 02:00:08 | tier-c | RED | 1 | 2073s | `build/nightly/tier-c-20261006-020007.log` | rc=1; tier-b: FAIL (stage build): source file 'upstream/oolite/src/Core/OOOXZManager+ObjCBridge.h' is NEWER than the binary; t |
| 2026-10-07 02:09:12 | tier-c | RED | 1 | 3702s | `build/nightly/tier-c-20261007-020912.log` | rc=1; tier-b: FAIL (stage build): source file 'upstream/oolite/src/Core/Entities/ShipEntity+ObjCBridge.h' is NEWER than the bi |
| 2026-10-08 02:00:02 | tier-c | RED | 1 | 983s | `build/nightly/tier-c-20261008-020002.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard2of8.log (pytest rc=1, 133 passed); full log |
| 2026-10-09 02:06:54 | tier-c | RED | 1 | 1783s | `build/nightly/tier-c-20261009-020654.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-10 02:00:02 | tier-c | RED | 1 | 1777s | `build/nightly/tier-c-20261010-020002.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-11 02:00:03 | tier-c | RED | 1 | 891s | `build/nightly/tier-c-20261011-020002.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-11 03:00:03 | corpus-tier3 | RED | 1 | 3s | `build/nightly/corpus-tier3-20261011-030003.log` | rc=1; NOTLOADED            3   NOTLOADED, no declared dependencies - a real rejection |
| 2026-10-12 02:00:04 | tier-c | RED | 1 | 930s | `build/nightly/tier-c-20261012-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-13 02:00:03 | tier-c | RED | 1 | 86s | `build/nightly/tier-c-20261013-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-14 02:00:04 | tier-c | RED | 1 | 83s | `build/nightly/tier-c-20261014-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-15 02:00:03 | tier-c | RED | 1 | 78s | `build/nightly/tier-c-20261015-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-16 02:00:03 | tier-c | RED | 1 | 83s | `build/nightly/tier-c-20261016-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-17 02:01:50 | tier-c | RED | 1 | 7139s | `build/nightly/tier-c-20261017-020139.log` | rc=1; tier-b: FAIL (stage build): source file 'upstream/oolite/src/Core/Entities/DustEntity.h' is NEWER than the binary; the b |
| 2026-10-18 03:14:08 | corpus-tier3 | RED | 1 | 78s | `build/nightly/corpus-tier3-20261018-031324.log` | rc=1; NOTLOADED            3   NOTLOADED, no declared dependencies - a real rejection |
| 2026-10-18 02:05:14 | tier-c | RED | 1 | 6572s | `build/nightly/tier-c-20261018-020513.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-19 02:00:03 | tier-c | RED | 1 | 838s | `build/nightly/tier-c-20261019-020003.log` | rc=1; tier-b: FAIL (stage tests): tests/golden failed in pytest-tests_golden.shard0of8.log (pytest rc=1, 134 passed); full log |
| 2026-10-20 02:00:04 | tier-c | RED | 1 | 926s | `build/nightly/tier-c-20261020-020003.log` | rc=1; tier-b: FAIL (stage tests): tools failed in pytest-tools.shard0of6.log (pytest rc=1, 37 passed); full log C:/Users/jon/s |
| 2026-10-21 02:00:06 | tier-c | RED | 1 | 2357s | `build/nightly/tier-c-20261021-020006.log` | rc=1; tier-c: FAIL (stage tier-b): tier-b exited 1; full log C:/Users/jon/scoop/apps/msys2/2025-12-13/tmp/tier-c-3470024-6zqE2 |
| 2026-10-22 02:00:03 | tier-c | RED | 1 | 1591s | `build/nightly/tier-c-20261022-020003.log` | rc=1; tier-c: FAIL (stage tier-b): tier-b exited 1; full log C:/Users/jon/scoop/apps/msys2/2025-12-13/tmp/tier-c-655-pc2BWm/ti |
| 2026-10-26 02:00:02 | tier-c | RED | 1 | 35s | `build/nightly/tier-c-20261026-020002.log` | rc=1; tier-b: FAIL (stage foundation): Foundation left in unfenced source (the census above); full log C:/Users/jon/scoop/apps |
