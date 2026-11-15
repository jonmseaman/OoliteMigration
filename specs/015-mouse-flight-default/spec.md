# Feature Specification: Mouse flight, easy to use and one setting away

**Feature Branch**: `015-mouse-flight-default` (planning repo); the game work goes on an
`oolite-dev` `feature/…` branch named at plan time

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Make mouse flight easy to use and, optionally, on by default. It
should feel like Elite Dangerous, where steering with the mouse is the main control. Cover a saved
preference to start flights with mouse flight on and which axis the mouse's sideways movement
steers (yaw or roll); allowing it in windowed mode by default or exposing that on the Game Options
screen; whether the default changes for everyone (the fork is being polished for upstream, so a
changed default must be argued, and the conservative default is 'off, but one setting away');
and how it fits with spec 004 (mouse-look) and spec 008 (display geometry)."

## Purpose

A player who wants to fly with the mouse turns it on once, in Game Options, and from then on every
flight starts with the mouse steering the ship. It works in a window as well as full screen, the
player can see how hard they are steering, and the mouse feels the same on any shape of screen.
Players who never touch the setting see the game they know.

## Context

How mouse flight works today, as a player sees it:

- **Turning it on.** In flight, Shift+M turns mouse flight on with the mouse's sideways movement
  rolling the ship and its up-and-down movement pitching it. Ctrl+Shift+M turns it on with
  sideways movement yawing instead. Either key turns it off. The keys can be rebound in Keyboard
  Configuration. A message says "Mouse control on." or "Mouse control off."
- **It is never remembered.** Starting a new game or loading a commander turns mouse flight off,
  so every session starts with it off and the player has to find and press the key again. Within
  a session it stays on across docking and launching, and across death and restart.
- **Full screen only.** In a window the keys do nothing unless the player has edited a hidden
  preference (`mouse-control-in-windowed-mode`). Switching from full screen to a window turns
  mouse flight off. Debug builds allow it everywhere.
- **The pointer can wander.** A second hidden preference (`grab-mouse-on-mouse-control`) keeps the
  pointer inside the game window. It is off by default.
- **How it steers.** The mouse moves a virtual stick: moving the mouse deflects the stick, and the
  stick stays where it was left (it does not spring back). The right button recentres it. The left
  button fires, and the scroll wheel changes speed. While mouse flight is on, the mouse's steering
  takes precedence over a joystick's.
- **The stick can't be seen.** Nothing on the default HUD shows a mouse-only player where the
  virtual stick is. The HUD's stick-sensitivity dial is drawn only when a joystick is plugged in.
- **Sensitivity depends on the window.** How far the mouse must move to reach full deflection is a
  fraction of the window's width (sideways) and height (up and down), set by a third hidden
  preference (`mouse-flight-sensitivity`). So sideways steering is slower than up-and-down
  steering by the window's aspect ratio. On a 1920×1080 screen, full sideways deflection takes
  about 1,090 pixels of mouse travel and full up-and-down deflection about 620. On a 5120×1440
  ("double wide") screen it is about 2,920 sideways and 820 up and down: sideways is 3.6 times
  slower than vertical.
- **Related specs.** Spec 004 (mouse-look camera, not built) gives the mouse camera controls and
  is inactive while mouse flight is on. Spec 008 (display geometry, in progress) changes how the
  space view is drawn on wide and curved screens. It requires that anything turning a screen
  position into a direction in space use the same mapping as the drawn view, and it keeps the
  crosshair at the window's centre.

## User Scenarios & Testing *(mandatory)*

The users are players who steer with the mouse and use the keyboard for everything else, the
way Elite Dangerous is commonly played, and existing players who fly with keyboard or joystick.

### User Story 1 - Every flight starts with mouse flight on (Priority: P1)

A player opens Game Options and sets **Mouse Flight at Launch** to "On, mouse steers yaw". They
launch from the station: mouse flight is already on, the stick is centred so the ship flies
straight out, and moving the mouse sideways yaws the ship. They quit, start the game the next
day, load their commander and launch: mouse flight is on again. The Shift+M and Ctrl+Shift+M keys
still work as before during the flight.

**Why this priority**: It's the request's core. Without a saved setting, mouse flight can never
be the player's primary control: it has to be rediscovered and re-enabled every session.

**Independent Test**: Set the option to each of its three values, restart the game, load a
commander and launch. Check mouse flight is off, on with roll, or on with yaw respectively, and
that the ship's turn rates are zero until the mouse moves.

**Acceptance Scenarios**:

1. **Given** Mouse Flight at Launch is "On, mouse steers roll", **When** the player launches,
   **Then** mouse flight is on, sideways mouse movement rolls the ship, up-and-down movement
   pitches it, and the stick starts centred.
2. **Given** the option is "On, mouse steers yaw", **When** the player launches, **Then** mouse
   flight is on and sideways movement yaws the ship.
3. **Given** the option is set to on, **When** the player quits, restarts the game, loads a
   commander and launches, **Then** mouse flight is on with the chosen axis.
4. **Given** mouse flight started on, **When** the player presses Shift+M, **Then** mouse flight
   turns off for the rest of this flight, and **When** they dock and launch again, **Then** it is
   on again.
5. **Given** the option is "Off", **When** the player launches, **Then** mouse flight behaves
   exactly as today: off after starting or loading a commander, toggled only by the keys.
6. **Given** the option is set to on, **When** the player dies and the game restarts them at a
   station and they launch, **Then** mouse flight is on.
7. **Given** the player changes the option during a flight, **When** they return to the flight,
   **Then** the current flight is unchanged and the new value applies from the next launch.

---

### User Story 2 - Mouse flight in a window (Priority: P1)

A player who plays in a window presses Shift+M, or launches with Mouse Flight at Launch on. Mouse
flight turns on, the pointer disappears and can't leave the window while they fly, so a fast
mouse movement never ends up clicking on the desktop. When they pause, open a game screen that
uses the pointer, turn mouse flight off, or switch to another application, the pointer is theirs
again.

**Why this priority**: A setting that silently does nothing in a window would look broken, and
many players play in a window. It's needed for User Story 1 to work for them.

**Independent Test**: In a window with no hidden preferences set, press Shift+M and check mouse
flight turns on. Move the mouse hard towards each edge and check the pointer stays inside the
window. Turn it off and check the pointer can leave.

**Acceptance Scenarios**:

1. **Given** the game is in a window and no hidden mouse preference has been set, **When** the
   player presses Shift+M in flight, **Then** mouse flight turns on.
2. **Given** mouse flight is on in a window, **When** the player moves the mouse fast past any
   edge of the window, **Then** the pointer stays inside the window and steering keeps
   responding.
3. **Given** mouse flight is on in a window, **When** the player turns it off, pauses, opens a
   screen that uses the pointer, or switches to another application, **Then** the pointer is
   released and can leave the window.
4. **Given** the pointer was released for one of those reasons, **When** the player returns to
   flight with mouse flight still on, **Then** the pointer is confined again and the stick is
   centred.
5. **Given** mouse flight is on, **When** the player switches between full screen and a window,
   **Then** mouse flight stays on.
6. **Given** the player has explicitly saved the old windowed-mode preference as off, **When**
   they press Shift+M in a window, **Then** nothing happens, as today.

---

### User Story 3 - See where the mouse is steering (Priority: P2)

With mouse flight on, a small indicator sits on the crosshair: a ring marking full deflection and
a dot showing where the virtual stick is. When the player moves the mouse right, the dot moves
right and the ship turns. When they right-click to recentre, the dot jumps back to the centre and
the ship stops turning.

**Why this priority**: Because the stick does not spring back, a player who can't see it can't
tell whether the ship will keep turning. It's the single largest difference from the Elite
Dangerous feel, where the mouse's deflection is always shown.

**Independent Test**: With mouse flight on and no joystick, move the mouse to several positions
and check the indicator's dot matches the stick's deflection, reaches the ring at full
deflection, and returns to the centre on right-click.

**Acceptance Scenarios**:

1. **Given** mouse flight is on with the default HUD, **When** the player is in any cockpit view,
   **Then** the indicator is shown centred on the crosshair.
2. **Given** the indicator is shown, **When** the player deflects the stick, **Then** the dot's
   offset from the centre is in the same direction and proportion as the deflection, and it
   touches the ring at full deflection.
3. **Given** the stick is deflected, **When** the player right-clicks, **Then** the dot returns to
   the centre.
4. **Given** mouse flight is off, **When** the player flies, **Then** no indicator is shown.
5. **Given** the player hides the HUD, **When** mouse flight is on, **Then** the indicator is
   hidden with it.
6. **Given** mouse flight is on in an external view, **When** the player looks at the screen,
   **Then** the indicator is shown at the screen centre where the crosshair would be.

---

### User Story 4 - The same feel on any screen, and a sensitivity setting (Priority: P2)

A player with a double-wide monitor moves the mouse the same distance sideways and up: the stick
deflects the same amount on both axes. Their friend on a 16:9 monitor gets the same deflection
from the same mouse movement. Both find the movement a little fast, so they lower **Mouse
Sensitivity** in Game Options.

**Why this priority**: On wide screens (spec 008's subject) sideways steering is today several
times slower than vertical, which makes yaw-on-the-mouse, the Elite Dangerous layout, feel
broken. A sensitivity the player can't reach without editing a file is not easy to use.

**Independent Test**: In windows of 1920×1080 and 3840×1080, move the mouse by the same count
sideways and then up. Check the stick's deflection is equal on both axes and in both windows.
Change Mouse Sensitivity and check the deflection for the same movement changes.

**Acceptance Scenarios**:

1. **Given** mouse flight is on, **When** the mouse moves the same distance sideways as it does
   up, **Then** the stick deflects by the same amount on both axes.
2. **Given** two windows of different width, or the same window resized, **When** the mouse makes
   the same movement, **Then** the stick deflects by the same amount.
3. **Given** a 1080-pixel-high window and the default sensitivity, **When** the mouse moves up,
   **Then** the up-and-down deflection is the same as today's.
4. **Given** the player raises Mouse Sensitivity, **When** they make the same movement, **Then**
   the stick deflects further, and lowering it deflects less.
5. **Given** the player had set the hidden sensitivity preference by hand, **When** they open Game
   Options, **Then** Mouse Sensitivity starts from their value (clamped to the limits under Edge
   Cases), and in a 1080-pixel-high window up-and-down steering is as it was.

---

### User Story 5 - Players can find mouse flight (Priority: P3)

When mouse flight turns on, the message says what the mouse now does and how to turn it off, using
the player's own key binding: for example "Mouse flight on: mouse steers yaw and pitch.
Shift+M to turn off."

**Why this priority**: A small change that removes the most common confusion (a ship that will
not stop turning because mouse flight was turned on by accident) without changing any default.

**Independent Test**: Rebind the mouse flight key, turn mouse flight on with each key, and check
the message names the axes and the rebound key.

**Acceptance Scenarios**:

1. **Given** the default keys, **When** the player presses Ctrl+Shift+M, **Then** the message says
   the mouse steers yaw and pitch and names the key that turns it off.
2. **Given** the player has rebound the mouse flight keys, **When** mouse flight turns on, **Then**
   the message names the rebound key.
3. **Given** mouse flight turns on at launch from the setting, **When** the player launches,
   **Then** the same message is shown.
4. **Given** mouse flight turns off, **When** the message is shown, **Then** it says mouse flight
   is off.

---

### Edge Cases

- **A joystick is plugged in** and Mouse Flight at Launch is on. The mouse takes precedence for
  steering, as it does today whenever mouse flight is on. Game Options says so next to the
  setting, so a joystick player who turns it on knows why the stick stopped steering.
- **The mouse is moving at the moment of launch.** The stick starts centred, and only movement
  after the launch deflects it.
- **Returning to flight from a screen that used the pointer** (status, chart, market, options,
  pause). The stick is centred on return, so the pointer's position on that screen never becomes
  a steering input.
- **The window loses focus mid-flight.** The pointer is released and the stick is centred, so the
  ship stops turning while the player is in another application.
- **Text entry screens.** The mouse flight keys are ignored there, as today.
- **Docked, hyperspace, witchspace, death.** Mouse flight's state carries through these as it does
  today; the setting only decides the state at launch.
- **Spec 004 mouse-look.** While mouse flight is on, mouse-look is inactive (spec 004, FR-014). A
  player who sets Mouse Flight at Launch to on reaches mouse-look by pressing Shift+M to turn
  mouse flight off for that flight.
- **External views.** Mouse flight keeps today's rules there (the wheel and left button defer to
  the Caps Lock camera controls). The indicator still shows the stick.
- **Expansion HUDs.** A HUD supplied by an expansion shows the indicator only if it includes it.
  Expansion HUD layouts are not changed.
- **Scripts that ask whether mouse control is on** get the true state, including when the setting
  turned it on.
- **Minimum and maximum sensitivity.** Mouse Sensitivity is limited to a range in which full
  deflection takes between 100 and 4,000 pixels of mouse travel, so it can't be set to a value at
  which the ship can't be steered.
- **The old windowed preference saved as on** still allows mouse flight in a window, as today. Only
  an explicitly saved "off" blocks it (User Story 2, scenario 6).
- **Debug builds** allow mouse flight everywhere, as today.

## Requirements *(mandatory)*

### Functional Requirements

**Starting flights with mouse flight on**

- **FR-001**: Game Options MUST offer **Mouse Flight at Launch** with three values: Off; On, mouse
  steers roll; On, mouse steers yaw. The default MUST be Off.
- **FR-002**: The setting MUST be saved with the other game preferences and survive restarting the
  game.
- **FR-003**: When the setting is on, every launch from a station MUST start with mouse flight on,
  with the chosen axis on sideways mouse movement, pitch on up-and-down movement, and the stick
  centred.
- **FR-004**: When the setting is Off, mouse flight MUST behave exactly as it does today, apart
  from FR-006 to FR-012, which apply to mouse flight however it was turned on.
- **FR-005**: The mouse flight keys MUST keep their current meanings in flight. Turning mouse
  flight off or on with them MUST NOT change the saved setting. A change made with them lasts
  until the next launch.

**Windowed play**

- **FR-006**: Mouse flight MUST be available in a window by default. An explicitly saved value of
  the old windowed-mode preference MUST still be honoured.
- **FR-007**: While mouse flight is on and the flight view is shown, the pointer MUST be hidden
  and MUST NOT leave the game window, in a window or full screen.
- **FR-008**: The pointer MUST be released when mouse flight turns off, the game pauses, a screen
  that uses the pointer opens, or the game window loses focus. It MUST be confined again when the
  player returns to the flight view with mouse flight on.
- **FR-009**: Switching between full screen and a window MUST NOT turn mouse flight off.

**Steering feel**

- **FR-010**: The stick MUST be centred at launch, on return to the flight view from any screen
  that used the pointer, and when the window loses focus. The right button MUST still recentre it.
- **FR-011**: The same mouse movement MUST deflect the stick by the same amount on both axes,
  whatever the window's size and shape. At the default sensitivity, in a window 1,080 pixels high,
  up-and-down deflection MUST match today's.
- **FR-012**: Game Options MUST offer **Mouse Sensitivity**, saved with the other game
  preferences, which scales deflection per unit of mouse movement within the limits under Edge
  Cases. A value already saved in the hidden sensitivity preference MUST be used as the starting
  value, clamped to those limits.

**Seeing the stick**

- **FR-013**: While mouse flight is on, the default HUD MUST show a deflection indicator centred on
  the crosshair: a ring marking full deflection and a dot at the stick's current deflection, in
  every flight view.
- **FR-014**: The indicator MUST hide with the HUD, MUST NOT be shown while mouse flight is off,
  and MUST NOT be added to HUDs supplied by expansions.

**Messages and discoverability**

- **FR-015**: The message shown when mouse flight turns on MUST say which axes the mouse steers
  and name the key, as currently bound, that turns it off. The message when it turns off MUST say
  it is off.
- **FR-016**: Game Options MUST say, beside Mouse Flight at Launch, that mouse steering takes
  precedence over a joystick while it is on.
- **FR-017**: The mouse settings of this spec and the mouse-look setting of spec 004 MUST be
  shown together in Game Options.

**Coexistence**

- **FR-018**: Mouse-look (spec 004) MUST remain inactive while mouse flight is on.
- **FR-019**: Mouse flight MUST NOT turn a screen position into a direction in space. If a later
  feature does (for example steering towards the pointer), it MUST use spec 008's mapping
  (spec 008, FR-012).

### Key Entities

- **Mouse Flight at Launch**: the player's saved choice: off, or on with roll or yaw on the
  mouse's sideways movement. Read at each launch.
- **Mouse Sensitivity**: the player's saved choice of stick deflection per unit of mouse
  movement, the same on both axes. Starts from any value already saved by hand.
- **Mouse flight state**: whether mouse flight is on during the current flight, and which axis
  sideways movement steers. Set by the setting at launch and by the keys during flight.
- **Virtual stick**: the deflection the mouse has built up, on two axes, each up to a fixed
  maximum. Centred at launch, on return to flight, on focus loss and by the right button.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With Mouse Flight at Launch on, 100% of launches (after a restart, after docking,
  after death) start with mouse flight on with the chosen axis, and the ship's turn rates are zero
  until the mouse moves.
- **SC-002**: With the setting Off and in full screen, every existing test passes unchanged and
  the keys behave as today.
- **SC-003**: The same mouse movement gives the same deflection sideways and vertically, and in a
  1920×1080, a 3840×1080 and a 5120×1440 window, each to within 2%. In a 1080-pixel-high window at
  default sensitivity, vertical deflection matches today's to within 2%.
- **SC-004**: With mouse flight on in a window, during 60 seconds of fast movement towards every
  edge the pointer leaves the window 0 times; after turning it off, the pointer can leave
  immediately.
- **SC-005**: The indicator's dot sits within 5% of the ring's radius of the position the stick's
  deflection implies, touches the ring at full deflection, and is at the centre after a right
  click.
- **SC-006**: A player who has never used the feature can, from the title screen, turn on Mouse
  Flight at Launch and launch with the mouse steering in under one minute without instructions.

## Assumptions

- **"A launch"** is leaving a station by the launch command, including the launch after a death
  and restart. Starting a session never puts the player in flight without a launch, because saved
  games always start docked.
- **The verifying tests** are GUI tests that drive the real mouse and Game Options screen, and
  component scenarios that read the mouse flight state and the stick through the debug console.
  Both suites exist today. The windowed tests take the desktop lock like every other GUI test.
- **Game Options has limited room.** The plan may put the mouse settings on a sub-screen reached
  from one Game Options row, as Joystick Configuration and Keyboard Configuration are, as long as
  FR-017 holds.
- **The indicator is a flat HUD element** drawn in screen space around the crosshair, which spec
  008 keeps at the window centre for every projection. It marks a stick deflection, not a
  direction in space, so it needs no projection mapping.
- **The axis choice of the setting** applies only when the setting turns mouse flight on. In
  flight, the two keys still choose roll or yaw, as today.

## Out of scope

- **Changing the default to on for everyone** (Decision 1).
- **A stick that springs back to centre** when the mouse stops (a "relative mouse" mode). It
  changes the control law and deserves its own spec.
- **Mouse-look while mouse flight is on** (for example holding a key to look around). It's a
  change to spec 004's rules and belongs to that spec or a follow-up.
- **Steering towards the pointer**, invert-vertical, a dead zone, and separate sensitivities per
  axis.
- **Keyboard and joystick behaviour**, which this spec does not change.

## Decisions

No question went to Jon. Each choice below is a conservative default taken under the project's
"never wait for Jon" rule; `/speckit-clarify` can revisit any of them.

1. **The default stays Off for everyone; on is one setting away.** The fork is being prepared for
   upstream, and turning mouse flight on by default would change the game for every existing
   player at their first launch: the mouse would steer, the left button would fire, the wheel
   would change speed, and, because mouse steering takes precedence over a joystick, joystick
   players would find their stick no longer steers. A player who wants Elite Dangerous-style
   flight sets one option once. A changed default can be proposed later, with play-testing, as
   its own change.
2. **Mouse flight is allowed in a window by default, with the pointer confined.** This is a
   changed default, argued as follows: today the keys do nothing in a window, so no existing
   behaviour is taken away; the restriction protected players from a pointer that wandered out
   of the window, which confinement now prevents; and without it, the new setting would silently
   fail for every windowed player. An explicitly saved "off" is still honoured. Confinement is
   forced while flying instead of left to the old opt-in preference, because a pointer that can
   leave the window during mouse flight is the failure the restriction existed for.
3. **The setting is read at each launch; the keys don't change it.** The setting is named for what
   it promises (every flight starts on). Saving the last key state instead would let one stray
   Shift+M change the next session. With the setting Off, today's within-session behaviour is
   kept.
4. **One setting with three values** (off, roll, yaw) rather than two settings, because Game
   Options is crowded and the axis choice means nothing when the setting is off.
5. **Equal sensitivity on both axes, independent of the window.** Today's difference between axes
   follows the window's shape by accident, so there is no single "today" for sideways steering to
   preserve. Up-and-down steering keeps its current feel at the most common screen height
   (1,080 pixels); sideways steering gets faster by the screen's aspect ratio. This changes the
   feel for existing mouse-flight players, and Mouse Sensitivity lets them adjust it.
6. **The indicator is on the default HUD only.** Expansion HUDs define their own layouts, and
   adding elements to them would move or overlap what their authors placed.
7. **Mouse-look stays off while mouse flight is on** (spec 004's rule, kept). In mouse flight the
   right button recentres and the left button fires; giving them camera meanings would change
   controls mouse-flight players rely on.
8. **A setting change in flight applies from the next launch**, so changing options never changes
   the controls under the player's hand mid-flight. The keys are there for an immediate change.
