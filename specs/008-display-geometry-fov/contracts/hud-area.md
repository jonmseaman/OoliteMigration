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

New accessor: `NSRect MyOpenGLView::hudArea() const` (pixels). Nothing else in the view's interface
changes.

## Checks

| Id | Check | Spec |
|---|---|---|
| H1 | Unit: the rule above for 1920×1080, 2560×1080, 3440×1440, 5120×1440, 1280×1024 | FR-016 |
| H2 | GUI test (style of `tests/gui/test_g1_exit_via_mouse.py`) at 3840×1080 windowed: clicking a menu row's centre selects that row | FR-016 |
| H3 | Smoke snapshot at 3840×1080: the pixel columns left of `x0` and right of `x0 + h·16/9` contain no HUD or menu pixels on a GUI screen | SC-007 |
| H4 | Existing GUI and smoke tests at their usual window sizes pass unchanged | SC-003 |
