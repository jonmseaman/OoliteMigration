# Research: Display Geometry and Field of View

Phase 0 for [plan.md](plan.md). Each entry is Decision / Rationale / Alternatives. Code
references are to `oolite-dev` at the planning date (2026-11-12).

## R1. Where the warp goes in the frame

**What the frame does today** (`src/Core/Universe.cpp`, `drawUniverse` from line 5265): with
shaders on, the scene is drawn into `msaaFramebufferID` or `targetFramebufferID` (both at the
window's backing size, set up in `initTargetFramebufferWithViewSize`, line 11351). Sun and star
glare are drawn next, still into that buffer, with a fixed screen-space frustum (line 5622). Then
either:

- *separate HUD pass* (`hudSeparateRenderPass`, line 5267: no post-effect, or cloak/bad-signal
  without a colour-blind filter): `drawTargetTextureIntoDefaultFramebuffer` (line 11659) copies the
  target texture into a two-attachment pass-through buffer (scene + bright parts), blurs the
  bright parts ten times for bloom, and runs the `final` program (bloom, post-effect, tone map,
  saturation) into the window; the HUD is then drawn straight into the window; or
- *HUD in the scene* (colour-blind filters and the other post-effects): the HUD is drawn into the
  target buffer too, and the same second pass runs afterwards (line 5755), so the filter covers
  the HUD.

**Decision**: add one pass, `warp`, between the glare and the HUD. The scene and glare are drawn
into a *flat render* buffer of the size R3 picks; `warp` draws the window-sized *warped* buffer
from it; from there on the frame is unchanged: the HUD is drawn into the warped buffer (HUD in the
scene) or the window (separate pass), and the second pass reads the warped buffer where it read
the target texture. When no warp is needed (R4) the flat render buffer *is* the warped buffer and
nothing changes.

**Rationale**: bloom, post-effects and the colour-blind filter then run on the warped image, so
they line up with what is shown (FR-006d: "applied to the warped image"); glare is drawn before
the warp in the flat image's own projection, so it lands on the sun after the warp. The HUD is
never warped, in either mode (spec edge case "GUI screens and HUD"). The cost is one full-window
textured draw and one window-sized RGBA16F buffer.

**Alternatives**: warp inside the `final` program (sample `scene` and `bloomBlur` at warped
coordinates). Fewer passes, but in the HUD-in-the-scene mode the HUD is already in `scene` and
would be warped; rejected. Warping after the second pass: post-effects such as the CRT effect
would then be bent; rejected.

## R2. One mapping, used by the warp and by everything else

**Decision**: the mapping lives once, in C++: a new pure module `OODisplayGeometry` (no GL, no
game state) that turns a screen description, viewer distance, field-of-view choice and look into
four functions: window position ↔ direction from the eye, and direction from the eye ↔ direction
in the scene. The warp does not re-implement it in GLSL: C++ fills a *warp mesh*, a grid of
vertices over the window, each carrying the flat-render texture coordinate of the scene direction
shown at that vertex. The `warp` pass draws that mesh with a plain texture shader. HUD markers,
mouse picking and mouse-look call the same C++ functions (FR-012).

**Rationale**: one source of truth that the unit tests can check against every number in the
spec, and that cannot drift from the shader. The mapping is smooth, so a grid of 128 × 64 cells over the window is expected to keep the
linear-interpolation error under 0.1 pixel on the G9 (5120 × 1440) for every look up to 150°;
this is an estimate, not yet measured, and the unit test sets the bound (if it fails, the grid
gets denser; the cost is negligible either way) (contract
[geometry.md](contracts/geometry.md), test G7). The mesh is rebuilt only when a setting or the
window size changes (FR-015), well under a millisecond.

**Alternatives**: the mapping written again in GLSL (two copies to keep equal, and no way to test
the GLSL copy in the unit suites); a look-up texture at window resolution (59 MB of RG32F on the
G9) or at reduced resolution (the same interpolation idea, more memory than a mesh).

## R3. Size of the flat render

**Decision**: the flat render is a flat perspective whose horizontal and vertical half-angles are
the largest scene angles any window pixel shows, and whose pixel size is chosen so that its
density at the centre (pixels per radian) is at least the window's density at the centre (FR-006c).
`OODisplayGeometry` returns that size. If it is larger than `GL_MAX_TEXTURE_SIZE` or
`GL_MAX_RENDERBUFFER_SIZE`, or than 3 × the window's pixel count, the slices of R6 are used.

**Rationale**: the figures in the spec's discussion (G9 at 80 cm: about 1.2× the window's pixels
at the physical 84°, 1.5–1.65× at 120°, 2.4–2.85× at 150°) come from exactly this rule. MSAA, when
on, applies to the flat render buffer, since that is where geometry is drawn.

**Alternatives**: a fixed 25% oversize (too little above 100°, too much on a flat screen).

## R4. When no warp is needed

**Decision**: a flat screen at the physical angle, or a flat screen with the classic look, or a
custom angle at or below the physical one on a flat screen, is an ordinary perspective; it is
drawn with the existing frustum at the right horizontal and vertical angles and no `warp` pass.
The warp runs only for a curved screen, or for the Panini or even-spacing look above the physical
angle. Shaders off: always this path (FR-017), with the classic look.

**Rationale**: on a flat screen the exact mapping *is* a perspective, so the warp would be an
identity copy; skipping it keeps flat screens at today's cost (FR-014).

## R5. The projection today, and what changes in it

`drawUniverse` sets the frustum at lines 5329–5340: for windows 4:3 or wider, the half-width is
`fov(true)` (the tangent of half the setting) and the half-height follows the window's aspect;
narrower windows fix the half-height at ¾ of that. The near plane is pulled in by
`distanceFactor` so corners are not clipped; frustum culling (`viewFrustumIntersectsSphereAt`)
reads the same matrix.

**Decision**: the frustum's four extents come from one function, `OODisplayGeometry::flatFrustum`,
that returns today's values exactly when screen-matching is off (SC-003; unit test G1 pins them
against the formula above) and the flat-render extents otherwise. `distanceFactor` is computed from
those extents. Culling then automatically covers the whole flat render.

**Rationale**: one change point; screen-matching off is bit-for-bit today's frustum.

## R6. Slices for very wide angles (FR-018)

**Decision**: the last milestone. Up to three flat renders, each a perspective turned about the
vertical axis (left, centre, right), drawn into one texture side by side; the warp mesh's texture
coordinates point into the slice that contains each scene direction. A mesh cell that spans two
slices is split at the seam so no triangle interpolates across it. Used only when R3's limit is
hit.

**Rationale**: the mesh approach (R2) makes slices a change to the mesh builder and the scene
loop, not to the shader or the HUD. Three slices of at most 60° each cover 180°.

**Alternatives**: a cube map (six renders, fixed 90° faces, wasted work for a 32:9 view).

## R7. Detecting the screen's size (FR-009)

The game uses SDL3, which reports pixels and content scale but not physical size.

**Decision**: a small platform function `OOQueryDisplayPhysicalSize(displayIndex)` returning an
optional width and height in millimetres:

- Windows: the monitor's EDID from the device registry key (SetupAPI,
  `SetupDiGetClassDevs(GUID_DEVCLASS_MONITOR)` + `SetupDiOpenDevRegKey(..., "EDID")`), matched to
  the SDL display through its device name; the size is the first detailed-timing descriptor's
  millimetres, falling back to bytes 21–22 (centimetres).
- macOS: `CGDisplayScreenSize`.
- Linux: not detected in this feature (no SDL3 API; X11 and Wayland differ). It returns nothing, so
  the player enters the size (spec Story 4 scenario 2).

Plausibility (spec edge case): diagonal 10–120 inches and aspect within 5% of the display's pixel
aspect, otherwise "not detected".

**Rationale**: EDID is what the monitor itself reports and is right for most panels; Windows'
`GetDeviceCaps(HORZSIZE)` is often a made-up value. Curved panels report a width that may be the
chord, not the arc; the plausibility check does not catch that, so the settings show the
detected size for the player to correct (the spec already says curvature is entered by hand).

**Alternatives**: WMI `WmiMonitorBasicDisplayParams` (centimetres only, COM set-up); SDL's DPI
(removed in SDL3).

## R8. Testing the geometry

**Decision**: every number in the spec's stories is a unit test of `OODisplayGeometry` in the
`core` meson suite, written before the module (the failing-then-passing command of the first
step). The shapes and line-bend figures are measured exactly as the spec's discussion did:
local Jacobian at the edge for shape and size, deviation from a great circle for straight lines.
Rendering is checked by: the existing smoke and GUI tests with screen-matching off (SC-003); a
component scenario that sets the preferences over the debug console and reads back the reported
field of view (FR-013, FR-015); a mesh test (G7); and a hand check on the G9 (quickstart).

**Rationale**: the claims in the spec are geometric; a render comparison would only re-test the
same mapping through more machinery. The renderer is tested for "unchanged when off" and "uses the
mapping when on".

## R9. Reference machine (FR-014, SC-005)

**Decision**: Jon's Windows development machine with the Odyssey G9 at 5120 × 1440, shaders on,
MSAA as Jon has it. Frame rate is measured with the game's own frame counter over 60 s in a fixed
scene (the station approach in the smoke run), median of three runs, screen-matching on (G9,
80 cm, physical) against off.

**Rationale**: the spec is about that monitor, and the warp cost scales with window pixels.

## R10. Settings screen

**Decision**: the settings go on the existing Game Options screen (`PlayerEntity` game-options
rows, beside `GUI_ROW_GAMEOPTIONS_FOV`) as one row "Screen matching: Off / On" that opens a
sub-screen with the rows of the [settings contract](contracts/settings.md). Spec 007 (RmlUi) is
not a dependency; when it lands, the rows move with the rest of Game Options.

**Rationale**: spec 007 is only specified; waiting for it would block this feature. The row
pattern is the one the FOV row already uses.

## R11. How the HUD and GUI are placed today

The HUD and GUI are not drawn with an orthographic projection. `MyOpenGLView::updateGLSize`
(`src/SDL/MyOpenGLView.cpp:585-606`) sets a full-window viewport and the frustum
`(-0.5, 0.5, -aspect·0.5, aspect·0.5)`, and the HUD and GUI draw at depth `display_z`, where one
unit is one virtual pixel. For windows wider than 4:3, `display_z = 480·w/h` and `x_offset =
240·w/h` (half the virtual width), `y_offset = 240`: the view is always 480 virtual units tall and
wider windows get more width. HUD items anchor to the edges as `x + x_offset·x_origin`
(`HeadUpDisplay.cpp:485-501` and about 60 more places). The GUI panel is a fixed 480 × 480
(`GuiDisplayGen.h:48-49`), centred. GUI mouse positions are normalised by `display_z` and
`MAIN_GUI_PIXEL_WIDTH` (`MyOpenGLView+Input.cpp:342-350`).

Markers over objects in space (target reticle, waypoints: `hudDrawReticleOnTarget`,
`hudDrawWaypoint`) are not projected to the screen: they are drawn in eye space after
`hudRotateViewpointForVirtualDepth` (`HeadUpDisplay.cpp:4104-4126`) undoes the field of view by
scaling the model-view by `1/(2·fov(true))`, with the same 4:3 branch as the scene frustum. The
reticle size (`:3818-3822`) and the scanner's field-of-view wedge (`:4652-4660`) use `fov(true)`.
There is no unproject or picking code; mouse flight is a virtual joystick that does not use the
field of view, and spec 004 (mouse-look) is not built yet.

## R12. The 16:9 HUD and menu area (FR-016)

**Decision**: `updateGLSize` computes a *HUD area*: the window itself when it is 16:9 or narrower,
otherwise the centred full-height rectangle of width `h·16/9`. `display_z`, `x_offset` and
`y_offset` are computed from the HUD area instead of the window. The HUD and GUI draw with the
viewport set to the HUD area; the scene keeps the full window. GUI mouse normalisation uses the
HUD area's size and origin. On GUI screens, the 3D background and demo ships draw in the HUD area
too, and the bars either side are cleared to the background colour (black). Contract:
[hud-area.md](contracts/hud-area.md).

**Rationale**: every HUD and GUI position already derives from `display_z` and the offsets, so
computing those from a smaller rectangle moves everything at once; on windows 16:9 or narrower
nothing changes (SC-003).

**Alternatives**: scaling HUD coordinates per call site (about 60 places); leaving GUI 3D content
full width (the demo ship would sit in a different place from the panel it belongs to).

## R13. Markers over objects in space

**Decision**: object-tied markers (reticle, waypoints, the scanner wedge's edges, sighting
markers) stop relying on the scene's projection. Each takes the object's direction from the eye,
maps it with `OODisplayGeometry::sceneToWindow` to a window position, and draws there with a
full-window viewport (so a marker outside the HUD area stays on its object, spec edge case).
`hudRotateViewpointForVirtualDepth` stays for the screen-matching-off path, where the old and new
results are identical (unit test G1 covers the frustum; component test C3 compares the reticle's
window position both ways). The reticle's size uses the mapping's local scale at that position
instead of `fov(true)`.

**Rationale**: with a warp, the scene projection is no longer what the window shows, so anything
drawn "in the scene's projection" after the warp lands in the wrong place, worst at the edges.
One mapping function is the only route that is right for every look.

