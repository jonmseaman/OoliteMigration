# Contract: `OODisplayGeometry`

New files `src/Core/OODisplayGeometry.h` and `.cpp`. Pure C++: no GL, no SDL, no game state, no
allocation after construction except the mesh. Style follows `src/Core/OOColor.*` (file header,
`#pragma once`, camelCase methods). It is a value type: copied, never shared, so no `oo::Ref`.
Fields are those of [data-model.md](../data-model.md).

## Interface

```cpp
#pragma once

#include <cstdint>
#include <optional>
#include <vector>

enum class OOFovMode { kPhysical, kCustom };
enum class OOWideLook { kPanini, kEvenSpacing, kClassicFlat };
enum class OOScreenSizeSource { kDefault, kDetected, kEntered };

struct OOScreenDescription {
  double diagonalMm = 609.6;              // 24"
  double aspect = 16.0 / 9.0;
  std::optional<double> curvatureMm;      // empty = flat
  OOScreenSizeSource source = OOScreenSizeSource::kDefault;
};

struct OOFieldOfViewChoice {
  OOFovMode mode = OOFovMode::kPhysical;
  double customHorizontalDeg = 90.0;
  OOWideLook look = OOWideLook::kPanini;
};

struct OODirection {  // unit vector; +z forward, +x right, +y up (eye or scene space)
  double x, y, z;
};

struct OOWindowPoint {  // window pixels, origin top-left, y down
  double x, y;
};

struct OOFlatFrustum {  // extents at distance 1, as OOGLFrustum takes them
  double left, right, bottom, top;
};

struct OOWarpVertex {
  float windowX, windowY;  // normalised 0..1
  float u, v;              // flat-render texture coordinate (slices side by side)
};

class OODisplayGeometry {
 public:
  // Screen-matching off: reproduces today's projection from the legacy fov setting.
  static OODisplayGeometry legacy(double fovDeg, int windowWidthPx, int windowHeightPx);

  // Screen-matching on. Inputs are clamped to the data-model limits; clampedInputs() reports what was used.
  OODisplayGeometry(const OOScreenDescription& screen, double viewerDistanceMm,
                    const OOFieldOfViewChoice& choice, int windowWidthPx, int windowHeightPx,
                    double windowFractionX = 1.0, double windowFractionY = 1.0,
                    bool shadersAvailable = true, int maxTextureSizePx = 16384);

  double physicalHorizontalDeg() const;
  double physicalVerticalDeg() const;
  double horizontalDeg() const;   // in use
  double verticalDeg() const;     // in use, always derived
  OOWideLook effectiveLook() const;
  bool needsWarp() const;

  // Flat render (research R3/R6).
  OOFlatFrustum flatFrustum(int slice = 0) const;  // legacy: today's frustum exactly
  double sliceYawDeg(int slice) const;
  int sliceCount() const;
  int flatRenderWidthPx() const;   // per slice
  int flatRenderHeightPx() const;

  // The four mappings (FR-006, FR-012). Window points outside the window are allowed.
  OODirection windowToEye(OOWindowPoint p) const;
  std::optional<OOWindowPoint> eyeToWindow(OODirection d) const;   // empty: not on the screen
  OODirection eyeToScene(OODirection d) const;
  OODirection sceneToEye(OODirection d) const;

  // Convenience for HUD markers and picking.
  std::optional<OOWindowPoint> sceneToWindow(OODirection d) const;
  OODirection windowToScene(OOWindowPoint p) const;
  double localPixelsPerRadian(OOWindowPoint p) const;  // reticle size (research R13)

  // Warp mesh (research R2): (cellsX + 1) * (cellsY + 1) vertices, row-major.
  std::vector<OOWarpVertex> warpMesh(int cellsX = 128, int cellsY = 64) const;

  // The script value (FR-013): horizontal degrees in use.
  double scriptFovValue() const;
};

struct OOPixelRect {  // window pixels, origin top-left
  int x, y, width, height;
};

// The HUD area (contracts/hud-area.md): the window if w / h <= 16/9, else the centred
// full-height 16:9 rectangle.
OOPixelRect OOHudAreaForWindow(int windowWidthPx, int windowHeightPx);

// Detection plausibility (research R7): diagonal 10"-120" and aspect within 5% of the pixel aspect.
bool OOPlausibleDisplaySize(double widthMm, double heightMm, int pixelWidth, int pixelHeight);
```

Platform query, `src/Core/OODisplaySize.h` (implementations in `src/SDL/`, research R7):

```cpp
#pragma once
#include <optional>
#include <utility>

// Physical width and height in millimetres of the SDL display, or empty if unknown.
std::optional<std::pair<double, double>> OOQueryDisplayPhysicalSize(int sdlDisplayIndex);
```

## Definitions the tests pin

- **Eye position**: on the screen's centre line, `viewerDistanceMm` from the centre of the panel.
- **Curved panel**: a cylinder of radius `curvatureMm` about a vertical axis behind the panel; a
  window point at arc length `s` from the centre is at angle `s / R` about that axis. Vertical is
  flat.
- **Physical angles**: the eye angles of the panel's left/right and top/bottom edges at the centre
  column/row.
- **Looks** (FR-007a), as maps from scene direction to eye direction, scaled so the edge of the
  angle in use lands on the edge of the panel:
  - *classic flat*: gnomonic in both axes (a perspective);
  - *even spacing*: eye azimuth and elevation are the scene's times one factor;
  - *Panini*: the scene's Panini (d = 1) coordinates laid out along the panel surface, horizontally
    by arc length, vertically by height, with the vertical scale chosen so the centre is
    conformal.
  At or below the physical angle the look is classic flat (FR-007b), and at exactly the physical
  angle `eyeToScene` is the identity.

## Unit tests (`tests/unit/core/test_OODisplayGeometry.cpp`, `core` suite)

Registered as `'test_OODisplayGeometry': ['Core/OODisplayGeometry.cpp']` in
`tests/unit/core/meson.build`, in the style of `test_OOVector.cpp` (`OO_TEST`, `OO_CHECK`).

| Id | Checks | Spec |
|---|---|---|
| G1 | `legacy()` frustum equals today's formula for 57.2°, 30°, 80° at 640×480, 1920×1080, 5120×1440, 1080×1920 | FR-002, SC-003 |
| G2 | 27" 16:9 flat at 600 mm: 53.0° × 31.3° (±0.5°) | Story 1, SC-001 |
| G3 | 49" 32:9 1800R at 800 mm: 80.0° × 23.8°; flat at 800 mm: 73.7° | Story 2, SC-001 |
| G4 | G9 (49" 32:9 1000R) at 800 mm: 84.0° × 23.8°; at 1000 mm: 68.6° × 19.1°; uniform angular spacing within 1% at 1000 mm | Story 2, SC-001 |
| G5 | Shape and size each within 2% from centre to edge at the physical angle for G2–G4 setups | SC-002, Story 2 scenario 3 |
| G6 | G9 at 800 mm, custom 120°: Panini shape ±2%, size +25% (±3 points), vertical 36.0°, bend ≤ 2°; even spacing shape and size ±2%, vertical 34.0°; classic flat straight within 0.2°, edge ratio 1.49 ±0.03, vertical 44.1° | Story 3, SC-002 |
| G7 | Warp mesh interpolation error below 0.1 px over a 5120×1440 window for every look at 84°, 120°, 150° | research R2, FR-006b |
| G8 | Round trips: `windowToScene(sceneToWindow(d)) == d` within 1e-9 rad over the screen | FR-012 |
| G9 | Clamping: out-of-range inputs come back as the data-model limits | FR-011 |
| G10 | Flat render size: centre density ≥ window centre density; sliceCount() > 1 when one image would exceed the texture limit | FR-006c, FR-018 |
| G11 | `needsWarp()`: false for flat + physical, flat + classic, flat + custom ≤ physical, shaders off; true for curved, or Panini/even above physical | research R4, FR-017 |
| G12 | Straight line on the G9 at 800 mm, physical: deviation ≤ 0.2° | SC-006, FR-006b |
| G13 | Window covering half the panel (`windowFractionX = windowFractionY = 0.5`, G9 at 800 mm): angles are those of the covered part, and G5's shape check holds inside the window | edge case "Window not full screen" |
| G14 | Eye behind the centre of curvature (G9 at 1200 mm): angles finite and G5's shape check holds | edge case "Eye outside the curve" |
| G15 | `windowToScene` at the window's centre is straight ahead (0, 0, 1) for every look and setup | FR-012 (crosshair) |
| G16 | `OOHudAreaForWindow` (H1) and `OOPlausibleDisplaySize`: 27"/16:9 and 49"/32:9 accepted; 8", 130", and aspect off by more than 5% rejected | FR-016, FR-009 |
