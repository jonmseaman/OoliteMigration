# Contract: the HUD area (FR-016)

## Rule

```text
window w × h px
HUD area = window,                                      if w / h ≤ 16/9
         = (x0, 0, h·16/9, h) with x0 = (w − h·16/9)/2,  otherwise   (rounded to whole pixels)
```

Applies whether or not screen-matching is on. Windows 16:9 or narrower are unchanged.

## What uses it

| Thing | Before | After |
|---|---|---|
| `MyOpenGLView::updateGLSize` (`MyOpenGLView.cpp:585-606`) | `display_z`, `x_offset`, `y_offset` from the window | from the HUD area; it also keeps the window's own size for the scene |
| HUD and GUI drawing (`Universe.cpp` HUD from :5652, GUI :5806-5816) | full-window viewport | viewport = HUD area |
| GUI screens' 3D background and demo ships | full window | HUD area; bars cleared to black |
| GUI mouse (`MyOpenGLView+Input.cpp:342-350`) | normalised by window | normalised by HUD area size, offset by `x0` |
| Object-tied markers (reticle, waypoints, scanner wedge edges, sighting markers) | eye space through the scene projection | window position from `OODisplayGeometry::sceneToWindow`, drawn with a full-window viewport (research R13) |
| Scene (space view, all views) | full window | full window |
| Snapshots | window | window (they read the finished frame) |
| Sun and star glare (`OOSunEntity.cpp`, both `getDisplay_z()` reads) | `display_z` | `getWindowDisplay_z()`: the window-based value, unchanged from today (research R12) |
| Crosshair (`OOCrosshairs.cpp:58`) | `display_z` | `display_z` (HUD); stays at the window centre because the area is centred |

New `MyOpenGLView` members (`src/SDL/MyOpenGLView.h`), quoted for the tasks:

```cpp
NSRect hudArea() const;                              // pixels, from OOHudAreaForWindow
GLfloat getWindowDisplay_z() const;                  // today's display_z, from the whole window
const OODisplayGeometry& displayGeometry() const;    // the geometry in use
std::uint64_t displayGeometryGeneration() const;     // bumped only when the geometry changes
```

Nothing else in the view's interface changes. `setFov` rebuilds the geometry only when its value
changes (research R14).

## Checks

| Id | Check | Spec |
|---|---|---|
| H1 | Unit: the rule above for 1920×1080, 2560×1080, 3440×1440, 5120×1440, 1280×1024 | FR-016 |
| H2 | GUI test (style of `tests/gui/test_g1_exit_via_mouse.py`) at 3840×1080 windowed: clicking a menu row's centre selects that row | FR-016 |
| H3 | Snapshots at 3840×1080 (`--window 3840x1080`) of the status (F5), market (F8), short-range chart (F6) and Game Options screens, and of the flight HUD: the pixel columns left of `x0` and right of `x0 + h·16/9` contain only the cleared bar colour (GUI screens) or no HUD pixels (flight, checked with the space view hidden) | SC-007 |
| H5 | Component scenario at 3840×1080, matching off: `hudArea` is `[960, 0, 1920, 1080]`, `displayZ` is 480·16/9, and C5's window `display_z` (today's value, which the glare reads) is unchanged | FR-016, FR-002 |
| H4 | Existing GUI and smoke tests at their usual window sizes pass unchanged | SC-003 |
