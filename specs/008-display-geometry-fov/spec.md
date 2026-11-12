# Feature Specification: Display Geometry and Field of View (ultrawide and curved monitors)

**Feature Branch**: `008-display-geometry-fov`

**Created**: 2026-11-10

**Status**: Draft

**Input**: User description: "Double wide and curved monitor support. I want to enter the curvature and size of the monitor in the settings (or have it auto-detected), and then it should have the correct horizontal and vertical field of view. Also, it should not warp the view. It needs to look correct at the center and edges of the screen. So, we should also have a distance to monitor parameter most likely. (My goal isn't necessarily to have a realistic fov though, but the proportions should be accurate.)"

## Context

Today the space view has a single "Field Of View" option in Game Options. The game draws one flat
perspective view sized from that value (default 57.2°, range 30–80°): on screens 4:3 or wider the
value is the horizontal angle and the vertical angle shrinks as the window gets wider; on
narrower screens the vertical angle is fixed at what a 4:3 screen would have. The 80° limit is
below the G9's physical 84° at 80 cm.
Nothing about the physical screen is known, so on a 32:9 "double wide" monitor the outer thirds of
the view are stretched sideways, and on a curved monitor the flat image is bent around the curve,
which stretches the edges further. Ships, planets and the station look the right shape only near
the middle of the screen.

The feature lets the player describe their screen (size, shape, curvature) and where they sit, and
draws the space view so that, from where they sit, things have the right proportions everywhere on
the screen, not only at the centre.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Correct proportions on a flat ultrawide monitor (Priority: P1)

A player with a flat 32:9 or 21:9 monitor opens the display settings, enters the screen's diagonal
size and their viewing distance, and turns on "match my screen". The horizontal and vertical field
of view are now worked out from the screen and distance, and are shown to the player. A round
planet or the station seen at the far left or right edge looks round from the player's seat, not
smeared sideways.

**Why this priority**: Flat ultrawide screens are the most common wide setup, and the flat case is
the base the curved case builds on. It delivers the core promise (correct proportions at the edges)
with the least new behaviour.

**Independent Test**: Enter a 27" 16:9 flat screen at 60 cm and check the game reports 53.0°
horizontal and 31.3° vertical (±0.5°). Fly so a planet sits at the screen edge and compare its
on-screen width and height as seen from the stated eye position.

**Acceptance Scenarios**:

1. **Given** screen-matching is on with a 27" 16:9 flat screen at 60 cm, **When** the player
   returns to flight, **Then** the reported field of view is 53.0° horizontal and 31.3° vertical,
   each within 0.5°.
2. **Given** the same settings, **When** a spherical object of the same angular size is shown at
   the centre and at the horizontal edge, **Then** each appears with a width-to-height ratio of
   1.0 within 2% from the stated eye position.
3. **Given** screen-matching is on, **When** the player changes the viewing distance, **Then** the
   reported field of view updates before they leave the settings screen.

---

### User Story 2 - Correct proportions on a curved monitor (Priority: P1)

A player with a curved monitor (for example a 49" 32:9 1800R) also enters the curvature radius.
The view is drawn for the curved surface: each part of the screen shows what lies in that
direction from the player's seat, so objects keep their shape and size as they move from the
centre to the edge, and straight lines in space look straight from the seat.

**Why this priority**: This is the case the request is about and the one the current game gets
most wrong. It depends on the screen description from Story 1.

**Independent Test**: Enter a 49" 32:9 screen, 1800R, at 80 cm; check the reported field of view is
80.0° horizontal and 23.8° vertical (±0.5°), then check an object's proportions at centre and edge.

**Acceptance Scenarios**:

1. **Given** a 49" 32:9 1800R screen at 80 cm, **When** screen-matching is on, **Then** the reported
   field of view is 80.0° horizontal and 23.8° vertical, each within 0.5° (a flat screen of the
   same size at the same distance reports 73.7° horizontal).
2. **Given** a Samsung Odyssey G9 (49" 32:9, 1000R) at 80 cm, **When** screen-matching is on,
   **Then** the reported field of view is 84.0° horizontal and 23.8° vertical, each within 0.5°;
   at 100 cm (the eye at the centre of curvature) it is 68.6° horizontal and 19.1° vertical.
3. **Given** the curved settings, **When** an object of fixed angular size moves from the centre to
   the horizontal edge, **Then** its width-to-height ratio and its angular size, as seen from the
   stated eye position, each stay within 2% of their values at the centre.
4. **Given** the curved settings with the eye placed at the screen's centre of curvature
   (distance = radius), **When** the view is drawn, **Then** equal horizontal distances along the
   screen surface correspond to equal angles (uniform angular spacing) within 1%.

---

### User Story 3 - A wider field of view with a chosen look (Priority: P2)

The player finds the true physical field of view narrow and sets a custom horizontal angle. The
vertical angle is always worked out by the game and shown, never entered. When the custom angle is
wider than the physical one, no image can be right everywhere (the screen covers less of the eye's
view than the scene being shown), so the player picks which compromise they prefer:

- **Panini** (default): objects keep their shape everywhere and straight lines stay nearly
  straight; objects grow towards the edges and the vertical view is a little shorter there.
- **Even spacing**: objects keep their shape and their size everywhere; horizontal lines bend
  towards the edges.
- **Classic flat**: straight lines stay straight; objects stretch sideways towards the edges, as in
  most wide-angle games.

A custom angle narrower than the physical one is a plain zoom and ignores the look setting.

**Why this priority**: The request says a realistic field of view is not the goal, accurate
proportions are. This gives that freedom and lets the player choose what to give up. It needs the
geometry of Stories 1 and 2 first.

**Independent Test**: With the Odyssey G9 at 80 cm, set the horizontal angle to 120°, switch
between the three looks, and check the reported vertical angle and the shape, size and line
measurements below.

**Acceptance Scenarios** (Odyssey G9, 1000R, at 80 cm, custom horizontal 120°):

1. **Given** screen-matching is on, **When** the player sets a custom horizontal angle, **Then** the
   vertical angle is worked out and shown, and there is no way to enter it.
2. **Given** the Panini look, **When** an object of fixed angular size moves from the centre to the
   horizontal edge, **Then** its width-to-height ratio stays within 2% of its centre value and its
   size grows by 25% (±3 points); the reported vertical angle is 36.0° at the centre (±0.5°); a
   straight horizontal line across the top of the view bends by no more than 2°.
3. **Given** the even-spacing look, **When** the same object moves to the edge, **Then** its
   width-to-height ratio and its size each stay within 2% of their centre values; the reported
   vertical angle is 34.0° (±0.5°).
4. **Given** the classic flat look, **When** a straight edge in space crosses the full width,
   **Then** it looks straight from the seat (within 0.2°); the object's width-to-height ratio at
   the edge is 1.49 (±0.03) times its centre value; the reported vertical angle is 44.1° (±0.5°).
5. **Given** a custom angle narrower than the physical one, **When** the player changes the look,
   **Then** the view does not change.
6. **Given** a custom angle, **When** the player picks "Physical", **Then** the angle returns to the
   value worked out from the screen and distance, and the view is exact again (Story 2).

---

### User Story 4 - Auto-detected screen size (Priority: P3)

When the player turns on screen-matching, the game fills in the screen's size and aspect from what
the operating system reports for the display the game is on, so most players only need to enter
their distance (and curvature, if curved).

**Why this priority**: A convenience. Manual entry already gives the full result.

**Independent Test**: On a machine whose display reports its physical size, enable screen-matching
with no saved values and check the size fields are pre-filled with the reported size, marked as
detected.

**Acceptance Scenarios**:

1. **Given** no saved screen description and a display that reports its physical size, **When**
   screen-matching is first turned on, **Then** the size and aspect fields are pre-filled from the
   display and marked "detected".
2. **Given** the display reports no size, or an implausible one (see Edge Cases), **When**
   screen-matching is turned on, **Then** the fields fall back to the defaults, are marked "not
   detected", and the player is told to enter them.
3. **Given** the player has edited a detected value, **When** the game restarts, **Then** the
   player's value is kept and not overwritten by detection.

---

### Edge Cases

- **Feature off**: with screen-matching off (the default), the space view, the Field Of View option
  and the value reported to scripts are exactly as today.
- **Implausible detection**: a reported diagonal under 10" or over 120", or an aspect that does not
  match the window's pixel aspect within 5%, is treated as not detected.
- **Window not full screen**: the screen description applies to the whole panel; a window that
  covers part of it uses the part of the physical screen it covers (its share of the width and
  height), so proportions stay correct inside the window.
- **Eye outside the curve**: a viewing distance greater than the curvature radius is allowed (eye
  behind the centre of curvature); the result is still computed from the eye position.
- **Extreme values**: viewing distance limited to 20–300 cm; curvature radius 800R–4000R or flat;
  chosen horizontal field of view limited to what the projection can draw without the view folding
  back on itself (at most 170°); out-of-range input is clamped and the clamped value shown.
- **Vertical curvature**: monitors curved vertically are out of scope; vertical is treated as flat.
- **GUI screens and HUD**: menus, the status screens and the HUD are not curved or warped. On a
  screen wider than 16:9 they sit in a centred 16:9 area at full height (FR-016); on a screen 16:9
  or narrower they fill the window as today. The space view always fills the whole window (all
  four views, and external views).
- **Shaders off**: curved drawing needs the shader detail levels. With shaders off, the curved
  setting falls back to a flat view of the same field of view, and the settings screen says so.
- **Very wide chosen field of view**: above about 120° horizontal, a single flat render needs a
  much larger off-screen image to keep the centre sharp, and somewhere above 150° (on the G9) it
  would exceed the largest image the graphics hardware can hold. The view is then drawn in several
  slices joined by the same final step, with no seams (FR-018). Slices never change the look.
- **Shaders off with a custom look**: Panini and even spacing need the final step as well; with
  shaders off the view falls back to classic flat, and the settings say so (FR-017).
- **Other camera features**: in-flight field-of-view control, mouse-look (spec 004), snapshots and
  the sun glare / break-pattern effects must use the same field of view as the space view, so
  nothing appears in the wrong place relative to the scene. The hyperspace tunnel and sun glare are
  drawn as part of the scene, before the final step. In-flight field-of-view control (a build
  option, off by default) changes the horizontal angle in use for the session only when
  screen-matching is on, as a custom angle that is not saved.
- **Targeting and aim**: the crosshair, scanner target reticle and any HUD marker placed over a
  ship must sit over that ship on the drawn view, including near the edges of a curved projection.
  Anything that turns a screen position into a direction in space (mouse picking, mouse-look) must
  give the direction the warped view actually shows at that position.
- **HUD markers outside the 16:9 area**: a marker for an object shown outside the centred HUD area
  (for example a target near the edge of a 32:9 screen) is still drawn over the object, not
  clamped into the 16:9 area.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Players MUST be able to turn screen-matching on or off in the game's settings; it is
  off by default.
- **FR-002**: With screen-matching off, the space view and the existing Field Of View option MUST
  behave exactly as they do now. (The 16:9 HUD and menu area of FR-016 is separate and changes
  only windows wider than 16:9.)
- **FR-003**: Players MUST be able to enter the screen's diagonal size (inches or centimetres),
  its aspect ratio (common presets 16:9, 16:10, 21:9, 32:9 and a custom value), and whether it is
  flat or curved with a curvature radius in the "R" notation monitors are sold with (e.g. 1800R =
  1800 mm).
- **FR-004**: Players MUST be able to enter their viewing distance from the centre of the screen.
- **FR-005**: The system MUST work out the horizontal and vertical field of view from the screen
  description and viewing distance, and show both to the player in the settings.
- **FR-005a**: The field of view setting MUST offer "Physical" (the default: the angles from
  FR-005) or a custom horizontal angle. The vertical angle MUST always be worked out by the system
  and shown; players MUST NOT be able to enter it. [Jon, 2026-11-12: a vertical angle that
  disagrees with the horizontal one can only squash or stretch the whole view.]
- **FR-006**: The system MUST draw the space view so that each point on the physical screen shows
  the scene in the direction of that point from the stated eye position (flat: a flat perspective;
  curved: a view matched to the curve).
- **FR-006a**: For a curved screen, or for the Panini or even-spacing look, the scene MUST be drawn flat into an off-screen image and then
  warped in one final full-screen step: for each pixel of the physical screen the step works out
  the direction from the eye to that pixel (from the screen description and viewing distance),
  converts it to the scene direction the chosen look puts there (identity at the physical angle),
  and takes the colour the flat image shows in that scene direction. [Approach chosen by Jon, 2026-11-10; see
  Assumptions.]
- **FR-006b**: The warped view MUST have no seams: a straight edge in space (a station's edge, a
  laser beam) drawn across the screen at the physical field of view MUST look straight from the
  stated eye position, with no kinks.
- **FR-006c**: The off-screen image MUST be large enough that the centre of the screen shows at
  least as much detail as the flat view does with screen-matching off.
- **FR-006d**: Effects that work on the finished image (bloom, sun glare, other post-effects) MUST
  line up with the warped scene; they are applied either before the warp or to the warped image,
  never split across both.
- **FR-007**: When the custom horizontal angle is wider than the physical one, players MUST be able
  to choose the look: Panini (default), even spacing, or classic flat, with the behaviour and
  measurements of User Story 3. The look setting MUST be saved with the other preferences.
- **FR-007a**: Panini on a curved screen MUST be laid out along the screen's surface (so that
  objects keep their shape on the curve); on a flat screen it is laid out on the flat surface.
  Even spacing MUST give equal angles from the seat to equal angles in the scene, in both
  directions. Classic flat MUST be a flat perspective at the custom angle; on a curved screen it is
  shown through the same final step so straight lines still look straight.
- **FR-007b**: When the custom angle is equal to or narrower than the physical one, the view MUST be
  a flat perspective at that angle (on a curved screen, shown through the final step), and the look
  setting MUST have no effect.
- **FR-008**: Players MUST be able to return to the physical field of view in one action.
- **FR-009**: The system MUST try to detect the screen's physical size and aspect from the
  operating system when no screen description is saved, and MUST say whether detection succeeded.
- **FR-010**: Values the player enters MUST be saved with the other game preferences and MUST take
  precedence over detection on later runs.
- **FR-011**: Out-of-range values MUST be clamped to the limits in Edge Cases, and the clamped value
  shown.
- **FR-012**: HUD markers tied to objects in space (crosshair alignment, target reticle, sighting
  markers) MUST appear over the object they mark on the drawn view; the crosshair MUST stay at the
  window's centre, which every look maps to straight ahead; and every conversion between a
  screen position and a direction in space (mouse picking, mouse-look) MUST use the same mapping as
  the warp in FR-006a.
- **FR-013**: The field of view reported to scripts MUST be the horizontal field of view actually in
  use. [Default chosen: same meaning as today's value, so existing scripts keep working.]
- **FR-014**: The space view MUST keep the current frame rate within 5% on the reference machine
  with screen-matching on, for both flat and curved settings.
- **FR-015**: Changing any screen-matching setting MUST take effect without restarting the game.
- **FR-016**: On a window wider than 16:9, the HUD, menus and status screens MUST be laid out in a
  centred 16:9 area at full window height, while the space view fills the whole window. This
  applies whether or not screen-matching is on.
- **FR-017**: With shaders off, a curved screen description, or the Panini or even-spacing look,
  MUST fall back to classic flat at the same horizontal field of view, and the settings MUST say
  that these need shaders.
- **FR-018**: For a horizontal field of view above 120°, the system MAY draw the flat image as
  several slices before the warp, and MUST do so when one image would be larger than the graphics
  hardware supports; the result MUST still meet FR-006b and FR-006c and look the same as a single
  image would.

### Key Entities

- **Screen description**: diagonal size, aspect ratio, flat or curved, curvature radius; source
  (entered or detected). Saved with preferences.
- **Viewer position**: distance from the eye to the centre of the screen, on the screen's centre
  line.
- **Field of view**: horizontal and vertical angles; either physical (worked out from screen and
  viewer) or custom (horizontal set by the player, vertical always worked out).
- **Wide-angle look**: Panini (default), even spacing or classic flat; used only when the custom
  horizontal angle is wider than the physical one. Saved with preferences.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For the three reference setups (27" 16:9 flat at 60 cm; 49" 32:9 1800R at 80 cm;
  Samsung Odyssey G9, 49" 32:9 1000R, at 80 cm and at 100 cm) the reported horizontal and vertical
  field of view match the values in Stories 1 and 2 within 0.5°.
- **SC-002**: With screen-matching on at the physical angle, an object of fixed angular size keeps
  its width-to-height ratio within 2% of its centre value anywhere across the horizontal extent of
  the screen, for every reference setup; at a custom 120° with the Panini or even-spacing look, the
  same holds on the Odyssey G9 at 80 cm.
- **SC-003**: With screen-matching off, every existing test and snapshot comparison of the space
  view passes unchanged.
- **SC-004**: A player with a supported display that reports its size can go from turning on
  screen-matching to flying with correct proportions by entering at most two values (distance and,
  if curved, curvature).
- **SC-005**: Frame rate with screen-matching on is within 5% of frame rate with it off on the
  reference machine.
- **SC-006**: On the Odyssey G9 setup at 80 cm, a straight edge crossing the full width of the
  screen deviates from a straight line, as seen from the stated eye position, by no more than 0.2°
  anywhere along it.
- **SC-007**: On a 32:9 window, every menu and status screen and the HUD fit inside the centred
  16:9 area, with nothing cut off or stretched.

## Assumptions

- **No clarification questions were asked** (project rule: every decision has a default). The
  defaults below are recorded here and can be revisited in `/speckit-clarify`.
- "Double wide" means one wide panel (e.g. 32:9). Several monitors side by side, with bezel
  correction, are out of scope.
- Monitor sizes are given as the diagonal measured along the screen surface, as manufacturers do;
  for curved panels the width is the length along the curve.
- Only horizontal curvature is supported (all common curved monitors).
- The eye is on the screen's centre line (horizontally and vertically centred); off-centre seating
  is out of scope.
- Operating systems usually report physical size but never curvature, so curvature is always
  entered by the player; detection may be missing or wrong on some displays, hence FR-009's
  "say whether it succeeded".
- **Angle entry and wide-angle looks (Jon, 2026-11-12).** Screen and distance are the main inputs;
  the field of view is Physical or a custom horizontal angle; the vertical angle is never entered;
  a custom angle wider than physical uses a chosen look, Panini by default. Panini is the default
  because on the G9 it keeps shapes within 1% and lines nearly straight up to 120°, where even
  spacing bends lines about 4° and classic flat stretches edges by about half. At the physical
  angle the exact warp beats every look, which is why the look only applies above it. Measured
  trade-offs on the G9 at 80 cm (edge object size growth / line bend): 120° Panini 25% / 1.7°,
  even 0% / 3.7°; 150° Panini 49% / 5.6°, even 0% / 6.2°. Above about 150° every look reads as
  stylised.
- The Story 3 figures were computed from the G9 geometry for each look as defined in FR-007a;
  the plan should reproduce them with a unit test of the mapping before any drawing is changed.
- Reference values were computed from the screen geometry: 27" 16:9 is 59.8 × 33.6 cm; 49" 32:9 is
  119.8 × 33.7 cm, and with 1800R the edges are at ±40.0° from a seat 80 cm away. The Odyssey G9
  is the same 119.8 × 33.7 cm panel at 1000R: its edges are at ±42.0° from 80 cm, and ±34.3° from
  100 cm, where the eye is at the centre of curvature. The G9 is the most curved common panel, so
  it is the hardest of the reference setups.
- **Drawing method for curved screens (Jon, 2026-11-10): one flat render plus a final warp.**
  Rejected: several flat slices shown without a warp. For the G9's 84°, 3 slices still stretch
  about 6% at each slice's edges and 5 slices about 2%; straight lines kink at every seam;
  whole-image effects don't line up across slices; and every slice redraws the scene. With the
  warp, the slice count only affects detail, so slices are kept only as the very-wide-angle
  extension (FR-018). A single flat render at 84° has about 19% fewer pixels per degree at the
  centre than the screen needs, hence FR-006c (draw the off-screen image about 25% larger).
- The game already draws into off-screen images and runs a final pass when shaders are on, so the
  warp is one more step there; with shaders off there is no such pass, hence the flat fallback
  (FR-017).
- The 16:9 HUD and menu area (FR-016) is Jon's request; whether its aspect should be adjustable
  is left for `/speckit-clarify` (default: fixed 16:9).
- The settings live with the existing Game Options; whether they sit there or in the new GUI
  (spec 007) is a planning decision.
- Default values when nothing is saved or detected: 24" 16:9 flat at 60 cm.
