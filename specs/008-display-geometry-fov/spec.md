# Feature Specification: Display Geometry and Field of View (ultrawide and curved monitors)

**Feature Branch**: `008-display-geometry-fov`

**Created**: 2026-11-10

**Status**: Draft

**Input**: User description: "Double wide and curved monitor support. I want to enter the curvature and size of the monitor in the settings (or have it auto-detected), and then it should have the correct horizontal and vertical field of view. Also, it should not warp the view. It needs to look correct at the center and edges of the screen. So, we should also have a distance to monitor parameter most likely. (My goal isn't necessarily to have a realistic fov though, but the proportions should be accurate.)"

## Context

Today the space view has a single "Field Of View" option in Game Options. The game draws one flat
perspective view sized from that value: on screens up to 4:3 the value sets the horizontal angle,
and on wider screens the vertical angle stays fixed and the horizontal angle grows with the width.
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

### User Story 3 - A chosen field of view that keeps the proportions (Priority: P2)

The player does not want the true physical field of view (it can feel narrow) and sets a wider or
narrower one. The view widens or narrows but keeps the shape-correctness of Stories 1 and 2:
an object still has the same proportions at the edge as at the centre, it is only bigger or smaller
overall.

**Why this priority**: The request says a realistic field of view is not the goal, accurate
proportions are. This keeps that freedom without bringing back edge stretching. It needs the
geometry of Stories 1 and 2 first.

**Independent Test**: With the 49" curved settings, set the horizontal field of view to 120° and
check that the vertical field of view follows from the screen's proportions and that object
proportions stay within 2% from centre to edge.

**Acceptance Scenarios**:

1. **Given** screen-matching is on, **When** the player sets a horizontal field of view of 120°,
   **Then** the vertical field of view is derived from the screen shape (not entered separately)
   and both are shown.
2. **Given** a chosen field of view that differs from the physical one, **When** an object of fixed
   angular size moves from the centre to the edge, **Then** its width-to-height ratio stays within
   2% of its value at the centre.
3. **Given** a chosen field of view, **When** the player picks "use physical", **Then** the field of
   view returns to the value worked out from the screen and distance.

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
- **GUI screens and HUD**: menus, the status screens and the HUD are not re-projected; they keep
  their current layout. Only the 3D space view (all four views, and external views) changes.
- **Other camera features**: in-flight field-of-view control, mouse-look (spec 004), snapshots and
  the sun glare / break-pattern effects must use the same field of view as the space view, so
  nothing appears in the wrong place relative to the scene.
- **Targeting and aim**: the crosshair, scanner target reticle and any HUD marker placed over a
  ship must sit over that ship on the drawn view, including near the edges of a curved projection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Players MUST be able to turn screen-matching on or off in the game's settings; it is
  off by default.
- **FR-002**: With screen-matching off, the space view and the existing Field Of View option MUST
  behave exactly as they do now.
- **FR-003**: Players MUST be able to enter the screen's diagonal size (inches or centimetres),
  its aspect ratio (common presets 16:9, 16:10, 21:9, 32:9 and a custom value), and whether it is
  flat or curved with a curvature radius in the "R" notation monitors are sold with (e.g. 1800R =
  1800 mm).
- **FR-004**: Players MUST be able to enter their viewing distance from the centre of the screen.
- **FR-005**: The system MUST work out the horizontal and vertical field of view from the screen
  description and viewing distance, and show both to the player in the settings.
- **FR-006**: The system MUST draw the space view so that each point on the physical screen shows
  the scene in the direction of that point from the stated eye position (flat: a flat perspective;
  curved: a view matched to the curve).
- **FR-007**: Players MUST be able to replace the physical horizontal field of view with a chosen
  one; the vertical field of view MUST then follow from the screen's shape, and object proportions
  MUST stay correct from centre to edge (User Story 3).
- **FR-008**: Players MUST be able to return to the physical field of view in one action.
- **FR-009**: The system MUST try to detect the screen's physical size and aspect from the
  operating system when no screen description is saved, and MUST say whether detection succeeded.
- **FR-010**: Values the player enters MUST be saved with the other game preferences and MUST take
  precedence over detection on later runs.
- **FR-011**: Out-of-range values MUST be clamped to the limits in Edge Cases, and the clamped value
  shown.
- **FR-012**: HUD markers tied to objects in space (crosshair alignment, target reticle, sighting
  markers) MUST appear over the object they mark on the drawn view.
- **FR-013**: The field of view reported to scripts MUST be the horizontal field of view actually in
  use. [Default chosen: same meaning as today's value, so existing scripts keep working.]
- **FR-014**: The space view MUST keep the current frame rate within 5% on the reference machine
  with screen-matching on, for both flat and curved settings.
- **FR-015**: Changing any screen-matching setting MUST take effect without restarting the game.

### Key Entities

- **Screen description**: diagonal size, aspect ratio, flat or curved, curvature radius; source
  (entered or detected). Saved with preferences.
- **Viewer position**: distance from the eye to the centre of the screen, on the screen's centre
  line.
- **Field of view**: horizontal and vertical angles; either physical (worked out from screen and
  viewer) or chosen (horizontal set by the player, vertical derived).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For the three reference setups (27" 16:9 flat at 60 cm; 49" 32:9 1800R at 80 cm;
  Samsung Odyssey G9, 49" 32:9 1000R, at 80 cm and at 100 cm) the reported horizontal and vertical
  field of view match the values in Stories 1 and 2 within 0.5°.
- **SC-002**: With screen-matching on, an object of fixed angular size keeps its width-to-height
  ratio within 2% of its centre value anywhere across the horizontal extent of the screen, for every
  reference setup and for a chosen 120° horizontal field of view.
- **SC-003**: With screen-matching off, every existing test and snapshot comparison of the space
  view passes unchanged.
- **SC-004**: A player with a supported display that reports its size can go from turning on
  screen-matching to flying with correct proportions by entering at most two values (distance and,
  if curved, curvature).
- **SC-005**: Frame rate with screen-matching on is within 5% of frame rate with it off on the
  reference machine.

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
- With a chosen field of view (Story 3), proportions are kept by spacing the view evenly by angle;
  this means long straight lines may curve slightly towards the edges of a wide chosen view. This
  trade-off follows the request: proportions accurate, field of view not necessarily realistic.
  When the chosen field of view equals the physical one, the view is exactly the physical one and
  straight lines are straight.
- Reference values were computed from the screen geometry: 27" 16:9 is 59.8 × 33.6 cm; 49" 32:9 is
  119.8 × 33.7 cm, and with 1800R the edges are at ±40.0° from a seat 80 cm away. The Odyssey G9
  is the same 119.8 × 33.7 cm panel at 1000R: its edges are at ±42.0° from 80 cm, and ±34.3° from
  100 cm, where the eye is at the centre of curvature. The G9 is the most curved common panel, so
  it is the hardest of the reference setups.
- The settings live with the existing Game Options; whether they sit there or in the new GUI
  (spec 007) is a planning decision.
- Default values when nothing is saved or detected: 24" 16:9 flat at 60 cm.
