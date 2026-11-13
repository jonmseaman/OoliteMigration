# Contract: the headless game

What the game exposes so that a test can run it with no devices. This is production code in
`src/Core` and `src/SDL`. Signatures are indicative; the behaviour is the contract.

## `OOHeadlessOptions` (`src/Core/OOHeadless.h`)

The fields and their defaults are in [data-model.md](../data-model.md#headless-options).

- A default-constructed value means "the windowed game, exactly as today".
- The header includes nothing from the game beyond basic types. It must stay cheap to include.

## `GameController::startHeadless(const OOHeadlessOptions&)`

Starts a game with no window.

- **Does**, in the order `applicationDidFinishLaunching` does them: seed the generators from
  `options.seed`; create the view without a window if `options.inputView`; create the universe
  through `Universe::newUniverse` with the options; load the player; if `options.startInFlight`,
  put the player in flight in the empty system.
- **Does not**: show a splash, set up display modes, create the expansion manager, create a
  window or GL context, open a sound device, start the frame loop, sleep.
- **Fails** by raising, with a message, if the options are inconsistent (see the data model's
  rules) or if a universe already exists in the process.
- **Must be called on the controller the game uses.** There is one per process.
- Returns when the game is ready for its first `tick`.

## `GameController::tick(OOTimeDelta dt)`

One simulation step: universe update, restart check, sound update, frame callbacks, in that
order.

- The windowed frame loop calls it with the dt it measured, then draws. Its behaviour must be
  what `doPerformGameTick` did before the split. The existing suites are the check.
- A headless game calls it with `options.step`. It advances the game clock by `dt` first.
- It never reads the real clock and never sleeps.
- If the game has a view, the caller polls input before `tick`, as the windowed loop does.

## Game clock (`OOGameClock`)

Owned by the controller.

- `monotonicSeconds()` and `timeOfDay()`.
- Windowed: both read the system.
- Headless: see the data model. Only `tick` advances it.
- These reads go through it and no longer through the system: frame dt; the ship clock's start;
  deferred-call deadlines; the GUI-screen time delta; the escape-pod double press; the
  frame-callback id start.
- Log timestamps and profiling keep reading the system.

## `OOGraphicsAvailable()`

- True in the windowed game once the GL context exists. False in a headless game, always.
- When false: the extension manager reports no shaders and makes no GL call; the guarded sites
  listed in research R2 do nothing; textures are not decoded and report zero size; materials are
  the basic kind.
- **No GL function may be called while it is false.** The GL trap enforces this in the test
  programs on Linux and macOS.
- It must not change what the simulation computes. A site whose skipped GL work feeds game state
  is a defect to report, not to guard.

## Sound

A headless game does not open a device. The existing "sound not OK" path makes every call a
no-op. Each request to play is appended to the presentation record before that path returns.

## `OOGameObserver`

An optional interface the controller holds. Null by default.

- `shipEvent(time, ship, name)`: called where a ship's script event is dispatched.
- `worldEvent(time, name)`: called where a world script event is dispatched.
- Called on the main thread, before the scripts run. It must not change game state.
- With no observer set the cost is one null check per dispatch.

## Script engine

In a headless game only:

- `Math.random` is replaced by a function drawing from a generator seeded from `options.seed`.
- The time limiter's limit is `options.scriptTimeLimit`.

Everything else about the engine is unchanged. `Date.now` and `performance.now` still read the
system; uses in the core scripts are listed in `tasks.md` (FR-005).

## `MyOpenGLView::initHeadless()`

Used when `options.inputView` is true.

- Initialises SDL's events and video subsystems with the video driver hint set to `dummy`. No
  audio, joystick or gamepad subsystem.
- Creates no window and no GL context.
- `pollControls()` works as in the windowed game and drains SDL's queue.
- The view's size is a fixed nominal size, so code that asks for it gets a sane answer.

## Key lookup member

`MyOpenGLView` gains one replaceable member: given (scancode, modifiers), return the key code.

- Default: `SDL_GetKeyFromScancode(scancode, modifiers, false)`, which is what the code does now.
- `pollControls` calls it in the one place that line is today. Nothing else changes.
- Tests replace it with a recorded layout. The shipped game never does.

## What must not change

- The windowed game's behaviour, timing, saved games, log output and scripting API.
- The debug console protocol, which the component tier uses.
- Any existing test.
