# Feature Specification: Mouse-look camera

**Feature Branch**: `004-mouse-look-camera`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Mouse look. Mouse look enables a player to right click and drag to
look left and right in the ship. When in 3rd person mode, right click and drag would rotate the
camera (ie, orbit camera.) The scroll wheel would move the camera further or closer. Holding both
mouse buttons and dragging would zoom, allowing vision of objects far away. This is like the EVE
Online mouse camera features."

Correction from the user: "Left click drag rotates the camera around the ship. Right click drag
doesn't move the camera, but angles it in different directions to allow looking sideways even
though the camera is away from the ship."

## Purpose

The player controls the camera with the mouse alone, the way EVE Online's camera works:

| Gesture | Cockpit view | External (3rd person) view |
|---|---|---|
| Left-drag | — | **Orbit**: the camera circles the ship, always facing it |
| Right-drag | **Look**: turn the head; the ship keeps its course | **Aim**: the camera turns where it stands, so it can look away from the ship |
| Scroll wheel | — | **Distance**: the camera moves closer to or further from the ship |
| Both buttons + drag | **Zoom**: magnify to see distant objects | **Zoom**: the same |

None of these changes where the ship flies or where its weapons point. They change only what the
player sees.

## Context

How the game behaves today, as seen by a player:

- **Views.** The cockpit has four fixed views (forward, aft, port, starboard), each with its own
  weapon mount. Most ships also define one or more **external views**: cameras placed outside the
  ship, which the player cycles through with a key.
- **External views can already be moved, but awkwardly.** With Caps Lock on, the player can rotate
  an external camera around the ship with a left-drag or the keyboard, and move it closer or
  further with the scroll wheel or Page Up/Down. The distance runs from 1.5 to 25 times the ship's
  size. Without Caps Lock the mouse does nothing to the camera.
- **The cockpit view can't be turned.** To look sideways the player has to switch to a fixed side
  view, which also switches the active weapon.
- **Zoom is fixed.** The field of view is a game setting (30°–80°). No in-flight magnification
  exists.
- **Mouse-steering mode** (toggled with a key) already claims the mouse. Moving the mouse steers
  the ship. Left button fires (in external views only when Caps Lock is off). Right button
  recentres the virtual stick. The wheel changes speed.

## User Scenarios & Testing *(mandatory)*

The users are players flying with the keyboard or a joystick, with the mouse free in their other
hand.

### User Story 1 - Look around from the cockpit (Priority: P1)

A player flying in the forward view holds the right mouse button and drags left. The view turns
left, as if the pilot turned their head. The ship keeps flying straight, and the forward weapon
stays the active one. When the player releases the button, the view eases back to straight ahead.

**Why this priority**: It's the gesture the user asked for first, and it has no workaround today:
switching to a side view changes the weapon and the view jumps 90°.

**Independent Test**: In flight, right-drag horizontally in the forward view. Check that the view
direction changes in proportion to the drag, the ship's heading is unchanged, the active weapon is
still the forward one, and the view is back to forward shortly after release.

**Acceptance Scenarios**:

1. **Given** the player is in the forward cockpit view, **When** they right-drag to the left,
   **Then** the view turns left in proportion to the drag distance and the ship's heading and
   active weapon are unchanged.
2. **Given** the player is right-dragging, **When** they drag up or down, **Then** the view tilts
   up or down.
3. **Given** the view is turned away from straight ahead, **When** the player releases the right
   button, **Then** the view returns smoothly to straight ahead within half a second.
4. **Given** the player keeps dragging in one direction, **When** the view reaches its limit,
   **Then** it stops turning (it never turns the full way round).
5. **Given** the player is in the port, aft or starboard view, **When** they right-drag, **Then**
   the view turns relative to that view's direction, and the same rules apply.

---

### User Story 2 - Orbit the ship in an external view (Priority: P1)

A player switches to an external view and left-drags. The camera circles the ship, always facing
it, so the player can see the ship from any side. The camera stays where it was left when the
button is released. No Caps Lock is needed.

**Why this priority**: It's the core of the EVE-style camera, and the game already supports it
behind Caps Lock. The feature makes it the default mouse behaviour.

**Independent Test**: In an external view with Caps Lock off, left-drag horizontally. Check that
the camera moves around the ship, still faces it, stays at the same distance, and holds its
position after release.

**Acceptance Scenarios**:

1. **Given** an external view with Caps Lock off, **When** the player left-drags horizontally,
   **Then** the camera circles the ship horizontally at a constant distance, facing it.
2. **Given** an external view, **When** the player left-drags vertically, **Then** the camera
   rises over or dips under the ship.
3. **Given** the camera has been orbited, **When** the player releases the button, **Then** the
   camera stays where it is.
4. **Given** an external view with Caps Lock on, **When** the player uses the existing Caps Lock
   camera controls, **Then** they behave as they do today.

---

### User Story 3 - Move the external camera closer or further (Priority: P2)

In an external view, the player rolls the scroll wheel. Rolling forward brings the camera closer
to the ship, and rolling back moves it away. No Caps Lock is needed.

**Why this priority**: It completes the external camera. It's lower priority than orbit because
it already works with Caps Lock.

**Independent Test**: In an external view with Caps Lock off, roll the wheel and check that the
camera's distance from the ship changes and stays within its limits.

**Acceptance Scenarios**:

1. **Given** an external view, **When** the player rolls the wheel forward, **Then** the camera
   moves towards the ship, and stops at the minimum distance.
2. **Given** an external view, **When** the player rolls the wheel back, **Then** the camera moves
   away from the ship, and stops at the maximum distance.
3. **Given** the cockpit view, **When** the player rolls the wheel, **Then** nothing changes
   about the camera.

---

### User Story 4 - Aim the external camera away from the ship (Priority: P2)

In an external view, the player right-drags. The camera stays where it is but turns, so the
player can look sideways at a station, a planet or another ship while the camera sits behind
their own ship. The camera keeps that angle when the button is released.

**Why this priority**: It's the second half of the EVE camera and depends on User Story 2's
external camera. It's less used than orbit.

**Independent Test**: In an external view, record the camera's position, right-drag, and check
that the position is unchanged, the direction it faces has changed, and the direction holds
after release.

**Acceptance Scenarios**:

1. **Given** an external view, **When** the player right-drags, **Then** the camera turns in
   place and its position does not change.
2. **Given** the camera is aimed away from the ship, **When** the player releases the button,
   **Then** the camera keeps its aim.
3. **Given** the camera is aimed away from the ship, **When** the player left-drags to orbit,
   **Then** the aim returns to the ship and the orbit proceeds as in User Story 2.
4. **Given** the camera is aimed away from the ship, **When** the player rolls the wheel,
   **Then** the camera moves closer to or further from the ship along its current line to the
   ship, and keeps its aim.

---

### User Story 5 - Zoom in on distant objects (Priority: P3)

The player holds both mouse buttons and drags up. The view magnifies, like a telescope, so a
distant ship or station fills more of the screen. Dragging down zooms back out to normal. It
works in the cockpit and in external views.

**Why this priority**: It's useful for spotting and identifying distant objects, but the game is
playable without it.

**Independent Test**: In the forward view, hold both buttons and drag up. Check that the field of
view narrows (a distant object's on-screen size grows), then drag down and check it returns to
the normal field of view and no wider.

**Acceptance Scenarios**:

1. **Given** any flight view, **When** the player holds both buttons and drags up, **Then** the
   view magnifies, up to the maximum magnification.
2. **Given** a magnified view, **When** the player holds both buttons and drags down, **Then** the
   view demagnifies, and stops at the player's normal field of view setting.
3. **Given** a magnified view, **When** the player releases the buttons, **Then** the
   magnification stays.
4. **Given** a magnified view, **When** the player switches view, **Then** the magnification
   resets to normal.

---

### Edge Cases

- **Both buttons in sequence.** The player holds one button, starts a drag, then presses the
  other. The first gesture ends where it is and zoom begins. When one button is released during a
  zoom, the zoom ends. The remaining button starts nothing until it is released and pressed
  again, so the camera never jumps.
- **A click without a drag** does nothing to the camera.
- **Mouse-steering mode is on.** The mouse keeps its mouse-steering meanings: steer, left fires,
  right recentres, wheel sets speed. Mouse look is inactive.
- **Non-flight screens** (status, charts, market, menus) and text entry: the mouse keeps its
  current meaning there. Mouse look is inactive.
- **Docked, launching, hyperspace, witchspace, death**: mouse look resets to neutral (cockpit
  look straight ahead, no zoom). External camera orbit and distance follow the existing rules for
  external views.
- **The game is paused**: orbit, aim, distance and zoom still work, as the Caps Lock controls do
  today, so the player can frame a view while paused. Cockpit look also works and springs back on
  release.
- **The window loses focus, or the pointer leaves the window, mid-drag.** Leaving the window does
  not end the drag. Losing focus ends it as if the buttons were released.
- **The ship has no external views.** The external-view gestures have nothing to act on. The
  cockpit gestures still work.
- **A script changes the view or the external camera** while the player is dragging. The script
  wins. The drag ends and the player's look and zoom reset to neutral.
- **The gunsight while looking away.** In the cockpit, the crosshair is hidden while the view is
  turned off-axis, because it no longer marks where the weapon points. It returns when the view
  is back to straight ahead.
- **A joystick or keyboard player who never touches the mouse** sees no change.

## Requirements *(mandatory)*

### Functional Requirements

**Cockpit look**

- **FR-001**: In any cockpit view, dragging with the right button held MUST turn the view
  horizontally and vertically in proportion to the drag distance.
- **FR-002**: Cockpit look MUST NOT change the ship's heading, its controls, or which weapon is
  active or where it points.
- **FR-003**: Cockpit look MUST be limited to 150° either side of the view's direction
  horizontally and 75° up or down vertically.
- **FR-004**: On release of the right button, the cockpit view MUST return smoothly to the view's
  normal direction within 0.5 seconds.
- **FR-005**: While the cockpit view is turned off-axis, the crosshair MUST be hidden.

**External camera**

- **FR-006**: In an external view, dragging with the left button held MUST orbit the camera
  around the ship at a constant distance, facing the ship, without Caps Lock.
- **FR-007**: In an external view, dragging with the right button held MUST turn the camera in
  place without changing its position.
- **FR-008**: In an external view, the scroll wheel MUST move the camera closer (forward roll) or
  further (back roll), within the distance limits external views already have (1.5 to 25 times
  the ship's size), without Caps Lock.
- **FR-009**: External camera orbit, aim and distance MUST persist after the buttons are released,
  until the player changes view or cycles to the next external view.
- **FR-010**: Starting an orbit MUST return the camera's aim to the ship.

**Zoom**

- **FR-011**: In any flight view, dragging with both buttons held MUST change magnification:
  dragging up magnifies, dragging down demagnifies.
- **FR-012**: Magnification MUST range from the player's normal field of view setting (no
  magnification) to at least 8× magnification.
- **FR-013**: Magnification MUST persist after release and reset to none when the player changes
  view.

**Coexistence**

- **FR-014**: Mouse look MUST be inactive while mouse-steering mode is on, on non-flight screens,
  and during text entry. In those states the mouse MUST behave exactly as it does today.
- **FR-015**: With Caps Lock on, the existing Caps Lock camera controls MUST behave as they do
  today.
- **FR-016**: Mouse look MUST reset to neutral when the player docks, launches, enters hyperspace
  or witchspace, or dies, and when a script changes the view.
- **FR-017**: The game options MUST include a setting to turn mouse look off. It is on by
  default. When off, the mouse MUST behave exactly as it does today.
- **FR-018**: A drag MUST continue when the pointer leaves the window, and MUST end when the
  window loses focus.

### Key Entities

- **Cockpit look offset**: how far the cockpit view is turned from the view's normal direction,
  horizontally and vertically. Transient: returns to zero on release.
- **External camera state**: the external camera's position around the ship (orbit), its
  distance from the ship, and its aim relative to the line to the ship. Persists until the view
  changes.
- **Magnification**: the current zoom factor, from 1× (the player's field of view setting) to the
  maximum. Persists until the view changes.
- **Mouse look setting**: the player's on/off choice, saved with the other game options.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the forward view, a horizontal right-drag of the same length always turns the
  view by the same angle (to within 1°), and the ship's heading changes by 0° over the drag.
- **SC-002**: After the right button is released in the cockpit, the view is straight ahead again
  within 0.5 seconds, every time.
- **SC-003**: In an external view, a left-drag that goes the full way round brings the camera back
  to its start position (to within 1°), at the same distance from the ship throughout (to within
  1%).
- **SC-004**: In an external view, a right-drag leaves the camera's position unchanged (to within
  1% of the ship's size) while its facing changes.
- **SC-005**: Zoom reaches at least 8× magnification, and zooming fully out always returns exactly
  to the player's field of view setting.
- **SC-006**: With mouse look turned off, or with mouse-steering mode on, every existing test
  passes unchanged.
- **SC-007**: A player new to the feature can look sideways from the cockpit, orbit their ship
  and zoom in on a distant station within one minute, without reading instructions.

## Assumptions

- **"3rd person" means the existing external views**, which ships define. This feature does not
  add external views to ships that have none.
- **Orbit centres on the ship's own centre of rotation**, the same point the Caps Lock controls
  orbit around today.
- **Drag sensitivity** uses a sensible fixed default. A sensitivity setting and an invert-vertical
  option are out of scope for this feature.
- **Mouse steering stays as it is.** Merging mouse look into mouse-steering mode is out of scope.
- **The verifying tests** are GUI tests that drive real mouse drags, and component scenarios that
  read the camera's state through the debug console. Both suites exist today.

## Decisions

Each one was taken as the conservative default without asking. `/speckit-clarify` can revisit
any of them.

1. **Cockpit look springs back on release; the external camera holds its aim.** The cockpit's
   reference is the gunsight, so a view that stayed turned would leave the player flying with no
   crosshair. The external camera is a spectator camera, so it keeps its aim, as in EVE.
2. **Mouse look is off while mouse-steering mode is on.** In that mode the left button fires and
   the right button recentres the stick. Taking those over would change the controls that
   mouse-steering players already rely on.
3. **The wheel does nothing to the cockpit camera.** The description only gave the wheel a meaning
   in third person. Zoom has its own gesture.
4. **Zoom resets on view change, not on release.** A telescope view that snapped back on release
   would force the player to hold both buttons to keep looking.
5. **The left button does nothing in the cockpit.** EVE has no cockpit, and nothing in the
   description assigns it one.
6. **Look limits of 150° horizontal and 75° vertical**, and a minimum of 8× zoom, are starting
   values. The plan can tune them. The tests check the limits that the plan sets.
