# Frame-rate baselines (spec 008 FR-014, SC-005)

Measured 2026-11-12 on the reference machine (research R9): Windows, the Odyssey G9, a 5120 x 1440
window, shaders on, the system's OpenGL driver (a private staged copy of the test build without
Mesa's `opengl32.dll`), V-Sync off in the game (`-v-sync NO`). Each run launches the scenario save
from the station with seed 20260910, waits 5 s in flight, then counts frames with a frame
callback over 60 s of real time. Three runs per row; the median is shown. The script is
`.agent-tmp/dw/measure_fps.py` (scratch, not committed); the settings are the G9's (49", 32:9,
viewer at 800 mm, `screen-window-fraction` 1).

| Setting | Off median (fps) | On median (fps) |
|---|---|---|
| Flat 32:9, physical (no warp) | 237.68 | 237.72 |
| G9 at 80 cm, physical (warp) | 237.68 | 237.02 |
| G9 at 80 cm, custom 120° Panini (warp) | 237.68 | 237.11 |

The "off" column is the same run set for every row: screen matching off (237.58, 237.68, 237.72).

**Caveat.** Every setting runs at about 237.7 fps, just under the G9's 240 Hz refresh, so the
frame rate is capped (by the driver's sync or the game's own limit) rather than bound by the
renderer. The table shows that the warp keeps the game at the cap on this machine (a drop of
0.3% at most), not how much headroom the warp costs below it. A run without the cap would be
needed to measure that cost.
