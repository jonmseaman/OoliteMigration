# Quickstart: verifying Display Geometry and Field of View

All commands from `oolite-dev` in an MSYS2 UCRT64 shell, on the feature branch
`epic/display-geometry-fov`. Test ids refer to the contracts.

## Every milestone

```bash
./mk.sh build test
```

```bash
tests/run.sh unit
```

```bash
tests/run.sh smoke
```

Expected: all pass; no new warnings at `-Wall -Wextra` (Clang and GCC).

## M1 — the geometry module

```bash
meson test -C build test_OODisplayGeometry --print-errorlogs
```

Fails before the module exists (test file added first), passes after: G1–G12 in
[geometry.md](contracts/geometry.md). This proves every number in the spec's stories.

## M2 — HUD area

```bash
tests/run.sh unit
```

H1 passes. Then, one at a time and with nothing else on the desktop:

```bash
tests/run.sh gui
```

H2 passes at 3840×1080 and H4 (the existing GUI tests) are unchanged. H3 via `tests/run.sh smoke`.

## M3 — projection from the module, markers from the mapping

```bash
tests/run.sh component -k screen
```

C1, C3 and C5 pass: with screen-matching off, the frustum, `display_z` and the reticle position are
what they were before the feature (C5 was recorded in Setup, research R8a). This is the proof of
SC-003; snapshots are not compared.

## M4 — settings and preferences

```bash
tests/run.sh component -k screen
```

C2 and C4 pass: the G9 settings give `fovValue` 84.0 without a restart, and entered sizes survive a
restart.

## M5 — the warp pass

```bash
tests/run.sh smoke
```

With screen-matching on and a curved screen set, the log has the `universe.profile.warp` line;
with it off the line is absent and C5 passes. Hand check on the reference machine (research R9), Odyssey G9 at 80 cm:

1. Game Options → Screen Matching: On; 49", 32:9, Curved 1000R, 80 cm. The rows show 84.0° × 23.8°.
2. Launch, turn so the station's long edge runs across the whole screen: it looks straight from the
   seat; a planet at the far left and far right edges looks round.
3. Target a ship near an edge: the reticle sits on it, outside the 16:9 HUD area if need be.
4. Set Custom 120°: switch Panini / Even spacing / Classic flat and see the trade-offs of Story 3.
5. Detail level without shaders: the view falls back to classic flat and the notice shows.

Frame rate (FR-014, SC-005): fixed scene, 60 s, three runs each with matching off and on; the
medians differ by at most 5%. Record the numbers in `specs/008-display-geometry-fov/baselines.md`.

## M6 — detection

On Windows with a monitor that has an EDID: delete the screen preferences, turn matching on, and
the size row shows the panel's size with "(detected)". With the size keys removed on Linux it shows
"(enter your size)".

## M7 — slices (optional)

G10 passes with a small `maxTextureSizePx`; on the G9 a custom 160° draws without a seam and the
smoke snapshot shows no seam column.
