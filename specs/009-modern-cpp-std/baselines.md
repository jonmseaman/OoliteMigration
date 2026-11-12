# Baselines: spec 009

Measured 2026-11-11 on this Mac (Apple M5, macOS 26, Homebrew clang 23.1.4 builds, clang-tidy
22.1.8) on `oolite-dev` `seriesb/027-modern-cpp` after T004–T008 (`00d44acdc`: C++23, no source
change). Later rows are added by the tasks that measure them (`<metric>@<milestone>`), and
`check.sh bound` compares each with its base row.

## Category counts

From `check.sh <category> --count` (`cast` from one `check.sh cast` run, split by area).

| category | count |
|---|---|
| alloc | 135 |
| ownership | 2007 |
| thread | 7 |
| oofnd | 1505 |
| enum | 179 |
| tbl | 10 |
| cast | 1205 |
| cast@entities | 483 |
| cast@scripting | 144 |
| cast@materials | 131 |
| cast@sdl-debug | 73 |
| cast@core | 368 |
| cast@oofnd | 6 |
| cstring | 66 |
| cstring@entities | 4 |
| cstring@scripting | 4 |
| cstring@materials | 1 |
| cstring@sdl-debug | 6 |
| cstring@core | 12 |
| cstring@oofnd | 39 |
| cstring-types | 815 |

## Measurements

Median and spread (max − min) of five runs, except where noted. Scripts and raw results are in
`.agent-tmp/bench009/` and `.agent-tmp/sanitizers/` (git-ignored).

| metric | median | spread | better |
|---|---|---|---|
| start | 0.702 | 0.053 | lower |
| frame | 3.088 | 0.354 | lower |
| quit | 0.0746 | 0.0026 | lower |
| asan-smoke | 0 | 0 | lower |
| tsan-smoke | 5 | 1 | lower |
| leaks | 288 | 2 | lower |
| tsan-smoke@M2 | 5 | 1 | lower |
| quit@M2-base | 0.0765 | 0.0557 | lower |
| quit@M2 | 0.0766 | 0.0556 | lower |

- **start**: seconds from launching the deployment build until it answers the debug console.
- **frame**: CPU milliseconds per frame (`ps -o cputime` over frames counted by a JS frame
  callback), in flight with 60 extra traders, 15 s, by the method of
  `notes/2026-11-10 Frame Rate Comparison.md` (throwaway `HOME`, `-novsync`, no tick cap,
  1280 × 720). T009 first named frames per second; the note shows frame rate is pinned at the
  120 Hz display rate in both builds, so CPU per frame is the figure that can show a slowdown.
- **quit**: seconds from the harness's `quit()`, sent in that same busy in-flight scene, until the
  run returns (process exit plus the harness's constant clean-up). T009 first named quitting
  during start-up planet generation; sending `quit()` the moment the console answers never
  brought the game down within 60 s, so the busy-scene quit is the measured case.
- **asan-smoke**: ASan reports in a smoke run of a `-Db_sanitize=address` build (debug, LTO off,
  `detect_leaks=0`; the runtime is linked and the report hooks present). One run.
- **tsan-smoke**: ThreadSanitizer warnings in a smoke run of a `-Db_sanitize=thread` build; three
  runs gave 4, 5, 5. They are existing data races: `OOPlanetTextureGenerator::loadTexture()`
  (`OOPlanetTextureGenerator.cpp:418`), `OOStandaloneAtmosphereGenerator::loadTexture()`
  (`OOStandaloneAtmosphereGenerator.cpp:233`) and `RanrotWithSeed` (`legacy_random.cpp:91`).
- **leaks**: leaks reported by `leaks --atExit` over a smoke run of the test build; three runs
  gave 288, 286, 288 (18,816 bytes in the median run).

## Same-session comparison, 2026-11-12

`oolite-dev` `518520d43` (C++20, before T004) against `c1413acaf` (C++23 plus T014–T019), both
deployment builds, five rounds each, run one after the other with nothing else building
(`.agent-tmp/bench009/cmp.log`). Each row's spread is that build's own.

| metric | C++20 base | branch at T019 | difference |
|---|---|---|---|
| frame (CPU ms per frame) | 2.346 (0.209) | 2.374 (0.226) | +1.2% |
| start (s) | 0.611 (0.849) | 0.623 (0.591) | +2.0% |
| quit (s) | 0.0732 (0.0046) | 0.0755 (0.0061) | +3.1% |

No difference larger than either build's spread. The same script gave `frame` 3.088 for the base
rows above, measured earlier in the same day: machine state moves the absolute numbers by about a
third between sessions, far more than the spread inside one. **So a later bound is checked against
the base re-measured in the same session**, from a `git worktree` of `518520d43` (the method of
this section), not against the base rows above; those stay as the record of T009.

## Fork against upstream, 2026-11-12

Today's branch (`f080599ca`, T026) against upstream's Objective-C build (`upstream/oolite`
`148575aab`, the build of `notes/2026-11-10 Frame Rate Comparison.md`), both deployment builds,
same machine and session.

By `bench009.py`, five alternating rounds: CPU per frame with 60 extra ships 3.06 (fork, spread
0.21) against 3.25 (upstream, 0.32), −5.8%; start-up 0.655 s against 0.785 s, −17%; quit 0.075 s
against 0.073 s.

By the note's own `fps_bench.py`, three alternating rounds, CPU ms per frame, median (range):

| scene | fork | upstream | fork vs upstream | note, 2026-11-10 |
|---|---|---|---|---|
| docked | 0.65 (0.60–1.09) | 0.78 (0.77–1.21) | −16% | −21% |
| in flight | 2.06 (1.51–2.20) | 1.76 (1.68–2.39) | +17%, ranges overlap | −7% |
| +60 ships | 2.87 (2.72–3.03) | 3.16 (3.12–3.25) | −9% | −22% |
| ~120 ships | 2.27 (2.01–2.44) | 2.76 (2.58–2.84) | −18% | −23% |

The fork still uses less CPU per frame than upstream wherever the ranges separate; in-flight is
within noise (both builds' first round was slow, frame rates 100–117 fps). With the C++20 base
and the branch equal in the same session (above), the work so far has not changed the gap.

## JS API snapshot

Generated by the snapshot tool restored from git into `.agent-tmp/js-api/` (T013), against the
test build of the tree above: 140 globals (86 Oolite, 54 ECMAScript), 39 native classes. Two runs
gave byte-identical files (`base.json`, `base2.json`).

| js-api | 58a6a19c262330e147449abcc0a05f75ae89284b5cff910e85caecbad506cdb4 |
|---|---|

## M2 (US3), 2026-11-12

TSan smoke at `b446e6b9e` (T028): 5, 4, 5 warnings (the same three existing races). Quit, same
session, five alternating rounds: C++20 base `518520d43` 0.0765 s against the branch (with the
work manager's `shutdown()` join on the quit path) 0.0766 s; the rows above, `quit@M2-base` being
the base re-measured in that session (`check.sh bound quit@M2 --base quit@M2-base`).

thread names: OOAsyncWorkManager thread 1 … OOAsyncWorkManager thread 8, loggerThread, alsoft-mixer, CVDisplayLink, com.apple.NSEventThread (lldb `thread list` on the running test build)

events: no Windows machine

The component-scenario event log (kill, dock, jump) was not recorded: `tests/run.sh component`
runs on Windows, and none was available to this session. T076 and T098 skip their comparison
until a base log exists.
