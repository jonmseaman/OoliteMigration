# Perf: frame rate and CPU per frame, fork vs upstream on macOS

| | |
|---|---|
| **Type** | Performance measurement |
| **Fork build** | `seriesb/026-migration-completion` at `977698a93`, `build/meson_deployment` |
| **Upstream build** | `upstream/oolite` at `148575aab` (2026-11-05), `build/meson_deployment` |
| **Machine** | Apple M5 (Mac17,2), 32 GB, macOS 26.6, 120 Hz display |
| **Date** | 2026-11-10 |

## Summary

- **Frame rate is the same in both builds.** Both hold at the 120 Hz display rate with V-Sync off
  and the game's tick cap removed.
- **The fork uses less CPU per frame:** about 21–23% less docked and with extra ships, and 7%
  less in plain flight.
- **Worst-case frames are the same:** 25–30 ms spikes in both. The fork's 99th percentile is
  slightly lower in the ship scenes.
- **Neither build was pushed to its limit.** Neither used more than 0.37 of a CPU core, so this
  says nothing yet about maximum frame rate under heavy load.

## Results

Medians of three rounds, alternating fork and upstream. Ranges are in brackets. "Ships" is
`system.allShips.length` at the end of each run.

| Scene | Build | fps | p50 frame (ms) | p99 frame (ms) | Worst frame (ms) | CPU ms per frame | CPU cores | Ships |
|---|---|---|---|---|---|---|---|---|
| Docked | fork | 132 (127–143) | 7.48 | 8.66 | 24.1 | **0.54** (0.54–0.63) | 0.08 | 62 / 76 / 74 |
| | upstream | 134 (134–143) | 7.49 | 8.60 | 9.4 | **0.68** (0.65–0.68) | 0.09 | 73 / 71 / 68 |
| In flight | fork | 118 (116–127) | 8.49 | 9.84 | 29.1 | **1.55** (1.48–1.57) | 0.18 | 63 / 78 / 75 |
| | upstream | 117 (117–127) | 8.50 | 9.90 | 26.5 | **1.67** (1.66–1.81) | 0.20 | 72 / 72 / 74 |
| +60 ships | fork | 117 (116–127) | 8.57 | 10.37 | 28.9 | **2.47** (2.38–2.48) | 0.29 | 162 / 168 / 162 |
| | upstream | 116 (116–126) | 8.51 | 10.90 | 27.6 | **3.16** (2.67–3.22) | 0.37 | 146 / 163 / 173 |
| +250 ships* | fork | 117 (117–126) | 8.53 | 9.98 | 14.6 | **2.11** (2.08–2.29) | 0.25 | 120 / 133 / 122 |
| | upstream | 117 (116–128) | 8.51 | 11.03 | 30.1 | **2.75** (2.20–2.98) | 0.32 | 115 / 112 / 120 |

\* The ships were added within an 8 km radius, so many collided and blew up. Only about 120 were
left, fewer than in the +60 scene. Treat it as a second "about 120–130 ships" sample, not a stress
test.

CPU per frame, fork against upstream: docked −21%, in flight −7%, +60 ships −22%, ~125 ships −23%.
The ranges don't overlap for docked and +60 ships; they overlap slightly in the other two.

## Method

Each run:

1. Stage a private copy of the app with `oolite-dev/tests/launch_snapshot.py` and connect over the
   debug console.
2. Load `Resources/Scenarios/oolite-standard.oolite-save`, which starts docked at Lave.
3. Measure each scene:
   - **Docked:** 10 s.
   - **In flight:** `player.ship.launch()`, wait for `STATUS_IN_FLIGHT` plus 3 s, then 15 s.
   - **+60 ships:** `system.addShips('trader', 60, player.ship.position, 6000)`, wait 3 s, then
     15 s.
   - **+250 ships:** add 190 more traders within 8000 m, wait 3 s, then 15 s.

Both builds got identical settings, as `-key value` arguments, which both read as defaults:

| Setting | Why |
|---|---|
| `-novsync` | Turns off V-Sync. Both logs confirm "V-Sync not requested". |
| `-animation_timer_interval 0.0001` | The default game tick is 1/200 s (`MINIMUM_ANIMATION_TICK`), which caps both builds at 200 fps |
| `-window_width 1280 -window_height 720` | Same window in both: a 2560 × 1440 pixel surface on Retina |
| A throwaway `HOME` per run | The fork then loads no managed add-ons and doesn't touch `~/GNUstep/Defaults`. Upstream had no managed add-ons anyway. |

How each figure was measured:

- **Frames and frame times.** A JS frame callback records each frame's `delta`. The script reads
  the count and the wall-clock time with `Date.now()` at the end, so fps is frames divided by wall
  seconds. The percentiles come from the per-frame deltas, which are game time and equal real time
  at time acceleration 1. The callback uses only ES5, so SpiderMonkey 1.8.5 runs the same code.
- **CPU.** `ps -o cputime` of the game process before and after each scene. The difference is
  divided by frames to give CPU ms per frame, and by wall time to give cores.

Both builds were `deployment` builds: `-O2`, LTO, `debug=false`, native arm64. Upstream uses
SpiderMonkey 1.8.5 and Apple Foundation; the fork uses QuickJS-ng and `oofnd`.

## Caveats

- **Frame rate is capped by the display.** With V-Sync off and the tick cap removed, both builds
  still hold at about 117–134 fps on the 120 Hz display. macOS appears to throttle windowed OpenGL
  to the refresh rate. The fps column therefore shows the cap, not either build's real maximum.
- **CPU time covers the whole process.** It includes the audio and texture-loader threads, not
  just the main loop.
- **The JS engines differ.** Some of the fork's saving may come from QuickJS-ng against
  SpiderMonkey 1.8.5's interpreter rather than from the C++ conversion. Separating them would need
  the JS share of each frame.
- **GPU time isn't measured.** With CPU use this low, the GPU or the compositor probably sets the
  pace.
- **The population is random.** Ship counts varied by about ±15% between runs, but were comparable
  between the two builds. Three rounds is a small sample.

## Next steps

These are needed before the comparison can say anything about maximum frame rate.

1. **A CPU-bound scene.** Spread the extra ships over 30–50 km so they don't collide, and add
   pirates and police so they fight. Aim for frames above 8.3 ms of CPU.
2. **Time inside the game.** Measure the main thread from the start of `performGameTick` to just
   before the buffer swap. That gives "frame cost" without the display cap and splits update time
   from draw time. It is a small change behind a debug flag.
3. **Full screen.** Try it to see whether full screen escapes the compositor's throttle.
4. **Windows and Linux.** Repeat on both, where the compositor behaves differently.

## Reproducing

The scripts are scratch files in `.agent-tmp/hudrepro/`, which git ignores. Move them under
`tools/` if this becomes a regular check. `fps_bench.py` wraps `launch_snapshot.py` and
alternates the two builds.

```bash
cd oolite-dev
python3 ../.agent-tmp/hudrepro/fps_bench.py ../.agent-tmp/fps/run3 3   # 3 rounds, about 8 minutes
```

Results are written to `<out>/results.json`, with each run's `Latest.log` next to it. Game
windows open in turn during the run; don't touch or close them.
