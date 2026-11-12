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

events: no Windows machine

The component-scenario event log (kill, dock, jump) was not recorded: `tests/run.sh component`
runs on Windows, and none was available to this session. T076 and T098 skip their comparison
until a base log exists.
