# Feature Specification: Headless component tests

**Feature Branch**: `011-headless-component-tests`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "I need c++ component tests that can simulate the game faster than
real time, but without graphics. This is to enable testing things like spawning each ship and
module type to make sure they all work. Make sure menus can work on each platform (there were some
issues with the flatpack build only reported recently. Someone wan't able to press n in the
tutorial, who knows why)."

Follow-up (Jon, 2026-11-13, during specification): "When you go and implement, be sure to make a
new worktree off the most recent seriesb branch for oolite-dev."

## Purpose

The game gets a tier of C++ tests that run the real simulation in the test's own process, with no
window, graphics card, sound device or keyboard. Time in these tests is simulated, so a test
covers minutes of game time in seconds of real time.

The tier is built for three uses, and all three ship with it:

- **A census of the game's content.** Every ship and every equipment item in the core data is
  created, run for a while and removed, so a definition that crashes, logs an error or never
  appears is found by a test and not by a player.
- **Menus and keys on every platform.** A test walks the menus and the first tutorial lessons by
  key press on Windows, macOS and Linux. A key that does nothing on one platform fails the test on
  that platform.
- **Small tests of one behaviour.** A ship's gun fires and hits; a mining laser breaks an
  asteroid. Each is a few lines and is the pattern for the next one.

## Context

What exists on 2026-11-13:

- **The component tier launches the whole game and runs in real time.** `tests/component` has
  nine Gherkin scenarios (S1–S8, T1). Each starts the full game (a real window on Windows and
  macOS, an offscreen graphics context on Linux) and drives it over the debug console. It always
  needs a graphics context. A scenario that waits 900 ticks (112.5 s of game time) takes about
  that long. The game's own time acceleration stops at 16×. This spec calls these the *windowed*
  scenarios.
- **Key presses are tested on Windows only.** The tutorial walkthrough (T1) sends real key events
  to the focused window with a Windows API. It needs the desktop to itself. Nothing presses a key
  on macOS or Linux.
- **The tutorial's "next" is the `n` key.** It is the *activate equipment* control, bound to `n`
  by default. The windowed game receives keys from the platform by physical key position and
  translates them through the active keyboard layout. The tutorial has no row of its own on the
  start screen: it is reached through *Start New Commander* and the scenario screen.
- **The report.** A player on the Flatpak build could not press `n` in the tutorial. The cause is
  not known. No matching issue was found in OoliteProject/oolite's tracker on 2026-11-13, and
  where it was reported is not recorded here.
- **The unit tests use stand-ins.** About 230 test programs exercise classes against stand-in
  universes and entities. None runs the real universe with the real data.
- **Spec 003 planned a headless game and has not started.** `specs/003-encapsulate-global-state`
  reaches a headless game by removing every global first. It has a plan and no tasks. Its User
  Story 3 (police against pirate, headless) is the same test as this spec's User Story 1.
- **Core content.** `Resources/Config/shipdata.plist` holds 194 definitions, 81 of them templates
  that other definitions copy, and `equipment.plist` holds 41 items. The census reads the data
  itself, so these counts are context and not part of any test.
- **Platforms.** The suites are run on Windows. The macOS build runs, and the component runner has
  macOS and Linux paths. CI builds Linux as AppImage, Ubuntu, Fedora and Flatpak packages and runs
  no tests on them.

## User Scenarios & Testing *(mandatory)*

The users are the people who change the game and need to know they have not broken it: Jon, the
agents working through Spec Kit tasks, and the upstream Oolite maintainers. Players benefit
indirectly, through faults that no longer reach a release.

### User Story 1 - Run a scene without a window, faster than real time (Priority: P1)

A developer writes a C++ test that creates a game with a fixed seed, spawns a police ship and a
pirate 10 km apart, advances 112.5 s of game time and asserts that the police ship engaged the
pirate and survived. The test opens no window, and it runs on a machine with no display and no
sound device. It finishes in a few seconds, and it gives the same result on every run.

**Why this priority**: The census and the menu tests are both written on top of this. On its own
it already replaces the slowest part of the developer loop: the combat scenarios that today cost a
game launch and two minutes of waiting each.

**Independent Test**: Write the police-against-pirate scenario
(`tests/component/features/s1_police_kills_pirate.feature`) as a headless test with the same seed.
Run it on a machine with no display and no audio device. It passes, and the game time it covers is
at least 20 times the real time it took to step through it.

**Acceptance Scenarios**:

1. **Given** a headless game seeded with 20260910 holding one police ship and one pirate 10 km
   apart, **When** the test advances 112.5 s of game time, **Then** the police ship has engaged the
   pirate and survives, as in the windowed scenario.
2. **Given** the same test, **When** it runs 100 times in a row on one machine, **Then** every run
   reports the same events in the same order at the same game times.
3. **Given** a machine with no display, no graphics card and no sound device, **When** the
   headless tests run, **Then** they pass.
4. **Given** a headless game, **When** game code would draw, play a sound or read an input
   device, **Then** nothing is drawn or played, the simulation carries on, and the test can ask
   what was requested.
5. **Given** a ship whose behaviour comes from the game's shipped AI and scripts, **When** it runs
   headless, **Then** it runs the same game code and the same data files as in the windowed game.
6. **Given** a failing headless test, **When** the developer reads the output, **Then** it gives
   the test name, the seed and the game time of the failure, and one command reruns that test
   alone.

---

### User Story 2 - Every ship and every equipment item is tried (Priority: P2)

A developer runs the census. It reads the core data, and for every ship definition it creates the
ship in a headless game, runs it for a fixed span of game time and removes it. For every equipment
item it fits the item to a ship that can carry it, uses it where it can be used, and removes it.
The census reports each definition by name as passed, failed or not applicable (with the reason).
A definition added to the data tomorrow is covered without anyone editing the test.

**Why this priority**: This is the first reason Jon gave for wanting the tier. It turns "all the
ships work" from an assumption into a result, on every platform, after every change.

**Independent Test**: Run the census on the core data. It lists every ship definition and every
equipment item by name with an outcome, and the number listed equals the number in the data. Add
a deliberately broken ship definition to a copy of the data: the census fails and names that
definition and no other.

**Acceptance Scenarios**:

1. **Given** the core ship data, **When** the census runs, **Then** every definition is created,
   simulated for the fixed span and removed, and each gets exactly one outcome.
2. **Given** a ship that is created, **When** it is simulated, **Then** it passes only if it is
   present in the game with the parts its definition declares, the run produces no error-level
   log line and no script error attributed to it, and after removal nothing of it remains.
3. **Given** the core equipment data, **When** the census runs, **Then** every item is fitted to a
   ship that can carry it, activated if it is something a player can activate, and removed, with
   the same pass conditions.
4. **Given** a definition that cannot stand on its own (a template that other definitions copy, a
   part that exists only attached to a parent, an item that is a one-off service and not a
   fitting), **When** the census meets it, **Then** it is reported as not applicable with the
   reason, and never skipped silently.
5. **Given** one definition that fails, **When** the census finishes, **Then** every other
   definition has still been tried, and the report names each failure with its seed.
6. **Given** a census that tried no definitions, or fewer than the data holds, **When** it
   finishes, **Then** it fails.
7. **Given** the census runs under the project's sanitizer build, **When** it finishes, **Then**
   there are no sanitizer reports.

---

### User Story 3 - Menus and the tutorial respond to keys on every platform (Priority: P2)

A developer runs the menu tests on Windows, macOS and Linux. Each test starts a headless game at
the start screen and presses keys: it moves through the menu, opens each screen the menu leads to,
backs out, starts the tutorial and advances through its first lessons with `n`. The test checks
which screen is showing, which row is selected and what the rows say. The same test source runs on
all three platforms, and no test needs the desktop.

**Why this priority**: A menu that ignores a key makes the game unusable, and today only Windows
has any test that presses one. It is second to Story 1 only because it is built on it.

**Independent Test**: Run the menu tests on each of the three platforms with no display. They
pass. Then change one key's translation on one platform so that `n` arrives as a different key:
the tutorial test fails on that platform and says which key press had no effect.

**Acceptance Scenarios**:

1. **Given** a headless game at the start screen, **When** the test presses down, up and enter,
   **Then** the selection moves row by row and enter opens the selected entry's screen.
2. **Given** each entry on the start screen and on the options screens beneath it, **When** the
   test opens it and backs out by key, **Then** the expected screen showed and the game returned
   to where it was.
3. **Given** the tutorial has started, **When** the test presses `n`, **Then** the tutorial moves
   to its next step, for every step of lessons 0 and 1.
4. **Given** a key press in a test, **When** it is delivered, **Then** it enters the game as the
   event the platform layer hands the game for that physical key, and goes through the same key
   handling as in the windowed game.
5. **Given** a key held down across several frames, **When** the game reads it, **Then** a
   control that acts once per press acts once, as it does for a player.
6. **Given** the same tests, **When** they run under each keyboard layout in the test set (US, one
   other Latin layout where letters move, one non-Latin layout), **Then** each control answers to
   the key the game's own key settings name for it.
7. **Given** the tests run, **When** they finish, **Then** the developer's own saved games, key
   settings and preferences are untouched.

---

### User Story 4 - The Flatpak `n` report is reproduced or ruled out (Priority: P3)

A developer takes the report that `n` did nothing in the tutorial on the Flatpak build, and uses
the Story 3 tests to find out why. The tests run inside the environment the Flatpak package is
built for. The outcome is one of two things. Either a test fails in a way that matches the report,
and the fault is fixed with that test left in place to guard it. Or the tests pass, and a written
finding says what has been ruled out, what the headless tests cannot see, and how to check the
rest by hand.

**Why this priority**: It is one report with an unknown cause, and the feature may or may not be
able to see it. The first three stories are worth having whatever the answer is.

**Independent Test**: The feature's notes hold either the name of a test that failed before a
named fix and passes after it, or a finding with the three parts above.

**Acceptance Scenarios**:

1. **Given** the Flatpak build environment, **When** the Story 3 tests run in it, **Then** they
   run to a result with no display, and the result is recorded.
2. **Given** a test that reproduces the report, **When** the fault is fixed, **Then** the test
   passes, it stays in the suite, and it fails again if the fix is taken out.
3. **Given** no test reproduces the report, **When** the investigation ends, **Then** the finding
   lists the parts of the key path the tests covered, the parts they cannot cover (the windowing
   system, input methods, the sandbox's access to input devices), and a manual procedure for
   those.

---

### User Story 5 - The combat scenarios run headless (Priority: P3)

The eight windowed combat scenarios (S1–S8) each have a headless counterpart with the same seed,
the same spawns and the same tolerant assertions. A developer who changes ship AI runs all eight
in well under a minute and without the desktop.

**Why this priority**: It is the day-to-day gain from the tier, but each scenario is a small step
once Story 1's first one exists.

**Independent Test**: Run the eight headless scenarios with no display. They pass, and together
they take less real time than one windowed scenario does today.

**Acceptance Scenarios**:

1. **Given** each of S1–S8, **When** its headless counterpart runs, **Then** it asserts the same
   outcome as the windowed scenario, within the same number of ticks.
2. **Given** a headless scenario and its windowed original disagree, **When** this is found,
   **Then** work on that scenario stops and the difference is reported. Neither test's expectation
   is changed to make them agree.
3. **Given** the windowed scenarios, **When** this story is done, **Then** they are all still in
   the tree and still run.

### User Story 6 - One behaviour of one ship is tested at a time (Priority: P2)

A developer writes a short test of a single thing a ship does. They create the ship, give it what
the behaviour needs, run a short span of game time and assert on the ship itself. Four such tests
ship with the feature: a ship's forward laser fires and damages what is in front of it; a ship
told to attack opens fire without further help; a ship with a mining laser breaks an asteroid into
boulders; and the player's fire key fires the player's laser.

**Why this priority**: The census says a ship can exist. These say a ship can do something. They
are also the smallest complete examples of the tier, so they are what a developer copies to write
the next one. (Jon asked for them on 2026-11-13.)

**Independent Test**: Run the four tests with no display; they pass. Take the weapon off the
shooting ship in the first test: it fails, and says the shot did not land.

**Acceptance Scenarios**:

1. **Given** a ship with a pulse laser and a target directly ahead and in range, **When** the ship
   fires its forward weapon, **Then** the weapon heats, the target loses energy, and the game
   reports the target as attacked.
2. **Given** a ship with a laser, a target a few kilometres away, and an order to attack it,
   **When** up to 60 s of game time pass, **Then** the target has been attacked and has lost
   energy.
3. **Given** a ship with a mining laser ordered to mine an asteroid 2 km away, **When** up to
   2 minutes of game time pass, **Then** the asteroid is destroyed and at least two boulders
   exist where there were none.
4. **Given** the player in flight with a pulse laser and a target directly ahead, **When** the
   test holds the fire key, **Then** the target loses energy and the player's weapon heats.
5. **Given** any of these tests with its weapon removed, **When** it runs, **Then** it fails.
6. **Given** a ship that a test added and that has since been destroyed, **When** the test asks
   about it, **Then** the test is told it is gone, and the test's hold on the ship has not kept
   it in the game.

### Edge Cases

- **No devices at all.** In a container with no display server, no graphics driver and no sound
  device, the tests pass. They do not skip.
- **Code that cannot do without graphics.** If some game code cannot run without a real graphics
  context, the test that reaches it fails and names it. It is never skipped quietly.
- **Faster means more steps, not bigger steps.** Time advances in the step sizes the windowed game
  uses. A test runs faster because steps are not paced to the clock. Larger steps would change the
  physics and the AI, and are not used.
- **Things tied to the real clock.** Script timers, frame callbacks, background loading and
  anything else that reads the real time must follow simulated time in a headless game. Any that
  cannot is listed with its reason.
- **Ships that leave by design.** Some definitions expire, explode or remove themselves within the
  census span. That is a pass if the definition says so, and is reported as such.
- **Ships that need company.** A station expects a system, a missile a target, an escort a
  leader. The census gives each what its definition requires. A requirement it cannot meet makes
  the definition not applicable with the reason, not a failure.
- **Equipment with conditions.** Items limited by technology level, by ship type or by a script
  condition are fitted where their conditions hold.
- **Keyboard layouts.** On a layout where the `n` character sits on another physical key, or where
  letters need a modifier, the test still presses the key the game's key settings name.
- **Text entry.** Screens that take typed text (a commander's name, a search) receive characters
  as well as keys, and both reach the game.
- **A test that hangs.** Every test has a limit in real time. One that exceeds it is stopped and
  reported by name, with the game time it had reached.
- **Many tests at once.** Tests run in parallel as separate processes. No two share a settings
  directory, a log file or a cache.
- **Differences between platforms.** Arithmetic can differ in the last digit from one platform to
  another. Assertions are tolerant ("within N ticks", "no pirate remains"), as the component
  tier's are. Exact repeatability is required per platform, not across platforms.
- **Expansions.** No test in this feature reads or loads expansion content (hard rule 4).

## Requirements *(mandatory)*

### Functional Requirements

**Headless game**

- **FR-001**: A C++ test MUST be able to create a game in its own process that opens no window and
  uses no graphics device, sound device or input device.
- **FR-002**: A headless game MUST run the same simulation code and load the same core data files
  as the windowed game. Only presentation and device input are replaced.
- **FR-003**: Where game code would draw, play a sound or read a device, a headless game MUST
  carry on without it, and MUST let the test read what was requested. Code that cannot proceed
  without a real device MUST fail the test with a message naming it.
- **FR-004**: A test MUST advance the game by an amount of game time or a number of ticks. The
  advance MUST be made of steps of the sizes the windowed game uses, and MUST NOT wait on the real
  clock.
- **FR-005**: Everything in the game that measures time MUST follow simulated time in a headless
  game. Each exception MUST be listed in the feature's notes with its reason.
- **FR-006**: A headless game MUST take a seed. Two runs with the same seed, the same data and the
  same test steps on the same platform MUST produce the same events at the same game times.
- **FR-007**: A test MUST be able to spawn ships and other entities by role or by definition name
  at a chosen position, find entities by role, position and state, and read the events the game
  raised (attacked, destroyed, docked and the like).
- **FR-008**: A headless game MUST keep its settings, saved games, logs and caches in a private
  location created for that test, and MUST NOT read or write the developer's own.
- **FR-009**: Creating a headless game MUST NOT require the whole of spec 003's encapsulation. One
  game per test process is sufficient for this feature.

**Running the tests**

- **FR-010**: The headless tests MUST run from the project's test runner as a named tier of their
  own, and MUST be included when all tiers are run.
- **FR-011**: The tier MUST build and run on Windows x64, macOS arm64 and Linux x64 from one set of
  test sources, under both Clang and GCC where the project builds with both.
- **FR-012**: Tests MUST be runnable in parallel as separate processes, and MUST NOT need the
  desktop, the foreground window or any other exclusive resource.
- **FR-013**: Every test MUST have a real-time limit. A test that exceeds it MUST be reported as a
  failure by name.
- **FR-014**: A failure MUST report the test, the seed, the game time, and what was expected and
  found. One command MUST rerun that test alone.
- **FR-015**: The tier MUST run under the project's sanitizer build with no new reports.
- **FR-016**: Adding the tier MUST NOT change how the shipped game behaves, what it installs or
  what it links.

**Census**

- **FR-017**: The census MUST take its list of ship definitions and equipment items from the core
  data at run time. No list of names is kept in the test.
- **FR-018**: For each ship definition the census MUST create it, simulate it for a fixed span of
  game time, and remove it. It passes only if it was present with the parts its definition
  declares, no error-level log line or script error was attributed to it, and nothing of it
  remains after removal.
- **FR-019**: For each equipment item the census MUST fit it to a ship that can carry it, activate
  it if a player can activate it, simulate for a fixed span, and remove it, with the pass
  conditions of FR-018.
- **FR-020**: Every definition MUST end with exactly one outcome: passed, failed, or not
  applicable with a reason. The census MUST fail if any definition has no outcome, or if the
  number of outcomes differs from the number of definitions in the data.
- **FR-021**: One definition's failure MUST NOT stop the others from being tried, and MUST NOT
  alter their results.
- **FR-022**: A failure found by the census when it is first run is a finding. It MUST be recorded
  in the feature's notes with the definition's name and the evidence. It is cleared by a fix to
  the game or the data, or by an entry in an expected-failures list that carries a reason. The
  census MUST fail when a listed definition passes, so the list cannot go stale.

**Menus and keys**

- **FR-023**: A test MUST be able to press, hold and release a key, and to enter text. A key MUST
  enter the game as the event the platform layer hands the game for a physical key (the key's
  position and the modifier state), through the same event queue, and MUST pass through all of the
  game's own key handling unchanged.
- **FR-024**: A test MUST be able to read which screen is showing, which row is selected, and each
  row's text and whether it can be selected.
- **FR-025**: The menu tests MUST visit every entry on the start screen and on the options screens
  beneath it by key, and return from each.
- **FR-026**: A test MUST start the tutorial and advance through every step of lessons 0 and 1
  with the tutorial's own "next" control, checking after each press that the tutorial moved.
- **FR-027**: The key tests MUST run under each layout in a fixed set: US, one other Latin layout
  in which letters change position, and one non-Latin layout. A layout is supplied to the test as
  a recording of what a real system gives for each key under that layout.
- **FR-028**: On Linux the key tests MUST also run inside the environment the Flatpak package is
  built for.
- **FR-029**: The key tests MUST be shown able to fail: with one key's translation deliberately
  altered, the test that depends on that key fails and names the press that had no effect.

**Outcome of the Flatpak report**

- **FR-030**: The feature's notes MUST end with one of: a test that reproduced the report and the
  fix that made it pass; or a finding that states what the tests covered, what they cannot cover,
  and a manual check for the remainder.

**Existing tests**

- **FR-031**: The windowed component, GUI and smoke tiers MUST keep running with the results they
  have today. No existing test is removed or changed by this feature (hard rule 1).
- **FR-032**: Each of the scenarios S1–S8 MUST have a headless counterpart with the same seed,
  spawns and assertions. A disagreement between a counterpart and its original MUST stop work on
  that scenario and be reported.
- **FR-033**: The testing docs, the agent contract's command list and exemplar table, and the
  glossary MUST describe the new tier and name one headless test as its exemplar.

**Basic behaviours**

- **FR-034**: The feature MUST include tests of four single behaviours: a forward laser fired
  directly; a ship ordered to attack opening fire; a mining laser breaking an asteroid into
  boulders; the player's fire key firing the player's laser.
- **FR-035**: A test MUST be able to add one ship by its definition name at a chosen place
  (a position, ahead of another entity, or near one), and call the game's own operations on it.
- **FR-036**: A test's reference to a ship it added MUST NOT keep that ship in the game or change
  when the game considers it gone. The test MUST be able to ask whether the ship still exists,
  and to match events to it after it is gone.
- **FR-037**: A game that starts in flight MUST be able to take key presses, so that a flight
  control can be tested without going through the menus.

### Key Entities

- **Headless game**: a game created by a test, with a seed, a private settings location and no
  devices. It holds entities, advances in simulated time and records events.
- **Simulated time**: the game's clock in a headless game. It moves only when the test advances
  it, in the windowed game's step sizes.
- **Event record**: what the game raised during a run (attacked, destroyed, docked, script
  errors, error-level log lines), in order, each with its game time.
- **Presentation record**: what the game asked to draw or play, kept for the test to read. It
  includes the showing screen, its rows and the selection.
- **Key event**: one press or release of a physical key, or a piece of entered text, as the
  platform would deliver it.
- **Definition**: one ship entry or one equipment entry in the core data, identified by its name.
- **Census outcome**: for one definition, passed, failed (with evidence) or not applicable (with a
  reason).
- **Expected-failures list**: definitions known to fail, each with a reason. Checked in both
  directions.
- **Layout set**: the keyboard layouts the key tests run under.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The police-against-pirate scenario passes headless on a machine with no display and
  no sound device. Game time advances at least 20 times faster than real time while it steps, and
  the whole test, start-up included, takes under 15 seconds.
- **SC-002**: Run 100 times in a row with one seed on one machine, a headless scenario gives the
  same result 100 times.
- **SC-003**: The census gives an outcome to 100% of the ship definitions and equipment items in
  the core data. None is unaccounted for, and every "not applicable" and every expected failure
  has a written reason.
- **SC-004**: The census finishes in under 5 minutes on the development machine.
- **SC-005**: The menu and tutorial tests pass on Windows, macOS and Linux from the same test
  sources, with no display, under all three layouts in the set.
- **SC-006**: Every entry on the start screen and the options screens is opened and returned from
  by key in a test: 100% of the entries, counted from the game's own menu.
- **SC-007**: With `n` deliberately mistranslated on one platform, the tutorial test fails on that
  platform and passes on the others.
- **SC-008**: The Flatpak report is closed as reproduced and fixed, or as ruled out with a written
  finding. It is not left open.
- **SC-009**: All eight combat scenarios run headless in less real time, in total, than one of
  them takes in the windowed tier today.
- **SC-010**: The whole headless tier, run in parallel on every core of the development machine,
  finishes in under 10 minutes, and gives the same results as when its tests are run one at a
  time.
- **SC-011**: Every existing suite (unit, component, smoke, GUI) has the same results after the
  feature as before it, and the smoke run's frame time is within 2% of what it was.
- **SC-012**: The four basic behaviour tests pass on Windows, macOS and Linux with no display,
  each in under 15 seconds, and each fails when the weapon it tests is removed.

## Assumptions

- **"Module" means equipment.** "Each ship and module type" is read as every ship definition and
  every equipment item in the core data. Parts attached to ships (turrets, engines and other
  sub-parts) are covered with the ship that carries them.
- **These are C++ tests.** Jon asked for C++. They are written on whichever C++ test harness the
  unit suites use when the work starts: the in-tree one today, Google Test if spec 005 has landed.
- **They are component tests** (Jon, 2026-11-13). The component tier gains a C++ half that runs
  headless. The Python scenarios that launch the whole game are its other half and stay. Where
  this spec says "the tier" or "headless tests" it means the C++ component tests, and "windowed"
  means the Python ones.
- **Core content only.** The census covers the game's own data. Expansions are untrusted input
  (hard rule 4) and are out of scope. Running the census over the expansion corpus later is
  separate work.
- **What the tier does not see.** A ship that simulates correctly but draws wrongly, a sound that
  does not play, and anything wrong in the windowing system are not found by headless tests. The
  smoke and GUI tiers remain the check for those.
- **Keyboard only.** Menu tests press keys. Mouse and joystick input stay with the GUI tier.
- **How far down a key test reaches** (found in planning, 2026-11-13; see research.md R7). The
  step that reads the operating system's keyboard layout is inside the platform library's
  windowing code, and it does not run without a display. A headless test therefore starts at the
  event that library hands the game, and gets its layouts from recordings. Everything the game
  does with a key is covered on every platform. The operating system's own layout step, window
  focus and the Flatpak sandbox's access to input devices are not. They are named in Story 4's
  finding with a manual check.
- **Platforms.** Windows x64, macOS arm64 and Linux x64. The existing unit suites are Windows-only
  and use Windows-only stand-ins, so this tier cannot depend on them.
- **The report's origin.** The Flatpak report is taken to concern a packaged build a player
  installed. Whether that was upstream's Objective-C build or this fork's is not known. If the
  fault exists only in upstream's code, tests of this fork cannot reproduce it, and the finding
  (FR-030) says so.
- **Bugs the census finds.** Each is recorded. A small fix that unblocks a story is made in this
  feature. Anything larger is separate work, and its definition goes on the expected-failures
  list with the reason until then. Jon adjudicates the list.
- **Speed targets are first estimates.** The 20× and 15-second figures in SC-001 and the 5 and 10
  minutes in SC-004 and SC-010 were set before any measurement. The plan measures a baseline. If
  a target cannot be met, that is reported with the measurement; the target is not quietly
  lowered.

### Relation to spec 003

Spec 003 gets to a headless game by first giving every global an owner. This feature needs the
headless game now and does not wait for that. It accepts one game per test process, with the
globals still in place, and makes only the changes a headless game cannot do without. What it
builds is the entry point spec 003 describes, so spec 003 later tightens it (two games in one
process, services passed in) and does not replace it. If this feature lands first, it satisfies
spec 003's User Story 3 and its SC-001 and SC-002, and spec 003 gets a one-line note saying so.
Its requirements are not rewritten.

### Where the work happens

- Jon's instruction (2026-11-13): implementation is done in a **new worktree of `oolite-dev`, cut
  from the most recent `seriesb` branch** at the time the work starts. On 2026-11-13 that is
  `seriesb/027-modern-cpp`.
- The worktree goes under `.agent-tmp/`, beside the existing ones, on its own feature branch. The
  main `oolite-dev` checkout holds another feature's uncommitted work and is left alone.
- `seriesb` branches are rebased and force-pushed by their owner. This feature's branch is never
  force-pushed (hard rule 3). If its base moves, the plan says how it follows.

### Decisions taken by default

Hard rule 8 applies: no question was left open. Jon can override any of these.

- **Do not wait for spec 003.** Its full encapsulation is a long series of stages. One game per
  process is enough for every test in this feature and is the shorter road.
- **Keys enter at the platform's event, not at the game's key table.** Setting the game's key
  state directly would be simpler, but it would skip the translation step, which is the likeliest
  place for a fault that shows on one platform only.
- **Fixed step sizes.** Speed comes from not waiting, never from larger steps, so that a headless
  run is evidence about the windowed game.
- **An expected-failures list, checked both ways.** A census over hundreds of definitions will
  probably find some that fail on day one. Without a list the feature could not land until every
  one was fixed; with an unchecked list failures would be hidden for good.
- **Keep the windowed scenarios.** The headless counterparts are added beside them. Retiring any
  windowed scenario is Jon's decision and not part of this feature.
- **Lessons 0 and 1 of the tutorial.** They are advanced by `n` alone, which is the reported
  fault. Later lessons need flying and stay with the windowed walkthrough.
- **Three layouts.** US is the default. A Latin layout with moved letters and a non-Latin layout
  cover the two ways a letter key can be mistranslated. The plan names the exact layouts.
