# Contract: settings rows, preferences and script value

## Game Options

One new row under the existing "Field Of View" row (`PlayerEntity.h` row enum,
`PlayerEntity::setGuiToGameOptionsScreen` at `PlayerEntity.cpp:9105`, keys in
`PlayerEntity::handleGameOptionsScreenKeys` at `PlayerEntityControls.cpp:3580`):

```text
 Screen Matching:            Off            ← left/right toggles; Enter opens the sub-screen when On
```

When screen-matching is on, the "Field Of View" row shows the angle in use, read-only, with
"(screen matching)" after it.

## Screen Matching sub-screen

Rows in order; left/right changes a value, Enter edits a number where shown. Every row applies at
once (FR-015). Description strings are new keys in `Resources/Config/descriptions.plist`, named
`gameoptions-screen-…`.

| Row | Values | Notes |
|---|---|---|
| Screen size | 10"–120" in 0.5" steps, or cm when Units = cm | shows "(detected)" or "(enter your size)" (FR-009) |
| Aspect | 16:9, 16:10, 21:9, 32:9, Custom (1.00–4.00 in 0.01 steps) | |
| Shape | Flat, Curved | |
| Curvature | 800R–4000R in 100R steps | shown only when Curved |
| Viewing distance | 20–300 cm in 1 cm steps, or inches | |
| Units | Inches, cm | display only; storage is mm |
| Field of view | Physical, Custom | |
| Horizontal angle | 20°–170° in 1° steps | Custom only; Physical shows the worked-out value |
| Vertical angle | shown, never editable | FR-005a |
| Wide-angle look | Panini, Even spacing, Classic flat | shown only when the custom angle is above physical (FR-007) |
| Notice | "Curved drawing needs shaders" | shown when shaders are off and a curved or Panini/even setting is chosen (FR-017) |
| Back | | |

A clamped value shows the clamped number (FR-011).

## Preferences

Keys and types in [data-model.md](../data-model.md#preferences-persisted), read and written with
`oo::Defaults::standard()` exactly as `fov-value` is (`Universe.cpp:342-349`,
`PlayerEntityControls.cpp:3995`).

## Script value

`oolite.gameSettings.fovValue` (`Universe.cpp:4980`) returns `OODisplayGeometry::scriptFovValue()`:
the horizontal degrees in use (FR-013). With screen-matching off it is `fov-value` as today. No new
script properties.

## Component scenarios (`tests/component/features/`, in the style of `s1_police_kills_pirate.feature`)

| Id | Scenario |
|---|---|
| C1 | Screen-matching off by default; `fovValue` equals `fov-value` |
| C2 | Starting with the G9 preferences at 80 cm and matching on: `fovValue` is 84.0 (±0.5); the flat 27" variant gives 53.0 |
| C3 | With matching off, the target reticle's window position (new mapping) equals the old projection's for a target at the centre and near each edge; the crosshair is at the window centre with matching off and with the G9 settings on |
| C4 | Entered size survives a restart and is not overwritten by detection (FR-010); with detection succeeding, entering only distance and curvature gives the right angles (SC-004) |
| C5 | Projection pin (research R8a), matching off, values recorded before the feature and never edited: at 1920×1080 every field of the debug read; at 2560×1080 and 3840×1080 the frustum extents, window `display_z` and `fovValue` (the HUD-area values there change by FR-016 and are checked by H5) |

The steps are in `tests/component/steps/display_steps.py`: "Given the preference "<key>" is
"<value>"", "Given a window of <W>x<H>", "Then the game setting "<name>" is about <n>",
"Then the projection's "<field>" is about <n> within <t>" and "Then the projection's "<field>"
equals <json>". Preferences are passed on the game's command line when the scenario starts (the
argument domain: read before the saved preferences, never written back), so a scenario checks what
the game does with them from the start. "Without a restart" (FR-015) is checked where the player
changes a setting: the Game Options GUI tests (T017, T023).

## Debug read (debug builds only)

`console.__displayProjection()` on the debug console object returns
`{left, right, bottom, top, displayZ, windowDisplayZ, hudArea: [x, y, w, h], fovValue,
reticle: [x, y], reticleOld: [x, y], crosshair: [x, y]}` for the current frame. Added beside the
existing debug-console methods, compiled only with `OO_DEBUG_MONITOR_ENABLED`.
