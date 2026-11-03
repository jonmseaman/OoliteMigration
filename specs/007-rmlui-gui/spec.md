# Feature Specification: Modernise the GUI with RmlUi

**Feature Branch**: `007-rmlui-gui`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "Modernize the gui with the C++ library rmlui."

## Purpose

The game's full-screen interface screens (status, market, shipyard, equipment, charts' text
panels, options, load and save, key and joystick configuration, mission screens) are rebuilt on
RmlUi, a C++ interface library laid out with HTML-like documents and CSS-like stylesheets. Players
get text that stays sharp at any window size, screens that work with the mouse as well as the
keyboard, and long lists that scroll. Contributors get screens described in documents and
stylesheets rather than row numbers and pixel offsets in C++. Expansions keep working without a
change.

## Context

How the GUI works today, as seen by a player and an expansion author:

- **One grid for every screen.** Each screen is a fixed grid of text rows with tab stops,
  sized for a 1024×768 canvas and scaled to the window. Long lists page with "more" rows rather
  than scrolling.
- **Bitmap font.** All text comes from one bitmap font texture, stretched to the window. At large
  window sizes it is soft; at small ones it is cramped.
- **Keyboard first.** Every screen is driven with the arrow keys and Enter. The mouse can pick a
  row on some screens, but nothing shows what is under the pointer, and the wheel does not scroll.
- **29 screens** share the grid: main menu and intro, ship library, new game, expansion manager,
  status, manifest, equip ship, shipyard, long and short range charts, system data, market and
  market info, options and game options, load, save and overwrite, joystick mapper and profile,
  mission, report, interfaces, and the keyboard configuration screens.
- **Expansions drive screens.** Mission screens, the interfaces screen, custom chart views,
  background and overlay images, 3D ship models behind the text, choice lists, text entry, and
  the GUI colour and background settings files are all set by expansions. Hundreds of published
  expansions depend on them.
- **The in-flight message area and comms log** are drawn by the same grid code, inside the HUD.
- **The chart graphics** (the star maps, routes and markers) are drawn directly, with the grid's
  text around them.
- **The tests** reach the screens through the GUI tier (PyAutoGUI against the real window: G4,
  G5, G8 and others) and through component scenarios over the debug console.

## User Scenarios & Testing *(mandatory)*

The users are players (keyboard, mouse, joystick; window sizes from a small laptop window to a
4K full screen), expansion authors who build mission screens, and contributors who change
screens.

### User Story 1 - Every screen works as it does today, on the new library (Priority: P1)

A player docks, opens each screen in turn with the function keys, buys fuel and cargo, changes
an option, saves the game and loads it again. Every screen shows the same information in the
same order, and every key does what it did before. The only visible differences are sharper
text and the layout adjusting to the window.

**Why this priority**: Nothing else is worth having if a screen loses a function. It is also the
largest piece of work, and the later stories build on it.

**Independent Test**: Run the existing GUI and component suites unchanged, then the new
per-screen scenarios (one per screen ID) that open the screen, check its title and rows through
the debug console, and drive one action with the keyboard.

**Acceptance Scenarios**:

1. **Given** the player is docked, **When** they open any of the 29 screens with its usual key or
   menu, **Then** the screen appears with the same title, rows, values and selectable items as
   today.
2. **Given** a screen with selectable rows, **When** the player uses the arrow keys and Enter,
   **Then** the selection moves and activates exactly as it does today, including skipping
   unselectable rows.
3. **Given** a list longer than the screen (market, equipment, shipyard, save files, key
   bindings), **When** the player moves past the last visible row, **Then** the list advances and
   no item becomes unreachable.
4. **Given** the player changes the window size or switches between windowed and full screen,
   **When** a screen is open, **Then** it re-lays out with nothing clipped or overlapping.
5. **Given** a screen that shows a 3D ship model or a chart behind or beside its text, **When** it
   opens, **Then** the model or chart appears as it does today and the text sits over it.

---

### User Story 2 - Expansion screens work unchanged (Priority: P1)

An expansion author's mission screen, written for Oolite 1.93, shows its title, message text,
background and overlay images, ship model, choice list or text entry, and returns the player's
choice to the expansion's callback. The author changes nothing.

**Why this priority**: Published expansions are a goal of the whole migration. A GUI that breaks
them can't go upstream.

**Independent Test**: Component scenarios that call the mission-screen and interfaces-screen
scripting entry points with each documented option, through the debug console, and check what
is shown and what the callback receives. No expansion content is read; the scenarios are written
from the documented scripting interface.

**Acceptance Scenarios**:

1. **Given** a script opens a mission screen with a title, message and choices, **When** the
   player picks a choice, **Then** the callback receives that choice's key, as today.
2. **Given** a script opens a mission screen with text entry, **When** the player types and
   presses Enter, **Then** the callback receives the typed text.
3. **Given** a script sets background or overlay images, a ship model, a custom chart view, or
   the screen it exits to, **When** the screen opens and closes, **Then** each takes effect as
   today.
4. **Given** a script adds entries to the interfaces screen, **When** the player selects one,
   **Then** the script's callback runs.
5. **Given** an installed expansion overrides the GUI colour or screen background settings files,
   **When** a screen opens, **Then** those colours and backgrounds are used.
6. **Given** a mission message too long for one screen, **When** it is shown, **Then** it wraps
   and continues as it does today, with no text lost.

---

### User Story 3 - Use the screens with the mouse (Priority: P2)

A player rests the pointer on a row in the market. The row highlights. One click selects it, the
same as the arrow keys would; activating it does what Enter does. The wheel scrolls long lists.

**Why this priority**: It's the most visible gain from a modern interface library, but it is new
behaviour, so it comes after parity.

**Independent Test**: GUI-tier tests that hover, click and scroll on the market, equipment and
load screens, and check the selection and the result through the debug console.

**Acceptance Scenarios**:

1. **Given** a screen with selectable rows, **When** the pointer rests on a selectable row,
   **Then** that row is highlighted without changing the keyboard selection's meaning.
2. **Given** a selectable row, **When** the player clicks it, **Then** it becomes the selected
   row; **When** they activate it (double-click), **Then** the screen acts as for Enter.
3. **Given** a list longer than the screen, **When** the player rolls the wheel, **Then** the list
   scrolls.
4. **Given** an unselectable row, **When** the player clicks it, **Then** nothing happens.
5. **Given** the player is flying (no GUI screen open), **When** they use the mouse, **Then** it
   behaves as today (mouse steering, camera), unchanged by this feature.

---

### User Story 4 - Sharper, adaptive look (Priority: P2)

On a 4K display the screens' text is crisp. On a small window it stays readable. The look is a
modern restyle of the current one, in the game's colours, and a player who prefers the classic
look can choose it in the game options.

**Why this priority**: It's the "modernise" in the request, but it's taste, so it goes after the
functional stories.

**Independent Test**: Snapshot each screen at three window sizes in both looks; check text is
rendered at the window's resolution (no stretched bitmap), nothing overlaps, and the option
switches looks without a restart.

**Acceptance Scenarios**:

1. **Given** a window of any supported size, **When** a screen is open, **Then** its text is
   rendered at the window's own resolution.
2. **Given** the game options screen, **When** the player switches between the modern and classic
   looks, **Then** every screen uses the chosen look from then on, and the choice is saved.
3. **Given** the classic look, **When** a screen is compared with today's, **Then** layout,
   colours and font face match.

---

### User Story 5 - Contributors change a screen without touching layout code (Priority: P3)

A contributor moves a column on the status screen or changes the selection colour by editing that
screen's document or the shared stylesheet, then restarts the game. They don't recompile.

**Why this priority**: It's the long-term maintainability gain, and it falls out of stories 1 and
4 once each screen has a document.

**Independent Test**: Change one property in the shared stylesheet in a test build, and check
through a snapshot that the screen reflects it without a rebuild.

**Acceptance Scenarios**:

1. **Given** a screen's layout document, **When** a contributor edits it and restarts, **Then**
   the change shows without a rebuild.
2. **Given** a malformed screen document, **When** the game starts, **Then** it logs which file
   and line failed and shows that screen in a plain fallback layout rather than crashing.

### Edge Cases

- A screen is opened before the interface library has finished loading its documents and fonts
  (first frame, or straight after a window resize).
- A text string contains characters the font lacks (non-Latin text from a localisation or an
  expansion): it shows a placeholder glyph, never a crash or a blank screen.
- An expansion sets text containing characters that look like markup (`<`, `&`): it is shown
  literally, never interpreted.
- An expansion's background or overlay image is missing or not a usable image: the screen opens
  without it and the log says so, as today.
- The window is shrunk below the design minimum (smaller than 800×600): the screen scales down
  and stays usable; nothing is cut off without a way to reach it.
- A mission screen is opened while another screen is open, or from a callback of a mission
  screen: the screen stack and exit-screen behaviour match today's.
- The game is paused, or in the middle of a hyperspace countdown, when a screen is opened or
  closed.
- A keyboard, joystick and mouse act at the same time on a screen: there is one selection, and
  the last input wins.
- A very long list (hundreds of save files or key bindings): opening and scrolling stay smooth.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All 29 GUI screens MUST be drawn and laid out through RmlUi.
- **FR-002**: Each screen MUST show the same information, and accept the same keys and joystick
  input with the same results, as it does today.
- **FR-003**: Every scripting entry point expansions use for screens (the mission screen and its
  options, the interfaces screen, custom chart views, screen backgrounds, GUI colour settings, the
  legacy mission-screen script commands) MUST keep its present names, arguments, defaults and
  results.
- **FR-004**: Text supplied by scripts or game data MUST be shown as plain text. It MUST never be
  interpreted as layout markup, styles or code.
- **FR-005**: Expansions MUST NOT be able to supply their own layout documents or stylesheets
  through this feature. That would be a new expansion interface and a separate decision.
- **FR-006**: Screens MUST re-lay out when the window size or full-screen mode changes, and
  render text at the window's resolution.
- **FR-007**: On every screen with selectable rows, the pointer MUST highlight the row under it,
  a click MUST select it, a double-click MUST activate it, and the wheel MUST scroll a list
  longer than the screen.
- **FR-008**: The game options MUST offer a modern and a classic look; the choice MUST be saved
  with the other settings and take effect without a restart.
- **FR-009**: Screen layouts and the shared styles MUST live in data files shipped with the game,
  read at start-up.
- **FR-010**: A screen document or stylesheet that fails to load MUST be logged with its file and
  line, and the screen MUST still open in a plain fallback layout.
- **FR-011**: 3D ship models, chart graphics and background images shown on screens today MUST
  still appear in the same places, with the interface drawn over them.
- **FR-012**: The in-flight HUD, including its message area and comms log, MUST look and behave
  as it does today.
- **FR-013**: The debug console MUST be able to report the open screen's ID, title, rows and
  selected row, so that component scenarios can check screens without reading pixels.
- **FR-014**: The game MUST build and pass its test suites with the new library on every
  platform it builds on today, with both supported compilers, and the library MUST NOT bring
  `libgnustep-base`, Objective-C or `JS_*` symbols back.
- **FR-015**: When the last screen has moved, the old grid drawing code that only the screens
  used MUST be removed. Code the HUD still needs stays.

### Key Entities

- **Screen**: one of the 29 GUI screen IDs. It has a title, rows of text or controls, an
  optional selection, an optional background, model or chart, and the screen it exits to.
- **Screen document**: the layout of one screen, shipped as game data.
- **Stylesheet / look**: the shared visual rules: font, colours, spacing, highlight. There are
  two looks, modern and classic.
- **Row**: a line in a screen: its text (or columns), its key, whether it can be selected, and
  its colour.
- **Mission screen request**: what a script asks for (title, message, choices, text entry,
  images, model, exit screen, callback) and what it gets back.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 29 screens open, show their content and complete their main action, checked by
  one automated scenario per screen, all passing.
- **SC-002**: Every existing GUI, component, unit and smoke test passes without being modified.
- **SC-003**: Every documented mission-screen and interfaces-screen option has an automated
  scenario that passes, and the expansion-facing scripting interface has no added, removed or
  renamed entries.
- **SC-004**: At window sizes 1024×768, 1920×1080 and 3840×2160, no screen has clipped or
  overlapping text, checked by snapshot in both looks.
- **SC-005**: Every selectable row on every screen can be selected with one click and activated
  with a double-click, checked by GUI-tier tests on at least the market, equipment, shipyard,
  load and game options screens.
- **SC-006**: With a screen open, frame time on the reference machine is no more than 10% above
  today's, and a 500-row list scrolls without a frame over 33 ms.
- **SC-007**: A change to a screen document or the shared stylesheet shows after a restart with
  no rebuild.
- **SC-008**: Script-supplied text containing markup characters is shown literally in 100% of
  the scenarios that test it.

## Assumptions

- **RmlUi is the library.** The user chose it. It is MIT-licensed, which can be shipped with a
  GPL game. It needs FreeType, which comes in the same way as the other third-party code: a
  pinned version in the build's subprojects, built on Windows, macOS and Linux.
- **Scope is the 29 full-screen GUI screens.** The in-flight HUD, its message area and comms log,
  and the crosshairs stay as they are. They are configured by expansion HUD files, and moving them
  would be a separate feature.
- **Chart graphics are not redrawn.** The star maps, routes and markers keep their present drawing
  code. RmlUi lays out the text and panels around them.
- **Parity first, then the new look.** Each screen moves on its own with the classic look and must
  pass its parity scenario (User Stories 1 and 2) before mouse support and the modern look are
  turned on for it. The old and new drawing paths exist side by side until the last screen moves.
- **Rendering.** RmlUi draws through the game's existing graphics layer. The move to GL 3.3 Core
  (Phase 6) is not part of this feature, and must not be blocked by it.
- **Fonts.** The classic look uses a scalable font that matches the present bitmap face as closely
  as possible; the font file and its licence are recorded in the plan.
- **Phase.** This is a design change of the kind Phase 6 holds. It runs on its own feature branch
  in `oolite-dev`, with the test suites as the gate, and does not hold up Phase 4p or Phase 5.
- **Expansions.** No expansion content is read to build or test this feature. Compatibility is
  shown from the documented scripting interface.
- **Localisation.** Present text strings and localisation files are reused unchanged. Right-to-left
  scripts are out of scope.

## Notes

Decisions taken without asking, with the conservative default (CLAUDE.md rule 8):

- **Scope** — The 29 GUI screens only, not the HUD. The request says "GUI", and the HUD is a
  separate, expansion-configured system.
- **Look** — Today's look stays available as "classic". The modern look is a restyle, not a
  redesign of each screen's content.
- **Expansions** — No new expansion interface (FR-005). Letting expansions ship RmlUi documents is
  worth considering later, but expansion files are untrusted input and that needs its own spec.
