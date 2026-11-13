# Data Model: Display Geometry and Field of View

Phase 1 for [plan.md](plan.md). Types are in `src/Core/OODisplayGeometry.h` (contract:
[geometry.md](contracts/geometry.md)); preferences are in the game's defaults store
(contract: [settings.md](contracts/settings.md)).

## ScreenDescription

| Field | Type | Rule |
|---|---|---|
| `diagonalMm` | double | 254–3048 (10"–120"); measured along the surface for curved panels |
| `aspect` | double | width ÷ height; presets 16:9, 16:10, 21:9 (64:27), 32:9; custom 1.0–4.0 |
| `curvatureMm` | optional double | absent = flat; 800–4000 (800R–4000R) |
| `source` | enum `Entered`, `Detected`, `Default` | `Detected` only from R7 after the plausibility check |

Derived: `widthMm = diagonal × aspect ÷ √(aspect² + 1)` (along the arc when curved), `heightMm =
widthMm ÷ aspect`; half arc angle about the centre of curvature `α = widthMm ÷ (2 × curvatureMm)`,
which must be below 90° (it is at most 62° inside the limits).

Default when nothing is saved or detected: 24", 16:9, flat, source `Default`.

## Viewer

| Field | Type | Rule |
|---|---|---|
| `distanceMm` | double | 200–3000; from the eye to the centre of the screen, on its centre line |

Default 600.

## FieldOfViewChoice

| Field | Type | Rule |
|---|---|---|
| `mode` | enum `Physical`, `Custom` | default `Physical` |
| `customHorizontalDeg` | double | 20–170; used only in `Custom` |
| `look` | enum `Panini`, `EvenSpacing`, `ClassicFlat` | default `Panini`; used only when the custom angle is above the physical one |

## DisplayGeometry (derived, not saved)

Built from the three records above plus the window's pixel size and the fraction of the panel the
window covers (spec edge case "Window not full screen"). Holds:

- `physicalHorizontalDeg`, `physicalVerticalDeg` (FR-005);
- `horizontalDeg`, `verticalDeg` in use (FR-005a; the vertical is always derived);
- `effectiveLook`: `ClassicFlat` when the angle in use ≤ physical (FR-007b) or shaders are off
  (FR-017), otherwise `look`;
- `needsWarp`: curved, or `effectiveLook` is Panini or even spacing (research R4);
- `flatRender`: half-angle tangents of the flat render and its pixel size (R3), and the slice
  count (R6);
- the four mappings of the contract.

Rebuilt when any input changes (FR-015); the renderer, HUD and input code hold a pointer to the
current one and compare its generation number to know when to rebuild the warp mesh.

## Preferences (persisted)

| Key | Type | Notes |
|---|---|---|
| `screen-matching` | bool | default false (FR-001) |
| `screen-diagonal-mm` | real | absent until entered or detected |
| `screen-aspect` | real | |
| `screen-curvature-mm` | real | absent or 0 = flat |
| `screen-size-source` | string `entered`/`detected` | entered values win on later runs (FR-010) |
| `viewer-distance-mm` | real | |
| `fov-mode` | string `physical`/`custom` | |
| `fov-custom-horizontal` | real | degrees |
| `fov-wide-look` | string `panini`/`even`/`classic` | |

| `screen-window-fraction` | real | test aid: the share of the panel the window covers, both axes; when absent it is worked out from the desktop mode |

`fov-value` keeps its meaning and range (30–80°) and is used only when `screen-matching` is false
(FR-002). Units are stored in millimetres; the settings screen shows inches or centimetres.

## State transitions

```text
screen-matching off ──turn on──▶ (no saved size?) ──detect──▶ size source = detected | default
        ▲                                   │
        └──────────turn off─────────────────┘   any edit of a size field ⇒ source = entered
```

Turning screen-matching off keeps every saved value; turning it on again restores them.
