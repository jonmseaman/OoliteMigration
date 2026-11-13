# Contract: `oo_component`, the C++ component-test interface

`tests/component/cpp/oo_component.hpp` and `.cpp`. The C++ component tests include this and nothing else from the
game unless they need a specific class. Names are indicative. The behaviour is the contract.

## Creating a game

```text
oo::component::Game game = oo::component::Game::scenario(seed);     // empty system, player in flight
oo::component::Game game = oo::component::Game::atStartScreen(seed); // normal start, input view
oo::component::Game game = oo::component::Game::current();           // the one an earlier case made
```

- Before the game starts, the constructor creates a scratch directory under the build directory,
  unique to this process, and points every user-directory variable at it (home, settings, saves,
  logs, snapshots, managed add-ons, extracted add-ons, additional add-ons). The developer's own
  files are never opened.
- It installs the log sink and the observer, then calls `startHeadless`.
- **One `Game` per process.** Constructing a second one fails the test with a message saying so.
  Later cases in the same program reach it with `current()`.
- The destructor does not tear the game down. The process ends instead. This is the current
  limit that spec 003 removes.

## Time

| Call | Effect |
|---|---|
| `game.step(n)` | `n` steps of 1/60 s: poll input if there is a view, then `tick` |
| `game.runFor(seconds)` | rounds up to whole steps |
| `game.runUntil(predicate, maxSeconds)` | steps until the predicate is true; returns whether it became true |
| `game.time()` | game time in seconds |

`runUntil` is how a test says "within N ticks". The component tier's tick is 0.125 s, so its
"within 900 ticks" is `runUntil(…, 112.5)`.

## Entities

| Call | Effect |
|---|---|
| `game.spawn(count, role)` | the windowed step "I spawn N ship(s) with role R" |
| `game.spawnWithin(count, role, km)` | the windowed step "… within K km" |
| `game.countWithRole(role)` | the windowed steps' `system.countShipsWithRole` |
| `game.engages(hunter, quarry)` | the windowed step "a ship with role H engages a ship with role Q" |
| `game.spawnKey(key, position)` | one ship by definition name; returns it or null |
| `game.remove(ship)` | removes it without an explosion |
| `game.shipsWithRole(role)` | the live ships whose primary role is `role` |
| `game.entityCount()` | everything in the universe |
| `game.player()` | the player's ship |

The first four run the same script the windowed step runs, including its pinned ship key per
role, its bounty for pirates and its AI per role (`tests/component/steps/world_steps.py`). Worked
samples are in [examples.md](../examples.md).

## Script expressions

`game.eval(source)` evaluates a script expression in the game's engine, the way the debug console
does, and returns a number, a string or a boolean.

- A ported scenario uses the **same expression** as the component step it ports, copied from
  `tests/component/steps/world_steps.py`. That is what keeps the assertion's meaning (FR-032).
- An expression that throws fails the test and prints the message.

## What happened

| Call | Returns |
|---|---|
| `game.events()` | the event record ([data-model.md](../data-model.md#event-record)) |
| `game.errors()` | the entries with `isError` |
| `game.presentation()` | frames and sounds requested |
| `game.digest()` | the scenario digest for the current step |

`OO_COMPONENT_CHECK_NO_ERRORS(game)` fails the case and prints each error entry.

## Keys and screens

Only for a game made with `atStartScreen`.

| Call | Effect |
|---|---|
| `game.useLayout(name)` | install a recorded layout from `tests/component/cpp/layouts/` |
| `game.press(key)` | key down, steps until the game has sampled it, key up, steps until sampled |
| `game.hold(key, predicate, maxSeconds)` | key down, `runUntil`, key up |
| `game.pressScancode(scancode, mods)` | by physical key, for fault tests |
| `game.type(text)` | one press per character |
| `game.screen()` | the showing screen id |
| `game.selectedRow()`, `game.rowText(i)`, `game.rowKey(i)` | menu state |
| `game.selectRowWithKey(key)` | presses up or down until that row is selected; fails after one full cycle |

- `key` is a character or a named key (`enter`, `escape`, `up`, `f5`). It is looked up in the
  current layout to get the scancode and modifiers. Every press becomes `SDL_EVENT_KEY_DOWN` and
  `SDL_EVENT_KEY_UP` on SDL's queue.
- **Every press that should change something is checked.** `press` returns nothing; a test pairs
  it with a check or uses `hold`. A helper, `OO_COMPONENT_PRESS_EXPECT(game, key, predicate)`, fails
  with "pressing <key> had no effect at <screen>, game time <t>", which is the message SC-007
  needs.

## Failure output

Every failed check prints, besides the harness's own line: the seed, the game time, the showing
screen, and the last ten entries of the event record. The program's name is the rerun command's
argument: `tests/run.sh component --cpp -k <name>`.

## Limits a test may rely on

- A `Game` never touches the network.
- A `Game` never reads an expansion.
- No call waits on the real clock. A test's real duration is bounded by its step count.
